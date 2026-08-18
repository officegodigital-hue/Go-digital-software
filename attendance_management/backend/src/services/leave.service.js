const pool = require('../config/database');
const AppError = require('../utils/AppError');
const { getTimeZoneParts } = require('../utils/dateTime');

const VALID_LEAVE_STATUSES = [
  'pending',
  'approved',
  'rejected',
  'cancelled',
];

const VALID_DAY_TYPES = [
  'full_day',
  'first_half',
  'second_half',
];

const toNumber = (value) => {
  const number = Number(value);

  return Number.isFinite(number) ? number : 0;
};

const validateDate = (value, fieldName) => {
  const dateValue = String(value || '').trim();

  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateValue)) {
    throw new AppError(
      422,
      'INVALID_DATE',
      `${fieldName} must use YYYY-MM-DD format`,
    );
  }

  const parsedDate = new Date(
    `${dateValue}T00:00:00.000Z`,
  );

  if (
    Number.isNaN(parsedDate.getTime()) ||
    parsedDate.toISOString().slice(0, 10) !==
      dateValue
  ) {
    throw new AppError(
      422,
      'INVALID_DATE',
      `${fieldName} is invalid`,
    );
  }

  return dateValue;
};

const getInclusiveDayCount = (
  startDate,
  endDate,
) => {
  const start = new Date(
    `${startDate}T00:00:00.000Z`,
  );

  const end = new Date(
    `${endDate}T00:00:00.000Z`,
  );

  const difference =
    end.getTime() - start.getTime();

  if (difference < 0) {
    throw new AppError(
      422,
      'INVALID_DATE_RANGE',
      'End date cannot be before start date',
    );
  }

  return Math.floor(
    difference / (24 * 60 * 60 * 1000),
  ) + 1;
};

const calculateTotalDays = ({
  startDate,
  endDate,
  dayType,
}) => {
  const inclusiveDays = getInclusiveDayCount(
    startDate,
    endDate,
  );

  if (dayType === 'full_day') {
    return inclusiveDays;
  }

  if (startDate !== endDate) {
    throw new AppError(
      422,
      'INVALID_HALF_DAY_RANGE',
      'Half-day leave can only be applied for one date',
    );
  }

  return 0.5;
};

const getEmployeeContext = async (
  employeeId,
  connection = pool,
) => {
  const [rows] = await connection.execute(
    `
      SELECT
        e.id AS employee_id,
        e.employee_code,
        e.full_name,
        e.company_id,
        e.branch_id,
        e.employment_status,

        c.name AS company_name,
        c.timezone,

        b.name AS branch_name

      FROM employees e

      INNER JOIN companies c
        ON c.id = e.company_id

      INNER JOIN branches b
        ON b.id = e.branch_id

      WHERE e.id = ?

      LIMIT 1
    `,
    [employeeId],
  );

  const employee = rows[0];

  if (!employee) {
    throw new AppError(
      404,
      'EMPLOYEE_NOT_FOUND',
      'Employee was not found',
    );
  }

  if (employee.employment_status !== 'active') {
    throw new AppError(
      403,
      'EMPLOYEE_INACTIVE',
      'Employee account is not active',
    );
  }

  return employee;
};

const getBalanceValues = (balance) => {
  const openingBalance = toNumber(
    balance.opening_balance,
  );

  const allocatedDays = toNumber(
    balance.allocated_days,
  );

  const carriedForwardDays = toNumber(
    balance.carried_forward_days,
  );

  const usedDays = toNumber(
    balance.used_days,
  );

  const pendingDays = toNumber(
    balance.pending_days,
  );

  const totalAllocated =
    openingBalance +
    allocatedDays +
    carriedForwardDays;

  const availableDays =
    totalAllocated -
    usedDays -
    pendingDays;

  return {
    opening_balance: openingBalance,
    allocated_days: allocatedDays,
    carried_forward_days:
      carriedForwardDays,
    total_allocated: totalAllocated,
    used_days: usedDays,
    pending_days: pendingDays,
    available_days: availableDays,
  };
};

