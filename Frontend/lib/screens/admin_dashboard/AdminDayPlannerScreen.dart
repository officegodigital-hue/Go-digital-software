import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class AdminDayPlannerScreen extends StatefulWidget {
  const AdminDayPlannerScreen({super.key});

  @override
  State<AdminDayPlannerScreen> createState() => _AdminDayPlannerScreenState();
}

class _AdminDayPlannerScreenState extends State<AdminDayPlannerScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  static const Color _primary = Color(0xFF0052CC);
  static const Color _primaryDark = Color(0xFF003B95);
  static const Color _primaryLight = Color(0xFFEAF2FF);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF7F9FC);

  final ScrollController _horizontalController = ScrollController();

  DateTime selectedDate = DateTime.now();
  String dateFilterMode = 'Today';
  
  String searchQuery = '';
  String? selectedRoleFilter;
  String? selectedStatusFilter;
  bool isAscendingOrder = true;

  String? selectedEmployee;
  List<Map<String, dynamic>> employeesList = [];
  List<Map<String, dynamic>> submissionStatusList = [];
  List<Map<String, dynamic>> dayPlanRows = [];
  bool isLoading = false;
  late IO.Socket socket;

  bool _hasColumn(List<Map<String, dynamic>> rows, String field) {
    return rows.any((r) {
      final value = (r[field] ?? '').toString().trim();
      return value.isNotEmpty && value != '-';
    });
  }

  @override
  void initState() {
    super.initState();
    _loadEmployeesAndSubmissions();
    _initSocketListener();
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
        _loadEmployeesAndSubmissions();
        if (selectedEmployee != null) {
          _fetchEmployeeDayPlan(selectedEmployee!);
        }
      }
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    socket.dispose();
    super.dispose();
  }

  Future<void> _loadEmployeesAndSubmissions() async {
    setState(() => isLoading = true);
    String formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    try {
      final subRes = await http.get(
        Uri.parse('$_baseUrl/day-planner/submissions?date=$formattedDate'),
      );

      if (subRes.statusCode == 200) {
        final subBody = jsonDecode(subRes.body);
        setState(() {
          employeesList = List<Map<String, dynamic>>.from(subBody['employees'] ?? []);
          submissionStatusList = List<Map<String, dynamic>>.from(subBody['submissions'] ?? []);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading submissions: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchEmployeeDayPlan(String empName) async {
    setState(() => isLoading = true);
    
    try {
      String url = '';
      if (dateFilterMode == 'Today') {
        String formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
        url = '$_baseUrl/day-planner/today/${Uri.encodeComponent(empName)}?date=$formattedDate';
      } else {
        String formattedMonth = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}";
        url = '$_baseUrl/day-planner/month-history/${Uri.encodeComponent(empName)}?month=$formattedMonth';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded is List ? decoded : (decoded['data'] ?? []);

        setState(() {
          selectedEmployee = empName;
          dayPlanRows = data.map((item) => {
            'id': item['id'],
            'date': item['plan_date_str'] ?? item['date'] ?? '',
            'client': item['client_name'] ?? item['client'] ?? '',
            'maintenance_date': item['maintenance_date'] ?? '',
            'ads': item['ads'] ?? '',
            'today_leads': item['today_leads'] ?? '',
            'today_report': item['today_report'] ?? '',
            'deliverables_1': item['deliverables_1'] ?? '',
            'complete_deliverables_1': item['complete_deliverables_1'] ?? '',
            'balanced_deliverables_1': item['balanced_deliverables_1'] ?? '',
            'deliverables_2': item['deliverables_2'] ?? '',
            'complete_deliverables_2': item['complete_deliverables_2'] ?? '',
            'balanced_deliverables_2': item['balanced_deliverables_2'] ?? '',
            'deliverables_3': item['deliverables_3'] ?? '',
            'complete_deliverables_3': item['complete_deliverables_3'] ?? '',
            'balanced_deliverables_3': item['balanced_deliverables_3'] ?? '',
            'today_plan': item['today_plan'] ?? '',
            'status': item['status'] ?? '',
            'remarks': item['remarks'] ?? '',
            'total_working_secs': item['total_working_secs'] ?? 0,
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching employee plan: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendNotificationToEmployee(String empName) async {
    final authService = context.read<AuthService>();
    final senderName = authService.user?['fullName'] as String? ?? 'Admin';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderName': senderName,
          'recipientName': empName,
          'message': jsonEncode({
            'preview': '$senderName sent you a reminder to submit your Day Planner.',
            'payload': {
              'type': 'DAY_PLANNER_REMINDER',
              'sender': senderName,
              'recipient': empName,
              'content': 'Please submit your Day Planner for today.'
            }
          }),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _showSnack('✅ Reminder notification sent to $empName successfully!', success: true);
      } else {
        if (!mounted) return;
        _showSnack('❌ Failed to send notification. Try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('❌ Error: $e');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        backgroundColor: success ? const Color(0xFF0F9D73) : const Color(0xFFDC2626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatWorkingTime(dynamic totalSecs) {
    int secs = int.tryParse(totalSecs.toString()) ?? 0;
    if (secs <= 0) return "00h 00m";
    int hours = secs ~/ 3600;
    int minutes = (secs % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: "Day Planner Monitoring",
      currentRoute: "/daily-planner",
      onSearch: (query) {
        setState(() {
          searchQuery = query;
        });
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(MediaQuery.of(context).size.width < 720),
            const SizedBox(height: 20),
            if (selectedEmployee == null) ...[
              _buildStats(MediaQuery.of(context).size.width < 720),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isMobile = constraints.maxWidth < 720;
                  return SizedBox(
                    height: 580,
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: _primary))
                        : (isMobile ? _buildEmployeeMobileCardList() : _buildEmployeeStatusTable()),
                  );
                },
              ),
            ] else ...[
              _buildSelectedEmployeeHeader(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isMobile = constraints.maxWidth < 760;
                  return SizedBox(
                    height: 600,
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: _primary))
                        : (isMobile ? _buildMobilePlannerCardList(dayPlanRows) : _buildGroupedSheetGrids(dayPlanRows)),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, Color(0xFF1267E8)],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
        boxShadow: [
          BoxShadow(color: _primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
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
                width: isMobile ? 46 : 56,
                height: isMobile ? 46 : 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                ),
                child: Icon(Icons.calendar_month_rounded, size: isMobile ? 24 : 28, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day Planner Command Center',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time tracking of team daily logs, status, working hours and reporting.',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                      _loadEmployeesAndSubmissions();
                      if (selectedEmployee != null) {
                        _fetchEmployeeDayPlan(selectedEmployee!);
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      dateFilterMode = dateFilterMode == 'Today' ? 'This Month' : 'Today';
                    });
                    if (selectedEmployee != null) {
                      _fetchEmployeeDayPlan(selectedEmployee!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      dateFilterMode,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(bool isMobile) {
    int totalCount = employeesList.length;
    int submittedCount = employeesList.where((emp) {
      final name = (emp['fullName'] ?? '').toString();
      return submissionStatusList.any((s) => (s['employeeName'] ?? '').toString().toLowerCase() == name.toLowerCase() && s['submitted'] == true);
    }).length;
    int pendingCount = totalCount - submittedCount;

    final stats = [
      {'label': 'Total Workforce', 'value': '$totalCount', 'icon': Icons.groups_rounded, 'color': _primary},
      {'label': 'Completed Submissions', 'value': '$submittedCount', 'icon': Icons.verified_user_rounded, 'color': const Color(0xFF10B981)},
      {'label': 'Pending Submissions', 'value': '$pendingCount', 'icon': Icons.pending_actions_rounded, 'color': const Color(0xFFDC2626)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 2.8 : 2.4,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        final color = stat['color'] as Color;

        return Container(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 38 : 46,
                height: isMobile ? 38 : 46,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)),
                child: Icon(stat['icon'] as IconData, color: color, size: isMobile ? 20 : 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat['value'] as String, style: TextStyle(fontSize: isMobile ? 19 : 24, fontWeight: FontWeight.w900, color: _ink)),
                    const SizedBox(height: 2),
                    Text(stat['label'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isMobile ? 10 : 11, color: _muted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

 Widget _buildEmployeeStatusTable() {
    final List<String> availableRoles = employeesList.map((emp) => (emp['role'] ?? 'Staff').toString()).toSet().toList()..sort();
    final filteredEmployees = employeesList.where((emp) {
      final name = (emp['fullName'] ?? '').toString();
      final role = (emp['role'] ?? 'Staff').toString();
      final matchesSearch = name.toLowerCase().contains(searchQuery.toLowerCase());
      final bool hasSubmitted = submissionStatusList.any((s) => (s['employeeName'] ?? '').toString().toLowerCase() == name.toLowerCase() && s['submitted'] == true);

      bool matchesRole = (selectedRoleFilter == null || selectedRoleFilter == 'All Roles' || role == selectedRoleFilter);
      bool matchesStatus = true;
      if (selectedStatusFilter == 'Submitted') matchesStatus = hasSubmitted;
      if (selectedStatusFilter == 'Pending') matchesStatus = !hasSubmitted;

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    filteredEmployees.sort((a, b) {
      final nameA = (a['fullName'] ?? '').toString().toLowerCase();
      final nameB = (b['fullName'] ?? '').toString().toLowerCase();
      return isAscendingOrder ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(color: _surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () => setState(() => isAscendingOrder = !isAscendingOrder),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("EMPLOYEE NAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.7)),
                        const SizedBox(width: 4),
                        Icon(isAscendingOrder ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 18, color: _primary),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: PopupMenuButton<String>(
                    initialValue: selectedRoleFilter ?? 'All Roles',
                    onSelected: (val) => setState(() => selectedRoleFilter = val == 'All Roles' ? null : val),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'All Roles', child: Text('All Roles', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      ...availableRoles.map((r) => PopupMenuItem(value: r, child: Text(r, style: TextStyle(fontSize: 12)))),
                    ],
                    child: Text(selectedRoleFilter ?? "ROLE ▾", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: selectedRoleFilter != null ? _primary : _muted, letterSpacing: 0.7)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: PopupMenuButton<String>(
                    initialValue: selectedStatusFilter ?? 'All Status',
                    onSelected: (val) => setState(() => selectedStatusFilter = val == 'All Status' ? null : val),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'All Status', child: Text('All Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      const PopupMenuItem(value: 'Submitted', child: Text('Submitted', style: TextStyle(fontSize: 12, color: Color(0xFF10B981)))),
                      const PopupMenuItem(value: 'Pending', child: Text('Pending', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                    ],
                    child: Text(selectedStatusFilter ?? "STATUS ▾", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: selectedStatusFilter != null ? _primary : _muted, letterSpacing: 0.7)),
                  ),
                ),
                // 🟢 WORKING HOURS Column Header added right after STATUS
                const Expanded(
                  flex: 2,
                  child: Text("WORKING HOURS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.7)),
                ),
                const Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text("ACTIONS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _muted, letterSpacing: 0.7)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: filteredEmployees.isEmpty
                ? const Center(child: Text("No employees found matching filter criteria.", style: TextStyle(color: _muted, fontWeight: FontWeight.w600)))
                : ListView.separated(
                    itemCount: filteredEmployees.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
                    itemBuilder: (context, index) {
                      final emp = filteredEmployees[index];
                      final empName = emp['fullName'] ?? 'Employee';
                      final empRole = emp['role'] ?? 'Staff';
                      
                      // Find matching submission record to check status and working hours
                      final submission = submissionStatusList.firstWhere(
                        (s) => (s['employeeName'] ?? '').toString().toLowerCase() == empName.toLowerCase(),
                        orElse: () => {},
                      );
                      final bool hasSubmitted = submission['submitted'] == true;
                      final workingSecs = submission['total_working_secs'] ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        color: index.isEven ? Colors.white : const Color(0xFFFBFCFE),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [_primary, Color(0xFF2879EE)]), shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: Text(_getInitials(empName), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(empName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _ink), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            Expanded(flex: 2, child: Text(empRole, style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600))),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: hasSubmitted ? const Color(0xFF10B981) : const Color(0xFFDC2626), shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text(hasSubmitted ? 'Submitted' : 'Pending', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: hasSubmitted ? const Color(0xFF10B981) : const Color(0xFFDC2626))),
                                ],
                              ),
                            ),
                            // 🟢 Working Hours Data Cell: Shows hours if submitted, else blank/dash
                            Expanded(
                              flex: 2,
                              child: hasSubmitted
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: _primaryLight, borderRadius: BorderRadius.circular(6)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 12, color: _primary),
                                          const SizedBox(width: 4),
                                          Text(_formatWorkingTime(workingSecs), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _primaryDark)),
                                        ],
                                      ),
                                    )
                                  : const Text('—', style: TextStyle(color: _muted, fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!hasSubmitted) ...[
                                    ElevatedButton.icon(
                                      onPressed: () => _sendNotificationToEmployee(empName),
                                      icon: const Icon(Icons.notifications_active_rounded, size: 13, color: Colors.white),
                                      label: const Text("Notify", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  ElevatedButton(
                                    onPressed: () => _fetchEmployeeDayPlan(empName),
                                    style: ElevatedButton.styleFrom(backgroundColor: _primaryLight, foregroundColor: _primary, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    child: const Text("View Planner", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                  ),
                                ],
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
    );
  }

  Widget _buildEmployeeMobileCardList() {
    final List<String> availableRoles = employeesList.map((emp) => (emp['role'] ?? 'Staff').toString()).toSet().toList()..sort();
    final filteredEmployees = employeesList.where((emp) {
      final name = (emp['fullName'] ?? '').toString();
      final role = (emp['role'] ?? 'Staff').toString();
      final matchesSearch = name.toLowerCase().contains(searchQuery.toLowerCase());
      final bool hasSubmitted = submissionStatusList.any((s) => (s['employeeName'] ?? '').toString().toLowerCase() == name.toLowerCase() && s['submitted'] == true);

      bool matchesRole = (selectedRoleFilter == null || selectedRoleFilter == 'All Roles' || role == selectedRoleFilter);
      bool matchesStatus = true;
      if (selectedStatusFilter == 'Submitted') matchesStatus = hasSubmitted;
      if (selectedStatusFilter == 'Pending') matchesStatus = !hasSubmitted;

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(color: _surface, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PopupMenuButton<String>(
                  initialValue: selectedRoleFilter ?? 'All Roles',
                  onSelected: (val) => setState(() => selectedRoleFilter = val == 'All Roles' ? null : val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'All Roles', child: Text('All Roles', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    ...availableRoles.map((r) => PopupMenuItem(value: r, child: Text(r, style: TextStyle(fontSize: 12)))),
                  ],
                  child: Chip(label: Text(selectedRoleFilter ?? 'Role ▾', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), backgroundColor: Colors.white),
                ),
                PopupMenuButton<String>(
                  initialValue: selectedStatusFilter ?? 'All Status',
                  onSelected: (val) => setState(() => selectedStatusFilter = val == 'All Status' ? null : val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'All Status', child: Text('All Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const PopupMenuItem(value: 'Submitted', child: Text('Submitted', style: TextStyle(fontSize: 12, color: Color(0xFF10B981)))),
                    const PopupMenuItem(value: 'Pending', child: Text('Pending', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                  ],
                  child: Chip(label: Text(selectedStatusFilter ?? 'Status ▾', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), backgroundColor: Colors.white),
                ),
                IconButton(icon: Icon(isAscendingOrder ? Icons.arrow_upward : Icons.arrow_downward, size: 18), onPressed: () => setState(() => isAscendingOrder = !isAscendingOrder)),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: filteredEmployees.isEmpty
                ? const Center(child: Text("No employees found.", style: TextStyle(color: _muted)))
                : ListView.builder(
                    itemCount: filteredEmployees.length,
                    padding: const EdgeInsets.all(10),
                    itemBuilder: (context, index) {
                      final emp = filteredEmployees[index];
                      final empName = emp['fullName'] ?? 'Employee';
                      final empRole = emp['role'] ?? 'Staff';
                      final bool hasSubmitted = submissionStatusList.any((s) => (s['employeeName'] ?? '').toString().toLowerCase() == empName.toLowerCase() && s['submitted'] == true);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _primaryLight,
                                  child: Text(_getInitials(empName), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _primary)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(empName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _ink)),
                                      const SizedBox(height: 2),
                                      Text(empRole, style: const TextStyle(fontSize: 11, color: _muted)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: hasSubmitted ? const Color(0xFF10B981) : const Color(0xFFDC2626), shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text(hasSubmitted ? 'Submitted' : 'Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: hasSubmitted ? const Color(0xFF10B981) : const Color(0xFFDC2626))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: _border),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!hasSubmitted) ...[
                                  ElevatedButton.icon(
                                    onPressed: () => _sendNotificationToEmployee(empName),
                                    icon: const Icon(Icons.notifications_active_rounded, size: 12, color: Colors.white),
                                    label: const Text("Notify", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                ElevatedButton(
                                  onPressed: () => _fetchEmployeeDayPlan(empName),
                                  style: ElevatedButton.styleFrom(backgroundColor: _primaryLight, foregroundColor: _primary, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  child: const Text("View Planner", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedEmployeeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_outline_rounded, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Employee Planner: $selectedEmployee", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _ink)),
                  const SizedBox(height: 2),
                  Text("Viewing mode: $dateFilterMode", style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => setState(() => selectedEmployee = null),
            icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
            label: const Text('Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(backgroundColor: _primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), elevation: 0),
          ),
        ],
      ),
    );
  }

// 🟢 Enhanced Responsive Mobile Card List for Planner Entries
  Widget _buildMobilePlannerCardList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
        alignment: Alignment.center,
        child: Text('No day plan entries found ($dateFilterMode).', style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600)),
      );
    }

    return ListView.builder(
      itemCount: rows.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final row = rows[index];
        final clientName = row['client'] ?? '—';
        final maintDate = row['maintenance_date'] ?? '—';
        final ads = row['ads'] ?? '';
        final leads = row['today_leads'] ?? '';
        final report = row['today_report'] ?? '';
        final deliv1 = row['deliverables_1'] ?? '';
        final comp1 = row['complete_deliverables_1'] ?? '';
        final bal1 = row['balanced_deliverables_1'] ?? '';
        final plan = row['today_plan'] ?? '—';
        final remarks = row['remarks'] ?? '';
        final status = (row['status'] ?? 'PENDING').toUpperCase();
        final workingTime = _formatWorkingTime(row['total_working_secs']);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client Name & Status Header (Fixed wrapping with Flexible container)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge with fixed horizontal layout to prevent awkward text wrapping
                  _statusCell(status, 110),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),

              // Details Grid / Rows
              _mobileDetailRow(Icons.calendar_today_rounded, "Maintenance Date", maintDate),
              if (ads.isNotEmpty && ads != '-') ...[
                const SizedBox(height: 6),
                _mobileDetailRow(Icons.campaign_outlined, "Ads", ads),
              ],
              if (leads.isNotEmpty && leads != '-') ...[
                const SizedBox(height: 6),
                _mobileDetailRow(Icons.trending_up_rounded, "Today Leads", leads),
              ],
              if (report.isNotEmpty && report != '-') ...[
                const SizedBox(height: 6),
                _mobileDetailRow(Icons.assessment_outlined, "Today Report", report),
              ],
              if (deliv1.isNotEmpty && deliv1 != '-') ...[
                const SizedBox(height: 6),
                _mobileDetailRow(Icons.inventory_2_outlined, "Deliverables 1", "$deliv1 (Comp: $comp1 | Bal: $bal1)"),
              ],
              const SizedBox(height: 6),
              _mobileDetailRow(Icons.notes_rounded, "Today Plan", plan),
              if (remarks.isNotEmpty && remarks != '-') ...[
                const SizedBox(height: 6),
                _mobileDetailRow(Icons.comment_outlined, "Remarks", remarks),
              ],

              const SizedBox(height: 14),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),

              // Working Hours Tag at bottom
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Tracked Time:", style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: _primary),
                        const SizedBox(width: 6),
                        Text(
                          workingTime,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _primaryDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mobileDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _muted),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
  
  // Desktop Grouped Table with Working Hours Button placed after Status
  Widget _buildGroupedSheetGrids(List<Map<String, dynamic>> rows) {
    final hasAds = _hasColumn(rows, 'ads');
    final hasLeads = _hasColumn(rows, 'today_leads');
    final hasReport = _hasColumn(rows, 'today_report');
    final hasRemarks = _hasColumn(rows, 'remarks');

    // 🟢 Working Hours Column Width (150px) positioned after status
    double tableWidth = 140 +
        (hasAds ? 140 : 0) +
        (hasLeads ? 110 : 0) +
        (hasReport ? 110 : 0) +
        150 +
        150 +
        150 +
        180 +
        (hasRemarks ? 180 : 0) +
        130 +
        150; // Working Hours button column

    if (rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
        alignment: Alignment.center,
        child: Text('No day plan entries found for this employee ($dateFilterMode).', style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600)),
      );
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var r in rows) {
      String dStr = r['date']?.toString().split('T')[0] ?? 'Unknown Date';
      grouped.putIfAbsent(dStr, () => []).add(r);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView.builder(
          itemCount: sortedKeys.length,
          itemBuilder: (context, groupIndex) {
            String dateKey = sortedKeys[groupIndex];
            List<Map<String, dynamic>> dateRows = grouped[dateKey]!;
            
            String dayName = '';
            try {
              DateTime parsed = DateTime.parse(dateKey);
              const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
              dayName = ' (${days[parsed.weekday - 1]})';
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_primaryDark, _primary]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text('Date: $dateKey$dayName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text('Day Working Time: ${_formatWorkingTime(dateRows.isNotEmpty ? dateRows.first['total_working_secs'] : 0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(
                          width: 180,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 44,
                                color: const Color(0xFF1E293B),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.centerLeft,
                                child: const Text('CLIENT NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                              ),
                              ...dateRows.map((row) => _clientCell(row)),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1, color: _border),
                        Expanded(
                          child: Listener(
                            onPointerSignal: (pointerSignal) {
                              if (pointerSignal is PointerScrollEvent) {
                                final double delta = pointerSignal.scrollDelta.dy;
                                if (delta != 0 && _horizontalController.hasClients) {
                                  final newOffset = (_horizontalController.offset + delta).clamp(
                                    _horizontalController.position.minScrollExtent,
                                    _horizontalController.position.maxScrollExtent,
                                  );
                                  _horizontalController.jumpTo(newOffset);
                                }
                              }
                            },
                            child: Scrollbar(
                              controller: _horizontalController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: tableWidth,
                                      height: 44,
                                      child: Row(
                                        children: [
                                          const _HeaderCell(width: 140, label: 'MAINTENANCE DATE'),
                                          if (hasAds) const _HeaderCell(width: 140, label: 'ADS'),
                                          if (hasLeads) const _HeaderCell(width: 110, label: 'TODAY LEADS'),
                                          if (hasReport) const _HeaderCell(width: 110, label: 'TODAY REPORT'),
                                          const _HeaderCell(width: 150, label: 'DELIVERABLES 1'),
                                          const _HeaderCell(width: 150, label: 'COMPLETE 1'),
                                          const _HeaderCell(width: 150, label: 'BALANCED 1'),
                                          const _HeaderCell(width: 180, label: 'TODAY PLAN'),
                                          if (hasRemarks) const _HeaderCell(width: 180, label: 'REMARKS'),
                                          const _HeaderCell(width: 130, label: 'STATUS'),
                                          // 🟢 Working Hours Button Header placed right after STATUS
                                          const _HeaderCell(width: 150, label: 'WORKING HOURS'),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: _border),
                                    ...dateRows.map(
                                      (row) => SizedBox(
                                        width: tableWidth,
                                        child: _buildDataRow(row, hasAds, hasLeads, hasReport, hasRemarks),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _clientCell(Map<String, dynamic> row) {
    final current = (row['client'] ?? '').toString();
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(color: _surface, border: Border(bottom: BorderSide(color: _border))),
      alignment: Alignment.centerLeft,
      child: Text(
        current.isEmpty ? '—' : current,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _ink),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataRow(
    Map<String, dynamic> row,
    bool hasAds,
    bool hasLeads,
    bool hasReport,
    bool hasRemarks,
  ) {
    return Row(
      children: [
        _textCell(row, 'maintenance_date', 140),
        if (hasAds) _textCell(row, 'ads', 140),
        if (hasLeads) _textCell(row, 'today_leads', 110),
        if (hasReport) _textCell(row, 'today_report', 110),
        _textCell(row, 'deliverables_1', 150),
        _textCell(row, 'complete_deliverables_1', 150),
        _textCell(row, 'balanced_deliverables_1', 150),
        _textCell(row, 'today_plan', 180),
        if (hasRemarks) _textCell(row, 'remarks', 180),
        _statusCell(row['status'] ?? 'PENDING', 130),
        // 🟢 Working Hours Button cell rendered right after status column
        _workingHoursCell(row['total_working_secs'], 150),
      ],
    );
  }

  Widget _textCell(Map<String, dynamic> row, String field, double width) {
    final value = (row[field] ?? '').toString();
    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _border), bottom: BorderSide(color: _border))),
      alignment: Alignment.centerLeft,
      child: Text(
        value.isEmpty ? '—' : value,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: value.isEmpty ? const Color(0xFFCBD5E1) : _ink),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusCell(String status, double width) {
    Color bgColor;
    Color textColor;
    switch (status.toUpperCase()) {
      case 'COMPLETE':
        bgColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        break;
      case 'PENDING':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        break;
      case 'HOLD':
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        break;
      case 'PROCESSING':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF0284C7);
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = _muted;
    }

    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _border), bottom: BorderSide(color: _border))),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: textColor.withValues(alpha: 0.25))),
        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.3)),
      ),
    );
  }

  // 🟢 Working Hours Button Cell Component
  Widget _workingHoursCell(dynamic totalSecs, double width) {
    final formattedTime = _formatWorkingTime(totalSecs);
    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: _border), bottom: BorderSide(color: _border))),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _primaryLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_rounded, size: 13, color: _primary),
            const SizedBox(width: 5),
            Text(
              formattedTime,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _primaryDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final double width;
  final String label;
  const _HeaderCell({required this.width, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF475569), letterSpacing: 0.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}