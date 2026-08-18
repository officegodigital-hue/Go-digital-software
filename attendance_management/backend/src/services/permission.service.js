const db = require('../config/database');

const notificationService = require(
  './notification.service'
);

const adminNotificationService = require(
  './adminNotification.service'
);

class PermissionService {
  // ===========================================================================
  // Pagination
  // ===========================================================================

  static normalizePagination(page, limit) {
    const safePage = Math.max(
      Number.parseInt(page, 10) || 1,
      1
    );

    const safeLimit = Math.min(
      Math.max(
        Number.parseInt(limit, 10) || 5,
        1
      ),
      100
    );

    return {
      page: safePage,
      limit: safeLimit,
      offset: (safePage - 1) * safeLimit,
    };
  }

  // ===========================================================================
  // Admin Filters
  // ===========================================================================

  static buildFilters({
    companyId,
    branchId,
    search,
    type,
    status,
  }) {
    const conditions = [
      'pr.deleted_at IS NULL',
    ];

    const values = [];

    if (companyId) {
      conditions.push(
        'pr.company_id = ?'
      );

      values.push(companyId);
    }

    if (branchId) {
      conditions.push(
        'pr.branch_id = ?'
      );

      values.push(branchId);
    }

    if (
      type &&
      [
        'leave_request',
        'late_login',
        'early_logout',
      ].includes(type)
    ) {
      conditions.push(
        'pr.request_type = ?'
      );

      values.push(type);
    }

    if (
      status &&
      [
        'pending',
        'approved',
        'rejected',
        'cancelled',
      ].includes(status)
    ) {
      conditions.push(
        'pr.status = ?'
      );

      values.push(status);
    }

    if (
      search &&
      search.trim()
    ) {
      const keyword =
        `%${search.trim()}%`;

      conditions.push(`
        (
          e.full_name LIKE ?
          OR e.employee_code LIKE ?
          OR e.role_name LIKE ?
          OR pr.request_title LIKE ?
          OR pr.reason LIKE ?
          OR pr.employee_remarks LIKE ?
          OR pr.admin_remarks LIKE ?
        )
      `);

      values.push(
        keyword,
        keyword,
        keyword,
        keyword,
        keyword,
        keyword,
        keyword
      );
    }

    return {
      whereClause:
        conditions.join(' AND '),

      values,
    };
  }

  // ===========================================================================
  // ADMIN - GET PERMISSION REQUESTS
  // ===========================================================================

  static async getPermissionRequests({
    companyId,
    branchId,
    page = 1,
    limit = 5,
    search = '',
    type = '',
    status = 'pending',
  }) {
    const pagination =
      this.normalizePagination(
        page,
        limit
      );

    const {
      whereClause,
      values,
    } = this.buildFilters({
      companyId,
      branchId,
      search,
      type,
      status,
    });

    const countSql = `
      SELECT
        COUNT(*) AS total

      FROM permission_requests pr

      INNER JOIN employees e
        ON e.id = pr.employee_id
        AND e.deleted_at IS NULL

      WHERE ${whereClause}
    `;

    const [countRows] =
      await db.query(
        countSql,
        values
      );

    const total = Number(
      countRows[0]?.total || 0
    );

    const listSql = `
      SELECT

        pr.id,

        pr.company_id,

        pr.branch_id,

        pr.employee_id,

        pr.request_type,

        pr.request_title,

        pr.reason,

        pr.request_date,

        pr.start_date,

        pr.end_date,

        pr.requested_time,

        pr.actual_time,

        pr.total_days,

        pr.status,

        pr.employee_remarks,

        pr.admin_remarks,

        pr.reviewed_by,

        pr.reviewed_at,

        pr.created_at,

        pr.updated_at,

        e.employee_code,

        e.full_name
          AS employee_name,

        e.role_name
          AS employee_role,

        e.profile_image_url,

        d.name
          AS department_name,

        des.name
          AS designation_name,

        reviewer.full_name
          AS reviewed_by_name

      FROM permission_requests pr

      INNER JOIN employees e
        ON e.id = pr.employee_id
        AND e.deleted_at IS NULL

      LEFT JOIN departments d
        ON d.id = e.department_id

      LEFT JOIN designations des
        ON des.id = e.designation_id

      LEFT JOIN employees reviewer
        ON reviewer.id = pr.reviewed_by

      WHERE ${whereClause}

      ORDER BY

        CASE

          WHEN pr.status = 'pending'
            THEN 0

          ELSE 1

        END,

        pr.created_at DESC,

        pr.id DESC

      LIMIT ?

      OFFSET ?
    `;

    const [rows] =
      await db.query(
        listSql,
        [
          ...values,

          pagination.limit,

          pagination.offset,
        ]
      );

    return {
      data: rows,

      pagination: {
        page:
          pagination.page,

        limit:
          pagination.limit,

        total,

        totalPages:
          Math.max(
            Math.ceil(
              total /
                pagination.limit
            ),
            1
          ),
      },
    };
  }

