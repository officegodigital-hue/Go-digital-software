const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsApprovalsController');

const soundDir = path.join(__dirname, '..', 'uploads', 'notification-sounds');
fs.mkdirSync(soundDir, { recursive: true });
const soundUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, soundDir),
    filename: (_req, file, cb) => {
      const extension = path.extname(file.originalname).toLowerCase();
      cb(null, `notification-${Date.now()}${extension}`);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = new Set(['.mp3', '.wav', '.m4a', '.aac', '.ogg']);
    const extension = path.extname(file.originalname).toLowerCase();
    cb(null, allowed.has(extension));
  },
});

router.use(authenticateToken);
// Employees may read the administrator's selected alert sound so the
// navigation-independent waiting prompt can use the same audio. Mutations
// remain protected by the admin middleware below.
router.get('/notifications/settings', hrms.notificationSettings);
router.use(hrms.requireAdmin);

router.get('/notifications', hrms.notifications);
router.patch('/notifications/read-all', hrms.markAllNotificationsRead);
router.put('/notifications/settings', hrms.updateNotificationSettings);
router.post('/notifications/settings/sound', soundUpload.single('sound'), hrms.uploadNotificationSound);
router.get('/', hrms.list);
router.patch('/:id', hrms.review);

module.exports = router;
