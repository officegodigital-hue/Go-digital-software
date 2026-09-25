// lib/core/widgets/employee_topbar.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart'; // 🟢 Added for saving agreed state
import '../constants/app_colors.dart';
import '../constants/employee_role.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart';

class EmployeeTopbar extends StatefulWidget {
  final EmployeeRole role;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAssignedTasks;
  final VoidCallback? onTapWorkingHours;
  final Function(String)? onSearch;

  const EmployeeTopbar({
    super.key,
    required this.role,
    this.onOpenNotifications,
    this.onOpenAssignedTasks,
    this.onTapWorkingHours,
    this.onSearch,
  });

  @override
  State<EmployeeTopbar> createState() => _EmployeeTopbarState();
}

class _EmployeeTopbarState extends State<EmployeeTopbar> with TickerProviderStateMixin {
  Timer? _pollingTimer;
  int _unreadCount = 0;
  String? _latestMessage;
  bool _showPopup = false;
  Timer? _popupTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  IO.Socket? _socket;
  Set<int> _knownNotificationIds = {};
  final TextEditingController _searchController = TextEditingController();

  String formattedTotalWorkingTime = "00h 00m";

  late AnimationController _rotateController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  bool _isPaused = false;
  bool _isBroadcastPopupShowing = false;

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _startPolling();
    _fetchTodayWorkingHours();
    _connectNotificationSocket();
    _checkActiveBroadcast();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _popupTimer?.cancel();
    _searchController.dispose();
    _socket?.dispose();
    _audioPlayer.dispose();
    _rotateController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  String get _socketUrl {
    return ApiConfig.baseUrl.trim().replaceFirst(RegExp(r'/api/?$'), '');
  }

 // 🟢 Broadcast/automation popup check with stable per-event acknowledgement keys.
  // Future<void> _checkActiveBroadcast() async {
  //   final authService = Provider.of<AuthService>(context, listen: false);
  //   final employeeId = authService.user?['id'];
  //   final employeeName =
  //       authService.user?['fullName'] ?? authService.user?['name'] ?? '';

  //   if (employeeId == null || employeeName.toString().trim().isEmpty) return;

  //   try {
  //     final response =
  //         await http.get(Uri.parse('${ApiConfig.baseUrl}/broadcast/settings'));

  //     if (response.statusCode != 200) return;

  //     final data = jsonDecode(response.body) as Map<String, dynamic>;

  //     final bool isActive = data['isActive'] ?? false;
  //     final bool newClientOn = data['newClientEnabled'] ?? true;
  //     final bool inactiveClientOn = data['inactiveClientEnabled'] ?? true;
  //     final String adminMessage = (data['message'] ?? '').toString().trim();

  //     // IMPORTANT:
  //     // Manual message title MUST always come from Admin's selected
  //     // Emergency / Warning / Important value.
  //     final String severity =
  //         (data['severity'] ?? 'Warning').toString().trim();

  //     final dynamic targetEmpId = data['targetEmployeeId'];
  //     final String dbBroadcastId = (data['id'] ?? 0).toString();

  //     if (!isActive) return;

  //     if (targetEmpId != null &&
  //         targetEmpId.toString() != employeeId.toString()) {
  //       return;
  //     }

  //     final prefs = await SharedPreferences.getInstance();
  //     final agreedKey = 'agreed_broadcast_key_$employeeId';

  //     final String lastAgreedKey = prefs.getString(agreedKey) ?? '';

  //     // 1. ADMIN MANUAL MESSAGE
  //     // Only this uses the Admin selected severity as the popup title.
  //     if (adminMessage.isNotEmpty && dbBroadcastId != '0') {
  //       final manualKey = 'manual:$dbBroadcastId';

  //       if (lastAgreedKey != manualKey && !_isBroadcastPopupShowing) {
  //         _showBlueWhiteAgreePopup(
  //           adminMessage,
  //           severity,
  //           manualKey,
  //           employeeId,
  //         );
  //         return;
  //       }
  //     }

