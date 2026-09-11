// lib/screens/admin_dashboard/performance_screen.dart
//
// Employee Performance & Productivity Dashboard — v2.
//
// Two views in one screen:
//   1) OVERVIEW  — loads automatically, shows every active employee as a
//      compact performance card (ring, completion/pending/rejected %,
//      tasks, clients, working hours). Sortable/filterable.
//   2) DETAIL    — tap any card to open that employee's full A-to-Z
//      dashboard: KPI grid, performance-score ring, working-hours &
//      productivity analytics, task/role distribution, client & task
//      tracking (expandable), Day Planner consistency heatmap, manager
//      review productivity, timeline, and a performance trend graph.
//
// Every number comes from routes/performance.js, which itself is built
// entirely from your existing tables (task_list, time_tracking_task_items,
// task_master/task_roles, day_plan_rows, manager_review) — nothing here is
// hardcoded or dummy.
//
// Needs `fl_chart` in pubspec.yaml:  fl_chart: ^0.68.0

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

// ════════════════════════════════════════════════════════════════
// Shared palette / small helpers
// ════════════════════════════════════════════════════════════════
class _Palette {
  // Premium software palette: blue/white foundation with semantic accents.
  static const primary = Color(0xFF0759D4);
  static const primary2 = Color(0xFF1D74E8);
  static const primary3 = Color(0xFF0B3B91);
  static const sky = Color(0xFFEAF4FF);
  static const completed = Color(0xFF16A34A);
  static const processing = Color(0xFF0066D6);
  static const onHold = Color(0xFFE58A00);
  static const pending = Color(0xFF64748B);
  static const rejected = Color(0xFFDC2626);
  static const purple = Color(0xFF7C3AED);
  static const cyan = Color(0xFF0891B2);
  static const ink = Color(0xFF14213D);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFD9E5F3);
  static const bg = Color(0xFFF4F8FD);

  static Color forScore(double score) {
    if (score >= 85) return completed;
    if (score >= 70) return processing;
    if (score >= 50) return onHold;
    return rejected;
  }
}

