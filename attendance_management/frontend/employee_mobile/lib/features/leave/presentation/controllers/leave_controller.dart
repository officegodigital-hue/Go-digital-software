import 'package:employee_mobile/features/leave/data/models/apply_leave_response.dart';
import 'package:employee_mobile/features/leave/data/models/cancel_leave_response.dart';
import 'package:employee_mobile/features/leave/data/models/leave_dashboard_response.dart';
import 'package:employee_mobile/features/leave/data/models/leave_history_response.dart';
import 'package:employee_mobile/features/leave/data/repositories/leave_repository.dart';
import 'package:flutter/foundation.dart';

class LeaveController extends ChangeNotifier {
  LeaveController({
    LeaveRepository? repository,
    int? initialYear,
  })  : _repository = repository ?? LeaveRepository(),
        _selectedYear = initialYear ?? DateTime.now().year;

  final LeaveRepository _repository;

  LeaveDashboardData? _dashboardData;
  LeaveHistoryData? _historyData;

  bool _isDashboardLoading = false;
  bool _isHistoryLoading = false;
  bool _isSubmitting = false;
  bool _isCancelling = false;

  String? _errorMessage;
  String? _successMessage;

  int _selectedYear;
  String? _selectedStatus;

  LeaveDashboardData? get dashboardData {
    return _dashboardData;
  }

  LeaveHistoryData? get historyData {
    return _historyData;
  }

  LeaveEmployee? get employee {
    return _dashboardData?.employee;
  }

  LeaveRequestSummary? get requestSummary {
    return _dashboardData?.requestSummary;
  }

  List<LeaveBalance> get balances {
    return _dashboardData?.balances ?? const <LeaveBalance>[];
  }

  List<LeaveRequestRecord> get requests {
    return _historyData?.requests ?? const <LeaveRequestRecord>[];
  }

  bool get isDashboardLoading {
    return _isDashboardLoading;
  }

  bool get isHistoryLoading {
    return _isHistoryLoading;
  }

  bool get isSubmitting {
    return _isSubmitting;
  }

  bool get isCancelling {
    return _isCancelling;
  }

  bool get isBusy {
    return _isDashboardLoading ||
        _isHistoryLoading ||
        _isSubmitting ||
        _isCancelling;
  }

  bool get isInitialLoading {
    return _dashboardData == null && _isDashboardLoading;
  }

  bool get hasDashboardData {
    return _dashboardData != null;
  }

  bool get hasHistory {
    return requests.isNotEmpty;
  }

  String? get errorMessage {
    return _errorMessage;
  }

  String? get successMessage {
    return _successMessage;
  }

  int get selectedYear {
    return _selectedYear;
  }

  String? get selectedStatus {
    return _selectedStatus;
  }

  String get selectedStatusLabel {
    switch (_selectedStatus) {
      case 'pending':
        return 'Pending';

      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'cancelled':
        return 'Cancelled';

      default:
        return 'All';
    }
  }

  Future<void> initialize() async {
    await refreshAll();
  }

  Future<void> refreshAll() async {
    await Future.wait<void>(
      <Future<void>>[
        loadDashboard(),
        loadHistory(),
      ],
    );
  }

  Future<void> loadDashboard({
    int? year,
  }) async {
    if (_isDashboardLoading) {
      return;
    }

    if (year != null) {
      _selectedYear = year;
    }

    _isDashboardLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _repository.getLeaveDashboard(
        year: _selectedYear,
      );

      _dashboardData = response.data;
    } on LeaveRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      debugPrint(
        'Leave dashboard error: $error',
      );