  // ===========================================================================
  // ADMIN - GET PERMISSION SUMMARY
  // ===========================================================================

  static async getPermissionSummary({
    companyId,
    branchId,
  }) {
    const conditions = [
      'pr.deleted_at IS NULL',
    ];

    const values = [];

    if (companyId) {
      conditions.push(
        'pr.company_id = ?'
      );

      values.push(companyId);
    }

    if (branchId) {
      conditions.push(
        'pr.branch_id = ?'
      );

      values.push(branchId);
    }

    const sql = `
      SELECT

        COUNT(*)
          AS total_requests,

        COALESCE(
          SUM(
            pr.status = 'pending'
          ),
          0
        )
          AS pending_requests,

        COALESCE(
          SUM(
            pr.request_type =
              'late_login'

            AND

            pr.status =
              'pending'
          ),
          0
        )
          AS pending_late_logins,

        COALESCE(
          SUM(
            pr.request_type =
              'leave_request'

            AND

            pr.status =
              'pending'
          ),
          0
        )
          AS pending_leave_requests,

        COALESCE(
          SUM(
            pr.request_type =
              'early_logout'

            AND

            pr.status =
              'pending'
          ),
          0
        )
          AS pending_early_logout_requests,

        COALESCE(
          SUM(
            pr.status =
              'approved'
          ),
          0
        )
          AS approved_requests,

        COALESCE(
          SUM(
            pr.status =
              'rejected'
          ),
          0
        )
          AS rejected_requests,

        COALESCE(
          SUM(
            pr.status =
              'cancelled'
          ),
          0
        )
          AS cancelled_requests

      FROM permission_requests pr

      WHERE
        ${conditions.join(
          ' AND '
        )}
    `;

    const [rows] =
      await db.query(
        sql,
        values
      );

    const summary =
      rows[0] || {};

    return {
      totalRequests:
        Number(
          summary.total_requests ||
            0
        ),

      pendingRequests:
        Number(
          summary.pending_requests ||
            0
        ),

      pendingLateLogins:
        Number(
          summary.pending_late_logins ||
            0
        ),

      pendingLeaveRequests:
        Number(
          summary.pending_leave_requests ||
            0
        ),

      pendingEarlyLogoutRequests:
        Number(
          summary
            .pending_early_logout_requests ||
            0
        ),

      approvedRequests:
        Number(
          summary.approved_requests ||
            0
        ),

      rejectedRequests:
        Number(
          summary.rejected_requests ||
            0
        ),

      cancelledRequests:
        Number(
          summary.cancelled_requests ||
            0
        ),
    };
  }

  // ===========================================================================
  // GET SINGLE PERMISSION
  // ===========================================================================

  static async getPermissionById(
    permissionId,
    companyId
  ) {
    const conditions = [
      'pr.id = ?',
      'pr.deleted_at IS NULL',
    ];

    const values = [
      permissionId,
    ];

    if (companyId) {
      conditions.push(
        'pr.company_id = ?'
      );

      values.push(
        companyId
      );
    }

    const sql = `
      SELECT

        pr.id,

        pr.company_id,

        pr.branch_id,

        pr.employee_id,

        pr.request_type,

        pr.request_title,

        pr.reason,

        pr.request_date,

        pr.start_date,

        pr.end_date,

        pr.requested_time,

        pr.actual_time,

        pr.total_days,

        pr.status,

        pr.employee_remarks,

        pr.admin_remarks,

        pr.reviewed_by,

        pr.reviewed_at,

        pr.created_at,

        pr.updated_at,

        e.employee_code,

        e.full_name
          AS employee_name,

        e.role_name
          AS employee_role,

        e.profile_image_url,

        d.name
          AS department_name,

        des.name
          AS designation_name,

        reviewer.full_name
          AS reviewed_by_name

      FROM permission_requests pr

      INNER JOIN employees e
        ON e.id = pr.employee_id
        AND e.deleted_at IS NULL

      LEFT JOIN departments d
        ON d.id = e.department_id

      LEFT JOIN designations des
        ON des.id = e.designation_id

      LEFT JOIN employees reviewer
        ON reviewer.id =
          pr.reviewed_by

      WHERE
        ${conditions.join(
          ' AND '
        )}

      LIMIT 1
    `;

    const [rows] =
      await db.query(
        sql,
        values
      );

    return (
      rows[0] ||
      null
    );
  }

