const policy = require('./attendancePolicy');

// [name, annual_allowance, usage_only, abbreviation, is_lop]
// Defaults are used only while seeding an empty database.  Once an administrator
// changes a leave policy, payroll must use that saved policy without resetting it.
const DEFAULT_TYPES = [
  ['Casual Leave',    12, 0, 'CL',  1],
  ['Sick Leave',       8, 1, 'SL',  1],
  ['Earned Leave',    18, 0, 'EL',  0],
  ['Optional Holiday', 3, 0, 'OH',  0],
];

function iso(value) {
  if (!value) return '';
  const match = String(value).match(/^(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : '';
}

function nextDate(value) {
  const date = new Date(`${value}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}

async function ensureLeaveTables(db) {
  await db.query(`CREATE TABLE IF NOT EXISTS hrms_leave_types (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(80) NOT NULL,
    annual_allowance DECIMAL(8,2) NOT NULL DEFAULT 0,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    show_balance_card TINYINT(1) NOT NULL DEFAULT 0,
    usage_only TINYINT(1) NOT NULL DEFAULT 0,
    display_mode ENUM('BALANCE_USAGE','USAGE_ONLY') NOT NULL DEFAULT 'BALANCE_USAGE',
    allow_half_day TINYINT(1) NOT NULL DEFAULT 1,
    card_order TINYINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_hrms_leave_type_name (name),
    KEY idx_hrms_leave_type_active (is_active, show_balance_card, card_order)
  )`);
  await db.query(`CREATE TABLE IF NOT EXISTS employee_leaves (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    employee_id BIGINT UNSIGNED NOT NULL,
    leave_type VARCHAR(80) NOT NULL,
    leave_type_id BIGINT UNSIGNED NULL,
    duration_type ENUM('Full Day', 'Half Day') NOT NULL DEFAULT 'Full Day',
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    days_count DECIMAL(8,2) NOT NULL,
    reason VARCHAR(1000) NOT NULL,
    status ENUM('PENDING', 'APPROVED', 'DENIED', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_employee_leaves_employee_dates (employee_id, from_date, to_date, status),
    KEY idx_employee_leaves_status_dates (status, from_date, to_date),
    KEY idx_employee_leaves_type (leave_type_id)
  )`);
  try { await db.query('ALTER TABLE hrms_leave_types ADD COLUMN usage_only TINYINT(1) NOT NULL DEFAULT 0 AFTER show_balance_card'); } catch (error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; }
  try { await db.query("ALTER TABLE hrms_leave_types ADD COLUMN display_mode ENUM('BALANCE_USAGE','USAGE_ONLY') NOT NULL DEFAULT 'BALANCE_USAGE' AFTER usage_only"); } catch (error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; }
  try { await db.query('ALTER TABLE hrms_leave_types ADD COLUMN allow_half_day TINYINT(1) NOT NULL DEFAULT 1 AFTER display_mode'); } catch (error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; }
  try { await db.query("ALTER TABLE hrms_leave_types ADD COLUMN abbreviation VARCHAR(10) NULL AFTER display_mode"); } catch (error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; }
  try { await db.query('ALTER TABLE hrms_leave_types ADD COLUMN is_lop TINYINT(1) NOT NULL DEFAULT 1 AFTER abbreviation'); } catch (error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; }
  for (const [name, allowance, usageOnly, abbreviation, isLop] of DEFAULT_TYPES) {
    await db.query(`INSERT IGNORE INTO hrms_leave_types (name, annual_allowance, is_active, show_balance_card, usage_only, abbreviation, is_lop, card_order)
      VALUES (?, ?, 1, 1, ?, ?, ?, ?)`, [name, allowance, usageOnly, abbreviation, isLop, DEFAULT_TYPES.findIndex((e) => e[0] === name) + 1]);
  }
  // Back-fill presentation-only abbreviations.  Do not update is_lop,
  // allow_half_day, or any other payroll policy here: Admin owns them.
  await db.query(`UPDATE hrms_leave_types SET abbreviation = 'CL' WHERE name = 'Casual Leave'    AND (abbreviation IS NULL OR abbreviation = '')`);
  await db.query(`UPDATE hrms_leave_types SET abbreviation = 'SL' WHERE name = 'Sick Leave'      AND (abbreviation IS NULL OR abbreviation = '')`);
  await db.query(`UPDATE hrms_leave_types SET abbreviation = 'EL' WHERE name = 'Earned Leave'    AND (abbreviation IS NULL OR abbreviation = '')`);
  await db.query(`UPDATE hrms_leave_types SET abbreviation = 'OH' WHERE name = 'Optional Holiday' AND (abbreviation IS NULL OR abbreviation = '')`);
  try { await db.query('ALTER TABLE employee_leaves ADD COLUMN leave_type_id BIGINT UNSIGNED NULL AFTER leave_type'); } catch (error) { if (error.code !== 'ER_DUP_FIELDNAME') throw error; }
  await db.query(`UPDATE employee_leaves l JOIN hrms_leave_types t
    ON CONVERT(t.name USING utf8mb4) COLLATE utf8mb4_unicode_ci = CONVERT(l.leave_type USING utf8mb4) COLLATE utf8mb4_unicode_ci
    SET l.leave_type_id = t.id WHERE l.leave_type_id IS NULL`);
}

async function workingDates(db, fromDate, toDate, employeeId) {
  const start = iso(fromDate); const end = iso(toDate);
  const [settings] = await db.query('SELECT weekly_off_days FROM hrms_payroll_policy WHERE id = 1 LIMIT 1').catch(() => [[]]);
  let weeklyOffValues = [0];
  try {
    const raw = settings[0] && settings[0].weekly_off_days;
    weeklyOffValues = Array.isArray(raw) ? raw : JSON.parse(raw || '[0]');
  } catch (_) {}
  const weeklyOff = new Set(Array.isArray(weeklyOffValues) ? weeklyOffValues.map(Number) : [0]);
  let department = '';
  if (employeeId) {
    const [profiles] = await db.query('SELECT department FROM hrms_employee_profiles WHERE employee_user_id=? LIMIT 1', [employeeId]).catch(() => [[]]);
    department = String(profiles[0]?.department || '');
  }
  const [overrides] = await db.query(`SELECT DATE_FORMAT(o.work_date, '%Y-%m-%d') AS work_date, o.status, o.scope_type, o.department, t.employee_id
    FROM hrms_calendar_overrides o LEFT JOIN hrms_calendar_override_targets t ON t.override_id=o.id
    WHERE o.work_date BETWEEN ? AND ?`, [start, end]).catch(() => [[]]);
  const overrideByDate = new Map();
  for (const row of overrides) {
    const priority = row.scope_type === 'employees' ? 3 : row.scope_type === 'department' ? 2 : 1;
    const matches = row.scope_type === 'all' || !row.scope_type ||
      (row.scope_type === 'department' && String(row.department || '') === department) ||
      (row.scope_type === 'employees' && Number(row.employee_id) === Number(employeeId));
    if (!matches) continue;
    const old = overrideByDate.get(iso(row.work_date));
    if (!old || priority >= old.priority) overrideByDate.set(iso(row.work_date), { status: row.status, priority });
  }
  const dates = [];
  for (let date = start; date && date <= end; date = nextDate(date)) {
    const override = overrideByDate.get(date)?.status;
    const weekday = new Date(`${date}T00:00:00Z`).getUTCDay();
    if (override === 'Working Day' || (!override && !weeklyOff.has(weekday))) dates.push(date);
  }
  return dates;
}

async function listTypes(db, { activeOnly = false } = {}) {
  await ensureLeaveTables(db);
  const [rows] = await db.query(`SELECT id, name, annual_allowance, is_active, show_balance_card, usage_only, display_mode, allow_half_day, abbreviation, is_lop, card_order
    FROM hrms_leave_types ${activeOnly ? 'WHERE is_active = 1' : ''} ORDER BY show_balance_card DESC, card_order ASC, name ASC`);
  return rows;
}

async function reconcileApprovedAbsences(db, leave) {
  const dates = await workingDates(db, leave.from_date, leave.to_date, leave.employee_id);
  if (!dates.length) return;
  await db.query(`DELETE FROM attendance_records
    WHERE employee_id = ? AND attendance_date IN (?) AND attendance_status = 'absent'
      AND check_in_at IS NULL AND check_out_at IS NULL`, [leave.employee_id, dates]);
}

module.exports = { ensureLeaveTables, listTypes, workingDates, reconcileApprovedAbsences, iso };
