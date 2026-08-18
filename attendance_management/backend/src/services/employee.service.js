const bcrypt = require('bcryptjs');

const pool = require('../config/database');

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;

const FIXED_COMPANY_CODE = 'GODIGITAL';
const FIXED_COMPANY_NAME = 'GoDigital';

const FIXED_BRANCH_CODE = 'GUDUVANCHERY';
const FIXED_BRANCH_NAME = 'Guduvanchery';

const FIXED_SHIFT_CODE = 'GENERAL_9_TO_6';
const FIXED_SHIFT_NAME = '9:00 AM - 6:00 PM';
const FIXED_SHIFT_START = '09:00:00';
const FIXED_SHIFT_END = '18:00:00';

const SCHEMA_TABLES = [
  'users',
  'employees',
  'companies',
  'branches',
  'shifts',
  'employee_credentials',
  'employee_shift_assignments',
];

let schemaCache = null;

function createHttpError(
  statusCode,
  message,
  details = null,
) {
  const error = new Error(message);

  error.statusCode = statusCode;
  error.status = statusCode;
  error.isOperational = true;

  if (details !== null) {
    error.details = details;
  }

  return error;
}

function normalizeString(value) {
  if (
    value === undefined ||
    value === null
  ) {
    return '';
  }

  return String(value).trim();
}

function normalizeBoolean(value) {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  const normalizedValue = normalizeString(
    value,
  ).toLowerCase();

  return [
    'true',
    '1',
    'yes',
    'active',
    'enabled',
  ].includes(normalizedValue);
}

function normalizePositiveInteger(
  value,
  fallback,
) {
  const parsedValue = Number.parseInt(
    String(value ?? ''),
    10,
  );

  if (
    !Number.isInteger(parsedValue) ||
    parsedValue <= 0
  ) {
    return fallback;
  }

  return parsedValue;
}

function getBcryptSaltRounds() {
  const rounds = Number.parseInt(
    process.env.BCRYPT_SALT_ROUNDS ||
      '12',
    10,
  );

  if (
    !Number.isInteger(rounds) ||
    rounds < 8 ||
    rounds > 15
  ) {
    return 12;
  }

  return rounds;
}

function formatDateForDatabase(value) {
  const normalizedValue =
    normalizeString(value);

  if (normalizedValue === '') {
    return null;
  }

  const isoMatch =
    /^(\d{4})-(\d{2})-(\d{2})/.exec(
      normalizedValue,
    );

  if (isoMatch) {
    return (
      `${isoMatch[1]}-` +
      `${isoMatch[2]}-` +
      `${isoMatch[3]}`
    );
  }

  const displayMatch =
    /^(\d{2})[-/](\d{2})[-/](\d{4})$/.exec(
      normalizedValue,
    );

  if (displayMatch) {
    return (
      `${displayMatch[3]}-` +
      `${displayMatch[2]}-` +
      `${displayMatch[1]}`
    );
  }

  throw createHttpError(
    400,
    'date_of_joining must use YYYY-MM-DD format.',
  );
}

function quoteIdentifier(identifier) {
  return `\`${String(identifier).replace(
    /`/g,
    '``',
  )}\``;
}

async function loadSchema(
  database,
  options = {},
) {
  const { refresh = false } = options;

  if (schemaCache && !refresh) {
    return schemaCache;
  }

  const placeholders = SCHEMA_TABLES
    .map(() => '?')
    .join(', ');

  const [rows] = await database.execute(
    `
      SELECT
        TABLE_NAME,
        COLUMN_NAME,
        IS_NULLABLE,
        COLUMN_DEFAULT,
        EXTRA,
        DATA_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME IN (${placeholders})
      ORDER BY TABLE_NAME, ORDINAL_POSITION
    `,
    SCHEMA_TABLES,
  );

  const tables = {};

  for (const tableName of SCHEMA_TABLES) {
    tables[tableName] = {
      exists: false,
      columns: {},
    };
  }

  for (const row of rows) {
    const tableName = row.TABLE_NAME;

    if (!tables[tableName]) {
      tables[tableName] = {
        exists: true,
        columns: {},
      };
    }

    tables[tableName].exists = true;
    tables[tableName].columns[
      row.COLUMN_NAME
    ] = {
      name: row.COLUMN_NAME,
      nullable:
        row.IS_NULLABLE === 'YES',
      defaultValue:
        row.COLUMN_DEFAULT,
      extra: row.EXTRA || '',
      dataType: row.DATA_TYPE,
    };
  }

  schemaCache = tables;
  return schemaCache;
}

function tableExists(schema, tableName) {
  return Boolean(
    schema[tableName]?.exists,
  );
}

function hasColumn(
  schema,
  tableName,
  columnName,
) {
  return Boolean(
    schema[tableName]?.columns?.[
      columnName
    ],
  );
}

function firstColumn(
  schema,
  tableName,
  candidates,
) {
  for (const candidate of candidates) {
    if (
      hasColumn(
        schema,
        tableName,
        candidate,
      )
    ) {
      return candidate;
    }
  }

  return null;
}

function columnExpression(
  schema,
  tableName,
  alias,
  candidates,
  outputAlias,
  fallbackExpression = 'NULL',
) {
  const columnName = firstColumn(
    schema,
    tableName,
    candidates,
  );

  if (!columnName) {
    return (
      `${fallbackExpression} AS ` +
      quoteIdentifier(outputAlias)
    );
  }

  return (
    `${alias}.${quoteIdentifier(
      columnName,
    )} AS ` +
    quoteIdentifier(outputAlias)
  );
}

function activeSqlExpression(
  schema,
  alias = 'e',
) {
  if (
    hasColumn(
      schema,
      'employees',
      'is_active',
    )
  ) {
    return `COALESCE(${alias}.is_active, 0)`;
  }

  const statusColumn = firstColumn(
    schema,
    'employees',
    [
      'employment_status',
      'status',
    ],
  );

  if (statusColumn) {
    return `
      CASE
        WHEN LOWER(
          COALESCE(
            ${alias}.${quoteIdentifier(
              statusColumn,
            )},
            ''
          )
        ) = 'active'
        THEN 1
        ELSE 0
      END
    `;
  }

  return '1';
}

function statusSqlExpression(
  schema,
  alias = 'e',
) {
  const statusColumn = firstColumn(
    schema,
    'employees',
    [
      'employment_status',
      'status',
    ],
  );

  if (statusColumn) {
    return `${alias}.${quoteIdentifier(
      statusColumn,
    )}`;
  }

  return `
    CASE
      WHEN ${activeSqlExpression(
        schema,
        alias,
      )} = 1
      THEN 'active'
      ELSE 'inactive'
    END
  `;
}

function softDeleteCondition(
  schema,
  alias = 'e',
) {
  if (
    hasColumn(
      schema,
      'employees',
      'deleted_at',
    )
  ) {
    return `${alias}.deleted_at IS NULL`;
  }

  return '1 = 1';
}

