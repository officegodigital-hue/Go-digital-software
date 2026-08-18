const pool = require('../config/database');


class PayrollService {


// =====================================
// Generate Payroll
// =====================================

static async generatePayroll(data){


const {
company_id,
branch_id,
payroll_month,
payroll_year
}=data;



if(
!company_id ||
!branch_id ||
!payroll_month ||
!payroll_year
){

throw new Error(
"Company Branch Month Year required"
);

}



// duplicate check

const [existing] =
await pool.execute(

`
SELECT id

FROM payroll_batches

WHERE company_id=?
AND branch_id=?
AND payroll_year=?
AND payroll_month=?

LIMIT 1
`,

[
company_id,
branch_id,
payroll_year,
payroll_month
]

);



if(existing.length){

throw new Error(
"Payroll already generated for this month"
);

}




// salary employees


const [employees] =
await pool.execute(

`
SELECT

sm.employee_id,

sm.basic_salary,

sm.house_rent_allowance,

sm.other_allowance,

e.employee_code,

e.full_name


FROM employee_salary_master sm


INNER JOIN employees e

ON e.id = sm.employee_id


WHERE sm.company_id=?

AND sm.branch_id=?

AND sm.is_active=1

AND sm.deleted_at IS NULL

`,

[
company_id,
branch_id
]

);



if(!employees.length){

throw new Error(
"No salary master found"
);

}



let totalGross=0;

let totalDeduction=0;

let totalNet=0;


const payrollEmployees=[];



for(const emp of employees){


const basic =
Number(emp.basic_salary || 0);


const hra =
Number(emp.house_rent_allowance || 0);



const other =
Number(emp.other_allowance || 0);



const gross =
basic + hra + other;



const deduction=0;


const net =
gross-deduction;



totalGross += gross;

totalDeduction += deduction;

totalNet += net;



payrollEmployees.push({

employee_id:
emp.employee_id,

employee_code:
emp.employee_code,

employee_name:
emp.full_name,

basic_salary:
basic,

gross_salary:
gross,

total_earnings:
gross,

total_deductions:
deduction,

net_salary:
net

});


}




// create batch


const batchName =
`Payroll-${payroll_month}-${payroll_year}`;



const [batch]=
await pool.execute(

`
INSERT INTO payroll_batches

(

company_id,

branch_id,

payroll_year,

payroll_month,

batch_name,

status,

total_employees,

total_gross_earnings,

total_deductions,

total_net_payable

)

VALUES(?,?,?,?,?,?,?,?,?,?)

`,

[

company_id,

branch_id,

payroll_year,

payroll_month,

batchName,

"calculated",

payrollEmployees.length,

totalGross,

totalDeduction,

totalNet

]

);



const batchId =
batch.insertId;




// employee payroll insert


for(const emp of payrollEmployees){


await pool.execute(

`

INSERT INTO employee_payroll

(

payroll_batch_id,

employee_id,

employee_code,

employee_name_snapshot,

basic_salary,

gross_salary,

total_earnings,

total_deductions,

net_salary,

payment_status

)


VALUES(?,?,?,?,?,?,?,?,?,?)

`

,

[

batchId,

emp.employee_id,

emp.employee_code,

emp.employee_name,

emp.basic_salary,

emp.gross_salary,

emp.total_earnings,

emp.total_deductions,

emp.net_salary,

"pending"

]

);


}



return {


payroll_batch_id:
batchId,


employees_processed:
payrollEmployees.length,


message:
"Payroll generated successfully"


};


}





// =====================================
// Payroll Runs
// =====================================


static async getPayrollRuns(data){


const {

company_id,

branch_id

}=data;



const [rows]=
await pool.execute(

`

SELECT

id,

payroll_month,

payroll_year,

batch_name,

status,

total_employees,

total_gross_earnings,

total_deductions,

total_net_payable,

created_at


FROM payroll_batches


WHERE company_id=?

AND branch_id=?


ORDER BY id DESC


`

,

[

company_id,

branch_id

]

);



return rows;


}





// =====================================
// Payroll Details With Employees
// =====================================


static async getPayrollDetails(payrollId){



const [batch]=
await pool.execute(

`

SELECT

id,

payroll_month,

payroll_year,

batch_name,

status


FROM payroll_batches


WHERE id=?


LIMIT 1


`

,

[

payrollId

]

);



if(!batch.length){

throw new Error(
"Payroll not found"
);

}





const [employees]=
await pool.execute(

`

SELECT

id,

employee_id,

employee_code,

employee_name_snapshot,

basic_salary,

gross_salary,

total_earnings,

total_deductions,

net_salary,

payment_status


FROM employee_payroll


WHERE payroll_batch_id=?


ORDER BY id DESC


`

,

[

payrollId

]

);



return {


payroll:
batch[0],


employees


};


}





// =====================================
// Employee Payslip
// =====================================


static async getEmployeePayslip(employeeId){



const [rows]=
await pool.execute(

`

SELECT


ep.*,


pb.payroll_month,

pb.payroll_year,

pb.status AS payroll_status


FROM employee_payroll ep


INNER JOIN payroll_batches pb

ON pb.id=ep.payroll_batch_id



WHERE ep.employee_id=?


ORDER BY ep.id DESC


LIMIT 1


`

,

[

employeeId

]

);



return rows.length
?
rows[0]
:
null;



}





// =====================================
// Delete Payroll
// =====================================


static async deletePayroll(payrollId){



await pool.execute(

`

DELETE FROM employee_payroll

WHERE payroll_batch_id=?

`

,

[

payrollId

]

);



await pool.execute(

`

DELETE FROM payroll_batches

WHERE id=?

`

,

[

payrollId

]

);



return {


message:
"Payroll deleted successfully"


};



}

// =====================================
// UPDATE PAYROLL
// =====================================

static async updatePayroll(id, data){


    const {
        basic_salary,
        allowances,
        deductions

    } = data;



    const [result] = await db.query(

        `
        UPDATE payroll_details

        SET
        basic_salary=?,
        allowances=?,
        deductions=?

        WHERE id=?

        `,

        [
            basic_salary,
            allowances,
            deductions,
            id
        ]

    );



    if(result.affectedRows === 0){

        throw new Error(
            "Payroll record not found"
        );

    }



    return {

        id,

        message:
        "Payroll updated successfully"

    };


}


}


module.exports = PayrollService;