const db = require('../config/db');
const staff = require('../lib/staffDirectory');
const policy = require('../lib/attendancePolicy');
const locationPolicy = require('../lib/attendanceLocationPolicy');
const { isWorkingDay } = require('../jobs/auto-absence');

function ok(res, data, message) {
  message = message || 'OK';
  return res.json({ success: true, message: message, data: data });
}

function fail(res, status, message) {
  return res.status(status).json({ success: false, message: message });
}

function parseDateParam(value) {
  if (!value) return policy.todayIstDate();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value))) return null;
  return String(value);
}

function sqlDate(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const year = value.getFullYear();
    const month = String(value.getMonth() + 1).padStart(2, '0');
    const day = String(value.getDate()).padStart(2, '0');
    return year + '-' + month + '-' + day;
  }
  return String(value).slice(0, 10);
}

function sqlDateTime(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const date = sqlDate(value);
    const hh = String(value.getHours()).padStart(2, '0');
    const mm = String(value.getMinutes()).padStart(2, '0');
    const ss = String(value.getSeconds()).padStart(2, '0');
    return date + ' ' + hh + ':' + mm + ':' + ss;
  }
  return String(value).slice(0, 19).replace('T', ' ');
}

function parseMonthParam(value) {
  if (!value) return policy.todayIstDate().slice(0, 7);
  if (!/^\d{4}-\d{2}$/.test(String(value))) return null;
  return String(value);
}

function shiftDurationMinutes(shiftStart, shiftEnd) {
  const toMinutes = function (value) {
    const parts = String(value || '').split(':').map(Number);
    return Number(parts[0] || 0) * 60 + Number(parts[1] || 0);
  };
  const start = toMinutes(shiftStart);
  let end = toMinutes(shiftEnd);
  if (end <= start) end += 24 * 60;
  return Math.max(0, end - start);
}

async function calendarSchedule(month) {
  const [year, monthNumber] = String(month).split('-').map(Number);
  const days = new Date(Date.UTC(year, monthNumber, 0)).getUTCDate();
  let weeklyOffDays = new Set([0]);
  let overrides = new Map();
  try {
    const [policyRows] = await db.query('SELECT weekly_off_days FROM hrms_payroll_policy WHERE id = 1');
    const parsed = JSON.parse((policyRows[0] && policyRows[0].weekly_off_days) || '[0]');
    weeklyOffDays = new Set(Array.isArray(parsed) ? parsed.map(Number) : [0]);
  } catch (_) {}
  try {
    const [rows] = await db.query(
      `SELECT DATE_FORMAT(work_date, '%Y-%m-%d') AS date, status FROM hrms_calendar_overrides
        WHERE work_date >= ? AND work_date <= LAST_DAY(?)`,
      [month + '-01', month + '-01']
    );
    overrides = new Map(rows.map((row) => [row.date, row.status]));
  } catch (_) {}
  const statusFor = function (day) {
    const date = month + '-' + String(day).padStart(2, '0');
    const override = overrides.get(date);
    if (override === 'Holiday') return 'H';
    if (override === 'Weekly Off') return 'OFF';
    if (override === 'Working Day') return '';
    return weeklyOffDays.has(new Date(Date.UTC(year, monthNumber - 1, day)).getUTCDay()) ? 'OFF' : '';
  };
  let workingDays = 0;
  for (let day = 1; day <= days; day += 1) if (!statusFor(day)) workingDays += 1;
  return { days, statusFor, workingDays };
}

function normalizeMethod(value) {
  const method = String(value || 'mobile').toLowerCase();
  if (method === 'wifi' || method === 'office_wifi') return 'wifi';
  if (method === 'manual') return 'manual';
  return 'mobile';
}

function requireAdmin(req, res, next) {
  const userType = String((req.user && req.user.userType) || '').toLowerCase();
  if (userType !== 'admin') {
    return fail(res, 403, 'Admin access required');
  }
  return next();
}

async function breakMinutes(attendanceId) {
  try {
    const [rows] = await db.query(
      "SELECT COALESCE(SUM(duration_minutes), 0) AS minutes FROM attendance_breaks WHERE attendance_id = ? AND status IN ('completed', 'auto_closed')",
      [attendanceId]
    );
    return Number(rows[0].minutes || 0);
  } catch (error) {
    if (error.code === 'ER_NO_SUCH_TABLE') return 0;
    throw error;
  }
}

async function ensureAttendanceBreakTable() {
  await db.query(`CREATE TABLE IF NOT EXISTS attendance_breaks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attendance_id BIGINT UNSIGNED NOT NULL,
    started_at DATETIME NOT NULL,
    ended_at DATETIME NULL,
    duration_minutes INT UNSIGNED NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_attendance_breaks_active (attendance_id, status)
  )`);
  const [idColumns] = await db.query("SHOW COLUMNS FROM attendance_breaks LIKE 'id'");
  if (idColumns[0] && !String(idColumns[0].Extra || '').toLowerCase().includes('auto_increment')) {
    const [indexes] = await db.query("SHOW INDEX FROM attendance_breaks WHERE Column_name = 'id'");
    if (!indexes.length) await db.query('ALTER TABLE attendance_breaks ADD PRIMARY KEY (id)');
    await db.query('ALTER TABLE attendance_breaks MODIFY COLUMN id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT');
  }
  const additions = ['ADD COLUMN allowed_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 60','ADD COLUMN overdue_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 0','ADD COLUMN employee_reason VARCHAR(500) NULL','ADD COLUMN alert_created_at DATETIME NULL','ADD COLUMN reviewed_by BIGINT UNSIGNED NULL','ADD COLUMN reviewed_at DATETIME NULL','ADD COLUMN return_latitude DECIMAL(10,7) NULL','ADD COLUMN return_longitude DECIMAL(10,7) NULL','ADD COLUMN return_accuracy_meters DECIMAL(8,2) NULL'];
  for (const addition of additions) { try { await db.query(`ALTER TABLE attendance_breaks ${addition}`); } catch (error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; } }
}

