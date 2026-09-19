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
  await addColumnIfMissing(db, 'assets', 'link', 'TEXT NULL');
  await addColumnIfMissing(db, 'assets', 'username', 'VARCHAR(255) NULL');
  await addColumnIfMissing(db, 'assets', 'password', 'TEXT NULL');

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
    FOREIGN KEY (employee_id) REFERENCES employee_users(id) ON DELETE CASCADE
  )`);
}
module.exports = { ensureClientRepositoryTables };