function buildEmployeeQueryParts(schema) {
  const selectFields = [
    'e.id AS employee_id',
    'e.user_id AS user_id',
    columnExpression(
      schema,
      'employees',
      'e',
      ['employee_code'],
      'employee_code',
      "''",
    ),
    columnExpression(
      schema,
      'employees',
      'e',
      ['full_name', 'name'],
      'full_name',
      "''",
    ),
    columnExpression(
      schema,
      'employees',
      'e',
      ['role_name', 'work_role'],
      'role_name',
      "'Employee'",
    ),
    columnExpression(
      schema,
      'users',
      'u',
      ['email'],
      'email',
      "''",
    ),
    columnExpression(
      schema,
      'employees',
      'e',
      ['phone', 'mobile'],
      'phone',
      "''",
    ),
    columnExpression(
      schema,
      'employees',
      'e',
      ['profile_image_url'],
      'profile_image_url',
      "''",
    ),
    columnExpression(
      schema,
      'employees',
      'e',
      ['date_of_joining'],
      'date_of_joining',
    ),
    columnExpression(
      schema,
      'employees',
      'e',
      ['company_id'],
      'company_id',
    ),
    columnExpression(
      schema,
      'employees',
      'e',
      ['branch_id'],
      'branch_id',
    ),
    `${activeSqlExpression(
      schema,
      'e',
    )} AS is_active`,
    `${statusSqlExpression(
      schema,
      'e',
    )} AS status`,
    columnExpression(
      schema,
      'employees',
      'e',
      ['created_at'],
      'created_at',
    ),
    columnExpression(
      schema,
      'employees',
      'e',
      ['updated_at'],
      'updated_at',
    ),
    columnExpression(
      schema,
      'companies',
      'c',
      ['company_code', 'code'],
      'company_code',
      "'GODIGITAL'",
    ),
    columnExpression(
      schema,
      'companies',
      'c',
      ['name', 'company_name'],
      'company_name',
      "'GoDigital'",
    ),
    columnExpression(
      schema,
      'branches',
      'b',
      ['branch_code', 'code'],
      'branch_code',
      "'GUDUVANCHERY'",
    ),
    columnExpression(
      schema,
      'branches',
      'b',
      ['name', 'branch_name'],
      'branch_name',
      "'Guduvanchery'",
    ),
  ];

  const joins = [
    `LEFT JOIN users u
      ON u.id = e.user_id`,
    `LEFT JOIN companies c
      ON c.id = e.company_id`,
    `LEFT JOIN branches b
      ON b.id = e.branch_id`,
  ];

  const employeeShiftColumn = firstColumn(
    schema,
    'employees',
    ['shift_id'],
  );

  const canJoinShift =
    Boolean(employeeShiftColumn) &&
    tableExists(schema, 'shifts');

  if (canJoinShift) {
    joins.push(
      `LEFT JOIN shifts s
        ON s.id = e.${quoteIdentifier(
          employeeShiftColumn,
        )}`,
    );

    selectFields.push(
      `e.${quoteIdentifier(
        employeeShiftColumn,
      )} AS shift_id`,
      columnExpression(
        schema,
        'shifts',
        's',
        ['shift_code', 'code'],
        'shift_code',
        `'${FIXED_SHIFT_CODE}'`,
      ),
      columnExpression(
        schema,
        'shifts',
        's',
        ['shift_name', 'name'],
        'shift_name',
        `'${FIXED_SHIFT_NAME}'`,
      ),
      columnExpression(
        schema,
        'shifts',
        's',
        ['start_time'],
        'shift_start_time',
        `'${FIXED_SHIFT_START}'`,
      ),
      columnExpression(
        schema,
        'shifts',
        's',
        ['end_time'],
        'shift_end_time',
        `'${FIXED_SHIFT_END}'`,
      ),
    );
  } else {
    selectFields.push(
      'NULL AS shift_id',
      `'${FIXED_SHIFT_CODE}' AS shift_code`,
      `'${FIXED_SHIFT_NAME}' AS shift_name`,
      `'${FIXED_SHIFT_START}' AS shift_start_time`,
      `'${FIXED_SHIFT_END}' AS shift_end_time`,
    );
  }

  const credentialsTableExists =
    tableExists(
      schema,
      'employee_credentials',
    ) &&
    hasColumn(
      schema,
      'employee_credentials',
      'employee_id',
    );

  if (credentialsTableExists) {
    joins.push(
      `LEFT JOIN employee_credentials ec
        ON ec.employee_id = e.id`,
    );

    selectFields.push(
      columnExpression(
        schema,
        'employee_credentials',
        'ec',
        ['username'],
        'username',
        "''",
      ),
      columnExpression(
        schema,
        'employee_credentials',
        'ec',
        ['role'],
        'authentication_role',
        "'employee'",
      ),
      columnExpression(
        schema,
        'employee_credentials',
        'ec',
        ['must_change_password'],
        'must_change_password',
        '0',
      ),
      columnExpression(
        schema,
        'employee_credentials',
        'ec',
        ['is_login_enabled'],
        'is_login_enabled',
        `${activeSqlExpression(
          schema,
          'e',
        )}`,
      ),
      columnExpression(
        schema,
        'employee_credentials',
        'ec',
        ['last_login_at'],
        'last_login_at',
      ),
      columnExpression(
        schema,
        'employee_credentials',
        'ec',
        ['password_changed_at'],
        'password_changed_at',
      ),
    );
  } else {
    selectFields.push(
      "'' AS username",
      "'employee' AS authentication_role",
      '0 AS must_change_password',
      `${activeSqlExpression(
        schema,
        'e',
      )} AS is_login_enabled`,
      'NULL AS last_login_at',
      'NULL AS password_changed_at',
    );
  }

  selectFields.push(
    columnExpression(
      schema,
      'users',
      'u',
      ['status'],
      'user_status',
      "'active'",
    ),
    columnExpression(
      schema,
      'users',
      'u',
      ['role'],
      'user_role',
      "'employee'",
    ),
  );

  return {
    selectSql: `
      SELECT
        ${selectFields.join(',\n        ')}
      FROM employees e
      ${joins.join('\n      ')}
    `,
    fromSql: `
      FROM employees e
      ${joins.join('\n      ')}
    `,
    hasCredentialsJoin:
      credentialsTableExists,
  };
}

function normalizeEmployeeRow(row) {
  if (!row) {
    return null;
  }

  const isActive =
    Number(row.is_active) === 1 ||
    normalizeString(
      row.status,
    ).toLowerCase() === 'active';

  const isLoginEnabled =
    Number(row.is_login_enabled) === 1;

  const mustChangePassword =
    Number(
      row.must_change_password,
    ) === 1;

  return {
    employee_id: row.employee_id,
    employeeId: row.employee_id,
    id: row.employee_id,

    user_id: row.user_id,
    userId: row.user_id,

    employee_code:
      row.employee_code || '',
    employeeCode:
      row.employee_code || '',

    full_name:
      row.full_name || '',
    fullName:
      row.full_name || '',
    employee_name:
      row.full_name || '',

    role_name:
      row.role_name || 'Employee',
    roleName:
      row.role_name || 'Employee',
    employee_role:
      row.role_name || 'Employee',

    email: row.email || '',

    phone: row.phone || '',
    mobile: row.phone || '',

    profile_image_url:
      row.profile_image_url || '',
    profileImageUrl:
      row.profile_image_url || '',

    date_of_joining:
      row.date_of_joining || null,
    dateOfJoining:
      row.date_of_joining || null,

    company_id: row.company_id,
    companyId: row.company_id,
    company_code:
      row.company_code ||
      FIXED_COMPANY_CODE,
    company_name:
      row.company_name ||
      FIXED_COMPANY_NAME,
    companyName:
      row.company_name ||
      FIXED_COMPANY_NAME,

    branch_id: row.branch_id,
    branchId: row.branch_id,
    branch_code:
      row.branch_code ||
      FIXED_BRANCH_CODE,
    branch_name:
      row.branch_name ||
      FIXED_BRANCH_NAME,
    branchName:
      row.branch_name ||
      FIXED_BRANCH_NAME,

    department_id: null,
    departmentId: null,
    department_name: '',
    departmentName: '',

    designation_id: null,
    designationId: null,
    designation_name: '',
    designationName: '',

    shift_id: row.shift_id,
    shiftId: row.shift_id,
    shift_code:
      row.shift_code ||
      FIXED_SHIFT_CODE,
    shift_name:
      row.shift_name ||
      FIXED_SHIFT_NAME,
    shiftName:
      row.shift_name ||
      FIXED_SHIFT_NAME,
    shift_start_time:
      row.shift_start_time ||
      FIXED_SHIFT_START,
    shift_end_time:
      row.shift_end_time ||
      FIXED_SHIFT_END,

    username: row.username || '',
    mobile_username:
      row.username || '',

    authentication_role:
      row.authentication_role ||
      row.user_role ||
      'employee',
    role:
      row.authentication_role ||
      row.user_role ||
      'employee',

    is_active: isActive,
    isActive,

    status:
      row.status ||
      (isActive
        ? 'active'
        : 'inactive'),

    must_change_password:
      mustChangePassword,
    mustChangePassword,

    is_login_enabled:
      isLoginEnabled,
    isLoginEnabled,

    last_login_at:
      row.last_login_at || null,
    password_changed_at:
      row.password_changed_at || null,

    created_at:
      row.created_at || null,
    updated_at:
      row.updated_at || null,
  };
}

