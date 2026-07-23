import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDayPlan();
  }

  Future<void> _fetchDayPlan() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/day-planner/today/${Uri.encodeComponent(widget.employeeName)}?date=${widget.date}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        setState(() {
          rows = List<Map<String, dynamic>>.from(jsonDecode(res.body));
          isLoading = false;
        });
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  // Column logic: Data irundha mattum column show aagum
  List<DataColumn> _buildColumns() {
    List<DataColumn> cols = [const DataColumn(label: Text("Client Name"))];

    if (rows.any((r) => (r['deliverables_1'] ?? '').toString().isNotEmpty)) {
      cols.addAll([
        const DataColumn(label: Text("Deliverable 1")),
        const DataColumn(label: Text("Completed Deliverable 1")),
        const DataColumn(label: Text("Balanced Deliverable 1")),
      ]);
    }
    if (rows.any((r) => (r['deliverables_2'] ?? '').toString().isNotEmpty)) {
      cols.addAll([
        const DataColumn(label: Text("Deliverable 2")),
        const DataColumn(label: Text("Completed Deliverable 2")),
        const DataColumn(label: Text("Balanced Deliverable 2")),
      ]);
    }
    if (rows.any((r) => (r['deliverables_3'] ?? '').toString().isNotEmpty)) {
      cols.addAll([
        const DataColumn(label: Text("Deliverable 3")),
        const DataColumn(label: Text("Completed Deliverable 3")),
        const DataColumn(label: Text("Balanced Deliverable 3")),
      ]);
    }

    cols.addAll([
      const DataColumn(label: Text("Today Plan")),
      const DataColumn(label: Text("Status")),
      const DataColumn(label: Text("Remarks")),
    ]);
    return cols;
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor = const Color(0xFFF1F5F9);
    Color textColor = const Color(0xFF64748B);
    switch (status.toUpperCase()) {
      case 'COMPLETE': bgColor = const Color(0xFFF0FDF4); textColor = const Color(0xFF16A34A); break;
      case 'PENDING': bgColor = const Color(0xFFFEF3C7); textColor = const Color(0xFFB45309); break;
      case 'PROCESSING': bgColor = const Color(0xFFEFF6FF); textColor = const Color(0xFF0369A1); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
final ScrollController _scrollController = ScrollController();
    return Scrollbar(
    controller: _scrollController,
    thumbVisibility: true, // Permanent-a scrollbar theriyum
    thickness: 8.0,
    child: SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: _buildColumns(),
        rows: rows.map((r) {
          // Row generation logic same-a irukkum...
          List<DataCell> cells = [DataCell(Text(r['client'] ?? '-'))];

          if (rows.any((row) => (row['deliverables_1'] ?? '').toString().isNotEmpty)) {
            cells.addAll([
              DataCell(Text(r['deliverables_1'] ?? '-')),
              DataCell(Text(r['complete_deliverables_1'] ?? '-')),
              DataCell(Text(r['balanced_deliverables_1'] ?? '-')),
            ]);
          }
          if (rows.any((row) => (row['deliverables_2'] ?? '').toString().isNotEmpty)) {
            cells.addAll([
              DataCell(Text(r['deliverables_2'] ?? '-')),
              DataCell(Text(r['complete_deliverables_2'] ?? '-')),
              DataCell(Text(r['balanced_deliverables_2'] ?? '-')),
            ]);
          }
          if (rows.any((row) => (row['deliverables_3'] ?? '').toString().isNotEmpty)) {
            cells.addAll([
              DataCell(Text(r['deliverables_3'] ?? '-')),
              DataCell(Text(r['complete_deliverables_3'] ?? '-')),
              DataCell(Text(r['balanced_deliverables_3'] ?? '-')),
            ]);
          }

          cells.addAll([
            DataCell(Text(r['today_plan'] ?? '-')),
            DataCell(_buildStatusBadge(r['status'] ?? 'NOT START')),
            DataCell(Text(r['remarks'] ?? '-')),
          ]);

          return DataRow(cells: cells);
        }).toList(),
      ),
    ),
  );
}
}



