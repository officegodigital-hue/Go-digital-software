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
  await db.query(`CREATE TABLE IF NOT EXISTS report_clients (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL,
    business_category VARCHAR(255) NULL,
    created_by_user_id INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_report_client_name (company_name)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`);

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
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`);
}

module.exports = { ensureReportClientSchema };
