// lib/ensureMeetingSchema.js
// Adds the columns/tables the Meeting Scheduling + background Live-Tracking
// workflow needs. Safe to run on every startup — it only creates what is
// missing and never drops or rewrites existing data. Mirrors the pattern used
// by lib/ensureWorkspaceTaskSchema.js.

async function columnInfo(db, table) {
  const [rows] = await db.query(
    `SELECT COLUMN_NAME FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?`,
    [table],
  );
  return new Set(rows.map((r) => r.COLUMN_NAME));
}

async function tableExists(db, table) {
  const [rows] = await db.query(
    `SELECT 1 FROM information_schema.TABLES
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? LIMIT 1`,
    [table],
  );
  return rows.length > 0;
}

async function ensureMeetingSchema(db) {
  // ── scheduled_meetings: add the scheduling / lifecycle columns ────────────
  if (await tableExists(db, 'scheduled_meetings')) {
    const cols = await columnInfo(db, 'scheduled_meetings');
    const wanted = [
      ['organizer_id', 'INT NULL'],
      ['start_at', 'DATETIME NULL'],
      ['end_at', 'DATETIME NULL'],
      ['duration_mins', 'INT NULL'],
      ['meeting_details', 'TEXT NULL'],
      ['started_at', 'DATETIME NULL'],
      ['completed_at', 'DATETIME NULL'],
    ];
    for (const [name, definition] of wanted) {
      if (!cols.has(name)) {
        await db.query(`ALTER TABLE scheduled_meetings ADD COLUMN \`${name}\` ${definition}`);
        console.log(`Meeting schema: added scheduled_meetings.${name}`);
      }
    }
    const [[status]] = await db.query(
      "SELECT COLUMN_TYPE, COLUMN_DEFAULT, IS_NULLABLE FROM information_schema.COLUMNS " +
      "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'scheduled_meetings' AND COLUMN_NAME = 'status'",
    );
    if (status && /^enum\(/i.test(status.COLUMN_TYPE) && !/'Scheduled'/i.test(status.COLUMN_TYPE)) {
      const type = status.COLUMN_TYPE.slice(0, -1) + ",'Scheduled')";
      const nullable = status.IS_NULLABLE === 'YES' ? ' NULL' : ' NOT NULL';
      const defaultClause = status.COLUMN_DEFAULT == null ? '' : ' DEFAULT ' + db.escape(status.COLUMN_DEFAULT);
      await db.query('ALTER TABLE scheduled_meetings MODIFY COLUMN status ' + type + nullable + defaultClause);
    }
  } else {
    // Fresh database: create the full table up front so every column exists.
    await db.query(
      `CREATE TABLE IF NOT EXISTS scheduled_meetings (
         id INT AUTO_INCREMENT PRIMARY KEY,
         title VARCHAR(255) NOT NULL,
         meeting_time VARCHAR(255) NULL,
         meeting_link TEXT NULL,
         host_name VARCHAR(255) NULL,
         organizer_id INT NULL,
         attendees LONGTEXT NULL,
         \`groups\` LONGTEXT NULL,
         status VARCHAR(20) NOT NULL DEFAULT 'Scheduled',
         start_at DATETIME NULL,
         end_at DATETIME NULL,
         duration_mins INT NULL,
         meeting_details TEXT NULL,
         started_at DATETIME NULL,
         completed_at DATETIME NULL,
         created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
       )`,
    );
    console.log('Meeting schema: created scheduled_meetings');
  }

  // ── meeting_participants: expanded, de-duplicated participant list ────────
  // UNIQUE(meeting_id, employee_name) is what prevents a duplicate assignment
  // when someone is selected individually AND through one or more groups.
  await db.query(
    `CREATE TABLE IF NOT EXISTS meeting_participants (
       id INT AUTO_INCREMENT PRIMARY KEY,
       meeting_id INT NOT NULL,
       employee_name VARCHAR(255) NOT NULL,
       source VARCHAR(20) NOT NULL DEFAULT 'individual',
       source_group VARCHAR(255) NULL,
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       UNIQUE KEY uq_meeting_emp (meeting_id, employee_name),
       INDEX idx_mp_meeting (meeting_id),
       INDEX idx_mp_emp (employee_name)
     )`,
  );

  // ── meeting_tracking_sessions: background tracking, one per participant ────
  // Deliberately separate from time_tracking_task_items so task start/hold/
  // complete (and autoHoldOtherEmployeeTasks) can never touch a meeting.
  // UNIQUE(meeting_id, employee_name) guarantees no duplicate tracking rows.
  await db.query(
    `CREATE TABLE IF NOT EXISTS meeting_tracking_sessions (
       id INT AUTO_INCREMENT PRIMARY KEY,
       meeting_id INT NOT NULL,
       employee_name VARCHAR(255) NOT NULL,
       status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
       scheduled_start DATETIME NULL,
       scheduled_end DATETIME NULL,
       started_at DATETIME NULL,
       active_since DATETIME NULL,
       tracked_intervals JSON NULL,
       ended_at DATETIME NULL,
       duration_secs INT NOT NULL DEFAULT 0,
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
       UNIQUE KEY uq_mts (meeting_id, employee_name),
       INDEX idx_mts_emp (employee_name, status),
       INDEX idx_mts_meeting (meeting_id)
     )`,
  );
  const sessionColumns = await columnInfo(db, 'meeting_tracking_sessions');
  if (!sessionColumns.has('tracked_intervals')) {
    await db.query('ALTER TABLE meeting_tracking_sessions ADD COLUMN tracked_intervals JSON NULL');
  }
  if (!sessionColumns.has('active_since')) {
    await db.query('ALTER TABLE meeting_tracking_sessions ADD COLUMN active_since DATETIME NULL');
  }
}

let ready = null;
function ensureMeetingSchemaOnce(db) {
  if (!ready) {
    ready = ensureMeetingSchema(db).catch((err) => {
      ready = null; // retry on next call
      throw err;
    });
  }
  return ready;
}

module.exports = { ensureMeetingSchema, ensureMeetingSchemaOnce };
