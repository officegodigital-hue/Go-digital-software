import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class TaskStatusScreen extends StatefulWidget {
  const TaskStatusScreen({super.key});

  @override
  State<TaskStatusScreen> createState() => _TaskStatusScreenState();
}

class _TaskStatusScreenState extends State<TaskStatusScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  // Current active filter category tab tracker
  String activeFilter = "All";

  String loggedInEmployeeName = "";

  // ── FILTER VISIBILITY TOGGLE TRACKER FLAG ──
  bool _isFilterMenuOpen = false;
  String searchQuery = "";

  // FIX: no longer hardcoded — populated from the backend in
  // _fetchReviewData(). Only COMPLETED tracking items come back, i.e. work
  // an employee has actually submitted, which is what "SUBMITTED" meant here.
  List<Map<String, dynamic>> reviewData = [];

  bool _loading = true;
  String? _error;
  late IO.Socket socket;

  
@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    final authService = context.read<AuthService>();
    final user = authService.user;

    if (!mounted) return;

    setState(() {
      loggedInEmployeeName =
          user?['fullName'] ??
          user?['name'] ??
          user?['username'] ??
          '';
    });

    _fetchReviewData();
    _initSocketListener();
  });
}

void _initSocketListener() {
  socket = IO.io(
    ApiConfig.socketUrl,
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableForceNew()
        .disableAutoConnect()
        .build(),
  );

  socket.connect();

  socket.off('task_updated'); // remove old listener

  socket.on('task_updated', (data) {
    print("🔥 $data");
    _fetchReviewData();
  });
}

Future<void> loadUser() async {

 final prefs = await SharedPreferences.getInstance();

 setState(() {
   loggedInEmployeeName =
       prefs.getString("employeeName") ?? " ";
 });

 _fetchReviewData();

}
Future<void> _fetchReviewData() async {
  if (!mounted) return;

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
final r = await http.get(
  Uri.parse(
      '$_baseUrl/manager-review/task-status/$loggedInEmployeeName'),
);

    if (!mounted) return;

    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      final rows = List<dynamic>.from(body['data'] ?? []);

      // Dispose old controllers
      for (final row in reviewData) {
        (row["controller"] as TextEditingController).dispose();
      }

      if (!mounted) return;

      setState(() {
        reviewData = rows.map((row) {
          final employeeName =
              row['employee_name'] as String? ?? 'Unassigned';

          return {
            "trackingItemId": row['tracking_item_id'],
            "client": row['client_name'] ?? '',
            "initials": _initialsFor(employeeName),
            "name": employeeName,
            "task": row['task'] ?? '',
             "taskDescription": row['task_description'] ?? '',
            "duration": row['duration'] ?? 'N/A',
            "status": row['status'] ?? 'COMPLETED',
            "action":
                (row['manager_action'] as String?)?.isNotEmpty == true
                    ? row['manager_action']
                    : 'ACTION',
            "controller": TextEditingController(
              text: row['manager_comment'] as String? ?? '',
            ),
          };
        }).toList();

        _loading = false;
      });
    } else {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load reviews (${r.statusCode})';
        _loading = false;
      });
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _error = 'Connection error: $e';
      _loading = false;
    });
  }
}
  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '--';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }


 

 @override
