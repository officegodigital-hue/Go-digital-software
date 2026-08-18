class TodayAttendanceResponse {
  const TodayAttendanceResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final TodayAttendanceData data;

  factory TodayAttendanceResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final dataJson =
        _asMap(json['data']) ?? json;

    return TodayAttendanceResponse(
      success: _readBool(
            json,
            <String>[
              'success',
              'status',
            ],
          ) ??
          true,
      message: _readString(
            json,
            <String>[
              'message',
              'msg',
            ],
          ) ??
          '',
      data: TodayAttendanceData.fromJson(
        dataJson,
      ),
    );
  }

  factory TodayAttendanceResponse.empty({
    String message = '',
  }) {
    return TodayAttendanceResponse(
      success: true,
      message: message,
      data: TodayAttendanceData.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'success': success,
      'message': message,
      'data': data.toJson(),
    };
  }
}

class TodayAttendanceData {
  const TodayAttendanceData({
    required this.employee,
    required this.shift,
    required this.attendance,
    required this.currentBreak,
    required this.summary,
    required this.canCheckIn,
    required this.canStartBreak,
    required this.canEndBreak,
    required this.canCheckOut,
  });

  final TodayEmployee? employee;
  final TodayShift? shift;
  final TodayAttendanceRecord? attendance;
  final TodayBreakRecord? currentBreak;
  final TodayAttendanceSummary summary;

  final bool canCheckIn;
  final bool canStartBreak;
  final bool canEndBreak;
  final bool canCheckOut;

  bool get hasCheckedIn {
    return attendance?.hasCheckedIn ?? false;
  }

  bool get hasCheckedOut {
    return attendance?.hasCheckedOut ?? false;
  }

  bool get isOnBreak {
    if (currentBreak?.isActive == true) {
      return true;
    }

    return attendance?.isOnBreak ?? false;
  }

  String get status {
    if (hasCheckedOut) {
      return 'completed';
    }

    if (isOnBreak) {
      return 'on_break';
    }

    if (attendance != null &&
        attendance!.status.trim().isNotEmpty) {
      return attendance!.status;
    }

    if (hasCheckedIn) {
      return 'working';
    }

    return 'not_checked_in';
  }

  String get statusLabel {
    switch (status.toLowerCase().replaceAll('-', '_')) {
      case 'present':
        return 'Present';

      case 'late':
        return 'Late';

      case 'absent':
        return 'Absent';

      case 'leave':
      case 'on_leave':
        return 'On Leave';

      case 'half_day':
        return 'Half Day';

      case 'working':
      case 'checked_in':
        return 'Working';

      case 'on_break':
      case 'break':
        return 'On Break';

      case 'completed':
      case 'checked_out':
        return 'Completed';

      case 'not_checked_in':
        return 'Not Checked In';

      default:
        return _titleCase(status);
    }
  }

