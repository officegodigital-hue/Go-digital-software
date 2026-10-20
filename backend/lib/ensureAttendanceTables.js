const fs = require('fs');
const path = require('path');

async function ensureAttendanceTables(db) {
  const sqlPath = path.join(__dirname, '..', 'sql', 'attendance.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const statements = sql.split(/;\s*$/m).map(function (chunk) {
    return chunk.trim();
  }).filter(function (chunk) {
    return chunk && chunk.indexOf('--') !== 0;
  });

  for (var i = 0; i < statements.length; i++) {
    await db.query(statements[i]);
  }

  // CREATE TABLE IF NOT EXISTS does not upgrade an older installation.  Add
  // only missing columns so existing attendance data is preserved.
  const [columns] = await db.query(
    `SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'attendance_records'`
  );
  const existing = new Set(columns.map(function (column) {
    return column.COLUMN_NAME;
  }));
  const required = {
    check_in_at: 'DATETIME NULL',
    check_out_at: 'DATETIME NULL',
    attendance_status: "VARCHAR(32) NOT NULL DEFAULT 'absent'",
    session_status: "VARCHAR(32) NOT NULL DEFAULT 'open'",
    check_in_method: 'VARCHAR(32) NULL',
    is_late: 'TINYINT(1) NOT NULL DEFAULT 0',
    working_minutes: 'INT UNSIGNED NOT NULL DEFAULT 0',
    outside_radius_since: 'DATETIME NULL',
    admin_status_override: 'VARCHAR(16) NULL',
    admin_override_reason: 'TEXT NULL',
    admin_override_by: 'INT NULL',
    admin_override_at: 'DATETIME NULL'
  };
  for (const [name, definition] of Object.entries(required)) {
    if (!existing.has(name)) {
      await db.query(`ALTER TABLE attendance_records ADD COLUMN \`${name}\` ${definition}`);
    }
  }
  await db.query(`CREATE TABLE IF NOT EXISTS attendance_admin_corrections (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attendance_id BIGINT UNSIGNED NOT NULL,
    employee_id INT NOT NULL,
    attendance_date DATE NOT NULL,
    previous_status VARCHAR(32) NOT NULL,
    corrected_status VARCHAR(16) NOT NULL,
    reason TEXT NOT NULL,
    admin_id INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_employee_day (employee_id, attendance_date)
  )`);
}

module.exports = { ensureAttendanceTables: ensureAttendanceTables };
