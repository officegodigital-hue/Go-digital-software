import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/admin_holiday_models.dart';
import '../../data/repositories/admin_calendar_repository.dart';

class AdminCalendarController extends ChangeNotifier {
  AdminCalendarController({
    AdminCalendarRepository? repository,
  }) : _repository =
            repository ?? AdminCalendarRepository() {
    final DateTime now = DateTime.now();

    _visibleMonth = DateTime(
      now.year,
      now.month,
    );

    _selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  final AdminCalendarRepository _repository;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isInitialized = false;
  bool _disposed = false;

  String? _errorMessage;
  String? _successMessage;

  DateTime _visibleMonth = DateTime.now();
  DateTime? _selectedDate;

  String _searchQuery = '';
  String _holidayType = 'all';
  bool _includeInactive = false;

  List<AdminHoliday> _holidays =
      const <AdminHoliday>[];

  Timer? _searchDebounce;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isDeleting => _isDeleting;

  bool get isBusy =>
      _isLoading || _isSaving || _isDeleting;

  bool get isInitialized => _isInitialized;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  bool get hasError =>
      _errorMessage != null &&
      _errorMessage!.trim().isNotEmpty;

  bool get hasSuccess =>
      _successMessage != null &&
      _successMessage!.trim().isNotEmpty;

  DateTime get visibleMonth => _visibleMonth;

  DateTime? get selectedDate => _selectedDate;

  String get searchQuery => _searchQuery;

  String get holidayType => _holidayType;

  bool get includeInactive => _includeInactive;

  List<AdminHoliday> get holidays {
    return List<AdminHoliday>.unmodifiable(
      _holidays,
    );
  }

  int get totalHolidays => _holidays.length;

  bool get isEmpty =>
      !_isLoading && _holidays.isEmpty;

  List<AdminHoliday> get selectedDateHolidays {
    final DateTime? selected = _selectedDate;

    if (selected == null) {
      return const <AdminHoliday>[];
    }

    return _holidays
        .where(
          (AdminHoliday holiday) =>
              holiday.isOnDate(selected),
        )
        .toList(growable: false);
  }

  List<AdminHoliday> get upcomingHolidays {
    final DateTime today = _dateOnly(
      DateTime.now(),
    );

    final List<AdminHoliday> result =
        _holidays.where(
      (AdminHoliday holiday) {
        return !holiday.holidayDate.isBefore(today);
      },
    ).toList(growable: true);

    result.sort(
      (
        AdminHoliday first,
        AdminHoliday second,
      ) {
        return first.holidayDate.compareTo(
          second.holidayDate,
        );
      },
    );

    return List<AdminHoliday>.unmodifiable(
      result,
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    await loadMonth();
  }

  Future<void> loadMonth() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _clearMessages(
      notify: false,
    );

    _notifySafely();

    try {
      final AdminHolidayCalendarPage result =
          await _repository.getCalendar(
        year: _visibleMonth.year,
        month: _visibleMonth.month,
        search: _searchQuery,
        holidayType: _holidayType,
        includeInactive: _includeInactive,
      );

      _holidays =
          List<AdminHoliday>.unmodifiable(
        result.holidays,
      );
    } on AdminCalendarRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage =
          'Unable to load holiday calendar: $error';
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> refresh() async {
    await loadMonth();
  }

  Future<void> goToPreviousMonth() async {
    if (_isLoading) {
      return;
    }

    _visibleMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month - 1,
    );

    _selectedDate = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );

    await loadMonth();
  }

  Future<void> goToNextMonth() async {
    if (_isLoading) {
      return;
    }

    _visibleMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
    );