  factory TodayAttendanceData.fromJson(
    Map<String, dynamic> json,
  ) {
    final employeeJson = _findMap(
      json,
      <String>[
        'employee',
        'employee_details',
        'employeeDetails',
      ],
    );

    final shiftJson = _findMap(
      json,
      <String>[
        'shift',
        'shift_details',
        'shiftDetails',
      ],
    );

    // IMPORTANT:
    // Backend GET /attendance/today returns the attendance record
    // inside data.today.
    final attendanceJson = _findMap(
      json,
      <String>[
        'today',
        'attendance',
        'attendance_record',
        'attendanceRecord',
        'today_attendance',
        'todayAttendance',
      ],
    );

    final permissionJson = _findMap(
      json,
      <String>[
        'permissions',
        'permission',
      ],
    );

    final attendance = attendanceJson == null
        ? null
        : TodayAttendanceRecord.fromJson(
            attendanceJson,
          );

    final bool activeBreak =
        _readBool(
          attendanceJson,
          <String>[
            'active_break',
            'activeBreak',
          ],
        ) ??
        false;

    Map<String, dynamic>? currentBreakJson = _findMap(
      json,
      <String>[
        'current_break',
        'currentBreak',
        'break_record',
        'breakRecord',
      ],
    );

    // The backend sends:
    // active_break: true/false
    // active_break_started_at: ...
    // inside data.today.
    //
    // Convert that into a TodayBreakRecord when a break is active.
    if (currentBreakJson == null &&
        activeBreak &&
        attendanceJson != null) {
      currentBreakJson = <String, dynamic>{
        'break_id': _readInt(
          attendanceJson,
          <String>[
            'active_break_id',
            'activeBreakId',
          ],
        ),
        'started_at': _readString(
          attendanceJson,
          <String>[
            'active_break_started_at',
            'activeBreakStartedAt',
          ],
        ),
        'ended_at': null,
        'duration_minutes':
            _readInt(
              attendanceJson,
              <String>[
                'break_minutes',
                'breakMinutes',
              ],
            ) ??
            0,
      };
    }

    final currentBreak = currentBreakJson == null
        ? null
        : TodayBreakRecord.fromJson(
            currentBreakJson,
          );

    final summaryJson = _findMap(
      json,
      <String>[
        'summary',
        'attendance_summary',
        'attendanceSummary',
        'today_summary',
        'todaySummary',
      ],
    );

    // The backend currently returns working_minutes,
    // break_minutes and overtime_minutes inside data.today.
    final summary = TodayAttendanceSummary.fromJson(
      summaryJson ?? attendanceJson ?? json,
      attendance: attendance,
    );

    final hasCheckedIn =
        attendance?.hasCheckedIn ?? false;

    final hasCheckedOut =
        attendance?.hasCheckedOut ?? false;

    final isOnBreak =
        activeBreak ||
        (currentBreak?.isActive ?? false) ||
        (attendance?.isOnBreak ?? false);

    final apiCanCheckIn = _readBool(
      permissionJson ?? json,
      <String>[
        'can_check_in',
        'canCheckIn',
      ],
    );

    final apiCanCheckOut = _readBool(
      permissionJson ?? json,
      <String>[
        'can_check_out',
        'canCheckOut',
      ],
    );

    final apiCanStartBreak = _readBool(
      permissionJson ?? json,
      <String>[
        'can_start_break',
        'canStartBreak',
      ],
    );

    final apiCanEndBreak = _readBool(
      permissionJson ?? json,
      <String>[
        'can_end_break',
        'canEndBreak',
      ],
    );

    return TodayAttendanceData(
      employee: employeeJson == null
          ? null
          : TodayEmployee.fromJson(
              employeeJson,
            ),
      shift: shiftJson == null
          ? null
          : TodayShift.fromJson(
              shiftJson,
            ),
      attendance: attendance,
      currentBreak: currentBreak,
      summary: summary,
      canCheckIn:
          apiCanCheckIn ??
          (!hasCheckedIn && !hasCheckedOut),
      canStartBreak:
          apiCanStartBreak ??
          (hasCheckedIn &&
              !hasCheckedOut &&
              !isOnBreak),
      canEndBreak:
          apiCanEndBreak ??
          (hasCheckedIn &&
              !hasCheckedOut &&
              isOnBreak),
      canCheckOut:
          apiCanCheckOut ??
          (hasCheckedIn &&
              !hasCheckedOut &&
              !isOnBreak),
    );
  }

  factory TodayAttendanceData.empty() {
    return TodayAttendanceData(
      employee: null,
      shift: null,
      attendance: null,
      currentBreak: null,
      summary: TodayAttendanceSummary.empty(),
      canCheckIn: true,
      canStartBreak: false,
      canEndBreak: false,
      canCheckOut: false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'employee': employee?.toJson(),
      'shift': shift?.toJson(),
      'today': attendance?.toJson(),
      'current_break': currentBreak?.toJson(),
      'summary': summary.toJson(),
      'permissions': <String, dynamic>{
        'can_check_in': canCheckIn,
        'can_start_break': canStartBreak,
        'can_end_break': canEndBreak,
        'can_check_out': canCheckOut,
      },
    };
  }
}

class TodayEmployee {
  const TodayEmployee({
    required this.employeeId,
    required this.employeeCode,
    required this.name,
    required this.email,
    required this.departmentName,
    required this.designationName,
    required this.branchName,
  });

  final int? employeeId;
  final String employeeCode;
  final String name;
  final String email;
  final String departmentName;
  final String designationName;
  final String branchName;

