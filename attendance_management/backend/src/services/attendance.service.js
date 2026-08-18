const pool = require('../config/database');
const AppError = require('../utils/AppError');

const {
  getTimeZoneParts,
  timeStringToMinutes,
  calculateShiftMinutes,
  calculateMinutesBetween,
} = require('../utils/dateTime');

const {
  validateGeofenceAccess,
} = require('../utils/geo');


const ADMIN_ATTENDANCE_DEFAULT_PAGE_SIZE = 20;
const ADMIN_ATTENDANCE_MAX_PAGE_SIZE = 100;
const ADMIN_ATTENDANCE_EXPORT_LIMIT = 5000;

const normalizeAdminString = (value) => {
  if (value === undefined || value === null) {
    return '';
  }

  return String(value).trim();
};

const normalizeAdminPositiveInteger = (
  value,
  fallback,
) => {
  const parsed = Number.parseInt(
    String(value ?? ''),
    10,
  );

  if (!Number.isInteger(parsed) || parsed <= 0) {
    return fallback;
  }

  return parsed;
};

const normalizeAdminDate = (
  value,
  fieldName,
) => {
  const normalized = normalizeAdminString(value);

  if (normalized === '') {
    return null;
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
    throw new AppError(
      400,
      'INVALID_DATE',
      `${fieldName} must use YYYY-MM-DD format`,
    );
  }

  const date = new Date(`${normalized}T00:00:00.000Z`);

  if (
    Number.isNaN(date.getTime()) ||
    date.toISOString().slice(0, 10) !== normalized
  ) {
    throw new AppError(
      400,
      'INVALID_DATE',
      `${fieldName} is not a valid date`,
    );
  }

  return normalized;
};

const normalizeAdminBoolean = (value) => {
  const normalized = normalizeAdminString(value).toLowerCase();

  return ['true', '1', 'yes'].includes(normalized);
};

const normalizeAttendanceDateValue = (value) => {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return value.toISOString().slice(0, 10);
  }

  return String(value).slice(0, 10);
};

const mapAdminAttendanceRow = (row) => {
  const breakMinutes = Math.max(
    0,
    Number(row.break_minutes || 0),
  );

  let workingMinutes = Math.max(
    0,
    Number(row.working_minutes || 0),
  );

  if (row.check_in_at && !row.check_out_at) {
    const liveGrossMinutes = calculateMinutesBetween(
      row.check_in_at,
      new Date(),
    );

    workingMinutes = Math.max(
      0,
      liveGrossMinutes - breakMinutes,
    );
  }

  const scheduledMinutes =
    row.shift_start_time && row.shift_end_time
      ? calculateShiftMinutes(
          row.shift_start_time,
          row.shift_end_time,
        )
      : 0;

  const extraHoursMinutes =
    scheduledMinutes > 0
      ? Math.max(
          0,
          workingMinutes - scheduledMinutes,
        )
      : Math.max(
          0,
          Number(row.overtime_minutes || 0),
        );

  const overtimeMinutes = Math.max(
    0,
    Number(row.overtime_minutes || 0),
  );

  const attendanceDate =
    normalizeAttendanceDateValue(
      row.attendance_date,
    );

  return {
    attendance_id: row.attendance_id,
    attendanceId: row.attendance_id,
    id: row.attendance_id,

    employee_id: row.employee_id,
    employeeId: row.employee_id,

    employee_code: row.employee_code || '',
    employeeCode: row.employee_code || '',

    employee_name: row.employee_name || '',
    employeeName: row.employee_name || '',
    full_name: row.employee_name || '',
    fullName: row.employee_name || '',

    role_name: row.role_name || 'Employee',
    roleName: row.role_name || 'Employee',

    email: row.email || '',

    profile_image_url:
      row.profile_image_url || '',
    profileImageUrl:
      row.profile_image_url || '',

    attendance_date: attendanceDate,
    attendanceDate,

    check_in_at: row.check_in_at || null,
    checkInAt: row.check_in_at || null,

    check_out_at: row.check_out_at || null,
    checkOutAt: row.check_out_at || null,

    working_minutes: workingMinutes,
    workingMinutes,

    break_minutes: breakMinutes,
    breakMinutes,

    scheduled_minutes: scheduledMinutes,
    scheduledMinutes,

    extra_hours_minutes: extraHoursMinutes,
    extraHoursMinutes,

    overtime_minutes: overtimeMinutes,
    overtimeMinutes,

    attendance_status:
      row.attendance_status || 'unknown',
    attendanceStatus:
      row.attendance_status || 'unknown',

    session_status:
      row.session_status || 'unknown',
    sessionStatus:
      row.session_status || 'unknown',

    shift_id: row.shift_id || null,
    shiftId: row.shift_id || null,

    shift_name: row.shift_name || '',
    shiftName: row.shift_name || '',

    shift_start_time:
      row.shift_start_time || null,
    shiftStartTime:
      row.shift_start_time || null,

    shift_end_time:
      row.shift_end_time || null,
    shiftEndTime:
      row.shift_end_time || null,
  };
};

