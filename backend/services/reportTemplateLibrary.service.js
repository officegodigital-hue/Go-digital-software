'use strict';

const db = require('../config/db');

async function findActiveReportTemplate() {
  const [rows] = await db.query(
    `SELECT id, name, original_filename, file_format, version, template_data,
            created_at
     FROM report_template_library
     WHERE is_active = 1
     ORDER BY created_at DESC, id DESC
     LIMIT 1`,
  );
  return rows[0] || null;
}

async function findReportTemplateById(id) {
  const [rows] = await db.query(
    `SELECT id, name, original_filename, file_format, version, template_data,
            created_at
     FROM report_template_library WHERE id = ? LIMIT 1`,
    [id],
  );
  return rows[0] || null;
}

module.exports = {
  findActiveReportTemplate,
  findReportTemplateById,
};
