class AdminPermissionModel {
  const AdminPermissionModel({
    required this.id,
    required this.companyId,
    required this.branchId,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.employeeRole,
    required this.requestType,
    required this.requestTitle,
    required this.reason,
    required this.requestDate,
    required this.status,
    this.profileImageUrl,
    this.departmentName,
    this.designationName,
    this.startDate,
    this.endDate,
    this.requestedTime,
    this.actualTime,
    this.totalDays,
    this.employeeRemarks,
    this.adminRemarks,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int companyId;
  final int? branchId;
  final int employeeId;

  final String? employeeCode;
  final String employeeName;
  final String? employeeRole;
  final String? profileImageUrl;
  final String? departmentName;
  final String? designationName;

  final String requestType;
  final String requestTitle;
  final String reason;
  final DateTime? requestDate;

  final DateTime? startDate;
  final DateTime? endDate;

  final String? requestedTime;
  final String? actualTime;

  final double? totalDays;
  final String status;

  final String? employeeRemarks;
  final String? adminRemarks;

  final int? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminPermissionModel.fromJson(Map<String, dynamic> json) {
    return AdminPermissionModel(
      id: _toInt(json['id']),
      companyId: _toInt(json['company_id']),
      branchId: _toNullableInt(json['branch_id']),
      employeeId: _toInt(json['employee_id']),

      employeeCode: _toNullableString(json['employee_code']),
      employeeName: _toString(json['employee_name']),
      employeeRole: _toNullableString(json['employee_role']),
      profileImageUrl: _toNullableString(json['profile_image_url']),
      departmentName: _toNullableString(json['department_name']),
      designationName: _toNullableString(json['designation_name']),

      requestType: _toString(json['request_type']),
      requestTitle: _toString(json['request_title']),
      reason: _toString(json['reason']),
      requestDate: _toNullableDateTime(json['request_date']),

      startDate: _toNullableDateTime(json['start_date']),
      endDate: _toNullableDateTime(json['end_date']),

      requestedTime: _toNullableString(json['requested_time']),
      actualTime: _toNullableString(json['actual_time']),

      totalDays: _toNullableDouble(json['total_days']),
      status: _toString(json['status']),

      employeeRemarks: _toNullableString(json['employee_remarks']),
      adminRemarks: _toNullableString(json['admin_remarks']),

      reviewedBy: _toNullableInt(json['reviewed_by']),
      reviewedByName: _toNullableString(json['reviewed_by_name']),
      reviewedAt: _toNullableDateTime(json['reviewed_at']),

      createdAt: _toNullableDateTime(json['created_at']),
      updatedAt: _toNullableDateTime(json['updated_at']),
    );
  }

  bool get isPending => status.toLowerCase() == 'pending';

  bool get isApproved => status.toLowerCase() == 'approved';

  bool get isRejected => status.toLowerCase() == 'rejected';

  bool get isCancelled => status.toLowerCase() == 'cancelled';

  bool get isLeaveRequest => requestType.toLowerCase() == 'leave_request';

  bool get isLateLogin => requestType.toLowerCase() == 'late_login';

  bool get isEarlyLogout => requestType.toLowerCase() == 'early_logout';

  String get requestTypeLabel {
    switch (requestType.toLowerCase()) {
      case 'leave_request':
        return 'Leave Request';

      case 'late_login':
        return 'Late Login';

      case 'early_logout':
        return 'Early Logout';

      default:
        return requestType.replaceAll('_', ' ').trim();
    }
  }

  String get statusLabel {
    if (status.isEmpty) {
      return '';
    }

    return '${status[0].toUpperCase()}'
        '${status.substring(1).toLowerCase()}';
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _toNullableString(dynamic value) {
    final String text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final String text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}

class AdminPermissionSummary {
  const AdminPermissionSummary({
    required this.totalRequests,
    required this.pendingRequests,
    required this.pendingLateLogins,
    required this.pendingLeaveRequests,
    required this.pendingEarlyLogoutRequests,
    required this.approvedRequests,
    required this.rejectedRequests,
    required this.cancelledRequests,
  });

  final int totalRequests;
  final int pendingRequests;
  final int pendingLateLogins;
  final int pendingLeaveRequests;
  final int pendingEarlyLogoutRequests;
  final int approvedRequests;
  final int rejectedRequests;
  final int cancelledRequests;

  factory AdminPermissionSummary.empty() {
    return const AdminPermissionSummary(
      totalRequests: 0,
      pendingRequests: 0,
      pendingLateLogins: 0,
      pendingLeaveRequests: 0,
      pendingEarlyLogoutRequests: 0,
      approvedRequests: 0,
      rejectedRequests: 0,
      cancelledRequests: 0,
    );
  }

  factory AdminPermissionSummary.fromJson(Map<String, dynamic> json) {
    return AdminPermissionSummary(
      totalRequests: _toInt(json['totalRequests']),
      pendingRequests: _toInt(json['pendingRequests']),
      pendingLateLogins: _toInt(json['pendingLateLogins']),
      pendingLeaveRequests: _toInt(json['pendingLeaveRequests']),
      pendingEarlyLogoutRequests: _toInt(json['pendingEarlyLogoutRequests']),
      approvedRequests: _toInt(json['approvedRequests']),
      rejectedRequests: _toInt(json['rejectedRequests']),
      cancelledRequests: _toInt(json['cancelledRequests']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AdminPermissionPagination {
  const AdminPermissionPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory AdminPermissionPagination.empty() {
    return const AdminPermissionPagination(
      page: 1,
      limit: 5,
      total: 0,
      totalPages: 1,
    );
  }

  factory AdminPermissionPagination.fromJson(Map<String, dynamic> json) {
    return AdminPermissionPagination(
      page: _toInt(json['page'], fallback: 1),
      limit: _toInt(json['limit'], fallback: 5),
      total: _toInt(json['total']),
      totalPages: _toInt(json['totalPages'], fallback: 1),
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class AdminPermissionListResult {
  const AdminPermissionListResult({
    required this.permissions,
    required this.pagination,
  });

  final List<AdminPermissionModel> permissions;
  final AdminPermissionPagination pagination;
}