  // ===========================================================================
  // EMPLOYEE - CREATE PERMISSION REQUEST
  // ===========================================================================

  static async createPermissionRequest({
    employeeId,
    companyId = null,
    branchId = null,
    requestType,
    requestDate,
    requestedTime,
    reason,
  }) {
    const parsedEmployeeId =
      Number.parseInt(
        employeeId,
        10
      );

    if (
      !Number.isInteger(
        parsedEmployeeId
      ) ||
      parsedEmployeeId <= 0
    ) {
      const error =
        new Error(
          'A valid employee ID is required.'
        );

      error.statusCode = 400;

      error.code =
        'INVALID_EMPLOYEE_ID';

      throw error;
    }

    // -------------------------------------------------------------------------
    // Permission Type
    // -------------------------------------------------------------------------

    const normalizedType =
      String(
        requestType || ''
      )
        .trim()
        .toLowerCase()
        .replaceAll(
          '-',
          '_'
        )
        .replaceAll(
          ' ',
          '_'
        );

    if (
      ![
        'late_login',
        'early_logout',
      ].includes(
        normalizedType
      )
    ) {
      const error =
        new Error(
          'Permission type must be late_login or early_logout.'
        );

      error.statusCode = 400;

      error.code =
        'INVALID_PERMISSION_TYPE';

      throw error;
    }

    // -------------------------------------------------------------------------
    // Request Date
    // -------------------------------------------------------------------------

    const normalizedDate =
      String(
        requestDate || ''
      ).trim();

    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(
        normalizedDate
      )
    ) {
      const error =
        new Error(
          'Request date must be in YYYY-MM-DD format.'
        );

      error.statusCode = 400;

      error.code =
        'INVALID_REQUEST_DATE';

      throw error;
    }

    const dateParts =
      normalizedDate
        .split('-')
        .map(
          (value) =>
            Number(value)
        );

    const parsedDate =
      new Date(
        Date.UTC(
          dateParts[0],
          dateParts[1] - 1,
          dateParts[2]
        )
      );

    if (
      parsedDate
        .getUTCFullYear() !==
        dateParts[0] ||

      parsedDate
        .getUTCMonth() !==
        dateParts[1] - 1 ||

      parsedDate
        .getUTCDate() !==
        dateParts[2]
    ) {
      const error =
        new Error(
          'Request date is invalid.'
        );

      error.statusCode = 400;

      error.code =
        'INVALID_REQUEST_DATE';

      throw error;
    }

    // -------------------------------------------------------------------------
    // Requested Time
    // -------------------------------------------------------------------------

    const normalizedTime =
      String(
        requestedTime || ''
      ).trim();