const getLeaveDashboard = async ({
  employeeId,
  year,
}) => {
  const employee =
    await getEmployeeContext(employeeId);

  const timezone =
    employee.timezone ||
    process.env.COMPANY_TIMEZONE ||
    'Asia/Kolkata';

  const currentDate =
    getTimeZoneParts(timezone).date;

  const selectedYear =
    year == null || year === ''
      ? Number(currentDate.substring(0, 4))
      : Number(year);

  if (
    !Number.isInteger(selectedYear) ||
    selectedYear < 2000 ||
    selectedYear > 2100
  ) {
    throw new AppError(
      422,
      'INVALID_YEAR',
      'Year must be valid',
    );
  }

  const [balanceRows] = await pool.execute(
    `
      SELECT
        leave_type.id AS leave_type_id,
        leave_type.name,
        leave_type.code,
        leave_type.annual_quota,
        leave_type.is_paid,
        leave_type.requires_attachment,
        leave_type.max_consecutive_days,

        balance.id AS balance_id,
        balance.balance_year,
        balance.opening_balance,
        balance.allocated_days,
        balance.carried_forward_days,
        balance.used_days,
        balance.pending_days

      FROM leave_types leave_type

      LEFT JOIN employee_leave_balances balance
        ON balance.leave_type_id = leave_type.id
        AND balance.employee_id = ?
        AND balance.balance_year = ?

      WHERE leave_type.company_id = ?
        AND leave_type.is_active = TRUE

      ORDER BY leave_type.id
    `,
    [
      employeeId,
      selectedYear,
      employee.company_id,
    ],
  );

  const [summaryRows] = await pool.execute(
    `
      SELECT
        COUNT(*) AS total_requests,

        SUM(
          CASE
            WHEN status = 'pending'
            THEN 1
            ELSE 0
          END
        ) AS pending_requests,

        SUM(
          CASE
            WHEN status = 'approved'
            THEN 1
            ELSE 0
          END
        ) AS approved_requests,

        SUM(
          CASE
            WHEN status = 'rejected'
            THEN 1
            ELSE 0
          END
        ) AS rejected_requests,

        SUM(
          CASE
            WHEN status = 'cancelled'
            THEN 1
            ELSE 0
          END
        ) AS cancelled_requests

      FROM leave_requests

      WHERE employee_id = ?
        AND YEAR(start_date) = ?
    `,
    [employeeId, selectedYear],
  );

  const requestSummary = summaryRows[0] || {};

  return {
    employee: {
      employee_id: employee.employee_id,
      employee_code: employee.employee_code,
      name: employee.full_name,
      company_name: employee.company_name,
      branch_name: employee.branch_name,
      timezone,
    },

    year: selectedYear,

    request_summary: {
      total_requests: toNumber(
        requestSummary.total_requests,
      ),
      pending_requests: toNumber(
        requestSummary.pending_requests,
      ),
      approved_requests: toNumber(
        requestSummary.approved_requests,
      ),
      rejected_requests: toNumber(
        requestSummary.rejected_requests,
      ),
      cancelled_requests: toNumber(
        requestSummary.cancelled_requests,
      ),
    },

    balances: balanceRows.map((row) => ({
      leave_type_id: row.leave_type_id,
      name: row.name,
      code: row.code,
      annual_quota: toNumber(
        row.annual_quota,
      ),
      is_paid: Boolean(row.is_paid),
      requires_attachment: Boolean(
        row.requires_attachment,
      ),
      max_consecutive_days:
        row.max_consecutive_days == null
          ? null
          : toNumber(
              row.max_consecutive_days,
            ),
      balance_year:
        row.balance_year == null
          ? selectedYear
          : Number(row.balance_year),
      ...getBalanceValues({
        opening_balance:
          row.opening_balance,
        allocated_days:
          row.allocated_days,
        carried_forward_days:
          row.carried_forward_days,
        used_days: row.used_days,
        pending_days: row.pending_days,
      }),
    })),
  };
};

