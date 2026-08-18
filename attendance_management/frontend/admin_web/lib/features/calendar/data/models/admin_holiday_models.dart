class AdminHoliday {
  const AdminHoliday({
    required this.id,
    required this.companyId,
    required this.branchId,
    required this.holidayName,
    required this.holidayDate,
    required this.holidayType,
    required this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int companyId;
  final int branchId;

  final String holidayName;
  final DateTime holidayDate;
  final String holidayType;
  final String description;

  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminHoliday.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminHoliday(
      id: _readInt(
        json,
        const <String>[
          'id',
          'holiday_id',
          'holidayId',
        ],
      ),
      companyId: _readInt(
        json,
        const <String>[
          'company_id',
          'companyId',
        ],
      ),
      branchId: _readInt(
        json,
        const <String>[
          'branch_id',
          'branchId',
        ],
      ),
      holidayName: _readString(
        json,
        const <String>[
          'holiday_name',
          'holidayName',
          'name',
        ],
        fallback: 'Holiday',
      ),
      holidayDate: _readDateOnly(
            json,
            const <String>[
              'holiday_date',
              'holidayDate',
              'date',
            ],
          ) ??
          DateTime(1970),
      holidayType: _readString(
        json,
        const <String>[
          'holiday_type',
          'holidayType',
          'type',
        ],
        fallback: 'public',
      ).toLowerCase(),
      description: _readString(
        json,
        const <String>[
          'description',
        ],
      ),
      isActive: _readBool(
        json,
        const <String>[
          'is_active',
          'isActive',
          'active',
        ],
        fallback: true,
      ),
      createdAt: _readDateTime(
        json,
        const <String>[
          'created_at',
          'createdAt',
        ],
      ),
      updatedAt: _readDateTime(
        json,
        const <String>[
          'updated_at',
          'updatedAt',
        ],
      ),
    );
  }

  String get typeLabel {
    switch (holidayType) {
      case 'public':
        return 'Public Holiday';
      case 'optional':
        return 'Optional Holiday';
      case 'company':
        return 'Company Holiday';
      case 'regional':
        return 'Regional Holiday';
      default:
        return _titleCase(holidayType);
    }
  }

  String get dateLabel {
    const List<String> months = <String>[
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

    return '${holidayDate.day.toString().padLeft(2, '0')} '
        '${months[holidayDate.month - 1]} '
        '${holidayDate.year}';
  }

  bool isOnDate(
    DateTime value,
  ) {
    return holidayDate.year == value.year &&
        holidayDate.month == value.month &&
        holidayDate.day == value.day;
  }

  AdminHoliday copyWith({
    int? id,
    int? companyId,
    int? branchId,
    String? holidayName,
    DateTime? holidayDate,
    String? holidayType,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminHoliday(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      branchId: branchId ?? this.branchId,
      holidayName: holidayName ?? this.holidayName,
      holidayDate: holidayDate ?? this.holidayDate,
      holidayType: holidayType ?? this.holidayType,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AdminHolidayCalendarFilters {
  const AdminHolidayCalendarFilters({
    required this.year,
    required this.month,
    required this.fromDate,
    required this.toDate,
    required this.search,
    required this.holidayType,
    required this.upcoming,
    required this.includeInactive,
  });

  final int? year;
  final int? month;

  final DateTime? fromDate;
  final DateTime? toDate;

  final String search;
  final String holidayType;

  final bool upcoming;
  final bool includeInactive;

  factory AdminHolidayCalendarFilters.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminHolidayCalendarFilters(
      year: _readNullableInt(
        json,
        const <String>[
          'year',
        ],
      ),
      month: _readNullableInt(
        json,
        const <String>[
          'month',
        ],
      ),
      fromDate: _readDateOnly(
        json,
        const <String>[
          'from_date',
          'fromDate',
        ],
      ),
      toDate: _readDateOnly(
        json,
        const <String>[
          'to_date',
          'toDate',
        ],
      ),
      search: _readString(
        json,
        const <String>[
          'search',
        ],
      ),
      holidayType: _readString(
        json,
        const <String>[
          'holiday_type',
          'holidayType',
          'type',
        ],
        fallback: 'all',
      ).toLowerCase(),
      upcoming: _readBool(
        json,
        const <String>[
          'upcoming',
        ],
      ),
      includeInactive: _readBool(
        json,
        const <String>[
          'include_inactive',
          'includeInactive',
        ],
      ),
    );
  }

  static const AdminHolidayCalendarFilters empty =
      AdminHolidayCalendarFilters(
    year: null,
    month: null,
    fromDate: null,
    toDate: null,
    search: '',
    holidayType: 'all',
    upcoming: false,
    includeInactive: false,
  );
}

class AdminHolidayCalendarPage {
  const AdminHolidayCalendarPage({
    required this.holidays,
    required this.total,
    required this.filters,
  });

  final List<AdminHoliday> holidays;
  final int total;
  final AdminHolidayCalendarFilters filters;

  factory AdminHolidayCalendarPage.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawHolidays =
        json['holidays'] ??
        json['records'] ??
        json['items'];

    final List<AdminHoliday> holidays =
        rawHolidays is List
            ? rawHolidays
                .whereType<Map>()
                .map(
                  (Map item) => AdminHoliday.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
            : const <AdminHoliday>[];

    final Map<String, dynamic> filtersJson =
        _readMap(
      json,
      const <String>[
        'filters',
      ],
    );

    return AdminHolidayCalendarPage(
      holidays: holidays,
      total: _readInt(
        json,
        const <String>[
          'total',
          'total_records',
          'totalRecords',
        ],
        fallback: holidays.length,
      ),
      filters: filtersJson.isEmpty
          ? AdminHolidayCalendarFilters.empty
          : AdminHolidayCalendarFilters.fromJson(
              filtersJson,
            ),
    );
  }

  static const AdminHolidayCalendarPage empty =
      AdminHolidayCalendarPage(
    holidays: <AdminHoliday>[],
    total: 0,
    filters: AdminHolidayCalendarFilters.empty,
  );
}

class AdminHolidayPayload {
  const AdminHolidayPayload({
    required this.holidayName,
    required this.holidayDate,
    required this.holidayType,
    required this.description,
    required this.isActive,
  });

  final String holidayName;
  final DateTime holidayDate;
  final String holidayType;
  final String description;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'holiday_name': holidayName.trim(),
      'holiday_date': _formatDate(holidayDate),
      'holiday_type': holidayType.trim().toLowerCase(),
      'description': description.trim(),
      'is_active': isActive,
    };
  }
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

    final String normalized =
        value.toString().trim();

    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return fallback;
}

int _readInt(
  Map<String, dynamic> json,
  List<String> keys, {
  int fallback = 0,
}) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value != null) {
      final int? parsed =
          int.tryParse(value.toString());

      if (parsed != null) {
        return parsed;
      }
    }
  }

  return fallback;
}

