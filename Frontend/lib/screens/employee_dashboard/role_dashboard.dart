// lib/screens/employee_dashboard/role_dashboard.dart
//
// One dashboard layout for every employee role (Designer, Video Editor /
// Videographer, Page Handler, Ads Handler). Order:
//   1. Welcome bar (compact)          — role, active time, date + filter
//   2. 4 metric cards                 — Assigned / New / Hold / Inactive clients
//   3. Work tables (left / right)     — Pending · This Week · Rework
//                                       (+ Task Review · Content Calendar for handlers)
//   4. Recent Alerts + Daily Productivity
// The old "Task Status & Live Monitoring" table is removed.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/widgets/metric_card.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/widgets/alerts_section.dart';
import 'package:godigital_portal/widgets/productivity_card.dart';
import '../../services/api_config.dart';
import 'dashboard_work_tables.dart';

class RoleDashboard extends StatefulWidget {
  /// Hero chip text, e.g. 'PAGE HANDLER'. Null → the user's role from login.
  final String? roleLabel;
  final String holdTitle;
  final bool isHandler;
  final VoidCallback? onOpenAssignedTask;
  final VoidCallback? onViewAllNotifications;

  /// Open a task in Employee Workspace: {client, due_date, section}.
  final ValueChanged<Map<String, dynamic>>? onOpenWorkspace;

