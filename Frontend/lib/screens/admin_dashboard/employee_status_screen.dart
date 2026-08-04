import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class EmployeeStatusScreen extends StatefulWidget {
  const EmployeeStatusScreen({super.key});

  @override
  State<EmployeeStatusScreen> createState() => _EmployeeStatusScreenState();
}

class _EmployeeStatusScreenState extends State<EmployeeStatusScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  // Active selected filter category tracker variable
  String activeFilter = "All";
  String searchText = "";

  // ── FILTER VISIBILITY TOGGLE TRACKER FLAG ──
  bool _isFilterMenuOpen = false;

  // FIX: no longer hardcoded — populated from the backend in _fetchEmployeeStatus().
  // Same map shape as before, plus a new "completedLabel" field (e.g. "5/12")
  // for the new COMPLETED column.
  List<Map<String, dynamic>> masterEmployeeData = [];

  bool _loading = true;
  String? _error;
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeStatus();
    _initSocketListener();
  }

  @override
  void dispose() {
    socket.dispose(); 
    super.dispose();
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

    socket.on('task_updated', (data) {
      print("🔥 Admin live status update received: $data");
      if (mounted) {
        _fetchEmployeeStatus(); // Employee task change aanal admin screen automatic-ah refresh aagum!
      }
    });
  }

  Future<void> _fetchEmployeeStatus() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(Uri.parse('$_baseUrl/admin/employee-status'));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final rows = List<dynamic>.from(body['data'] ?? []);
        setState(() {
          // masterEmployeeData = rows.map((row) => _mapRow(row)).toList();
          masterEmployeeData =
    rows.reversed.map((row) => _mapRow(row)).toList();
    masterEmployeeData.sort((a, b) {
  return b["date"].compareTo(a["date"]);
});
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load employee status (${r.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loading = false; });
    }
  }

  // Turns one backend row into the exact map shape the existing table
  // widgets expect — this is the only place that knows about colors/labels.
  Map<String, dynamic> _mapRow(dynamic row) {
    final employeeName = row['employeeName'] as String? ?? 'Unassigned';
    final priority = (row['priority'] as String? ?? 'LOW').toUpperCase();
    final rawStatus = (row['status'] as String? ?? 'IDLE').toUpperCase();
    final daysLeft = row['daysLeft'] as int?;

    final priorityColors = _priorityColors(priority);
    // final statusInfo = _statusDisplay(rawStatus);
    final timeInfo = _timeLeftDisplay(daysLeft);

    // FIX: new "completed/total" label, e.g. "5/12", from the backend's
    // completedRows/totalRows counts.
final completedRows = row['completedRows'] as int? ?? 0;
final totalRows = row['totalRows'] as int? ?? 0;

final holdRows = row['holdRows'] as int? ?? 0;
final processingRows = row['processingRows'] as int? ?? 0;
final notStartedRows = row['notStartedRows'] as int? ?? 0;

final completedLabel = '$completedRows/$totalRows';
final holdLabel = '$holdRows/$totalRows';
final processingLabel = '$processingRows/$totalRows';
final notStartedLabel = '$notStartedRows/$totalRows';

final allDone = totalRows > 0 && completedRows >= totalRows;

    return {
      "client": row['clientName'] ?? '',
      "initials": _initialsFor(employeeName),
      "name": employeeName,
      "task": row['task'] ?? '',
      "duration": row['duration'] ?? 'N/A',
      "priority": priority,
      "priorityBg": priorityColors.$1,
      "priorityText": priorityColors.$2,
      "date": _formatDate(row['submissionDate'] as String?),
      "timeLeft": timeInfo.$1,
      "timeColor": timeInfo.$2,
      // "status": statusInfo.$1,
      // "statusBg": statusInfo.$2,
      // "statusText": statusInfo.$3,
      "completedLabel": completedLabel,
"completedAllDone": allDone,

"holdTask": holdLabel,
"processingTask": processingLabel,
"notStartedTask": notStartedLabel,
    };
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '--';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    try {
      final d = DateTime.parse(raw);
      const months = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  (Color, Color) _priorityColors(String priority) {
    switch (priority) {
      case 'URGENT': return (const Color(0xFFFEE2E2), const Color(0xFFDC2626));
      case 'HIGH':   return (const Color(0xFFFFE4E6), const Color(0xFFEF4444));
      case 'MEDIUM': return (const Color(0xFFFEF3C7), const Color(0xFFD97706));
      default:       return (const Color(0xFFDCFCE7), const Color(0xFF16A34A)); // LOW
    }
  }

  // FIX: this is the "IDLE -> Not Started" rename the person asked for,
  // plus a color for every real DB status value.
  (String, Color, Color) _statusDisplay(String rawStatus) {
    switch (rawStatus) {
      case 'IDLE':
        return ('NOT STARTED', const Color(0xFFF1F5F9), const Color(0xFF64748B));
      case 'IN PROGRESS':
        return ('IN PROGRESS', const Color(0xFFE0F2FE), const Color(0xFF0369A1));
      case 'ON HOLD':
        return ('ON HOLD', const Color(0xFFFEF3C7), const Color(0xFFD97706));
      case 'COMPLETED':
        return ('COMPLETED', const Color(0xFFDCFCE7), const Color(0xFF16A34A));
      case 'REJECTED':
        return ('REJECTED', const Color(0xFFFEE2E2), const Color(0xFFDC2626));
      default:
        return (rawStatus, const Color(0xFFF1F5F9), const Color(0xFF64748B));
    }
  }

  (String, Color) _timeLeftDisplay(int? daysLeft) {
    if (daysLeft == null) return ('--', const Color(0xFF64748B));
    if (daysLeft > 0) return ('$daysLeft Day${daysLeft == 1 ? '' : 's'} Left', const Color(0xFF22C55E));
    if (daysLeft == 0) return ('Due Today', const Color(0xFFD97706));
    final overdue = daysLeft.abs();
    return ('$overdue Day${overdue == 1 ? '' : 's'} Overdue', const Color(0xFFDC2626));
  }

  @override
  Widget build(BuildContext context) {
    // ── FUNCTIONAL REACTIVE DATA FILTERING ENGINE ──
    // List<Map<String, dynamic>> filteredRows = masterEmployeeData.where((row) {
    List<Map<String, dynamic>> filteredRows =
    masterEmployeeData.where((row) {

  bool statusMatch =
      !_isFilterMenuOpen ||
      activeFilter == "All" ||
      row["priority"]
          .toString()
          .toUpperCase() ==
          activeFilter.toUpperCase();

  bool searchMatch =
      searchText.isEmpty ||

      row["client"]
          .toString()
          .toLowerCase()
          .contains(searchText.toLowerCase()) ||

      row["name"]
          .toString()
          .toLowerCase()
          .contains(searchText.toLowerCase()) ||

      row["task"]
          .toString()
          .toLowerCase()
          .contains(searchText.toLowerCase());

  return statusMatch && searchMatch;
}).toList();
    //   if (!_isFilterMenuOpen || activeFilter == "All") return true;
    //   return row["status"].toString().toUpperCase() == activeFilter.toUpperCase();
    // }).toList();

    return AdminLayout(
      pageTitle: "Employee Status",
      currentRoute: "/employee-status",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title & Global Creation Toolbar Row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Employee Status",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Assign, monitor, and manage employee tasks based on departments, projects, and client deliverables.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── MAIN CONTENT LEDGER DATA CONTAINER TABLE ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Dynamic Interactive Ribbon Filter Tabs Panel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    //   const Text(
                    //     "Employee Status",
                    //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    //   ),
                    //   const SizedBox(height: 20),

// SizedBox(
//   width: 350,
//   child: TextField(
//     onChanged: (value) {
//       setState(() {
//         searchText = value;
//       });
//     },
//     decoration: InputDecoration(
//       hintText: "Search Client / Employee / Task",
//       prefixIcon: const Icon(Icons.search),
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//       ),
//       contentPadding: const EdgeInsets.symmetric(vertical: 12),
//     ),
//   ),
// ),

Container(
  width: 350,
  height: 42,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  child: TextField(
    onChanged: (value) {
      setState(() {
        searchText = value;
      });
    },
    decoration: InputDecoration(
      hintText: "Search Client / Employee / Task",
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 13,
      ),
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: Color.fromARGB(255, 158, 158, 158),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 11,
        horizontal: 10,
      ),
    ),
  ),
),

const SizedBox(height: 20),
                      Row(
                        children: [
                          // ── ANIMATED FILTER CHIPS MENU BLOCK ──
                          AnimatedVisibility(
                            visible: _isFilterMenuOpen,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFilterTab("All"),
                                _buildFilterTab("Urgent"),
                                _buildFilterTab("High"),
                                _buildFilterTab("Medium"),
                                _buildFilterTab("Low"),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),

                          // ── MASTER FILTERS SHUTTER TOGGLE BUTTON ──
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isFilterMenuOpen = !_isFilterMenuOpen;
                                if (!_isFilterMenuOpen) {
                                  activeFilter = "All"; // Resets filter configuration when drawer rolls up
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

                // 2. Fixed Data Table Heading Headers Ribbon
                Container(
                  color: Colors.white,
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text("CLIENT", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("EMPLOYEE NAME", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("TASKS", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("TIME/DURATION", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("PRIORITY", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("DUE DATE", style: _headerStyle)),
                      // Expanded(flex: 2, child: Text("STATUS", style: _headerStyle)),
                      // Expanded(flex: 2, child: Text("COMPLETED TASK", style: _headerStyle)),
                      Expanded(flex: 2, child: Text("COMPLETED TASK", style: _headerStyle)),
Expanded(flex: 2, child: Text("HOLD TASK", style: _headerStyle)),
Expanded(flex: 2, child: Text("PROCESSING TASK", style: _headerStyle)),
Expanded(flex: 2, child: Text("NOT STARTED TASK", style: _headerStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                // 3. Vertically Scrollable Filtered Grid Rows Area
                SizedBox(
                  height: 480,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                  const SizedBox(height: 10),
                                  TextButton(onPressed: _fetchEmployeeStatus, child: const Text('Retry')),
                                ],
                              ),
                            )
                          : filteredRows.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No employee task matches this status group.",
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                  ),
                                )
                              : ListView.separated(
                          itemCount: filteredRows.length,
                          physics: const BouncingScrollPhysics(),
                          separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final row = filteredRows[index];
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
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: const BoxDecoration(color: Color(0xFFDCE4F7), shape: BoxShape.circle),
                                          alignment: Alignment.center,
                                          child: Text(
                                            row["initials"],
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4A69B3)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          row["name"],
                                          style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(row["task"], style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
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
                                        decoration: BoxDecoration(color: row["priorityBg"], borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          row["priority"],
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: row["priorityText"], letterSpacing: 0.3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row["date"], style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 3),
                                        Text(row["timeLeft"], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: row["timeColor"])),
                                      ],
                                    ),
                                  ),
                                  // Expanded(
                                  //   flex: 2,
                                  //   child: Align(
                                  //     alignment: Alignment.centerLeft,
                                  //     child: Container(
                                  //       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  //       decoration: BoxDecoration(color: row["statusBg"], borderRadius: BorderRadius.circular(4)),
                                  //       child: Text(
                                  //         row["status"],
                                  //         style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: row["statusText"], letterSpacing: 0.2),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                  // ── NEW: COMPLETED TASK COLUMN — e.g. "5/12" ──
Expanded(
  flex: 2,
  child: Text(
    row["completedLabel"],
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: row["completedAllDone"]
          ? const Color(0xFF16A34A)
          : const Color(0xFF334155),
    ),
  ),
),

Expanded(
  flex: 2,
  child: Text(
    row["holdTask"],
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: row["holdTask"].toString().startsWith("0/")
          ? const Color(0xFF64748B)
          : const Color(0xFFD97706),
    ),
  ),
),

Expanded(
  flex: 2,
  child: Text(
    row["processingTask"],
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: row["processingTask"].toString().startsWith("0/")
          ? const Color(0xFF64748B)
          : const Color(0xFF2563EB),
    ),
  ),
),

Expanded(
  flex: 2,
  child: Text(
    row["notStartedTask"],
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: row["notStartedTask"].toString().startsWith("0/")
          ? const Color(0xFF64748B)
          : const Color(0xFFDC2626),
    ),
  ),
),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // 4. Data Ledger Pagination Footer Component
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Showing 1 to ${filteredRows.length} of ${filteredRows.length} items", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Row(
                        children: [
                          _buildPageButton("<", false),
                          _buildPageButton("1", true),
                          _buildPageButton("2", false),
                          _buildPageButton("3", false),
                          _buildPageButton(">", false),
                        ],
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

  // ── CORE UTILITY DESIGN BUTTON GENERATORS ──
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