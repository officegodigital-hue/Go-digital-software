async function ensureContentCalendarWorkspaceSchema(db) {
  // Older installations created this table manually.  A new installation did
  // not have that prerequisite, so the first SHOW COLUMNS call prevented the
  // remainder of the startup migrations from running.  Keep this definition
  // deliberately independent of foreign keys: clients, employee users, and
  // task rows may be created in a different order during initial setup.
  await db.query(`
    CREATE TABLE IF NOT EXISTS content_calendar (
      id BIGINT NOT NULL AUTO_INCREMENT,
      client_id BIGINT NULL,
      client_name VARCHAR(255) NOT NULL,
      s_no INT UNSIGNED NOT NULL DEFAULT 1,
      deliverable VARCHAR(255) NOT NULL,
      hook_headline TEXT NULL,
      description LONGTEXT NULL,
      description_rich LONGTEXT NULL,
      caption LONGTEXT NULL,
      cta TEXT NULL,
      publish_date DATE NULL,
      submit_date DATE NULL,
      assigned_to_id BIGINT NULL,
      assigned_to_name VARCHAR(255) NULL,
      assigned_by_id BIGINT NULL,
      assigned_by_name VARCHAR(255) NULL,
      task_item_id BIGINT NULL,
      notes TEXT NULL,
      cc_status VARCHAR(20) NOT NULL DEFAULT 'IDLE',
      cc_duration_secs INT UNSIGNED NOT NULL DEFAULT 0,
      cc_started_at DATETIME NULL,
      cc_hold_reason TEXT NULL,
      cc_prepared_by_id BIGINT NULL,
      cc_prepared_by_name VARCHAR(255) NULL,
      cc_handoff_at DATETIME NULL,
      cc_last_activity_at DATETIME NULL,
      is_emergency TINYINT(1) NOT NULL DEFAULT 0,
      cc_emergency_reason TEXT NULL,
      cc_reassigned TINYINT(1) NOT NULL DEFAULT 0,
      cc_submit_edited TINYINT(1) NOT NULL DEFAULT 0,
      source_assignment_id BIGINT NULL,
      source_role VARCHAR(40) NULL,
      source_task_index INT UNSIGNED NULL,
      source_row_number INT UNSIGNED NULL,
      source_active TINYINT(1) NOT NULL DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      INDEX idx_content_calendar_client (client_id, s_no),
      INDEX idx_content_calendar_task_item (task_item_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  const [columns] = await db.query('SHOW COLUMNS FROM content_calendar');
  const existing = new Set(columns.map((column) => column.Field));
  const required = {
    notes: 'TEXT NULL',
    cc_status: "VARCHAR(20) NOT NULL DEFAULT 'IDLE'",
    cc_duration_secs: 'INT UNSIGNED NOT NULL DEFAULT 0',
    cc_started_at: 'DATETIME NULL',
    cc_hold_reason: 'TEXT NULL',
    cc_prepared_by_id: 'BIGINT NULL',
    cc_prepared_by_name: 'VARCHAR(255) NULL',
    cc_handoff_at: 'DATETIME NULL',
    cc_last_activity_at: 'DATETIME NULL',
    is_emergency: 'TINYINT(1) NOT NULL DEFAULT 0',
    cc_emergency_reason: 'TEXT NULL',
    source_assignment_id: 'BIGINT NULL',
    source_role: 'VARCHAR(40) NULL',
    source_task_index: 'INT UNSIGNED NULL',
    source_row_number: 'INT UNSIGNED NULL',
    source_active: 'TINYINT(1) NOT NULL DEFAULT 1',
  };

  for (const [name, definition] of Object.entries(required)) {
    if (existing.has(name)) continue;
    await db.query(`ALTER TABLE content_calendar ADD COLUMN \`${name}\` ${definition}`);
  }

  const [indexes] = await db.query('SHOW INDEX FROM content_calendar');
  if (!indexes.some((index) => index.Key_name === 'uq_content_calendar_source_row')) {
    await db.query(
      `ALTER TABLE content_calendar
       ADD UNIQUE INDEX uq_content_calendar_source_row
       (source_assignment_id, source_role, source_task_index, source_row_number)`,
    );
  }
  if (!indexes.some((index) => index.Key_name === 'idx_content_calendar_preparer_active')) {
    await db.query(
      `ALTER TABLE content_calendar
       ADD INDEX idx_content_calendar_preparer_active (cc_prepared_by_id, cc_status)`,
    );
  }
}

module.exports = { ensureContentCalendarWorkspaceSchema };
