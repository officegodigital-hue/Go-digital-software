'use strict';

const {
  extractPowerPointTemplatePages,
} = require('../services/reportTemplate.service');

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
    version INT UNSIGNED NOT NULL DEFAULT 1,
    uploaded_by_user_id INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_report_template_active (is_active)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`);

  const [templateColumns] = await db.query(
    "SHOW COLUMNS FROM report_template_library LIKE 'version'",
  );
  if (!templateColumns.length) {
    await db.query(
      'ALTER TABLE report_template_library ADD COLUMN version INT UNSIGNED NOT NULL DEFAULT 1',
    );
  }

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

  const [[existing]] = await db.query(
    'SELECT COUNT(*) AS count FROM report_template_library',
  );
  if (Number(existing.count) > 0) return;
  const [[legacy]] = await db.query(
    `SELECT file_name, template_data, uploaded_by_user_id
     FROM report_templates WHERE scope = ? LIMIT 1`,
    ['EMPLOYEE_ADMIN'],
  );
  if (!legacy) return;

  const templateBytes = Buffer.from(legacy.template_data);
  const pages = await extractPowerPointTemplatePages(templateBytes);
  const [created] = await db.query(
    `INSERT INTO report_template_library
       (name, original_filename, file_format, file_size, template_data,
        is_active, version, uploaded_by_user_id)
     VALUES (?, ?, 'pptx', ?, ?, 1, 1, ?)`,
    [
      String(legacy.file_name).replace(/\.pptx$/i, '').slice(0, 255),
      String(legacy.file_name).slice(0, 500),
      templateBytes.length,
      templateBytes,
      legacy.uploaded_by_user_id || null,
    ],
  );
  for (const [index, page] of pages.entries()) {
    await db.query(
      `INSERT INTO report_template_pages
         (template_id, page_order, page_title, provider_code, required_static)
       VALUES (?, ?, ?, ?, ?)`,
      [
        created.insertId,
        index + 1,
        page.page_title,
        page.provider_code || null,
        page.required_static ? 1 : 0,
      ],
    );
  }
}

module.exports = { ensureReportTemplateSchema };
