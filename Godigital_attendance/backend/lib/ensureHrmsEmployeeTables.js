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
  // Employee type is extensible (for example Manager, Supervisor, or Intern).
  // Older installations created this column as an ENUM, so widen it without
  // changing existing Employee/Labour values.
  try {
    await db.query("ALTER TABLE hrms_employee_profiles MODIFY COLUMN employee_type VARCHAR(100) NOT NULL DEFAULT 'Employee'");
  } catch (error) {
    // Keep startup non-fatal for databases whose account cannot alter schema;
    // the existing two built-in values remain usable in that case.
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
    // A duplicated staff_id must not make startup fail. Keep the first
    // occurrence's code and give later users a deterministic unique code.
    "SELECT u.id, CASE WHEN NULLIF(u.staff_id, '') IS NOT NULL AND (SELECT COUNT(*) FROM employee_users sx WHERE sx.staff_id = u.staff_id) = 1 THEN u.staff_id ELSE CONCAT('EMP', LPAD(u.id, 4, '0')) END, " +
    "COALESCE(NULLIF(u.full_name, ''), CONCAT(u.first_name, ' ', u.last_name)), u.email, " +
    "COALESCE(NULLIF(u.role, ''), 'Engineering'), 'Office', " +
    "CASE WHEN u.is_active = 1 THEN 'Active' ELSE 'Inactive' END " +
    "FROM employee_users u LEFT JOIN hrms_employee_profiles p ON p.employee_user_id = u.id " +
    "WHERE p.id IS NULL AND LOWER(u.user_type) = 'employee' " +
    "AND NOT EXISTS (SELECT 1 FROM hrms_employee_profiles existing WHERE existing.employee_code = CASE WHEN NULLIF(u.staff_id, '') IS NOT NULL AND (SELECT COUNT(*) FROM employee_users sx2 WHERE sx2.staff_id = u.staff_id) = 1 THEN u.staff_id ELSE CONCAT('EMP', LPAD(u.id, 4, '0')) END)"
  );
}

module.exports = { ensureHrmsEmployeeTables: ensureHrmsEmployeeTables };
