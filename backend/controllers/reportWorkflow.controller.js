'use strict';

const db = require('../config/db');
const { analyzeDashboardImages } = require('./dashboardOcr.controller');
const {
  downloadFullReportPpt,
  submitReportForApproval,
} = require('./fullReportPpt.controller');
const {
  canAccessReportClient,
  isAdmin,
  listAssignedReportClients,
} = require('../lib/reportTaskAccess');
const {
  extractPowerPointTemplatePages,
} = require('../services/reportTemplate.service');
const {
  findActiveReportTemplate,
  findReportTemplateById,
} = require('../services/reportTemplateLibrary.service');
const { ensureReportWorkflowSchemaOnce } = require('../lib/ensureReportWorkflowSchema');

const PROVIDER_NAMES = {
  GOOGLE_BUSINESS_PROFILE: 'Google Business Profile',
  GOOGLE_ADS: 'Google Ads',
  GOOGLE_ANALYTICS: 'Google Analytics',
  GOOGLE_SEARCH_CONSOLE: 'Google Search Console',
  META_ADS: 'Meta Ads',
  LINKEDIN_ADS: 'LinkedIn Ads',
  FACEBOOK: 'Facebook',
  INSTAGRAM: 'Instagram',
  YOUTUBE: 'YouTube',
  TWITTER: 'Twitter/X',
  TWITTER_X: 'Twitter/X',
  LOCAL_SEO: 'Local SEO',
};

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function providerName(value) {
  const key = String(value || '').toUpperCase().replace(/[^A-Z0-9]+/g, '_');
  return PROVIDER_NAMES[key] || String(value || '').replaceAll('_', ' ');
}

function fieldKey(value) {
  return String(value || '').trim().toLowerCase()
    .replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 255);
}

