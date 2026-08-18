require('dotenv').config();

const bcrypt = require('bcryptjs');

const pool = require('../config/database');

const ADMIN_EMAIL = 'admin@gmail.com';
const ADMIN_PASSWORD = 'admin123@';

async function setAdminCredentials() {
  let connection;

  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();

    const normalizedEmail = ADMIN_EMAIL
      .trim()
      .toLowerCase();

    if (!normalizedEmail) {
      throw new Error(
        'Admin email cannot be empty.',
      );
    }

    if (ADMIN_PASSWORD.length < 8) {
      throw new Error(
        'Admin password must contain at least 8 characters.',
      );
    }

    /**
     * Use the first existing admin account.
     *
     * This safely preserves the existing linked
     * employee, company and branch records.
     */
    const [adminRows] = await connection.execute(
      `
        SELECT
          u.id AS user_id,
          u.email,
          u.role,
          e.id AS employee_id,
          e.full_name
        FROM users u
        INNER JOIN employees e
          ON e.user_id = u.id
        WHERE LOWER(u.role) = 'admin'
        ORDER BY u.id ASC
        LIMIT 1
      `,
    );

    const adminAccount = adminRows[0];

    if (!adminAccount) {
      throw new Error(
        'No existing admin account was found. ' +
          'Create an employee-linked admin user first.',
      );
    }

    /**
     * Prevent accidentally assigning an email
     * that already belongs to another user.
     */
    const [emailRows] = await connection.execute(
      `
        SELECT id
        FROM users
        WHERE LOWER(email) = LOWER(?)
          AND id <> ?
        LIMIT 1
      `,
      [
        normalizedEmail,
        adminAccount.user_id,
      ],
    );

    if (emailRows.length > 0) {
      throw new Error(
        `The email ${normalizedEmail} is already used by another account.`,
      );
    }

    const passwordHash = await bcrypt.hash(
      ADMIN_PASSWORD,
      12,
    );

    await connection.execute(
      `
        UPDATE users
        SET
          email = ?,
          password_hash = ?,
          role = 'admin',
          status = 'active'
        WHERE id = ?
      `,
      [
        normalizedEmail,
        passwordHash,
        adminAccount.user_id,
      ],
    );

    await connection.execute(
      `
        UPDATE employees
        SET employment_status = 'active'
        WHERE id = ?
      `,
      [
        adminAccount.employee_id,
      ],
    );

    await connection.commit();

    console.log('');
    console.log(
      'Admin credentials updated successfully.',
    );
    console.log(
      `Employee: ${adminAccount.full_name}`,
    );
    console.log(
      `User ID: ${adminAccount.user_id}`,
    );
    console.log(
      `Employee ID: ${adminAccount.employee_id}`,
    );
    console.log(
      `Email: ${normalizedEmail}`,
    );
    console.log(
      `Password: ${ADMIN_PASSWORD}`,
    );
    console.log('');
  } catch (error) {
    if (connection) {
      await connection.rollback();
    }

    console.error('');
    console.error(
      'Unable to update admin credentials.',
    );
    console.error(
      error instanceof Error
        ? error.message
        : String(error),
    );
    console.error('');

    process.exitCode = 1;
  } finally {
    if (connection) {
      connection.release();
    }

    await pool.end();
  }
}

setAdminCredentials();