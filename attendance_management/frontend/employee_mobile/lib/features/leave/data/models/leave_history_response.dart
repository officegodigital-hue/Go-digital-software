class LeaveHistoryResponse {
  const LeaveHistoryResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final LeaveHistoryData data;

  factory LeaveHistoryResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveHistoryResponse(
      success: _toBool(
        json['success'],
      ),
      message: _toText(
        json['message'],
      ),
      data: LeaveHistoryData.fromJson(
        _toMap(json['data']),
      ),
    );
  }
}

class LeaveHistoryData {
  const LeaveHistoryData({
    required this.employee,
    required this.filter,
    required this.requests,
  });

  final LeaveHistoryEmployee employee;
  final LeaveHistoryFilter filter;
  final List<LeaveRequestRecord> requests;

  factory LeaveHistoryData.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawRequests = json['requests'];

    return LeaveHistoryData(
      employee:
          LeaveHistoryEmployee.fromJson(
        _toMap(json['employee']),
      ),
      filter: LeaveHistoryFilter.fromJson(
        _toMap(json['filter']),
      ),
      requests: rawRequests is List
          ? rawRequests
              .whereType<Map>()
              .map(
                (item) =>
                    LeaveRequestRecord.fromJson(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
              )
              .toList()
          : const <LeaveRequestRecord>[],
    );
  }
}

class LeaveHistoryEmployee {
  const LeaveHistoryEmployee({
    required this.employeeId,
    required this.employeeCode,
    required this.name,
    required this.timezone,
  });

  final int employeeId;
  final String employeeCode;
  final String name;
  final String timezone;

  factory LeaveHistoryEmployee.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveHistoryEmployee(
      employeeId: _toInt(
        json['employee_id'],
      ),
      employeeCode: _toText(
        json['employee_code'],
      ),
      name: _toText(
        json['name'],
      ),
      timezone: _toText(
        json['timezone'],
      ),
    );
  }
}

class LeaveHistoryFilter {
  const LeaveHistoryFilter({
    required this.year,
    required this.status,
  });

  final int year;
  final String? status;

  factory LeaveHistoryFilter.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveHistoryFilter(
      year: _toInt(
        json['year'],
      ),
      status: _toNullableText(
        json['status'],
      ),
    );
  }
}

class LeaveRequestRecord {
  const LeaveRequestRecord({
    required this.leaveRequestId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.dayType,
    required this.totalDays,
    required this.reason,
    required this.attachmentUrl,
    required this.status,
    required this.reviewedAt,
    required this.reviewComment,
    required this.cancelledAt,
    required this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
    required this.canCancel,
  });

  final int leaveRequestId;

  final LeaveRequestType leaveType;

  final DateTime? startDate;
  final DateTime? endDate;

  final String dayType;
  final double totalDays;
  final String reason;

  final String? attachmentUrl;

  final String status;

  final DateTime? reviewedAt;
  final String? reviewComment;

  final DateTime? cancelledAt;
  final String? cancellationReason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final bool canCancel;

  factory LeaveRequestRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveRequestRecord(
      leaveRequestId: _toInt(
        json['leave_request_id'],
      ),
      leaveType:
          LeaveRequestType.fromJson(
        _toMap(json['leave_type']),
      ),
      startDate: _toDateTime(
        json['start_date'],
      ),
      endDate: _toDateTime(
        json['end_date'],
      ),
      dayType: _toText(
        json['day_type'],
      ),
      totalDays: _toDouble(
        json['total_days'],
      ),
      reason: _toText(
        json['reason'],
      ),
      attachmentUrl: _toNullableText(
        json['attachment_url'],
      ),
      status: _toText(
        json['status'],
      ),
      reviewedAt: _toDateTime(
        json['reviewed_at'],
      ),
      reviewComment: _toNullableText(
        json['review_comment'],
      ),
      cancelledAt: _toDateTime(
        json['cancelled_at'],
      ),
      cancellationReason:
          _toNullableText(
        json['cancellation_reason'],
      ),
      createdAt: _toDateTime(
        json['created_at'],
      ),
      updatedAt: _toDateTime(
        json['updated_at'],
      ),
      canCancel: _toBool(
        json['can_cancel'],
      ),
    );
  }

  bool get isPending {
    return status == 'pending';
  }

  bool get isApproved {
    return status == 'approved';
  }

  bool get isRejected {
    return status == 'rejected';
  }

  bool get isCancelled {
    return status == 'cancelled';
  }

  String get totalDaysLabel {
    if (totalDays == totalDays.roundToDouble()) {
      final days = totalDays.toInt();

      return '$days ${days == 1 ? 'day' : 'days'}';
    }

    return '${totalDays.toStringAsFixed(1)} days';
  }

  String get dayTypeLabel {
    switch (dayType) {
      case 'first_half':
        return 'First Half';

      case 'second_half':
        return 'Second Half';

      default:
        return 'Full Day';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'cancelled':
        return 'Cancelled';

      default:
        return 'Pending';
    }
  }

  String get dateRangeLabel {
    if (startDate == null &&
        endDate == null) {
      return '--';
    }

    if (_isSameDate(
      startDate,
      endDate,
    )) {
      return _formatDate(startDate);
    }

    return '${_formatDate(startDate)} - '
        '${_formatDate(endDate)}';
  }
}

class LeaveRequestType {
  const LeaveRequestType({
    required this.leaveTypeId,
    required this.name,
    required this.code,
    required this.isPaid,
    required this.requiresAttachment,
  });

  final int leaveTypeId;
  final String name;
  final String code;
  final bool isPaid;
  final bool requiresAttachment;

  factory LeaveRequestType.fromJson(
    Map<String, dynamic> json,
  ) {
    return LeaveRequestType(
      leaveTypeId: _toInt(
        json['leave_type_id'],
      ),
      name: _toText(
        json['name'],
      ),
      code: _toText(
        json['code'],
      ),
      isPaid: _toBool(
        json['is_paid'],
      ),
      requiresAttachment: _toBool(
        json['requires_attachment'],
      ),
    );
  }

  String get paymentLabel {
    return isPaid
        ? 'Paid Leave'
        : 'Unpaid Leave';
  }
}

bool _isSameDate(
  DateTime? first,
  DateTime? second,
) {
  if (first == null || second == null) {
    return false;
  }

  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _formatDate(
  DateTime? value,
) {
  if (value == null) {
    return '--';
  }

  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${value.day} '
      '${months[value.month - 1]} '
      '${value.year}';
}

Map<String, dynamic> _toMap(
  dynamic value,
) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(
      value,
    );
  }

  return <String, dynamic>{};
}

String _toText(
  dynamic value,
) {
  if (value == null) {
    return '';
  }

  return value.toString();
}

String? _toNullableText(
  dynamic value,
) {
  final text = _toText(value).trim();

  if (text.isEmpty) {
    return null;
  }

  return text;
}

int _toInt(
  dynamic value,
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

double _toDouble(
  dynamic value,
) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}

bool _toBool(
  dynamic value,
) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalized =
      value?.toString().toLowerCase();

  return normalized == 'true' ||
      normalized == '1';
}

DateTime? _toDateTime(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return null;
  }

  final dateOnlyPattern = RegExp(
    r'^\d{4}-\d{2}-\d{2}$',
  );

  if (dateOnlyPattern.hasMatch(text)) {
    final parts = text.split('-');

    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  final parsedDate =
      DateTime.tryParse(text);

  return parsedDate?.toLocal();
}