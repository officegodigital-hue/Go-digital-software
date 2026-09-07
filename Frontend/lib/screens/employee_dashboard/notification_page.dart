// notification_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:audioplayers/audioplayers.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class DayPlanTableViewer extends StatefulWidget {
  final String employeeName;
  final String date;
  const DayPlanTableViewer({super.key, required this.employeeName, required this.date});
  @override
  State<DayPlanTableViewer> createState() => _DayPlanTableViewerState();
}

class _DayPlanTableViewerState extends State<DayPlanTableViewer> {
  List<Map<String, dynamic>> rows = [];
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDayPlan();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _fetchDayPlan() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/day-planner/today/${Uri.encodeComponent(widget.employeeName)}?date=${widget.date}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        debugPrint("DAY PLAN RESPONSE = ${res.body}");
        setState(() {
          rows = List<Map<String, dynamic>>.from(decoded is List ? decoded : (decoded['data'] ?? []));
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor = const Color(0xFFF1F5F9);
    Color textColor = const Color(0xFF64748B);
    switch (status.toUpperCase()) {
      case 'COMPLETE':
        bgColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        break;
      case 'PENDING':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        break;
      case 'PROCESSING':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF0369A1);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)));
    }

    if (rows.isEmpty) {
      return const Center(child: Text("No Day Plan Data Found", style: TextStyle(fontSize: 14, color: Color(0xFF64748B))));
    }

    return SizedBox(
      width: 1200,
      height: 500,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalController,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              notificationPredicate: (notification) => notification.depth == 1,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 55,
                  dataRowMinHeight: 85,
                  dataRowMaxHeight: 85,
                  columnSpacing: 25,
                  dividerThickness: 1,
                  border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF0052CC)),
                  columns: const [
                    DataColumn(label: Text("CLIENT NAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("ADS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("LEADS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("DELIVERABLE 1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("COMPLETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("BALANCE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("TODAY PLAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("STATUS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text("REMARKS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ],
                  rows: List.generate(rows.length, (index) {
                    final r = rows[index];
                    return DataRow(
                      color: WidgetStateProperty.all(index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                      cells: [
                        DataCell(
                          Container(
                            width: 160,
                            height: double.infinity,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            color: const Color(0xFF0052CC),
                            child: Text(r["client"] ?? "-", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        DataCell(SizedBox(width: 220, child: Text(r["ads"] ?? "-", softWrap: true))),
                        DataCell(Text(r["today_leads"] ?? "-")),
                        DataCell(Text(r["today_report"] ?? "-")),
                        DataCell(SizedBox(width: 250, child: Text(r["deliverables_1"] ?? "-", softWrap: true))),
                        DataCell(Text(r["complete_deliverables_1"] ?? "-")),
                        DataCell(Text(r["balanced_deliverables_1"] ?? "-")),
                        DataCell(SizedBox(width: 180, child: Text(r["today_plan"] ?? "-", softWrap: true))),
                        DataCell(_buildStatusBadge((r["status"] ?? "-").toString())),
                        DataCell(SizedBox(width: 200, child: Text(r["remarks"] ?? "-", softWrap: true))),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;
  String? _loggedInEmployee;
  String _selectedChatTarget = '';
  bool _isGroupChat = false;
  
  List<Map<String, dynamic>> notificationLogs = [];
  List<Map<String, dynamic>> activeEmployees = [];
  List<dynamic> chatGroups = [];
  List<dynamic> scheduledMeetings = [];
  
  bool _loading = true;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  int _whatsappNavIndex = 0; 
  String _meetingFilter = 'All'; 
  bool _showEmojiPicker = false;
  Map<String, dynamic>? _replyingToMessage;

  bool _showMentionOverlay = false;
  List<Map<String, dynamic>> _filteredMentionEmployees = [];
  List<String> pinnedChats = [];
  IO.Socket? _socket;
  final AudioPlayer _chatAudioPlayer = AudioPlayer();
  bool _showMobileChatList = true;
  String? _selectedFileName;
  int _unreadTotal = 0; 

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      //final authService = context.read<AuthService>();
      //final loggedInName = authService.user?['fullName'] as String? ?? 'Admin';

      final authService = context.read<AuthService>();
      final loggedInName = authService.user?['fullName'] as String? ?? 'Admin';

      if (!mounted) return;

      setState(() {
        _loggedInEmployee = loggedInName;
      });

      await _fetchHubData();
      _connectSocket();
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _searchController.dispose();
    _socket?.dispose();
    _chatAudioPlayer.dispose();
    super.dispose();
  }

  String get _socketUrl {
    final raw = _baseUrl.trim();
    return raw.replaceFirst(RegExp(r'/api/?$'), '');
  }

  void _connectSocket() {
    if (_loggedInEmployee == null) return;

    try {
      _socket = IO.io(_socketUrl, {
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
      });

      _socket!.connect();

      _socket!.onConnect((_) {
        debugPrint('✅ Chat socket connected');
      });

      _socket!.on('receive_message', (payload) {
        _handleSocketMessage(payload);
      });

      _socket!.on('receive_group_message', (payload) {
        _handleSocketMessage(payload);
      });

      _socket!.on('messages_seen', (payload) {
        if (!mounted || payload is! Map) return;
        final recipient = payload['recipientName']?.toString();
        final sender = payload['senderName']?.toString();

        if (recipient != _loggedInEmployee) return;
        setState(() {
          for (final log in notificationLogs) {
            if (sender != null &&
                log['senderName'] == sender &&
                log['recipientName'] == recipient) {
              log['isSeen'] = true;
            }
          }
          _unreadTotal = _calculateUnreadTotal();
        });
      });

      _socket!.on('chat_pin_updated', (payload) {
        if (!mounted || payload is! Map) return;
        final owner = payload['ownerName']?.toString();
        final target = payload['targetName']?.toString();
        final pinned = payload['pinned'] == true;
        if (owner != _loggedInEmployee || target == null) return;

        setState(() {
          if (pinned && !pinnedChats.contains(target)) {
            pinnedChats.add(target);
          } else if (!pinned) {
            pinnedChats.remove(target);
          }
        });
      });

      _socket!.onDisconnect((_) => debugPrint('🔌 Chat socket disconnected'));
      _socket!.onError((e) => debugPrint('Socket error: $e'));
    } catch (e) {
      debugPrint('Socket init error: $e');
    }
  }

  void _handleSocketMessage(dynamic payload) {
    if (!mounted || payload is! Map) return;

    final incoming = Map<String, dynamic>.from(payload);
    final sender = incoming['senderName']?.toString() ?? '';
    final recipient = incoming['recipientName']?.toString() ?? '';
    final isGroup = incoming['isGroup'] == true ||
        incoming['isGroup'] == 1 ||
        incoming['isGroup']?.toString() == '1';

    final isForMe = isGroup
        ? _isGroupChat && recipient == _selectedChatTarget
        : (recipient == _loggedInEmployee || sender == _loggedInEmployee);

    if (!isForMe) return;

    final id = int.tryParse(incoming['id']?.toString() ?? '') ?? 0;
    if (id != 0 && notificationLogs.any((m) => int.tryParse(m['id']?.toString() ?? '') == id)) {
      return;
    }

    final message = incoming['message'];
    final row = <String, dynamic>{
      'id': id,
      'senderName': sender,
      'recipientName': recipient,
      'message': message ?? '',
      'time': incoming['time'] ?? 'Just Now',
      'isGroup': isGroup,
      'isSeen': sender == _loggedInEmployee,
      'isFavorite': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      notificationLogs.insert(0, row);
      if (sender != _loggedInEmployee && !_isCurrentConversation(row)) {
        _unreadTotal++;
      }
    });

    if (sender != _loggedInEmployee) {
      _playChatSound();
      _showInPageNotification(sender, _plainMessage(row['message']));
    }
  }

  bool _isCurrentConversation(Map<String, dynamic> log) {
    if (_selectedChatTarget.isEmpty) return false;
    if (_isGroupChat) {
      return log['isGroup'] == true && log['recipientName'] == _selectedChatTarget;
    }
    return (log['senderName'] == _loggedInEmployee &&
            log['recipientName'] == _selectedChatTarget) ||
        (log['senderName'] == _selectedChatTarget &&
            log['recipientName'] == _loggedInEmployee);
  }

  Future<void> _playChatSound() async {
    try {
      await _chatAudioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Chat sound error: $e');
    }
  }

  void _showInPageNotification(String sender, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        backgroundColor: const Color(0xFF0052CC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$sender\n$message',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMessageChanged() {
    final text = _messageController.text;
    final selection = _messageController.selection;
    
    if (_isGroupChat && selection.baseOffset > 0) {
      final currentSubstring = text.substring(0, selection.baseOffset);
      final lastAtIndex = currentSubstring.lastIndexOf('@');
      
      if (lastAtIndex != -1) {
        final query = currentSubstring.substring(lastAtIndex + 1);
        if (!query.contains(' ')) {
          setState(() {
            _showMentionOverlay = true;
            _filteredMentionEmployees = activeEmployees.where((e) => 
              (e["full_name"] ?? "").toLowerCase().contains(query.toLowerCase())
            ).toList();
          });
          return;
        }
      }
    }
    if (_showMentionOverlay) {
      setState(() {
        _showMentionOverlay = false;
      });
    }
  }

  bool _isSeenValue(dynamic value) {
    return value == true || value == 1 || value?.toString().toLowerCase() == 'true' || value?.toString() == '1';
  }

  int _calculateUnreadTotal() {
    if (_loggedInEmployee == null) return 0;

    return notificationLogs.where((log) {
      final sender = log["senderName"]?.toString() ?? '';
      final recipient = log["recipientName"]?.toString() ?? '';
      final isGroup = _isSeenValue(log["isGroup"]);
      final seen = _isSeenValue(log["isSeen"]);

      if (seen || sender == _loggedInEmployee) return false;

      if (isGroup) {
        return chatGroups.any((g) {
          final groupName = g["group_name"]?.toString() ?? '';
          if (groupName != recipient) return false;
          try {
            final members = List<String>.from(jsonDecode(g["members"] ?? '[]'));
            return members.contains(_loggedInEmployee) || g["created_by"]?.toString() == _loggedInEmployee;
          } catch (_) {
            return g["created_by"]?.toString() == _loggedInEmployee;
          }
        });
      }

      return recipient == _loggedInEmployee;
    }).length;
  }

  Future<void> _fetchHubData() async {
    if (_loggedInEmployee == null) return;
    if (mounted) setState(() => _loading = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/chat/${Uri.encodeComponent(_loggedInEmployee!)}'),
      );

      if (response.statusCode != 200) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final body = jsonDecode(response.body);
      final rawEmployees = body["employees"] ?? [];
      final parsedEmployees = <Map<String, dynamic>>[];
      for (final e in rawEmployees) {
        if (e is Map) parsedEmployees.add(Map<String, dynamic>.from(e));
      }

      final loadedLogs = <Map<String, dynamic>>[];
      for (final item in (body["data"] ?? [])) {
        if (item is Map) loadedLogs.add(Map<String, dynamic>.from(item));
      }

      final loadedGroups = List<dynamic>.from(body["groups"] ?? []);
      final serverPins = <String>{};
      final rawPinnedChats = body["pinnedChats"];

      if (rawPinnedChats is List) {
        for (final item in rawPinnedChats) {
          if (item is Map) {
            final targetName = item["targetName"]?.toString().trim();
            if (targetName != null && targetName.isNotEmpty) {
              serverPins.add(targetName);
            }
          } else if (item != null) {
            final value = item.toString().trim();
            if (value.isNotEmpty) {
              serverPins.add(value);
            }
          }
        }
      }

      if (serverPins.isEmpty) {
        for (final log in loadedLogs) {
          if (!_isSeenValue(log["isFavorite"])) continue;
          final isGroup = _isSeenValue(log["isGroup"]);
          if (isGroup) {
            final target = log["recipientName"]?.toString();
            if (target != null && target.isNotEmpty) serverPins.add(target);
          } else {
            final sender = log["senderName"]?.toString();
            final recipient = log["recipientName"]?.toString();
            if (sender == _loggedInEmployee && recipient != null) serverPins.add(recipient);
            if (recipient == _loggedInEmployee && sender != null) serverPins.add(sender);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        notificationLogs = loadedLogs;
        activeEmployees = parsedEmployees;
        chatGroups = loadedGroups;
        scheduledMeetings = List<dynamic>.from(body["meetings"] ?? []);
        pinnedChats = serverPins.toList();
        _unreadTotal = _calculateUnreadTotal();

        if (_selectedChatTarget.isEmpty && activeEmployees.isNotEmpty) {
          _selectedChatTarget = activeEmployees.first["full_name"]?.toString() ?? '';
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint("Fetch Hub Data Error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markMessagesSeen(String targetName, bool isGroup) async {
    if (_loggedInEmployee == null || targetName.isEmpty) return;

    setState(() {
      for (final log in notificationLogs) {
        final sender = log["senderName"]?.toString();
        final recipient = log["recipientName"]?.toString();
        final group = _isSeenValue(log["isGroup"]);

        if (!isGroup) {
          if (!group && sender == targetName && recipient == _loggedInEmployee) {
            log["isSeen"] = true;
          }
        } else if (group && recipient == targetName && sender != _loggedInEmployee) {
          log["isSeen"] = true;
        }
      }
      _unreadTotal = _calculateUnreadTotal();
    });

    try {
      final response = await http.patch(
        Uri.parse(isGroup ? '$_baseUrl/chat/mark-seen-group' : '$_baseUrl/chat/mark-seen'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(isGroup
            ? {
                'groupName': targetName,
                'employeeName': _loggedInEmployee,
              }
            : {
                'recipientName': _loggedInEmployee,
                'senderName': targetName,
              }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Mark seen failed: ${response.statusCode} ${response.body}');
      }

      final body = jsonDecode(response.body);
      if (body is Map && body['success'] == false) {
        throw Exception(body['message'] ?? 'Mark seen failed');
      }

      if (mounted) {
        setState(() => _unreadTotal = _calculateUnreadTotal());
      }
    } catch (e) {
      debugPrint("Mark seen error: $e");
      await _fetchHubData();
    }
  }

  Future<void> _toggleChatPin(
    String targetName,
    bool isGroup,
    bool currentlyPinned,
  ) async {
    if (_loggedInEmployee == null || targetName.trim().isEmpty) {
      return;
    }

    final next = !currentlyPinned;
    final oldPins = List<String>.from(pinnedChats);

    setState(() {
      if (next) {
        if (!pinnedChats.contains(targetName)) {
          pinnedChats.add(targetName);
        }
      } else {
        pinnedChats.remove(targetName);
      }
    });

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/chat/pin-chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ownerName': _loggedInEmployee,
          'targetName': targetName,
          'isGroup': isGroup,
          'pinned': next,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Pin request failed: ${response.statusCode} ${response.body}');
      }

      final body = jsonDecode(response.body);
      if (body is! Map || body['success'] != true) {
        throw Exception(body['message']?.toString() ?? 'Pin request failed');
      }

      final serverData = body['data'];
      bool serverPinned = next;

      if (serverData is Map) {
        serverPinned =
            serverData['pinned'] == true ||
            serverData['pinned'] == 1 ||
            serverData['pinned']?.toString() == 'true' ||
            serverData['pinned']?.toString() == '1';
      }

      if (!mounted) return;

      setState(() {
        if (serverPinned) {
          if (!pinnedChats.contains(targetName)) {
            pinnedChats.add(targetName);
          }
        } else {
          pinnedChats.remove(targetName);
        }
      });
    } catch (e) {
      debugPrint('❌ Pin error: $e');
      if (!mounted) return;
      setState(() {
        pinnedChats = oldPins;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(next ? 'Could not pin chat.' : 'Could not unpin chat.'),
        ),
      );
    }
  }

  void _exportChatTranscript() {
    final messages = _currentStreamMessages;
    final buffer = StringBuffer();
    buffer.writeln("--- CHAT TRANSCRIPT: $_selectedChatTarget ---");
    buffer.writeln("Exported by: $_loggedInEmployee on ${DateTime.now()}\n");
    for (var m in messages.reversed) {
      buffer.writeln("[${m["time"]}] ${m["senderName"]}: ${m["message"]}");
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Chat transcript copied to clipboard!")),
    );
  }

  void _openMeetingSchedulerDialog() {
    final TextEditingController topicController = TextEditingController();
    final TextEditingController linkController = TextEditingController();
    
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    Map<String, bool> selectedAttendees = {
      for (var e in activeEmployees)
        e["full_name"].toString(): false,
    };
    Map<String, bool> selectedGroupsForMeeting = {
      for (var g in chatGroups)
        g["group_name"].toString(): false,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Schedule Meeting", style: TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 500,
            height: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: topicController, decoration: const InputDecoration(labelText: 'Meeting Topic / Agenda')),
                  const SizedBox(height: 12),
                  TextField(controller: linkController, decoration: const InputDecoration(labelText: 'Meeting Link (Zoom / Meet URL)')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(selectedTime.format(context)),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setDialogState(() => selectedTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Select Employees & Groups to Share Meeting:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 8),
                  
                  if (chatGroups.isNotEmpty) ...[
                    const Text("Chat Groups:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
                    ...chatGroups.map((g) {
                      final gName = g["group_name"] ?? "";
                      return CheckboxListTile(
                        dense: true,
                        title: Text(gName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: selectedGroupsForMeeting[gName] ?? false,
                        activeColor: const Color(0xFF0052CC),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedGroupsForMeeting[gName] = val ?? false;
                          });
                        },
                      );
                    }),
                    const Divider(),
                  ],

                  const Text("Employees:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
                  ...activeEmployees.map((emp) {
                    final name = emp["full_name"]?.toString() ?? "";
                    final role = emp["role"]?.toString() ?? "Employee";
                    final initials = emp["initials"]?.toString() ?? "?";

                    return CheckboxListTile(
                      dense: true,
                      secondary: CircleAvatar(
                        backgroundColor: const Color(0xFF0052CC),
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(role, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      value: selectedAttendees[name] ?? false,
                      activeColor: const Color(0xFF0052CC),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedAttendees[name] = val ?? false;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), foregroundColor: Colors.white),
              onPressed: () async {
                final chosenPersons = selectedAttendees.entries.where((e) => e.value).map((e) => e.key).toList();
                final chosenGroups = selectedGroupsForMeeting.entries.where((e) => e.value).map((e) => e.key).toList();

                if (topicController.text.isEmpty || linkController.text.isEmpty || (chosenPersons.isEmpty && chosenGroups.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields and select at least one employee or group.")));
                  return;
                }

                final formattedDateTime = "${DateFormat('yyyy-MM-dd').format(selectedDate)} ${selectedTime.format(context)}";

                await http.post(
                  Uri.parse('$_baseUrl/chat/meetings'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'title': topicController.text,
                    'meetingTime': formattedDateTime,
                    'meetingLink': linkController.text,
                    'hostName': _loggedInEmployee,
                    'selectedPersons': chosenPersons,
                    'selectedGroups': chosenGroups,
                  }),
                );

                Navigator.pop(ctx);
                _fetchHubData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Meeting scheduled & broadcasted!")));
              },
              child: const Text("Schedule & Share"),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditMeetingDialog(Map<String, dynamic> meeting) {
    final TextEditingController topicController = TextEditingController(text: meeting["title"]);
    final TextEditingController linkController = TextEditingController(text: meeting["meeting_link"]);
    
    List<dynamic> currentAttendees = [];
    try { currentAttendees = jsonDecode(meeting["attendees"] ?? '[]'); } catch (_) {}

    Map<String, bool> selectedAttendees = {
      for (var e in activeEmployees)
        e["full_name"].toString(): currentAttendees.contains(e["full_name"].toString())
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit Meeting & Attendees", style: TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 500,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: topicController, decoration: const InputDecoration(labelText: 'Meeting Topic')),
                  const SizedBox(height: 12),
                  TextField(controller: linkController, decoration: const InputDecoration(labelText: 'Meeting Link')),
                  const SizedBox(height: 16),
                  const Text("Modify Meeting Attendees:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...activeEmployees.map((emp) {
                    final name = emp["full_name"]?.toString() ?? "";
                    return CheckboxListTile(
                      dense: true,
                      title: Text(name),
                      value: selectedAttendees[name] ?? false,
                      onChanged: (val) {
                        setDialogState(() {
                          selectedAttendees[name] = val ?? false;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), foregroundColor: Colors.white),
              onPressed: () async {
                final chosenPersons = selectedAttendees.entries.where((e) => e.value).map((e) => e.key).toList();
                await http.patch(
                  Uri.parse('$_baseUrl/chat/meetings/${meeting["id"]}'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'title': topicController.text,
                    'meetingLink': linkController.text,
                    'attendees': chosenPersons,
                  }),
                );
                Navigator.pop(ctx);
                _fetchHubData();
              },
              child: const Text("Update Meeting"),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateGroupDialog() {
    final TextEditingController groupNameController = TextEditingController();
    Map<String, bool> selectedMembers = {
      for (var e in activeEmployees)
        e["full_name"].toString(): false,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Create WhatsApp Group", style: TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 450,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: groupNameController, decoration: const InputDecoration(labelText: 'Group Name')),
                  const SizedBox(height: 16),
                  const Text("Select Group Members:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  activeEmployees.isEmpty
                      ? const Text("No employees found.", style: TextStyle(color: Colors.grey))
                      : Column(
                          children: activeEmployees.map((emp) {
                            final name = emp["full_name"]?.toString() ?? "";
                            final role = emp["role"]?.toString() ?? "Employee";
                            final initials = emp["initials"]?.toString() ?? "?";

                            return CheckboxListTile(
                              secondary: CircleAvatar(
                                backgroundColor: const Color(0xFF0EA5E9),
                                child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text(role, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              value: selectedMembers[name] ?? false,
                              activeColor: const Color(0xFF0052CC),
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedMembers[name] = val ?? false;
                                });
                              },
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), foregroundColor: Colors.white),
              onPressed: () async {
                final members = selectedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
                if (groupNameController.text.isEmpty || members.isEmpty) return;

                await http.post(
                  Uri.parse('$_baseUrl/chat/groups'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'groupName': groupNameController.text, 'createdBy': _loggedInEmployee, 'members': members}),
                );

                Navigator.pop(ctx);
                _fetchHubData();
              },
              child: const Text("Create Group"),
            ),
          ],
        ),
      ),
    );
  }

  void _openMediaGalleryDialog() {
    final mediaMessages = _currentStreamMessages.where((l) {
      final payload = _messagePayload(l["message"]);
      return (payload != null && payload["type"] == "file") ||
          (l["message"] ?? "").toString().contains("Attached Document");
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Media & Files: $_selectedChatTarget", style: const TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 400,
          height: 350,
          child: mediaMessages.isEmpty
              ? const Center(child: Text("No shared files or documents found in this chat.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: mediaMessages.length,
                  itemBuilder: (context, index) {
                    final msg = mediaMessages[index];
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF0052CC)),
                      title: Text(
                        _messagePayload(msg["message"])?["fileName"]?.toString() ??
                            _plainMessage(msg["message"]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Sent by ${msg["senderName"]} at ${msg["time"]}", style: const TextStyle(fontSize: 10)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _openGroupDetailsDialog(Map<String, dynamic> group) {
    final bool isCreator = group["created_by"] == _loggedInEmployee;
    List<String> admins = [];
    try { admins = List<String>.from(jsonDecode(group["admins"] ?? '[]')); } catch (_) { admins = [group["created_by"]]; }
    final bool isAdmin = admins.contains(_loggedInEmployee) || isCreator;

    List<String> members = [];
    try { members = List<String>.from(jsonDecode(group["members"] ?? '[]')); } catch (_) {}

    final TextEditingController groupNameController = TextEditingController(text: group["group_name"]);
    Map<String, bool> editedMembers = {
      for (var e in activeEmployees)
        e["full_name"].toString(): members.contains(e["full_name"].toString())
    };
    Map<String, bool> editedAdmins = {
      for (var e in activeEmployees)
        e["full_name"].toString(): admins.contains(e["full_name"].toString())
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(group["group_name"], style: const TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w900)),
              Text("${members.length} Members", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          content: SizedBox(
            width: 550,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin) ...[
                    TextField(controller: groupNameController, decoration: const InputDecoration(labelText: 'Group Name')),
                    const SizedBox(height: 16),
                  ],
                  const Text("Group Admins:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0052CC))),
                  const SizedBox(height: 6),
                  ...activeEmployees.map((emp) {
                    final name = emp["full_name"]?.toString() ?? "";
                    final isMember = editedMembers[name] ?? false;
                    final isGroupAdmin = editedAdmins[name] ?? false;

                    if (!isMember || !isGroupAdmin) return const SizedBox.shrink();

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Admin Access", style: TextStyle(fontSize: 11, color: Colors.purple)),
                      trailing: isAdmin ? TextButton(
                        child: const Text("Dismiss Admin", style: TextStyle(fontSize: 11, color: Colors.red)),
                        onPressed: () {
                          setDialogState(() {
                            editedAdmins[name] = false;
                          });
                        },
                      ) : null,
                    );
                  }),
                  const Divider(height: 24),
                  const Text("Group Members & Add Members:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0052CC))),
                  const SizedBox(height: 6),
                  ...activeEmployees.map((emp) {
                    final name = emp["full_name"]?.toString() ?? "";
                    final isMember = editedMembers[name] ?? false;
                    final isGroupAdmin = editedAdmins[name] ?? false;

                    return CheckboxListTile(
                      dense: true,
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(isGroupAdmin ? "Admin" : (isMember ? "Group Member" : "Not in group (Add Member)"), 
                        style: TextStyle(fontSize: 11, color: isMember ? (isGroupAdmin ? Colors.purple : Colors.green) : Colors.grey)),
                      value: isMember,
                      activeColor: const Color(0xFF0052CC),
                      onChanged: isAdmin ? (val) {
                        setDialogState(() {
                          editedMembers[name] = val ?? false;
                          if (!(val ?? false)) {
                            editedAdmins[name] = false;
                          }
                        });
                      } : null,
                      secondary: isAdmin && isMember && !isGroupAdmin ? TextButton(
                        child: const Text("Make Admin", style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            editedAdmins[name] = true;
                          });
                        },
                      ) : null,
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
            if (isAdmin)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), foregroundColor: Colors.white),
                onPressed: () async {
                  final newMembers = editedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
                  final newAdmins = editedAdmins.entries.where((e) => e.value && editedMembers[e.key] == true).map((e) => e.key).toList();

                  await http.patch(
                    Uri.parse('$_baseUrl/chat/groups/${group["id"]}'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'groupName': groupNameController.text,
                      'members': newMembers,
                      'admins': newAdmins,
                      'requesterName': _loggedInEmployee,
                    }),
                  );

                  Navigator.pop(ctx);
                  _fetchHubData();
                },
                child: const Text("Save Changes"),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateMeetingStatus(int meetingId, String status) async {
    final res = await http.patch(
      Uri.parse('$_baseUrl/chat/meetings/$meetingId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'actionBy': _loggedInEmployee}),
    );
    if (res.statusCode == 200) {
      _fetchHubData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Meeting marked as $status successfully!")));
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedChatTarget.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/chat/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderName': _loggedInEmployee,
          'recipientName': _isGroupChat ? null : _selectedChatTarget,
          'groupId': _isGroupChat ? _selectedChatTarget : null,
          'isGroup': _isGroupChat ? 1 : 0,
          'message': _messageController.text.trim(),
          'replyTo': _replyingToMessage?["message"],
        }),
      );
      _messageController.clear();
      setState(() {
        _replyingToMessage = null;
        _showEmojiPicker = false;
        _showMentionOverlay = false;
      });
      _fetchHubData();
    } catch (_) {}
  }

  Future<void> _pickKbDocumentAndSend() async {
  if (_selectedChatTarget.isEmpty) return;

  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,

      // ONLY these file types
      allowedExtensions: [
        'pdf',
        'csv',
        'ppt',
        'pptx',
        'doc',
        'docx',
      ],

      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;

    if (file.bytes == null) {
      _showFileError(
        'Unable to read the selected file. Please try again.',
      );
      return;
    }

    // =========================================================
    // MAX FILE SIZE = 1 MB
    // =========================================================

    const maxFileSize = 1 * 1024 * 1024; // 1 MB

    if (file.size > maxFileSize) {
      _showFileError(
        'File size must be below 1 MB.',
      );
      return;
    }

    // =========================================================
    // EXTRA FRONTEND EXTENSION CHECK
    // =========================================================

    final extension =
        file.name.split('.').last.toLowerCase();

    const allowedExtensions = {
      'pdf',
      'csv',
      'ppt',
      'pptx',
      'doc',
      'docx',
    };

    if (!allowedExtensions.contains(extension)) {
      _showFileError(
        'Only PDF, CSV, PPT, PPTX, DOC and DOCX files are allowed.',
      );
      return;
    }

    setState(() {
      _selectedFileName = file.name;
    });

    if (!mounted) return;

    final shouldSend = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        // final sizeMb =
        //     (file.size / (1024 * 1024)).toStringAsFixed(2);

// Replace with this:
final double sizeInKb = file.size / 1024;
final String sizeText = sizeInKb > 1024 
    ? '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB' 
    : '${sizeInKb.toStringAsFixed(1)} KB';


        return Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                blurRadius: 28,
                color: Color(0x26000000),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius:
                        BorderRadius.circular(99),
                  ),
                ),

                const SizedBox(height: 18),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ready to share?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F7FF),
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD8E8FF),
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            Color(0xFF0052CC),
                        child: Icon(
                          Icons.insert_drive_file_rounded,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text('$sizeText  •  Tap Send to upload',
    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        style:
                            OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(48),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        child:
                            const Text('Cancel'),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pop(ctx, true),
                        icon: const Icon(
                          Icons.send_rounded,
                          size: 18,
                        ),
                        label:
                            const Text('Send File'),
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF0052CC),
                          foregroundColor:
                              Colors.white,
                          minimumSize:
                              const Size.fromHeight(48),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSend != true) {
      if (mounted) {
        setState(() {
          _selectedFileName = null;
        });
      }
      return;
    }

    // =========================================================
    // MULTIPART REQUEST
    // =========================================================

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/chat/send'),
    );

    request.fields['senderName'] =
        _loggedInEmployee ?? 'Admin';

    if (_isGroupChat) {
      request.fields['groupId'] =
          _selectedChatTarget;

      request.fields['isGroup'] = '1';
    } else {
      request.fields['recipientName'] =
          _selectedChatTarget;

      request.fields['isGroup'] = '0';
    }

    if (_replyingToMessage != null) {
      request.fields['replyTo'] =
          _plainMessage(
        _replyingToMessage!['message'],
      );
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ),
    );

    // =========================================================
    // SEND
    // =========================================================

    final response = await request.send();

    final body =
        await response.stream.bytesToString();

    if (response.statusCode == 201) {
      if (mounted) {
        setState(() {
          _selectedFileName = null;
          _replyingToMessage = null;
        });
      }

      await _fetchHubData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'File uploaded and shared successfully.',
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedFileName = null;
        });
      }

      _showFileError(
        'File upload failed (${response.statusCode}).',
      );

      debugPrint(
        'Upload response: $body',
      );
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _selectedFileName = null;
      });
    }

    _showFileError(
      'File upload failed. Please try again.',
    );

    debugPrint(
      'Upload error: $e',
    );
  }
}

  void _showFileError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> get _currentStreamMessages {
    if (_selectedChatTarget.isEmpty) return [];
    return notificationLogs.where((log) {
      if (_isGroupChat) {
        return log["isGroup"] == true && log["recipientName"] == _selectedChatTarget;
      } else {
        return (log["senderName"] == _loggedInEmployee && log["recipientName"] == _selectedChatTarget) ||
               (log["senderName"] == _selectedChatTarget && log["recipientName"] == _loggedInEmployee);
      }
    }).toList();
  }

Map<String, dynamic>? _messagePayload(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is! String) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  
  if (raw.startsWith('📎 ')) {
    final name = raw.replaceFirst('📎 ', '').trim();
    return {
      'type': 'file',
      'fileName': name,
      'name': name,
      'url': '/uploads/chat/$name',
      'fileUrl': '/uploads/chat/$name'
    };
  }
  
  return null;
}


  String _plainMessage(dynamic raw) {
    final payload = _messagePayload(raw);
    if (payload == null) return raw?.toString() ?? '';
    if (payload['type'] == 'file') {
      return '📎 ${payload['fileName'] ?? 'Shared file'}';
    }
    return payload['text']?.toString() ?? raw.toString();
  }

  Future<void> _copyMessage(dynamic raw) async {
    await Clipboard.setData(ClipboardData(text: _plainMessage(raw)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard.')),
    );
  }

  Widget _buildMessageContent(dynamic raw, {bool compact = false}) {
    final payload = _messagePayload(raw);

    if (payload != null && payload['type'] == 'file') {
      final fileName = payload['fileName']?.toString() ?? 'Shared file';
      final relativeUrl = payload['url']?.toString() ?? payload['fileUrl']?.toString() ?? '';
      final originUrl = _baseUrl.replaceAll(RegExp(r'/api/?$'), '');
      // final fileUrl = relativeUrl.startsWith('http') ? relativeUrl : '$originUrl$relativeUrl';
      final fileUrl = relativeUrl.startsWith('http') 
    ? relativeUrl 
    : '$originUrl/api/chat/download/${Uri.encodeComponent(fileName)}';
      
      final size = int.tryParse(payload['size']?.toString() ?? '') ?? 0;
      
      final double sizeInKb = size / 1024;
      final String sizeText = sizeInKb > 1024 
          ? '${(size / (1024 * 1024)).toStringAsFixed(2)} MB' 
          : '${sizeInKb.toStringAsFixed(1)} KB';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD6E5FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF0052CC),
                  child: Icon(Icons.description_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(size > 0 ? sizeText : 'Document', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // OutlinedButton.icon(
                //   style: OutlinedButton.styleFrom(
                //     foregroundColor: const Color(0xFF0052CC),
                //     side: const BorderSide(color: Color(0xFF0052CC)),
                //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                //     minimumSize: Size.zero,
                //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                //   ),
                  // icon: const Icon(Icons.visibility_rounded, size: 14),
                  // label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  // onPressed: fileUrl.isEmpty ? null : () async {
                  //   final uri = Uri.tryParse(fileUrl);
                  //   if (uri != null && await canLaunchUrl(uri)) {
                  //     await launchUrl(uri, mode: LaunchMode.externalApplication);
                  //   }
                  // },
                // ),
                // const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052CC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Download', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: fileUrl.isEmpty ? null : () async {
  try {
    final uri = Uri.parse(fileUrl);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      // Force correct PDF/Binary blob handling
      final blob = html.Blob([response.bodyBytes], 'application/octet-stream');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final uriFallback = Uri.parse(fileUrl);
      if (await canLaunchUrl(uriFallback)) {
        await launchUrl(uriFallback, mode: LaunchMode.externalApplication);
      }
    }
  } catch (e) {
    debugPrint("Download error: $e");
  }
},
              ),
              ],
            ),
          ],
        ),
      );
    }

    final textValue = payload?['text']?.toString() ?? raw?.toString() ?? '';
    final reply = payload?['replyTo']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reply != null && reply.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: const Border(left: BorderSide(color: Color(0xFF0052CC), width: 3)),
            ),
            child: Text(
              reply,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ),
        _buildRichTextWithLinks(textValue),
      ],
    );
  }

  Widget _buildRichTextWithLinks(String value) {
    final regex = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)', caseSensitive: false);
    final matches = regex.allMatches(value).toList();
    if (matches.isEmpty) {
      return Text(value, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF172033)));
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      var urlText = value.substring(match.start, match.end);
      var trailing = '';
      while (urlText.isNotEmpty && '.,!?)]}'.contains(urlText[urlText.length - 1])) {
        trailing = urlText[urlText.length - 1] + trailing;
        urlText = urlText.substring(0, urlText.length - 1);
      }
      final href = urlText.startsWith('http') ? urlText : 'https://$urlText';
      spans.add(
        TextSpan(
          text: urlText,
          style: const TextStyle(color: Color(0xFF0052CC), decoration: TextDecoration.underline, fontWeight: FontWeight.w700),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(href);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing));
      cursor = match.end;
    }
    if (cursor < value.length) spans.add(TextSpan(text: value.substring(cursor)));

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF172033)),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.trim().toLowerCase();

    final filteredMeetings = scheduledMeetings.where((m) {
      List<dynamic> attendees = [];
      try { attendees = jsonDecode(m["attendees"] ?? '[]'); } catch (_) {}
      bool isParticipant = m["host_name"] == _loggedInEmployee || attendees.contains(_loggedInEmployee);
      if (!isParticipant) return false;

      final String status = m["status"] ?? 'Active';
      if (_meetingFilter == 'Active' || _meetingFilter == 'Present') {
        return status == 'Active';
      } else if (_meetingFilter == 'Completed') {
        return status == 'Completed';
      } else if (_meetingFilter == 'Rejected') {
        return status == 'Rejected';
      }
      return true;
    }).toList();

    List<Map<String, dynamic>> sortedEmployees = List.from(activeEmployees);
    if (searchQuery.isNotEmpty) {
      sortedEmployees = sortedEmployees.where((e) => (e["full_name"] ?? "").toLowerCase().contains(searchQuery)).toList();
    }
    sortedEmployees.sort((a, b) {
      String nameA = a["full_name"] ?? "";
      String nameB = b["full_name"] ?? "";

      bool pinA = pinnedChats.contains(nameA);
      bool pinB = pinnedChats.contains(nameB);
      if (pinA && !pinB) return -1;
      if (!pinA && pinB) return 1;

      var msgsA = notificationLogs.where((l) => (l["senderName"] == nameA && l["recipientName"] == _loggedInEmployee) || (l["senderName"] == _loggedInEmployee && l["recipientName"] == nameA));
      var msgsB = notificationLogs.where((l) => (l["senderName"] == nameB && l["recipientName"] == _loggedInEmployee) || (l["senderName"] == _loggedInEmployee && l["recipientName"] == nameB));
      String timeA = msgsA.isNotEmpty ? msgsA.first["created_at"] ?? msgsA.first["time"] ?? "" : "";
      String timeB = msgsB.isNotEmpty ? msgsB.first["created_at"] ?? msgsB.first["time"] ?? "" : "";
      return timeB.compareTo(timeA);
    });

    List<dynamic> sortedGroups = List.from(chatGroups);
    if (searchQuery.isNotEmpty) {
      sortedGroups = sortedGroups.where((g) => (g["group_name"] ?? "").toLowerCase().contains(searchQuery)).toList();
    }
    sortedGroups.sort((a, b) {
      String nameA = a["group_name"] ?? "";
      String nameB = b["group_name"] ?? "";

      bool pinA = pinnedChats.contains(nameA);
      bool pinB = pinnedChats.contains(nameB);
      if (pinA && !pinB) return -1;
      if (!pinA && pinB) return 1;

      var msgsA = notificationLogs.where((l) => l["recipientName"] == nameA && l["isGroup"] == true);
      var msgsB = notificationLogs.where((l) => l["recipientName"] == nameB && l["isGroup"] == true);
      String timeA = msgsA.isNotEmpty ? msgsA.first["created_at"] ?? msgsA.first["time"] ?? "" : "";
      String timeB = msgsB.isNotEmpty ? msgsB.first["created_at"] ?? msgsB.first["time"] ?? "" : "";
      return timeB.compareTo(timeA);
    });

    return Material(
      color: const Color(0xFFF7F9FC),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // ADMIN PANEL STYLE HERO HEADER
            // ==========================================
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 18 : 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF003B95),
                    Color(0xFF0052CC),
                    Color(0xFF1267E8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0052CC).withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.chat_bubble_rounded, size: 27, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Chats, Groups & Meeting Hub",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Real-time corporate messaging, group sync, and interactive meeting schedule.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0052CC),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _openMeetingSchedulerDialog,
                        icon: const Icon(Icons.timer_rounded, size: 18),
                        label: const Text("Schedule Meeting", style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _openCreateGroupDialog,
                        icon: const Icon(Icons.group_add_rounded, size: 18),
                        label: const Text("Create Group", style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (MediaQuery.of(context).size.width >= 760 || _showMobileChatList)
                      Container(
                        width: MediaQuery.of(context).size.width < 760
                            ? MediaQuery.of(context).size.width
                            : 300,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  TextButton(onPressed: () => setState(() => _whatsappNavIndex = 0), child: Text("Chats", style: TextStyle(fontWeight: FontWeight.bold, color: _whatsappNavIndex == 0 ? const Color(0xFF0052CC) : Colors.grey))),
                                  TextButton(onPressed: () => setState(() => _whatsappNavIndex = 1), child: Text("Groups", style: TextStyle(fontWeight: FontWeight.bold, color: _whatsappNavIndex == 1 ? const Color(0xFF0052CC) : Colors.grey))),
                                  TextButton(onPressed: () => setState(() => _whatsappNavIndex = 2), child: Text("Meetings", style: TextStyle(fontWeight: FontWeight.bold, color: _whatsappNavIndex == 2 ? const Color(0xFF0052CC) : Colors.grey))),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search chats & groups...',
                                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              ),
                            ),
                            if (_whatsappNavIndex == 2)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _meetingFilter,
                                  items: const [
                                    DropdownMenuItem(value: 'All', child: Text("All Meetings", style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Active', child: Text("Present / Active", style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Completed', child: Text("Completed", style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Rejected', child: Text("Rejected", style: TextStyle(fontSize: 12))),
                                  ],
                                  onChanged: (val) => setState(() => _meetingFilter = val ?? 'All'),
                                ),
                              ),
                            Expanded(
                              child: _whatsappNavIndex == 0
                                  ? sortedEmployees.isEmpty
                                      ? const Center(child: Text("No employees found", style: TextStyle(color: Colors.grey, fontSize: 12)))
                                      : ListView.builder(
                                          itemCount: sortedEmployees.length,
                                          itemBuilder: (context, index) {
                                            final emp = sortedEmployees[index];
                                            final String name = emp["full_name"]?.toString() ?? "Unknown User";
                                            final String role = emp["role"]?.toString().trim().isNotEmpty == true
                                                ? emp["role"].toString()
                                                : emp["user_type"]?.toString() == "admin" ? "Administrator" : "Employee";
                                            final String initials = emp["initials"]?.toString().trim().isNotEmpty == true
                                                ? emp["initials"].toString()
                                                : name.split(" ").where((e) => e.isNotEmpty).take(2).map((e) => e[0]).join().toUpperCase();
                                            final bool isAdmin = emp["user_type"]?.toString().toLowerCase() == "admin" ||
                                                emp["is_main_admin"] == 1 || emp["is_main_admin"] == true;
                                            final bool isSelected = _selectedChatTarget == name && !_isGroupChat;
                                            final bool isPinned = pinnedChats.contains(name);

                                            final unreadCount = notificationLogs.where((l) => l["senderName"] == name && l["recipientName"] == _loggedInEmployee && l["isSeen"] != true).length;
                                            final empMsgs = notificationLogs.where((l) => (l["senderName"] == name && l["recipientName"] == _loggedInEmployee) || (l["senderName"] == _loggedInEmployee && l["recipientName"] == name));
                                            final String lastChatTime = empMsgs.isNotEmpty ? (empMsgs.first["time"]?.toString() ?? "") : "";

                                            return ListTile(
                                              dense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                              leading: CircleAvatar(
                                                radius: 22,
                                                backgroundColor: isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF0052CC),
                                                child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                              title: Row(
                                                children: [
                                                  Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isSelected ? const Color(0xFF0052CC) : const Color(0xFF1E293B)))),
                                                  if (isPinned) const Icon(Icons.push_pin, size: 12, color: Colors.amber),
                                                ],
                                              ),
                                              subtitle: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                  ),
                                                  if (isAdmin) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(5)),
                                                      child: const Text("ADMIN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              trailing: SizedBox(
                                                width: 75,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    if (lastChatTime.isNotEmpty)
                                                      Text(lastChatTime, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        if (unreadCount > 0)
                                                          Container(
                                                            padding: const EdgeInsets.all(5),
                                                            decoration: const BoxDecoration(color: Color(0xFF0052CC), shape: BoxShape.circle),
                                                            child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                          ),
                                                        IconButton(
                                                          padding: EdgeInsets.zero,
                                                          constraints: const BoxConstraints(),
                                                          icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 14, color: isPinned ? Colors.amber : Colors.grey),
                                                          onPressed: () => _toggleChatPin(name, false, isPinned),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              selected: isSelected,
                                              selectedTileColor: const Color(0xFFEFF6FF),
                                              onTap: () {
                                                setState(() {
                                                  _selectedChatTarget = name;
                                                  _isGroupChat = false;
                                                  _showMobileChatList = false;
                                                });
                                                _markMessagesSeen(name, false);
                                              },
                                            );
                                          },
                                        )
                                  : _whatsappNavIndex == 1
                                      ? sortedGroups.isEmpty
                                          ? const Center(child: Text("No groups found", style: TextStyle(color: Colors.grey, fontSize: 12)))
                                          : ListView.builder(
                                              itemCount: sortedGroups.length,
                                              itemBuilder: (context, index) {
                                                final g = sortedGroups[index];
                                                final gName = g["group_name"];
                                                final unreadGroupCount = notificationLogs.where((l) => l["isGroup"] == true && l["recipientName"] == gName && l["senderName"] != _loggedInEmployee && l["isSeen"] != true).length;
                                                final isSelected = _selectedChatTarget == gName && _isGroupChat;
                                                final bool isPinned = pinnedChats.contains(gName);
                                                final groupMsgs = notificationLogs.where((l) => l["isGroup"] == true && l["recipientName"] == gName);
                                                final String lastGroupChatTime = groupMsgs.isNotEmpty ? (groupMsgs.first["time"]?.toString() ?? "") : "";

                                                return ListTile(
                                                  leading: const CircleAvatar(backgroundColor: Color(0xFF0EA5E9), child: Icon(Icons.group, color: Colors.white, size: 16)),
                                                  title: Row(
                                                    children: [
                                                      Expanded(child: Text(gName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                                      if (isPinned) const Icon(Icons.push_pin, size: 12, color: Colors.amber),
                                                    ],
                                                  ),
                                                  trailing: SizedBox(
                                                    width: 75,
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        if (lastGroupChatTime.isNotEmpty)
                                                          Text(lastGroupChatTime, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                        const SizedBox(height: 2),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          mainAxisAlignment: MainAxisAlignment.end,
                                                          children: [
                                                            if (unreadGroupCount > 0)
                                                              Container(
                                                                padding: const EdgeInsets.all(5),
                                                                decoration: const BoxDecoration(color: Color(0xFF0052CC), shape: BoxShape.circle),
                                                                child: Text('$unreadGroupCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                              ),
                                                            IconButton(
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                              icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 14, color: isPinned ? Colors.amber : Colors.grey),
                                                              onPressed: () => _toggleChatPin(gName, true, isPinned),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  selected: isSelected,
                                                  selectedTileColor: const Color(0xFFEFF6FF),
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedChatTarget = gName;
                                                      _isGroupChat = true;
                                                      _showMobileChatList = false;
                                                    });
                                                    _markMessagesSeen(gName, true);
                                                  },
                                                );
                                              },
                                            )
                                      : filteredMeetings.isEmpty
                                          ? const Center(child: Text("No meetings found", style: TextStyle(color: Colors.grey, fontSize: 12)))
                                          : ListView(
                                              children: filteredMeetings.map((m) {
                                                final String status = m["status"] ?? 'Active';
                                                final bool isActive = status == 'Active';
                                                final String hostName = m["host_name"] ?? 'Admin';
                                                final bool isMeetingAdmin = hostName == _loggedInEmployee;

                                                return Card(
                                                  margin: const EdgeInsets.all(8),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(m["title"], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
                                                            Chip(
                                                              backgroundColor: isActive ? Colors.green[100] : Colors.grey[300],
                                                              label: Text(
                                                                isActive ? "Active" : status, 
                                                                style: TextStyle(fontSize: 10, color: isActive ? Colors.green[800] : Colors.grey[700], fontWeight: FontWeight.bold)
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Text("Meeting Admin: $hostName", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                                                        Text("Time: ${m["meeting_time"]}", style: const TextStyle(fontSize: 11)),
                                                        InkWell(
                                                          onTap: () async {
                                                            final Uri url = Uri.parse(m["meeting_link"]);
                                                            if (await canLaunchUrl(url)) {
                                                              await launchUrl(url, mode: LaunchMode.externalApplication);
                                                            }
                                                          },
                                                          child: Text("Link: ${m["meeting_link"]}", style: const TextStyle(fontSize: 11, color: Colors.blue, decoration: TextDecoration.underline)),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            if (isMeetingAdmin && isActive)
                                                              TextButton(
                                                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                                                onPressed: () => _openEditMeetingDialog(m),
                                                                child: const Text("Edit", style: TextStyle(fontSize: 10)),
                                                              ),
                                                            if (isMeetingAdmin && isActive)
                                                              Row(
                                                                children: [
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 6)),
                                                                    onPressed: () => _updateMeetingStatus(m["id"], 'Completed'),
                                                                    child: const Text("Complete", style: TextStyle(fontSize: 10)),
                                                                  ),
                                                                  const SizedBox(width: 4),
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 6)),
                                                                    onPressed: () => _updateMeetingStatus(m["id"], 'Rejected'),
                                                                    child: const Text("Reject", style: TextStyle(fontSize: 10)),
                                                                  ),
                                                                ],
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                            ),
                          ],
                        ),
                      ),
                    if (MediaQuery.of(context).size.width >= 760 || !_showMobileChatList)
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
                              ),
                              child: Row(
                                children: [
                                  if (MediaQuery.of(context).size.width < 760)
                                    IconButton(
                                      tooltip: 'Back to chats',
                                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0052CC)),
                                      onPressed: () => setState(() => _showMobileChatList = true),
                                    ),
                                  CircleAvatar(
                                    backgroundColor: _isGroupChat ? const Color(0xFF0EA5E9) : const Color(0xFF0052CC), 
                                    radius: 18, 
                                    child: Icon(_isGroupChat ? Icons.group : Icons.chat, color: Colors.white, size: 16)
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        if (_isGroupChat) {
                                          final group = chatGroups.firstWhere((g) => g["group_name"] == _selectedChatTarget, orElse: () => {});
                                          if (group.isNotEmpty) _openGroupDetailsDialog(group);
                                        }
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedChatTarget.isEmpty ? 'Select a chat' : _selectedChatTarget, 
                                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))
                                          ),
                                          if (_isGroupChat)
                                            const Text("Click here to view group info, members & settings", style: TextStyle(fontSize: 10, color: Color(0xFF0052CC))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.folder_shared_outlined, color: Color(0xFF0052CC)),
                                    tooltip: "View Shared Media & Files",
                                    onPressed: _openMediaGalleryDialog,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, color: Color(0xFF0052CC)),
                                    tooltip: "Export Chat Transcript",
                                    onPressed: _exportChatTranscript,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: _currentStreamMessages.isEmpty
                                  ? const Center(child: Text("No messages yet. Start the conversation!", style: TextStyle(color: Colors.grey, fontSize: 13)))
                                  : ListView.builder(
                                      reverse: true,
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _currentStreamMessages.length,
                                      itemBuilder: (context, index) {
                                        final log = _currentStreamMessages[index];
                                        final bool isSentByMe = log["senderName"] == _loggedInEmployee;
                                        final bool isSeen = log["isSeen"] == true;
                                        final String sender = log["senderName"] ?? "Unknown";

                                        return Align(
                                          alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(vertical: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            constraints: const BoxConstraints(maxWidth: 480),
                                            decoration: BoxDecoration(
                                              // ==========================================
                                              // WHATSAPP / PREMIUM CHAT BUBBLE DESIGN
                                              // ==========================================
                                              color: isSentByMe ? const Color(0xFFEAF2FF) : Colors.white,
                                              borderRadius: BorderRadius.only(
                                                topLeft: const Radius.circular(16),
                                                topRight: const Radius.circular(16),
                                                bottomLeft: Radius.circular(isSentByMe ? 16 : 4),
                                                bottomRight: Radius.circular(isSentByMe ? 4 : 16),
                                              ),
                                              border: Border.all(
                                                color: isSentByMe ? const Color(0xFFCFE0FF) : const Color(0xFFE2E8F0),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.02),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (_isGroupChat && !isSentByMe) ...[
                                                  Text(
                                                    sender,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF0052CC),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                ],
                                                _buildMessageContent(log["message"]),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(log["time"], style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                                    const SizedBox(width: 6),
                                                    if (isSentByMe) ...[
                                                      Icon(
                                                        isSeen ? Icons.done_all : Icons.check,
                                                        size: 14,
                                                        color: isSeen ? const Color(0xFF0052CC) : Colors.grey,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      if (isSeen)
                                                        const Text(
                                                          "Seen",
                                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0052CC)),
                                                        ),
                                                    ],
                                                    const Spacer(),
                                                    IconButton(
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      tooltip: 'Copy message',
                                                      icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                                                      onPressed: () => _copyMessage(log["message"]),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      tooltip: 'Reply',
                                                      icon: const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF64748B)),
                                                      onPressed: () => setState(() => _replyingToMessage = log),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            if (_replyingToMessage != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                color: const Color(0xFFF1F5F9),
                                child: Row(
                                  children: [
                                    Expanded(child: Text("Replying to: ${_plainMessage(_replyingToMessage!["message"])}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                                    IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _replyingToMessage = null)),
                                  ],
                                ),
                              ),
                            if (_isGroupChat && _showMentionOverlay && _filteredMentionEmployees.isNotEmpty)
                              Container(
                                height: 120,
                                color: Colors.white,
                                child: ListView.builder(
                                  itemCount: _filteredMentionEmployees.length,
                                  itemBuilder: (context, index) {
                                    final emp = _filteredMentionEmployees[index];
                                    final name = emp["full_name"] ?? "";
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(radius: 12, child: Text(emp["initials"] ?? "?", style: const TextStyle(fontSize: 10))),
                                      title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onTap: () {
                                        final text = _messageController.text;
                                        final lastAtIndex = text.lastIndexOf('@');
                                        if (lastAtIndex != -1) {
                                          final newText = "${text.substring(0, lastAtIndex)}@$name ";
                                          _messageController.text = newText;
                                          _messageController.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
                                        }
                                        setState(() => _showMentionOverlay = false);
                                      },
                                    );
                                  },
                                ),
                              ),
                            if (_showEmojiPicker)
                              SizedBox(
                                height: 250,
                                child: EmojiPicker(
                                  onEmojiSelected: (category, emoji) {
                                    _messageController.text += emoji.emoji;
                                  },
                                ),
                              ),
                            if (_selectedFileName != null)
                              Container(
                                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF3FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCFE0FF)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.attach_file_rounded, size: 17, color: Color(0xFF0052CC)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_selectedFileName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0052CC))),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF64748B)),
                                      onPressed: () => setState(() => _selectedFileName = null),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(top: BorderSide(color: Color(0xFFE2E8F0))), borderRadius: BorderRadius.only(bottomRight: Radius.circular(20))),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF0052CC)),
                                    onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF0052CC)),
                                    tooltip: "Attach KB File (Max 10MB)",
                                    onPressed: _pickKbDocumentAndSend,
                                  ),
                                  Expanded(
                                    child: CallbackShortcuts(
                                      bindings: <ShortcutActivator, VoidCallback>{
                                        const SingleActivator(LogicalKeyboardKey.enter): () {
                                          _sendMessage();
                                        },
                                      },
                                      child: TextField(
                                        controller: _messageController,
                                        maxLines: null,
                                        keyboardType: TextInputType.multiline,
                                        decoration: InputDecoration(
                                          hintText: 'Type a message (Press Enter to send)...',
                                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF0052CC), width: 1.5)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF0052CC),
                                    child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18), onPressed: _sendMessage),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}