String _gradeLabel(String? grade) => grade ?? '—';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  String _mode = 'daily';
  String _quickFilter = 'today';
  DateTime _selectedDate = DateTime.now();
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  bool _loadingOverview = true;
  String? _overviewError;
  List<Map<String, dynamic>> _employees = [];
  String _searchQuery = '';
  String _sortBy = 'performance_desc';

  String? _selectedEmployeeName;
  bool _loadingDetail = false;
  String? _detailError;
  Map<String, dynamic>? _detail;
  final Set<String> _expandedClients = {};

  @override
  void initState() {
    super.initState();
    _fetchOverview();
  }

  Future<Map<String, String>> _authHeaders() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authService.token}'};
  }

  String _rangeQuery() {
    if (_mode == 'daily') {
      return 'mode=daily&date=${DateFormat('yyyy-MM-dd').format(_selectedDate)}';
    }
    return 'mode=monthly&fromDate=${DateFormat('yyyy-MM-dd').format(_fromDate)}&toDate=${DateFormat('yyyy-MM-dd').format(_toDate)}';
  }

  Future<void> _fetchOverview() async {
    setState(() {
      _loadingOverview = true;
      _overviewError = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/performance/overview?${_rangeQuery()}'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _employees = List<Map<String, dynamic>>.from(body['data']['employees'] ?? []);
          _loadingOverview = false;
        });
      } else {
        setState(() {
          _overviewError = 'Failed to load employees';
          _loadingOverview = false;
        });
      }
    } catch (e) {
      setState(() {
        _overviewError = 'Cannot connect to server';
        _loadingOverview = false;
      });
    }
  }

  Future<void> _fetchDetail(String employeeName) async {
    setState(() {
      _selectedEmployeeName = employeeName;
      _loadingDetail = true;
      _detailError = null;
      _detail = null;
      _expandedClients.clear();
    });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/performance/detail?employeeName=${Uri.encodeComponent(employeeName)}&${_rangeQuery()}'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _detail = body['data'];
          _loadingDetail = false;
        });
      } else {
        final body = jsonDecode(response.body);
        setState(() {
          _detailError = body['message'] ?? 'Failed to load employee detail';
          _loadingDetail = false;
        });
      }
    } catch (e) {
      setState(() {
        _detailError = 'Cannot connect to server';
        _loadingDetail = false;
      });
    }
  }

  void _refreshCurrentView() {
    _fetchOverview();
    if (_selectedEmployeeName != null) _fetchDetail(_selectedEmployeeName!);
  }

  void _applyQuickFilter(String key) {
    final now = DateTime.now();
    setState(() {
      _quickFilter = key;
      switch (key) {
        case 'today':
          _mode = 'daily';
          _selectedDate = now;
          break;
        case 'week':
          _mode = 'monthly';
          _fromDate = now.subtract(Duration(days: now.weekday - 1));
          _toDate = now;
          break;
        case 'month':
          _mode = 'monthly';
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = now;
          break;
        case 'custom':
          _mode = 'monthly';
          break;
      }
    });
    _refreshCurrentView();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _quickFilter = 'custom';
        _mode = 'monthly';
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _refreshCurrentView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Employee Performance',
      currentRoute: '/performance',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;
          final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 1100;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(isMobile),
              const SizedBox(height: 16),
              _buildFilterBar(isMobile),
              const SizedBox(height: 16),
              if (_selectedEmployeeName == null)
                _buildOverview(isMobile, isTablet)
              else
                _buildDetail(isMobile, isTablet),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHero(bool isMobile) {
    final detailMode = _selectedEmployeeName != null;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 18 : 22, isMobile ? 12 : 18, isMobile ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Palette.primary3, _Palette.primary, _Palette.primary2],
          stops: [0.0, 0.48, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _Palette.primary.withValues(alpha: 0.25), blurRadius: 26, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -25, top: -45, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)))),
          Positioned(right: 70, bottom: -55, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 46 : 52,
                height: isMobile ? 46 : 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (detailMode)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedEmployeeName = null;
                            _detail = null;
                            _detailError = null;
                          }),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_rounded, color: Colors.white, size: 15),
                                SizedBox(width: 5),
                                Text('Back to All Employees', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Text(
                      detailMode ? _selectedEmployeeName! : 'Employee Performance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detailMode ? 'Full productivity, task, planner and review analytics' : 'Monitor productivity, performance and workload across your team',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 10.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (detailMode)
                Container(
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.22))),
                  child: IconButton(onPressed: _refreshCurrentView, icon: const Icon(Icons.refresh_rounded, color: Colors.white), tooltip: 'Refresh'),
                )
              else
                Container(
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.22))),
                  child: IconButton(onPressed: _refreshCurrentView, icon: const Icon(Icons.refresh_rounded, color: Colors.white), tooltip: 'Refresh'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    final custom = _quickFilter == 'custom';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.border),
        boxShadow: [BoxShadow(color: _Palette.primary.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: _Palette.sky, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.tune_rounded, color: _Palette.primary, size: 17)),
              const SizedBox(width: 9),
              const Text('Performance Filters', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _Palette.ink)),
              const Spacer(),
              if (custom)
                Text('Custom period selected', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _Palette.primary)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _quickChip('Today', 'today'),
              _quickChip('This Week', 'week'),
              _quickChip('This Month', 'month'),
              GestureDetector(
                onTap: _pickCustomRange,
                child: _chipShell(
                  selected: custom,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.date_range_rounded, size: 14),
                    const SizedBox(width: 6),
                    Text(custom ? 'Custom Range' : 'Custom Range', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
              if (!isMobile) Container(width: 1, height: 26, color: _Palette.border),
              if (_selectedEmployeeName == null)
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search employee...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: _Palette.muted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 17, color: _Palette.primary),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      filled: true,
                      fillColor: _Palette.bg,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _Palette.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _Palette.primary, width: 1.4)),
                    ),
                  ),
                ),
              if (_selectedEmployeeName == null) _sortDropdown(),
            ],
          ),
          if (custom) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _Palette.sky.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFCFE3FA))),
              child: isMobile
                  ? Column(children: [
                      Row(children: [Expanded(child: _dateField('FROM DATE', _fromDate, () => _pickSingleDate(true))), const SizedBox(width: 8), Expanded(child: _dateField('TO DATE', _toDate, () => _pickSingleDate(false)))]),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _pickCustomRange, icon: const Icon(Icons.calendar_month_rounded, size: 16), label: const Text('Change Date Range'), style: _rangeButtonStyle())),
                    ])
                  : Row(children: [
                      _dateField('FROM DATE', _fromDate, () => _pickSingleDate(true)),
                      const SizedBox(width: 10),
                      _dateField('TO DATE', _toDate, () => _pickSingleDate(false)),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(onPressed: _pickCustomRange, icon: const Icon(Icons.calendar_month_rounded, size: 16), label: const Text('Change Range'), style: _rangeButtonStyle()),
                      const Spacer(),
                      Text('${DateFormat('dd MMM yyyy').format(_fromDate)}  →  ${DateFormat('dd MMM yyyy').format(_toDate)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _Palette.primary)),
                    ]),
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _rangeButtonStyle() => ElevatedButton.styleFrom(
    backgroundColor: _Palette.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
  );

  Widget _dateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 155,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBFD5EE))),
        child: Row(children: [
          const Icon(Icons.event_rounded, size: 15, color: _Palette.primary),
          const SizedBox(width: 7),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: _Palette.muted, letterSpacing: 0.5)), const SizedBox(height: 2), Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _Palette.ink))])),
        ]),
      ),
    );
  }

  Future<void> _pickSingleDate(bool isFrom) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2035), builder: (context, child) {
      return Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: _Palette.primary, surface: Colors.white)), child: child!);
    });
    if (picked == null) return;
    if (isFrom && picked.isAfter(_toDate)) return;
    if (!isFrom && picked.isBefore(_fromDate)) return;
    setState(() {
      _quickFilter = 'custom';
      _mode = 'monthly';
      if (isFrom) _fromDate = picked; else _toDate = picked;
    });
    _refreshCurrentView();
  }

  Widget _quickChip(String label, String key) {
    return GestureDetector(
      onTap: () => _applyQuickFilter(key),
      child: _chipShell(selected: _quickFilter == key, child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
    );
  }

  Widget _chipShell({required bool selected, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? _Palette.primary : const Color(0xFFF7FAFE),
        border: Border.all(color: selected ? _Palette.primary : _Palette.border),
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected ? [BoxShadow(color: _Palette.primary.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3))] : null,
      ),
      child: DefaultTextStyle(style: TextStyle(color: selected ? Colors.white : _Palette.muted), child: child),
    );
  }

  Widget _sortDropdown() {
    const options = {
      'performance_desc': 'Highest Performance',
      'performance_asc': 'Lowest Performance',
      'tasks_desc': 'Most Tasks',
      'completed_desc': 'Most Completed',
      'productivity_desc': 'Productivity',
      'hours_desc': 'Working Hours',
      'pending_desc': 'Pending Work',
      'role': 'Role',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(border: Border.all(color: _Palette.border), borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isDense: true,
          icon: const Icon(Icons.sort_rounded, size: 15),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _Palette.ink),
          items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => _sortBy = v!),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleEmployees {
    var list = _employees.where((e) {
      if (_searchQuery.isEmpty) return true;
      final name = (e['fullName'] ?? '').toString().toLowerCase();
      final role = (e['role'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || role.contains(_searchQuery);
    }).toList();

    int cmpNum(num a, num b) => b.compareTo(a);
    switch (_sortBy) {
      case 'performance_desc':
        list.sort((a, b) => cmpNum(a['performancePct'], b['performancePct']));
        break;
      case 'performance_asc':
        list.sort((a, b) => -cmpNum(a['performancePct'], b['performancePct']));
        break;
      case 'tasks_desc':
        list.sort((a, b) => cmpNum(a['totalTasks'], b['totalTasks']));
        break;
      case 'completed_desc':
        list.sort((a, b) => cmpNum(a['completed'], b['completed']));
        break;
      case 'productivity_desc':
        list.sort((a, b) => cmpNum(a['productivityPct'], b['productivityPct']));
        break;
      case 'hours_desc':
        list.sort((a, b) => cmpNum(a['workingSecs'], b['workingSecs']));
        break;
      case 'pending_desc':
        list.sort((a, b) => cmpNum(a['pending'], b['pending']));
        break;
      case 'role':
        list.sort((a, b) => (a['role'] ?? '').toString().compareTo((b['role'] ?? '').toString()));
        break;
    }
    return list;
  }

  Widget _buildOverview(bool isMobile, bool isTablet) {
    if (_loadingOverview) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator(color: _Palette.primary)));
    }
    if (_overviewError != null) {
      return _errorBox(_overviewError!, _fetchOverview);
    }
    final list = _visibleEmployees;
    if (list.isEmpty) {
      return _emptyBox('No employees found', 'Try a different search term.');
    }

    final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: isMobile ? 1.85 : 1.55,
      ),
      itemBuilder: (context, i) => _employeeCard(list[i]),
    );
  }

  Widget _employeeCard(Map<String, dynamic> emp) {
    final score = (emp['performancePct'] as num).toDouble();
    final color = _Palette.forScore(score);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _fetchDetail(emp['fullName']),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _Palette.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _Palette.primary.withValues(alpha: 0.1),
                  child: Text((emp['initials'] ?? '?').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _Palette.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp['fullName'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _Palette.ink)),
                      Text(emp['role'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: _Palette.muted)),
                    ],
                  ),
                ),
                _AnimatedRing(percent: score, color: color, size: 46, strokeWidth: 5, centerText: '${score.toInt()}'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _miniStat('${emp['totalTasks']}', 'Tasks'),
                _miniStat('${emp['totalClients']}', 'Clients'),
                _miniStat(emp['workingHours'] ?? '0m', 'Hours'),
                _miniStat('${emp['productivityPct']}%', 'Prod.'),
              ],
            ),
            const SizedBox(height: 8),
            _segmentBar([
              _Seg((emp['completedPct'] as num).toDouble(), _Palette.completed),
              _Seg((emp['processingPct'] as num).toDouble(), _Palette.processing),
              _Seg((emp['pendingPct'] as num).toDouble(), _Palette.pending),
              _Seg((emp['rejectedPct'] as num).toDouble(), _Palette.rejected),
            ]),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${emp['completed']} done', style: const TextStyle(fontSize: 9.5, color: _Palette.completed, fontWeight: FontWeight.w700)),
                Text(_gradeLabel(emp['performanceGrade']), style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _Palette.ink)),
          Text(label, style: const TextStyle(fontSize: 8.5, color: _Palette.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildDetail(bool isMobile, bool isTablet) {
    if (_loadingDetail) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator(color: _Palette.primary)));
    }
    if (_detailError != null) {
      return _errorBox(_detailError!, () => _fetchDetail(_selectedEmployeeName!));
    }
    if (_detail == null) return const SizedBox.shrink();

    final emp = _detail!['employee'];
    final perf = _detail!['performance'];
    final summary = _detail!['summary'];
    final hours = _detail!['workingHours'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailHeader(emp, perf, hours, isMobile),
        const SizedBox(height: 16),
        _kpiGrid(summary, isMobile, isTablet),
        const SizedBox(height: 16),
        _sectionRow(isMobile, [
          _card('Working Hours & Productivity', _workingHoursBody(hours)),
          _card('Task Distribution by Role', _roleDistributionBody()),
        ]),
        const SizedBox(height: 16),
        _card('Performance Trend', _trendBody(isMobile)),
        const SizedBox(height: 16),
        _sectionRow(isMobile, [
          _card('Manager Approval Productivity', _managerReviewBody()),
          _card('Day Planner Consistency', _dayPlannerBody()),
        ]),
        const SizedBox(height: 16),
        _card('Client & Task Tracking', _clientsBody(isMobile)),
        const SizedBox(height: 16),
        _card('Daily Activity Timeline', _timelineBody()),
      ],
    );
  }

  Widget _sectionRow(bool isMobile, List<Widget> children) {
    if (isMobile) {
      return Column(children: [for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: c)]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _card(String title, Widget body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _Palette.ink)),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _detailHeader(Map emp, Map perf, Map hours, bool isMobile) {
    final score = (perf['score'] as num).toDouble();
    final color = _Palette.forScore(score);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF1F7FF)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Palette.border),
        boxShadow: [BoxShadow(color: _Palette.primary.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 7))],
      ),
      child: Column(
        children: [
          Row(children: [
            OutlinedButton.icon(
              onPressed: () => setState(() { _selectedEmployeeName = null; _detail = null; _detailError = null; }),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Employees'),
              style: OutlinedButton.styleFrom(foregroundColor: _Palette.primary, side: const BorderSide(color: Color(0xFFBFD5EE)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            _miniBadge('${perf['score']}% score', color),
          ]),
          const SizedBox(height: 14),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 14, children: [
            SizedBox(
              width: isMobile ? double.infinity : 340,
              child: Row(children: [
                CircleAvatar(radius: 27, backgroundColor: _Palette.sky, child: Text((emp['initials'] ?? '?').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _Palette.primary))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emp['fullName'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _Palette.ink)),
                  Text('${emp['role'] ?? ''}${(emp['staffId'] ?? '').toString().isNotEmpty ? ' • ID: ${emp['staffId']}' : ''}', style: const TextStyle(fontSize: 11.5, color: _Palette.muted, fontWeight: FontWeight.w600)),
                ])),
              ]),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 300,
              child: Row(children: [
                _AnimatedRing(percent: score, color: color, size: 66, strokeWidth: 7, centerText: '${score.toInt()}%'),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Performance Score', style: TextStyle(fontSize: 10.5, color: _Palette.muted, fontWeight: FontWeight.w700)),
                  Text(_gradeLabel(perf['grade']), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                  Text('Total working: ${hours['total']}', style: const TextStyle(fontSize: 10.5, color: _Palette.muted)),
                ]),
              ]),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _kpiGrid(Map summary, bool isMobile, bool isTablet) {
    final items = [
      _KpiItem('Total Clients', '${summary['totalClients']}', null, Icons.apartment_rounded, _Palette.primary),
      _KpiItem('Total Tasks', '${summary['totalTasks']}', null, Icons.list_alt_rounded, _Palette.ink),
      _KpiItem('Completed', '${summary['completed']}', '${summary['completedPct']}%', Icons.check_circle_rounded, _Palette.completed),
      _KpiItem('Processing', '${summary['processing']}', '${summary['processingPct']}%', Icons.autorenew_rounded, _Palette.processing),
      _KpiItem('On Hold', '${summary['onHold']}', '${summary['onHoldPct']}%', Icons.pause_circle_rounded, _Palette.onHold),
      _KpiItem('Pending', '${summary['pending']}', '${summary['pendingPct']}%', Icons.hourglass_empty_rounded, _Palette.pending),
      _KpiItem('Rejected', '${summary['rejected']}', '${summary['rejectedPct']}%', Icons.cancel_rounded, _Palette.rejected),
    ];

    final crossAxisCount = isMobile ? 2 : (isTablet ? 4 : 7);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: isMobile ? 1.5 : 1.05,
      children: items.map((k) => _kpiCard(k)).toList(),
    );
  }

  Widget _kpiCard(_KpiItem k) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _Palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(k.icon, size: 16, color: k.color),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(k.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: k.color)),
              if (k.subValue != null) ...[
                const SizedBox(width: 4),
                Text(k.subValue!, style: const TextStyle(fontSize: 10, color: _Palette.muted, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          Text(k.label, style: const TextStyle(fontSize: 9.5, color: _Palette.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _workingHoursBody(Map hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _hourStat('Total', hours['total'], _Palette.ink),
            _hourStat('Productive', hours['productive'], _Palette.completed),
            _hourStat('Idle', hours['idle'], _Palette.onHold),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _hourStat('Avg / Day', hours['avgDaily'], _Palette.processing),
            _hourStat('Avg / Task', hours['avgTask'], _Palette.primary),
            _hourStat('Productivity', '${hours['productivityPct']}%', _Palette.completed),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ((hours['productivityPct'] as num).toDouble() / 100).clamp(0, 1),
            minHeight: 8,
            backgroundColor: _Palette.bg,
            valueColor: const AlwaysStoppedAnimation(_Palette.completed),
          ),
        ),
      ],
    );
  }

  Widget _hourStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: _Palette.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _roleDistributionBody() {
    final roles = List<Map<String, dynamic>>.from(_detail!['roles'] ?? []);
    if (roles.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('No task data in this period', style: TextStyle(fontSize: 12, color: _Palette.muted))));
    }
    final maxVal = roles.map((r) => r['totalTasks'] as int).fold<int>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(
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
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= roles.length) return const SizedBox.shrink();
                  final name = roles[i]['roleName'].toString();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(name.length > 10 ? '${name.substring(0, 10)}...' : name, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: _Palette.muted)),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(roles.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: (roles[i]['totalTasks'] as int).toDouble(), color: _Palette.primary, width: 16, borderRadius: BorderRadius.circular(4)),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _trendBody(bool isMobile) {
    final trend = List<Map<String, dynamic>>.from(_detail!['trend'] ?? []);
    if (trend.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('No activity in this period', style: TextStyle(fontSize: 12, color: _Palette.muted))));
    }

    final spots = List.generate(trend.length, (i) => FlSpot(i.toDouble(), (trend[i]['dayPerformancePct'] as num).toDouble()));

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 25, getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 9, color: _Palette.muted)))),
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
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(date != null ? DateFormat('dd/MM').format(date) : '', style: const TextStyle(fontSize: 9, color: _Palette.muted)));
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _Palette.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: _Palette.primary.withValues(alpha: 0.08)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _managerReviewBody() {
    final mr = _detail!['managerReview'];
    return Column(
      children: [
        Row(
          children: [
            _reviewStat('Approved', mr['approved'], _Palette.completed),
            _reviewStat('Rework', mr['rework'], _Palette.onHold),
            _reviewStat('Rejected', mr['rejected'], _Palette.rejected),
            _reviewStat('Pending', mr['pendingReview'], _Palette.pending),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Approval Rate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Palette.muted)),
            const Spacer(),
            Text('${mr['approvalRatePct']}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _Palette.completed)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ((mr['approvalRatePct'] as num).toDouble() / 100).clamp(0, 1),
            minHeight: 8,
            backgroundColor: _Palette.bg,
            valueColor: const AlwaysStoppedAnimation(_Palette.completed),
          ),
        ),
      ],
    );
  }

  Widget _reviewStat(String label, dynamic value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: _Palette.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _dayPlannerBody() {
    final planner = _detail!['dayPlanner'];
    final days = List<Map<String, dynamic>>.from(planner['days'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _reviewStat('Submitted', planner['submittedDays'], _Palette.completed),
            _reviewStat('Missed', planner['missedDays'], _Palette.rejected),
            _reviewStat('Morning', planner['morningSubmittedCount'], _Palette.processing),
            _reviewStat('Evening', planner['eveningSubmittedCount'], _Palette.primary),
          ],
        ),
        const SizedBox(height: 12),
        if (days.isEmpty)
          const Text('No planner activity in this period', style: TextStyle(fontSize: 11.5, color: _Palette.muted))
        else
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: days.map((d) {
              final morning = d['morningSubmitted'] == true;
              final evening = d['eveningSubmitted'] == true;
              final color = morning && evening
                  ? _Palette.completed
                  : (morning || evening ? _Palette.onHold : _Palette.border);
              final date = DateTime.tryParse(d['date'].toString());
              return Tooltip(
                message: '${date != null ? DateFormat('dd MMM').format(date) : d['date']}\nMorning: ${morning ? "yes" : "no"}  Evening: ${evening ? "yes" : "no"}',
                child: Container(width: 20, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Consistency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Palette.muted)),
            const Spacer(),
            Text('${planner['consistencyPct']}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _Palette.primary)),
          ],
        ),
      ],
    );
  }

  Widget _clientsBody(bool isMobile) {
    final clients = List<Map<String, dynamic>>.from(_detail!['clients'] ?? []);
    if (clients.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No clients/tasks found for this period', style: TextStyle(fontSize: 12, color: _Palette.muted))));
    }
    return Column(children: clients.map((c) => _clientCard(c, isMobile)).toList());
  }

  Widget _clientCard(Map<String, dynamic> client, bool isMobile) {
    final name = client['clientName'] as String;
    final expanded = _expandedClients.contains(name);
    final tasks = List<Map<String, dynamic>>.from(client['tasks'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _Palette.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _Palette.border)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => expanded ? _expandedClients.remove(name) : _expandedClients.add(name)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: _Palette.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.apartment_rounded, size: 17, color: _Palette.primary)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _Palette.ink)),
                        const SizedBox(height: 3),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          _miniBadge('${client['totalTasks']} tasks', _Palette.muted),
                          _miniBadge('${client['completionPct']}% done', _Palette.completed),
                          _miniBadge(client['totalDuration'] ?? '0m', _Palette.processing),
                          if ((client['ON HOLD'] ?? 0) > 0) _miniBadge('${client['ON HOLD']} hold', _Palette.onHold),
                          if ((client['REJECTED'] ?? 0) > 0) _miniBadge('${client['REJECTED']} rejected', _Palette.rejected),
                        ]),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: _Palette.muted),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(children: tasks.map((t) => _taskRow(t, isMobile)).toList()),
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

  Widget _taskRow(Map<String, dynamic> task, bool isMobile) {
    final status = task['status'] as String;
    final color = {
          'IDLE': _Palette.pending,
          'IN PROGRESS': _Palette.processing,
          'ON HOLD': _Palette.onHold,
          'COMPLETED': _Palette.completed,
          'REJECTED': _Palette.rejected,
        }[status] ??
        _Palette.muted;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _Palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task['deliverable'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _Palette.ink)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _miniBadge(task['roleName'] ?? '', _Palette.primary),
            _miniBadge(task['statusLabel'] ?? '', color),
            _miniBadge('Time: ${task['duration']}', _Palette.muted),
            _miniBadge('Perf: ${task['performance']}', _Palette.muted),
            if (task['reviewStatus'] != null && task['reviewStatus'] != '-') _miniBadge('Review: ${task['reviewStatus']}', _Palette.primary2),
          ]),
        ],
      ),
    );
  }

  Widget _timelineBody() {
    final timeline = List<Map<String, dynamic>>.from(_detail!['timeline'] ?? []);
    if (timeline.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('No recorded activity in this period', style: TextStyle(fontSize: 12, color: _Palette.muted))));
    }

    const icons = {
      'TASK_STARTED': Icons.play_circle_rounded,
      'TASK_COMPLETED': Icons.check_circle_rounded,
      'TASK_REJECTED': Icons.cancel_rounded,
      'PLANNER_SUBMITTED': Icons.assignment_turned_in_rounded,
      'MANAGER_APPROVED': Icons.verified_rounded,
      'MANAGER_REWORK': Icons.replay_circle_filled_rounded,
      'MANAGER_REJECTED': Icons.report_rounded,
    };
    const colors = {
      'TASK_STARTED': _Palette.processing,
      'TASK_COMPLETED': _Palette.completed,
      'TASK_REJECTED': _Palette.rejected,
      'PLANNER_SUBMITTED': _Palette.primary,
      'MANAGER_APPROVED': _Palette.completed,
      'MANAGER_REWORK': _Palette.onHold,
      'MANAGER_REJECTED': _Palette.rejected,
    };

    return Column(
      children: timeline.take(30).map((e) {
        final date = DateTime.tryParse(e['date'].toString());
        final icon = icons[e['type']] ?? Icons.circle;
        final color = colors[e['type']] ?? _Palette.muted;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(e['label'] ?? '', style: const TextStyle(fontSize: 12, color: _Palette.ink))),
              Text(date != null ? DateFormat('dd/MM HH:mm').format(date) : '', style: const TextStyle(fontSize: 10, color: _Palette.muted)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _errorBox(String message, VoidCallback onRetry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Palette.border)),
      child: Center(
        child: Column(children: [
          const Icon(Icons.cloud_off_rounded, size: 32, color: _Palette.muted),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(fontSize: 12, color: _Palette.muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry')),
        ]),
      ),
    );
  }

  Widget _emptyBox(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Palette.border)),
      child: Center(
        child: Column(children: [
          const Icon(Icons.people_outline_rounded, size: 32, color: _Palette.muted),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Palette.ink)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: _Palette.muted)),
        ]),
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final String? subValue;
  final IconData icon;
  final Color color;
  _KpiItem(this.label, this.value, this.subValue, this.icon, this.color);
}

class _Seg {
  final double pct;
  final Color color;
  _Seg(this.pct, this.color);
}

Widget _segmentBar(List<_Seg> segments) {
  final total = segments.fold<double>(0, (a, b) => a + b.pct);
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      height: 7,
      child: Row(
        children: segments.where((s) => s.pct > 0).map((s) {
          final flex = total > 0 ? (s.pct * 1000).round() : 1;
          return Expanded(flex: flex.clamp(1, 100000), child: Container(color: s.color));
        }).toList()
          ..addAll(total == 0 ? [Expanded(child: Container(color: _Palette.bg))] : []),
      ),
    ),
  );
}

/// Animated circular "ring" progress indicator with a percentage/label in
/// the center. Pure CustomPaint - no extra dependency needed.
class _AnimatedRing extends StatelessWidget {
  final double percent;
  final Color color;
  final double size;
  final double strokeWidth;
  final String centerText;

  const _AnimatedRing({
    required this.percent,
    required this.color,
    required this.size,
    required this.strokeWidth,
    required this.centerText,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (percent / 100).clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(progress: value, color: color, strokeWidth: strokeWidth),
              ),
              Text(centerText, style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  _RingPainter({required this.progress, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2;
    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}