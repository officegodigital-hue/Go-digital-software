const express = require('express');
const authenticate = require('../middleware/auth.middleware');
const requireRole = require('../middleware/role.middleware');
const { downloadFullReportPpt, getClientReportHistory, getClientReportCompanies, saveClientProfile, downloadClientReportHistory, deleteClientReportHistory, getReportTemplate, saveReportTemplate } = require('../controllers/fullReportPpt.controller');

const router = express.Router();
router.use(authenticate);
router.use(requireRole('USER', 'ADMIN', 'EMPLOYEE'));
router.get('/client-history', getClientReportHistory);
router.get('/client-companies', getClientReportCompanies);
router.put('/client-profile', saveClientProfile);
router.get('/client-history/:historyId/download', downloadClientReportHistory);
router.delete('/client-history/:historyId', deleteClientReportHistory);
router.get('/template', getReportTemplate);
router.put('/template', saveReportTemplate);
router.post('/full-report.:format', downloadFullReportPpt);

module.exports = router;
