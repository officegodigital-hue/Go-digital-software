import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import '../../layouts/admin_layout.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const String _baseUrl = 'http://127.0.0.1:5000/api';

  String _selectedDateRange = "Today";
  final List<String> _dateOptions = ["Today", "This Week", "This Month"];
  String _activePerformanceView = "Client";

  // ── FIX: stat cards + Employee Status preview are now backend-driven.
  // Total/Active/Inactive clients come from /api/clients (status field:
  // draft/pending/verified/complete). Client Pending Task and the preview
  // rows come from /api/admin/employee-status (the same endpoint the full
  // Employee Status screen uses).
  bool _loadingStats = true;
  String? _statsError;

  int _totalClients = 0;
  int _activeClients = 0;
  int _inactiveClients = 0;
  int _pendingTasks = 0;

  // Just the first few rows, for the dashboard's preview table — the full
  // list lives on the Employee Status screen ("View All").
  List<Map<String, dynamic>> _previewRows = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() { _loadingStats = true; _statsError = null; });

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/clients')),
        http.get(Uri.parse('$_baseUrl/admin/employee-status')),
      ]);

      final clientsResponse = results[0];
      final statusResponse = results[1];

      if (clientsResponse.statusCode != 200) {
        setState(() { _statsError = 'Failed to load clients (${clientsResponse.statusCode})'; _loadingStats = false; });
        return;
      }
      if (statusResponse.statusCode != 200) {
        setState(() { _statsError = 'Failed to load employee status (${statusResponse.statusCode})'; _loadingStats = false; });
        return;
      }

      final clients = List<dynamic>.from(jsonDecode(clientsResponse.body)['data'] ?? []);
      final statusRows = List<dynamic>.from(jsonDecode(statusResponse.body)['data'] ?? []);

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
      setState(() { _statsError = 'Connection error: $e'; _loadingStats = false; });
    }
  }

  // Same color/label logic as the full Employee Status screen, kept local
  // here since the dashboard only needs it for the 3-row preview.
  Map<String, dynamic> _mapPreviewRow(dynamic row) {
    final employeeName = row['employeeName'] as String? ?? 'Unassigned';
    final priority = (row['priority'] as String? ?? 'LOW').toUpperCase();
    final rawStatus = (row['status'] as String? ?? 'IDLE').toUpperCase();
    final daysLeft = row['daysLeft'] as int?;

    final priorityColors = _priorityColors(priority);
    final statusInfo = _statusDisplay(rawStatus);
    final timeInfo = _timeLeftDisplay(daysLeft);

    return {
      "client": row['clientName'] ?? '',
      "initials": _initialsFor(employeeName),
      "name": employeeName,
      "task": row['task'] ?? '',
      "duration": row['duration'] ?? 'N/A',
      "priority": priority,
      "priorityBg": priorityColors.$1,
      "priorityText": priorityColors.$2,
      "date": _formatDate(row['submissionDate'] as String?),
      "timeLeft": timeInfo.$1,
      "timeColor": timeInfo.$2,
      "status": statusInfo.$1,
      "statusBg": statusInfo.$2,
      "statusText": statusInfo.$3,
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

  (Color, Color) _priorityColors(String priority) {
    switch (priority) {
      case 'URGENT': return (const Color(0xFFFEE2E2), const Color(0xFFDC2626));
      case 'HIGH':   return (const Color(0xFFFFE4E6), const Color(0xFFEF4444));
      case 'MEDIUM': return (const Color(0xFFFEF3C7), const Color(0xFFD97706));
      default:       return (const Color(0xFFDCFCE7), const Color(0xFF16A34A)); // LOW
    }
  }

  (String, Color, Color) _statusDisplay(String rawStatus) {
    switch (rawStatus) {
      case 'IDLE':
        return ('NOT STARTED', const Color(0xFFF1F5F9), const Color(0xFF64748B));
      case 'IN PROGRESS':
        return ('IN PROGRESS', const Color(0xFFE0F2FE), const Color(0xFF0369A1));
      case 'ON HOLD':
        return ('ON HOLD', const Color(0xFFFEF3C7), const Color(0xFFD97706));
      case 'COMPLETED':
        return ('COMPLETED', const Color(0xFFDCFCE7), const Color(0xFF16A34A));
      case 'REJECTED':
        return ('REJECTED', const Color(0xFFFEE2E2), const Color(0xFFDC2626));
      default:
        return (rawStatus, const Color(0xFFF1F5F9), const Color(0xFF64748B));
    }
  }

  (String, Color) _timeLeftDisplay(int? daysLeft) {
    if (daysLeft == null) return ('--', const Color(0xFF64748B));
    if (daysLeft > 0) return ('$daysLeft Day${daysLeft == 1 ? '' : 's'} Left', const Color(0xFF22C55E));
    if (daysLeft == 0) return ('Due Today', const Color(0xFFD97706));
    final overdue = daysLeft.abs();
    return ('$overdue Day${overdue == 1 ? '' : 's'} Overdue', const Color(0xFFDC2626));
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
          // ── Header Toolbar Banner ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Welcome Admin",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Here is an overview of today's GoDigital priorities and performance metrics.",
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              
              // Right Side Date Filter Dropdown Card
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
                    Text(
                      "$dynamicTodayString - ",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
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

          // ── Stat Cards Summary Row — now backend-driven ──
          if (_statsError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Expanded(child: Text(_statsError!, style: TextStyle(color: Colors.red.shade700))),
                TextButton(onPressed: _fetchDashboardData, child: const Text('Retry')),
              ]),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people_alt_rounded,
                    headerColor: const Color(0xFF2A52BE),
                    label: 'Total Clients',
                    value: _loadingStats ? '—' : _totalClients.toString(),
                    bottom: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups_2_outlined, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text('All onboarded clients', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.groups_rounded,
                    headerColor: const Color(0xFF16A34A),
                    label: 'Active Client',
                    value: _loadingStats ? '—' : _activeClients.toString(),
                    bottom: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync, size: 14, color: Color(0xFF475569)),
                        SizedBox(width: 6),
                        Text('Verified / complete', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.assignment_late_outlined,
                    headerColor: const Color(0xFFE67E00),
                    label: 'Client Pending Task',
                    value: _loadingStats ? '—' : _pendingTasks.toString(),
                    bottom: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFB91C1C), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Requires Attention', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.cancel_outlined,
                    headerColor: const Color(0xFFE10000),
                    label: 'In Active Clients',
                    value: _loadingStats ? '—' : _inactiveClients.toString(),
                    bottom: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drafts_outlined, size: 14, color: Color(0xFFB91C1C)),
                        SizedBox(width: 4),
                        Text('Still in draft', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 32),

          // ── Employee Status Table Layout Component ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Employee Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/employee-status'),
                        child: const Text("View All", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                Container(
                  color: Colors.white,
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text("CLIENT", style: _columnTitleStyle)),
                      Expanded(flex: 3, child: Text("EMPLOYEE NAME", style: _columnTitleStyle)),
                      Expanded(flex: 2, child: Text("TASKS", style: _columnTitleStyle)),
                      Expanded(flex: 2, child: Text("TIME/DURATION", style: _columnTitleStyle)),
                      Expanded(flex: 2, child: Text("PRIORITY", style: _columnTitleStyle)),
                      Expanded(flex: 3, child: Text("DUE DATE", style: _columnTitleStyle)),
                      Expanded(flex: 2, child: Text("STATUS", style: _columnTitleStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _loadingStats
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _previewRows.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text("No tasks to show yet.", style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              ),
                            )
                          : Column(
                              children: [
                                for (int i = 0; i < _previewRows.length; i++) ...[
                                  _buildCustomTableRow(
                                    client: _previewRows[i]["client"],
                                    employee: _buildEmployeeAvatar(_previewRows[i]["initials"], _previewRows[i]["name"]),
                                    task: _previewRows[i]["task"],
                                    duration: _previewRows[i]["duration"],
                                    priority: _buildPriorityBadge(_previewRows[i]["priority"], _previewRows[i]["priorityBg"], _previewRows[i]["priorityText"]),
                                    dueDate: _buildDueDateCell(_previewRows[i]["date"], _previewRows[i]["timeLeft"], _previewRows[i]["timeColor"]),
                                    status: _buildStatusBadge(_previewRows[i]["status"], _previewRows[i]["statusBg"], _previewRows[i]["statusText"]),
                                  ),
                                  if (i != _previewRows.length - 1)
                                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                ],
                              ],
                            ),
                ),
              ],
            ),
          ),
        
          const SizedBox(height: 32),

          // ── WORK PERFORMANCE LINE GRAPH & DAILY PRODUCTIVITY MATRICES PANEL ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Side View Canvas: Line Graph
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  height: 350,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Work Performance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                          
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
                      const SizedBox(height: 10),
                      
                      // ── CUSTOM RENDERING SHEET FOR THE SYNCHRONIZED LINE GRAPH ──
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return CustomPaint(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              painter: PerformanceLineGraphPainter(
                                viewMode: _activePerformanceView,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right Side View Canvas: Segmented Progress Arc Donut Indicator (Synced Theme Colors)
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

          const SizedBox(height: 32),

          // ── ALERTS SECTION ──
          _buildAlertsSection(context),
        ],
      ),
    );
  }

  // ── SUB-COMPONENT BUILDER FACTORIES ──
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
                Container(width: 44, height: 44, color: headerColor, child: Icon(icon, color: Colors.white, size: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 44,
                    color: headerColor,
                    alignment: Alignment.center,
                    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.only(top: 14, bottom: 4), child: Text(value, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Color(0xFF111C24)))),
          Padding(padding: const EdgeInsets.only(bottom: 14), child: SizedBox(height: 24, child: Center(child: bottom))),
        ],
      ),
    );
  }

  Widget _buildCustomTableRow({required String client, required Widget employee, required String task, required String duration, required Widget priority, required Widget dueDate, required Widget status}) {
    return SizedBox(
      height: 64, 
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(client, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: employee),
          Expanded(flex: 2, child: Text(task, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text(duration, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: priority)),
          Expanded(flex: 3, child: dueDate),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: status)),
        ],
      ),
    );
  }

  Widget _buildEmployeeAvatar(String initials, String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26, height: 26,
          decoration: const BoxDecoration(color: Color(0xFFDCE4F7), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4A69B3))),
        ),
        const SizedBox(width: 10),
        Text(name, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPriorityBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.3)),
    );
  }

  Widget _buildDueDateCell(String date, String remaining, Color statusColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(remaining, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
      ],
    );
  }

  Widget _buildStatusBadge(String status, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.2)),
    );
  }

  Widget _buildProductivityLegend(String text, String percentage, Color indicatorColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569))),
          ],
        ),
        Text(percentage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Alerts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/notifications'),
                child: const Text("View All Notifications", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildAlertCard(icon: Icons.person_add_alt_1_outlined, borderColor: const Color(0xFF2563EB), title: "New Client Onboarded", subtitle: "Sarah Miller joined the GoDigital Team.", time: "24 MINS AGO")),
              const SizedBox(width: 16),
              Expanded(child: _buildAlertCard(icon: Icons.error_outline_rounded, borderColor: const Color(0xFFEF4444), title: "Urgent Review Required", subtitle: "Project 'GA Mall' has exceeded timeline.", time: "1 HOUR AGO")),
              const SizedBox(width: 16),
              Expanded(child: _buildAlertCard(icon: Icons.rate_review_outlined, borderColor: const Color(0xFFF59E0B), title: "Manager Review Complete", subtitle: "Feedback provided for GA Mall Website Performance.", time: "3 HOURS AGO")),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAlertCard({required IconData icon, required Color borderColor, required String title, required String subtitle, required String time}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border(left: BorderSide(color: borderColor, width: 4))),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3)),
                const SizedBox(height: 10),
                Text(time, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: borderColor.withOpacity(0.8), letterSpacing: 0.5)),
              ],
            ),
          ),
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

  static const TextStyle _columnTitleStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.8);
}

