import 'package:employee_mobile/features/attendance/data/models/today_attendance_response.dart';
import 'package:employee_mobile/features/attendance/data/repositories/attendance_repository.dart';
import 'package:flutter/foundation.dart';

class AttendanceController extends ChangeNotifier {
  AttendanceController({
    AttendanceRepository? repository,
  }) : _repository = repository ?? AttendanceRepository();

  final AttendanceRepository _repository;

  TodayAttendanceResponse? _todayAttendance;

  bool _isLoading = false;
  bool _isActionLoading = false;

  String? _errorMessage;
  String? _successMessage;

  // ---------------------------------------------------------------------------
  // Main response getters
  // ---------------------------------------------------------------------------

  TodayAttendanceResponse? get todayAttendance => _todayAttendance;

  TodayAttendanceData? get todayData => _todayAttendance?.data;

  TodayAttendanceRecord? get attendance => todayData?.attendance;

  TodayEmployee? get employee => todayData?.employee;

  TodayShift? get shift => todayData?.shift;

  TodayAttendanceSummary? get summary => todayData?.summary;

  TodayBreakRecord? get currentBreak => todayData?.currentBreak;

  // ---------------------------------------------------------------------------
  // Loading and message getters
  // ---------------------------------------------------------------------------

  bool get isLoading => _isLoading;

  bool get isAttendanceLoading => _isLoading;

  bool get isActionLoading => _isActionLoading;

  bool get isBusy => _isLoading || _isActionLoading;

  bool get hasTodayData => _todayAttendance != null;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  // ---------------------------------------------------------------------------
  // Attendance time getters
  // ---------------------------------------------------------------------------

  String? get checkInTime => attendance?.checkInTime;

  String? get checkOutTime => attendance?.checkOutTime;

  String? get breakStartTime => currentBreak?.startTime;

  String? get breakEndTime => currentBreak?.endTime;

  // ---------------------------------------------------------------------------
  // Attendance state getters
  // ---------------------------------------------------------------------------

  bool get hasCheckedIn => todayData?.hasCheckedIn ?? false;

  bool get isCheckedIn => hasCheckedIn;

  bool get hasCheckedOut => todayData?.hasCheckedOut ?? false;

  bool get isCheckedOut => hasCheckedOut;

  bool get isOnBreak => todayData?.isOnBreak ?? false;

  bool get onBreak => isOnBreak;

  bool get canCheckIn {
    return todayData?.canCheckIn ?? (!hasCheckedIn && !hasCheckedOut);
  }

  bool get canStartBreak {
    return todayData?.canStartBreak ??
        (hasCheckedIn && !hasCheckedOut && !isOnBreak);
  }

  bool get canEndBreak {
    return todayData?.canEndBreak ??
        (hasCheckedIn && !hasCheckedOut && isOnBreak);
  }

  bool get canCheckOut {
    return todayData?.canCheckOut ??
        (hasCheckedIn && !hasCheckedOut && !isOnBreak);
  }

  // ---------------------------------------------------------------------------
  // Attendance summary getters
  // ---------------------------------------------------------------------------

  int get workedMinutes {
    return summary?.workedMinutes ?? attendance?.workedMinutes ?? 0;
  }

  int get breakMinutes {
    return summary?.breakMinutes ?? attendance?.breakMinutes ?? 0;
  }

  int get overtimeMinutes {
    return summary?.overtimeMinutes ?? attendance?.overtimeMinutes ?? 0;
  }

  String get workingDurationLabel => _formatMinutes(workedMinutes);

  String get totalWorkingTimeLabel => workingDurationLabel;

  String get breakDurationLabel => _formatMinutes(breakMinutes);

  String get totalBreakTimeLabel => breakDurationLabel;

  String get overtimeLabel => _formatMinutes(overtimeMinutes);

  int get overtime => overtimeMinutes;

  // ---------------------------------------------------------------------------
  // Attendance status getters
  // ---------------------------------------------------------------------------

  String get status => todayData?.status ?? 'not_checked_in';

  String get statusLabel => todayData?.statusLabel ?? 'Not Checked In';

  // ---------------------------------------------------------------------------
  // Employee and shift getters
  // ---------------------------------------------------------------------------

  String get employeeName => employee?.name ?? '';

  String get employeeCode => employee?.employeeCode ?? '';

  String get departmentName => employee?.departmentName ?? '';

  String get designationName => employee?.designationName ?? '';

  String get branchName => employee?.branchName ?? '';

  String get shiftName => shift?.name ?? '';

  String? get shiftStartTime => shift?.startTime;

  String? get shiftEndTime => shift?.endTime;

