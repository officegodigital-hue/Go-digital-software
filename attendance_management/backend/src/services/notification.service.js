const pool = require('../config/database');
const AppError = require('../utils/AppError');

const MAX_NOTIFICATION_LIMIT = 100;

const parsePositiveId = (
  value,
  fieldName,
) => {
  const parsedValue = Number(value);

  if (
    !Number.isInteger(parsedValue) ||
    parsedValue <= 0
  ) {
    throw new AppError(
      422,
      'VALIDATION_ERROR',
      `${fieldName} must be a valid positive number`,
    );
  }

  return parsedValue;
};

const mapNotification = (
  row,
) => {
  return {
    notification_id: Number(
      row.notification_id,
    ),

    title: row.title,

    message: row.message,

    notification_type:
      row.notification_type ||
      'general',

    type:
      row.notification_type ||
      'general',

    reference_type:
      row.reference_type ||
      null,

    reference_id:
      row.reference_id == null
        ? null
        : Number(
            row.reference_id,
          ),

    is_read:
      Number(row.is_read) === 1,

    read_at:
      row.read_at || null,

    created_at:
      row.created_at,
  };
};

const getNotifications = async ({
  employeeId,
  unreadOnly = false,
}) => {
  const validEmployeeId =
    parsePositiveId(
      employeeId,
      'Employee ID',
    );

  const whereUnread =
    unreadOnly
      ? 'AND is_read = 0'
      : '';

  const [rows] =
    await pool.execute(
      `
        SELECT

          id AS notification_id,

          title,

          message,

          notification_type,

          reference_type,

          reference_id,

          is_read,

          read_at,

          created_at

        FROM notifications

        WHERE employee_id = ?

          ${whereUnread}

        ORDER BY

          created_at DESC,

          id DESC

        LIMIT ${MAX_NOTIFICATION_LIMIT}
      `,
      [
        validEmployeeId,
      ],
    );

  const [countRows] =
    await pool.execute(
      `
        SELECT

          COUNT(*) AS total_count,

          COALESCE(
            SUM(
              CASE
                WHEN is_read = 0
                THEN 1
                ELSE 0
              END
            ),
            0
          ) AS unread_count

        FROM notifications

        WHERE employee_id = ?
      `,
      [
        validEmployeeId,
      ],
    );

  return {
    notifications:
      rows.map(
        mapNotification,
      ),

    total_count:
      Number(
        countRows[0]
          ?.total_count || 0,
      ),

    unread_count:
      Number(
        countRows[0]
          ?.unread_count || 0,
      ),
  };
};

const getUnreadCount = async ({
  employeeId,
}) => {
  const validEmployeeId =
    parsePositiveId(
      employeeId,
      'Employee ID',
    );

  const [rows] =
    await pool.execute(
      `
        SELECT

          COUNT(*) AS unread_count

        FROM notifications

        WHERE employee_id = ?

          AND is_read = 0
      `,
      [
        validEmployeeId,
      ],
    );

  return {
    unread_count:
      Number(
        rows[0]
          ?.unread_count || 0,
      ),
  };
};

const getNotificationById = async ({
  employeeId,
  notificationId,
}) => {
  const validEmployeeId =
    parsePositiveId(
      employeeId,
      'Employee ID',
    );

  const validNotificationId =
    parsePositiveId(
      notificationId,
      'Notification ID',
    );

  const [rows] =
    await pool.execute(
      `
        SELECT

          id AS notification_id,

          title,

          message,

          notification_type,

          reference_type,

          reference_id,

          is_read,

          read_at,

          created_at

        FROM notifications

        WHERE id = ?

          AND employee_id = ?

        LIMIT 1
      `,
      [
        validNotificationId,
        validEmployeeId,
      ],
    );

  if (!rows[0]) {
    throw new AppError(
      404,
      'NOTIFICATION_NOT_FOUND',
      'Notification was not found',
    );
  }

  return mapNotification(
    rows[0],
  );
};

const markNotificationAsRead =
  async ({
    employeeId,
    notificationId,
  }) => {
    const validEmployeeId =
      parsePositiveId(
        employeeId,
        'Employee ID',
      );

    const validNotificationId =
      parsePositiveId(
        notificationId,
        'Notification ID',
      );

    await getNotificationById({
      employeeId:
        validEmployeeId,

      notificationId:
        validNotificationId,
    });

    await pool.execute(
      `
        UPDATE notifications

        SET

          is_read = 1,

          read_at =
            COALESCE(
              read_at,
              UTC_TIMESTAMP()
            )

        WHERE id = ?

          AND employee_id = ?
      `,
      [
        validNotificationId,
        validEmployeeId,
      ],
    );

    return getNotificationById({
      employeeId:
        validEmployeeId,

      notificationId:
        validNotificationId,
    });
  };

const markAllNotificationsAsRead =
  async ({
    employeeId,
  }) => {
    const validEmployeeId =
      parsePositiveId(
        employeeId,
        'Employee ID',
      );

    const [result] =
      await pool.execute(
        `
          UPDATE notifications

          SET

            is_read = 1,

            read_at =
              COALESCE(
                read_at,
                UTC_TIMESTAMP()
              )

          WHERE employee_id = ?

            AND is_read = 0
        `,
        [
          validEmployeeId,
        ],
      );

    return {
      updated_count:
        Number(
          result.affectedRows ||
          0,
        ),

      unread_count: 0,
    };
  };

const deleteNotification = async ({
  employeeId,
  notificationId,
}) => {
  const validEmployeeId =
    parsePositiveId(
      employeeId,
      'Employee ID',
    );

  const validNotificationId =
    parsePositiveId(
      notificationId,
      'Notification ID',
    );

  await getNotificationById({
    employeeId:
      validEmployeeId,

    notificationId:
      validNotificationId,
  });

  const [result] =
    await pool.execute(
      `
        DELETE FROM notifications

        WHERE id = ?

          AND employee_id = ?
      `,
      [
        validNotificationId,
        validEmployeeId,
      ],
    );

  if (
    result.affectedRows === 0
  ) {
    throw new AppError(
      404,
      'NOTIFICATION_NOT_FOUND',
      'Notification was not found',
    );
  }

  return {
    deleted_notification_id:
      validNotificationId,
  };
};

const createNotification = async ({
  employeeId,
  companyId = null,
  title,
  message,
  notificationType = 'general',
  referenceType = null,
  referenceId = null,
  externalKey = null,
}) => {
  const validEmployeeId =
    parsePositiveId(
      employeeId,
      'Employee ID',
    );

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
      'Notification title is required',
    );
  }

  if (!cleanMessage) {
    throw new AppError(
      422,
      'VALIDATION_ERROR',
      'Notification message is required',
    );
  }

  const [result] =
    await pool.execute(
      `
        INSERT INTO notifications
        (
          employee_id,

          company_id,

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
          0,
          UTC_TIMESTAMP(),
          UTC_TIMESTAMP()
        )
      `,
      [
        validEmployeeId,

        companyId == null
          ? null
          : Number(
              companyId,
            ),

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

        externalKey == null
          ? null
          : String(
              externalKey,
            ).trim(),
      ],
    );

  return getNotificationById({
    employeeId:
      validEmployeeId,

    notificationId:
      result.insertId,
  });
};

module.exports = {
  getNotifications,
  getUnreadCount,
  getNotificationById,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
  createNotification,
};