function validImageFile(file) {
  const bytes = file.buffer;
  if (file.mimetype === 'image/png') {
    return bytes.length >= 8
      && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  }
  if (file.mimetype === 'image/jpeg') {
    return bytes.length >= 3 && bytes[0] === 0xff
      && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  return file.mimetype === 'image/webp'
    && bytes.length >= 12
    && bytes.toString('ascii', 0, 4) === 'RIFF'
    && bytes.toString('ascii', 8, 12) === 'WEBP';
}

async function activeTemplate() {
  return findActiveReportTemplate();
}

async function pagesForTemplate(templateId) {
  const template = await findReportTemplateById(Number(templateId));
  if (!template) throw httpError(404, 'The selected report template was not found.');
  return extractPowerPointTemplatePages(Buffer.from(template.template_data));
}

async function requireDraft(req, draftId) {
  const [rows] = await db.query(
    `SELECT id, client_id, client_name, template_id, employee_id,
            report_name, reporting_month, status
     FROM report_workflow_drafts WHERE id = ? LIMIT 1`,
    [draftId],
  );
  const draft = rows[0];
  if (!draft) throw httpError(404, 'Report draft not found.');
  if (!isAdmin(req.user) && String(draft.employee_id) !== String(req.user.id)) {
    throw httpError(403, 'This report draft belongs to another employee.');
  }
  if (!(await canAccessReportClient(db, req.user, draft.client_name))) {
    throw httpError(403, 'You no longer have a Task Manager assignment for this client.');
  }
  return draft;
}

async function getDraftData(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const [rows] = await db.query(
    'SELECT report_data FROM report_workflow_drafts WHERE id = ? LIMIT 1',
    [draft.id],
  );
  const stored = rows[0]?.report_data;
  if (stored == null) return res.json({ success: true, reportData: null });
  let reportData;
  try {
    reportData = JSON.parse(Buffer.isBuffer(stored)
      ? stored.toString('utf8')
      : String(stored));
  } catch (error) {
    console.error('Stored report draft data is invalid:', error.message);
    throw httpError(500, 'The saved report draft data could not be read.');
  }
  return res.json({ success: true, reportData });
}

async function saveDraftData(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const reportData = req.body?.reportData;
  if (!reportData || typeof reportData !== 'object' || Array.isArray(reportData)) {
    throw httpError(400, 'Provide report draft data as an object.');
  }
  if (Number(reportData.templateId) !== Number(draft.template_id)) {
    throw httpError(400, 'The report draft must use its selected template.');
  }
  const serialized = JSON.stringify(reportData);
  if (Buffer.byteLength(serialized, 'utf8') > 50 * 1024 * 1024) {
    throw httpError(413, 'The saved report draft must be 50 MB or smaller.');
  }
  await db.query(
    `UPDATE report_workflow_drafts
     SET report_data = ?, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?`,
    [serialized, draft.id],
  );
  return res.json({ success: true });
}

async function getTemplates(req, res) {
  const template = await activeTemplate();
  return res.json({
    success: true,
    templates: template ? [{
      id: Number(template.id),
      name: template.name,
      version: Number(template.version) || 1,
      updated_at: template.created_at,
    }] : [],
  });
}

async function getTemplatePages(req, res) {
  const pages = await pagesForTemplate(req.params.templateId);
  return res.json({ success: true, pages });
}

async function getHistory(req, res) {
  let names;
  if (isAdmin(req.user)) {
    names = null;
  } else {
    const assigned = await listAssignedReportClients(db, req.user.id);
    names = assigned.map((client) => client.name);
    if (!names.length) return res.json({ success: true, reports: [] });
  }

  let sql = `SELECT h.id, h.company_name, h.report_month, h.report_year,
                    h.file_name AS exact_filename, h.created_at,
                    c.id AS client_id, 'approved' AS status
             FROM client_full_report_history h
             LEFT JOIN clients c
               ON LOWER(TRIM(c.company_name)) = LOWER(TRIM(h.company_name))`;
  const params = [];
  if (names) {
    sql += ' WHERE h.company_name IN (?)';
    params.push(names);
  }
  sql += ' ORDER BY h.created_at DESC LIMIT 300';
  const [reports] = await db.query(sql, params);
  return res.json({ success: true, reports });
}

async function getClientWorkspace(req, res) {
  await ensureReportWorkflowSchemaOnce(db);
  const clientId = Number(req.params.clientId);
  if (!Number.isSafeInteger(clientId) || clientId < 1) {
    throw httpError(400, 'A valid client ID is required.');
  }
  const [clients] = await db.query(
    `SELECT id, company_name, industry FROM clients
     WHERE id = ? AND COALESCE(is_active, 1) = 1 LIMIT 1`,
    [clientId],
  );
  const client = clients[0];
  if (!client) throw httpError(404, 'Client not found.');
  if (!(await canAccessReportClient(db, req.user, client.company_name))) {
    throw httpError(403, 'You do not have a Task Manager assignment for this client.');
  }
  const month = String(req.query.month || '').match(/^(\d{4})-(\d{2})$/);
  if (!month || Number(month[2]) < 1 || Number(month[2]) > 12) {
    throw httpError(400, 'Month must use the YYYY-MM format.');
  }
  const selectedStatus = String(req.query.status || 'all');
  if (!['all', 'approved', 'pending', 'draft'].includes(selectedStatus)) {
    throw httpError(400, 'Unsupported report status filter.');
  }

  const employeeFilter = isAdmin(req.user) ? '' : ' AND submitted_by_user_id = ?';
  const submissionParams = [client.company_name, Number(month[1]), Number(month[2])];
  if (!isAdmin(req.user)) submissionParams.push(req.user.id);
  const [submissions] = await db.query(
    `SELECT id, report_month, report_year, payload, status, created_at
     FROM report_submissions
     WHERE company_name = ? AND report_year = ? AND report_month = ?${employeeFilter}
     ORDER BY created_at DESC`,
    submissionParams,
  );

  const draftFilter = isAdmin(req.user) ? '' : ' AND employee_id = ?';
  const draftParams = [client.id, `${month[1]}-${month[2]}-01`];
  if (!isAdmin(req.user)) draftParams.push(req.user.id);
  const [drafts] = await db.query(
    `SELECT id, report_name, status, created_at
     FROM report_workflow_drafts
     WHERE client_id = ? AND reporting_month = ?${draftFilter}
     ORDER BY created_at DESC`,
    draftParams,
  );
  const [history] = await db.query(
    `SELECT id, file_name, file_format, created_at
     FROM client_full_report_history
     WHERE company_name = ? AND report_year = ? AND report_month = ?
     ORDER BY created_at DESC`,
    [client.company_name, Number(month[1]), Number(month[2])],
  );

  const reportRows = [
    ...submissions.map((submission) => {
      let payload = {};
      try {
        const content = Buffer.isBuffer(submission.payload)
          ? submission.payload.toString('utf8')
          : String(submission.payload);
        payload = JSON.parse(content);
      } catch (error) {
        console.error('Stored report submission payload is invalid:', error.message);
      }
      return {
        id: Number(submission.id),
        name: payload.reportName || `${client.company_name} report`,
        createdOn: submission.created_at,
        providers: Array.isArray(payload.providers)
          ? payload.providers.map((item) =>
              typeof item === 'string' ? item : item.provider).filter(Boolean)
          : [],
        status: String(submission.status || 'pending').toLowerCase(),
      };
    }),
    ...drafts.map((draft) => ({
      id: Number(draft.id),
      name: draft.report_name,
      createdOn: draft.created_at,
      providers: [],
      status: 'draft',
    })),
    ...history.map((saved) => ({
      id: Number(saved.id),
      name: saved.file_name,
      createdOn: saved.created_at,
      providers: [],
      status: 'approved',
    })),
  ];
  const summary = {
    total: reportRows.length,
    approved: reportRows.filter((report) => report.status === 'approved').length,
    pending: reportRows.filter((report) => report.status === 'pending').length,
    drafts: reportRows.filter((report) => report.status === 'draft').length,
  };
  const reports = selectedStatus === 'all'
    ? reportRows
    : reportRows.filter((report) => report.status === selectedStatus);
  return res.json({
    success: true,
    client: {
      id: String(client.id),
      name: client.company_name,
      category: client.industry || '',
      assignedOn: null,
      assignedBy: null,
    },
    summary,
    reports,
  });
}

async function createDraft(req, res) {
  await ensureReportWorkflowSchemaOnce(db);
  const clientId = Number(req.body?.clientId);
  const templateId = Number(req.body?.templateId);
  const reportingMonth = String(req.body?.reportingMonth || '');
  const requestedName = String(req.body?.clientName || req.body?.reportName || '').trim();
  const match = /^(\d{4})-(\d{2})$/.exec(reportingMonth);
  const hasClientId = Number.isSafeInteger(clientId) && clientId > 0;
  if ((!hasClientId && !requestedName)
      || (hasClientId && requestedName.length > 255)
      || requestedName.length > 255
      || !Number.isSafeInteger(templateId) || templateId < 1
      || !match || Number(match[2]) < 1 || Number(match[2]) > 12) {
    throw httpError(400, 'A valid client, template, and reporting month are required.');
  }

  let resolvedClientId = 0;
  let clientName = requestedName;
  if (hasClientId) {
    const [clients] = await db.query(
      'SELECT id, company_name FROM clients WHERE id = ? AND COALESCE(is_active, 1) = 1 LIMIT 1',
      [clientId],
    );
    const client = clients[0];
    if (!client) throw httpError(404, 'The selected client was not found.');
    resolvedClientId = Number(client.id);
    clientName = client.company_name;
  }
  if (!clientName || !(await canAccessReportClient(db, req.user, clientName))) {
    throw httpError(403, 'You do not have a Task Manager assignment for this client.');
  }
  const template = await findReportTemplateById(templateId);
  if (!template) {
    throw httpError(404, 'The selected report template was not found.');
  }

  const monthDate = `${match[1]}-${match[2]}-01`;
  const name = String(req.body?.reportName || `${clientName} report`).trim().slice(0, 255);
  const [existingDrafts] = await db.query(
    `SELECT id FROM report_workflow_drafts
     WHERE client_id = ? AND client_name = ? AND template_id = ? AND employee_id = ?
       AND reporting_month = ? AND status = 'draft'
     ORDER BY updated_at DESC LIMIT 1`,
    [resolvedClientId, clientName, templateId, req.user.id, monthDate],
  );
  if (existingDrafts[0]) {
    return res.status(200).json({ success: true, id: Number(existingDrafts[0].id) });
  }
  const [result] = await db.query(
    `INSERT INTO report_workflow_drafts
      (client_id, client_name, template_id, employee_id, report_name, reporting_month)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [resolvedClientId, clientName, templateId, req.user.id, name, monthDate],
  );
  return res.status(201).json({ success: true, id: Number(result.insertId) });
}

async function listScreenshots(req, res) {
  await requireDraft(req, req.params.draftId);
  const [screenshots] = await db.query(
    `SELECT id, original_filename, mime_type, provider_name,
            provider_confidence, template_page_id, ocr_status, ocr_error, created_at
     FROM report_workflow_screenshots
     WHERE draft_id = ? ORDER BY created_at, id`,
    [req.params.draftId],
  );
  return res.json({ success: true, screenshots });
}

async function saveScreenshotOcr(draft, file, screenshotId, fallbackPage = null) {
  let ocr;
  try {
    ocr = await analyzeDashboardImages([{
      base64: file.buffer.toString('base64'),
    }]);
  } catch (error) {
    const message = String(error.message || 'OCR failed').slice(0, 1000);
    await db.query(
      `UPDATE report_workflow_screenshots
       SET ocr_status = 'failed', ocr_error = ? WHERE id = ? AND draft_id = ?`,
      [message, screenshotId, draft.id],
    );
    return {
      id: screenshotId,
      original_filename: file.originalname,
      provider_name: fallbackPage?.provider_name || null,
      provider_confidence: 0,
      template_page_id: fallbackPage?.id || null,
      ocr_status: 'failed',
      ocr_error: message,
    };
  }

  const detectedProvider = ocr.detected_provider || fallbackPage?.provider_name || null;
  const pages = await pagesForTemplate(draft.template_id);
  const page = pages.find((candidate) =>
    detectedProvider
    && providerName(candidate.provider_code).toLowerCase()
      === detectedProvider.toLowerCase()) || fallbackPage;
  await db.query(
    `UPDATE report_workflow_screenshots
     SET provider_name = ?, provider_confidence = ?, template_page_id = ?,
         ocr_status = 'completed', ocr_error = NULL
     WHERE id = ? AND draft_id = ?`,
    [detectedProvider, ocr.provider_confidence, page?.id || null,
      screenshotId, draft.id],
  );
  for (const [label, value] of Object.entries(ocr.metrics || {})) {
    await db.query(
      `INSERT INTO report_workflow_fields
        (draft_id, screenshot_id, template_page_id, provider_name, source_label, extracted_value)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [draft.id, screenshotId, page?.id || null, detectedProvider,
        label, String(value).slice(0, 4000)],
    );
  }
  return {
    id: screenshotId,
    original_filename: file.originalname,
    provider_name: detectedProvider,
    provider_confidence: ocr.provider_confidence,
    template_page_id: page?.id || null,
    ocr_status: 'completed',
  };
}

