const express = require('express');

const PermissionController = require(
  '../controllers/permission.controller'
);

const {
  authenticate,
} = require('../middlewares/auth.middleware');

const router = express.Router();

/**
 * All admin permission routes require authentication.
 *
 * Mounted at:
 * /api/v1/admin/permissions
 */
router.use(authenticate);

/**
 * GET /api/v1/admin/permissions/summary
 */
router.get(
  '/summary',
  PermissionController.getPermissionSummary
);

/**
 * GET /api/v1/admin/permissions
 */
router.get(
  '/',
  PermissionController.getPermissionRequests
);

/**
 * GET /api/v1/admin/permissions/:permissionId
 */
router.get(
  '/:permissionId',
  PermissionController.getPermissionById
);

/**
 * PATCH /api/v1/admin/permissions/:permissionId/status
 */
router.patch(
  '/:permissionId/status',
  PermissionController.updatePermissionStatus
);

/**
 * PATCH /api/v1/admin/permissions/:permissionId/approve
 */
router.patch(
  '/:permissionId/approve',
  PermissionController.approvePermission
);

/**
 * PATCH /api/v1/admin/permissions/:permissionId/reject
 */
router.patch(
  '/:permissionId/reject',
  PermissionController.rejectPermission
);

module.exports = router;