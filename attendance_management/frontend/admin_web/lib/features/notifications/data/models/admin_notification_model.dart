class AdminNotificationModel {
  const AdminNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    this.companyId,
    this.branchId,
    this.employeeId,
    this.employeeName,
    this.employeeCode,
    this.employeeRole,
    this.profileImageUrl,
    this.referenceType,
    this.referenceId,
    this.externalKey,
    this.readAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  final int? companyId;
  final int? branchId;
  final int? employeeId;

  final String? employeeName;
  final String? employeeCode;
  final String? employeeRole;
  final String? profileImageUrl;

  final String title;
  final String message;
  final String notificationType;

  final String? referenceType;
  final int? referenceId;
  final String? externalKey;

  final bool isRead;

  final DateTime? readAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminNotificationModel.fromJson(Map<String, dynamic> json) {
    return AdminNotificationModel(
      id: _toInt(json['notification_id'] ?? json['id']),

      companyId: _toNullableInt(json['company_id']),

      branchId: _toNullableInt(json['branch_id']),

      employeeId: _toNullableInt(json['employee_id']),

      employeeName: _toNullableString(json['employee_name']),

      employeeCode: _toNullableString(json['employee_code']),

      employeeRole: _toNullableString(json['employee_role']),

      profileImageUrl: _toNullableString(json['profile_image_url']),

      title: _toString(json['title']),

      message: _toString(json['message']),

      notificationType: _toString(json['notification_type'] ?? json['type']),

      referenceType: _toNullableString(json['reference_type']),

      referenceId: _toNullableInt(json['reference_id']),

      externalKey: _toNullableString(json['external_key']),

      isRead: _toBool(json['is_read']),

      readAt: _toDateTime(json['read_at']),

      createdAt: _toDateTime(json['created_at']),

      updatedAt: _toDateTime(json['updated_at']),
    );
  }

  String get employeeDisplayName {
    final String name = employeeName?.trim() ?? '';

    return name.isEmpty ? 'System' : name;
  }

  String get typeLabel {
    switch (notificationType.trim().toLowerCase()) {
      case 'permission_request':
        return 'Permission';

      case 'leave_request':
        return 'Leave';

      case 'late_login':
        return 'Late Login';

      case 'attendance':
        return 'Attendance';

      case 'check_in':
        return 'Check In';

      case 'check_out':
        return 'Check Out';

      case 'payroll':
        return 'Payroll';

      default:
        return notificationType.replaceAll('_', ' ').trim();
    }
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

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _toNullableString(dynamic value) {
    final String text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String text = value?.toString().trim().toLowerCase() ?? '';

    return <String>['true', '1', 'yes'].contains(text);
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }
}

class AdminNotificationListResult {
  const AdminNotificationListResult({
    required this.notifications,
    required this.totalCount,
    required this.unreadCount,
  });

  final List<AdminNotificationModel> notifications;

  final int totalCount;
  final int unreadCount;
}
