const PermissionService = require('../services/permission.service');

class PermissionController {
  // ---------------------------------------------------------------------------
  // Authentication helpers
  // ---------------------------------------------------------------------------

  static getAuthenticatedCompanyId(req) {
    return (
      req.auth?.companyId ||
      req.auth?.company_id ||
      req.user?.companyId ||
      req.user?.company_id ||
      req.admin?.companyId ||
      req.admin?.company_id ||
      null
    );
  }

  static getAuthenticatedBranchId(req) {
    return (
      req.auth?.branchId ||
      req.auth?.branch_id ||
      req.user?.branchId ||
      req.user?.branch_id ||
      req.admin?.branchId ||
      req.admin?.branch_id ||
      null
    );
  }

  static getAuthenticatedEmployeeId(req) {
    return (
      req.auth?.employeeId ||
      req.auth?.employee_id ||
      req.user?.employeeId ||
      req.user?.employee_id ||
      req.user?.id ||
      null
    );
  }

  static getAuthenticatedReviewerId(req) {
    return (
      req.auth?.employeeId ||
      req.auth?.employee_id ||
      req.auth?.userId ||
      req.auth?.user_id ||
      req.user?.employeeId ||
      req.user?.employee_id ||
      req.user?.id ||
      req.admin?.employeeId ||
      req.admin?.employee_id ||
      req.admin?.id ||
      null
    );
  }

  // ---------------------------------------------------------------------------
  // EMPLOYEE - CREATE PERMISSION REQUEST
  // ---------------------------------------------------------------------------

