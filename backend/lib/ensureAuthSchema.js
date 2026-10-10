'use strict';

async function ensureAuthSchema(db) {
  const [columns] = await db.query(
    "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employee_users' AND COLUMN_NAME = 'is_main_admin'"
  );
  if (!columns.length) {
    try {
      await db.query('ALTER TABLE employee_users ADD COLUMN is_main_admin TINYINT(1) NOT NULL DEFAULT 0');
    } catch (error) {
      // Another server instance may have added the column during startup.
      if (error.code !== 'ER_DUP_FIELDNAME') throw error;
    }
  }
  await db.query(`CREATE TABLE IF NOT EXISTS role_page_access (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    allowed_pages TEXT NOT NULL,
    KEY employee_id (employee_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`);

  // Per-employee application permissions are read during every login and are
  // also maintained by the employee-management routes.
  await db.query(`CREATE TABLE IF NOT EXISTS employee_application_access (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    employee_id INT NOT NULL,
    application VARCHAR(64) NOT NULL,
    access_type VARCHAR(32) NOT NULL DEFAULT 'none',
    allowed_pages TEXT NOT NULL,
    UNIQUE KEY employee_application (employee_id, application),
    KEY employee_id (employee_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`);

  // Role-level access is the fallback for employees without an explicit
  // application-access record.
  await db.query(`CREATE TABLE IF NOT EXISTS role_application_access (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    role_id INT NOT NULL,
    application VARCHAR(64) NOT NULL,
    access_type VARCHAR(32) NOT NULL DEFAULT 'none',
    allowed_pages TEXT NOT NULL,
    UNIQUE KEY role_application (role_id, application),
    KEY role_id (role_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`);
}

module.exports = { ensureAuthSchema };
