const String fixedEmployeeCompanyName = 'GoDigital';
const String fixedEmployeeBranchName = 'Guduvanchery';
const String fixedEmployeeShiftName = '9:00 AM - 6:00 PM';

class CompanyEmployee {
  const CompanyEmployee({
    this.employeeId,
    this.employeeCode = '',
    this.fullName = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.username = '',
    this.role = 'Employee',
    this.profileImageUrl = '',
    this.dateOfJoining,
    this.companyId,
    this.branchId,
    this.departmentId,
    this.designationId,
    this.shiftId,
    this.companyName = fixedEmployeeCompanyName,
    this.branchName = fixedEmployeeBranchName,
    this.departmentName = '',
    this.designationName = '',
    this.shiftName = fixedEmployeeShiftName,
    this.isActive = true,
    this.mustChangePassword = false,
    this.isLoginEnabled = true,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final int? employeeId;
  final String employeeCode;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String username;

  /// Manually entered employee work role.
  ///
  /// Examples:
  /// Graphic Designer
  /// Digital Marketing Executive
  /// Developer
  /// Video Editor
  final String role;

  final String profileImageUrl;
  final DateTime? dateOfJoining;

  /// These IDs are retained for compatibility with existing files.
  /// The Admin Web form does not ask the user to select them.
  final int? companyId;
  final int? branchId;
  final int? departmentId;
  final int? designationId;
  final int? shiftId;

  final String companyName;
  final String branchName;
  final String departmentName;
  final String designationName;
  final String shiftName;

  final bool isActive;
  final bool mustChangePassword;
  final bool isLoginEnabled;
  final String status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final String normalizedFullName = fullName.trim();

    if (normalizedFullName.isNotEmpty) {
      return normalizedFullName;
    }

    final String combinedName = <String>[
      firstName.trim(),
      lastName.trim(),
    ].where((String value) => value.isNotEmpty).join(' ');

    if (combinedName.isNotEmpty) {
      return combinedName;
    }

    if (employeeCode.trim().isNotEmpty) {
      return employeeCode.trim();
    }

    return 'Employee';
  }

  String get displayRole {
    final String normalizedRole = role.trim();

    return normalizedRole.isEmpty ? 'Employee' : normalizedRole;
  }

  String get displayCompanyName {
    final String normalizedName = companyName.trim();

    return normalizedName.isEmpty
        ? fixedEmployeeCompanyName
        : normalizedName;
  }

  String get displayBranchName {
    final String normalizedName = branchName.trim();

    return normalizedName.isEmpty
        ? fixedEmployeeBranchName
        : normalizedName;
  }

  String get displayShiftName {
    final String normalizedName = shiftName.trim();

    return normalizedName.isEmpty ? fixedEmployeeShiftName : normalizedName;
  }

  bool get hasMobileLogin => username.trim().isNotEmpty;

  factory CompanyEmployee.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> company = _readNestedMap(
      json,
      const <String>[
        'company',
        'company_details',
      ],
    );

    final Map<String, dynamic> branch = _readNestedMap(
      json,
      const <String>[
        'branch',
        'branch_details',
      ],
    );

    final Map<String, dynamic> department = _readNestedMap(
      json,
      const <String>[
        'department',
        'department_details',
      ],
    );

    final Map<String, dynamic> designation = _readNestedMap(
      json,
      const <String>[
        'designation',
        'designation_details',
      ],
    );

    final Map<String, dynamic> shift = _readNestedMap(
      json,
      const <String>[
        'shift',
        'shift_details',
      ],
    );

    final Map<String, dynamic> credentials = _readNestedMap(
      json,
      const <String>[
        'credentials',
        'login_credentials',
        'employee_login',
        'user',
      ],
    );

    final String firstName = _readString(
      json,
      const <String>[
        'first_name',
        'firstName',
      ],
    );

    final String lastName = _readString(
      json,
      const <String>[
        'last_name',
        'lastName',
      ],
    );

    String fullName = _readString(
      json,
      const <String>[
        'full_name',
        'fullName',
        'employee_name',
        'employeeName',
        'name',
      ],
    );

    if (fullName.isEmpty) {
      fullName = <String>[
        firstName,
        lastName,
      ].where((String value) => value.isNotEmpty).join(' ');
    }

    final String status = _readString(
      json,
      const <String>[
        'status',
        'employee_status',
        'employeeStatus',
      ],
      fallback: 'active',
    );

    final bool isActive = _readBool(
      json,
      const <String>[
        'is_active',
        'isActive',
        'active',
        'enabled',
      ],
      fallback: _statusIsActive(status),
    );

    final String roleName = _firstNonEmptyString(
      <String>[
        _readString(
          json,
          const <String>[
            'role_name',
            'roleName',
            'employee_role',
            'employeeRole',
            'job_role',
            'jobRole',
            'position',
          ],
        ),
        _readString(
          json,
          const <String>[
            'role',
          ],
        ),
      ],
      fallback: 'Employee',
    );

    return CompanyEmployee(
      employeeId: _readInt(
        json,
        const <String>[
          'employee_id',
          'employeeId',
          'id',
          'user_id',
          'userId',
        ],
      ),
      employeeCode: _readString(
        json,
        const <String>[
          'employee_code',
          'employeeCode',
          'code',
          'staff_code',
          'staffCode',
        ],
      ),
      fullName: fullName,
      firstName: firstName,
      lastName: lastName,
      email: _readString(
        json,
        const <String>[
          'email',
          'email_address',
          'emailAddress',
          'official_email',
          'officialEmail',
        ],
      ),
      phone: _readString(
        json,
        const <String>[
          'phone',
          'mobile',
          'mobile_number',
          'mobileNumber',
          'phone_number',
          'phoneNumber',
          'contact_number',
          'contactNumber',
        ],
      ),
      username: _firstNonEmptyString(
        <String>[
          _readString(
            json,
            const <String>[
              'username',
              'mobile_username',
              'mobileUsername',
              'login_username',
              'loginUsername',
            ],
          ),
          _readString(
            credentials,
            const <String>[
              'username',
              'mobile_username',
              'mobileUsername',
              'login_username',
              'loginUsername',
            ],
          ),
        ],
      ),
      role: roleName,
      profileImageUrl: _readString(
        json,
        const <String>[
          'profile_image_url',
          'profileImageUrl',
          'profile_image',
          'profileImage',
          'avatar_url',
          'avatarUrl',
          'avatar',
          'photo_url',
          'photoUrl',
        ],
      ),
      dateOfJoining: _readDate(
        json,
        const <String>[
          'date_of_joining',
          'dateOfJoining',
          'joining_date',
          'joiningDate',
          'joined_at',
          'joinedAt',
        ],
      ),
      companyId: _firstNonNullInt(
        <int?>[
          _readInt(
            json,
            const <String>[
              'company_id',
              'companyId',
            ],
          ),
          _readInt(
            company,
            const <String>[
              'company_id',
              'companyId',
              'id',
            ],
          ),
        ],
      ),
      branchId: _firstNonNullInt(
        <int?>[
          _readInt(
            json,
            const <String>[
              'branch_id',
              'branchId',
            ],
          ),
          _readInt(
            branch,
            const <String>[
              'branch_id',
              'branchId',
              'id',
            ],
          ),
        ],
      ),
      departmentId: _firstNonNullInt(
        <int?>[
          _readInt(
            json,
            const <String>[
              'department_id',
              'departmentId',
            ],
          ),
          _readInt(
            department,
            const <String>[
              'department_id',
              'departmentId',
              'id',
            ],
          ),
        ],
      ),
      designationId: _firstNonNullInt(
        <int?>[
          _readInt(
            json,
            const <String>[
              'designation_id',
              'designationId',
            ],
          ),
          _readInt(
            designation,
            const <String>[
              'designation_id',
              'designationId',
              'id',
            ],
          ),
        ],
      ),
      shiftId: _firstNonNullInt(
        <int?>[
          _readInt(
            json,
            const <String>[
              'shift_id',
              'shiftId',
            ],
          ),
          _readInt(
            shift,
            const <String>[
              'shift_id',
              'shiftId',
              'id',
            ],
          ),
        ],
      ),
      companyName: _firstNonEmptyString(
        <String>[
          _readString(
            json,
            const <String>[
              'company_name',
              'companyName',
            ],
          ),
          _readString(
            company,
            const <String>[
              'company_name',
              'companyName',
              'name',
            ],
          ),
        ],
        fallback: fixedEmployeeCompanyName,
      ),
      branchName: _firstNonEmptyString(
        <String>[
          _readString(
            json,
            const <String>[
              'branch_name',
              'branchName',
            ],
          ),
          _readString(
            branch,
            const <String>[
              'branch_name',
              'branchName',
              'name',
            ],
          ),
        ],
        fallback: fixedEmployeeBranchName,
      ),
      departmentName: _firstNonEmptyString(
        <String>[
          _readString(
            json,
            const <String>[
              'department_name',
              'departmentName',
            ],
          ),
          _readString(
            department,
            const <String>[
              'department_name',
              'departmentName',
              'name',
            ],
          ),
        ],
      ),
      designationName: _firstNonEmptyString(
        <String>[
          _readString(
            json,
            const <String>[
              'designation_name',
              'designationName',
            ],
          ),
          _readString(
            designation,
            const <String>[
              'designation_name',
              'designationName',
              'name',
            ],
          ),
        ],
      ),
      shiftName: _firstNonEmptyString(
        <String>[
          _readString(
            json,
            const <String>[
              'shift_name',
              'shiftName',
            ],
          ),
          _readString(
            shift,
            const <String>[
              'shift_name',
              'shiftName',
              'name',
            ],
          ),
        ],
        fallback: fixedEmployeeShiftName,
      ),
      isActive: isActive,
      mustChangePassword: _firstNonNullBool(
        <bool?>[
          _readNullableBool(
            json,
            const <String>[
              'must_change_password',
              'mustChangePassword',
              'password_change_required',
              'passwordChangeRequired',
            ],
          ),
          _readNullableBool(
            credentials,
            const <String>[
              'must_change_password',
              'mustChangePassword',
              'password_change_required',
              'passwordChangeRequired',
            ],
          ),
        ],
        fallback: false,
      ),
      isLoginEnabled: _firstNonNullBool(
        <bool?>[
          _readNullableBool(
            json,
            const <String>[
              'is_login_enabled',
              'isLoginEnabled',
              'login_enabled',
              'loginEnabled',
            ],
          ),
          _readNullableBool(
            credentials,
            const <String>[
              'is_login_enabled',
              'isLoginEnabled',
              'login_enabled',
              'loginEnabled',
            ],
          ),
        ],
        fallback: true,
      ),
      status: status.isEmpty
          ? isActive
              ? 'active'
              : 'inactive'
          : status,
      createdAt: _readDate(
        json,
        const <String>[
          'created_at',
          'createdAt',
        ],
      ),
      updatedAt: _readDate(
        json,
        const <String>[
          'updated_at',
          'updatedAt',
        ],
      ),
    );
  }

