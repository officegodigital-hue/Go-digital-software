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
  extractPowerPointTemplateFields,
  renderPowerPointTemplatePreview,
  validatePowerPointTemplate,
} = require('../services/reportTemplate.service');
const {
  findActiveReportTemplate,
  findReportTemplateById,
} = require('../services/reportTemplateLibrary.service');
const { ensureReportTemplateSchema } = require('../lib/ensureReportTemplateSchema');
const { ensureFullReportExportSchema } = require('../lib/ensureFullReportExportSchema');

let schemaReady;
async function ensureSchema() {
  if (!schemaReady) {
    schemaReady = ensureFullReportExportSchema(db)
      .then(() => ensureReportTemplateSchema(db))
      .catch((error) => {
        schemaReady = null;
        throw error;
      });
  }
  return schemaReady;
}

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

// The report module authenticates employees through employee_users, while
// older report_templates installations can retain a foreign key to users.id.
// Only write the legacy audit field when the current ID exists in that table.
// The template itself remains fully usable when the two account tables are
// not synchronized.
async function legacyUploaderId(queryable, employeeUserId) {
  const id = Number(employeeUserId);
  if (!Number.isSafeInteger(id) || id < 1) return null;
  try {
    const [rows] = await queryable.query(
      'SELECT id FROM users WHERE id = ? LIMIT 1',
      [id],
    );
    return rows[0] ? id : null;
  } catch (error) {
    // Some deployments no longer have the legacy users table or its foreign
    // key. In either case, omitting this optional audit value is safe.
    if (error?.code === 'ER_NO_SUCH_TABLE') return null;
    throw error;
  }
}

// Mirror a library template's bytes into the legacy single-active row the
// exporter reads. Keeps old and new systems consistent.
async function syncActiveToLegacy(templateId, actorId) {
  const [[row]] = await db.query(
    'SELECT original_filename, template_data FROM report_template_library WHERE id = ? LIMIT 1',
    [templateId],
  );
  if (!row) return;
  const uploadedByUserId = await legacyUploaderId(db, actorId);
  await db.query(
    `INSERT INTO report_templates (scope, file_name, template_data, uploaded_by_user_id)
     VALUES ('EMPLOYEE_ADMIN', ?, ?, ?)
     ON DUPLICATE KEY UPDATE file_name = VALUES(file_name),
       template_data = VALUES(template_data), uploaded_by_user_id = VALUES(uploaded_by_user_id)`,
    [String(row.original_filename).slice(0, 500), row.template_data, uploadedByUserId],
  );
}

