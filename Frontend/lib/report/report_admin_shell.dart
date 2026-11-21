// lib/report/report_admin_shell.dart
//
// The GoDigital "Task Manager" style shell, reused for the Report module so the
// report admin experience matches the main admin workspace exactly:
//   • collapsible navy sidebar with floating bubbles + brand logo,
//   • a top bar with search, Quick Add, notification bell and signed-in profile,
//   • the shared notification Robot (same scene as the employee top bar / admin
//     layout) that walks in for new notifications AND for in-app actions.
//
// It is pure chrome: the hosting screen passes its own nav items, search,
// Quick Add and body, and all report logic stays in the hosting screen.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/services/api_config.dart';
import 'package:godigital_portal/core/widgets/notification_robot.dart';

import 'report_brand.dart';
import 'report_notification_filter.dart';

/// Tracks how many drill-down routes are open on a report shell's nested
/// navigator, so the shell can show a single back button instead of a top bar
/// per sub-screen. [onDepth] fires with the current depth (0 = root).
class ReportShellNavObserver extends NavigatorObserver {
  ReportShellNavObserver(this.onDepth);
  final void Function(int depth) onDepth;
  int _depth = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) onDepth(++_depth);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && _depth > 0) onDepth(--_depth);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && _depth > 0) onDepth(--_depth);
  }
}

/// One sidebar entry for the report shell.
class ReportNavItem {
  const ReportNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Lets a hosting screen (which sits ABOVE the shell in the tree) trigger the
/// notification Robot for an in-app action — e.g. after a client is added.
/// Descendants of the shell should use [ReportRobotScope] instead.
class ReportRobotController {
  void Function(RobotEvent event, String message)? _play;
  void _bind(void Function(RobotEvent, String) fn) => _play = fn;

  /// Plays the Robot with [event] and [message]. No-op until the shell mounts.
  void play(RobotEvent event, String message) => _play?.call(event, message);
}

/// Lets any descendant of the shell trigger the notification Robot for an
/// in-app action (e.g. report approved / submitted). Null when not inside a
/// shell, so callers use `ReportRobotScope.of(context)?.play(...)`.
class ReportRobotScope extends InheritedWidget {
  const ReportRobotScope({super.key, required this.play, required super.child});

  final void Function(RobotEvent event, String message) play;

  static ReportRobotScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReportRobotScope>();

  @override
  bool updateShouldNotify(ReportRobotScope oldWidget) => false;
}

class ReportAdminShell extends StatefulWidget {
  const ReportAdminShell({
    super.key,
    required this.navItems,
    required this.child,
    this.brandTitle = 'GoDigital Reports',
    this.onSearch,
    this.searchHint = 'Search reports, clients...',
    this.quickAddLabel,
    this.onQuickAdd,
    this.onNotificationsTap,
    this.topActions = const <Widget>[],
    this.robotController,
    this.onBack,
    this.contextTitle,
  });

  final List<ReportNavItem> navItems;
  final Widget child;
  final String brandTitle;
  final ValueChanged<String>? onSearch;
  final String searchHint;
  final String? quickAddLabel;
  final VoidCallback? onQuickAdd;
  final VoidCallback? onNotificationsTap;

  /// When non-null, the top bar shows a back button (a drill-down is open).
  final VoidCallback? onBack;

  /// Optional title shown next to the back button for the open drill-down.
  final String? contextTitle;

  /// Extra desktop top-bar actions (e.g. a "Report template" button).
  final List<Widget> topActions;

  /// Optional controller for the hosting screen to play the Robot on actions.
  final ReportRobotController? robotController;