class _NotificationsScreenState extends State<NotificationsScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  // Selected employee filter (i.e. which conversation thread to show)
  String? _selectedEmployee;

  // Logged-in employee (from auth service)
  String? _loggedInEmployee;

  // FIX: no longer hardcoded — populated from the backend in
  // _fetchNotifications(), scoped to whoever is actually logged in. The
  // backend guarantees only threads where this person is sender OR
  // recipient ever come back, so there's no way to see someone else's
  // messages by accident.
  List<Map<String, dynamic>> notificationLogs = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      final loggedInName = authService.user?['fullName'] as String? ?? 'Unknown';
      setState(() {
        _loggedInEmployee = loggedInName;
      });
      _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    if (_loggedInEmployee == null || _loggedInEmployee!.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    try {
      final r = await http.get(
        Uri.parse('$_baseUrl/notifications/${Uri.encodeComponent(_loggedInEmployee!)}'),
      );
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final rows = List<dynamic>.from(body['data'] ?? []);
        setState(() {
          notificationLogs = rows.map((row) {
  final otherParty = row['otherParty'] as String? ?? 'Unknown';

  String rawMessage = row['message'] ?? '';
  String displayMessage = rawMessage;

  // JSON notification-na preview mattum list-la kaatu
  try {
    final obj = jsonDecode(rawMessage);

    if (obj is Map && obj["preview"] != null) {
      displayMessage = obj["preview"];
    }
  } catch (_) {
    // PLAN_SUBMITTED mathiri plain text notifications-ku onnum panna vendam
  }

  return {
    "id": row['id'],
    "initials": _initialsFor(otherParty),
    "name": otherParty,

    // Notification list-la idhu dhaan theriyum
    "message": displayMessage,

    // Popup open panna full JSON idhula irukkum
    "rawMessage": rawMessage,

    "time": row['time'] ?? '',
    "type": row['type'] ?? 'RECEIVED',
    "isSeen": row['isSeen'] as bool? ?? false,
    "isFavorite": row['isFavorite'] as bool? ?? false,
    "isArchived": row['isArchived'] as bool? ?? false,
  };
}).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load notifications (${r.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loading = false; });
    }
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '--';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _toggleFavorite(Map<String, dynamic> log) async {
    final newValue = !(log["isFavorite"] as bool);
    setState(() => log["isFavorite"] = newValue);
    try {
      await http.patch(
        Uri.parse('$_baseUrl/notifications/${log["id"]}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isFavorite': newValue}),
      );
    } catch (_) {
      // Non-fatal — local UI already updated; a refresh will resync if it failed.
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> log) async {
    setState(() => notificationLogs.remove(log));
    try {
      await http.delete(Uri.parse('$_baseUrl/notifications/${log["id"]}'));
    } catch (_) {}
  }

  // Get unique "other party" list — i.e. everyone THIS logged-in person has
  // an actual conversation thread with. Never anyone else's data.
  List<String> get _uniqueEmployees {
    final names = notificationLogs.map((log) => log["name"] as String).toSet().toList();
    names.sort();
    return names;
  }

  // Filter notifications based on selected thread
  List<Map<String, dynamic>> get _filteredNotifications {
    return notificationLogs.where((log) {
      if (_selectedEmployee == null) return true;
      return log["name"] == _selectedEmployee;
    }).toList();
  }

  // FIX: this file lives under employee_dashboard/, so it must never render
  // AdminLayout — that was causing "undefined_method: AdminLayout" since the
  // import for it isn't (and shouldn't be) present here. It now just returns
  // its own content in a plain scroll view, same as your other employee-side
  // screens (e.g. NotificationContent), which rely on whatever shell already
  // wraps them for the sidebar/header.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Header Banner ──
          const Text(
            "Notification",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            "Never miss an update — get real-time notifications on all your activities.",
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 28),

          // ── Main Content Container ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Title Bar ──
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    "List of Notification",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ── Main Content Row: Sidebar + Notifications ──
                SizedBox(
                  height: 520,
                  child: Row(
                    children: [
                      // ── LEFT SIDEBAR: threads for THIS logged-in person only ──
                      Container(
                        width: 200,
                        decoration: const BoxDecoration(
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildEmployeeItem("All", null),
                            const Divider(height: 1),
                            ..._uniqueEmployees.map((employee) {
                              return _buildEmployeeItem(employee, employee);
                            }).toList(),
                          ],
                        ),
                      ),

                      // ── RIGHT SECTION: Notifications List ──
                      Expanded(
                        child: Column(
                          children: [
                            // ── Table Header ──
                            Container(
                              height: 44,
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: const Row(
                                children: [
                                  SizedBox(width: 100, child: Text("TYPE", style: _headerStyle)),
                                  Expanded(child: Text("MESSAGE", style: _headerStyle)),
                                  SizedBox(width: 120, child: Text("TIME", textAlign: TextAlign.center, style: _headerStyle)),
                                  SizedBox(width: 60, child: Text("STATUS", textAlign: TextAlign.center, style: _headerStyle)),
                                  SizedBox(width: 60, child: Text("ACTION", textAlign: TextAlign.center, style: _headerStyle)),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),

                            // ── Notifications List ──
                            Expanded(
                              child: _loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _error != null
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(_error!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                              const SizedBox(height: 10),
                                              TextButton(onPressed: _fetchNotifications, child: const Text('Retry')),
                                            ],
                                          ),
                                        )
                                      : _filteredNotifications.isEmpty
                                          ? const Center(
                                              child: Text(
                                                "No notifications found.",
                                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                              ),
                                            )
                                          : ListView.separated(
                                      itemCount: _filteredNotifications.length,
                                      physics: const BouncingScrollPhysics(),
                                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                      itemBuilder: (context, index) {
  final log = _filteredNotifications[index];
  final isSent = log["type"] == "SENT";
  final isSeen = log["isSeen"] as bool;

  // InkWell wrap pannirukken for click effect
  return InkWell(
    onTap: () => _handleNotificationClick(log), 
    child: Container(
      height: 60,
      color: Colors.transparent, // InkWell click effect-kaga transparent
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // ── TYPE BADGE (SENT/RECEIVED) ──
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSent ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isSent ? "Sent" : "Received",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSent ? const Color(0xFF0052CC) : const Color(0xFFEA580C),
                ),
              ),
            ),
          ),

          // ── MESSAGE ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      log["message"],
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleFavorite(log),
                    icon: Icon(
                      log["isFavorite"] ? Icons.star_rounded : Icons.star_border_rounded,
                      color: log["isFavorite"] ? const Color(0xFF0052CC) : const Color(0xFFCBD5E1),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── TIME ──
          SizedBox(
            width: 120,
            child: Text(
              log["time"],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // ── STATUS ──
          SizedBox(
            width: 60,
            child: Center(
              child: isSent
                  ? isSeen
                      ? const Tooltip(
                          message: "Seen",
                          child: Icon(Icons.done_all, size: 16, color: Color(0xFF0052CC)),
                        )
                      : const Tooltip(
                          message: "Sent",
                          child: Icon(Icons.check, size: 16, color: Color(0xFF94A3B8)),
                        )
                  : const SizedBox(),
            ),
          ),

          // ── DELETE ──
          SizedBox(
            width: 60,
            child: Center(
              child: IconButton(
                onPressed: () => _deleteNotification(log),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
},
                                    ),
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  void _showDayPlanPopup(String empName, String date) {
    showDialog(
      context: context, // Ippo error varathu
      builder: (context) => AlertDialog(
        title: Text("Day Plan Details: $empName ($date)"),
        content: SizedBox(
          width: 900,
          height: 500,
          child: DayPlanTableViewer(employeeName: empName, date: date),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

// void _handleNotificationClick(Map<String, dynamic> log) {
//   final msg = log["message"].toString();
  
//   // 1. Debugging: Click work aagutha nu paakka
//   debugPrint("DEBUG: Notification clicked. Message: $msg");

//   // 2. Exact-a PLAN_SUBMITTED nu iruntha mattum execute aagum
//   // contains() use pannuvom so that it catches if there's any extra text
//   if (msg.contains("PLAN_SUBMITTED")) {
    
//     // Message structure: PLAN_SUBMITTED|EmployeeName|Date
//     final parts = msg.split('|');
    
//     // Index 0: PLAN_SUBMITTED, Index 1: Name, Index 2: Date
//     if (parts.length >= 3) {
//       final empName = parts[1].trim(); // trim() add pannunga (spaces remove panna)
//       final date = parts[2].trim();
      
//       debugPrint("DEBUG: Opening Popup for $empName on $date");
      
//       showDialog(
//         context: context, 
//         builder: (BuildContext dialogContext) {
//           return AlertDialog(
//             title: Text("Day Plan Details: $empName ($date)"),
//             content: SizedBox(
//               width: 900,
//               height: 500,
//               child: DayPlanTableViewer(employeeName: empName, date: date),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(dialogContext),
//                 child: const Text("Close"),
//               ),
//             ],
//           );
//         },
//       );
//     } else {
//       debugPrint("DEBUG: Message format mismatch. Parts: ${parts.length}");
//     }
//   } else {
//     debugPrint("DEBUG: Message does not contain PLAN_SUBMITTED");
//   }
// }


void _handleNotificationClick(Map<String, dynamic> log) {
  final msg = (log["rawMessage"] ?? log["message"]).toString();

  if (!(log["isSeen"] as bool)) {
    _markAsSeen(log);
  }

  debugPrint("Notification : $msg");

  // -----------------------------
  // DAY PLANNER (non JSON)
  // -----------------------------
  if (msg.startsWith("PLAN_SUBMITTED")) {
    final parts = msg.split("|");

    if (parts.length >= 3) {
      final empName = parts[1].trim();
      final date = parts[2].trim();

      _showDayPlanPopup(empName, date);
      return;
    }
  }

  // -----------------------------
  // JSON Notifications
  // -----------------------------
// -----------------------------
// JSON Notifications
// -----------------------------
if (!msg.startsWith("{")) {
  debugPrint("Not JSON notification");
  return;
}

try {
  final json = jsonDecode(msg);

  final data = json;

  switch (data["type"]) {

    // ===========================
    // TASK PLANNER
    // ===========================
    case "TASK_PLANNER_SHARE":

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Task Planner"),
          content: SizedBox(
            width: 650,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text("Shared By : ${data["sender"]}"),

                const SizedBox(height: 15),

                Text("Content Type : ${data["contentType"]}"),

                const SizedBox(height: 15),

                const Text("Message"),

                const SizedBox(height: 5),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(data["content"] ?? ""),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      );

      return;

    // ===========================
    // VIDEOGRAPHER
    // ===========================
    case "VIDEOGRAPHER_SHARE":

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Videographer Planner"),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text("Shared By : ${data["sender"]}"),

                const SizedBox(height: 10),

                Text("Client : ${data["client"]}"),

                const SizedBox(height: 10),

                const Text("Scheduling Details"),

                const SizedBox(height: 5),

                Text(data["schedulingDetails"] ?? ""),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      );

      return;

    default:
      debugPrint("Unknown notification type");
  }

} catch (e) {
  debugPrint("Notification JSON Error : $e");
}
}

Future<void> _markAsSeen(Map<String, dynamic> log) async {
  try {
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/notifications/${log["id"]}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'isSeen': true}),
    );
    setState(() => log["isSeen"] = true); // UI-la update panna
  } catch (e) {
    debugPrint("Error marking seen: $e");
  }
}

int _unreadCount(String employee) {
  return notificationLogs.where((log) {
    return log["name"] == employee &&
        (log["isSeen"] == false);
  }).length;
}

  // ── Build Employee Sidebar Item ──

  Widget _buildEmployeeItem(String label, String? employeeName) {
  final isSelected = _selectedEmployee == employeeName;

  return InkWell(
    onTap: () {
      setState(() {
        _selectedEmployee = employeeName;
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isSelected
          ? const Color(0xFFEFF6FF)
          : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF0052CC)
                    : const Color(0xFF475569),
              ),
            ),
          ),

          // Unread Count
          if (employeeName != null && _unreadCount(employeeName) > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 54, 70, 244),
                shape: BoxShape.circle,
              ),
              child: Text(
                "${_unreadCount(employeeName)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
 
  // Widget _buildEmployeeItem(String label, String? employeeName) {
  //   final isSelected = _selectedEmployee == employeeName;

  //   return InkWell(
  //     onTap: () {
  //       setState(() {
  //         _selectedEmployee = employeeName;
  //       });
  //     },
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  //       color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
  //       child: Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: 13,
  //           fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
  //           color: isSelected ? const Color(0xFF0052CC) : const Color(0xFF475569),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF475569),
    letterSpacing: 0.8,
  );
}