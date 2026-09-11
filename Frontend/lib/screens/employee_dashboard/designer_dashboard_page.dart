// lib/screens/employee_dashboard/designer_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../services/api_config.dart';

import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/constants/app_text_styles.dart';
import 'package:godigital_portal/core/widgets/metric_card.dart';
import 'package:godigital_portal/core/widgets/status_badge.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/widgets/alerts_section.dart';
import 'package:godigital_portal/widgets/productivity_card.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class DesignerDashboardPage extends StatefulWidget {
  final VoidCallback? onOpenAssignedTask;
  final VoidCallback? onViewAllNotifications;

  const DesignerDashboardPage({
    super.key,
    this.onOpenAssignedTask,
    this.onViewAllNotifications,
  });

  @override
  State<DesignerDashboardPage> createState() => _DesignerDashboardPageState();
}

class _DesignerDashboardPageState extends State<DesignerDashboardPage> with TickerProviderStateMixin {
  static String get _baseUrl => ApiConfig.baseUrl;

  List<DesignerTaskModel> tasks = [];
  List<Map<String, dynamic>> recentNotifications = [];

  int assignedClients = 0;
  int activeTasks = 0;
  int holdTasks = 0;
  int rejectedTasks = 0;

  int approved = 0;
  int rejected = 0;
  int rework = 0;
  int review = 0;
  int others = 0;

  bool _loading = true;
  String? _error;
  String? _employeeName;
  late IO.Socket socket;

  // 🟢 Live Working Time State
  String totalWorkingTimeFormatted = "00h 00m";

  // 🟢 Animation Controllers
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _entranceController.forward();

    _fetchDashboardSummary();
    _fetchLiveWorkingTime();
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

