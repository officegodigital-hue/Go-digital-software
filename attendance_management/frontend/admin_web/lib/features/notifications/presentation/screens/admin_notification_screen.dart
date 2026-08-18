import 'package:flutter/material.dart';

import '../../data/models/admin_notification_model.dart';
import '../controllers/admin_notification_controller.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  late final AdminNotificationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AdminNotificationController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _controller.initialize();
    });
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(),

            const SizedBox(height: 18),

            if (_controller.isLoading)
              const LinearProgressIndicator(minHeight: 2),

            if (_controller.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),

              _buildError(),
            ],

            const SizedBox(height: 12),

            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20232A),
                ),
              ),

              SizedBox(height: 4),

              Text(
                'All employee and system notifications.',
                style: TextStyle(fontSize: 12, color: Color(0xFF747B8A)),
              ),
            ],
          ),
        ),

        if (_controller.unreadCount > 0)
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEC),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${_controller.unreadCount} unread',
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

        if (_controller.unreadCount > 0)
          OutlinedButton.icon(
            onPressed: _controller.isLoading ? null : _controller.markAllAsRead,

            icon: const Icon(Icons.done_all_rounded, size: 16),

            label: const Text('Mark all read'),
          ),

        const SizedBox(width: 8),

        OutlinedButton.icon(
          onPressed: _controller.isLoading ? null : _controller.refresh,

          icon: const Icon(Icons.refresh_rounded, size: 16),

          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_controller.isLoading && !_controller.hasNotifications) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_controller.hasNotifications) {
      return _buildEmpty();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E4EA)),
      ),
      child: ListView.separated(
        itemCount: _controller.notifications.length,

        separatorBuilder: (BuildContext context, int index) {
          return const Divider(height: 1, color: Color(0xFFE8EAF0));
        },

        itemBuilder: (BuildContext context, int index) {
          final notification = _controller.notifications[index];

          return _NotificationRow(
            notification: notification,

            onTap: () {
              _controller.markAsRead(notification);
            },

            onDelete: () {
              _deleteNotification(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(8),

          border: Border.all(color: const Color(0xFFE1E4EA)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 31,
              backgroundColor: Color(0xFFE9EAFF),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 31,
                color: Color(0xFF1616E8),
              ),
            ),

            SizedBox(height: 16),

            Text(
              'No notifications found',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),

            SizedBox(height: 6),

            Text(
              'New employee and system notifications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF747B8A), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),

        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _controller.errorMessage ?? 'Unable to load notifications.',
        style: const TextStyle(color: Color(0xFFC62828)),
      ),
    );
  }

  Future<void> _deleteNotification(AdminNotificationModel notification) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Notification'),

          content: const Text('Delete this notification?'),

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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _controller.deleteNotification(notification);
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final AdminNotificationModel notification;

  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = _typeColor(notification.notificationType);

    return Material(
      color: notification.isRead ? Colors.white : const Color(0xFFF7F8FF),

      child: InkWell(
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,

                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),

                  borderRadius: BorderRadius.circular(9),
                ),

                child: Icon(
                  _typeIcon(notification.notificationType),
                  color: iconColor,
                  size: 21,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,

                            style: TextStyle(
                              fontSize: 13,

                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,

                              color: const Color(0xFF20232A),
                            ),
                          ),
                        ),

                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1616E8),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      notification.message,

                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: Color(0xFF5F6675),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      children: <Widget>[
                        if (notification.employeeName != null)
                          Text(
                            notification.employeeDisplayName,

                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1616E8),
                            ),
                          ),

                        Text(
                          notification.typeLabel,

                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF747B8A),
                          ),
                        ),

                        Text(
                          _formatDate(notification.createdAt),

                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF747B8A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                tooltip: 'Delete',

                onPressed: onDelete,

                icon: const Icon(
                  Icons.delete_outline_rounded,

                  size: 18,

                  color: Color(0xFF8A909D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _typeIcon(String type) {
    switch (type.trim().toLowerCase()) {
      case 'permission_request':
        return Icons.pending_actions_outlined;

      case 'leave_request':
        return Icons.event_busy_outlined;

      case 'late_login':
        return Icons.schedule_rounded;

      case 'check_in':
        return Icons.login_rounded;

      case 'check_out':
        return Icons.logout_rounded;

      case 'attendance':
        return Icons.fact_check_outlined;

      case 'payroll':
        return Icons.payments_outlined;

      default:
        return Icons.notifications_none_rounded;
    }
  }

  static Color _typeColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'leave_request':
        return const Color(0xFFC62828);

      case 'late_login':
        return const Color(0xFFA7600A);

      case 'check_in':
        return const Color(0xFF14834B);

      case 'check_out':
        return const Color(0xFFB26819);

      default:
        return const Color(0xFF1616E8);
    }
  }

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }

    final DateTime local = date.toLocal();

    final int hour = local.hour % 12 == 0 ? 12 : local.hour % 12;

    final String minute = local.minute.toString().padLeft(2, '0');

    final String period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day}/${local.month}/${local.year} '
        '$hour:$minute $period';
  }
}