  factory CompanyEmployee.fromDynamic(dynamic source) {
    if (source is CompanyEmployee) {
      return source;
    }

    final Map<String, dynamic>? json = _asStringMap(source);

    if (json == null) {
      throw const FormatException(
        'Company employee data must be a JSON object.',
      );
    }

    return CompanyEmployee.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'employee_id': employeeId,
      'employee_code': employeeCode,
      'full_name': fullName,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'username': username,
      'role_name': role,
      'employee_role': role,
      'profile_image_url': profileImageUrl,
      'date_of_joining': _dateToApi(dateOfJoining),
      'company_id': companyId,
      'branch_id': branchId,
      'department_id': departmentId,
      'designation_id': designationId,
      'shift_id': shiftId,
      'company_name': displayCompanyName,
      'branch_name': displayBranchName,
      'shift_name': displayShiftName,
      'is_active': isActive,
      'must_change_password': mustChangePassword,
      'is_login_enabled': isLoginEnabled,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CompanyEmployee copyWith({
    int? employeeId,
    String? employeeCode,
    String? fullName,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? username,
    String? role,
    String? profileImageUrl,
    DateTime? dateOfJoining,
    bool clearDateOfJoining = false,
    int? companyId,
    bool clearCompanyId = false,
    int? branchId,
    bool clearBranchId = false,
    int? departmentId,
    bool clearDepartmentId = false,
    int? designationId,
    bool clearDesignationId = false,
    int? shiftId,
    bool clearShiftId = false,
    String? companyName,
    String? branchName,
    String? departmentName,
    String? designationName,
    String? shiftName,
    bool? isActive,
    bool? mustChangePassword,
    bool? isLoginEnabled,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyEmployee(
      employeeId: employeeId ?? this.employeeId,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      dateOfJoining: clearDateOfJoining
          ? null
          : dateOfJoining ?? this.dateOfJoining,
      companyId: clearCompanyId ? null : companyId ?? this.companyId,
      branchId: clearBranchId ? null : branchId ?? this.branchId,
      departmentId: clearDepartmentId
          ? null
          : departmentId ?? this.departmentId,
      designationId: clearDesignationId
          ? null
          : designationId ?? this.designationId,
      shiftId: clearShiftId ? null : shiftId ?? this.shiftId,
      companyName: companyName ?? this.companyName,
      branchName: branchName ?? this.branchName,
      departmentName: departmentName ?? this.departmentName,
      designationName: designationName ?? this.designationName,
      shiftName: shiftName ?? this.shiftName,
      isActive: isActive ?? this.isActive,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      isLoginEnabled: isLoginEnabled ?? this.isLoginEnabled,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CompanyEmployeeFormData {
  const CompanyEmployeeFormData({
    required this.employeeCode,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.username,
    required this.temporaryPassword,
    required this.role,
    required this.profileImageUrl,
    required this.dateOfJoining,
    required this.isActive,
    required this.mustChangePassword,
    this.isLoginEnabled = true,

    /// Retained temporarily so existing UI files continue compiling
    /// until the form dialog is replaced.
    this.companyId,
    this.branchId,
    this.departmentId,
    this.designationId,
    this.shiftId,
  });

  final String employeeCode;
  final String fullName;
  final String email;
  final String phone;
  final String username;
  final String temporaryPassword;
  final String role;
  final String profileImageUrl;
  final DateTime? dateOfJoining;

  final bool isActive;
  final bool mustChangePassword;
  final bool isLoginEnabled;

  /// Compatibility-only fields.
  final int? companyId;
  final int? branchId;
  final int? departmentId;
  final int? designationId;
  final int? shiftId;

  factory CompanyEmployeeFormData.empty() {
    return const CompanyEmployeeFormData(
      employeeCode: '',
      fullName: '',
      email: '',
      phone: '',
      username: '',
      temporaryPassword: '',
      role: '',
      profileImageUrl: '',
      dateOfJoining: null,
      isActive: true,
      mustChangePassword: true,
      isLoginEnabled: true,
    );
  }

  factory CompanyEmployeeFormData.fromEmployee(
    CompanyEmployee employee,
  ) {
    return CompanyEmployeeFormData(
      employeeCode: employee.employeeCode,
      fullName: employee.displayName,
      email: employee.email,
      phone: employee.phone,
      username: employee.username,
      temporaryPassword: '',
      role: employee.displayRole,
      profileImageUrl: employee.profileImageUrl,
      dateOfJoining: employee.dateOfJoining,
      isActive: employee.isActive,
      mustChangePassword: employee.mustChangePassword,
      isLoginEnabled: employee.isLoginEnabled,
      companyId: employee.companyId,
      branchId: employee.branchId,
      departmentId: employee.departmentId,
      designationId: employee.designationId,
      shiftId: employee.shiftId,
    );
  }

  String? validate({
    bool passwordRequired = false,
  }) {
    if (employeeCode.trim().isEmpty) {
      return 'Employee code is required.';
    }

    if (fullName.trim().isEmpty) {
      return 'Employee full name is required.';
    }

    final String normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      return 'Email address is required.';
    }

    final RegExp emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!emailPattern.hasMatch(normalizedEmail)) {
      return 'Enter a valid email address.';
    }

    final String phoneDigits = phone.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (phoneDigits.length < 7 || phoneDigits.length > 15) {
      return 'Enter a valid mobile number.';
    }

    final String normalizedRole = role.trim();

    if (normalizedRole.isEmpty) {
      return 'Employee role is required.';
    }

    if (normalizedRole.length < 2 || normalizedRole.length > 100) {
      return 'Employee role must contain between 2 and 100 characters.';
    }

    if (username.trim().isEmpty) {
      return 'Mobile app username is required.';
    }

    final String normalizedPassword = temporaryPassword.trim();

    if (passwordRequired && normalizedPassword.isEmpty) {
      return 'Temporary password is required.';
    }

    if (normalizedPassword.isNotEmpty && normalizedPassword.length < 6) {
      return 'Temporary password must contain at least 6 characters.';
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    final String normalizedPassword = temporaryPassword.trim();
    final String? password = normalizedPassword.isEmpty
        ? null
        : normalizedPassword;

    return <String, dynamic>{
      'employee_code': employeeCode.trim(),
      'full_name': fullName.trim(),
      'employee_name': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'mobile': phone.trim(),
      'username': username.trim(),
      'mobile_username': username.trim(),

      /// Typeable employee work role.
      'role_name': role.trim(),
      'employee_role': role.trim(),

      'profile_image_url': profileImageUrl.trim(),
      'date_of_joining': _dateToApi(dateOfJoining),

      /// Informational fixed values.
      /// The backend selects their database IDs automatically.
      'company_name': fixedEmployeeCompanyName,
      'branch_name': fixedEmployeeBranchName,
      'shift_name': fixedEmployeeShiftName,

      'is_active': isActive,
      'status': isActive ? 'active' : 'inactive',
      'must_change_password': mustChangePassword,
      'is_login_enabled': isLoginEnabled,
      'temporary_password': password,
      'password': password,
    };
  }
}

class EmployeeLoginCredential {
  const EmployeeLoginCredential({
    this.username = '',
    this.temporaryPassword = '',
    this.mustChangePassword = false,
    this.isLoginEnabled = true,
  });

  final String username;
  final String temporaryPassword;
  final bool mustChangePassword;
  final bool isLoginEnabled;

  factory EmployeeLoginCredential.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmployeeLoginCredential(
      username: _readString(
        json,
        const <String>[
          'username',
          'mobile_username',
          'mobileUsername',
          'login_username',
          'loginUsername',
        ],
      ),
      temporaryPassword: _readString(
        json,
        const <String>[
          'temporary_password',
          'temporaryPassword',
          'password',
        ],
      ),
      mustChangePassword: _readBool(
        json,
        const <String>[
          'must_change_password',
          'mustChangePassword',
          'password_change_required',
          'passwordChangeRequired',
        ],
      ),
      isLoginEnabled: _readBool(
        json,
        const <String>[
          'is_login_enabled',
          'isLoginEnabled',
          'login_enabled',
          'loginEnabled',
          'is_active',
          'isActive',
        ],
        fallback: true,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final String normalizedPassword = temporaryPassword.trim();
    final String? password = normalizedPassword.isEmpty
        ? null
        : normalizedPassword;

    return <String, dynamic>{
      'username': username.trim(),
      'temporary_password': password,
      'password': password,
      'must_change_password': mustChangePassword,
      'is_login_enabled': isLoginEnabled,
    };
  }
}

/// Kept for compatibility with existing controller and repository files.
///
/// Employee creation no longer requires Company, Branch, Department,
/// Designation or Shift lookup dropdowns.
class EmployeeLookupOption {
  const EmployeeLookupOption({
    required this.id,
    required this.name,
    this.code = '',
    this.isActive = true,
  });

  final int id;
  final String name;
  final String code;
  final bool isActive;

  factory EmployeeLookupOption.fromJson(
    Map<String, dynamic> json,
  ) {
    final int? id = _readInt(
      json,
      const <String>[
        'id',
        'value',
        'company_id',
        'companyId',
        'branch_id',
        'branchId',
        'department_id',
        'departmentId',
        'designation_id',
        'designationId',
        'shift_id',
        'shiftId',
      ],
    );

    final String name = _readString(
      json,
      const <String>[
        'name',
        'label',
        'title',
        'company_name',
        'companyName',
        'branch_name',
        'branchName',
        'department_name',
        'departmentName',
        'designation_name',
        'designationName',
        'shift_name',
        'shiftName',
      ],
    );

    if (id == null || id <= 0) {
      throw const FormatException(
        'Lookup option ID is missing or invalid.',
      );
    }

    if (name.isEmpty) {
      throw const FormatException(
        'Lookup option name is missing.',
      );
    }

    return EmployeeLookupOption(
      id: id,
      name: name,
      code: _readString(
        json,
        const <String>[
          'code',
          'company_code',
          'companyCode',
          'branch_code',
          'branchCode',
          'department_code',
          'departmentCode',
          'designation_code',
          'designationCode',
          'shift_code',
          'shiftCode',
        ],
      ),
      isActive: _readBool(
        json,
        const <String>[
          'is_active',
          'isActive',
          'active',
          'enabled',
        ],
        fallback: true,
      ),
    );
  }

  factory EmployeeLookupOption.fromDynamic(
    dynamic source,
  ) {
    if (source is EmployeeLookupOption) {
      return source;
    }

    final Map<String, dynamic>? json = _asStringMap(source);

    if (json == null) {
      throw const FormatException(
        'Lookup option data must be a JSON object.',
      );
    }

    return EmployeeLookupOption.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'code': code,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EmployeeLookupOption &&
            other.id == id &&
            other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);
}

class CompanyEmployeePagination {
  const CompanyEmployeePagination({
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.pageSize = 20,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;

  bool get hasPreviousPage => currentPage > 1;

  bool get hasNextPage => currentPage < totalPages;

  factory CompanyEmployeePagination.fromJson(
    Map<String, dynamic> json,
  ) {
    final int currentPage = _readInt(
          json,
          const <String>[
            'current_page',
            'currentPage',
            'page',
          ],
        ) ??
        1;

    final int pageSize = _readInt(
          json,
          const <String>[
            'page_size',
            'pageSize',
            'limit',
            'per_page',
            'perPage',
          ],
        ) ??
        20;

    final int totalItems = _readInt(
          json,
          const <String>[
            'total_items',
            'totalItems',
            'total',
            'count',
          ],
        ) ??
        0;

    int totalPages = _readInt(
          json,
          const <String>[
            'total_pages',
            'totalPages',
            'pages',
            'last_page',
            'lastPage',
          ],
        ) ??
        0;

    if (totalPages <= 0 && pageSize > 0) {
      totalPages = (totalItems / pageSize).ceil();
    }

    return CompanyEmployeePagination(
      currentPage: currentPage < 1 ? 1 : currentPage,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalItems: totalItems < 0 ? 0 : totalItems,
      pageSize: pageSize < 1 ? 20 : pageSize,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'current_page': currentPage,
      'total_pages': totalPages,
      'total_items': totalItems,
      'page_size': pageSize,
    };
  }
}

class CompanyEmployeeResponse {
  const CompanyEmployeeResponse({
    required this.employee,
    this.success = true,
    this.message = '',
  });

  final CompanyEmployee? employee;
  final bool success;
  final String message;

  factory CompanyEmployeeResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawEmployee = _extractEmployeePayload(json);

    return CompanyEmployeeResponse(
      employee: _tryParseEmployee(rawEmployee),
      success: _readBool(
        json,
        const <String>[
          'success',
        ],
        fallback: true,
      ),
      message: _readString(
        json,
        const <String>[
          'message',
          'error',
        ],
      ),
    );
  }
}

class CompanyEmployeeListResponse {
  const CompanyEmployeeListResponse({
    required this.employees,
    required this.pagination,
    this.success = true,
    this.message = '',
  });

  final List<CompanyEmployee> employees;
  final CompanyEmployeePagination pagination;
  final bool success;
  final String message;

  factory CompanyEmployeeListResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawEmployees = _extractEmployeeListPayload(json);

    final Map<String, dynamic> paginationJson =
        _extractPaginationPayload(json);

    return CompanyEmployeeListResponse(
      employees: _parseEmployeeList(rawEmployees),
      pagination: CompanyEmployeePagination.fromJson(
        paginationJson.isEmpty ? json : paginationJson,
      ),
      success: _readBool(
        json,
        const <String>[
          'success',
        ],
        fallback: true,
      ),
      message: _readString(
        json,
        const <String>[
          'message',
          'error',
        ],
      ),
    );
  }
}

List<CompanyEmployee> parseCompanyEmployeeList(
  dynamic source,
) {
  if (source == null) {
    return <CompanyEmployee>[];
  }

  if (source is CompanyEmployeeListResponse) {
    return source.employees;
  }

  if (source is Iterable) {
    return _parseEmployeeList(source);
  }

  final Map<String, dynamic>? json = _asStringMap(source);

  if (json == null) {
    return <CompanyEmployee>[];
  }

  final dynamic employeeList = _extractEmployeeListPayload(json);

  if (employeeList != null) {
    return _parseEmployeeList(employeeList);
  }

  if (_looksLikeEmployee(json)) {
    return <CompanyEmployee>[
      CompanyEmployee.fromJson(json),
    ];
  }

  return <CompanyEmployee>[];
}

CompanyEmployee? parseCompanyEmployee(
  dynamic source,
) {
  if (source == null) {
    return null;
  }

  if (source is CompanyEmployee) {
    return source;
  }

  if (source is Iterable) {
    for (final dynamic item in source) {
      final CompanyEmployee? employee = _tryParseEmployee(item);

      if (employee != null) {
        return employee;
      }
    }

    return null;
  }

  final Map<String, dynamic>? json = _asStringMap(source);

  if (json == null) {
    return null;
  }

  final dynamic employeePayload = _extractEmployeePayload(json);

  return _tryParseEmployee(employeePayload);
}

List<EmployeeLookupOption> parseEmployeeLookupOptions(
  dynamic source,
) {
  if (source == null) {
    return <EmployeeLookupOption>[];
  }

  if (source is Iterable) {
    final List<EmployeeLookupOption> options = <EmployeeLookupOption>[];

    for (final dynamic item in source) {
      try {
        options.add(
          EmployeeLookupOption.fromDynamic(item),
        );
      } on FormatException {
        continue;
      }
    }

    return options;
  }

  final Map<String, dynamic>? json = _asStringMap(source);

  if (json == null) {
    return <EmployeeLookupOption>[];
  }

  final dynamic nested = _readFirstValue(
    json,
    const <String>[
      'items',
      'options',
      'records',
      'rows',
      'data',
      'result',
      'companies',
      'branches',
      'departments',
      'designations',
      'shifts',
    ],
  );

  if (nested != null && !identical(nested, source)) {
    return parseEmployeeLookupOptions(nested);
  }

  try {
    return <EmployeeLookupOption>[
      EmployeeLookupOption.fromJson(json),
    ];
  } on FormatException {
    return <EmployeeLookupOption>[];
  }
}

dynamic _extractEmployeePayload(
  Map<String, dynamic> json,
) {
  final dynamic directEmployee = _readFirstValue(
    json,
    const <String>[
      'employee',
      'record',
      'item',
    ],
  );

  if (directEmployee != null) {
    return directEmployee;
  }

  final dynamic rawData = json['data'];
  final Map<String, dynamic>? dataMap = _asStringMap(rawData);

  if (dataMap != null) {
    final dynamic nestedEmployee = _readFirstValue(
      dataMap,
      const <String>[
        'employee',
        'record',
        'item',
      ],
    );

    if (nestedEmployee != null) {
      return nestedEmployee;
    }

    if (_looksLikeEmployee(dataMap)) {
      return dataMap;
    }
  }

  if (rawData is Iterable) {
    return rawData;
  }

  final dynamic rawResult = json['result'];
  final Map<String, dynamic>? resultMap = _asStringMap(rawResult);

  if (resultMap != null) {
    final dynamic nestedEmployee = _readFirstValue(
      resultMap,
      const <String>[
        'employee',
        'record',
        'item',
      ],
    );

    if (nestedEmployee != null) {
      return nestedEmployee;
    }

    if (_looksLikeEmployee(resultMap)) {
      return resultMap;
    }
  }

  if (_looksLikeEmployee(json)) {
    return json;
  }

  return null;
}

dynamic _extractEmployeeListPayload(
  Map<String, dynamic> json,
) {
  final dynamic directList = _readFirstValue(
    json,
    const <String>[
      'employees',
      'items',
      'records',
      'rows',
    ],
  );

  if (directList != null) {
    return directList;
  }

  final dynamic rawData = json['data'];

  if (rawData is Iterable) {
    return rawData;
  }

  final Map<String, dynamic>? dataMap = _asStringMap(rawData);

  if (dataMap != null) {
    final dynamic nestedList = _readFirstValue(
      dataMap,
      const <String>[
        'employees',
        'items',
        'records',
        'rows',
      ],
    );

    if (nestedList != null) {
      return nestedList;
    }
  }

  final dynamic rawResult = json['result'];

  if (rawResult is Iterable) {
    return rawResult;
  }

  final Map<String, dynamic>? resultMap = _asStringMap(rawResult);

  if (resultMap != null) {
    return _readFirstValue(
      resultMap,
      const <String>[
        'employees',
        'items',
        'records',
        'rows',
      ],
    );
  }

  return null;
}

Map<String, dynamic> _extractPaginationPayload(
  Map<String, dynamic> json,
) {
  final Map<String, dynamic> directPagination = _readNestedMap(
    json,
    const <String>[
      'pagination',
      'meta',
      'page_info',
      'pageInfo',
    ],
  );

  if (directPagination.isNotEmpty) {
    return directPagination;
  }

  final Map<String, dynamic>? dataMap = _asStringMap(
    json['data'],
  );

  if (dataMap != null) {
    final Map<String, dynamic> dataPagination = _readNestedMap(
      dataMap,
      const <String>[
        'pagination',
        'meta',
        'page_info',
        'pageInfo',
      ],
    );

    if (dataPagination.isNotEmpty) {
      return dataPagination;
    }
  }

  final Map<String, dynamic>? resultMap = _asStringMap(
    json['result'],
  );

  if (resultMap != null) {
    return _readNestedMap(
      resultMap,
      const <String>[
        'pagination',
        'meta',
        'page_info',
        'pageInfo',
      ],
    );
  }

  return <String, dynamic>{};
}

List<CompanyEmployee> _parseEmployeeList(
  dynamic source,
) {
  if (source == null) {
    return <CompanyEmployee>[];
  }

  if (source is! Iterable) {
    final CompanyEmployee? employee = _tryParseEmployee(source);

    return employee == null
        ? <CompanyEmployee>[]
        : <CompanyEmployee>[employee];
  }

  final List<CompanyEmployee> employees = <CompanyEmployee>[];

  for (final dynamic item in source) {
    final CompanyEmployee? employee = _tryParseEmployee(item);

    if (employee != null) {
      employees.add(employee);
    }
  }

  return employees;
}

CompanyEmployee? _tryParseEmployee(
  dynamic source,
) {
  if (source == null) {
    return null;
  }

  if (source is CompanyEmployee) {
    return source;
  }

  if (source is Iterable) {
    for (final dynamic item in source) {
      final CompanyEmployee? employee = _tryParseEmployee(item);

      if (employee != null) {
        return employee;
      }
    }

    return null;
  }

  final Map<String, dynamic>? json = _asStringMap(source);

  if (json == null || !_looksLikeEmployee(json)) {
    return null;
  }

  try {
    return CompanyEmployee.fromJson(json);
  } on FormatException {
    return null;
  }
}

bool _looksLikeEmployee(
  Map<String, dynamic> json,
) {
  const Set<String> employeeKeys = <String>{
    'employee_id',
    'employeeId',
    'employee_code',
    'employeeCode',
    'full_name',
    'fullName',
    'employee_name',
    'employeeName',
    'username',
    'email',
    'phone',
    'mobile',
  };

  return employeeKeys.any(json.containsKey);
}

Map<String, dynamic> _readNestedMap(
  Map<String, dynamic> source,
  List<String> keys,
) {
  final dynamic value = _readFirstValue(
    source,
    keys,
  );

  return _asStringMap(value) ?? <String, dynamic>{};
}

dynamic _readFirstValue(
  Map<String, dynamic> source,
  List<String> keys,
) {
  for (final String key in keys) {
    if (!source.containsKey(key)) {
      continue;
    }

    final dynamic value = source[key];

    if (value != null) {
      return value;
    }
  }

  return null;
}

String _readString(
  Map<String, dynamic> source,
  List<String> keys, {
  String fallback = '',
}) {
  final dynamic value = _readFirstValue(
    source,
    keys,
  );

  if (value == null) {
    return fallback;
  }

  final String normalized = value.toString().trim();

  if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
    return fallback;
  }

  return normalized;
}

int? _readInt(
  Map<String, dynamic> source,
  List<String> keys,
) {
  final dynamic value = _readFirstValue(
    source,
    keys,
  );

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

bool _readBool(
  Map<String, dynamic> source,
  List<String> keys, {
  bool fallback = false,
}) {
  return _readNullableBool(
        source,
        keys,
      ) ??
      fallback;
}

bool? _readNullableBool(
  Map<String, dynamic> source,
  List<String> keys,
) {
  final dynamic value = _readFirstValue(
    source,
    keys,
  );

  if (value == null) {
    return null;
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final String normalized = value.toString().trim().toLowerCase();

  if (<String>{
    'true',
    '1',
    'yes',
    'y',
    'active',
    'enabled',
    'approved',
    'success',
  }.contains(normalized)) {
    return true;
  }

  if (<String>{
    'false',
    '0',
    'no',
    'n',
    'inactive',
    'disabled',
    'rejected',
    'failed',
  }.contains(normalized)) {
    return false;
  }

  return null;
}

DateTime? _readDate(
  Map<String, dynamic> source,
  List<String> keys,
) {
  final dynamic value = _readFirstValue(
    source,
    keys,
  );

  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  if (value is int) {
    final int milliseconds = value > 1000000000000
        ? value
        : value * 1000;

    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  final String normalized = value.toString().trim();

  if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
    return null;
  }

  final DateTime? isoDate = DateTime.tryParse(normalized);

  if (isoDate != null) {
    return isoDate;
  }

  final Match? match = RegExp(
    r'^(\d{2})[-/](\d{2})[-/](\d{4})$',
  ).firstMatch(normalized);

  if (match == null) {
    return null;
  }

  final int? day = int.tryParse(match.group(1) ?? '');
  final int? month = int.tryParse(match.group(2) ?? '');
  final int? year = int.tryParse(match.group(3) ?? '');

  if (day == null || month == null || year == null) {
    return null;
  }

  return DateTime(
    year,
    month,
    day,
  );
}

Map<String, dynamic>? _asStringMap(
  dynamic source,
) {
  if (source is Map<String, dynamic>) {
    return source;
  }

  if (source is Map) {
    return source.map<String, dynamic>(
      (
        dynamic key,
        dynamic value,
      ) {
        return MapEntry<String, dynamic>(
          key.toString(),
          value,
        );
      },
    );
  }

  return null;
}

String _firstNonEmptyString(
  List<String> values, {
  String fallback = '',
}) {
  for (final String value in values) {
    final String normalized = value.trim();

    if (normalized.isNotEmpty) {
      return normalized;
    }
  }

  return fallback;
}

int? _firstNonNullInt(
  List<int?> values,
) {
  for (final int? value in values) {
    if (value != null) {
      return value;
    }
  }

  return null;
}

bool _firstNonNullBool(
  List<bool?> values, {
  required bool fallback,
}) {
  for (final bool? value in values) {
    if (value != null) {
      return value;
    }
  }

  return fallback;
}

bool _statusIsActive(
  String status,
) {
  final String normalized = status.trim().toLowerCase();

  if (normalized.isEmpty) {
    return true;
  }

  return !<String>{
    'inactive',
    'disabled',
    'suspended',
    'deleted',
    'terminated',
    'rejected',
    'blocked',
  }.contains(normalized);
}

String? _dateToApi(
  DateTime? date,
) {
  if (date == null) {
    return null;
  }

  final String month = date.month.toString().padLeft(
        2,
        '0',
      );

  final String day = date.day.toString().padLeft(
        2,
        '0',
      );

  return '${date.year}-$month-$day';
} 