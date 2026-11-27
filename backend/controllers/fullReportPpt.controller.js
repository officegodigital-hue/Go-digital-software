const { canAccessBusiness } = require('../middleware/businessAccess.middleware');
const db = require('../config/db');
const { createNotification } = require('../routes/notifications');
const { buildReportHtml } = require('../services/reportHtml.service');
const { renderHtmlToPdf, renderHtmlToImages } = require('../services/fullReportRender.service');
const { buildPptxFromImages } = require('../services/fullReportPpt.service');
const { buildDocxFromImages } = require('../services/fullReportWord.service');
const { generateFromPowerPointTemplate } = require('../services/reportTemplate.service');
const {
  findActiveReportTemplate,
  findReportTemplateById,
} = require('../services/reportTemplateLibrary.service');
const {
  canAccessReportClient,
  isAdmin: hasReportAdminAccess,
  listAssignedReportClients,
  reportAccessType,
} = require('../lib/reportTaskAccess');

function safeFilename(value) {
  return String(value || 'Business').replace(/[^a-z0-9]+/gi, '_').replace(/^_+|_+$/g, '') || 'Business';
}

const _MONTHS = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
function monthName(m) { const n = Number(m); return (n >= 1 && n <= 12) ? _MONTHS[n] : `${m}`; }

// Employees must get approval before downloading; admins/owners download freely.
function isEmployee(user) {
  return String(user?.userType || '').toLowerCase() === 'employee'
    && !hasReportAdminAccess(user);
}

async function userName(id) {
  if (!id) return null;
  try {
    const [rows] = await db.query(
      'SELECT full_name FROM employee_users WHERE id = ? LIMIT 1',
      [id],
    );
    return rows[0]?.full_name || null;
  } catch (_) {
    return null;
  }
}

function reportPeriod(body) {
  const now = new Date();
  return {
    company: String(body?.clientName || 'Client').slice(0, 255),
    month: Number(body?.reportMonth) || now.getMonth() + 1,
    year: Number(body?.reportYear) || now.getFullYear(),
  };
}

// Sections that are not real client platforms, so they never appear as a
// per-platform deliverable on the client's month card.
const NON_PLATFORM_KEYS = new Set([
  'LOCAL_SEO',
  'CREATIVE_SHOWCASE',
  'CREATIVES_PUBLISHED',
  'NEXT_MONTH_PLAN',
]);

// The platform keys a report submission covers, normalised to UPPER_SNAKE so
// they align with the frontend provider keys (INSTAGRAM, FACEBOOK,
// GOOGLE_BUSINESS_PROFILE, META_ADS, ...).
function platformKeysFromPayload(body) {
  const raw = Array.isArray(body?.selectedProviders)
    ? body.selectedProviders
    : Array.isArray(body?.providers)
      ? body.providers.map((p) => (p && typeof p === 'object' ? p.provider : p))
      : [];
  const keys = [];
  const seen = new Set();
  for (const value of raw) {
    const key = String(value || '').trim().toUpperCase().replace(/\s+/g, '_');
    if (!key || NON_PLATFORM_KEYS.has(key) || seen.has(key)) continue;
    seen.add(key);
    keys.push(key.slice(0, 64));
  }
  return keys;
}

// Upsert the per-platform status for a client + month. Best-effort: a failure
// here never fails the submission / approval it is attached to.
async function setPlatformStatuses({
  company,
  month,
  year,
  platforms,
  status,
  submissionId = null,
  userId = null,
  submittedByName = null,
}) {
  if (!Array.isArray(platforms) || !platforms.length) return;
  try {
    for (const platform of platforms) {
      await db.query(
        `INSERT INTO report_platform_status
           (company_name, report_month, report_year, platform_key, status,
            submission_id, submitted_by_user_id, submitted_by_name)
         VALUES (?,?,?,?,?,?,?,?)
         ON DUPLICATE KEY UPDATE
           status = VALUES(status),
           submission_id = VALUES(submission_id),
           submitted_by_user_id = VALUES(submitted_by_user_id),
           submitted_by_name = VALUES(submitted_by_name),
           updated_at = CURRENT_TIMESTAMP`,
        [company, month, year, platform, status, submissionId, userId, submittedByName],
      );
    }
  } catch (error) {
    console.error('setPlatformStatuses failed:', error.message);
  }
}

