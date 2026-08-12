import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:godigital_portal/services/api_config.dart';

class AdminLayout extends StatefulWidget {
  final String pageTitle;
  final String currentRoute;
  final Widget child;
  final Function(String)? onSearch;

  const AdminLayout({
    super.key,
    required this.pageTitle,
    required this.currentRoute,
    required this.child,
    this.onSearch,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  Timer? _pollingTimer;
  Timer? _popupTimer;

  int _unreadCount = 0;

  bool _showPopup = false;
  String? _latestMessage;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();

  Set<int> _knownNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _popupTimer?.cancel();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkNewNotifications();
    });
  }

  Future<void> _checkNewNotifications() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeName = authService.user?['fullName'];
    
    if (employeeName == null || employeeName.isEmpty) return;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/notifications/${Uri.encodeComponent(employeeName)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List rows = body["data"] ?? [];

        int unread = 0;
        Set<int> currentIds = {};
        bool hasNewNotification = false;
        String? latestMsgText;

        for (var row in rows) {
          int id = int.tryParse(row["id"]?.toString() ?? '0') ?? 0;
          currentIds.add(id);

          bool isSentByMe = row["type"] == "SENT";
          bool isSeen = row["isSeen"] == true || row["isSeen"] == 1 || row["isSeen"].toString() == "true";

          if (!isSentByMe && !isSeen) {
            unread++;
          }

          if (_knownNotificationIds.isNotEmpty && !_knownNotificationIds.contains(id) && !isSentByMe && !isSeen) {
            hasNewNotification = true;
            try {
              final decoded = jsonDecode(row["message"]);
              final preview = decoded["preview"] ?? "New Notification";
              latestMsgText = preview;
            } catch (e) {
              latestMsgText = row["message"] ?? "New Notification";
            }
          }
        }

        setState(() {
          _unreadCount = unread;
          if (_knownNotificationIds.isEmpty && currentIds.isNotEmpty) {
            _knownNotificationIds = currentIds;
          } else if (currentIds.isNotEmpty) {
            _knownNotificationIds = currentIds;
          }
        });

        if (hasNewNotification) {
          _playNotificationSound();
          _triggerTopRightPopup(latestMsgText ?? "You have a new notification");
        }
      }
    } catch (e) {
      debugPrint("Polling error: $e");
    }
  }

  void _triggerTopRightPopup(String message) {
    setState(() {
      _latestMessage = message;
      _showPopup = true;
    });

    _popupTimer?.cancel();
    _popupTimer = Timer(
      const Duration(seconds: 10),
      () {
        if (mounted) {
          setState(() {
            _showPopup = false;
          });
        }
      },
    );
  }

  void _playNotificationSound() async {
    try {
      await _audioPlayer.play(
        AssetSource("sounds/notification.mp3"),
      );
      debugPrint("Sound Played");
    } catch (e) {
      debugPrint("Audio Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;

    final String userName = user?['name']?.toString() ??
        user?['full_name']?.toString() ??
        user?['username']?.toString() ??
        'Admin User';

    final String userType = user?['user_type']?.toString() ?? 'Administrator';
    final String userRole = user?['role']?.toString() ?? 'Administrator';

    final String initials = userName
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        final bool isSmallMobile = constraints.maxWidth < 450;

        // Reusable Sidebar Widget with Close Button for Mobile
        final Widget sidebarWidget = Container(
          width: 230,
          color: const Color(0xFF151D2E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 64,
                width: double.infinity,
                color: const Color(0xFF151D2E),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'GoDigital Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (!isDesktop)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
              Container(height: 1, color: const Color(0xFF232D42)),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _navItem(Icons.dashboard_rounded, 'Dashboard', '/admin', context),
                      _navItem(Icons.person_add_alt_1_rounded, 'Client Onboarding', '/client-history', context),
                      _navItem(Icons.inventory_2_outlined, 'Package & Quotation', '/quotation', context),
                      _navItem(Icons.receipt_long_outlined, 'Invoice', '/invoice', context),
                      _navItem(Icons.assignment_outlined, 'Tasks Assign', '/tasks', context),
                      _navItem(Icons.assignment_outlined, 'Daily Planner', '/daily-planner', context),
                      _navItem(Icons.people_outline_rounded, 'Employee Status', '/employee-status', context),
                      _navItem(Icons.rate_review_outlined, 'Manager Review', '/manager-review', context),
                      _navItem(Icons.notifications_none_rounded, 'Notifications', '/notifications', context),
                      _navItem(Icons.show_chart_rounded, 'Performance', '/performance', context),
                      _navItem(Icons.admin_panel_settings_outlined, 'Employee Management', '/admin-panel', context),
                      _navItem(Icons.access_time_rounded, 'Time Manager', '/time-manager', context),
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: const Color(0xFF232D42)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final authService = Provider.of<AuthService>(context, listen: false);
                      await authService.logout();
                      if (!mounted) return;
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(
                        children: const [
                          Icon(Icons.logout_rounded, size: 17, color: Color(0xFF8A94A6)),
                          SizedBox(width: 12),
                          Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8A94A6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          drawer: isDesktop ? null : Drawer(child: sidebarWidget),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDesktop) sidebarWidget,

              // ── RIGHT PANEL ───────────────────────────────────────────────────────
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          const SizedBox(height: 65),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: SelectionArea(
                                      child: Padding(
                                        padding: const EdgeInsets.all(28),
                                        child: widget.child,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── FIXED TOP BAR ──────────────────────────────────────────
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Material(
                        color: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.12),
                        child: Container(
                          height: 64,
                          color: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 8 : 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 3-Dash Menu Icon (Only for mobile/tablet screens)
                              if (!isDesktop)
                                Builder(
                                  builder: (ctx) => IconButton(
                                    icon: const Icon(Icons.menu, color: Color(0xFF1A1A2E)),
                                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              if (!isDesktop) SizedBox(width: isSmallMobile ? 4 : 12),

                              // SEARCH BAR (Adjusted size for small mobile screens)
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 440),
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6FA),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE0E4EF)),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 8),
                                        const Icon(Icons.search, size: 16, color: Color(0xFFADB5BD)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: (value) {
                                              setState(() {});
                                              widget.onSearch?.call(value);
                                            },
                                            decoration: const InputDecoration(
                                              hintText: 'Search...',
                                              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9AA3B2)),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                        if (_searchController.text.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 16, color: Color(0xFF7B8494)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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

                              const SizedBox(width: 6),

                              // QUICK ADD (Hidden on very small mobile screens to prevent overflow, shown as icon or compact button)
                              if (!isSmallMobile) ...[
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/client-history');
                                  },
                                  icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                  label: const Text(
                                    'Quick Add',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2A52BE),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    elevation: 0,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],

                              // NOTIFICATION
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF555F6E)),
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/notifications');
                                    },
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                  ),
                                  if (_unreadCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        child: Text(
                                          '$_unreadCount',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              // HELP & SETTINGS (Hidden on small mobile to save space, available inside sidebar/settings menu)
                              if (!isSmallMobile) ...[
                                const SizedBox(width: 2),
                                IconButton(
                                  icon: const Icon(Icons.help_outline_rounded, size: 19, color: Color(0xFF555F6E)),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Help Center"),
                                        content: const Text("Need assistance?\n\nEmail: support@godigital.com\nPhone: +91 XXXXX XXXXX"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                                        ],
                                      ),
                                    );
                                  },
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  icon: const Icon(Icons.settings_outlined, size: 19, color: Color(0xFF555F6E)),
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/settings');
                                  },
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                ),
                              ],

                              const SizedBox(width: 4),
                              if (isDesktop) ...[
                                Container(width: 1, height: 36, color: const Color(0xFFE0E4EF)),
                                const SizedBox(width: 10),
                              ],

                              // MOBILE VIEW: Profile Icon with Popup Menu
                              if (!isDesktop)
                                PopupMenuButton<int>(
                                  offset: const Offset(0, 45),
                                  icon: const CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Color(0xFF2A52BE),
                                    child: Icon(Icons.person, size: 16, color: Colors.white),
                                  ),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      enabled: false,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
                                          const SizedBox(height: 2),
                                          Text("$userType | $userRole", style: const TextStyle(fontSize: 11, color: Color(0xFF8A94A6))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                              // DESKTOP VIEW: Admin Name & Details
                              if (isDesktop) ...[
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                                    Text(userType, style: const TextStyle(fontSize: 11, color: Color(0xFF8A94A6))),
                                    Text(userRole, style: const TextStyle(fontSize: 8, color: Color(0xFF8A94A6))),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF2A52BE),
                                  child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── NOTIFICATION POPUP ────────────────────────────────────
                    if (_showPopup)
                      Positioned(
                        top: 70,
                        right: 20,
                        child: Material(
                          elevation: 10,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 320,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2A52BE)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications_active, color: Color(0xFF2A52BE)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("New Notification", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 3),
                                      Text(
                                        _latestMessage ?? "",
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navItem(IconData icon, String title, String route, BuildContext context) {
    final bool isActive = widget.currentRoute == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isActive) Navigator.pushNamed(context, route);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF2A52BE) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: isActive ? Colors.white : const Color(0xFF8A94A6)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? Colors.white : const Color(0xFF8A94A6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}