async function uploadScreenshots(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const files = req.files || [];
  if (!files.length) throw httpError(400, 'Select one or more screenshots to upload.');
  if (files.some((file) => !validImageFile(file))) {
    throw httpError(400, 'Screenshots must be valid PNG, JPEG, or WebP images.');
  }
  const requestedPageId = Number(req.body?.templatePageId) || null;
  const templatePages = requestedPageId
    ? await pagesForTemplate(draft.template_id)
    : [];
  const requestedPage = templatePages.find((page) => page.id === requestedPageId);
  if (requestedPageId && !requestedPage) {
    throw httpError(400, 'The selected dashboard page is not in this report template.');
  }
  const assignedProvider = requestedPage
      && !['mandatory', 'unknown'].includes(requestedPage.provider_code)
    ? providerName(requestedPage.provider_code)
    : null;

  const screenshots = [];
  for (const file of files) {
    const [result] = await db.query(
      `INSERT INTO report_workflow_screenshots
        (draft_id, original_filename, mime_type, image_data, provider_name,
         template_page_id, ocr_status)
       VALUES (?, ?, ?, ?, ?, ?, 'processing')`,
      [draft.id, String(file.originalname || 'screenshot').slice(0, 500),
        file.mimetype, file.buffer, assignedProvider, requestedPageId],
    );
    screenshots.push(await saveScreenshotOcr(
      draft,
      file,
      Number(result.insertId),
      requestedPage ? { ...requestedPage, provider_name: assignedProvider } : null,
    ));
  }
  return res.status(201).json({ success: true, screenshots });
}

