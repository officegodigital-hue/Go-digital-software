'use strict';

// Report-module-owned client + assignment tables. Kept separate from the
// Task Manager's `clients` / `task_assignments` so the report module can manage
// its own client logos, business category, employee assignment and provider
// assignment without touching the task-manager schema. Logos continue to live
// in the existing `client_profiles` table (keyed by company_name).
//
// Employee visibility for reports is the UNION of these assignments and the
// existing Task Manager assignments (see lib/reportTaskAccess.js), so nothing
// that currently works is lost.
async function ensureReportClientSchema(db) {
  // NOTE: these tables MUST use the database's default collation (same as the
  // shared client_profiles / client_full_report_history tables, which are
  // created with a bare `DEFAULT CHARSET=utf8mb4`). Previously these two tables
  // forced `COLLATE utf8mb4_general_ci`; on a MySQL 8 server the shared tables
  // default to `utf8mb4_0900_ai_ci`, so joining report_clients.company_name to
  // client_profiles.company_name threw "Illegal mix of collations". We now omit
  // the explicit COLLATE so fresh installs match, and normalizeCollation() below
  // repairs any already-created tables that still carry the old collation.
  await db.query(`CREATE TABLE IF NOT EXISTS report_clients (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL,
    business_category VARCHAR(255) NULL,
    created_by_user_id INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_report_client_name (company_name)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);

  // One row per (client, employee). `providers` holds a JSON array of provider
  // keys (e.g. ["google_ads","meta_ads"]). `active` = current assignment.
  await db.query(`CREATE TABLE IF NOT EXISTS report_client_assignments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL,
    employee_id INT NOT NULL,
    employee_name VARCHAR(255) NULL,
    providers TEXT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    assigned_by_user_id INT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP NULL,
    UNIQUE KEY uq_report_assignment (company_name, employee_id),
    KEY idx_report_assignment_emp (employee_id, active),
    KEY idx_report_assignment_company (company_name, active)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);

  await normalizeCollation(db, ['report_clients', 'report_client_assignments']);
}

// Convert the given tables to the database's default collation when they differ,
// so cross-table string comparisons (company_name joins) never hit MySQL 8's
// "Illegal mix of collations" error. Idempotent: the ALTER only runs when a
// table's collation actually differs, so normal restarts do no work. Wrapped so
// a missing ALTER privilege degrades gracefully (the query-level COLLATE in the
// controller is the fallback).
async function normalizeCollation(db, tables) {
  try {
    const [[schema]] = await db.query(
      `SELECT DEFAULT_COLLATION_NAME AS coll
         FROM information_schema.SCHEMATA
        WHERE SCHEMA_NAME = DATABASE()`,
    );
    const targetCollation = schema && schema.coll;
    if (!targetCollation) return;

    for (const table of tables) {
      const [[row]] = await db.query(
        `SELECT TABLE_COLLATION AS coll
           FROM information_schema.TABLES
          WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?`,
        [table],
      );
      if (row && row.coll && row.coll !== targetCollation) {
        await db.query(
          `ALTER TABLE \`${table}\` CONVERT TO CHARACTER SET utf8mb4 COLLATE \`${targetCollation}\``,
        );
        console.log(
          `Report schema: converted ${table} collation ${row.coll} -> ${targetCollation}`,
        );
      }
    }
  } catch (error) {
    console.error('Report schema: collation normalization skipped:', error.message);
  }
}

module.exports = { ensureReportClientSchema };
