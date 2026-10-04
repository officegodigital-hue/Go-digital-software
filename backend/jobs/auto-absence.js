const db = require('../config/db');
const policy = require('../lib/attendancePolicy');

function previousDate(date) {
  const [year, month, day] = date.split('-').map(Number);
  const value = new Date(Date.UTC(year, month - 1, day - 1));
  return value.toISOString().slice(0, 10);
}

async function isWorkingDay(date) {
  const day = new Date(`${date}T00:00:00Z`).getUTCDay();
  let weeklyOffDays = [0];
  try {
    const [rows] = await db.query('SELECT weekly_off_days FROM hrms_payroll_policy WHERE id = 1');
    const parsed = JSON.parse((rows[0] && rows[0].weekly_off_days) || '[0]');
    // Older live databases can contain an invalid/non-list JSON value.
    // Treat it as the configured default instead of allowing the scheduler
    // to fail before automatic absence processing.
    weeklyOffDays = Array.isArray(parsed)
      ? parsed.map(Number).filter((value) => Number.isInteger(value) && value >= 0 && value <= 6)
      : [0];
    if (!weeklyOffDays.length) weeklyOffDays = [0];
  } catch (_) {}

  try {
    const [[override]] = await db.query(
      'SELECT status FROM hrms_calendar_overrides WHERE work_date = ? LIMIT 1',
      [date]
    );
    if (override) return override.status === 'Working Day';
  } catch (_) {}

  return !weeklyOffDays.includes(day);
}

async function ensureAuditTable() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_auto_absence_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    attendance_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_auto_absence (employee_id, attendance_date)
  )`);
}

async function runAutoAbsence(targetDate = previousDate(policy.todayIstDate())) {
  await ensureAuditTable();
  if (!await isWorkingDay(targetDate)) return { date: targetDate, skipped: 'non-working day', created: 0 };

  const [employees] = await db.query(
    `SELECT id FROM employee_users
      WHERE user_type = 'employee' AND is_active = 1`
  );
  if (!employees.length) return { date: targetDate, created: 0 };
  const ids = employees.map((row) => row.id);

  const [records] = await db.query(
    'SELECT employee_id FROM attendance_records WHERE attendance_date = ? AND employee_id IN (?)',
    [targetDate, ids]
  );
  const [leaves] = await db.query(
    `SELECT employee_id FROM employee_leaves
      WHERE status = 'APPROVED' AND from_date <= ? AND to_date >= ? AND employee_id IN (?)`,
    [targetDate, targetDate, ids]
  );
  const [permissions] = await db.query(
    `SELECT employee_id FROM attendance_permission_requests
      WHERE status = 'approved' AND request_date = ? AND employee_id IN (?)`,
    [targetDate, ids]
  );

  const excluded = new Set([
    ...records.map((row) => Number(row.employee_id)),
    ...leaves.map((row) => Number(row.employee_id)),
    ...permissions.map((row) => Number(row.employee_id)),
  ]);
  const missing = ids.filter((id) => !excluded.has(Number(id)));
  if (!missing.length) return { date: targetDate, created: 0 };

  const values = missing.map(() => '(?, ?, NULL, NULL, \'absent\', \'closed\', NULL, 0, 0)').join(',');
  const params = missing.flatMap((id) => [id, targetDate]);
  await db.query(
    `INSERT INTO attendance_records
      (employee_id, attendance_date, check_in_at, check_out_at, attendance_status, session_status, check_in_method, is_late, working_minutes)
     VALUES ${values}
     ON DUPLICATE KEY UPDATE id = id`,
    params
  );
  await db.query(
    `INSERT IGNORE INTO hrms_auto_absence_audit (employee_id, attendance_date)
     VALUES ${missing.map(() => '(?, ?)').join(',')}`,
    missing.flatMap((id) => [id, targetDate])
  );
  return { date: targetDate, created: missing.length };
}

module.exports = { runAutoAbsence, isWorkingDay };
