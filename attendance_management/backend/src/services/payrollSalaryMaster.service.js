const pool = require('../config/database');


class PayrollSalaryMasterService {


  /**
   * Get all salary masters
   */
  static async getSalaryMasters({
    companyId = null,
    branchId = null,
    page = 1,
    limit = 10,
    status = 'active',
  }) {


    const currentPage = Number(page) || 1;
    const pageLimit = Number(limit) || 10;

    const offset =
      (currentPage - 1) * pageLimit;


    let where = `
      sm.deleted_at IS NULL
    `;


    const params = [];


    if (
      companyId !== null &&
      companyId !== undefined
    ) {

      where += `
        AND sm.company_id = ?
      `;

      params.push(companyId);

    }



    if (
      branchId !== null &&
      branchId !== undefined
    ) {

      where += `
        AND sm.branch_id = ?
      `;

      params.push(branchId);

    }



    if(status === 'active') {

      where += `
        AND sm.is_active = 1
      `;

    }



    const [countRows] =
      await pool.execute(
        `
        SELECT COUNT(*) AS total

        FROM employee_salary_master sm

        WHERE ${where}

        `,
        params
      );



    const total =
      Number(countRows[0].total);



    const [rows] =
      await pool.query(
        `
        SELECT

          sm.id,

          sm.company_id,
          sm.branch_id,
          sm.employee_id,

          sm.monthly_ctc,
          sm.basic_salary,
          sm.house_rent_allowance,
          sm.other_allowance,

          sm.pf_applicable,
          sm.esic_applicable,

          sm.effective_from,
          sm.effective_to,

          sm.is_active,

          sm.created_at,
          sm.updated_at,


          e.employee_code,

          e.full_name AS employee_name


        FROM employee_salary_master sm


        INNER JOIN employees e

          ON e.id = sm.employee_id



        WHERE ${where}


        ORDER BY sm.id DESC


        LIMIT ?

        OFFSET ?

        `,
        [
          ...params,
          pageLimit,
          offset
        ]
      );



    return {

      data: rows,


      pagination: {

        page: currentPage,

        limit: pageLimit,

        total,

        totalPages:
          Math.ceil(
            total / pageLimit
          )

      }

    };


  }




  /**
   * Get single salary master
   */
  static async getSalaryMasterById(id){


    const [rows] =
      await pool.execute(
        `
        SELECT

          sm.*,

          e.employee_code,

          e.full_name AS employee_name


        FROM employee_salary_master sm


        INNER JOIN employees e

        ON e.id = sm.employee_id


        WHERE sm.id = ?

        AND sm.deleted_at IS NULL


        LIMIT 1

        `,
        [
          id
        ]
      );



    return rows[0] || null;


  }






  /**
   * Create salary master
   */
  static async createSalaryMaster(data){


    const {

      company_id,

      branch_id,

      employee_id,


      monthly_ctc = 0,

      basic_salary = 0,

      house_rent_allowance = 0,

      other_allowance = 0,


      pf_applicable = false,

      esic_applicable = false,


      effective_from,

      effective_to = null


    } = data;



    const [result] =
      await pool.execute(

        `
        INSERT INTO employee_salary_master


        (

          company_id,

          branch_id,

          employee_id,


          monthly_ctc,

          basic_salary,

          house_rent_allowance,

          other_allowance,


          pf_applicable,

          esic_applicable,


          effective_from,

          effective_to,


          is_active


        )


        VALUES

        (?,?,?,?,?,?,?,?,?,?,?,1)


        `,

        [

          company_id ?? null,

          branch_id ?? null,

          employee_id,


          monthly_ctc,

          basic_salary,

          house_rent_allowance,

          other_allowance,


          pf_applicable ? 1 : 0,

          esic_applicable ? 1 : 0,


          effective_from,

          effective_to

        ]

      );



    return this.getSalaryMasterById(
      result.insertId
    );


  }







  /**
   * Update salary master
   */
  static async updateSalaryMaster(
    id,
    data
  ){


    const monthly_ctc =
      data.monthly_ctc ?? 0;


    const basic_salary =
      data.basic_salary ?? 0;


    const house_rent_allowance =
      data.house_rent_allowance ?? 0;


    const other_allowance =
      data.other_allowance ?? 0;



    const pf_applicable =
      data.pf_applicable ?? false;


    const esic_applicable =
      data.esic_applicable ?? false;



    const effective_from =
      data.effective_from ?? null;



    const effective_to =
      data.effective_to ?? null;




    await pool.execute(

      `

      UPDATE employee_salary_master


      SET


        monthly_ctc = ?,

        basic_salary = ?,

        house_rent_allowance = ?,

        other_allowance = ?,



        pf_applicable = ?,

        esic_applicable = ?,



        effective_from =
        COALESCE(
          ?,
          effective_from
        ),


        effective_to = ?,



        updated_at =
        CURRENT_TIMESTAMP



      WHERE id = ?



      `,

      [

        monthly_ctc,

        basic_salary,

        house_rent_allowance,

        other_allowance,


        pf_applicable ? 1 : 0,

        esic_applicable ? 1 : 0,


        effective_from,

        effective_to,


        id

      ]

    );



    return this.getSalaryMasterById(id);


  }








  /**
   * Delete salary master
   */
  static async deleteSalaryMaster(id){



    await pool.execute(

      `

      UPDATE employee_salary_master


      SET


        deleted_at =
        CURRENT_TIMESTAMP,


        is_active = 0



      WHERE id = ?


      `,

      [
        id
      ]

    );



    return {

      message:
      'Salary master deleted successfully'

    };


  }







  /**
   * Employee salary history
   */
  static async getEmployeeSalary(
    employeeId
  ){


    const [rows] =
      await pool.execute(

        `

        SELECT *

        FROM employee_salary_master


        WHERE employee_id = ?


        AND deleted_at IS NULL


        ORDER BY id DESC


        `,

        [
          employeeId
        ]

      );



    return rows;


  }



}



module.exports =
PayrollSalaryMasterService;