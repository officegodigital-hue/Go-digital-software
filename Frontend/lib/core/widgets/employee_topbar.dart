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
import 'package:godigital_portal/screens/employee_dashboard/task_actions.dart';

class EmployeeTopbar extends StatefulWidget {
  final EmployeeRole role;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAssignedTasks;
  final VoidCallback? onTapWorkingHours;
  final VoidCallback? onOpenRunningTask;
  /// Tapping the running chip: gets the running item
  /// ({client, due_date, section: 'My Tasks' | 'Content Calendar', task_id, …})
  /// so the dashboard can open that client's workspace on that tab.
  final ValueChanged<Map<String, dynamic>>? onOpenRunningItem;
  final Function(String)? onSearch;

  const EmployeeTopbar({
    super.key,
    required this.role,
    this.onOpenNotifications,
    this.onOpenAssignedTasks,
    this.onTapWorkingHours,
    this.onOpenRunningTask,
    this.onOpenRunningItem,
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

  String formattedTotalWorkingTime = "00h 00m 00s";

  // ── Working hours + running task (server is the source of truth) ──
  int _baseTotalSecs = 0;               // seconds worked today when last fetched
  DateTime _baseAt = DateTime.now();    // local time of that fetch
  Duration _serverOffset = Duration.zero;
  Map<String, dynamic>? _running;       // {trackingItemId, client, task, sessionStartedAt}
  Timer? _tickTimer;

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
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _recomputeWorkingDisplay();
    });
    _connectNotificationSocket();
    _checkActiveBroadcast();
    _checkAssignedClientStatusChanges();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tickTimer?.cancel();
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



// Future<void> _checkActiveBroadcast() async {
//     final authService = Provider.of<AuthService>(context, listen: false);
//     final employeeId = authService.user?['id'];
//     final employeeName =
//         authService.user?['fullName'] ?? authService.user?['name'] ?? '';

//     if (employeeId == null || employeeName.toString().trim().isEmpty) return;

//     try {
//       final response =
//           await http.get(Uri.parse('${ApiConfig.baseUrl}/broadcast/settings'));

//       if (response.statusCode != 200) return;

//       final data = jsonDecode(response.body) as Map<String, dynamic>;

//       final bool isActive = data['isActive'] ?? false;
//       final bool newClientOn = data['newClientEnabled'] ?? true;
//       final bool inactiveClientOn = data['inactiveClientEnabled'] ?? true;
//       final String adminMessage = (data['message'] ?? '').toString().trim();
//       final String severity =
//           (data['severity'] ?? 'Warning').toString().trim();

//       final dynamic targetEmpId = data['targetEmployeeId'];
//       final String dbBroadcastId = (data['id'] ?? 0).toString();

//       if (!isActive) return;

//       if (targetEmpId != null &&
//           targetEmpId.toString() != employeeId.toString()) {
//         return;
//       }

//       final prefs = await SharedPreferences.getInstance();

//       // 1. ADMIN MANUAL MESSAGE
//       if (adminMessage.isNotEmpty && dbBroadcastId != '0') {
//         final manualKey = 'manual_agreed_$employeeId';
//         final savedMsg = prefs.getString(manualKey) ?? '';

//         // Puthu message-ah iruntha mattum thaan open aagum, same message-ku open aagathu
//         if (savedMsg != adminMessage && !_isBroadcastPopupShowing) {
//           _showBlueWhiteAgreePopup(
//             adminMessage,
//             severity,
//             manualKey,
//             adminMessage,
//             employeeId,
//           );
//           return;
//         }
//       }

//       // 2. AUTOMATED CLIENT / TASK POPUPS
//       final summaryRes = await http.get(
//         Uri.parse(
//           '${ApiConfig.baseUrl}/dashboard/summary/${Uri.encodeComponent(employeeName.toString())}',
//         ),
//       );

//       if (summaryRes.statusCode != 200) return;

//       final summaryData =
//           (jsonDecode(summaryRes.body)['data'] ?? {}) as Map<String, dynamic>;

//       // 2A. New client task assigned
//       final newClientsList =
//           List<dynamic>.from(summaryData['newClientsList'] ?? []);

//       if (newClientOn && newClientsList.isNotEmpty) {
//         final clientNames = newClientsList
//             .map((c) => (c['clientName'] ?? 'Client').toString().trim())
//             .where((name) => name.isNotEmpty)
//             .toSet()
//             .toList()
//           ..sort();

//         if (clientNames.isNotEmpty) {
//           final namesStr = clientNames.join(', ');
//           final triggerMsg =
//               'New client task assigned for: $namesStr. '
//               'Please check your task panel.';

//           final newClientKey = 'new_client_agreed_$employeeId';
//           final savedNewClient = prefs.getString(newClientKey) ?? '';

//           if (savedNewClient != namesStr && !_isBroadcastPopupShowing) {
//             _showBlueWhiteAgreePopup(
//               triggerMsg,
//               'Information',
//               newClientKey,
//               namesStr,
//               employeeId,
//             );
//             return;
//           }
//         }
//       }

//       // 2B. Inactive client
//       final inactiveList =
//           List<dynamic>.from(summaryData['inactiveTodayList'] ?? []);

//       if (inactiveClientOn && inactiveList.isNotEmpty) {
//         final clientNames = inactiveList
//             .map((c) => (c['clientName'] ?? 'Client').toString().trim())
//             .where((name) => name.isNotEmpty)
//             .toSet()
//             .toList()
//           ..sort();

//         if (clientNames.isNotEmpty) {
//           final namesStr = clientNames.join(', ');
//           final triggerMsg =
//               'Assigned client(s) marked inactive: $namesStr.';

//           final inactiveKey = 'inactive_client_agreed_$employeeId';
//           final savedInactive = prefs.getString(inactiveKey) ?? '';

//           if (savedInactive != namesStr && !_isBroadcastPopupShowing) {
//             _showBlueWhiteAgreePopup(
//               triggerMsg,
//               'Information',
//               inactiveKey,
//               namesStr,
//               employeeId,
//             );
//             return;
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint("Broadcast check error: $e");
//     }
//   }

//   void _showBlueWhiteAgreePopup(String message, String severity, String storageKey, String contentValue, dynamic employeeId) {
//     if (!mounted) return;
//     setState(() {
//       _isBroadcastPopupShowing = true;
//     });

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return PopScope(
//           canPop: false,
//           child: AlertDialog(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             contentPadding: EdgeInsets.zero,
//             content: Container(
//               width: 420,
//               padding: const EdgeInsets.all(24),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(20),
//                 gradient: const LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [Color(0xFFF0F5FF), Colors.white],
//                 ),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF0757D5).withValues(alpha: 0.1),
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(
//                       severity == 'Emergency' 
//                           ? Icons.error_outline 
//                           : severity == 'Warning' 
//                               ? Icons.warning_amber_rounded 
//                               : Icons.info_outline_rounded,
//                       color: const Color(0xFF0757D5),
//                       size: 32,
//                     ),
//                   ),
//                   const SizedBox(height: 14),
//                   Text(
//                     '$severity Alert',
//                     style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF04296B)),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     message,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
//                   ),
//                   const SizedBox(height: 24),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF0757D5),
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                         elevation: 0,
//                       ),
//                       onPressed: () async {
//                         final prefs = await SharedPreferences.getInstance();
//                         // Indha specific message / client string-ah save seithu viduvathal, adutha murai same message-ku popup varaathu
//                         await prefs.setString(storageKey, contentValue);

//                         if (dialogContext.mounted) {
//                           Navigator.of(dialogContext).pop();
//                         }
//                         setState(() {
//                           _isBroadcastPopupShowing = false;
//                         });
//                       },
//                       child: const Text(
//                         'Agree',
//                         style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

  // Independent client-status broadcast checker.
  // Uses the existing blue-and-white Agree popup.
  bool _clientStatusCheckRunning = false;

  Future<void> _checkAssignedClientStatusChanges() async {
    if (!mounted || _clientStatusCheckRunning) return;
    _clientStatusCheckRunning = true;

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final employeeId = (auth.user?['id'] ?? '').toString();
      final employeeName =
          (auth.user?['fullName'] ?? auth.user?['name'] ?? '')
              .toString().trim();

      if (employeeId.isEmpty || employeeName.isEmpty) return;

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/dashboard/summary/'
          '${Uri.encodeComponent(employeeName)}',
        ),
      );

      if (!mounted || response.statusCode != 200) return;

      final payload = jsonDecode(response.body);
      if (payload is! Map) return;

      final data = payload['data'];
      if (data is! Map) return;

      final rows = data['assignedClientStatuses'];
      if (rows is! List || rows.isEmpty) return;

      final current = <String, bool>{};
      final names = <String, String>{};

      for (final row in rows) {
        if (row is! Map) continue;

        final id = (row['clientId'] ?? '').toString();
        if (id.isEmpty) continue;

        final raw = row['isActive'];
        current[id] = raw == 1 || raw == true || raw.toString() == '1';
        names[id] = (row['clientName'] ?? 'Client').toString();
      }

      if (current.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final snapshotKey = 'client_status_snapshot_v3_$employeeId';
      final pendingKey = 'client_status_pending_v3_$employeeId';

      final oldText = prefs.getString(snapshotKey);

      // Initial load: record current statuses, do not announce old changes.
      if (oldText == null) {
        await prefs.setString(snapshotKey, jsonEncode(current));
        return;
      }

      final oldStatuses =
          Map<String, dynamic>.from(jsonDecode(oldText) as Map);

      final pendingText = prefs.getString(pendingKey);
      final pending = pendingText == null
          ? <dynamic>[]
          : List<dynamic>.from(jsonDecode(pendingText) as List);

      // Detect actual observed status transitions.
      for (final entry in current.entries) {
        // Notify when a client first appears in this employee's
        // assignment list, or when its Active/Inactive status changes.
        if (oldStatuses.containsKey(entry.key) &&
            oldStatuses[entry.key] == entry.value) {
          continue;
        }

        final clientName = names[entry.key] ?? 'Client';
        final status = entry.value ? 'Active' : 'Inactive';

        final eventId =
            '${entry.key}_${status}_${DateTime.now().microsecondsSinceEpoch}';

        pending.add({
          'key': 'client_status_agreed_${employeeId}_${entry.key}',
          'eventId': eventId,
          'message': entry.value
              ? 'Your assigned client $clientName has been marked Active. '
                'Please review your assigned tasks.'
              : 'Your assigned client $clientName has been marked Inactive. '
                'Please review your assigned tasks.',
        });
      }

      // Persist pending alerts before updating the last-known status.
      await prefs.setString(pendingKey, jsonEncode(pending));
      await prefs.setString(snapshotKey, jsonEncode(current));

      // Do not overlap manual broadcasts or other existing popup dialogs.
      if (!mounted || _isBroadcastPopupShowing) return;

      // Existing Agree button writes the acknowledged event ID.
      while (pending.isNotEmpty) {
        final event = Map<String, dynamic>.from(pending.first as Map);
        final key = event['key'].toString();
        final eventId = event['eventId'].toString();

        if (prefs.getString(key) == eventId) {
          pending.removeAt(0);
          continue;
        }

        await prefs.setString(pendingKey, jsonEncode(pending));

        if (!mounted || _isBroadcastPopupShowing) return;

        _showBlueWhiteAgreePopup(
          event['message'].toString(),
          'Information',
          key,
          eventId,
          employeeId,
        );
        return;
      }

      await prefs.setString(pendingKey, jsonEncode(pending));
    } catch (e) {
      debugPrint('Assigned client status popup error: $e');
    } finally {
      _clientStatusCheckRunning = false;
    }
  }
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

