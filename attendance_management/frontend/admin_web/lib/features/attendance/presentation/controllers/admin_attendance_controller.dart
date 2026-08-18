import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/admin_attendance_models.dart';
import '../../data/repositories/admin_attendance_repository.dart';

class AdminAttendanceController extends ChangeNotifier {
  AdminAttendanceController({AdminAttendanceRepository? repository})
    : _repository = repository ?? AdminAttendanceRepository() {
    final DateTime today = DateTime.now();

    _fromDate = DateTime(today.year, today.month, 1);

    _toDate = DateTime(today.year, today.month, today.day);
  }

  final AdminAttendanceRepository _repository;

  static const int defaultPageSize = 20;

  bool _isLoading = false;
  bool _isExporting = false;
  bool _isInitialized = false;
  bool _disposed = false;

  String? _errorMessage;

  List<AdminAttendanceRecord> _records = const <AdminAttendanceRecord>[];

  AdminAttendanceSummary _summary = AdminAttendanceSummary.empty;

  AdminAttendancePagination _pagination = AdminAttendancePagination.empty;

  DateTime? _fromDate;
  DateTime? _toDate;

  String _searchQuery = '';
  String _attendanceStatus = 'all';
  String _sessionStatus = 'all';

  int _pageSize = defaultPageSize;

  Timer? _searchDebounce;

  bool get isLoading => _isLoading;

  bool get isExporting => _isExporting;

  bool get isInitialized => _isInitialized;

  String? get errorMessage => _errorMessage;

  bool get hasError =>
      _errorMessage != null && _errorMessage!.trim().isNotEmpty;

  List<AdminAttendanceRecord> get records {
    return List<AdminAttendanceRecord>.unmodifiable(_records);
  }

  AdminAttendanceSummary get summary => _summary;

  AdminAttendancePagination get pagination => _pagination;

  DateTime? get fromDate => _fromDate;

  DateTime? get toDate => _toDate;

  String get searchQuery => _searchQuery;

  String get attendanceStatus => _attendanceStatus;

  String get sessionStatus => _sessionStatus;

  int get pageSize => _pageSize;

  int get currentPage => _pagination.currentPage;

  int get totalPages => _pagination.totalPages;

  int get totalItems => _pagination.totalItems;

  bool get hasPreviousPage => _pagination.hasPreviousPage;

  bool get hasNextPage => _pagination.hasNextPage;

  bool get isEmpty => !_isLoading && _records.isEmpty;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    await loadPage(page: 1);
  }

  Future<void> refresh() async {
    await loadPage(page: currentPage);
  }

  Future<void> loadFirstPage() async {
    await loadPage(page: 1);
  }

  Future<void> loadPage({required int page}) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    _notifySafely();

    try {
      final AdminAttendancePage result = await _repository.getAttendanceLog(
        page: page,
        limit: _pageSize,
        fromDate: _fromDate,
        toDate: _toDate,
        search: _searchQuery,
        status: _attendanceStatus,
        sessionStatus: _sessionStatus,
      );

      _records = List<AdminAttendanceRecord>.unmodifiable(result.records);

      _summary = result.summary;
      _pagination = result.pagination;
    } on AdminAttendanceRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Unable to load attendance records: $error';
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> goToPreviousPage() async {
    if (_isLoading || !_pagination.hasPreviousPage) {
      return;
    }

    await loadPage(page: _pagination.currentPage - 1);
  }

  Future<void> goToNextPage() async {
    if (_isLoading || !_pagination.hasNextPage) {
      return;
    }

    await loadPage(page: _pagination.currentPage + 1);
  }

  Future<void> goToPage(int page) async {
    if (_isLoading) {
      return;
    }

    final int safePage = page.clamp(1, _pagination.totalPages).toInt();

    if (safePage == _pagination.currentPage) {
      return;
    }

    await loadPage(page: safePage);
  }

  Future<void> setDateRange({
    required DateTime? fromDate,
    required DateTime? toDate,
  }) async {
    if (fromDate != null &&
        toDate != null &&
        _dateOnly(fromDate).isAfter(_dateOnly(toDate))) {
      _errorMessage = 'The start date cannot be after the end date.';

      _notifySafely();
      return;
    }

    _fromDate = fromDate == null ? null : _dateOnly(fromDate);

    _toDate = toDate == null ? null : _dateOnly(toDate);

    await loadFirstPage();
  }

  Future<void> clearDateRange() async {
    _fromDate = null;
    _toDate = null;

    await loadFirstPage();
  }

  void updateSearchQuery(
    String value, {
    Duration debounce = const Duration(milliseconds: 450),
  }) {
    final String normalized = value.trim();

    if (_searchQuery == normalized) {
      return;
    }

    _searchQuery = normalized;

    _searchDebounce?.cancel();

    _searchDebounce = Timer(debounce, () {
      if (_disposed) {
        return;
      }

      unawaited(loadFirstPage());
    });

    _notifySafely();
  }

  Future<void> submitSearch(String value) async {
    _searchDebounce?.cancel();
    _searchQuery = value.trim();

    await loadFirstPage();
  }

  Future<void> clearSearch() async {
    _searchDebounce?.cancel();

    if (_searchQuery.isEmpty) {
      return;
    }

    _searchQuery = '';

    await loadFirstPage();
  }

  Future<void> setAttendanceStatus(String value) async {
    final String normalized = _normalizeFilterValue(value);

    if (_attendanceStatus == normalized) {
      return;
    }

    _attendanceStatus = normalized;

    await loadFirstPage();
  }

  Future<void> setSessionStatus(String value) async {
    final String normalized = _normalizeFilterValue(value);

    if (_sessionStatus == normalized) {
      return;
    }

    _sessionStatus = normalized;

    await loadFirstPage();
  }

  Future<void> setPageSize(int value) async {
    if (value <= 0 || value > 100 || value == _pageSize) {
      return;
    }

    _pageSize = value;

    await loadFirstPage();
  }

  Future<void> resetFilters() async {
    final DateTime today = DateTime.now();

    _searchDebounce?.cancel();

    _searchQuery = '';
    _attendanceStatus = 'all';
    _sessionStatus = 'all';
    _pageSize = defaultPageSize;

    _fromDate = DateTime(today.year, today.month, 1);

    _toDate = DateTime(today.year, today.month, today.day);

    await loadFirstPage();
  }

  Future<List<AdminAttendanceRecord>> loadExportRecords() async {
    if (_isExporting) {
      return const <AdminAttendanceRecord>[];
    }

    _isExporting = true;
    _errorMessage = null;

    _notifySafely();

    try {
      return await _repository.getAttendanceExportRecords(
        fromDate: _fromDate,
        toDate: _toDate,
        search: _searchQuery,
        status: _attendanceStatus,
        sessionStatus: _sessionStatus,
      );
    } on AdminAttendanceRepositoryException catch (error) {
      _errorMessage = error.message;

      return const <AdminAttendanceRecord>[];
    } catch (error) {
      _errorMessage = 'Unable to prepare attendance export: $error';

      return const <AdminAttendanceRecord>[];
    } finally {
      _isExporting = false;
      _notifySafely();
    }
  }

  void clearError({bool notify = true}) {
    _errorMessage = null;

    if (notify) {
      _notifySafely();
    }
  }

  String _normalizeFilterValue(String value) {
    final String normalized = value.trim().toLowerCase();

    return normalized.isEmpty ? 'all' : normalized;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    super.dispose();
  }
}
