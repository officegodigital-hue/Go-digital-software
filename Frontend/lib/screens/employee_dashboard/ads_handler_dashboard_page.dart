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
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  List<AdsHandlerTaskModel> tasks = [];
  List<Map<String, dynamic>> recentNotifications = [];

  // Live counts from the backend, replacing the old hardcoded getters.
  int assignedClients = 0;
  int activeClients = 0;
  int taskPending = 0;
  int holdTasks = 0;
  int upcomingDeadlines = 0;

  int approved = 0;
int rejected = 0;
int rework = 0;
int review  = 0;
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
      print("🔥 Dashboard live update received: $data");
      if (mounted) {
        _fetchDashboardSummary(); // Task update aana odane dashboard summary & table live-ah refresh aagum!
      }
    });
  }

@override
  void dispose() {
    socket.dispose(); // 🟢 Widget close aagum pothu socket-ai dispose seyyungal
    super.dispose();
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

  Future<void> _fetchDashboardSummary() async {
    setState(() { _loading = true; _error = null; });

    try {
      final user = context.read<AuthService>().user;
      _employeeName = (user?['fullName'] ?? user?['name'] ?? '') as String? ?? '';

      if (_employeeName == null || _employeeName!.isEmpty) {
        setState(() { _error = 'Employee name not found. Please re-login.'; _loading = false; });
        return;
      }

      final r = await http.get(
        Uri.parse('$_baseUrl/dashboard/summary/${Uri.encodeComponent(_employeeName!)}'),
      );
final n = await http.get(
  Uri.parse(
    '$_baseUrl/dashboard/recent-notifications/${Uri.encodeComponent(_employeeName!)}',
  ),
);
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final productivity =
    data['productivity'] as Map<String, dynamic>? ?? {};
        final rawTasks = List<dynamic>.from(data['tasks'] ?? []);
List<Map<String, dynamic>> notificationData = [];

if (n.statusCode == 200) {
  final notificationBody = jsonDecode(n.body);

  notificationData = List<Map<String, dynamic>>.from(
    notificationBody["data"] ?? [],
  );
}
        setState(() {
          assignedClients   = data['assignedClients'] as int? ?? 0;
          activeClients     = data['activeClients'] as int? ?? 0;
          // taskPending        = data['taskPending'] as int? ?? 0;
          holdTasks = data['onHoldCount'] ?? 0;
          upcomingDeadlines  = data['upcomingDeadlines'] as int? ?? 0;
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
        setState(() { _error = 'Failed to load dashboard (${r.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loading = false; });
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

  // Pushes the popup-menu selection to the backend (same endpoints the
  // Assigned Tasks screen uses) then refreshes the local model on success,
  // so a refresh of this page always reflects the real DB state.
  Future<void> updateTask(AdsHandlerTaskModel task, String endpointAction, String localAction, String localStatus) async {
    if (task.trackingItemId == null) {
      // No tracking item exists yet for this task (e.g. it was never opened
      // in Assigned Tasks) — nothing to update on the backend.
      _showSnack('This task has no tracker entry yet — open it in Assigned Tasks first.');
      return;
    }

    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/tracking-items/${task.trackingItemId}/$endpointAction'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(endpointAction == 'complete' ? {'performance': 'N/A'} : {}),
      );
      if (r.statusCode == 200) {
        setState(() {
          task.action = localAction;
          task.status = localStatus;
        });
      } else {
        _showSnack('Update failed (${r.statusCode})');
      }
    } catch (e) {
      _showSnack('Update error: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _welcomeSection(),
          const SizedBox(height: 28),
          _summaryCards(),
          const SizedBox(height: 28),
          _taskStatusTable(),
          const SizedBox(height: 28),
           Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                // child: AlertsSection(),
                child: AlertsSection(
  notifications: recentNotifications,
  onViewAll: widget.onViewAllNotifications,
),
              ),
              SizedBox(width: 22),
              Expanded(
                flex: 3,
                // child: ProductivityCard(),
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
        ],
      ),
    );
  }

  Widget _welcomeSection() {
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Welcome ',
                  style: AppTextStyles.heading,
                ),
                SizedBox(width: 6),
                
              ],
            ),
            SizedBox(height: 6),
            Text(
              "Here is an overview of today's GoDigital priorities and performance metrics.",
              style: AppTextStyles.subHeading,
            ),
          ],
        ),
        const Spacer(),
      Container(
  height: 34,
  padding: const EdgeInsets.symmetric(horizontal: 14),
  decoration: BoxDecoration(
    color: AppColors.lightBlue,
    border: Border.all(color: AppColors.border),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Row( // <-- Remove const here
    children: [
      const Icon(
        Icons.calendar_month,
        size: 17,
        color: AppColors.primary,
      ),
      const SizedBox(width: 8),
      Text(
        getTodayDate(),
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
),],
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            icon: Icons.groups,
            title: 'Assigned Clients',
            value: assignedClients.toString().padLeft(2, '0'),
            label: 'Current',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          child: MetricCard(
            icon: Icons.account_tree_outlined,
            title: 'Active Clients',
            value: activeClients.toString().padLeft(2, '0'),
            label: 'Current',
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 28),
        // Expanded(
        //   child: MetricCard(
        //     icon: Icons.pending_actions,
        //     title: 'Task Pending',
        //     value: taskPending.toString().padLeft(2, '0'),
        //     label: 'Action required',
        //     color: AppColors.orange,
        //   ),
        // ),
        Expanded(
  child: MetricCard(
    icon: Icons.pause_circle_outline,
    title: 'Hold Task',
    value: holdTasks.toString().padLeft(2, '0'),
    label: 'Action required',
    color: AppColors.orange,
  ),
),
        const SizedBox(width: 28),
        Expanded(
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
  }

  Widget _taskStatusTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: 50,
            color: AppColors.lightBlue,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Text(
                  'Task Status',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: widget.onOpenAssignedTask,
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _tableHeader(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                Text(_error!, style: const TextStyle(color: AppColors.textGrey)),
                const SizedBox(height: 10),
                TextButton(onPressed: _fetchDashboardSummary, child: const Text('Retry')),
              ]),
            )
          else if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('No tasks assigned yet', style: TextStyle(color: AppColors.textGrey))),
            )
          else
            ...tasks.map((task) => _taskRow(task)),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
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
            child: Text('DURATION', style: AppTextStyles.tableHeader),
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
  flex: 1,
  child: Text('STATUS', style: AppTextStyles.tableHeader),
),

Expanded(
  flex: 2,
  child: Text(
    'COMPLETED TASK',
    style: AppTextStyles.tableHeader,
  ),
),

        ],
      ),
    );
  }

  Widget _taskRow(AdsHandlerTaskModel task) {
    return Container(
      height: 52,
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
            child: Text(task.clientName, style: AppTextStyles.tableText),
          ),
          Expanded(
            flex: 2,
            child: Text(task.task, style: AppTextStyles.tableText),
          ),
          Expanded(
            flex: 2,
            child: Text(task.duration, style: AppTextStyles.tableText),
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
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: task.dateLabel!.contains('1')
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
            flex: 1,
            child: StatusBadge(text: task.status),
          ),
          Expanded(
  flex: 2,
  child: Align(
    alignment: Alignment.center,
    child: Text(
      task.completedLabel,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: task.completedAllDone
            ? const Color(0xFF16A34A)
            : const Color(0xFF334155),
      ),
    ),
  ),
),
        ],
      ),
    );
  }
}

class AdsHandlerTaskModel {
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

AdsHandlerTaskModel({
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