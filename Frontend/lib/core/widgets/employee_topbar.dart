import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../constants/app_colors.dart';
import '../constants/employee_role.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart';

class EmployeeTopbar extends StatefulWidget {
  final EmployeeRole role;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAssignedTasks;
  final Function(String)? onSearch;

  const EmployeeTopbar({
    super.key,
    required this.role,
    this.onOpenNotifications,
    this.onOpenAssignedTasks,
    this.onSearch,
  });

  @override
  State<EmployeeTopbar> createState() => _EmployeeTopbarState();
}

class _EmployeeTopbarState extends State<EmployeeTopbar> {
  Timer? _pollingTimer;
  int _unreadCount = 0;
  String? _latestMessage;
  bool _showPopup = false;
  Timer? _popupTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Set<int> _knownNotificationIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _popupTimer?.cancel();
    _searchController.dispose();
    _audioPlayer.dispose();
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

  void _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint("Audio play error: $e");
    }
  }

   void _triggerTopRightPopup(String message) {
    setState(() {
      _latestMessage = message;
      _showPopup = true;
    });

    _popupTimer?.cancel();
    _popupTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showPopup = false;
        });
      }
    });
  }

 @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    final bool isSmallMobile = MediaQuery.of(context).size.width < 450;

    return SizedBox(
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 8 : 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 📱 Hamburger Menu Icon for Mobile
                if (!isDesktop) ...[
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: AppColors.textDark),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  SizedBox(width: isSmallMobile ? 4 : 12),
                ],

                // 🔍 Responsive Search Bar
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(Icons.search, size: 16, color: AppColors.textGrey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {});
                                widget.onSearch?.call(value);
                              },
                              decoration: const InputDecoration(
                                hintText: 'Search tasks, clients...',
                                hintStyle: TextStyle(fontSize: 12, color: AppColors.textGrey),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.textGrey),
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
                
                const SizedBox(width: 8),
                
                // 🔔 Notification Icon with Badge
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 20, color: AppColors.textDark),
                      onPressed: widget.onOpenNotifications,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                
                if (!isSmallMobile) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.textDark),
                  const SizedBox(width: 16),
                  Container(height: 30, width: 1, color: AppColors.border),
                  const SizedBox(width: 14),
                ],

                // 👤 User Profile Section
                Consumer<AuthService>(
                  builder: (context, authService, _) {
                    final employeeName = authService.user?['fullName'] ?? 'Employee';
                    final employeeRole = authService.user?['role'] ?? widget.role.title;
                    final initials = authService.user?['initials'] ?? _generateInitials(employeeName);

                    if (!isDesktop) {
                      return PopupMenuButton<int>(
                        offset: const Offset(0, 45),
                        icon: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            enabled: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                                const SizedBox(height: 2),
                                Text(employeeRole, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              employeeName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark),
                            ),
                            Text(
                              employeeRole,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            initials,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 🌟 Top-Right Notification Popup
          if (_showPopup)
            Positioned(
              top: 68,
              right: 20,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("New Notification", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textDark)),
                            const SizedBox(height: 2),
                            Text(
                              _latestMessage ?? "",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
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
    );
  }
 
  String _generateInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    } else {
      return parts.first[0].toUpperCase();
    }
  }
}