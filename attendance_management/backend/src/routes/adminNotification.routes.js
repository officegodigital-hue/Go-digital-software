const express = require(
  'express',
);

const {
  authenticate,
} = require(
  '../middlewares/auth.middleware',
);

const {
  getNotifications,
  getUnreadCount,
  getNotificationById,
  markAsRead,
  markAllAsRead,
  deleteNotification,
} = require(
  '../controllers/adminNotification.controller',
);

const router =
  express.Router();

router.use(
  authenticate,
);

router.get(
  '/',
  getNotifications,
);

router.get(
  '/unread-count',
  getUnreadCount,
);

router.patch(
  '/read-all',
  markAllAsRead,
);

router.get(
  '/:notificationId',
  getNotificationById,
);

router.patch(
  '/:notificationId/read',
  markAsRead,
);

router.delete(
  '/:notificationId',
  deleteNotification,
);

module.exports = router;