  // ---------------------------------------------------------------------------
  // Initial loading
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    await loadTodayAttendance();
  }

  Future<void> loadToday() async {
    await loadTodayAttendance();
  }

  Future<void> refresh() async {
    await loadTodayAttendance();
  }

  Future<void> loadTodayAttendance() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await _repository.getTodayAttendance();

      if (!response.success) {
        _errorMessage = response.message.trim().isEmpty
            ? 'Unable to load attendance.'
            : response.message.trim();
        return;
      }

      _todayAttendance = response;
    } on AttendanceRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Unable to load attendance: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Check In
  // ---------------------------------------------------------------------------

  Future<TodayAttendanceResponse?> checkIn({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    return _performAction(
      action: () {
        return _repository.checkIn(
          latitude: latitude,
          longitude: longitude,
          address: address,
        );
      },
      defaultSuccessMessage: 'Checked in successfully.',
    );
  }

  Future<TodayAttendanceResponse?> submitCheckIn({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    return checkIn(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  // ---------------------------------------------------------------------------
  // Start Break
  // ---------------------------------------------------------------------------

  Future<TodayAttendanceResponse?> startBreak() async {
    return _performAction(
      action: _repository.startBreak,
      defaultSuccessMessage: 'Break started successfully.',
    );
  }

  Future<TodayAttendanceResponse?> beginBreak() async {
    return startBreak();
  }

  // ---------------------------------------------------------------------------
  // End Break
  // ---------------------------------------------------------------------------

  Future<TodayAttendanceResponse?> endBreak() async {
    return _performAction(
      action: _repository.endBreak,
      defaultSuccessMessage: 'Break ended successfully.',
    );
  }

  Future<TodayAttendanceResponse?> finishBreak() async {
    return endBreak();
  }

  // ---------------------------------------------------------------------------
  // Check Out
  // ---------------------------------------------------------------------------

  Future<TodayAttendanceResponse?> checkOut({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    return _performAction(
      action: () {
        return _repository.checkOut(
          latitude: latitude,
          longitude: longitude,
          address: address,
        );
      },
      defaultSuccessMessage: 'Checked out successfully.',
    );
  }

  Future<TodayAttendanceResponse?> submitCheckOut({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    return checkOut(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared action handler
  // ---------------------------------------------------------------------------

  Future<TodayAttendanceResponse?> _performAction({
    required Future<TodayAttendanceResponse> Function() action,
    required String defaultSuccessMessage,
  }) async {
    if (_isActionLoading) {
      return null;
    }

    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;

    notifyListeners();

    try {
      final actionResponse = await action();

      if (!actionResponse.success) {
        _errorMessage = actionResponse.message.trim().isEmpty
            ? 'Attendance action failed.'
            : actionResponse.message.trim();
        return null;
      }

      final actionMessage = actionResponse.message.trim();

      _successMessage = actionMessage.isEmpty
          ? defaultSuccessMessage
          : actionMessage;

      // Keep the action response temporarily so the controller still has
      // useful state even if the refresh request fails.
      _todayAttendance = actionResponse;

      // IMPORTANT:
      // Always reload /attendance/today after a successful action.
      // This is the authoritative state used for:
      // - check-in / check-out times
      // - active break
      // - working / break / overtime minutes
      // - can_check_in / can_check_out
      // - can_start_break / can_end_break
      try {
        final refreshedResponse =
            await _repository.getTodayAttendance();

        if (refreshedResponse.success) {
          _todayAttendance = refreshedResponse;
        } else if (refreshedResponse.message.trim().isNotEmpty) {
          // Do not convert a successful action into a failed action just
          // because the follow-up refresh returned success=false.
          _errorMessage = refreshedResponse.message.trim();
        }
      } on AttendanceRepositoryException catch (error) {
        // The action already succeeded. Keep the action response and expose
        // the refresh problem without losing successful attendance state.
        _errorMessage = error.message;
      } catch (error) {
        _errorMessage = 'Unable to refresh attendance: $error';
      }

      return _todayAttendance ?? actionResponse;
    } on AttendanceRepositoryException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (error) {
      _errorMessage = 'Attendance action failed: $error';
      return null;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  void clearErrorMessage() {
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

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  String formatTime(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.trim().toLowerCase() == 'null') {
      return '-- : --';
    }

    final text = value.trim();

    DateTime? parsedDate = DateTime.tryParse(text);

    if (parsedDate != null) {
      parsedDate = parsedDate.toLocal();
      return _formatDateTimeClock(parsedDate);
    }

    final timeMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(text);

    if (timeMatch != null) {
      final hour = int.parse(timeMatch.group(1)!);
      final minute = timeMatch.group(2)!;
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      final period = hour >= 12 ? 'PM' : 'AM';

      return '$displayHour:$minute $period';
    }

    return text;
  }

  String formatCheckInTime() {
    return formatTime(checkInTime);
  }

  String formatCheckOutTime() {
    return formatTime(checkOutTime);
  }

  String _formatDateTimeClock(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0m';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '${minutes}m';
    }

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }
}
