// lib/screens/admin_dashboard/performance_screen.dart
//
// Employee Performance Dashboard.
//
// Flow for a non-technical person looking at this screen:
//   1. Search and pick an employee.
//   2. Choose "Daily" (pick one date) or "Monthly" (pick a From/To range).
//   3. The page shows: how many tasks are Completed / Processing / On Hold /
//      Pending / Rejected, a couple of charts, and — most importantly — every
//      client assigned to that employee with the exact tasks under each
//      client and their current status. Tasks are automatically grouped by
//      role (Designer, Videographer, Developer, etc.) using whatever role
//      each task belongs to in Task Master, so nothing needs to be
//      hand-mapped per employee.
//
// Needs `fl_chart` in pubspec.yaml:
//   dependencies:
//     fl_chart: ^0.68.0

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // ---- status palette (used everywhere: cards, chips, charts) ----
  static const Map<String, Color> _statusColor = {
    'PENDING': Color(0xFF94A3B8),
    'PROCESSING': Color(0xFF0052CC),
    'ON HOLD': Color(0xFFD97706),
    'COMPLETED': Color(0xFF16A34A),
    'REJECTED': Color(0xFFDC2626),
  };

  // ---- employee search ----
  final TextEditingController _employeeSearchCtrl = TextEditingController();
  final LayerLink _employeeLayerLink = LayerLink();
  OverlayEntry? _employeeOverlay;
  List<Map<String, dynamic>> _allEmployees = [];
  List<Map<String, dynamic>> _employeeResults = [];
  bool _loadingEmployees = true;
  Map<String, dynamic>? _selectedEmployee;

  // ---- filters ----
  String _mode = 'daily'; // 'daily' | 'monthly'
  DateTime _selectedDate = DateTime.now();
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  // ---- data ----
  bool _loadingData = false;
  String? _error;
  Map<String, dynamic>? _data;

  // ---- client cards expand/collapse ----
  final Set<String> _expandedClients = {};

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  @override
  void dispose() {
    _employeeOverlay?.remove();
    _employeeSearchCtrl.dispose();
    super.dispose();
  }

  // ================================================================
  // DATA FETCHING
  // ================================================================
  Future<Map<String, String>> _authHeaders() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${authService.token}',
    };
  }

  Future<void> _fetchEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/employees'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _allEmployees = List<Map<String, dynamic>>.from(body['data'] ?? []);
          _loadingEmployees = false;
        });
      } else {
        setState(() => _loadingEmployees = false);
      }
    } catch (e) {
      setState(() => _loadingEmployees = false);
    }
  }

  Future<void> _fetchPerformance() async {
    if (_selectedEmployee == null) return;

    setState(() {
      _loadingData = true;
      _error = null;
    });

    try {
      final employeeName = _selectedEmployee!['full_name'] ?? '';
      String url;

      if (_mode == 'daily') {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        url = '$_baseUrl/performance?employeeName=${Uri.encodeComponent(employeeName)}&mode=daily&date=$dateStr';
      } else {
        final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
        final toStr = DateFormat('yyyy-MM-dd').format(_toDate);
        url = '$_baseUrl/performance?employeeName=${Uri.encodeComponent(employeeName)}&mode=monthly&fromDate=$fromStr&toDate=$toStr';
      }

      final response = await http.get(Uri.parse(url), headers: await _authHeaders());

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _data = body['data'];
          _loadingData = false;
          _expandedClients.clear();
        });
      } else {
        final body = jsonDecode(response.body);
        setState(() {
          _error = body['message'] ?? 'Failed to load performance data';
          _loadingData = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Cannot connect to server';
        _loadingData = false;
      });
    }
  }

  // ================================================================
  // EMPLOYEE SEARCH DROPDOWN (same floating-overlay pattern used
  // elsewhere in this app for client search)
  // ================================================================
  void _onEmployeeSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _employeeResults = q.isEmpty
          ? []
          : _allEmployees.where((e) {
              final name = (e['full_name'] ?? '').toString().toLowerCase();
              final staffId = (e['staff_id'] ?? '').toString().toLowerCase();
              return name.contains(q) || staffId.contains(q);
            }).toList();
    });
    if (_employeeResults.isNotEmpty) {
      _showEmployeeOverlay();
    } else {
      _hideEmployeeOverlay();
    }
  }

  void _selectEmployee(Map<String, dynamic> employee) {
    setState(() {
      _selectedEmployee = employee;
      _employeeSearchCtrl.text = employee['full_name'] ?? '';
      _data = null;
    });
    _hideEmployeeOverlay();
    _fetchPerformance();
  }

  void _showEmployeeOverlay() {
    _employeeOverlay?.remove();
    _employeeOverlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 340,
        child: CompositedTransformFollower(
          link: _employeeLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _employeeResults.length,
                itemBuilder: (context, index) {
                  final emp = _employeeResults[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        (emp['initials'] ?? '?').toString(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0052CC)),
                      ),
                    ),
                    title: Text(emp['full_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(emp['role'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    onTap: () => _selectEmployee(emp),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_employeeOverlay!);
  }

  void _hideEmployeeOverlay() {
    _employeeOverlay?.remove();
    _employeeOverlay = null;
  }

  // ================================================================
  // DATE PICKERS
  // ================================================================
  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchPerformance();
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _fetchPerformance();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _fetchPerformance();
    }
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Employee Performance',
      currentRoute: '/performance',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(isMobile),
              const SizedBox(height: 18),
              _buildFilterCard(isMobile),
              const SizedBox(height: 18),
              if (_selectedEmployee == null)
                _buildEmptyPrompt()
              else if (_loadingData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                )
              else if (_error != null)
                _buildErrorState()
              else if (_data != null) ...[
                _buildSummaryCards(isMobile),
                const SizedBox(height: 18),
                _buildChartsSection(isMobile),
                const SizedBox(height: 18),
                _buildClientsSection(isMobile),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  // ---------------- Hero ----------------
  Widget _buildHero(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 22),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.insights_rounded, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employee Performance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Search an employee to see their assigned clients, tasks and progress at a glance.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Filter card ----------------
  Widget _buildFilterCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(width: isMobile ? double.infinity : 300, child: _buildEmployeeSearchField()),
          SizedBox(width: isMobile ? double.infinity : 240, child: _buildModeToggle()),
          if (_mode == 'daily')
            SizedBox(width: isMobile ? double.infinity : 200, child: _buildDateField('Date', _selectedDate, _pickSingleDate))
          else ...[
            SizedBox(width: isMobile ? double.infinity : 190, child: _buildDateField('From Date', _fromDate, _pickFromDate)),
            SizedBox(width: isMobile ? double.infinity : 190, child: _buildDateField('To Date', _toDate, _pickToDate)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Employee', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        CompositedTransformTarget(
          link: _employeeLayerLink,
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _employeeSearchCtrl,
              onChanged: _onEmployeeSearchChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by name or staff ID...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _loadingEmployees
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(child: _modeButton('Daily', 'daily')),
              Expanded(child: _modeButton('Monthly', 'monthly')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeButton(String label, String value) {
    final isActive = _mode == value;
    return GestureDetector(
      onTap: () {
        setState(() => _mode = value);
        _fetchPerformance();
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildDateField(String label, DateTime value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(DateFormat('dd/MM/yyyy').format(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Empty / error states ----------------
  Widget _buildEmptyPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.person_search_rounded, size: 40, color: Color(0xFF94A3B8)),
            SizedBox(height: 10),
            Text('Search and select an employee above', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
            SizedBox(height: 4),
            Text('Their performance, assigned clients and tasks will show here.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 34, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(_error ?? 'Something went wrong', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _fetchPerformance, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // ---------------- Summary cards ----------------
  Widget _buildSummaryCards(bool isMobile) {
    final summary = _data!['summary'] as Map<String, dynamic>;
    final emp = _data!['employee'] as Map<String, dynamic>;

    final cards = [
      _statCard('Total Tasks', summary['totalTasks'].toString(), Icons.list_alt_rounded, const Color(0xFF172033)),
      _statCard('Completed', summary['completed'].toString(), Icons.check_circle_rounded, _statusColor['COMPLETED']!),
      _statCard('Processing', summary['processing'].toString(), Icons.autorenew_rounded, _statusColor['PROCESSING']!),
      _statCard('On Hold', summary['onHold'].toString(), Icons.pause_circle_rounded, _statusColor['ON HOLD']!),
      _statCard('Pending', summary['pending'].toString(), Icons.hourglass_empty_rounded, _statusColor['PENDING']!),
      _statCard('Rejected', summary['rejected'].toString(), Icons.cancel_rounded, _statusColor['REJECTED']!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEFF6FF),
              child: Text((emp['initials'] ?? '?').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp['fullName'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF172033))),
                Text('${emp['role'] ?? ''} • Total time ${summary['totalDuration']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: isMobile ? 2 : 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isMobile ? 1.5 : 1.15,
          children: cards,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  // ---------------- Charts ----------------
  Widget _buildChartsSection(bool isMobile) {
    final summary = _data!['summary'] as Map<String, dynamic>;
    final roles = List<Map<String, dynamic>>.from(_data!['roles'] ?? []);
    final trend = List<Map<String, dynamic>>.from(_data!['trend'] ?? []);

    final statusChart = _chartCard(
      title: 'Status Breakdown',
      child: SizedBox(height: 220, child: _buildStatusPieChart(summary)),
    );

    final roleChart = _chartCard(
      title: 'Tasks by Role',
      child: SizedBox(height: 220, child: _buildRoleBarChart(roles)),
    );

    final trendChart = _mode == 'monthly'
        ? _chartCard(
            title: 'Completed Tasks Trend',
            child: SizedBox(height: 220, child: _buildTrendLineChart(trend)),
          )
        : null;

    if (isMobile) {
      return Column(
        children: [
          statusChart,
          const SizedBox(height: 14),
          roleChart,
          if (trendChart != null) ...[const SizedBox(height: 14), trendChart],
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: statusChart),
            const SizedBox(width: 14),
            Expanded(child: roleChart),
          ],
        ),
        if (trendChart != null) ...[const SizedBox(height: 14), trendChart],
      ],
    );
  }

  Widget _chartCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF172033))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusPieChart(Map<String, dynamic> summary) {
    final entries = <MapEntry<String, int>>[
      MapEntry('Completed', summary['completed'] as int),
      MapEntry('Processing', summary['processing'] as int),
      MapEntry('On Hold', summary['onHold'] as int),
      MapEntry('Pending', summary['pending'] as int),
      MapEntry('Rejected', summary['rejected'] as int),
    ].where((e) => e.value > 0).toList();

    if (entries.isEmpty) {
      return const Center(child: Text('No tasks in this period', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))));
    }

    final colors = {
      'Completed': _statusColor['COMPLETED']!,
      'Processing': _statusColor['PROCESSING']!,
      'On Hold': _statusColor['ON HOLD']!,
      'Pending': _statusColor['PENDING']!,
      'Rejected': _statusColor['REJECTED']!,
    };

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: entries.map((e) {
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  color: colors[e.key],
                  title: '${e.value}',
                  radius: 46,
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: colors[e.key], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${e.key} (${e.value})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoleBarChart(List<Map<String, dynamic>> roles) {
    if (roles.isEmpty) {
      return const Center(child: Text('No tasks in this period', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))));
    }

    final maxVal = roles.map((r) => r['totalTasks'] as int).fold<int>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxVal + 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= roles.length) return const SizedBox.shrink();
                final name = roles[i]['roleName'].toString();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    name.length > 8 ? '${name.substring(0, 8)}…' : name,
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(roles.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (roles[i]['totalTasks'] as int).toDouble(),
                color: const Color(0xFF4F46E5),
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTrendLineChart(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) {
      return const Center(child: Text('No activity in this period', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))));
    }

    final spots = List.generate(trend.length, (i) {
      final completed = (trend[i]['COMPLETED'] ?? 0) as int;
      return FlSpot(i.toDouble(), completed.toDouble());
    });

    final maxY = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY + 1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (trend.length / 6).clamp(1, trend.length).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                final date = DateTime.tryParse(trend[i]['date'].toString());
                final label = date != null ? DateFormat('dd/MM').format(date) : '';
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF16A34A),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF16A34A).withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }

  // ---------------- Clients + tasks section ----------------
  Widget _buildClientsSection(bool isMobile) {
    final clients = List<Map<String, dynamic>>.from(_data!['clients'] ?? []);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assigned Clients & Tasks (${clients.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF172033))),
          const SizedBox(height: 4),
          const Text('Tap a client to see every task, its role, and current status.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 12),
          if (clients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No clients/tasks found for this period', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
            )
          else
            ...clients.map((client) => _buildClientCard(client, isMobile)),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client, bool isMobile) {
    final clientName = client['clientName'] as String;
    final isExpanded = _expandedClients.contains(clientName);
    final tasks = List<Map<String, dynamic>>.from(client['tasks'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedClients.remove(clientName);
                } else {
                  _expandedClients.add(clientName);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.apartment_rounded, size: 17, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF172033))),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _miniBadge('${client['totalTasks']} tasks', const Color(0xFF64748B)),
                            if ((client['COMPLETED'] ?? 0) > 0) _miniBadge('${client['COMPLETED']} done', _statusColor['COMPLETED']!),
                            if ((client['IN PROGRESS'] ?? 0) > 0) _miniBadge('${client['IN PROGRESS']} processing', _statusColor['PROCESSING']!),
                            if ((client['ON HOLD'] ?? 0) > 0) _miniBadge('${client['ON HOLD']} hold', _statusColor['ON HOLD']!),
                            if ((client['IDLE'] ?? 0) > 0) _miniBadge('${client['IDLE']} pending', _statusColor['PENDING']!),
                            if ((client['REJECTED'] ?? 0) > 0) _miniBadge('${client['REJECTED']} rejected', _statusColor['REJECTED']!),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: const Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: tasks.map((t) => _buildTaskRow(t, isMobile)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task, bool isMobile) {
    final status = task['status'] as String;
    final color = _statusColor[status == 'IDLE' ? 'PENDING' : (status == 'IN PROGRESS' ? 'PROCESSING' : status)] ?? const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task['deliverable'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF172033))),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _miniBadge(task['roleName'] ?? '', const Color(0xFF4F46E5)),
                  _miniBadge(task['statusLabel'] ?? '', color),
                  _miniBadge('⏱ ${task['duration']}', const Color(0xFF64748B)),
                  _miniBadge('⭐ ${task['performance']}', const Color(0xFF64748B)),
                ]),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: Text(task['deliverable'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF172033)))),
                Expanded(flex: 2, child: _miniBadge(task['roleName'] ?? '', const Color(0xFF4F46E5))),
                Expanded(flex: 2, child: _miniBadge(task['statusLabel'] ?? '', color)),
                Expanded(flex: 1, child: Text(task['duration'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                Expanded(flex: 1, child: Text(task['performance'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
              ],
            ),
    );
  }
}