function handleDatabaseError(error) {
  if (!error) {
    return;
  }

  if (error.statusCode) {
    throw error;
  }

  if (error.code === 'ER_DUP_ENTRY') {
    const message = normalizeString(
      error.message,
    ).toLowerCase();

    if (
      message.includes('username')
    ) {
      throw createHttpError(
        409,
        'The mobile app username is already in use.',
      );
    }

    if (
      message.includes(
        'employee_code',
      )
    ) {
      throw createHttpError(
        409,
        'The employee code is already in use.',
      );
    }

    if (message.includes('email')) {
      throw createHttpError(
        409,
        'The employee email address is already in use.',
      );
    }

    throw createHttpError(
      409,
      'A record with the same value already exists.',
    );
  }

  if (
    error.code ===
    'ER_NO_REFERENCED_ROW_2'
  ) {
    throw createHttpError(
      400,
      'The company, branch or shift configuration is invalid.',
      error.sqlMessage ||
        error.message ||
        null,
    );
  }

  if (
    error.code ===
    'ER_BAD_FIELD_ERROR'
  ) {
    throw createHttpError(
      500,
      error.sqlMessage ||
        error.message ||
        'A required database column does not exist.',
    );
  }

  if (
    error.code ===
    'ER_NO_DEFAULT_FOR_FIELD'
  ) {
    throw createHttpError(
      500,
      error.sqlMessage ||
        error.message ||
        'A required database field has no value.',
    );
  }

  throw error;
}

function addActiveCondition(
  conditions,
  schema,
  tableName,
  alias,
) {
  const activeColumn = firstColumn(
    schema,
    tableName,
    [
      'is_active',
      'status',
    ],
  );

  if (!activeColumn) {
    return;
  }

  if (activeColumn === 'is_active') {
    conditions.push(
      `COALESCE(${alias}.is_active, 1) = 1`,
    );
    return;
  }

  conditions.push(`
    LOWER(
      COALESCE(
        ${alias}.${quoteIdentifier(
          activeColumn,
        )},
        'active'
      )
    ) = 'active'
  `);
}

