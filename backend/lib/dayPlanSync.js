// lib/dayPlanSync.js — keep today's Day Planner STATUS in step with real work.
//
// Day Planner rows are per client. Their status is derived from what the
// employee is actually doing on that client (My Tasks + Content Calendar):
//   PROCESSING  something is running now
//   HOLD        something is on hold / sent back for rework (nothing running)
//   COMPLETE    work was completed today and nothing open is left
//   PENDING     work was started/completed today but more is still open
//   NOT START   nothing touched today
const db = require('../config/db');

const pad = (n) => String(n).padStart(2, '0');
const localDay = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

function isOn(value, day) {
  if (!value) return false;
  const d = value instanceof Date ? value : new Date(value);
  return !Number.isNaN(d.getTime()) && localDay(d) === day;
}

function touchedOn(row, day) {
  if (isOn(row.start_time, day) || isOn(row.complete_time, day)) return true;
  for (let i = 1; i <= 10; i += 1) {
    if (isOn(row[`hold_time_${i}`], day) || isOn(row[`restart_time_${i}`], day)) return true;
  }
  return false;
}

async function computeClientStatus(employeeName, clientName, day) {
  const [[emp]] = await db.query(
    'SELECT id FROM employee_users WHERE LOWER(TRIM(full_name)) = LOWER(TRIM(?)) LIMIT 1',
    [employeeName],
  );
  const employeeId = emp?.id ?? -1;
  const [rows] = await db.query(
    `SELECT tti.*
     FROM time_tracking_task_items tti
     JOIN task_list tl ON tl.id = tti.task_list_id
     WHERE (tl.employee_id = ? OR LOWER(TRIM(tl.employee_name)) = LOWER(TRIM(?)))
       AND LOWER(TRIM(tl.client_name)) = LOWER(TRIM(?))`,
    [employeeId, employeeName, clientName],
  );
  const [sheets] = await db.query(
    `SELECT cc_status, cc_last_activity_at FROM content_calendar
     WHERE (cc_prepared_by_id = ? OR LOWER(TRIM(cc_prepared_by_name)) = LOWER(TRIM(?)))
       AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))
       AND cc_handoff_at IS NULL`,
    [employeeId, employeeName, clientName],
  );

  const status = (r) => String(r.status || 'IDLE').toUpperCase();
  const review = (r) => String(r.review_status || '').toUpperCase();
  const sheetStatus = (s) => String(s.cc_status || 'IDLE').toUpperCase();

  if (rows.some((r) => status(r) === 'IN PROGRESS') || sheets.some((s) => sheetStatus(s) === 'IN PROGRESS')) {
    return 'PROCESSING';
  }
  const reworkOpen = (r) => status(r) === 'REWORK' ||
    (review(r) === 'REWORK' && !['IN PROGRESS', 'COMPLETED'].includes(status(r)));
  if (rows.some((r) => status(r) === 'ON HOLD' || reworkOpen(r)) ||
      sheets.some((s) => sheetStatus(s) === 'ON HOLD')) {
    return 'HOLD';
  }
  const touchedToday = rows.some((r) => touchedOn(r, day)) ||
    sheets.some((s) => isOn(s.cc_last_activity_at, day));
  if (!touchedToday) return 'NOT START';
  const openLeft = rows.some((r) => status(r) === 'IDLE' && !r.complete_time) ||
    sheets.some((s) => ['IDLE', 'ON HOLD', 'IN PROGRESS'].includes(sheetStatus(s)) && isOn(s.cc_last_activity_at, day));
  return openLeft ? 'PENDING' : 'COMPLETE';
}

// Planner status for one task row (marker "[Task Row #id]").
function taskRowPlanStatus(r) {
  const status = String(r.status || 'IDLE').toUpperCase();
  const review = String(r.review_status || '').toUpperCase();
  if (status === 'IN PROGRESS') return 'PROCESSING';
  if (status === 'ON HOLD') return 'HOLD';
  if (status === 'REWORK' || (review === 'REWORK' && status !== 'COMPLETED')) return 'REWORK';
  if (status === 'COMPLETED' || status === 'REJECTED' || review === 'APPROVED') return 'COMPLETE';
  return r.start_time ? 'PENDING' : 'NOT START';
}