async function listTemplates(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    await ensureSchema();
    const [rows] = await db.query(
      `SELECT l.id, l.name, l.original_filename, l.file_format, l.file_size,
              l.version, l.is_active, l.created_at,
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
  let connection;
  try {
    if (!requireAdmin(req, res)) return undefined;
    await ensureSchema();
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
    if (!name) {
      return res.status(400).json({ success: false, message: 'A template name is required.' });
    }

    // A template consists of a binary record, its page index and, when active,
    // the legacy export copy. Commit them together so a temporary database
    // error cannot leave a template that later fails to preview or export.
    connection = await db.getConnection();
    await connection.beginTransaction();
    // Lock the library before choosing the active record and next version.
    // Concurrent uploads therefore cannot both become the active template.
    const [[existingActive]] = await connection.query(
      'SELECT COUNT(*) AS n FROM report_template_library WHERE is_active = 1 FOR UPDATE',
    );
    const activate = req.body?.activate === true || Number(existingActive.n) === 0;
    const [[latestVersion]] = await connection.query(
      'SELECT COALESCE(MAX(version), 0) AS version FROM report_template_library WHERE name = ? FOR UPDATE',
      [name],
    );
    const version = Number(latestVersion.version) + 1;
    const [created] = await connection.query(
      `INSERT INTO report_template_library
         (name, original_filename, file_format, file_size, template_data,
          is_active, version, uploaded_by_user_id)
       VALUES (?,?,?,?,?,?,?,?)`,
      [name, originalFilename, 'pptx', data.length, data, activate ? 1 : 0,
        version, req.user?.id || null],
    );
    const templateId = created.insertId;

    for (const [index, page] of pages.entries()) {
      await connection.query(
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
      await connection.query('UPDATE report_template_library SET is_active = 0 WHERE id <> ?', [templateId]);
      const [[template]] = await connection.query(
        'SELECT original_filename, template_data FROM report_template_library WHERE id = ? LIMIT 1',
        [templateId],
      );
      const uploadedByUserId = await legacyUploaderId(connection, req.user?.id);
      await connection.query(
        `INSERT INTO report_templates (scope, file_name, template_data, uploaded_by_user_id)
         VALUES ('EMPLOYEE_ADMIN', ?, ?, ?)
         ON DUPLICATE KEY UPDATE file_name = VALUES(file_name),
           template_data = VALUES(template_data), uploaded_by_user_id = VALUES(uploaded_by_user_id)`,
        [String(template.original_filename).slice(0, 500), template.template_data, uploadedByUserId],
      );
    }
    await connection.commit();

    return res.status(201).json({
      success: true,
      id: templateId,
      version,
      pageCount: pages.length,
      active: activate,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    console.error('uploadTemplate error:', error.message);
    const message = error?.code === 'ER_DATA_TOO_LONG'
      ? 'The template is too large for the database. Use a PPTX smaller than 10 MB.'
      : `Unable to save the report template: ${error.message}`;
    return res.status(500).json({ success: false, message });
  } finally {
    connection?.release();
  }
}

async function activateTemplate(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    await ensureSchema();
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

async function deactivateTemplate(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    await ensureSchema();
    const id = Number(req.params.id);
    const [[row]] = await db.query(
      'SELECT id, is_active FROM report_template_library WHERE id = ? LIMIT 1',
      [id],
    );
    if (!row) return res.status(404).json({ success: false, message: 'Template not found.' });
    await db.query('UPDATE report_template_library SET is_active = 0 WHERE id = ?', [id]);
    if (Number(row.is_active) === 1) {
      await db.query(
        'DELETE FROM report_templates WHERE scope = ?',
        ['EMPLOYEE_ADMIN'],
      );
    }
    return res.json({ success: true });
  } catch (error) {
    console.error('deactivateTemplate error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to deactivate the template.' });
  }
}

async function deleteTemplate(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    await ensureSchema();
    const id = Number(req.params.id);
    const [[row]] = await db.query(
      'SELECT is_active FROM report_template_library WHERE id = ? LIMIT 1',
      [id],
    );
    if (!row) return res.status(404).json({ success: false, message: 'Template not found.' });
    await db.query('DELETE FROM report_template_pages WHERE template_id = ?', [id]);
    await db.query('DELETE FROM report_template_library WHERE id = ?', [id]);
    // If the active template was removed, promote the newest remaining one.
    if (Number(row.is_active) === 1) {
      const [[next]] = await db.query(
        'SELECT id FROM report_template_library ORDER BY created_at DESC, id DESC LIMIT 1',
      );
      if (next) {
        await db.query('UPDATE report_template_library SET is_active = (id = ?)', [next.id]);
        await syncActiveToLegacy(next.id, req.user?.id);
      } else {
        await db.query(
          'DELETE FROM report_templates WHERE scope = ?',
          ['EMPLOYEE_ADMIN'],
        );
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
    await ensureSchema();
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

async function getActiveTemplate(req, res) {
  try {
    await ensureSchema();
    const template = await findActiveReportTemplate();
    if (!template) return res.json({ success: true, template: null });
    return res.json({
      success: true,
      template: {
        id: Number(template.id),
        name: template.name,
        original_filename: template.original_filename,
        version: Number(template.version) || 1,
        created_at: template.created_at,
      },
    });
  } catch (error) {
    console.error('getActiveTemplate error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load the active report template.' });
  }
}

async function previewTemplate(req, res) {
  try {
    await ensureSchema();
    const id = Number(req.params.id);
    if (!Number.isSafeInteger(id) || id < 1) {
      return res.status(400).json({ success: false, message: 'A valid template is required.' });
    }
    const template = await findReportTemplateById(id);
    if (!template) return res.status(404).json({ success: false, message: 'Template not found.' });
    const pdf = await renderPowerPointTemplatePreview(Buffer.from(template.template_data));
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="template-preview.pdf"',
      'Content-Length': pdf.length,
      'Cache-Control': 'no-store',
    });
    return res.send(pdf);
  } catch (error) {
    console.error('previewTemplate error:', error?.stack || error.message);
    return res.status(500).json({
      success: false,
      message: `Unable to render the template preview: ${error.message}`,
    });
  }
}

async function downloadTemplate(req, res) {
  try {
    if (!requireAdmin(req, res)) return undefined;
    await ensureSchema();
    const id = Number(req.params.id);
    if (!Number.isSafeInteger(id) || id < 1) {
      return res.status(400).json({ success: false, message: 'A valid template is required.' });
    }
    const template = await findReportTemplateById(id);
    if (!template) return res.status(404).json({ success: false, message: 'Template not found.' });
    const safeName = String(template.original_filename || 'report-template.pptx')
      .replace(/[\\/:*?"<>|\r\n]+/g, '_');
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'Content-Disposition': `attachment; filename="${safeName}"`,
      'Content-Length': Buffer.byteLength(template.template_data),
      'Cache-Control': 'no-store',
    });
    return res.send(Buffer.from(template.template_data));
  } catch (error) {
    console.error('downloadTemplate error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to download the report template.' });
  }
}

async function getTemplateFields(req, res) {
  try {
    await ensureSchema();
    const id = Number(req.params.id);
    if (!Number.isSafeInteger(id) || id < 1) {
      return res.status(400).json({ success: false, message: 'A valid template is required.' });
    }
    const template = await findReportTemplateById(id);
    if (!template) return res.status(404).json({ success: false, message: 'Template not found.' });
    const fields = await extractPowerPointTemplateFields(Buffer.from(template.template_data));
    return res.json({ success: true, templateId: id, fields });
  } catch (error) {
    console.error('getTemplateFields error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to read template fields.' });
  }
}

module.exports = {
  listTemplates,
  uploadTemplate,
  activateTemplate,
  deactivateTemplate,
  deleteTemplate,
  getActiveTemplate,
  downloadTemplate,
  getTemplateFields,
  getTemplatePages,
  previewTemplate,
};
