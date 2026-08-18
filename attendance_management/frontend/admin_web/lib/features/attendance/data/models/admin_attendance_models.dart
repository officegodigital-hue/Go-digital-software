class AdminAttendanceRecord {
  const AdminAttendanceRecord({
    required this.attendanceId,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.roleName,
    required this.email,
    required this.profileImageUrl,
    required this.attendanceDate,
    required this.checkInAt,
    required this.checkOutAt,
    required this.workingMinutes,
    required this.breakMinutes,
    required this.scheduledMinutes,
    required this.extraHoursMinutes,
    required this.overtimeMinutes,
    required this.attendanceStatus,
    required this.sessionStatus,
    required this.shiftId,
    required this.shiftName,
    required this.shiftStartTime,
    required this.shiftEndTime,
  });

  final int attendanceId;
  final int employeeId;

  final String employeeCode;
  final String employeeName;
  final String roleName;
  final String email;
  final String? profileImageUrl;

  final DateTime? attendanceDate;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;

  final int workingMinutes;
  final int breakMinutes;
  final int scheduledMinutes;
  final int extraHoursMinutes;
  final int overtimeMinutes;

  final String attendanceStatus;
  final String sessionStatus;

  final int? shiftId;
  final String shiftName;
  final String? shiftStartTime;
  final String? shiftEndTime;

  factory AdminAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AdminAttendanceRecord(
      attendanceId: _readInt(json, const <String>[
        'attendance_id',
        'attendanceId',
        'id',
      ]),
      employeeId: _readInt(json, const <String>['employee_id', 'employeeId']),
      employeeCode: _readString(json, const <String>[
        'employee_code',
        'employeeCode',
      ]),
      employeeName: _readString(json, const <String>[
        'employee_name',
        'employeeName',
        'full_name',
        'fullName',
        'name',
      ], fallback: 'Employee'),
      roleName: _readString(json, const <String>[
        'role_name',
        'roleName',
        'employee_role',
        'employeeRole',
      ], fallback: 'Employee'),
      email: _readString(json, const <String>['email']),
     profileImageUrl: _readNullableString(json, const <String>[
  'profile_image_url',
  'profileImageUrl',
]),
      attendanceDate: _readDateOnly(json, const <String>[
        'attendance_date',
        'attendanceDate',
        'date',
      ]),
      checkInAt: _readDateTime(json, const <String>[
        'check_in_at',
        'checkInAt',
        'login_time',
        'loginTime',
      ]),
      checkOutAt: _readDateTime(json, const <String>[
        'check_out_at',
        'checkOutAt',
        'logout_time',
        'logoutTime',
      ]),
      workingMinutes: _readInt(json, const <String>[
        'working_minutes',
        'workingMinutes',
        'work_minutes',
        'workMinutes',
      ]),
      breakMinutes: _readInt(json, const <String>[
        'break_minutes',
        'breakMinutes',
      ]),
      scheduledMinutes: _readInt(json, const <String>[
        'scheduled_minutes',
        'scheduledMinutes',
      ]),
      extraHoursMinutes: _readInt(json, const <String>[
        'extra_hours_minutes',
        'extraHoursMinutes',
        'extra_minutes',
        'extraMinutes',
      ]),
      overtimeMinutes: _readInt(json, const <String>[
        'overtime_minutes',
        'overtimeMinutes',
      ]),
      attendanceStatus: _readString(json, const <String>[
        'attendance_status',
        'attendanceStatus',
        'status',
      ], fallback: 'unknown').toLowerCase(),
      sessionStatus: _readString(json, const <String>[
        'session_status',
        'sessionStatus',
      ], fallback: 'unknown').toLowerCase(),
      shiftId: _readNullableInt(json, const <String>['shift_id', 'shiftId']),
      shiftName: _readString(json, const <String>['shift_name', 'shiftName']),
      shiftStartTime: _readNullableString(json, const <String>[
        'shift_start_time',
        'shiftStartTime',
      ]),
      shiftEndTime: _readNullableString(json, const <String>[
        'shift_end_time',
        'shiftEndTime',
      ]),
    );
  }

  DateTime? get localCheckInAt {
    return checkInAt?.toLocal();
  }

  DateTime? get localCheckOutAt {
    return checkOutAt?.toLocal();
  }

  bool get isPresent {
    return attendanceStatus == 'present';
  }

  bool get isLate {
    return attendanceStatus == 'late';
  }

  bool get isAbsent {
    return attendanceStatus == 'absent';
  }

  bool get isActiveSession {
    return sessionStatus == 'active';
  }

  bool get isCompletedSession {
    return sessionStatus == 'completed';
  }

  String get workingTimeLabel {
    return formatMinutes(workingMinutes);
  }

  String get breakTimeLabel {
    return formatMinutes(breakMinutes);
  }

  String get extraHoursLabel {
    return formatMinutes(extraHoursMinutes);
  }

  String get overtimeLabel {
    return formatMinutes(overtimeMinutes);
  }

  static String formatMinutes(int value) {
    final int safeMinutes = value < 0 ? 0 : value;
    final int hours = safeMinutes ~/ 60;
    final int minutes = safeMinutes % 60;

    if (hours == 0) {
      return '${minutes}m';
    }

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }
}

class AdminAttendanceSummary {
  const AdminAttendanceSummary({
    required this.totalRecords,
    required this.presentRecords,
    required this.lateRecords,
    required this.absentRecords,
    required this.activeSessions,
    required this.completedSessions,
  });

