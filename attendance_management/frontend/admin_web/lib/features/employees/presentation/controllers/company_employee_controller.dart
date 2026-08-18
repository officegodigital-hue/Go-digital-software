import 'package:flutter/foundation.dart';

import '../../data/models/company_employee.dart';
import '../../data/repositories/company_employee_repository.dart';

class CompanyEmployeeController extends ChangeNotifier {
  CompanyEmployeeController({CompanyEmployeeRepository? repository})
    : _repository = repository ?? CompanyEmployeeRepository();

  final CompanyEmployeeRepository _repository;

  final List<CompanyEmployee> _employees = <CompanyEmployee>[];

  final List<EmployeeLookupOption> _companies = <EmployeeLookupOption>[];

  final List<EmployeeLookupOption> _branches = <EmployeeLookupOption>[];

  final List<EmployeeLookupOption> _departments = <EmployeeLookupOption>[];

  final List<EmployeeLookupOption> _designations = <EmployeeLookupOption>[];

  final List<EmployeeLookupOption> _shifts = <EmployeeLookupOption>[];

  final Set<int> _busyEmployeeIds = <int>{};

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingProfileImage = false;
  bool _disposed = false;

  double _profileImageUploadProgress = 0;

  String? _errorMessage;
  String? _successMessage;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _pageSize = 20;

  String _search = '';
  String? _statusFilter;

  /*
   * These filter fields remain only for compatibility
   * with older Admin Web files.
   *
   * Company, branch and shift are fixed.
   * Department and designation are removed.
   */
  int? _companyFilterId;
  int? _branchFilterId;
  int? _departmentFilterId;
  int? _designationFilterId;
  int? _shiftFilterId;

  List<CompanyEmployee> get employees {
    return List<CompanyEmployee>.unmodifiable(_employees);
  }

  List<EmployeeLookupOption> get companies {
    return List<EmployeeLookupOption>.unmodifiable(_companies);
  }

  List<EmployeeLookupOption> get branches {
    return List<EmployeeLookupOption>.unmodifiable(_branches);
  }

  List<EmployeeLookupOption> get departments {
    return List<EmployeeLookupOption>.unmodifiable(_departments);
  }

  List<EmployeeLookupOption> get designations {
    return List<EmployeeLookupOption>.unmodifiable(_designations);
  }

  List<EmployeeLookupOption> get shifts {
    return List<EmployeeLookupOption>.unmodifiable(_shifts);
  }

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isUploadingProfileImage {
    return _isUploadingProfileImage;
  }

  double get profileImageUploadProgress {
    return _profileImageUploadProgress;
  }

  bool get isLoadingLookups => false;

  bool get hasError {
    return _errorMessage != null && _errorMessage!.trim().isNotEmpty;
  }

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  int get currentPage => _currentPage;

  int get totalPages => _totalPages;

  int get totalItems => _totalItems;

  int get pageSize => _pageSize;

  bool get hasPreviousPage {
    return _currentPage > 1;
  }

  bool get hasNextPage {
    return _currentPage < _totalPages;
  }

  String get search => _search;

  String? get statusFilter => _statusFilter;

  int? get companyFilterId => _companyFilterId;

  int? get branchFilterId => _branchFilterId;

  int? get departmentFilterId {
    return _departmentFilterId;
  }

  int? get designationFilterId {
    return _designationFilterId;
  }

  int? get shiftFilterId => _shiftFilterId;

  Future<void> initialize() async {
    clearMessages(notify: false);

    _setFixedLookupValues();

    await loadEmployees();
  }

