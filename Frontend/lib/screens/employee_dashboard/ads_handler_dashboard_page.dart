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

class AdsHandlerDashboardPage extends StatefulWidget {
  final VoidCallback? onOpenAssignedTask;
  final VoidCallback? onViewAllNotifications;

  const AdsHandlerDashboardPage({
    super.key,
    this.onOpenAssignedTask,
    this.onViewAllNotifications,
  });

  @override
  State<AdsHandlerDashboardPage> createState() =>
      _AdsHandlerDashboardPageState();
}

class _AdsHandlerDashboardPageState extends State<AdsHandlerDashboardPage> {
  static String get _baseUrl => ApiConfig.baseUrl;

  List<AdsHandlerTaskModel> tasks = [];
  List<Map<String, dynamic>> recentNotifications = [];

  int assignedClients = 0;
  int activeClients = 0;
  int holdTasks = 0;
  int upcomingDeadlines = 0;

  int approved = 0;
  int rejected = 0;
  int rework = 0;
  int review = 0;
  int others = 0;

  bool _loading = true;
  String? _error;
  String? _employeeName;
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _fetchDashboardSummary();
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
      }
    });
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  String? _daysLeftLabel(String? raw, String action) {
    if (raw == null || raw.isEmpty) return null;
    if (action == 'COMPLETED' || action == 'REJECTED' || action == 'SUBMITTED') {
      return null;
    }
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
          notificationData = List<Map<String, dynamic>>.from(
            notificationBody["data"] ?? [],
          );
        }

        setState(() {
          assignedClients = data['assignedClients'] as int? ?? 0;
          activeClients = data['activeClients'] as int? ?? 0;
          holdTasks = data['onHoldCount'] ?? 0;
          upcomingDeadlines = data['upcomingDeadlines'] as int? ?? 0;
          approved = productivity['approved'] ?? 0;
          rework = productivity['rework'] ?? 0;
          rejected = productivity['rejected'] ?? 0;
          review = productivity['review'] ?? 0;
          others = productivity['others'] ?? 0;
          recentNotifications = notificationData;

          tasks = rawTasks.map((t) {
            final action = t['action'] ?? 'IDLE';
            final completedRows = t['completedRows'] ?? 0;
            final totalRows = t['totalRows'] ?? 0;

            return AdsHandlerTaskModel(
              clientName: t['clientName'] ?? '',
              task: t['task'] ?? '',
              duration: t['duration'] ?? 'N/A',
              submissionDate: _formatDate(t['submissionDate']),
              dateLabel: _daysLeftLabel(t['submissionDate'], action),
              action: action,
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

  String getTodayDate() {
    final now = DateTime.now();
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 38,
        isMobile ? 18 : 30,
        isMobile ? 16 : 38,
        30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _welcomeSection(),
          SizedBox(height: isMobile ? 20 : 28),
          _summaryCards(),
          SizedBox(height: isMobile ? 20 : 28),

          // -------------------------------------------------
          // RECENT ALERTS + DAILY PRODUCTIVITY
          // -------------------------------------------------
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AlertsSection(
                      notifications: recentNotifications,
                      onViewAll: widget.onViewAllNotifications,
                    ),
                    const SizedBox(height: 18),
                    ProductivityCard(
                      approved: approved,
                      rework: rework,
                      rejected: rejected,
                      review: review,
                      others: others,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: AlertsSection(
                      notifications: recentNotifications,
                      onViewAll: widget.onViewAllNotifications,
                    ),
                  ),
                  const SizedBox(width: 22),
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
              );
            },
          ),

          SizedBox(height: isMobile ? 20 : 28),

          // -------------------------------------------------
          // MAIN TASK STATUS TABLE
          // -------------------------------------------------
          _taskStatusTable(),
        ],
      ),
    );
  }

  Widget _welcomeSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width < 600 ? 20 : 28,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF04296B),
            Color(0xFF0757D5),
            Color(0xFF1D74E8),
          ],
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _welcomeContent(),
                    const SizedBox(height: 18),
                    _welcomeDate(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _welcomeContent()),
                    const SizedBox(width: 20),
                    _welcomeDate(),
                  ],
                );
        },
      ),
    );
  }

  Widget _welcomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _heroChip(
              icon: Icons.verified_rounded,
              iconColor: const Color(0xFF4ADE80),
              text: 'ADS HANDLER',
            ),
            _heroChip(
              icon: Icons.timer_rounded,
              iconColor: const Color(0xFF93C5FD),
              text: 'LIVE DASHBOARD',
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Welcome back! ✨',
          style: TextStyle(
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
    );
  }

  Widget _heroChip({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeDate() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded, size: 19, color: Colors.white),
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
    );
  }

  Widget _summaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 4 : 2;
        final gap = columns == 4 ? 22.0 : 14.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                icon: Icons.groups_rounded,
                title: 'Assigned Clients',
                value: assignedClients.toString().padLeft(2, '0'),
                label: 'Current',
                color: AppColors.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                icon: Icons.account_tree_outlined,
                title: 'Active Clients',
                value: activeClients.toString().padLeft(2, '0'),
                label: 'Current',
                color: AppColors.green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                icon: Icons.pause_circle_outline,
                title: 'Hold Task',
                value: holdTasks.toString().padLeft(2, '0'),
                label: 'Action required',
                color: AppColors.orange,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                icon: Icons.cancel_outlined,
                title: 'Upcoming Deadlines',
                value: upcomingDeadlines.toString().padLeft(2, '0'),
                label: 'High Risk',
                color: AppColors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _taskStatusTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5ECF6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B5ED7).withOpacity(0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;

          return Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 16 : 22,
                  mobile ? 16 : 20,
                  mobile ? 16 : 22,
                  mobile ? 16 : 18,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: mobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _taskHeaderIcon(),
                              const SizedBox(width: 11),
                              const Expanded(
                                child: Text(
                                  'Task Status & Live Monitoring',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                '${tasks.length} assigned task${tasks.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const Spacer(),
                              _liveBadge(),
                              const SizedBox(width: 8),
                              _viewAllButton(),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          _taskHeaderIcon(),
                          const SizedBox(width: 13),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Task Status & Live Monitoring',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Assigned tasks currently being monitored',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _liveBadge(),
                          const SizedBox(width: 12),
                          _viewAllButton(),
                        ],
                      ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 55),
                  child: CircularProgressIndicator(),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 35),
                  child: Column(
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _fetchDashboardSummary,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 55),
                  child: Text(
                    'No tasks assigned yet',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                )
              else if (mobile)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: tasks.map(_mobileTaskCard).toList(),
                  ),
                )
              else
                _premiumTaskTableContent(),
            ],
          );
        },
      ),
    );
  }

  Widget _taskHeaderIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0757D5), Color(0xFF1D74E8)],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0757D5).withOpacity(0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.monitor_heart_rounded,
        color: Colors.white,
        size: 21,
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: Color(0xFF16A34A)),
          SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: Color(0xFF15803D),
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewAllButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpenAssignedTask,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFD8E9FF)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileTaskCard(AdsHandlerTaskModel task) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5ECF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.clientName.isEmpty ? 'Client' : task.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(text: task.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            task.task,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.tableText,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _mobileInfo(Icons.timer_outlined, task.duration),
              _mobileInfo(Icons.calendar_month_outlined, task.submissionDate),
              _mobileInfo(Icons.check_circle_outline, task.completedLabel),
            ],
          ),
          if (task.dateLabel != null || task.action.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (task.dateLabel != null)
                  Expanded(
                    child: Text(
                      task.dateLabel!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: task.dateLabel!.contains('1')
                            ? AppColors.orange
                            : AppColors.green,
                      ),
                    ),
                  ),
                if (task.action.isNotEmpty) StatusBadge(text: task.action),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5ECF6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
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
              (entry) => _premiumTaskRow(entry.value, entry.key),
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
        border: Border(bottom: BorderSide(color: Color(0xFFE6ECF4))),
      ),
      child: Row(
        children: [
          _headerCell(Icons.business_rounded, 'CLIENT', 20),
          _headerCell(Icons.assignment_rounded, 'TASK', 22),
          _headerCell(Icons.schedule_rounded, 'TIME / DURATION', 17),
          _headerCell(Icons.event_available_rounded, 'DUE DATE', 18),
          _headerCell(Icons.flash_on_rounded, 'ACTION', 14),
          _headerCell(Icons.track_changes_rounded, 'STATUS', 14),
          _headerCell(Icons.task_alt_rounded, 'COMPLETION', 15),
        ],
      ),
    );
  }

  Widget _headerCell(IconData icon, String title, int flex) {
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: .55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumTaskRow(AdsHandlerTaskModel task, int index) {
    return _PremiumTaskRow(
      task: task,
      index: index,
    );
  }
}