  factory TodayEmployee.fromJson(
    Map<String, dynamic> json,
  ) {
    return TodayEmployee(
      employeeId: _readInt(
        json,
        <String>[
          'employee_id',
          'employeeId',
          'id',
        ],
      ),
      employeeCode: _readString(
            json,
            <String>[
              'employee_code',
              'employeeCode',
              'code',
            ],
          ) ??
          '',
      name: _readString(
            json,
            <String>[
              'employee_name',
              'employeeName',
              'full_name',
              'fullName',
              'name',
            ],
          ) ??
          '',
      email: _readString(
            json,
            <String>[
              'email',
              'email_address',
              'emailAddress',
            ],
          ) ??
          '',
      departmentName: _readString(
            json,
            <String>[
              'department_name',
              'departmentName',
              'department',
            ],
          ) ??
          '',
      designationName: _readString(
            json,
            <String>[
              'designation_name',
              'designationName',
              'designation',
            ],
          ) ??
          '',
      branchName: _readString(
            json,
            <String>[
              'branch_name',
              'branchName',
              'branch',
            ],
          ) ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'employee_id': employeeId,
      'employee_code': employeeCode,
      'name': name,
      'email': email,
      'department_name':
          departmentName,
      'designation_name':
          designationName,
      'branch_name': branchName,
    };
  }
}

class TodayShift {
  const TodayShift({
    required this.shiftId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
  });

  final int? shiftId;
  final String name;
  final String? startTime;
  final String? endTime;
  final int graceMinutes;

  factory TodayShift.fromJson(
    Map<String, dynamic> json,
  ) {
    return TodayShift(
      shiftId: _readInt(
        json,
        <String>[
          'shift_id',
          'shiftId',
          'id',
        ],
      ),
      name: _readString(
            json,
            <String>[
              'shift_name',
              'shiftName',
              'name',
            ],
          ) ??
          '',
      startTime: _readString(
        json,
        <String>[
          'start_time',
          'startTime',
          'shift_start_time',
          'shiftStartTime',
        ],
      ),
      endTime: _readString(
        json,
        <String>[
          'end_time',
          'endTime',
          'shift_end_time',
          'shiftEndTime',
        ],
      ),
      graceMinutes: _readInt(
            json,
            <String>[
              'grace_minutes',
              'graceMinutes',
              'grace_period_minutes',
              'gracePeriodMinutes',
              'late_grace_minutes',
              'lateGraceMinutes',
            ],
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'shift_id': shiftId,
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      'grace_minutes': graceMinutes,
    };
  }
}

class TodayAttendanceRecord {
  const TodayAttendanceRecord({
    required this.attendanceId,
    required this.attendanceDate,
    required this.checkInTime,
    required this.checkOutTime,
    required this.status,
    required this.workedMinutes,
    required this.breakMinutes,
    required this.overtimeMinutes,
    required this.activeBreak,
    required this.checkInLatitude,
    required this.checkInLongitude,
    required this.checkOutLatitude,
    required this.checkOutLongitude,
  });

  final int? attendanceId;
  final String? attendanceDate;
  final String? checkInTime;
  final String? checkOutTime;
  final String status;

  final int workedMinutes;
  final int breakMinutes;
  final int overtimeMinutes;

  final bool activeBreak;

  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;

  bool get hasCheckedIn {
    return _hasValue(checkInTime);
  }

  bool get hasCheckedOut {
    return _hasValue(checkOutTime);
  }

  bool get isOnBreak {
    if (activeBreak) {
      return true;
    }

    final normalizedStatus =
        status.toLowerCase().replaceAll('_', ' ');

    return normalizedStatus == 'on break' ||
        normalizedStatus == 'break';
  }

  String get workedDurationLabel {
    return _formatMinutes(workedMinutes);
  }

  String get breakDurationLabel {
    return _formatMinutes(breakMinutes);
  }

  String get overtimeLabel {
    return _formatMinutes(overtimeMinutes);
  }