    socket.on('task_updated', (data) {
      if (mounted) {
        _fetchDashboardSummary();
        _fetchLiveWorkingTime();
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    socket.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = context.read<AuthService>().user;
      _employeeName = (user?['fullName'] ?? user?['name'] ?? '') as String? ?? '';

      if (_employeeName == null || _employeeName!.isEmpty) {
        setState(() {
          _error = 'Employee name not found. Please re-login.';
          _loading = false;
        });
        return;
      }

      final r = await http.get(
        Uri.parse('$_baseUrl/dashboard/summary/${Uri.encodeComponent(_employeeName!)}'),
      );

      final n = await http.get(
        Uri.parse('$_baseUrl/dashboard/recent-notifications/${Uri.encodeComponent(_employeeName!)}'),
      );

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final data = body['data'] as Map<String, dynamic>? ?? {};

        final productivity = data['productivity'] as Map<String, dynamic>? ?? {};
        final rawTasks = List<dynamic>.from(data['tasks'] ?? []);

        List<Map<String, dynamic>> notificationData = [];
        if (n.statusCode == 200) {
          final notificationBody = jsonDecode(n.body);
          notificationData = List<Map<String, dynamic>>.from(notificationBody["data"] ?? []);
        }

        setState(() {
          assignedClients = data['assignedClients'] ?? 0;
          activeTasks = data['activeTasks'] ?? 0;
          holdTasks = data['onHoldCount'] ?? 0;
          rejectedTasks = data['rejectedTasks'] ?? 0;

          approved = productivity['approved'] ?? 0;
          rework = productivity['rework'] ?? 0;
          rejected = productivity['rejected'] ?? 0;
          review = productivity['review'] ?? 0;
          others = productivity['others'] ?? 0;

          recentNotifications = notificationData;

          tasks = rawTasks.map((t) {
            final action = t['action'] as String? ?? 'IDLE';
            final completedRows = t['completedRows'] ?? 0;
            final totalRows = t['totalRows'] ?? 0;

            return DesignerTaskModel(
              clientName: t['clientName'] ?? '',
              task: t['task'] ?? '',
              duration: t['duration'] ?? 'N/A',
              submissionDate: _formatDate(t['submissionDate']),
              dateLabel: _daysLeftLabel(t['submissionDate'], action),
              action: t['action'] ?? 'COMPLETED',
              status: t['status'] ?? '-',
              trackingItemId: t['trackingItemId'],
              completedLabel: '$completedRows/$totalRows',
              completedAllDone: totalRows > 0 && completedRows >= totalRows,
            );
          }).toList();

          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load dashboard (${r.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchLiveWorkingTime() async {
    if (_employeeName == null || _employeeName!.isEmpty) return;
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final response = await http.get(
        Uri.parse('$_baseUrl/dashboard/live-tracking-tasks/${Uri.encodeComponent(_employeeName!)}?date=$todayStr'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final rows = List<dynamic>.from(body['data'] ?? []);
        
        int totalSumSecs = 0;
        for (var row in rows) {
          final durSecs = _parseNum(row['duration_secs']);
          if (durSecs > 0) {
            totalSumSecs += durSecs.toInt();
          } else {
            String durStr = (row['duration'] ?? '').toString().toLowerCase();
            int hrs = 0;
            int mins = 0;
            if (durStr.contains('hr')) {
              final parts = durStr.split('hr');
              hrs = int.tryParse(parts[0].trim()) ?? 0;
              if (parts.length > 1 && parts[1].contains('min')) {
                mins = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              }
            } else if (durStr.contains('min')) {
              mins = int.tryParse(durStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            }
            totalSumSecs += (hrs * 3600) + (mins * 60);
          }
        }

        final h = totalSumSecs ~/ 3600;
        final m = (totalSumSecs % 3600) ~/ 60;

        if (mounted) {
          setState(() {
            totalWorkingTimeFormatted = '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching live working time: $e");
    }
  }

  String getTodayDate() {
    final now = DateTime.now();
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[now.month]} ${now.day.toString().padLeft(2, '0')}, ${now.year} - Today';
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

  String? _daysLeftLabel(String? raw, String action) {
    if (raw == null || raw.isEmpty) return null;
    if (action == 'COMPLETED' || action == 'REJECTED' || action == 'SUBMITTED') return null;
    try {
      final due = DateTime.parse(raw);
      final today = DateTime.now();
      final days = DateTime(due.year, due.month, due.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      if (days > 0) return '$days Day${days == 1 ? '' : 's'} Left';
      if (days == 0) return 'Due Today';
      return '${days.abs()} Day${days.abs() == 1 ? '' : 's'} Overdue';
    } catch (_) {
      return null;
    }
  }

  @override
  @override
Widget build(BuildContext context) {
  final user = context.watch<AuthService>().user;

  final String fullName =
      user?['fullName'] ??
      user?['name'] ??
      user?['username'] ??
      'Designer';

  final String roleTitle =
      user?['role'] ??
      'Creative Specialist';

  return FadeTransition(
    opacity: _fadeAnimation,
    child: SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(38, 30, 38, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _welcomeSection(fullName, roleTitle),

            const SizedBox(height: 26),

            _summaryCards(),

            const SizedBox(height: 24),

            // -------------------------------------------------
            // RECENT ALERTS + DAILY PRODUCTIVITY
            // -------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: AlertsSection(
                    notifications: recentNotifications,
                    onViewAll: widget.onViewAllNotifications,
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  flex: 3,
                  child: ProductivityCard(
                    approved: approved,
                    rework: rework,
                    rejected: rejected,
                    review: review,
                    others: others,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // -------------------------------------------------
            // MAIN TASK STATUS TABLE
            // -------------------------------------------------
            _taskStatusTable(),
          ],
        ),
      ),
    ),
  );
}

  Widget _welcomeSection(String name, String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF04296B), Color(0xFF0757D5), Color(0xFF1D74E8)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0757D5).withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.28)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF4ADE80)),
                          const SizedBox(width: 6),
                          Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded, size: 13, color: Color(0xFF93C5FD)),
                          const SizedBox(width: 6),
                          Text(
                            'Active Time: $totalWorkingTimeFormatted',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Welcome back, $name! ✨',
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Here is your live overview of today's GoDigital priorities, client tasks, and performance metrics.",
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 19,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  getTodayDate(),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            icon: Icons.groups_rounded,
            title: 'Assigned Clients',
            value: assignedClients.toString().padLeft(2, '0'),
            label: 'Current',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: MetricCard(
            icon: Icons.account_tree_rounded,
            title: 'Active Tasks',
            value: activeTasks.toString().padLeft(2, '0'),
            label: 'Current',
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: MetricCard(
            icon: Icons.pause_circle_rounded,
            title: 'Hold Task',
            value: holdTasks.toString().padLeft(2, '0'),
            label: 'Action required',
            color: AppColors.orange,
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: MetricCard(
            icon: Icons.cancel_rounded,
            title: 'Rejected Task',
            value: rejectedTasks.toString().padLeft(2, '0'),
            label: 'High Risk',
            color: AppColors.red,
          ),
        ),
      ],
    );
  }

  Widget _taskStatusTable() {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: const Color(0xFFE5ECF6),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0B5ED7).withOpacity(0.06),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        // =====================================================
        // PREMIUM TABLE HEADER
        // =====================================================
        Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF8FBFF),
                Color(0xFFF1F6FD),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE4EBF5),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0757D5),
                      Color(0xFF1D74E8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0757D5)
                          .withOpacity(0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.monitor_heart_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Task Status & Live Monitoring',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF172033),
                            letterSpacing: -0.3,
                          ),
                        ),

                        const SizedBox(width: 9),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LivePulse(),
                              const SizedBox(width: 5),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF15803D),
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${tasks.length} assigned task${tasks.length == 1 ? '' : 's'} currently being monitored',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B8798),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onOpenAssignedTask,
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFFD4E6FF),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All Assigned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0757D5),
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Color(0xFF0757D5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // =====================================================
        // TABLE
        // =====================================================
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 70),
            child: Column(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0757D5),
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Loading live task activity...',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8798),
                  ),
                ),
              ],
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 55),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFDC2626),
                    size: 25,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: _fetchDashboardSummary,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                  ),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0757D5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: Color(0xFF3B82F6),
                    size: 28,
                  ),
                ),

                const SizedBox(height: 13),

                const Text(
                  'No tasks assigned yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF334155),
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Your assigned tasks will appear here.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          )
        else
          _premiumTaskTableContent(),
      ],
    ),
  );
}