const getLeaveHistory = async ({
  employeeId,
  year,
  status,
}) => {
  const employee =
    await getEmployeeContext(employeeId);

  const timezone =
    employee.timezone ||
    process.env.COMPANY_TIMEZONE ||
    'Asia/Kolkata';

  const currentDate =
    getTimeZoneParts(timezone).date;

  const selectedYear =
    year == null || year === ''
      ? Number(currentDate.substring(0, 4))
      : Number(year);

  if (
    !Number.isInteger(selectedYear) ||
    selectedYear < 2000 ||
    selectedYear > 2100
  ) {
    throw new AppError(
      422,
      'INVALID_YEAR',
      'Year must be valid',
    );
  }

  const normalizedStatus =
    status == null || status === ''
      ? null
      : String(status).trim().toLowerCase();

  if (
    normalizedStatus &&
    !VALID_LEAVE_STATUSES.includes(
      normalizedStatus,
    )
  ) {
    throw new AppError(
      422,
      'INVALID_LEAVE_STATUS',
      'Leave status is invalid',
    );
  }

  const parameters = [
    employeeId,
    selectedYear,
  ];

  let statusCondition = '';

  if (normalizedStatus) {
    statusCondition =
      'AND request.status = ?';

    parameters.push(normalizedStatus);
  }

  const [rows] = await pool.execute(
    `
      SELECT
        request.id AS leave_request_id,
        request.start_date,
        request.end_date,
        request.day_type,
        request.total_days,
        request.reason,
        request.attachment_url,
        request.status,

        request.reviewed_at,
        request.review_comment,

        request.cancelled_at,
        request.cancellation_reason,

        request.created_at,
        request.updated_at,

        leave_type.id AS leave_type_id,
        leave_type.name AS leave_type_name,
        leave_type.code AS leave_type_code,
        leave_type.is_paid,
        leave_type.requires_attachment

      FROM leave_requests request

      INNER JOIN leave_types leave_type
        ON leave_type.id =
          request.leave_type_id

      WHERE request.employee_id = ?
        AND YEAR(request.start_date) = ?

        ${statusCondition}

      ORDER BY
        request.created_at DESC,
        request.id DESC
    `,
    parameters,
  );

  return {
    employee: {
      employee_id: employee.employee_id,
      employee_code: employee.employee_code,
      name: employee.full_name,
      timezone,
    },

    filter: {
      year: selectedYear,
      status: normalizedStatus,
    },

    requests: rows.map((row) => ({
      leave_request_id:
        row.leave_request_id,

      leave_type: {
        leave_type_id:
          row.leave_type_id,
        name: row.leave_type_name,
        code: row.leave_type_code,
        is_paid: Boolean(row.is_paid),
        requires_attachment: Boolean(
          row.requires_attachment,
        ),
      },

      start_date: row.start_date,
      end_date: row.end_date,
      day_type: row.day_type,

      total_days: toNumber(
        row.total_days,
      ),

      reason: row.reason,

      attachment_url:
        row.attachment_url || null,

      status: row.status,

      reviewed_at:
        row.reviewed_at || null,

      review_comment:
        row.review_comment || null,

      cancelled_at:
        row.cancelled_at || null,

      cancellation_reason:
        row.cancellation_reason || null,

      created_at: row.created_at,
      updated_at: row.updated_at,

      can_cancel:
        row.status === 'pending',
    })),
  };
};

