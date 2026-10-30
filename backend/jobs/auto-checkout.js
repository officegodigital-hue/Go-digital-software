'use strict';

const db = require('../config/db');
const attendancePolicy = require('../lib/attendancePolicy');

// Format a MySQL Date/string as "YYYY-MM-DD HH:MM:SS" (local time, matching DB storage)
function sqlDateTime(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const pad = (n) => String(n).padStart(2, '0');
    return (
      value.getFullYear() + '-' +
      pad(value.getMonth() + 1) + '-' +
      pad(value.getDate()) + ' ' +
      pad(value.getHours()) + ':' +
      pad(value.getMinutes()) + ':' +
      pad(value.getSeconds())
    );
  }
  return String(value).slice(0, 19).replace('T', ' ');
}

/**
 * Auto-checkout cron job — runs every minute.
 *
 * Handles the case when the employee's phone is closed (no live heartbeats):
 *  Rule 1 – Outside radius + grace passed → checkout at departure time.
 *  Rule 2 – No GPS ping for `no_gps_timeout_minutes` → checkout at last ping time.
 *           Paused during an active break.
 */
async function runAutoCheckout() {
  const today = attendancePolicy.todayIstDate();
  const now = attendancePolicy.nowIstDateTime();
  let checked = 0;

  // Fetch ALL open attendance sessions (any date) — an employee may have
  // checked in on a previous calendar day and never checked out
  const [openSessions] = await db.query(
    `SELECT ar.id, ar.employee_id, ar.check_in_at,
            ep.work_mode
     FROM attendance_records ar
     JOIN hrms_employee_profiles ep ON ep.employee_user_id = ar.employee_id
     WHERE EXISTS (SELECT 1 FROM employee_users u WHERE u.id=ar.employee_id AND u.is_active=1)
       AND ar.check_in_at IS NOT NULL
       AND ar.check_out_at IS NULL`
  );

  if (!openSessions.length) return { checked, today };

  // Fetch tracking settings once
  const [[settings]] = await db.query('SELECT * FROM hrms_tracking_settings WHERE id = 1');
  if (!settings) return { checked, today };

  const officeGrace = Number(settings.office_outside_radius_grace_minutes) || 5;
  const homeGrace = Number(settings.home_outside_radius_grace_minutes) || 5;
  const officeNoGps = Number(settings.office_no_gps_timeout_minutes) || 30;
  const homeNoGps = Number(settings.home_no_gps_timeout_minutes) || 30;

  for (const session of openSessions) {
    const mode = session.work_mode; // 'Office', 'Home', 'Hybrid'
    // Hybrid employees use field tracking – server handles them differently; skip here
    if (!['Office', 'Home'].includes(mode)) continue;

    const grace = mode === 'Home' ? homeGrace : officeGrace;
    const noGpsMins = mode === 'Home' ? homeNoGps : officeNoGps;

    // ── Rule 1: out of radius + grace expired ─────────────────────────────────
    const [[departure]] = await db.query(
      `SELECT left_at FROM hrms_attendance_radius_departures
       WHERE attendance_id = ? AND status = 'pending'
       LIMIT 1`,
      [session.id]
    );
    if (departure) {
      const minsOut = attendancePolicy.minutesBetween(sqlDateTime(departure.left_at), now);
      if (minsOut >= grace) {
        await _doCheckout(
          session,
          sqlDateTime(departure.left_at), // checkout at departure time
          'outside_radius_auto_checkout',
          `${mode} employee remained outside the approved radius for ${grace} minutes`
        );
        checked++;
        continue; // processed this session
      }
    }

    // ── Rule 2: no GPS for too long ───────────────────────────────────────────
    // Pause during active break
    const [[activeBreak]] = await db.query(
      `SELECT id FROM attendance_breaks
       WHERE attendance_id = ? AND status = 'active'
       LIMIT 1`,
      [session.id]
    );
    if (activeBreak) continue;

    // Only consider pings received AFTER today's check-in — never historical ones
    const [[lastPing]] = await db.query(
      `SELECT recorded_at FROM hrms_location_pings
       WHERE employee_user_id = ?
         AND recorded_at >= ?
       ORDER BY recorded_at DESC
       LIMIT 1`,
      [session.employee_id, sqlDateTime(session.check_in_at)]
    );
    // No ping since check-in yet — employee just started, skip (do not penalise)
    if (!lastPing) continue;

    const minsSincePing = attendancePolicy.minutesBetween(sqlDateTime(lastPing.recorded_at), now);
    if (minsSincePing >= noGpsMins) {
      await _doCheckout(
        session,
        sqlDateTime(lastPing.recorded_at), // checkout at last known ping time
        'no_gps_auto_checkout',
        `No GPS update for ${Math.round(minsSincePing)} minutes (threshold: ${noGpsMins} min)`
      );
      checked++;
    }
  }

  return { checked, today };
}

