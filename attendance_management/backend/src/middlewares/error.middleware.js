const fs = require('fs');
const path = require('path');

const errorLogPath = path.join(
  process.cwd(),
  'backend-error.log',
);

function sanitizeBody(body) {
  if (
    !body ||
    typeof body !== 'object'
  ) {
    return body;
  }

  const sanitized = {
    ...body,
  };

  const sensitiveFields = [
    'password',
    'currentPassword',
    'newPassword',
    'confirmPassword',
    'password_hash',
    'token',
    'access_token',
  ];

  for (const field of sensitiveFields) {
    if (
      Object.prototype.hasOwnProperty.call(
        sanitized,
        field,
      )
    ) {
      sanitized[field] = '[REDACTED]';
    }
  }

  return sanitized;
}

function buildErrorDetails(error) {
  return {
    name: error?.name || null,
    message:
      error?.message ||
      'Unknown server error',
    code: error?.code || null,
    statusCode:
      error?.statusCode || null,
    errno: error?.errno || null,
    sqlState:
      error?.sqlState || null,
    sqlMessage:
      error?.sqlMessage || null,
    sql: error?.sql || null,
    details:
      error?.details || null,
    stack: error?.stack || null,
  };
}

function writeErrorLog(
  error,
  req,
) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    request: {
      method: req.method,
      originalUrl: req.originalUrl,
      params: req.params,
      query: req.query,
      body: sanitizeBody(
        req.body,
      ),
      auth: req.auth || null,
      ip: req.ip || null,
    },
    error:
      buildErrorDetails(error),
  };

  const formattedLog =
    `${JSON.stringify(
      logEntry,
      null,
      2,
    )}\n\n`;

  console.error(
    '\n========== BACKEND ERROR ==========\n',
  );

  console.error(
    formattedLog,
  );

  console.error(
    '===================================\n',
  );

  try {
    fs.appendFileSync(
      errorLogPath,
      formattedLog,
      'utf8',
    );
  } catch (logError) {
    console.error(
      'Unable to write backend error log:',
      logError,
    );
  }
}

const notFoundHandler = (
  req,
  res,
) => {
  return res.status(404).json({
    success: false,
    message: 'API endpoint not found',
    error: {
      code: 'ROUTE_NOT_FOUND',
      details: null,
    },
  });
};

const errorHandler = (
  error,
  req,
  res,
  next,
) => {
  /**
   * Keep the fourth argument so Express
   * recognizes this as an error middleware.
   */
  void next;

  writeErrorLog(
    error,
    req,
  );

  const statusCode =
    error.statusCode || 500;

  const code =
    error.code || 'SERVER_ERROR';

  const isDevelopment =
    process.env.NODE_ENV !==
    'production';

  const message =
    error.isOperational ||
    isDevelopment
      ? error.message
      : 'An unexpected server error occurred';

  const developmentDetails =
    isDevelopment
      ? {
          name:
            error.name || null,
          errno:
            error.errno || null,
          sqlState:
            error.sqlState || null,
          sqlMessage:
            error.sqlMessage || null,
          sql:
            error.sql || null,
          stack:
            error.stack || null,
        }
      : null;

  return res
    .status(statusCode)
    .json({
      success: false,
      message:
        message ||
        'An unexpected server error occurred',
      error: {
        code,
        details:
          error.details ||
          developmentDetails,
      },
    });
};

module.exports = {
  notFoundHandler,
  errorHandler,
};