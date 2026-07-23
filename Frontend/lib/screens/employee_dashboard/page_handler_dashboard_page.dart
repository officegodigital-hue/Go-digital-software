import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/constants/app_text_styles.dart';
import 'package:godigital_portal/core/widgets/metric_card.dart';
import 'package:godigital_portal/core/widgets/status_badge.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/widgets/alerts_section.dart';
import 'package:godigital_portal/widgets/productivity_card.dart';
import '../../services/api_config.dart';

class PageHandlerDashboardPage extends StatefulWidget {
  final VoidCallback? onOpenAssignedTask;
  final VoidCallback? onViewAllNotifications;

  const PageHandlerDashboardPage({super.key, this.onOpenAssignedTask, this.onViewAllNotifications});

  @override
  State<PageHandlerDashboardPage> createState() => _PageHandlerDashboardPageState();
}

class _PageHandlerDashboardPageState extends State<PageHandlerDashboardPage> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  List<PageHandlerTaskModel> tasks = [];

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
          assignedClients  = data['assignedClients'] as int? ?? 0;
          activeClients     = data['activeClients'] as int? ?? 0;
          taskPending        = data['taskPending'] as int? ?? 0;
          upcomingDeadlines  = data['upcomingDeadlines'] as int? ?? 0;
          approved = productivity['approved'] ?? 0;
rework = productivity['rework'] ?? 0;
rejected = productivity['rejected'] ?? 0;
changes = productivity['changes'] ?? 0;
          tasks = rawTasks.map((t) => PageHandlerTaskModel(
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
              Expanded(flex: 7, child: AlertsSection()),
              SizedBox(width: 22),
              Expanded(flex: 3, 
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('Welcome ', style: AppTextStyles.heading),
              ],
            ),
            const SizedBox(height: 6),
            Text("Here is an overview of today's GoDigital priorities and performance metrics.", style: AppTextStyles.subHeading),
          ],
        ),
        const Spacer(),
        // Container(
        //   height: 38,
        //   padding: const EdgeInsets.symmetric(horizontal: 14),
        //   decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
        //   // child: const Row(
        //   //   children: [
        //   //     Icon(Icons.calendar_month, size: 17, color: AppColors.primary),
        //   //     SizedBox(width: 8),
        //   //     Text('June 01, 2026 - Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        //   //   ],
        //   // ),
        // ),
      ],
    );
  }

  Widget _summaryCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: MetricCard(icon: Icons.groups, title: 'Assigned Clients', value: assignedClients.toString().padLeft(2, '0'), label: 'Current', color: AppColors.primary)),
          const SizedBox(width: 28),
          Expanded(child: MetricCard(icon: Icons.account_tree_outlined, title: 'Active Clients', value: activeClients.toString().padLeft(2, '0'), label: 'Current', color: AppColors.green)),
          const SizedBox(width: 28),
          Expanded(child: MetricCard(icon: Icons.pending_actions, title: 'Task Pending', value: taskPending.toString().padLeft(2, '0'), label: 'Action required', color: AppColors.orange)),
          const SizedBox(width: 28),
          Expanded(child: MetricCard(icon: Icons.cancel_outlined, title: 'Upcoming Deadlines', value: upcomingDeadlines.toString().padLeft(2, '0'), label: 'High Risk', color: AppColors.red)),
        ],
      ),
    );
  }

  Widget _taskStatusTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Container(
            height: 50,
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text('Task Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const Spacer(),
                InkWell(onTap: widget.onOpenAssignedTask, child: const Text('View All', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
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
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('CLIENT', style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('TASKS', style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('DURATION', style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('SUBMISSION\nDATE', style: AppTextStyles.tableHeader)),
          Expanded(flex: 2, child: Text('ACTION', style: AppTextStyles.tableHeader)),
          Expanded(flex: 1, child: Text('STATUS', style: AppTextStyles.tableHeader)),
        ],
      ),
    );
  }

  Widget _taskRow(PageHandlerTaskModel task) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(task.clientName, style: AppTextStyles.tableText)),
          Expanded(flex: 2, child: Text(task.task, style: AppTextStyles.tableText)),
          Expanded(flex: 2, child: Text(task.duration, style: AppTextStyles.tableText)),
          Expanded(flex: 2, child: Text(task.submissionDate, style: AppTextStyles.tableText)),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: StatusBadge(text: task.action))),
          Expanded(flex: 1, child: StatusBadge(text: task.status)),
        ],
      ),
    );
  }
}

class PageHandlerTaskModel {
  final String clientName;
  final String task;
  final String duration;
  final String submissionDate;
  final int? trackingItemId;
  String action;
  String status;

  PageHandlerTaskModel({
    required this.clientName,
    required this.task,
    required this.duration,
    required this.submissionDate,
    required this.action,
    required this.status,
    this.trackingItemId,
  });
}