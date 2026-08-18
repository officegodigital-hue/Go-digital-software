const express = require('express');

const {
  authenticate,
} = require('../middlewares/auth.middleware');

const {
  getToday,
  checkIn,
  checkOut,
  startBreak,
  endBreak,
} = require('../controllers/attendance.controller');

const router = express.Router();

/**
 * All attendance routes require a valid JWT token.
 */
router.use(authenticate);

/**
 * GET /api/v1/attendance/today
 *
 * Returns today's attendance, shift, break,
 * office location and available actions.
 */
router.get('/today', getToday);

/**
 * POST /api/v1/attendance/check-in
 *
 * Optional JSON body:
 * {
 *   "location": {
 *     "latitude": 12.921456,
 *     "longitude": 80.127845,
 *     "accuracy_meters": 10,
 *     "is_mocked": false
 *   }
 * }
 */
router.post('/check-in', checkIn);

/**
 * POST /api/v1/attendance/check-out
 *
 * Optional JSON body:
 * {
 *   "location": {
 *     "latitude": 12.921456,
 *     "longitude": 80.127845,
 *     "accuracy_meters": 10,
 *     "is_mocked": false
 *   }
 * }
 */
router.post('/check-out', checkOut);

/**
 * POST /api/v1/attendance/breaks/start
 */
router.post('/breaks/start', startBreak);

/**
 * POST /api/v1/attendance/breaks/end
 */
router.post('/breaks/end', endBreak);

module.exports = router;