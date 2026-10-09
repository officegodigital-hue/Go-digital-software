import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../../services/hrms_notifications_api.dart';
import '../../../services/auth_service.dart';
import '../../../screens/login_screen.dart';

const _blue = Color(0xFF075EF7);
const _navy = Color(0xFF061457);

class AdminTopNav extends StatelessWidget {
  const AdminTopNav({super.key, required this.activeRoute});

  final String activeRoute;

  static const items = <(String, String)>[
    ('Dashboard', '/admin/dashboard'),
    ('Employees', '/admin/employees'),
    ('Clock Logs', '/admin/clock-logs'),
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
    // The full navigation pill needs considerably more room than the page
    // content. Switch to a compact menu before Windows display scaling can
    // squeeze the trailing actions outside the viewport.
    final compact = screenWidth < 1180;
    return Container(
      height: mobile ? 68 : 90,
      padding: EdgeInsets.symmetric(
        horizontal: mobile
            ? 14
            : compact
            ? 16
            : 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12071A72),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
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
          SizedBox(width: mobile ? 8 : 20),
          if (!compact)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _DesktopNav(
                    activeRoute: activeRoute,
                    onOpen: (route) => _open(context, route),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          if (compact && !mobile)
            _AdminNavMenu(
              activeRoute: activeRoute,
              onOpen: (route) => _open(context, route),
            ),
          if (compact && !mobile) const SizedBox(width: 8),
          AdminNotificationBell(mobile: mobile),
          const SizedBox(width: 8),
          const AdminAccountButton(),
          SizedBox(
            width: mobile
                ? 3
                : compact
                ? 8
                : 18,
          ),
          AdminLogoutButton(compact: compact || mobile),
        ],
      ),
    );
  }
}

class _AdminNavMenu extends StatelessWidget {
  const _AdminNavMenu({required this.activeRoute, required this.onOpen});

