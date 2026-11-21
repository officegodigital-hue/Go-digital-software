'use strict';

// Multi-template library for the report module. The existing single-active
// template the exporter reads still lives in `report_templates`
// (scope='EMPLOYEE_ADMIN'); activating a library template syncs its bytes into
// that row, so the PPTX exporter keeps working unchanged. Page titles are
// extracted from the PPTX on upload and stored so the workspace can show only
// the pages that actually exist in the active template.
async function ensureReportTemplateSchema(db) {
  await db.query(`CREATE TABLE IF NOT EXISTS report_template_library (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    original_filename VARCHAR(500) NOT NULL,
    file_format VARCHAR(20) NOT NULL DEFAULT 'pptx',
    file_size BIGINT NOT NULL DEFAULT 0,
    template_data LONGBLOB NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 0,
    uploaded_by_user_id INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_report_template_active (is_active)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`);

  await db.query(`CREATE TABLE IF NOT EXISTS report_template_pages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    template_id BIGINT UNSIGNED NOT NULL,
    page_order INT NOT NULL DEFAULT 0,
    page_title VARCHAR(500) NOT NULL,
    provider_code VARCHAR(120) NULL,
    required_static TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_report_template_page (template_id, page_order)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`);
}

module.exports = { ensureReportTemplateSchema };
