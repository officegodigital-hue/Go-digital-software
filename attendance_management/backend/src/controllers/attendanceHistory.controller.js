const asyncHandler = require('../utils/asyncHandler');
const { sendSuccess } = require('../utils/apiResponse');

const attendanceHistoryService = require(
  '../services/attendanceHistory.service',
);

/**
 * GET /api/v1/attendance/history
 *
 * Optional query:
 * ?month=2026-07
 */
const getAttendanceHistory = asyncHandler(
  async (req, res) => {
    const data =
      await attendanceHistoryService
        .getAttendanceHistory({
          employeeId: req.auth.employeeId,
          month: req.query.month,
        });

    return sendSuccess(res, {
      statusCode: 200,
      message:
        'Attendance history fetched successfully',
      data,
    });
  },
);

module.exports = {
  getAttendanceHistory,
};