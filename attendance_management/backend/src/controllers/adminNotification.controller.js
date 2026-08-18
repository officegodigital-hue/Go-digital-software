const asyncHandler = require(
  '../utils/asyncHandler',
);

const {
  sendSuccess,
} = require(
  '../utils/apiResponse',
);

const adminNotificationService =
  require(
    '../services/adminNotification.service',
  );

const getCompanyId = (req) => {
  return (
    req.auth?.companyId ??
    req.auth?.company_id ??
    null
  );
};

const getBranchId = (req) => {
  return (
    req.auth?.branchId ??
    req.auth?.branch_id ??
    null
  );
};

const parseBoolean = (value) => {
  if (
    value === undefined ||
    value === null
  ) {
    return false;
  }

  return [
    'true',
    '1',
    'yes',
    'on',
  ].includes(
    String(value)
      .trim()
      .toLowerCase(),
  );
};

// GET /api/v1/admin/notifications

const getNotifications =
  asyncHandler(
    async (req, res) => {
      const data =
        await adminNotificationService
          .getNotifications({
            companyId:
              getCompanyId(req),

            branchId:
              req.query.branchId ??
              req.query.branch_id ??
              null,

            unreadOnly:
              parseBoolean(
                req.query.unread_only ??
                  req.query.unreadOnly,
              ),

            page:
              req.query.page ?? 1,

            limit:
              req.query.limit ?? 50,
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Admin notifications fetched successfully',

        data,
      });
    },
  );

// GET /api/v1/admin/notifications/unread-count

const getUnreadCount =
  asyncHandler(
    async (req, res) => {
      const data =
        await adminNotificationService
          .getUnreadCount({
            companyId:
              getCompanyId(req),

            branchId:
              getBranchId(req),
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Admin unread notification count fetched successfully',

        data,
      });
    },
  );

// GET /api/v1/admin/notifications/:notificationId

const getNotificationById =
  asyncHandler(
    async (req, res) => {
      const data =
        await adminNotificationService
          .getNotificationById({
            notificationId:
              req.params.notificationId,

            companyId:
              getCompanyId(req),
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Admin notification fetched successfully',

        data,
      });
    },
  );

// PATCH /api/v1/admin/notifications/:notificationId/read

const markAsRead =
  asyncHandler(
    async (req, res) => {
      const data =
        await adminNotificationService
          .markAsRead({
            notificationId:
              req.params.notificationId,

            companyId:
              getCompanyId(req),
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Admin notification marked as read',

        data,
      });
    },
  );

// PATCH /api/v1/admin/notifications/read-all

const markAllAsRead =
  asyncHandler(
    async (req, res) => {
      const data =
        await adminNotificationService
          .markAllAsRead({
            companyId:
              getCompanyId(req),

            branchId:
              getBranchId(req),
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'All admin notifications marked as read',

        data,
      });
    },
  );

// DELETE /api/v1/admin/notifications/:notificationId

const deleteNotification =
  asyncHandler(
    async (req, res) => {
      const data =
        await adminNotificationService
          .deleteNotification({
            notificationId:
              req.params.notificationId,

            companyId:
              getCompanyId(req),
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Admin notification deleted successfully',

        data,
      });
    },
  );

module.exports = {
  getNotifications,
  getUnreadCount,
  getNotificationById,
  markAsRead,
  markAllAsRead,
  deleteNotification,
};