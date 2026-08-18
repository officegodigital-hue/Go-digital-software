class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final String expiresIn;
  final LoginUser user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']);
    final userJson = _asMap(data['user']);

    return LoginResponse(
      accessToken: data['access_token']?.toString() ?? '',
      tokenType: data['token_type']?.toString() ?? 'Bearer',
      expiresIn: data['expires_in']?.toString() ?? '',
      user: LoginUser.fromJson(userJson),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }
}

class LoginUser {
  const LoginUser({
    required this.userId,
    required this.employeeId,
    required this.employeeCode,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.companyName,
    required this.branchName,
    required this.departmentName,
    required this.designationName,
    required this.timezone,
    this.profileImageUrl,
  });

  final String userId;
  final String employeeId;
  final String employeeCode;
  final String role;
  final String name;
  final String email;
  final String phone;
  final String? profileImageUrl;
  final String companyName;
  final String branchName;
  final String departmentName;
  final String designationName;
  final String timezone;

  factory LoginUser.fromJson(Map<String, dynamic> json) {
    return LoginUser(
      userId: json['user_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      employeeCode: json['employee_code']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      profileImageUrl: json['profile_image_url']?.toString(),
      companyName: json['company_name']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      departmentName: json['department_name']?.toString() ?? '',
      designationName: json['designation_name']?.toString() ?? '',
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
    );
  }
}
