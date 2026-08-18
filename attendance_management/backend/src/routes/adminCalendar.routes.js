const express = require('express');

const {
  authenticate,
} = require(
  '../middlewares/auth.middleware',
);

const {
  getAdminCalendar,
  getAdminHolidayById,
  createAdminHoliday,
  updateAdminHoliday,
  deleteAdminHoliday,
} = require(
  '../controllers/adminCalendar.controller',
);

const router = express.Router();

/**
 * All Admin Calendar routes require
 * a valid admin Bearer token.
 */
router.use(authenticate);

/**
 * GET /api/v1/admin/calendar
 *
 * Query parameters:
 * year
 * month
 * from_date
 * to_date
 * search
 * type
 * upcoming
 * include_inactive
 */
router.get(
  '/',
  getAdminCalendar,
);

/**
 * GET /api/v1/admin/calendar/:holidayId
 */
router.get(
  '/:holidayId',
  getAdminHolidayById,
);

/**
 * POST /api/v1/admin/calendar
 */
router.post(
  '/',
  createAdminHoliday,
);

/**
 * PUT /api/v1/admin/calendar/:holidayId
 */
router.put(
  '/:holidayId',
  updateAdminHoliday,
);

/**
 * PATCH /api/v1/admin/calendar/:holidayId
 */
router.patch(
  '/:holidayId',
  updateAdminHoliday,
);

/**
 * DELETE /api/v1/admin/calendar/:holidayId
 *
 * Performs a soft delete.
 */
router.delete(
  '/:holidayId',
  deleteAdminHoliday,
);

module.exports = router;