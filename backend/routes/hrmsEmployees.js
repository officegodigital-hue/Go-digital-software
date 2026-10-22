// const express = require('express');
// const router = express.Router();
// const { authenticateToken } = require('./auth');
// const hrms = require('../controllers/hrmsEmployeesController');
// const profile = require('../controllers/hrmsEmployeeProfileController');

// router.use(authenticateToken);
// router.use(hrms.requireAdmin);

// router.get('/summary', hrms.summary);
// router.get('/export', hrms.exportCsv);
// router.get('/:id/profile', profile.getProfile);
// router.get('/', hrms.list);
// router.post('/', hrms.create);
// router.put('/:id', hrms.update);
// router.patch('/:id/status', hrms.updateStatus);
// router.delete('/:id', hrms.remove);

// module.exports = router;

const express = require('express');
const router = express.Router();
const { authenticateToken } = require('./auth');
const hrms = require('../controllers/hrmsEmployeesController');
const profile = require('../controllers/hrmsEmployeeProfileController');
const { syncStatusFromProfile } = require('../lib/attendanceProfileSync');

router.use(authenticateToken);
router.use(hrms.requireAdmin);

// After the Attendance page changes an employee (status / details), keep the
// Admin Panel (employee_users.is_active) the same.
const syncAdminStatus = (req, res, next) => {
  res.on('finish', () => {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      syncStatusFromProfile(req.params.id).catch((err) =>
        console.warn('Attendance → Admin Panel status sync failed:', err.message));
    }
  });
  next();
};

router.get('/summary', hrms.summary);
router.get('/export', hrms.exportCsv);
router.get('/:id/profile', profile.getProfile);
router.get('/', hrms.list);
// Employees are added in the Admin Panel (Employee Management). This stays
// for old screens / imports only.
router.post('/', hrms.create);
router.put('/:id', syncAdminStatus, hrms.update);
router.patch('/:id/status', syncAdminStatus, hrms.updateStatus);
router.delete('/:id', hrms.remove);

module.exports = router;