    const timeMatch =
      /^([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?$/.exec(
        normalizedTime
      );

    if (!timeMatch) {
      const error =
        new Error(
          'Requested time must be in HH:mm or HH:mm:ss format.'
        );

      error.statusCode = 400;

      error.code =
        'INVALID_REQUESTED_TIME';

      throw error;
    }

    const finalRequestedTime =
      `${timeMatch[1]}:${timeMatch[2]}:${timeMatch[3] || '00'}`;

    // -------------------------------------------------------------------------
    // Reason
    // -------------------------------------------------------------------------

    const normalizedReason =
      String(
        reason || ''
      ).trim();

    if (
      normalizedReason.length <
      3
    ) {
      const error =
        new Error(
          'Reason must contain at least 3 characters.'
        );

      error.statusCode = 400;

      error.code =
        'INVALID_REASON';

      throw error;
    }

    if (
      normalizedReason.length >
      500
    ) {
      const error =
        new Error(
          'Reason must not exceed 500 characters.'
        );

      error.statusCode = 400;

      error.code =
        'INVALID_REASON';

      throw error;
    }

    // -------------------------------------------------------------------------
    // Request Title
    // -------------------------------------------------------------------------

    const requestTitle =
      normalizedType ===
      'late_login'
        ? 'Late Login Permission'
        : 'Early Logout Permission';

    // -------------------------------------------------------------------------
    // Start Transaction
    // -------------------------------------------------------------------------

    const connection =
      await db.getConnection();

    let committed = false;

    try {
      await connection
        .beginTransaction();

      // -----------------------------------------------------------------------
      // Get Employee
      // -----------------------------------------------------------------------

      const [employeeRows] =
        await connection.query(
          `
            SELECT

              id,

              company_id,

              branch_id,

              employee_code,

              full_name

            FROM employees

            WHERE
              id = ?

              AND

              deleted_at IS NULL

            LIMIT 1

            FOR UPDATE
          `,
          [
            parsedEmployeeId,
          ]
        );

      if (
        employeeRows.length === 0
      ) {
        const error =
          new Error(
            'Employee not found.'
          );

        error.statusCode = 404;

        error.code =
          'EMPLOYEE_NOT_FOUND';

        throw error;
      }

      const employee =
        employeeRows[0];

      // -----------------------------------------------------------------------
      // Company Validation
      // -----------------------------------------------------------------------

      if (
        companyId != null &&
        Number(companyId) !==
          Number(
            employee.company_id
          )
      ) {
        const error =
          new Error(
            'Employee does not belong to this company.'
          );

        error.statusCode = 403;

        error.code =
          'COMPANY_MISMATCH';

        throw error;
      }

      // -----------------------------------------------------------------------
      // Branch Validation
      // -----------------------------------------------------------------------

      if (
        branchId != null &&
        employee.branch_id != null &&
        Number(branchId) !==
          Number(
            employee.branch_id
          )
      ) {
        const error =
          new Error(
            'Employee does not belong to this branch.'
          );

        error.statusCode = 403;

        error.code =
          'BRANCH_MISMATCH';

        throw error;
      }

      // -----------------------------------------------------------------------
      // Prevent Duplicate Request
      // -----------------------------------------------------------------------

      const [existingRows] =
        await connection.query(
          `
            SELECT

              id,

              status

            FROM
              permission_requests

            WHERE

              employee_id = ?

              AND

              request_type = ?

              AND

              request_date = ?

              AND

              status IN (
                'pending',
                'approved'
              )

              AND

              deleted_at IS NULL

            LIMIT 1

            FOR UPDATE
          `,
          [
            parsedEmployeeId,

            normalizedType,

            normalizedDate,
          ]
        );

      if (
        existingRows.length > 0
      ) {
        const existing =
          existingRows[0];

        const error =
          new Error(
            `A ${normalizedType.replaceAll(
              '_',
              ' '
            )} request is already ${existing.status} for this date.`
          );

        error.statusCode = 409;

        error.code =
          'PERMISSION_REQUEST_EXISTS';

        throw error;
      }

      // -----------------------------------------------------------------------
      // Insert Permission Request
      // -----------------------------------------------------------------------

      const [insertResult] =
        await connection.query(
          `
            INSERT INTO
              permission_requests
            (
              company_id,

              branch_id,

              employee_id,

              request_type,

              request_title,

              reason,

              request_date,

              requested_time,

              status,

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

              'pending',

              CURRENT_TIMESTAMP,

              CURRENT_TIMESTAMP
            )
          `,
          [
            employee.company_id,

            employee.branch_id ??
              null,

            parsedEmployeeId,

            normalizedType,

            requestTitle,

            normalizedReason,

            normalizedDate,

            finalRequestedTime,
          ]
        );

      // -----------------------------------------------------------------------
      // Commit Permission Request
      // -----------------------------------------------------------------------

      await connection.commit();

      committed = true;

      // -----------------------------------------------------------------------
      // CREATE ADMIN NOTIFICATION
      // -----------------------------------------------------------------------

      try {
        const permissionTypeLabel =
          normalizedType ===
          'late_login'
            ? 'Late Login'
            : 'Early Logout';

        await adminNotificationService
          .createNotification({
            companyId:
              employee.company_id,

            branchId:
              employee.branch_id ??
              null,

            employeeId:
              parsedEmployeeId,

            title:
              'New Permission Request',

            message:
              `${employee.full_name} requested ` +
              `${permissionTypeLabel} permission ` +
              `for ${normalizedDate} at ` +
              `${finalRequestedTime}. ` +
              `Reason: ${normalizedReason}`,

            notificationType:
              'permission_request',

            referenceType:
              'permission_request',

            referenceId:
              insertResult.insertId,

            externalKey:
              `permission_request_${insertResult.insertId}_submitted`,
          });
      } catch (
        notificationError
      ) {
        console.error(
          'Admin permission notification error:',
          notificationError
        );
      }

      // -----------------------------------------------------------------------
      // Return Newly Created Permission
      // -----------------------------------------------------------------------

      return await this
        .getPermissionById(
          insertResult.insertId,
          employee.company_id
        );
    } catch (error) {
      if (!committed) {
        await connection
          .rollback();
      }

      throw error;
    } finally {
      connection.release();
    }
  }

  // ===========================================================================
  // ADMIN - UPDATE PERMISSION STATUS
  // ===========================================================================

  static async updatePermissionStatus({
    permissionId,
    companyId,
    status,
    adminRemarks,
    reviewedBy,
  }) {
    const normalizedStatus =
      String(
        status || ''
      )
        .trim()
        .toLowerCase();

    if (
      ![
        'approved',
        'rejected',
      ].includes(
        normalizedStatus
      )
    ) {
      const error =
        new Error(
          'Status must be either approved or rejected.'
        );

      error.statusCode = 400;

      throw error;
    }

    const connection =
      await db.getConnection();

    let committed = false;

    try {
      await connection
        .beginTransaction();

      const conditions = [
        'id = ?',

        'deleted_at IS NULL',
      ];

      const values = [
        permissionId,
      ];

      if (companyId) {
        conditions.push(
          'company_id = ?'
        );

        values.push(
          companyId
        );
      }

      const [permissionRows] =
        await connection.query(
          `
            SELECT

              id,

              company_id,

              branch_id,

              employee_id,

              request_type,

              request_title,

              reason,

              request_date,

              requested_time,

              status

            FROM
              permission_requests

            WHERE
              ${conditions.join(
                ' AND '
              )}

            LIMIT 1

            FOR UPDATE
          `,
          values
        );

      if (
        permissionRows.length === 0
      ) {
        const error =
          new Error(
            'Permission request not found.'
          );

        error.statusCode = 404;

        throw error;
      }

      const permission =
        permissionRows[0];

      if (
        permission.status !==
        'pending'
      ) {
        const error =
          new Error(
            `This request is already ${permission.status}.`
          );

        error.statusCode = 409;

        throw error;
      }

      // -----------------------------------------------------------------------
      // Update Permission Status
      // -----------------------------------------------------------------------

      await connection.query(
        `
          UPDATE
            permission_requests

          SET

            status = ?,

            admin_remarks = ?,

            reviewed_by = ?,

            reviewed_at = NOW(),

            updated_at =
              CURRENT_TIMESTAMP

          WHERE
            id = ?
        `,
        [
          normalizedStatus,

          adminRemarks ||
            null,

          reviewedBy ||
            null,

          permissionId,
        ]
      );

      // -----------------------------------------------------------------------
      // Apply Approved Effects
      // -----------------------------------------------------------------------

      if (
        normalizedStatus ===
        'approved'
      ) {
        await this
          .applyApprovedPermissionEffects(
            connection,
            permission
          );
      }

      await connection.commit();

      committed = true;

      // -----------------------------------------------------------------------
      // CREATE EMPLOYEE NOTIFICATION
      // -----------------------------------------------------------------------

      try {
        const isApproved =
          normalizedStatus ===
          'approved';

        const notificationTitle =
          isApproved
            ? 'Permission Approved'
            : 'Permission Rejected';

        let notificationMessage =
          isApproved
            ? `Your ${permission.request_title} has been approved.`
            : `Your ${permission.request_title} has been rejected.`;

        const cleanAdminRemarks =
          String(
            adminRemarks || ''
          ).trim();

        if (
          cleanAdminRemarks.length >
          0
        ) {
          notificationMessage +=
            ` Admin remarks: ${cleanAdminRemarks}`;
        }

        await notificationService
          .createNotification({
            employeeId:
              permission.employee_id,

            companyId:
              permission.company_id,

            title:
              notificationTitle,

            message:
              notificationMessage,

            notificationType:
              'permission',

            referenceType:
              'permission_request',

            referenceId:
              permission.id,

            externalKey:
              `permission_${permission.id}_${normalizedStatus}`,
          });
      } catch (
        notificationError
      ) {
        console.error(
          'Employee permission notification error:',
          notificationError
        );
      }

      return await this
        .getPermissionById(
          permissionId,
          companyId
        );
    } catch (error) {
      if (!committed) {
        await connection
          .rollback();
      }

      throw error;
    } finally {
      connection.release();
    }
  }

  // ===========================================================================
  // APPROVAL EFFECTS
  // ===========================================================================

  static async applyApprovedPermissionEffects(
    connection,
    permission
  ) {
    // Approved Late Login / Early Logout effects
    // can later be connected with attendance_records.

    return {
      permissionId:
        permission.id,

      requestType:
        permission.request_type,
    };
  }
}

module.exports = PermissionService;