async function replaceScreenshot(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const file = req.file;
  if (!file) throw httpError(400, 'Choose a replacement screenshot.');
  if (!validImageFile(file)) {
    throw httpError(400, 'Screenshots must be valid PNG, JPEG, or WebP images.');
  }
  const screenshotId = Number(req.params.screenshotId);
  const [rows] = await db.query(
    `SELECT id FROM report_workflow_screenshots
     WHERE id = ? AND draft_id = ? LIMIT 1`,
    [screenshotId, draft.id],
  );
  if (!rows[0]) throw httpError(404, 'Screenshot not found in this report.');
  await db.query(
    `UPDATE report_workflow_screenshots
     SET original_filename = ?, mime_type = ?, image_data = ?,
         provider_name = NULL, provider_confidence = NULL, template_page_id = NULL,
         ocr_status = 'processing', ocr_error = NULL
     WHERE id = ? AND draft_id = ?`,
    [String(file.originalname || 'screenshot').slice(0, 500),
      file.mimetype, file.buffer, screenshotId, draft.id],
  );
  await db.query(
    'DELETE FROM report_workflow_fields WHERE screenshot_id = ? AND draft_id = ?',
    [screenshotId, draft.id],
  );
  const screenshot = await saveScreenshotOcr(draft, file, screenshotId);
  return res.json({ success: true, screenshot });
}

