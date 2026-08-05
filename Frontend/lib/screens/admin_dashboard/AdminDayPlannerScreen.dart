import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class AdminDayPlannerScreen extends StatefulWidget {
  const AdminDayPlannerScreen({super.key});

  @override
  State<AdminDayPlannerScreen> createState() => _AdminDayPlannerScreenState();
}

class _AdminDayPlannerScreenState extends State<AdminDayPlannerScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final ScrollController _horizontalController = ScrollController();
  Timer? _autoSaveTimer;
  final TextEditingController _searchController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String dateFilterMode = 'Today'; // 'Today' or 'This Month'
  String searchQuery = '';
  String employeeDropdownFilter = 'All Employees';
  
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
      print("🔥 Real-time update received: $data");
      if (mounted) {
        _fetchTotalWorkingHours();
        _loadEmployeesAndSubmissions();
      }
    });
  }

  Future<void> _fetchTotalWorkingHours() async {
    if (selectedEmployee != null) {
      await _fetchEmployeeDayPlan(selectedEmployee!);
    }
    await _loadEmployeesAndSubmissions();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _autoSaveTimer?.cancel();
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: "Day Planner Monitoring",
      currentRoute: "/daily-planner",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader(),
          const SizedBox(height: 20),
          if (selectedEmployee == null) ...[
            _buildSummaryCards(),
            const SizedBox(height: 20),
            _buildFiltersRow(),
            const SizedBox(height: 16),
            SizedBox(
              height: 460,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildEmployeeStatusTable(),
            ),
          ] else ...[
            _buildSelectedEmployeeHeader(),
            const SizedBox(height: 16),
            SizedBox(
              height: 480,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildGroupedSheetGrids(dayPlanRows),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day Planner Monitoring', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            SizedBox(height: 4),
            Text('Monitor employee day planner submissions and review logs.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 12),
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
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF2A52BE)),
                        const SizedBox(width: 8),
                        Text(
                          "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2A52BE),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
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
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    int totalCount = employeesList.length;
    int submittedCount = employeesList.where((emp) {
      final name = (emp['fullName'] ?? '').toString();
      return submissionStatusList.any((s) => (s['employeeName'] ?? '').toString().toLowerCase() == name.toLowerCase() && s['submitted'] == true);
    }).length;
    int pendingCount = totalCount - submittedCount;

    return Row(
      children: [
        Expanded(child: _summaryCard('Total Employees', '$totalCount', Icons.people_outline, const Color(0xFF2A52BE))),
        const SizedBox(width: 16),
        Expanded(child: _summaryCard('Submitted', '$submittedCount', Icons.check_circle_outline, const Color(0xFF16A34A))),
        const SizedBox(width: 16),
        Expanded(child: _summaryCard('Pending / Not Submitted', '$pendingCount', Icons.hourglass_empty, const Color(0xFFDC2626))),
      ],
    );
  }

  Widget _summaryCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          height: 40,
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: "Search employee...",
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A52BE))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: employeeDropdownFilter,
              items: ['All Employees', 'Submitted', 'Pending'].map((val) {
                return DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => employeeDropdownFilter = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeStatusTable() {
    final filteredEmployees = employeesList.where((emp) {
      final name = (emp['fullName'] ?? '').toString();
      final matchesSearch = name.toLowerCase().contains(searchQuery.toLowerCase());
      
      final bool hasSubmitted = submissionStatusList.any(
        (s) => (s['employeeName'] ?? '').toString().toLowerCase() == name.toLowerCase() && s['submitted'] == true,
      );

      bool matchesDropdown = true;
      if (employeeDropdownFilter == 'Submitted') matchesDropdown = hasSubmitted;
      if (employeeDropdownFilter == 'Pending') matchesDropdown = !hasSubmitted;

      return matchesSearch && matchesDropdown;
    }).toList();

    if (filteredEmployees.isEmpty) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        alignment: Alignment.center,
        child: const Text("No employees found matching filter criteria.", style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(flex: 3, child: Text("EMPLOYEE NAME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text("ROLE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text("STATUS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text("ACTION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: ListView.separated(
              itemCount: filteredEmployees.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final emp = filteredEmployees[index];
                final empName = emp['fullName'] ?? 'Employee';
                final empRole = emp['role'] ?? 'Staff';
                final bool hasSubmitted = submissionStatusList.any(
                  (s) => (s['employeeName'] ?? '').toString().toLowerCase() == empName.toLowerCase() && s['submitted'] == true,
                );

                return InkWell(
                  onTap: () => _fetchEmployeeDayPlan(empName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF2A52BE).withValues(alpha: 0.1),
                                child: Text(empName[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2A52BE))),
                              ),
                              const SizedBox(width: 10),
                              Text(empName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(empRole, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: hasSubmitted ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _fetchEmployeeDayPlan(empName),
                              child: const Text("View Planner", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2A52BE))),
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
    );
  }

  Widget _buildSelectedEmployeeHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Employee Planner: $selectedEmployee ($dateFilterMode Mode)",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        ElevatedButton.icon(
          onPressed: () => setState(() => selectedEmployee = null),
          icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white),
          label: const Text('Back to Overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A52BE), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ],
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        alignment: Alignment.center,
        child: Text('No day plan entries found for this employee ($dateFilterMode).', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
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
        borderRadius: BorderRadius.circular(8),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: const Color(0xFF1E293B),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📅 Date: $dateKey$dayName',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.timer_rounded, size: 14, color: Color(0xFF60A5FA)),
                            const SizedBox(width: 6),
                            Text(
                              'Working Time: ${_formatWorkingTime(dateRows.isNotEmpty ? dateRows.first['total_working_secs'] : 0)}',
                              style: const TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 180,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 40,
                                color: const Color(0xFF0052CC),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.centerLeft,
                                child: const Text('CLIENT NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              ...dateRows.map((row) => _clientCell(row)),
                            ],
                          ),
                        ),
                        const VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
                        Flexible(
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
                                  children: [
                                    SizedBox(
                                      width: tableWidth,
                                      height: 40,
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
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0052CC),
        border: Border(bottom: BorderSide(color: Color(0xFF0044B3))),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        current.isEmpty ? '—' : current,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        value.isEmpty ? '—' : value,
        style: TextStyle(fontSize: 11, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
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
        bgColor = const Color(0xFFF0F4F8);
        textColor = const Color(0xFF1E293B);
        break;
      case 'PROCESSING':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF0369A1);
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
    }

    return Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: bgColor,
      ),
      alignment: Alignment.centerLeft,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
          child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.2),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}