  //     // 2. AUTOMATED CLIENT / TASK POPUPS
  //     // These are ALWAYS "Information Alert", never Emergency/Warning/Important.
  //     final summaryRes = await http.get(
  //       Uri.parse(
  //         '${ApiConfig.baseUrl}/dashboard/summary/${Uri.encodeComponent(employeeName.toString())}',
  //       ),
  //     );

  //     if (summaryRes.statusCode != 200) return;

  //     final summaryData =
  //         (jsonDecode(summaryRes.body)['data'] ?? {}) as Map<String, dynamic>;

  //     final todayKey = DateTime.now().toIso8601String().substring(0, 10);

  //     // 2A. New client task assigned.
  //     final newClientsList =
  //         List<dynamic>.from(summaryData['newClientsList'] ?? []);

  //     if (newClientOn && newClientsList.isNotEmpty) {
  //       final clientNames = newClientsList
  //           .map((c) => (c['clientName'] ?? 'Client').toString().trim())
  //           .where((name) => name.isNotEmpty)
  //           .toSet()
  //           .toList()
  //         ..sort();

  //       if (clientNames.isNotEmpty) {
  //         final namesKey = clientNames.join('|').toLowerCase();
  //         final newClientKey = 'new-client:$todayKey:$namesKey';

  //         final triggerMsg =
  //             'New client task assigned for: ${clientNames.join(', ')}. '
  //             'Please check your task panel.';

  //         if (lastAgreedKey != newClientKey &&
  //             !_isBroadcastPopupShowing) {
  //           _showBlueWhiteAgreePopup(
  //             triggerMsg,
  //             'Information',
  //             newClientKey,
  //             employeeId,
  //           );
  //           return;
  //         }
  //       }
  //     }

  //     // 2B. NEW TASK ASSIGNMENT notification.
  //     // This catches a newly assigned task even when the client itself
  //     // was created earlier, so the popup does not depend only on
  //     // clients.created_at.
  //     if (newClientOn) {
  //       try {
  //         final notificationRes = await http.get(
  //           Uri.parse(
  //             '${ApiConfig.baseUrl}/dashboard/recent-notifications/${Uri.encodeComponent(employeeName.toString())}',
  //           ),
  //         );

  //         if (notificationRes.statusCode == 200) {
  //           final notificationData =
  //               (jsonDecode(notificationRes.body)['data'] ?? []) as List;

  //           for (final item in notificationData) {
  //             if (item is! Map) continue;

  //             final dynamic notificationId = item['id'];
  //             final String category =
  //                 (item['category'] ?? '').toString().toLowerCase();
  //             final String preview =
  //                 (item['preview'] ?? item['message'] ?? '').toString().trim();

  //             if (notificationId == null ||
  //                 !category.contains('task assigned')) {
  //               continue;
  //             }

  //             final taskKey = 'task-assigned:$notificationId';

  //             if (lastAgreedKey != taskKey && !_isBroadcastPopupShowing) {
  //               final taskMessage = preview.isNotEmpty
  //                   ? preview
  //                   : 'A new task has been assigned to you. Please check your task panel.';

  //               _showBlueWhiteAgreePopup(
  //                 taskMessage,
  //                 'Information',
  //                 taskKey,
  //                 employeeId,
  //               );
  //               return;
  //             }
  //           }
  //         }
  //       } catch (e) {
  //         debugPrint('Task assignment popup check error: $e');
  //       }
  //     }

  //     // 2C. Inactive client.
  //     final inactiveList =
  //         List<dynamic>.from(summaryData['inactiveTodayList'] ?? []);

  //     if (inactiveClientOn && inactiveList.isNotEmpty) {
  //       final clientNames = inactiveList
  //           .map((c) => (c['clientName'] ?? 'Client').toString().trim())
  //           .where((name) => name.isNotEmpty)
  //           .toSet()
  //           .toList()
  //         ..sort();

