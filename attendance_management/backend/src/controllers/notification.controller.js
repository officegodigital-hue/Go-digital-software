const asyncHandler = require(
  '../utils/asyncHandler',
);

const {
  sendSuccess,
} = require('../utils/apiResponse');

const notificationService = require(
  '../services/notification.service',
);

/**
 * Convert query parameter values into boolean values.
 */
const parseBooleanQuery = (
  value,
) => {
  if (value === undefined || value === null) {
    return false;
  }

  const normalizedValue = String(value)
    .trim()
    .toLowerCase();

  return [
    'true',
    '1',
    'yes',
    'on',
  ].includes(normalizedValue);
};

/**
 * GET /api/v1/notifications
 * GET /api/v1/notifications?unread_only=true
 */
const getNotifications = asyncHandler(
  async (req, res) => {
    const unreadOnly = parseBooleanQuery(
      req.query.unread_only ??
        req.query.unreadOnly,
    );

    const data =
      await notificationService.getNotifications({
        employeeId: req.auth.employeeId,
        unreadOnly,
      });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Notifications fetched successfully',
      data,
    });
  },
);

/**
 * GET /api/v1/notifications/unread-count
 */
const getUnreadCount = asyncHandler(
  async (req, res) => {
    const data =
      await notificationService.getUnreadCount({
        employeeId: req.auth.employeeId,
      });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Unread notification count fetched successfully',
      data,
    });
  },
);

/**
 * GET /api/v1/notifications/:notificationId
 */
const getNotificationById = asyncHandler(
  async (req, res) => {
    const data =
      await notificationService.getNotificationById({
        employeeId: req.auth.employeeId,

        notificationId:
          req.params.notificationId,
      });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Notification fetched successfully',
      data,
    });
  },
);

/**
 * PATCH /api/v1/notifications/:notificationId/read
 */
const markNotificationAsRead = asyncHandler(
  async (req, res) => {
    const data =
      await notificationService
        .markNotificationAsRead({
          employeeId: req.auth.employeeId,

          notificationId:
            req.params.notificationId,
        });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Notification marked as read',
      data,
    });
  },
);

/**
 * PATCH /api/v1/notifications/read-all
 */
const markAllNotificationsAsRead =
  asyncHandler(
    async (req, res) => {
      const data =
        await notificationService
          .markAllNotificationsAsRead({
            employeeId:
              req.auth.employeeId,
          });

      return sendSuccess(res, {
        statusCode: 200,
        message:
          'All notifications marked as read',
        data,
      });
    },
  );

/**
 * DELETE /api/v1/notifications/:notificationId
 */
const deleteNotification = asyncHandler(
  async (req, res) => {
    const data =
      await notificationService.deleteNotification({
        employeeId: req.auth.employeeId,

        notificationId:
          req.params.notificationId,
      });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Notification deleted successfully',
      data,
    });
  },
);

module.exports = {
  getNotifications,
  getUnreadCount,
  getNotificationById,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
};