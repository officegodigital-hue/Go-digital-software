async function addColumnIfMissing(db, table, column, definition) {
  const [rows] = await db.query(
    `SELECT 1 FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [table, column],
  );
  if (!rows.length) {
    await db.query(`ALTER TABLE \`${table}\` ADD COLUMN \`${column}\` ${definition}`);
  }
}

async function ensureClientRepositoryTables(db) {
  // These tables are deliberately additive. They never drop or replace an
  // existing Assets backup table when the application starts.
  await db.query(`CREATE TABLE IF NOT EXISTS companies (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    logo_url VARCHAR(500) NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY companies_name_unique (name)
  )`);

  await db.query(`CREATE TABLE IF NOT EXISTS assets (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT NOT NULL,
    company_name VARCHAR(255) NULL,
    section VARCHAR(80) NULL,
    type VARCHAR(100) NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT NULL,
    link TEXT NULL,
    username VARCHAR(255) NULL,
    password TEXT NULL,
    file_url VARCHAR(1000) NULL,
    file_name VARCHAR(255) NULL,
    mime_type VARCHAR(120) NULL,
    file_size BIGINT NULL,
    created_by_employee_id BIGINT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_employee_id) REFERENCES employee_users(id) ON DELETE SET NULL,
    KEY assets_company_id_index (company_id)
  )`);

  await db.query(`CREATE TABLE IF NOT EXISTS company_sections (
    company_id BIGINT NOT NULL,
    section VARCHAR(80) NOT NULL,
    PRIMARY KEY (company_id, section),
    FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
  )`);

  // A previous local startup may have created the lightweight initial schema.
  // Add these legacy-compatible fields safely so existing data is preserved.
  await addColumnIfMissing(db, 'assets', 'company_name', 'VARCHAR(255) NULL');
  await addColumnIfMissing(db, 'assets', 'section', 'VARCHAR(80) NULL');
  await addColumnIfMissing(db, 'assets', 'type', 'VARCHAR(100) NULL');
  await addColumnIfMissing(db, 'assets', 'description', 'TEXT NULL');
  await addColumnIfMissing(db, 'assets', 'link', 'TEXT NULL');
  await addColumnIfMissing(db, 'assets', 'username', 'VARCHAR(255) NULL');
  await addColumnIfMissing(db, 'assets', 'password', 'TEXT NULL');
  await addColumnIfMissing(db, 'assets', 'file_url', 'VARCHAR(1000) NULL');
  await addColumnIfMissing(db, 'assets', 'file_name', 'VARCHAR(255) NULL');
  await addColumnIfMissing(db, 'assets', 'mime_type', 'VARCHAR(120) NULL');
  await addColumnIfMissing(db, 'assets', 'file_size', 'BIGINT NULL');
  await addColumnIfMissing(db, 'assets', 'created_by_employee_id', 'BIGINT NULL');
  await addColumnIfMissing(db, 'assets', 'updated_at', 'TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP');

  // Older repository installs used a fixed ENUM for section and made type
  // mandatory. That blocked new admin-defined sections and link-only assets.
  // Keep every existing value and make both fields flexible/database-driven.
  await db.query('ALTER TABLE `assets` MODIFY COLUMN `section` VARCHAR(80) NULL');
  await db.query('ALTER TABLE `assets` MODIFY COLUMN `type` VARCHAR(100) NULL');

  // asset_id must match assets.id (BIGINT UNSIGNED) and employee_id must
  // match employee_users.id (INT) exactly, or MySQL refuses the foreign key.
  await db.query(`CREATE TABLE IF NOT EXISTS asset_downloads (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    asset_id BIGINT UNSIGNED NOT NULL,
    employee_id INT NOT NULL,
    downloaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employee_users(id) ON DELETE CASCADE,
    KEY asset_downloads_asset_id_index (asset_id),
    KEY asset_downloads_employee_id_index (employee_id)
  )`);

  await db.query(`CREATE TABLE IF NOT EXISTS client_repository_access (
    employee_id INT NOT NULL PRIMARY KEY,
    granted_by INT NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    can_view TINYINT(1) NOT NULL DEFAULT 1,
    can_create TINYINT(1) NOT NULL DEFAULT 0,
    can_edit TINYINT(1) NOT NULL DEFAULT 0,
    can_delete TINYINT(1) NOT NULL DEFAULT 0,
    can_download TINYINT(1) NOT NULL DEFAULT 1,
    can_create_company TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (employee_id) REFERENCES employee_users(id) ON DELETE CASCADE
  )`);

  // Add explicit, per-user permissions to databases created by the initial
  // access-only version. Existing granted employees retain read/download
  // access; administrators configure the remaining actions from the UI.
  await addColumnIfMissing(db, 'client_repository_access', 'can_view', 'TINYINT(1) NOT NULL DEFAULT 1');
  await addColumnIfMissing(db, 'client_repository_access', 'can_create', 'TINYINT(1) NOT NULL DEFAULT 0');
  await addColumnIfMissing(db, 'client_repository_access', 'can_edit', 'TINYINT(1) NOT NULL DEFAULT 0');
  await addColumnIfMissing(db, 'client_repository_access', 'can_delete', 'TINYINT(1) NOT NULL DEFAULT 0');
  await addColumnIfMissing(db, 'client_repository_access', 'can_download', 'TINYINT(1) NOT NULL DEFAULT 1');
  await addColumnIfMissing(db, 'client_repository_access', 'can_create_company', 'TINYINT(1) NOT NULL DEFAULT 0');

  // The repository Users page stores a contact number and profile photo.
  // These are additive migrations so current employee records stay intact.
  await addColumnIfMissing(db, 'employee_users', 'mobile', 'VARCHAR(40) NULL');
  await addColumnIfMissing(db, 'employee_users', 'profile_photo_url', 'VARCHAR(500) NULL');

  // Isolated notification table for the Client Repository / Assets module.
  // Keeps assets notifications completely separate from HRMS notifications
  // so that HRMS chat, task, and planner messages never appear in the
  // assets notification bell, and vice versa.
  await db.query(`CREATE TABLE IF NOT EXISTS client_repository_notifications (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    recipient_id INT NOT NULL,
    recipient_name VARCHAR(255) NOT NULL,
    sender_name VARCHAR(255) NULL,
    message TEXT NOT NULL,
    is_seen TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (recipient_id) REFERENCES employee_users(id) ON DELETE CASCADE,
    KEY crn_recipient_id_index (recipient_id)
  )`);
}
module.exports = { ensureClientRepositoryTables };