void dispose() {


  for (final row in reviewData) {
    (row["controller"] as TextEditingController).dispose();
  }
socket.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    // ── REACTIVE DATA FILTERING ENGINE ──
    // List<Map<String, dynamic>> filteredReviews = reviewData.where((row) {
    //   if (!_isFilterMenuOpen || activeFilter == "All") return true;
    //   return row["action"].toString().toUpperCase() == activeFilter.toUpperCase();
    // }).toList();
    final String query = searchQuery.trim().toLowerCase();

List<Map<String, dynamic>> filteredReviews = reviewData.where((row) {

  final client =
      (row["client"] ?? "").toString().toLowerCase();

  final task =
      (row["task"] ?? "").toString().toLowerCase();

  final duration =
      (row["duration"] ?? "").toString().toLowerCase();

  final status =
      (row["status"] ?? "").toString().toLowerCase();

  final action =
      (row["action"] ?? "").toString().toLowerCase();

  final controller =
      row["controller"] as TextEditingController?;

  final comment =
      controller?.text.toLowerCase() ?? "";

  // SEARCH
  final searchMatches =
      query.isEmpty ||
      client.contains(query) ||
      task.contains(query) ||
      duration.contains(query) ||
      status.contains(query) ||
      action.contains(query) ||
      comment.contains(query);

  if (!searchMatches) {
    return false;
  }

  // ACTION FILTER
  if (!_isFilterMenuOpen || activeFilter == "All") {
    return true;
  }

  return action == activeFilter.toLowerCase();

}).toList();

    return Scaffold(
  backgroundColor: const Color(0xFFF8FAFC),

  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Header & Description ──
          const Text(
            "Task  Status",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
  "Review completed tasks and provide approval, rework, or rejection with comments.",
  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),

          const SizedBox(height: 28),

          // ── Work Review Layout Container Data Grid ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Data Grid Control Ribbon Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Task Status",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      Row(
                        children: [
                          // ── DYNAMIC HORIZONTAL FILTER MENU TABS ──
                          AnimatedVisibility(
                            visible: _isFilterMenuOpen,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFilterTab("All"),
                                _buildFilterTab("Action"),
                                _buildFilterTab("Approved"),
                                _buildFilterTab("Rework"),
                                _buildFilterTab("Rejected"),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),

                          // ── FILTER VISIBILITY TOGGLE BUTTON ──
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isFilterMenuOpen = !_isFilterMenuOpen;
                                if (!_isFilterMenuOpen) {
                                  activeFilter = "All"; // Resets filter layout cleanly when hidden
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isFilterMenuOpen ? const Color(0xFFF1F5F9) : Colors.transparent,
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isFilterMenuOpen ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                                    size: 14,
                                    color: const Color(0xFF475569)
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isFilterMenuOpen ? "Hide Filters" : "Filters",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                // 2. Table Column Heading Titles Row
                Container(
                  color: Colors.white,
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text("CLIENT", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("TASKS", style: _headerStyle)),
                      Expanded(flex: 3, child: Text("TASK DESCRIPTION", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("TIME/DURATION", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("STATUS", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("ACTION", style: _headerStyle)),
                      Expanded(flex: 4, child: Text("COMMENT", style: _headerStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                // 3. Scrollable List of Work Review Submissions
                SizedBox(
                  height: 480,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                  const SizedBox(height: 10),
                                  TextButton(onPressed: _fetchReviewData, child: const Text('Retry')),
                                ],
                              ),
                            )
                          : filteredReviews.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No review logs found matching this active filter status.",
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                )
                              : ListView.separated(
                          itemCount: filteredReviews.length,
                          physics: const BouncingScrollPhysics(),
                          separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final row = filteredReviews[index];
                            return Container(
                              height: 64,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      row["client"],
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                 Expanded(
                                    flex: 2,
                                    child: Text(row["task"], style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                  ),
                                  Expanded(
  flex: 3,
  child: Text(
    row["taskDescription"] ?? "-",
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 13,
      color: Color(0xFF475569),
    ),
  ),
),
                                  Expanded(
                                    flex: 2,
                                    child: Text(row["duration"], style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                        child: const Text(
                                          "SUBMITTED",
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A), letterSpacing: 0.2),
                                        ),
                                      ),
                                    ),
                                  ),
                                 Expanded(
  flex: 2,
  child: Align(
    alignment: Alignment.centerLeft,
    child: _buildActionBadge(row["action"] ?? "ACTION"),
  ),
),
                                  Expanded(
  flex: 4,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Container(
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        (row["controller"] as TextEditingController).text.isEmpty
            ? "-"
            : (row["controller"] as TextEditingController).text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF334155),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ),
),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // 4. Data Ledger Pagination Footer Area Component
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Showing 1 to ${filteredReviews.length} of ${filteredReviews.length} review records", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      // Row(
                      //   children: [
                      //     _buildPageButton("<", false),
                      //     _buildPageButton("1", true),
                      //     _buildPageButton("2", false),
                      //     _buildPageButton("3", false),
                      //     _buildPageButton(">", false),
                      //   ],
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  ),
    );
  }

Widget _buildActionBadge(String action) {
  action = action.toUpperCase();

  Color bg = const Color(0xFFF1F5F9);
  Color txt = const Color(0xFF475569);

  switch (action) {
    case "APPROVED":
      bg = const Color(0xFFDCFCE7);
      txt = const Color(0xFF16A34A);
      break;

    case "REWORK":
      bg = const Color(0xFFFEF3C7);
      txt = const Color(0xFFD97706);
      break;

    case "REJECTED":
      bg = const Color(0xFFFEE2E2);
      txt = const Color(0xFFDC2626);
      break;

    default:
      bg = const Color(0xFFF1F5F9);
      txt = const Color(0xFF475569);
  }

  return Container(
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      action,
      style: TextStyle(
        color: txt,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    ),
  );
}
  Widget _buildFilterTab(String label) {
    bool isActive = activeFilter.toUpperCase() == label.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            activeFilter = label;
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF0052CC) : Colors.transparent,
          side: BorderSide(color: isActive ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          elevation: 0,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildPageButton(String text, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0052CC) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isActive ? null : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF475569)),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.8);
}

// ── CUSTOM LIGHTWEIGHT ANIMATED VISIBILITY HELPER WIDGET ──
class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;

  const AnimatedVisibility({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}