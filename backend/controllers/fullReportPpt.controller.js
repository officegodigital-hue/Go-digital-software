const { canAccessBusiness } = require('../middleware/businessAccess.middleware');
const db = require('../config/db');
const { createNotification } = require('../routes/notifications');
const { buildReportHtml } = require('../services/reportHtml.service');
const { renderHtmlToPdf, renderHtmlToImages } = require('../services/fullReportRender.service');
const { buildPptxFromImages } = require('../services/fullReportPpt.service');
const { buildDocxFromImages } = require('../services/fullReportWord.service');

function safeFilename(value) {
  return String(value || 'Business').replace(/[^a-z0-9]+/gi, '_').replace(/^_+|_+$/g, '') || 'Business';
}

const _MONTHS = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
function monthName(m) { const n = Number(m); return (n >= 1 && n <= 12) ? _MONTHS[n] : `${m}`; }

// Employees must get approval before downloading; admins/owners download freely.
function isEmployee(user) { return String(user?.role || '').toUpperCase() === 'EMPLOYEE'; }

async function userName(id) {
  if (!id) return null;
  try {
    const [rows] = await db.query('SELECT name FROM users WHERE id = ? LIMIT 1', [id]);
    return rows[0]?.name || null;
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

async function downloadFullReportPpt(req, res) {
  try {
    const businessId = Number.parseInt(req.body?.businessId, 10);
    const screenshotOnly = req.body?.reportTemplate === 'EMPLOYEE_ADMIN' && (!Number.isSafeInteger(businessId) || businessId < 1);
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
      const [approved] = await db.query(
        "SELECT id FROM report_submissions WHERE company_name = ? AND report_month = ? AND report_year = ? AND status = 'approved' ORDER BY created_at DESC LIMIT 1",
        [company, month, year],
      );
      if (!approved[0]) {
        return res.status(403).json({ success: false, message: 'This report needs admin approval before it can be downloaded. Use "Pass report" to submit it for approval.' });
      }
    }
    const payload = applyPreviewOverrides(req.body || {});
    const format = ['pptx', 'docx', 'pdf'].includes(req.params.format) ? req.params.format : 'pdf';
    const html = buildReportHtml(payload);
    let file;
    if (format === 'pdf') {
      file = await renderHtmlToPdf(html);
    } else {
      const images = await renderHtmlToImages(html);
      file = format === 'pptx'
        ? await buildPptxFromImages(images)
        : await buildDocxFromImages(images);
    }
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
      await db.query(
        'INSERT INTO client_full_report_history (company_name, report_month, report_year, file_format, file_name, content_type, file_data, downloaded_by_user_id) VALUES (?,?,?,?,?,?,?,?)',
        [
          String(req.body?.clientName || 'Client').slice(0, 255),
          Number(req.body?.reportMonth) || now.getMonth() + 1,
          Number(req.body?.reportYear) || now.getFullYear(),
          format,
          fileName.slice(0, 500),
          contentType,
          file,
          req.user?.id || null,
        ],
      );
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
    return res.status(500).json({
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
    const set = new Set([...profiles.map((r) => r.company_name), ...history.map((r) => r.company_name)]);
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
    const clients = [...profiles, ...orphans].map((r) => ({
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
    const [rows] = await db.query('SELECT file_name, content_type, file_data FROM client_full_report_history WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Saved report not found.' });
    const row = rows[0];
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
    await db.query('DELETE FROM client_full_report_history WHERE id = ?', [req.params.id]);
    return res.json({ success: true });
  } catch (error) {
    console.error('deleteClientReportHistory error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to delete the saved report.' });
  }
}

// ---- Shared report template ----------------------------------------------
async function saveReportTemplate(req, res) {
  try {
    const data = req.body?.bytesBase64 ? Buffer.from(String(req.body.bytesBase64), 'base64') : null;
    if (!data || !data.length) return res.status(400).json({ success: false, message: 'No template file was provided.' });
    const fileName = String(req.body?.fileName || 'report-template.pptx').slice(0, 500);
    await db.query(
      `INSERT INTO report_templates (scope, file_name, template_data, uploaded_by_user_id)
       VALUES (?,?,?,?)
       ON DUPLICATE KEY UPDATE file_name = VALUES(file_name), template_data = VALUES(template_data), uploaded_by_user_id = VALUES(uploaded_by_user_id)`,
      ['EMPLOYEE_ADMIN', fileName, data, req.user?.id || null],
    );
    return res.json({ success: true });
  } catch (error) {
    console.error('saveReportTemplate error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to save the report template.' });
  }
}

async function getReportTemplate(req, res) {
  try {
    const [rows] = await db.query('SELECT file_name, updated_at FROM report_templates WHERE scope = ? LIMIT 1', ['EMPLOYEE_ADMIN']);
    return res.json({ success: true, template: rows[0] || null });
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
    const submitterName = req.user?.name || (await userName(req.user?.id)) || 'Employee';
    const [result] = await db.query(
      `INSERT INTO report_submissions (company_name, report_month, report_year, payload, status, submitted_by_user_id, submitted_by_name)
       VALUES (?,?,?,?, 'pending', ?, ?)`,
      [company, month, year, Buffer.from(JSON.stringify(body)), req.user?.id || null, submitterName],
    );
    // Notify every active admin that a report is awaiting approval.
    try {
      const [admins] = await db.query("SELECT name FROM users WHERE role = 'Admin' AND is_active = 1");
      for (const admin of admins) {
        await createNotification({
          senderName: submitterName,
          recipientName: admin.name,
          message: `Report for ${company} (${monthName(month)} ${year}) is ready for your approval.`,
        });
      }
    } catch (notifyError) {
      console.error('Approval notification failed:', notifyError.message);
    }
    return res.json({ success: true, submissionId: result.insertId });
  } catch (error) {
    console.error('submitReportForApproval error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to submit the report for approval.' });
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

// Latest submission status for a client + period (employee download gating UI).
async function latestSubmissionStatus(req, res) {
  try {
    const now = new Date();
    const company = String(req.query.company || '');
    const month = Number(req.query.month) || now.getMonth() + 1;
    const year = Number(req.query.year) || now.getFullYear();
    const [rows] = await db.query(
      'SELECT id, status, review_note, reviewed_by_name, reviewed_at, created_at FROM report_submissions WHERE company_name = ? AND report_month = ? AND report_year = ? ORDER BY created_at DESC LIMIT 1',
      [company, month, year],
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
    const [rows] = await db.query('SELECT payload FROM report_submissions WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Submission not found.' });
    const payload = applyPreviewOverrides(JSON.parse(rows[0].payload.toString('utf8')));
    let file = await renderHtmlToPdf(buildReportHtml(payload));
    if (!Buffer.isBuffer(file)) file = Buffer.from(file);
    res.set({ 'Content-Type': 'application/pdf', 'Content-Disposition': 'inline; filename="report-preview.pdf"', 'Content-Length': file.length, 'Cache-Control': 'no-store' });
    return res.send(file);
  } catch (error) {
    console.error('previewSubmission error:', error.message);
    return res.status(500).json({ success: false, message: `Unable to render the preview: ${error.message}` });
  }
}

async function reviewSubmission(req, res, decision) {
  try {
    const [rows] = await db.query('SELECT company_name, report_month, report_year, submitted_by_name FROM report_submissions WHERE id = ? LIMIT 1', [req.params.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'Submission not found.' });
    const note = String(req.body?.note || '').slice(0, 2000);
    const reviewerName = req.user?.name || (await userName(req.user?.id)) || 'Admin';
    await db.query(
      'UPDATE report_submissions SET status = ?, reviewed_by_user_id = ?, reviewed_by_name = ?, review_note = ?, reviewed_at = NOW() WHERE id = ?',
      [decision, req.user?.id || null, reviewerName, note || null, req.params.id],
    );
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
  latestSubmissionStatus,
  previewSubmission,
  approveSubmission,
  rejectSubmission,
  saveClientProfile,
  getClientReportCompanies,
  getClientsDetailed,
  getClientReportHistory,
  downloadClientReportHistory,
  deleteClientReportHistory,
  saveReportTemplate,
  getReportTemplate,
};
