require('dotenv').config();

const bcrypt = require('bcryptjs');

const pool = require('../config/database');

const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = 'admin123@';

async function verifyAdminLogin() {
  try {
    const [databaseRows] = await pool.execute(
      'SELECT DATABASE() AS database_name',
    );

    console.log('');
    console.log(
      `Connected database: ${
        databaseRows[0]?.database_name || 'Unknown'
      }`,
    );

    const [rows] = await pool.execute(
      `
        SELECT
          u.id AS user_id,
          u.email,
          u.password_hash,
          u.role,
          u.status AS user_status,
          e.id AS employee_id,
          e.full_name,
          e.employment_status,
          c.name AS company_name,
          b.name AS branch_name
        FROM users u
        INNER JOIN employees e
          ON e.user_id = u.id
        INNER JOIN companies c
          ON c.id = e.company_id
        INNER JOIN branches b
          ON b.id = e.branch_id
        WHERE LOWER(u.email) = LOWER(?)
        LIMIT 1
      `,
      [ADMIN_EMAIL],
    );

    const account = rows[0];

    if (!account) {
      console.log('');
      console.log(
        `No account found for ${ADMIN_EMAIL}.`,
      );
      console.log(
        'Run setAdminCredentials.js and check its output.',
      );
      console.log('');

      process.exitCode = 1;
      return;
    }

    const passwordMatches =
        await bcrypt.compare(
          ADMIN_PASSWORD,
          account.password_hash,
        );

    console.log('');
    console.log('Admin account found:');
    console.log(
      `User ID: ${account.user_id}`,
    );
    console.log(
      `Employee ID: ${account.employee_id}`,
    );
    console.log(
      `Name: ${account.full_name}`,
    );
    console.log(
      `Email: ${account.email}`,
    );
    console.log(
      `Role: ${account.role}`,
    );
    console.log(
      `User status: ${account.user_status}`,
    );
    console.log(
      `Employment status: ${account.employment_status}`,
    );
    console.log(
      `Company: ${account.company_name}`,
    );
    console.log(
      `Branch: ${account.branch_name}`,
    );
    console.log(
      `Password matches admin123@: ${passwordMatches}`,
    );
    console.log('');

    if (
      account.user_status !== 'active' ||
      account.employment_status !== 'active' ||
      !passwordMatches
    ) {
      process.exitCode = 1;
    }
  } catch (error) {
    console.error('');
    console.error(
      'Admin login verification failed.',
    );
    console.error(
      error instanceof Error
        ? error.message
        : String(error),
    );
    console.error('');

    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

verifyAdminLogin();