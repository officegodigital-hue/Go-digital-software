const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../routes/auth');
const leavePolicies = require('./leavePolicies');

// Define admin validation middleware
const requireAdmin = (req, res, next) => {
  const userType = String((req.user && req.user.userType) || '').toLowerCase();
  if (userType === 'admin') return next();
  return res.status(403).json({ message: 'Access denied: Admins only' });
};

// Define controller handler functions safely
const dashboard = (req, res) => res.json({ message: 'Admin Dashboard' });
const employeeDashboard = (req, res) => res.json({ message: 'Employee Dashboard' });
const clockLogs = (req, res) => res.json({ message: 'Clock Logs endpoint' });
const exportCsv = (req, res) => res.json({ message: 'Export CSV endpoint' });
const adminPermissions = (req, res) => res.json({ message: 'Admin Permissions endpoint' });
const reviewPermission = (req, res) => res.json({ message: 'Review Permission endpoint' });
const myHistory = (req, res) => res.json({ message: 'My History endpoint' });
const myExport = (req, res) => res.json({ message: 'My Export endpoint' });
const checkInPolicy = (req, res) => res.json({ message: 'Check-in Policy endpoint' });
const checkIn = (req, res) => res.json({ message: 'Check-in successful' });
const checkOut = (req, res) => res.json({ message: 'Check-out successful' });
const startBreak = (req, res) => res.json({ message: 'Break started' });
const endBreak = (req, res) => res.json({ message: 'Break ended' });
const submitExceededBreakComment = (req, res) => res.json({ message: 'Comment submitted' });
const heartbeat = (req, res) => res.json({ status: 'ok' });
const createReclockInRequest = (req, res) => res.json({ message: 'Reclock-in request created' });
const myPermissions = (req, res) => res.json({ message: 'My Permissions endpoint' });
const createPermission = (req, res) => res.json({ message: 'Permission created' });

// Apply authentication middleware to all routes below
router.use(authenticateToken);

router.use('/leave/policies', requireAdmin);
router.get('/leave/policies', requireAdmin, leavePolicies.list);
router.put('/leave/policies/:id', requireAdmin, leavePolicies.save);

// Both portals keep their existing URL. The signed-in user determines the response shape.
router.get('/dashboard', function (req, res, next) {
  const userType = String((req.user && req.user.userType) || '').toLowerCase();
  if (userType === 'admin') return dashboard(req, res, next);
  return employeeDashboard(req, res, next);
});

router.get('/clock-logs', requireAdmin, clockLogs);
router.get('/export', requireAdmin, exportCsv);
router.get('/permissions', requireAdmin, adminPermissions);
router.patch('/permissions/:id', requireAdmin, reviewPermission);

router.get('/me', myHistory);
router.get('/me/export', myExport);
router.get('/check-in-policy', checkInPolicy);
router.post('/check-in', checkIn);
router.post('/check-out', checkOut);
router.post('/break-in', startBreak);
router.post('/break-out', endBreak);
router.post('/break-exceeded-comment', submitExceededBreakComment);
router.post('/heartbeat', heartbeat);

// Compatibility with the employee module's original API contract.
router.post('/clock-in', checkIn);
router.post('/clock-out', checkOut);
router.post('/reclock-in-request', createReclockInRequest);
router.get('/permissions/mine', myPermissions);
router.post('/permissions', createPermission);

module.exports = router;