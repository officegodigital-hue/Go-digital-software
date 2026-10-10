const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsTrackingController');

router.use(authenticateToken);
router.get('/settings', hrms.getTrackingSettings);
router.put('/settings', hrms.requireAdmin, hrms.updateTrackingSettings);
// router.put('/office-location', hrms.requireAdmin, hrms.updateOfficeLocation);
// router.put('/home-settings', hrms.requireAdmin, hrms.updateHomeSettings);
// router.put('/hybrid-settings', hrms.requireAdmin, hrms.updateHybridSettings);

// Employee self-service — called from the mobile app
router.post('/status', hrms.setStatus);
router.post('/ping', hrms.ping);

// Admin dashboard views
router.get('/', hrms.requireAdmin, hrms.list);
router.get('/live', hrms.requireAdmin, hrms.liveOverview);
router.get('/route/me', hrms.myRouteHistory);
router.get('/route/:employeeUserId', hrms.requireAdmin, hrms.routeHistory);
router.get('/employee/:employeeUserId/monthly', hrms.requireAdmin, hrms.monthlyReport);

router.get('/home-location', hrms.getMyHomeLocation);
router.post('/home-location', hrms.submitHomeLocation);

router.get('/home-locations', hrms.requireAdmin, hrms.listHomeLocations);
router.patch(
  '/home-locations/:employeeUserId',
  hrms.requireAdmin,
  hrms.reviewHomeLocation
);
router.get('/field-waiting-alert', hrms.getMyWaitingAlert);
router.post(
  '/field-waiting-reasons/:id',
  hrms.submitWaitingReason
);

router.get(
  '/field-waiting-reasons',
  hrms.requireAdmin,
  hrms.listFieldWaitingReasons
);

router.patch(
  '/field-waiting-reasons/:id/review',
  hrms.requireAdmin,
  hrms.reviewFieldWaitingReason
);

router.get('/field-session', hrms.getMyFieldSession);
router.post('/field-session/start', hrms.startFieldTracking);
router.post('/field-session/stop', hrms.stopFieldTracking);
// Public Hybrid routes. The older field-session URLs remain as compatibility
// aliases; live tracking itself is now available only to Hybrid employees.
router.get('/hybrid-session', hrms.getMyFieldSession);
router.post('/hybrid-session/start', hrms.startFieldTracking);
router.post('/hybrid-session/stop', hrms.stopFieldTracking);
router.get('/hybrid-waiting-alert', hrms.getMyWaitingAlert);
router.post('/hybrid-waiting-reasons/:id', hrms.submitWaitingReason);
router.get('/hybrid-waiting-reasons', hrms.requireAdmin, hrms.listFieldWaitingReasons);
router.patch('/hybrid-waiting-reasons/:id/review', hrms.requireAdmin, hrms.reviewFieldWaitingReason);
router.get('/field-waiting-alert', hrms.getMyWaitingAlert);

router.post(
  '/field-waiting-reasons/:id',
  hrms.submitWaitingReason
);

router.get(
  '/field-waiting-reasons',
  hrms.requireAdmin,
  hrms.listFieldWaitingReasons
);

router.patch(
  '/field-waiting-reasons/:id/review',
  hrms.requireAdmin,
  hrms.reviewFieldWaitingReason
);
module.exports = router;
