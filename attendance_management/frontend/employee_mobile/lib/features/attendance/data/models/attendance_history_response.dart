class AttendanceHistoryResponse {
  const AttendanceHistoryResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final AttendanceHistoryData? data;

  factory AttendanceHistoryResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final dataJson = _nullableMap(json['data']);

    return AttendanceHistoryResponse(
      success: _toBool(json['success']),
      message: _toString(json['message']),
      data: dataJson == null
          ? null
          : AttendanceHistoryData.fromJson(
              dataJson,
            ),
    );
  }
}

class AttendanceHistoryData {
  const AttendanceHistoryData({
    required this.employee,
    required this.filter,
    required this.summary,
    required this.records,
  });

  final HistoryEmployee employee;
  final AttendanceHistoryFilter filter;
  final AttendanceHistorySummary summary;
  final List<AttendanceHistoryRecord> records;

  factory AttendanceHistoryData.fromJson(
    Map<String, dynamic> json,
  ) {
    final recordsJson = json['records'];

    return AttendanceHistoryData(
      employee: HistoryEmployee.fromJson(
        _map(json['employee']),
      ),
      filter: AttendanceHistoryFilter.fromJson(
        _map(json['filter']),
      ),
      summary: AttendanceHistorySummary.fromJson(
        _map(json['summary']),
      ),
      records: recordsJson is List
          ? recordsJson
              .whereType<Map>()
              .map(
                (record) =>
                    AttendanceHistoryRecord.fromJson(
                  Map<String, dynamic>.from(record),
                ),
              )
              .toList()
          : <AttendanceHistoryRecord>[],
    );
  }
}

class HistoryEmployee {
  const HistoryEmployee({
    required this.employeeId,
    required this.employeeCode,
    required this.name,
    required this.companyId,
    required this.companyName,
    required this.branchId,
    required this.branchName,
    required this.timezone,
  });

  final int employeeId;
  final String employeeCode;
  final String name;

  final int companyId;
  final String companyName;

  final int branchId;
  final String branchName;

  final String timezone;

  factory HistoryEmployee.fromJson(
    Map<String, dynamic> json,
  ) {
    return HistoryEmployee(
      employeeId: _toInt(
        json['employee_id'],
      ),
      employeeCode: _toString(
        json['employee_code'],
      ),
      name: _toString(
        json['name'],
      ),
      companyId: _toInt(
        json['company_id'],
      ),
      companyName: _toString(
        json['company_name'],
      ),
      branchId: _toInt(
        json['branch_id'],
      ),
      branchName: _toString(
        json['branch_name'],
      ),
      timezone: _toString(
        json['timezone'],
      ),
    );
  }
}

class AttendanceHistoryFilter {
  const AttendanceHistoryFilter({
    required this.month,
    required this.startDate,
    required this.endDateExclusive,
  });

  final String month;
  final DateTime? startDate;
  final DateTime? endDateExclusive;

  factory AttendanceHistoryFilter.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendanceHistoryFilter(
      month: _toString(
        json['month'],
      ),
      startDate: _toDateTime(
        json['start_date'],
      ),
      endDateExclusive: _toDateTime(
        json['end_date_exclusive'],
      ),
    );
  }
}

class AttendanceHistorySummary {
  const AttendanceHistorySummary({
    required this.totalRecords,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.halfDays,
    required this.leaveDays,
    required this.workFromHomeDays,
    required this.holidayDays,
    required this.weekOffDays,
    required this.incompleteDays,
    required this.completedSessions,
    required this.activeSessions,
    required this.totalWorkingMinutes,
    required this.totalBreakMinutes,
    required this.totalOvertimeMinutes,
  });

  final int totalRecords;

  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int halfDays;
  final int leaveDays;
  final int workFromHomeDays;
  final int holidayDays;
  final int weekOffDays;
  final int incompleteDays;

  final int completedSessions;
  final int activeSessions;

  final int totalWorkingMinutes;
  final int totalBreakMinutes;
  final int totalOvertimeMinutes;

