const pool = require('../config/database');
const AppError = require('../utils/AppError');

const {
  getTimeZoneParts,
} = require('../utils/dateTime');

/**
 * Validates an optional month query.
 *
 * Accepted format:
 * 2026-07
 */
const validateMonth = (value) => {
  if (value == null || value === '') {
    return null;
  }

  const normalizedMonth = String(value).trim();

  if (!/^\d{4}-\d{2}$/.test(normalizedMonth)) {
    throw new AppError(
      422,
      'INVALID_MONTH',
      'Month must use YYYY-MM format',
    );
  }

  const year = Number(
    normalizedMonth.substring(0, 4),
  );

  const monthNumber = Number(
    normalizedMonth.substring(5, 7),
  );

  if (
    !Number.isInteger(year) ||
    year < 2000 ||
    year > 2100 ||
    !Number.isInteger(monthNumber) ||
    monthNumber < 1 ||
    monthNumber > 12
  ) {
    throw new AppError(
      422,
      'INVALID_MONTH',
      'Month must use YYYY-MM format',
    );
  }

  return normalizedMonth;
};

/**
 * Builds the first date of the selected month and
 * the first date of the following month.
 *
 * Example:
 * selected month: 2026-07
 * start date: 2026-07-01
 * end date exclusive: 2026-08-01
 */
const getMonthRange = (
  requestedMonth,
  timezone,
) => {
  const currentDate =
    getTimeZoneParts(timezone).date;

  const selectedMonth =
    validateMonth(requestedMonth) ??
    currentDate.substring(0, 7);

  const [year, month] = selectedMonth
    .split('-')
    .map(Number);

  let nextYear = year;
  let nextMonth = month + 1;

  if (nextMonth > 12) {
    nextMonth = 1;
    nextYear += 1;
  }

  const formattedNextMonth = String(
    nextMonth,
  ).padStart(2, '0');

  return {
    month: selectedMonth,
    startDate: `${selectedMonth}-01`,
    endDateExclusive:
      `${nextYear}-${formattedNextMonth}-01`,
  };
};

/**
 * Loads and validates the authenticated employee.
 */
const getEmployeeContext = async (
  employeeId,
) => {
  const [rows] = await pool.execute(
    `
      SELECT
        e.id AS employee_id,
        e.employee_code,
        e.full_name,
        e.employment_status,
        e.company_id,
        e.branch_id,

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

/**
 * Converts database numeric values safely.
 */
const toNumber = (value) => {
  const result = Number(value);

  return Number.isFinite(result)
    ? result
    : 0;
};

/**
 * Creates a monthly attendance summary.
 */
const createSummary = (records) => {
  return records.reduce(
    (summary, record) => {
      summary.total_records += 1;

      summary.total_working_minutes +=
        toNumber(record.working_minutes);

      summary.total_break_minutes +=
        toNumber(record.break_minutes);

      summary.total_overtime_minutes +=
        toNumber(record.overtime_minutes);

      switch (record.attendance_status) {
        case 'present':
          summary.present_days += 1;
          break;

        case 'late':
          summary.late_days += 1;
          break;

        case 'absent':
          summary.absent_days += 1;
          break;

        case 'half_day':
          summary.half_days += 1;
          break;

        case 'leave':
          summary.leave_days += 1;
          break;

        case 'work_from_home':
          summary.work_from_home_days += 1;
          break;

        case 'holiday':
          summary.holiday_days += 1;
          break;

        case 'week_off':
          summary.week_off_days += 1;
          break;

        case 'incomplete':
          summary.incomplete_days += 1;
          break;

        default:
          break;
      }

      if (
        record.session_status === 'completed'
      ) {
        summary.completed_sessions += 1;
      }

      if (
        record.session_status === 'active'
      ) {
        summary.active_sessions += 1;
      }

      return summary;
    },
    {
      total_records: 0,

      present_days: 0,
      late_days: 0,
      absent_days: 0,
      half_days: 0,
      leave_days: 0,
      work_from_home_days: 0,
      holiday_days: 0,
      week_off_days: 0,
      incomplete_days: 0,

      completed_sessions: 0,
      active_sessions: 0,

      total_working_minutes: 0,
      total_break_minutes: 0,
      total_overtime_minutes: 0,
    },
  );
};

/**
 * GET /api/v1/attendance/history
 * GET /api/v1/attendance/history?month=2026-07
 */
const getAttendanceHistory = async ({
  employeeId,
  month,
}) => {
  const employee =
    await getEmployeeContext(employeeId);

  const timezone =
    employee.timezone ||
    process.env.COMPANY_TIMEZONE ||
    'Asia/Kolkata';

  const monthRange = getMonthRange(
    month,
    timezone,
  );

  const [records] = await pool.execute(
    `
      SELECT
        attendance.id AS attendance_id,
        attendance.attendance_date,

        attendance.check_in_at,
        attendance.check_out_at,

        attendance.working_minutes,
        attendance.break_minutes,
        attendance.overtime_minutes,

        attendance.attendance_status,
        attendance.session_status,
        attendance.notes,

        shift.id AS shift_id,
        shift.name AS shift_name,
        shift.start_time,
        shift.end_time,
        shift.grace_period_minutes,
        shift.late_threshold_minutes

      FROM attendance_records attendance

      LEFT JOIN shifts shift
        ON shift.id = attendance.shift_id

      WHERE attendance.employee_id = ?
        AND attendance.attendance_date >= ?
        AND attendance.attendance_date < ?

      ORDER BY
        attendance.attendance_date DESC,
        attendance.id DESC
    `,
    [
      employeeId,
      monthRange.startDate,
      monthRange.endDateExclusive,
    ],
  );

  const summary = createSummary(records);

  return {
    employee: {
      employee_id:
        employee.employee_id,

      employee_code:
        employee.employee_code,

      name:
        employee.full_name,

      company_id:
        employee.company_id,

      company_name:
        employee.company_name,

      branch_id:
        employee.branch_id,

      branch_name:
        employee.branch_name,

      timezone,
    },

    filter: {
      month:
        monthRange.month,

      start_date:
        monthRange.startDate,

      end_date_exclusive:
        monthRange.endDateExclusive,
    },

    summary,

    records: records.map((record) => {
      return {
        attendance_id:
          record.attendance_id,

        attendance_date:
          record.attendance_date,

        check_in_at:
          record.check_in_at,

        check_out_at:
          record.check_out_at,

        working_minutes:
          toNumber(
            record.working_minutes,
          ),

        break_minutes:
          toNumber(
            record.break_minutes,
          ),

        overtime_minutes:
          toNumber(
            record.overtime_minutes,
          ),

        attendance_status:
          record.attendance_status,

        session_status:
          record.session_status,

        notes:
          record.notes || null,

        shift: record.shift_id
          ? {
              shift_id:
                record.shift_id,

              name:
                record.shift_name,

              start_time:
                record.start_time,

              end_time:
                record.end_time,

              grace_period_minutes:
                toNumber(
                  record
                    .grace_period_minutes,
                ),

              late_threshold_minutes:
                toNumber(
                  record
                    .late_threshold_minutes,
                ),
            }
          : null,
      };
    }),
  };
};

module.exports = {
  getAttendanceHistory,
};