class AdsHandlerTaskModel {
  final String clientName;
  final String task;
  final String duration;
  final String submissionDate;
  final int? trackingItemId;
  final String completedLabel;
  final bool completedAllDone;
  final String? dateLabel;
  String action;
  String status;

  AdsHandlerTaskModel({
    required this.clientName,
    required this.task,
    required this.duration,
    required this.submissionDate,
    required this.action,
    required this.status,
    this.trackingItemId,
    required this.completedLabel,
    required this.completedAllDone,
    required this.dateLabel,
  });
}

class _PremiumTaskRow extends StatefulWidget {
  final AdsHandlerTaskModel task;
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

  AdsHandlerTaskModel get task => widget.task;

  @override
  Widget build(BuildContext context) {
    final completed = _completedValue(task.completedLabel);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFF5F9FF) : Colors.white,
          border: const Border(
            bottom: BorderSide(
              color: Color(0xFFEDF1F6),
            ),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF0B5ED7).withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 20,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hovered ? const Color(0xFFDBEAFE) : const Color(0xFFF1F6FD),
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
                      task.clientName.isEmpty ? 'Unknown Client' : task.clientName,
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
            Expanded(
              flex: 18,
              child: _dueDateWidget(task),
            ),
            Expanded(
              flex: 14,
              child: _premiumStatusPill(
                task.action,
                _actionColor(task.action),
                _actionIcon(task.action),
              ),
            ),
            Expanded(
              flex: 14,
              child: _premiumStatusPill(
                task.status,
                _statusColor(task.status),
                _statusIcon(task.status),
              ),
            ),
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
                        backgroundColor: const Color(0xFFE8EEF6),
                        valueColor: AlwaysStoppedAnimation<Color>(
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

  Widget _dueDateWidget(AdsHandlerTaskModel task) {
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
    final display = value.trim().isEmpty ? '-' : value;

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
      case 'COMPLETED': return const Color(0xFF16A34A);
      case 'SUBMITTED': return const Color(0xFF2563EB);
      case 'REJECTED': return const Color(0xFFDC2626);
      case 'HOLD':
      case 'ON HOLD': return const Color(0xFFD97706);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _actionIcon(String value) {
    switch (value.toUpperCase()) {
      case 'COMPLETED': return Icons.check_circle_rounded;
      case 'SUBMITTED': return Icons.upload_rounded;
      case 'REJECTED': return Icons.cancel_rounded;
      case 'HOLD':
      case 'ON HOLD': return Icons.pause_circle_rounded;
      default: return Icons.flash_on_rounded;
    }
  }

  Color _statusColor(String value) {
    final v = value.toUpperCase();
    if (v.contains('APPROV')) return const Color(0xFF16A34A);
    if (v.contains('REJECT')) return const Color(0xFFDC2626);
    if (v.contains('REWORK')) return const Color(0xFFD97706);
    if (v.contains('REVIEW')) return const Color(0xFF7C3AED);
    if (v.contains('HOLD')) return const Color(0xFFF59E0B);
    return const Color(0xFF2563EB);
  }

  IconData _statusIcon(String value) {
    final v = value.toUpperCase();
    if (v.contains('APPROV')) return Icons.verified_rounded;
    if (v.contains('REJECT')) return Icons.block_rounded;
    if (v.contains('REWORK')) return Icons.replay_rounded;
    if (v.contains('REVIEW')) return Icons.rate_review_rounded;
    if (v.contains('HOLD')) return Icons.pause_circle_rounded;
    return Icons.track_changes_rounded;
  }
}