class ApplyLeaveResponse {
  const ApplyLeaveResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final AppliedLeaveData data;

  factory ApplyLeaveResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApplyLeaveResponse(
      success: _toBool(
        json['success'],
      ),
      message: _toText(
        json['message'],
      ),
      data: AppliedLeaveData.fromJson(
        _toMap(json['data']),
      ),
    );
  }
}

class AppliedLeaveData {
  const AppliedLeaveData({
    required this.leaveRequestId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.dayType,
    required this.totalDays,
    required this.reason,
    required this.attachmentUrl,
    required this.status,
  });

  final int leaveRequestId;

  final AppliedLeaveType leaveType;

  final DateTime? startDate;
  final DateTime? endDate;

  final String dayType;
  final double totalDays;
  final String reason;

  final String? attachmentUrl;

  final String status;

  factory AppliedLeaveData.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppliedLeaveData(
      leaveRequestId: _toInt(
        json['leave_request_id'],
      ),
      leaveType: AppliedLeaveType.fromJson(
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
    );
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

  String get totalDaysLabel {
    if (totalDays == totalDays.roundToDouble()) {
      final days = totalDays.toInt();

      return '$days ${days == 1 ? 'day' : 'days'}';
    }

    return '${totalDays.toStringAsFixed(1)} days';
  }

  String get dateRangeLabel {
    if (startDate == null && endDate == null) {
      return '--';
    }

    if (_isSameDate(startDate, endDate)) {
      return _formatDate(startDate);
    }

    return '${_formatDate(startDate)} - '
        '${_formatDate(endDate)}';
  }
}

class AppliedLeaveType {
  const AppliedLeaveType({
    required this.leaveTypeId,
    required this.name,
    required this.code,
  });

  final int leaveTypeId;
  final String name;
  final String code;

  factory AppliedLeaveType.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppliedLeaveType(
      leaveTypeId: _toInt(
        json['leave_type_id'],
      ),
      name: _toText(
        json['name'],
      ),
      code: _toText(
        json['code'],
      ),
    );
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

  final parsedDate = DateTime.tryParse(text);

  return parsedDate?.toLocal();
}