function applyPreviewOverrides(payload) {
  const snapshots = Array.isArray(payload?.snapshots) ? payload.snapshots : [];
  for (const snapshot of snapshots) {
    const metrics = snapshot?.metrics;
    const overrides = metrics?.export_overrides;
    if (!metrics || !overrides || typeof overrides !== 'object') continue;
    const apply = (value) => {
      if (Array.isArray(value)) return value.map(apply);
      if (!value || typeof value !== 'object') return value;
      for (const [key, child] of Object.entries(value)) {
        if (key === 'export_overrides') continue;
        if (Object.prototype.hasOwnProperty.call(overrides, key)) {
          value[key] = overrides[key];
        } else {
          value[key] = apply(child);
        }
      }
      return value;
    };
    apply(metrics);
    // Keep employee-entered values for fields the provider did not return at
    // all; these become normal top-level report metrics for every exporter.
    for (const [key, value] of Object.entries(overrides)) {
      if (metrics[key] === undefined) metrics[key] = value;
    }
    // Preserve the approved values for the exporter. Some providers keep
    // their report fields in nested totals (Meta/Facebook/Instagram), so the
    // PPT builder applies these overrides after selecting that section.
  }
  return payload;
}

// Attaches the previous month's snapshots so the report can auto-compute the
// "vs last month %" on each metric card. Best-effort; never blocks generation.
async function attachLastMonthSnapshots(payload) {
  try {
    const company = String(payload?.clientName || '').trim();
    const month = Number(payload?.reportMonth);
    const year = Number(payload?.reportYear);
    if (!company || !month || !year) return;
    let prevMonth = month - 1;
    let prevYear = year;
    if (prevMonth < 1) { prevMonth = 12; prevYear = year - 1; }
    const [rows] = await db.query(
      `SELECT payload FROM report_submissions
       WHERE company_name = ? AND report_month = ? AND report_year = ?
       ORDER BY created_at DESC LIMIT 1`,
      [company, prevMonth, prevYear],
    );
    if (!rows[0]?.payload) return;
    const prev = applyPreviewOverrides(JSON.parse(rows[0].payload.toString('utf8')));
    if (Array.isArray(prev.snapshots)) payload.lastMonthSnapshots = prev.snapshots;
  } catch (error) {
    console.error('attachLastMonthSnapshots error:', error.message);
  }
}

async function generateReportFile(payload, format) {
  await attachLastMonthSnapshots(payload);
  // Always render from the CURRENTLY ACTIVE template so that uploading or
  // activating a new template immediately governs EVERY report — new and old,
  // preview, template view and download alike. A report created earlier may
  // still carry a pinned payload.templateId, but that template can be replaced
  // or deleted; instead of failing with "the selected report template no longer
  // exists", we prefer the active template and only fall back to the pinned id
  // when (and only when) no template is currently active.
  let template = await findActiveReportTemplate();
  if (!template && payload.templateId != null) {
    const templateId = Number(payload.templateId);
    if (Number.isSafeInteger(templateId) && templateId >= 1) {
      template = await findReportTemplateById(templateId);
    }
  }

  if (template) {
    return {
      file: await generateFromPowerPointTemplate(
        Buffer.from(template.template_data),
        payload.powerPointEditTemplateId != null && Number(payload.powerPointEditTemplateId) !== Number(template.id)
          ? { ...payload, powerPointEdits: {} }
          : payload,
        format,
      ),
      template,
    };
  }
  if (payload.reportTemplate === 'EMPLOYEE_ADMIN') {
    const error = new Error('No active PowerPoint report template is available.');
    error.status = 409;
    throw error;
  }

  const html = buildReportHtml(payload);
  if (format === 'pdf') return { file: await renderHtmlToPdf(html), template: null };
  const images = await renderHtmlToImages(html);
  if (format === 'editor') {
    return { file: images.map((image) => ({ image: Buffer.from(image).toString('base64'), elements: [] })), template: null };
  }
  return {
    file: format === 'pptx'
      ? await buildPptxFromImages(images)
      : await buildDocxFromImages(images),
    template: null,
  };
}

