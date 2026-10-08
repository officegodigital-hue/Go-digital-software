const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsDashboardController');

router.use(authenticateToken);
router.use(hrms.requireAdmin);

router.get('/time-settings', hrms.timeSettings);
router.put('/time-settings', hrms.updateTimeSettings);
router.get('/calendar', hrms.calendar);
router.put('/calendar', hrms.updateCalendar);
router.get('/', hrms.monthView);

module.exports = router;