    _selectedDate = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );

    await loadMonth();
  }

  Future<void> goToCurrentMonth() async {
    if (_isLoading) {
      return;
    }

    final DateTime now = DateTime.now();

    _visibleMonth = DateTime(
      now.year,
      now.month,
    );

    _selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    );

    await loadMonth();
  }

  Future<void> setVisibleMonth(
    DateTime value,
  ) async {
    final DateTime normalized = DateTime(
      value.year,
      value.month,
    );

    if (_sameMonth(
      _visibleMonth,
      normalized,
    )) {
      return;
    }

    _visibleMonth = normalized;

    _selectedDate = DateTime(
      normalized.year,
      normalized.month,
      1,
    );

    await loadMonth();
  }

  void selectDate(
    DateTime value,
  ) {
    _selectedDate = _dateOnly(value);

    _clearMessages(
      notify: false,
    );

    _notifySafely();
  }

  void updateSearchQuery(
    String value, {
    Duration debounce =
        const Duration(milliseconds: 450),
  }) {
    final String normalized =
        value.trim();

    if (_searchQuery == normalized) {
      return;
    }

    _searchQuery = normalized;

    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      debounce,
      () {
        if (_disposed) {
          return;
        }

        unawaited(loadMonth());
      },
    );

    _notifySafely();
  }

  Future<void> submitSearch(
    String value,
  ) async {
    _searchDebounce?.cancel();
    _searchQuery = value.trim();

    await loadMonth();
  }

  Future<void> clearSearch() async {
    _searchDebounce?.cancel();

    if (_searchQuery.isEmpty) {
      return;
    }

    _searchQuery = '';

    await loadMonth();
  }

  Future<void> setHolidayType(
    String value,
  ) async {
    final String normalized =
        value.trim().toLowerCase();

    final String safeValue =
        normalized.isEmpty ? 'all' : normalized;

    if (_holidayType == safeValue) {
      return;
    }

    _holidayType = safeValue;

    await loadMonth();
  }

  Future<void> setIncludeInactive(
    bool value,
  ) async {
    if (_includeInactive == value) {
      return;
    }

    _includeInactive = value;

    await loadMonth();
  }

  Future<AdminHoliday?> createHoliday({
    required String holidayName,
    required DateTime holidayDate,
    required String holidayType,
    String description = '',
    bool isActive = true,
  }) async {
    if (_isSaving) {
      return null;
    }

    _isSaving = true;
    _clearMessages(
      notify: false,
    );

    _notifySafely();

    try {
      final AdminHoliday created =
          await _repository.createHoliday(
        payload: AdminHolidayPayload(
          holidayName: holidayName,
          holidayDate: holidayDate,
          holidayType: holidayType,
          description: description,
          isActive: isActive,
        ),
      );

      _successMessage =
          'Holiday created successfully.';

      if (_sameMonth(
        holidayDate,
        _visibleMonth,
      )) {
        await _reloadAfterMutation();
      } else {
        _visibleMonth = DateTime(
          holidayDate.year,
          holidayDate.month,
        );

        _selectedDate = _dateOnly(
          holidayDate,
        );

        await _reloadAfterMutation();
      }

      return created;
    } on AdminCalendarRepositoryException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (error) {
      _errorMessage =
          'Unable to create holiday: $error';
      return null;
    } finally {
      _isSaving = false;
      _notifySafely();
    }
  }

  Future<AdminHoliday?> updateHoliday({
    required int holidayId,
    required String holidayName,
    required DateTime holidayDate,
    required String holidayType,
    String description = '',
    bool isActive = true,
  }) async {
    if (_isSaving) {
      return null;
    }

    _isSaving = true;
    _clearMessages(
      notify: false,
    );

    _notifySafely();

    try {
      final AdminHoliday updated =
          await _repository.updateHoliday(
        holidayId: holidayId,
        payload: AdminHolidayPayload(
          holidayName: holidayName,
          holidayDate: holidayDate,
          holidayType: holidayType,
          description: description,
          isActive: isActive,
        ),
      );

      _successMessage =
          'Holiday updated successfully.';

      if (!_sameMonth(
        holidayDate,
        _visibleMonth,
      )) {
        _visibleMonth = DateTime(
          holidayDate.year,
          holidayDate.month,
        );
      }

      _selectedDate = _dateOnly(
        holidayDate,
      );

      await _reloadAfterMutation();

      return updated;
    } on AdminCalendarRepositoryException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (error) {
      _errorMessage =
          'Unable to update holiday: $error';
      return null;
    } finally {
      _isSaving = false;
      _notifySafely();
    }
  }

  Future<bool> deleteHoliday({
    required int holidayId,
  }) async {
    if (_isDeleting) {
      return false;
    }

    _isDeleting = true;
    _clearMessages(
      notify: false,
    );

    _notifySafely();

    try {
      await _repository.deleteHoliday(
        holidayId: holidayId,
      );

      _successMessage =
          'Holiday deleted successfully.';

      await _reloadAfterMutation();

      return true;
    } on AdminCalendarRepositoryException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (error) {
      _errorMessage =
          'Unable to delete holiday: $error';
      return false;
    } finally {
      _isDeleting = false;
      _notifySafely();
    }
  }

  AdminHoliday? holidayById(
    int holidayId,
  ) {
    for (final AdminHoliday holiday in _holidays) {
      if (holiday.id == holidayId) {
        return holiday;
      }
    }

    return null;
  }

  List<AdminHoliday> holidaysForDate(
    DateTime value,
  ) {
    return _holidays
        .where(
          (AdminHoliday holiday) =>
              holiday.isOnDate(value),
        )
        .toList(growable: false);
  }

  bool hasHolidayOnDate(
    DateTime value,
  ) {
    return _holidays.any(
      (AdminHoliday holiday) =>
          holiday.isOnDate(value),
    );
  }

  void clearMessages({
    bool notify = true,
  }) {
    _clearMessages(
      notify: notify,
    );
  }

  Future<void> _reloadAfterMutation() async {
    final AdminHolidayCalendarPage result =
        await _repository.getCalendar(
      year: _visibleMonth.year,
      month: _visibleMonth.month,
      search: _searchQuery,
      holidayType: _holidayType,
      includeInactive: _includeInactive,
    );

    _holidays =
        List<AdminHoliday>.unmodifiable(
      result.holidays,
    );
  }

  void _clearMessages({
    required bool notify,
  }) {
    _errorMessage = null;
    _successMessage = null;

    if (notify) {
      _notifySafely();
    }
  }

  bool _sameMonth(
    DateTime first,
    DateTime second,
  ) {
    return first.year == second.year &&
        first.month == second.month;
  }

  DateTime _dateOnly(
    DateTime value,
  ) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
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
