class NotificationListResponse {
  const NotificationListResponse({
    required this.success,
    required this.message,
    required this.notifications,
    required this.unreadCount,
  });

  final bool success;
  final String message;
  final List<AppNotification> notifications;
  final int unreadCount;

  factory NotificationListResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final notificationItems =
        _findNotificationList(json);

    final notifications = notificationItems
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) {
            return AppNotification.fromJson(
              item.map<String, dynamic>(
                (
                  dynamic key,
                  dynamic value,
                ) {
                  return MapEntry<String, dynamic>(
                    key.toString(),
                    value,
                  );
                },
              ),
            );
          },
        )
        .toList();

    final unreadCount = _readInt(
          json,
          const <String>[
            'unread_count',
            'unreadCount',
            'total_unread',
            'totalUnread',
          ],
        ) ??
        notifications
            .where(
              (AppNotification notification) {
                return !notification.isRead;
              },
            )
            .length;

    return NotificationListResponse(
      success: _readBool(
            json,
            const <String>[
              'success',
              'status',
            ],
          ) ??
          true,
      message: _readString(
            json,
            const <String>[
              'message',
              'msg',
            ],
          ) ??
          '',
      notifications: notifications,
      unreadCount: unreadCount,
    );
  }

  factory NotificationListResponse.empty({
    String message = '',
  }) {
    return NotificationListResponse(
      success: true,
      message: message,
      notifications:
          const <AppNotification>[],
      unreadCount: 0,
    );
  }

  NotificationListResponse copyWith({
    bool? success,
    String? message,
    List<AppNotification>? notifications,
    int? unreadCount,
  }) {
    return NotificationListResponse(
      success: success ?? this.success,
      message: message ?? this.message,
      notifications:
          notifications ?? this.notifications,
      unreadCount:
          unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'success': success,
      'message': message,
      'unread_count': unreadCount,
      'notifications': notifications
          .map(
            (AppNotification notification) {
              return notification.toJson();
            },
          )
          .toList(),
    };
  }
}

class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.referenceId,
    required this.referenceType,
  });

  final int? notificationId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final int? referenceId;
  final String referenceType;

  factory AppNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppNotification(
      notificationId: _readInt(
        json,
        const <String>[
          'notification_id',
          'notificationId',
          'id',
        ],
      ),
      title: _readString(
            json,
            const <String>[
              'title',
              'notification_title',
              'notificationTitle',
              'subject',
            ],
          ) ??
          'Notification',
      message: _readString(
            json,
            const <String>[
              'message',
              'body',
              'description',
              'content',
              'notification_message',
              'notificationMessage',
            ],
          ) ??
          '',
      type: _readString(
            json,
            const <String>[
              'notification_type',
              'notificationType',
              'type',
              'category',
            ],
          ) ??
          'general',
      isRead: _readBool(
            json,
            const <String>[
              'is_read',
              'isRead',
              'read',
              'read_status',
              'readStatus',
            ],
          ) ??
          false,
      createdAt: _readDateTime(
        json,
        const <String>[
          'created_at',
          'createdAt',
          'sent_at',
          'sentAt',
          'notification_date',
          'notificationDate',
          'date',
        ],
      ),
      referenceId: _readInt(
        json,
        const <String>[
          'reference_id',
          'referenceId',
          'entity_id',
          'entityId',
          'leave_request_id',
          'leaveRequestId',
        ],
      ),
      referenceType: _readString(
            json,
            const <String>[
              'reference_type',
              'referenceType',
              'entity_type',
              'entityType',
            ],
          ) ??
          '',
    );
  }

  String get typeLabel {
    final normalizedType = type
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');

    if (normalizedType.isEmpty) {
      return 'General';
    }

    return normalizedType
        .split(RegExp(r'\s+'))
        .where(
          (String word) {
            return word.isNotEmpty;
          },
        )
        .map(
          (String word) {
            return '${word[0].toUpperCase()}'
                '${word.substring(1)}';
          },
        )
        .join(' ');
  }

  String get dateLabel {
    final date = createdAt;

    if (date == null) {
      return '';
    }

    final localDate = date.toLocal();
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final notificationDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final difference = today
        .difference(notificationDate)
        .inDays;

    if (difference == 0) {
      return 'Today, ${_formatTime(localDate)}';
    }

    if (difference == 1) {
      return 'Yesterday, ${_formatTime(localDate)}';
    }

    return '${localDate.day.toString().padLeft(2, '0')} '
        '${_shortMonth(localDate.month)} '
        '${localDate.year}, '
        '${_formatTime(localDate)}';
  }

  String get iconType {
    final normalizedType =
        type.trim().toLowerCase();

    if (normalizedType.contains('leave')) {
      return 'leave';
    }

    if (normalizedType.contains('attendance') ||
        normalizedType.contains('check')) {
      return 'attendance';
    }

    if (normalizedType.contains('approval') ||
        normalizedType.contains('approved')) {
      return 'approved';
    }

    if (normalizedType.contains('reject')) {
      return 'rejected';
    }

    if (normalizedType.contains('reminder')) {
      return 'reminder';
    }

    return 'general';
  }

  AppNotification copyWith({
    int? notificationId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    int? referenceId,
    String? referenceType,
  }) {
    return AppNotification(
      notificationId:
          notificationId ?? this.notificationId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      referenceId:
          referenceId ?? this.referenceId,
      referenceType:
          referenceType ?? this.referenceType,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notification_id': notificationId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'created_at':
          createdAt?.toIso8601String(),
      'reference_id': referenceId,
      'reference_type': referenceType,
    };
  }
}