  Future<void> loadEmployees({int? page, int? limit}) async {
    if (_isLoading) {
      return;
    }

    if (page != null && page > 0) {
      _currentPage = page;
    }

    if (limit != null && limit > 0) {
      _pageSize = limit;
    }

    _isLoading = true;
    _errorMessage = null;

    _notifySafely();

    try {
      final dynamic response = await _repository.getEmployees(
        page: _currentPage,
        limit: _pageSize,
        search: _search,
        status: _statusFilter,
      );

      final CompanyEmployeeListResponse result = _parseEmployeeListResponse(
        response,
      );

      _employees
        ..clear()
        ..addAll(result.employees);

      _currentPage = result.pagination.currentPage;

      _totalPages = result.pagination.totalPages;

      _totalItems = result.pagination.totalItems;

      _pageSize = result.pagination.pageSize;

      if (_totalPages < 1) {
        _totalPages = 1;
      }

      if (_currentPage < 1) {
        _currentPage = 1;
      }

      if (_currentPage > _totalPages) {
        _currentPage = _totalPages;
      }
    } catch (error) {
      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to load employees.',
      );
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> refreshEmployees() async {
    await loadEmployees(page: _currentPage);
  }

  Future<void> searchEmployees(String value) async {
    final String normalized = value.trim();

    if (_search == normalized && _currentPage == 1) {
      return;
    }

    _search = normalized;
    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> clearSearch() async {
    if (_search.isEmpty) {
      return;
    }

    _search = '';
    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> updateStatusFilter(String? value) async {
    _statusFilter = _normalizeNullableText(value);

    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> updateCompanyFilter(int? value) async {
    _companyFilterId = value;
    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> updateBranchFilter(int? value) async {
    _branchFilterId = value;
    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> updateDepartmentFilter(int? value) async {
    _departmentFilterId = value;
    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> updateDesignationFilter(int? value) async {
    _designationFilterId = value;
    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> updateShiftFilter(int? value) async {
    _shiftFilterId = value;
    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> clearFilters() async {
    _statusFilter = null;
    _companyFilterId = null;
    _branchFilterId = null;
    _departmentFilterId = null;
    _designationFilterId = null;
    _shiftFilterId = null;
    _currentPage = 1;

    await loadEmployees();
  }

  Future<void> goToPreviousPage() async {
    if (!hasPreviousPage || _isLoading) {
      return;
    }

    await loadEmployees(page: _currentPage - 1);
  }

  Future<void> goToNextPage() async {
    if (!hasNextPage || _isLoading) {
      return;
    }

    await loadEmployees(page: _currentPage + 1);
  }

  Future<CompanyEmployee?> loadEmployeeDetails(int employeeId) async {
    if (employeeId <= 0) {
      _errorMessage = 'A valid employee ID is required.';

      _notifySafely();

      return null;
    }

    _setEmployeeBusy(employeeId, true);

    _errorMessage = null;

    try {
      final dynamic response = await _repository.getEmployeeById(employeeId);

      final CompanyEmployee? employee = parseCompanyEmployee(response);

      if (employee == null) {
        throw StateError('Employee details were not returned by the server.');
      }

      _replaceEmployee(employee);

      return employee;
    } catch (error) {
      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to load employee details.',
      );

      return null;
    } finally {
      _setEmployeeBusy(employeeId, false);
    }
  }

  Future<CompanyEmployee?> createEmployee(
    CompanyEmployeeFormData formData,
  ) async {
    if (_isSaving) {
      return null;
    }

    final String? validationMessage = formData.validate(passwordRequired: true);

    if (validationMessage != null) {
      _errorMessage = validationMessage;

      _notifySafely();

      return null;
    }

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;

    _notifySafely();

    try {
      final dynamic response = await _repository.createEmployee(formData);

      CompanyEmployee? employee = parseCompanyEmployee(response);

      await loadEmployees(page: 1);

      employee ??= _findEmployeeByCode(formData.employeeCode);

      if (employee == null) {
        throw StateError(
          'The employee was created, but the saved record was not returned.',
        );
      }

      _successMessage = '${employee.displayName} was added successfully.';

      return employee;
    } catch (error) {
      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to add the employee.',
      );

      return null;
    } finally {
      _isSaving = false;
      _notifySafely();
    }
  }

  Future<CompanyEmployee?> updateEmployee(
    int employeeId,
    CompanyEmployeeFormData formData,
  ) async {
    if (_isSaving || employeeId <= 0) {
      return null;
    }

    final String? validationMessage = formData.validate(
      passwordRequired: false,
    );

    if (validationMessage != null) {
      _errorMessage = validationMessage;

      _notifySafely();

      return null;
    }

    _isSaving = true;

    _setEmployeeBusy(employeeId, true);

    _errorMessage = null;
    _successMessage = null;

    try {
      final dynamic response = await _repository.updateEmployee(
        employeeId,
        formData,
      );

      CompanyEmployee? employee = parseCompanyEmployee(response);

      employee ??= await _loadEmployeeDetailsDirectly(employeeId);

      if (employee == null) {
        throw StateError('The updated employee record was not returned.');
      }

      _replaceEmployee(employee);

      _successMessage = '${employee.displayName} was updated successfully.';

      return employee;
    } catch (error) {
      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to update the employee.',
      );

      return null;
    } finally {
      _isSaving = false;

      _setEmployeeBusy(employeeId, false);
    }
  }

  Future<String?> uploadEmployeeProfileImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (_isUploadingProfileImage) {
      return null;
    }

    if (bytes.isEmpty) {
      _errorMessage = 'Select a profile image to upload.';

      _notifySafely();

      return null;
    }

    _isUploadingProfileImage = true;
    _profileImageUploadProgress = 0;
    _errorMessage = null;

    _notifySafely();

    try {
      final String imageUrl = await _repository.uploadEmployeeProfileImage(
        bytes: bytes,
        fileName: fileName,
        onSendProgress: (int sent, int total) {
          if (total <= 0) {
            return;
          }

          _profileImageUploadProgress = (sent / total)
              .clamp(0.0, 1.0)
              .toDouble();

          _notifySafely();
        },
      );

      _profileImageUploadProgress = 1;

      return imageUrl;
    } catch (error) {
      _profileImageUploadProgress = 0;

      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to upload the profile image.',
      );

      return null;
    } finally {
      _isUploadingProfileImage = false;
      _notifySafely();
    }
  }

  void resetProfileImageUploadState() {
    _profileImageUploadProgress = 0;

    _notifySafely();
  }

  Future<bool> updateEmployeeStatus(
    CompanyEmployee employee, {
    required bool isActive,
  }) async {
    final int? employeeId = employee.employeeId;

    if (employeeId == null || employeeId <= 0) {
      _errorMessage = 'A valid employee ID is required.';

      _notifySafely();

      return false;
    }

    _setEmployeeBusy(employeeId, true);

    _errorMessage = null;
    _successMessage = null;

    try {
      await _repository.updateEmployeeStatus(employeeId, isActive: isActive);

      await refreshEmployees();

      _successMessage = isActive
          ? '${employee.displayName} was activated.'
          : '${employee.displayName} was deactivated.';

      return true;
    } catch (error) {
      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to update employee status.',
      );

      return false;
    } finally {
      _setEmployeeBusy(employeeId, false);
    }
  }

  Future<bool> updateEmployeeLoginStatus(
    CompanyEmployee employee, {
    required bool isLoginEnabled,
  }) async {
    final int? employeeId = employee.employeeId;

    if (employeeId == null || employeeId <= 0) {
      _errorMessage = 'A valid employee ID is required.';

      _notifySafely();

      return false;
    }

    _setEmployeeBusy(employeeId, true);

    _errorMessage = null;
    _successMessage = null;

    try {
      await _repository.updateEmployeeLoginStatus(
        employeeId,
        isLoginEnabled: isLoginEnabled,
      );

      await refreshEmployees();

      _successMessage = isLoginEnabled
          ? 'Mobile login was enabled for ${employee.displayName}.'
          : 'Mobile login was disabled for ${employee.displayName}.';

      return true;
    } catch (error) {
      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to update mobile login status.',
      );

      return false;
    } finally {
      _setEmployeeBusy(employeeId, false);
    }
  }

  Future<bool> resetEmployeePassword(
    CompanyEmployee employee, {
    required String temporaryPassword,
    required bool mustChangePassword,
  }) async {
    final int? employeeId = employee.employeeId;

    if (employeeId == null || employeeId <= 0) {
      _errorMessage = 'A valid employee ID is required.';

      _notifySafely();

      return false;
    }

    if (temporaryPassword.trim().length < 6) {
      _errorMessage =
          'The temporary password must contain at least 6 characters.';

      _notifySafely();

      return false;
    }

    _setEmployeeBusy(employeeId, true);

    _errorMessage = null;
    _successMessage = null;

    try {
      await _repository.resetEmployeePassword(
        employeeId,
        temporaryPassword: temporaryPassword.trim(),
        mustChangePassword: mustChangePassword,
      );

      _successMessage =
          'The mobile app password for ${employee.displayName} was reset.';

      return true;
    } catch (error) {
      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to reset the employee password.',
      );

      return false;
    } finally {
      _setEmployeeBusy(employeeId, false);
    }
  }

  Future<bool> deleteEmployee(CompanyEmployee employee) async {
    final int? employeeId = employee.employeeId;

    if (employeeId == null || employeeId <= 0) {
      _errorMessage = 'A valid employee ID is required.';

      _notifySafely();

      return false;
    }

    _setEmployeeBusy(employeeId, true);

    _errorMessage = null;
    _successMessage = null;

    try {
      await _repository.deleteEmployee(employeeId);

      _employees.removeWhere((CompanyEmployee item) {
        return item.employeeId == employeeId;
      });

      if (_totalItems > 0) {
        _totalItems -= 1;
      }

      if (_employees.isEmpty && _currentPage > 1) {
        await loadEmployees(page: _currentPage - 1);
      }

      _successMessage = '${employee.displayName} was deleted successfully.';

      return true;
    } catch (error) {
      _errorMessage = _friendlyError(
        error,
        fallback: 'Unable to delete the employee.',
      );

      return false;
    } finally {
      _setEmployeeBusy(employeeId, false);
    }
  }

  bool isEmployeeBusy(int? employeeId) {
    return employeeId != null && _busyEmployeeIds.contains(employeeId);
  }

  /*
   * Compatibility lookup methods.
   *
   * No backend lookup API requests are required.
   */
  Future<void> loadInitialLookups() async {
    _setFixedLookupValues();
    _notifySafely();
  }

  Future<void> loadFilterLookups({int? companyId}) async {
    _setFixedLookupValues();
    _notifySafely();
  }

  Future<void> loadBranchDependentLookups({
    int? companyId,
    int? branchId,
  }) async {
    _setFixedLookupValues();
    _notifySafely();
  }

  Future<void> loadDesignations({int? companyId, int? departmentId}) async {
    _designations.clear();
    _notifySafely();
  }

  void clearMessages({bool notify = true}) {
    _errorMessage = null;
    _successMessage = null;

    if (notify) {
      _notifySafely();
    }
  }

  void _setFixedLookupValues() {
    _companies
      ..clear()
      ..add(
        const EmployeeLookupOption(
          id: 1,
          name: fixedEmployeeCompanyName,
          code: 'GODIGITAL',
        ),
      );

    _branches
      ..clear()
      ..add(
        const EmployeeLookupOption(
          id: 1,
          name: fixedEmployeeBranchName,
          code: 'GUDUVANCHERY',
        ),
      );

    _departments.clear();
    _designations.clear();

    _shifts
      ..clear()
      ..add(
        const EmployeeLookupOption(
          id: 1,
          name: fixedEmployeeShiftName,
          code: 'GENERAL_9_TO_6',
        ),
      );
  }

  CompanyEmployeeListResponse _parseEmployeeListResponse(dynamic response) {
    final Map<String, dynamic>? json = _asStringMap(response);

    if (json != null) {
      return CompanyEmployeeListResponse.fromJson(json);
    }

    final List<CompanyEmployee> employees = parseCompanyEmployeeList(response);

    return CompanyEmployeeListResponse(
      employees: employees,
      pagination: CompanyEmployeePagination(
        currentPage: _currentPage,
        totalPages: 1,
        totalItems: employees.length,
        pageSize: _pageSize,
      ),
    );
  }

  Future<CompanyEmployee?> _loadEmployeeDetailsDirectly(int employeeId) async {
    final dynamic response = await _repository.getEmployeeById(employeeId);

    return parseCompanyEmployee(response);
  }

  void _replaceEmployee(CompanyEmployee employee) {
    final int? employeeId = employee.employeeId;

    if (employeeId == null) {
      return;
    }

    final int index = _employees.indexWhere((CompanyEmployee item) {
      return item.employeeId == employeeId;
    });

    if (index >= 0) {
      _employees[index] = employee;
    } else {
      _employees.insert(0, employee);
    }

    _notifySafely();
  }

  CompanyEmployee? _findEmployeeByCode(String employeeCode) {
    final String normalizedCode = employeeCode.trim().toLowerCase();

    for (final CompanyEmployee employee in _employees) {
      if (employee.employeeCode.trim().toLowerCase() == normalizedCode) {
        return employee;
      }
    }

    return null;
  }

  void _setEmployeeBusy(int employeeId, bool busy) {
    if (busy) {
      _busyEmployeeIds.add(employeeId);
    } else {
      _busyEmployeeIds.remove(employeeId);
    }

    _notifySafely();
  }

  String _friendlyError(Object error, {required String fallback}) {
    if (error is CompanyEmployeeRepositoryException) {
      final String message = error.message.trim();

      return message.isEmpty ? fallback : message;
    }

    final String raw = error.toString().trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return fallback;
    }

    return raw
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '')
        .trim();
  }

  String? _normalizeNullableText(String? value) {
    final String normalized = value?.trim() ?? '';

    return normalized.isEmpty ? null : normalized;
  }

  Map<String, dynamic>? _asStringMap(dynamic source) {
    if (source is Map<String, dynamic>) {
      return source;
    }

    if (source is Map) {
      return source.map<String, dynamic>((dynamic key, dynamic value) {
        return MapEntry<String, dynamic>(key.toString(), value);
      });
    }

    return null;
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