  //       if (clientNames.isNotEmpty) {
  //         final namesKey = clientNames.join('|').toLowerCase();
  //         final inactiveKey = 'inactive-client:$todayKey:$namesKey';

  //         final triggerMsg =
  //             'Assigned client(s) marked inactive: ${clientNames.join(', ')}.';

  //         if (lastAgreedKey != inactiveKey &&
  //             !_isBroadcastPopupShowing) {
  //           _showBlueWhiteAgreePopup(
  //             triggerMsg,
  //             'Information',
  //             inactiveKey,
  //             employeeId,
  //           );
  //           return;
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint("Broadcast check error: $e");
  //   }
  // }


  // // 🟢 Blue & White Gradient Modal Popup with dynamic title matching severity
  // void _showBlueWhiteAgreePopup(String message, String severity, String broadcastKey, dynamic employeeId) {
  //   if (!mounted) return;
  //   setState(() {
  //     _isBroadcastPopupShowing = true;
  //   });

  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext dialogContext) {
  //       return PopScope(
  //         canPop: false,
  //         child: AlertDialog(
  //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //           contentPadding: EdgeInsets.zero,
  //           content: Container(
  //             width: 420,
  //             padding: const EdgeInsets.all(24),
  //             decoration: BoxDecoration(
  //               borderRadius: BorderRadius.circular(20),
  //               gradient: const LinearGradient(
  //                 begin: Alignment.topCenter,
  //                 end: Alignment.bottomCenter,
  //                 colors: [Color(0xFFF0F5FF), Colors.white],
  //               ),
  //             ),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 Container(
  //                   padding: const EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     color: const Color(0xFF0757D5).withValues(alpha: 0.1),
  //                     shape: BoxShape.circle,
  //                   ),
  //                   child: Icon(
  //                     severity == 'Emergency' 
  //                         ? Icons.error_outline 
  //                         : severity == 'Warning' 
  //                             ? Icons.warning_amber_rounded 
  //                             : Icons.info_outline_rounded,
  //                     color: const Color(0xFF0757D5),
  //                     size: 32,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 14),
  //                 Text(
  //                   '$severity Alert', // Admin kudutha Emergency/Warning/Important title ingae varum
  //                   style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF04296B)),
  //                 ),
  //                 const SizedBox(height: 10),
  //                 Text(
  //                   message, // Client names-udan message ingae varum
  //                   textAlign: TextAlign.center,
  //                   style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
  //                 ),
  //                 const SizedBox(height: 24),
  //                 SizedBox(
  //                   width: double.infinity,
  //                   child: ElevatedButton(
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: const Color(0xFF0757D5),
  //                       padding: const EdgeInsets.symmetric(vertical: 14),
  //                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //                       elevation: 0,
  //                     ),
  //                     onPressed: () async {
  //                       final prefs = await SharedPreferences.getInstance();
  //                       await prefs.setString('agreed_broadcast_key_$employeeId', broadcastKey);

  //                       if (dialogContext.mounted) {
  //                         Navigator.of(dialogContext).pop();
  //                       }
  //                       setState(() {
  //                         _isBroadcastPopupShowing = false;
  //                       });
  //                     },
  //                     child: const Text(
  //                       'Agree',
  //                       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

Future<void> _checkActiveBroadcast() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeId = authService.user?['id'];
    final employeeName =
        authService.user?['fullName'] ?? authService.user?['name'] ?? '';

    if (employeeId == null || employeeName.toString().trim().isEmpty) return;

    try {
      final response =
          await http.get(Uri.parse('${ApiConfig.baseUrl}/broadcast/settings'));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final bool isActive = data['isActive'] ?? false;
      final bool newClientOn = data['newClientEnabled'] ?? true;
      final bool inactiveClientOn = data['inactiveClientEnabled'] ?? true;
      final String adminMessage = (data['message'] ?? '').toString().trim();
      final String severity =
          (data['severity'] ?? 'Warning').toString().trim();

      final dynamic targetEmpId = data['targetEmployeeId'];
      final String dbBroadcastId = (data['id'] ?? 0).toString();

      if (!isActive) return;

      if (targetEmpId != null &&
          targetEmpId.toString() != employeeId.toString()) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // 1. ADMIN MANUAL MESSAGE
      if (adminMessage.isNotEmpty && dbBroadcastId != '0') {
        final manualKey = 'manual_agreed_$employeeId';
        final savedMsg = prefs.getString(manualKey) ?? '';

        // Puthu message-ah iruntha mattum thaan open aagum, same message-ku open aagathu
        if (savedMsg != adminMessage && !_isBroadcastPopupShowing) {
          _showBlueWhiteAgreePopup(
            adminMessage,
            severity,
            manualKey,
            adminMessage,
            employeeId,
          );
          return;
        }
      }

      // 2. AUTOMATED CLIENT / TASK POPUPS
      final summaryRes = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/dashboard/summary/${Uri.encodeComponent(employeeName.toString())}',
        ),
      );

      if (summaryRes.statusCode != 200) return;

      final summaryData =
          (jsonDecode(summaryRes.body)['data'] ?? {}) as Map<String, dynamic>;

      // 2A. New client task assigned
      final newClientsList =
          List<dynamic>.from(summaryData['newClientsList'] ?? []);

      if (newClientOn && newClientsList.isNotEmpty) {
        final clientNames = newClientsList
            .map((c) => (c['clientName'] ?? 'Client').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        if (clientNames.isNotEmpty) {
          final namesStr = clientNames.join(', ');
          final triggerMsg =
              'New client task assigned for: $namesStr. '
              'Please check your task panel.';

          final newClientKey = 'new_client_agreed_$employeeId';
          final savedNewClient = prefs.getString(newClientKey) ?? '';

          if (savedNewClient != namesStr && !_isBroadcastPopupShowing) {
            _showBlueWhiteAgreePopup(
              triggerMsg,
              'Information',
              newClientKey,
              namesStr,
              employeeId,
            );
            return;
          }
        }
      }

      // 2B. Inactive client
      final inactiveList =
          List<dynamic>.from(summaryData['inactiveTodayList'] ?? []);

      if (inactiveClientOn && inactiveList.isNotEmpty) {
        final clientNames = inactiveList
            .map((c) => (c['clientName'] ?? 'Client').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        if (clientNames.isNotEmpty) {
          final namesStr = clientNames.join(', ');
          final triggerMsg =
              'Assigned client(s) marked inactive: $namesStr.';

          final inactiveKey = 'inactive_client_agreed_$employeeId';
          final savedInactive = prefs.getString(inactiveKey) ?? '';

          if (savedInactive != namesStr && !_isBroadcastPopupShowing) {
            _showBlueWhiteAgreePopup(
              triggerMsg,
              'Information',
              inactiveKey,
              namesStr,
              employeeId,
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Broadcast check error: $e");
    }
  }

  void _showBlueWhiteAgreePopup(String message, String severity, String storageKey, String contentValue, dynamic employeeId) {
    if (!mounted) return;
    setState(() {
      _isBroadcastPopupShowing = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0F5FF), Colors.white],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0757D5).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      severity == 'Emergency' 
                          ? Icons.error_outline 
                          : severity == 'Warning' 
                              ? Icons.warning_amber_rounded 
                              : Icons.info_outline_rounded,
                      color: const Color(0xFF0757D5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$severity Alert',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF04296B)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0757D5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        // Indha specific message / client string-ah save seithu viduvathal, adutha murai same message-ku popup varaathu
                        await prefs.setString(storageKey, contentValue);

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        setState(() {
                          _isBroadcastPopupShowing = false;
                        });
                      },
                      child: const Text(
                        'Agree',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
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


  void _connectNotificationSocket() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeName = authService.user?['fullName'];
    if (employeeName == null || employeeName.toString().isEmpty) return;

    try {
      _socket = IO.io(_socketUrl, {
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
      });

      _socket!.connect();

      void handle(dynamic payload) {
        if (!mounted || payload is! Map) return;
        final recipient = payload['recipientName']?.toString() ?? '';
        final sender = payload['senderName']?.toString() ?? '';
        final isGroup = payload['isGroup'] == true ||
            payload['isGroup'] == 1 ||
            payload['isGroup']?.toString() == '1';

        if (isGroup || recipient != employeeName || sender == employeeName) return;

        final id = int.tryParse(payload['id']?.toString() ?? '') ?? 0;
        if (id != 0 && _knownNotificationIds.contains(id)) return;
        if (id != 0) _knownNotificationIds.add(id);

        setState(() => _unreadCount += 1);

        final raw = payload['message']?.toString() ?? 'New message';
        String preview = raw;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            preview = decoded['preview']?.toString() ??
                decoded['text']?.toString() ??
                (decoded['fileName'] != null ? '📎 ${decoded['fileName']}' : raw);
          }
        } catch (_) {}

        _playNotificationSound();
        _triggerTopRightPopup(preview);
      }

      _socket!.on('new_notification', handle);
    } catch (e) {
      debugPrint('Topbar socket init error: $e');
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkNewNotifications();
      await _fetchTodayWorkingHours();
      await _checkActiveBroadcast();
    });
  }

  Future<void> _fetchTodayWorkingHours() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeName = authService.user?['fullName'] ?? authService.user?['name'] ?? authService.user?['username'];
    
    if (employeeName == null || employeeName.isEmpty) return;

    try {
      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final url = Uri.parse('${ApiConfig.baseUrl}/dashboard/live-tracking-tasks/$employeeName?date=$formattedDate');
      final r = await http.get(url);

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final rows = List<dynamic>.from(body['data'] ?? []);

        int totalSumSeconds = 0;
        for (var row in rows) {
          String durStr = (row["duration"] ?? "").toString().toLowerCase();
          
          int hrs = 0;
          int mins = 0;

          if (durStr.contains('hrs') || durStr.contains('hr')) {
            final parts = durStr.split('hr');
            hrs = int.tryParse(parts[0].trim()) ?? 0;
            if (parts.length > 1 && parts[1].contains('min')) {
              final minPart = parts[1].replaceAll('s', '').replaceAll('mins', '').replaceAll('min', '').trim();
              mins = int.tryParse(minPart) ?? 0;
            }
          } else if (durStr.contains('min')) {
            final minPart = durStr.replaceAll('s', '').replaceAll('mins', '').replaceAll('min', '').trim();
            mins = int.tryParse(minPart) ?? 0;
          }

          totalSumSeconds += (hrs * 3600) + (mins * 60);
        }

        int totalHours = totalSumSeconds ~/ 3600;
        int totalMinutes = (totalSumSeconds % 3600) ~/ 60;

        if (mounted) {
          setState(() {
            formattedTotalWorkingTime = '${totalHours.toString().padLeft(2, '0')}h ${totalMinutes.toString().padLeft(2, '0')}m';
          });
        }
      }
    } catch (e) {
      debugPrint("Working hours fetch error: $e");
    }
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

                MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      _isPaused = true;
                      _rotateController.stop();
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _isPaused = false;
                      _rotateController.repeat();
                    });
                  },
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPaused = !_isPaused;
                        if (_isPaused) {
                          _rotateController.stop();
                        } else {
                          _rotateController.repeat();
                        }
                      });
                      widget.onTapWorkingHours?.call();
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_rotateController, _glowAnimation]),
                      builder: (context, child) {
                        final double angle = _isPaused 
                            ? 0.0 
                            : _rotateController.value * 2 * 3.141592653589793;
                        final bool isBackSide = angle > (3.141592653589793 / 2) && angle < (3 * 3.141592653589793 / 2);
                        final double currentGlow = _glowAnimation.value;

                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          alignment: Alignment.center,
                          child: Transform(
                            transform: Matrix4.identity()
                              ..rotateY(isBackSide ? 3.141592653589793 : 0.0),
                            alignment: Alignment.center,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withValues(alpha: 0.6),
                                    blurRadius: currentGlow * 1.5,
                                    spreadRadius: currentGlow * 0.4,
                                  ),
                                  BoxShadow(
                                    color: Colors.purpleAccent.withValues(alpha: 0.5),
                                    blurRadius: currentGlow * 2,
                                    spreadRadius: currentGlow * 0.2,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Material(
                        color: const Color.fromARGB(255, 245, 249, 255),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {},
                          child: CustomPaint(
                            painter: MovingNeonBorderPainter(
                              animationValue: _isPaused ? 0.0 : _rotateController.value,
                              borderRadius: BorderRadius.circular(8),
                              strokeWidth: 2.5,
                            ),
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(0, 14, 65, 141),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 16, color: Colors.cyanAccent),
                                  const SizedBox(width: 4),
                                  ShaderMask(
                                    shaderCallback: (bounds) {
                                      return LinearGradient(
                                        colors: const [
                                          Colors.cyanAccent,
                                          Colors.blueAccent,
                                          Colors.purpleAccent,
                                          Colors.pinkAccent,
                                          Colors.cyanAccent,
                                        ],
                                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                                        transform: GradientRotation(_isPaused ? 0.0 : _rotateController.value * 2 * 3.141592653589793),
                                      ).createShader(bounds);
                                    },
                                    child: Text(
                                      isSmallMobile ? "Today: $formattedTotalWorkingTime" : "Today Working Hours: $formattedTotalWorkingTime",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
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

                Consumer<AuthService>(
                  builder: (context, authService, _) {
                    final user = authService.user;
                    final employeeName = user?['fullName'] ?? 'Employee';
                    final employeeRole = user?['role'] ?? widget.role.title;
                    final initials = user?['initials'] ?? _generateInitials(employeeName);

                    final String? profilePhoto = user?['profile_photo']?.toString() ?? user?['profilePhoto']?.toString();
                    final String avatarColorHex = user?['avatar_color']?.toString() ?? user?['avatarColor']?.toString() ?? '';

                    Color avatarColor = AppColors.primary;
                    if (avatarColorHex.isNotEmpty) {
                      try {
                        final s = avatarColorHex.replaceAll('#', '');
                        avatarColor = Color(int.parse('FF$s', radix: 16));
                      } catch (_) {}
                    }

                    ImageProvider? profileImage;
                    if (profilePhoto != null && profilePhoto.isNotEmpty) {
                      try {
                        profileImage = MemoryImage(base64Decode(profilePhoto.split(',').last));
                      } catch (_) {}
                    }

                    if (!isDesktop) {
                      return PopupMenuButton<int>(
                        offset: const Offset(0, 45),
                        icon: CircleAvatar(
                          radius: 16,
                          backgroundColor: avatarColor,
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))
                              : null,
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
                          backgroundColor: avatarColor,
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                )
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

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

class MovingNeonBorderPainter extends CustomPainter {
  final double animationValue;
  final BorderRadius borderRadius;
  final double strokeWidth;

  MovingNeonBorderPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = borderRadius.toRRect(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * 3.141592653589793,
        colors: const [
          Colors.cyanAccent,
          Colors.blueAccent,
          Colors.purpleAccent,
          Colors.pinkAccent,
          Colors.amberAccent,
          Colors.cyanAccent,
        ],
        transform: GradientRotation(animationValue * 2 * 3.141592653589793),
      ).createShader(rect);

    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant MovingNeonBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}