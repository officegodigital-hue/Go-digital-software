import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../layouts/admin_layout.dart';
import 'package:fl_chart/fl_chart.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  String _activeView = "Client";
  String _activePeriod = "Monthly";
  Offset? _hoverPosition;
  String _hoveredSegment = "";
LineChartData _buildChart() {
  final labels = _activePeriod == "Weekly"
      ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
      : _activePeriod == "Monthly"
          ? ["W1", "W2", "W3", "W4"]
          : ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

  final data = _activeView == "Client"
      ? (_activePeriod == "Weekly"
          ? [65, 72, 68, 85, 90, 78, 95]
          : _activePeriod == "Monthly"
              ? [78, 88, 70, 96]
              : [42,55,47,63,58,77,68,80,74,84,78,91])
      : (_activePeriod == "Weekly"
          ? [55, 62, 60, 72, 80, 75, 88]
          : _activePeriod == "Monthly"
              ? [70, 76, 82, 92]
              : [35,48,42,59,55,70,62,75,69,82,74,89]);

  return LineChartData(
    minY: 0,
    maxY: 100,
    gridData: const FlGridData(show: true),
    borderData: FlBorderData(show: true),

    titlesData: FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 20,
        ),
      ),

      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            int i = value.toInt();

            if (i >= labels.length) {
              return const SizedBox();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                labels[i],
                style: const TextStyle(fontSize: 11),
              ),
            );
          },
        ),
      ),
    ),

    lineBarsData: [
      LineChartBarData(
        isCurved: true,
        color: const Color(0xFF4F46E5),
        barWidth: 4,
        dotData: const FlDotData(show: true),

        spots: List.generate(
          data.length,
          (index) => FlSpot(
            index.toDouble(),
            data[index].toDouble(),
          ),
        ),
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: "Performance",
      currentRoute: "/performance",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Performance Overview", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 28),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── LEFT: WORK PERFORMANCE LINE GRAPH ──
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  height: 400,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Work Performance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          Row(children: [_buildToggleRow(["Weekly", "Monthly", "Yearly"], _activePeriod, (v) => setState(() => _activePeriod = v)), const SizedBox(width: 10), _buildToggleRow(["Client", "Employee"], _activeView, (v) => setState(() => _activeView = v))]),
                        ],
                      ),
                      const SizedBox(height: 20),
                  //     Expanded(
                  //       child: GestureDetector(
                  //         onPanUpdate: (d) => setState(() => _hoverPosition = d.localPosition),
                  //         onPanEnd: (_) => setState(() => _hoverPosition = null),
                  //         child: CustomPaint(
                  //           size: Size.infinite,
                  //           painter: PerformanceSplinePainter(viewMode: _activeView, period: _activePeriod, hoverPos: _hoverPosition),
                  //         ),
                  //       ),
                  //     ),// Replace your existing Expanded stack block with this:
                  Expanded(
  child: Padding(
    padding: const EdgeInsets.only(top: 10),
    child: LineChart(
      _buildChart(),
    ),
  ),
),
                   ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // ── RIGHT: DAILY PRODUCTIVITY DONUT ──
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  height: 400,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    children: [
                      const Text("Daily Productivity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 30),
                      Expanded(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Donut Chart
            CustomPaint(
              size: const Size(180, 180),
              painter: HighFidelityDonutChartPainter(),
            ),
            // Center Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text("100%", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text("Total", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
                      _buildLegendRow("Approved", "62%", const Color(0xFF16A34A)),
                      _buildLegendRow("Reworks", "18%", const Color(0xFFE67E00)),
                      _buildLegendRow("Rejected", "10%", const Color(0xFFE10000)),
                      _buildLegendRow("Others", "10%", const Color(0xFF2A52BE)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(List<String> items, String active, Function(String) onTap) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.all(2),
      child: Row(children: items.map((l) => GestureDetector(
        onTap: () => onTap(l),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: active == l ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(4)),
          child: Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active == l ? const Color(0xFF0052CC) : const Color(0xFF64748B))),
        ),
      )).toList()),
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

// ── PAINTER LOGIC ──

class PerformanceSplinePainter extends CustomPainter {
  final String viewMode; final String period; final Offset? hoverPos;
  PerformanceSplinePainter({required this.viewMode, required this.period, this.hoverPos});

  @override
  void paint(Canvas canvas, Size size) {
    Paint p = Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    Path path = Path();
    path.moveTo(0, size.height * 0.6);
    path.cubicTo(size.width * 0.25, size.height * 0.3, size.width * 0.75, size.height * 0.7, size.width, size.height * 0.2);
    canvas.drawPath(path, p..color = const Color(0xFF2A52BE));
    
    // Draw dots
    for (double i = 0; i <= 1.0; i += 0.25) {
      canvas.drawCircle(Offset(size.width * i, size.height * (0.6 - (i*0.2))), 6, Paint()..color = const Color(0xFF2A52BE));
    }
    
    // Hover Tooltip
    if (hoverPos != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hoverPos!.dx, hoverPos!.dy - 40, 80, 30), const Radius.circular(4)), Paint()..color = Colors.black);
      TextPainter tp = TextPainter(text: const TextSpan(text: "Data", style: TextStyle(color: Colors.white)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(hoverPos!.dx + 10, hoverPos!.dy - 35));
    }
  }
  @override
  bool shouldRepaint(covariant PerformanceSplinePainter oldDelegate) => true;
}

class HighFidelityDonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0;

    // Define colors mapping to your labels
    final List<Map<String, dynamic>> segments = [
      {"val": 0.62, "color": const Color(0xFF16A34A)}, // Approved (Green)
      {"val": 0.18, "color": const Color(0xFFE67E00)}, // Reworks (Orange)
      {"val": 0.10, "color": const Color(0xFFE10000)}, // Rejected (Red)
      {"val": 0.10, "color": const Color(0xFF2A52BE)}, // Others (Blue)
    ];

    double startAngle = -math.pi / 2;
    for (var seg in segments) {
      double sweep = (2 * math.pi) * seg["val"] - 0.05;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius), 
        startAngle, 
        sweep, 
        false, 
        paint..color = seg["color"]
      );
      startAngle += sweep + 0.05;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}