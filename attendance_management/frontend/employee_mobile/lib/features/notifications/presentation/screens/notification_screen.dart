import 'package:employee_mobile/features/attendance/presentation/screens/attendance_history_screen.dart';
import 'package:employee_mobile/features/leave/presentation/controllers/leave_controller.dart';
import 'package:employee_mobile/features/leave/presentation/screens/leave_dashboard_screen.dart';
import 'package:employee_mobile/features/notifications/data/models/notification_response.dart';
import 'package:employee_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() {
    return _NotificationScreenState();
  }
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color _primaryBlue = Color(0xFF075ECF);
  static const Color _darkText = Color(0xFF14213D);
  static const Color _mutedText = Color(0xFF667085);
  static const Color _borderColor = Color(0xFFDCE3EE);
  static const Color _pageBackground = Color(0xFFFAFBFD);

  late final NotificationController _notificationController;
  late final LeaveController _leaveController;

  @override
  void initState() {
    super.initState();

    _notificationController = NotificationController();
    _leaveController = LeaveController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationController.initialize();
    });
  }

  @override
  void dispose() {
    _notificationController.dispose();
    _leaveController.dispose();

    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    await _notificationController.refresh();

    if (!mounted) {
      return;
    }

    final errorMessage = _notificationController.errorMessage;

    if (errorMessage != null && errorMessage.trim().isNotEmpty) {
      _showMessage(errorMessage, isError: true);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.isRead) {
      await _notificationController.markAsRead(notification);
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _NotificationTypeIcon(type: notification.iconType, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                notification.message.isEmpty
                    ? 'No notification details available.'
                    : notification.message,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (notification.dateLabel.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  notification.dateLabel,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllNotifications() async {
    final notifications = List<AppNotification>.from(
      _notificationController.notifications,
    );

    if (notifications.isEmpty) {
      _showMessage('No notifications to clear.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear All Notifications'),
          content: const Text(
            'Are you sure you want to remove all notifications?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    for (final notification in notifications) {
      final success = await _notificationController.deleteNotification(
        notification,
      );

      if (!success) {
        if (mounted) {
          _showMessage(
            _notificationController.errorMessage ??
                'Unable to clear all notifications.',
            isError: true,
          );
        }

        return;
      }
    }

    if (!mounted) {
      return;
    }

    _showMessage('All notifications cleared.');
  }

  Future<void> _openAttendance() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AttendanceHistoryScreen();
        },
      ),
    );
  }

  Future<void> _openLeave() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LeaveDashboardScreen(controller: _leaveController);
        },
      ),
    );
  }

  Future<void> _handleBottomNavigation(int index) async {
    switch (index) {
      case 0:
        Navigator.of(context).popUntil((Route<dynamic> route) {
          return route.isFirst;
        });
        break;

      case 1:
        await _openAttendance();
        break;

      case 2:
        await _openLeave();
        break;

      case 3:
        break;

      case 4:
        _showMessage('Profile module will be connected next.');
        break;
    }
  }

  void _openNotificationSettings() {
    _showMessage('Notification settings will be connected next.');
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
      animation: _notificationController,
      builder: (BuildContext context, Widget? child) {
        final notifications = _notificationController.notifications;

        return Scaffold(
          backgroundColor: _pageBackground,
          appBar: _buildAppBar(),
          body: RefreshIndicator(
            onRefresh: _refreshNotifications,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: <Widget>[
                if (_notificationController.isLoading)
                  _buildLoadingState()
                else if (_notificationController.errorMessage != null)
                  _buildErrorState()
                else if (notifications.isEmpty)
                  _buildEmptyState()
                else ...<Widget>[
                  ...notifications.map(_buildNotificationCard),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: _notificationController.isBusy
                          ? null
                          : _clearAllNotifications,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF535D70),
                        side: const BorderSide(color: Color(0xFF9CA6B7)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Clear All Notifications',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFFBF9FF),
      surfaceTintColor: const Color(0xFFFBF9FF),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 14,
      title: const Row(
        children: <Widget>[
          CircleAvatar(
            radius: 15,
            backgroundColor: Color(0xFFEAF2FF),
            child: Icon(Icons.person_rounded, color: _primaryBlue, size: 18),
          ),
          SizedBox(width: 10),
          Text(
            'Notifications',
            style: TextStyle(
              color: Color(0xFF0757B8),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'Notification settings',
          onPressed: _openNotificationSettings,
          icon: const Icon(
            Icons.settings_outlined,
            color: Color(0xFF4D5665),
            size: 21,
          ),
        ),
        const SizedBox(width: 6),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: Color(0xFFE4E8EF)),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: notification.isRead ? _borderColor : const Color(0xFFB7D2F8),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          _openNotification(notification);
        },
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 11, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _NotificationTypeIcon(type: notification.iconType),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _darkText,
                              fontSize: 13,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _compactDateLabel(notification),
                          style: const TextStyle(
                            color: _mutedText,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message.isEmpty
                          ? 'No notification details available.'
                          : notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF586477),
                        fontSize: 10.5,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _compactDateLabel(AppNotification notification) {
    final date = notification.createdAt;

    if (date == null) {
      return '';
    }

    final localDate = date.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final notificationDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final difference = today.difference(notificationDate).inDays;

    if (difference == 0) {
      return _formatClockTime(localDate);
    }

    if (difference == 1) {
      return 'Yesterday';
    }

    return '${localDate.day.toString().padLeft(2, '0')} '
        '${_shortMonth(localDate.month)} '
        '${localDate.year}';
  }

  String _formatClockTime(DateTime value) {
    final displayHour = value.hour % 12 == 0 ? 12 : value.hour % 12;

    final minute = value.minute.toString().padLeft(2, '0');

    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$displayHour:$minute $period';
  }

  String _shortMonth(int month) {
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

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
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
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            _notificationController.errorMessage ??
                'Unable to load notifications.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A1C17),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: () {
              _notificationController.loadNotifications();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 52),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: <Widget>[
          CircleAvatar(
            radius: 32,
            backgroundColor: Color(0xFFEAF2FF),
            child: Icon(
              Icons.notifications_none_rounded,
              color: _primaryBlue,
              size: 31,
            ),
          ),
          SizedBox(height: 15),
          Text(
            'No notifications found',
            style: TextStyle(
              color: _darkText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'New notifications will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 3,
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
}

class _NotificationTypeIcon extends StatelessWidget {
  const _NotificationTypeIcon({required this.type, this.size = 38});

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon(type);
    final iconColor = _getIconColor(type);
    final backgroundColor = _getBackgroundColor(type);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: size * 0.48),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'leave':
        return Icons.check_circle_outline_rounded;

      case 'attendance':
        return Icons.notifications_none_rounded;

      case 'approved':
        return Icons.check_circle_outline_rounded;

      case 'rejected':
        return Icons.cancel_outlined;

      case 'reminder':
        return Icons.notifications_none_rounded;

      default:
        return Icons.article_outlined;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'leave':
      case 'approved':
        return const Color(0xFF18A85C);

      case 'attendance':
      case 'reminder':
        return const Color(0xFF0867DB);

      case 'rejected':
        return const Color(0xFFD92D20);

      default:
        return const Color(0xFF586477);
    }
  }

  Color _getBackgroundColor(String type) {
    switch (type) {
      case 'leave':
      case 'approved':
        return const Color(0xFFE7F8EE);

      case 'attendance':
      case 'reminder':
        return const Color(0xFFEAF2FF);

      case 'rejected':
        return const Color(0xFFFFE6E6);

      default:
        return const Color(0xFFF0F2F5);
    }
  }
}
