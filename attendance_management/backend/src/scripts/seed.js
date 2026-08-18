require('dotenv').config();

const bcrypt = require('bcryptjs');
const pool = require('../config/database');

const runSeed = async () => {
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    await connection.execute(
      `
        INSERT INTO companies (
          external_id,
          name,
          timezone,
          status
        )
        VALUES (?, ?, ?, ?)

        ON DUPLICATE KEY UPDATE
          name = VALUES(name),
          timezone = VALUES(timezone),
          status = VALUES(status)
      `,
      [
        'COMPANY-001',
        'Go Digital',
        'Asia/Kolkata',
        'active',
      ],
    );

    const [companyRows] = await connection.execute(
      `
        SELECT id
        FROM companies
        WHERE external_id = ?
        LIMIT 1
      `,
      ['COMPANY-001'],
    );

    const companyId = companyRows[0].id;

    await connection.execute(
      `
        INSERT INTO branches (
          company_id,
          external_id,
          name,
          address,
          latitude,
          longitude,
          status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)

        ON DUPLICATE KEY UPDATE
          name = VALUES(name),
          address = VALUES(address),
          status = VALUES(status)
      `,
      [
        companyId,
        'BRANCH-001',
        'Chennai Office',
        'Chennai, Tamil Nadu',
        12.9214560,
        80.1278450,
        'active',
      ],
    );

    const [branchRows] = await connection.execute(
      `
        SELECT id
        FROM branches
        WHERE company_id = ?
          AND external_id = ?
        LIMIT 1
      `,
      [companyId, 'BRANCH-001'],
    );

    const branchId = branchRows[0].id;

    await connection.execute(
      `
        INSERT INTO departments (
          company_id,
          external_id,
          name,
          status
        )
        VALUES (?, ?, ?, ?)

        ON DUPLICATE KEY UPDATE
          name = VALUES(name),
          status = VALUES(status)
      `,
      [
        companyId,
        'DEPARTMENT-001',
        'Designing',
        'active',
      ],
    );

    const [departmentRows] =
      await connection.execute(
        `
          SELECT id
          FROM departments
          WHERE company_id = ?
            AND external_id = ?
          LIMIT 1
        `,
        [companyId, 'DEPARTMENT-001'],
      );

    const departmentId = departmentRows[0].id;

    await connection.execute(
      `
        INSERT INTO designations (
          company_id,
          external_id,
          name,
          status
        )
        VALUES (?, ?, ?, ?)

        ON DUPLICATE KEY UPDATE
          name = VALUES(name),
          status = VALUES(status)
      `,
      [
        companyId,
        'DESIGNATION-001',
        'UI/UX Designer',
        'active',
      ],
    );

    const [designationRows] =
      await connection.execute(
        `
          SELECT id
          FROM designations
          WHERE company_id = ?
            AND external_id = ?
          LIMIT 1
        `,
        [companyId, 'DESIGNATION-001'],
      );

    const designationId = designationRows[0].id;

    const passwordHash = await bcrypt.hash(
      '123456',
      12,
    );

    await connection.execute(
      `
        INSERT INTO users (
          email,
          password_hash,
          role,
          status
        )
        VALUES (?, ?, ?, ?)

        ON DUPLICATE KEY UPDATE
          password_hash = VALUES(password_hash),
          role = VALUES(role),
          status = VALUES(status)
      `,
      [
        'employee@company.com',
        passwordHash,
        'employee',
        'active',
      ],
    );

    const [userRows] = await connection.execute(
      `
        SELECT id
        FROM users
        WHERE email = ?
        LIMIT 1
      `,
      ['employee@company.com'],
    );

    const userId = userRows[0].id;

    await connection.execute(
      `
        INSERT INTO employees (
          user_id,
          company_id,
          branch_id,
          department_id,
          designation_id,
          external_id,
          source_system,
          employee_code,
          full_name,
          phone,
          date_of_joining,
          employment_status
        )
        VALUES (
          ?, ?, ?, ?, ?, ?,
          ?, ?, ?, ?, ?, ?
        )

        ON DUPLICATE KEY UPDATE
          department_id = VALUES(department_id),
          designation_id = VALUES(designation_id),
          full_name = VALUES(full_name),
          phone = VALUES(phone),
          employment_status =
            VALUES(employment_status)
      `,
      [
        userId,
        companyId,
        branchId,
        departmentId,
        designationId,
        'EMPLOYEE-001',
        'main_company_software',
        '90046036',
        'Pavithra C',
        '9876543210',
        '2026-04-27',
        'active',
      ],
    );

    await connection.commit();

    console.log('Seed completed successfully');
    console.log('Email: employee@company.com');
    console.log('Password: 123456');
  } catch (error) {
    await connection.rollback();

    console.error('Seed failed:', error);
    process.exitCode = 1;
  } finally {
    connection.release();
    await pool.end();
  }
};

runSeed();