  static async createPermissionRequest(req, res, next) {
    try {
      const employeeId =
        PermissionController.getAuthenticatedEmployeeId(req);

      if (!employeeId) {
        return res.status(401).json({
          success: false,
          code: 'EMPLOYEE_REQUIRED',
          message:
            'Employee information is missing from the login token.',
        });
      }

      const companyId =
        PermissionController.getAuthenticatedCompanyId(req);

      const branchId =
        PermissionController.getAuthenticatedBranchId(req);

      const requestType = String(
        req.body.requestType ||
          req.body.request_type ||
          req.body.type ||
          ''
      )
        .trim()
        .toLowerCase();

      const requestDate = String(
        req.body.requestDate ||
          req.body.request_date ||
          req.body.date ||
          ''
      ).trim();

      const requestedTime = String(
        req.body.requestedTime ||
          req.body.requested_time ||
          req.body.time ||
          ''
      ).trim();

      const reason = String(
        req.body.reason ||
          req.body.employeeRemarks ||
          req.body.employee_remarks ||
          ''
      ).trim();

      if (!requestType) {
        return res.status(400).json({
          success: false,
          code: 'REQUEST_TYPE_REQUIRED',
          message: 'Permission type is required.',
        });
      }

      if (
        ![
          'late_login',
          'early_logout',
        ].includes(requestType)
      ) {
        return res.status(400).json({
          success: false,
          code: 'INVALID_PERMISSION_TYPE',
          message:
            'Permission type must be late_login or early_logout.',
        });
      }

      if (!requestDate) {
        return res.status(400).json({
          success: false,
          code: 'REQUEST_DATE_REQUIRED',
          message: 'Request date is required.',
        });
      }

      if (!requestedTime) {
        return res.status(400).json({
          success: false,
          code: 'REQUESTED_TIME_REQUIRED',
          message: 'Requested time is required.',
        });
      }

      if (!reason) {
        return res.status(400).json({
          success: false,
          code: 'REASON_REQUIRED',
          message: 'Reason is required.',
        });
      }

      const permission =
        await PermissionService.createPermissionRequest({
          employeeId,
          companyId,
          branchId,
          requestType,
          requestDate,
          requestedTime,
          reason,
        });

      return res.status(201).json({
        success: true,
        message:
          'Permission request submitted successfully.',
        data: permission,
      });
    } catch (error) {
      return next(error);
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN - GET PERMISSION REQUESTS
  // ---------------------------------------------------------------------------

  static async getPermissionRequests(req, res, next) {
    try {
      const companyId =
        PermissionController.getAuthenticatedCompanyId(req);

      const branchId =
        req.query.branchId ||
        req.query.branch_id ||
        PermissionController.getAuthenticatedBranchId(req);

      const result =
        await PermissionService.getPermissionRequests({
          companyId,
          branchId,
          page: req.query.page,
          limit: req.query.limit,
          search: req.query.search || '',
          type:
            req.query.type ||
            req.query.requestType ||
            req.query.request_type ||
            '',
          status:
            req.query.status || 'pending',
        });

      return res.status(200).json({
        success: true,
        message:
          'Permission requests fetched successfully.',
        data: result.data,
        pagination: result.pagination,
      });
    } catch (error) {
      return next(error);
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN - PERMISSION SUMMARY
  // ---------------------------------------------------------------------------

  static async getPermissionSummary(req, res, next) {
    try {
      const companyId =
        PermissionController.getAuthenticatedCompanyId(req);

      const branchId =
        req.query.branchId ||
        req.query.branch_id ||
        PermissionController.getAuthenticatedBranchId(req);

      const summary =
        await PermissionService.getPermissionSummary({
          companyId,
          branchId,
        });

      return res.status(200).json({
        success: true,
        message:
          'Permission summary fetched successfully.',
        data: summary,
      });
    } catch (error) {
      return next(error);
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN - GET SINGLE PERMISSION
  // ---------------------------------------------------------------------------

  static async getPermissionById(req, res, next) {
    try {
      const permissionId =
        Number.parseInt(
          req.params.permissionId ||
            req.params.id,
          10
        );

      if (
        !Number.isInteger(permissionId) ||
        permissionId <= 0
      ) {
        return res.status(400).json({
          success: false,
          message:
            'A valid permission ID is required.',
        });
      }

      const companyId =
        PermissionController.getAuthenticatedCompanyId(req);

      const permission =
        await PermissionService.getPermissionById(
          permissionId,
          companyId
        );

      if (!permission) {
        return res.status(404).json({
          success: false,
          message:
            'Permission request not found.',
        });
      }

      return res.status(200).json({
        success: true,
        message:
          'Permission request fetched successfully.',
        data: permission,
      });
    } catch (error) {
      return next(error);
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN - UPDATE STATUS
  // ---------------------------------------------------------------------------

  static async updatePermissionStatus(
    req,
    res,
    next
  ) {
    try {
      const permissionId =
        Number.parseInt(
          req.params.permissionId ||
            req.params.id,
          10
        );

      if (
        !Number.isInteger(permissionId) ||
        permissionId <= 0
      ) {
        return res.status(400).json({
          success: false,
          message:
            'A valid permission ID is required.',
        });
      }

      const status = String(
        req.body.status || ''
      )
        .trim()
        .toLowerCase();

      const adminRemarks = String(
        req.body.adminRemarks ||
          req.body.admin_remarks ||
          req.body.remarks ||
          ''
      ).trim();

      if (
        ![
          'approved',
          'rejected',
        ].includes(status)
      ) {
        return res.status(400).json({
          success: false,
          message:
            'Status must be either approved or rejected.',
        });
      }

      if (
        status === 'rejected' &&
        !adminRemarks
      ) {
        return res.status(400).json({
          success: false,
          message:
            'Admin remarks are required when rejecting a request.',
        });
      }

      const companyId =
        PermissionController.getAuthenticatedCompanyId(req);

      const reviewedBy =
        PermissionController.getAuthenticatedReviewerId(req);

      const updatedPermission =
        await PermissionService.updatePermissionStatus({
          permissionId,
          companyId,
          status,
          adminRemarks,
          reviewedBy,
        });

      return res.status(200).json({
        success: true,
        message:
          status === 'approved'
            ? 'Permission request approved successfully.'
            : 'Permission request rejected successfully.',
        data: updatedPermission,
      });
    } catch (error) {
      return next(error);
    }
  }

  // ---------------------------------------------------------------------------
  // ADMIN - APPROVE
  // ---------------------------------------------------------------------------

  static async approvePermission(req, res, next) {
    req.body = {
      ...req.body,
      status: 'approved',
    };

    return PermissionController.updatePermissionStatus(
      req,
      res,
      next
    );
  }

  // ---------------------------------------------------------------------------
  // ADMIN - REJECT
  // ---------------------------------------------------------------------------

  static async rejectPermission(req, res, next) {
    req.body = {
      ...req.body,
      status: 'rejected',
    };

    return PermissionController.updatePermissionStatus(
      req,
      res,
      next
    );
  }
}

module.exports = PermissionController;