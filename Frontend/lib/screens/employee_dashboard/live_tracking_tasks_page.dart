import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LiveTrackingTasksPage extends StatefulWidget {
   final String searchQuery;
  const LiveTrackingTasksPage({
    super.key,
     this.searchQuery = '',
     });

  @override
  State<LiveTrackingTasksPage> createState() => _LiveTrackingTasksPageState();
}

class _LiveTrackingTasksPageState extends State<LiveTrackingTasksPage> {
  static String get _baseUrl => ApiConfig.baseUrl;
String searchQuery = "";
  String activeFilter = "All";
  String loggedInEmployeeName = "";
  bool _isFilterMenuOpen = false;
  List<Map<String, dynamic>> liveTasksData = [];
  bool _loading = true;
  String? _error;
  late IO.Socket socket;
  
  DateTime selectedDate = DateTime.now();
  
  // 🟢 State variable for total working hours display
  String formattedTotalWorkingTime = "00h 00m";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authService = context.read<AuthService>();
      final user = authService.user;

      setState(() {
        loggedInEmployeeName = user?['fullName'] ?? user?['name'] ?? user?['username'] ?? '';
      });

      _fetchLiveTasks();
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
    socket.off('task_updated');
    socket.on('task_updated', (data) {
      if (mounted) {
        _fetchLiveTasks();
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _fetchLiveTasks();
    }
  }

Future<void> _fetchLiveTasks() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

      final r = await http.get(
        Uri.parse('$_baseUrl/dashboard/live-tracking-tasks/$loggedInEmployeeName?date=$formattedDate'),
      );

      if (!mounted) return;

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final rows = List<dynamic>.from(body['data'] ?? []);

        List<Map<String, dynamic>> parsedTasks = rows.map((row) {
          return {
            "trackingItemId": row['trackingItemId'],
            "client": row['client_name'] ?? '',
            "task": row['task'] ?? '',
             "taskDescription": row['task_description'] ?? '',
            "duration": row['duration'] ?? 'N/A',
            "status": row['status'] ?? 'IDLE',
            "action": row['manager_action'] ?? 'ACTION',
            // "comment": row['manager_comment'] ?? '',
            "comment": row['comment'] ?? '',
          };
        }).toList();

        // 🟢 TABLE-IL IRUKKURA DURATION VALUES-MATTUM CALCULATE PANRA LOGIC
        int totalSumSeconds = 0;
        for (var task in parsedTasks) {
          String durStr = task["duration"].toString().toLowerCase();
          
          // Example: "22 mins" or "1 hrs 15 mins" or "2 hrs"
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

        setState(() {
          formattedTotalWorkingTime = '${totalHours.toString().padLeft(2, '0')}h ${totalMinutes.toString().padLeft(2, '0')}m';
          liveTasksData = parsedTasks;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load live tasks (${r.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _loading = false;
      });
    }
  }
  
  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // List<Map<String, dynamic>> filteredTasks = liveTasksData.where((row) {
    //   if (!_isFilterMenuOpen || activeFilter == "All") return true;
    //   return row["status"].toString().toUpperCase() == activeFilter.toUpperCase();
    // }).toList();
    List<Map<String, dynamic>> filteredTasks = liveTasksData.where((row) {
  // ─────────────────────────────
  // STATUS FILTER
  // ─────────────────────────────
  final statusMatches =
      activeFilter == "All" ||
      row["status"].toString().toUpperCase() ==
          activeFilter.toUpperCase();

  // ─────────────────────────────
  // SEARCH FILTER
  // ─────────────────────────────
  final search = widget.searchQuery.trim().toLowerCase();

  if (search.isEmpty) {
    return statusMatches;
  }

  final client =
      row["client"]?.toString().toLowerCase() ?? '';

  final task =
      row["task"]?.toString().toLowerCase() ?? '';

  final duration =
      row["duration"]?.toString().toLowerCase() ?? '';

  final description =
      row["taskDescription"]?.toString().toLowerCase() ?? '';

  final status =
      row["status"]?.toString().toLowerCase() ?? '';

  final action =
      row["action"]?.toString().toLowerCase() ?? '';

  final comment =
      row["comment"]?.toString().toLowerCase() ?? '';

  final searchMatches =
      client.contains(search) ||
      task.contains(search) ||
      duration.contains(search) ||
      description.contains(search) ||
      status.contains(search) ||
      action.contains(search) ||
      comment.contains(search);

  return statusMatches && searchMatches;
}).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Date Picker Row with Total Working Time Widget
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Live Tracking Tasks",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Monitor tasks started, restarted, or completed in real-time.",
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // 🟢 Total Working Hours Widget next to Date Picker
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_rounded, size: 16, color: Color(0xFF004AAD)),
                            const SizedBox(width: 6),
                            Text(
                              "Working Time: $formattedTotalWorkingTime",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _selectDate(context),
                        icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                        label: Text(
                          "Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0052CC),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Data Grid Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ribbon Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Task Logs",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                          Row(
                            children: [
                              if (_isFilterMenuOpen) ...[
                                _buildFilterTab("All"),
                                _buildFilterTab("IN PROGRESS"),
                                _buildFilterTab("ON HOLD"),
                                _buildFilterTab("COMPLETED"),
                                const SizedBox(width: 8),
                              ],
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isFilterMenuOpen = !_isFilterMenuOpen;
                                    if (!_isFilterMenuOpen) activeFilter = "All";
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF475569)),
                                      const SizedBox(width: 6),
                                      Text(_isFilterMenuOpen ? "Hide Filters" : "Filters",
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Table Headers
                    Container(
                      color: Colors.white,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text("CLIENT", style: _headerStyle)),
                          Expanded(flex: 2, child: Text("TASK", style: _headerStyle)),
                          Expanded(flex: 2, child: Text("DURATION", style: _headerStyle)),
                          Expanded(flex: 2, child: Text("TASK DESCRIPTION", style: _headerStyle)),
                          Expanded(flex: 2, child: Text("STATUS", style: _headerStyle)),
                          Expanded(flex: 2, child: Text("REVIEW ACTION", style: _headerStyle)),
                          Expanded(flex: 3, child: Text("COMMENT", style: _headerStyle)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Table Body List
                    SizedBox(
                      height: 480,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                              : filteredTasks.isEmpty
                                  ? const Center(child: Text("No live task tracking logs found for this date."))
                                  : ListView.separated(
                                      itemCount: filteredTasks.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (context, index) {
                                        final row = filteredTasks[index];
                                        return Container(
                                          height: 64,
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 2, child: Text(row["client"], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                              Expanded(flex: 2, child: Text(row["task"], style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
                                              Expanded(flex: 2, child: Text(row["duration"], style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
                                              Expanded(flex: 2, child: Text(row["taskDescription"], style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
                                              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildStatusBadge(row["status"]))),
                                              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Text(row["action"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                                              Expanded(flex: 3, child: Text(row["comment"].isEmpty ? "-" : row["comment"], style: const TextStyle(fontSize: 12, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
                                            ],
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
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color txt = const Color(0xFF475569);

    if (status == "IN PROGRESS") {
      bg = const Color(0xFFEFF6FF);
      txt = const Color(0xFF0284C7);
    } else if (status == "ON HOLD") {
      bg = const Color(0xFFFEF3C7);
      txt = const Color(0xFFD97706);
    } else if (status == "COMPLETED") {
      bg = const Color(0xFFDCFCE7);
      txt = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: txt)),
    );
  }

  Widget _buildFilterTab(String label) {
    bool isActive = activeFilter.toUpperCase() == label.toUpperCase();
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: OutlinedButton(
        onPressed: () => setState(() => activeFilter = label),
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF0052CC) : Colors.transparent,
          side: BorderSide(color: isActive ? const Color(0xFF0052CC) : const Color(0xFFE2E8F0)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: isActive ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.8);
}




