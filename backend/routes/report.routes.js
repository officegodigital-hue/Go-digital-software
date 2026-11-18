const express = require('express');
const router = express.Router();

// Import controllers
const { readDashboardOcr } = require('../controllers/dashboardOcr.controller');
const {
  downloadFullReportPpt,
  saveClientProfile,
  getClientReportCompanies,
  getClientsDetailed,
  getClientReportHistory,
  downloadClientReportHistory,
  deleteClientReportHistory,
  saveReportTemplate,
  getReportTemplate,
  submitReportForApproval,
  listSubmissions,
  latestSubmissionStatus,
  previewSubmission,
  approveSubmission,
  rejectSubmission,
} = require('../controllers/fullReportPpt.controller');

// Authentication middleware
const { authenticateToken } = require('../middleware/auth.middleware');

// 1. Dashboard OCR reading route
router.post('/dashboard-ocr/read', authenticateToken, readDashboardOcr);

// 2. Report document export route (pptx, docx, pdf)
router.post('/report-export/full-report/:format', authenticateToken, downloadFullReportPpt);

// 3. Client profile (logo) + saved clients
router.put('/report-export/client-profile', authenticateToken, saveClientProfile);
router.get('/report-export/client-companies', authenticateToken, getClientReportCompanies);
router.get('/report-export/clients', authenticateToken, getClientsDetailed);

// 4. Client report history (list / download / delete)
router.get('/report-export/client-history', authenticateToken, getClientReportHistory);
router.get('/report-export/client-history/:id/download', authenticateToken, downloadClientReportHistory);
router.delete('/report-export/client-history/:id', authenticateToken, deleteClientReportHistory);

// 5. Shared report template
router.get('/report-export/template', authenticateToken, getReportTemplate);
router.put('/report-export/template', authenticateToken, saveReportTemplate);

// 6. Approval workflow (employee submits, admin reviews, download gated)
router.post('/report-export/submit', authenticateToken, submitReportForApproval);
router.get('/report-export/submissions', authenticateToken, listSubmissions);
router.get('/report-export/submissions/status', authenticateToken, latestSubmissionStatus);
router.get('/report-export/submissions/:id/preview.pdf', authenticateToken, previewSubmission);
router.post('/report-export/submissions/:id/approve', authenticateToken, approveSubmission);
router.post('/report-export/submissions/:id/reject', authenticateToken, rejectSubmission);

module.exports = router;