Widget _premiumTaskTableContent() {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SizedBox(
      width: 1100,
      child: Column(
        children: [
          _premiumTableHeader(),

          ...tasks.asMap().entries.map(
            (entry) => _premiumTaskRow(
              entry.value,
              entry.key,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _premiumTableHeader() {
  return Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: const BoxDecoration(
      color: Color(0xFFF8FAFD),
      border: Border(
        bottom: BorderSide(
          color: Color(0xFFE6ECF4),
        ),
      ),
    ),
    child: Row(
      children: [
        _headerCell(
          icon: Icons.business_rounded,
          title: 'CLIENT',
          flex: 20,
        ),
        _headerCell(
          icon: Icons.assignment_rounded,
          title: 'TASK',
          flex: 22,
        ),
        _headerCell(
          icon: Icons.schedule_rounded,
          title: 'TIME / DURATION',
          flex: 17,
        ),
        _headerCell(
          icon: Icons.event_available_rounded,
          title: 'DUE DATE',
          flex: 18,
        ),
        _headerCell(
          icon: Icons.flash_on_rounded,
          title: 'ACTION',
          flex: 14,
        ),
        _headerCell(
          icon: Icons.track_changes_rounded,
          title: 'STATUS',
          flex: 14,
        ),
        _headerCell(
          icon: Icons.task_alt_rounded,
          title: 'COMPLETION',
          flex: 15,
        ),
      ],
    ),
  );
}

Widget _headerCell({
  required IconData icon,
  required String title,
  required int flex,
}) {
  return Expanded(
    flex: flex,
    child: Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
            letterSpacing: 0.55,
          ),
        ),
      ],
    ),
  );
}

Widget _premiumTaskRow(
  DesignerTaskModel task,
  int index,
) {
  return _PremiumTaskRow(
    task: task,
    index: index,
  );
}

  Widget _tableHeader() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('CLIENT', style: AppTextStyles.tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text('TASKS', style: AppTextStyles.tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text('TIME/DURATION', style: AppTextStyles.tableHeader),
          ),
          Expanded(
            flex: 3,
            child: Text('DUE DATE', style: AppTextStyles.tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text('ACTION', style: AppTextStyles.tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text('STATUS', style: AppTextStyles.tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text("COMPLETED TASK", style: AppTextStyles.tableHeader),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(DesignerTaskModel task) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(task.clientName, style: AppTextStyles.tableText, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(task.task, style: AppTextStyles.tableText, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(
              task.duration,
              style: AppTextStyles.tableText,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.submissionDate, style: AppTextStyles.tableText),
                if (task.dateLabel != null)
                  Text(
                    task.dateLabel!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: task.dateLabel!.contains('1') || task.dateLabel!.contains('Overdue')
                          ? AppColors.orange
                          : AppColors.green,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(text: task.action),
            ),
          ),
          Expanded(
            flex: 2,
            child: StatusBadge(text: task.status),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                task.completedLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: task.completedAllDone ? const Color(0xFF16A34A) : const Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DesignerTaskModel {
  final String clientName;
  final String task;
  final String duration;
  final String submissionDate;
  final String? dateLabel;
  final int? trackingItemId;
  final String completedLabel;
  final bool completedAllDone;
  String action;
  String status;

  DesignerTaskModel({
    required this.clientName,
    required this.task,
    required this.duration,
    required this.submissionDate,
    required this.dateLabel,
    required this.action,
    required this.status,
    this.trackingItemId,
    required this.completedLabel,
    required this.completedAllDone,
  });
}

num _parseNum(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val;
  return num.tryParse(val.toString()) ?? 0;
}


class _PremiumTaskRow extends StatefulWidget {
  final DesignerTaskModel task;
  final int index;

  const _PremiumTaskRow({
    required this.task,
    required this.index,
  });

  @override
  State<_PremiumTaskRow> createState() => _PremiumTaskRowState();
}

class _PremiumTaskRowState extends State<_PremiumTaskRow> {
  bool _hovered = false;

  DesignerTaskModel get task => widget.task;

  @override
  Widget build(BuildContext context) {
    final completed = _completedValue(task.completedLabel);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: _hovered
              ? const Color(0xFFF5F9FF)
              : Colors.white,
          border: const Border(
            bottom: BorderSide(
              color: Color(0xFFEDF1F6),
            ),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF0B5ED7)
                        .withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // CLIENT
            Expanded(
              flex: 20,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF1F6FD),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      size: 17,
                      color: Color(0xFF2563EB),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      task.clientName.isEmpty
                          ? 'Unknown Client'
                          : task.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TASK
            Expanded(
              flex: 22,
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_rounded,
                    size: 15,
                    color: Color(0xFF94A3B8),
                  ),

                  const SizedBox(width: 7),

                  Expanded(
                    child: Text(
                      task.task,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // DURATION
            Expanded(
              flex: 17,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(width: 7),

                  Expanded(
                    child: Text(
                      task.duration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // DUE DATE
            Expanded(
              flex: 18,
              child: _dueDateWidget(task),
            ),

            // ACTION
            Expanded(
              flex: 14,
              child: _premiumStatusPill(
                task.action,
                _actionColor(task.action),
                _actionIcon(task.action),
              ),
            ),

            // STATUS
            Expanded(
              flex: 14,
              child: _premiumStatusPill(
                task.status,
                _statusColor(task.status),
                _statusIcon(task.status),
              ),
            ),

            // COMPLETION
            Expanded(
              flex: 15,
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: completed,
                        backgroundColor:
                            const Color(0xFFE8EEF6),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                          task.completedAllDone
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 9),

                  Text(
                    task.completedLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: task.completedAllDone
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),

            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _hovered ? 22 : 0,
              child: _hovered
                  ? const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFF2563EB),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueDateWidget(DesignerTaskModel task) {
    final label = task.dateLabel;

    Color color = const Color(0xFF64748B);
    Color bg = const Color(0xFFF1F5F9);
    IconData icon = Icons.event_rounded;

    if (label != null) {
      if (label.contains('Overdue')) {
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFFF1F2);
        icon = Icons.warning_rounded;
      } else if (label == 'Due Today') {
        color = const Color(0xFFD97706);
        bg = const Color(0xFFFFF7ED);
        icon = Icons.priority_high_rounded;
      } else {
        color = const Color(0xFF15803D);
        bg = const Color(0xFFF0FDF4);
        icon = Icons.schedule_rounded;
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                task.submissionDate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),

        if (label != null) ...[
          const SizedBox(height: 5),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 9,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _premiumStatusPill(
    String value,
    Color color,
    IconData icon,
  ) {
    final display =
        value.trim().isEmpty ? '-' : value;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 115,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _completedValue(String value) {
    try {
      final parts = value.split('/');
      if (parts.length != 2) return 0;

      final done = double.tryParse(parts[0]) ?? 0;
      final total = double.tryParse(parts[1]) ?? 0;

      if (total <= 0) return 0;

      return (done / total).clamp(0.0, 1.0);
    } catch (_) {
      return 0;
    }
  }

  Color _actionColor(String value) {
    switch (value.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF16A34A);
      case 'SUBMITTED':
        return const Color(0xFF2563EB);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'HOLD':
      case 'ON HOLD':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _actionIcon(String value) {
    switch (value.toUpperCase()) {
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'SUBMITTED':
        return Icons.upload_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      case 'HOLD':
      case 'ON HOLD':
        return Icons.pause_circle_rounded;
      default:
        return Icons.flash_on_rounded;
    }
  }

  Color _statusColor(String value) {
    final v = value.toUpperCase();

    if (v.contains('APPROV')) {
      return const Color(0xFF16A34A);
    }

    if (v.contains('REJECT')) {
      return const Color(0xFFDC2626);
    }

    if (v.contains('REWORK')) {
      return const Color(0xFFD97706);
    }

    if (v.contains('REVIEW')) {
      return const Color(0xFF7C3AED);
    }

    if (v.contains('HOLD')) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF2563EB);
  }

  IconData _statusIcon(String value) {
    final v = value.toUpperCase();

    if (v.contains('APPROV')) {
      return Icons.verified_rounded;
    }

    if (v.contains('REJECT')) {
      return Icons.block_rounded;
    }

    if (v.contains('REWORK')) {
      return Icons.replay_rounded;
    }

    if (v.contains('REVIEW')) {
      return Icons.rate_review_rounded;
    }

    if (v.contains('HOLD')) {
      return Icons.pause_circle_rounded;
    }

    return Icons.track_changes_rounded;
  }
}

class _LivePulse extends StatefulWidget {
  const _LivePulse();

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Container(
          width: 6 + (_controller.value * 2),
          height: 6 + (_controller.value * 2),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withOpacity(
                  0.25 + (_controller.value * 0.3),
                ),
                blurRadius: 5 + (_controller.value * 4),
              ),
            ],
          ),
        );
      },
    );
  }
}