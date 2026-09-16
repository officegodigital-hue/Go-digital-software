const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsEmployeesController');

router.use(authenticateToken);
router.use(hrms.requireAdmin);

router.get('/summary', hrms.summary);
router.get('/export', hrms.exportCsv);
router.post('/roles', hrms.createRole);
router.get('/', hrms.list);
router.post('/', hrms.create);
router.put('/:id', hrms.update);
router.post('/:id/reset-password', hrms.resetPassword);
router.patch('/:id/status', hrms.updateStatus);
router.delete('/:id', hrms.remove);

module.exports = router;
