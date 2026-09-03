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

  String selectedViewMode = 'client';

  List<Map<String, dynamic>> masterEmployeeData = [];
  List<Map<String, dynamic>> masterEmployeeSummaryData = [];
  List<Map<String, dynamic>> rawTasksList = [];

  // Sorting and Filters State
  bool isSNoAscending = true;
  bool isClientAscending = true;
  bool isEmployeeAscending = true;
  bool isTotalClientsAscending = true;

  String? selectedMaintenanceSort; 
  String selectedMonthFilter = "All"; 
  String selectedSubmitDateFilter = "All"; 
  String selectedStatusFilter = "Processing"; 
  String searchQuery = ""; 

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
        
        final mappedRows = rows.map((row) => _mapRow(row)).toList();

        setState(() {
          masterEmployeeData = mappedRows;
          _loading = false;
        });

        _fetchEmployeeSummaryList();
      } else {
        setState(() { _error = 'Failed to load (${r.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loading = false; });
    }
  }

  Future<void> _fetchEmployeeSummaryList() async {
    try {
      final tasksRes = await http.get(Uri.parse('$_baseUrl/tasks'));
      final empRes = await http.get(Uri.parse('$_baseUrl/employees'));

      if (tasksRes.statusCode == 200 && empRes.statusCode == 200) {
        final tasksBody = jsonDecode(tasksRes.body);
        final empBody = jsonDecode(empRes.body);

        final tasks = List<Map<String, dynamic>>.from(tasksBody['data'] ?? []);
        final employees = List<Map<String, dynamic>>.from(empBody['data'] ?? []);

        rawTasksList = tasks;

        Map<String, Set<String>> empClients = {};

        for (var t in tasks) {
          final client = (t['client_name'] ?? '').toString().trim();
          if (client.isEmpty) continue;

          final roles = [
            t['ads_handling'], t['page_handling'], t['designer'],
            t['videographer'], t['video_editor'], t['ui_ux_designer'],
            t['developer'], t['website_designer']
          ];

          for (var emp in roles) {
            if (emp != null && emp.toString().trim().isNotEmpty && emp.toString().toUpperCase() != 'NONE') {
              final empName = emp.toString().trim().toUpperCase();
              empClients.putIfAbsent(empName, () => {}).add(client);
            }
          }
        }

        List<Map<String, dynamic>> summaryList = [];
        int index = 1;
        for (var e in employees) {
          final name = (e['full_name'] ?? '').toString().trim().toUpperCase();
          if (name.isEmpty) continue;

          final clientsAssigned = empClients[name] ?? {};
          summaryList.add({
            "sNo": index++,
            "employeeName": name,
            "totalClients": clientsAssigned.length,
            "clientsList": clientsAssigned.toList(),
          });
        }

        if (mounted) {
          setState(() {
            masterEmployeeSummaryData = summaryList;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching employee summary list: $e');
    }
  }

  Map<String, dynamic> _mapRow(dynamic row) {
    String status = row['status'] ?? 'Processing';
    if (status.toLowerCase() == 'in progress' || status.toLowerCase() == 'processing') {
      status = 'Processing';
    }
    return {
      "taskListId": row['taskListId'],
      "client": row['clientName'] ?? '',
      "maintenanceDate": _formatOnlyDay(row['maintenanceDate']),
      "task": row['task'] ?? '',
      "package": row['packageName'] ?? row['task'] ?? 'Standard Package',
      "date": row['submissionDate'] ?? '',
      "formattedDate": _formatDate(row['submissionDate'] as String?),
      "month": _extractMonth(row['submissionDate'] as String?),
      "status": status,
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

 // 🟢 Fixed Employee Detail View to fetch tracking progress securely by matching task list assignment & deliverables
  void _navigateToEmployeeDetailView(String employeeName) async {
    List<Map<String, dynamic>> employeeAssignments = [];
    Map<String, int> dbTaskProgressCounts = {};

    try {
      final Map<String, Map<String, dynamic>> latestClientAssignmentsMap = {};

      for (var row in rawTasksList) {
        bool matches = false;
        final roles = [
          row['ads_handling'], row['page_handling'], row['designer'],
          row['videographer'], row['video_editor'], row['ui_ux_designer'],
          row['developer'], row['website_designer']
        ];
        for (var emp in roles) {
          if (emp != null && emp.toString().trim().toUpperCase() == employeeName.toUpperCase()) {
            matches = true;
            break;
          }
        }

        if (matches) {
          final clientName = (row['client_name'] ?? '').toString().trim().toLowerCase();
          final rowId = row['id'] is int ? row['id'] : int.tryParse(row['id'].toString()) ?? 0;

          if (!latestClientAssignmentsMap.containsKey(clientName) || 
              rowId > (latestClientAssignmentsMap[clientName]!['id'] is int ? latestClientAssignmentsMap[clientName]!['id'] : 0)) {
            latestClientAssignmentsMap[clientName] = row;
          }
        }
      }

      employeeAssignments = latestClientAssignmentsMap.values.toList();

      for (var assignment in employeeAssignments) {
        final clientName = assignment['client_name'] ?? '';
        final assignmentId = assignment['id'];
        if (clientName.isEmpty) continue;

        // 🟢 Fetch task lists specifically matching this task_assignment_id
        final trRes = await http.get(Uri.parse('$_baseUrl/task-list/client/${Uri.encodeComponent(clientName)}'));
        if (trRes.statusCode == 200) {
          final trBody = jsonDecode(trRes.body);
          final taskLists = List<dynamic>.from(trBody['data'] ?? []);

          for (var tl in taskLists) {
            // Match exact task_assignment_id to avoid cross-cycle count mismatch
            if (tl['task_assignment_id'] != null && tl['task_assignment_id'].toString() != assignmentId.toString()) {
              continue;
            }

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
      }
    } catch (e) {
      debugPrint('Error fetching employee task details: $e');
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
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
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
                        child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0052CC), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Employee Task Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            const SizedBox(height: 3),
                            Text(employeeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
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
                  child: employeeAssignments.isEmpty
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
                                const Text('No assigned clients found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(18),
                          itemCount: employeeAssignments.length,
                          itemBuilder: (context, index) {
                            final assignment = employeeAssignments[index];
                            final clientName = assignment['client_name'] ?? 'Unknown Client';
                            final packageTitle = assignment['deliverables'] ?? 'Standard Package';
                            final submitDateStr = _formatDate(assignment['deadline'] ?? assignment['created_at']?.toString());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(clientName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 4),
                                  Text('Package / Deliverables: $packageTitle', style: const TextStyle(fontSize: 11.5, color: Color(0xFF0052CC), fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text('Submit Date: $submitDateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 10),

                                  ...roleMappings.map((roleInfo) {
                                    final roleLabel = roleInfo['roleLabel'] as String;
                                    final icon = roleInfo['icon'] as IconData;
                                    final empField = roleInfo['empField'] as String;
                                    final taskField = roleInfo['taskField'] as String;

                                    List<String> employeeTasksForRole = [];
                                    final empVal = (assignment[empField] ?? '').toString().trim();
                                    if (empVal.toUpperCase() == employeeName.toUpperCase()) {
                                      final taskStr = (assignment[taskField] ?? '').toString().trim();
                                      if (taskStr.isNotEmpty) {
                                        final tList = taskStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
                                        employeeTasksForRole.addAll(tList);
                                      }
                                    }

                                    if (employeeTasksForRole.isEmpty) return const SizedBox.shrink();

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(icon, size: 15, color: const Color(0xFF004AAD)),
                                              const SizedBox(width: 6),
                                              Text(roleLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: employeeTasksForRole.map((tClean) {
                                              final match = RegExp(r'^(.*?)\s*\((\d+)\)$').firstMatch(tClean.trim());
                                              final tName = match != null ? match.group(1)!.trim() : tClean;
                                              final totalR = match != null ? int.parse(match.group(2)!) : 1;

                                              int compR = dbTaskProgressCounts[tName.toLowerCase()] ?? 0;
                                              final isCompleted = compR > 0;
                                              final progressText = 'Total Complete: $compR / Total Task: $totalR';

                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: isCompleted ? const Color(0xFFF0FDF4) : Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                                                    width: isCompleted ? 1.2 : 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                                      size: 13,
                                                      color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      tName,
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: isCompleted ? const Color(0xFF166534) : const Color(0xFF334155),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      child: Text(
                                                        progressText,
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w800,
                                                          color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF475569),
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
                          },
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
  
  void _navigateToTaskDetailViewForSpecificRow(String clientName, Map<String, dynamic> targetRow) async {
    List<Map<String, dynamic>> clientAssignments = [];
    Map<String, int> dbTaskProgressCounts = {};

    try {
      clientAssignments = rawTasksList.where((row) {
        final cName = (row['client_name'] ?? '').toString().trim().toLowerCase();
        return cName == clientName.toLowerCase();
      }).toList();

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
      debugPrint('Error fetching specific row client details: $e');
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
                            Text('$clientName (Submit Date: ${targetRow["formattedDate"]})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
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
                                                  final isCompleted = compR > 0;
                                                  final progressText = 'Total Complete: $compR / Total Task: $totalR';

                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(9),
                                                      border: Border.all(
                                                        color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                                        width: isCompleted ? 1.2 : 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                                          size: 14,
                                                          color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          tName,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: isCompleted ? const Color(0xFF166534) : const Color(0xFF475569),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            progressText,
                                                            style: TextStyle(
                                                              fontSize: 9.5,
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
      bool clientMatch = searchQuery.isEmpty ||
          row["client"].toString().toLowerCase().contains(searchQuery.toLowerCase());

      bool packageMatch = selectedMonthFilter == "All" ||
          row["package"] == selectedMonthFilter || row["task"] == selectedMonthFilter;

      bool submitDateMatch = selectedSubmitDateFilter == "All" ||
          row["month"] == selectedSubmitDateFilter;

      bool statusMatch = selectedStatusFilter == "All" ||
          row["status"] == selectedStatusFilter ||
          (selectedStatusFilter == "Processing" && (row["status"] == "Processing" || row["status"] == "In Progress"));

      return clientMatch && packageMatch && submitDateMatch && statusMatch;
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

    List<Map<String, dynamic>> filteredEmployeeRows = masterEmployeeSummaryData.where((row) {
      bool nameMatch = searchQuery.isEmpty ||
          row["employeeName"].toString().toLowerCase().contains(searchQuery.toLowerCase());
      return nameMatch;
    }).toList();

    filteredEmployeeRows.sort((a, b) {
      if (!isEmployeeAscending) {
        return b["employeeName"].toString().compareTo(a["employeeName"].toString());
      }
      if (!isTotalClientsAscending) {
        return (b["totalClients"] as int).compareTo(a["totalClients"] as int);
      }
      return a["employeeName"].toString().compareTo(b["employeeName"].toString());
    });

    if (!isSNoAscending) {
      filteredEmployeeRows = filteredEmployeeRows.reversed.toList();
    }

    return AdminLayout(
      pageTitle: "Employee Status",
      currentRoute: "/employee-status",
      onSearch: (query) => setState(() => searchQuery = query),
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
                                  fontSize: isMobile ? 20 : 51,
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
                    
                    // Split Client & Employee View Switcher Buttons
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => selectedViewMode = 'client'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedViewMode == 'client' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Client View',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: selectedViewMode == 'client' ? const Color(0xFF0052CC) : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => selectedViewMode = 'employee'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedViewMode == 'employee' ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Employee View',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: selectedViewMode == 'employee' ? const Color(0xFF0052CC) : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // DATA TABLE CONTAINER
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
                    if (!isMobile && selectedViewMode == 'client')
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
                            // Maintenance Header Filter
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
                            // Packages Header
                            const Expanded(
                              flex: 2,
                              child: Text("PACKAGES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.7)),
                            ),
                            // Submit Date Column with separate Month Filter Dropdown
                            Expanded(
                              flex: 2,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedSubmitDateFilter,
                                  isDense: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0052CC)),
                                  items: const [
                                    DropdownMenuItem(value: "All", child: Text("SUBMIT DATE: ALL ▾", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
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
                                  onChanged: (val) => setState(() => selectedSubmitDateFilter = val ?? "All"),
                                ),
                              ),
                            ),
                            // Status Filter
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
                                    DropdownMenuItem(value: "Processing", child: Text("PROCESSING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)))),
                                  ],
                                  onChanged: (val) => setState(() => selectedStatusFilter = val ?? "All"),
                                ),
                              ),
                            ),
                            const Expanded(flex: 1, child: Text("VIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.7), textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                    
                    if (!isMobile && selectedViewMode == 'employee')
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
                                    const Text("S.NO", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
                                    const SizedBox(width: 2),
                                    Icon(isSNoAscending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 18, color: const Color(0xFF0052CC)),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: InkWell(
                                onTap: () => setState(() => isEmployeeAscending = !isEmployeeAscending),
                                child: Row(
                                  children: [
                                    const Text("EMPLOYEE NAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
                                    const SizedBox(width: 2),
                                    Icon(isEmployeeAscending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 18, color: const Color(0xFF0052CC)),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () => setState(() => isTotalClientsAscending = !isTotalClientsAscending),
                                child: Row(
                                  children: [
                                    const Text("TOTAL CLIENTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
                                    const SizedBox(width: 2),
                                    Icon(isTotalClientsAscending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 18, color: const Color(0xFF0052CC)),
                                  ],
                                ),
                              ),
                            ),
                            const Expanded(flex: 1, child: Text("VIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
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
                              : selectedViewMode == 'client' && filteredRows.isEmpty || selectedViewMode == 'employee' && filteredEmployeeRows.isEmpty
                                  ? const Center(child: Text("No records found", style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)))
                                  : selectedViewMode == 'employee'
                                      ? ListView.separated(
                                          itemCount: filteredEmployeeRows.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                          itemBuilder: (context, index) {
                                            final empRow = filteredEmployeeRows[index];
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
                                                    flex: 4,
                                                    child: Text(
                                                      empRow["employeeName"],
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      '${empRow["totalClients"]} Clients',
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF0052CC), fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: InkWell(
                                                        onTap: () => _navigateToEmployeeDetailView(empRow["employeeName"]),
                                                        borderRadius: BorderRadius.circular(10),
                                                        child: Container(
                                                          width: 36,
                                                          height: 34,
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF0052CC),
                                                            borderRadius: BorderRadius.circular(10),
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
                                            if (status == 'Processing') statusColor = const Color(0xFF0284C7);

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
                                                      row["package"],
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
                                                  Expanded(
                                                    flex: 1,
                                                    child: Center(
                                                      child: InkWell(
                                                        onTap: () => _navigateToTaskDetailViewForSpecificRow(row["client"], row),
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