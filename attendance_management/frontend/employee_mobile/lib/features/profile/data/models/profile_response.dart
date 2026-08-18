class ProfileResponse {
  const ProfileResponse({
    required this.success,
    required this.message,
    required this.profile,
  });

  final bool success;
  final String message;
  final EmployeeProfile? profile;

  factory ProfileResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawData =
        json['data'] ??
        json['profile'] ??
        json['employee'];

    final Map<String, dynamic>? data =
        _toStringDynamicMap(rawData);

    final Map<String, dynamic>? nestedProfile =
        data == null
            ? null
            : _toStringDynamicMap(
                data['profile'] ??
                    data['employee'] ??
                    data['user'],
              );

    final Map<String, dynamic>? profileJson =
        nestedProfile ?? data;

    return ProfileResponse(
      success: _parseBool(
        json['success'],
        fallback: true,
      ),
      message: _parseString(
        json['message'],
      ),
      profile: profileJson == null
          ? null
          : EmployeeProfile.fromJson(
              profileJson,
            ),
    );
  }
}

class EmployeeProfile {
  const EmployeeProfile({
    this.userId,
    this.employeeId,
    required this.employeeCode,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.profileImageUrl,
    this.dateOfJoining,
    this.companyId,
    required this.companyName,
    this.branchId,
    required this.branchName,
    this.departmentId,
    required this.departmentName,
    this.designationId,
    required this.designationName,
  });

  final int? userId;
  final int? employeeId;

  final String employeeCode;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String profileImageUrl;

  final DateTime? dateOfJoining;

  final int? companyId;
  final String companyName;

  final int? branchId;
  final String branchName;

  final int? departmentId;
  final String departmentName;

  final int? designationId;
  final String designationName;

  String get displayName {
    final String value = fullName.trim();

    return value.isEmpty ? 'Employee' : value;
  }

  String get initials {
    final List<String> words = displayName
        .split(RegExp(r'\s+'))
        .where(
          (String word) {
            return word.trim().isNotEmpty;
          },
        )
        .toList();

    if (words.isEmpty) {
      return 'E';
    }

    if (words.length == 1) {
      final String word = words.first;

      if (word.length == 1) {
        return word.toUpperCase();
      }

      return word
          .substring(0, 2)
          .toUpperCase();
    }

    return '${words.first[0]}${words.last[0]}'
        .toUpperCase();
  }

  String get designationLabel {
    final String value =
        designationName.trim();

    return value.isEmpty ? 'Employee' : value;
  }

  String get departmentLabel {
    final String value =
        departmentName.trim();

    return value.isEmpty
        ? 'Not assigned'
        : value;
  }

  String get branchLabel {
    final String value = branchName.trim();

    return value.isEmpty
        ? 'Not assigned'
        : value;
  }

  String get companyLabel {
    final String value = companyName.trim();

    return value.isEmpty
        ? 'Not available'
        : value;
  }

  String get joiningDateLabel {
    final DateTime? value = dateOfJoining;

    if (value == null) {
      return 'Not available';
    }

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

    final String day =
        value.day.toString().padLeft(2, '0');

    return '$day ${months[value.month - 1]} '
        '${value.year}';
  }

  factory EmployeeProfile.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmployeeProfile(
      userId: _parseInt(
        json['user_id'] ??
            json['userId'] ??
            json['id'],
      ),
      employeeId: _parseInt(
        json['employee_id'] ??
            json['employeeId'],
      ),
      employeeCode: _parseString(
        json['employee_code'] ??
            json['employeeCode'] ??
            json['code'],
      ),
      fullName: _parseString(
        json['full_name'] ??
            json['fullName'] ??
            json['name'],
      ),
      email: _parseString(
        json['email'],
      ),
      phone: _parseString(
        json['phone'] ??
            json['mobile'] ??
            json['mobile_number'] ??
            json['mobileNumber'],
      ),
      role: _parseString(
        json['role'],
        fallback: 'employee',
      ),
      profileImageUrl: _parseString(
        json['profile_image_url'] ??
            json['profileImageUrl'] ??
            json['image_url'] ??
            json['imageUrl'] ??
            json['avatar'],
      ),
      dateOfJoining: _parseDateTime(
        json['date_of_joining'] ??
            json['dateOfJoining'] ??
            json['joining_date'] ??
            json['joiningDate'],
      ),
      companyId: _parseInt(
        json['company_id'] ??
            json['companyId'],
      ),
      companyName: _parseString(
        json['company_name'] ??
            json['companyName'],
      ),
      branchId: _parseInt(
        json['branch_id'] ??
            json['branchId'],
      ),
      branchName: _parseString(
        json['branch_name'] ??
            json['branchName'],
      ),
      departmentId: _parseInt(
        json['department_id'] ??
            json['departmentId'],
      ),
      departmentName: _parseString(
        json['department_name'] ??
            json['departmentName'],
      ),
      designationId: _parseInt(
        json['designation_id'] ??
            json['designationId'],
      ),
      designationName: _parseString(
        json['designation_name'] ??
            json['designationName'],
      ),
    );
  }

  EmployeeProfile copyWith({
    int? userId,
    int? employeeId,
    String? employeeCode,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? profileImageUrl,
    DateTime? dateOfJoining,
    int? companyId,
    String? companyName,
    int? branchId,
    String? branchName,
    int? departmentId,
    String? departmentName,
    int? designationId,
    String? designationName,
  }) {
    return EmployeeProfile(
      userId: userId ?? this.userId,
      employeeId:
          employeeId ?? this.employeeId,
      employeeCode:
          employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl:
          profileImageUrl ??
          this.profileImageUrl,
      dateOfJoining:
          dateOfJoining ??
          this.dateOfJoining,
      companyId: companyId ?? this.companyId,
      companyName:
          companyName ?? this.companyName,
      branchId: branchId ?? this.branchId,
      branchName:
          branchName ?? this.branchName,
      departmentId:
          departmentId ??
          this.departmentId,
      departmentName:
          departmentName ??
          this.departmentName,
      designationId:
          designationId ??
          this.designationId,
      designationName:
          designationName ??
          this.designationName,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'employee_id': employeeId,
      'employee_code': employeeCode,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'profile_image_url':
          profileImageUrl,
      'date_of_joining':
          dateOfJoining?.toIso8601String(),
      'company_id': companyId,
      'company_name': companyName,
      'branch_id': branchId,
      'branch_name': branchName,
      'department_id': departmentId,
      'department_name': departmentName,
      'designation_id': designationId,
      'designation_name': designationName,
    };
  }
}

Map<String, dynamic>? _toStringDynamicMap(
  dynamic value,
) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map<String, dynamic>(
      (
        dynamic key,
        dynamic item,
      ) {
        return MapEntry<String, dynamic>(
          key.toString(),
          item,
        );
      },
    );
  }

  return null;
}

String _parseString(
  dynamic value, {
  String fallback = '',
}) {
  if (value == null) {
    return fallback;
  }

  final String parsed = value.toString().trim();

  return parsed.isEmpty ? fallback : parsed;
}

int? _parseInt(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
    value.toString().trim(),
  );
}

bool _parseBool(
  dynamic value, {
  required bool fallback,
}) {
  if (value == null) {
    return fallback;
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final String normalized =
      value.toString().trim().toLowerCase();

  if (<String>{
    'true',
    '1',
    'yes',
    'y',
  }.contains(normalized)) {
    return true;
  }

  if (<String>{
    'false',
    '0',
    'no',
    'n',
  }.contains(normalized)) {
    return false;
  }

  return fallback;
}

DateTime? _parseDateTime(
  dynamic value,
) {
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