async function ensureAttendanceSafetyTables() {
  try {
    await db.query('ALTER TABLE attendance_records ADD COLUMN work_mode_snapshot VARCHAR(16) NULL');
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_attendance_break_alerts (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, attendance_break_id BIGINT UNSIGNED NOT NULL, employee_id BIGINT UNSIGNED NOT NULL, overdue_minutes SMALLINT UNSIGNED NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'open', reason VARCHAR(500) NULL, reviewed_by BIGINT UNSIGNED NULL, reviewed_at DATETIME NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, UNIQUE KEY uq_break_alert (attendance_break_id))`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_attendance_checkout_audit (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attendance_id BIGINT UNSIGNED NOT NULL,
    employee_id BIGINT UNSIGNED NOT NULL,
    event_type VARCHAR(40) NOT NULL,
    checkout_at DATETIME NULL,
    latitude DECIMAL(10,7) NULL,
    longitude DECIMAL(10,7) NULL,
    accuracy_meters DECIMAL(8,2) NULL,
    reason VARCHAR(500) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_checkout_audit (attendance_id, created_at)
  )`);
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_attendance_correction_requests (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attendance_id BIGINT UNSIGNED NOT NULL,
    employee_id BIGINT UNSIGNED NOT NULL,
    request_type VARCHAR(40) NOT NULL,
    reason VARCHAR(500) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_by BIGINT UNSIGNED NULL,
    reviewed_at DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_correction_status (status, created_at)
  )`);
  const additions = [
    'ADD COLUMN requested_check_in_at DATETIME NULL',
    'ADD COLUMN requested_check_out_at DATETIME NULL',
    'ADD COLUMN admin_note VARCHAR(500) NULL'
  ];
  for (const addition of additions) {
    try { await db.query(`ALTER TABLE hrms_attendance_correction_requests ${addition}`); }
    catch (error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; }
  }
}

async function persistedWorkedMinutes(record) {
  const stored = Number(record && record.working_minutes || 0);
  if (!record || !record.check_in_at || !record.check_out_at || stored > 0) return stored;
  const completedBreakMinutes = await breakMinutes(record.id);
  return Math.max(0,
    policy.minutesBetween(sqlDateTime(record.check_in_at), sqlDateTime(record.check_out_at)) - completedBreakMinutes);
}

async function getRecord(employeeId, date, executor = db, lock = false) {
  const [rows] = await executor.query(
    'SELECT * FROM attendance_records WHERE employee_id = ? AND attendance_date = ? LIMIT 1' + (lock ? ' FOR UPDATE' : ''),
    [employeeId, date]
  );
  return rows[0] || null;
}

function computeStatus(record) {
  if (!record || !record.check_in_at) {
    return record && record.attendance_status === 'on_leave' ? 'on_leave' : 'absent';
  }
  // Employee physically checked in — 'absent' stored at clock-in means they
  // arrived after the absent threshold; treat as 'late' since they did attend.
  const worked = Number(record.working_minutes || 0);
  if (record.check_out_at && policy.isEarlyExit(worked)) return 'early_exit';
  if (record.is_late || record.attendance_status === 'absent') return 'late';
  return 'present';
}

function capitalize(value) {
  const text = String(value || '');
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function serializeRecord(row, person) {
  const worked = Number(row.working_minutes || 0);
  return {
    id: row.id,
    employeeId: row.employee_id,
    employeeName: person ? person.full_name : null,
    staffId: person ? person.staff_id : null,
    role: person ? person.role : null,
    date: sqlDate(row.attendance_date),
    checkIn: policy.formatDisplayTime(sqlDateTime(row.check_in_at)),
    checkOut: policy.formatDisplayTime(sqlDateTime(row.check_out_at)),
    checkInAt: sqlDateTime(row.check_in_at),
    checkOutAt: sqlDateTime(row.check_out_at),
    method: row.check_in_method,
    isLate: Boolean(Number(row.is_late)),
    workingMinutes: worked,
    status: policy.displayStatus({
      status: row.attendance_status,
      isLate: Number(row.is_late),
      checkInAt: row.check_in_at,
      checkOutAt: row.check_out_at
    })
  };
}

async function dashboard(req, res) {
  try {
    const date = parseDateParam(req.query.date);
    if (!date) return fail(res, 400, 'date must be YYYY-MM-DD');

    const employees = await staff.listActiveStaff(db);
    const totalEmployees = employees.length;
    const ids = employees.map(function (row) { return row.id; });

    const [records] = ids.length
      ? await db.query('SELECT * FROM attendance_records WHERE attendance_date = ? AND employee_id IN (?)', [date, ids])
      : [[]];

    const recordByEmployee = new Map(records.map(function (row) { return [row.employee_id, row]; }));

    const [approvedLeave] = ids.length
      ? await db.query(
        "SELECT employee_id FROM attendance_permission_requests WHERE request_date = ? AND status = 'approved' AND request_type IN ('leave', 'risk_leave') AND employee_id IN (?)",
        [date, ids]
      )
      : [[]];
    const onLeave = new Set(approvedLeave.map(function (row) { return row.employee_id; }));

    let presentToday = 0;
    let lateLogins = 0;
    let absent = 0;
    let wifi = 0;
    const byRole = new Map();

    employees.forEach(function (person) {
      const roleName = person.role || 'Unassigned';
      if (!byRole.has(roleName)) byRole.set(roleName, { name: roleName, total: 0, present: 0 });
      const bucket = byRole.get(roleName);
      bucket.total += 1;

      const record = recordByEmployee.get(person.id);
      const checkedIn = Boolean(record && record.check_in_at);
      // 'absent' stored on check_in_at records means post-threshold arrival — still attended.
      const trulyAbsent = Boolean(record && record.attendance_status === 'absent' && !record.check_in_at) || (!record && !onLeave.has(person.id));
      const isLate = checkedIn && (Number(record.is_late) || record.attendance_status === 'absent');
      if (record && record.check_in_method === 'wifi') wifi += 1;
      if (checkedIn && isLate) lateLogins += 1;
      if (trulyAbsent) {
        absent += 1;
      } else if (checkedIn && !isLate) {
        presentToday += 1;
        bucket.present += 1;
      } else if (checkedIn && isLate) {
        bucket.present += 1;
      }
    });

    const [pendingRows] = await db.query("SELECT COUNT(*) AS total FROM attendance_permission_requests WHERE status = 'pending'");
    const pendingRow = pendingRows[0];

    const weekDays = policy.weekdaysForDate(date);
    const weekly = [];
    for (var i = 0; i < weekDays.length; i++) {
      const day = weekDays[i];
      const [dayRows] = await db.query(
        'SELECT COUNT(DISTINCT CASE WHEN check_in_at IS NOT NULL THEN employee_id END) AS punched FROM attendance_records WHERE attendance_date = ?',
        [day]
      );
      const punched = Number(dayRows[0].punched || 0);
      weekly.push({
        day: policy.weekdayShort(day),
        date: day,
        presentPercent: totalEmployees ? Math.round((punched / totalEmployees) * 100) : 0
      });
    }

    const [activityPunches] = await db.query(
      'SELECT r.employee_id, s.' + staff.quote(staff.STAFF.name) + ' AS full_name, r.check_in_at, r.check_out_at, r.is_late, r.attendance_status, r.check_in_method FROM attendance_records r JOIN ' +
      staff.staffFrom() + ' s ON s.' + staff.quote(staff.STAFF.id) + ' = r.employee_id WHERE r.attendance_date = ? ORDER BY COALESCE(r.check_out_at, r.check_in_at) DESC LIMIT 20',
      [date]
    );

    const activity = [];
    activityPunches.forEach(function (row) {
      if (row.check_out_at) {
        activity.push({
          name: row.full_name,
          action: 'logged Out',
          time: policy.formatDisplayTime(row.check_out_at),
          status: 'Log Out'
        });
      }
      if (row.check_in_at) {
        const wifiLabel = row.check_in_method === 'wifi' ? ' (WIFI)' : '';
        const lateLabel = row.attendance_status === 'absent' ? ' (Absent)' : (Number(row.is_late) ? ' (Late)' : wifiLabel);
        activity.push({
          name: row.full_name,
          action: 'logged in' + lateLabel,
          time: policy.formatDisplayTime(row.check_in_at),
          status: 'Log In'
        });
      }
    });

    const [pendingPermissions] = await db.query(
      'SELECT p.id, p.request_type, p.request_date, p.status, p.reason, s.' + staff.quote(staff.STAFF.name) +
      ' AS full_name FROM attendance_permission_requests p JOIN ' + staff.staffFrom() +
      ' s ON s.' + staff.quote(staff.STAFF.id) + ' = p.employee_id ORDER BY p.created_at DESC LIMIT 20'
    );

    const [recentPermissions] = await db.query(
      'SELECT p.request_type, p.status, p.created_at, s.' + staff.quote(staff.STAFF.name) +
      ' AS full_name FROM attendance_permission_requests p JOIN ' + staff.staffFrom() +
      ' s ON s.' + staff.quote(staff.STAFF.id) + ' = p.employee_id ORDER BY p.created_at DESC LIMIT 8'
    );

    recentPermissions.forEach(function (row) {
      activity.push({
        name: row.full_name,
        action: 'requested ' + String(row.request_type).replace(/_/g, ' '),
        time: policy.formatDisplayTime(row.created_at),
        status: row.status === 'pending' ? 'Pending' : String(row.status)
      });
    });

    const departments = [];
    byRole.forEach(function (row) {
      departments.push({
        name: row.name,
        percentage: row.total ? Math.round((row.present / row.total) * 100) : 0
      });
    });

    return ok(res, {
      date: date,
      timezone: policy.TIME_ZONE,
      shift: {
        start: policy.SHIFT_START,
        end: policy.SHIFT_END,
        requiredHours: policy.REQUIRED_MINUTES / 60,
        lateAfter: policy.LATE_AFTER,
        absentAfter: policy.ABSENT_AFTER
      },
      metrics: {
        totalEmployees: totalEmployees,
        presentToday: presentToday,
        lateLogins: lateLogins,
        absent: absent,
        wifi: wifi,
        permissionPending: Number(pendingRow.total || 0)
      },
      weekly: weekly,
      departments: departments,
      activity: activity.slice(0, 12),
      pendingPermissions: pendingPermissions.map(function (row) {
        return {
          employee: row.full_name,
          type: String(row.request_type).replace(/_/g, ' '),
          date: row.request_date,
          status: capitalize(row.status)
        };
      }),
      log: records.map(function (row) {
        const person = employees.find(function (p) { return p.id === row.employee_id; });
        return serializeRecord(row, person);
      })
    });
  } catch (error) {
    console.error('GET /attendance/dashboard', error);
    return fail(res, 500, error.message);
  }
}

async function clockLogs(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const view = req.query.view === 'day' ? 'day' : 'month';
    let start, end;
    if (view === 'day') {
      const date = parseDateParam(req.query.date);
      if (!date) return fail(res, 400, 'date must be YYYY-MM-DD');
      start = date;
      end = date;
    } else {
      const month = parseMonthParam(req.query.month);
      if (!month) return fail(res, 400, 'month must be YYYY-MM');
      const parts = month.split('-').map(Number);
      const daysInMonth = new Date(Date.UTC(parts[0], parts[1], 0)).getUTCDate();
      start = month + '-01';
      end = month + '-' + String(daysInMonth).padStart(2, '0');
    }

    const employees = await staff.listActiveStaff(db);
    const employeeIdFilter = req.query.employeeId ? Number(req.query.employeeId) : null;
    const scopedEmployees = employeeIdFilter
      ? employees.filter(function (person) { return person.id === employeeIdFilter; })
      : employees;
    const ids = scopedEmployees.map(function (person) { return person.id; });

    const [records] = ids.length
      ? await db.query(
          'SELECT * FROM attendance_records WHERE attendance_date BETWEEN ? AND ? AND employee_id IN (?) ORDER BY attendance_date DESC, check_in_at DESC',
          [start, end, ids]
        )
      : [[]];

    // Profile ID lookup (hrms_employee_profiles.id) keyed by employee_user_id
    const [profileRows] = ids.length
      ? await db.query(
          'SELECT id AS profile_id, employee_user_id, work_mode FROM hrms_employee_profiles WHERE employee_user_id IN (?) AND employment_status <> \'Inactive\'',
          [ids]
        ).catch(function () { return [[]]; })
      : [[]];
    const profileIdByUserId = new Map();
    const workModeByUserId = new Map();
    profileRows.forEach(function (r) {
      profileIdByUserId.set(Number(r.employee_user_id), Number(r.profile_id));
      workModeByUserId.set(Number(r.employee_user_id), r.work_mode || null);
    });

    // A shift can contain several breaks. Fetch their persistent records in
    // one query and attach them to the matching clock-log row.
    await ensureAttendanceBreakTable();
    const recordIds = records.map(function (row) { return row.id; });
    const [breakRows] = recordIds.length
      ? await db.query(
          "SELECT attendance_id, id, started_at, ended_at, duration_minutes, allowed_minutes, overdue_minutes, employee_reason, alert_created_at, reviewed_at, status FROM attendance_breaks WHERE attendance_id IN (?) ORDER BY attendance_id, started_at, id",
          [recordIds]
        )
      : [[]];
    const breaksByAttendanceId = new Map();
    breakRows.forEach(function (breakRow) {
      const key = Number(breakRow.attendance_id);
      if (!breaksByAttendanceId.has(key)) breaksByAttendanceId.set(key, []);
      breaksByAttendanceId.get(key).push({
        id: breakRow.id,
        startAt: sqlDateTime(breakRow.started_at),
        endAt: sqlDateTime(breakRow.ended_at),
        start: policy.formatDisplayTime(sqlDateTime(breakRow.started_at)),
        end: policy.formatDisplayTime(sqlDateTime(breakRow.ended_at)),
        durationMinutes: Number(breakRow.duration_minutes || 0),
        allowedMinutes: Number(breakRow.allowed_minutes || 60),
        overdueMinutes: Number(breakRow.overdue_minutes || 0),
        employeeReason: breakRow.employee_reason || null,
        alertCreatedAt: sqlDateTime(breakRow.alert_created_at),
        reviewedAt: sqlDateTime(breakRow.reviewed_at),
        status: breakRow.status
      });
    });

    const items = records
      .filter(function (row) { return row.check_in_at; })
      .map(function (row) {
        const person = scopedEmployees.find(function (p) { return p.id === row.employee_id; });
        const item = serializeRecord(row, person);
        const breaks = breaksByAttendanceId.get(Number(row.id)) || [];
        const completed = breaks.filter(function (entry) { return entry.endAt; });
        item.breakStart = breaks.length ? breaks[0].start : '-';
        item.breakEnd = completed.length ? completed[completed.length - 1].end : '-';
        item.breaks = breaks;
        item.breakMinutes = breaks.reduce(function (total, entry) {
          if (entry.endAt) return total + Number(entry.durationMinutes || 0);
          return total + Math.max(0, policy.minutesBetween(entry.startAt, policy.nowIstDateTime()));
        }, 0);
        // An active shift has no final stored duration yet. Calculate its
        // current duration on every request so Clock Logs stays live without
        // modifying historical, completed attendance records.
        if (!row.check_out_at && sqlDate(row.attendance_date) === policy.todayIstDate()) {
          const now = policy.nowIstDateTime();
          const breakMinutesSoFar = breaks.reduce(function (total, entry) {
            if (entry.endAt) return total + Number(entry.durationMinutes || 0);
            return total + Math.max(0, policy.minutesBetween(entry.startAt, now));
          }, 0);
          item.workingMinutes = Math.max(0,
            policy.minutesBetween(sqlDateTime(row.check_in_at), now) - breakMinutesSoFar);
        }
        item.profileId = profileIdByUserId.get(Number(row.employee_id)) || null;
        item.workMode = row.work_mode_snapshot || workModeByUserId.get(Number(row.employee_id)) || 'Not set';
        return item;
      });

    return ok(res, {
      view: view,
      start: start,
      end: end,
      employees: scopedEmployees.map(function (person) {
        return {
          id: person.id,
          employeeId: person.id,
          employeeName: person.full_name,
          staffId: person.staff_id,
          role: person.role
        };
      }),
      items: items
    });
  } catch (error) {
    console.error('GET /attendance/clock-logs', error);
    return fail(res, 500, error.message);
  }
}

async function myHistory(req, res) {
  try {
    const month = parseMonthParam(req.query.month);
    if (!month) return fail(res, 400, 'month must be YYYY-MM');
    const employeeId = req.user.id;
    const start = month + '-01';

    const [rows] = await db.query(
      'SELECT * FROM attendance_records WHERE employee_id = ? AND attendance_date >= ? AND attendance_date < DATE_ADD(?, INTERVAL 1 MONTH) ORDER BY attendance_date DESC',
      [employeeId, start, start]
    );

    let present = 0;
    let absentCount = 0;
    let late = 0;
    let earlyExit = 0;

    const calendarData = {};
    const records = rows.map(function (row) {
      const item = serializeRecord(row);
      if (item.status === 'Present') present += 1;
      if (item.status === 'Absent') absentCount += 1;
      if (item.status === 'Late') late += 1;
      if (item.status === 'Early Exit') earlyExit += 1;

      calendarData[item.date] = {
        status: item.status,
        checkIn: item.checkIn,
        checkOut: item.checkOut,
        isLate: item.isLate,
        workingMinutes: item.workingMinutes
      };

      return item;
    });

    const [permissions] = await db.query(
      'SELECT * FROM attendance_permission_requests WHERE employee_id = ? AND request_date >= ? AND request_date < DATE_ADD(?, INTERVAL 1 MONTH) ORDER BY created_at DESC',
      [employeeId, start, start]
    );

    return ok(res, {
      month: month,
      summary: { present: present, absent: absentCount, late: late, earlyExit: earlyExit },
      calendarData: calendarData,
      records: records,
      requests: permissions.map(function (row) {
        return {
          id: row.id,
          type: String(row.request_type).replace(/_/g, ' '),
          date: row.request_date,
          reason: row.reason,
          status: capitalize(row.status)
        };
      })
    });
  } catch (error) {
    console.error('GET /attendance/me', error);
    return fail(res, 500, error.message);
  }
}

async function employeeDashboard(req, res) {
  try {
    await ensureAttendanceBreakTable();
    await ensureAttendanceSafetyTables();
    const employeeId = req.user.id;
    const date = policy.todayIstDate();
    const month = parseMonthParam(req.query.month);
    if (!month) return fail(res, 400, 'month must be YYYY-MM');
    const schedule = await calendarSchedule(month);

    const people = await staff.listActiveStaff(db);
    const person = people.find(function (item) {
      return String(item.id) === String(employeeId);
    });
    if (!person) return fail(res, 403, 'Employee account is not active');

    const record = await getRecord(employeeId, date);
    const [[profile]] = await db.query('SELECT work_mode FROM hrms_employee_profiles WHERE employee_user_id = ? LIMIT 1', [employeeId]);
    const currentWorkMode = (profile && profile.work_mode) || 'Not set';
    const checkedIn = Boolean(record && record.check_in_at && !record.check_out_at);
    const checkedOut = Boolean(record && record.check_out_at);
    let hasPendingCorrection = false;
    if (checkedOut && record) {
      const [[pendingCorrection]] = await db.query("SELECT id FROM hrms_attendance_correction_requests WHERE attendance_id = ? AND request_type = 'checkout_correction' AND status = 'pending' LIMIT 1", [record.id]);
      hasPendingCorrection = Boolean(pendingCorrection);
    }
    let activeBreak = null;
    if (checkedIn) {
      const [breaks] = await db.query("SELECT id, started_at FROM attendance_breaks WHERE attendance_id = ? AND status = 'active' ORDER BY id DESC LIMIT 1", [record.id]);
      activeBreak = breaks[0] || null;
    }

    const [monthRows] = await db.query(
      `SELECT id, employee_id, attendance_date, check_in_at, check_out_at, is_late, attendance_status, work_mode_snapshot
       FROM attendance_records
       WHERE employee_id = ?
         AND attendance_date >= ?
         AND attendance_date <= LAST_DAY(?)
       ORDER BY attendance_date ASC`,
      [employeeId, month + '-01', month + '-01']
    );

    // Calendar is the source of truth for whether a date is eligible for
    // attendance.  A previous automatic absence can remain in the audit trail
    // after an admin changes that date back to Weekly Off/Holiday, but it must
    // not be displayed or counted as an absence in either portal.
    const displayRows = monthRows.filter(function (row) {
      const rowDate = sqlDate(row.attendance_date);
      const day = Number(String(rowDate).slice(-2));
      return !schedule.statusFor(day);
    });

    const presentDays = displayRows.filter(function (row) {
      return Boolean(row.check_in_at) && String(row.attendance_status) !== 'absent';
    }).length;

    const lateDays = displayRows.filter(function (row) {
      return Boolean(Number(row.is_late)) && String(row.attendance_status) !== 'absent';
    }).length;

    const absentDays = displayRows.filter(function (row) {
      return String(row.attendance_status) === 'absent';
    }).length;

    const timeSettings = await policy.getTimeSettings(db);
    const breakPolicy = {
      break_calculation_mode: 'actual_break',
      fixed_break_minutes: Number(timeSettings.breakMinutes || 60),
      max_break_minutes: Number(timeSettings.breakMinutes || 60),
    };
    const dailyTargetMinutes = shiftDurationMinutes(timeSettings.shiftStart, timeSettings.shiftEnd);
    const monthlyWorkingDays = schedule.workingDays;
    const targetMinutes = dailyTargetMinutes * monthlyWorkingDays;
    const completedMinutes = await Promise.all(displayRows.map(persistedWorkedMinutes));
    let actualMinutes = completedMinutes.reduce(function (sum, minutes) {
      return sum + minutes;
    }, 0);

    // Fetch breaks for all attendance records in this month in one query.
    const attendanceIds = displayRows.map(function (row) { return row.id; }).filter(Boolean);
    const breaksByAttendance = {};
    if (attendanceIds.length) {
      const [breakRows] = await db.query(
        "SELECT id, attendance_id, started_at, ended_at, allowed_minutes, duration_minutes, overdue_minutes, status FROM attendance_breaks WHERE attendance_id IN (?) ORDER BY id ASC",
        [attendanceIds]
      );
      breakRows.forEach(function (brk) {
        const aid = Number(brk.attendance_id);
        if (!breaksByAttendance[aid]) breaksByAttendance[aid] = [];
        breaksByAttendance[aid].push(brk);
      });
    }

    // Keep a date-keyed representation as well as the list. Older employee
    // clients use the keyed form, while newer ones use month_records.
    const calendarData = {};
    for (let day = 1; day <= schedule.days; day += 1) {
      const status = schedule.statusFor(day);
      if (status) {
        const workDate = month + '-' + String(day).padStart(2, '0');
        calendarData[workDate] = { work_date: workDate, attendance_status: status };
      }
    }
    const monthRecords = displayRows.map(function (row) {
      const rowBreaks = breaksByAttendance[row.id] || [];
      const firstBreak = rowBreaks[0] || null;
      const item = {
        id: row.id,
        work_date: sqlDate(row.attendance_date),
        clock_in_at: row.check_in_at ? sqlDateTime(row.check_in_at) : null,
        clock_out_at: row.check_out_at ? sqlDateTime(row.check_out_at) : null,
        is_late: Boolean(Number(row.is_late)),
        attendance_status: row.attendance_status || (row.check_in_at ? 'present' : 'absent'),
        break_in_at: firstBreak ? sqlDateTime(firstBreak.started_at) : null,
        break_out_at: firstBreak && firstBreak.ended_at ? sqlDateTime(firstBreak.ended_at) : null,
        break_overdue_minutes: firstBreak ? Number(firstBreak.overdue_minutes || 0) : 0,
        break_minutes: rowBreaks.reduce(function (total, brk) {
          if (brk.ended_at) return total + Number(brk.duration_minutes || 0);
          return total + Math.max(0, policy.minutesBetween(sqlDateTime(brk.started_at), policy.nowIstDateTime()));
        }, 0),
        work_mode: row.work_mode_snapshot || currentWorkMode,
      };
      calendarData[item.work_date] = item;
      return item;
    });

    let workedSeconds = Number(record && record.working_minutes || 0) * 60;
    let breakSeconds = record ? (await breakMinutes(record.id)) * 60 : 0;
    if (checkedIn) {
      const completedBreakMinutes = await breakMinutes(record.id);
      const activeBreakMinutes = activeBreak
        ? policy.minutesBetween(sqlDateTime(activeBreak.started_at), policy.nowIstDateTime())
        : 0;
      const liveMinutes = Math.max(0,
        policy.minutesBetween(sqlDateTime(record.check_in_at), policy.nowIstDateTime()) - completedBreakMinutes - activeBreakMinutes);
      workedSeconds = liveMinutes * 60;
      breakSeconds = (completedBreakMinutes + activeBreakMinutes) * 60;
      if (month === date.slice(0, 7)) actualMinutes += liveMinutes;
    }

    return ok(res, {
      employee: { id: person.id, name: person.full_name, staff_id: person.staff_id },
      date: date,
      status: checkedIn ? 'checked_in' : (checkedOut ? 'checked_out' : 'not_checked_in'),
      session: record && record.check_in_at ? {
        id: record.id,
        work_date: sqlDate(record.attendance_date),
        punch_in: sqlDateTime(record.check_in_at),
        punch_out: sqlDateTime(record.check_out_at),
        clock_in_at: sqlDateTime(record.check_in_at),
        clock_out_at: sqlDateTime(record.check_out_at),
        worked_seconds: workedSeconds,
        break_seconds: breakSeconds,
        work_mode: record.work_mode_snapshot || currentWorkMode,
        is_late: Boolean(Number(record.is_late))
      } : null,
      actions: { can_clock_in: !record || !record.check_in_at, can_clock_out: checkedIn, has_pending_correction: hasPendingCorrection },
      break: activeBreak ? { active: true, id: activeBreak.id, started_at: sqlDateTime(activeBreak.started_at) } : { active: false },
      break_policy: breakPolicy,
      month_overview: {
        month: month,
        present_days: presentDays,
        absent_days: absentDays,
        late_days: lateDays,
        work_time: {
          actual_minutes: actualMinutes,
          target_minutes: targetMinutes,
          daily_target_minutes: dailyTargetMinutes,
          working_days: monthlyWorkingDays,
          overtime_minutes: Math.max(0, actualMinutes - targetMinutes),
          remaining_minutes: Math.max(0, targetMinutes - actualMinutes),
          shift_start: timeSettings.shiftStart,
          shift_end: timeSettings.shiftEnd,
          is_live: checkedIn && month === date.slice(0, 7)
        }
      },
      month_records: monthRecords,
      calendarData: calendarData
    });
  } catch (error) {
    console.error('GET /attendance/dashboard (employee)', error);
    return fail(res, 500, error.message);
  }
}

async function checkInPolicy(req, res) {
  try {
    const rules = await locationPolicy.getCheckInPolicy(db, req.user && req.user.id);
    return ok(res, {
      workMode: rules.workMode,
      requiresLocation: rules.requiresLocation,
      radiusMeters: rules.radiusMeters
    });
  } catch (error) {
    if (error instanceof locationPolicy.LocationPolicyError) return fail(res, error.status, error.message);
    console.error('GET /attendance/check-in-policy', error);
    return fail(res, 500, 'Unable to load Clock In location policy. Please try again.');
  }
}

async function checkIn(req, res) {
  let connection;
  try {
    await ensureAttendanceSafetyTables();
    if (!req.user || !req.user.id) return fail(res, 401, 'Unauthorized');
    const employeeId = req.user.id;
    const date = policy.todayIstDate();
    const at = policy.nowIstDateTime();
    const method = normalizeMethod((req.body && (req.body.method || req.body.check_in_method)));
    const late = policy.isLateCheckIn(at);
    const absent = policy.isAbsentCheckIn(at);
    connection = await db.getConnection();
    await connection.beginTransaction();
    const rules = await locationPolicy.getCheckInPolicy(connection, employeeId, true);
    locationPolicy.validateCheckIn(rules, req.body || {});
    const existing = await getRecord(employeeId, date, connection, true);
    if (existing && existing.check_in_at) {
      throw new locationPolicy.LocationPolicyError(409, 'Already checked in today');
    }

    // If employee checks in after the absent threshold they are still attending —
    // record 'late' (not 'absent') since they physically showed up.
    const status = (absent || late) ? 'late' : 'present';
    if (existing) {
      await connection.query(
        "UPDATE attendance_records SET check_in_at = ?, check_in_method = ?, is_late = ?, attendance_status = ?, session_status = 'active', work_mode_snapshot = ? WHERE id = ?",
        [at, method, late ? 1 : 0, status, rules.workMode, existing.id]
      );
    } else {
      await connection.query(
        "INSERT INTO attendance_records (employee_id, attendance_date, check_in_at, check_in_method, is_late, attendance_status, session_status, work_mode_snapshot) VALUES (?, ?, ?, ?, ?, ?, 'active', ?)",
        [employeeId, date, at, method, late ? 1 : 0, status, rules.workMode]
      );
    }

    if (rules.requiresLocation) {
      await connection.query(
        `INSERT INTO hrms_employee_location_status (employee_user_id, status)
         VALUES (?, ?)
         ON DUPLICATE KEY UPDATE status = VALUES(status), updated_at = CURRENT_TIMESTAMP`,
        [employeeId, rules.workMode.toLowerCase()]
      );
    }

    // Store check-in location as a tracking ping so it appears on the live map
    const ciLat = Number(req.body && req.body.latitude);
    const ciLng = Number(req.body && req.body.longitude);
    const ciAcc = req.body && req.body.accuracy != null ? Number(req.body.accuracy) : null;
    if (Number.isFinite(ciLat) && Number.isFinite(ciLng)) {
      await connection.query(
        `INSERT INTO hrms_location_pings (employee_user_id, latitude, longitude, accuracy_meters)
         VALUES (?, ?, ?, ?)`,
        [employeeId, ciLat, ciLng, ciAcc]
      );
    }

    const record = await getRecord(employeeId, date, connection);
    await connection.commit();
    return ok(res, serializeRecord(record), 'Checked in');
  } catch (error) {
    if (connection) await connection.rollback();
    if (error instanceof locationPolicy.LocationPolicyError) return fail(res, error.status, error.message);
    console.error('POST /attendance/check-in', error);
    return fail(res, 500, 'Unable to save Clock In. Please try again.');
  } finally {
    if (connection) connection.release();
  }
}

async function checkOut(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const employeeId = req.user.id;
    const date = policy.todayIstDate();
    const at = policy.nowIstDateTime();
    const record = await getRecord(employeeId, date);
    if (!record || !record.check_in_at) return fail(res, 409, 'Check in before checking out');
    if (record.check_out_at) return fail(res, 409, 'Already checked out today');

    const breaks = await breakMinutes(record.id);
    const rawMinutes = policy.minutesBetween(sqlDateTime(record.check_in_at), at);
    const workingMinutes = Math.max(0, rawMinutes - breaks);
    const status = computeStatus({
      check_in_at: record.check_in_at,
      check_out_at: at,
      working_minutes: rawMinutes,
      is_late: record.is_late,
      attendance_status: record.attendance_status
    });

    await db.query(
      "UPDATE attendance_records SET check_out_at = ?, working_minutes = ?, attendance_status = ?, session_status = 'completed' WHERE id = ?",
      [at, workingMinutes, status, record.id]
    );
    await db.query(
      "INSERT INTO hrms_attendance_checkout_audit (attendance_id, employee_id, event_type, checkout_at, latitude, longitude, accuracy_meters, reason) VALUES (?, ?, 'manual_checkout', ?, ?, ?, ?, ?)",
      [record.id, employeeId, at, Number(req.body && req.body.latitude) || null, Number(req.body && req.body.longitude) || null, Number(req.body && req.body.accuracy) || null, 'Employee manual checkout']
    );

    await db.query(
      `UPDATE hrms_field_tracking_sessions
       SET is_active = 0,
           stopped_at = ?
       WHERE employee_user_id = ?
         AND is_active = 1`,
      [at, employeeId]
    );

    const updated = await getRecord(employeeId, date);
    return ok(res, {
      ...serializeRecord(updated),
      completed_break_minutes: breaks,
    }, 'Checked out');
  } catch (error) {
    console.error('POST /attendance/check-out', error);
    return fail(res, 500, error.message);
  }
}

async function startBreak(req, res) {
  try {
    await ensureAttendanceBreakTable();
    const record = await getRecord(req.user.id, policy.todayIstDate());
    if (!record || !record.check_in_at || record.check_out_at) return fail(res, 409, 'Check in before starting a break');
    const [existingBreaks] = await db.query("SELECT id, status FROM attendance_breaks WHERE attendance_id = ? ORDER BY id DESC LIMIT 1", [record.id]);
    if (existingBreaks.length) {
      return fail(res, 409, existingBreaks[0].status === 'active'
        ? 'A break is already active'
        : 'Your break has already been used for this shift');
    }
    const settings = await policy.getTimeSettings(db);
    const allowed = Number(settings.breakMinutes || 60);
    if (allowed < 1) return fail(res, 409, 'Breaks are not enabled for this shift');
    const at = policy.nowIstDateTime();
    const [result] = await db.query("INSERT INTO attendance_breaks (attendance_id, started_at, allowed_minutes, status) VALUES (?, ?, ?, 'active')", [record.id, at, allowed]);
    return ok(res, { id: result.insertId, attendance_id: record.id, started_at: at, allowed_minutes: allowed, status: 'active' }, 'Break started');
  } catch (error) {
    console.error('POST /attendance/break-in', error);
    return fail(res, 500, error.message);
  }
}

async function endBreak(req, res) {
  try {
    await ensureAttendanceBreakTable();
    const record = await getRecord(req.user.id, policy.todayIstDate());
    if (!record || !record.check_in_at || record.check_out_at) return fail(res, 409, 'There is no active work session');
    const locationRules = await locationPolicy.getCheckInPolicy(db, req.user.id, true);
    const fix = locationPolicy.validateCheckIn(locationRules, req.body || {});
    const [rows] = await db.query("SELECT id, started_at, allowed_minutes FROM attendance_breaks WHERE attendance_id = ? AND status = 'active' ORDER BY id DESC LIMIT 1", [record.id]);
    if (!rows.length) return fail(res, 409, 'There is no active break');
    const at = policy.nowIstDateTime();
    const duration = policy.minutesBetween(sqlDateTime(rows[0].started_at), at);
    const overdue = Math.max(0, duration - Number(rows[0].allowed_minutes || 60));
    const timeSettings = await policy.getTimeSettings(db);
    const graceMinutes = Number(timeSettings.breakGraceMinutes ?? 5);
    const reason = String(req.body && req.body.reason || '').trim().slice(0, 500);
    if (overdue > graceMinutes && !reason) return fail(res, 400, 'A reason is required after the extended-break grace period');
    const needsAlert = overdue > graceMinutes;
    const alertAt = needsAlert ? at : null;
    await db.query("UPDATE attendance_breaks SET ended_at=?, duration_minutes=?, overdue_minutes=?, employee_reason=?, alert_created_at=?, return_latitude=?, return_longitude=?, return_accuracy_meters=?, status='completed' WHERE id=?", [at,duration,overdue,reason||null,alertAt,fix&&fix.latitude,fix&&fix.longitude,fix&&fix.accuracy,rows[0].id]);
    if (needsAlert) {
      await ensureAttendanceSafetyTables();
      await db.query("INSERT INTO hrms_attendance_break_alerts (attendance_break_id, employee_id, overdue_minutes, status, reason) VALUES (?, ?, ?, 'open', ?) ON DUPLICATE KEY UPDATE overdue_minutes=VALUES(overdue_minutes), reason=VALUES(reason)", [rows[0].id, req.user.id, overdue, reason||null]);
    }
    return ok(res, { id: rows[0].id, attendance_id: record.id, started_at: sqlDateTime(rows[0].started_at), ended_at: at, duration_minutes: duration, overdue_minutes: overdue, employee_reason: reason || null, status: 'completed' }, overdue > 0 ? 'Extended break recorded for admin review' : 'Break ended');
  } catch (error) {
    console.error('POST /attendance/break-out', error);
    return fail(res, 500, error.message);
  }
}

async function undoCheckout(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const record = await getRecord(req.user.id, policy.todayIstDate());
    if (!record || !record.check_out_at) return fail(res, 409, 'There is no checkout to undo');
    if (policy.minutesBetween(sqlDateTime(record.check_out_at), policy.nowIstDateTime()) > 10) return fail(res, 409, 'The undo window has expired. Submit a checkout correction request.');
    const locationRules = await locationPolicy.getCheckInPolicy(db, req.user.id, true);
    locationPolicy.validateCheckIn(locationRules, req.body || {});
    await db.query("UPDATE attendance_records SET check_out_at = NULL, working_minutes = 0, session_status = 'active' WHERE id = ?", [record.id]);
    await db.query("INSERT INTO hrms_attendance_checkout_audit (attendance_id, employee_id, event_type, checkout_at, latitude, longitude, accuracy_meters, reason) VALUES (?, ?, 'undo_checkout', ?, ?, ?, ?, ?)", [record.id, req.user.id, record.check_out_at, Number(req.body.latitude) || null, Number(req.body.longitude) || null, Number(req.body.accuracy) || null, 'Employee undo within grace window']);
    return ok(res, { attendance_id: record.id }, 'Checkout undone. Your shift is active again.');
  } catch (error) { return fail(res, error.status || 500, error.message); }
}

async function requestCheckoutCorrection(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const record = await getRecord(req.user.id, policy.todayIstDate());
    const reason = String(req.body && req.body.reason || '').trim();
    if (!record || !record.check_out_at) return fail(res, 409, 'A completed checkout is required');
    if (!reason) return fail(res, 400, 'Provide a correction reason');
    const [[existing]] = await db.query("SELECT id FROM hrms_attendance_correction_requests WHERE attendance_id = ? AND request_type = 'checkout_correction' AND status = 'pending' LIMIT 1", [record.id]);
    if (existing) return fail(res, 409, 'A correction request is already pending. Wait for admin to review it before submitting another.');
    const [result] = await db.query("INSERT INTO hrms_attendance_correction_requests (attendance_id, employee_id, request_type, reason) VALUES (?, ?, 'checkout_correction', ?)", [record.id, req.user.id, reason.slice(0, 500)]);
    return ok(res, { id: result.insertId }, 'Correction request sent to Admin.');
  } catch (error) { return fail(res, 500, error.message); }
}

function correctionTime(date, time) {
  const value = String(time || '').trim();
  if (!/^\d{2}:\d{2}$/.test(value)) return null;
  return `${date} ${value}:00`;
}

async function requestAttendanceCorrection(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const date = String(req.body?.attendanceDate || '');
    const requestType = String(req.body?.requestType || '');
    const reason = String(req.body?.reason || '').trim().slice(0, 500);
    const today = policy.todayIstDate();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || date >= today) return fail(res, 400, 'Choose a past attendance date');
    if (policy.minutesBetween(`${date} 00:00:00`, `${today} 00:00:00`) > 7 * 24 * 60) return fail(res, 400, 'Corrections are allowed within 7 days');
    if (!['missed_check_in', 'missed_check_out', 'incorrect_time', 'automatic_absence'].includes(requestType)) return fail(res, 400, 'Choose a valid correction type');
    if (!reason) return fail(res, 400, 'Provide a correction reason');
    if (!await isWorkingDay(date)) return fail(res, 400, 'Corrections are available only for working days');
    const requestedCheckIn = correctionTime(date, req.body?.checkInTime);
    const requestedCheckOut = correctionTime(date, req.body?.checkOutTime);
    if ((requestType === 'missed_check_in' || requestType === 'automatic_absence') && !requestedCheckIn) return fail(res, 400, 'Provide the corrected check-in time');
    if (requestType === 'missed_check_out' && !requestedCheckOut) return fail(res, 400, 'Provide the corrected check-out time');
    let record = await getRecord(req.user.id, date);
    if (!record) {
      const [result] = await db.query(`INSERT INTO attendance_records
        (employee_id, attendance_date, attendance_status, session_status) VALUES (?, ?, 'absent', 'closed')`, [req.user.id, date]);
      record = { id: result.insertId };
    }
    const [[existing]] = await db.query(`SELECT id FROM hrms_attendance_correction_requests
      WHERE attendance_id=? AND status='pending' LIMIT 1`, [record.id]);
    if (existing) return fail(res, 409, 'A correction request is already pending for this date');
    const [result] = await db.query(`INSERT INTO hrms_attendance_correction_requests
      (attendance_id, employee_id, request_type, reason, requested_check_in_at, requested_check_out_at)
      VALUES (?, ?, ?, ?, ?, ?)`, [record.id, req.user.id, requestType, reason, requestedCheckIn, requestedCheckOut]);
    return ok(res, { id: result.insertId }, 'Attendance correction request sent to Admin.');
  } catch (error) { return fail(res, 500, error.message); }
}

async function heartbeat(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const employeeId = req.user.id;
    const record = await getRecord(employeeId, policy.todayIstDate());
    if (!record || !record.check_in_at || record.check_out_at) {
      return fail(res, 409, 'There is no active work session.');
    }
    const completedBreakMinutes = await breakMinutes(record.id);
    const [activeBreaks] = await db.query("SELECT started_at FROM attendance_breaks WHERE attendance_id = ? AND status = 'active' ORDER BY id DESC LIMIT 1", [record.id]);
    const activeBreakMinutes = activeBreaks[0]
      ? policy.minutesBetween(sqlDateTime(activeBreaks[0].started_at), policy.nowIstDateTime())
      : 0;
    const nowForWork = policy.nowIstDateTime();
    const rawMinutes = policy.minutesBetween(sqlDateTime(record.check_in_at), nowForWork);
    const workingMinutes = Math.max(0, rawMinutes - completedBreakMinutes - activeBreakMinutes);
    await db.query(
      "UPDATE attendance_records SET working_minutes = ? WHERE id = ? AND check_out_at IS NULL",
      [workingMinutes, record.id]
    );
    const latitude = Number(req.body && req.body.latitude);
    const longitude = Number(req.body && req.body.longitude);
    const accuracy = req.body && req.body.accuracy != null ? Number(req.body.accuracy) : null;
    let radiusState = 'not_evaluated';
    if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
      // Store every heartbeat location as a tracking ping for live map visibility
      await db.query(
        `INSERT INTO hrms_location_pings (employee_user_id, latitude, longitude, accuracy_meters)
         VALUES (?, ?, ?, ?)`,
        [employeeId, latitude, longitude, accuracy]
      ).catch(function (e) { console.error('Heartbeat ping insert failed', e.message); });
      const [[profile]] = await db.query('SELECT work_mode FROM hrms_employee_profiles WHERE employee_user_id = ?', [employeeId]);
      const mode = profile && profile.work_mode;
      const [hybridRows] = mode === 'Hybrid' ? await db.query('SELECT id FROM hrms_field_tracking_sessions WHERE employee_user_id=? AND is_active=1 LIMIT 1', [employeeId]) : [[]];
      const activeHybrid = hybridRows[0];
      if (activeHybrid) {
        // Starting Hybrid tracking during the grace period means the employee
        // is now legitimately working away from the Office.
        await db.query("UPDATE hrms_attendance_radius_departures SET status='cancelled', last_seen_at=? WHERE attendance_id=? AND status='pending'", [policy.nowIstDateTime(), record.id]);
        radiusState = 'hybrid_tracking_active';
      }
      if ((mode === 'Office' || mode === 'Home' || mode === 'Hybrid') && !activeHybrid) {
        const rules = mode === 'Hybrid' ? await locationPolicy.settingsFor(db) : await locationPolicy.getCheckInPolicy(db, employeeId);
        const center = mode === 'Hybrid' ? locationPolicy.coordinates(rules.office_latitude, rules.office_longitude) : rules.center;
        const radius = Number(mode === 'Hybrid'
          ? rules.officeRadiusMeters
          : rules.radiusMeters);
        const distance = locationPolicy.distanceMeters(center, { latitude, longitude });
        if (distance <= radius) {
          await db.query("UPDATE hrms_attendance_radius_departures SET status='cancelled', last_seen_at=? WHERE attendance_id=? AND status='pending'", [policy.nowIstDateTime(), record.id]);
          radiusState = 'inside_radius';
        } else {
          const now = policy.nowIstDateTime();
          await db.query(`INSERT INTO hrms_attendance_radius_departures (attendance_id,employee_id,location_type,left_at,last_seen_at,latitude,longitude,distance_meters) VALUES (?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE left_at=IF(status='cancelled',VALUES(left_at),left_at),last_seen_at=VALUES(last_seen_at),latitude=VALUES(latitude),longitude=VALUES(longitude),distance_meters=VALUES(distance_meters),status=IF(status='cancelled','pending',status)`, [record.id, employeeId, mode, now, now, latitude, longitude, distance]);
          const [[departure]] = await db.query('SELECT left_at FROM hrms_attendance_radius_departures WHERE attendance_id=? AND status=?', [record.id, 'pending']);
          const [[tracking]] = await db.query(
            'SELECT office_outside_radius_grace_minutes, home_outside_radius_grace_minutes FROM hrms_tracking_settings WHERE id=1'
          );
          const grace = Number(mode === 'Home'
            ? tracking && tracking.home_outside_radius_grace_minutes
            : tracking && tracking.office_outside_radius_grace_minutes);
          if (departure && policy.minutesBetween(sqlDateTime(departure.left_at), now) >= grace) {
            const status = computeStatus({
              check_in_at: record.check_in_at,
              check_out_at: now,
              working_minutes: rawMinutes,
              is_late: record.is_late,
              attendance_status: record.attendance_status,
            });
            await db.query("UPDATE attendance_records SET check_out_at=?, working_minutes=?, attendance_status=?, session_status='completed' WHERE id=? AND check_out_at IS NULL", [now, workingMinutes, status, record.id]);
            await db.query("UPDATE hrms_attendance_radius_departures SET status='auto_checked_out' WHERE attendance_id=?", [record.id]);
            await db.query("UPDATE hrms_field_tracking_sessions SET is_active=0, stopped_at=? WHERE employee_user_id=? AND is_active=1", [now, employeeId]);
            await db.query("INSERT INTO hrms_attendance_checkout_audit (attendance_id, employee_id, event_type, checkout_at, latitude, longitude, accuracy_meters, reason) VALUES (?, ?, 'outside_radius_auto_checkout', ?, ?, ?, ?, ?)", [record.id, employeeId, now, latitude, longitude, Number(req.body && req.body.accuracy) || null, `${mode} employee remained outside the approved radius for ${grace} minutes`]);
            radiusState = 'auto_checked_out';
          } else radiusState = 'outside_radius_grace';
        }
      }
    }
    return ok(res, { attendance_id: record.id, working_minutes: workingMinutes, radius_state: radiusState });
  } catch (error) {
    console.error('POST /attendance/heartbeat', error);
    return fail(res, 500, 'Unable to save current work time.');
  }
}

async function myPermissions(req, res) {
  try {
    const [rows] = await db.query(
      'SELECT * FROM attendance_permission_requests WHERE employee_id = ? ORDER BY created_at DESC LIMIT 50',
      [req.user.id]
    );
    return ok(res, rows.map(function (row) {
      return {
        id: row.id,
        type: String(row.request_type).replace(/_/g, ' '),
        date: row.request_date,
        start_time: row.permission_start_time || null,
        end_time: row.permission_end_time || null,
        reason: row.reason,
        status: capitalize(row.status)
      };
    }));
  } catch (error) {
    console.error('GET /attendance/permissions/mine', error);
    return fail(res, 500, error.message);
  }
}

async function ensurePermissionTimeColumns() {
  const [startColumns] = await db.query("SHOW COLUMNS FROM attendance_permission_requests LIKE 'permission_start_time'");
  if (!startColumns.length) {
    await db.query('ALTER TABLE attendance_permission_requests ADD COLUMN permission_start_time TIME NULL AFTER request_date');
  }
  const [endColumns] = await db.query("SHOW COLUMNS FROM attendance_permission_requests LIKE 'permission_end_time'");
  if (!endColumns.length) {
    await db.query('ALTER TABLE attendance_permission_requests ADD COLUMN permission_end_time TIME NULL AFTER permission_start_time');
  }
}

async function createPermission(req, res) {
  try {
    const type = String((req.body && (req.body.type || req.body.request_type)) || '').toLowerCase().replace(/\s+/g, '_');
    const allowed = { leave: 1, late_entry: 1, early_exit: 1, risk_leave: 1, permission: 1, wfh: 1 };
    if (!allowed[type]) return fail(res, 400, 'type must be leave, late_entry, early_exit, risk_leave, permission, or wfh');
    const date = parseDateParam(req.body && (req.body.date || req.body.request_date));
    if (!date) return fail(res, 400, 'date must be YYYY-MM-DD');
    const reason = String((req.body && req.body.reason) || '').trim();
    const startTime = String((req.body && req.body.start_time) || '').trim();
    const endTime = String((req.body && req.body.end_time) || '').trim();
    if (type === 'permission' && (!/^\d{2}:\d{2}$/.test(startTime) || !/^\d{2}:\d{2}$/.test(endTime) || startTime >= endTime)) {
      return fail(res, 400, 'Permission start and end times are required, and the end time must be later');
    }

    await ensurePermissionTimeColumns();

    const [result] = await db.query(
      "INSERT INTO attendance_permission_requests (employee_id, request_type, request_date, permission_start_time, permission_end_time, reason, status) VALUES (?, ?, ?, ?, ?, ?, 'pending')",
      [req.user.id, type, date, type === 'permission' ? startTime + ':00' : null, type === 'permission' ? endTime + ':00' : null, reason || null]
    );
    return ok(res, { id: result.insertId, type: type, date: date, start_time: startTime || null, end_time: endTime || null, reason: reason, status: 'Pending' }, 'Request submitted');
  } catch (error) {
    console.error('POST /attendance/permissions', error);
    return fail(res, 500, error.message);
  }
}

async function adminPermissions(req, res) {
  try {
    const status = String(req.query.status || '').toLowerCase();
    const params = [];
    let where = '1=1';
    if (status && status !== 'all') {
      where += ' AND p.status = ?';
      params.push(status);
    }
    const [rows] = await db.query(
      'SELECT p.*, s.' + staff.quote(staff.STAFF.name) + ' AS full_name FROM attendance_permission_requests p JOIN ' +
      staff.staffFrom() + ' s ON s.' + staff.quote(staff.STAFF.id) + ' = p.employee_id WHERE ' + where +
      ' ORDER BY p.created_at DESC LIMIT 100',
      params
    );
    return ok(res, rows.map(function (row) {
      return {
        id: row.id,
        employee: row.full_name,
        type: String(row.request_type).replace(/_/g, ' '),
        date: row.request_date,
        reason: row.reason,
        status: capitalize(row.status)
      };
    }));
  } catch (error) {
    console.error('GET /attendance/permissions', error);
    return fail(res, 500, error.message);
  }
}

async function reviewPermission(req, res) {
  try {
    const id = Number(req.params.id);
    const status = String((req.body && req.body.status) || '').toLowerCase();
    if (status !== 'approved' && status !== 'rejected') return fail(res, 400, 'status must be approved or rejected');
    const at = policy.nowIstDateTime();
    const [result] = await db.query(
      "UPDATE attendance_permission_requests SET status = ?, reviewed_by = ?, reviewed_at = ? WHERE id = ? AND status = 'pending'",
      [status, req.user.id, at, id]
    );
    if (!result.affectedRows) return fail(res, 404, 'Pending request not found');
    return ok(res, { id: id, status: capitalize(status) }, 'Request updated');
  } catch (error) {
    console.error('PATCH /attendance/permissions/:id', error);
    return fail(res, 500, error.message);
  }
}

async function exportCsv(req, res) {
  try {
    const date = parseDateParam(req.query.date);
    if (!date) return fail(res, 400, 'date must be YYYY-MM-DD');
    const employees = await staff.listActiveStaff(db);
    const [records] = await db.query('SELECT * FROM attendance_records WHERE attendance_date = ?', [date]);
    const byId = new Map(records.map(function (row) { return [row.employee_id, row]; }));
    const lines = ['Employee,Staff ID,Role,Check In,Check Out,Method,Status,Working Minutes'];
    employees.forEach(function (person) {
      const row = byId.get(person.id);
      const item = row ? serializeRecord(row, person) : {
        checkIn: '-', checkOut: '-', method: '', status: 'Absent', workingMinutes: 0
      };
      const cols = [person.full_name, person.staff_id, person.role, item.checkIn, item.checkOut, item.method || '', item.status, item.workingMinutes];
      lines.push(cols.map(function (value) {
        return '"' + String(value == null ? '' : value).replace(/"/g, '""') + '"';
      }).join(','));
    });
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="attendance-' + date + '.csv"');
    return res.send(lines.join('\n'));
  } catch (error) {
    console.error('GET /attendance/export', error);
    return fail(res, 500, error.message);
  }
}

async function myExport(req, res) {
  try {
    const month = parseMonthParam(req.query.month);
    if (!month) return fail(res, 400, 'month must be YYYY-MM');
    const [rows] = await db.query(
      'SELECT * FROM attendance_records WHERE employee_id = ? AND attendance_date >= ? AND attendance_date < DATE_ADD(?, INTERVAL 1 MONTH) ORDER BY attendance_date ASC',
      [req.user.id, month + '-01', month + '-01']
    );
    const lines = ['Date,Check In,Check Out,Status'];
    rows.forEach(function (row) {
      const item = serializeRecord(row);
      lines.push([item.date, item.checkIn, item.checkOut, item.status].join(','));
    });
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="my-attendance-' + month + '.csv"');
    return res.send(lines.join('\n'));
  } catch (error) {
    console.error('GET /attendance/me/export', error);
    return fail(res, 500, error.message);
  }
}

async function reviewBreak(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const breakId = Number(req.params.id);
    const action = String(req.body && req.body.action || '').trim();
    const clarification = String(req.body && req.body.clarification || '').trim().slice(0, 500);
    if (!breakId) return fail(res, 400, 'Break ID is required');
    if (action !== 'reviewed' && action !== 'clarification_requested') return fail(res, 400, 'action must be reviewed or clarification_requested');
    const [[brk]] = await db.query('SELECT b.*, a.status AS alert_status FROM attendance_breaks b LEFT JOIN hrms_attendance_break_alerts a ON a.attendance_break_id = b.id WHERE b.id = ?', [breakId]);
    if (!brk) return fail(res, 404, 'Break not found');
    const now = policy.nowIstDateTime();
    await db.query('UPDATE attendance_breaks SET reviewed_by = ?, reviewed_at = ? WHERE id = ?', [req.user.id, now, breakId]);
    await db.query("INSERT INTO hrms_attendance_break_alerts (attendance_break_id, employee_id, overdue_minutes, status, reason, reviewed_by, reviewed_at) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE status=VALUES(status), reviewed_by=VALUES(reviewed_by), reviewed_at=VALUES(reviewed_at), reason=IF(VALUES(reason) != '', VALUES(reason), reason)", [breakId, brk.employee_id || brk.attendance_id, brk.overdue_minutes || 0, action, clarification || null, req.user.id, now]);
    return ok(res, { break_id: breakId, action, reviewed_by: req.user.id, reviewed_at: now }, action === 'reviewed' ? 'Break marked as reviewed' : 'Clarification requested from employee');
  } catch (error) {
    console.error('PATCH /attendance/breaks/:id/review', error);
    return fail(res, 500, error.message);
  }
}

async function getBreakReview(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const breakId = Number(req.params.id);
    if (!breakId) return fail(res, 400, 'Break ID is required');
    const [[brk]] = await db.query(`SELECT b.id, b.attendance_id, b.started_at, b.ended_at, b.allowed_minutes, b.duration_minutes, b.overdue_minutes, b.employee_reason, b.alert_created_at, b.reviewed_by, b.reviewed_at, b.return_latitude, b.return_longitude, b.return_accuracy_meters, a.status AS alert_status, a.reason AS clarification_message, u.full_name AS reviewer_name FROM attendance_breaks b LEFT JOIN hrms_attendance_break_alerts a ON a.attendance_break_id = b.id LEFT JOIN hrms_employee_profiles u ON u.employee_user_id = b.reviewed_by WHERE b.id = ?`, [breakId]);
    if (!brk) return fail(res, 404, 'Break not found');
    return ok(res, brk);
  } catch (error) {
    return fail(res, 500, error.message);
  }
}

async function listCorrectionRequests(req, res) {
  try {
    await ensureAttendanceSafetyTables();
    const [rows] = await db.query(`
      SELECT r.id, r.attendance_id, r.request_type, r.reason, r.status, r.created_at,
             r.requested_check_in_at, r.requested_check_out_at, r.admin_note,
             e.full_name, e.staff_id,
             a.check_in_at, a.check_out_at
      FROM hrms_attendance_correction_requests r
      JOIN employee_users e ON e.id = r.employee_id
      JOIN attendance_records a ON a.id = r.attendance_id
      ORDER BY r.created_at DESC
    `);
    return ok(res, { items: rows });
  } catch (error) { return fail(res, 500, error.message); }
}

async function approveCorrectionRequest(req, res) {
  try {
    const { id } = req.params;
    const [[req_row]] = await db.query('SELECT * FROM hrms_attendance_correction_requests WHERE id = ?', [id]);
    if (!req_row) return fail(res, 404, 'Correction request not found');
    if (req_row.request_type === 'checkout_correction') {
      await db.query('UPDATE attendance_records SET check_out_at = NULL, working_minutes = 0 WHERE id = ?', [req_row.attendance_id]);
    } else {
      const [records] = await db.query('SELECT check_in_at, check_out_at FROM attendance_records WHERE id=?', [req_row.attendance_id]);
      const record = records[0];
      const checkIn = req_row.requested_check_in_at || record.check_in_at;
      const checkOut = req_row.requested_check_out_at || record.check_out_at;
      // A correction uses the same current admin-configured thresholds as a
      // normal check-in.  The time is retained even when the result is Absent.
      await policy.getTimeSettings(db);
      const status = !checkIn ? 'absent' : policy.isAbsentCheckIn(sqlDateTime(checkIn))
        ? 'absent' : policy.isLateCheckIn(sqlDateTime(checkIn)) ? 'late' : 'present';
      const workingMinutes = checkIn && checkOut
        ? policy.minutesBetween(sqlDateTime(checkIn), sqlDateTime(checkOut)) : 0;
      await db.query(`UPDATE attendance_records SET check_in_at=?, check_out_at=?, attendance_status=?,
        session_status=?, is_late=?, working_minutes=? WHERE id=?`, [
        checkIn, checkOut, status, checkOut ? 'completed' : 'closed', status === 'late' ? 1 : 0,
        workingMinutes, req_row.attendance_id
      ]);
    }
    await db.query('UPDATE hrms_attendance_correction_requests SET status = ?, reviewed_by=?, reviewed_at = NOW() WHERE id = ?', ['approved', req.user.id, id]);
    return ok(res, {}, 'Attendance correction approved.');
  } catch (error) { return fail(res, 500, error.message); }
}

async function rejectCorrectionRequest(req, res) {
  try {
    const { id } = req.params;
    const adminNote = String(req.body?.admin_note || '').trim().slice(0, 300);
    const [[req_row]] = await db.query('SELECT id FROM hrms_attendance_correction_requests WHERE id = ?', [id]);
    if (!req_row) return fail(res, 404, 'Correction request not found');
    await db.query('UPDATE hrms_attendance_correction_requests SET status = ?, admin_note = ?, reviewed_by = ?, reviewed_at = NOW() WHERE id = ?', ['rejected', adminNote || null, req.user.id, id]);
    return ok(res, {}, 'Request rejected.');
  } catch (error) { return fail(res, 500, error.message); }
}

module.exports = {
  requireAdmin: requireAdmin,
  dashboard: dashboard,
  clockLogs: clockLogs,
  employeeDashboard: employeeDashboard,
  myHistory: myHistory,
  checkInPolicy: checkInPolicy,
  checkIn: checkIn,
  checkOut: checkOut,
  startBreak: startBreak,
  endBreak: endBreak,
  reviewBreak: reviewBreak,
  getBreakReview: getBreakReview,
  undoCheckout: undoCheckout,
  requestCheckoutCorrection: requestCheckoutCorrection,
  requestAttendanceCorrection: requestAttendanceCorrection,
  listCorrectionRequests: listCorrectionRequests,
  approveCorrectionRequest: approveCorrectionRequest,
  rejectCorrectionRequest: rejectCorrectionRequest,
  heartbeat: heartbeat,
  myPermissions: myPermissions,
  createPermission: createPermission,
  adminPermissions: adminPermissions,
  reviewPermission: reviewPermission,
  exportCsv: exportCsv,
  myExport: myExport
};