async function updateScreenshot(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const screenshotId = Number(req.params.screenshotId);
  const [rows] = await db.query(
    `SELECT id FROM report_workflow_screenshots WHERE id = ? AND draft_id = ? LIMIT 1`,
    [screenshotId, draft.id],
  );
  if (!rows[0]) throw httpError(404, 'Screenshot not found in this report.');

  const provider = String(req.body?.providerName || req.body?.provider || '').trim();
  const requestedPageId = Number(req.body?.templatePageId || req.body?.pageId) || null;
  if (provider.length > 100) throw httpError(400, 'Provider name is too long.');
  const pages = provider || requestedPageId
    ? await pagesForTemplate(draft.template_id)
    : [];
  const page = requestedPageId
    ? pages.find((candidate) => candidate.id === requestedPageId)
    : pages.find((candidate) =>
        provider
        && !['mandatory', 'unknown'].includes(candidate.provider_code)
        && providerName(candidate.provider_code).toLowerCase()
          === provider.toLowerCase());
  if (requestedPageId && !page) {
    throw httpError(400, 'The selected dashboard page is not in this report template.');
  }
  const pageId = page?.id || null;
  await db.query(
    `UPDATE report_workflow_screenshots
     SET provider_name = ?, template_page_id = ? WHERE id = ? AND draft_id = ?`,
    [provider || null, pageId, screenshotId, draft.id],
  );
  await db.query(
    `UPDATE report_workflow_fields
     SET provider_name = ?, template_page_id = ?
     WHERE screenshot_id = ? AND draft_id = ?`,
    [provider || null, pageId, screenshotId, draft.id],
  );
  return res.json({ success: true });
}

