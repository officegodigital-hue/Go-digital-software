async function ensureContentCalendarWorkspaceSchema(db) {
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
