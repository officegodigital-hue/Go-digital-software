const express = require('express');

const {
  authenticate,
} = require('../middlewares/auth.middleware');

const {
  getNotifications,
  getUnreadCount,
  getNotificationById,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
} = require(
  '../controllers/notification.controller',
);

const router = express.Router();

/**
 * All notification routes require
 * a valid employee JWT token.
 */
router.use(authenticate);

/**
 * GET /api/v1/notifications
 * GET /api/v1/notifications?unread_only=true
 */
router.get(
  '/',
  getNotifications,
);

/**
 * GET /api/v1/notifications/unread-count
 *
 * This route must remain before
 * /:notificationId.
 */
router.get(
  '/unread-count',
  getUnreadCount,
);

/**
 * PATCH /api/v1/notifications/read-all
 *
 * This route must remain before
 * /:notificationId routes.
 */
router.patch(
  '/read-all',
  markAllNotificationsAsRead,
);

/**
 * GET /api/v1/notifications/:notificationId
 */
router.get(
  '/:notificationId',
  getNotificationById,
);

/**
 * PATCH /api/v1/notifications/:notificationId/read
 */
router.patch(
  '/:notificationId/read',
  markNotificationAsRead,
);

/**
 * DELETE /api/v1/notifications/:notificationId
 */
router.delete(
  '/:notificationId',
  deleteNotification,
);

module.exports = router;