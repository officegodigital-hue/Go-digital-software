const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');

const pool = require('./config/database');

const authRoutes = require(
  './routes/auth.routes',
);

const attendanceRoutes = require(
  './routes/attendance.routes',
);

const attendanceHistoryRoutes = require(
  './routes/attendanceHistory.routes',
);

const adminAttendanceRoutes = require(
  './routes/adminAttendance.routes',
);

const leaveRoutes = require(
  './routes/leave.routes',
);

const notificationRoutes = require(
  './routes/notification.routes',
);

const employeeRoutes = require(
  './routes/employee.routes',
);

const {
  notFoundHandler,
  errorHandler,
} = require(
  './middlewares/error.middleware',
);

const app = express();

/**
 * Hide Express information from response headers.
 */
app.disable('x-powered-by');

/**
 * Add security headers.
 *
 * cross-origin is required because Flutter Web
 * runs on port 5003 and loads images from port 3000.
 */
app.use(
  helmet({
    crossOriginResourcePolicy: {
      policy: 'cross-origin',
    },
  }),
);

/**
 * Allow Flutter Web, Flutter Mobile
 * and other approved clients.
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
  }),
);

/**
 * Parse JSON request bodies.
 */
app.use(
  express.json({
    limit: '2mb',
  }),
);

/**
 * Parse URL-encoded request bodies.
 */
app.use(
  express.urlencoded({
    extended: true,
    limit: '2mb',
  }),
);

/**
 * Make uploaded images publicly accessible.
 *
 * Physical folder:
 * backend/uploads
 *
 * Public URL:
 * http://localhost:3000/uploads/employee-profiles/file-name.png
 */
const uploadsDirectory = path.resolve(
  __dirname,
  '../uploads',
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
          'cross-origin',
        );

        res.setHeader(
          'Cache-Control',
          'public, max-age=86400',
        );
      },
    },
  ),
);

/**
 * Backend health endpoint.
 *
 * GET http://localhost:3000/health
 */
app.get(
  '/health',
  (req, res) => {
    return res.status(200).json({
      success: true,
      message:
        'Attendance API is running',
      timestamp:
        new Date().toISOString(),
    });
  },
);

/**
 * MySQL database health endpoint.
 *
 * GET http://localhost:3000/db-health
 */
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
          `,
        );

      return res.status(200).json({
        success: true,

        message:
          'MySQL database connected successfully',

        data: {
          database:
            rows[0]?.database_name ??
            null,

          database_time:
            rows[0]?.database_time ??
            null,
        },
      });
    } catch (error) {
      return next(error);
    }
  },
);

/**
 * Authentication routes.
 *
 * POST /api/v1/auth/login
 * GET  /api/v1/auth/me
 */
app.use(
  '/api/v1/auth',
  authRoutes,
);

/**
 * Current-day employee attendance routes.
 */
app.use(
  '/api/v1/attendance',
  attendanceRoutes,
);

/**
 * Employee attendance history routes.
 */
app.use(
  '/api/v1/attendance',
  attendanceHistoryRoutes,
);

/**
 * Admin Daily Attendance Log routes.
 *
 * GET /api/v1/admin/attendance
 */
app.use(
  '/api/v1/admin/attendance',
  adminAttendanceRoutes,
);

/**
 * Leave routes.
 */
app.use(
  '/api/v1/leaves',
  leaveRoutes,
);

/**
 * Notification routes.
 */
app.use(
  '/api/v1/notifications',
  notificationRoutes,
);

/**
 * Admin employee-management routes.
 *
 * GET    /api/v1/admin/employees
 * GET    /api/v1/admin/employees/:employeeId
 * POST   /api/v1/admin/employees
 * PUT    /api/v1/admin/employees/:employeeId
 * DELETE /api/v1/admin/employees/:employeeId
 *
 * Profile image upload:
 *
 * POST /api/v1/admin/employees/profile-image
 */
app.use(
  '/api/v1/admin/employees',
  employeeRoutes,
);

/**
 * Error handlers must remain after
 * static files and all API routes.
 */
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;