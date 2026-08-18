import 'package:flutter/foundation.dart';

import '../../../attendance/data/models/admin_attendance_models.dart';
import '../../../attendance/data/repositories/admin_attendance_repository.dart';

import '../../../employees/data/models/company_employee.dart';
import '../../../employees/data/repositories/company_employee_repository.dart';

import '../../../permissions/data/models/admin_permission_model.dart';
import '../../../permissions/data/repositories/admin_permission_repository.dart';

class AdminDashboardController extends ChangeNotifier {
  AdminDashboardController({
    AdminAttendanceRepository? attendanceRepository,
    CompanyEmployeeRepository? employeeRepository,
    AdminPermissionRepository? permissionRepository,
  }) : _attendanceRepository =
           attendanceRepository ?? AdminAttendanceRepository(),
       _employeeRepository = employeeRepository ?? CompanyEmployeeRepository(),
       _permissionRepository =
           permissionRepository ?? AdminPermissionRepository();

  final AdminAttendanceRepository _attendanceRepository;
  final CompanyEmployeeRepository _employeeRepository;
  final AdminPermissionRepository _permissionRepository;

  AdminAttendancePage _attendancePage = AdminAttendancePage.empty;

  AdminPermissionSummary _permissionSummary = AdminPermissionSummary.empty();

  final List<AdminPermissionModel> _pendingPermissions =
      <AdminPermissionModel>[];

  int _totalEmployees = 0;

  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;
  bool _isPermissionUpdating = false;

  String? _errorMessage;
  String? _successMessage;

  // ============================================================
  // GETTERS
  // ============================================================

  AdminAttendancePage get attendancePage {
    return _attendancePage;
  }

  AdminAttendanceSummary get attendanceSummary {
    return _attendancePage.summary;
  }

  List<AdminAttendanceRecord> get attendanceRecords {
    return List<AdminAttendanceRecord>.unmodifiable(_attendancePage.records);
  }

  List<AdminPermissionModel> get pendingPermissions {
    return List<AdminPermissionModel>.unmodifiable(_pendingPermissions);
  }

  AdminPermissionSummary get permissionSummary {
    return _permissionSummary;
  }

  DateTime get selectedDate {
    return _selectedDate;
  }

  bool get isLoading {
    return _isLoading;
  }

  bool get isPermissionUpdating {
    return _isPermissionUpdating;
  }

  bool get isBusy {
    return _isLoading || _isPermissionUpdating;
  }

  String? get errorMessage {
    return _errorMessage;
  }

  String? get successMessage {
    return _successMessage;
  }

  // ============================================================
  // DASHBOARD METRICS
  // ============================================================

  int get totalEmployees {
    return _totalEmployees;
  }

  int get presentToday {
    return attendanceSummary.presentRecords;
  }

  int get lateLogins {
    return attendanceSummary.lateRecords;
  }

  int get absentToday {
    return attendanceSummary.absentRecords;
  }

  int get permissionPending {
    return _permissionSummary.pendingRequests;
  }

  int get activeSessions {
    return attendanceSummary.activeSessions;
  }

  int get completedSessions {
    return attendanceSummary.completedSessions;
  }

  /// Current attendance API does not expose
  /// Work From Home information.
  ///
  /// Keep this at zero until backend provides
  /// an explicit work-mode / WFH field.
  int get workFromHome {
    return 0;
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    await refresh();
  }

  // ============================================================
  // REFRESH ALL DASHBOARD DATA
  // ============================================================