async function getFixedAssignment(database) {
  const schema = await loadSchema(
    database,
  );

  if (
    !tableExists(schema, 'companies') ||
    !tableExists(schema, 'branches')
  ) {
    throw createHttpError(
      500,
      'The companies or branches table is missing.',
    );
  }

  const companyNameColumn = firstColumn(
    schema,
    'companies',
    ['name', 'company_name'],
  );

  const companyCodeColumn = firstColumn(
    schema,
    'companies',
    ['company_code', 'code'],
  );

  const companyConditions = [];
  const companyParameters = [];

  addActiveCondition(
    companyConditions,
    schema,
    'companies',
    'c',
  );

  const companyMatch = [];

  if (companyCodeColumn) {
    companyMatch.push(
      `UPPER(c.${quoteIdentifier(
        companyCodeColumn,
      )}) = UPPER(?)`,
    );
    companyParameters.push(
      FIXED_COMPANY_CODE,
    );
  }

  if (companyNameColumn) {
    companyMatch.push(`
      LOWER(
        REPLACE(
          c.${quoteIdentifier(
            companyNameColumn,
          )},
          ' ',
          ''
        )
      ) = LOWER(
        REPLACE(?, ' ', '')
      )
    `);
    companyParameters.push(
      FIXED_COMPANY_NAME,
    );
  }

  if (companyMatch.length) {
    companyConditions.push(
      `(${companyMatch.join(' OR ')})`,
    );
  }

  const companySelectName =
    companyNameColumn
      ? `c.${quoteIdentifier(
          companyNameColumn,
        )}`
      : `'${FIXED_COMPANY_NAME}'`;

  const companySelectCode =
    companyCodeColumn
      ? `c.${quoteIdentifier(
          companyCodeColumn,
        )}`
      : `'${FIXED_COMPANY_CODE}'`;

  let [companyRows] =
    await database.execute(
      `
        SELECT
          c.id,
          ${companySelectName}
            AS company_name,
          ${companySelectCode}
            AS company_code
        FROM companies c
        ${
          companyConditions.length
            ? `WHERE ${companyConditions.join(
                ' AND ',
              )}`
            : ''
        }
        ORDER BY c.id ASC
        LIMIT 1
      `,
      companyParameters,
    );

  if (!companyRows.length) {
    [companyRows] =
      await database.execute(
        `
          SELECT
            c.id,
            ${companySelectName}
              AS company_name,
            ${companySelectCode}
              AS company_code
          FROM companies c
          ORDER BY c.id ASC
          LIMIT 1
        `,
      );
  }

  if (!companyRows.length) {
    throw createHttpError(
      500,
      'GoDigital company configuration was not found.',
    );
  }

  const companyId = companyRows[0].id;

  const branchNameColumn = firstColumn(
    schema,
    'branches',
    ['name', 'branch_name'],
  );

  const branchCodeColumn = firstColumn(
    schema,
    'branches',
    ['branch_code', 'code'],
  );

  const branchConditions = [];
  const branchParameters = [];

  if (
    hasColumn(
      schema,
      'branches',
      'company_id',
    )
  ) {
    branchConditions.push(
      'b.company_id = ?',
    );
    branchParameters.push(companyId);
  }

  addActiveCondition(
    branchConditions,
    schema,
    'branches',
    'b',
  );

  const branchMatch = [];

  if (branchCodeColumn) {
    branchMatch.push(
      `UPPER(b.${quoteIdentifier(
        branchCodeColumn,
      )}) = UPPER(?)`,
    );
    branchParameters.push(
      FIXED_BRANCH_CODE,
    );
  }

  if (branchNameColumn) {
    branchMatch.push(`
      LOWER(
        REPLACE(
          b.${quoteIdentifier(
            branchNameColumn,
          )},
          ' ',
          ''
        )
      ) IN (
        'guduvanchery',
        'guduvancheri'
      )
    `);
  }

  if (branchMatch.length) {
    branchConditions.push(
      `(${branchMatch.join(' OR ')})`,
    );
  }

  const branchSelectName =
    branchNameColumn
      ? `b.${quoteIdentifier(
          branchNameColumn,
        )}`
      : `'${FIXED_BRANCH_NAME}'`;

  const branchSelectCode =
    branchCodeColumn
      ? `b.${quoteIdentifier(
          branchCodeColumn,
        )}`
      : `'${FIXED_BRANCH_CODE}'`;

  let [branchRows] =
    await database.execute(
      `
        SELECT
          b.id,
          ${branchSelectName}
            AS branch_name,
          ${branchSelectCode}
            AS branch_code
        FROM branches b
        ${
          branchConditions.length
            ? `WHERE ${branchConditions.join(
                ' AND ',
              )}`
            : ''
        }
        ORDER BY b.id ASC
        LIMIT 1
      `,
      branchParameters,
    );

  if (!branchRows.length) {
    const fallbackConditions = [];
    const fallbackParameters = [];

    if (
      hasColumn(
        schema,
        'branches',
        'company_id',
      )
    ) {
      fallbackConditions.push(
        'b.company_id = ?',
      );
      fallbackParameters.push(
        companyId,
      );
    }

    [branchRows] =
      await database.execute(
        `
          SELECT
            b.id,
            ${branchSelectName}
              AS branch_name,
            ${branchSelectCode}
              AS branch_code
          FROM branches b
          ${
            fallbackConditions.length
              ? `WHERE ${fallbackConditions.join(
                  ' AND ',
                )}`
              : ''
          }
          ORDER BY b.id ASC
          LIMIT 1
        `,
        fallbackParameters,
      );
  }

  if (!branchRows.length) {
    throw createHttpError(
      500,
      'Guduvanchery branch configuration was not found.',
    );
  }

  const branchId = branchRows[0].id;

  let shiftId = null;
  let shiftName = FIXED_SHIFT_NAME;
  let shiftCode = FIXED_SHIFT_CODE;

  if (tableExists(schema, 'shifts')) {
    const shiftNameColumn = firstColumn(
      schema,
      'shifts',
      ['shift_name', 'name'],
    );

    const shiftCodeColumn = firstColumn(
      schema,
      'shifts',
      ['shift_code', 'code'],
    );

    const shiftConditions = [];
    const shiftParameters = [];

    if (
      hasColumn(
        schema,
        'shifts',
        'company_id',
      )
    ) {
      shiftConditions.push(
        's.company_id = ?',
      );
      shiftParameters.push(companyId);
    }

    if (
      hasColumn(
        schema,
        'shifts',
        'branch_id',
      )
    ) {
      shiftConditions.push(
        '(s.branch_id IS NULL OR s.branch_id = ?)',
      );
      shiftParameters.push(branchId);
    }

    addActiveCondition(
      shiftConditions,
      schema,
      'shifts',
      's',
    );

    const shiftMatch = [];

    if (shiftCodeColumn) {
      shiftMatch.push(
        `UPPER(s.${quoteIdentifier(
          shiftCodeColumn,
        )}) = UPPER(?)`,
      );
      shiftParameters.push(
        FIXED_SHIFT_CODE,
      );
    }

    if (
      hasColumn(
        schema,
        'shifts',
        'start_time',
      ) &&
      hasColumn(
        schema,
        'shifts',
        'end_time',
      )
    ) {
      shiftMatch.push(
        '(s.start_time = ? AND s.end_time = ?)',
      );
      shiftParameters.push(
        FIXED_SHIFT_START,
        FIXED_SHIFT_END,
      );
    }

    if (shiftNameColumn) {
      shiftMatch.push(`
        LOWER(
          REPLACE(
            s.${quoteIdentifier(
              shiftNameColumn,
            )},
            ' ',
            ''
          )
        ) LIKE '%9%6%'
      `);
    }

    if (shiftMatch.length) {
      shiftConditions.push(
        `(${shiftMatch.join(' OR ')})`,
      );
    }

    const shiftSelectName =
      shiftNameColumn
        ? `s.${quoteIdentifier(
            shiftNameColumn,
          )}`
        : `'${FIXED_SHIFT_NAME}'`;

    const shiftSelectCode =
      shiftCodeColumn
        ? `s.${quoteIdentifier(
            shiftCodeColumn,
          )}`
        : `'${FIXED_SHIFT_CODE}'`;

    let [shiftRows] =
      await database.execute(
        `
          SELECT
            s.id,
            ${shiftSelectName}
              AS shift_name,
            ${shiftSelectCode}
              AS shift_code
          FROM shifts s
          ${
            shiftConditions.length
              ? `WHERE ${shiftConditions.join(
                  ' AND ',
                )}`
              : ''
          }
          ORDER BY s.id ASC
          LIMIT 1
        `,
        shiftParameters,
      );

    if (!shiftRows.length) {
      [shiftRows] =
        await database.execute(
          `
            SELECT
              s.id,
              ${shiftSelectName}
                AS shift_name,
              ${shiftSelectCode}
                AS shift_code
            FROM shifts s
            ORDER BY s.id ASC
            LIMIT 1
          `,
        );
    }

    if (shiftRows.length) {
      shiftId = shiftRows[0].id;
      shiftName =
        shiftRows[0].shift_name ||
        FIXED_SHIFT_NAME;
      shiftCode =
        shiftRows[0].shift_code ||
        FIXED_SHIFT_CODE;
    }
  }

  const employeeShiftMetadata =
    schema.employees?.columns?.shift_id;

  if (
    employeeShiftMetadata &&
    !employeeShiftMetadata.nullable &&
    employeeShiftMetadata.defaultValue ===
      null &&
    shiftId === null
  ) {
    throw createHttpError(
      500,
      'The 9:00 AM to 6:00 PM shift configuration was not found.',
    );
  }

  return {
    companyId,
    companyName:
      companyRows[0].company_name ||
      FIXED_COMPANY_NAME,
    companyCode:
      companyRows[0].company_code ||
      FIXED_COMPANY_CODE,

    branchId,
    branchName:
      branchRows[0].branch_name ||
      FIXED_BRANCH_NAME,
    branchCode:
      branchRows[0].branch_code ||
      FIXED_BRANCH_CODE,

    shiftId,
    shiftName,
    shiftCode,
  };
}

async function findEmployeeRawById(
  database,
  employeeId,
  options = {},
) {
  const { includeDeleted = false } =
    options;

  const schema = await loadSchema(
    database,
  );

  const conditions = ['e.id = ?'];

  if (!includeDeleted) {
    conditions.push(
      softDeleteCondition(
        schema,
        'e',
      ),
    );
  }

  const [rows] = await database.execute(
    `
      SELECT
        e.*,
        u.email AS user_email,
        u.status AS user_status,
        u.role AS user_role
      FROM employees e
      LEFT JOIN users u
        ON u.id = e.user_id
      WHERE ${conditions.join(' AND ')}
      LIMIT 1
    `,
    [employeeId],
  );

  return rows[0] || null;
}

async function findEmployeeById(
  database,
  employeeId,
  options = {},
) {
  const { includeDeleted = false } =
    options;

  const schema = await loadSchema(
    database,
  );

  const queryParts =
    buildEmployeeQueryParts(schema);

  const conditions = ['e.id = ?'];

  if (!includeDeleted) {
    conditions.push(
      softDeleteCondition(
        schema,
        'e',
      ),
    );
  }

  const [rows] = await database.execute(
    `
      ${queryParts.selectSql}
      WHERE ${conditions.join(' AND ')}
      LIMIT 1
    `,
    [employeeId],
  );

  return normalizeEmployeeRow(
    rows[0],
  );
}

async function assertEmployeeExists(
  database,
  employeeId,
) {
  const employee =
    await findEmployeeRawById(
      database,
      employeeId,
    );

  if (!employee) {
    throw createHttpError(
      404,
      'Employee not found.',
    );
  }

  return employee;
}

