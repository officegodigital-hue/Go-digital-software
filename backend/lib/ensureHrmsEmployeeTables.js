const fs = require('fs');
const path = require('path');

async function ensureHrmsEmployeeTables(db) {
  const sqlPath = path.join(__dirname, '..', 'sql', 'hrms_employee_profiles.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');
  await db.query(sql);

  await db.query(
    "INSERT INTO hrms_employee_profiles (employee_user_id, employee_code, full_name, email, department, work_mode, employment_status) " +
    "SELECT u.id, COALESCE(NULLIF(u.staff_id, ''), CONCAT('EMP', LPAD(u.id, 4, '0'))), " +
    "COALESCE(NULLIF(u.full_name, ''), CONCAT(u.first_name, ' ', u.last_name)), u.email, " +
    "COALESCE(NULLIF(u.role, ''), 'Engineering'), 'Office', " +
    "CASE WHEN u.is_active = 1 THEN 'Active' ELSE 'Inactive' END " +
    "FROM employee_users u LEFT JOIN hrms_employee_profiles p ON p.employee_user_id = u.id WHERE p.id IS NULL"
  );
}

module.exports = { ensureHrmsEmployeeTables: ensureHrmsEmployeeTables };