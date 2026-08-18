const express = require('express');

const PermissionController = require(
  '../controllers/permission.controller'
);

const {
  authenticate,
} = require('../middlewares/auth.middleware');

const router = express.Router();

/**
 * Employee Permission APIs
 *
 * Mounted at:
 * /api/v1/permissions
 */

router.use(authenticate);

/**
 * POST /api/v1/permissions
 *
 * Employee submits:
 * - Late Login
 * - Early Logout
 */
router.post(
  '/',
  PermissionController.createPermissionRequest
);

module.exports = router;