const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsPayrollController');

router.use(authenticateToken);
router.use(hrms.requireAdmin);

router.get('/', hrms.list);
router.get('/leave-policy', hrms.getPaidLeavePolicy);
router.put('/leave-policy', hrms.updatePaidLeavePolicy);
router.post('/generate', hrms.generate);
router.patch('/:id', hrms.markPaid);

module.exports = router;
