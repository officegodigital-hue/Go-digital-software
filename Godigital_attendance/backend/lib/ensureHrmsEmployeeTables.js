const fs = require('fs');
const path = require('path');

async function ensureHrmsEmployeeTables(db) {
  const sqlPath = path.join(__dirname, '..', 'sql', 'hrms_employee_profiles.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');
  await db.query(sql);
  try {
    await db.query(
      'ALTER TABLE hrms_employee_profiles ADD COLUMN field_tracking_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER employment_status'
    );
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  try {
    await db.query("ALTER TABLE hrms_employee_profiles ADD COLUMN employee_type ENUM('Employee', 'Labour') NOT NULL DEFAULT 'Employee' AFTER work_mode");
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  try {
    await db.query('ALTER TABLE hrms_employee_profiles ADD COLUMN overtime_eligible TINYINT(1) NOT NULL DEFAULT 0 AFTER employee_type');
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  try {
    await db.query("ALTER TABLE hrms_employee_profiles ADD COLUMN salary_type ENUM('Standard','Flexible') NOT NULL DEFAULT 'Standard' AFTER monthly_salary");
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  try {
    await db.query('ALTER TABLE hrms_employee_profiles ADD COLUMN flexible_cycle_start_day TINYINT UNSIGNED NULL AFTER salary_type');
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  try {
    await db.query('ALTER TABLE hrms_employee_profiles ADD COLUMN flexible_cycle_end_day TINYINT UNSIGNED NULL AFTER flexible_cycle_start_day');
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }

  await db.query(
    "INSERT INTO hrms_employee_profiles (employee_user_id, employee_code, full_name, email, department, work_mode, employment_status) " +
    "SELECT u.id, COALESCE(NULLIF(u.staff_id, ''), CONCAT('EMP', LPAD(u.id, 4, '0'))), " +
    "COALESCE(NULLIF(u.full_name, ''), CONCAT(u.first_name, ' ', u.last_name)), u.email, " +
    "COALESCE(NULLIF(u.role, ''), 'Engineering'), 'Office', " +
    "CASE WHEN u.is_active = 1 THEN 'Active' ELSE 'Inactive' END " +
    "FROM employee_users u LEFT JOIN hrms_employee_profiles p ON p.employee_user_id = u.id " +
    "WHERE p.id IS NULL AND LOWER(u.user_type) = 'employee' " +
    "AND NOT EXISTS (SELECT 1 FROM hrms_employee_profiles existing WHERE existing.employee_code = COALESCE(NULLIF(u.staff_id, ''), CONCAT('EMP', LPAD(u.id, 4, '0'))))"
  );
}

module.exports = { ensureHrmsEmployeeTables: ensureHrmsEmployeeTables };
