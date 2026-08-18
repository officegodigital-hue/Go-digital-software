const pool = require('../config/database');
const AppError = require('../utils/AppError');

const MAX_LIMIT = 100;

const parsePositiveId = (
  value,
  fieldName,
) => {
  const parsed = Number(value);

  if (
    !Number.isInteger(parsed) ||
    parsed <= 0
  ) {
    throw new AppError(
      422,
      'VALIDATION_ERROR',
      `${fieldName} must be a valid positive number`,
    );
  }

  return parsed;
};

const mapNotification = (row) => {
  return {
    notification_id: Number(row.notification_id),

    company_id:
      row.company_id == null
        ? null
        : Number(row.company_id),

    branch_id:
      row.branch_id == null
        ? null
        : Number(row.branch_id),

    employee_id:
      row.employee_id == null
        ? null
        : Number(row.employee_id),

    employee_name:
      row.employee_name || null,

    employee_code:
      row.employee_code || null,

    employee_role:
      row.employee_role || null,

    profile_image_url:
      row.profile_image_url || null,

    title: row.title,

    message: row.message,

    notification_type:
      row.notification_type || 'general',

    type:
      row.notification_type || 'general',

    reference_type:
      row.reference_type || null,

    reference_id:
      row.reference_id == null
        ? null
        : Number(row.reference_id),

    external_key:
      row.external_key || null,

    is_read:
      Number(row.is_read) === 1,

    read_at:
      row.read_at || null,

    created_at:
      row.created_at,

    updated_at:
      row.updated_at,
  };
};

const buildCompanyFilter = ({
  companyId,
  branchId,
}) => {
  const conditions = [];
  const values = [];

  if (companyId != null) {
    conditions.push(
      'an.company_id = ?',
    );

    values.push(
      Number(companyId),
    );
  }

  if (branchId != null) {
    conditions.push(
      'an.branch_id = ?',
    );

    values.push(
      Number(branchId),
    );
  }

  return {
    conditions,
    values,
  };
};

// ============================================================
// GET ADMIN NOTIFICATIONS
// ============================================================

const getNotifications = async ({
  companyId = null,
  branchId = null,
  unreadOnly = false,
  page = 1,
  limit = 50,
}) => {
  const safePage = Math.max(
    Number.parseInt(page, 10) || 1,
    1,
  );

  const safeLimit = Math.min(
    Math.max(
      Number.parseInt(limit, 10) || 50,
      1,
    ),
    MAX_LIMIT,
  );

  const offset =
    (safePage - 1) *
    safeLimit;

  const {
    conditions,
    values,
  } = buildCompanyFilter({
    companyId,
    branchId,
  });

  if (unreadOnly) {
    conditions.push(
      'an.is_read = 0',
    );
  }

  const whereClause =
    conditions.length > 0
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

  const [rows] =
    await pool.query(
      `
        SELECT

          an.id
            AS notification_id,

          an.company_id,

          an.branch_id,

          an.employee_id,

          an.title,

          an.message,

          an.notification_type,

          an.reference_type,

          an.reference_id,

          an.external_key,

          an.is_read,

          an.read_at,

          an.created_at,

          an.updated_at,

          e.full_name
            AS employee_name,

          e.employee_code,

          e.role_name
            AS employee_role,

          e.profile_image_url

        FROM admin_notifications an

        LEFT JOIN employees e
          ON e.id = an.employee_id

        ${whereClause}

        ORDER BY
          an.created_at DESC,
          an.id DESC

        LIMIT ?
        OFFSET ?
      `,
      [
        ...values,
        safeLimit,
        offset,
      ],
    );

  const [countRows] =
    await pool.query(
      `
        SELECT

          COUNT(*) AS total_count,

          COALESCE(
            SUM(
              CASE
                WHEN an.is_read = 0
                THEN 1
                ELSE 0
              END
            ),
            0
          ) AS unread_count

        FROM admin_notifications an

        ${whereClause}
      `,
      values,
    );

  const totalCount =
    Number(
      countRows[0]
        ?.total_count || 0,
    );

  return {
    notifications:
      rows.map(
        mapNotification,
      ),

    total_count:
      totalCount,

    unread_count:
      Number(
        countRows[0]
          ?.unread_count || 0,
      ),

    pagination: {
      page: safePage,

      limit: safeLimit,

      total: totalCount,

      total_pages:
        Math.max(
          Math.ceil(
            totalCount /
              safeLimit,
          ),
          1,
        ),
    },
  };
};

// ============================================================
// UNREAD COUNT
// ============================================================

const getUnreadCount = async ({
  companyId = null,
  branchId = null,
}) => {
  const {
    conditions,
    values,
  } = buildCompanyFilter({
    companyId,
    branchId,
  });

  conditions.push(
    'an.is_read = 0',
  );

  const [rows] =
    await pool.query(
      `
        SELECT
          COUNT(*) AS unread_count

        FROM admin_notifications an

        WHERE
          ${conditions.join(' AND ')}
      `,
      values,
    );

  return {
    unread_count:
      Number(
        rows[0]
          ?.unread_count || 0,
      ),
  };
};

// ============================================================
// GET SINGLE
// ============================================================

