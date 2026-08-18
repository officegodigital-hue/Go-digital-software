import 'package:employee_mobile/features/attendance/data/models/attendance_history_response.dart';
import 'package:employee_mobile/features/attendance/data/repositories/attendance_history_repository.dart';
import 'package:flutter/foundation.dart';

class AttendanceHistoryController extends ChangeNotifier {
  AttendanceHistoryController({
    AttendanceHistoryRepository? repository,
  }) : _repository =
            repository ?? AttendanceHistoryRepository();

  final AttendanceHistoryRepository _repository;

  AttendanceHistoryData? _historyData;
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  DateTime? _selectedDate;

  AttendanceHistoryData? get historyData =>
      _historyData;

  AttendanceHistorySummary? get summary =>
      _historyData?.summary;

  List<AttendanceHistoryRecord> get records =>
      _historyData?.records ??
      const <AttendanceHistoryRecord>[];

  HistoryEmployee? get employee =>
      _historyData?.employee;

  AttendanceHistoryFilter? get filter =>
      _historyData?.filter;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  DateTime get selectedMonth => _selectedMonth;

  DateTime? get selectedDate => _selectedDate;

  bool get hasRecords => records.isNotEmpty;

  AttendanceHistoryRecord? get selectedDateRecord {
    final selected = _selectedDate;

    if (selected == null) {
      return null;
    }

    for (final record in records) {
      final recordDate =
          record.attendanceDate?.toLocal();

      if (recordDate == null) {
        continue;
      }

      if (recordDate.year == selected.year &&
          recordDate.month == selected.month &&
          recordDate.day == selected.day) {
        return record;
      }
    }

    return null;
  }

  String get selectedMonthValue {
    final month = _selectedMonth.month
        .toString()
        .padLeft(2, '0');

    return '${_selectedMonth.year}-$month';
  }

  String get selectedMonthLabel {
    const monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${monthNames[_selectedMonth.month - 1]} '
        '${_selectedMonth.year}';
  }

  String get selectedDateLabel {
    final date = _selectedDate;

    if (date == null) {
      return 'Select Date';
    }

    return formatDate(date);
  }

  bool get canLoadNextMonth {
    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    return !_isFutureMonth(nextMonth);
  }

  Future<void> loadHistory({
    DateTime? month,
  }) async {
    if (_isLoading) {
      return;
    }

    if (month != null) {
      _selectedMonth = DateTime(
        month.year,
        month.month,
      );
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final response =
          await _repository.getAttendanceHistory(
        month: selectedMonthValue,
      );

      _historyData = response.data;
    } on AttendanceHistoryRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      debugPrint(
        'Attendance history error: $error',
      );

      _errorMessage =
          'Unable to load attendance history.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectDate(
    DateTime date,
  ) async {
    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final selectedDateMonth = DateTime(
      normalizedDate.year,
      normalizedDate.month,
    );

    final monthChanged =
        selectedDateMonth.year !=
                _selectedMonth.year ||
            selectedDateMonth.month !=
                _selectedMonth.month;

    _selectedDate = normalizedDate;

    if (monthChanged) {
      await loadHistory(
        month: selectedDateMonth,
      );

      return;
    }

    notifyListeners();
  }

  void clearSelectedDate() {
    if (_selectedDate == null) {
      return;
    }

    _selectedDate = null;
    notifyListeners();
  }

  Future<void> loadPreviousMonth() async {
    if (_isLoading) {
      return;
    }

    final previousMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    );

    _selectedDate = null;

    await loadHistory(
      month: previousMonth,
    );
  }

  Future<void> loadNextMonth() async {
    if (_isLoading) {
      return;
    }

    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    if (_isFutureMonth(nextMonth)) {
      return;
    }

    _selectedDate = null;

    await loadHistory(
      month: nextMonth,
    );
  }

  Future<void> selectMonth(
    DateTime month,
  ) async {
    final normalizedMonth = DateTime(
      month.year,
      month.month,
    );

    if (_isFutureMonth(normalizedMonth)) {
      return;
    }

    _selectedDate = null;

    await loadHistory(
      month: normalizedMonth,
    );
  }

  bool _isFutureMonth(
    DateTime month,
  ) {
    final currentMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );

    return month.isAfter(currentMonth);
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  String formatDuration(
    int? totalMinutes,
  ) {
    final safeMinutes =
        totalMinutes == null || totalMinutes < 0
            ? 0
            : totalMinutes;

    final hours = safeMinutes ~/ 60;
    final minutes = safeMinutes % 60;

    if (hours == 0) {
      return '${minutes}m';
    }

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }

  String formatStatus(
    String? status,
  ) {
    switch (status) {
      case 'present':
        return 'Present';

      case 'late':
        return 'Late';

      case 'absent':
        return 'Absent';

      case 'half_day':
        return 'Half Day';

      case 'leave':
        return 'On Leave';

      case 'work_from_home':
        return 'Work From Home';

      case 'holiday':
        return 'Holiday';

      case 'week_off':
        return 'Week Off';

      case 'incomplete':
        return 'Incomplete';

      case 'not_checked_in':
        return 'Not Checked In';

      default:
        return 'Not Available';
    }
  }

  String formatDate(
    DateTime? value,
  ) {
    if (value == null) {
      return '--';
    }

    const monthNames = <String>[
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

    final localDate = value.toLocal();

    return '${localDate.day} '
        '${monthNames[localDate.month - 1]} '
        '${localDate.year}';
  }

  String formatTime(
    DateTime? value,
  ) {
    if (value == null) {
      return '--';
    }

    final localTime = value.toLocal();

    final hour = localTime.hour % 12 == 0
        ? 12
        : localTime.hour % 12;

    final minute = localTime.minute
        .toString()
        .padLeft(2, '0');

    final period =
        localTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}