  final String activeRoute;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final activeLabel = AdminTopNav.items
        .firstWhere(
          (item) => item.$2 == activeRoute,
          orElse: () => ('Menu', ''),
        )
        .$1;
    return PopupMenuButton<String>(
      tooltip: 'Admin navigation',
      onSelected: onOpen,
      itemBuilder: (_) => AdminTopNav.items
          .map(
            (item) => PopupMenuItem<String>(
              value: item.$2,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: item.$2 == activeRoute
                        ? const Icon(
                            Icons.check_rounded,
                            color: _blue,
                            size: 19,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(item.$1),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FE),
          border: Border.all(color: const Color(0xFFD6E0F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_rounded, color: _navy, size: 21),
            const SizedBox(width: 8),
            Text(
              activeLabel,
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _navy,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminLogoutButton extends StatelessWidget {
  const AdminLogoutButton({super.key, this.compact = false});

  final bool compact;

  Future<void> _logout(BuildContext context) async {
    // Use the app's provided service instead of constructing a separate
    // instance. The provider must be notified so AuthGate switches to login.
    await context.read<AuthService>().logout();
    if (context.mounted) {
      // AdminPortalApp is a nested MaterialApp, so '/' would resolve back to
      // the admin dashboard. Replace the whole visible stack with login.
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Logout',
        onPressed: () => _logout(context),
        style: IconButton.styleFrom(
          minimumSize: const Size(42, 42),
          backgroundColor: const Color(0xFFEAF0FA),
          foregroundColor: _navy,
          shape: const CircleBorder(),
        ),
        icon: const Icon(Icons.logout_rounded, size: 21),
      );
    }
    return TextButton.icon(
      onPressed: () => _logout(context),
      icon: const Icon(Icons.logout_rounded, size: 19),
      label: const Text('Logout'),
      style: TextButton.styleFrom(
        foregroundColor: _navy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFD6E0F0)),
        ),
      ),
    );
  }
}

class AdminAccountButton extends StatelessWidget {
  const AdminAccountButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Change username or password',
    onPressed: () => _showDialog(context),
    icon: const Icon(Icons.manage_accounts_outlined, color: _navy),
  );

  Future<void> _showDialog(BuildContext context) async {
    final auth = context.read<AuthService>();
    final currentUsername = TextEditingController(
      text: auth.user?['username']?.toString() ?? '',
    );
    final newUsername = TextEditingController();
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    var hidden = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Admin account credentials'),
          content: SizedBox(
            width: 390,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentUsername,
                  decoration: const InputDecoration(
                    labelText: 'Current username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currentPassword,
                  obscureText: hidden,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(() => hidden = !hidden),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newUsername,
                  decoration: const InputDecoration(
                    labelText: 'New username (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassword,
                  obscureText: hidden,
                  decoration: const InputDecoration(
                    labelText: 'New password (optional, minimum 8)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final message = await auth.changePassword(
                  username: currentUsername.text,
                  currentPassword: currentPassword.text,
                  newPassword: newPassword.text,
                  newUsername: newUsername.text,
                );
                if (!dialogContext.mounted) return;
                if (message == null) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Admin credentials updated. Use the new details at your next login.',
                      ),
                    ),
                  );
                } else
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared floating dock for every admin page below the mobile breakpoint.
/// Less-frequent destinations remain available from the hamburger drawer.
class AdminMobileBottomNav extends StatelessWidget {
  const AdminMobileBottomNav({super.key, required this.activeRoute});

  final String activeRoute;

  void _open(BuildContext context, String route) {
    if (route == activeRoute) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 600) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF172554),
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _dockItem(
              context,
              icon: Icons.home_rounded,
              label: 'Dashboard',
              route: '/admin/dashboard',
            ),
            _dockItem(
              context,
              icon: Icons.groups_rounded,
              label: 'Employees',
              route: '/admin/employees',
            ),
            _dockItem(
              context,
              icon: Icons.history_rounded,
              label: 'Clock Logs',
              route: '/admin/clock-logs',
            ),
            _dockItem(
              context,
              icon: Icons.task_alt_rounded,
              label: 'Approvals',
              route: '/admin/approvals',
            ),
            _dockItem(
              context,
              icon: Icons.account_balance_wallet_rounded,
              label: 'Payroll',
              route: '/admin/payroll',
            ),
            _dockItem(
              context,
              icon: Icons.location_on_rounded,
              label: 'Tracking',
              route: '/admin/tracking',
            ),
          ],
        ),
      ),
    );
  }

  Widget _dockItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final active = activeRoute == route;
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => _open(context, route),
          borderRadius: BorderRadius.circular(25),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: active ? const Color(0xFF2563EB) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
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
              const Text('Home', style: TextStyle(color: _blue, fontSize: 15)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.chevron_right, color: _blue, size: 18),
              ),
              Text(
                breadcrumb ?? title,
                style: const TextStyle(color: _blue, fontSize: 15),
              ),
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
        children: [
          Expanded(child: heading),
          trailing!,
        ],
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
          color: Color(0x0C071A72),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
            decoration: BoxDecoration(
              color: active ? _blue : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              item.$1,
              style: TextStyle(
                color: active ? Colors.white : _navy,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
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
  final AudioPlayer _soundPlayer = AudioPlayer();
  final Set<int> _knownIds = <int>{};
  bool _loadedOnce = false;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _settings = const {};

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _soundPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await HrmsNotificationsApi.list();
      if (!mounted) return;
      final items = ((data['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final freshUnread = _loadedOnce
          ? items.where((item) {
              final id = (item['id'] as num?)?.toInt();
              return id != null &&
                  item['isRead'] != true &&
                  !_knownIds.contains(id);
            }).toList()
          : const <Map<String, dynamic>>[];
      _knownIds.addAll(
        items.map((item) => (item['id'] as num?)?.toInt()).whereType<int>(),
      );
      final settings = data['settings'] is Map
          ? Map<String, dynamic>.from(data['settings'] as Map)
          : _settings;
      setState(() {
        _unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
        _items = items;
        _settings = settings;
      });
      _loadedOnce = true;
      if (freshUnread.isNotEmpty && settings['soundEnabled'] == true) {
        final name = settings['soundName']?.toString() ?? 'notification.mp3';
        final volume =
            ((settings['soundVolume'] as num?)?.toDouble() ?? 70) / 100;
        await _soundPlayer.play(
          AssetSource('sounds/$name'),
          volume: volume.clamp(0.0, 1.0).toDouble(),
        );
      }
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
        onSettings: () async {
          final changed = await showDialog<bool>(
            context: context,
            builder: (_) => _NotificationSettingsDialog(settings: _settings),
          );
          if (changed == true) _load();
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
      child: Icon(
        Icons.notifications_none_rounded,
        color: _navy,
        size: widget.mobile ? 22 : 24,
      ),
    ),
  );
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog({
    required this.items,
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.onViewApprovals,
    required this.onSettings,
  });

  final List<Map<String, dynamic>> items;
  final int unreadCount;
  final Future<void> Function() onMarkAllRead;
  final VoidCallback onViewApprovals;
  final Future<void> Function() onSettings;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.notifications_rounded, color: _blue),
        const SizedBox(width: 9),
        const Expanded(child: Text('Notifications')),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Notification settings',
        ),
        TextButton(
          onPressed: unreadCount == 0 ? null : onMarkAllRead,
          child: const Text('Mark all as read'),
        ),
      ],
    ),
    content: SizedBox(
      width: 420,
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No notifications yet.')),
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
                      child: Icon(
                        item['type'] == 'tracking_comment'
                            ? Icons.comment_rounded
                            : item['type'] == 'field_waiting_reason'
                            ? Icons.timer_outlined
                            : Icons.assignment_rounded,
                        color: unread ? _blue : const Color(0xFF63718F),
                      ),
                    ),
                    title: Text(
                      item['title']?.toString() ?? 'Notification',
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      item['message']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _NotificationSettingsDialog extends StatefulWidget {
  const _NotificationSettingsDialog({required this.settings});
  final Map<String, dynamic> settings;

  @override
  State<_NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<_NotificationSettingsDialog> {
  late bool _soundEnabled;
  late bool _commentsEnabled;
  late bool _waitingEnabled;
  late String _soundName;
  late double _volume;
  bool _saving = false;

  static const _sounds = <String>[
    'notification.mp3',
    'notifications.mp3',
    'notificationss.mp3',
    'notification_ai voice.mp3',
  ];

  @override
  void initState() {
    super.initState();
    _soundEnabled = widget.settings['soundEnabled'] != false;
    _commentsEnabled = widget.settings['commentNotificationsEnabled'] != false;
    _waitingEnabled =
        widget.settings['waitingReasonNotificationsEnabled'] != false;
    _soundName = _sounds.contains(widget.settings['soundName'])
        ? widget.settings['soundName'] as String
        : _sounds.first;
    final requestedVolume =
        (widget.settings['soundVolume'] as num?)?.toDouble() ?? 70;
    _volume = requestedVolume < 0
        ? 0
        : (requestedVolume > 100 ? 100 : requestedVolume);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await HrmsNotificationsApi.updateSettings({
        'soundEnabled': _soundEnabled,
        'soundName': _soundName,
        'soundVolume': _volume.round(),
        'commentNotificationsEnabled': _commentsEnabled,
        'waitingReasonNotificationsEnabled': _waitingEnabled,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Notification settings'),
    content: SizedBox(
      width: 390,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Play a sound for new alerts'),
            value: _soundEnabled,
            onChanged: (value) => setState(() => _soundEnabled = value),
          ),
          DropdownButtonFormField<String>(
            value: _soundName,
            decoration: const InputDecoration(labelText: 'Notification sound'),
            items: _sounds
                .map(
                  (sound) => DropdownMenuItem(
                    value: sound,
                    child: Text(
                      sound.replaceAll('.mp3', '').replaceAll('_', ' '),
                    ),
                  ),
                )
                .toList(),
            onChanged: _soundEnabled
                ? (value) => setState(() => _soundName = value!)
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Volume'),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '${_volume.round()}%',
                  onChanged: _soundEnabled
                      ? (value) => setState(() => _volume = value)
                      : null,
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Employee comments'),
            value: _commentsEnabled,
            onChanged: (value) => setState(() => _commentsEnabled = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Field waiting reasons'),
            value: _waitingEnabled,
            onChanged: (value) => setState(() => _waitingEnabled = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving...' : 'Save settings'),
      ),
    ],
  );
}
