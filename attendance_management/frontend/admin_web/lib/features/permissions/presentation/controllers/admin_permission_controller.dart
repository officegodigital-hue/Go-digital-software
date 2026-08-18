import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/admin_permission_model.dart';
import '../../data/repositories/admin_permission_repository.dart';

class AdminPermissionController extends ChangeNotifier {
  AdminPermissionController({AdminPermissionRepository? repository})
    : _repository = repository ?? AdminPermissionRepository();

  final AdminPermissionRepository _repository;

  final List<AdminPermissionModel> _permissions = <AdminPermissionModel>[];

  AdminPermissionSummary _summary = AdminPermissionSummary.empty();

  AdminPermissionPagination _pagination = AdminPermissionPagination.empty();

  bool _isLoading = false;
  bool _isSummaryLoading = false;
  bool _isUpdatingStatus = false;

  String? _errorMessage;
  String? _successMessage;

  int _currentPage = 1;
  int _pageLimit = 5;

  String _searchQuery = '';
  String _selectedType = '';
  String _selectedStatus = 'pending';

  Timer? _searchDebounce;

  List<AdminPermissionModel> get permissions =>
      List<AdminPermissionModel>.unmodifiable(_permissions);

  AdminPermissionSummary get summary => _summary;

  AdminPermissionPagination get pagination => _pagination;

  bool get isLoading => _isLoading;

  bool get isSummaryLoading => _isSummaryLoading;

  bool get isUpdatingStatus => _isUpdatingStatus;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  int get currentPage => _currentPage;

  int get pageLimit => _pageLimit;

  String get searchQuery => _searchQuery;

  String get selectedType => _selectedType;

  String get selectedStatus => _selectedStatus;

  bool get hasPreviousPage => _pagination.page > 1;

  bool get hasNextPage => _pagination.page < _pagination.totalPages;

  bool get hasPermissions => _permissions.isNotEmpty;

  Future<void> initialize() async {
    await Future.wait<void>(<Future<void>>[fetchSummary(), fetchPermissions()]);
  }

  Future<void> fetchPermissions({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      final AdminPermissionListResult result = await _repository
          .getPermissionRequests(
            page: _currentPage,
            limit: _pageLimit,
            search: _searchQuery,
            type: _selectedType,
            status: _selectedStatus,
          );

      _permissions
        ..clear()
        ..addAll(result.permissions);

      _pagination = result.pagination;
      _currentPage = result.pagination.page;
    } catch (error) {
      _errorMessage = _normalizeErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSummary() async {
    _isSummaryLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _repository.getPermissionSummary();
    } catch (error) {
      _errorMessage = _normalizeErrorMessage(error);
    } finally {
      _isSummaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait<void>(<Future<void>>[
      fetchSummary(),
      fetchPermissions(showLoading: false),
    ]);
  }

  void updateSearchQuery(String value) {
    _searchQuery = value.trim();
    _currentPage = 1;

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      fetchPermissions();
    });
  }

  Future<void> updateTypeFilter(String value) async {
    if (_selectedType == value) {
      return;
    }

    _selectedType = value;
    _currentPage = 1;
    notifyListeners();

    await fetchPermissions();
  }

  Future<void> updateStatusFilter(String value) async {
    if (_selectedStatus == value) {
      return;
    }

    _selectedStatus = value;
    _currentPage = 1;
    notifyListeners();

    await fetchPermissions();
  }

  Future<void> updatePageLimit(int value) async {
    if (value <= 0 || _pageLimit == value) {
      return;
    }

    _pageLimit = value;
    _currentPage = 1;
    notifyListeners();

    await fetchPermissions();
  }

  Future<void> goToPage(int page) async {
    if (page < 1 || page > _pagination.totalPages || page == _currentPage) {
      return;
    }

    _currentPage = page;
    notifyListeners();

    await fetchPermissions();
  }

  Future<void> goToPreviousPage() async {
    if (!hasPreviousPage) {
      return;
    }

    await goToPage(_currentPage - 1);
  }

  Future<void> goToNextPage() async {
    if (!hasNextPage) {
      return;
    }

    await goToPage(_currentPage + 1);
  }

  Future<bool> approvePermission({
    required int permissionId,
    String adminRemarks = '',
  }) async {
    return _updatePermissionStatus(
      permissionId: permissionId,
      status: 'approved',
      adminRemarks: adminRemarks,
    );
  }

  Future<bool> rejectPermission({
    required int permissionId,
    required String adminRemarks,
  }) async {
    if (adminRemarks.trim().isEmpty) {
      _errorMessage = 'Remarks are required when rejecting a request.';
      notifyListeners();
      return false;
    }

    return _updatePermissionStatus(
      permissionId: permissionId,
      status: 'rejected',
      adminRemarks: adminRemarks,
    );
  }

  Future<bool> _updatePermissionStatus({
    required int permissionId,
    required String status,
    required String adminRemarks,
  }) async {
    _isUpdatingStatus = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _repository.updatePermissionStatus(
        permissionId: permissionId,
        status: status,
        adminRemarks: adminRemarks,
      );

      _successMessage = status == 'approved'
          ? 'Permission request approved successfully.'
          : 'Permission request rejected successfully.';

      if (_permissions.length == 1 && _currentPage > 1) {
        _currentPage -= 1;
      }

      await Future.wait<void>(<Future<void>>[
        fetchSummary(),
        fetchPermissions(showLoading: false),
      ]);

      return true;
    } catch (error) {
      _errorMessage = _normalizeErrorMessage(error);
      return false;
    } finally {
      _isUpdatingStatus = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  String _normalizeErrorMessage(Object error) {
    final String message = error.toString().trim();

    if (message.startsWith('Exception:')) {
      return message.substring('Exception:'.length).trim();
    }

    return message.isEmpty ? 'Something went wrong.' : message;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
