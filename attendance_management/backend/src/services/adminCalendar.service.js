const pool = require('../config/database');
const AppError = require('../utils/AppError');

const HOLIDAY_TYPES = new Set([
  'public',
  'optional',
  'company',
  'regional',
]);

const normalizeText = (
  value,
  {
    maxLength = 255,
    fallback = '',
  } = {},
) => {
  if (value == null) {
    return fallback;
  }

  return String(value)
    .trim()
    .slice(0, maxLength);
};

const normalizeHolidayType = (
  value,
  {
    fallback = 'public',
  } = {},
) => {
  const normalized =
    normalizeText(value, {
      maxLength: 30,
      fallback,
    }).toLowerCase();

  if (!HOLIDAY_TYPES.has(normalized)) {
    throw new AppError(
      400,
      'INVALID_HOLIDAY_TYPE',
      'Holiday type must be public, optional, company, or regional',
    );
  }

  return normalized;
};

const normalizeBoolean = (
  value,
  {
    fallback = true,
  } = {},
) => {
  if (value == null || value === '') {
    return fallback;
  }

  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  const normalized =
    String(value).trim().toLowerCase();

  if (
    normalized === 'true' ||
    normalized === '1' ||
    normalized === 'yes' ||
    normalized === 'active'
  ) {
    return true;
  }

  if (
    normalized === 'false' ||
    normalized === '0' ||
    normalized === 'no' ||
    normalized === 'inactive'
  ) {
    return false;
  }

  return fallback;
};

const normalizePositiveInteger = (
  value,
  {
    fieldName,
    required = true,
  },
) => {
  const parsed = Number.parseInt(
    String(value ?? ''),
    10,
  );

  if (
    !Number.isInteger(parsed) ||
    parsed <= 0
  ) {
    if (!required && value == null) {
      return null;
    }

    throw new AppError(
      400,
      'INVALID_IDENTIFIER',
      `${fieldName} must be a positive integer`,
    );
  }

  return parsed;
};

const normalizeYear = (
  value,
) => {
  if (value == null || value === '') {
    return null;
  }

  const year = Number.parseInt(
    String(value),
    10,
  );

  if (
    !Number.isInteger(year) ||
    year < 2000 ||
    year > 2200
  ) {
    throw new AppError(
      400,
      'INVALID_YEAR',
      'Year must be between 2000 and 2200',
    );
  }

  return year;
};

const normalizeMonth = (
  value,
) => {
  if (value == null || value === '') {
    return null;
  }

  const month = Number.parseInt(
    String(value),
    10,
  );

  if (
    !Number.isInteger(month) ||
    month < 1 ||
    month > 12
  ) {
    throw new AppError(
      400,
      'INVALID_MONTH',
      'Month must be between 1 and 12',
    );
  }

  return month;
};

const normalizeDate = (
  value,
  {
    fieldName = 'Holiday date',
    required = true,
  } = {},
) => {
  if (
    value == null ||
    String(value).trim() === ''
  ) {
    if (!required) {
      return null;
    }

    throw new AppError(
      400,
      'HOLIDAY_DATE_REQUIRED',
      `${fieldName} is required`,
    );
  }

  const normalized =
    String(value).trim().slice(0, 10);

  const match =
    /^(\d{4})-(\d{2})-(\d{2})$/
      .exec(normalized);

  if (!match) {
    throw new AppError(
      400,
      'INVALID_HOLIDAY_DATE',
      `${fieldName} must use YYYY-MM-DD format`,
    );
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);

  const date = new Date(
    Date.UTC(
      year,
      month - 1,
      day,
    ),
  );

  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    throw new AppError(
      400,
      'INVALID_HOLIDAY_DATE',
      `${fieldName} is not a valid calendar date`,
    );
  }

  return normalized;
};

const mapHolidayRow = (
  row,
) => {
  const isActive =
    Number(row.is_active) === 1;

  return {
    id: Number(row.id),

    company_id:
      Number(row.company_id),
    companyId:
      Number(row.company_id),

    branch_id:
      Number(row.branch_id),
    branchId:
      Number(row.branch_id),

    holiday_name:
      row.holiday_name,
    holidayName:
      row.holiday_name,

    holiday_date:
      row.holiday_date,
    holidayDate:
      row.holiday_date,

    holiday_type:
      row.holiday_type,
    holidayType:
      row.holiday_type,

    description:
      row.description || '',

    is_active:
      isActive,
    isActive,

    created_at:
      row.created_at,
    createdAt:
      row.created_at,

    updated_at:
      row.updated_at,
    updatedAt:
      row.updated_at,
  };
};

