// name=employee_status_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as io_client;

class EmployeeStatusScreen extends StatefulWidget {
  const EmployeeStatusScreen({super.key});

  @override
  State<EmployeeStatusScreen> createState() => _EmployeeStatusScreenState();
}

class _EmployeeStatusScreenState extends State<EmployeeStatusScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  List<Map<String, dynamic>> masterEmployeeData = [];

  // Sorting and Filters State
  bool isSNoAscending = true;
  bool isClientAscending = true;
  String? selectedMaintenanceSort; // '1 to 31' or '31 to 1'
  String selectedMonthFilter = "All"; 
  String selectedStatusFilter = "All"; // 'All', 'Completed', 'Pending'
  String clientNameSearch = ""; // Client Name search query

  bool _loading = true;
  String? _error;
  late io_client.Socket socket;

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
    socket = io_client.io(
      ApiConfig.socketUrl,
      io_client.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    socket.connect();
    socket.on('task_updated', (data) {
      if (mounted) _fetchEmployeeStatus();
    });
  }

  Future<void> _fetchEmployeeStatus() async {
    setState(() { _loading = true; _error = null; });
    try {
      final url = Uri.parse('$_baseUrl/admin/admin-employee-status');
      final r = await http.get(url);

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final rows = List<dynamic>.from(body['data'] ?? []);
        setState(() {
          masterEmployeeData = rows.map((row) => _mapRow(row)).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load (${r.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loading = false; });
    }
  }

  Map<String, dynamic> _mapRow(dynamic row) {
    return {
      "taskListId": row['taskListId'],
      "client": row['clientName'] ?? '',
      "maintenanceDate": _formatOnlyDay(row['maintenanceDate']),
      "task": row['task'] ?? '',
      "date": row['submissionDate'] ?? '',
      "formattedDate": _formatDate(row['submissionDate'] as String?),
      "month": _extractMonth(row['submissionDate'] as String?),
      "status": row['status'] ?? 'In Progress',
    };
  }

  String _formatOnlyDay(dynamic rawDate) {
    if (rawDate == null || rawDate.toString().trim().isEmpty) return '—';
    final val = rawDate.toString().trim();
    if (val.contains('/')) {
      final parts = val.split('/');
      if (parts.isNotEmpty) return parts[0];
    }
    try {
      final parsed = DateTime.parse(val);
      return parsed.day.toString().padLeft(2, '0');
    } catch (_) {
      return val;
    }
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

  String _extractMonth(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      const months = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return months[d.month];
    } catch (_) {
      return '';
    }
  }

  void _navigateToTaskDetailView(String clientName) async {
    List<Map<String, dynamic>> clientAssignments = [];
    Map<String, int> dbTaskProgressCounts = {};

    try {
      final r = await http.get(Uri.parse('$_baseUrl/tasks'));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final allRows = List<Map<String, dynamic>>.from(body['data'] ?? []);
        clientAssignments = allRows.where((row) {
          return (row['client_name'] ?? '').toString().trim().toLowerCase() ==
              clientName.toString().trim().toLowerCase();
        }).toList();
      }

      final trRes = await http.get(Uri.parse('$_baseUrl/task-list/client/${Uri.encodeComponent(clientName)}'));
      if (trRes.statusCode == 200) {
        final trBody = jsonDecode(trRes.body);
        final taskLists = List<dynamic>.from(trBody['data'] ?? []);

        for (var tl in taskLists) {
          final tListId = tl['id'];
          final deliverables = (tl['deliverables'] ?? '').toString().trim().toLowerCase();

          final itemsRes = await http.get(Uri.parse('$_baseUrl/tracking-items/by-task-list/$tListId'));
          if (itemsRes.statusCode == 200) {
            final itemsBody = jsonDecode(itemsRes.body);
            final items = List<dynamic>.from(itemsBody['data'] ?? []);

            int completedRows = items.where((item) {
              final st = (item['status'] ?? '').toString().toUpperCase();
              return st == 'COMPLETED' || st == 'REJECTED';
            }).length;

            dbTaskProgressCounts[deliverables] = completedRows;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching client details for summary dialog: $e');
    }

    if (!mounted) return;

    final roleMappings = [
      {'roleLabel': 'Ads Handler', 'icon': Icons.campaign_outlined, 'empField': 'ads_handling', 'taskField': 'ads_platform'},
      {'roleLabel': 'Page Handler', 'icon': Icons.pages_outlined, 'empField': 'page_handling', 'taskField': 'pages_platform'},
      {'roleLabel': 'Designer', 'icon': Icons.design_services_outlined, 'empField': 'designer', 'taskField': 'designer_tasks'},
      {'roleLabel': 'Videographer', 'icon': Icons.videocam_outlined, 'empField': 'videographer', 'taskField': 'videographer_tasks'},
      {'roleLabel': 'Video Editor', 'icon': Icons.video_settings_outlined, 'empField': 'video_editor', 'taskField': 'video_editor_task'},
      {'roleLabel': 'UI/UX Designer', 'icon': Icons.web_outlined, 'empField': 'ui_ux_designer', 'taskField': 'ui_ux_tasks'},
      {'roleLabel': 'Developer', 'icon': Icons.code_outlined, 'empField': 'developer', 'taskField': 'developer_tasks'},
      {'roleLabel': 'Website Designer', 'icon': Icons.language_outlined, 'empField': 'website_designer', 'taskField': 'website_designer_tasks'},
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.analytics_outlined, color: Color(0xFF0052CC), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Task Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            const SizedBox(height: 3),
                            Text(clientName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 21, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: clientAssignments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64, height: 64,
                                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                                  child: const Icon(Icons.assignment_outlined, size: 30, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 14),
                                const Text('No assignments found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Assigned Team', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              const Text('View employees and their current task progress.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              const SizedBox(height: 16),
                              ...roleMappings.map((roleInfo) {
                                final roleLabel = roleInfo['roleLabel'] as String;
                                final icon = roleInfo['icon'] as IconData;
                                final empField = roleInfo['empField'] as String;
                                final taskField = roleInfo['taskField'] as String;

                                final Map<String, List<String>> empTaskMap = {};

                                for (var assignment in clientAssignments) {
                                  final empName = (assignment[empField] ?? '').toString().trim();
                                  final taskStr = (assignment[taskField] ?? '').toString().trim();

                                  if (empName.isEmpty || empName.toUpperCase() == 'NONE' || taskStr.isEmpty) continue;

                                  final tasksList = taskStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                                  empTaskMap.putIfAbsent(empName, () => []).addAll(tasksList);
                                }

                                if (empTaskMap.isEmpty) return const SizedBox.shrink();

                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 34, height: 34,
                                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(9)),
                                              child: Icon(icon, size: 18, color: const Color(0xFF004AAD)),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(roleLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                                              child: Text(
                                                '${empTaskMap.length} ${empTaskMap.length == 1 ? 'Employee' : 'Employees'}',
                                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      ...empTaskMap.entries.map((entry) {
                                        final employeeName = entry.key;
                                        final tasks = entry.value;

                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 28, height: 28,
                                                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE2E8F0))),
                                                    child: const Icon(Icons.person_outline, size: 16, color: Color(0xFF475569)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(employeeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 9),
                                              Wrap(
                                                spacing: 7,
                                                runSpacing: 7,
                                                children: tasks.map((tClean) {
                                                  final match = RegExp(r'^(.*?)\s*\((\d+)\)$').firstMatch(tClean.trim());
                                                  final tName = match != null ? match.group(1)!.trim() : tClean;
                                                  final totalR = match != null ? int.parse(match.group(2)!) : 1;

                                                  int compR = dbTaskProgressCounts[tName.toLowerCase()] ?? 0;
                                                  final isCompleted = totalR > 0 && compR >= totalR;
                                                  final progressText = '$compR/$totalR';

                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                    decoration: BoxDecoration(
                                                      color: isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(9),
                                                      border: Border.all(color: isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isCompleted ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                                                          size: 14,
                                                          color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Flexible(
                                                          child: Text(
                                                            tName,
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight: FontWeight.w600,
                                                              color: isCompleted ? const Color(0xFF166534) : const Color(0xFF475569),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            progressText,
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.w800,
                                                              color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 15, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Progress is updated from the assigned tasks.', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004AAD),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          ),
                          child: const Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredRows = masterEmployeeData.where((row) {
      bool clientMatch = clientNameSearch.isEmpty ||
          row["client"].toString().toLowerCase().contains(clientNameSearch.toLowerCase());

      bool monthMatch = selectedMonthFilter == "All" ||
          row["month"] == selectedMonthFilter;

      bool statusMatch = selectedStatusFilter == "All" ||
          row["status"] == selectedStatusFilter;

      return clientMatch && monthMatch && statusMatch;
    }).toList();

    filteredRows.sort((a, b) {
      int cmp = a["client"].toString().compareTo(b["client"].toString());
      return isClientAscending ? cmp : -cmp;
    });

    if (selectedMaintenanceSort != null) {
      filteredRows.sort((a, b) {
        int dayA = int.tryParse(a["maintenanceDate"].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        int dayB = int.tryParse(b["maintenanceDate"].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return selectedMaintenanceSort == "1 to 31" ? dayA.compareTo(dayB) : dayB.compareTo(dayA);
      });
    }

    if (!isSNoAscending) {
      filteredRows = filteredRows.reversed.toList();
    }

    return AdminLayout(
      pageTitle: "Employee Status",
      currentRoute: "/employee-status",
      onSearch: (query) => setState(() => clientNameSearch = query),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 750;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER HERO SECTION
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 20 : 28),
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
                  borderRadius: BorderRadius.circular(isMobile ? 22 : 28),
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
                  runSpacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isMobile ? 52 : 62,
                          height: isMobile ? 52 : 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                          ),
                          child: Icon(
                            Icons.people_outline_rounded,
                            size: isMobile ? 27 : 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Employee Status',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Monitor task assignments, deliverables, and schedules.',
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  height: 1.5,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        '${filteredRows.length} TASKS FOUND',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // FILTER BAR (Shown ONLY on mobile view as requested)
              if (isMobile) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButton<String>(
                          hint: const Text("Maintenance Date ▾", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
                          value: selectedMaintenanceSort,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0052CC)),
                          items: const [
                            DropdownMenuItem(value: "1 to 31", child: Text("1 to 31 (Asc)", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "31 to 1", child: Text("31 to 1 (Desc)", style: TextStyle(fontSize: 11))),
                          ],
                          onChanged: (val) => setState(() => selectedMaintenanceSort = val),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButton<String>(
                          value: selectedMonthFilter,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0052CC)),
                          items: const [
                            DropdownMenuItem(value: "All", child: Text("All Months ▾", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0052CC)))),
                            DropdownMenuItem(value: "Jan", child: Text("January", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Feb", child: Text("February", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Mar", child: Text("March", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Apr", child: Text("April", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "May", child: Text("May", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Jun", child: Text("June", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Jul", child: Text("July", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Aug", child: Text("August", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Sep", child: Text("September", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Oct", child: Text("October", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Nov", child: Text("November", style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: "Dec", child: Text("December", style: TextStyle(fontSize: 11))),
                          ],
                          onChanged: (val) => setState(() => selectedMonthFilter = val ?? "All"),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButton<String>(
                          value: selectedStatusFilter,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0052CC)),
                          items: const [
                            DropdownMenuItem(value: "All", child: Text("All Status ▾", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0052CC)))),
                            DropdownMenuItem(value: "Completed", child: Text("Completed", style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w700))),
                            DropdownMenuItem(value: "Pending", child: Text("Pending", style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w700))),
                          ],
                          onChanged: (val) => setState(() => selectedStatusFilter = val ?? "All"),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // DATA TABLE / CARD CONTAINER
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isMobile)
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => setState(() => isSNoAscending = !isSNoAscending),
                              child: SizedBox(
                                width: 60,
                                child: Row(
                                  children: [
                                    const Text("S.NO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.7)),
                                    const SizedBox(width: 2),
                                    Icon(isSNoAscending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 18, color: const Color(0xFF0052CC)),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () => setState(() => isClientAscending = !isClientAscending),
                                child: Row(
                                  children: [
                                    const Text("CLIENT NAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.7)),
                                    const SizedBox(width: 2),
                                    Icon(isClientAscending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 18, color: const Color(0xFF0052CC)),
                                  ],
                                ),
                              ),
                            ),
                            // DESKTOP HEADER 1: MAINTENANCE FILTER
                            Expanded(
                              flex: 2,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedMaintenanceSort,
                                  isDense: true,
                                  hint: const Text("MAINTENANCE ▾", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.7)),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0052CC)),
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text("MAINTENANCE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                                    DropdownMenuItem(value: "1 to 31", child: Text("1 to 31 (Asc)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "31 to 1", child: Text("31 to 1 (Desc)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                  ],
                                  onChanged: (val) => setState(() => selectedMaintenanceSort = val),
                                ),
                              ),
                            ),
                            // DESKTOP HEADER 2: MONTH FILTER
                            Expanded(
                              flex: 2,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedMonthFilter,
                                  isDense: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0052CC)),
                                  items: const [
                                    DropdownMenuItem(value: "All", child: Text("MONTH: ALL ▾", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
                                    DropdownMenuItem(value: "Jan", child: Text("January", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Feb", child: Text("February", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Mar", child: Text("March", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Apr", child: Text("April", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "May", child: Text("May", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Jun", child: Text("June", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Jul", child: Text("July", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Aug", child: Text("August", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Sep", child: Text("September", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Oct", child: Text("October", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Nov", child: Text("November", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                    DropdownMenuItem(value: "Dec", child: Text("December", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)))),
                                  ],
                                  onChanged: (val) => setState(() => selectedMonthFilter = val ?? "All"),
                                ),
                              ),
                            ),
                            const Expanded(flex: 2, child: Text("SUBMIT DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.7))),
                            // DESKTOP HEADER 3: STATUS FILTER (Default selection status included)
                            Expanded(
                              flex: 2,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedStatusFilter,
                                  isDense: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0052CC)),
                                  items: const [
                                    DropdownMenuItem(value: "All", child: Text("STATUS: ALL ▾", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
                                    DropdownMenuItem(value: "Completed", child: Text("COMPLETED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)))),
                                    DropdownMenuItem(value: "Pending", child: Text("PENDING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)))),
                                  ],
                                  onChanged: (val) => setState(() => selectedStatusFilter = val ?? "All"),
                                ),
                              ),
                            ),
                            const Expanded(flex: 1, child: Text("VIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.7), textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                    if (!isMobile) const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    SizedBox(
                      height: 480,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
                          : _error != null
                              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)))
                              : filteredRows.isEmpty
                                  ? const Center(child: Text("No tasks found", style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)))
                                  : isMobile
                                      ? ListView.builder(
                                          itemCount: filteredRows.length,
                                          padding: const EdgeInsets.all(14),
                                          itemBuilder: (context, index) {
                                            final row = filteredRows[index];
                                            final status = row["status"];
                                            Color statusColor = status == 'Completed' ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.02),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFEAF2FF),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            '#${index + 1}',
                                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF0052CC)),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                          decoration: BoxDecoration(
                                                            color: statusColor.withValues(alpha: 0.09),
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                                                          ),
                                                          child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      row["client"],
                                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.work_outline_rounded, size: 14, color: Color(0xFF0052CC)),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            "Deliverable: ${row["task"]}",
                                                            style: const TextStyle(fontSize: 12, color: Color(0xFF0052CC), fontWeight: FontWeight.w700),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                                                        const SizedBox(width: 6),
                                                        Text("Maintenance: ${row["maintenanceDate"]}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                                                        const SizedBox(width: 6),
                                                        Text("Submit Date: ${row["formattedDate"]}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 14),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () => _navigateToTaskDetailView(row["client"]),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF0052CC),
                                                          foregroundColor: Colors.white,
                                                          elevation: 0,
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                        child: const Text("View Details", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : ListView.separated(
                                          itemCount: filteredRows.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                          itemBuilder: (context, index) {
                                            final row = filteredRows[index];
                                            final status = row["status"];
                                            
                                            Color statusColor = const Color(0xFF0052CC);
                                            if (status == 'Completed') statusColor = const Color(0xFF16A34A);
                                            if (status == 'Pending') statusColor = const Color(0xFFDC2626);

                                            return Container(
                                              height: 64,
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              color: index.isEven ? Colors.white : const Color(0xFFFBFCFE),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 60,
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      row["client"],
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      row["maintenanceDate"],
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      row["task"],
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF0052CC), fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      row["formattedDate"],
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                        decoration: BoxDecoration(
                                                          color: statusColor.withValues(alpha: 0.09),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: statusColor.withValues(alpha: 0.16)),
                                                        ),
                                                        child: Text(
                                                          status.toUpperCase(),
                                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // HIGHLIGHTED BLUE BUTTON WITH PLAY/YOUTUBE STYLE ICON
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: InkWell(
                                                        onTap: () => _navigateToTaskDetailView(row["client"]),
                                                        borderRadius: BorderRadius.circular(10),
                                                        child: Container(
                                                          width: 36,
                                                          height: 34,
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF0052CC),
                                                            borderRadius: BorderRadius.circular(10),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: const Color(0xFF0052CC).withValues(alpha: 0.25),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, 3),
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Icon(
                                                            Icons.play_arrow_rounded,
                                                            color: Colors.white,
                                                            size: 20,
                                                          ),
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}