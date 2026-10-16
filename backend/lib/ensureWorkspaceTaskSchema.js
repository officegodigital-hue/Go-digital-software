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