  factory TodayAttendanceRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return TodayAttendanceRecord(
      attendanceId: _readInt(
        json,
        <String>[
          'attendance_id',
          'attendanceId',
          'id',
        ],
      ),
      attendanceDate: _readString(
        json,
        <String>[
          'attendance_date',
          'attendanceDate',
          'date',
        ],
      ),
      checkInTime: _readString(
        json,
        <String>[
          'check_in_time',
          'checkInTime',
          'checkin_time',
          'checkinTime',
          'check_in_at',
          'checkInAt',
          'clock_in_time',
          'clockInTime',
        ],
      ),
      checkOutTime: _readString(
        json,
        <String>[
          'check_out_time',
          'checkOutTime',
          'checkout_time',
          'checkoutTime',
          'check_out_at',
          'checkOutAt',
          'clock_out_time',
          'clockOutTime',
        ],
      ),
      status:
          _readString(
            json,
            <String>[
              'attendance_status',
              'attendanceStatus',
              'status',
            ],
          ) ??
          '',
      workedMinutes: _readDurationMinutes(
        json,
        minuteKeys: <String>[
          'worked_minutes',
          'workedMinutes',
          'working_minutes',
          'workingMinutes',
          'total_worked_minutes',
          'totalWorkedMinutes',
        ],
        durationKeys: <String>[
          'working_duration',
          'workingDuration',
          'worked_duration',
          'workedDuration',
          'working_hours',
          'workingHours',
          'worked',
        ],
      ),
      breakMinutes: _readDurationMinutes(
        json,
        minuteKeys: <String>[
          'break_minutes',
          'breakMinutes',
          'total_break_minutes',
          'totalBreakMinutes',
        ],
        durationKeys: <String>[
          'break_duration',
          'breakDuration',
          'total_break_time',
          'totalBreakTime',
        ],
      ),
      overtimeMinutes: _readDurationMinutes(
        json,
        minuteKeys: <String>[
          'overtime_minutes',
          'overtimeMinutes',
          'ot_minutes',
          'otMinutes',
        ],
        durationKeys: <String>[
          'overtime_duration',
          'overtimeDuration',
          'overtime',
          'ot_duration',
          'otDuration',
        ],
      ),
      activeBreak:
          _readBool(
            json,
            <String>[
              'active_break',
              'activeBreak',
            ],
          ) ??
          false,
      checkInLatitude: _readDouble(
        json,
        <String>[
          'check_in_latitude',
          'checkInLatitude',
          'check_in_lat',
          'checkInLat',
        ],
      ),
      checkInLongitude: _readDouble(
        json,
        <String>[
          'check_in_longitude',
          'checkInLongitude',
          'check_in_lng',
          'checkInLng',
        ],
      ),
      checkOutLatitude: _readDouble(
        json,
        <String>[
          'check_out_latitude',
          'checkOutLatitude',
          'check_out_lat',
          'checkOutLat',
        ],
      ),
      checkOutLongitude: _readDouble(
        json,
        <String>[
          'check_out_longitude',
          'checkOutLongitude',
          'check_out_lng',
          'checkOutLng',
        ],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attendance_id': attendanceId,
      'date': attendanceDate,
      'attendance_status': status,
      'check_in_at': checkInTime,
      'check_out_at': checkOutTime,
      'working_minutes': workedMinutes,
      'break_minutes': breakMinutes,
      'overtime_minutes': overtimeMinutes,
      'active_break': activeBreak,
      'check_in_latitude': checkInLatitude,
      'check_in_longitude': checkInLongitude,
      'check_out_latitude': checkOutLatitude,
      'check_out_longitude': checkOutLongitude,
    };
  }
}

class TodayBreakRecord {
  const TodayBreakRecord({
    required this.breakId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  final int? breakId;
  final String? startTime;
  final String? endTime;
  final int durationMinutes;

  bool get isActive {
    return _hasValue(startTime) &&
        !_hasValue(endTime);
  }

  String get durationLabel {
    return _formatMinutes(
      durationMinutes,
    );
  }

  factory TodayBreakRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return TodayBreakRecord(
      breakId: _readInt(
        json,
        <String>[
          'break_id',
          'breakId',
          'id',
        ],
      ),
      startTime: _readString(
        json,
        <String>[
          'break_start_time',
          'breakStartTime',
          'start_time',
          'startTime',
          'started_at',
          'startedAt',
          'active_break_started_at',
          'activeBreakStartedAt',
        ],
      ),
      endTime: _readString(
        json,
        <String>[
          'break_end_time',
          'breakEndTime',
          'end_time',
          'endTime',
          'ended_at',
          'endedAt',
        ],
      ),
      durationMinutes:
          _readDurationMinutes(
        json,
        minuteKeys: <String>[
          'duration_minutes',
          'durationMinutes',
          'break_minutes',
          'breakMinutes',
        ],
        durationKeys: <String>[
          'duration',
          'break_duration',
          'breakDuration',
        ],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'break_id': breakId,
      'start_time': startTime,
      'end_time': endTime,
      'duration_minutes':
          durationMinutes,
    };
  }
}

class TodayAttendanceSummary {
  const TodayAttendanceSummary({
    required this.workedMinutes,
    required this.breakMinutes,
    required this.overtimeMinutes,
  });

  final int workedMinutes;
  final int breakMinutes;
  final int overtimeMinutes;

  String get workingDurationLabel {
    return _formatMinutes(workedMinutes);
  }

  String get breakDurationLabel {
    return _formatMinutes(breakMinutes);
  }

  String get overtimeLabel {
    return _formatMinutes(overtimeMinutes);
  }

  factory TodayAttendanceSummary.fromJson(
    Map<String, dynamic> json, {
    TodayAttendanceRecord? attendance,
  }) {
    final workedMinutes =
        _readDurationMinutes(
      json,
      minuteKeys: <String>[
        'worked_minutes',
        'workedMinutes',
        'working_minutes',
        'workingMinutes',
        'total_worked_minutes',
        'totalWorkedMinutes',
      ],
      durationKeys: <String>[
        'working_duration',
        'workingDuration',
        'worked_duration',
        'workedDuration',
        'working_hours',
        'workingHours',
        'worked',
      ],
    );

    final breakMinutes =
        _readDurationMinutes(
      json,
      minuteKeys: <String>[
        'break_minutes',
        'breakMinutes',
        'total_break_minutes',
        'totalBreakMinutes',
      ],
      durationKeys: <String>[
        'break_duration',
        'breakDuration',
        'total_break_time',
        'totalBreakTime',
      ],
    );

    final overtimeMinutes =
        _readDurationMinutes(
      json,
      minuteKeys: <String>[
        'overtime_minutes',
        'overtimeMinutes',
        'ot_minutes',
        'otMinutes',
      ],
      durationKeys: <String>[
        'overtime_duration',
        'overtimeDuration',
        'overtime',
        'ot_duration',
        'otDuration',
      ],
    );

    return TodayAttendanceSummary(
      workedMinutes: workedMinutes > 0
          ? workedMinutes
          : attendance?.workedMinutes ??
              0,
      breakMinutes: breakMinutes > 0
          ? breakMinutes
          : attendance?.breakMinutes ??
              0,
      overtimeMinutes:
          overtimeMinutes > 0
              ? overtimeMinutes
              : attendance
                      ?.overtimeMinutes ??
                  0,
    );
  }

  factory TodayAttendanceSummary.empty() {
    return const TodayAttendanceSummary(
      workedMinutes: 0,
      breakMinutes: 0,
      overtimeMinutes: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'worked_minutes': workedMinutes,
      'break_minutes': breakMinutes,
      'overtime_minutes':
          overtimeMinutes,
    };
  }
}

Map<String, dynamic>? _asMap(
  dynamic value,
) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, item) {
        return MapEntry(
          key.toString(),
          item,
        );
      },
    );
  }

  return null;
}

