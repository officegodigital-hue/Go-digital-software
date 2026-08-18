const express = require('express');

const {
  authenticate,
} = require('../middlewares/auth.middleware');

const PayrollSalaryMasterController = require(
  '../controllers/payrollSalaryMaster.controller',
);

const router = express.Router();

/**
 * All salary master routes require
 * a valid admin or employee JWT.
 *
 * Admin UI will use the static admin token.
 */
router.use(authenticate);

/**
 * GET /api/v1/admin/payroll/salary-masters
 *
 * Optional query parameters:
 *
 * page=1
 * limit=10
 * search=kumar
 * status=active
 * branchId=1
 */
router.get(
  '/',
  PayrollSalaryMasterController.getSalaryMasters,
);

/**
 * GET /api/v1/admin/payroll/salary-masters/:salaryMasterId
 */
router.get(
  '/:salaryMasterId',
  PayrollSalaryMasterController.getSalaryMasterById,
);

/**
 * POST /api/v1/admin/payroll/salary-masters
 */
router.post(
  '/',
  PayrollSalaryMasterController.createSalaryMaster,
);

/**
 * PUT /api/v1/admin/payroll/salary-masters/:salaryMasterId
 */
router.put(
  '/:salaryMasterId',
  PayrollSalaryMasterController.updateSalaryMaster,
);

/**
 * PATCH is also supported for the Admin Web
 * edit form.
 *
 * The current controller expects the full salary
 * structure, so the frontend should send all fields.
 */
router.patch(
  '/:salaryMasterId',
  PayrollSalaryMasterController.updateSalaryMaster,
);

/**
 * DELETE /api/v1/admin/payroll/salary-masters/:salaryMasterId
 *
 * This performs a soft delete or deactivation.
 */
router.delete(
  '/:salaryMasterId',
  PayrollSalaryMasterController.deleteSalaryMaster,
);

module.exports = router;