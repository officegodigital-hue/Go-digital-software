'use strict';

// The report workflow can be deployed independently of the SQL migration.
// Create its tables on first use so opening a report draft works on existing
// installations as well as freshly provisioned databases.
async function ensureReportWorkflowSchema(db) {
  await db.query(`CREATE TABLE IF NOT EXISTS report_workflow_drafts (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    client_id INT UNSIGNED NOT NULL,
    client_name VARCHAR(255) NOT NULL,
    template_id INT UNSIGNED NOT NULL,
    employee_id INT UNSIGNED NOT NULL,
    report_name VARCHAR(255) NOT NULL,
    reporting_month DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    report_data LONGBLOB NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_report_workflow_drafts_employee (employee_id, updated_at),
    KEY idx_report_workflow_drafts_client_month (client_id, reporting_month, status)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);

  await db.query(`CREATE TABLE IF NOT EXISTS report_workflow_screenshots (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    draft_id INT UNSIGNED NOT NULL,
    original_filename VARCHAR(500) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    image_data MEDIUMBLOB NOT NULL,
    provider_name VARCHAR(100) NULL,
    provider_confidence DECIMAL(5,4) NULL,
    template_page_id INT NULL,
    ocr_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    ocr_error VARCHAR(1000) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_report_workflow_screenshots_draft (draft_id, created_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);

  await db.query(`CREATE TABLE IF NOT EXISTS report_workflow_fields (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    draft_id INT UNSIGNED NOT NULL,
    screenshot_id INT UNSIGNED NULL,
    template_page_id INT NULL,
    provider_name VARCHAR(100) NULL,
    source_label VARCHAR(255) NOT NULL,
    extracted_value TEXT NULL,
    override_label VARCHAR(255) NULL,
    override_value TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_report_workflow_fields_draft (draft_id, template_page_id),
    KEY idx_report_workflow_fields_screenshot (screenshot_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
}

let ready = null;
function ensureReportWorkflowSchemaOnce(db) {
  if (!ready) {
    ready = ensureReportWorkflowSchema(db).catch((error) => {
      ready = null;
      throw error;
    });
  }
  return ready;
}

module.exports = { ensureReportWorkflowSchema, ensureReportWorkflowSchemaOnce };
