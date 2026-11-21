'use strict';

// Admin multi-template management for the report module: upload / list /
// activate / delete PPTX templates, with slide page-titles extracted on upload.
// The active template is mirrored into report_templates(scope='EMPLOYEE_ADMIN')
// so the existing PPTX exporter (fullReportPpt.controller) keeps working.

const db = require('../config/db');
const { isAdmin } = require('../lib/reportTaskAccess');
const {
  MAX_TEMPLATE_BYTES,
  extractPowerPointTemplatePages,
  validatePowerPointTemplate,
} = require('../services/reportTemplate.service');

function requireAdmin(req, res) {
  if (!isAdmin(req.user)) {
    res.status(403).json({
      success: false,
      message: 'Only report administrators can manage report templates.',
    });
    return false;
  }
  return true;
}

// Mirror a library template's bytes into the legacy single-active row the
// exporter reads. Keeps old and new systems consistent.
async function syncActiveToLegacy(templateId, actorId) {
  const [[row]] = await db.query(
    'SELECT original_filename, template_data FROM report_template_library WHERE id = ? LIMIT 1',
    [templateId],
  );
  if (!row) return;
  await db.query(
    `INSERT INTO report_templates (scope, file_name, template_data, uploaded_by_user_id)
     VALUES ('EMPLOYEE_ADMIN', ?, ?, ?)
     ON DUPLICATE KEY UPDATE file_name = VALUES(file_name),
       template_data = VALUES(template_data), uploaded_by_user_id = VALUES(uploaded_by_user_id)`,
    [String(row.original_filename).slice(0, 500), row.template_data, actorId || null],
  );
}

async function listTemplates(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const [rows] = await db.query(
      `SELECT l.id, l.name, l.original_filename, l.file_format, l.file_size,
              l.is_active, l.created_at,
              (SELECT COUNT(*) FROM report_template_pages p WHERE p.template_id = l.id) AS page_count
       FROM report_template_library l
       ORDER BY l.is_active DESC, l.created_at DESC`,
    );
    return res.json({ success: true, templates: rows });
  } catch (error) {
    console.error('listTemplates error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load report templates.' });
  }
}

async function uploadTemplate(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const data = req.body?.bytesBase64
      ? Buffer.from(String(req.body.bytesBase64), 'base64')
      : null;
    if (!data || !data.length) {
      return res.status(400).json({ success: false, message: 'No template file was provided.' });
    }
    const originalFilename = String(req.body?.fileName || 'report-template.pptx').slice(0, 500);
    if (!/\.pptx$/i.test(originalFilename)) {
      return res.status(400).json({ success: false, message: 'The report template must be a .pptx file.' });
    }
    if (data.length > MAX_TEMPLATE_BYTES) {
      return res.status(413).json({ success: false, message: 'The report template must be 10 MB or smaller.' });
    }
    try {
      await validatePowerPointTemplate(data);
    } catch (error) {
      return res.status(400).json({ success: false, message: error.message });
    }

    let pages = [];
    try {
      pages = await extractPowerPointTemplatePages(data);
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: `Could not read slide pages from the template: ${error.message}`,
      });
    }

    const name = req.body?.name
      ? String(req.body.name).trim().slice(0, 255)
      : originalFilename.replace(/\.pptx$/i, '');

    // First template auto-activates; otherwise honour the activate flag.
    const [[existingActive]] = await db.query(
      'SELECT COUNT(*) AS n FROM report_template_library WHERE is_active = 1',
    );
    const activate = req.body?.activate === true || Number(existingActive.n) === 0;

    const [created] = await db.query(
      `INSERT INTO report_template_library
         (name, original_filename, file_format, file_size, template_data, is_active, uploaded_by_user_id)
       VALUES (?,?,?,?,?,?,?)`,
      [name, originalFilename, 'pptx', data.length, data, activate ? 1 : 0, req.user?.id || null],
    );
    const templateId = created.insertId;

    for (const [index, page] of pages.entries()) {
      await db.query(
        `INSERT INTO report_template_pages
           (template_id, page_order, page_title, provider_code, required_static)
         VALUES (?,?,?,?,?)`,
        [
          templateId,
          index + 1,
          String(page.page_title || `Report page ${index + 1}`).slice(0, 500),
          page.provider_code ? String(page.provider_code).slice(0, 120) : null,
          page.required_static ? 1 : 0,
        ],
      );
    }

    if (activate) {
      await db.query('UPDATE report_template_library SET is_active = 0 WHERE id <> ?', [templateId]);
      await syncActiveToLegacy(templateId, req.user?.id);
    }

    return res.status(201).json({ success: true, id: templateId, pageCount: pages.length, active: activate });
  } catch (error) {
    console.error('uploadTemplate error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to save the report template.' });
  }
}

async function activateTemplate(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const id = Number(req.params.id);
    const [[row]] = await db.query(
      'SELECT id FROM report_template_library WHERE id = ? LIMIT 1',
      [id],
    );
    if (!row) return res.status(404).json({ success: false, message: 'Template not found.' });
    await db.query('UPDATE report_template_library SET is_active = (id = ?)', [id]);
    await syncActiveToLegacy(id, req.user?.id);
    return res.json({ success: true });
  } catch (error) {
    console.error('activateTemplate error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to activate the template.' });
  }
}

async function deleteTemplate(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    const id = Number(req.params.id);
    const [[row]] = await db.query(
      'SELECT is_active FROM report_template_library WHERE id = ? LIMIT 1',
      [id],
    );
    if (!row) return res.status(404).json({ success: false, message: 'Template not found.' });
    await db.query('DELETE FROM report_template_pages WHERE template_id = ?', [id]);
    await db.query('DELETE FROM report_template_library WHERE id = ?', [id]);
    // If the active template was removed, promote the newest remaining one.
    if (row.is_active === 1) {
      const [[next]] = await db.query(
        'SELECT id FROM report_template_library ORDER BY created_at DESC LIMIT 1',
      );
      if (next) {
        await db.query('UPDATE report_template_library SET is_active = (id = ?)', [next.id]);
        await syncActiveToLegacy(next.id, req.user?.id);
      }
    }
    return res.json({ success: true });
  } catch (error) {
    console.error('deleteTemplate error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to delete the template.' });
  }
}

// Page titles for a template (defaults to the active one) — used by the
// workspace so it shows only pages that exist in the PPTX.
async function getTemplatePages(req, res) {
  try {
    let templateId = Number(req.params.id);
    if (!Number.isSafeInteger(templateId) || templateId < 1) {
      const [[active]] = await db.query(
        'SELECT id FROM report_template_library WHERE is_active = 1 ORDER BY created_at DESC LIMIT 1',
      );
      templateId = active ? active.id : 0;
    }
    if (!templateId) return res.json({ success: true, pages: [] });
    const [pages] = await db.query(
      `SELECT page_order, page_title, provider_code, required_static
       FROM report_template_pages WHERE template_id = ? ORDER BY page_order`,
      [templateId],
    );
    return res.json({ success: true, templateId, pages });
  } catch (error) {
    console.error('getTemplatePages error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load template pages.' });
  }
}

module.exports = {
  listTemplates,
  uploadTemplate,
  activateTemplate,
  deleteTemplate,
  getTemplatePages,
};