const applyLeave = async ({
  employeeId,
  leaveTypeId,
  startDate,
  endDate,
  dayType = 'full_day',
  reason,
  attachmentUrl,
}) => {
  const normalizedDayType = String(
    dayType || 'full_day',
  )
    .trim()
    .toLowerCase();

  if (
    !VALID_DAY_TYPES.includes(
      normalizedDayType,
    )
  ) {
    throw new AppError(
      422,
      'INVALID_DAY_TYPE',
      'Leave day type is invalid',
    );
  }

  const normalizedStartDate = validateDate(
    startDate,
    'Start date',
  );

  const normalizedEndDate = validateDate(
    endDate,
    'End date',
  );

  const normalizedReason = String(
    reason || '',
  ).trim();

  if (normalizedReason.length < 3) {
    throw new AppError(
      422,
      'INVALID_REASON',
      'Leave reason must contain at least 3 characters',
    );
  }

  const totalDays = calculateTotalDays({
    startDate: normalizedStartDate,
    endDate: normalizedEndDate,
    dayType: normalizedDayType,
  });

  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const employee =
      await getEmployeeContext(
        employeeId,
        connection,
      );

    const timezone =
      employee.timezone ||
      process.env.COMPANY_TIMEZONE ||
      'Asia/Kolkata';

    const currentDate =
      getTimeZoneParts(timezone).date;

    if (normalizedStartDate < currentDate) {
      throw new AppError(
        422,
        'PAST_LEAVE_DATE',
        'Leave cannot be applied for a past date',
      );
    }

    const [leaveTypeRows] =
      await connection.execute(
        `
          SELECT
            id,
            name,
            code,
            annual_quota,
            is_paid,
            requires_attachment,
            max_consecutive_days

          FROM leave_types

          WHERE id = ?
            AND company_id = ?
            AND is_active = TRUE

          LIMIT 1
        `,
        [
          Number(leaveTypeId),
          employee.company_id,
        ],
      );

    const leaveType = leaveTypeRows[0];

    if (!leaveType) {
      throw new AppError(
        404,
        'LEAVE_TYPE_NOT_FOUND',
        'Leave type was not found',
      );
    }

    if (
      leaveType.requires_attachment &&
      !String(attachmentUrl || '').trim()
    ) {
      throw new AppError(
        422,
        'ATTACHMENT_REQUIRED',
        `Attachment is required for ${leaveType.name}`,
      );
    }

    if (
      leaveType.max_consecutive_days != null &&
      totalDays >
        Number(
          leaveType.max_consecutive_days,
        )
    ) {
      throw new AppError(
        422,
        'MAXIMUM_LEAVE_DAYS_EXCEEDED',
        `Maximum consecutive leave allowed is ${leaveType.max_consecutive_days} days`,
      );
    }

    const [overlapRows] =
      await connection.execute(
        `
          SELECT id

          FROM leave_requests

          WHERE employee_id = ?
            AND status IN (
              'pending',
              'approved'
            )

            AND start_date <= ?
            AND end_date >= ?

          LIMIT 1
        `,
        [
          employeeId,
          normalizedEndDate,
          normalizedStartDate,
        ],
      );

    if (overlapRows.length > 0) {
      throw new AppError(
        409,
        'OVERLAPPING_LEAVE',
        'A pending or approved leave already exists for the selected dates',
      );
    }

    const balanceYear = Number(
      normalizedStartDate.substring(0, 4),
    );

    let balance = null;

    if (Boolean(leaveType.is_paid)) {
      const [balanceRows] =
        await connection.execute(
          `
            SELECT
              id,
              opening_balance,
              allocated_days,
              carried_forward_days,
              used_days,
              pending_days

            FROM employee_leave_balances

            WHERE employee_id = ?
              AND leave_type_id = ?
              AND balance_year = ?

            LIMIT 1

            FOR UPDATE
          `,
          [
            employeeId,
            leaveType.id,
            balanceYear,
          ],
        );

      balance = balanceRows[0];

      if (!balance) {
        throw new AppError(
          422,
          'LEAVE_BALANCE_NOT_FOUND',
          'Leave balance is not available for the selected year',
        );
      }

      const balanceValues =
        getBalanceValues(balance);

      if (
        totalDays >
        balanceValues.available_days
      ) {
        throw new AppError(
          422,
          'INSUFFICIENT_LEAVE_BALANCE',
          `Only ${balanceValues.available_days} leave days are available`,
        );
      }
    }

    const [insertResult] =
      await connection.execute(
        `
          INSERT INTO leave_requests (
            employee_id,
            leave_type_id,
            start_date,
            end_date,
            day_type,
            total_days,
            reason,
            attachment_url,
            status
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')
        `,
        [
          employeeId,
          leaveType.id,
          normalizedStartDate,
          normalizedEndDate,
          normalizedDayType,
          totalDays,
          normalizedReason,
          String(attachmentUrl || '').trim() ||
            null,
        ],
      );

    if (balance) {
      await connection.execute(
        `
          UPDATE employee_leave_balances

          SET pending_days =
            pending_days + ?

          WHERE id = ?
        `,
        [
          totalDays,
          balance.id,
        ],
      );
    }

    await connection.commit();

    return {
      leave_request_id:
        insertResult.insertId,

      leave_type: {
        leave_type_id:
          leaveType.id,
        name: leaveType.name,
        code: leaveType.code,
      },

      start_date:
        normalizedStartDate,

      end_date:
        normalizedEndDate,

      day_type:
        normalizedDayType,

      total_days:
        totalDays,

      reason:
        normalizedReason,

      attachment_url:
        String(attachmentUrl || '').trim() ||
        null,

      status: 'pending',
    };
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

const cancelLeave = async ({
  employeeId,
  leaveRequestId,
  cancellationReason,
}) => {
  const normalizedReason = String(
    cancellationReason || '',
  ).trim();

  if (normalizedReason.length < 3) {
    throw new AppError(
      422,
      'INVALID_CANCELLATION_REASON',
      'Cancellation reason must contain at least 3 characters',
    );
  }

  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [rows] = await connection.execute(
      `
        SELECT
          request.id,
          request.employee_id,
          request.leave_type_id,
          request.start_date,
          request.total_days,
          request.status,

          leave_type.is_paid

        FROM leave_requests request

        INNER JOIN leave_types leave_type
          ON leave_type.id =
            request.leave_type_id

        WHERE request.id = ?
          AND request.employee_id = ?

        LIMIT 1

        FOR UPDATE
      `,
      [
        Number(leaveRequestId),
        employeeId,
      ],
    );

    const leaveRequest = rows[0];

    if (!leaveRequest) {
      throw new AppError(
        404,
        'LEAVE_REQUEST_NOT_FOUND',
        'Leave request was not found',
      );
    }

    if (leaveRequest.status !== 'pending') {
      throw new AppError(
        409,
        'LEAVE_CANNOT_BE_CANCELLED',
        'Only pending leave requests can be cancelled',
      );
    }

    await connection.execute(
      `
        UPDATE leave_requests

        SET
          status = 'cancelled',
          cancelled_at = NOW(),
          cancellation_reason = ?

        WHERE id = ?
      `,
      [
        normalizedReason,
        leaveRequest.id,
      ],
    );

    if (Boolean(leaveRequest.is_paid)) {
      const balanceYear = new Date(
        leaveRequest.start_date,
      ).getFullYear();

      await connection.execute(
        `
          UPDATE employee_leave_balances

          SET pending_days =
            GREATEST(
              pending_days - ?,
              0
            )

          WHERE employee_id = ?
            AND leave_type_id = ?
            AND balance_year = ?
        `,
        [
          toNumber(
            leaveRequest.total_days,
          ),
          employeeId,
          leaveRequest.leave_type_id,
          balanceYear,
        ],
      );
    }

    await connection.commit();

    return {
      leave_request_id:
        leaveRequest.id,

      status: 'cancelled',

      cancelled_at:
        new Date().toISOString(),

      cancellation_reason:
        normalizedReason,
    };
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
};

module.exports = {
  getLeaveDashboard,
  getLeaveHistory,
  applyLeave,
  cancelLeave,
};