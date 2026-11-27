// backend/lib/ensureIndexes.js
//
// Adds the database indexes the hot read paths need (Employee Workspace cards,
// task review, live tracking, meeting scheduler, notifications). Without these,
// the frequent JOINs/filters do full-table scans, which is the usual reason a
// MySQL-backed server sits at 100% CPU and pages load slowly.
//
// Safe to run on every boot:
//   • skips tables / columns that don't exist in this database,
//   • skips an index that already exists (by name),
//   • for single-column indexes, also skips when that column already leads some
//     other index (e.g. a foreign-key index), so we never create duplicates,
//   • each ALTER is wrapped in try/catch and only logs on failure.
//
// InnoDB ADD INDEX is online in MySQL 5.6+, so this does not block writes.

const db = require('../config/db');

// [table, indexName, [columns...]] — ordered by impact.
const INDEXES = [
  // Employee Workspace / Task Review hot JOINs & filters
  ['time_tracking_task_items', 'idx_tti_task_list_id', ['task_list_id']],
  ['time_tracking_task_items', 'idx_tti_parent_item_id', ['parent_item_id']],
  ['time_tracking_task_items', 'idx_tti_status', ['status']],
  ['task_list', 'idx_tl_task_assignment_id', ['task_assignment_id']],
  ['task_list', 'idx_tl_additional_task_id', ['additional_task_id']],
  ['task_list', 'idx_tl_client_name', ['client_name']],
  ['task_assignments', 'idx_ta_client_name', ['client_name']],
  ['task_assignments', 'idx_ta_is_assigned', ['is_assigned']],
  ['manager_review', 'idx_mr_tracking_item_id', ['tracking_item_id']],
  ['content_calendar', 'idx_cc_task_item_id', ['task_item_id']],
  ['clients', 'idx_clients_is_active', ['is_active']],
  ['workspace_client_chat', 'idx_wcc_client_name', ['client_name']],

  // Meeting scheduler sweep (runs on a timer) + live sessions
  ['scheduled_meetings', 'idx_sm_status_end_at', ['status', 'end_at']],
  ['meeting_tracking_sessions', 'idx_mts_meeting_id', ['meeting_id']],
  ['meeting_tracking_sessions', 'idx_mts_employee_name', ['employee_name']],
  ['meeting_participants', 'idx_mp_meeting_id', ['meeting_id']],
];

// Many workspace queries filter on `LOWER(TRIM(client_name)) = LOWER(TRIM(?))`.
// A plain index on client_name can't serve that, so these expression indexes
// match the exact predicate. Expression indexes need MySQL 8.0.13+ — on older
// servers the ALTER throws and is logged + skipped (the app still works).
// [table, indexName, expression, baseColumnForExistenceCheck]
const FUNCTIONAL_INDEXES = [
  ['task_list', 'idx_tl_client_name_norm', 'LOWER(TRIM(`client_name`))', 'client_name'],
  ['task_assignments', 'idx_ta_client_name_norm', 'LOWER(TRIM(`client_name`))', 'client_name'],
  ['employee_users', 'idx_eu_full_name_norm', 'LOWER(TRIM(`full_name`))', 'full_name'],
];

async function tableExists(table) {
  const [r] = await db.query(
    `SELECT COUNT(*) AS c FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?`,
    [table],
  );
  return r[0].c > 0;
}

async function columnExists(table, column) {
  const [r] = await db.query(
    `SELECT COUNT(*) AS c FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [table, column],
  );
  return r[0].c > 0;
}

async function indexExists(table, indexName) {
  const [r] = await db.query(
    `SELECT COUNT(*) AS c FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?`,
    [table, indexName],
  );
  return r[0].c > 0;
}

// Does some index already start with this column? (first column, SEQ_IN_INDEX = 1)
async function leadingIndexExists(table, column) {
  const [r] = await db.query(
    `SELECT COUNT(*) AS c FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
        AND COLUMN_NAME = ? AND SEQ_IN_INDEX = 1`,
    [table, column],
  );
  return r[0].c > 0;
}

async function ensureOne(table, indexName, cols) {
  if (!(await tableExists(table))) return 'no-table';
  for (const c of cols) {
    if (!(await columnExists(table, c))) return 'no-column';
  }
  if (await indexExists(table, indexName)) return 'exists';
  // Avoid duplicating a single-column index that another index already covers.
  if (cols.length === 1 && (await leadingIndexExists(table, cols[0]))) {
    return 'already-indexed';
  }
  const colSql = cols.map((c) => `\`${c}\``).join(', ');
  await db.query(`ALTER TABLE \`${table}\` ADD INDEX \`${indexName}\` (${colSql})`);
  return 'created';
}

async function ensureFunctional(table, indexName, expression, baseColumn) {
  if (!(await tableExists(table))) return 'no-table';
  if (!(await columnExists(table, baseColumn))) return 'no-column';
  if (await indexExists(table, indexName)) return 'exists';
  await db.query(`ALTER TABLE \`${table}\` ADD INDEX \`${indexName}\` ((${expression}))`);
  return 'created';
}

async function ensureIndexes() {
  let created = 0;
  for (const [table, indexName, cols] of INDEXES) {
    try {
      const result = await ensureOne(table, indexName, cols);
      if (result === 'created') {
        created += 1;
        console.log(`[ensureIndexes] + ${indexName} on ${table}(${cols.join(', ')})`);
      }
    } catch (err) {
      console.error(`[ensureIndexes] ${indexName} on ${table} failed:`, err.message);
    }
  }
  // Expression indexes only exist on MySQL 8.0.13+. MariaDB (and older MySQL)
  // don't support them, so skip the whole set there with a single line instead
  // of a failing ALTER per index on every boot.
  let supportsFunctional = false;
  try {
    const [[v]] = await db.query('SELECT VERSION() AS v');
    const version = String(v.v || '');
    if (!/mariadb/i.test(version)) {
      const m = version.match(/^(\d+)\.(\d+)\.(\d+)/);
      if (m) {
        const [maj, min, patch] = [+m[1], +m[2], +m[3]];
        supportsFunctional =
          maj > 8 || (maj === 8 && (min > 0 || (min === 0 && patch >= 13)));
      }
    }
    if (!supportsFunctional) {
      console.log(
        `[ensureIndexes] expression indexes not supported on ${version || 'this server'} — skipping ${FUNCTIONAL_INDEXES.length}.`,
      );
    }
  } catch (_) {
    supportsFunctional = false;
  }
  if (supportsFunctional) {
    for (const [table, indexName, expr, baseColumn] of FUNCTIONAL_INDEXES) {
      try {
        const result = await ensureFunctional(table, indexName, expr, baseColumn);
        if (result === 'created') {
          created += 1;
          console.log(`[ensureIndexes] + ${indexName} on ${table}((${expr}))`);
        }
      } catch (err) {
        console.error(`[ensureIndexes] functional ${indexName} on ${table} skipped:`, err.message);
      }
    }
  }
  if (created > 0) {
    console.log(`[ensureIndexes] created ${created} new index(es).`);
  } else {
    console.log('[ensureIndexes] all performance indexes already present.');
  }
  return created;
}

let done;
function ensureIndexesOnce() {
  if (!done) {
    done = ensureIndexes().catch((err) => {
      done = null;
      throw err;
    });
  }
  return done;
}

module.exports = { ensureIndexes, ensureIndexesOnce };