      _errorMessage = 'Unable to load leave dashboard.';
    } finally {
      _isDashboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory({
    int? year,
    String? status,
    bool updateStatus = false,
  }) async {
    if (_isHistoryLoading) {
      return;
    }

    if (year != null) {
      _selectedYear = year;
    }

    if (updateStatus) {
      _selectedStatus = _normalizeStatus(status);
    }

    _isHistoryLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _repository.getLeaveHistory(
        year: _selectedYear,
        status: _selectedStatus,
      );

      _historyData = response.data;
    } on LeaveRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      debugPrint(
        'Leave history error: $error',
      );

      _errorMessage = 'Unable to load leave history.';
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> changeYear(
    int year,
  ) async {
    if (year < 2000 || year > 2100) {
      _errorMessage = 'Please select a valid year.';
      notifyListeners();
      return;
    }

    if (_selectedYear == year) {
      return;
    }

    _selectedYear = year;
    _errorMessage = null;

    notifyListeners();

    await refreshAll();
  }

  Future<void> changeStatus(
    String? status,
  ) async {
    final normalizedStatus = _normalizeStatus(status);

    if (_selectedStatus == normalizedStatus) {
      return;
    }

    _selectedStatus = normalizedStatus;
    _errorMessage = null;

    notifyListeners();

    await loadHistory();
  }

  Future<AppliedLeaveData?> submitLeave({
    required int leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    required String dayType,
    required String reason,
    String? attachmentUrl,
  }) async {
    if (_isSubmitting) {
      return null;
    }

    final normalizedReason = reason.trim();

    if (leaveTypeId <= 0) {
      _errorMessage = 'Please select a leave type.';
      notifyListeners();
      return null;
    }

    final normalizedStartDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final normalizedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    if (normalizedEndDate.isBefore(normalizedStartDate)) {
      _errorMessage = 'End date cannot be before start date.';
      notifyListeners();
      return null;
    }

    if (normalizedReason.length < 3) {
      _errorMessage =
          'Leave reason must contain at least 3 characters.';

      notifyListeners();
      return null;
    }

    final normalizedDayType = _normalizeDayType(dayType);

    if (normalizedDayType != 'full_day' &&
        !_isSameDate(
          normalizedStartDate,
          normalizedEndDate,
        )) {
      _errorMessage =
          'Half-day leave can only be applied for one date.';

      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();

    try {
      final response = await _repository.applyLeave(
        leaveTypeId: leaveTypeId,
        startDate: formatApiDate(normalizedStartDate),
        endDate: formatApiDate(normalizedEndDate),
        dayType: normalizedDayType,
        reason: normalizedReason,
        attachmentUrl: _normalizeOptionalText(
          attachmentUrl,
        ),
      );

      _successMessage = response.message;

      await refreshAll();

      return response.data;
    } on LeaveRepositoryException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (error) {
      debugPrint(
        'Apply leave error: $error',
      );

      _errorMessage = 'Unable to submit leave request.';

      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<CancelledLeaveData?> cancelLeave({
    required int leaveRequestId,
    required String cancellationReason,
  }) async {
    if (_isCancelling) {
      return null;
    }

    final normalizedReason = cancellationReason.trim();

    if (leaveRequestId <= 0) {
      _errorMessage = 'Invalid leave request.';
      notifyListeners();
      return null;
    }

    if (normalizedReason.length < 3) {
      _errorMessage =
          'Cancellation reason must contain at least 3 characters.';

      notifyListeners();
      return null;
    }

    _isCancelling = true;
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();

    try {
      final response = await _repository.cancelLeave(
        leaveRequestId: leaveRequestId,
        cancellationReason: normalizedReason,
      );

      _successMessage = response.message;

      await refreshAll();

      return response.data;
    } on LeaveRepositoryException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (error) {
      debugPrint(
        'Cancel leave error: $error',
      );

      _errorMessage = 'Unable to cancel leave request.';

      return null;
    } finally {
      _isCancelling = false;
      notifyListeners();
    }
  }

  LeaveBalance? findBalanceByLeaveTypeId(
    int leaveTypeId,
  ) {
    for (final balance in balances) {
      if (balance.leaveTypeId == leaveTypeId) {
        return balance;
      }
    }

    return null;
  }

  LeaveRequestRecord? findRequestById(
    int leaveRequestId,
  ) {
    for (final request in requests) {
      if (request.leaveRequestId == leaveRequestId) {
        return request;
      }
    }

    return null;
  }

  List<LeaveRequestRecord> get pendingRequests {
    return requests
        .where(
          (request) => request.status == 'pending',
        )
        .toList();
  }

  List<LeaveRequestRecord> get approvedRequests {
    return requests
        .where(
          (request) => request.status == 'approved',
        )
        .toList();
  }

  List<LeaveRequestRecord> get rejectedRequests {
    return requests
        .where(
          (request) => request.status == 'rejected',
        )
        .toList();
  }

  List<LeaveRequestRecord> get cancelledRequests {
    return requests
        .where(
          (request) => request.status == 'cancelled',
        )
        .toList();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  void clearSuccessMessage() {
    if (_successMessage == null) {
      return;
    }

    _successMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    if (_errorMessage == null && _successMessage == null) {
      return;
    }

    _errorMessage = null;
    _successMessage = null;

    notifyListeners();
  }

  String formatApiDate(
    DateTime value,
  ) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }

  String formatDisplayDate(
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

    return '${value.day} '
        '${months[value.month - 1]} '
        '${value.year}';
  }

  String formatDays(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  String formatStatus(
    String status,
  ) {
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

  String formatDayType(
    String dayType,
  ) {
    switch (dayType) {
      case 'first_half':
        return 'First Half';

      case 'second_half':
        return 'Second Half';

      default:
        return 'Full Day';
    }
  }

  String? _normalizeStatus(
    String? status,
  ) {
    final normalized = status?.trim().toLowerCase();

    if (normalized == null ||
        normalized.isEmpty ||
        normalized == 'all') {
      return null;
    }

    const validStatuses = <String>{
      'pending',
      'approved',
      'rejected',
      'cancelled',
    };

    if (!validStatuses.contains(normalized)) {
      return null;
    }

    return normalized;
  }

  String _normalizeDayType(
    String value,
  ) {
    final normalized = value.trim().toLowerCase();

    const validDayTypes = <String>{
      'full_day',
      'first_half',
      'second_half',
    };

    if (!validDayTypes.contains(normalized)) {
      return 'full_day';
    }

    return normalized;
  }

  String? _normalizeOptionalText(
    String? value,
  ) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  bool _isSameDate(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}