async function readScreenshot(req, res) {
  await requireDraft(req, req.params.draftId);
  const [rows] = await db.query(
    `SELECT original_filename, mime_type, image_data
     FROM report_workflow_screenshots WHERE id = ? AND draft_id = ? LIMIT 1`,
    [req.params.screenshotId, req.params.draftId],
  );
  if (!rows[0]) throw httpError(404, 'Screenshot not found.');
  const filename = rows[0].original_filename.replace(/[^A-Za-z0-9._ -]/g, '_');
  res.set({
    'Content-Type': rows[0].mime_type,
    'Content-Disposition': `inline; filename="${filename}"`,
    'Cache-Control': 'no-store',
  });
  return res.send(rows[0].image_data);
}

async function deleteScreenshot(req, res) {
  await requireDraft(req, req.params.draftId);
  const [result] = await db.query(
    `DELETE FROM report_workflow_screenshots WHERE id = ? AND draft_id = ?`,
    [req.params.screenshotId, req.params.draftId],
  );
  if (!result.affectedRows) throw httpError(404, 'Screenshot not found.');
  return res.json({ success: true });
}

async function listFields(req, res) {
  await requireDraft(req, req.params.draftId);
  const [fields] = await db.query(
    `SELECT id, screenshot_id, template_page_id, provider_name,
            source_label, extracted_value, override_label, override_value
     FROM report_workflow_fields WHERE draft_id = ? ORDER BY id`,
    [req.params.draftId],
  );
  return res.json({ success: true, fields });
}

async function getDraftPreview(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const [screenshots] = await db.query(
    `SELECT id, original_filename, provider_name, template_page_id, ocr_status
     FROM report_workflow_screenshots
     WHERE draft_id = ? ORDER BY created_at, id`,
    [draft.id],
  );
  const [fields] = await db.query(
    `SELECT id, template_page_id, provider_name, source_label,
            extracted_value, override_label, override_value
     FROM report_workflow_fields
     WHERE draft_id = ?
       AND COALESCE(NULLIF(override_value, ''), NULLIF(extracted_value, '')) IS NOT NULL
     ORDER BY id`,
    [draft.id],
  );
  const pages = await pagesForTemplate(draft.template_id);
  return res.json({
    success: true,
    draft: {
      id: Number(draft.id),
      clientId: Number(draft.client_id),
      clientName: draft.client_name,
      reportName: draft.report_name,
      reportingMonth: draft.reporting_month,
      status: draft.status,
    },
    pages,
    screenshots,
    fields,
  });
}

async function addField(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const label = String(req.body?.label || '').trim();
  if (!label || label.length > 255) throw httpError(400, 'Field name is required and must be 255 characters or fewer.');
  const pageId = Number(req.body?.templatePageId) || null;
  let provider = String(req.body?.providerName || '').trim() || null;
  if (!provider && pageId) {
    const pages = await pagesForTemplate(draft.template_id);
    const page = pages.find((candidate) => candidate.id === pageId);
    if (page && !['mandatory', 'unknown'].includes(page.provider_code)) {
      provider = providerName(page.provider_code);
    }
  }
  const [result] = await db.query(
    `INSERT INTO report_workflow_fields
      (draft_id, template_page_id, provider_name, source_label, extracted_value, override_label, override_value)
     VALUES (?, ?, ?, ?, NULL, ?, ?)`,
    [draft.id, pageId, provider, label, label,
      String(req.body?.value || '').slice(0, 4000)],
  );
  return res.status(201).json({ success: true, id: Number(result.insertId) });
}

async function updateField(req, res) {
  await requireDraft(req, req.params.draftId);
  const label = String(req.body?.label || '').trim();
  const value = String(req.body?.value || '').slice(0, 4000);
  if (!label || label.length > 255) throw httpError(400, 'Field name is required and must be 255 characters or fewer.');
  const [result] = await db.query(
    `UPDATE report_workflow_fields SET override_label = ?, override_value = ?
     WHERE id = ? AND draft_id = ?`,
    [label, value, req.params.fieldId, req.params.draftId],
  );
  if (!result.affectedRows) throw httpError(404, 'Report field not found.');
  return res.json({ success: true });
}

