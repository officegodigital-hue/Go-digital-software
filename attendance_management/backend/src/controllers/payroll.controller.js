const PayrollService =
require('../services/payroll.service');


const asyncHandler =
require('../utils/asyncHandler');


const {
    sendSuccess
} = require('../utils/apiResponse');




// =====================================
// Generate Payroll
// POST /api/v1/admin/payroll/generate
// =====================================

const generatePayroll =
asyncHandler(async(req,res)=>{


    const companyId =
        req.auth.company_id ||
        req.auth.companyId;


    const branchId =
        req.auth.branch_id ||
        req.auth.branchId;



    if(!companyId || !branchId){

        return res.status(403).json({

            success:false,

            message:
            "Company or Branch information missing"

        });

    }



    const {
        payroll_month,
        payroll_year

    } = req.body;



    if(!payroll_month || !payroll_year){

        return res.status(422).json({

            success:false,

            message:
            "Payroll month and year required"

        });

    }




    const result =
    await PayrollService.generatePayroll({

        company_id:companyId,

        branch_id:branchId,

        payroll_month,

        payroll_year

    });



    return sendSuccess(res,{

        message:
        "Payroll generated successfully",

        data:
        result

    });


});








// =====================================
// Payroll Runs
// GET /api/v1/admin/payroll/runs
// =====================================

const getPayrollRuns =
asyncHandler(async(req,res)=>{


    const companyId =
        req.auth.company_id ||
        req.auth.companyId;


    const branchId =
        req.auth.branch_id ||
        req.auth.branchId;




    if(!companyId || !branchId){

        return res.status(403).json({

            success:false,

            message:
            "Company or Branch information missing"

        });

    }




    const result =
    await PayrollService.getPayrollRuns({

        company_id:companyId,

        branch_id:branchId

    });




    return sendSuccess(res,{

        message:
        "Payroll list fetched successfully",

        data:
        result

    });


});









// =====================================
// Payroll Details
// GET /api/v1/admin/payroll/runs/:id
// =====================================

const getPayrollDetails =
asyncHandler(async(req,res)=>{


    const payrollId =
        Number(req.params.id);



    if(!payrollId){

        return res.status(422).json({

            success:false,

            message:
            "Valid Payroll ID required"

        });

    }




    const result =
    await PayrollService.getPayrollDetails(
        payrollId
    );




    if(!result){

        return res.status(404).json({

            success:false,

            message:
            "Payroll not found"

        });

    }




    return sendSuccess(res,{

        message:
        "Payroll details fetched successfully",

        data:
        result

    });


});









// =====================================
// Employee Payslip
// GET /api/v1/admin/payroll/payslip/:employeeId
// =====================================

const getEmployeePayslip =
asyncHandler(async(req,res)=>{


    const employeeId =
        Number(req.params.employeeId);



    if(!employeeId){

        return res.status(422).json({

            success:false,

            message:
            "Valid Employee ID required"

        });

    }





    const result =
    await PayrollService.getEmployeePayslip(
        employeeId
    );




    if(!result){

        return res.status(404).json({

            success:false,

            message:
            "Payslip not found"

        });

    }




    return sendSuccess(res,{

        message:
        "Payslip fetched successfully",

        data:
        result

    });


});









// =====================================
// Delete Payroll
// DELETE /api/v1/admin/payroll/runs/:id
// =====================================

const deletePayroll =
asyncHandler(async(req,res)=>{


    const payrollId =
        Number(req.params.id);



    if(!payrollId){

        return res.status(422).json({

            success:false,

            message:
            "Valid Payroll ID required"

        });

    }




    const result =
    await PayrollService.deletePayroll(
        payrollId
    );




    return sendSuccess(res,{

        message:
        result.message ||
        "Payroll deleted successfully"

    });


});

const updatePayroll =
asyncHandler(async(req,res)=>{


const result =
await PayrollService.updatePayroll(

req.params.id,

req.body

);



return sendSuccess(res,{

message:
"Payroll updated successfully",

data:
result

});


});






module.exports = {


    generatePayroll,

    getPayrollRuns,

    getPayrollDetails,

    getEmployeePayslip,

    deletePayroll,

    updatePayroll


};