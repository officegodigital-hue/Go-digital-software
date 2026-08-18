const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../utils/AppError');

const {
  sendSuccess,
} = require('../utils/apiResponse');

const attendanceService = require(
  '../services/attendance.service',
);

/**
 * GET /api/v1/admin/attendance
 *
 * Admin Daily Attendance Log.
 *
 * Supported query parameters:
 *
 * from_date=2026-08-01
 * to_date=2026-08-31
 * search=employee name or code
 * status=all|present|late|absent
 * session_status=all|active|completed
 * page=1
 * limit=20
 * export=true
 */
const getAdminAttendanceLog =
  asyncHandler(
    async (req, res) => {
      if (
        String(
          req.auth?.role || '',
        ).toLowerCase() !== 'admin'
      ) {
        throw new AppError(
          403,
          'ADMIN_ACCESS_REQUIRED',
          'Admin access is required',
        );
      }

      const data =
        await attendanceService
          .getAdminAttendanceLog({
            companyId:
              req.auth.companyId,

            branchId:
              req.auth.branchId ||
              null,

            filters: {
              fromDate:
                req.query.from_date ??
                req.query.fromDate,

              toDate:
                req.query.to_date ??
                req.query.toDate,

              search:
                req.query.search,

              status:
                req.query.status,

              sessionStatus:
                req.query
                  .session_status ??
                req.query
                  .sessionStatus,

              page:
                req.query.page,

              limit:
                req.query.limit,

              export:
                req.query.export,
            },
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Attendance log fetched successfully',

        data,
      });
    },
  );

/**
 * GET /api/v1/attendance/today
 *
 * Returns the logged-in employee's attendance
 * status for the current company-local date.
 */
const getToday =
  asyncHandler(
    async (req, res) => {
      const data =
        await attendanceService
          .getTodayAttendance({
            employeeId:
              req.auth.employeeId,
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Today attendance fetched successfully',

        data,
      });
    },
  );

/**
 * POST /api/v1/attendance/check-in
 *
 * Optional body:
 * {
 *   "location": {
 *     "latitude": 12.921456,
 *     "longitude": 80.127845,
 *     "accuracy_meters": 10,
 *     "is_mocked": false
 *   }
 * }
 */
const checkIn =
  asyncHandler(
    async (req, res) => {
      const data =
        await attendanceService
          .checkIn({
            employeeId:
              req.auth.employeeId,

            body:
              req.body || {},
          });

      return sendSuccess(res, {
        statusCode: 200,
        message:
          'Check-in successful',
        data,
      });
    },
  );

/**
 * POST /api/v1/attendance/check-out
 *
 * Optional body:
 * {
 *   "location": {
 *     "latitude": 12.921456,
 *     "longitude": 80.127845,
 *     "accuracy_meters": 10,
 *     "is_mocked": false
 *   }
 * }
 */
const checkOut =
  asyncHandler(
    async (req, res) => {
      const data =
        await attendanceService
          .checkOut({
            employeeId:
              req.auth.employeeId,

            body:
              req.body || {},
          });

      return sendSuccess(res, {
        statusCode: 200,
        message:
          'Check-out successful',
        data,
      });
    },
  );

/**
 * POST /api/v1/attendance/breaks/start
 */
const startBreak =
  asyncHandler(
    async (req, res) => {
      const data =
        await attendanceService
          .startBreak({
            employeeId:
              req.auth.employeeId,
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Break started successfully',

        data,
      });
    },
  );

/**
 * POST /api/v1/attendance/breaks/end
 */
const endBreak =
  asyncHandler(
    async (req, res) => {
      const data =
        await attendanceService
          .endBreak({
            employeeId:
              req.auth.employeeId,
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Break ended successfully',

        data,
      });
    },
  );

module.exports = {
  getAdminAttendanceLog,
  getToday,
  checkIn,
  checkOut,
  startBreak,
  endBreak,
};