Map<String, dynamic>? _findMap(
  dynamic source,
  List<String> keys,
) {
  final value = _findValue(
    source,
    keys,
  );

  return _asMap(value);
}

dynamic _findValue(
  dynamic source,
  List<String> keys,
) {
  final normalizedKeys = keys
      .map(_normalizeKey)
      .toSet();

  return _findValueRecursive(
    source,
    normalizedKeys,
    <int>{},
  );
}

dynamic _findValueRecursive(
  dynamic source,
  Set<String> normalizedKeys,
  Set<int> visited,
) {
  if (source == null) {
    return null;
  }

  if (source is Map) {
    final identity =
        identityHashCode(source);

    if (visited.contains(identity)) {
      return null;
    }

    visited.add(identity);

    for (final entry in source.entries) {
      final key = _normalizeKey(
        entry.key.toString(),
      );

      if (normalizedKeys.contains(key)) {
        return entry.value;
      }
    }

    for (final value in source.values) {
      final result =
          _findValueRecursive(
        value,
        normalizedKeys,
        visited,
      );

      if (result != null) {
        return result;
      }
    }
  }

  if (source is List) {
    final identity =
        identityHashCode(source);

    if (visited.contains(identity)) {
      return null;
    }

    visited.add(identity);

    for (final value in source) {
      final result =
          _findValueRecursive(
        value,
        normalizedKeys,
        visited,
      );

      if (result != null) {
        return result;
      }
    }
  }

  return null;
}

