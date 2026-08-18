const express = require('express');

const {
  authenticate,
} = require('../middlewares/auth.middleware');

const {
  getLeaveDashboard,
  getLeaveHistory,
  applyLeave,
  cancelLeave,
} = require('../controllers/leave.controller');

const router = express.Router();

/**
 * All leave routes require a valid employee JWT.
 */
router.use(authenticate);

/**
 * GET /api/v1/leaves/dashboard
 * GET /api/v1/leaves/dashboard?year=2026
 */
router.get(
  '/dashboard',
  getLeaveDashboard,
);

/**
 * GET /api/v1/leaves/history
 * GET /api/v1/leaves/history?year=2026
 * GET /api/v1/leaves/history?status=pending
 */
router.get(
  '/history',
  getLeaveHistory,
);

/**
 * POST /api/v1/leaves
 *
 * Example body:
 * {
 *   "leave_type_id": 1,
 *   "start_date": "2026-07-25",
 *   "end_date": "2026-07-25",
 *   "day_type": "full_day",
 *   "reason": "Personal work",
 *   "attachment_url": null
 * }
 */
router.post(
  '/',
  applyLeave,
);

/**
 * PATCH /api/v1/leaves/:leaveRequestId/cancel
 *
 * Example body:
 * {
 *   "cancellation_reason": "Plans changed"
 * }
 */
router.patch(
  '/:leaveRequestId/cancel',
  cancelLeave,
);

module.exports = router;