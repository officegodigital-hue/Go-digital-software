import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'package:godigital_portal/services/auth_storage.dart';
// lib/services/app_notification_center.dart
//
// One notification listener for the whole app, on every page: Home,
// Attendance, Task Manager, Client Repository and the rest.
//   • New chat / group / client-group messages and task notifications play
//     the notification sound and show a banner at the top of the screen.
//   • Chrome / Edge: when the tab is in the background or minimised, a
//     desktop (browser) notification is shown as well.
//   • Phone: when the app is closed or in the background, Firebase push
//     (push_notification_service.dart) shows the system notification.
//
// Started once after login (HomeScreen / layouts call start()). It keeps
// running when you move between pages because it is not tied to one page.

import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'api_config.dart';
import 'browser_notifier_stub.dart'
    if (dart.library.js_interop) 'browser_notifier_web.dart' as browser;
import 'push_notification_service.dart';

class AppNotificationCenter with WidgetsBindingObserver {
  AppNotificationCenter._();
  static final AppNotificationCenter instance = AppNotificationCenter._();

  /// Task Manager layouts (admin layout / employee top bar) already play a
  /// sound and show a pop-up for the notifications list while they are open.
  /// They increase this so the same alert is not shown twice.
  static int layoutPollers = 0;

  String? _employee;
  OverlayState? _overlay;
  IO.Socket? _socket;
  Future<void> Function()? _onAccountDeactivated;
  Timer? _pollTimer;
  Timer? _groupsTimer;
  final AudioPlayer _player = AudioPlayer();
  final Set<int> _knownIds = {};
  bool _primed = false;
  bool _foreground = true;
  bool _observing = false;
  final Set<String> _myGroups = {};
  final Set<String> _myClients = {};
  final Map<String, DateTime> _recent = {};

  OverlayEntry? _banner;
  Timer? _bannerTimer;

  bool get running => _employee != null;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get _base => ApiConfig.baseUrl;
  String get _socketUrl => _base.trim().replaceFirst(RegExp(r'/api/?$'), '');

  static String _k(dynamic v) => (v?.toString() ?? '').trim().toLowerCase();

  /// Call after login with the user's full name. Safe to call from many pages.
  void start(BuildContext context, String? employee) {
    final name = employee?.trim() ?? '';
    if (name.isEmpty) return;
    final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay != null) _overlay = overlay;
    _onAccountDeactivated = () async {
      final navigator = Navigator.of(context, rootNavigator: true);
      final auth = context.read<AuthService>();
      stop();
      await auth.logout();
      if (navigator.mounted) navigator.pushNamedAndRemoveUntil('/', (_) => false);
    };
    if (_employee == name) return;