String? _readString(
  dynamic source,
  List<String> keys,
) {
  final value = _findValue(
    source,
    keys,
  );

  if (value == null ||
      value is Map ||
      value is List) {
    return null;
  }

  final text = value.toString().trim();

  if (text.isEmpty ||
      text.toLowerCase() == 'null') {
    return null;
  }

  return text;
}

int? _readInt(
  dynamic source,
  List<String> keys,
) {
  final value = _findValue(
    source,
    keys,
  );

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.round();
  }

  return int.tryParse(
    value?.toString() ?? '',
  );
}

double? _readDouble(
  dynamic source,
  List<String> keys,
) {
  final value = _findValue(
    source,
    keys,
  );

  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
    value?.toString() ?? '',
  );
}

bool? _readBool(
  dynamic source,
  List<String> keys,
) {
  final value = _findValue(
    source,
    keys,
  );

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final text = value
      ?.toString()
      .trim()
      .toLowerCase();

  if (text == 'true' ||
      text == '1' ||
      text == 'yes') {
    return true;
  }

  if (text == 'false' ||
      text == '0' ||
      text == 'no') {
    return false;
  }

  return null;
}

int _readDurationMinutes(
  dynamic source, {
  required List<String> minuteKeys,
  required List<String> durationKeys,
}) {
  final minuteValue = _findValue(
    source,
    minuteKeys,
  );

  final minuteResult =
      _durationToMinutes(
    minuteValue,
    numericIsMinutes: true,
  );

  if (minuteResult != null) {
    return minuteResult;
  }

  final durationValue = _findValue(
    source,
    durationKeys,
  );

  return _durationToMinutes(
        durationValue,
        numericIsMinutes: true,
      ) ??
      0;
}

int? _durationToMinutes(
  dynamic value, {
  required bool numericIsMinutes,
}) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return numericIsMinutes
        ? value.round()
        : null;
  }

  final text = value.toString().trim();

  if (text.isEmpty ||
      text.toLowerCase() == 'null') {
    return null;
  }

  final numeric =
      double.tryParse(text);

  if (numeric != null) {
    return numeric.round();
  }

  final timeMatch = RegExp(
    r'^(\d{1,3}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(text);

  if (timeMatch != null) {
    final hours =
        int.parse(timeMatch.group(1)!);

    final minutes =
        int.parse(timeMatch.group(2)!);

    final seconds = int.tryParse(
          timeMatch.group(3) ?? '0',
        ) ??
        0;

    return (hours * 60) +
        minutes +
        (seconds >= 30 ? 1 : 0);
  }

  final hourMatch = RegExp(
    r'(\d+)\s*h',
    caseSensitive: false,
  ).firstMatch(text);

  final minuteMatch = RegExp(
    r'(\d+)\s*m',
    caseSensitive: false,
  ).firstMatch(text);

  if (hourMatch != null ||
      minuteMatch != null) {
    final hours = int.tryParse(
          hourMatch?.group(1) ?? '0',
        ) ??
        0;

    final minutes = int.tryParse(
          minuteMatch?.group(1) ?? '0',
        ) ??
        0;

    return (hours * 60) + minutes;
  }

  return null;
}

String _formatMinutes(
  int totalMinutes,
) {
  if (totalMinutes <= 0) {
    return '0m';
  }

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) {
    return '${minutes}m';
  }

  if (minutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${minutes}m';
}

bool _hasValue(
  dynamic value,
) {
  if (value == null) {
    return false;
  }

  final text =
      value.toString().trim().toLowerCase();

  return text.isNotEmpty &&
      text != 'null' &&
      text != '--' &&
      text != '-- : --';
}

String _normalizeKey(
  String value,
) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
}

String _titleCase(
  String value,
) {
  return value
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where(
        (word) => word.isNotEmpty,
      )
      .map(
        (word) {
          return '${word[0].toUpperCase()}'
              '${word.substring(1).toLowerCase()}';
        },
      )
      .join(' ');
}