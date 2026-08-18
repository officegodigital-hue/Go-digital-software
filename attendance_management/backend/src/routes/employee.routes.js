const express = require('express');
const fs = require('fs');
const path = require('path');

const employeeController = require(
  '../controllers/employee.controller',
);

const {
  uploadEmployeeProfileImage,
} = require(
  '../controllers/employeeProfileImage.controller',
);

const {
  profileImageUpload,
} = require(
  '../middlewares/profileImageUpload.middleware',
);

const {
  authenticate,
} = require(
  '../middlewares/auth.middleware',
);

const router = express.Router();

const errorLogPath = path.join(
  process.cwd(),
  'employee-api-error.log',
);

function logEmployeeRouteError(
  req,
  error,
) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    method: req.method,
    originalUrl: req.originalUrl,
    params: req.params,
    query: req.query,
    auth: req.auth || null,
    error: {
      name: error?.name || null,
      message:
        error?.message ||
        String(error),
      code: error?.code || null,
      errno: error?.errno || null,
      sqlState:
        error?.sqlState || null,
      sqlMessage:
        error?.sqlMessage || null,
      sql: error?.sql || null,
      stack: error?.stack || null,
    },
  };

  const output =
    `${JSON.stringify(
      logEntry,
      null,
      2,
    )}\n\n`;

  console.error(
    '\nEMPLOYEE API ERROR\n',
    output,
  );

  try {
    fs.appendFileSync(
      errorLogPath,
      output,
      'utf8',
    );
  } catch (logError) {
    console.error(
      'Unable to write employee API error log:',
      logError,
    );
  }
}

/**
 * Forward both synchronous errors and rejected
 * async controller promises to the centralized
 * error middleware.
 */
function asyncHandler(handler) {
  return function wrappedAsyncHandler(
    req,
    res,
    next,
  ) {
    try {
      Promise.resolve(
        handler(req, res, next),
      ).catch((error) => {
        logEmployeeRouteError(
          req,
          error,
        );

        next(error);
      });
    } catch (error) {
      logEmployeeRouteError(
        req,
        error,
      );

      next(error);
    }
  };
}

/**
 * Every employee-management endpoint requires
 * a valid Bearer access token.
 */
router.use(authenticate);

/**
 * Upload an employee profile image.
 *
 * POST /api/v1/admin/employees/profile-image
 *
 * Content-Type:
 * multipart/form-data
 *
 * Multipart field:
 * profile_image
 *
 * Keep this route above /:employeeId.
 */
router.post(
  '/profile-image',
  profileImageUpload,
  asyncHandler(
    uploadEmployeeProfileImage,
  ),
);

/**
 * Get all employees.
 *
 * GET /api/v1/admin/employees
 */
router.get(
  '/',
  asyncHandler(
    employeeController.getEmployees,
  ),
);

/**
 * Create an employee.
 *
 * POST /api/v1/admin/employees
 */
router.post(
  '/',
  asyncHandler(
    employeeController.createEmployee,
  ),
);

/**
 * Get one employee.
 *
 * GET /api/v1/admin/employees/:employeeId
 */
router.get(
  '/:employeeId',
  asyncHandler(
    employeeController.getEmployeeById,
  ),
);

/**
 * Update employee information.
 *
 * PUT /api/v1/admin/employees/:employeeId
 */
router.put(
  '/:employeeId',
  asyncHandler(
    employeeController.updateEmployee,
  ),
);

/**
 * Activate or deactivate an employee.
 *
 * PATCH /api/v1/admin/employees/:employeeId/status
 */
router.patch(
  '/:employeeId/status',
  asyncHandler(
    employeeController.updateEmployeeStatus,
  ),
);

/**
 * Update employee mobile-app credentials.
 *
 * PATCH /api/v1/admin/employees/:employeeId/credentials
 */
router.patch(
  '/:employeeId/credentials',
  asyncHandler(
    employeeController.updateEmployeeCredentials,
  ),
);

/**
 * Reset employee mobile-app password.
 *
 * PATCH /api/v1/admin/employees/:employeeId/reset-password
 */
router.patch(
  '/:employeeId/reset-password',
  asyncHandler(
    employeeController.resetEmployeePassword,
  ),
);

/**
 * Enable or disable employee mobile login.
 *
 * PATCH /api/v1/admin/employees/:employeeId/login-status
 */
router.patch(
  '/:employeeId/login-status',
  asyncHandler(
    employeeController.updateEmployeeLoginStatus,
  ),
);

/**
 * Soft-delete an employee.
 *
 * DELETE /api/v1/admin/employees/:employeeId
 */
router.delete(
  '/:employeeId',
  asyncHandler(
    employeeController.deleteEmployee,
  ),
);

module.exports = router;