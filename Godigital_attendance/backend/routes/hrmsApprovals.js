const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsApprovalsController');

router.use(authenticateToken);
router.use(hrms.requireAdmin);

router.get('/notifications', hrms.notifications);
router.patch('/notifications/read-all', hrms.markAllNotificationsRead);
router.get('/leave-policies', hrms.leavePolicies);
router.put('/leave-policies', hrms.updateLeavePolicies);
router.get('/', hrms.list);
router.patch('/:id', hrms.review);

module.exports = router;
