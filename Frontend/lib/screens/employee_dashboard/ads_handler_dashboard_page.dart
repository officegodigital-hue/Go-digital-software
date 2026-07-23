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

class AdsHandlerDashboardPage extends StatefulWidget {
  final VoidCallback? onOpenAssignedTask;

  const AdsHandlerDashboardPage({
    super.key,
    this.onOpenAssignedTask,
  });

  @override
  State<AdsHandlerDashboardPage> createState() =>
      _AdsHandlerDashboardPageState();
}

class _AdsHandlerDashboardPageState extends State<AdsHandlerDashboardPage> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  List<AdsHandlerTaskModel> tasks = [];

  // Live counts from the backend, replacing the old hardcoded getters.
  int assignedClients = 0;
  int activeClients = 0;
  int taskPending = 0;
  int upcomingDeadlines = 0;

  int approved = 0;
int rejected = 0;
int rework = 0;
int changes = 0;

  bool _loading = true;
  String? _error;
  String? _employeeName;

  @override
  void initState() {
    super.initState();
    _fetchDashboardSummary();
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

      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final data = body['data'] as Map<String, dynamic>? ?? {};
        final productivity =
    data['productivity'] as Map<String, dynamic>? ?? {};
        final rawTasks = List<dynamic>.from(data['tasks'] ?? []);

        setState(() {
          assignedClients   = data['assignedClients'] as int? ?? 0;
          activeClients     = data['activeClients'] as int? ?? 0;
          taskPending        = data['taskPending'] as int? ?? 0;
          upcomingDeadlines  = data['upcomingDeadlines'] as int? ?? 0;
          approved = productivity['approved'] ?? 0;
rework = productivity['rework'] ?? 0;
rejected = productivity['rejected'] ?? 0;
changes = productivity['changes'] ?? 0;
          tasks = rawTasks.map((t) => AdsHandlerTaskModel(
            clientName:      t['clientName'] as String? ?? '',
            task:            t['task'] as String? ?? '',
            duration:        t['duration'] as String? ?? 'N/A',
            submissionDate:  _formatDate(t['submissionDate'] as String?),
            action:          t['action'] as String? ?? 'IDLE',
            status:          t['status'] as String? ?? '-',
            trackingItemId:  t['trackingItemId'] as int?,
          )).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load dashboard (${r.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loading = false; });
    }
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
                child: AlertsSection(),
              ),
              SizedBox(width: 22),
              Expanded(
                flex: 3,
                // child: ProductivityCard(),
                child: ProductivityCard(
  approved: approved,
  rework: rework,
  rejected: rejected,
  changes: changes,
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
                  'Welcome - Susan',
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
        // Container(
        //   height: 34,
        //   padding: const EdgeInsets.symmetric(horizontal: 14),
        //   decoration: BoxDecoration(
        //     color: AppColors.lightBlue,
        //     border: Border.all(color: AppColors.border),
        //     borderRadius: BorderRadius.circular(4),
        //   ),
          // child: const Row(
          //   children: [
          //     Icon(
          //       Icons.calendar_month,
          //       size: 17,
          //       color: AppColors.primary,
          //     ),
          //     SizedBox(width: 8),
          //     Text(
          //       'June 01, 2026 - Today',
          //       style: TextStyle(
          //         fontSize: 12,
          //         color: AppColors.textDark,
          //         fontWeight: FontWeight.w600,
          //       ),
          //     ),
          //   ],
          // ),
        // ),
      ],
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
        Expanded(
          child: MetricCard(
            icon: Icons.pending_actions,
            title: 'Task Pending',
            value: taskPending.toString().padLeft(2, '0'),
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
            flex: 2,
            child: Text('SUBMISSION\nDATE', style: AppTextStyles.tableHeader),
          ),
          Expanded(
            flex: 2,
            child: Text('ACTION', style: AppTextStyles.tableHeader),
          ),
          Expanded(
            flex: 1,
            child: Text('STATUS', style: AppTextStyles.tableHeader),
          ),
          SizedBox(width: 48),
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
            flex: 2,
            child: Text(task.submissionDate, style: AppTextStyles.tableText),
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
          SizedBox(
            width: 48,
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.textGrey,
              ),
              onSelected: (value) {
                if (value == 'progress') {
                  updateTask(task, 'start', 'IN PROGRESS', '-');
                }
                if (value == 'completed') {
                  updateTask(task, 'complete', 'COMPLETED', 'REVIEW');
                }
                if (value == 'hold') {
                  updateTask(task, 'hold', 'ON HOLD', '-');
                }
                if (value == 'rejected') {
                  updateTask(task, 'reject', 'REJECTED', '-');
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem(
                    value: 'progress',
                    child: Text('Mark In Progress'),
                  ),
                  PopupMenuItem(
                    value: 'completed',
                    child: Text('Mark Completed'),
                  ),
                  PopupMenuItem(
                    value: 'hold',
                    child: Text('Put On Hold'),
                  ),
                  PopupMenuItem(
                    value: 'rejected',
                    child: Text('Mark Rejected'),
                  ),
                ];
              },
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
  final int? trackingItemId;
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
  });
}