async function deleteField(req, res) {
  await requireDraft(req, req.params.draftId);
  const [result] = await db.query(
    'DELETE FROM report_workflow_fields WHERE id = ? AND draft_id = ?',
    [req.params.fieldId, req.params.draftId],
  );
  if (!result.affectedRows) throw httpError(404, 'Report field not found.');
  return res.json({ success: true });
}

async function replaceDraftFields(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const fields = req.body?.fields;
  if (!Array.isArray(fields) || fields.length > 500) {
    throw httpError(400, 'Provide no more than 500 editable template fields.');
  }
  const pages = await pagesForTemplate(draft.template_id);
  const pageIds = new Set(pages.map((page) => page.id));
  const normalized = fields.map((field) => {
    const label = String(field?.label || '').trim();
    const value = String(field?.value ?? '');
    const pageId = Number(field?.templatePageId) || null;
    if (!label || label.length > 255) {
      throw httpError(400, 'Each editable field needs a name of 255 characters or fewer.');
    }
    if (value.length > 4000) {
      throw httpError(400, 'Editable field values must be 4,000 characters or fewer.');
    }
    if (pageId != null && !pageIds.has(pageId)) {
      throw httpError(400, 'An editable field refers to a page outside this template.');
    }
    return { label, value, pageId };
  });
  if (new Set(normalized.map((field) => field.label.toLowerCase())).size !== normalized.length) {
    throw httpError(400, 'Editable template field names must be unique.');
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    await connection.query(
      'DELETE FROM report_workflow_fields WHERE draft_id = ? AND screenshot_id IS NULL',
      [draft.id],
    );
    for (const field of normalized) {
      await connection.query(
        `INSERT INTO report_workflow_fields
           (draft_id, template_page_id, source_label, extracted_value,
            override_label, override_value)
         VALUES (?, ?, ?, NULL, ?, ?)`,
        [draft.id, field.pageId, field.label, field.label, field.value],
      );
    }
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
  return res.json({ success: true, fieldCount: normalized.length });
}

async function buildDraftPayload(draft) {
  const [savedRows] = await db.query(
    'SELECT report_data FROM report_workflow_drafts WHERE id = ? LIMIT 1',
    [draft.id],
  );
  const savedData = savedRows[0]?.report_data;
  if (savedData != null) {
    let payload;
    try {
      payload = JSON.parse(Buffer.isBuffer(savedData)
        ? savedData.toString('utf8')
        : String(savedData));
    } catch (error) {
      console.error('Stored report draft data is invalid:', error.message);
      throw httpError(500, 'The saved report draft data could not be read.');
    }
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw httpError(500, 'The saved report draft data has an invalid format.');
    }
    if (Number(payload.templateId) !== Number(draft.template_id)) {
      throw httpError(409, 'The saved report draft template no longer matches.');
    }
    return payload;
  }

  const [screenshots] = await db.query(
    `SELECT id, image_data, mime_type, provider_name
     FROM report_workflow_screenshots
     WHERE draft_id = ? AND provider_name IS NOT NULL
     ORDER BY created_at, id`,
    [draft.id],
  );
  const [fields] = await db.query(
    `SELECT template_page_id, provider_name, source_label, extracted_value,
            override_label, override_value
     FROM report_workflow_fields WHERE draft_id = ? ORDER BY id`,
    [draft.id],
  );
  const snapshots = new Map();
  const slideEdits = {};
  const templateFields = {};
  for (const field of fields) {
    const key = fieldKey(field.override_label || field.source_label);
    const value = field.override_value ?? field.extracted_value;
    if (!key || value == null || String(value).trim() === '') continue;
    const provider = providerName(field.provider_name);
    if (!provider && field.template_page_id != null) {
      templateFields[field.override_label || field.source_label] = String(value);
      continue;
    }
    if (!provider) {
      templateFields[field.override_label || field.source_label] = String(value);
      continue;
    }
    if (!provider) continue;
    const metrics = snapshots.get(provider) || {};
    metrics[key] = String(value);
    snapshots.set(provider, metrics);
  }
  const reportingMonth = draft.reporting_month instanceof Date
    ? draft.reporting_month.toISOString().slice(0, 7)
    : String(draft.reporting_month).slice(0, 7);
  const [year, month] = reportingMonth.split('-').map(Number);
  const providers = [...new Set([
    ...screenshots.map((screenshot) => providerName(screenshot.provider_name)),
    ...snapshots.keys(),
  ].filter(Boolean))];
  return {
    businessId: String(draft.client_id),
    clientId: Number(draft.client_id),
    clientName: draft.client_name,
    templateId: Number(draft.template_id),
    reportName: draft.report_name,
    reportMonth: month,
    reportYear: year,
    periodLabel: `${year}-${String(month).padStart(2, '0')}`,
    filePeriod: `${year}-${String(month).padStart(2, '0')}`,
    dateRange: 'Overall',
    reportTemplate: 'EMPLOYEE_ADMIN',
    providers: providers.map((provider) => ({
      provider,
      connectionStatus: 'SCREENSHOT',
    })),
    selectedProviders: providers,
    snapshots: [...snapshots.entries()].map(([provider, metrics]) => ({
      provider,
      metrics: { ...metrics, export_overrides: metrics },
    })),
    templateFields,
    slide_edits: slideEdits,
    screenshots: screenshots.map((screenshot) => ({
      provider: providerName(screenshot.provider_name),
      mimeType: screenshot.mime_type,
      bytesBase64: Buffer.from(screenshot.image_data).toString('base64'),
    })),
  };
}