async function assertUniqueValues(
  database,
  payload,
  employeeId = null,
) {
  const schema = await loadSchema(
    database,
  );

  const assignment =
    await getFixedAssignment(database);

  const employeeConditions = [
    'e.company_id = ?',
    'e.employee_code = ?',
    softDeleteCondition(
      schema,
      'e',
    ),
  ];

  const employeeParameters = [
    assignment.companyId,
    payload.employeeCode,
  ];

  if (employeeId !== null) {
    employeeConditions.push(
      'e.id <> ?',
    );
    employeeParameters.push(
      employeeId,
    );
  }

  const [employeeRows] =
    await database.execute(
      `
        SELECT e.id
        FROM employees e
        WHERE ${employeeConditions.join(
          ' AND ',
        )}
        LIMIT 1
      `,
      employeeParameters,
    );

  if (employeeRows.length) {
    throw createHttpError(
      409,
      'The employee code is already in use.',
    );
  }

  const emailConditions = [
    'LOWER(u.email) = LOWER(?)',
  ];

  const emailParameters = [
    payload.email,
  ];

  if (employeeId !== null) {
    emailConditions.push(
      'e.id <> ?',
    );
    emailParameters.push(employeeId);
  }

  emailConditions.push(
    softDeleteCondition(
      schema,
      'e',
    ),
  );

  const [emailRows] =
    await database.execute(
      `
        SELECT u.id
        FROM users u
        INNER JOIN employees e
          ON e.user_id = u.id
        WHERE ${emailConditions.join(
          ' AND ',
        )}
        LIMIT 1
      `,
      emailParameters,
    );

  if (emailRows.length) {
    throw createHttpError(
      409,
      'The employee email address is already in use.',
    );
  }

  if (
    tableExists(
      schema,
      'employee_credentials',
    ) &&
    hasColumn(
      schema,
      'employee_credentials',
      'username',
    )
  ) {
    const credentialConditions = [
      'LOWER(username) = LOWER(?)',
    ];

    const credentialParameters = [
      payload.username,
    ];

    if (employeeId !== null) {
      credentialConditions.push(
        'employee_id <> ?',
      );
      credentialParameters.push(
        employeeId,
      );
    }

    const [credentialRows] =
      await database.execute(
        `
          SELECT employee_id
          FROM employee_credentials
          WHERE ${credentialConditions.join(
            ' AND ',
          )}
          LIMIT 1
        `,
        credentialParameters,
      );

    if (credentialRows.length) {
      throw createHttpError(
        409,
        'The mobile app username is already in use.',
      );
    }
  }

  return assignment;
}

function addInsertValue(
  schema,
  tableName,
  columns,
  expressions,
  parameters,
  columnName,
  value,
  options = {},
) {
  if (
    !hasColumn(
      schema,
      tableName,
      columnName,
    )
  ) {
    return;
  }

  const { raw = false } = options;

  columns.push(
    quoteIdentifier(columnName),
  );

  if (raw) {
    expressions.push(String(value));
  } else {
    expressions.push('?');
    parameters.push(value);
  }
}

function addUpdateValue(
  schema,
  tableName,
  assignments,
  parameters,
  columnName,
  value,
  options = {},
) {
  if (
    !hasColumn(
      schema,
      tableName,
      columnName,
    )
  ) {
    return;
  }

  const { raw = false } = options;

  if (raw) {
    assignments.push(
      `${quoteIdentifier(
        columnName,
      )} = ${value}`,
    );
  } else {
    assignments.push(
      `${quoteIdentifier(
        columnName,
      )} = ?`,
    );
    parameters.push(value);
  }
}

async function insertUser(
  database,
  schema,
  payload,
  passwordHash,
  isActive,
) {
  const columns = [];
  const expressions = [];
  const parameters = [];

  addInsertValue(
    schema,
    'users',
    columns,
    expressions,
    parameters,
    'email',
    payload.email,
  );

  addInsertValue(
    schema,
    'users',
    columns,
    expressions,
    parameters,
    'password_hash',
    passwordHash,
  );

  addInsertValue(
    schema,
    'users',
    columns,
    expressions,
    parameters,
    'role',
    'employee',
  );

  addInsertValue(
    schema,
    'users',
    columns,
    expressions,
    parameters,
    'status',
    isActive
      ? 'active'
      : 'inactive',
  );

  addInsertValue(
    schema,
    'users',
    columns,
    expressions,
    parameters,
    'created_at',
    'CURRENT_TIMESTAMP',
    { raw: true },
  );

  addInsertValue(
    schema,
    'users',
    columns,
    expressions,
    parameters,
    'updated_at',
    'CURRENT_TIMESTAMP',
    { raw: true },
  );

  if (!columns.length) {
    throw createHttpError(
      500,
      'The users table does not contain the required login columns.',
    );
  }

  const [result] = await database.execute(
    `
      INSERT INTO users (
        ${columns.join(', ')}
      )
      VALUES (
        ${expressions.join(', ')}
      )
    `,
    parameters,
  );

  return result.insertId;
}

async function updateUser(
  database,
  schema,
  userId,
  values = {},
) {
  if (!userId) {
    return;
  }

  const assignments = [];
  const parameters = [];

  if (values.email !== undefined) {
    addUpdateValue(
      schema,
      'users',
      assignments,
      parameters,
      'email',
      values.email,
    );
  }

  if (
    values.passwordHash !== undefined &&
    values.passwordHash !== null
  ) {
    addUpdateValue(
      schema,
      'users',
      assignments,
      parameters,
      'password_hash',
      values.passwordHash,
    );
  }

  if (values.status !== undefined) {
    addUpdateValue(
      schema,
      'users',
      assignments,
      parameters,
      'status',
      values.status,
    );
  }

  if (values.role !== undefined) {
    addUpdateValue(
      schema,
      'users',
      assignments,
      parameters,
      'role',
      values.role,
    );
  }

  addUpdateValue(
    schema,
    'users',
    assignments,
    parameters,
    'updated_at',
    'CURRENT_TIMESTAMP',
    { raw: true },
  );

  if (!assignments.length) {
    return;
  }

  parameters.push(userId);

  await database.execute(
    `
      UPDATE users
      SET ${assignments.join(', ')}
      WHERE id = ?
    `,
    parameters,
  );
}

async function insertEmployee(
  database,
  schema,
  payload,
  assignment,
  userId,
  isActive,
  dateOfJoining,
) {
  const columns = [];
  const expressions = [];
  const parameters = [];

  const values = {
    user_id: userId,
    company_id: assignment.companyId,
    branch_id: assignment.branchId,
    department_id: null,
    designation_id: null,
    shift_id: assignment.shiftId,
    employee_code:
      payload.employeeCode,
    full_name: payload.fullName,
    role_name: payload.roleName,
    phone: payload.phone,
    profile_image_url:
      normalizeString(
        payload.profileImageUrl,
      ) || null,
    date_of_joining: dateOfJoining,
    is_active: isActive ? 1 : 0,
    status: isActive
      ? 'active'
      : 'inactive',
    employment_status: isActive
      ? 'active'
      : 'inactive',
  };

  for (const [columnName, value] of
    Object.entries(values)) {
    addInsertValue(
      schema,
      'employees',
      columns,
      expressions,
      parameters,
      columnName,
      value,
    );
  }

  addInsertValue(
    schema,
    'employees',
    columns,
    expressions,
    parameters,
    'created_at',
    'CURRENT_TIMESTAMP',
    { raw: true },
  );

  addInsertValue(
    schema,
    'employees',
    columns,
    expressions,
    parameters,
    'updated_at',
    'CURRENT_TIMESTAMP',
    { raw: true },
  );

  const [result] = await database.execute(
    `
      INSERT INTO employees (
        ${columns.join(', ')}
      )
      VALUES (
        ${expressions.join(', ')}
      )
    `,
    parameters,
  );

  return result.insertId;
}

