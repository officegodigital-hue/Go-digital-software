const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../utils/AppError');

const {
  sendSuccess,
} = require('../utils/apiResponse');

const adminCalendarService = require(
  '../services/adminCalendar.service',
);

const requireAdmin = (
  req,
) => {
  const role =
    String(
      req.auth?.role || '',
    )
      .trim()
      .toLowerCase();

  if (role !== 'admin') {
    throw new AppError(
      403,
      'ADMIN_ACCESS_REQUIRED',
      'Admin access is required',
    );
  }

  if (!req.auth?.companyId) {
    throw new AppError(
      403,
      'ADMIN_COMPANY_REQUIRED',
      'Admin company access is required',
    );
  }

  if (!req.auth?.branchId) {
    throw new AppError(
      403,
      'ADMIN_BRANCH_REQUIRED',
      'Admin branch access is required',
    );
  }
};

/**
 * GET /api/v1/admin/calendar
 *
 * Supported query parameters:
 *
 * year=2026
 * month=8
 * from_date=2026-08-01
 * to_date=2026-08-31
 * search=holiday name
 * type=all|public|optional|company|regional
 * upcoming=true
 * include_inactive=false
 */
const getAdminCalendar =
  asyncHandler(
    async (req, res) => {
      requireAdmin(req);

      const data =
        await adminCalendarService
          .getAdminCalendar({
            companyId:
              req.auth.companyId,

            branchId:
              req.auth.branchId,

            filters: {
              year:
                req.query.year,

              month:
                req.query.month,

              fromDate:
                req.query.from_date ??
                req.query.fromDate,

              toDate:
                req.query.to_date ??
                req.query.toDate,

              search:
                req.query.search,

              type:
                req.query.type ??
                req.query.holiday_type ??
                req.query.holidayType,

              upcoming:
                req.query.upcoming,

              includeInactive:
                req.query.include_inactive ??
                req.query.includeInactive,
            },
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Holiday calendar fetched successfully',

        data,
      });
    },
  );

/**
 * GET /api/v1/admin/calendar/:holidayId
 */
const getAdminHolidayById =
  asyncHandler(
    async (req, res) => {
      requireAdmin(req);

      const data =
        await adminCalendarService
          .getHolidayById({
            holidayId:
              req.params.holidayId,

            companyId:
              req.auth.companyId,

            branchId:
              req.auth.branchId,
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Holiday fetched successfully',

        data,
      });
    },
  );

/**
 * POST /api/v1/admin/calendar
 *
 * Body:
 * {
 *   "holiday_name": "Independence Day",
 *   "holiday_date": "2026-08-15",
 *   "holiday_type": "public",
 *   "description": "National holiday",
 *   "is_active": true
 * }
 */
const createAdminHoliday =
  asyncHandler(
    async (req, res) => {
      requireAdmin(req);

      const data =
        await adminCalendarService
          .createHoliday({
            companyId:
              req.auth.companyId,

            branchId:
              req.auth.branchId,

            payload:
              req.body || {},
          });

      return sendSuccess(res, {
        statusCode: 201,

        message:
          'Holiday created successfully',

        data,
      });
    },
  );

/**
 * PUT /api/v1/admin/calendar/:holidayId
 *
 * PATCH is also supported by the route file.
 *
 * Body fields are optional:
 * {
 *   "holiday_name": "Updated name",
 *   "holiday_date": "2026-08-16",
 *   "holiday_type": "company",
 *   "description": "Updated description",
 *   "is_active": true
 * }
 */
const updateAdminHoliday =
  asyncHandler(
    async (req, res) => {
      requireAdmin(req);

      const data =
        await adminCalendarService
          .updateHoliday({
            holidayId:
              req.params.holidayId,

            companyId:
              req.auth.companyId,

            branchId:
              req.auth.branchId,

            payload:
              req.body || {},
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Holiday updated successfully',

        data,
      });
    },
  );

/**
 * DELETE /api/v1/admin/calendar/:holidayId
 *
 * Performs a soft delete.
 */
const deleteAdminHoliday =
  asyncHandler(
    async (req, res) => {
      requireAdmin(req);

      const data =
        await adminCalendarService
          .deleteHoliday({
            holidayId:
              req.params.holidayId,

            companyId:
              req.auth.companyId,

            branchId:
              req.auth.branchId,
          });

      return sendSuccess(res, {
        statusCode: 200,

        message:
          'Holiday deleted successfully',

        data,
      });
    },
  );

module.exports = {
  getAdminCalendar,
  getAdminHolidayById,
  createAdminHoliday,
  updateAdminHoliday,
  deleteAdminHoliday,
};