const handleDatabaseError = (
  error,
) => {
  if (error?.code === 'ER_DUP_ENTRY') {
    throw new AppError(
      409,
      'HOLIDAY_ALREADY_EXISTS',
      'A holiday with the same name and date already exists',
    );
  }

  if (
    error?.code ===
      'ER_NO_REFERENCED_ROW_2' ||
    error?.code ===
      'ER_ROW_IS_REFERENCED_2'
  ) {
    throw new AppError(
      409,
      'HOLIDAY_REFERENCE_CONFLICT',
      'The holiday company or branch reference is invalid',
    );
  }

  throw error;
};

const assertScopeExists = async (
  executor,
  {
    companyId,
    branchId,
  },
) => {
  const [rows] =
    await executor.execute(
      `
        SELECT
          c.id AS company_id,
          b.id AS branch_id

        FROM companies c

        INNER JOIN branches b
          ON b.company_id = c.id

        WHERE c.id = ?
          AND b.id = ?

        LIMIT 1
      `,
      [
        companyId,
        branchId,
      ],
    );

  if (!rows[0]) {
    throw new AppError(
      404,
      'COMPANY_BRANCH_NOT_FOUND',
      'The assigned company or branch was not found',
    );
  }
};

const findHolidayById = async (
  executor,
  {
    holidayId,
    companyId,
    branchId,
    lock = false,
  },
) => {
  const lockClause =
    lock ? 'FOR UPDATE' : '';

  const [rows] =
    await executor.execute(
      `
        SELECT
          id,
          company_id,
          branch_id,
          holiday_name,
          DATE_FORMAT(
            holiday_date,
            '%Y-%m-%d'
          ) AS holiday_date,
          holiday_type,
          description,
          is_active,
          created_at,
          updated_at

        FROM company_holidays

        WHERE id = ?
          AND company_id = ?
          AND branch_id = ?
          AND deleted_at IS NULL

        LIMIT 1

        ${lockClause}
      `,
      [
        holidayId,
        companyId,
        branchId,
      ],
    );

  return rows[0] || null;
};

const getAdminCalendar = async ({
  companyId,
  branchId,
  filters = {},
}) => {
  const safeCompanyId =
    normalizePositiveInteger(
      companyId,
      {
        fieldName: 'Company ID',
      },
    );

  const safeBranchId =
    normalizePositiveInteger(
      branchId,
      {
        fieldName: 'Branch ID',
      },
    );

  const year =
    normalizeYear(filters.year);

  const month =
    normalizeMonth(filters.month);

  const fromDate =
    normalizeDate(
      filters.fromDate ??
        filters.from_date,
      {
        fieldName: 'From date',
        required: false,
      },
    );

  const toDate =
    normalizeDate(
      filters.toDate ??
        filters.to_date,
      {
        fieldName: 'To date',
        required: false,
      },
    );

  if (
    fromDate &&
    toDate &&
    fromDate > toDate
  ) {
    throw new AppError(
      400,
      'INVALID_DATE_RANGE',
      'From date cannot be after to date',
    );
  }

  const search =
    normalizeText(
      filters.search,
      {
        maxLength: 150,
      },
    );

  const requestedType =
    normalizeText(
      filters.type ??
        filters.holidayType ??
        filters.holiday_type,
      {
        maxLength: 30,
      },
    ).toLowerCase();

  const holidayType =
    requestedType &&
    requestedType !== 'all'
      ? normalizeHolidayType(
          requestedType,
        )
      : null;

  const onlyUpcoming =
    normalizeBoolean(
      filters.upcoming,
      {
        fallback: false,
      },
    );

  const includeInactive =
    normalizeBoolean(
      filters.includeInactive ??
        filters.include_inactive,
      {
        fallback: false,
      },
    );

  const whereParts = [
    'h.company_id = ?',
    'h.branch_id = ?',
    'h.deleted_at IS NULL',
  ];

  const params = [
    safeCompanyId,
    safeBranchId,
  ];

  if (!includeInactive) {
    whereParts.push(
      'h.is_active = 1',
    );
  }

  if (year != null) {
    whereParts.push(
      'YEAR(h.holiday_date) = ?',
    );
    params.push(year);
  }

  if (month != null) {
    whereParts.push(
      'MONTH(h.holiday_date) = ?',
    );
    params.push(month);
  }

  if (fromDate) {
    whereParts.push(
      'h.holiday_date >= ?',
    );
    params.push(fromDate);
  }

  if (toDate) {
    whereParts.push(
      'h.holiday_date <= ?',
    );
    params.push(toDate);
  }

  if (holidayType) {
    whereParts.push(
      'h.holiday_type = ?',
    );
    params.push(holidayType);
  }

  if (onlyUpcoming) {
    whereParts.push(
      'h.holiday_date >= CURDATE()',
    );
  }

  if (search) {
    const searchPattern =
      `%${search}%`;

    whereParts.push(
      `
        (
          h.holiday_name LIKE ?
          OR h.description LIKE ?
        )
      `,
    );

    params.push(
      searchPattern,
      searchPattern,
    );
  }

  const [rows] =
    await pool.execute(
      `
        SELECT
          h.id,
          h.company_id,
          h.branch_id,
          h.holiday_name,

          DATE_FORMAT(
            h.holiday_date,
            '%Y-%m-%d'
          ) AS holiday_date,

          h.holiday_type,
          h.description,
          h.is_active,
          h.created_at,
          h.updated_at

        FROM company_holidays h

        WHERE ${whereParts.join(
          '\n AND ',
        )}

        ORDER BY
          h.holiday_date ASC,
          h.holiday_name ASC
      `,
      params,
    );

  const holidays =
    rows.map(mapHolidayRow);

  return {
    holidays,
    records: holidays,

    total: holidays.length,

    filters: {
      year,
      month,

      from_date: fromDate,
      fromDate,

      to_date: toDate,
      toDate,

      search,

      holiday_type:
        holidayType || 'all',
      holidayType:
        holidayType || 'all',

      upcoming: onlyUpcoming,

      include_inactive:
        includeInactive,
      includeInactive,
    },
  };
};

