const attendancePolicy = require('./attendancePolicy');
const { workedMinutes } = require('./dashboardWorkTime');
const { mergeRoleAccessRows } = require('./employeeRoles');

async function optionalRows(db, sql, params) {
  try {
    const [rows] = await db.query(sql, params);
    return rows;
  } catch (error) {
    if (error.code === 'ER_NO_SUCH_TABLE') return [];
    throw error;
  }
}

function pagesFrom(value) {
  try {
    const pages = Array.isArray(value) ? value : JSON.parse(value || '[]');
    return Array.isArray(pages) ? pages.map((page) => String(page).trim().toLowerCase()) : [];
  } catch {
    return [];
  }
}

async function taskManagerAdminPages(db, users) {
  if (!users.length) return new Map();
  const ids = users.map((user) => user.id);
  const [individual, roleAccess, assignments, legacy] = await Promise.all([
    optionalRows(db, 'SELECT employee_id, application, access_type, allowed_pages FROM employee_application_access WHERE employee_id IN (?)', [ids]),
    optionalRows(db, `SELECT a.role_id, r.role_name, a.application, a.access_type, a.allowed_pages
      FROM role_application_access a JOIN user_roles r ON r.id = a.role_id`, []),
    optionalRows(db, `SELECT a.employee_id, a.role_id FROM employee_user_roles a
      JOIN user_roles r ON r.id = a.role_id WHERE a.employee_id IN (?)`, [ids]),
    optionalRows(db, 'SELECT employee_id, allowed_pages FROM role_page_access WHERE employee_id IN (?)', [ids]),
  ]);
  return new Map(users.map((user) => {
    if (Number(user.is_main_admin) === 1) {
      return [Number(user.id), new Set(['/invoice', '/quotations', '/client-history', '/performance'])];
    }
    const employeeRows = individual.filter((row) => Number(row.employee_id) === Number(user.id));
    const assignedIds = new Set(assignments.filter((row) => Number(row.employee_id) === Number(user.id))
      .map((row) => Number(row.role_id)));
    const roleRows = roleAccess.filter((row) => assignedIds.size > 0 ? assignedIds.has(Number(row.role_id))
      : String(row.role_name).trim().toLowerCase() === String(user.role || '').trim().toLowerCase());
    const configured = employeeRows.length ? employeeRows : roleRows;
    const taskManager = mergeRoleAccessRows(configured).task_manager;
    const allowed = taskManager.accessType === 'admin' ? taskManager.allowedPages
      : !configured.length && String(user.user_type).toLowerCase() === 'admin'
        ? legacy.filter((row) => Number(row.employee_id) === Number(user.id)).flatMap((row) => pagesFrom(row.allowed_pages))
        : [];
    return [Number(user.id), new Set(allowed.map((page) => String(page).trim().toLowerCase()))];
  }));
}

async function attendanceByEmployee(db, from, to, now, offsetMinutes) {
  const records = await optionalRows(db, `SELECT id, employee_id, admin_status_override,
      DATE_FORMAT(attendance_date, '%Y-%m-%d') AS day,
      DATE_FORMAT(check_in_at, '%Y-%m-%d %H:%i:%s') AS check_in_at,
      DATE_FORMAT(check_out_at, '%Y-%m-%d %H:%i:%s') AS check_out_at
    FROM attendance_records WHERE attendance_date BETWEEN ? AND ? AND check_in_at IS NOT NULL`, [from, to]);
  const breaks = records.length ? await optionalRows(db, `SELECT attendance_id, status, duration_minutes,
      DATE_FORMAT(started_at, '%Y-%m-%d %H:%i:%s') AS started_at,
      DATE_FORMAT(ended_at, '%Y-%m-%d %H:%i:%s') AS ended_at
    FROM attendance_breaks WHERE attendance_id IN (?)`, [records.map((row) => row.id)]) : [];
  const byRecord = new Map();
  for (const entry of breaks) {
    if (!byRecord.has(entry.attendance_id)) byRecord.set(entry.attendance_id, []);
    byRecord.get(entry.attendance_id).push(entry);
  }
  const officeNow = attendancePolicy.partsInZone(now);
  const toEpoch = (value) => value ? Date.parse(value.replace(' ', 'T') + 'Z') - offsetMinutes * 60000 : NaN;
  const byEmployee = new Map();
  for (const row of records) {
    if (row.admin_status_override === 'absent') continue;
    const live = !row.check_out_at && row.day === officeNow.date;
    const dayBreaks = byRecord.get(row.id) || [];
    const start = toEpoch(row.check_in_at);
    const clockOut = row.check_out_at > officeNow.dateTime ? officeNow.dateTime : row.check_out_at;
    const end = toEpoch(clockOut || (live ? officeNow.dateTime : null));
    const valid = end >= start && end - start <= 86400000;
    const workedSecs = valid
      ? workedMinutes({ ...row, check_out_at: clockOut }, dayBreaks, officeNow.dateTime, live) * 60 : null;
    const employeeId = Number(row.employee_id);
    if (!byEmployee.has(employeeId)) byEmployee.set(employeeId, new Map());
    byEmployee.get(employeeId).set(row.day, {
      date: row.day,
      checkIn: row.check_in_at,
      checkOut: row.check_out_at,
      live,
      workedSecs,
      start,
      end,
      breaks: dayBreaks.map((entry) => [toEpoch(entry.started_at), toEpoch(entry.ended_at || (live ? officeNow.dateTime : row.check_out_at))]),
    });
  }
  return byEmployee;
}

function trackedSeconds(entries, attendance) {
  if (attendance?.workedSecs === 0) return 0;
  const clocked = attendance?.workedSecs != null;
  const intervals = [];
  for (const entry of entries) {
    const start = clocked ? Math.max(entry.start, attendance.start) : entry.start;
    const end = clocked ? Math.min(entry.end, attendance.end) : entry.end;
    if (end > start) intervals.push([start, end]);
  }
  intervals.sort(([a], [b]) => a - b);
  const merged = [];
  for (const [start, end] of intervals) {
    const last = merged[merged.length - 1];
    if (last && last[1] >= start) last[1] = Math.max(last[1], end);
    else merged.push([start, end]);
  }
  let trackedMs = 0;
  for (const [start, end] of merged) {
    let segments = [[start, end]];
    for (const [breakStart, breakEnd] of attendance?.breaks || []) {
      if (!clocked || !(breakEnd > breakStart)) continue;
      segments = segments.flatMap(([a, b]) => breakStart >= b || breakEnd <= a
        ? [[a, b]]
        : [[a, Math.max(a, breakStart)], [Math.min(b, breakEnd), b]]);
    }
    trackedMs += segments.reduce((sum, [a, b]) => sum + b - a, 0);
  }
  const total = Math.floor(trackedMs / 1000);
  return clocked ? Math.min(attendance.workedSecs, total) : total;
}

module.exports = { attendanceByEmployee, optionalRows, taskManagerAdminPages, trackedSeconds };
