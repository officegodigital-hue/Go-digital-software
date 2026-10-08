const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsEmployeesController');
const profile = require('../controllers/hrmsEmployeeProfileController');

router.use(authenticateToken);
router.use(hrms.requireAdmin);

router.get('/summary', hrms.summary);
router.get('/export', hrms.exportCsv);
router.get('/:id/profile', profile.getProfile);
router.get('/', hrms.list);
router.post('/', hrms.create);
router.put('/:id', hrms.update);
router.patch('/:id/status', hrms.updateStatus);
router.delete('/:id', hrms.remove);

module.exports = router;