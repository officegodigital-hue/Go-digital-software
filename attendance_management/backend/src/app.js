const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');

const pool = require('./config/database');


// ================= ROUTES =================

const authRoutes =
require('./routes/auth.routes');

const attendanceRoutes =
require('./routes/attendance.routes');

const attendanceHistoryRoutes =
require('./routes/attendanceHistory.routes');

const adminAttendanceRoutes =
require('./routes/adminAttendance.routes');

const adminCalendarRoutes =
require('./routes/adminCalendar.routes');

const leaveRoutes =
require('./routes/leave.routes');

const notificationRoutes =
require('./routes/notification.routes');

const employeeRoutes =
require('./routes/employee.routes');

const permissionRoutes =
require('./routes/permission.routes');


// Employee permission routes
const employeePermissionRoutes =
require('./routes/employeePermission.routes');


// NEW - Admin notification routes
const adminNotificationRoutes =
require('./routes/adminNotification.routes');


const payrollSalaryMasterRoutes =
require('./routes/payrollSalaryMaster.routes');

const payrollRoutes =
require('./routes/payroll.routes');


// ================= MIDDLEWARE =================

const {
  notFoundHandler,
  errorHandler,
} = require('./middlewares/error.middleware');


const app = express();


/**
 * Hide Express header
 */
app.disable('x-powered-by');


/**
 * Security headers
 */
app.use(
  helmet({
    crossOriginResourcePolicy: {
      policy: 'cross-origin',
    },
  })
);


/**
 * CORS
 */
app.use(
  cors({
    origin: true,

    credentials: true,

    methods: [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'OPTIONS',
    ],

    allowedHeaders: [
      'Content-Type',
      'Authorization',
    ],
  })
);


/**
 * Body parser
 */
app.use(
  express.json({
    limit: '2mb',
  })
);


app.use(
  express.urlencoded({
    extended: true,
    limit: '2mb',
  })
);


// ================= FILE UPLOAD =================

const uploadsDirectory =
path.resolve(
  __dirname,
  '../uploads'
);


app.use(
  '/uploads',
  express.static(
    uploadsDirectory,
    {
      fallthrough: false,

      setHeaders: (res) => {
        res.setHeader(
          'Cross-Origin-Resource-Policy',
          'cross-origin'
        );

        res.setHeader(
          'Cache-Control',
          'public,max-age=86400'
        );
      },
    }
  )
);


// ================= HEALTH =================

app.get(
  '/health',
  (req, res) => {
    res.status(200).json({
      success: true,

      message:
        'Attendance API is running',

      timestamp:
        new Date().toISOString(),
    });
  }
);


app.get(
  '/db-health',
  async (req, res, next) => {
    try {
      const [rows] =
        await pool.execute(
          `
          SELECT
            DATABASE() AS database_name,
            NOW() AS database_time
          `
        );

      res.status(200).json({
        success: true,

        message:
          'MySQL database connected successfully',

        data: {
          database:
            rows[0]?.database_name || null,

          database_time:
            rows[0]?.database_time || null,
        },
      });
    } catch (error) {
      next(error);
    }
  }
);


// ================= API ROUTES =================


/**
 * Authentication
 *
 * /api/v1/auth
 */
app.use(
  '/api/v1/auth',
  authRoutes
);


/**
 * Employee Attendance
 *
 * /api/v1/attendance
 */
app.use(
  '/api/v1/attendance',
  attendanceRoutes
);


/**
 * Attendance History
 *
 * /api/v1/attendance
 */
app.use(
  '/api/v1/attendance',
  attendanceHistoryRoutes
);


/**
 * Admin Attendance
 *
 * /api/v1/admin/attendance
 */
app.use(
  '/api/v1/admin/attendance',
  adminAttendanceRoutes
);


/**
 * Admin Calendar / Holidays
 *
 * /api/v1/admin/calendar
 */
app.use(
  '/api/v1/admin/calendar',
  adminCalendarRoutes
);


/**
 * Employee Leave
 *
 * /api/v1/leaves
 */
app.use(
  '/api/v1/leaves',
  leaveRoutes
);


/**
 * Employee Notifications
 *
 * /api/v1/notifications
 *
 * Used by Employee Mobile Alerts screen
 */
app.use(
  '/api/v1/notifications',
  notificationRoutes
);


/**
 * Admin Notifications
 *
 * GET
 * /api/v1/admin/notifications
 *
 * GET
 * /api/v1/admin/notifications/unread-count
 *
 * PATCH
 * /api/v1/admin/notifications/read-all
 *
 * PATCH
 * /api/v1/admin/notifications/:notificationId/read
 *
 * DELETE
 * /api/v1/admin/notifications/:notificationId
 */
app.use(
  '/api/v1/admin/notifications',
  adminNotificationRoutes
);


/**
 * Employee Management
 *
 * /api/v1/admin/employees
 */
app.use(
  '/api/v1/admin/employees',
  employeeRoutes
);


// =====================================================
// EMPLOYEE PERMISSION
// =====================================================

/**
 * Employee Permission Requests
 *
 * POST
 * /api/v1/permissions
 *
 * Employee can submit:
 *
 * late_login
 * early_logout
 */
app.use(
  '/api/v1/permissions',
  employeePermissionRoutes
);


// =====================================================
// ADMIN PERMISSION
// =====================================================

/**
 * Admin Permission Management
 *
 * GET
 * /api/v1/admin/permissions
 *
 * GET
 * /api/v1/admin/permissions/summary
 *
 * PATCH
 * /api/v1/admin/permissions/:permissionId/approve
 *
 * PATCH
 * /api/v1/admin/permissions/:permissionId/reject
 */
app.use(
  '/api/v1/admin/permissions',
  permissionRoutes
);


// ================= PAYROLL =================


/**
 * Payroll Salary Master
 *
 * GET
 * /api/v1/admin/payroll/salary-masters
 */
app.use(
  '/api/v1/admin/payroll/salary-masters',
  payrollSalaryMasterRoutes
);


/**
 * Payroll Generation
 *
 * POST
 * /api/v1/admin/payroll/generate
 *
 * GET
 * /api/v1/admin/payroll/runs
 */
app.use(
  '/api/v1/admin/payroll',
  payrollRoutes
);


// ================= ERROR HANDLER =================

app.use(
  notFoundHandler
);


app.use(
  errorHandler
);


module.exports = app;