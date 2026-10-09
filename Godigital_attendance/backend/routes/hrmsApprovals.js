const express = require('express');
const multer = require('multer');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsApprovalsController');
const notificationSoundUpload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

router.use(authenticateToken);
router.use(hrms.requireAdmin);

router.get('/notifications', hrms.notifications);
router.patch('/notifications/read-all', hrms.markAllNotificationsRead);
router.get('/notifications/settings', hrms.notificationSettings);
router.put('/notifications/settings', hrms.saveNotificationSettings);
router.post('/notifications/settings/sound', notificationSoundUpload.single('sound'), hrms.uploadNotificationSound);
router.get('/', hrms.list);
router.patch('/:id', hrms.review);

module.exports = router;
