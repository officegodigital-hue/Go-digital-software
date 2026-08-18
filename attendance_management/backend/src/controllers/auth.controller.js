  const bcrypt = require('bcryptjs');
  const jwt = require('jsonwebtoken');

  const pool = require('../config/database');
  const AppError = require('../utils/AppError');
  const asyncHandler = require('../utils/asyncHandler');
  const { sendSuccess } = require('../utils/apiResponse');

  /**
   * Admin Web login credentials.
   *
   * No admin user or employee record is required
   * in the database for this login.
   *
   * These values can later be moved to .env:
   *
   * ADMIN_LOGIN_EMAIL=admin@gmail.com
   * ADMIN_LOGIN_PASSWORD=admin123@
   */
  const ADMIN_LOGIN_EMAIL = String(
    process.env.ADMIN_LOGIN_EMAIL ||
      'admin@gmail.com',
  )
    .trim()
    .toLowerCase();

  const ADMIN_LOGIN_PASSWORD = String(
    process.env.ADMIN_LOGIN_PASSWORD ||
      'admin123@',
  );

  async function getStaticAdminContext() {
    const context = {
      company_id: null,
      company_name: 'GoDigital',
      timezone: 'Asia/Kolkata',
      branch_id: null,
      branch_name: 'Guduvanchery',
    };

    try {
      const [companyRows] = await pool.execute(
        `
          SELECT
            id,
            name,
            timezone
          FROM companies
          ORDER BY id ASC
          LIMIT 1
        `,
      );

      const company = companyRows[0];

      if (!company) {
        return context;
      }

      context.company_id = company.id;
      context.company_name =
        company.name || context.company_name;
      context.timezone =
        company.timezone || context.timezone;

      const [branchRows] = await pool.execute(
        `
          SELECT
            id,
            name
          FROM branches
          WHERE company_id = ?
          ORDER BY id ASC
          LIMIT 1
        `,
        [company.id],
      );

      const branch = branchRows[0];

      if (branch) {
        context.branch_id = branch.id;
        context.branch_name =
          branch.name || context.branch_name;
      }

      return context;
    } catch (error) {
      /**
       * Admin login should still work even when
       * company or branch records are not ready.
       */
      return context;
    }
  }

  function createAccessToken(payload) {
    if (!process.env.JWT_ACCESS_SECRET) {
      throw new AppError(
        500,
        'JWT_SECRET_MISSING',
        'JWT access secret is not configured',
      );
    }

    return jwt.sign(
      payload,
      process.env.JWT_ACCESS_SECRET,
      {
        expiresIn:
          process.env.JWT_ACCESS_EXPIRES_IN ||
          '1h',
      },
    );
  }

  function buildStaticAdminUser(context) {
    return {
      user_id: null,
      employee_id: null,
      employee_code: 'ADMIN',
      role: 'admin',

      name: 'GoDigital Admin',
      email: ADMIN_LOGIN_EMAIL,
      phone: null,
      profile_image_url: null,

      company_id: context.company_id,
      company_name: context.company_name,

      branch_id: context.branch_id,
      branch_name: context.branch_name,

      department_id: null,
      department_name: null,

      designation_id: null,
      designation_name: null,

      timezone: context.timezone,
    };
  }

  const login = asyncHandler(async (req, res) => {
    const email = String(req.body.email || '')
      .trim()
      .toLowerCase();

    const password = String(
      req.body.password || '',
    );

    if (!email || !password) {
      throw new AppError(
        422,
        'VALIDATION_ERROR',
        'Email and password are required',
      );
    }

    /**
     * Static Admin Web login.
     *
     * This does not require an admin record in
     * users or employees.
     */
    if (
      email === ADMIN_LOGIN_EMAIL &&
      password === ADMIN_LOGIN_PASSWORD
    ) {
      const context =
        await getStaticAdminContext();

      const accessToken =
        createAccessToken({
          userId: null,
          employeeId: null,
          companyId: context.company_id,
          branchId: context.branch_id,
          role: 'admin',
          isStaticAdmin: true,
        });

      return sendSuccess(res, {
        message: 'Login successful',
        data: {
          access_token: accessToken,
          token_type: 'Bearer',
          expires_in:
            process.env
              .JWT_ACCESS_EXPIRES_IN ||
            '1h',
          user:
            buildStaticAdminUser(context),
        },
      });
    }

    /**
     * Existing database employee login.
     *
     * This remains unchanged for the employee
     * mobile app and other existing users.
     */
    const [rows] = await pool.execute(
      `
        SELECT
          u.id AS user_id,
          u.email,
          u.password_hash,
          u.role,
          u.status AS user_status,

          e.id AS employee_id,
          e.employee_code,
          e.full_name,
          e.phone,
          e.profile_image_url,
          e.company_id,
          e.branch_id,
          e.department_id,
          e.designation_id,
          e.employment_status,

          c.name AS company_name,
          c.timezone,

          b.name AS branch_name,
          d.name AS department_name,
          des.name AS designation_name

        FROM users u

        INNER JOIN employees e
          ON e.user_id = u.id

        INNER JOIN companies c
          ON c.id = e.company_id

        INNER JOIN branches b
          ON b.id = e.branch_id

        LEFT JOIN departments d
          ON d.id = e.department_id

        LEFT JOIN designations des
          ON des.id = e.designation_id

        WHERE LOWER(u.email) = LOWER(?)

        LIMIT 1
      `,
      [email],
    );

    const account = rows[0];

    if (!account) {
      throw new AppError(
        401,
        'INVALID_CREDENTIALS',
        'Invalid email address or password',
      );
    }

    if (
      account.user_status !== 'active' ||
      account.employment_status !== 'active'
    ) {
      throw new AppError(
        403,
        'EMPLOYEE_INACTIVE',
        'This employee account is not active',
      );
    }

    const passwordMatches =
      await bcrypt.compare(
        password,
        account.password_hash,
      );

    if (!passwordMatches) {
      throw new AppError(
        401,
        'INVALID_CREDENTIALS',
        'Invalid email address or password',
      );
    }

    const accessToken =
      createAccessToken({
        userId: account.user_id,
        employeeId: account.employee_id,
        companyId: account.company_id,
        branchId: account.branch_id,
        role: account.role,
        isStaticAdmin: false,
      });

    await pool.execute(
      `
        UPDATE users
        SET last_login_at = UTC_TIMESTAMP()
        WHERE id = ?
      `,
      [account.user_id],
    );

    return sendSuccess(res, {
      message: 'Login successful',
      data: {
        access_token: accessToken,
        token_type: 'Bearer',
        expires_in:
          process.env.JWT_ACCESS_EXPIRES_IN ||
          '1h',

        user: {
          user_id: account.user_id,
          employee_id: account.employee_id,
          employee_code:
            account.employee_code,
          role: account.role,

          name: account.full_name,
          email: account.email,
          phone: account.phone,
          profile_image_url:
            account.profile_image_url,

          company_id: account.company_id,
          company_name:
            account.company_name,

          branch_id: account.branch_id,
          branch_name:
            account.branch_name,

          department_id:
            account.department_id,
          department_name:
            account.department_name,

          designation_id:
            account.designation_id,
          designation_name:
            account.designation_name,

          timezone: account.timezone,
        },
      },
    });
  });

  const getCurrentUser = asyncHandler(
    async (req, res) => {
      /**
       * Return the Static Admin Web profile
       * without reading a users/employees row.
       */
      if (req.auth.isStaticAdmin === true) {
        const context =
          await getStaticAdminContext();

        return sendSuccess(res, {
          message:
            'Admin profile fetched successfully',
          data:
            buildStaticAdminUser(context),
        });
      }

      const [rows] = await pool.execute(
        `
          SELECT
            u.id AS user_id,
            u.email,
            u.role,

            e.id AS employee_id,
            e.employee_code,
            e.full_name,
            e.phone,
            e.profile_image_url,
            e.date_of_joining,

            c.id AS company_id,
            c.name AS company_name,

            b.id AS branch_id,
            b.name AS branch_name,

            d.id AS department_id,
            d.name AS department_name,

            des.id AS designation_id,
            des.name AS designation_name

          FROM users u

          INNER JOIN employees e
            ON e.user_id = u.id

          INNER JOIN companies c
            ON c.id = e.company_id

          INNER JOIN branches b
            ON b.id = e.branch_id

          LEFT JOIN departments d
            ON d.id = e.department_id

          LEFT JOIN designations des
            ON des.id = e.designation_id

          WHERE u.id = ?
            AND e.id = ?

          LIMIT 1
        `,
        [
          req.auth.userId,
          req.auth.employeeId,
        ],
      );

      if (!rows[0]) {
        throw new AppError(
          404,
          'EMPLOYEE_NOT_FOUND',
          'Employee profile was not found',
        );
      }

      return sendSuccess(res, {
        message:
          'Employee profile fetched successfully',
        data: rows[0],
      });
    },
  );

  module.exports = {
      login,
      getCurrentUser,
  };