      // Puthu message-ah iruntha mattum popup open aagum
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


// ============================================================
// BLUE + WHITE BROADCAST POPUP
// ============================================================

void _showBlueWhiteAgreePopup(
  String message,
  String severity,
  String storageKey,
  String contentValue,
  dynamic employeeId,
) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF0F5FF),
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ------------------------------------------------
                // ICON
                // ------------------------------------------------
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

                // ------------------------------------------------
                // TITLE
                // ------------------------------------------------
                Text(
                  '$severity Alert',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF04296B),
                  ),
                ),

                const SizedBox(height: 10),

                // ------------------------------------------------
                // MESSAGE WITH HIGHLIGHT
                // ------------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: SelectableText.rich(
                    TextSpan(
                      children: _buildHighlightedMessage(message),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ------------------------------------------------
                // AGREE BUTTON
                // ------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0757D5),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final prefs =
                          await SharedPreferences.getInstance();

                      // Same message / same client list-ku
                      // next time popup varaama irukka save pannum.
                      await prefs.setString(
                        storageKey,
                        contentValue,
                      );

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }

                      if (mounted) {
                        setState(() {
                          _isBroadcastPopupShowing = false;
                        });
                      }
                    },
                    child: const Text(
                      'Agree',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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


// ============================================================
// MESSAGE HIGHLIGHTER
// ============================================================

List<TextSpan> _buildHighlightedMessage(String message) {
  final List<TextSpan> spans = [];

  final RegExp regex = RegExp(
    r'https?:\/\/[^\s]+|'
    r'@[A-Za-z0-9_.]+|'
    r'\b(?:click here|click|here|important|urgent|'
    r'action required|please note|warning|emergency|'
    r'new client|task assigned|inactive)\b',
    caseSensitive: false,
  );

  final List<_HighlightPart> highlights = [];

  // ---------------------------------------------
  // Keyword / URL / @employee highlight
  // ---------------------------------------------
  for (final match in regex.allMatches(message)) {
    highlights.add(
      _HighlightPart(
        start: match.start,
        end: match.end,
      ),
    );
  }

  // ---------------------------------------------
  // Highlight value after ":"
  //
  // Example:
  // Assigned client(s) marked inactive: JEYASRI HOSTAL.
  //
  // "JEYASRI HOSTAL" will also be highlighted.
  // ---------------------------------------------
  final colonIndex = message.indexOf(':');

  if (colonIndex != -1) {
    final valueStart = colonIndex + 1;

    final value = message
        .substring(valueStart)
        .trim();

    if (value.isNotEmpty) {
      final actualStart =
          message.indexOf(value, valueStart);

      if (actualStart >= 0) {
        highlights.add(
          _HighlightPart(
            start: actualStart,
            end: actualStart + value.length,
          ),
        );
      }
    }
  }

  // Sort
  highlights.sort(
    (a, b) => a.start.compareTo(b.start),
  );

  // Remove overlapping ranges
  final List<_HighlightPart> cleanHighlights = [];

  int lastEnd = -1;

  for (final item in highlights) {
    if (item.start >= lastEnd) {
      cleanHighlights.add(item);
      lastEnd = item.end;
    }
  }

  // ---------------------------------------------
  // Create TextSpans
  // ---------------------------------------------
  int lastIndex = 0;

  for (final item in cleanHighlights) {
    // Normal text
    if (item.start > lastIndex) {
      spans.add(
        TextSpan(
          text: message.substring(
            lastIndex,
            item.start,
          ),
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Highlight
    spans.add(
      TextSpan(
        text: message.substring(
          item.start,
          item.end,
        ),
        style: const TextStyle(
          color: Color(0xFF0757D5),
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF0757D5),
          decorationThickness: 1.5,
        ),
      ),
    );

    lastIndex = item.end;
  }

  // Remaining text
  if (lastIndex < message.length) {
    spans.add(
      TextSpan(
        text: message.substring(lastIndex),
        style: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  return spans;
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
      _socket!.on('task_updated', (_) {
        if (mounted) _fetchTodayWorkingHours();
      });
    } catch (e) {
      debugPrint('Topbar socket init error: $e');
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkNewNotifications();
      await _fetchTodayWorkingHours();
      await _checkActiveBroadcast();
      await _checkAssignedClientStatusChanges();
    });
  }

  Future<void> _fetchTodayWorkingHours() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final employeeName = authService.user?['fullName'] ?? authService.user?['name'] ?? authService.user?['username'];
    if (employeeName == null || employeeName.toString().isEmpty) return;
    try {
      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      // Running item (task or Content Calendar category) + today's total —
      // the same numbers My Tasks, Live Tracking and the Day Planner use.
      final url = Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/running').replace(
        queryParameters: {'employee': employeeName.toString(), 'date': formattedDate},
      );
      final r = await http.get(url);
      if (r.statusCode == 200 && mounted) {
        final body = jsonDecode(r.body);
        final serverNow = DateTime.tryParse((body['serverNow'] ?? '').toString());
        setState(() {
          _baseTotalSecs = (body['totalSecs'] as num?)?.toInt() ?? 0;
          _baseAt = DateTime.now();
          _serverOffset = serverNow != null ? serverNow.difference(DateTime.now()) : Duration.zero;
          _running = body['running'] is Map ? Map<String, dynamic>.from(body['running'] as Map) : null;
        });
        _recomputeWorkingDisplay();
      }
    } catch (e) {
      debugPrint("Working hours fetch error: $e");
    }
  }

  // Ticks every second: today's total grows only while a task is running.
  void _recomputeWorkingDisplay() {
    int total = _baseTotalSecs;
    if (_running != null) total += DateTime.now().difference(_baseAt).inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final sec = total % 60;
    // Runs live with seconds while something is in progress.
    final text = '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m '
        '${sec.toString().padLeft(2, '0')}s';
    if (_running != null || text != formattedTotalWorkingTime) {
      setState(() => formattedTotalWorkingTime = text);
    }
  }

  String _runningTimerText() {
    // Total time on the running item (all sessions), ticking live.
    final base = int.tryParse('${_running?['elapsedSecs'] ?? ''}');
    int secs;
    if (base != null) {
      secs = base + DateTime.now().difference(_baseAt).inSeconds;
    } else {
      final started = DateTime.tryParse((_running?['sessionStartedAt'] ?? '').toString());
      if (started == null) return '00:00:00';
      secs = DateTime.now().add(_serverOffset).difference(started).inSeconds;
    }
    if (secs < 0) secs = 0;
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  Future<void> _holdRunningTask() async {
    final running = _running;
    if (running == null) return;
    final token = Provider.of<AuthService>(context, listen: false).token ?? '';
    await TaskActions.run(context, Map<String, dynamic>.from(running), 'hold', token: token);
    await _fetchTodayWorkingHours();
  }

  // Compact "running task" chip shown next to Today Working Hours.
  Widget _buildRunningChip() {
    final running = _running;
    if (running == null) return const SizedBox.shrink();
    final client = (running['client'] ?? '').toString();
    var title = '${client.isEmpty ? '' : '$client · '}${running['task'] ?? ''}';
    if (title.length > 32) title = '${title.substring(0, 32)}…';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            final item = _running;
            if (item != null && widget.onOpenRunningItem != null) {
              widget.onOpenRunningItem!(Map<String, dynamic>.from(item));
            } else {
              widget.onOpenRunningTask?.call();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 9, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF14532D))),
                    Text(_runningTimerText(),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF166534))),
                  ],
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _holdRunningTask,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Hold',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                                hintText: 'Search client name…',
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
                                  // Soft, readable glow (deep blue / violet).
                                  BoxShadow(
                                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
                                    blurRadius: currentGlow * 1.2,
                                    spreadRadius: currentGlow * 0.15,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                                    blurRadius: currentGlow * 1.6,
                                    spreadRadius: currentGlow * 0.1,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Material(
                        color: const Color(0xFFF1F6FF),
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
                                  const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 4),
                                  ShaderMask(
                                    shaderCallback: (bounds) {
                                      return LinearGradient(
                                        // Dark, high-contrast colours on the light
                                        // pill (navy → royal blue → violet → teal).
                                        colors: const [
                                          Color(0xFF0A3D91),
                                          Color(0xFF1D4ED8),
                                          Color(0xFF6D28D9),
                                          Color(0xFF0F766E),
                                          Color(0xFF0A3D91),
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
                if (!isSmallMobile) _buildRunningChip(),
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
          Color(0xFF1D4ED8),
          Color(0xFF7C3AED),
          Color(0xFFDB2777),
          Color(0xFFD97706),
          Color(0xFF0891B2),
          Color(0xFF1D4ED8),
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

class _HighlightPart {
  final int start;
  final int end;

  _HighlightPart({
    required this.start,
    required this.end,
  });
}