const getEmployeeContext = async (
  executor,
  employeeId,
) => {
  const [rows] = await executor.execute(
    `
      SELECT
        e.id AS employee_id,
        e.company_id,
        e.branch_id,
        e.employee_code,
        e.full_name,
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

const getOfficeLocation = async (
  executor,
  companyId,
  branchId,
) => {
  const [rows] = await executor.execute(
    `
      SELECT
        id,
        company_id,
        branch_id,
        name,
        address,
        latitude,
        longitude,
        radius_meters,
        strict_mode,
        status

      FROM office_locations

      WHERE company_id = ?
        AND branch_id = ?
        AND status = 'active'

      ORDER BY id DESC
      LIMIT 1
    `,
    [
      companyId,
      branchId,
    ],
  );

  return rows[0] || null;
};

const getAssignedShift = async (
  executor,
  employeeContext,
  attendanceDate,
) => {
  const [assignedRows] = await executor.execute(
    `
      SELECT
        s.id,
        s.name,
        s.start_time,
        s.end_time,
        s.grace_period_minutes,
        s.late_threshold_minutes

      FROM employee_shift_assignments esa

      INNER JOIN shifts s
        ON s.id = esa.shift_id

      WHERE esa.employee_id = ?
        AND esa.effective_from <= ?
        AND (
          esa.effective_to IS NULL
          OR esa.effective_to >= ?
        )
        AND s.status = 'active'

      ORDER BY esa.effective_from DESC
      LIMIT 1
    `,
    [
      employeeContext.employee_id,
      attendanceDate,
      attendanceDate,
    ],
  );

  if (assignedRows[0]) {
    return assignedRows[0];
  }

  const [defaultRows] = await executor.execute(
    `
      SELECT
        id,
        name,
        start_time,
        end_time,
        grace_period_minutes,
        late_threshold_minutes

      FROM shifts

      WHERE company_id = ?
        AND (
          branch_id = ?
          OR branch_id IS NULL
        )
        AND status = 'active'

      ORDER BY
        CASE
          WHEN branch_id = ? THEN 0
          ELSE 1
        END,
        id ASC

      LIMIT 1
    `,
    [
      employeeContext.company_id,
      employeeContext.branch_id,
      employeeContext.branch_id,
    ],
  );

  return defaultRows[0] || null;
};


const getAttendanceRecord = async (
  executor,
  employeeId,
  attendanceDate,
  {
    lock = false,
  } = {},
) => {

  const lockClause = lock
    ? 'FOR UPDATE'
    : '';

  const [rows] = await executor.execute(
    `
    SELECT
      ar.id,
      ar.employee_id,
      ar.company_id,
      ar.branch_id,
      ar.shift_id,

      ar.attendance_date,

      ar.check_in_at,
      ar.check_out_at,

      ar.working_minutes,
      ar.break_minutes,
      ar.overtime_minutes,

      ar.attendance_status,
      ar.session_status,

      s.name AS shift_name,
      s.start_time,
      s.end_time,
      s.grace_period_minutes,
      s.late_threshold_minutes

    FROM attendance_records ar

    LEFT JOIN shifts s
      ON s.id = ar.shift_id

    WHERE ar.employee_id = ?

    AND ar.attendance_date = ?

    ORDER BY ar.id DESC

    LIMIT 1

    ${lockClause}
    `,
    [
      employeeId,
      attendanceDate,
    ],
  );

  return rows[0] || null;

};


const getAttendanceBreaks = async (
  executor,
  attendanceId,
) => {
  const [rows] = await executor.execute(
    `
      SELECT
        id,
        attendance_id,
        started_at,
        ended_at,
        duration_minutes,
        status

      FROM attendance_breaks

      WHERE attendance_id = ?

      ORDER BY started_at ASC
    `,
    [attendanceId],
  );

  return rows;
};

const getActiveBreak = async (
  executor,
  attendanceId,
  {
    lock = false,
  } = {},
) => {
  const lockClause = lock
    ? 'FOR UPDATE'
    : '';

  const [rows] = await executor.execute(
    `
      SELECT
        id,
        attendance_id,
        started_at,
        ended_at,
        duration_minutes,
        status

      FROM attendance_breaks

      WHERE attendance_id = ?
        AND status = 'active'

      ORDER BY started_at DESC
      LIMIT 1
      ${lockClause}
    `,
    [attendanceId],
  );

  return rows[0] || null;
};

const convertDatabaseBoolean = (value) => {
  if (value == null) {
    return null;
  }

  return (
    value === true ||
    value === 1 ||
    value === '1'
  );
};

const mapOfficeLocation = (
  officeLocation,
) => {
  if (!officeLocation) {
    return null;
  }

  return {
    id: officeLocation.id,
    name: officeLocation.name,
    address: officeLocation.address,

    latitude: Number(
      officeLocation.latitude,
    ),

    longitude: Number(
      officeLocation.longitude,
    ),

    radius_meters: Number(
      officeLocation.radius_meters,
    ),

    strict_mode: convertDatabaseBoolean(
      officeLocation.strict_mode,
    ),
  };
};

const mapShift = (shift) => {
  if (!shift) {
    return null;
  }

  return {
    shift_id: shift.id,
    name: shift.name,
    start_time: shift.start_time,
    end_time: shift.end_time,

    grace_period_minutes: Number(
      shift.grace_period_minutes || 0,
    ),

    late_threshold_minutes: Number(
      shift.late_threshold_minutes || 0,
    ),
  };
};

const buildPermissions = ({
  attendance,
  activeBreak,
}) => {

  if (!attendance) {

    return {
      can_check_in: true,
      can_check_out: false,
      can_start_break: false,
      can_end_break: false,
      can_request_overtime: false,
    };

  }


  const checkedIn =
    Boolean(attendance.check_in_at);

  const checkedOut =
    Boolean(attendance.check_out_at);


  return {

    can_check_in:false,


    can_check_out:
      checkedIn &&
      !checkedOut &&
      !activeBreak,


    can_start_break:
      checkedIn &&
      !checkedOut &&
      !activeBreak,


    can_end_break:
      checkedIn &&
      !checkedOut &&
      Boolean(activeBreak),


    can_request_overtime:
      checkedIn &&
      !checkedOut,

  };

};
const getTodayAttendance = async ({
  employeeId,
}) => {
  const employeeContext =
    await getEmployeeContext(
      pool,
      employeeId,
    );

  const timezone =
    employeeContext.timezone ||
    process.env.COMPANY_TIMEZONE ||
    'Asia/Kolkata';

  const timeParts =
    getTimeZoneParts(timezone);

  const attendanceDate =
    timeParts.date;

  const attendance =
    await getAttendanceRecord(
      pool,
      employeeId,
      attendanceDate,
    );

  const officeLocation =
    await getOfficeLocation(
      pool,
      employeeContext.company_id,
      employeeContext.branch_id,
    );

  const assignedShift =
    attendance
      ? null
      : await getAssignedShift(
          pool,
          employeeContext,
          attendanceDate,
        );

  if (!attendance) {
    return {
      employee: {
        employee_id:
          employeeContext.employee_id,

        employee_code:
          employeeContext.employee_code,

        name:
          employeeContext.full_name,

        company_name:
          employeeContext.company_name,

        branch_name:
          employeeContext.branch_name,

        timezone,
      },

      today: {
        date: attendanceDate,

        attendance_id: null,

        attendance_status:
          'not_checked_in',

        session_status: null,

        check_in_at: null,
        check_out_at: null,

        working_minutes: 0,
        break_minutes: 0,
        overtime_minutes: 0,

        active_break: false,
      },

      shift: mapShift(
        assignedShift,
      ),

      office_location:
        mapOfficeLocation(
          officeLocation,
        ),

      permissions:
        buildPermissions({
          attendance: null,
          activeBreak: null,
        }),
    };
  }

  const breakRows =
    await getAttendanceBreaks(
      pool,
      attendance.id,
    );

  const activeBreak =
    breakRows.find(
      (breakRecord) =>
        breakRecord.status === 'active',
    ) || null;

  const completedBreakMinutes =
    breakRows
      .filter(
        (breakRecord) =>
          breakRecord.status !== 'active',
      )
      .reduce(
        (
          total,
          breakRecord,
        ) => {
          return (
            total +
            Number(
              breakRecord.duration_minutes ||
                0,
            )
          );
        },
        0,
      );

  const activeBreakMinutes =
    activeBreak
      ? calculateMinutesBetween(
          activeBreak.started_at,
          new Date(),
        )
      : 0;

  const totalBreakMinutes =
    completedBreakMinutes +
    activeBreakMinutes;

  let workingMinutes = Number(
    attendance.working_minutes || 0,
  );

  if (
    attendance.check_in_at &&
    !attendance.check_out_at
  ) {
    const grossMinutes =
      calculateMinutesBetween(
        attendance.check_in_at,
        new Date(),
      );

    workingMinutes = Math.max(
      0,
      grossMinutes -
        totalBreakMinutes,
    );
  }

  return {
    employee: {
      employee_id:
        employeeContext.employee_id,

      employee_code:
        employeeContext.employee_code,

      name:
        employeeContext.full_name,

      company_name:
        employeeContext.company_name,

      branch_name:
        employeeContext.branch_name,

      timezone,
    },

    today: {
      date: attendanceDate,

      attendance_id:
        attendance.id,

      attendance_status:
        attendance.attendance_status,

      session_status:
        attendance.session_status,

      check_in_at:
        attendance.check_in_at,

      check_out_at:
        attendance.check_out_at,

      working_minutes:
        workingMinutes,

      break_minutes:
        totalBreakMinutes,

      overtime_minutes:
        Number(
          attendance.overtime_minutes || 0,
        ),

      active_break:
        activeBreak != null,

      active_break_started_at:
        activeBreak?.started_at || null,
    },

    shift: attendance.shift_id
      ? {
          shift_id:
            attendance.shift_id,

          name:
            attendance.shift_name,

          start_time:
            attendance.start_time,

          end_time:
            attendance.end_time,

          grace_period_minutes:
            Number(
              attendance
                .grace_period_minutes ||
                0,
            ),

          late_threshold_minutes:
            Number(
              attendance
                .late_threshold_minutes ||
                0,
            ),
        }
      : null,

    office_location:
      mapOfficeLocation(
        officeLocation,
      ),

    permissions:
      buildPermissions({
        attendance,
        activeBreak,
      }),
  };
};

const checkIn = async ({
  employeeId,
  body,
}) => {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const employeeContext =
      await getEmployeeContext(
        connection,
        employeeId,
      );

    const timezone =
      employeeContext.timezone ||
      process.env.COMPANY_TIMEZONE ||
      'Asia/Kolkata';

    const timeParts =
      getTimeZoneParts(timezone);

    const attendanceDate =
      timeParts.date;

    const attendance =
      await getAttendanceRecord(
        connection,
        employeeId,
        attendanceDate,
        {
          lock: true,
        },
      );

    if (attendance?.check_in_at) {
      throw new AppError(
        409,
        'ALREADY_CHECKED_IN',
        'You have already checked in today',
      );
    }

    const officeLocation =
      await getOfficeLocation(
        connection,
        employeeContext.company_id,
        employeeContext.branch_id,
      );

    const {
      location,
      geofence,
    } = validateGeofenceAccess({
      rawLocation:
        body?.location ?? null,

      officeLocation,
    });

    const shift =
      await getAssignedShift(
        connection,
        employeeContext,
        attendanceDate,
      );

    let attendanceStatus =
      'present';

    if (shift) {
      const shiftStartMinutes =
        timeStringToMinutes(
          shift.start_time,
        );

      const allowedCheckInMinutes =
        shiftStartMinutes +
        Number(
          shift.grace_period_minutes ||
            0,
        );

      if (
        timeParts.minutesFromMidnight >
        allowedCheckInMinutes
      ) {
        attendanceStatus = 'late';
      }
    }

    const insideGeofence =
      geofence.inside == null
        ? null
        : geofence.inside
          ? 1
          : 0;

    if (attendance) {
      await connection.execute(
        `
          UPDATE attendance_records

          SET
            shift_id = ?,

            check_in_at =
              UTC_TIMESTAMP(),

            check_out_at = NULL,

            check_in_latitude = ?,
            check_in_longitude = ?,
            check_in_accuracy_meters = ?,
            check_in_inside_geofence = ?,
            check_in_distance_meters = ?,

            attendance_status = ?,
            session_status = 'active',

            working_minutes = 0,
            break_minutes = 0,
            overtime_minutes = 0

          WHERE id = ?
        `,
        [
          shift?.id ?? null,

          location?.latitude ?? null,
          location?.longitude ?? null,
          location?.accuracyMeters ?? null,

          insideGeofence,

          geofence.distanceMeters ??
            null,

          attendanceStatus,

          attendance.id,
        ],
      );
    } else {
      await connection.execute(
        `
          INSERT INTO attendance_records (
            employee_id,
            company_id,
            branch_id,
            shift_id,

            attendance_date,
            check_in_at,

            check_in_latitude,
            check_in_longitude,
            check_in_accuracy_meters,
            check_in_inside_geofence,
            check_in_distance_meters,

            attendance_status,
            session_status,
            source_system
          )
          VALUES (
            ?, ?, ?, ?,
            ?, UTC_TIMESTAMP(),
            ?, ?, ?, ?, ?,
            ?, 'active', 'attendance'
          )
        `,
        [
          employeeId,
          employeeContext.company_id,
          employeeContext.branch_id,
          shift?.id ?? null,

          attendanceDate,

          location?.latitude ?? null,
          location?.longitude ?? null,
          location?.accuracyMeters ?? null,

          insideGeofence,

          geofence.distanceMeters ??
            null,

          attendanceStatus,
        ],
      );
    }

    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }

  return getTodayAttendance({
    employeeId,
  });
};

const startBreak = async ({
  employeeId,
}) => {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const employeeContext =
      await getEmployeeContext(
        connection,
        employeeId,
      );

    const timezone =
      employeeContext.timezone ||
      process.env.COMPANY_TIMEZONE ||
      'Asia/Kolkata';

    const attendanceDate =
      getTimeZoneParts(
        timezone,
      ).date;

    const attendance =
      await getAttendanceRecord(
        connection,
        employeeId,
        attendanceDate,
        {
          lock: true,
        },
      );

    if (!attendance?.check_in_at) {
      throw new AppError(
        409,
        'NOT_CHECKED_IN',
        'Please check in before starting a break',
      );
    }

    if (attendance.check_out_at) {
      throw new AppError(
        409,
        'ATTENDANCE_COMPLETED',
        'Attendance is already completed',
      );
    }

    const activeBreak =
      await getActiveBreak(
        connection,
        attendance.id,
        {
          lock: true,
        },
      );

    if (activeBreak) {
      throw new AppError(
        409,
        'BREAK_ALREADY_ACTIVE',
        'A break is already active',
      );
    }

    await connection.execute(
      `
        INSERT INTO attendance_breaks (
          attendance_id,
          started_at,
          status
        )
        VALUES (
          ?,
          UTC_TIMESTAMP(),
          'active'
        )
      `,
      [attendance.id],
    );

    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }

  return getTodayAttendance({
    employeeId,
  });
};

const endBreak = async ({
  employeeId,
}) => {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const employeeContext =
      await getEmployeeContext(
        connection,
        employeeId,
      );

    const timezone =
      employeeContext.timezone ||
      process.env.COMPANY_TIMEZONE ||
      'Asia/Kolkata';

    const attendanceDate =
      getTimeZoneParts(
        timezone,
      ).date;

    const attendance =
      await getAttendanceRecord(
        connection,
        employeeId,
        attendanceDate,
        {
          lock: true,
        },
      );

    if (
      !attendance?.check_in_at ||
      attendance.check_out_at
    ) {
      throw new AppError(
        409,
        'NO_ACTIVE_ATTENDANCE',
        'No active attendance session was found',
      );
    }

    const activeBreak =
      await getActiveBreak(
        connection,
        attendance.id,
        {
          lock: true,
        },
      );

    if (!activeBreak) {
      throw new AppError(
        409,
        'NO_ACTIVE_BREAK',
        'There is no active break',
      );
    }

    await connection.execute(
      `
        UPDATE attendance_breaks

        SET
          ended_at =
            UTC_TIMESTAMP(),

          duration_minutes =
            GREATEST(
              0,
              TIMESTAMPDIFF(
                MINUTE,
                started_at,
                UTC_TIMESTAMP()
              )
            ),

          status = 'completed'

        WHERE id = ?
      `,
      [activeBreak.id],
    );

    const [breakSummaryRows] =
      await connection.execute(
        `
          SELECT
            COALESCE(
              SUM(duration_minutes),
              0
            ) AS total_break_minutes

          FROM attendance_breaks

          WHERE attendance_id = ?
            AND status IN (
              'completed',
              'auto_closed'
            )
        `,
        [attendance.id],
      );

    const breakMinutes =
      Number(
        breakSummaryRows[0]
          .total_break_minutes || 0,
      );

    await connection.execute(
      `
        UPDATE attendance_records

        SET break_minutes = ?

        WHERE id = ?
      `,
      [
        breakMinutes,
        attendance.id,
      ],
    );

    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }

  return getTodayAttendance({
    employeeId,
  });
};

const checkOut = async ({
  employeeId,
  body,
}) => {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const employeeContext =
      await getEmployeeContext(
        connection,
        employeeId,
      );

    const timezone =
      employeeContext.timezone ||
      process.env.COMPANY_TIMEZONE ||
      'Asia/Kolkata';

    const attendanceDate =
      getTimeZoneParts(
        timezone,
      ).date;

    const attendance =
      await getAttendanceRecord(
        connection,
        employeeId,
        attendanceDate,
        {
          lock: true,
        },
      );

    if (!attendance?.check_in_at) {
      throw new AppError(
        409,
        'NOT_CHECKED_IN',
        'Please check in first',
      );
    }

    if (attendance.check_out_at) {
      throw new AppError(
        409,
        'ALREADY_CHECKED_OUT',
        'You have already checked out today',
      );
    }

    const officeLocation =
      await getOfficeLocation(
        connection,
        employeeContext.company_id,
        employeeContext.branch_id,
      );

    const {
      location,
      geofence,
    } = validateGeofenceAccess({
      rawLocation:
        body?.location ?? null,

      officeLocation,
    });

    await connection.execute(
      `
        UPDATE attendance_breaks

        SET
          ended_at =
            UTC_TIMESTAMP(),

          duration_minutes =
            GREATEST(
              0,
              TIMESTAMPDIFF(
                MINUTE,
                started_at,
                UTC_TIMESTAMP()
              )
            ),

          status = 'auto_closed'

        WHERE attendance_id = ?
          AND status = 'active'
      `,
      [attendance.id],
    );

    const [breakSummaryRows] =
      await connection.execute(
        `
          SELECT
            COALESCE(
              SUM(duration_minutes),
              0
            ) AS total_break_minutes

          FROM attendance_breaks

          WHERE attendance_id = ?
            AND status IN (
              'completed',
              'auto_closed'
            )
        `,
        [attendance.id],
      );

    const breakMinutes =
      Number(
        breakSummaryRows[0]
          .total_break_minutes || 0,
      );

    const [grossRows] =
      await connection.execute(
        `
          SELECT
            GREATEST(
              0,
              TIMESTAMPDIFF(
                MINUTE,
                check_in_at,
                UTC_TIMESTAMP()
              )
            ) AS gross_minutes

          FROM attendance_records

          WHERE id = ?
        `,
        [attendance.id],
      );

    const grossMinutes =
      Number(
        grossRows[0]
          .gross_minutes || 0,
      );

    const workingMinutes =
      Math.max(
        0,
        grossMinutes -
          breakMinutes,
      );

    const scheduledMinutes =
      attendance.start_time &&
      attendance.end_time
        ? calculateShiftMinutes(
            attendance.start_time,
            attendance.end_time,
          )
        : 0;

    const overtimeMinutes =
      scheduledMinutes > 0
        ? Math.max(
            0,
            workingMinutes -
              scheduledMinutes,
          )
        : 0;

    const insideGeofence =
      geofence.inside == null
        ? null
        : geofence.inside
          ? 1
          : 0;

    await connection.execute(
      `
        UPDATE attendance_records

        SET
          check_out_at =
            UTC_TIMESTAMP(),

          check_out_latitude = ?,
          check_out_longitude = ?,
          check_out_accuracy_meters = ?,
          check_out_inside_geofence = ?,
          check_out_distance_meters = ?,

          working_minutes = ?,
          break_minutes = ?,
          overtime_minutes = ?,

          session_status = 'completed'

        WHERE id = ?
      `,
      [
        location?.latitude ?? null,
        location?.longitude ?? null,
        location?.accuracyMeters ?? null,

        insideGeofence,

        geofence.distanceMeters ??
          null,

        workingMinutes,
        breakMinutes,
        overtimeMinutes,

        attendance.id,
      ],
    );

    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }

  return getTodayAttendance({
    employeeId,
  });
};



/**
 * Admin Daily Attendance Log
 *
 * Supports:
 * - company and branch scoping
 * - date range filtering
 * - employee search
 * - attendance status filtering
 * - pagination
 * - export mode
 */
const getAdminAttendanceLog = async ({
  companyId,
  branchId = null,
  filters = {},
}) => {
  if (!companyId) {
    throw new AppError(
      400,
      'COMPANY_CONTEXT_REQUIRED',
      'Admin company context is required',
    );
  }

  const page = normalizeAdminPositiveInteger(
    filters.page,
    1,
  );

  const requestedLimit = normalizeAdminPositiveInteger(
    filters.limit,
    ADMIN_ATTENDANCE_DEFAULT_PAGE_SIZE,
  );

  const exportMode = normalizeAdminBoolean(
    filters.export,
  );

  const limit = exportMode
    ? ADMIN_ATTENDANCE_EXPORT_LIMIT
    : Math.min(
        requestedLimit,
        ADMIN_ATTENDANCE_MAX_PAGE_SIZE,
      );

  const fromDate = normalizeAdminDate(
    filters.fromDate ?? filters.from_date,
    'from_date',
  );

  const toDate = normalizeAdminDate(
    filters.toDate ?? filters.to_date,
    'to_date',
  );

  if (fromDate && toDate && fromDate > toDate) {
    throw new AppError(
      400,
      'INVALID_DATE_RANGE',
      'from_date cannot be after to_date',
    );
  }

  const whereConditions = [
    'ar.company_id = ?',
    'e.deleted_at IS NULL',
  ];

  const parameters = [companyId];

  if (branchId) {
    whereConditions.push('ar.branch_id = ?');
    parameters.push(branchId);
  }

  if (fromDate) {
    whereConditions.push('ar.attendance_date >= ?');
    parameters.push(fromDate);
  }

  if (toDate) {
    whereConditions.push('ar.attendance_date <= ?');
    parameters.push(toDate);
  }

  const search = normalizeAdminString(
    filters.search,
  );

  if (search !== '') {
    const searchValue = `%${search}%`;

    whereConditions.push(`
      (
        e.full_name LIKE ?
        OR e.employee_code LIKE ?
        OR e.role_name LIKE ?
        OR u.email LIKE ?
      )
    `);

    parameters.push(
      searchValue,
      searchValue,
      searchValue,
      searchValue,
    );
  }

  const status = normalizeAdminString(
    filters.status,
  ).toLowerCase();

  if (status !== '' && status !== 'all') {
    whereConditions.push(
      'LOWER(ar.attendance_status) = ?',
    );
    parameters.push(status);
  }

  const sessionStatus = normalizeAdminString(
    filters.sessionStatus ??
      filters.session_status,
  ).toLowerCase();

  if (
    sessionStatus !== '' &&
    sessionStatus !== 'all'
  ) {
    whereConditions.push(
      'LOWER(ar.session_status) = ?',
    );
    parameters.push(sessionStatus);
  }

  const whereClause =
    whereConditions.join(' AND ');

  const [countRows] = await pool.execute(
    `
      SELECT
        COUNT(DISTINCT ar.id) AS total_items

      FROM attendance_records ar

      INNER JOIN employees e
        ON e.id = ar.employee_id

      LEFT JOIN users u
        ON u.id = e.user_id

      WHERE ${whereClause}
    `,
    parameters,
  );

  const totalItems = Number(
    countRows[0]?.total_items || 0,
  );

  const totalPages = Math.max(
    1,
    Math.ceil(totalItems / limit),
  );

  const safePage = exportMode
    ? 1
    : Math.min(page, totalPages);

  const offset = exportMode
    ? 0
    : (safePage - 1) * limit;

  const [summaryRows] = await pool.execute(
    `
      SELECT
        COUNT(DISTINCT ar.id) AS total_records,

        COALESCE(
          SUM(
            CASE
              WHEN LOWER(
                ar.attendance_status
              ) = 'present'
              THEN 1
              ELSE 0
            END
          ),
          0
        ) AS present_records,

        COALESCE(
          SUM(
            CASE
              WHEN LOWER(
                ar.attendance_status
              ) = 'late'
              THEN 1
              ELSE 0
            END
          ),
          0
        ) AS late_records,

        COALESCE(
          SUM(
            CASE
              WHEN LOWER(
                ar.attendance_status
              ) = 'absent'
              THEN 1
              ELSE 0
            END
          ),
          0
        ) AS absent_records,

        COALESCE(
          SUM(
            CASE
              WHEN LOWER(
                ar.session_status
              ) = 'active'
              THEN 1
              ELSE 0
            END
          ),
          0
        ) AS active_sessions,

        COALESCE(
          SUM(
            CASE
              WHEN LOWER(
                ar.session_status
              ) = 'completed'
              THEN 1
              ELSE 0
            END
          ),
          0
        ) AS completed_sessions

      FROM attendance_records ar

      INNER JOIN employees e
        ON e.id = ar.employee_id

      LEFT JOIN users u
        ON u.id = e.user_id

      WHERE ${whereClause}
    `,
    parameters,
  );

  const [rows] = await pool.execute(
    `
      SELECT
        ar.id AS attendance_id,
        ar.employee_id,
        ar.shift_id,
        ar.attendance_date,

        ar.check_in_at,
        ar.check_out_at,

        ar.working_minutes,
        ar.break_minutes,
        ar.overtime_minutes,

        ar.attendance_status,
        ar.session_status,

        e.employee_code,
        e.full_name AS employee_name,
        e.role_name,
        e.profile_image_url,

        u.email,

        s.name AS shift_name,
        s.start_time AS shift_start_time,
        s.end_time AS shift_end_time

      FROM attendance_records ar

      INNER JOIN employees e
        ON e.id = ar.employee_id

      LEFT JOIN users u
        ON u.id = e.user_id

      LEFT JOIN shifts s
        ON s.id = ar.shift_id

      WHERE ${whereClause}

      ORDER BY
        ar.attendance_date DESC,
        ar.check_in_at DESC,
        ar.id DESC

      LIMIT ${limit}
      OFFSET ${offset}
    `,
    parameters,
  );

  const summary = summaryRows[0] || {};

  const records = rows.map(
    mapAdminAttendanceRow,
  );

  return {
    records,
    attendance_records: records,

    summary: {
      total_records: Number(
        summary.total_records || 0,
      ),
      totalRecords: Number(
        summary.total_records || 0,
      ),

      present_records: Number(
        summary.present_records || 0,
      ),
      presentRecords: Number(
        summary.present_records || 0,
      ),

      late_records: Number(
        summary.late_records || 0,
      ),
      lateRecords: Number(
        summary.late_records || 0,
      ),

      absent_records: Number(
        summary.absent_records || 0,
      ),
      absentRecords: Number(
        summary.absent_records || 0,
      ),

      active_sessions: Number(
        summary.active_sessions || 0,
      ),
      activeSessions: Number(
        summary.active_sessions || 0,
      ),

      completed_sessions: Number(
        summary.completed_sessions || 0,
      ),
      completedSessions: Number(
        summary.completed_sessions || 0,
      ),
    },

    filters: {
      from_date: fromDate,
      fromDate,

      to_date: toDate,
      toDate,

      search,
      status: status || 'all',

      session_status:
        sessionStatus || 'all',
      sessionStatus:
        sessionStatus || 'all',

      export: exportMode,
    },

    pagination: {
      current_page: safePage,
      currentPage: safePage,

      total_pages: totalPages,
      totalPages,

      total_items: totalItems,
      totalItems,

      page_size: limit,
      pageSize: limit,

      page: safePage,
      limit,

      has_previous_page:
        safePage > 1,
      hasPreviousPage:
        safePage > 1,

      has_next_page:
        safePage < totalPages,
      hasNextPage:
        safePage < totalPages,
    },
  };
};

module.exports = {
  getTodayAttendance,
  getAdminAttendanceLog,
  checkIn,
  checkOut,
  startBreak,
  endBreak,
};