// Planner status for one Content Calendar category (marker "[Calendar Row #id]").
async function calendarPlanStatus(calendarId) {
  const [[row]] = await db.query(
    `SELECT id, source_assignment_id, source_role, source_task_index, cc_status
     FROM content_calendar WHERE id = ?`,
    [calendarId],
  );
  if (!row) return null;
  let statuses = [String(row.cc_status || 'IDLE').toUpperCase()];
  if (row.source_assignment_id) {
    const [group] = await db.query(
      `SELECT cc_status FROM content_calendar
       WHERE source_assignment_id = ? AND source_role = ? AND source_task_index = ?`,
      [row.source_assignment_id, row.source_role, row.source_task_index],
    );
    statuses = group.map((g) => String(g.cc_status || 'IDLE').toUpperCase());
  }
  if (statuses.includes('IN PROGRESS')) return 'PROCESSING';
  if (statuses.includes('ON HOLD')) return 'HOLD';
  if (statuses.length && statuses.every((x) => x === 'COMPLETED')) return 'COMPLETE';
  return 'NOT START';
}

/**
 * Update today's Day Planner rows for this employee (optionally one client).
 *   "[Task Row #id] …"     → that task row's own status
 *   "[Calendar Row #id] …" → that Content Calendar category's status
 *   other rows             → the client's overall status
 * Only writes when a value changes. Returns true when anything changed.
 */
async function syncDayPlanStatus(employeeName, clientName = null, date = null) {
  const name = String(employeeName || '').trim();
  if (!name) return false;
  const day = date || localDay(new Date());
  const params = [name, day];
  let clientSql = '';
  if (clientName) {
    clientSql = 'AND LOWER(TRIM(client_name)) = LOWER(TRIM(?))';
    params.push(clientName);
  }
  const [planRows] = await db.query(
    `SELECT id, client_name, status, today_plan FROM day_plan_rows
     WHERE LOWER(TRIM(employee_name)) = LOWER(TRIM(?)) AND DATE(plan_date) = ?
       AND client_name IS NOT NULL AND client_name <> '' ${clientSql}`,
    params,
  );
  const clientCache = new Map();
  let changed = false;
  for (const row of planRows) {
    const plan = String(row.today_plan || '');
    let next = null;
    const taskMarker = plan.match(/\[Task Row #(\d+)\]/);
    const calMarker = plan.match(/\[Calendar Row #(\d+)\]/);
    if (taskMarker) {
      const [[t]] = await db.query(
        'SELECT status, review_status, start_time FROM time_tracking_task_items WHERE id = ?',
        [Number(taskMarker[1])],
      );
      next = t ? taskRowPlanStatus(t) : null;
    } else if (calMarker) {
      next = await calendarPlanStatus(Number(calMarker[1]));
    } else {
      const key = String(row.client_name).trim().toLowerCase();
      if (!clientCache.has(key)) clientCache.set(key, await computeClientStatus(name, row.client_name, day));
      next = clientCache.get(key);
    }
    if (next && String(row.status || '').toUpperCase() !== next) {
      await db.query('UPDATE day_plan_rows SET status = ? WHERE id = ?', [next, row.id]);
      changed = true;
    }
  }
  return changed;
}

/** Same, starting from a tracking item id (employee + client looked up). */
async function syncDayPlanForItem(trackingItemId) {
  try {
    const [[info]] = await db.query(
      `SELECT tl.employee_name, tl.client_name
       FROM time_tracking_task_items tti JOIN task_list tl ON tl.id = tti.task_list_id
       WHERE tti.id = ?`,
      [trackingItemId],
    );
    if (info) await syncDayPlanStatus(info.employee_name, info.client_name);
  } catch (err) {
    console.error('syncDayPlanForItem:', err.message);
  }
}

module.exports = { syncDayPlanStatus, syncDayPlanForItem, computeClientStatus, touchedOn, localDay };
