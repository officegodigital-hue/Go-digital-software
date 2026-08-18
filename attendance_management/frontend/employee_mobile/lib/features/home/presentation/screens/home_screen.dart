import 'dart:async';

import 'package:employee_mobile/features/attendance/data/models/today_attendance_response.dart';
import 'package:employee_mobile/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:employee_mobile/features/attendance/presentation/screens/attendance_history_screen.dart';
import 'package:employee_mobile/features/leave/presentation/controllers/leave_controller.dart';
import 'package:employee_mobile/features/leave/presentation/screens/leave_dashboard_screen.dart';
import 'package:employee_mobile/features/notifications/presentation/screens/notification_screen.dart';
import 'package:employee_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.employeeName, super.key});

  final String employeeName;

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _primaryBlue = Color(0xFF075ECF);
  static const Color _darkBlue = Color(0xFF07459A);
  static const Color _pageBackground = Color(0xFFFDFDFD);
  static const Color _lightBorder = Color(0xFFE8ECF3);
  static const Color _mutedText = Color(0xFF667085);

  late final AttendanceController _attendanceController;
  late final LeaveController _leaveController;

  Timer? _attendanceRefreshTimer;
  int _selectedNavigationIndex = 0;

  @override
  void initState() {
    super.initState();

    _attendanceController = AttendanceController();
    _leaveController = LeaveController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTodayAttendance(showError: true);
      _startAttendanceRefreshTimer();
    });
  }

  @override
  void dispose() {
    _attendanceRefreshTimer?.cancel();
    _attendanceController.dispose();
    _leaveController.dispose();
    super.dispose();
  }

  String get _displayName {
    final name = widget.employeeName.trim();
    return name.isEmpty ? 'Employee' : name;
  }

  String get _checkInTime {
    return _attendanceController.formatCheckInTime();
  }

  String get _checkOutTime {
    return _attendanceController.formatCheckOutTime();
  }

  String get _workingHours {
    return _attendanceController.workingDurationLabel;
  }

  String get _breakDuration {
    return _attendanceController.breakDurationLabel;
  }

  String get _overtime {
    return _attendanceController.overtimeLabel;
  }

  bool get _hasCheckedIn {
    return _attendanceController.hasCheckedIn;
  }

  bool get _hasCheckedOut {
    return _attendanceController.hasCheckedOut;
  }

  bool get _isOnBreak {
    return _attendanceController.isOnBreak;
  }

  bool get _canCheckIn {
    return _attendanceController.canCheckIn;
  }

  bool get _canCheckOut {
    return _attendanceController.canCheckOut;
  }

  bool get _canStartBreak {
    return _attendanceController.canStartBreak;
  }

  bool get _canEndBreak {
    return _attendanceController.canEndBreak;
  }

  bool get _isBusy {
    return _attendanceController.isLoading ||
        _attendanceController.isActionLoading;
  }

  String get _status {
    if (!_hasCheckedIn) {
      return '--';
    }

    if (_hasCheckedOut) {
      return 'Completed';
    }

    if (_isOnBreak) {
      return 'On Break';
    }

    return _attendanceController.statusLabel;
  }

  String get _mainActionLabel {
    if (!_hasCheckedIn) {
      return 'CHECK IN';
    }

    if (_hasCheckedOut) {
      return 'COMPLETED';
    }

    if (_isOnBreak) {
      return 'END BREAK';
    }

    return 'CHECK OUT';
  }

  IconData get _mainActionIcon {
    if (!_hasCheckedIn) {
      return Icons.location_on_rounded;
    }

    if (_hasCheckedOut) {
      return Icons.check_circle_rounded;
    }

    if (_isOnBreak) {
      return Icons.restaurant_rounded;
    }

    return Icons.logout_rounded;
  }

  bool get _canUseMainAction {
    if (_isBusy) {
      return false;
    }

    if (!_hasCheckedIn) {
      return _canCheckIn;
    }

    if (_hasCheckedOut) {
      return false;
    }

    if (_isOnBreak) {
      return _canEndBreak;
    }

    return _canCheckOut;
  }

  void _startAttendanceRefreshTimer() {
    _attendanceRefreshTimer?.cancel();

    _attendanceRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted || _isBusy) {
          return;
        }

        _loadTodayAttendance(showError: false);
      },
    );
  }

  Future<void> _loadTodayAttendance({bool showError = false}) async {
    await _attendanceController.loadTodayAttendance();

    if (!mounted) {
      return;
    }

    final error = _attendanceController.errorMessage;

    if (showError && error != null && error.trim().isNotEmpty) {
      _showMessage(error, isError: true);
    }
  }

  Future<void> _runAttendanceAction({
    required Future<TodayAttendanceResponse?> Function() action,
    required String fallbackSuccessMessage,
  }) async {
    if (_isBusy) {
      return;
    }

    final response = await action();

    if (!mounted) {
      return;
    }

    if (response == null) {
      final error = _attendanceController.errorMessage;

      _showMessage(
        error == null || error.trim().isEmpty
            ? 'Attendance action failed. Please try again.'
            : error,
        isError: true,
      );
      return;
    }

    final success = _attendanceController.successMessage;

    _showMessage(
      success == null || success.trim().isEmpty
          ? fallbackSuccessMessage
          : success,
    );
  }

  Future<void> _checkIn() async {
    if (!_canCheckIn || _isBusy) {
      return;
    }

    await _runAttendanceAction(
      action: () => _attendanceController.checkIn(),
      fallbackSuccessMessage: 'Checked in successfully.',
    );
  }

  Future<void> _startBreak() async {
    if (!_canStartBreak || _isBusy) {
      return;
    }

    await _runAttendanceAction(
      action: () => _attendanceController.startBreak(),
      fallbackSuccessMessage: 'Break started successfully.',
    );
  }

  Future<void> _endBreak() async {
    if (!_canEndBreak || _isBusy) {
      return;
    }

    await _runAttendanceAction(
      action: () => _attendanceController.endBreak(),
      fallbackSuccessMessage: 'Break ended successfully.',
    );
  }

  Future<void> _checkOut() async {
    if (!_canCheckOut || _isBusy) {
      return;
    }

    await _runAttendanceAction(
      action: () => _attendanceController.checkOut(),
      fallbackSuccessMessage: 'Checked out successfully.',
    );
  }

  Future<void> _handleMainAction() async {
    if (_isBusy) {
      return;
    }

    if (!_hasCheckedIn) {
      await _checkIn();
      return;
    }

    if (_isOnBreak) {
      await _endBreak();
      return;
    }

    if (!_hasCheckedOut) {
      await _checkOut();
    }
  }

  Future<void> _openLeaveDashboard() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          return LeaveDashboardScreen(controller: _leaveController);
        },
      ),
    );
  }

  Future<void> _openAttendanceHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AttendanceHistoryScreen();
        },
      ),
    );
  }

  Future<void> _openAlerts() async {
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

  Future<void> _showLocation() async {
    _showMessage(
      'Location access will be connected with the attendance action.',
    );
  }

  Future<void> _onNavigationTapped(int index) async {
    if (index == 0) {
      setState(() {
        _selectedNavigationIndex = 0;
      });
      return;
    }

    setState(() {
      _selectedNavigationIndex = index;
    });

    if (index == 1) {
      await _openAttendanceHistory();
    } else if (index == 2) {
      await _openLeaveDashboard();
    } else if (index == 3) {
      await _openAlerts();
    } else if (index == 4) {
      await _openProfile();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedNavigationIndex = 0;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _attendanceController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _pageBackground,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: RefreshIndicator(
                  onRefresh: () => _loadTodayAttendance(showError: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    children: <Widget>[
                      _buildHeader(context),
                      const SizedBox(height: 22),
                      _buildAttendanceCard(context),
                      const SizedBox(height: 20),
                      _buildActionRow(context),
                      const SizedBox(height: 24),
                      _buildSummaryHeader(context),
                      const SizedBox(height: 12),
                      _buildSummaryCard(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: _buildBottomNavigation(),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F0FF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFB7CCFA)),
          ),
          child: Center(
            child: Text(
              _initials(_displayName),
              style: const TextStyle(
                color: _primaryBlue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_greeting()}, $_displayName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _darkBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrentDate(),
                style: const TextStyle(
                  color: _mutedText,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconButton(
              tooltip: 'Alerts',
              onPressed: _openAlerts,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: _primaryBlue,
                size: 23,
              ),
            ),
            Positioned(
              right: 10,
              top: 9,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF075BCF), Color(0xFF0A70E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _AttendanceTimeColumn(
                  label: 'Check In',
                  value: _checkInTime,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withValues(alpha: 0.22),
              ),
              Expanded(
                child: _AttendanceTimeColumn(
                  label: 'Check Out',
                  value: _checkOutTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 47,
            child: FilledButton.icon(
              onPressed: _canUseMainAction ? _handleMainAction : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _darkBlue,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.85),
                disabledForegroundColor: _darkBlue.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: _isBusy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_mainActionIcon, size: 18),
              label: Text(
                _isBusy ? 'PLEASE WAIT' : _mainActionLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _ActionItem(
          icon: Icons.local_cafe_outlined,
          label: 'Start\nBreak',
          iconColor: const Color(0xFFFFA41C),
          backgroundColor: const Color(0xFFFFF4E1),
          enabled: _canStartBreak && !_isBusy,
          onTap: _startBreak,
        ),
        _ActionItem(
          icon: Icons.restaurant_rounded,
          label: 'End\nBreak',
          iconColor: const Color(0xFF00A86B),
          backgroundColor: const Color(0xFFE4F8EF),
          enabled: _canEndBreak && !_isBusy,
          onTap: _endBreak,
        ),
        _ActionItem(
          icon: Icons.logout_rounded,
          label: 'Check\nOut',
          iconColor: const Color(0xFFFF5964),
          backgroundColor: const Color(0xFFFFEBED),
          enabled: _canCheckOut && !_isBusy,
          onTap: _checkOut,
        ),
        _ActionItem(
          icon: Icons.location_on_outlined,
          label: 'My\nLocation',
          iconColor: const Color(0xFF1A8CFF),
          backgroundColor: const Color(0xFFE8F3FF),
          enabled: true,
          onTap: _showLocation,
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            "Today's Summary",
            style: TextStyle(
              color: Color(0xFF132A55),
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: _openAttendanceHistory,
          style: TextButton.styleFrom(
            foregroundColor: _primaryBlue,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'View History',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _lightBorder),
      ),
      child: Column(
        children: <Widget>[
          _SummaryRow(
            icon: Icons.access_time_rounded,
            label: 'Working Hours',
            value: _workingHours,
          ),
          const Divider(height: 1, color: _lightBorder),
          _SummaryRow(
            icon: Icons.timer_outlined,
            label: 'Break Duration',
            value: _breakDuration,
          ),
          const Divider(height: 1, color: _lightBorder),
          _SummaryRow(
            icon: Icons.alarm_rounded,
            label: 'Overtime',
            value: _overtime,
          ),
          const Divider(height: 1, color: _lightBorder),
          _SummaryRow(
            icon: Icons.info_outline_rounded,
            label: 'Status',
            value: _status,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _selectedNavigationIndex,
      onTap: _onNavigationTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 12,
      selectedItemColor: _primaryBlue,
      unselectedItemColor: const Color(0xFF4F5668),
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

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good Morning';
    }

    if (hour < 17) {
      return 'Good Afternoon';
    }

    return 'Good Evening';
  }

  String _formatCurrentDate() {
    final value = DateTime.now();

    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

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

    return '${value.day} ${months[value.month - 1]} '
        '${value.year}, ${weekdays[value.weekday - 1]}';
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'E';
    }

    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }

    return '${words.first.substring(0, 1)}'
            '${words.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _AttendanceTimeColumn extends StatelessWidget {
  const _AttendanceTimeColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.74),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.backgroundColor,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color backgroundColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 64,
          child: Column(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF222A3A),
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 31,
            height: 31,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF1FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _HomeScreenState._primaryBlue, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF545D6E),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF132A55),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