// ── CUSTOM RADIAL SEGMENT ARCS PAINTER ENGINE (MAPPED TO THE 4 CONTAINER ACCENT COLORS) ──
class MultiColorRadialArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    const double strokeWidth = 10.0;

    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFF1F5F9);

    canvas.drawCircle(center, radius, basePaint);

    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    // Segment 1: Total Clients Theme Arc (62%)
    double sweepAngle1 = (2 * math.pi) * 0.62;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle1, false, arcPaint..color = const Color(0xFF2A52BE));
    startAngle += sweepAngle1;

    // Segment 2: Active Clients Theme Arc (12%)
    double sweepAngle2 = (2 * math.pi) * 0.12;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle2, false, arcPaint..color = const Color(0xFF16A34A));
    startAngle += sweepAngle2;

    // Segment 3: Pending Tasks Theme Arc (18%)
    double sweepAngle3 = (2 * math.pi) * 0.18;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle3, false, arcPaint..color = const Color(0xFFE67E00));
    startAngle += sweepAngle3;

    // Segment 4: Inactive Clients Theme Arc (8%)
    double sweepAngle4 = (2 * math.pi) * 0.08;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle4, false, arcPaint..color = const Color(0xFFE10000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── NEW SMOOTH LINE GRAPH PAINTER (COLOR MATRIX COHERENT WITH BANNER THEME) ──
class PerformanceLineGraphPainter extends CustomPainter {
  final String viewMode;
  PerformanceLineGraphPainter({required this.viewMode});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double graphBottom = height - 25;
    final double graphTop = 20;

    // 1. Draw Subtle Horizontal Light Background Grid Lines
    final Paint gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      double y = graphTop + (graphBottom - graphTop) * (i / 4);
      canvas.drawLine(Offset(40, y), Offset(width, y), gridPaint);
    }

    // 2. Map Dynamic Plot Multi-Points based on view criteria flag toggle selection
    final List<double> values = viewMode == "Client" 
        ? [35, 65, 45, 85, 55, 70, 90]  // Client Data metrics trend lines
        : [50, 40, 80, 60, 85];         // Employee Data metrics trend lines

    final List<String> labels = viewMode == "Client"
        ? ["GA Mall", "Jyothi", "Brahmos", "GA Mall", "Nova ST", "Brahmos 2", "GA Mall 2"]
        : ["Pavi", "Susan", "Arun", "Mithra", "Sinu"];

    final int pointsCount = values.length;
    final double xStep = (width - 60) / (pointsCount - 1);

    List<Offset> points = [];
    for (int i = 0; i < pointsCount; i++) {
      double x = 40 + (i * xStep);
      // Normalized calculated coordinate points scaling mapping boundaries securely
      double normalizedY = graphBottom - ((values[i] / 100) * (graphBottom - graphTop));
      points.add(Offset(x, normalizedY));

      // Draw horizontal Bottom text Labels
      final TextPainter tp = TextPainter(
        text: TextSpan(text: labels[i], style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - (tp.width / 2), graphBottom + 6));
    }

    // ── 3. DRAW MULTI-COLOR SEGMENT LINES MATRIX ──
    // Points loop colors through your 4 primary core colors in order
    final List<Color> themeLineColors = [
      const Color(0xFF2A52BE), // Total Clients Color
      const Color(0xFF16A34A), // Active Client Color
      const Color(0xFFE67E00), // Client Pending Task Color
      const Color(0xFFE10000), // In Active Clients Color
    ];

    final Paint linePaint = Paint()
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < points.length - 1; i++) {
      Color currentSegmentColor = themeLineColors[i % themeLineColors.length];
      
      // Connect points with matching color segment lines
      canvas.drawLine(points[i], points[i + 1], linePaint..color = currentSegmentColor);
      
      // Draw outer point bullet nodes anchors
      canvas.drawCircle(points[i], 5.5, dotPaint..color = currentSegmentColor);
      canvas.drawCircle(points[i], 2.5, dotPaint..color = Colors.white);
    }
    
    // Render the final point node anchor cap
    Color lastColor = themeLineColors[(points.length - 1) % themeLineColors.length];
    canvas.drawCircle(points.last, 5.5, dotPaint..color = lastColor);
    canvas.drawCircle(points.last, 2.5, dotPaint..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant PerformanceLineGraphPainter oldDelegate) => oldDelegate.viewMode != viewMode;
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