  @override
  State<ReportAdminShell> createState() => _ReportAdminShellState();
}

class _ReportAdminShellState extends State<ReportAdminShell>
    with TickerProviderStateMixin {
  bool _collapsed = false;
  final _searchController = TextEditingController();

  // Notifications / robot.
  Timer? _pollingTimer;
  Timer? _popupTimer;
  Timer? _robotActionTimer;
  int _unreadCount = 0;
  bool _showPopup = false;
  String? _latestMessage;
  RobotEvent _robotEvent = RobotEvent.generic;
  Set<int> _knownIds = {};
  bool _hasLoadedNotifications = false;
  final AudioPlayer _audio = AudioPlayer();

  late final AnimationController _bubble;
  late final AnimationController _robot;
  late final AnimationController _robotAction;
  late final AnimationController _robotPulse;

  @override
  void initState() {
    super.initState();
    _bubble = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
    _robot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
      reverseDuration: const Duration(milliseconds: 2200),
    );
    _robotAction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _robotPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    widget.robotController?._bind(_playRobot);
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _checkNewNotifications(),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkNewNotifications(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _popupTimer?.cancel();
    _robotActionTimer?.cancel();
    _searchController.dispose();
    _audio.dispose();
    _bubble.dispose();
    _robot.dispose();
    _robotAction.dispose();
    _robotPulse.dispose();
    super.dispose();
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<void> _checkNewNotifications() async {
    if (!mounted) return;
    final user = Provider.of<AuthService>(context, listen: false).user;
    final name = (user?['fullName'] ?? user?['full_name'] ?? user?['name'])
        ?.toString()
        .trim();
    if (name == null || name.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/notifications/${Uri.encodeComponent(name)}',
        ),
      );
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final List rows = body['data'] ?? [];
      int unread = 0;
      final current = <int>{};
      bool hasNew = false;
      String? latestMsg;
      RobotEvent latestEvent = RobotEvent.generic;
      for (final row in rows) {
        if (row is! Map ||
            !isReportWorkflowNotification(row['message']?.toString())) {
          continue;
        }
        final id = int.tryParse(row['id']?.toString() ?? '0') ?? 0;
        current.add(id);
        final sentByMe = row['type'] == 'SENT';
        final seen =
            row['isSeen'] == true ||
            row['isSeen'] == 1 ||
            row['isSeen'].toString() == 'true';
        if (!sentByMe && !seen) unread++;
        if (_hasLoadedNotifications &&
            !_knownIds.contains(id) &&
            !sentByMe &&
            !seen) {
          hasNew = true;
          final parsed = parseNotificationMessage(
            row['message']?.toString() ?? '',
          );
          if (parsed.preview.trim().isNotEmpty) {
            latestMsg = parsed.preview;
            latestEvent = classifyNotificationEvent(
              row,
              parsed.decoded,
              parsed.preview,
            );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _unreadCount = unread;
        _knownIds = current;
        _hasLoadedNotifications = true;
      });
      if (hasNew) {
        _playSound();
        _triggerRobot(latestMsg ?? 'You have a new notification', latestEvent);
      }
    } catch (_) {
      // Notifications are best-effort; never surface polling errors.
    }
  }

  void _playSound() async {
    try {
      await _audio.play(AssetSource('sounds/notification.mp3'));
    } catch (_) {}
  }

  // Adapter matching the (event, message) order used by the controller/scope.
  void _playRobot(RobotEvent event, String message) =>
      _triggerRobot(message, event);

  // Public-facing robot trigger (notifications + actions).
  void _triggerRobot(String message, RobotEvent event) {
    if (!mounted) return;
    _popupTimer?.cancel();
    final wasVisible = _showPopup;
    setState(() {
      _latestMessage = message;
      _robotEvent = event;
      _showPopup = true;
    });
    if (wasVisible) {
      _robot.forward();
    } else {
      _robot.forward(from: 0);
    }
    _robotAction.stop();
    _robotAction.value = 0;
    final actionDelayMs = wasVisible
        ? 0
        : ((0.70 - _robot.value).clamp(0.0, 1.0) *
                  _robot.duration!.inMilliseconds)
              .round();
    _robotActionTimer?.cancel();
    _robotActionTimer = Timer(Duration(milliseconds: actionDelayMs), () {
      if (!mounted || !_showPopup) return;
      _robotAction.forward(from: 0);
    });
    final remainingOpenMs =
        ((1 - _robot.value) * _robot.duration!.inMilliseconds).round();
    _popupTimer = Timer(
      Duration(milliseconds: remainingOpenMs + event.holdMs),
      _dismiss,
    );
  }

  void _dismiss() {
    if (!mounted) return;
    _robot.reverse().whenComplete(() {
      if (!mounted) return;
      if (_robot.status == AnimationStatus.dismissed) {
        _robotAction.stop();
        _robotAction.value = 0;
        setState(() => _showPopup = false);
      }
    });
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isSmall = constraints.maxWidth < 460;
        final sidebar = _buildSidebar();
        return Scaffold(
          backgroundColor: Colors.white,
          drawer: isDesktop ? null : Drawer(child: sidebar),
          body: SafeArea(
            child: ColoredBox(
              color: const Color(0xFFF6F9FE),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isDesktop) sidebar,
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          children: [
                            _buildTopBar(isDesktop, isSmall),
                            Expanded(
                              child: ReportRobotScope(
                                play: _playRobot,
                                child: widget.child,
                              ),
                            ),
                          ],
                        ),
                        if (_showPopup)
                          Positioned(
                            top: 74,
                            right: 20,
                            child: Material(
                              color: Colors.transparent,
                              child: NotificationRobotScene(
                                controller: _robot,
                                pulse: _robotPulse,
                                action: _robotAction,
                                event: _robotEvent,
                                message:
                                    _latestMessage ??
                                    'You have a new notification.',
                                maxWidth:
                                    MediaQuery.of(context).size.width - 40,
                              ),
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
      },
    );
  }

  // ── Sidebar ─────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _collapsed ? 76 : 252,
      child: AnimatedBuilder(
        animation: _bubble,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_bubble.value);
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xFF031C4C),
                  Color.fromARGB(255, 8, 52, 122),
                  Color.fromARGB(255, 6, 85, 189),
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -25 + (t * 15),
                  top: 60 + (t * 10),
                  child: _bubbleCircle(125, .09),
                ),
                Positioned(
                  left: -20 - (t * 15),
                  bottom: 100 - (t * 15),
                  child: _bubbleCircle(140, .06),
                ),
                SafeArea(
                  right: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sidebarHeader(),
                      Container(height: 1, color: Colors.white24),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in widget.navItems)
                                _navTile(item),
                            ],
                          ),
                        ),
                      ),
                      Container(height: 1, color: Colors.white24),
                      _sidebarFooterButton(
                        icon: Icons.home_rounded,
                        label: 'Workspace',
                        color: Colors.white70,
                        onTap: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                      ),
                      _sidebarFooterButton(
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        color: const Color(0xFFFF8080),
                        onTap: _logout,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bubbleCircle(double size, double opacity) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: opacity * .6),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
    ),
  );

  Widget _sidebarHeader() {
    return Container(
      height: 68,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: _collapsed ? 10 : 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_collapsed)
            Expanded(
              child: Row(
                children: [
                  const GoDigitalLogo(size: 34, radius: 10, padding: 4),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.brandTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Material(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(8),
            child: IconButton(
              tooltip: _collapsed ? 'Expand' : 'Collapse',
              icon: Icon(
                _collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => setState(() => _collapsed = !_collapsed),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(ReportNavItem item) {
    final active = item.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (MediaQuery.sizeOf(context).width < 900) {
              Navigator.maybePop(context);
            }
            item.onTap();
          },
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: .14),
          splashColor: Colors.white.withValues(alpha: .2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _collapsed ? 16 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: active ? const Color(0xFF0757D5) : Colors.white70,
                ),
                if (!_collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active
                            ? const Color(0xFF0757D5)
                            : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarFooterButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: .12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _collapsed ? 16 : 12,
              vertical: 11,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                if (!_collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isDesktop, bool isSmall) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    final userName =
        (user?['name'] ??
                user?['fullName'] ??
                user?['full_name'] ??
                'Admin User')
            .toString();
    final userRole = (auth.userRole ?? auth.userType ?? 'Administrator')
        .toString();
    final initials = userName
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: .06),
      child: Container(
        height: 68,
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 20),
        child: Row(
          children: [
            if (widget.onBack != null) ...[
              IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF0757D5),
                ),
                onPressed: widget.onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if ((widget.contextTitle ?? '').isNotEmpty && !isSmall) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    widget.contextTitle!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
            ] else if (!isDesktop)
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF0757D5)),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            if (widget.onBack == null && !isDesktop)
              SizedBox(width: isSmall ? 4 : 10),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.search,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) {
                            setState(() {});
                            widget.onSearch?.call(v);
                          },
                          decoration: InputDecoration(
                            hintText: widget.searchHint,
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            widget.onSearch?.call('');
                            setState(() {});
                          },
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (!isSmall && widget.onQuickAdd != null) ...[
              ElevatedButton.icon(
                onPressed: widget.onQuickAdd,
                icon: const Icon(Icons.add, size: 15, color: Colors.white),
                label: Text(
                  widget.quickAddLabel ?? 'Quick Add',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0757D5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (!isSmall) ...widget.topActions,
            // Notification bell + unread badge (drives the robot).
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    size: 21,
                    color: Color(0xFF475569),
                  ),
                  tooltip: 'Notifications',
                  onPressed: widget.onNotificationsTap,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            if (isDesktop) ...[
              Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    userRole.toLowerCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
            ],
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0757D5),
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
