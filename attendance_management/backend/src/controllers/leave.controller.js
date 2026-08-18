const asyncHandler = require('../utils/asyncHandler');
const { sendSuccess } = require('../utils/apiResponse');

const leaveService = require(
  '../services/leave.service',
);

/**
 * GET /api/v1/leaves/dashboard
 * GET /api/v1/leaves/dashboard?year=2026
 *
 * Returns:
 * - Employee information
 * - Leave balances
 * - Leave request summary
 */
const getLeaveDashboard = asyncHandler(
  async (req, res) => {
    const data =
      await leaveService.getLeaveDashboard({
        employeeId: req.auth.employeeId,
        year: req.query.year,
      });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Leave dashboard fetched successfully',
      data,
    });
  },
);

/**
 * GET /api/v1/leaves/history
 * GET /api/v1/leaves/history?year=2026
 * GET /api/v1/leaves/history?status=pending
 * GET /api/v1/leaves/history?year=2026&status=approved
 */
const getLeaveHistory = asyncHandler(
  async (req, res) => {
    const data =
      await leaveService.getLeaveHistory({
        employeeId: req.auth.employeeId,
        year: req.query.year,
        status: req.query.status,
      });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Leave history fetched successfully',
      data,
    });
  },
);

/**
 * POST /api/v1/leaves
 *
 * Request body:
 * {
 *   "leave_type_id": 1,
 *   "start_date": "2026-07-25",
 *   "end_date": "2026-07-25",
 *   "day_type": "full_day",
 *   "reason": "Personal work",
 *   "attachment_url": null
 * }
 */
const applyLeave = asyncHandler(
  async (req, res) => {
    const {
      leave_type_id: leaveTypeIdSnakeCase,
      leaveTypeId: leaveTypeIdCamelCase,

      start_date: startDateSnakeCase,
      startDate: startDateCamelCase,

      end_date: endDateSnakeCase,
      endDate: endDateCamelCase,

      day_type: dayTypeSnakeCase,
      dayType: dayTypeCamelCase,

      reason,

      attachment_url:
        attachmentUrlSnakeCase,

      attachmentUrl:
        attachmentUrlCamelCase,
    } = req.body;

    const data = await leaveService.applyLeave({
      employeeId: req.auth.employeeId,

      leaveTypeId:
        leaveTypeIdSnakeCase ??
        leaveTypeIdCamelCase,

      startDate:
        startDateSnakeCase ??
        startDateCamelCase,

      endDate:
        endDateSnakeCase ??
        endDateCamelCase,

      dayType:
        dayTypeSnakeCase ??
        dayTypeCamelCase ??
        'full_day',

      reason,

      attachmentUrl:
        attachmentUrlSnakeCase ??
        attachmentUrlCamelCase,
    });

    return sendSuccess(res, {
      statusCode: 201,
      message:
        'Leave request submitted successfully',
      data,
    });
  },
);

/**
 * PATCH /api/v1/leaves/:leaveRequestId/cancel
 *
 * Request body:
 * {
 *   "cancellation_reason": "Plans changed"
 * }
 */
const cancelLeave = asyncHandler(
  async (req, res) => {
    const {
      cancellation_reason:
        cancellationReasonSnakeCase,

      cancellationReason:
        cancellationReasonCamelCase,
    } = req.body;

    const data =
      await leaveService.cancelLeave({
        employeeId: req.auth.employeeId,

        leaveRequestId:
          req.params.leaveRequestId,

        cancellationReason:
          cancellationReasonSnakeCase ??
          cancellationReasonCamelCase,
      });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Leave request cancelled successfully',
      data,
    });
  },
);

module.exports = {
  getLeaveDashboard,
  getLeaveHistory,
  applyLeave,
  cancelLeave,
};