function reportDataSnapshot(payload) {
  const snapshot = { ...payload };
  if (Array.isArray(snapshot.screenshots)) {
    snapshot.screenshots = snapshot.screenshots.map((screenshot) => {
      const { bytesBase64, ...metadata } = screenshot || {};
      return metadata;
    });
  }
  return Buffer.from(JSON.stringify(snapshot));
}

async function saveClientReportHistory({
  clientName,
  clientId,
  month,
  year,
  format,
  fileName,
  contentType,
  file,
  userId,
  template,
  payload,
}) {
  await db.query(
    `INSERT INTO client_full_report_history
       (company_name, report_month, report_year, file_format, file_name,
        content_type, file_data, downloaded_by_user_id, client_id,
        template_id, template_version, report_data)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
    [
      String(clientName || 'Client').slice(0, 255),
      month,
      year,
      format,
      fileName.slice(0, 500),
      contentType,
      file,
      userId || null,
      Number.isSafeInteger(Number(clientId)) && Number(clientId) > 0
        ? Number(clientId)
        : null,
      template ? Number(template.id) : null,
      template ? Number(template.version) || 1 : null,
      reportDataSnapshot(payload),
    ],
  );
}

async function downloadFullReportPpt(req, res) {
  try {
    const businessId = Number.parseInt(req.body?.businessId, 10);
    const screenshotOnly = req.body?.reportTemplate === 'EMPLOYEE_ADMIN';
    if (!screenshotOnly && (!Number.isSafeInteger(businessId) || businessId < 1)) {
      return res.status(400).json({ success: false, message: 'A valid business is required.' });
    }
    if (!screenshotOnly && !(await canAccessBusiness(req.user, businessId))) {
      return res.status(403).json({ success: false, message: 'You do not have access to this business.' });
    }
    if (!screenshotOnly && req.user.role === 'EMPLOYEE') {
      const [membership] = await db.query('SELECT permission_level FROM user_businesses WHERE business_id=? AND user_id=? LIMIT 1', [businessId, req.user.id]);
      if (!['EDIT', 'ADMIN'].includes(membership[0]?.permission_level)) {
        return res.status(403).json({ success: false, message: 'You need edit access to export this report.' });
      }
    }
    // Approval gate: an employee may only download a report that an admin has
    // approved for this client + period. Admins/owners are not restricted.
    if (isEmployee(req.user)) {
      const { company, month, year } = reportPeriod(req.body);
      if (!(await canAccessReportClient(db, req.user, company))) {
        return res.status(403).json({
          success: false,
          message: 'You do not have a Task Manager assignment for this client.',
        });
      }
      const [approved] = await db.query(
        `SELECT id FROM report_submissions
         WHERE company_name = ? AND report_month = ? AND report_year = ?
           AND submitted_by_user_id = ? AND status = 'approved'
         ORDER BY created_at DESC LIMIT 1`,
        [company, month, year, req.user.id],
      );
      if (!approved[0]) {
        return res.status(403).json({ success: false, message: 'This report needs admin approval before it can be downloaded. Use "Pass report" to submit it for approval.' });
      }
    }
    const payload = applyPreviewOverrides(req.body || {});
    const format = ['pptx', 'docx', 'pdf'].includes(req.params.format) ? req.params.format : 'pdf';
    const generated = await generateReportFile(payload, format);
    let file = generated.file;
    // Puppeteer's page.pdf() can return a Uint8Array; Express res.send() only
    // treats a Buffer as binary (a Uint8Array would be sent as JSON), so coerce.
    if (!Buffer.isBuffer(file)) file = Buffer.from(file);
    const client = safeFilename(req.body?.clientName);
    const period = safeFilename(req.body?.filePeriod || req.body?.periodLabel);
    const contentType = format === 'pdf'
      ? 'application/pdf'
      : format === 'docx'
      ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      : 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    const fileName = `${client}_Full_Report_${period}.${format}`;

    // Persist to the client's report history so it can be viewed/re-downloaded
    // later. A history failure must never fail the download itself.
    try {
      const now = new Date();
      await saveClientReportHistory({
        clientName: req.body?.clientName,
        clientId: req.body?.clientId ?? req.body?.businessId,
        month: Number(req.body?.reportMonth) || now.getMonth() + 1,
        year: Number(req.body?.reportYear) || now.getFullYear(),
        format,
        fileName,
        contentType,
        file,
        userId: req.user?.id,
        template: generated.template,
        payload,
      });
    } catch (historyError) {
      console.error('Report history save failed:', historyError.message);
    }

    res.set({
      'Content-Type': contentType,
      'Content-Disposition': `attachment; filename="${fileName}"`,
      'Content-Length': file.length,
      'Cache-Control': 'no-store',
    });
    return res.send(file);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    console.error('Full Report export error:', error?.stack || detail);
    // The client needs an actionable message here. Returning a generic error
    // made template/deployment failures impossible to diagnose from the UI.
    return res.status(error.status || 500).json({
      success: false,
      message: `Unable to generate this report: ${detail}`,
    });
  }
}

// ---- Client profiles (logo) ----------------------------------------------
async function saveClientProfile(req, res) {
  try {
    const name = String(req.body?.companyName || '').trim();
    if (!name) return res.status(400).json({ success: false, message: 'A client business name is required.' });
    if (isEmployee(req.user) && !(await canAccessReportClient(db, req.user, name))) {
      return res.status(403).json({
        success: false,
        message: 'You do not have a Task Manager assignment for this client.',
      });
    }
    const logo = req.body?.logoBase64 ? Buffer.from(String(req.body.logoBase64), 'base64') : null;
    const mime = String(req.body?.logoMimeType || 'image/png').slice(0, 150);
    await db.query(
      `INSERT INTO client_profiles (company_name, logo_data, logo_mime_type)
       VALUES (?,?,?)
       ON DUPLICATE KEY UPDATE logo_data = VALUES(logo_data), logo_mime_type = VALUES(logo_mime_type)`,
      [name.slice(0, 255), logo, mime],
    );
    return res.json({ success: true });
  } catch (error) {
    console.error('saveClientProfile error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to save the company logo.' });
  }
}

async function getClientReportCompanies(req, res) {
  try {
    const [profiles] = await db.query('SELECT company_name FROM client_profiles');
    const [history] = await db.query('SELECT DISTINCT company_name FROM client_full_report_history');
    const assigned = isEmployee(req.user)
      ? new Set((await listAssignedReportClients(db, req.user.id)).map((client) => client.name.toLowerCase()))
      : null;
    const set = new Set(
      [...profiles.map((r) => r.company_name), ...history.map((r) => r.company_name)]
        .filter((name) => !assigned || assigned.has(String(name).toLowerCase())),
    );
    return res.json({ success: true, companies: [...set].sort((a, b) => a.localeCompare(b)) });
  } catch (error) {
    console.error('getClientReportCompanies error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load saved clients.' });
  }
}

// Rich client list for the Report dashboard: logo + report count + last report.
async function getClientsDetailed(req, res) {
  try {
    const [profiles] = await db.query(
      `SELECT cp.company_name AS name, cp.logo_data, cp.logo_mime_type,
         (SELECT COUNT(*) FROM client_full_report_history h WHERE h.company_name = cp.company_name) AS report_count,
         (SELECT MAX(h.created_at) FROM client_full_report_history h WHERE h.company_name = cp.company_name) AS last_report_at
       FROM client_profiles cp`,
    );
    const [orphans] = await db.query(
      `SELECT h.company_name AS name, NULL AS logo_data, NULL AS logo_mime_type,
         COUNT(*) AS report_count, MAX(h.created_at) AS last_report_at
       FROM client_full_report_history h
       WHERE h.company_name NOT IN (SELECT company_name FROM client_profiles)
       GROUP BY h.company_name`,
    );
    const assigned = isEmployee(req.user)
      ? new Set((await listAssignedReportClients(db, req.user.id)).map((client) => client.name.toLowerCase()))
      : null;
    const clients = [...profiles, ...orphans]
      .filter((row) => !assigned || assigned.has(String(row.name).toLowerCase()))
      .map((r) => ({
      name: r.name,
      reportCount: Number(r.report_count) || 0,
      lastReportAt: r.last_report_at,
      logoBase64: r.logo_data ? r.logo_data.toString('base64') : null,
      logoMimeType: r.logo_mime_type || null,
    })).sort((a, b) => {
      const ta = a.lastReportAt ? new Date(a.lastReportAt).getTime() : 0;
      const tb = b.lastReportAt ? new Date(b.lastReportAt).getTime() : 0;
      return tb - ta || a.name.localeCompare(b.name);
    });
    return res.json({ success: true, clients });
  } catch (error) {
    console.error('getClientsDetailed error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load clients.' });
  }
}

// ---- Client report history ------------------------------------------------
async function getClientReportHistory(req, res) {
  try {
    const name = String(req.query.companyName || '').trim();
    if (!name) return res.json({ success: true, reports: [] });
    if (isEmployee(req.user) && !(await canAccessReportClient(db, req.user, name))) {
      return res.status(403).json({
        success: false,
        message: 'You do not have a Task Manager assignment for this client.',
      });
    }
    const params = [name];
    let sql = `SELECT id, company_name, report_month, report_year, file_format, file_name, content_type, created_at
               FROM client_full_report_history WHERE company_name = ?`;
    if (req.query.month && req.query.year) {
      sql += ' AND report_month = ? AND report_year = ?';
      params.push(Number(req.query.month), Number(req.query.year));
    }
    sql += ' ORDER BY created_at DESC LIMIT 200';
    const [reports] = await db.query(sql, params);
    const [profile] = await db.query('SELECT logo_data, logo_mime_type FROM client_profiles WHERE company_name = ? LIMIT 1', [name]);
    const out = { success: true, reports };
    if (profile[0]?.logo_data) {
      out.companyLogoBase64 = profile[0].logo_data.toString('base64');
      out.companyLogoMimeType = profile[0].logo_mime_type || 'image/png';
    }
    return res.json(out);
  } catch (error) {
    console.error('getClientReportHistory error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load report history.' });
  }
}

async function downloadClientReportHistory(req, res) {
  try {
    const [rows] = await db.query(
      'SELECT company_name, file_name, content_type, file_data FROM client_full_report_history WHERE id = ? LIMIT 1',
      [req.params.id],
    );
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Saved report not found.' });
    const row = rows[0];
    if (isEmployee(req.user) && !(await canAccessReportClient(db, req.user, row.company_name))) {
      return res.status(403).json({
        success: false,
        message: 'You do not have a Task Manager assignment for this client.',
      });
    }
    res.set({
      'Content-Type': row.content_type,
      'Content-Disposition': `attachment; filename="${row.file_name}"`,
      'Content-Length': row.file_data.length,
      'Cache-Control': 'no-store',
    });
    return res.send(row.file_data);
  } catch (error) {
    console.error('downloadClientReportHistory error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to download the saved report.' });
  }
}

async function deleteClientReportHistory(req, res) {
  try {
    if (!hasReportAdminAccess(req.user)) {
      return res.status(403).json({
        success: false,
        message: 'Only report administrators can delete saved report history.',
      });
    }
    await db.query('DELETE FROM client_full_report_history WHERE id = ?', [req.params.id]);
    return res.json({ success: true });
  } catch (error) {
    console.error('deleteClientReportHistory error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to delete the saved report.' });
  }
}

async function getReportTemplate(req, res) {
  try {
    const template = await findActiveReportTemplate();
    return res.json({
      success: true,
      template: template
        ? {
            id: Number(template.id),
            name: template.name,
            file_name: template.original_filename,
            version: Number(template.version) || 1,
            updated_at: template.created_at,
          }
        : null,
    });
  } catch (error) {
    console.error('getReportTemplate error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load the report template.' });
  }
}

// ---- Approval workflow ----------------------------------------------------
// Employee submits a built report for admin approval ("Pass report").
async function submitReportForApproval(req, res) {
  try {
    const body = req.body || {};
    const { company, month, year } = reportPeriod(body);
    if (isEmployee(req.user) && !(await canAccessReportClient(db, req.user, company))) {
      return res.status(403).json({
        success: false,
        message: 'You do not have a Task Manager assignment for this client.',
      });
    }
    const submitterName = req.user?.fullName || (await userName(req.user?.id)) || 'Employee';
    const [result] = await db.query(
      `INSERT INTO report_submissions (company_name, report_month, report_year, payload, status, submitted_by_user_id, submitted_by_name)
       VALUES (?,?,?,?, 'pending', ?, ?)`,
      [company, month, year, Buffer.from(JSON.stringify(body)), req.user?.id || null, submitterName],
    );
    // Mark every platform this report covers as 'pending' (submitted, awaiting
    // approval). A client's other assigned platforms stay unset, so the UI
    // shows them as still-pending deliverables for the month.
    await setPlatformStatuses({
      company,
      month,
      year,
      platforms: platformKeysFromPayload(body),
      status: 'pending',
      submissionId: result.insertId,
      userId: req.user?.id || null,
      submittedByName: submitterName,
    });
    // Notify every active admin that a report is awaiting approval.
    try {
      const [candidates] = await db.query(
        `SELECT id, full_name AS name, user_type AS userType, role
         FROM employee_users
         WHERE COALESCE(is_active, 1) = 1`,
      );
      for (const candidate of candidates) {
        if (await reportAccessType(db, candidate) !== 'admin') continue;
        await createNotification({
          senderName: submitterName,
          recipientName: candidate.name,
          message: `Report for ${company} (${monthName(month)} ${year}) is ready for your approval.`,
        });
      }
    } catch (notifyError) {
      console.error('Approval notification failed:', notifyError.message);
    }
    return res.json({ success: true, submissionId: result.insertId });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    console.error('submitReportForApproval error:', error?.stack || detail);
    return res.status(500).json({
      success: false,
      message: `Unable to submit the report: ${detail}`,
    });
  }
}

async function listSubmissions(req, res) {
  try {
    const params = [];
    let sql = `SELECT id, company_name, report_month, report_year, status, submitted_by_name,
               reviewed_by_name, review_note, created_at, reviewed_at
               FROM report_submissions WHERE 1 = 1`;
    if (req.query.status) { sql += ' AND status = ?'; params.push(String(req.query.status)); }
    if (req.query.company) { sql += ' AND company_name = ?'; params.push(String(req.query.company)); }
    // Employees only ever see their own submissions; admins see all.
    if (isEmployee(req.user)) { sql += ' AND submitted_by_user_id = ?'; params.push(req.user.id); }
    sql += ' ORDER BY (status = \'pending\') DESC, created_at DESC LIMIT 300';
    const [rows] = await db.query(sql, params);
    return res.json({ success: true, submissions: rows });
  } catch (error) {
    console.error('listSubmissions error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load report submissions.' });
  }
}

// Per-platform submission status for a client (optionally one month). Drives
// the month card's per-platform "Pending / In review / Completed" breakdown and
// its "Completed" ribbon. Employees are limited to clients they can access.
async function listPlatformStatus(req, res) {
  try {
    const company = String(req.query.company || '').trim();
    if (!company) return res.json({ success: true, statuses: [] });
    if (isEmployee(req.user) && !(await canAccessReportClient(db, req.user, company))) {
      return res.status(403).json({
        success: false,
        message: 'You do not have a Task Manager assignment for this client.',
      });
    }
    const params = [company];
    let sql = `SELECT company_name, report_month, report_year, platform_key, status,
               submitted_by_name, updated_at
               FROM report_platform_status WHERE company_name = ?`;
    if (req.query.month && req.query.year) {
      sql += ' AND report_month = ? AND report_year = ?';
      params.push(Number(req.query.month), Number(req.query.year));
    }
    sql += ' ORDER BY report_year DESC, report_month DESC, platform_key';
    const [rows] = await db.query(sql, params);
    return res.json({ success: true, statuses: rows });
  } catch (error) {
    // A missing table (server not yet restarted after deploy) is not an error
    // for the caller — there is simply no per-platform status yet.
    if (/doesn't exist|no such table/i.test(error.message || '')) {
      return res.json({ success: true, statuses: [] });
    }
    console.error('listPlatformStatus error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load platform status.' });
  }
}

// Latest submission status for a client + period (employee download gating UI).
async function latestSubmissionStatus(req, res) {
  try {
    const now = new Date();
    const company = String(req.query.company || '');
    if (isEmployee(req.user) && !(await canAccessReportClient(db, req.user, company))) {
      return res.status(403).json({
        success: false,
        message: 'You do not have a Task Manager assignment for this client.',
      });
    }
    const month = Number(req.query.month) || now.getMonth() + 1;
    const year = Number(req.query.year) || now.getFullYear();
    const [rows] = await db.query(
      `SELECT id, status, review_note, reviewed_by_name, reviewed_at, created_at
       FROM report_submissions
       WHERE company_name = ? AND report_month = ? AND report_year = ?
         ${isEmployee(req.user) ? 'AND submitted_by_user_id = ?' : ''}
       ORDER BY created_at DESC LIMIT 1`,
      isEmployee(req.user)
        ? [company, month, year, req.user.id]
        : [company, month, year],
    );
    return res.json({ success: true, submission: rows[0] || null });
  } catch (error) {
    console.error('latestSubmissionStatus error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load approval status.' });
  }
}

// Admin preview: render the submitted payload to a PDF for review.
async function previewSubmission(req, res) {
  try {
    const [rows] = await db.query(
      'SELECT payload, company_name, submitted_by_user_id FROM report_submissions WHERE id = ? LIMIT 1',
      [req.params.id],
    );
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Submission not found.' });
    if (isEmployee(req.user) && String(rows[0].submitted_by_user_id) !== String(req.user.id)) {
      return res.status(403).json({
        success: false,
        message: 'You can only preview your own report submissions.',
      });
    }
    if (isEmployee(req.user) && !(await canAccessReportClient(db, req.user, rows[0].company_name))) {
      return res.status(403).json({
        success: false,
        message: 'You do not have a Task Manager assignment for this client.',
      });
    }
    const payload = applyPreviewOverrides(JSON.parse(rows[0].payload.toString('utf8')));
    let file = (await generateReportFile(payload, 'pdf')).file;
    if (!Buffer.isBuffer(file)) file = Buffer.from(file);
    res.set({ 'Content-Type': 'application/pdf', 'Content-Disposition': 'inline; filename="report-preview.pdf"', 'Content-Length': file.length, 'Cache-Control': 'no-store' });
    return res.send(file);
  } catch (error) {
    console.error('previewSubmission error:', error.message);
    return res.status(error.status || 500).json({ success: false, message: `Unable to render the preview: ${error.message}` });
  }
}

// Render the current (unsaved) report payload to a PDF for on-screen preview.
// Unlike the download route, this is NOT gated on admin approval, so an
// employee can see exactly how the report will look before passing it or
// downloading it. Task Manager access is still enforced for employees.
async function previewReport(req, res) {
  try {
    const body = req.body || {};
    if (isEmployee(req.user)) {
      const { company } = reportPeriod(body);
      if (!(await canAccessReportClient(db, req.user, company))) {
        return res.status(403).json({
          success: false,
          message: 'You do not have a Task Manager assignment for this client.',
        });
      }
    }
    const payload = applyPreviewOverrides(body);
    if (req.path.endsWith('/slides')) {
      const { file } = await generateReportFile(payload, 'editor');
      res.set('Cache-Control', 'no-store');
      return res.json({ slides: file });
    }
    let file = (await generateReportFile(payload, 'pdf')).file;
    if (!Buffer.isBuffer(file)) file = Buffer.from(file);
    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'inline; filename="report-preview.pdf"',
      'Content-Length': file.length,
      'Cache-Control': 'no-store',
    });
    return res.send(file);
  } catch (error) {
    console.error('previewReport error:', error?.stack || error.message);
    return res.status(error.status || 500).json({
      success: false,
      message: `Unable to render the preview: ${error.message}`,
    });
  }
}

async function reviewSubmission(req, res, decision) {
  try {
    if (!hasReportAdminAccess(req.user)) {
      return res.status(403).json({
        success: false,
        message: 'Report administrator permission is required.',
      });
    }
    const [rows] = await db.query('SELECT company_name, report_month, report_year, submitted_by_name, submitted_by_user_id, payload FROM report_submissions WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Submission not found.' });
    const note = String(req.body?.note || '').slice(0, 2000);
    const reviewerName = req.user?.name || (await userName(req.user?.id)) || 'Admin';
    await db.query(
      'UPDATE report_submissions SET status = ?, reviewed_by_user_id = ?, reviewed_by_name = ?, review_note = ?, reviewed_at = NOW() WHERE id = ?',
      [decision, req.user?.id || null, reviewerName, note || null, req.params.id],
    );
    // Carry the decision down to every platform this report covered, so the
    // client's month card can mark those platforms approved / rejected while
    // any not-yet-submitted platforms stay pending. A platform is "Completed"
    // only once its latest decision is 'approved'.
    try {
      const submittedBody = rows[0].payload
        ? JSON.parse(rows[0].payload.toString('utf8'))
        : {};
      await setPlatformStatuses({
        company: rows[0].company_name,
        month: Number(rows[0].report_month),
        year: Number(rows[0].report_year),
        platforms: platformKeysFromPayload(submittedBody),
        status: decision,
        submissionId: Number(req.params.id) || null,
        userId: rows[0].submitted_by_user_id || null,
        submittedByName: rows[0].submitted_by_name || null,
      });
    } catch (platformError) {
      console.error('Platform status update failed:', platformError.message);
    }
    // Every decision saves a PDF of the report to the client's history, so
    // there is always a record of exactly what was approved/rejected.
    try {
      if (rows[0].payload) {
        const payload = applyPreviewOverrides(JSON.parse(rows[0].payload.toString('utf8')));
        const generated = await generateReportFile(payload, 'pdf');
        let file = generated.file;
        if (!Buffer.isBuffer(file)) file = Buffer.from(file);
        const safeClient = String(rows[0].company_name || 'Client').replace(/[^a-z0-9]+/gi, '_').replace(/^_+|_+$/g, '') || 'Client';
        const period = `${rows[0].report_year}-${String(rows[0].report_month).padStart(2, '0')}`;
        const fileName = `${safeClient}_${decision}_${period}.pdf`.slice(0, 500);
        await saveClientReportHistory({
          clientName: rows[0].company_name,
          clientId: payload.clientId ?? payload.businessId,
          month: Number(rows[0].report_month),
          year: Number(rows[0].report_year),
          format: 'pdf',
          fileName,
          contentType: 'application/pdf',
          file,
          userId: rows[0].submitted_by_user_id,
          template: generated.template,
          payload,
        });
      }
    } catch (saveError) {
      console.error('Review report save failed:', saveError.message);
    }
    try {
      await createNotification({
        senderName: reviewerName,
        recipientName: rows[0].submitted_by_name,
        message: `Your report for ${rows[0].company_name} (${monthName(rows[0].report_month)} ${rows[0].report_year}) was ${decision}.${note ? ` Note: ${note}` : ''}`,
      });
    } catch (notifyError) {
      console.error('Review notification failed:', notifyError.message);
    }
    return res.json({ success: true });
  } catch (error) {
    console.error('reviewSubmission error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to update the submission.' });
  }
}

const approveSubmission = (req, res) => reviewSubmission(req, res, 'approved');
const rejectSubmission = (req, res) => reviewSubmission(req, res, 'rejected');

module.exports = {
  downloadFullReportPpt,
  submitReportForApproval,
  listSubmissions,
  listPlatformStatus,
  latestSubmissionStatus,
  previewSubmission,
  previewReport,
  approveSubmission,
  rejectSubmission,
  saveClientProfile,
  getClientReportCompanies,
  getClientsDetailed,
  getAssignedReportClients: async function getAssignedReportClients(req, res) {
    try {
      if (!isEmployee(req.user)) {
        return res.status(403).json({
          success: false,
          message: 'Assigned report clients are available to employees only.',
        });
      }
      const clients = await listAssignedReportClients(db, req.user.id);
      return res.json({ success: true, clients });
    } catch (error) {
      console.error('getAssignedReportClients error:', error.message);
      return res.status(error.status || 500).json({
        success: false,
        message: error.status ? error.message : 'Unable to load assigned report clients.',
      });
    }
  },
  getClientReportHistory,
  downloadClientReportHistory,
  deleteClientReportHistory,
  getReportTemplate,
};