async function updateEmployeeRecord(
  database,
  schema,
  employeeId,
  payload,
  assignment,
  isActive,
  dateOfJoining,
) {
  const assignments = [];
  const parameters = [];

  const values = {
    company_id: assignment.companyId,
    branch_id: assignment.branchId,
    department_id: null,
    designation_id: null,
    shift_id: assignment.shiftId,
    employee_code:
      payload.employeeCode,
    full_name: payload.fullName,
    role_name: payload.roleName,
    phone: payload.phone,
    profile_image_url:
      normalizeString(
        payload.profileImageUrl,
      ) || null,
    date_of_joining: dateOfJoining,
    is_active: isActive ? 1 : 0,
    status: isActive
      ? 'active'
      : 'inactive',
    employment_status: isActive
      ? 'active'
      : 'inactive',
  };

  for (const [columnName, value] of
    Object.entries(values)) {
    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      columnName,
      value,
    );
  }

  addUpdateValue(
    schema,
    'employees',
    assignments,
    parameters,
    'updated_at',
    'CURRENT_TIMESTAMP',
    { raw: true },
  );

  parameters.push(employeeId);

  await database.execute(
    `
      UPDATE employees
      SET ${assignments.join(', ')}
      WHERE id = ?
        AND ${softDeleteCondition(
          schema,
          'employees',
        ).replace(
          /employees\./g,
          '',
        )}
    `,
    parameters,
  );
}

async function syncEmployeeCredentials(
  database,
  schema,
  employeeId,
  payload,
  passwordHash,
  loginEnabled,
) {
  if (
    !tableExists(
      schema,
      'employee_credentials',
    ) ||
    !hasColumn(
      schema,
      'employee_credentials',
      'employee_id',
    )
  ) {
    return;
  }

  const [rows] = await database.execute(
    `
      SELECT employee_id
      FROM employee_credentials
      WHERE employee_id = ?
      LIMIT 1
    `,
    [employeeId],
  );

  const username = normalizeString(
    payload.username,
  );

  if (!rows.length) {
    if (!passwordHash) {
      throw createHttpError(
        400,
        'A temporary password is required to create mobile login credentials.',
      );
    }

    const columns = [];
    const expressions = [];
    const parameters = [];

    const insertUsername =
      username || `employee_${employeeId}`;

    const values = {
      employee_id: employeeId,
      username: insertUsername,
      password_hash: passwordHash,
      role: 'employee',
      must_change_password:
        normalizeBoolean(
          payload.mustChangePassword,
        )
          ? 1
          : 0,
      is_login_enabled:
        loginEnabled ? 1 : 0,
      failed_login_attempts: 0,
      locked_until: null,
      refresh_token_hash: null,
      refresh_token_expires_at: null,
    };

    for (const [columnName, value] of
      Object.entries(values)) {
      addInsertValue(
        schema,
        'employee_credentials',
        columns,
        expressions,
        parameters,
        columnName,
        value,
      );
    }

    addInsertValue(
      schema,
      'employee_credentials',
      columns,
      expressions,
      parameters,
      'password_changed_at',
      'CURRENT_TIMESTAMP',
      { raw: true },
    );

    addInsertValue(
      schema,
      'employee_credentials',
      columns,
      expressions,
      parameters,
      'created_at',
      'CURRENT_TIMESTAMP',
      { raw: true },
    );

    addInsertValue(
      schema,
      'employee_credentials',
      columns,
      expressions,
      parameters,
      'updated_at',
      'CURRENT_TIMESTAMP',
      { raw: true },
    );

    await database.execute(
      `
        INSERT INTO employee_credentials (
          ${columns.join(', ')}
        )
        VALUES (
          ${expressions.join(', ')}
        )
      `,
      parameters,
    );

    return;
  }

  const assignments = [];
  const parameters = [];

  if (username !== '') {
    addUpdateValue(
      schema,
      'employee_credentials',
      assignments,
      parameters,
      'username',
      username,
    );
  }

  if (passwordHash) {
    addUpdateValue(
      schema,
      'employee_credentials',
      assignments,
      parameters,
      'password_hash',
      passwordHash,
    );
  }

  addUpdateValue(
    schema,
    'employee_credentials',
    assignments,
    parameters,
    'role',
    'employee',
  );

  addUpdateValue(
    schema,
    'employee_credentials',
    assignments,
    parameters,
    'must_change_password',
    normalizeBoolean(
      payload.mustChangePassword,
    )
      ? 1
      : 0,
  );

  addUpdateValue(
    schema,
    'employee_credentials',
    assignments,
    parameters,
    'is_login_enabled',
    loginEnabled ? 1 : 0,
  );

  addUpdateValue(
    schema,
    'employee_credentials',
    assignments,
    parameters,
    'failed_login_attempts',
    0,
  );

  addUpdateValue(
    schema,
    'employee_credentials',
    assignments,
    parameters,
    'locked_until',
    null,
  );

  if (passwordHash) {
    addUpdateValue(
      schema,
      'employee_credentials',
      assignments,
      parameters,
      'refresh_token_hash',
      null,
    );

    addUpdateValue(
      schema,
      'employee_credentials',
      assignments,
      parameters,
      'refresh_token_expires_at',
      null,
    );

    addUpdateValue(
      schema,
      'employee_credentials',
      assignments,
      parameters,
      'password_changed_at',
      'CURRENT_TIMESTAMP',
      { raw: true },
    );
  }

  addUpdateValue(
    schema,
    'employee_credentials',
    assignments,
    parameters,
    'updated_at',
    'CURRENT_TIMESTAMP',
    { raw: true },
  );

  if (!assignments.length) {
    return;
  }

  parameters.push(employeeId);

  await database.execute(
    `
      UPDATE employee_credentials
      SET ${assignments.join(', ')}
      WHERE employee_id = ?
    `,
    parameters,
  );
}

async function assignShiftIfRequired(
  database,
  schema,
  employeeId,
  shiftId,
) {
  if (
    hasColumn(
      schema,
      'employees',
      'shift_id',
    ) ||
    !shiftId ||
    !tableExists(
      schema,
      'employee_shift_assignments',
    ) ||
    !hasColumn(
      schema,
      'employee_shift_assignments',
      'employee_id',
    ) ||
    !hasColumn(
      schema,
      'employee_shift_assignments',
      'shift_id',
    )
  ) {
    return;
  }

  const [existingRows] =
    await database.execute(
      `
        SELECT employee_id
        FROM employee_shift_assignments
        WHERE employee_id = ?
        LIMIT 1
      `,
      [employeeId],
    );

  if (existingRows.length) {
    await database.execute(
      `
        UPDATE employee_shift_assignments
        SET shift_id = ?
        WHERE employee_id = ?
      `,
      [shiftId, employeeId],
    );
    return;
  }

  const columns = [
    'employee_id',
    'shift_id',
  ];

  const expressions = ['?', '?'];
  const parameters = [
    employeeId,
    shiftId,
  ];

  const assignmentTable =
    'employee_shift_assignments';

  if (
    hasColumn(
      schema,
      assignmentTable,
      'effective_from',
    )
  ) {
    columns.push('effective_from');
    expressions.push('CURRENT_DATE');
  }

  if (
    hasColumn(
      schema,
      assignmentTable,
      'start_date',
    )
  ) {
    columns.push('start_date');
    expressions.push('CURRENT_DATE');
  }

  if (
    hasColumn(
      schema,
      assignmentTable,
      'is_active',
    )
  ) {
    columns.push('is_active');
    expressions.push('1');
  }

  await database.execute(
    `
      INSERT INTO employee_shift_assignments (
        ${columns
          .map(quoteIdentifier)
          .join(', ')}
      )
      VALUES (
        ${expressions.join(', ')}
      )
    `,
    parameters,
  );
}