  final int totalRecords;
  final int presentRecords;
  final int lateRecords;
  final int absentRecords;
  final int activeSessions;
  final int completedSessions;

  factory AdminAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AdminAttendanceSummary(
      totalRecords: _readInt(json, const <String>[
        'total_records',
        'totalRecords',
      ]),
      presentRecords: _readInt(json, const <String>[
        'present_records',
        'presentRecords',
      ]),
      lateRecords: _readInt(json, const <String>[
        'late_records',
        'lateRecords',
      ]),
      absentRecords: _readInt(json, const <String>[
        'absent_records',
        'absentRecords',
      ]),
      activeSessions: _readInt(json, const <String>[
        'active_sessions',
        'activeSessions',
      ]),
      completedSessions: _readInt(json, const <String>[
        'completed_sessions',
        'completedSessions',
      ]),
    );
  }

  static const AdminAttendanceSummary empty = AdminAttendanceSummary(
    totalRecords: 0,
    presentRecords: 0,
    lateRecords: 0,
    absentRecords: 0,
    activeSessions: 0,
    completedSessions: 0,
  );
}

class AdminAttendancePagination {
  const AdminAttendancePagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory AdminAttendancePagination.fromJson(Map<String, dynamic> json) {
    final int currentPage = _readInt(json, const <String>[
      'current_page',
      'currentPage',
      'page',
    ], fallback: 1);

    final int totalPages = _readInt(json, const <String>[
      'total_pages',
      'totalPages',
    ], fallback: 1);

    return AdminAttendancePagination(
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalItems: _readInt(json, const <String>['total_items', 'totalItems']),
      pageSize: _readInt(json, const <String>[
        'page_size',
        'pageSize',
        'limit',
      ], fallback: 20),
      hasPreviousPage: _readBool(json, const <String>[
        'has_previous_page',
        'hasPreviousPage',
      ], fallback: currentPage > 1),
      hasNextPage: _readBool(json, const <String>[
        'has_next_page',
        'hasNextPage',
      ], fallback: currentPage < totalPages),
    );
  }

  static const AdminAttendancePagination empty = AdminAttendancePagination(
    currentPage: 1,
    totalPages: 1,
    totalItems: 0,
    pageSize: 20,
    hasPreviousPage: false,
    hasNextPage: false,
  );
}

class AdminAttendancePage {
  const AdminAttendancePage({
    required this.records,
    required this.summary,
    required this.pagination,
  });

  final List<AdminAttendanceRecord> records;
  final AdminAttendanceSummary summary;
  final AdminAttendancePagination pagination;

  factory AdminAttendancePage.fromJson(Map<String, dynamic> json) {
    final dynamic rawRecords =
        json['records'] ??
        json['attendance_records'] ??
        json['attendanceRecords'];

    final List<AdminAttendanceRecord> records = rawRecords is List
        ? rawRecords
              .whereType<Map>()
              .map(
                (Map item) => AdminAttendanceRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <AdminAttendanceRecord>[];

    final Map<String, dynamic> summaryJson = _readMap(json, const <String>[
      'summary',
    ]);

    final Map<String, dynamic> paginationJson = _readMap(json, const <String>[
      'pagination',
    ]);

    return AdminAttendancePage(
      records: records,
      summary: summaryJson.isEmpty
          ? AdminAttendanceSummary.empty
          : AdminAttendanceSummary.fromJson(summaryJson),
      pagination: paginationJson.isEmpty
          ? AdminAttendancePagination.empty
          : AdminAttendancePagination.fromJson(paginationJson),
    );
  }

  static const AdminAttendancePage empty = AdminAttendancePage(
    records: <AdminAttendanceRecord>[],
    summary: AdminAttendanceSummary.empty,
    pagination: AdminAttendancePagination.empty,
  );
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    final String normalized = value.toString().trim();

    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return fallback;
}

String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
  final String value = _readString(json, keys);

  return value.isEmpty ? null : value;
}

int _readInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value != null) {
      final int? parsed = int.tryParse(value.toString());

      if (parsed != null) {
        return parsed;
      }
    }
  }

  return fallback;
}

int? _readNullableInt(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final int? parsed = int.tryParse(value.toString());

    if (parsed != null) {
      return parsed;
    }
  }

  return null;
}

bool _readBool(
  Map<String, dynamic> json,
  List<String> keys, {
  bool fallback = false,
}) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value != null) {
      final String normalized = value.toString().trim().toLowerCase();

      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }

      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
  }

  return fallback;
}

DateTime? _readDateOnly(Map<String, dynamic> json, List<String> keys) {
  final String? value = _readNullableString(json, keys);

  if (value == null) {
    return null;
  }

  final RegExpMatch? match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})',
  ).firstMatch(value);

  if (match == null) {
    return DateTime.tryParse(value);
  }

  final int? year = int.tryParse(match.group(1)!);
  final int? month = int.tryParse(match.group(2)!);
  final int? day = int.tryParse(match.group(3)!);

  if (year == null || month == null || day == null) {
    return null;
  }

  return DateTime(year, month, day);
}

DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
  final String? value = _readNullableString(json, keys);

  if (value == null) {
    return null;
  }

  return DateTime.tryParse(value);
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
  }

  return <String, dynamic>{};
}