List<dynamic> _findNotificationList(
  dynamic source,
) {
  if (source is List) {
    return source;
  }

  if (source is! Map) {
    return <dynamic>[];
  }

  const preferredKeys = <String>[
    'notifications',
    'notification_list',
    'notificationList',
    'items',
    'rows',
    'records',
    'result',
    'data',
  ];

  for (final key in preferredKeys) {
    final value = source[key];

    if (value is List) {
      return value;
    }

    if (value is Map) {
      final nestedList =
          _findNotificationList(value);

      if (nestedList.isNotEmpty) {
        return nestedList;
      }
    }
  }

  for (final value in source.values) {
    if (value is List) {
      return value;
    }

    if (value is Map) {
      final nestedList =
          _findNotificationList(value);

      if (nestedList.isNotEmpty) {
        return nestedList;
      }
    }
  }

  return <dynamic>[];
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
      text == 'yes' ||
      text == 'read') {
    return true;
  }

  if (text == 'false' ||
      text == '0' ||
      text == 'no' ||
      text == 'unread') {
    return false;
  }

  return null;
}

DateTime? _readDateTime(
  dynamic source,
  List<String> keys,
) {
  final value = _findValue(
    source,
    keys,
  );

  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  final text = value.toString().trim();

  if (text.isEmpty ||
      text.toLowerCase() == 'null') {
    return null;
  }

  return DateTime.tryParse(text);
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
  Set<String> keys,
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
      final normalizedKey =
          _normalizeKey(
        entry.key.toString(),
      );

      if (keys.contains(normalizedKey)) {
        return entry.value;
      }
    }

    for (final value in source.values) {
      final foundValue =
          _findValueRecursive(
        value,
        keys,
        visited,
      );

      if (foundValue != null) {
        return foundValue;
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
      final foundValue =
          _findValueRecursive(
        value,
        keys,
        visited,
      );

      if (foundValue != null) {
        return foundValue;
      }
    }
  }

  return null;
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

String _formatTime(
  DateTime value,
) {
  final displayHour =
      value.hour % 12 == 0
          ? 12
          : value.hour % 12;

  final minute = value.minute
      .toString()
      .padLeft(2, '0');

  final period =
      value.hour >= 12 ? 'PM' : 'AM';

  return '$displayHour:$minute $period';
}

String _shortMonth(
  int month,
) {
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

  return months[month - 1];
}