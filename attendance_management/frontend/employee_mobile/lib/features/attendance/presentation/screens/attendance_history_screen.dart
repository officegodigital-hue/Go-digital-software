import 'package:dio/dio.dart';
import 'package:employee_mobile/core/network/api_client.dart';
import 'package:employee_mobile/features/leave/presentation/controllers/leave_controller.dart';
import 'package:employee_mobile/features/leave/presentation/screens/leave_dashboard_screen.dart';
import 'package:employee_mobile/features/notifications/presentation/screens/notification_screen.dart';
import 'package:employee_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() {
    return _AttendanceHistoryScreenState();
  }
}

enum _AttendanceViewMode { weekly, monthly }

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  static const Color _primaryBlue = Color(0xFF0867DB);
  static const Color _darkText = Color(0xFF102A4C);
  static const Color _mutedText = Color(0xFF667085);
  static const Color _borderColor = Color(0xFFDCE3EE);
  static const Color _pageBackground = Color(0xFFFFFFFF);

  late final Dio _dio;
  late final LeaveController _leaveController;

  _AttendanceViewMode _viewMode = _AttendanceViewMode.weekly;

  bool _isLoading = false;
  String? _errorMessage;

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime? _selectedDate;

  List<_AttendanceRecord> _records = <_AttendanceRecord>[];

  @override
  void initState() {
    super.initState();

    _dio = ApiClient.instance.dio;
    _leaveController = LeaveController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendanceHistory();
    });
  }

  @override
  void dispose() {
    _leaveController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceHistory() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _getHistoryResponse();

      _validateResponse(response.data);

      final records = _parseAttendanceRecords(response.data);

      records.sort((_AttendanceRecord first, _AttendanceRecord second) {
        return second.date.compareTo(first.date);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
      });
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _getDioErrorMessage(error);
      });
    } on _AttendanceException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load attendance history: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Response<dynamic>> _getHistoryResponse() async {
    final monthValue = _formatApiMonth(_focusedMonth);

    const endpoints = <String>[
      '/attendance/history',
      '/attendance/my-history',
      '/attendance/records',
    ];

    DioException? lastError;

    for (final endpoint in endpoints) {
      try {
        return await _dio.get<dynamic>(
          endpoint,
          queryParameters: <String, dynamic>{
            // The backend requires this exact format: YYYY-MM.
            'month': monthValue,
          },
        );
      } on DioException catch (error) {
        lastError = error;

        final statusCode = error.response?.statusCode;

        if (statusCode == 404 || statusCode == 405) {
          continue;
        }

        rethrow;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw const _AttendanceException(
      'Attendance history endpoint is unavailable.',
    );
  }

  void _validateResponse(dynamic responseData) {
    if (responseData is! Map) {
      return;
    }

    final success = responseData['success'];

    final failed =
        success == false ||
        success == 0 ||
        success?.toString().trim().toLowerCase() == 'false';

    if (!failed) {
      return;
    }

    throw _AttendanceException(
      _extractApiMessage(responseData) ?? 'Unable to load attendance history.',
    );
  }

  List<_AttendanceRecord> _parseAttendanceRecords(dynamic responseData) {
    final rawRecords = _findAttendanceList(responseData);

    final parsedRecords = <_AttendanceRecord>[];

    for (final item in rawRecords) {
      if (item is! Map) {
        continue;
      }

      final json = item.map<String, dynamic>((dynamic key, dynamic value) {
        return MapEntry<String, dynamic>(key.toString(), value);
      });

      final record = _AttendanceRecord.fromJson(json);

      if (record.hasValidDate) {
        parsedRecords.add(record);
      }
    }

    return parsedRecords;
  }

  List<dynamic> _findAttendanceList(dynamic source) {
    if (source is List) {
      return source;
    }

    if (source is! Map) {
      return <dynamic>[];
    }

    const preferredKeys = <String>[
      'records',
      'attendance_records',
      'attendanceRecords',
      'history',
      'attendance_history',
      'attendanceHistory',
      'items',
      'rows',
      'result',
      'data',
    ];

    for (final key in preferredKeys) {
      final value = source[key];

      if (value is List) {
        return value;
      }

      if (value is Map) {
        final nestedRecords = _findAttendanceList(value);

        if (nestedRecords.isNotEmpty) {
          return nestedRecords;
        }
      }
    }

    for (final value in source.values) {
      if (value is List && value.isNotEmpty && value.first is Map) {
        final firstRecord = value.first as Map<dynamic, dynamic>;

        if (_looksLikeAttendanceRecord(firstRecord)) {
          return value;
        }
      }

      if (value is Map) {
        final nestedRecords = _findAttendanceList(value);

        if (nestedRecords.isNotEmpty) {
          return nestedRecords;
        }
      }
    }

    return <dynamic>[];
  }

  bool _looksLikeAttendanceRecord(Map<dynamic, dynamic> json) {
    final keys = json.keys.map((dynamic key) {
      return _normalizeKey(key.toString());
    }).toSet();

    const attendanceKeys = <String>{
      'attendancedate',
      'workdate',
      'date',
      'checkintime',
      'checkouttime',
      'workedminutes',
      'workingminutes',
      'attendancestatus',
    };

    return keys.any(attendanceKeys.contains);
  }

  List<_AttendanceRecord> get _visibleRecords {
    Iterable<_AttendanceRecord> result = _records.where((
      _AttendanceRecord record,
    ) {
      return record.date.year == _focusedMonth.year &&
          record.date.month == _focusedMonth.month;
    });

    final selectedDate = _selectedDate;

    if (selectedDate != null) {
      result = result.where((_AttendanceRecord record) {
        return _isSameDate(record.date, selectedDate);
      });

      return result.toList();
    }

    if (_viewMode == _AttendanceViewMode.monthly) {
      return result.toList();
    }

    final monthRecords = result.toList();

    if (monthRecords.isEmpty) {
      return <_AttendanceRecord>[];
    }

    final now = DateTime.now();

    final isCurrentMonth =
        now.year == _focusedMonth.year && now.month == _focusedMonth.month;

    final anchorDate = isCurrentMonth ? now : monthRecords.first.date;

    final normalizedAnchor = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
    );

    final weekStart = normalizedAnchor.subtract(
      Duration(days: normalizedAnchor.weekday - DateTime.monday),
    );

    final weekEnd = weekStart.add(const Duration(days: 7));

    return monthRecords.where((_AttendanceRecord record) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );

      return !recordDate.isBefore(weekStart) && recordDate.isBefore(weekEnd);
    }).toList();
  }

  Future<void> _changeMonth(int monthDifference) async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + monthDifference,
      );

      _selectedDate = null;
    });

    await _loadAttendanceHistory();
  }

  Future<void> _selectAttendanceDate() async {
    final initialDate =
        _selectedDate ?? DateTime(_focusedMonth.year, _focusedMonth.month, 1);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select Attendance Date',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final monthChanged =
        selectedDate.year != _focusedMonth.year ||
        selectedDate.month != _focusedMonth.month;

    setState(() {
      _selectedDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      _focusedMonth = DateTime(selectedDate.year, selectedDate.month);
    });

    if (monthChanged) {
      await _loadAttendanceHistory();
    }
  }

  void _clearSelectedDate() {
    setState(() {
      _selectedDate = null;
    });
  }

  Future<void> _openLeaveDashboard() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LeaveDashboardScreen(controller: _leaveController);
        },
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const NotificationScreen();
        },
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const ProfileScreen();
        },
      ),
    );
  }

  Future<void> _handleBottomNavigation(int index) async {
    switch (index) {
      case 0:
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;

      case 1:
        // Already on the Attendance screen.
        break;

      case 2:
        await _openLeaveDashboard();
        break;

      case 3:
        await _openNotifications();
        break;

      case 4:
        await _openProfile();
        break;
    }
  }

  String _getDioErrorMessage(DioException error) {
    final apiMessage = _extractApiMessage(error.response?.data);

    if (apiMessage != null && apiMessage.trim().isNotEmpty) {
      return apiMessage;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Attendance request timed out.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the attendance server.';

      case DioExceptionType.cancel:
        return 'Attendance request was cancelled.';

      case DioExceptionType.badResponse:
        return 'Attendance request failed with status '
            '${error.response?.statusCode ?? 'unknown'}.';

      default:
        return error.message ?? 'Unable to load attendance history.';
    }
  }

  String? _extractApiMessage(dynamic source) {
    if (source is! Map) {
      return null;
    }

    final message = source['message'] ?? source['error'] ?? source['details'];

    if (message == null || message is Map || message is List) {
      return null;
    }

    final text = message.toString().trim();

    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final records = _visibleRecords;

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadAttendanceHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            _buildViewSelector(),
            const SizedBox(height: 18),
            _buildMonthSelector(),
            const SizedBox(height: 18),
            _buildDateSelector(),
            const SizedBox(height: 20),
            _buildHistoryHeading(records.length),
            const SizedBox(height: 10),
            if (_isLoading)
              _buildLoadingState()
            else if (_errorMessage != null)
              _buildErrorState()
            else if (records.isEmpty)
              _buildEmptyState()
            else
              ...records.map(_buildAttendanceCard),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () {
          Navigator.of(context).maybePop();
        },
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _primaryBlue,
          size: 19,
        ),
      ),
      titleSpacing: 0,
      title: const Text(
        'Attendance',
        style: TextStyle(
          color: Color(0xFF0757B8),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'Select date',
          onPressed: _selectAttendanceDate,
          icon: const Icon(
            Icons.calendar_month_rounded,
            color: _primaryBlue,
            size: 23,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF9FC3F8)),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: _primaryBlue,
              size: 21,
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE4E8EF)),
      ),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FB),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ViewTab(
              label: 'Weekly',
              selected: _viewMode == _AttendanceViewMode.weekly,
              onTap: () {
                setState(() {
                  _viewMode = _AttendanceViewMode.weekly;
                  _selectedDate = null;
                });
              },
            ),
          ),
          Expanded(
            child: _ViewTab(
              label: 'Monthly',
              selected: _viewMode == _AttendanceViewMode.monthly,
              onTap: () {
                setState(() {
                  _viewMode = _AttendanceViewMode.monthly;
                  _selectedDate = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          tooltip: 'Previous month',
          onPressed: _isLoading
              ? null
              : () {
                  _changeMonth(-1);
                },
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFF4D5665),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 116,
          child: Text(
            '${_monthName(_focusedMonth.month)} '
            '${_focusedMonth.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _darkText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Next month',
          onPressed: _isLoading
              ? null
              : () {
                  _changeMonth(1);
                },
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF4D5665),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final selectedDate = _selectedDate;

    return InkWell(
      onTap: _selectAttendanceDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: _primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Select Attendance Date',
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedDate == null
                        ? 'Select Date'
                        : _formatDisplayDate(selectedDate),
                    style: const TextStyle(
                      color: _darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (selectedDate != null)
              IconButton(
                tooltip: 'Clear date',
                onPressed: _clearSelectedDate,
                icon: const Icon(
                  Icons.close_rounded,
                  color: _mutedText,
                  size: 20,
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF596273)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeading(int count) {
    final String title;

    if (_selectedDate != null) {
      title = 'Attendance Record';
    } else if (_viewMode == _AttendanceViewMode.weekly) {
      title = 'Weekly Attendance';
    } else {
      title = 'Monthly Attendance';
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _darkText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '$count ${count == 1 ? 'record' : 'records'}',
          style: const TextStyle(
            color: _mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 50),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCCCC)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD92D20),
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Unable to load attendance history.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A1C17),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadAttendanceHistory,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.event_busy_rounded, color: Color(0xFF8B95A7), size: 38),
          SizedBox(height: 12),
          Text(
            'No attendance records found.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _darkText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(_AttendanceRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(12, 13, 11, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 48,
                child: Column(
                  children: <Widget>[
                    Text(
                      record.date.day.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        color: _darkText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _shortMonthName(record.date.month).toUpperCase(),
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 54, color: _borderColor),
              const SizedBox(width: 11),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _RecordValue(
                        label: 'CHECK-IN',
                        value: record.checkInLabel,
                        icon: Icons.login_rounded,
                      ),
                    ),
                    Expanded(
                      child: _RecordValue(
                        label: 'CHECK-OUT',
                        value: record.checkOutLabel,
                        icon: Icons.logout_rounded,
                      ),
                    ),
                    Expanded(
                      child: _RecordValue(
                        label: 'WORKED',
                        value: record.workedLabel,
                        highlight: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const SizedBox(width: 60),
              Expanded(
                child: Text(
                  record.shiftName.isEmpty ? 'General Shift' : record.shiftName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _StatusBadge(status: record.statusLabel),
            ],
          ),
          if (record.breakMinutes > 0 ||
              record.overtimeMinutes > 0) ...<Widget>[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Break: ${_formatMinutes(record.breakMinutes)}'
                  '    Overtime: '
                  '${_formatMinutes(record.overtimeMinutes)}',
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 1,
      onTap: (int index) {
        _handleBottomNavigation(index);
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 12,
      selectedItemColor: _primaryBlue,
      unselectedItemColor: const Color(0xFF5D6678),
      selectedFontSize: 10,
      unselectedFontSize: 10,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined),
          activeIcon: Icon(Icons.calendar_month_rounded),
          label: 'Attendance',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_note_outlined),
          activeIcon: Icon(Icons.event_note_rounded),
          label: 'Leave',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none_rounded),
          activeIcon: Icon(Icons.notifications_rounded),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatApiMonth(DateTime value) {
    return '${value.year}-'
        '${value.month.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')} '
        '${_monthName(value.month)} '
        '${value.year}';
  }

  String _monthName(int month) {
    const months = <String>[
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

    return months[month - 1];
  }

  String _shortMonthName(int month) {
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

    return months[month - 1];
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0867DB) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF667085),
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RecordValue extends StatelessWidget {
  const _RecordValue({
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: const Color(0xFF0867DB), size: 12),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlight
                      ? const Color(0xFF0867DB)
                      : const Color(0xFF102A4C),
                  fontSize: 11,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.trim().toLowerCase();

    late final Color backgroundColor;
    late final Color textColor;

    switch (normalizedStatus) {
      case 'present':
      case 'approved':
      case 'completed':
        backgroundColor = const Color(0xFFE3F8EB);
        textColor = const Color(0xFF11883E);
        break;

      case 'late':
      case 'pending':
        backgroundColor = const Color(0xFFFFF1D8);
        textColor = const Color(0xFFF79009);
        break;

      case 'absent':
      case 'rejected':
        backgroundColor = const Color(0xFFFFE2E2);
        textColor = const Color(0xFFD92D20);
        break;

      case 'on leave':
      case 'leave':
        backgroundColor = const Color(0xFFE8EEFF);
        textColor = const Color(0xFF3157C8);
        break;

      default:
        backgroundColor = const Color(0xFFF0F2F5);
        textColor = const Color(0xFF596273);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AttendanceRecord {
  const _AttendanceRecord({
    required this.date,
    required this.checkInTime,
    required this.checkOutTime,
    required this.workedMinutes,
    required this.breakMinutes,
    required this.overtimeMinutes,
    required this.shiftName,
    required this.status,
  });

  final DateTime date;
  final String? checkInTime;
  final String? checkOutTime;

  final int workedMinutes;
  final int breakMinutes;
  final int overtimeMinutes;

  final String shiftName;
  final String status;

  bool get hasValidDate {
    return date.year > 2000;
  }

  String get checkInLabel {
    return _formatTimeValue(checkInTime);
  }

  String get checkOutLabel {
    return _formatTimeValue(checkOutTime);
  }

  String get workedLabel {
    return _formatMinutes(workedMinutes);
  }

  String get statusLabel {
    final normalizedStatus = status
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');

    if (normalizedStatus.isEmpty) {
      return 'Present';
    }

    return normalizedStatus
        .split(RegExp(r'\s+'))
        .where((String word) {
          return word.isNotEmpty;
        })
        .map((String word) {
          return '${word[0].toUpperCase()}'
              '${word.substring(1)}';
        })
        .join(' ');
  }

  factory _AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final dateValue = _findValue(json, const <String>[
      'attendance_date',
      'attendanceDate',
      'work_date',
      'workDate',
      'date',
    ]);

    return _AttendanceRecord(
      date: _parseDate(dateValue),
      checkInTime: _findString(json, const <String>[
        'check_in_time',
        'checkInTime',
        'checkin_time',
        'checkinTime',
        'check_in_at',
        'checkInAt',
        'clock_in_time',
        'clockInTime',
      ]),
      checkOutTime: _findString(json, const <String>[
        'check_out_time',
        'checkOutTime',
        'checkout_time',
        'checkoutTime',
        'check_out_at',
        'checkOutAt',
        'clock_out_time',
        'clockOutTime',
      ]),
      workedMinutes: _readDurationMinutes(
        json,
        minuteKeys: const <String>[
          'worked_minutes',
          'workedMinutes',
          'working_minutes',
          'workingMinutes',
          'total_worked_minutes',
          'totalWorkedMinutes',
          'worked_duration_minutes',
          'workedDurationMinutes',
        ],
        durationKeys: const <String>[
          'worked',
          'working_duration',
          'workingDuration',
          'worked_duration',
          'workedDuration',
          'working_hours',
          'workingHours',
        ],
      ),
      breakMinutes: _readDurationMinutes(
        json,
        minuteKeys: const <String>[
          'break_minutes',
          'breakMinutes',
          'total_break_minutes',
          'totalBreakMinutes',
          'break_duration_minutes',
          'breakDurationMinutes',
        ],
        durationKeys: const <String>[
          'break_duration',
          'breakDuration',
          'total_break_time',
          'totalBreakTime',
        ],
      ),
      overtimeMinutes: _readDurationMinutes(
        json,
        minuteKeys: const <String>[
          'overtime_minutes',
          'overtimeMinutes',
          'total_overtime_minutes',
          'totalOvertimeMinutes',
          'ot_minutes',
          'otMinutes',
        ],
        durationKeys: const <String>[
          'overtime',
          'overtime_duration',
          'overtimeDuration',
          'ot_duration',
          'otDuration',
        ],
      ),
      shiftName:
          _findNestedName(
            json,
            directKeys: const <String>['shift_name', 'shiftName'],
            objectKeys: const <String>['shift'],
          ) ??
          '',
      status:
          _findString(json, const <String>[
            'attendance_status',
            'attendanceStatus',
            'status',
          ]) ??
          'Present',
    );
  }
}

class _AttendanceException implements Exception {
  const _AttendanceException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

DateTime _parseDate(dynamic value) {
  if (value == null) {
    return DateTime(1970);
  }

  if (value is DateTime) {
    return value;
  }

  final text = value.toString().trim();

  if (text.isEmpty) {
    return DateTime(1970);
  }

  final parsedDate = DateTime.tryParse(text);

  if (parsedDate != null) {
    return parsedDate.toLocal();
  }

  final dateMatch = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$',
  ).firstMatch(text);

  if (dateMatch != null) {
    return DateTime(
      int.parse(dateMatch.group(3)!),
      int.parse(dateMatch.group(2)!),
      int.parse(dateMatch.group(1)!),
    );
  }

  return DateTime(1970);
}

String _formatTimeValue(String? value) {
  if (value == null ||
      value.trim().isEmpty ||
      value.trim().toLowerCase() == 'null') {
    return '--';
  }

  final text = value.trim();

  final parsedDate = DateTime.tryParse(text);

  if (parsedDate != null) {
    final localDate = parsedDate.toLocal();

    return _formatClockTime(localDate.hour, localDate.minute);
  }

  final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(text);

  if (timeMatch != null) {
    return _formatClockTime(
      int.parse(timeMatch.group(1)!),
      int.parse(timeMatch.group(2)!),
    );
  }

  return text;
}

String _formatClockTime(int hour, int minute) {
  final normalizedHour = hour % 24;

  final displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12;

  final period = normalizedHour >= 12 ? 'PM' : 'AM';

  return '$displayHour:'
      '${minute.toString().padLeft(2, '0')} '
      '$period';
}

int _readDurationMinutes(
  Map<String, dynamic> json, {
  required List<String> minuteKeys,
  required List<String> durationKeys,
}) {
  final minuteValue = _findValue(json, minuteKeys);

  final minuteResult = _parseDurationMinutes(minuteValue);

  if (minuteResult != null) {
    return minuteResult;
  }

  final durationValue = _findValue(json, durationKeys);

  return _parseDurationMinutes(durationValue) ?? 0;
}

int? _parseDurationMinutes(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.round();
  }

  final text = value.toString().trim();

  if (text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }

  final numericValue = double.tryParse(text);

  if (numericValue != null) {
    return numericValue.round();
  }

  final clockMatch = RegExp(
    r'^(\d{1,3}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(text);

  if (clockMatch != null) {
    final hours = int.parse(clockMatch.group(1)!);

    final minutes = int.parse(clockMatch.group(2)!);

    final seconds = int.tryParse(clockMatch.group(3) ?? '0') ?? 0;

    return (hours * 60) + minutes + (seconds >= 30 ? 1 : 0);
  }

  final hourMatch = RegExp(r'(\d+)\s*h', caseSensitive: false).firstMatch(text);

  final minuteMatch = RegExp(
    r'(\d+)\s*m',
    caseSensitive: false,
  ).firstMatch(text);

  if (hourMatch != null || minuteMatch != null) {
    final hours = int.tryParse(hourMatch?.group(1) ?? '0') ?? 0;

    final minutes = int.tryParse(minuteMatch?.group(1) ?? '0') ?? 0;

    return (hours * 60) + minutes;
  }

  return null;
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

String? _findNestedName(
  Map<String, dynamic> json, {
  required List<String> directKeys,
  required List<String> objectKeys,
}) {
  final directValue = _findString(json, directKeys);

  if (directValue != null) {
    return directValue;
  }

  for (final objectKey in objectKeys) {
    final value = _findValue(json, <String>[objectKey]);

    if (value is Map) {
      final map = value.map<String, dynamic>((dynamic key, dynamic item) {
        return MapEntry<String, dynamic>(key.toString(), item);
      });

      final name = _findString(map, const <String>[
        'name',
        'title',
        'label',
        'shift_name',
        'shiftName',
      ]);

      if (name != null) {
        return name;
      }
    }

    if (value != null && value is! Map && value is! List) {
      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
  }

  return null;
}

String? _findString(dynamic source, List<String> keys) {
  final value = _findValue(source, keys);

  if (value == null || value is Map || value is List) {
    return null;
  }

  final text = value.toString().trim();

  if (text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }

  return text;
}

dynamic _findValue(dynamic source, List<String> keys) {
  final normalizedKeys = keys.map(_normalizeKey).toSet();

  return _findValueRecursive(source, normalizedKeys, <int>{});
}

dynamic _findValueRecursive(
  dynamic source,
  Set<String> keys,
  Set<int> visited,
) {
  if (source == null) {
    return null;
  }

  if (source is Map) {
    final identity = identityHashCode(source);

    if (visited.contains(identity)) {
      return null;
    }

    visited.add(identity);

    for (final entry in source.entries) {
      final normalizedKey = _normalizeKey(entry.key.toString());

      if (keys.contains(normalizedKey)) {
        return entry.value;
      }
    }

    for (final value in source.values) {
      final foundValue = _findValueRecursive(value, keys, visited);

      if (foundValue != null) {
        return foundValue;
      }
    }
  }

  if (source is List) {
    final identity = identityHashCode(source);

    if (visited.contains(identity)) {
      return null;
    }

    visited.add(identity);

    for (final value in source) {
      final foundValue = _findValueRecursive(value, keys, visited);

      if (foundValue != null) {
        return foundValue;
      }
    }
  }

  return null;
}

String _normalizeKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