  Future<void> refresh() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await Future.wait<void>(<Future<void>>[
        _loadEmployees(),
        _loadAttendance(),
        _loadPermissions(),
      ]);
    } catch (error) {
      _errorMessage = _normalizeErrorMessage(error);
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // CHANGE DASHBOARD DATE
  // ============================================================

  Future<void> changeDate(DateTime date) async {
    final DateTime normalized = DateTime(date.year, date.month, date.day);

    final DateTime current = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    if (normalized == current) {
      return;
    }

    _selectedDate = normalized;

    notifyListeners();

    await loadAttendance();
  }

  // ============================================================
  // EMPLOYEES
  // ============================================================

  Future<void> _loadEmployees() async {
    final dynamic response = await _employeeRepository.getEmployees(
      page: 1,
      limit: 1,
    );

    final Map<String, dynamic>? json = _toMap(response);

    if (json == null) {
      _totalEmployees = 0;
      return;
    }

    final CompanyEmployeeListResponse result =
        CompanyEmployeeListResponse.fromJson(json);

    if (result.pagination.totalItems > 0) {
      _totalEmployees = result.pagination.totalItems;
    } else {
      _totalEmployees = result.employees.length;
    }
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  Future<void> loadAttendance() async {
    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await _loadAttendance();
    } catch (error) {
      _errorMessage = _normalizeErrorMessage(error);
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  Future<void> _loadAttendance() async {
    final AdminAttendancePage result = await _attendanceRepository
        .getAttendanceLog(
          page: 1,
          limit: 100,
          fromDate: _selectedDate,
          toDate: _selectedDate,
        );

    _attendancePage = result;
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================

  Future<void> _loadPermissions() async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _permissionRepository.getPermissionSummary(),

      _permissionRepository.getPermissionRequests(
        page: 1,
        limit: 5,
        status: 'pending',
      ),
    ]);

    _permissionSummary = results[0] as AdminPermissionSummary;

    final AdminPermissionListResult listResult =
        results[1] as AdminPermissionListResult;

    _pendingPermissions
      ..clear()
      ..addAll(listResult.permissions);
  }

  Future<void> refreshPermissions() async {
    try {
      await _loadPermissions();

      notifyListeners();
    } catch (error) {
      _errorMessage = _normalizeErrorMessage(error);

      notifyListeners();
    }
  }

  // ============================================================
  // APPROVE PERMISSION
  // ============================================================

  Future<bool> approvePermission({
    required int permissionId,
    String adminRemarks = '',
  }) async {
    if (_isPermissionUpdating) {
      return false;
    }

    _isPermissionUpdating = true;
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();

    try {
      await _permissionRepository.approvePermission(
        permissionId: permissionId,
        adminRemarks: adminRemarks,
      );

      _successMessage = 'Permission request approved successfully.';

      await _loadPermissions();

      return true;
    } catch (error) {
      _errorMessage = _normalizeErrorMessage(error);

      return false;
    } finally {
      _isPermissionUpdating = false;

      notifyListeners();
    }
  }

  // ============================================================
  // REJECT PERMISSION
  // ============================================================

  Future<bool> rejectPermission({
    required int permissionId,
    required String adminRemarks,
  }) async {
    if (_isPermissionUpdating) {
      return false;
    }

    final String remarks = adminRemarks.trim();

    if (remarks.isEmpty) {
      _errorMessage =
          'Remarks are required when rejecting a permission request.';

      notifyListeners();

      return false;
    }

    _isPermissionUpdating = true;
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();

    try {
      await _permissionRepository.rejectPermission(
        permissionId: permissionId,
        adminRemarks: remarks,
      );

      _successMessage = 'Permission request rejected successfully.';

      await _loadPermissions();

      return true;
    } catch (error) {
      _errorMessage = _normalizeErrorMessage(error);

      return false;
    } finally {
      _isPermissionUpdating = false;

      notifyListeners();
    }
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic>? _toMap(dynamic source) {
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

  String _normalizeErrorMessage(Object error) {
    final String message = error.toString().trim();

    if (message.startsWith('Exception:')) {
      return message.substring('Exception:'.length).trim();
    }

    return message.isEmpty ? 'Unable to load dashboard data.' : message;
  }

  @override
  void dispose() {
    _permissionRepository.dispose();

    super.dispose();
  }
}
