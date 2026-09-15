// lib/screens/admin_dashboard/admin_dashboard.dart
//
// Admin Command Center — redesigned with the premium style of Ads Handler & Designer Dashboards
// including animations, proper spacing, removing Onboard Client from quick-access/nav hub,
// and strictly preserving all backend functions and structure.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/widgets/metric_card.dart';
import 'package:godigital_portal/widgets/alerts_section.dart';

class _Palette {
  static const primary = Color(0xFF0757D5);
  static const primary2 = Color(0xFF1D74E8);
  static const completed = Color(0xFF16A34A);
  static const onHold = Color(0xFFD97706);
  static const rejected = Color(0xFFDC2626);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const bg = Color(0xFFF8FAFC);
}

class _NavTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final Object? arguments;
  const _NavTile(this.title, this.subtitle, this.icon, this.color, this.route, {this.arguments});
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  static String get _baseUrl => ApiConfig.baseUrl;

  bool _loading = true;
  String? _error;

  int _totalClients = 0;
  int _activeClients = 0;
  int _totalEmployees = 0;
  double _avgPerformance = 0;
  int _totalPendingTasks = 0;
  int _totalTasksToday = 0;
  List<Map<String, dynamic>> _topPerformers = [];
  List<Map<String, dynamic>> _plannerSubmittedToday = [];

  List<Map<String, dynamic>> _recentNotifications = [];

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
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _authHeaders() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer ${authService.token}'};
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await _authHeaders();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/clients'), headers: headers).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_baseUrl/employees'), headers: headers).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_baseUrl/performance/overview?mode=daily&date=$today'), headers: headers).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_baseUrl/day-planner/submissions?date=$today&type=Morning'), headers: headers).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_baseUrl/day-planner/submissions?date=$today&type=Evening'), headers: headers).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_baseUrl/dashboard/admin-notifications'), headers: headers).catchError((_) => http.Response('', 500)),
      ]);

      if (results[0].statusCode == 200) {
        final body = jsonDecode(results[0].body);
        final clients = List<Map<String, dynamic>>.from(body['data'] ?? []);
        _totalClients = clients.length;
        _activeClients = clients.where((c) => c['is_active'] == 1 || c['is_active'] == true).length;
      }

      if (results[1].statusCode == 200) {
        final body = jsonDecode(results[1].body);
        final employees = List<Map<String, dynamic>>.from(body['data'] ?? []);
        _totalEmployees = employees.length;
      }

      if (results[2].statusCode == 200) {
        final body = jsonDecode(results[2].body);
        final employees = List<Map<String, dynamic>>.from(body['data']?['employees'] ?? []);

        if (employees.isNotEmpty) {
          final totalScore = employees.fold<num>(0, (a, e) => a + (e['performancePct'] as num? ?? 0));
          _avgPerformance = totalScore / employees.length;
          _totalPendingTasks = employees.fold<int>(0, (a, e) => a + ((e['pending'] as num? ?? 0).toInt()));
          _totalTasksToday = employees.fold<int>(0, (a, e) => a + ((e['totalTasks'] as num? ?? 0).toInt()));

          final sorted = [...employees]..sort((a, b) => (b['performancePct'] as num).compareTo(a['performancePct'] as num));
          _topPerformers = sorted.take(5).toList();
        }
      }

      final Map<String, Map<String, dynamic>> plannerMap = {};
      if (results[3].statusCode == 200) {
        final body = jsonDecode(results[3].body);
        for (final s in List<Map<String, dynamic>>.from(body['submissions'] ?? [])) {
          if (s['submitted'] != true) continue;
          final name = s['employeeName'];
          plannerMap.putIfAbsent(name, () => {'name': name, 'morning': false, 'evening': false, 'workingSecs': 0});
          plannerMap[name]!['morning'] = true;
          plannerMap[name]!['workingSecs'] = (s['total_working_secs'] as num?)?.toInt() ?? 0;
        }
      }
      if (results[4].statusCode == 200) {
        final body = jsonDecode(results[4].body);
        for (final s in List<Map<String, dynamic>>.from(body['submissions'] ?? [])) {
          if (s['submitted'] != true) continue;
          final name = s['employeeName'];
          plannerMap.putIfAbsent(name, () => {'name': name, 'morning': false, 'evening': false, 'workingSecs': 0});
          plannerMap[name]!['evening'] = true;
          final secs = (s['total_working_secs'] as num?)?.toInt() ?? 0;
          if (secs > (plannerMap[name]!['workingSecs'] as int)) plannerMap[name]!['workingSecs'] = secs;
        }
      }
      _plannerSubmittedToday = plannerMap.values.toList()..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (results[5].statusCode == 200) {
        final body = jsonDecode(results[5].body);
        _recentNotifications = List<Map<String, dynamic>>.from(body["data"] ?? []);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Some dashboard data could not be loaded';
        _loading = false;
      });
    }
  }

  // ----------------------------------------------------------------
  // Navigation hub definition (Onboard Client removed)
  // ----------------------------------------------------------------
  static const Map<String, List<_NavTile>> _navGroups = {
    'Clients': [
      _NavTile('Client Details', 'Browse & manage clients', Icons.groups_rounded, _Palette.primary2, '/client'),
      _NavTile('Client History', 'Past activity & records', Icons.history_rounded, Color(0xFF9333EA), '/client-history'),
    ],
    'Sales & Billing': [
      _NavTile('Packages', 'Manage service packages', Icons.inventory_2_rounded, Color(0xFF0891B2), '/packages'),
      _NavTile('Quotations', 'All quotations', Icons.request_quote_rounded, Color(0xFF7C3AED), '/quotations'),
      _NavTile('Create Quotation', 'Draft a new quotation', Icons.note_add_rounded, Color(0xFF7C3AED), '/create-quotation'),
      _NavTile('Invoices', 'All invoices', Icons.receipt_long_rounded, _Palette.completed, '/invoice'),
      _NavTile('Create Invoice', 'Bill a client', Icons.add_card_rounded, _Palette.completed, '/add-invoice'),
    ],
    'Work & Performance': [
      _NavTile('Task Assignment', 'Assign work to employees', Icons.assignment_ind_rounded, _Palette.onHold, '/tasks'),
      _NavTile('Daily Planner', "Employees' day plans", Icons.calendar_today_rounded, Color(0xFF0EA5E9), '/daily-planner'),
      _NavTile('Employee Status', 'Who is doing what, live', Icons.person_pin_circle_rounded, Color(0xFF16A34A), '/employee-status'),
      _NavTile('Manager Review', 'Approve / rework / reject', Icons.rate_review_rounded, Color(0xFFD97706), '/manager-review'),
      _NavTile('Time Manager', 'Task timing master data', Icons.timer_rounded, Color(0xFF4F46E5), '/time-manager'),
      _NavTile('Performance', 'Full productivity dashboard', Icons.insights_rounded, _Palette.primary, '/performance'),
    ],
    'Admin & System': [
      _NavTile('Admin Panel', 'Roles, users & access', Icons.admin_panel_settings_rounded, Color(0xFF334155), '/admin-panel'),
      _NavTile('Attendance', 'HRMS attendance', Icons.fingerprint_rounded, Color(0xFF0EA5E9), '/attendance'),
      _NavTile('Notifications', 'Recent alerts', Icons.notifications_rounded, Color(0xFFDC2626), '/notifications'),
      _NavTile('Settings', 'App configuration', Icons.settings_rounded, Color(0xFF64748B), '/settings'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final adminName = authService.user?['fullName']?.toString().split(' ').first ?? 'Admin';
    final isMainAdmin = authService.user?['isMainAdmin'] == true;
    final allowedPages = List<String>.from(
      (authService.user?['allowed_pages'] as List?)?.map((p) => p.toString()) ?? [],
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return AdminLayout(
      pageTitle: 'Dashboard',
      currentRoute: '/admin',
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 38,
              isMobile ? 18 : 30,
              isMobile ? 16 : 38,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _welcomeSection(adminName),
                SizedBox(height: isMobile ? 20 : 28),
                _summaryCards(),
                SizedBox(height: isMobile ? 20 : 28),
                if (_error != null) _buildErrorBanner(),
                if (_topPerformers.isNotEmpty || _plannerSubmittedToday.isNotEmpty) ...[
                  _buildTopSectionRow(isMobile),
                  SizedBox(height: isMobile ? 20 : 28),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 1100;
                    return _buildNavHub(isMobile, isTablet, isMainAdmin, allowedPages);
                  },
                ),
                SizedBox(height: isMobile ? 20 : 28),
                AlertsSection(
                  notifications: _recentNotifications,
                  onViewAll: () => Navigator.pushNamed(context, '/notifications'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeSection(String adminName) {
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
                    _welcomeContent(adminName),
                    const SizedBox(height: 18),
                    _welcomeDate(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _welcomeContent(adminName)),
                    const SizedBox(width: 20),
                    _welcomeDate(),
                  ],
                );
        },
      ),
    );
  }

  Widget _welcomeContent(String adminName) {
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
              text: 'ADMIN COMMAND CENTER',
            ),
            _heroChip(
              icon: Icons.timer_rounded,
              iconColor: const Color(0xFF93C5FD),
              text: 'LIVE DASHBOARD',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Welcome back, $adminName! ✨',
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
    final now = DateTime.now();
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final dateStr = '${months[now.month]} ${now.day.toString().padLeft(2, '0')}, ${now.year} - Today';

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
            dateStr,
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
        final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                icon: Icons.groups_rounded,
                title: 'Total Clients',
                value: _loading ? '—' : _totalClients.toString().padLeft(2, '0'),
                label: 'Current',
                color: AppColors.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                icon: Icons.account_tree_outlined,
                title: 'Active Clients',
                value: _loading ? '—' : _activeClients.toString().padLeft(2, '0'),
                label: 'Verified',
                color: AppColors.green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                icon: Icons.pause_circle_outline,
                title: 'Team Performance',
                value: _loading ? '—' : '${_avgPerformance.toStringAsFixed(0)}%',
                label: 'Average Score',
                color: AppColors.orange,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: MetricCard(
                icon: Icons.cancel_outlined,
                title: 'Pending Work',
                value: _loading ? '—' : _totalPendingTasks.toString().padLeft(2, '0'),
                label: 'High Risk',
                color: AppColors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF92400E)),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E)))),
      ]),
    );
  }

  Widget _buildTopSectionRow(bool isMobile) {
    final left = _buildTopPerformers(isMobile);
    final right = _buildPlannerSubmissions(isMobile);

    if (isMobile) {
      return Column(children: [left, const SizedBox(height: 14), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 22),
        Expanded(child: right),
      ],
    );
  }

  String _formatHours(int secs) {
    final hrs = secs ~/ 3600;
    final mins = (secs % 3600) ~/ 60;
    if (hrs > 0) return '${hrs}h ${mins}m';
    return '${mins}m';
  }

  Widget _buildPlannerSubmissions(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Today's Day Planner", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _Palette.ink)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/daily-planner'),
                child: const Text('View all', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0757D5))),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('${_plannerSubmittedToday.length} member${_plannerSubmittedToday.length == 1 ? '' : 's'} submitted', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _Palette.muted)),
          const SizedBox(height: 12),
          if (_plannerSubmittedToday.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No planner submissions yet today', style: TextStyle(fontSize: 12, color: _Palette.muted))),
            )
          else
            ...List.generate(_plannerSubmittedToday.length, (i) {
              final entry = _plannerSubmittedToday[i];
              final morning = entry['morning'] == true;
              final evening = entry['evening'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFF16A34A).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF16A34A)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(entry['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _Palette.ink)),
                    ),
                    if (morning) _plannerBadge('AM', const Color(0xFF1D74E8)),
                    if (morning && evening) const SizedBox(width: 4),
                    if (evening) _plannerBadge('PM', const Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Text(_formatHours(entry['workingSecs'] as int), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _Palette.muted)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _plannerBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color)),
    );
  }

  Widget _buildTopPerformers(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Today's Top Performers", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _Palette.ink)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/performance'),
                child: const Text('View all', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0757D5))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(_topPerformers.length, (i) {
            final emp = _topPerformers[i];
            final score = (emp['performancePct'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFF0757D5).withOpacity(0.1), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF0757D5))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(emp['fullName'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _Palette.ink)),
                  ),
                  SizedBox(
                    width: isMobile ? 90 : 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (score / 100).clamp(0, 1),
                        minHeight: 7,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation(score >= 70 ? const Color(0xFF16A34A) : (score >= 50 ? const Color(0xFFD97706) : const Color(0xFFDC2626))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 34, child: Text('${score.toInt()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: _Palette.ink))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static const List<String> _controllableRoutes = [
    '/admin', '/client-history', '/client-credentials', '/packages', '/quotations',
    '/quotation', '/invoice', '/tasks', '/daily-planner', '/employee-status',
    '/manager-review', '/notifications', '/performance', '/admin-panel', '/time-manager',
  ];

  Widget _buildNavHub(bool isMobile, bool isTablet, bool isMainAdmin, List<String> allowedPages) {
    final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);

    bool tileAllowed(_NavTile tile) {
      if (isMainAdmin) return true;
      if (!_controllableRoutes.contains(tile.route)) return true;
      return allowedPages.contains(tile.route);
    }

    final visibleGroups = <String, List<_NavTile>>{};
    for (final group in _navGroups.entries) {
      final visibleTiles = group.value.where(tileAllowed).toList();
      if (visibleTiles.isNotEmpty) visibleGroups[group.key] = visibleTiles;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _Palette.ink)),
        const SizedBox(height: 4),
        Text(
          isMainAdmin ? 'Every admin page, one tap away.' : 'The pages your role has access to.',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _Palette.muted),
        ),
        const SizedBox(height: 14),
        if (visibleGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _Palette.border)),
            child: const Center(child: Text('No pages have been granted to your role yet.', style: TextStyle(fontSize: 12, color: _Palette.muted))),
          )
        else
          for (final group in visibleGroups.entries) ...[
            Text(group.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _Palette.muted, letterSpacing: 0.3)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isMobile ? 3.6 : 3.2,
              children: group.value.map(_navTile).toList(),
            ),
            const SizedBox(height: 18),
          ],
      ],
    );
  }

  Widget _navTile(_NavTile tile) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pushNamed(context, tile.route, arguments: tile.arguments),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _Palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tile.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(tile.icon, size: 18, color: tile.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tile.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _Palette.ink)),
                  Text(tile.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _Palette.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: _Palette.muted),
          ],
        ),
      ),
    );
  }
}