const getHolidayById = async ({
  holidayId,
  companyId,
  branchId,
}) => {
  const safeHolidayId =
    normalizePositiveInteger(
      holidayId,
      {
        fieldName: 'Holiday ID',
      },
    );

  const safeCompanyId =
    normalizePositiveInteger(
      companyId,
      {
        fieldName: 'Company ID',
      },
    );

  const safeBranchId =
    normalizePositiveInteger(
      branchId,
      {
        fieldName: 'Branch ID',
      },
    );

  const row =
    await findHolidayById(
      pool,
      {
        holidayId:
          safeHolidayId,
        companyId:
          safeCompanyId,
        branchId:
          safeBranchId,
      },
    );

  if (!row) {
    throw new AppError(
      404,
      'HOLIDAY_NOT_FOUND',
      'Holiday was not found',
    );
  }

  return mapHolidayRow(row);
};

const createHoliday = async ({
  companyId,
  branchId,
  payload = {},
}) => {
  const safeCompanyId =
    normalizePositiveInteger(
      companyId,
      {
        fieldName: 'Company ID',
      },
    );

  const safeBranchId =
    normalizePositiveInteger(
      branchId,
      {
        fieldName: 'Branch ID',
      },
    );

  const holidayName =
    normalizeText(
      payload.holidayName ??
        payload.holiday_name ??
        payload.name,
      {
        maxLength: 150,
      },
    );

  if (!holidayName) {
    throw new AppError(
      400,
      'HOLIDAY_NAME_REQUIRED',
      'Holiday name is required',
    );
  }

  const holidayDate =
    normalizeDate(
      payload.holidayDate ??
        payload.holiday_date ??
        payload.date,
    );

  const holidayType =
    normalizeHolidayType(
      payload.holidayType ??
        payload.holiday_type ??
        payload.type,
    );

  const description =
    normalizeText(
      payload.description,
      {
        maxLength: 500,
      },
    );

  const isActive =
    normalizeBoolean(
      payload.isActive ??
        payload.is_active,
      {
        fallback: true,
      },
    );

  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    await assertScopeExists(
      connection,
      {
        companyId:
          safeCompanyId,
        branchId:
          safeBranchId,
      },
    );

    const [result] =
      await connection.execute(
        `
          INSERT INTO company_holidays (
            company_id,
            branch_id,
            holiday_name,
            holiday_date,
            holiday_type,
            description,
            is_active
          )
          VALUES (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
          )
        `,
        [
          safeCompanyId,
          safeBranchId,
          holidayName,
          holidayDate,
          holidayType,
          description || null,
          isActive ? 1 : 0,
        ],
      );

    await connection.commit();

    return await getHolidayById({
      holidayId:
        result.insertId,
      companyId:
        safeCompanyId,
      branchId:
        safeBranchId,
    });
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
  } finally {
    connection.release();
  }

  return null;
};