function hasReportContent(payload) {
  return (Array.isArray(payload.screenshots) && payload.screenshots.length > 0)
    || (Array.isArray(payload.snapshots) && payload.snapshots.length > 0)
    || Object.keys(payload.templateFields || {}).length > 0
    || Object.keys(payload.slide_edits || {}).length > 0;
}

async function readyDraftPayload(draft) {
  const [savedRows] = await db.query(
    'SELECT report_data FROM report_workflow_drafts WHERE id = ? LIMIT 1',
    [draft.id],
  );
  if (savedRows[0]?.report_data != null) {
    const payload = await buildDraftPayload(draft);
    if (!hasReportContent(payload)) {
      throw httpError(400, 'Enter report values or add a dashboard image before exporting.');
    }
    return payload;
  }

  const payload = await buildDraftPayload(draft);
  const [rows] = await db.query(
    `SELECT COUNT(*) AS total,
            SUM(CASE WHEN provider_name IS NULL OR TRIM(provider_name) = '' THEN 1 ELSE 0 END) AS unassigned
     FROM report_workflow_screenshots WHERE draft_id = ?`,
    [draft.id],
  );
  if (!Number(rows[0]?.total)) {
    throw httpError(400, 'Upload at least one dashboard screenshot before submitting the report.');
  }
  if (Number(rows[0]?.unassigned)) {
    throw httpError(400, 'Choose a provider for every screenshot before submitting the report.');
  }
  return payload;
}

async function submitDraft(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const delegated = Object.create(req);
  delegated.body = await readyDraftPayload(draft);
  return submitReportForApproval(delegated, res);
}

async function exportDraft(req, res) {
  const draft = await requireDraft(req, req.params.draftId);
  const delegated = Object.create(req);
  delegated.body = await readyDraftPayload(draft);
  delegated.params = { ...req.params, format: req.params.format };
  return downloadFullReportPpt(delegated, res);
}

module.exports = {
  addField,
  createDraft,
  deleteField,
  deleteScreenshot,
  getDraftData,
  getHistory,
  getClientWorkspace,
  exportDraft,
  getDraftPreview,
  getTemplatePages,
  getTemplates,
  listFields,
  listScreenshots,
  readScreenshot,
  replaceScreenshot,
  replaceDraftFields,
  saveDraftData,
  submitDraft,
  updateField,
  updateScreenshot,
  uploadScreenshots,
};