    stop();
    _employee = name;
    PushNotificationService.inAppAlertsActive = true;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _poll());
    _loadGroups();
    _groupsTimer = Timer.periodic(const Duration(minutes: 3), (_) => _loadGroups());
    _connectSocket();

    if (kIsWeb) browser.requestPermission();
    PushNotificationService.instance.registerUser(name);
  }

  /// Call on logout.
  void stop() {
    _pollTimer?.cancel();
    _groupsTimer?.cancel();
    _pollTimer = null;
    _groupsTimer = null;
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _employee = null;
    _knownIds.clear();
    _primed = false;
    _myGroups.clear();
    _myClients.clear();
    _hideBanner();
    PushNotificationService.inAppAlertsActive = false;
  }

  /// Browser permission (Settings card button). Returns 'granted', 'denied' …
  Future<String> enableBrowserNotifications() => browser.requestPermission();
  String get browserPermission => browser.permission;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On the phone, background alerts come from Firebase push instead.
    if (_isMobile) _foreground = state == AppLifecycleState.resumed;
  }

  // ── Notifications list (private chat + task alerts) ─────────────────────
  Future<void> _poll() async {
    final me = _employee;
    if (me == null) return;
    try {
      final res = await http.get(Uri.parse('$_base/notifications/${Uri.encodeComponent(me)}'));
      if (res.statusCode != 200 || _employee != me) return;
      final body = jsonDecode(res.body);
      final rows = body is Map ? (body['data'] as List? ?? []) : (body is List ? body : []);
      final fresh = <Map>[];
      for (final row in rows) {
        if (row is! Map) continue;
        final id = int.tryParse('${row['id'] ?? 0}') ?? 0;
        if (id == 0 || _knownIds.contains(id)) continue;
        _knownIds.add(id);
        final mine = row['type'] == 'SENT';
        final seen = row['isSeen'] == true || row['isSeen'] == 1 || '${row['isSeen']}' == 'true';
        if (_primed && !mine && !seen) fresh.add(row);
      }
      _primed = true;
      if (fresh.isEmpty) return;
      // Task Manager pages already alert for these; the chat page shows chats.
      if (layoutPollers > 0) return;
      final row = fresh.last;
      final sender = (row['senderName'] ?? row['sender_name'] ?? row['sender'] ?? '').toString();
      _alert(
        title: sender.isEmpty ? 'GoDigital' : sender,
        body: fresh.length > 1
            ? '${_preview(row['message'])}  (+${fresh.length - 1} more)'
            : _preview(row['message']),
        key: 'n|$sender',
        chat: true,
      );
    } catch (e) {
      debugPrint('Notification poll error: $e');
    }
  }

  // ── Groups I belong to (for group sound) ────────────────────────────────
  Future<void> _loadGroups() async {
    final me = _employee;
    if (me == null) return;
    try {
      final res = await http.get(Uri.parse('$_base/chat/${Uri.encodeComponent(me)}'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final groups = body is Map ? (body['groups'] as List? ?? []) : [];
        final mine = <String>{};
        for (final g in groups) {
          if (g is! Map) continue;
          final name = _k(g['group_name']);
          if (name.isEmpty) continue;
          var member = _k(g['created_by']) == _k(me);
          try {
            final raw = g['members'];
            final list = raw is List ? raw : jsonDecode(raw?.toString() ?? '[]');
            if (list is List && list.any((m) => _k(m) == _k(me))) member = true;
          } catch (_) {}
          if (member) mine.add(name);
        }
        _myGroups
          ..clear()
          ..addAll(mine);
      }
    } catch (_) {}
    try {
      final res = await http.get(
        Uri.parse('$_base/workspace-tasks/team/groups').replace(queryParameters: {'employee': me}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body is Map ? (body['data'] as List? ?? []) : [];
        _myClients
          ..clear()
          ..addAll(list.whereType<Map>().map((c) => _k(c['client_name'])).where((c) => c.isNotEmpty));
      }
    } catch (_) {}
  }

  // ── Live socket (instant group / client-group messages) ─────────────────
  void _connectSocket() {
    try {
      final socket = IO.io(_socketUrl, {
        'transports': ['websocket'],
        'auth': {'token': AuthStorage.cachedToken},
        'autoConnect': false,
        'reconnection': true,
        'forceNew': true,
      });
      socket.on('account_deactivated', (_) { _onAccountDeactivated?.call(); });
      socket.on('receive_group_message', (payload) {
        if (payload is! Map) return;
        final sender = '${payload['senderName'] ?? ''}';
        final group = '${payload['recipientName'] ?? payload['groupName'] ?? ''}';
        if (_k(sender) == _k(_employee) || !_myGroups.contains(_k(group))) return;
        _alert(
          title: '$sender  •  $group',
          body: _preview(payload['message']),
          key: 'g|$group|$sender',
          chat: true,
        );
      });
      void direct(dynamic payload) {
        if (payload is! Map || layoutPollers > 0) return;
        final isGroup = payload['isGroup'] == true || payload['isGroup'] == 1 || '${payload['isGroup']}' == '1';
        if (isGroup) return;
        final sender = '${payload['senderName'] ?? ''}';
        if (_k(payload['recipientName']) != _k(_employee) || _k(sender) == _k(_employee)) return;
        final id = int.tryParse('${payload['id'] ?? 0}') ?? 0;
        if (id != 0) _knownIds.add(id); // the list poll will not repeat it
        _alert(title: sender.isEmpty ? 'GoDigital' : sender, body: _preview(payload['message']), key: 'n|$sender', chat: true);
      }

      socket.on('receive_message', direct);
      socket.on('new_notification', direct);
      socket.on('workspace_client_chat', (payload) {
        if (payload is! Map) return;
        final client = '${payload['client'] ?? ''}';
        final sender = '${payload['sender'] ?? ''}';
        if (_k(sender) == _k(_employee) || !_myClients.contains(_k(client))) return;
        _alert(
          title: '$sender  •  $client',
          body: 'New message in the $client client group',
          key: 'c|$client|$sender',
          chat: true,
        );
      });
      socket.connect();
      _socket = socket;
    } catch (e) {
      debugPrint('Notification socket error: $e');
    }
  }

  String _preview(dynamic raw) {
    if (raw == null) return 'New notification';
    var value = raw;
    if (value is String) {
      final t = value.trim();
      if (!t.startsWith('{')) return t.isEmpty ? 'New notification' : t;
      try {
        value = jsonDecode(t);
      } catch (_) {
        return t;
      }
    }
    if (value is Map) {
      if (value['type'] == 'file') return '📎 ${value['fileName'] ?? value['name'] ?? 'Shared a file'}';
      return '${value['preview'] ?? value['text'] ?? value['message'] ?? 'New notification'}';
    }
    return value.toString();
  }

  // ── Show it ─────────────────────────────────────────────────────────────
  void _alert({required String title, required String body, required String key, bool chat = false}) {
    if (_employee == null || !_foreground) return;
    if (chat && PushNotificationService.chatScreenOpen) return; // chat page shows it
    final now = DateTime.now();
    _recent.removeWhere((_, t) => now.difference(t).inSeconds > 20);
    final last = _recent[key];
    if (last != null && now.difference(last).inSeconds < 4) return;
    _recent[key] = now;

    _playSound();
    if (kIsWeb && browser.pageHidden) {
      browser.show(title, body, tag: key);
    }
    _showBanner(title, body);
  }

  Future<void> _playSound() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Notification sound error: $e');
    }
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    try {
      _banner?.remove();
    } catch (_) {}
    _banner = null;
  }

  void _showBanner(String title, String body) {
    final overlay = _overlay;
    if (overlay == null || !overlay.mounted) return;
    _hideBanner();
    final entry = OverlayEntry(
      builder: (context) => _TopBanner(
        title: title,
        body: body,
        onClose: _hideBanner,
      ),
    );
    _banner = entry;
    overlay.insert(entry);
    _bannerTimer = Timer(const Duration(seconds: 5), _hideBanner);
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.title, required this.body, required this.onClose});

  final String title;
  final String body;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final width = MediaQuery.of(context).size.width;
    return Positioned(
      top: top + 10,
      left: width < 600 ? 10 : null,
      right: 10,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, -20 * (1 - t)), child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width < 600 ? null : 380,
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1F44),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0052CC),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFC7D4EA), fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF9FB0CC), size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