  const RoleDashboard({
    super.key,
    this.roleLabel,
    this.holdTitle = 'Hold Task',
    this.isHandler = false,
    this.onOpenAssignedTask,
    this.onViewAllNotifications,
    this.onOpenWorkspace,
  });

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard> {
  static String get _baseUrl => ApiConfig.baseUrl;

  List<Map<String, dynamic>> recentNotifications = [];
  int assignedClientsCount = 0;
  List<dynamic> assignedClientsList = [];
  int newClientsCount = 0;
  List<dynamic> newClientsList = [];
  int holdTasks = 0;
  List<dynamic> holdTasksList = [];
  int inactiveTodayCount = 0;
  List<dynamic> inactiveTodayList = [];
  String globalFilterMode = 'Today';
  int approved = 0, rejected = 0, rework = 0, review = 0, others = 0;
  String? _employeeName;
  String totalWorkingTimeFormatted = '00h 00m';
  io.Socket? _socket;
  bool _cardsFromWorkspace = false;

  /// Hold Task + New Clients from /workspace-tasks/dashboard: real hold rows
  /// (My Tasks + Content Calendar) and clients newly given to this employee
  /// (new assignment, or moved from another person) in the selected period.
  void _applyCards(Map<String, dynamic> cards) {
    if (!mounted) return;
    int toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    setState(() {
      _cardsFromWorkspace = true;
      holdTasks = toInt(cards['hold_count']);
      holdTasksList = cards['hold_list'] as List? ?? [];
      newClientsCount = toInt(cards['new_clients_count']);
      newClientsList = cards['new_clients'] as List? ?? [];
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchDashboardSummary();
    _fetchLiveWorkingTime();
    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder().setTransports(['websocket']).enableForceNew().disableAutoConnect().build(),
    )..connect();
    _socket!
      ..on('task_updated', (_) {
        if (!mounted) return;
        _fetchDashboardSummary();
        _fetchLiveWorkingTime();
      })
      ..on('taskAssigned', (_) {
        if (mounted) _fetchDashboardSummary();
      });
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  String _nameFromAuth() {
    final user = context.read<AuthService>().user;
    return '${user?['fullName'] ?? user?['name'] ?? ''}'.trim();
  }

  Future<void> _fetchDashboardSummary() async {
    _employeeName = _nameFromAuth();
    if (_employeeName!.isEmpty) return;
    try {
      final name = Uri.encodeComponent(_employeeName!);
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/dashboard/summary/$name?filter=${Uri.encodeComponent(globalFilterMode)}')),
        http.get(Uri.parse('$_baseUrl/dashboard/recent-notifications/$name')),
      ]);
      final r = results[0];
      final n = results[1];
      if (r.statusCode != 200 || !mounted) return;
      final data = (jsonDecode(r.body)['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final productivity = (data['productivity'] as Map?)?.cast<String, dynamic>() ?? {};
      var notes = <Map<String, dynamic>>[];
      if (n.statusCode == 200) {
        notes = List<Map<String, dynamic>>.from(jsonDecode(n.body)['data'] ?? []);
      }
      int toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
      setState(() {
        assignedClientsCount = toInt(data['assignedClientsCount']);
        assignedClientsList = data['assignedClientsList'] as List? ?? [];
        // New Clients + Hold Task come from the work tables (_applyCards),
        // which use the same rows as Employee Workspace.
        if (!_cardsFromWorkspace) {
          newClientsCount = toInt(data['newClientsCount']);
          newClientsList = data['newClientsList'] as List? ?? [];
          holdTasks = toInt(data['onHoldCount']);
          holdTasksList = data['onHoldList'] as List? ?? [];
        }
        inactiveTodayCount = toInt(data['inactiveTodayCount']);
        inactiveTodayList = data['inactiveTodayList'] as List? ?? [];
        approved = toInt(productivity['approved']);
        rework = toInt(productivity['rework']);
        rejected = toInt(productivity['rejected']);
        review = toInt(productivity['review']);
        others = toInt(productivity['others']);
        recentNotifications = notes;
      });
    } catch (e) {
      debugPrint('Dashboard summary error: $e');
    }
  }

  Future<void> _fetchLiveWorkingTime() async {
    final name = _employeeName ?? _nameFromAuth();
    if (name.isEmpty) return;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final res = await http.get(Uri.parse(
          '$_baseUrl/dashboard/live-tracking-tasks/${Uri.encodeComponent(name)}?date=$today'));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      var secs = int.tryParse('${body['totalWorkingSecs'] ?? ''}') ?? -1;
      if (secs < 0) {
        secs = 0;
        for (final row in (body['data'] as List? ?? [])) {
          secs += int.tryParse('${row['duration_secs'] ?? 0}') ?? 0;
        }
      }
      final h = secs ~/ 3600;
      final m = (secs % 3600) ~/ 60;
      if (mounted) {
        setState(() => totalWorkingTimeFormatted =
            '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m');
      }
    } catch (e) {
      debugPrint('Live working time error: $e');
    }
  }

  String _formatDate(dynamic raw) {
    final s = '${raw ?? ''}';
    if (s.isEmpty || s == 'null') return '--';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
  }

  String _todayText() {
    final now = DateTime.now();
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'];
    return '${months[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    final name = '${user?['fullName'] ?? user?['name'] ?? user?['username'] ?? ''}'.trim();
    final role = (widget.roleLabel ?? '${user?['role'] ?? 'Employee'}').toUpperCase();
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final gap = mobile ? 14.0 : 18.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
padding: EdgeInsets.fromLTRB(mobile ? 12 : 22, mobile ? 12 : 16, mobile ? 12 : 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _welcome(name, role),
          SizedBox(height: gap),
          _summaryCards(),
          SizedBox(height: gap),
          // Work tables come BEFORE the alerts and productivity cards.
          DashboardWorkTables(
            employeeName: name,
            token: auth.token ?? '',
            isHandler: widget.isHandler,
            onOpenWorkspace: widget.onOpenWorkspace,
            filter: globalFilterMode,
            onCards: _applyCards,
          ),
          SizedBox(height: gap),
          LayoutBuilder(builder: (context, c) {
            final alerts = AlertsSection(
              notifications: recentNotifications,
              onViewAll: widget.onViewAllNotifications,
            );
            final productivity = ProductivityCard(
              approved: approved,
              rework: rework,
              rejected: rejected,
              review: review,
              others: others,
            );
            if (c.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [alerts, const SizedBox(height: 14), productivity],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: alerts),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: productivity),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _welcome(String name, String role) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          _heroChip(Icons.verified_rounded, const Color(0xFF4ADE80), role),
          _heroChip(Icons.timer_rounded, const Color(0xFF93C5FD), 'ACTIVE TIME: $totalWorkingTimeFormatted'),
        ]),
        const SizedBox(height: 8),
        Text(
          name.isEmpty ? 'Welcome back! ✨' : 'Welcome back, $name! ✨',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -.4),
        ),
        const SizedBox(height: 2),
        Text(
          'Your pending work, this week\'s deadlines and live progress — start tasks right here.',
          style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: MediaQuery.sizeOf(context).width < 600 ? 14 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF04296B), Color(0xFF0757D5), Color(0xFF1D74E8)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0757D5).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [content, const SizedBox(height: 10), _dateFilter()],
          );
        }
        return Row(children: [Expanded(child: content), const SizedBox(width: 16), _dateFilter()]);
      }),
    );
  }

  Widget _heroChip(IconData icon, Color iconColor, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .5)),
        ]),
      );

  Widget _dateFilter() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(_todayText(),
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(height: 16, width: 1, color: Colors.white30),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            initialValue: globalFilterMode,
            onSelected: (v) {
              setState(() => globalFilterMode = v);
              _fetchDashboardSummary();
            },
            itemBuilder: (_) => [
              for (final v in ['Today', 'This Week', 'This Month'])
                PopupMenuItem(
                  value: v,
                  child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(globalFilterMode,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
            ]),
          ),
        ]),
      );

  Widget _summaryCards() {
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 900 ? 4 : 2;
      final gap = columns == 4 ? 16.0 : 12.0;
      final w = (c.maxWidth - gap * (columns - 1)) / columns;
      Widget card(VoidCallback onTap, Widget child) =>
          SizedBox(width: w, child: GestureDetector(onTap: onTap, child: child));
      return Wrap(spacing: gap, runSpacing: 12, children: [
        card(
          () => _showDetailsPopup('Assigned Clients & Allocated Tasks', assignedClientsList, isAssignedClient: true),
          MetricCard(
            icon: Icons.groups_rounded,
            title: 'Assigned Clients',
            value: assignedClientsCount.toString().padLeft(2, '0'),
            label: 'Active Clients',
            color: AppColors.primary,
          ),
        ),
        card(
          () => _showDetailsPopup('New Clients ($globalFilterMode)', newClientsList),
          MetricCard(
            icon: Icons.fiber_new_rounded,
            title: 'New Clients',
            value: newClientsCount.toString().padLeft(2, '0'),
            label: globalFilterMode,
            color: AppColors.green,
          ),
        ),
        card(
          () => _showDetailsPopup(widget.holdTitle, holdTasksList, isHoldCard: true),
          MetricCard(
            icon: Icons.pause_circle_rounded,
            title: widget.holdTitle,
            value: holdTasks.toString().padLeft(2, '0'),
            label: 'Action required',
            color: AppColors.orange,
          ),
        ),
        card(
          () => _showDetailsPopup('Inactive Clients ($globalFilterMode)', inactiveTodayList, isInactiveCard: true),
          MetricCard(
            icon: Icons.person_off_rounded,
            title: 'Inactive Clients',
            value: inactiveTodayCount.toString().padLeft(2, '0'),
            label: globalFilterMode,
            color: AppColors.red,
          ),
        ),
      ]);
    });
  }

  // Blue & white popup (one entry per client).
  void _showDetailsPopup(String title, List<dynamic> items,
      {bool isAssignedClient = false, bool isHoldCard = false, bool isInactiveCard = false}) {
    final unique = <String, dynamic>{};
    for (final item in items) {
      final name = '${item['clientName'] ?? item['company_name'] ?? item['client_name'] ?? 'Client'}';
      // Hold: one line per task; other cards: one line per client.
      unique.putIfAbsent(isHoldCard ? '$name|${item['task'] ?? unique.length}' : name, () => item);
    }
    final clean = unique.values.toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 480,
          height: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F5FF), Colors.white],
            ),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF04296B), Color(0xFF0757D5)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                const Icon(Icons.business_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Expanded(
              child: clean.isEmpty
                  ? const Center(
                      child: Text('No records found.',
                          style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: clean.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = clean[index];
                        final clientName =
                            '${item['clientName'] ?? item['company_name'] ?? item['client_name'] ?? 'Client'}';
                        final tasks = item['tasks'] as List<dynamic>? ?? [];
                        final sub = _formatDate(item['submissionDate'] ?? item['created_at']);
                        final hold = _formatDate(item['holdDate']);
                        final inactive = _formatDate(item['inactiveDate'] ?? item['updated_at']);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD8E9FF)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFEAF3FF),
                                child: Text('${index + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF0757D5))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(clientName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900, fontSize: 13.5, color: AppColors.textDark)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 38),
                              child: isAssignedClient && tasks.isNotEmpty
                                  ? Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        for (final t in tasks)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEAF3FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('$t',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0757D5))),
                                          ),
                                      ],
                                    )
                                  : Text(
                                      isHoldCard
                                          ? '${item['task'] == null ? '' : '${item['task']}\n'}Hold Date: $hold | Submit Date: $sub'
                                          : isInactiveCard
                                              ? 'Inactive Date: $inactive'
                                              : '${item['note'] == null ? '' : '${item['note']} · '}Submit Date: $sub',
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w500),
                                    ),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