const getNotificationById = async ({
  notificationId,
  companyId = null,
}) => {
  const validId =
    parsePositiveId(
      notificationId,
      'Notification ID',
    );

  const conditions = [
    'an.id = ?',
  ];

  const values = [
    validId,
  ];

  if (companyId != null) {
    conditions.push(
      'an.company_id = ?',
    );

    values.push(
      Number(companyId),
    );
  }

  const [rows] =
    await pool.query(
      `
        SELECT

          an.id
            AS notification_id,

          an.company_id,

          an.branch_id,

          an.employee_id,

          an.title,

          an.message,

          an.notification_type,

          an.reference_type,

          an.reference_id,

          an.external_key,

          an.is_read,

          an.read_at,

          an.created_at,

          an.updated_at,

          e.full_name
            AS employee_name,

          e.employee_code,

          e.role_name
            AS employee_role,

          e.profile_image_url

        FROM admin_notifications an

        LEFT JOIN employees e
          ON e.id = an.employee_id

        WHERE
          ${conditions.join(' AND ')}

        LIMIT 1
      `,
      values,
    );

  if (!rows[0]) {
    throw new AppError(
      404,
      'ADMIN_NOTIFICATION_NOT_FOUND',
      'Admin notification was not found',
    );
  }

  return mapNotification(
    rows[0],
  );
};

// ============================================================
// MARK ONE READ
// ============================================================

const markAsRead = async ({
  notificationId,
  companyId = null,
}) => {
  const notification =
    await getNotificationById({
      notificationId,
      companyId,
    });

  await pool.query(
    `
      UPDATE admin_notifications

      SET
        is_read = 1,

        read_at =
          COALESCE(
            read_at,
            UTC_TIMESTAMP()
          ),

        updated_at =
          UTC_TIMESTAMP()

      WHERE id = ?
    `,
    [
      notification.notification_id,
    ],
  );

  return getNotificationById({
    notificationId:
      notification.notification_id,

    companyId,
  });
};

// ============================================================
// MARK ALL READ
// ============================================================

const markAllAsRead = async ({
  companyId = null,
  branchId = null,
}) => {
  const {
    conditions,
    values,
  } = buildCompanyFilter({
    companyId,
    branchId,
  });

  conditions.push(
    'an.is_read = 0',
  );

  const [result] =
    await pool.query(
      `
        UPDATE admin_notifications an

        SET
          an.is_read = 1,

          an.read_at =
            COALESCE(
              an.read_at,
              UTC_TIMESTAMP()
            ),

          an.updated_at =
            UTC_TIMESTAMP()

        WHERE
          ${conditions.join(' AND ')}
      `,
      values,
    );

  return {
    updated_count:
      Number(
        result.affectedRows || 0,
      ),

    unread_count: 0,
  };
};

// ============================================================
// DELETE
// ============================================================

const deleteNotification = async ({
  notificationId,
  companyId = null,
}) => {
  const notification =
    await getNotificationById({
      notificationId,
      companyId,
    });

  const [result] =
    await pool.query(
      `
        DELETE FROM
          admin_notifications

        WHERE id = ?
      `,
      [
        notification.notification_id,
      ],
    );

  return {
    deleted_notification_id:
      notification.notification_id,

    deleted:
      result.affectedRows > 0,
  };
};

// ============================================================
// CREATE ADMIN NOTIFICATION
// ============================================================

const createNotification = async ({
  companyId = null,
  branchId = null,
  employeeId = null,
  title,
  message,
  notificationType = 'general',
  referenceType = null,
  referenceId = null,
  externalKey = null,
}) => {
  const cleanTitle =
    String(
      title || '',
    ).trim();

  const cleanMessage =
    String(
      message || '',
    ).trim();

  if (!cleanTitle) {
    throw new AppError(
      422,
      'VALIDATION_ERROR',
      'Admin notification title is required',
    );
  }

  if (!cleanMessage) {
    throw new AppError(
      422,
      'VALIDATION_ERROR',
      'Admin notification message is required',
    );
  }

  const normalizedExternalKey =
    externalKey == null
      ? null
      : String(
          externalKey,
        ).trim() || null;

  // Prevent duplicate event notifications.
  if (normalizedExternalKey) {
    const [existing] =
      await pool.query(
        `
          SELECT id

          FROM admin_notifications

          WHERE external_key = ?

          LIMIT 1
        `,
        [
          normalizedExternalKey,
        ],
      );

    if (existing.length > 0) {
      return getNotificationById({
        notificationId:
          existing[0].id,

        companyId,
      });
    }
  }

  const [result] =
    await pool.query(
      `
        INSERT INTO
          admin_notifications
        (
          company_id,
          branch_id,
          employee_id,

          title,
          message,

          notification_type,

          reference_type,
          reference_id,

          external_key,

          is_read,

          created_at,
          updated_at
        )

        VALUES
        (
          ?,
          ?,
          ?,

          ?,
          ?,

          ?,

          ?,
          ?,

          ?,

          0,

          UTC_TIMESTAMP(),
          UTC_TIMESTAMP()
        )
      `,
      [
        companyId == null
          ? null
          : Number(companyId),

        branchId == null
          ? null
          : Number(branchId),

        employeeId == null
          ? null
          : Number(employeeId),

        cleanTitle,

        cleanMessage,

        String(
          notificationType ||
            'general',
        ).trim(),

        referenceType == null
          ? null
          : String(
              referenceType,
            ).trim(),

        referenceId == null
          ? null
          : Number(
              referenceId,
            ),

        normalizedExternalKey,
      ],
    );

  return getNotificationById({
    notificationId:
      result.insertId,

    companyId,
  });
};

module.exports = {
  getNotifications,
  getUnreadCount,
  getNotificationById,
  markAsRead,
  markAllAsRead,
  deleteNotification,
  createNotification,
};