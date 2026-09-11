const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const attendance = require('../controllers/attendanceController');

router.use(authenticateToken);

// Both portals keep their existing URL.  The signed-in user determines the
// response shape, while both response paths read the same attendance_records.
router.get('/dashboard', function (req, res, next) {
  const userType = String((req.user && req.user.userType) || '').toLowerCase();
  if (userType === 'admin') return attendance.dashboard(req, res, next);
  return attendance.employeeDashboard(req, res, next);
});
router.get('/export', attendance.requireAdmin, attendance.exportCsv);
router.get('/permissions', attendance.requireAdmin, attendance.adminPermissions);
router.patch('/permissions/:id', attendance.requireAdmin, attendance.reviewPermission);

router.get('/me', attendance.myHistory);
router.get('/me/export', attendance.myExport);
router.get('/check-in-policy', attendance.checkInPolicy);
router.post('/check-in', attendance.checkIn);
router.post('/check-out', attendance.checkOut);
// Compatibility with the employee module's original API contract.
router.post('/clock-in', attendance.checkIn);
router.post('/clock-out', attendance.checkOut);
router.get('/permissions/mine', attendance.myPermissions);
router.post('/permissions', attendance.createPermission);

module.exports = router;