  factory AttendanceHistorySummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendanceHistorySummary(
      totalRecords: _toInt(
        json['total_records'],
      ),
      presentDays: _toInt(
        json['present_days'],
      ),
      lateDays: _toInt(
        json['late_days'],
      ),
      absentDays: _toInt(
        json['absent_days'],
      ),
      halfDays: _toInt(
        json['half_days'],
      ),
      leaveDays: _toInt(
        json['leave_days'],
      ),
      workFromHomeDays: _toInt(
        json['work_from_home_days'],
      ),
      holidayDays: _toInt(
        json['holiday_days'],
      ),
      weekOffDays: _toInt(
        json['week_off_days'],
      ),
      incompleteDays: _toInt(
        json['incomplete_days'],
      ),
      completedSessions: _toInt(
        json['completed_sessions'],
      ),
      activeSessions: _toInt(
        json['active_sessions'],
      ),
      totalWorkingMinutes: _toInt(
        json['total_working_minutes'],
      ),
      totalBreakMinutes: _toInt(
        json['total_break_minutes'],
      ),
      totalOvertimeMinutes: _toInt(
        json['total_overtime_minutes'],
      ),
    );
  }
}

class AttendanceHistoryRecord {
  const AttendanceHistoryRecord({
    required this.attendanceId,
    required this.attendanceDate,
    required this.checkInAt,
    required this.checkOutAt,
    required this.workingMinutes,
    required this.breakMinutes,
    required this.overtimeMinutes,
    required this.attendanceStatus,
    required this.sessionStatus,
    required this.notes,
    required this.shift,
  });

  final int attendanceId;
  final DateTime? attendanceDate;

  final DateTime? checkInAt;
  final DateTime? checkOutAt;

  final int workingMinutes;
  final int breakMinutes;
  final int overtimeMinutes;

  final String attendanceStatus;
  final String sessionStatus;

  final String? notes;
  final AttendanceHistoryShift? shift;

  factory AttendanceHistoryRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    final shiftJson = _nullableMap(
      json['shift'],
    );

    return AttendanceHistoryRecord(
      attendanceId: _toInt(
        json['attendance_id'],
      ),
      attendanceDate: _toDateTime(
        json['attendance_date'],
      ),
      checkInAt: _toDateTime(
        json['check_in_at'],
      ),
      checkOutAt: _toDateTime(
        json['check_out_at'],
      ),
      workingMinutes: _toInt(
        json['working_minutes'],
      ),
      breakMinutes: _toInt(
        json['break_minutes'],
      ),
      overtimeMinutes: _toInt(
        json['overtime_minutes'],
      ),
      attendanceStatus: _toString(
        json['attendance_status'],
      ),
      sessionStatus: _toString(
        json['session_status'],
      ),
      notes: _nullableString(
        json['notes'],
      ),
      shift: shiftJson == null
          ? null
          : AttendanceHistoryShift.fromJson(
              shiftJson,
            ),
    );
  }

  bool get isCompleted =>
      sessionStatus == 'completed';
}

class AttendanceHistoryShift {
  const AttendanceHistoryShift({
    required this.shiftId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.gracePeriodMinutes,
    required this.lateThresholdMinutes,
  });

  final int shiftId;
  final String name;
  final String startTime;
  final String endTime;

  final int gracePeriodMinutes;
  final int lateThresholdMinutes;

  factory AttendanceHistoryShift.fromJson(
    Map<String, dynamic> json,
  ) {
    return AttendanceHistoryShift(
      shiftId: _toInt(
        json['shift_id'],
      ),
      name: _toString(
        json['name'],
      ),
      startTime: _toString(
        json['start_time'],
      ),
      endTime: _toString(
        json['end_time'],
      ),
      gracePeriodMinutes: _toInt(
        json['grace_period_minutes'],
      ),
      lateThresholdMinutes: _toInt(
        json['late_threshold_minutes'],
      ),
    );
  }
}

Map<String, dynamic> _map(
  Object? value,
) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

Map<String, dynamic>? _nullableMap(
  Object? value,
) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return null;
}

String _toString(
  Object? value,
) {
  return value?.toString() ?? '';
}

String? _nullableString(
  Object? value,
) {
  if (value == null) {
    return null;
  }

  final result = value.toString().trim();

  return result.isEmpty ? null : result;
}

int _toInt(
  Object? value,
) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

bool _toBool(
  Object? value,
) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalized =
      value?.toString().trim().toLowerCase();

  return normalized == 'true' ||
      normalized == '1';
}

DateTime? _toDateTime(
  Object? value,
) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}