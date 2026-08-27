import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:provider/provider.dart';
import '../../services/auth_service.dart'; // Unga project directory path-ku thakkatha maari match pannikonga

class AdminDayPlannerScreen extends StatefulWidget {
  const AdminDayPlannerScreen({super.key});

  @override
  State<AdminDayPlannerScreen> createState() => _AdminDayPlannerScreenState();
}

class _AdminDayPlannerScreenState extends State<AdminDayPlannerScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final ScrollController _horizontalController = ScrollController();

  DateTime selectedDate = DateTime.now();
  String dateFilterMode = 'Today'; // 'Today' or 'This Month'
  
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
      print("🔥 Admin Real-time update received: $data");
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
    // 🟢 Logged-in admin/user name-ai get panrom
    final authService = context.read<AuthService>();
    final senderName = authService.user?['fullName'] as String? ?? 'Admin';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/send'), // Note: backend-la route /send-irukkutha nu check pannikonga
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderName': senderName, // 🟢 Yaru click pandrangalo avuga name
          'recipientName': empName, // 🟢 Yaru name-ku send pandrangalo avuga name
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Reminder notification sent to $empName successfully!'), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to send notification. Try again.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(),
              const SizedBox(height: 24),
              if (selectedEmployee == null) ...[
                _buildSummaryCards(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 700;
                    return SizedBox(
                      height: 580,
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
                          : (isMobile ? _buildEmployeeMobileCardList() : _buildEmployeeStatusTable()),
                    );
                  },
                ),
              ] else ...[
                _buildSelectedEmployeeHeader(),
                const SizedBox(height: 16),
                SizedBox(
                  height: 580,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
                      : _buildGroupedSheetGrids(dayPlanRows),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 650;
          return Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day Planner Command Center', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  SizedBox(height: 4),
                  Text('Real-time tracking of team daily logs, status, and reporting.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              if (isMobile) const SizedBox(height: 14),
              Row(
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0052CC)),
                          const SizedBox(width: 8),
                          Text(
                            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF0052CC), Color(0xFF2A52BE)]),
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(10)),
                      ),
                      child: Text(
                        dateFilterMode,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards() {
    int totalCount = employeesList.length;
    int submittedCount = employeesList.where((emp) {
      final name = (emp['fullName'] ?? '').toString();
      return submissionStatusList.any((s) => (s['employeeName'] ?? '').toString().toLowerCase() == name.toLowerCase() && s['submitted'] == true);
    }).length;
    int pendingCount = totalCount - submittedCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 750;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : (constraints.maxWidth - 32) / 3,
              child: _summaryCard('Total Workforce', '$totalCount', Icons.group_outlined, const Color(0xFF0052CC)),
            ),
            SizedBox(
              width: isMobile ? double.infinity : (constraints.maxWidth - 32) / 3,
              child: _summaryCard('Completed Submissions', '$submittedCount', Icons.verified_outlined, const Color(0xFF16A34A)),
            ),
            SizedBox(
              width: isMobile ? double.infinity : (constraints.maxWidth - 32) / 3,
              child: _summaryCard('Pending Submissions', '$pendingCount', Icons.pending_actions_rounded, const Color(0xFFDC2626)),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeStatusTable() {
    final List<String> availableRoles = employeesList
        .map((emp) => (emp['role'] ?? 'Staff').toString())
        .toSet()
        .toList()
      ..sort();

    final filteredEmployees = employeesList.where((emp) {
      final name = (emp['fullName'] ?? '').toString();
      final role = (emp['role'] ?? 'Staff').toString();
      
      final matchesSearch = name.toLowerCase().contains(searchQuery.toLowerCase());
      
      final bool hasSubmitted = submissionStatusList.any(
        (s) => (s['employeeName'] ?? '').toString().toLowerCase() == name.toLowerCase() && s['submitted'] == true,
      );

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () => setState(() => isAscendingOrder = !isAscendingOrder),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("EMPLOYEE NAME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                        const SizedBox(width: 4),
                        Icon(isAscendingOrder ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 18, color: const Color(0xFF0052CC)),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedRoleFilter ?? "ROLE ▾",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selectedRoleFilter != null ? const Color(0xFF0052CC) : const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: PopupMenuButton<String>(
                    initialValue: selectedStatusFilter ?? 'All Status',
                    onSelected: (val) => setState(() => selectedStatusFilter = val == 'All Status' ? null : val),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'All Status', child: Text('All Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      const PopupMenuItem(value: 'Submitted', child: Text('Submitted', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A)))),
                      const PopupMenuItem(value: 'Pending', child: Text('Pending', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedStatusFilter ?? "STATUS ▾",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selectedStatusFilter != null ? const Color(0xFF0052CC) : const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text("ACTIONS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: filteredEmployees.isEmpty
                ? const Center(child: Text("No employees found matching filter criteria.", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)))
                : ListView.separated(
                    itemCount: filteredEmployees.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final emp = filteredEmployees[index];
                      final empName = emp['fullName'] ?? 'Employee';
                      final empRole = emp['role'] ?? 'Staff';
                      final bool hasSubmitted = submissionStatusList.any(
                        (s) => (s['employeeName'] ?? '').toString().toLowerCase() == empName.toLowerCase() && s['submitted'] == true,
                      );

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF0052CC).withValues(alpha: 0.1),
                                    child: Text(empName[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(empName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(empRole, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: hasSubmitted ? const Color(0xFF16A34A) : const Color(0xFFDC2626), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    hasSubmitted ? 'Submitted' : 'Pending',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hasSubmitted ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!hasSubmitted) ...[
                                    ElevatedButton.icon(
                                      onPressed: () => _sendNotificationToEmployee(empName),
                                      icon: const Icon(Icons.notifications_active_rounded, size: 12, color: Colors.white),
                                      label: const Text("Notify", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD97706),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 0,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  OutlinedButton(
                                    onPressed: () => _fetchEmployeeDayPlan(empName),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF0052CC)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    child: const Text("View Planner", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0052CC))),
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
    final List<String> availableRoles = employeesList
        .map((emp) => (emp['role'] ?? 'Staff').toString())
        .toSet()
        .toList()
      ..sort();

    final filteredEmployees = employeesList.where((emp) {
      final name = (emp['fullName'] ?? '').toString();
      final role = (emp['role'] ?? 'Staff').toString();
      final matchesSearch = name.toLowerCase().contains(searchQuery.toLowerCase());
      
      final bool hasSubmitted = submissionStatusList.any(
        (s) => (s['employeeName'] ?? '').toString().toLowerCase() == name.toLowerCase() && s['submitted'] == true,
      );

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
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
                  child: Chip(
                    label: Text(selectedRoleFilter ?? 'Role ▾', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.white,
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: selectedStatusFilter ?? 'All Status',
                  onSelected: (val) => setState(() => selectedStatusFilter = val == 'All Status' ? null : val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'All Status', child: Text('All Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const PopupMenuItem(value: 'Submitted', child: Text('Submitted', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A)))),
                    const PopupMenuItem(value: 'Pending', child: Text('Pending', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                  ],
                  child: Chip(
                    label: Text(selectedStatusFilter ?? 'Status ▾', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.white,
                  ),
                ),
                IconButton(
                  icon: Icon(isAscendingOrder ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
                  onPressed: () => setState(() => isAscendingOrder = !isAscendingOrder),
                  tooltip: 'Sort A-Z / Z-A',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: filteredEmployees.isEmpty
                ? const Center(child: Text("No employees found.", style: TextStyle(color: Color(0xFF64748B))))
                : ListView.builder(
                    itemCount: filteredEmployees.length,
                    padding: const EdgeInsets.all(10),
                    itemBuilder: (context, index) {
                      final emp = filteredEmployees[index];
                      final empName = emp['fullName'] ?? 'Employee';
                      final empRole = emp['role'] ?? 'Staff';
                      final bool hasSubmitted = submissionStatusList.any(
                        (s) => (s['employeeName'] ?? '').toString().toLowerCase() == empName.toLowerCase() && s['submitted'] == true,
                      );

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
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF0052CC).withValues(alpha: 0.1),
                                    child: Text(empName[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0052CC))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                                        const SizedBox(height: 2),
                                        Text(empRole, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: hasSubmitted ? const Color(0xFF16A34A) : const Color(0xFFDC2626), shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        hasSubmitted ? 'Submitted' : 'Pending',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: hasSubmitted ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!hasSubmitted) ...[
                                    ElevatedButton.icon(
                                      onPressed: () => _sendNotificationToEmployee(empName),
                                      icon: const Icon(Icons.notifications_active_rounded, size: 12, color: Colors.white),
                                      label: const Text("Notify", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD97706),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        elevation: 0,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  OutlinedButton(
                                    onPressed: () => _fetchEmployeeDayPlan(empName),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF0052CC)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    child: const Text("View Planner", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0052CC))),
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
        ],
      ),
    );
  }

  Widget _buildSelectedEmployeeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 6),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 650;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: Color(0xFF0052CC), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Planner: $selectedEmployee",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    "Mode: $dateFilterMode",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => selectedEmployee = null),
                    icon: const Icon(Icons.arrow_back_rounded, size: 15, color: Colors.white),
                    label: const Text('Back to Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF0052CC).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0052CC), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Employee Planner: $selectedEmployee",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Viewing mode: $dateFilterMode",
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => selectedEmployee = null),
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                label: const Text('Back to Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0052CC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatWorkingTime(dynamic totalSecs) {
    int secs = int.tryParse(totalSecs.toString()) ?? 0;
    if (secs <= 0) return "00h 00m";
    int hours = secs ~/ 3600;
    int minutes = (secs % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  Widget _buildGroupedSheetGrids(List<Map<String, dynamic>> rows) {
    final hasAds = _hasColumn(rows, 'ads');
    final hasLeads = _hasColumn(rows, 'today_leads');
    final hasReport = _hasColumn(rows, 'today_report');
    final hasRemarks = _hasColumn(rows, 'remarks');

    double tableWidth = 140 +
        (hasAds ? 140 : 0) +
        (hasLeads ? 110 : 0) +
        (hasReport ? 110 : 0) +
        150 +
        150 +
        150 +
        180 +
        (hasRemarks ? 180 : 0) +
        130;

    if (rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        alignment: Alignment.center,
        child: Text('No day plan entries found for this employee ($dateFilterMode).', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
      );
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var r in rows) {
      String dStr = r['date']?.toString().split('T')[0] ?? 'Unknown Date';
      grouped.putIfAbsent(dStr, () => []).add(r);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
                      gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF60A5FA)),
                                const SizedBox(width: 8),
                                Text(
                                  'Date: $dateKey$dayName',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 6),
                                Text(
                                  'Working Time: ${_formatWorkingTime(dateRows.isNotEmpty ? dateRows.first['total_working_secs'] : 0)}',
                                  style: const TextStyle(color: Color(0xFFE0F2FE), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
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
                                color: const Color(0xFF0052CC),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.centerLeft,
                                child: const Text('CLIENT NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                              ),
                              ...dateRows.map((row) => _clientCell(row)),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
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
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
      decoration: const BoxDecoration(
        color: Color(0xFF0052CC),
        border: Border(bottom: BorderSide(color: Color(0xFF0044B3))),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        current.isEmpty ? '—' : current,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
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
      ],
    );
  }

  Widget _textCell(Map<String, dynamic> row, String field, double width) {
    final value = (row[field] ?? '').toString();
    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        value.isEmpty ? '—' : value,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
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
        textColor = const Color(0xFF64748B);
    }

    return Container(
      width: width,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: bgColor,
      ),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor, 
          borderRadius: BorderRadius.circular(6), 
          border: Border.all(color: textColor.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: textColor.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.3)),
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
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}