async function getEmployees(filters = {}) {
  const page =
    normalizePositiveInteger(
      filters.page,
      1,
    );

  const requestedLimit =
    normalizePositiveInteger(
      filters.limit,
      DEFAULT_PAGE_SIZE,
    );

  const limit = Math.min(
    requestedLimit,
    MAX_PAGE_SIZE,
  );

  try {
    const schema = await loadSchema(pool);
    const queryParts =
      buildEmployeeQueryParts(schema);

    const whereConditions = [
      softDeleteCondition(
        schema,
        'e',
      ),
    ];

    const parameters = [];

    const search = normalizeString(
      filters.search,
    );

    if (search !== '') {
      const searchValue = `%${search}%`;
      const searchConditions = [];

      if (
        hasColumn(
          schema,
          'employees',
          'employee_code',
        )
      ) {
        searchConditions.push(
          'e.employee_code LIKE ?',
        );
        parameters.push(searchValue);
      }

      if (
        hasColumn(
          schema,
          'employees',
          'full_name',
        )
      ) {
        searchConditions.push(
          'e.full_name LIKE ?',
        );
        parameters.push(searchValue);
      }

      if (
        hasColumn(
          schema,
          'employees',
          'role_name',
        )
      ) {
        searchConditions.push(
          'e.role_name LIKE ?',
        );
        parameters.push(searchValue);
      }

      searchConditions.push(
        'u.email LIKE ?',
      );
      parameters.push(searchValue);

      const phoneColumn = firstColumn(
        schema,
        'employees',
        ['phone', 'mobile'],
      );

      if (phoneColumn) {
        searchConditions.push(
          `e.${quoteIdentifier(
            phoneColumn,
          )} LIKE ?`,
        );
        parameters.push(searchValue);
      }

      if (
        queryParts.hasCredentialsJoin &&
        hasColumn(
          schema,
          'employee_credentials',
          'username',
        )
      ) {
        searchConditions.push(
          'ec.username LIKE ?',
        );
        parameters.push(searchValue);
      }

      if (searchConditions.length) {
        whereConditions.push(
          `(${searchConditions.join(
            ' OR ',
          )})`,
        );
      }
    }

    const roleName = normalizeString(
      filters.roleName ||
        filters.role_name,
    );

    if (
      roleName !== '' &&
      hasColumn(
        schema,
        'employees',
        'role_name',
      )
    ) {
      whereConditions.push(
        'e.role_name LIKE ?',
      );
      parameters.push(`%${roleName}%`);
    }

    const status = normalizeString(
      filters.status,
    ).toLowerCase();

    if (
      status === 'active' ||
      status === 'enabled'
    ) {
      whereConditions.push(
        `${activeSqlExpression(
          schema,
          'e',
        )} = 1`,
      );
    } else if (
      status === 'inactive' ||
      status === 'disabled'
    ) {
      whereConditions.push(
        `${activeSqlExpression(
          schema,
          'e',
        )} = 0`,
      );
    } else if (
      status === 'suspended' ||
      status === 'terminated'
    ) {
      whereConditions.push(
        `LOWER(${statusSqlExpression(
          schema,
          'e',
        )}) = ?`,
      );
      parameters.push(status);
    }

    const whereClause =
      whereConditions.join(' AND ');

    const [countRows] = await pool.execute(
      `
        SELECT
          COUNT(DISTINCT e.id)
            AS total_items
        ${queryParts.fromSql}
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

    const safePage = Math.min(
      page,
      totalPages,
    );

    const offset =
      (safePage - 1) * limit;

    const [rows] = await pool.execute(
      `
        ${queryParts.selectSql}
        WHERE ${whereClause}
        ORDER BY
          ${
            hasColumn(
              schema,
              'employees',
              'created_at',
            )
              ? 'e.created_at DESC,'
              : ''
          }
          e.id DESC
        LIMIT ${limit}
        OFFSET ${offset}
      `,
      parameters,
    );

    return {
      employees: rows.map(
        normalizeEmployeeRow,
      ),
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
  } catch (error) {
    handleDatabaseError(error);
    throw error;
  }
}

async function getEmployeeById(employeeId) {
  try {
    return await findEmployeeById(
      pool,
      employeeId,
    );
  } catch (error) {
    handleDatabaseError(error);
    throw error;
  }
}

async function createEmployee(payload) {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const schema = await loadSchema(
      connection,
    );

    const assignment =
      await assertUniqueValues(
        connection,
        payload,
      );

    const password = normalizeString(
      payload.password,
    );

    if (password.length < 6) {
      throw createHttpError(
        400,
        'Temporary password must contain at least 6 characters.',
      );
    }

    const passwordHash =
      await bcrypt.hash(
        password,
        getBcryptSaltRounds(),
      );

    const isActive = normalizeBoolean(
      payload.isActive,
    );

    const dateOfJoining =
      formatDateForDatabase(
        payload.dateOfJoining,
      );

    const userId = await insertUser(
      connection,
      schema,
      payload,
      passwordHash,
      isActive,
    );

    const employeeId =
      await insertEmployee(
        connection,
        schema,
        payload,
        assignment,
        userId,
        isActive,
        dateOfJoining,
      );

    await syncEmployeeCredentials(
      connection,
      schema,
      employeeId,
      payload,
      passwordHash,
      Boolean(
        normalizeBoolean(
          payload.isLoginEnabled,
        ) && isActive,
      ),
    );

    await assignShiftIfRequired(
      connection,
      schema,
      employeeId,
      assignment.shiftId,
    );

    await connection.commit();

    return await findEmployeeById(
      pool,
      employeeId,
    );
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
    throw error;
  } finally {
    connection.release();
  }
}

async function updateEmployee(
  employeeId,
  payload,
) {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const schema = await loadSchema(
      connection,
    );

    const employee =
      await assertEmployeeExists(
        connection,
        employeeId,
      );

    const assignment =
      await assertUniqueValues(
        connection,
        payload,
        employeeId,
      );

    const isActive = normalizeBoolean(
      payload.isActive,
    );

    const dateOfJoining =
      formatDateForDatabase(
        payload.dateOfJoining,
      );

    const password = normalizeString(
      payload.password,
    );

    let passwordHash = null;

    if (password !== '') {
      if (password.length < 6) {
        throw createHttpError(
          400,
          'Password must contain at least 6 characters.',
        );
      }

      passwordHash = await bcrypt.hash(
        password,
        getBcryptSaltRounds(),
      );
    }

    await updateUser(
      connection,
      schema,
      employee.user_id,
      {
        email: payload.email,
        passwordHash,
        role: 'employee',
        status: isActive
          ? 'active'
          : 'inactive',
      },
    );

    await updateEmployeeRecord(
      connection,
      schema,
      employeeId,
      payload,
      assignment,
      isActive,
      dateOfJoining,
    );

    await syncEmployeeCredentials(
      connection,
      schema,
      employeeId,
      payload,
      passwordHash,
      Boolean(
        normalizeBoolean(
          payload.isLoginEnabled,
        ) && isActive,
      ),
    );

    await assignShiftIfRequired(
      connection,
      schema,
      employeeId,
      assignment.shiftId,
    );

    await connection.commit();

    return await findEmployeeById(
      pool,
      employeeId,
    );
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
    throw error;
  } finally {
    connection.release();
  }
}

async function updateEmployeeStatus(
  employeeId,
  isActive,
) {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const schema = await loadSchema(
      connection,
    );

    const employee =
      await assertEmployeeExists(
        connection,
        employeeId,
      );

    const active = normalizeBoolean(
      isActive,
    );

    const assignments = [];
    const parameters = [];

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'is_active',
      active ? 1 : 0,
    );

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'status',
      active
        ? 'active'
        : 'inactive',
    );

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'employment_status',
      active
        ? 'active'
        : 'inactive',
    );

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'updated_at',
      'CURRENT_TIMESTAMP',
      { raw: true },
    );

    parameters.push(employeeId);

    await connection.execute(
      `
        UPDATE employees
        SET ${assignments.join(', ')}
        WHERE id = ?
      `,
      parameters,
    );

    await updateUser(
      connection,
      schema,
      employee.user_id,
      {
        status: active
          ? 'active'
          : 'inactive',
      },
    );

    if (
      tableExists(
        schema,
        'employee_credentials',
      ) &&
      hasColumn(
        schema,
        'employee_credentials',
        'is_login_enabled',
      )
    ) {
      await connection.execute(
        `
          UPDATE employee_credentials
          SET is_login_enabled = ?
          WHERE employee_id = ?
        `,
        [active ? 1 : 0, employeeId],
      );
    }

    await connection.commit();

    return await findEmployeeById(
      pool,
      employeeId,
    );
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
    throw error;
  } finally {
    connection.release();
  }
}

async function updateEmployeeCredentials(
  employeeId,
  payload,
) {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const schema = await loadSchema(
      connection,
    );

    const employee =
      await assertEmployeeExists(
        connection,
        employeeId,
      );

    const username = normalizeString(
      payload.username,
    );

    if (username === '') {
      throw createHttpError(
        400,
        'username is required.',
      );
    }

    const password = normalizeString(
      payload.password,
    );

    let passwordHash = null;

    if (password !== '') {
      if (password.length < 6) {
        throw createHttpError(
          400,
          'Password must contain at least 6 characters.',
        );
      }

      passwordHash = await bcrypt.hash(
        password,
        getBcryptSaltRounds(),
      );
    }

    const employeeIsActive =
      Number(
        employee.is_active,
      ) === 1 ||
      normalizeString(
        employee.employment_status ||
          employee.status,
      ).toLowerCase() === 'active';

    const loginEnabled =
      normalizeBoolean(
        payload.isLoginEnabled,
      ) && employeeIsActive;

    await syncEmployeeCredentials(
      connection,
      schema,
      employeeId,
      {
        ...payload,
        username,
      },
      passwordHash,
      loginEnabled,
    );

    await updateUser(
      connection,
      schema,
      employee.user_id,
      {
        passwordHash,
        status: loginEnabled
          ? 'active'
          : 'inactive',
      },
    );

    await connection.commit();

    return await findEmployeeById(
      pool,
      employeeId,
    );
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
    throw error;
  } finally {
    connection.release();
  }
}

async function resetEmployeePassword(
  employeeId,
  payload,
) {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const schema = await loadSchema(
      connection,
    );

    const employee =
      await assertEmployeeExists(
        connection,
        employeeId,
      );

    const temporaryPassword =
      normalizeString(
        payload.temporaryPassword,
      );

    if (temporaryPassword.length < 6) {
      throw createHttpError(
        400,
        'Temporary password must contain at least 6 characters.',
      );
    }

    const passwordHash =
      await bcrypt.hash(
        temporaryPassword,
        getBcryptSaltRounds(),
      );

    await updateUser(
      connection,
      schema,
      employee.user_id,
      {
        passwordHash,
      },
    );

    await syncEmployeeCredentials(
      connection,
      schema,
      employeeId,
      {
        ...payload,
        username: normalizeString(
          payload.username,
        ),
        mustChangePassword:
          payload.mustChangePassword !==
          false,
      },
      passwordHash,
      true,
    );

    await connection.commit();

    return await findEmployeeById(
      pool,
      employeeId,
    );
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
    throw error;
  } finally {
    connection.release();
  }
}

async function updateEmployeeLoginStatus(
  employeeId,
  isLoginEnabled,
) {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const schema = await loadSchema(
      connection,
    );

    const employee =
      await assertEmployeeExists(
        connection,
        employeeId,
      );

    const enabled = normalizeBoolean(
      isLoginEnabled,
    );

    const employeeIsActive =
      Number(
        employee.is_active,
      ) === 1 ||
      normalizeString(
        employee.employment_status ||
          employee.status,
      ).toLowerCase() === 'active';

    if (enabled && !employeeIsActive) {
      throw createHttpError(
        400,
        'Activate the employee before enabling mobile login.',
      );
    }

    if (
      tableExists(
        schema,
        'employee_credentials',
      ) &&
      hasColumn(
        schema,
        'employee_credentials',
        'is_login_enabled',
      )
    ) {
      const [result] =
        await connection.execute(
          `
            UPDATE employee_credentials
            SET is_login_enabled = ?
            WHERE employee_id = ?
          `,
          [enabled ? 1 : 0, employeeId],
        );

      if (result.affectedRows === 0) {
        throw createHttpError(
          404,
          'Employee login credentials were not found.',
        );
      }
    }

    await updateUser(
      connection,
      schema,
      employee.user_id,
      {
        status: enabled
          ? 'active'
          : 'inactive',
      },
    );

    await connection.commit();

    return await findEmployeeById(
      pool,
      employeeId,
    );
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
    throw error;
  } finally {
    connection.release();
  }
}

async function deleteEmployee(employeeId) {
  const connection =
    await pool.getConnection();

  try {
    await connection.beginTransaction();

    const schema = await loadSchema(
      connection,
    );

    const employee =
      await assertEmployeeExists(
        connection,
        employeeId,
      );

    const timestamp = Date.now();
    const deletedCode =
      `DEL-${employeeId}-${String(
        timestamp,
      ).slice(-8)}`;
    const deletedEmail =
      `deleted-${employeeId}-${timestamp}` +
      '@deleted.local';
    const deletedUsername =
      `deleted_${employeeId}_${timestamp}`;

    if (
      tableExists(
        schema,
        'employee_credentials',
      )
    ) {
      const assignments = [];
      const parameters = [];

      addUpdateValue(
        schema,
        'employee_credentials',
        assignments,
        parameters,
        'username',
        deletedUsername,
      );

      addUpdateValue(
        schema,
        'employee_credentials',
        assignments,
        parameters,
        'is_login_enabled',
        0,
      );

      addUpdateValue(
        schema,
        'employee_credentials',
        assignments,
        parameters,
        'refresh_token_hash',
        null,
      );

      addUpdateValue(
        schema,
        'employee_credentials',
        assignments,
        parameters,
        'refresh_token_expires_at',
        null,
      );

      addUpdateValue(
        schema,
        'employee_credentials',
        assignments,
        parameters,
        'updated_at',
        'CURRENT_TIMESTAMP',
        { raw: true },
      );

      if (assignments.length) {
        parameters.push(employeeId);

        await connection.execute(
          `
            UPDATE employee_credentials
            SET ${assignments.join(', ')}
            WHERE employee_id = ?
          `,
          parameters,
        );
      }
    }

    await updateUser(
      connection,
      schema,
      employee.user_id,
      {
        email: deletedEmail,
        status: 'inactive',
      },
    );

    const assignments = [];
    const parameters = [];

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'employee_code',
      deletedCode,
    );

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'is_active',
      0,
    );

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'status',
      'terminated',
    );

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'employment_status',
      'terminated',
    );

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'deleted_at',
      'CURRENT_TIMESTAMP',
      { raw: true },
    );

    addUpdateValue(
      schema,
      'employees',
      assignments,
      parameters,
      'updated_at',
      'CURRENT_TIMESTAMP',
      { raw: true },
    );

    parameters.push(employeeId);

    const [result] = await connection.execute(
      `
        UPDATE employees
        SET ${assignments.join(', ')}
        WHERE id = ?
      `,
      parameters,
    );

    if (result.affectedRows === 0) {
      throw createHttpError(
        404,
        'Employee not found.',
      );
    }

    await connection.commit();
    return true;
  } catch (error) {
    await connection.rollback();
    handleDatabaseError(error);
    throw error;
  } finally {
    connection.release();
  }
}

module.exports = {
  getEmployees,
  getEmployeeById,
  createEmployee,
  updateEmployee,
  updateEmployeeStatus,
  updateEmployeeCredentials,
  resetEmployeePassword,
  updateEmployeeLoginStatus,
  deleteEmployee,
};