// lib/ensureWorkspaceTaskSchema.js
// Adds the columns/indexes the Employee Workspace (My Tasks, nested Ads rows,
// Task Review) needs. Safe to run on every startup — it only changes what is
// missing.
async function columnInfo(db, table) {
  const [rows] = await db.query(
    `SELECT COLUMN_NAME, DATA_TYPE FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?`,
    [table],
  );
  return new Map(rows.map((r) => [r.COLUMN_NAME, String(r.DATA_TYPE).toLowerCase()]));
}

async function indexes(db, table) {
  const [rows] = await db.query(
    `SELECT INDEX_NAME, NON_UNIQUE, COLUMN_NAME, SEQ_IN_INDEX
     FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
     ORDER BY INDEX_NAME, SEQ_IN_INDEX`,
    [table],
  );
  const map = new Map();
  for (const r of rows) {
    const entry = map.get(r.INDEX_NAME) || { unique: Number(r.NON_UNIQUE) === 0, columns: [] };
    entry.columns.push(r.COLUMN_NAME);
    map.set(r.INDEX_NAME, entry);
  }
  return map;
}

async function ensureWorkspaceTaskSchema(db) {
  const T = 'time_tracking_task_items';
  const cols = await columnInfo(db, T);

  const wanted = [
    ['parent_item_id', 'INT NULL'],
    ['sub_no', 'INT NOT NULL DEFAULT 0'],
    ['review_status', 'VARCHAR(20) NULL'],
    ['content_calendar_assigned', 'TINYINT(1) NOT NULL DEFAULT 0'],
    // "Confirm & Share All" (Content Calendar → employee) writes these.
    ['content_calendar_assigned_to', 'VARCHAR(255) NULL'],
    ['cc_assigned_to_id', 'INT NULL'],
    ['cc_assigned_by_name', 'VARCHAR(255) NULL'],
    ['cc_assigned_at', 'DATETIME NULL'],
    ['hook_headline', 'TEXT NULL'],
    ['description_points', 'TEXT NULL'],
    ['caption', 'TEXT NULL'],
    ['cta', 'TEXT NULL'],
    ['notes', 'TEXT NULL'],
    ['employee_notes', 'TEXT NULL'],
    ['description_rich', 'LONGTEXT NULL'],
    ['publish_date', 'DATE NULL'],
  ];
  for (const [name, definition] of wanted) {
    if (!cols.has(name)) {
      await db.query(`ALTER TABLE ${T} ADD COLUMN \`${name}\` ${definition}`);
      console.log(`Workspace schema: added ${T}.${name}`);
    }
  }

  // Content Calendar: formatted description (website designer) and a flag so
  // the admin-assignment sync does not undo a manual row reassignment.
  const ccCols = await columnInfo(db, 'content_calendar');
  if (ccCols.size) {
    for (const [name, definition] of [
      ['description_rich', 'LONGTEXT NULL'],
      ['cc_reassigned', 'TINYINT(1) NOT NULL DEFAULT 0'],
      // 1 = the handler picked this submit date; the assignment sync keeps it.
      ['cc_submit_edited', 'TINYINT(1) NOT NULL DEFAULT 0'],
    ]) {
      if (!ccCols.has(name)) {
        await db.query(`ALTER TABLE content_calendar ADD COLUMN \`${name}\` ${definition}`);
        console.log(`Workspace schema: added content_calendar.${name}`);
      }
    }
  }

  // day_plan_rows.maintenance_date: on some servers this is a short text
  // column and MySQL strict mode (usually on in production) rejects longer
  // values with "Data too long for column 'maintenance_date'". Widen it once.
  try {
    const [[mcol]] = await db.query(
      `SELECT DATA_TYPE AS t, CHARACTER_MAXIMUM_LENGTH AS len, IS_NULLABLE AS n
       FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'day_plan_rows'
         AND COLUMN_NAME = 'maintenance_date'`,
    );
    if (mcol && ['varchar', 'char'].includes(String(mcol.t).toLowerCase()) && Number(mcol.len) < 40) {
      await db.query('ALTER TABLE day_plan_rows MODIFY maintenance_date VARCHAR(40) NULL');
      console.log('Workspace schema: day_plan_rows.maintenance_date widened to VARCHAR(40)');
    }
  } catch (err) {
    console.warn('Workspace schema: maintenance_date check skipped:', err.message);
  }

  // Older "Add content" rows (not from the admin's Task Assignment) were put
  // in a plain list, so Employee Workspace never showed them. Mark those lists
  // as additional work (once; safe to repeat).
  try {
    const [fixed] = await db.query(
      `UPDATE task_list tl
       SET tl.additional_task_id = tl.id,
           tl.submission_date = COALESCE(tl.submission_date, (
             SELECT MIN(cc.submit_date) FROM content_calendar cc
             JOIN time_tracking_task_items tti ON tti.id = cc.task_item_id
             WHERE tti.task_list_id = tl.id), DATE(NOW()))
       WHERE tl.task_assignment_id IS NULL AND tl.additional_task_id IS NULL
         AND EXISTS (
           SELECT 1 FROM time_tracking_task_items tti
           JOIN content_calendar cc ON cc.task_item_id = tti.id
           WHERE tti.task_list_id = tl.id AND cc.source_assignment_id IS NULL)`,
    );
    if (fixed.affectedRows) {
      console.log(`Workspace schema: ${fixed.affectedRows} "Add content" list(s) marked as additional tasks`);
    }
    await db.query(
      `UPDATE time_tracking_task_items tti
       JOIN content_calendar cc ON cc.task_item_id = tti.id
       SET tti.content_calendar_assigned = 1,
           tti.content_calendar_assigned_to = COALESCE(tti.content_calendar_assigned_to, cc.assigned_to_name),
           tti.cc_assigned_by_name = COALESCE(tti.cc_assigned_by_name, cc.assigned_by_name),
           tti.hook_headline = COALESCE(NULLIF(tti.hook_headline, ''), cc.hook_headline)
       WHERE cc.source_assignment_id IS NULL AND cc.assigned_to_id IS NOT NULL
         AND COALESCE(tti.content_calendar_assigned, 0) = 0`,
    );
  } catch (err) {
    console.warn('Workspace schema: additional-list fix skipped:', err.message);
  }

  // Client group chat (Employee Workspace → Team Chat)
  await db.query(
    `CREATE TABLE IF NOT EXISTS workspace_client_chat (
       id INT AUTO_INCREMENT PRIMARY KEY,
       client_name VARCHAR(255) NOT NULL,
       sender_name VARCHAR(255) NOT NULL,
       message TEXT NOT NULL,
       created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       INDEX idx_wcc_client (client_name, id)
     )`,
  );

  // status must accept 'REWORK'
  if (cols.get('status') === 'enum') {
    await db.query(`ALTER TABLE ${T} MODIFY status VARCHAR(20) NOT NULL DEFAULT 'IDLE'`);
    console.log(`Workspace schema: ${T}.status changed to VARCHAR(20)`);
  }

  const idx = await indexes(db, T);
  if (![...idx.values()].some((i) => i.columns[0] === 'parent_item_id')) {
    await db.query(`ALTER TABLE ${T} ADD INDEX idx_tti_parent (parent_item_id)`);
  }
  // A unique key on (task_list_id, s_no) would block nested rows 1.1, 1.2 …
  for (const [name, info] of idx) {
    if (info.unique && info.columns.length === 2 &&
        info.columns.includes('task_list_id') && info.columns.includes('s_no')) {
      await db.query(
        `ALTER TABLE ${T} DROP INDEX \`${name}\`,
         ADD UNIQUE KEY uq_tti_row (task_list_id, s_no, sub_no)`,
      );
      console.log(`Workspace schema: widened unique key ${name} to include sub_no`);
    }
  }

  // One manager_review row per tracking item (skipped if old duplicates exist)
  const mrIdx = await indexes(db, 'manager_review');
  const hasUnique = [...mrIdx.values()].some(
    (i) => i.unique && i.columns.length === 1 && i.columns[0] === 'tracking_item_id',
  );
  if (!hasUnique) {
    try {
      await db.query('ALTER TABLE manager_review ADD UNIQUE KEY uq_mr_item (tracking_item_id)');
    } catch (err) {
      console.warn('Workspace schema: manager_review unique key skipped:', err.message);
    }
  }
}

let ready = null;
function ensureWorkspaceTaskSchemaOnce(db) {
  if (!ready) {
    ready = ensureWorkspaceTaskSchema(db).catch((err) => {
      ready = null; // retry on next call
      throw err;
    });
  }
  return ready;
}

module.exports = { ensureWorkspaceTaskSchema, ensureWorkspaceTaskSchemaOnce };
