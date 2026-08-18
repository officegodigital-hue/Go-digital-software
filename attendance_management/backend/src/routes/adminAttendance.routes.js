const express = require('express');

const {
  authenticate,
} = require(
  '../middlewares/auth.middleware',
);

const {
  getAdminAttendanceLog,
} = require(
  '../controllers/attendance.controller',
);

const router = express.Router();

/**
 * Every Admin Attendance endpoint requires
 * a valid Bearer access token.
 */
router.use(authenticate);

/**
 * GET /api/v1/admin/attendance
 *
 * Query parameters:
 * from_date
 * to_date
 * search
 * status
 * session_status
 * page
 * limit
 * export
 */
router.get(
  '/',
  getAdminAttendanceLog,
);

module.exports = router;