import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:godigital_portal/widgets/alerts_section.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static String get _baseUrl => ApiConfig.baseUrl;

  String _selectedDateRange = "This Week";
  final List<String> _dateOptions = ["Today", "This Week", "This Month"];
  String _activePerformanceView = "Client";

  bool _loadingStats = true;
  String? _statsError;

  int _totalClients = 0;
  int _activeClients = 0;
  int _inactiveClients = 0;
  int _pendingTasks = 0;
  String? _employeeName;

  bool _loadingPerformance = true;

  // Performance lists with safe fallback mocks if backend lists are empty
  List<dynamic> _topEmployees = [
    {"name": "Mithra", "approved": 5, "rework": 2, "review": 1, "rejected": 0},
    {"name": "Pavithra", "approved": 4, "rework": 1, "review": 2, "rejected": 1},
    {"name": "Arun", "approved": 6, "rework": 0, "review": 1, "rejected": 0},
    {"name": "Susan", "approved": 2, "rework": 3, "review": 0, "rejected": 2},
    {"name": "Susheel", "approved": 5, "rework": 1, "review": 1, "rejected": 0},
    {"name": "Subha", "approved": 3, "rework": 2, "review": 2, "rejected": 0},
  ];

  List<dynamic> _clientPerformance = [
    {"name": "GA Mall", "approved": 8, "rework": 1, "review": 2, "rejected": 0},
    {"name": "Wash Monkey", "approved": 6, "rework": 2, "review": 1, "rejected": 1},
    {"name": "Ayyanar", "approved": 5, "rework": 0, "review": 3, "rejected": 0},
    {"name": "Star Hotel", "approved": 4, "rework": 2, "review": 0, "rejected": 1},
  ];

  Map<String, dynamic> _productivity = {
    "ratios": {"approved": 0.50, "rework": 0.20, "rejected": 0.15, "review": 0.15}
  };

  List<Map<String, dynamic>> _recentNotifications = [];

  bool _loadingNotifications = false;

  List<Map<String, dynamic>> _previewRows = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchDashboardData(),
      _fetchPerformanceAnalytics(),
      _fetchDashboardAnalytics(),
  _fetchRecentNotifications(),
    ]);
  }

  // Safe fetch for recent notifications using general fallback or admin streams
  Future<void> _fetchRecentNotifications() async {
  try {
    final response = await http.get(
  Uri.parse("$_baseUrl/dashboard/admin-notifications"),
);

    print("Status : ${response.statusCode}");
    print("Body : ${response.body}");

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      setState(() {
        _recentNotifications = List<Map<String, dynamic>>.from(
          body["data"] ?? [],
        );
      });

      print(_recentNotifications);
    }
  } catch (e) {
    print(e);
  }
}
  
  
  Future<void> _fetchDashboardData() async {
    setState(() { _loadingStats = true; _statsError = null; });

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/clients')),
        http.get(Uri.parse('$_baseUrl/admin/employee-status')),
      ]);

      if (results[0].statusCode != 200 || results[1].statusCode != 200) {
        setState(() { _loadingStats = false; });
        return;
      }

      final clients = List<dynamic>.from(jsonDecode(results[0].body)['data'] ?? []);
      final statusRows = List<dynamic>.from(jsonDecode(results[1].body)['data'] ?? []);

      int active = 0;
      int inactive = 0;
      for (final c in clients) {
        final status = (c['status'] as String? ?? '').toLowerCase();
        if (status == 'verified' || status == 'complete') {
          active++;
        } else if (status == 'draft') {
          inactive++;
        }
      }

      int pending = 0;
      for (final r in statusRows) {
        final status = (r['status'] as String? ?? 'IDLE').toUpperCase();
        if (status != 'COMPLETED') pending++;
      }

      setState(() {
        _totalClients = clients.length;
        _activeClients = active;
        _inactiveClients = inactive;
        _pendingTasks = pending;
        _previewRows = statusRows.take(3).map((r) => _mapPreviewRow(r)).toList();
        _loadingStats = false;
      });
    } catch (e) {
      setState(() { _loadingStats = false; });
    }
  }

  Future<void> _fetchPerformanceAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/performance/analytics"),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json["data"];
        if (data["productivity"] != null) {
          setState(() {
            _productivity = Map<String, dynamic>.from(data["productivity"] ?? {});
          });
        }
      }
    } catch (e) {
      debugPrint("Performance Analytics Error: $e");
    }
  }

  Future<void> _fetchDashboardAnalytics() async {
    setState(() => _loadingPerformance = true);
    try {
      String queryParam = "week";
      if (_selectedDateRange == "Today") queryParam = "today";
      if (_selectedDateRange == "This Month") queryParam = "month";

      final response = await http.get(
        Uri.parse("$_baseUrl/performance/dashboard-analytics?range=$queryParam"),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json["data"] ?? {};

        final fetchedEmployees = List<Map<String, dynamic>>.from(data["employeePerformance"] ?? []);
        final fetchedClients = List<Map<String, dynamic>>.from(data["clientPerformance"] ?? []);

        setState(() {
          if (fetchedEmployees.isNotEmpty) _topEmployees = fetchedEmployees;
          if (fetchedClients.isNotEmpty) _clientPerformance = fetchedClients;
          _loadingPerformance = false;
        });
      } else {
        setState(() => _loadingPerformance = false);
      }
    } catch (e) {
      debugPrint("Dashboard Analytics Error: $e");
      setState(() => _loadingPerformance = false);
    }
  }

  // Stacked Bar Chart for Work Performance matching 🟢 Approved, 🟠 Rework, 🔵 Review, 🔴 Rejected
  BarChartData _buildPerformanceBarChart() {
    final items = _activePerformanceView == "Client" ? _clientPerformance : _topEmployees;

    double maxVal = 10;
    for (var item in items) {
      double total = ((item["approved"] ?? 0) + (item["rework"] ?? 0) + (item["review"] ?? 0) + (item["rejected"] ?? 0)).toDouble();
      if (total > maxVal) maxVal = total + 2;
    }

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxVal,
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              if (index < 0 || index >= items.length) return const SizedBox();
              String name = items[index]["name"] ?? "Unknown";
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  name.length > 8 ? "${name.substring(0, 6)}.." : name,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
              );
            },
            reservedSize: 32,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: maxVal > 10 ? 5 : 2),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(items.length, (index) {
        final element = items[index];
        final approvedVal = (element["approved"] ?? 0).toDouble();
        final reworkVal = (element["rework"] ?? 0).toDouble();
        final reviewVal = (element["review"] ?? 0).toDouble();
        final rejectedVal = (element["rejected"] ?? 0).toDouble();

        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: approvedVal + reworkVal + reviewVal + rejectedVal,
              rodStackItems: [
                BarChartRodStackItem(0, approvedVal, const Color(0xFF16A34A)), // 🟢 Approved
                BarChartRodStackItem(approvedVal, approvedVal + reworkVal, const Color(0xFFE67E00)), // 🟠 Rework
                BarChartRodStackItem(approvedVal + reworkVal, approvedVal + reworkVal + reviewVal, const Color(0xFF2A52BE)), // 🔵 Review
                BarChartRodStackItem(approvedVal + reworkVal + reviewVal, approvedVal + reworkVal + reviewVal + rejectedVal, const Color(0xFFE10000)), // 🔴 Rejected
              ],
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }),
    );
  }

  Map<String, dynamic> _mapPreviewRow(dynamic row) {
    final employeeName = row['employeeName'] as String? ?? 'Unassigned';
    final priority = (row['priority'] as String? ?? 'LOW').toUpperCase();
    final rawStatus = (row['status'] as String? ?? 'IDLE').toUpperCase();
    final daysLeft = row['daysLeft'] as int?;

    return {
      "client": row['clientName'] ?? '',
      "initials": _initialsFor(employeeName),
      "name": employeeName,
      "task": row['task'] ?? '',
      "duration": row['duration'] ?? 'N/A',
      "priority": priority,
      "date": _formatDate(row['submissionDate'] as String?),
      "timeLeft": _timeLeftDisplay(daysLeft).$1,
      "timeColor": _timeLeftDisplay(daysLeft).$2,
      "status": _statusDisplay(rawStatus).$1,
      "statusBg": _statusDisplay(rawStatus).$2,
      "statusText": _statusDisplay(rawStatus).$3,
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

  (String, Color, Color) _statusDisplay(String rawStatus) {
    switch (rawStatus) {
      case 'IDLE': return ('NOT STARTED', const Color(0xFFF1F5F9), const Color(0xFF64748B));
      case 'IN PROGRESS': return ('IN PROGRESS', const Color(0xFFE0F2FE), const Color(0xFF0369A1));
      case 'ON HOLD': return ('ON HOLD', const Color(0xFFFEF3C7), const Color(0xFFD97706));
      case 'COMPLETED': return ('COMPLETED', const Color(0xFFDCFCE7), const Color(0xFF16A34A));
      case 'REJECTED': return ('REJECTED', const Color(0xFFFEE2E2), const Color(0xFFDC2626));
      default: return (rawStatus, const Color(0xFFF1F5F9), const Color(0xFF64748B));
    }
  }

  (String, Color) _timeLeftDisplay(int? daysLeft) {
    if (daysLeft == null) return ('--', const Color(0xFF64748B));
    if (daysLeft > 0) return ('$daysLeft Day${daysLeft == 1 ? '' : 's'} Left', const Color(0xFF22C55E));
    if (daysLeft == 0) return ('Due Today', const Color(0xFFD97706));
    final overdue = daysLeft.abs();
    return ('$overdue Day${overdue == 1 ? '' : 's'} Overdue', const Color(0xFFDC2626));
  }

  String _timeAgo(String raw) {
    if (raw.isEmpty) return "";
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return "JUST NOW";
      if (diff.inMinutes < 60) return "${diff.inMinutes} MINS AGO";
      if (diff.inHours < 24) return "${diff.inHours} HOURS AGO";
      return "${diff.inDays} DAYS AGO";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final String dynamicTodayString = "${months[now.month - 1]} ${now.day}, ${now.year}";

    return AdminLayout(
      pageTitle: "Dashboard",
      currentRoute: "/admin",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome Admin", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  SizedBox(height: 6),
                  Text("Here is an overview of today's GoDigital priorities and performance metrics.", style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                ],
              ),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF1E293B)),
                    const SizedBox(width: 8),
                    Text("$dynamicTodayString - ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDateRange,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0052CC)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                        items: _dateOptions.map((String option) {
                          return DropdownMenuItem<String>(value: option, child: Text(option));
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedDateRange = newValue!;
                            _fetchDashboardAnalytics();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Stat Cards
          Row(
            children: [
              Expanded(child: _buildStatCard(icon: Icons.people_alt_rounded, headerColor: const Color(0xFF2A52BE), label: 'Total Clients', value: _loadingStats ? '—' : _totalClients.toString(), bottom: const Text('All onboarded clients', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))))),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(icon: Icons.groups_rounded, headerColor: const Color(0xFF16A34A), label: 'Active Client', value: _loadingStats ? '—' : _activeClients.toString(), bottom: const Text('Verified / complete', style: TextStyle(fontSize: 12, color: Color(0xFF475569))))),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(icon: Icons.assignment_late_outlined, headerColor: const Color(0xFFE67E00), label: 'Client Pending Task', value: _loadingStats ? '—' : _pendingTasks.toString(), bottom: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFB91C1C), borderRadius: BorderRadius.circular(20)), child: const Text('Requires Attention', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))))),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(icon: Icons.cancel_outlined, headerColor: const Color(0xFFE10000), label: 'In Active Clients', value: _loadingStats ? '—' : _inactiveClients.toString(), bottom: const Text('Still in draft', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))))),
            ],
          ),
          const SizedBox(height: 32),

          // Work Performance Stack & Bar Analytics
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  height: 380,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Work Performance Stack", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              children: [
                                _buildPerformanceViewToggleItem("Client"),
                                _buildPerformanceViewToggleItem("Employee"),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)), SizedBox(width: 4), Text("Approved", style: TextStyle(fontSize: 10)), SizedBox(width: 8),
                          Icon(Icons.circle, size: 8, color: Color(0xFFE67E00)), SizedBox(width: 4), Text("Rework", style: TextStyle(fontSize: 10)), SizedBox(width: 8),
                          Icon(Icons.circle, size: 8, color: Color(0xFF2A52BE)), SizedBox(width: 4), Text("Review", style: TextStyle(fontSize: 10)), SizedBox(width: 8),
                          Icon(Icons.circle, size: 8, color: Color(0xFFE10000)), SizedBox(width: 4), Text("Rejected", style: TextStyle(fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _loadingPerformance
                            ? const Center(child: CircularProgressIndicator())
                            : BarChart(_buildPerformanceBarChart()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Donut Chart Metric Summary
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  height: 380,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    children: [
                      const Text("Daily Productivity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(160, 160),
                              painter: HighFidelityDonutChartPainter(
                                approved: (_productivity["ratios"]?["approved"] ?? 0.43).toDouble(),
                                rework: (_productivity["ratios"]?["rework"] ?? 0.29).toDouble(),
                                rejected: (_productivity["ratios"]?["rejected"] ?? 0.14).toDouble(),
                                review: (_productivity["ratios"]?["review"] ?? 0.14).toDouble(),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text("100%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                Text("Total", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildLegendRow("Approved", "${((_productivity["ratios"]?["approved"] ?? 0.43) * 100).toStringAsFixed(0)}%", const Color(0xFF16A34A)),
                      _buildLegendRow("Reworks", "${((_productivity["ratios"]?["rework"] ?? 0.29) * 100).toStringAsFixed(0)}%", const Color(0xFFE67E00)),
                      _buildLegendRow("Rejected", "${((_productivity["ratios"]?["rejected"] ?? 0.14) * 100).toStringAsFixed(0)}%", const Color(0xFFE10000)),
                      _buildLegendRow("Review", "${((_productivity["ratios"]?["review"] ?? 0.14) * 100).toStringAsFixed(0)}%", const Color(0xFF2A52BE)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // _buildAlertsSection(context),
          AlertsSection(
  notifications: _recentNotifications,
  onViewAll: () {
    Navigator.pushNamed(context, "/notifications");
  },
),
        ],
      ),
    );
  }

  Widget _buildPerformanceViewToggleItem(String label) {
    final bool isSelected = _activePerformanceView == label;
    return GestureDetector(
      onTap: () => setState(() => _activePerformanceView = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected ? const [BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? const Color(0xFF0052CC) : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required Color headerColor, required String label, required String value, required Widget bottom}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFDBE5F5), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              children: [
                Container(width: 40, height: 40, color: headerColor, child: Icon(icon, color: Colors.white, size: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 40,
                    color: headerColor,
                    alignment: Alignment.center,
                    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF111C24)))),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: SizedBox(height: 22, child: Center(child: bottom))),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text("Alerts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pushNamed(context, "/notifications"),
                child: const Text("View All Notifications", style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: List.generate(
                _recentNotifications.length > 3 ? 3 : _recentNotifications.length,
                (index) {
                  final item = _recentNotifications[index];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 2 ? 0 : 16),
                      child: _buildAlertCard(item),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> item) {
    final title = item["title"] ?? "Notification";
    final message = item["message"] ?? "";
    final time = _timeAgo(item["created_at"] ?? "");

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(left: BorderSide(color: Color(0xFF2563EB), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String t, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [Container(width: 8, height: 8, color: c), const SizedBox(width: 8), Text(t)]),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold))
    ]),
  );
}

class HighFidelityDonutChartPainter extends CustomPainter {
  final double approved;
  final double rework;
  final double rejected;
  final double review;

  HighFidelityDonutChartPainter({
    required this.approved,
    required this.rework,
    required this.rejected,
    required this.review,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    final segments = [
      {"value": approved, "color": const Color(0xFF16A34A)},
      {"value": rework, "color": const Color(0xFFE67E00)},
      {"value": review, "color": const Color(0xFF2A52BE)},
      {"value": rejected, "color": const Color(0xFFE10000)},
    ];

    double startAngle = -math.pi / 2;

    for (final seg in segments) {
      final value = seg["value"] as double;
      final color = seg["color"] as Color;
      final sweep = value * 2 * math.pi;

      if (sweep > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweep,
          false,
          paint..color = color,
        );
        startAngle += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant HighFidelityDonutChartPainter oldDelegate) {
    return approved != oldDelegate.approved ||
        rework != oldDelegate.rework ||
        rejected != oldDelegate.rejected ||
        review != oldDelegate.review;
  }
}