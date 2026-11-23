const express = require('express');
const router = express.Router();

// Import controllers
const { readDashboardOcr } = require('../controllers/dashboardOcr.controller');
const {
  downloadFullReportPpt,
  saveClientProfile,
  getClientReportCompanies,
  getClientsDetailed,
  getAssignedReportClients,
  getClientReportHistory,
  downloadClientReportHistory,
  deleteClientReportHistory,
  getReportTemplate,
  submitReportForApproval,
  listSubmissions,
  latestSubmissionStatus,
  previewSubmission,
  previewReport,
  approveSubmission,
  rejectSubmission,
} = require('../controllers/fullReportPpt.controller');

const {
  listAssignableEmployees,
  listReportClients,
  upsertReportClient,
  assignEmployee,
  revokeAssignment,
  deleteReportClient,
} = require('../controllers/reportClients.controller');

const {
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
} = require('../controllers/reportTemplates.controller');

// Authentication middleware
const { authenticateToken } = require('../middleware/auth.middleware');
const db = require('../config/db');
const { reportAccessType } = require('../lib/reportTaskAccess');

router.use(authenticateToken);
router.use(async (req, res, next) => {
  try {
    const accessType = await reportAccessType(db, req.user);
    if (accessType === 'none') {
      return res.status(403).json({
        success: false,
        message: 'Report access has not been granted to this account.',
      });
    }
    req.user.reportAccessType = accessType;
    return next();
  } catch (error) {
    return next(error);
  }
});

// 1. Dashboard OCR reading route
router.post('/dashboard-ocr/read', readDashboardOcr);

// 2. Report document export route (pptx, docx, pdf)
router.post('/report-export/full-report/:format', downloadFullReportPpt);
// Render the current payload to a PDF for on-screen preview (no approval gate).
router.post('/report-export/preview', previewReport);

// 3. Client profile (logo) + saved clients
router.put('/report-export/client-profile', saveClientProfile);
router.get('/report-export/client-companies', getClientReportCompanies);
router.get('/report-export/clients', getClientsDetailed);
router.get('/report-export/assigned-clients', getAssignedReportClients);

// 4. Client report history (list / download / delete)
router.get('/report-export/client-history', getClientReportHistory);
router.get('/report-export/client-history/:id/download', downloadClientReportHistory);
router.delete('/report-export/client-history/:id', deleteClientReportHistory);

// 5. Shared report template
router.get('/report-export/template', getReportTemplate);
router.put('/report-export/template', (req, res) => {
  req.body = { ...(req.body || {}), activate: true };
  return uploadTemplate(req, res);
});

// 6. Approval workflow (employee submits, admin reviews, download gated)
router.post('/report-export/submit', submitReportForApproval);
router.get('/report-export/submissions', listSubmissions);
router.get('/report-export/submissions/status', latestSubmissionStatus);
router.get('/report-export/submissions/:id/preview.pdf', previewSubmission);
router.post('/report-export/submissions/:id/approve', approveSubmission);
router.post('/report-export/submissions/:id/reject', rejectSubmission);

// Admin: report-module client creation, assignment and provider management.
router.get('/report-export/report-employees', listAssignableEmployees);
router.get('/report-export/report-clients', listReportClients);
router.post('/report-export/report-clients', upsertReportClient);
router.post('/report-export/report-clients/assign', assignEmployee);
router.post('/report-export/report-clients/revoke', revokeAssignment);
router.delete('/report-export/report-clients/:company', deleteReportClient);

// Admin: multi-template library (upload / list / activate / delete) + pages.
router.get('/report-export/templates', listTemplates);
router.get('/report-export/templates/active', getActiveTemplate);
router.post('/report-export/templates', uploadTemplate);
router.post('/report-export/templates/:id/activate', activateTemplate);
router.post('/report-export/templates/:id/deactivate', deactivateTemplate);
router.delete('/report-export/templates/:id', deleteTemplate);
router.get('/report-export/templates/:id/preview.pdf', previewTemplate);
router.get('/report-export/templates/:id/download', downloadTemplate);
router.get('/report-export/templates/:id/fields', getTemplateFields);
router.get('/report-export/templates/pages', getTemplatePages);
router.get('/report-export/templates/:id/pages', getTemplatePages);

module.exports = router;
