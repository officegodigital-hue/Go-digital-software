const express = require('express');

const router = express.Router();


const payrollController =
require('../controllers/payroll.controller');


const {
    authenticate
} = require('../middlewares/auth.middleware');



// DEBUG

console.log(
    "PAYROLL ROUTES LOADED"
);

console.log(
    payrollController
);



// ===============================
// Generate Payroll
// POST /api/v1/admin/payroll/generate
// ===============================

router.post(
    '/generate',
    authenticate,
    payrollController.generatePayroll
);



// ===============================
// Payroll Runs
// GET /api/v1/admin/payroll/runs
// ===============================

router.get(
    '/runs',
    authenticate,
    payrollController.getPayrollRuns
);



// ===============================
// Payroll Details
// GET /api/v1/admin/payroll/runs/:id
// ===============================

router.get(
    '/runs/:id',
    authenticate,
    payrollController.getPayrollDetails
);



// ===============================
// Employee Payslip
// GET /api/v1/admin/payroll/payslip/:employeeId
// ===============================

router.get(
    '/payslip/:employeeId',
    authenticate,
    payrollController.getEmployeePayslip
);



// ===============================
// Delete Payroll
// DELETE /api/v1/admin/payroll/runs/:id
// ===============================

router.delete(
    '/runs/:id',
    authenticate,
    payrollController.deletePayroll
);

router.put(
'/runs/:id',
authenticate,
payrollController.updatePayroll
);

module.exports = router;