async function _doCheckout(session, checkoutAt, eventType, reason, auditAt = checkoutAt) {
  const checkIn = sqlDateTime(session.check_in_at);
  const rawMinutes = checkIn ? attendancePolicy.minutesBetween(checkIn, checkoutAt) : 0;
  const [[breakRow]] = await db.query(
    `SELECT COALESCE(SUM(duration_minutes), 0) AS total
     FROM attendance_breaks
     WHERE attendance_id = ? AND status IN ('completed', 'auto_closed')`,
    [session.id]
  );
  const breakMins = Number(breakRow && breakRow.total) || 0;
  const workingMinutes = Math.max(0, rawMinutes - breakMins);

  await db.query(
    `UPDATE attendance_records
     SET check_out_at = ?, working_minutes = ?, session_status = 'completed'
     WHERE id = ? AND check_out_at IS NULL`,
    [checkoutAt, workingMinutes, session.id]
  );
  await db.query(
    `UPDATE hrms_attendance_radius_departures
     SET status = 'auto_checked_out'
     WHERE attendance_id = ? AND status = 'pending'`,
    [session.id]
  );
  await db.query(
    `UPDATE hrms_field_tracking_sessions
     SET is_active = 0, stopped_at = ?
     WHERE employee_user_id = ? AND is_active = 1`,
    [checkoutAt, session.employee_id]
  );
  await db.query(
    `INSERT INTO hrms_attendance_checkout_audit
       (attendance_id, employee_id, event_type, checkout_at, reason)
     VALUES (?, ?, ?, ?, ?)`,
    [session.id, session.employee_id, eventType, auditAt, reason]
  );
}

function shiftEndForDate(workDate, shiftEnd, latestAllowed) {
  const normalizedTime = String(shiftEnd || '').match(/^(\d{2}):(\d{2})(?::(\d{2}))?/);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(workDate)) || !normalizedTime) {
    return latestAllowed;
  }
  const value = `${workDate} ${normalizedTime[1]}:${normalizedTime[2]}:${normalizedTime[3] || '00'}`;
  // Never save a future checkout. This also keeps overnight shifts safe when
  // their configured end falls after the 11:59 PM close job.
  return value <= latestAllowed ? value : latestAllowed;
}

/**
 * End-of-day auto-close — runs at 11:59 PM IST.
 * Closes every open attendance session from today so no session
 * carries over past midnight.
 */
async function runEndOfDayClose() {
  const today = attendancePolicy.todayIstDate();
  const closeAt = today + ' 23:59:00';
  const rules = await attendancePolicy.getTimeSettings(db);
  const attendanceEndsAt = shiftEndForDate(today, rules.shiftEnd, closeAt);
  let closed = 0;

  const [openSessions] = await db.query(
    `SELECT ar.id, ar.employee_id, ar.check_in_at
     FROM attendance_records ar
     WHERE EXISTS (SELECT 1 FROM employee_users u WHERE u.id=ar.employee_id AND u.is_active=1)
       AND ar.attendance_date = ?
       AND ar.check_in_at IS NOT NULL
       AND ar.check_out_at IS NULL`,
    [today]
  );

  for (const session of openSessions) {
    await _doCheckout(
      session,
      attendanceEndsAt,
      'end_of_day_auto_close',
      `Session auto-closed at 11:59 PM; worked time ended at the configured shift end (${rules.shiftEnd})`,
      closeAt
    );
    closed++;
  }

  return { closed, today };
}

module.exports = { runAutoCheckout, runEndOfDayClose, shiftEndForDate };
