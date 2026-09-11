import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/hrms_notifications_api.dart';

const _blue = Color(0xFF075EF7);
const _navy = Color(0xFF061457);

class AdminTopNav extends StatelessWidget {
  const AdminTopNav({super.key, required this.activeRoute});

  final String activeRoute;

  static const items = <(String, String)>[
    ('Dashboard', '/admin/dashboard'),
    ('Employees', '/admin/employees'),
    ('Approvals', '/admin/approvals'),
    ('Payroll', '/admin/payroll'),
    ('Tracking', '/admin/tracking'),
  ];

  void _open(BuildContext context, String route) {
    if (route == activeRoute) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final mobile = screenWidth < 600;
    final compact = screenWidth < 880;
    return Container(
      height: mobile ? 68 : 90,
      padding: EdgeInsets.symmetric(
          horizontal: mobile
              ? 14
              : compact
                  ? 16
                  : 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x12071A72), blurRadius: 16, offset: Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/godigital_logo.png',
            width: mobile
                ? 116
                : compact
                    ? 142
                    : 174,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          if (!compact)
            _DesktopNav(
                activeRoute: activeRoute,
                onOpen: (route) => _open(context, route)),
          if (!mobile) const Spacer(),
          AdminNotificationBell(mobile: mobile),
          SizedBox(width: mobile ? 3 : 18),
          AdminLogoutButton(compact: compact || mobile),
          if (compact)
            PopupMenuButton<String>(
              tooltip: 'Navigation',
              icon: const Icon(Icons.menu_rounded, color: _navy, size: 28),
              onSelected: (route) => _open(context, route),
              itemBuilder: (_) => items
                  .map(
                    (item) => PopupMenuItem(
                      value: item.$2,
                      child: Row(
                        children: [
                          if (item.$2 == activeRoute) ...[
                            const Icon(Icons.circle, size: 8, color: _blue),
                            const SizedBox(width: 10),
                          ],
                          Text(item.$1,
                              style: TextStyle(
                                  fontWeight: item.$2 == activeRoute
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class AdminLogoutButton extends StatelessWidget {
  const AdminLogoutButton({super.key, this.compact = false});

  final bool compact;

  void _openWorkspace(BuildContext context) {
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => _openWorkspace(context),
        icon: const Icon(Icons.grid_view_rounded, size: 19),
        label: compact ? const SizedBox.shrink() : const Text('Workspace'),
        style: TextButton.styleFrom(
          foregroundColor: _navy,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFD6E0F0)),
          ),
        ),
      );
}
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.breadcrumb,
    this.trailing,
  });

  final String title;
  final String? breadcrumb;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF11131A),
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Home',
                      style: TextStyle(color: _blue, fontSize: 15)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.chevron_right, color: _blue, size: 18),
                  ),
                  Text(breadcrumb ?? title,
                      style: const TextStyle(color: _blue, fontSize: 15)),
                ],
              ),
            ],
          );
          if (trailing == null) return heading;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 14), trailing!],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Expanded(child: heading), trailing!],
          );
        },
      );
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({required this.activeRoute, required this.onOpen});
  final String activeRoute;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Container(
        height: 60,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E7F1)),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0C071A72), blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Row(
          children: AdminTopNav.items.map((item) {
            final active = item.$2 == activeRoute;
            return InkWell(
              onTap: () => onOpen(item.$2),
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
                decoration: BoxDecoration(
                    color: active ? _blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(13)),
                child: Text(item.$1,
                    style: TextStyle(
                        color: active ? Colors.white : _navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ),
            );
          }).toList(),
        ),
      );
}

class AdminNotificationBell extends StatefulWidget {
  const AdminNotificationBell({super.key, required this.mobile});
  final bool mobile;

  @override
  State<AdminNotificationBell> createState() => _AdminNotificationBellState();
}

class _AdminNotificationBellState extends State<AdminNotificationBell> {
  Timer? _timer;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await HrmsNotificationsApi.list();
      if (!mounted) return;
      setState(() {
        _unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
        _items = ((data['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _open() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _NotificationsDialog(
        items: _items,
        unreadCount: _unreadCount,
        onMarkAllRead: () async {
          await HrmsNotificationsApi.markAllRead();
          if (!mounted) return;
          setState(() => _unreadCount = 0);
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        },
        onViewApprovals: () {
          Navigator.pop(dialogContext);
          Navigator.pushReplacementNamed(context, '/admin/approvals');
        },
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Notifications',
        onPressed: _open,
        style: IconButton.styleFrom(
          minimumSize: Size(widget.mobile ? 38 : 45, widget.mobile ? 38 : 45),
          backgroundColor: widget.mobile ? const Color(0xFFF3F6FC) : Colors.white,
          side: const BorderSide(color: Color(0xFFE2E7F1)),
        ),
        icon: Badge(
          isLabelVisible: _unreadCount > 0,
          label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
          backgroundColor: _blue,
          child: Icon(Icons.notifications_none_rounded,
              color: _navy, size: widget.mobile ? 22 : 24),
        ),
      );
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog({
    required this.items,
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.onViewApprovals,
  });

  final List<Map<String, dynamic>> items;
  final int unreadCount;
  final Future<void> Function() onMarkAllRead;
  final VoidCallback onViewApprovals;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.notifications_rounded, color: _blue),
          const SizedBox(width: 9),
          const Expanded(child: Text('Notifications')),
          TextButton(
            onPressed: unreadCount == 0 ? null : onMarkAllRead,
            child: const Text('Mark all as read'),
          ),
        ]),
        content: SizedBox(
          width: 420,
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No approval notifications.')),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final unread = item['isRead'] != true;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: unread
                              ? const Color(0xFFEAF2FF)
                              : const Color(0xFFF3F5F9),
                          child: Icon(Icons.assignment_rounded,
                              color: unread ? _blue : const Color(0xFF63718F)),
                        ),
                        title: Text(item['title']?.toString() ?? 'Approval request',
                            style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                        subtitle: Text(item['message']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: onViewApprovals,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('View Approvals'),
          ),
        ],
      );
}

