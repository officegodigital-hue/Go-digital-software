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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Employee Status", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      SizedBox(height: 4),
                      Text("Monitor task assignments, deliverables, and schedules.", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 40,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButton<String>(
                      hint: const Text("Maintenance Date ▾", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      value: selectedMaintenanceSort,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: "1 to 31", child: Text("1 to 31 (Asc)", style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: "31 to 1", child: Text("31 to 1 (Desc)", style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (val) => setState(() => selectedMaintenanceSort = val),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 40,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButton<String>(
                      value: selectedMonthFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: "All", child: Text("All Months ▾", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: 40,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButton<String>(
                      value: selectedStatusFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: "All", child: Text("All Status ▾", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: "Completed", child: Text("Completed", style: TextStyle(fontSize: 11, color: Color(0xFF16A34A)))),
                        DropdownMenuItem(value: "Pending", child: Text("Pending", style: TextStyle(fontSize: 11, color: Color(0xFFDC2626)))),
                      ],
                      onChanged: (val) => setState(() => selectedStatusFilter = val ?? "All"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isMobile)
                      Container(
                        color: const Color(0xFFF8FAFC),
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => setState(() => isSNoAscending = !isSNoAscending),
                              child: SizedBox(
                                width: 60,
                                child: Row(
                                  children: const [
                                    Text("S.NO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052CC), letterSpacing: 0.5)),
                                    Icon(Icons.swap_vert, size: 14, color: Color(0xFF0052CC)),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () => setState(() => isClientAscending = !isClientAscending),
                                child: Row(
                                  children: const [
                                    Text("CLIENT NAME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052CC), letterSpacing: 0.5)),
                                    Icon(Icons.swap_vert, size: 14, color: Color(0xFF0052CC)),
                                  ],
                                ),
                              ),
                            ),
                            const Expanded(flex: 2, child: Text("MAINTENANCE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052CC), letterSpacing: 0.5))),
                            const Expanded(flex: 2, child: Text("DELIVERABLES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052CC), letterSpacing: 0.5))),
                            const Expanded(flex: 2, child: Text("SUBMIT DATE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052CC), letterSpacing: 0.5))),
                            const Expanded(flex: 2, child: Text("STATUS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052CC), letterSpacing: 0.5))),
                            const Expanded(flex: 1, child: Text("VIEW", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052CC), letterSpacing: 0.5), textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                    if (!isMobile) const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    SizedBox(
                      height: 480,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 11)))
                              : filteredRows.isEmpty
                                  ? const Center(child: Text("No tasks found", style: TextStyle(color: Colors.grey, fontSize: 11)))
                                  : isMobile
                                      ? ListView.builder(
                                          itemCount: filteredRows.length,
                                          padding: const EdgeInsets.all(12),
                                          itemBuilder: (context, index) {
                                            final row = filteredRows[index];
                                            final status = row["status"];
                                            Color statusColor = status == 'Completed' ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(14),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text('${index + 1}. ${row["client"]}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                                          child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text("Deliverable: ${row["task"]}", style: const TextStyle(fontSize: 11, color: Color(0xFF0052CC), fontWeight: FontWeight.w600)),
                                                    const SizedBox(height: 4),
                                                    Text("Maintenance Date: ${row["maintenanceDate"]}", style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                                    Text("Submit Date: ${row["formattedDate"]}", style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                                    const SizedBox(height: 10),
                                                    Align(
                                                      alignment: Alignment.centerRight,
                                                      child: OutlinedButton(
                                                        onPressed: () => _navigateToTaskDetailView(row["client"]),
                                                        style: OutlinedButton.styleFrom(
                                                          side: const BorderSide(color: Color(0xFF0052CC)),
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        ),
                                                        child: const Text("View Details", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
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
                                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                          itemBuilder: (context, index) {
                                            final row = filteredRows[index];
                                            final status = row["status"];
                                            
                                            Color statusColor = Colors.blue;
                                            if (status == 'Completed') statusColor = const Color(0xFF16A34A);
                                            if (status == 'Pending') statusColor = const Color(0xFFDC2626);

                                            return Container(
                                              height: 60,
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              child: Row(
                                                children: [
                                                  SizedBox(width: 60, child: Text('${index + 1}.', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                                  Expanded(flex: 3, child: Text(row["client"], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                                                  Expanded(flex: 2, child: Text(row["maintenanceDate"], style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                                                  Expanded(flex: 2, child: Text(row["task"], style: const TextStyle(fontSize: 11, color: Color(0xFF0052CC), fontWeight: FontWeight.w600))),
                                                  Expanded(flex: 2, child: Text(row["formattedDate"], style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: IconButton(
                                                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF0052CC)),
                                                        onPressed: () => _navigateToTaskDetailView(row["client"]),
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