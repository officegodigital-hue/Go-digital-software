const employeeService = require(
  '../services/employee.service',
);

function createHttpError(
  statusCode,
  message,
  details = null,
) {
  const error = new Error(message);

  error.statusCode = statusCode;
  error.status = statusCode;

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

function optionalString(value) {
  const normalizedValue =
    normalizeString(value);

  return normalizedValue === ''
    ? null
    : normalizedValue;
}

function parsePositiveInteger(
  value,
  fieldName,
  options = {},
) {
  const {
    required = false,
    defaultValue = null,
    maximum = null,
  } = options;

  if (
    value === undefined ||
    value === null ||
    String(value).trim() === ''
  ) {
    if (required) {
      throw createHttpError(
        400,
        `${fieldName} is required.`,
      );
    }

    return defaultValue;
  }

  const parsedValue = Number.parseInt(
    String(value),
    10,
  );

  if (
    !Number.isInteger(parsedValue) ||
    parsedValue <= 0
  ) {
    throw createHttpError(
      400,
      `${fieldName} must be a positive integer.`,
    );
  }

  if (
    maximum !== null &&
    parsedValue > maximum
  ) {
    return maximum;
  }

  return parsedValue;
}

function parseBoolean(
  value,
  fieldName,
  options = {},
) {
  const {
    required = false,
    defaultValue = null,
  } = options;

  if (
    value === undefined ||
    value === null ||
    String(value).trim() === ''
  ) {
    if (required) {
      throw createHttpError(
        400,
        `${fieldName} is required.`,
      );
    }

    return defaultValue;
  }

  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  const normalizedValue = String(value)
    .trim()
    .toLowerCase();

  if (
    [
      'true',
      '1',
      'yes',
      'y',
      'active',
      'enabled',
    ].includes(normalizedValue)
  ) {
    return true;
  }

  if (
    [
      'false',
      '0',
      'no',
      'n',
      'inactive',
      'disabled',
    ].includes(normalizedValue)
  ) {
    return false;
  }

  throw createHttpError(
    400,
    `${fieldName} must be true or false.`,
  );
}

function getAuthenticatedUserId(req) {
  const possibleValues = [
    req.user?.id,
    req.user?.userId,
    req.user?.user_id,
    req.user?.adminId,
    req.user?.admin_id,
    req.auth?.id,
    req.auth?.userId,
    req.auth?.user_id,
  ];

  for (const value of possibleValues) {
    const parsedValue = Number.parseInt(
      String(value ?? ''),
      10,
    );

    if (
      Number.isInteger(parsedValue) &&
      parsedValue > 0
    ) {
      return parsedValue;
    }
  }

  return null;
}

function validateEmail(email) {
  const emailPattern =
    /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

  return emailPattern.test(email);
}

function validatePhone(phone) {
  const digits = phone.replace(
    /[^0-9]/g,
    '',
  );

  return (
    digits.length >= 7 &&
    digits.length <= 15
  );
}

function normalizeEmployeePayload(
  body,
  options = {},
) {
  const {
    requirePassword = false,
  } = options;

  const employeeCode = normalizeString(
    body.employee_code ??
      body.employeeCode,
  );

  const fullName = normalizeString(
    body.full_name ??
      body.fullName ??
      body.employee_name ??
      body.employeeName ??
      body.name,
  );

  const email = normalizeString(
    body.email ??
      body.email_address ??
      body.emailAddress,
  ).toLowerCase();

  const phone = normalizeString(
    body.phone ??
      body.mobile ??
      body.mobile_number ??
      body.mobileNumber,
  );

  const roleName = normalizeString(
    body.role_name ??
      body.roleName ??
      body.employee_role ??
      body.employeeRole ??
      body.job_role ??
      body.jobRole ??
      body.role,
  );

  const username = normalizeString(
    body.username ??
      body.mobile_username ??
      body.mobileUsername ??
      body.login_username ??
      body.loginUsername,
  );

  const password = normalizeString(
    body.temporary_password ??
      body.temporaryPassword ??
      body.new_password ??
      body.newPassword ??
      body.password,
  );

  const profileImageUrl = normalizeString(
    body.profile_image_url ??
      body.profileImageUrl ??
      body.profile_image ??
      body.profileImage,
  );

  const dateOfJoining = optionalString(
    body.date_of_joining ??
      body.dateOfJoining ??
      body.joining_date ??
      body.joiningDate,
  );

  const isActive = parseBoolean(
    body.is_active ??
      body.isActive ??
      body.active,
    'is_active',
    {
      defaultValue: true,
    },
  );

  const mustChangePassword = parseBoolean(
    body.must_change_password ??
      body.mustChangePassword ??
      body.password_change_required ??
      body.passwordChangeRequired,
    'must_change_password',
    {
      defaultValue: true,
    },
  );

  const isLoginEnabled = parseBoolean(
    body.is_login_enabled ??
      body.isLoginEnabled ??
      body.login_enabled ??
      body.loginEnabled,
    'is_login_enabled',
    {
      defaultValue: true,
    },
  );

  const requiredFields = [
    [
      'employee_code',
      employeeCode,
    ],
    [
      'full_name',
      fullName,
    ],
    [
      'email',
      email,
    ],
    [
      'phone',
      phone,
    ],
    [
      'role_name',
      roleName,
    ],
    [
      'username',
      username,
    ],
  ];

  for (const [
    fieldName,
    fieldValue,
  ] of requiredFields) {
    if (fieldValue === '') {
      throw createHttpError(
        400,
        `${fieldName} is required.`,
      );
    }
  }

  if (!validateEmail(email)) {
    throw createHttpError(
      400,
      'Enter a valid email address.',
    );
  }

  if (!validatePhone(phone)) {
    throw createHttpError(
      400,
      'Enter a valid mobile number.',
    );
  }

  if (
    roleName.length < 2 ||
    roleName.length > 100
  ) {
    throw createHttpError(
      400,
      'Role must contain between 2 and 100 characters.',
    );
  }

  if (
    requirePassword &&
    password === ''
  ) {
    throw createHttpError(
      400,
      'Temporary password is required.',
    );
  }

  if (
    password !== '' &&
    password.length < 6
  ) {
    throw createHttpError(
      400,
      'Password must contain at least 6 characters.',
    );
  }

  return {
    employeeCode,
    fullName,
    email,
    phone,
    roleName,
    username,
    password,
    profileImageUrl,
    dateOfJoining,
    isActive,
    mustChangePassword,
    isLoginEnabled,

    /**
     * Authentication role remains employee.
     * roleName is the manually entered work role.
     */
    authenticationRole: 'employee',
  };
}

/**
 * GET /api/v1/admin/employees
 *
 * Search supports:
 * employee name
 * employee code
 * email
 * mobile
 * username
 * role
 */
async function getEmployees(req, res) {
  const page = parsePositiveInteger(
    req.query.page,
    'page',
    {
      defaultValue: 1,
    },
  );

  const limit = parsePositiveInteger(
    req.query.limit,
    'limit',
    {
      defaultValue: 20,
      maximum: 100,
    },
  );

  const filters = {
    search: normalizeString(
      req.query.search,
    ),

    status: normalizeString(
      req.query.status,
    ).toLowerCase(),

    roleName: normalizeString(
      req.query.role_name ??
        req.query.roleName ??
        req.query.role,
    ),

    page,
    limit,
  };

  const result =
    await employeeService.getEmployees(
      filters,
    );

  return res.status(200).json({
    success: true,
    message:
      'Employees fetched successfully.',

    data: {
      employees: result.employees,
      pagination: result.pagination,
    },

    employees: result.employees,
    pagination: result.pagination,
  });
}

/**
 * GET /api/v1/admin/employees/:employeeId
 */
async function getEmployeeById(req, res) {
  const employeeId =
    parsePositiveInteger(
      req.params.employeeId,
      'employeeId',
      {
        required: true,
      },
    );

  const employee =
    await employeeService.getEmployeeById(
      employeeId,
    );

  if (!employee) {
    throw createHttpError(
      404,
      'Employee not found.',
    );
  }

  return res.status(200).json({
    success: true,
    message:
      'Employee fetched successfully.',

    data: {
      employee,
    },

    employee,
  });
}

/**
 * POST /api/v1/admin/employees
 */
async function createEmployee(req, res) {
  const payload =
    normalizeEmployeePayload(
      req.body ?? {},
      {
        requirePassword: true,
      },
    );

  const employee =
    await employeeService.createEmployee(
      payload,
      {
        actorId:
          getAuthenticatedUserId(req),
      },
    );

  return res.status(201).json({
    success: true,
    message:
      'Employee created successfully.',

    data: {
      employee,
    },

    employee,
  });
}

/**
 * PUT /api/v1/admin/employees/:employeeId
 */
async function updateEmployee(req, res) {
  const employeeId =
    parsePositiveInteger(
      req.params.employeeId,
      'employeeId',
      {
        required: true,
      },
    );

  const payload =
    normalizeEmployeePayload(
      req.body ?? {},
      {
        requirePassword: false,
      },
    );

  const employee =
    await employeeService.updateEmployee(
      employeeId,
      payload,
      {
        actorId:
          getAuthenticatedUserId(req),
      },
    );

  if (!employee) {
    throw createHttpError(
      404,
      'Employee not found.',
    );
  }

  return res.status(200).json({
    success: true,
    message:
      'Employee updated successfully.',

    data: {
      employee,
    },

    employee,
  });
}

/**
 * PATCH /api/v1/admin/employees/:employeeId/status
 */
async function updateEmployeeStatus(
  req,
  res,
) {
  const employeeId =
    parsePositiveInteger(
      req.params.employeeId,
      'employeeId',
      {
        required: true,
      },
    );

  let isActive;

  const providedStatus =
    normalizeString(
      req.body?.status,
    ).toLowerCase();

  if (providedStatus !== '') {
    if (
      ![
        'active',
        'inactive',
      ].includes(providedStatus)
    ) {
      throw createHttpError(
        400,
        'status must be active or inactive.',
      );
    }

    isActive =
      providedStatus === 'active';
  } else {
    isActive = parseBoolean(
      req.body?.is_active ??
        req.body?.isActive ??
        req.body?.active,
      'is_active',
      {
        required: true,
      },
    );
  }

  const employee =
    await employeeService.updateEmployeeStatus(
      employeeId,
      isActive,
      {
        actorId:
          getAuthenticatedUserId(req),
      },
    );

  if (!employee) {
    throw createHttpError(
      404,
      'Employee not found.',
    );
  }

  return res.status(200).json({
    success: true,

    message: isActive
      ? 'Employee activated successfully.'
      : 'Employee deactivated successfully.',

    data: {
      employee,
    },

    employee,
  });
}

/**
 * PATCH /api/v1/admin/employees/:employeeId/credentials
 */
async function updateEmployeeCredentials(
  req,
  res,
) {
  const employeeId =
    parsePositiveInteger(
      req.params.employeeId,
      'employeeId',
      {
        required: true,
      },
    );

  const username = normalizeString(
    req.body?.username ??
      req.body?.mobile_username ??
      req.body?.mobileUsername,
  );

  const password = normalizeString(
    req.body?.temporary_password ??
      req.body?.temporaryPassword ??
      req.body?.password,
  );

  if (username === '') {
    throw createHttpError(
      400,
      'username is required.',
    );
  }

  if (
    password !== '' &&
    password.length < 6
  ) {
    throw createHttpError(
      400,
      'Password must contain at least 6 characters.',
    );
  }

  const credentialPayload = {
    username,
    password,

    mustChangePassword: parseBoolean(
      req.body?.must_change_password ??
        req.body?.mustChangePassword,
      'must_change_password',
      {
        defaultValue:
          password !== '',
      },
    ),

    isLoginEnabled: parseBoolean(
      req.body?.is_login_enabled ??
        req.body?.isLoginEnabled,
      'is_login_enabled',
      {
        defaultValue: true,
      },
    ),
  };

  const employee =
    await employeeService
        .updateEmployeeCredentials(
      employeeId,
      credentialPayload,
      {
        actorId:
          getAuthenticatedUserId(req),
      },
    );

  if (!employee) {
    throw createHttpError(
      404,
      'Employee not found.',
    );
  }

  return res.status(200).json({
    success: true,
    message:
      'Employee login credentials updated successfully.',

    data: {
      employee,
    },

    employee,
  });
}

/**
 * PATCH /api/v1/admin/employees/:employeeId/reset-password
 */
async function resetEmployeePassword(
  req,
  res,
) {
  const employeeId =
    parsePositiveInteger(
      req.params.employeeId,
      'employeeId',
      {
        required: true,
      },
    );

  const temporaryPassword =
    normalizeString(
      req.body?.temporary_password ??
        req.body?.temporaryPassword ??
        req.body?.new_password ??
        req.body?.newPassword ??
        req.body?.password,
    );

  if (
    temporaryPassword.length < 6
  ) {
    throw createHttpError(
      400,
      'Temporary password must contain at least 6 characters.',
    );
  }

  const mustChangePassword =
    parseBoolean(
      req.body?.must_change_password ??
        req.body?.mustChangePassword,
      'must_change_password',
      {
        defaultValue: true,
      },
    );

  const employee =
    await employeeService
        .resetEmployeePassword(
      employeeId,
      {
        temporaryPassword,
        mustChangePassword,
      },
      {
        actorId:
          getAuthenticatedUserId(req),
      },
    );

  if (!employee) {
    throw createHttpError(
      404,
      'Employee not found.',
    );
  }

  return res.status(200).json({
    success: true,
    message:
      'Employee password reset successfully.',

    data: {
      employee,
    },

    employee,
  });
}

/**
 * PATCH /api/v1/admin/employees/:employeeId/login-status
 */
async function updateEmployeeLoginStatus(
  req,
  res,
) {
  const employeeId =
    parsePositiveInteger(
      req.params.employeeId,
      'employeeId',
      {
        required: true,
      },
    );

  const isLoginEnabled =
    parseBoolean(
      req.body?.is_login_enabled ??
        req.body?.isLoginEnabled ??
        req.body?.login_enabled ??
        req.body?.loginEnabled,
      'is_login_enabled',
      {
        required: true,
      },
    );

  const employee =
    await employeeService
        .updateEmployeeLoginStatus(
      employeeId,
      isLoginEnabled,
      {
        actorId:
          getAuthenticatedUserId(req),
      },
    );

  if (!employee) {
    throw createHttpError(
      404,
      'Employee not found.',
    );
  }

  return res.status(200).json({
    success: true,

    message: isLoginEnabled
      ? 'Employee mobile login enabled successfully.'
      : 'Employee mobile login disabled successfully.',

    data: {
      employee,
    },

    employee,
  });
}

/**
 * DELETE /api/v1/admin/employees/:employeeId
 */
async function deleteEmployee(req, res) {
  const employeeId =
    parsePositiveInteger(
      req.params.employeeId,
      'employeeId',
      {
        required: true,
      },
    );

  const deleted =
    await employeeService.deleteEmployee(
      employeeId,
      {
        actorId:
          getAuthenticatedUserId(req),
      },
    );

  if (!deleted) {
    throw createHttpError(
      404,
      'Employee not found.',
    );
  }

  return res.status(200).json({
    success: true,
    message:
      'Employee deleted successfully.',

    data: {
      employee_id: employeeId,
    },
  });
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