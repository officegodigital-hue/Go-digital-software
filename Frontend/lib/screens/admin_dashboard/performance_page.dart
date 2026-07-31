import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../layouts/admin_layout.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart';
import 'package:intl/intl.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  String _activePeriod = "This Month";
  String _activeView = "Client";
  bool _loading = true;

  int _clientsCount = 0;
  int _employeesCount = 0;
  double _efficiencyPercent = 94.5;
  String _revenueString = "₹4.8L";

  List<double> _chartValues = [78, 88, 70, 96];
  List<String> _chartLabels = ["W1", "W2", "W3", "W4"];

  double _approvedShare = 0.62;
  double _reworkShare = 0.18;
  double _rejectedShare = 0.10;
  double _othersShare = 0.10;

  List<Map<String, dynamic>> _topEmployees = [];
  List<Map<String, dynamic>> _clientPerformances = [];

  int _completedTasksPercent = 80;
  int _pendingTasksPercent = 15;
  int _onHoldTasksPercent = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAnalyticsData();
    });
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/performance/analytics'));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'];
        final revenue = (data['estimatedRevenue'] ?? 0).toDouble();

        if (data != null) {
          setState(() {
            _clientsCount = data['clientsCount'] ?? 0;
            _employeesCount = data['employeesCount'] ?? 0;
            _efficiencyPercent = (data['efficiencyPercent'] ?? 94.5).toDouble();
            // _revenueString = data['estimatedRevenue'] ?? "₹4.8L";
            _revenueString = "₹${revenue.toStringAsFixed(0)}";

            // Productivity Donut shares
            final ratios = data['productivity']?['ratios'];
            if (ratios != null) {
              _approvedShare = (ratios['approved'] ?? 0.62).toDouble();
              _reworkShare = (ratios['rework'] ?? 0.18).toDouble();
              _rejectedShare = (ratios['rejected'] ?? 0.10).toDouble();
              _othersShare = (ratios['review'] ?? 0.10).toDouble();
            }

            // Top 10 Employees
            _topEmployees = List<Map<String, dynamic>>.from(data['topEmployees'] ?? []);

            // Client performance rankings
            _clientPerformances = List<Map<String, dynamic>>.from(data['clientPerformances'] ?? []);

            // Task distribution percentages
            final dist = data['taskStatusDistribution'];
            if (dist != null) {
              _completedTasksPercent = dist['completedPercent'] ?? 80;
              _pendingTasksPercent = dist['pendingPercent'] ?? 15;
              _onHoldTasksPercent = dist['holdPercent'] ?? 5;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Performance analytics error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }


  void _updateChartParameters(String period, String view) {
    setState(() {
      _activePeriod = period;
      _activeView = view;

      if (period == "This Week") {
        _chartLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        _chartValues = view == "Client" ? [65, 72, 68, 85, 90, 78, 95] : [55, 62, 60, 72, 80, 75, 88];
      } else if (period == "This Month") {
        _chartLabels = ["W1", "W2", "W3", "W4"];
        _chartValues = view == "Client" ? [78, 88, 70, 96] : [70, 76, 82, 92];
      } else if (period == "This Year") {
        _chartLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        _chartValues = view == "Client" ? [42, 55, 47, 63, 58, 77, 68, 80, 74, 84, 78, 91] : [35, 48, 42, 59, 55, 70, 62, 75, 69, 82, 74, 89];
      } else {
        _chartLabels = ["9AM", "11AM", "1PM", "3PM", "5PM", "7PM"];
        _chartValues = [70, 82, 75, 88, 92, 95];
      }
    });
  }

  LineChartData _buildLineChartData() {
    return LineChartData(
      minY: 0,
      maxY: 100,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (val) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 25,
            reservedSize: 28,
            getTitlesWidget: (value, meta) => Text(
              "${value.toInt()}%",
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              int idx = value.toInt();
              if (idx < 0 || idx >= _chartLabels.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _chartLabels[idx],
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          isCurved: true,
          color: const Color(0xFF0052CC),
          barWidth: 3.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4.5,
              color: Colors.white,
              strokeWidth: 2.5,
              strokeColor: const Color(0xFF0052CC),
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0052CC).withValues(alpha: 0.15),
                const Color(0xFF0052CC).withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          spots: List.generate(
            _chartValues.length,
            (index) => FlSpot(index.toDouble(), _chartValues[index]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: "Performance Dashboard",
      currentRoute: "/performance",
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0052CC)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(38, 24, 38, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Performance Dashboard",
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Real-time analytics across client execution, team productivity, and delivery metrics.",
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: ["Today", "This Week", "This Month", "This Year"].map((period) {
                            final isActive = _activePeriod == period;
                            return GestureDetector(
                              onTap: () => _updateChartParameters(period, _activeView),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFF0052CC) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  period,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard("Clients", "$_clientsCount", Icons.business_center_rounded, const Color(0xFF0052CC))),
                      const SizedBox(width: 20),
                      Expanded(child: _buildMetricCard("Employees", "$_employeesCount", Icons.group_rounded, const Color(0xFF0EA5E9))),
                      const SizedBox(width: 20),
                      Expanded(child: _buildMetricCard("Efficiency", "$_efficiencyPercent% ▲", Icons.trending_up_rounded, const Color(0xFF16A34A))),
                      const SizedBox(width: 20),
                      Expanded(child: _buildMetricCard("Revenue", _revenueString, Icons.account_balance_wallet_rounded, const Color(0xFF9333EA))),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          height: 420,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Performance Trend", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                    child: Row(
                                      children: ["Client", "Employee"].map((view) {
                                        final isSel = _activeView == view;
                                        return GestureDetector(
                                          onTap: () => _updateChartParameters(_activePeriod, view),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSel ? Colors.white : Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                              boxShadow: isSel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
                                            ),
                                            child: Text(
                                              view,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isSel ? const Color(0xFF0052CC) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                              Expanded(
                                child: LineChart(_buildLineChartData()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          height: 420,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Productivity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                              const SizedBox(height: 20),
                              Expanded(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 55,
                                        sections: [
                                          PieChartSectionData(color: const Color(0xFF16A34A), value: _approvedShare * 100, title: '', radius: 22),
                                          PieChartSectionData(color: const Color(0xFFE67E00), value: _reworkShare * 100, title: '', radius: 22),
                                          PieChartSectionData(color: const Color(0xFFE10000), value: _rejectedShare * 100, title: '', radius: 22),
                                          PieChartSectionData(color: const Color(0xFF0052CC), value: _othersShare * 100, title: '', radius: 22),
                                        ],
                                      ),
                                    ),
                                    const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text("100%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                        Text("Total", style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              _buildLegendRow("Approved", "${(_approvedShare * 100).toStringAsFixed(0)}%", const Color(0xFF16A34A)),
                              _buildLegendRow("Reworks", "${(_reworkShare * 100).toStringAsFixed(0)}%", const Color(0xFFE67E00)),
                              _buildLegendRow("Rejected", "${(_rejectedShare * 100).toStringAsFixed(0)}%", const Color(0xFFE10000)),
                              _buildLegendRow("Others", "${(_othersShare * 100).toStringAsFixed(0)}%", const Color(0xFF0052CC)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // Top 10 Performing Employees
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Top Performing Employees", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                        const SizedBox(height: 20),
                        _topEmployees.isEmpty
                            ? const Text("No employee performance records found.", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
                            : Column(
                                children: _topEmployees.map((emp) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFFEFF6FF),
                                            child: Text(emp["name"][0].toUpperCase(), style: const TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                          const SizedBox(width: 14),
                                          SizedBox(
                                            width: 120,
                                            child: Text(emp["name"], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                                          ),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: (emp["percent"] as int) / 100.0,
                                                backgroundColor: const Color(0xFFF1F5F9),
                                                color: const Color(0xFF0052CC),
                                                minHeight: 10,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Text("${emp["percent"]}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    )).toList(),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Task Status & Client Performance
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Task Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                              const SizedBox(height: 20),
                              _buildStatusRow("Completed", "$_completedTasksPercent%", const Color(0xFF16A34A), _completedTasksPercent / 100.0),
                              const SizedBox(height: 16),
                              _buildStatusRow("Pending", "$_pendingTasksPercent%", const Color(0xFFE67E00), _pendingTasksPercent / 100.0),
                              const SizedBox(height: 16),
                              _buildStatusRow("Hold", "$_onHoldTasksPercent%", const Color(0xFFE10000), _onHoldTasksPercent / 100.0),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Client Performance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                              const SizedBox(height: 20),
                              _clientPerformances.isEmpty
                                  ? const Text("No client ratings available.", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
                                  : Column(
                                      children: _clientPerformances.map((client) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.business_rounded, size: 16, color: Color(0xFF0052CC)),
                                                    const SizedBox(width: 10),
                                                    Text(client["name"], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text("${client["score"]}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0052CC), fontSize: 12)),
                                                ),
                                              ],
                                            ),
                                          )).toList(),
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
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String title, String percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            ],
          ),
          Text(percentage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF1F5F9),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}