const updateHoliday = async ({
  holidayId,
  companyId,
  branchId,
  payload = {},
}) => {
  const safeHolidayId =
    normalizePositiveInteger(
      holidayId,
      {
        fieldName: 'Holiday ID',
      },
    );

  const safeCompanyId =
    normalizePositiveInteger(
      companyId,
      {
        fieldName: 'Company ID',
      },
    );

  const safeBranchId =
    normalizePositiveInteger(
      branchId,
      {
        fieldName: 'Branch ID',
      },
    );

  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const existing =
      await findHolidayById(
        connection,
        {
          holidayId:
            safeHolidayId,
          companyId:
            safeCompanyId,
          branchId:
            safeBranchId,
          lock: true,
        },
      );

    if (!existing) {
      throw new AppError(
        404,
        'HOLIDAY_NOT_FOUND',
        'Holiday was not found',
      );
    }

    const holidayName =
      payload.holidayName != null ||
      payload.holiday_name != null ||
      payload.name != null
        ? normalizeText(
            payload.holidayName ??
              payload.holiday_name ??
              payload.name,
            {
              maxLength: 150,
            },
          )
        : existing.holiday_name;

    if (!holidayName) {
      throw new AppError(
        400,
        'HOLIDAY_NAME_REQUIRED',
        'Holiday name is required',
      );
    }

    const holidayDate =
      payload.holidayDate != null ||
      payload.holiday_date != null ||
      payload.date != null
        ? normalizeDate(
            payload.holidayDate ??
              payload.holiday_date ??
              payload.date,
          )
        : existing.holiday_date;

    const holidayType =
      payload.holidayType != null ||
      payload.holiday_type != null ||
      payload.type != null
        ? normalizeHolidayType(
            payload.holidayType ??
              payload.holiday_type ??
              payload.type,
          )
        : existing.holiday_type;

    const description =
      payload.description !== undefined
        ? normalizeText(
            payload.description,
            {
              maxLength: 500,
            },
          )
        : existing.description || '';

    const isActive =
      payload.isActive !== undefined ||
      payload.is_active !== undefined
        ? normalizeBoolean(
            payload.isActive ??
              payload.is_active,
            {
              fallback:
                Number(
                  existing.is_active,
                ) === 1,
            },
          )
        : Number(
            existing.is_active,
          ) === 1;

    await connection.execute(
      `
        UPDATE company_holidays

        SET
          holiday_name = ?,
          holiday_date = ?,
          holiday_type = ?,
          description = ?,
          is_active = ?

        WHERE id = ?
          AND company_id = ?
          AND branch_id = ?
          AND deleted_at IS NULL
      `,
      [
        holidayName,
        holidayDate,
        holidayType,
        description || null,
        isActive ? 1 : 0,

        safeHolidayId,
        safeCompanyId,
        safeBranchId,
      ],
    );

    await connection.commit();

    return await getHolidayById({
      holidayId:
        safeHolidayId,
      companyId:
        safeCompanyId,
      branchId:
        safeBranchId,
    });
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
  } finally {
    connection.release();
  }

  return null;
};

const deleteHoliday = async ({
  holidayId,
  companyId,
  branchId,
}) => {
  const safeHolidayId =
    normalizePositiveInteger(
      holidayId,
      {
        fieldName: 'Holiday ID',
      },
    );

  const safeCompanyId =
    normalizePositiveInteger(
      companyId,
      {
        fieldName: 'Company ID',
      },
    );

  const safeBranchId =
    normalizePositiveInteger(
      branchId,
      {
        fieldName: 'Branch ID',
      },
    );

  const [result] =
    await pool.execute(
      `
        UPDATE company_holidays

        SET
          deleted_at = NOW(),
          is_active = 0

        WHERE id = ?
          AND company_id = ?
          AND branch_id = ?
          AND deleted_at IS NULL
      `,
      [
        safeHolidayId,
        safeCompanyId,
        safeBranchId,
      ],
    );

  if (result.affectedRows === 0) {
    throw new AppError(
      404,
      'HOLIDAY_NOT_FOUND',
      'Holiday was not found',
    );
  }

  return {
    holiday_id:
      safeHolidayId,
    holidayId:
      safeHolidayId,

    deleted: true,
  };
};

module.exports = {
  HOLIDAY_TYPES,

  getAdminCalendar,
  getHolidayById,
  createHoliday,
  updateHoliday,
  deleteHoliday,
};