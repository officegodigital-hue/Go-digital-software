const db = require('../config/db');

async function ensureCalendarOverrideTables() {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_calendar_overrides (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    work_date DATE NOT NULL,
    status ENUM('Working Day', 'Weekly Off', 'Holiday') NOT NULL,
    scope VARCHAR(64) NOT NULL DEFAULT 'All Employees',
    reason VARCHAR(500) NULL,
    notify_employees TINYINT(1) NOT NULL DEFAULT 1,
    updated_by INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  )`);
  // Older installations used one global override per date.  Scoped rules need
  // several records for a date, so retire that legacy uniqueness constraint.
  try { await db.query('ALTER TABLE hrms_calendar_overrides DROP INDEX unique_work_date'); } catch (_) {}
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_calendar_override_targets (
    override_id INT UNSIGNED NOT NULL, employee_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (override_id, employee_id), KEY employee_date (employee_id)
  )`);
  try { await db.query("ALTER TABLE hrms_calendar_overrides ADD COLUMN scope_type ENUM('all','department','employees') NOT NULL DEFAULT 'all' AFTER status"); } catch (_) {}
  try { await db.query('ALTER TABLE hrms_calendar_overrides ADD COLUMN department VARCHAR(255) NULL AFTER scope_type'); } catch (_) {}
  await db.query("UPDATE hrms_calendar_overrides SET scope_type='all' WHERE scope_type IS NULL");
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_employee_calendar_notifications (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT UNSIGNED NOT NULL, override_id INT UNSIGNED NOT NULL,
    title VARCHAR(160) NOT NULL, message VARCHAR(500) NOT NULL,
    is_read TINYINT(1) NOT NULL DEFAULT 0, read_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY employee_override (employee_id, override_id), KEY employee_unread (employee_id, is_read, created_at)
  )`);
}

function resolveEffectiveOverrides(rows, employees) {
  const result = new Map();
  for (const employee of employees) {
    const employeeId = Number(employee.employee_user_id || employee.id);
    const department = String(employee.calendar_department || employee.department || employee.role || '').trim();
    const dates = new Map();
    for (const row of rows) {
      const matches = row.scope_type === 'all' ||
        (row.scope_type === 'department' && String(row.department || '') === department) ||
        (row.scope_type === 'employees' && Number(row.employee_id) === employeeId);
      if (!matches) continue;
      const priority = row.scope_type === 'employees' ? 3 : row.scope_type === 'department' ? 2 : 1;
      const current = dates.get(row.work_date);
      if (!current || priority >= current.priority) dates.set(row.work_date, { status: row.status, priority });
    }
    result.set(employeeId, dates);
  }
  return result;
}

async function effectiveOverrides(start, end, employees) {
  await ensureCalendarOverrideTables();
  const [rows] = await db.query(`SELECT o.id, DATE_FORMAT(o.work_date,'%Y-%m-%d') work_date, o.status, o.scope_type, o.department, o.updated_at,
    t.employee_id FROM hrms_calendar_overrides o LEFT JOIN hrms_calendar_override_targets t ON t.override_id=o.id
    WHERE o.work_date BETWEEN ? AND ? ORDER BY o.updated_at ASC, o.id ASC`, [start, end]);
  return resolveEffectiveOverrides(rows, employees);
}

module.exports = { ensureCalendarOverrideTables, effectiveOverrides, resolveEffectiveOverrides };
