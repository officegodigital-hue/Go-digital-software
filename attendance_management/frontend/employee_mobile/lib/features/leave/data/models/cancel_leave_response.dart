class CancelLeaveResponse {
  const CancelLeaveResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  final bool success;
  final String message;
  final CancelledLeaveData data;

  factory CancelLeaveResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return CancelLeaveResponse(
      success: _toBool(
        json['success'],
      ),
      message: _toText(
        json['message'],
      ),
      data: CancelledLeaveData.fromJson(
        _toMap(json['data']),
      ),
    );
  }
}

class CancelledLeaveData {
  const CancelledLeaveData({
    required this.leaveRequestId,
    required this.status,
    required this.cancelledAt,
    required this.cancellationReason,
  });

  final int leaveRequestId;
  final String status;
  final DateTime? cancelledAt;
  final String cancellationReason;

  factory CancelledLeaveData.fromJson(
    Map<String, dynamic> json,
  ) {
    return CancelledLeaveData(
      leaveRequestId: _toInt(
        json['leave_request_id'],
      ),
      status: _toText(
        json['status'],
      ),
      cancelledAt: _toDateTime(
        json['cancelled_at'],
      ),
      cancellationReason: _toText(
        json['cancellation_reason'],
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

  bool get isCancelled {
    return status == 'cancelled';
  }

  String get cancelledDateLabel {
    return _formatDateTime(
      cancelledAt,
    );
  }
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

  final parsedDate =
      DateTime.tryParse(text);

  return parsedDate?.toLocal();
}

String _formatDateTime(
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

  final localDate = value.toLocal();

  final hour = localDate.hour % 12 == 0
      ? 12
      : localDate.hour % 12;

  final minute = localDate.minute
      .toString()
      .padLeft(2, '0');

  final period =
      localDate.hour >= 12
          ? 'PM'
          : 'AM';

  return '${localDate.day} '
      '${months[localDate.month - 1]} '
      '${localDate.year}, '
      '$hour:$minute $period';
}