int? _readNullableInt(
  Map<String, dynamic> json,
  List<String> keys,
) {
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

    final int? parsed =
        int.tryParse(value.toString());

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
      final String normalized =
          value.toString().trim().toLowerCase();

      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'active') {
        return true;
      }

      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized == 'inactive') {
        return false;
      }
    }
  }

  return fallback;
}

DateTime? _readDateOnly(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    final String normalized =
        value.toString().trim();

    final RegExpMatch? match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})',
    ).firstMatch(normalized);

    if (match == null) {
      continue;
    }

    final int? year =
        int.tryParse(match.group(1)!);

    final int? month =
        int.tryParse(match.group(2)!);

    final int? day =
        int.tryParse(match.group(3)!);

    if (year == null ||
        month == null ||
        day == null) {
      continue;
    }

    return DateTime(year, month, day);
  }

  return null;
}

DateTime? _readDateTime(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final String key in keys) {
    final dynamic value = json[key];

    if (value == null) {
      continue;
    }

    final DateTime? parsed =
        DateTime.tryParse(value.toString());

    if (parsed != null) {
      return parsed;
    }
  }

  return null;
}

Map<String, dynamic> _readMap(
  Map<String, dynamic> json,
  List<String> keys,
) {
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

String _formatDate(
  DateTime value,
) {
  final String month =
      value.month.toString().padLeft(2, '0');

  final String day =
      value.day.toString().padLeft(2, '0');

  return '${value.year}-$month-$day';
}

String _titleCase(
  String value,
) {
  final List<String> words =
      value
          .split(RegExp(r'[_\s-]+'))
          .where(
            (String word) => word.isNotEmpty,
          )
          .toList();

  if (words.isEmpty) {
    return 'Unknown';
  }

  return words
      .map(
        (String word) =>
            '${word[0].toUpperCase()}'
            '${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}