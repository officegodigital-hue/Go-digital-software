const express = require('express');

const {
  authenticate,
} = require('../middlewares/auth.middleware');

const {
  getAttendanceHistory,
} = require('../controllers/attendanceHistory.controller');

const router = express.Router();

/**
 * All attendance-history routes require
 * a valid employee JWT token.
 */
router.use(authenticate);

/**
 * GET /api/v1/attendance/history
 *
 * Optional month filter:
 * GET /api/v1/attendance/history?month=2026-07
 */
router.get(
  '/history',
  getAttendanceHistory,
);

module.exports = router;