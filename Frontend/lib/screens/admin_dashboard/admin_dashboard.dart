
// lib/screens/admin_dashboard/admin_dashboard.dart
//
// GoDigital Admin Command Center
// Premium 2050 UI
// - 6 KPI cards
// - Animated hero
// - Animated KPI cards
// - Hover / press interactions
// - Responsive mobile/tablet/desktop
// - Quick Access animated cards
// - Existing backend structure preserved
// - Existing permissions preserved
// - Top Performers preserved
// - Day Planner preserved
// - Alerts preserved

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import 'package:godigital_portal/widgets/alerts_section.dart';

class _Palette {
  static const primary = Color(0xFF0757D5);
  static const primary2 = Color(0xFF1D74E8);
  static const deepBlue = Color(0xFF04296B);
  static const cyan = Color(0xFF0891B2);
  static const completed = Color(0xFF16A34A);
  static const onHold = Color(0xFFD97706);
  static const rejected = Color(0xFFDC2626);
  static const purple = Color(0xFF7C3AED);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const bg = Color(0xFFF6F9FE);
  static const softBlue = Color(0xFFEAF2FF);
}

class _NavTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final Object? arguments;

  const _NavTile(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.route) : arguments = null;
}

class _KpiData {
  final String title;
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _KpiData({
    required this.title,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  static String get _baseUrl => ApiConfig.baseUrl;

  bool _loading = true;
  String? _error;

  int _totalClients = 0;
  int _activeClients = 0;
  int _totalEmployees = 0;
  double _avgPerformance = 0;
  int _totalPendingTasks = 0;
  int _totalTasksToday = 0;

  double _invoiceCollected = 0;
  double _invoicePending = 0;

  List<Map<String, dynamic>> _topPerformers = [];
  List<Map<String, dynamic>> _plannerSubmittedToday = [];
  List<Map<String, dynamic>> _recentNotifications = [];

  late AnimationController _entranceController;
  late AnimationController _heroController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    _entranceController.forward();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _heroController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _authHeaders() async {
    final authService = Provider.of<AuthService>(
      context,
      listen: false,
    );

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${authService.token}',
    };
  }

  Future<void> _fetchDashboardData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final headers = await _authHeaders();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final results = await Future.wait([
        http
            .get(
              Uri.parse('$_baseUrl/clients'),
              headers: headers,
            )
            .catchError(
              (_) => http.Response('', 500),
            ),
        http
            .get(
              Uri.parse('$_baseUrl/employees'),
              headers: headers,
            )
            .catchError(
              (_) => http.Response('', 500),
            ),
        http
            .get(
              Uri.parse(
                '$_baseUrl/performance/overview?mode=daily&date=$today',
              ),
              headers: headers,
            )
            .catchError(
              (_) => http.Response('', 500),
            ),
        http
            .get(
              Uri.parse(
                '$_baseUrl/day-planner/submissions?date=$today&type=Morning',
              ),
              headers: headers,
            )
            .catchError(
              (_) => http.Response('', 500),
            ),
        http
            .get(
              Uri.parse(
                '$_baseUrl/day-planner/submissions?date=$today&type=Evening',
              ),
              headers: headers,
            )
            .catchError(
              (_) => http.Response('', 500),
            ),
        http
            .get(
              Uri.parse('$_baseUrl/dashboard/admin-notifications'),
              headers: headers,
            )
            .catchError(
              (_) => http.Response('', 500),
            ),
        http
            .get(
              Uri.parse('$_baseUrl/invoices'),
              headers: headers,
            )
            .catchError(
              (_) => http.Response('', 500),
            ),
      ]);

      // ---------------------------------------------------------------
      // CLIENTS
      // ---------------------------------------------------------------
      if (results[0].statusCode == 200) {
        final body = _decodeMap(results[0].body);

        final clients = _extractList(
          body,
          keys: const ['data', 'clients', 'rows'],
        );

        _totalClients = clients.length;

        _activeClients = clients.where((client) {
          final active = client['is_active'];

          return active == 1 ||
              active == true ||
              active?.toString().toLowerCase() == 'true';
        }).length;
      }

      // ---------------------------------------------------------------
      // EMPLOYEES
      // ---------------------------------------------------------------
      if (results[1].statusCode == 200) {
        final body = _decodeMap(results[1].body);

        final employees = _extractList(
          body,
          keys: const ['data', 'employees', 'rows'],
        );

        _totalEmployees = employees.length;
      }

      // ---------------------------------------------------------------
      // PERFORMANCE
      // ---------------------------------------------------------------
      if (results[2].statusCode == 200) {
        final body = _decodeMap(results[2].body);

        final employees = _extractNestedList(
          body,
          firstKeys: const ['data'],
          secondKeys: const ['employees'],
        );

        if (employees.isNotEmpty) {
          final totalScore = employees.fold<num>(
            0,
            (sum, employee) {
              return sum + _toDouble(
                employee['performancePct'],
              );
            },
          );

          _avgPerformance = totalScore / employees.length;

          _totalPendingTasks = employees.fold<int>(
            0,
            (sum, employee) {
              return sum + _toInt(employee['pending']);
            },
          );

          _totalTasksToday = employees.fold<int>(
            0,
            (sum, employee) {
              return sum + _toInt(employee['totalTasks']);
            },
          );

          final sorted = [...employees];

          sorted.sort(
            (a, b) {
              return _toDouble(
                b['performancePct'],
              ).compareTo(
                _toDouble(
                  a['performancePct'],
                ),
              );
            },
          );

          _topPerformers = sorted.take(5).toList();
        } else {
          _avgPerformance = 0;
          _totalPendingTasks = 0;
          _totalTasksToday = 0;
          _topPerformers = [];
        }
      }

      // ---------------------------------------------------------------
      // DAY PLANNER
      // ---------------------------------------------------------------
      final Map<String, Map<String, dynamic>> plannerMap = {};

      if (results[3].statusCode == 200) {
        final body = _decodeMap(results[3].body);

        final submissions = _extractList(
          body,
          keys: const ['submissions', 'data', 'rows'],
        );

        for (final submission in submissions) {
          if (submission['submitted'] != true &&
              submission['submitted']?.toString().toLowerCase() != 'true') {
            continue;
          }

          final name =
              submission['employeeName']?.toString().trim().isNotEmpty == true
                  ? submission['employeeName'].toString()
                  : 'Employee';

          plannerMap.putIfAbsent(
            name,
            () => {
              'name': name,
              'morning': false,
              'evening': false,
              'workingSecs': 0,
            },
          );

          plannerMap[name]!['morning'] = true;

          plannerMap[name]!['workingSecs'] =
              _toInt(submission['total_working_secs']);
        }
      }

      if (results[4].statusCode == 200) {
        final body = _decodeMap(results[4].body);

        final submissions = _extractList(
          body,
          keys: const ['submissions', 'data', 'rows'],
        );

        for (final submission in submissions) {
          if (submission['submitted'] != true &&
              submission['submitted']?.toString().toLowerCase() != 'true') {
            continue;
          }

          final name =
              submission['employeeName']?.toString().trim().isNotEmpty == true
                  ? submission['employeeName'].toString()
                  : 'Employee';

          plannerMap.putIfAbsent(
            name,
            () => {
              'name': name,
              'morning': false,
              'evening': false,
              'workingSecs': 0,
            },
          );

          plannerMap[name]!['evening'] = true;

          final secs = _toInt(
            submission['total_working_secs'],
          );

          if (secs > _toInt(plannerMap[name]!['workingSecs'])) {
            plannerMap[name]!['workingSecs'] = secs;
          }
        }
      }

      _plannerSubmittedToday = plannerMap.values.toList();

      _plannerSubmittedToday.sort(
        (a, b) {
          return (a['name'] ?? '')
              .toString()
              .compareTo(
                (b['name'] ?? '').toString(),
              );
        },
      );

      // ---------------------------------------------------------------
      // NOTIFICATIONS
      // ---------------------------------------------------------------
      if (results[5].statusCode == 200) {
        final body = _decodeMap(results[5].body);

        _recentNotifications = _extractList(
          body,
          keys: const ['data', 'notifications', 'rows'],
        );
      }

      // ---------------------------------------------------------------
      // INVOICES
      // ---------------------------------------------------------------
      if (results[6].statusCode == 200) {
        final body = _decodeMap(results[6].body);

        final invoices = _extractList(
          body,
          keys: const ['data', 'invoices', 'rows'],
        );

        double collected = 0;
        double pending = 0;

        for (final invoice in invoices) {
          final total = _firstAmount(
            invoice,
            const [
              'grandTotal',
              'grand_total',
              'totalAmount',
              'total_amount',
              'total',
              'amount',
              'invoiceTotal',
              'invoice_total',
            ],
          );

          final paid = _firstAmount(
            invoice,
            const [
              'paidAmount',
              'paid_amount',
              'amountPaid',
              'amount_paid',
              'collectedAmount',
              'collected_amount',
            ],
          );

          final status =
              invoice['status']?.toString().trim().toUpperCase() ?? '';

         if (status == 'PAID') {
  collected += total;
} else if (status == 'PARTIAL') {
  collected += paid;
  pending += (total - paid)
      .clamp(0, double.infinity)
      .toDouble();
} else if (status == 'DRAFT') {
  // Draft invoices are not treated as pending collection.
} else {
  final remaining = total - paid;

  if (remaining > 0) {
    pending += remaining;
  } else if (paid > 0) {
    collected += paid;
  }
}
        }

        _invoiceCollected = collected;
        _invoicePending = pending;
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Some dashboard data could not be loaded';
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _decodeMap(String raw) {
    if (raw.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return {};
    } catch (_) {
      return {};
    }
  }

  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> body, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = body[key];

      if (value is List) {
        return value
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }
    }

    return [];
  }

  List<Map<String, dynamic>> _extractNestedList(
    Map<String, dynamic> body, {
    required List<String> firstKeys,
    required List<String> secondKeys,
  }) {
    dynamic current = body;

    for (final key in firstKeys) {
      if (current is Map) {
        current = current[key];
      }
    }

    if (current is Map) {
      for (final key in secondKeys) {
        current = current[key];
      }
    }

    if (current is List) {
      return current
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    return [];
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString().replaceAll(',', ''),
        ) ??
        double.tryParse(
          value.toString().replaceAll(',', ''),
        )?.toInt() ??
        0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is double) return value;

    if (value is num) return value.toDouble();

    return double.tryParse(
          value.toString().replaceAll(',', '').replaceAll('₹', '').trim(),
        ) ??
        0;
  }

  double _firstAmount(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (data.containsKey(key)) {
        return _toDouble(data[key]);
      }
    }

    return 0;
  }

  // ---------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------

  static const Map<String, List<_NavTile>> _navGroups = {
    'Clients': [
      _NavTile(
        'Client Details',
        'Browse & manage clients',
        Icons.groups_rounded,
        _Palette.primary2,
        '/client',
      ),
      _NavTile(
        'Client History',
        'Past activity & records',
        Icons.history_rounded,
        Color(0xFF9333EA),
        '/client-history',
      ),
    ],
    'Sales & Billing': [
      _NavTile(
        'Packages',
        'Manage service packages',
        Icons.inventory_2_rounded,
        Color(0xFF0891B2),
        '/packages',
      ),
      _NavTile(
        'Quotations',
        'All quotations',
        Icons.request_quote_rounded,
        Color(0xFF7C3AED),
        '/quotations',
      ),
      _NavTile(
        'Create Quotation',
        'Draft a new quotation',
        Icons.note_add_rounded,
        Color(0xFF7C3AED),
        '/create-quotation',
      ),
      _NavTile(
        'Invoices',
        'All invoices',
        Icons.receipt_long_rounded,
        _Palette.completed,
        '/invoice',
      ),
      _NavTile(
        'Create Invoice',
        'Bill a client',
        Icons.add_card_rounded,
        _Palette.completed,
        '/add-invoice',
      ),
    ],
    'Work & Performance': [
      _NavTile(
        'Task Assignment',
        'Assign work to employees',
        Icons.assignment_ind_rounded,
        _Palette.onHold,
        '/tasks',
      ),
      _NavTile(
        'Daily Planner',
        "Employees' day plans",
        Icons.calendar_today_rounded,
        Color(0xFF0EA5E9),
        '/daily-planner',
      ),
      _NavTile(
        'Employee Status',
        'Who is doing what, live',
        Icons.person_pin_circle_rounded,
        Color(0xFF16A34A),
        '/employee-status',
      ),
      _NavTile(
        'Manager Review',
        'Approve / rework / reject',
        Icons.rate_review_rounded,
        Color(0xFFD97706),
        '/manager-review',
      ),
      _NavTile(
        'Time Manager',
        'Task timing master data',
        Icons.timer_rounded,
        Color(0xFF4F46E5),
        '/time-manager',
      ),
      _NavTile(
        'Performance',
        'Full productivity dashboard',
        Icons.insights_rounded,
        _Palette.primary,
        '/performance',
      ),
    ],
    'Admin & System': [
      _NavTile(
        'Admin Panel',
        'Roles, users & access',
        Icons.admin_panel_settings_rounded,
        Color(0xFF334155),
        '/admin-panel',
      ),
      _NavTile(
        'Attendance',
        'HRMS attendance',
        Icons.fingerprint_rounded,
        Color(0xFF0EA5E9),
        '/attendance',
      ),
      _NavTile(
        'Notifications',
        'Recent alerts',
        Icons.notifications_rounded,
        Color(0xFFDC2626),
        '/notifications',
      ),
      _NavTile(
        'Settings',
        'App configuration',
        Icons.settings_rounded,
        Color(0xFF64748B),
        '/settings',
      ),
    ],
  };

  static const List<String> _controllableRoutes = [
    '/admin',
    '/client-history',
    '/client-credentials',
    '/packages',
    '/quotations',
    '/quotation',
    '/invoice',
    '/tasks',
    '/daily-planner',
    '/employee-status',
    '/manager-review',
    '/notifications',
    '/performance',
    '/admin-panel',
    '/time-manager',
  ];

  // ---------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(
      context,
      listen: false,
    );

    final adminName =
        authService.user?['fullName']
            ?.toString()
            .split(' ')
            .first ??
        'Admin';

    final isMainAdmin = authService.user?['isMainAdmin'] == true;

    final allowedPages = List<String>.from(
      (authService.user?['allowed_pages'] as List?)
              ?.map(
                (page) => page.toString(),
              ) ??
          [],
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return AdminLayout(
      pageTitle: 'Dashboard',
      currentRoute: '/admin',
      child: RefreshIndicator(
        color: _Palette.primary,
        backgroundColor: Colors.white,
        onRefresh: _fetchDashboardData,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isMobile ? 14 : 30,
                isMobile ? 14 : 26,
                isMobile ? 14 : 30,
                34,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _welcomeSection(adminName),

                  SizedBox(
                    height: isMobile ? 16 : 24,
                  ),

                  _summaryCards(),

                  SizedBox(
                    height: isMobile ? 20 : 28,
                  ),

                  if (_error != null) ...[
                    _buildErrorBanner(),
                    const SizedBox(height: 14),
                  ],

                  // 🟢 Show Top Performers and Day Planner ONLY for Main Admin
                  if (isMainAdmin &&
                      (_topPerformers.isNotEmpty ||
                          _plannerSubmittedToday.isNotEmpty)) ...[
                    _buildTopSectionRow(isMobile),
                    SizedBox(
                      height: isMobile ? 22 : 30,
                    ),
                  ],

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet =
                          constraints.maxWidth >= 720 &&
                          constraints.maxWidth < 1100;

                      return _buildNavHub(
                        isMobile,
                        isTablet,
                        isMainAdmin,
                        allowedPages,
                      );
                    },
                  ),

                  SizedBox(
                    height: isMobile ? 20 : 28,
                  ),

                  AlertsSection(
                    notifications: _recentNotifications,
                    onViewAll: () {
                      Navigator.pushNamed(
                        context,
                        '/notifications',
                      );
                    },
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // HERO
  // ---------------------------------------------------------------------

  Widget _welcomeSection(String adminName) {
    return AnimatedBuilder(
      animation: _heroController,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(
          _heroController.value,
        );

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
                Color(0xFF031C4C),
                Color(0xFF0757D5),
                Color(0xFF1D74E8),
              ],
              stops: [
                0.0,
                0.52,
                1.0,
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: _Palette.primary.withValues(
                  alpha: 0.24 + (t * 0.08),
                ),
                blurRadius: 34 + (t * 8),
                offset: Offset(
                  0,
                  14 + (t * 4),
                ),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -35 + (t * 20),
                top: -55,
                child: _heroOrb(
                  size: 170,
                  opacity: 0.11,
                ),
              ),
              Positioned(
                right: 90 - (t * 30),
                bottom: -90,
                child: _heroOrb(
                  size: 190,
                  opacity: 0.07,
                ),
              ),
              Positioned(
                left: 30 + (t * 25),
                bottom: -110,
                child: _heroOrb(
                  size: 150,
                  opacity: 0.05,
                ),
              ),
              child ??
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxWidth < 650;

                      return compact
                          ? Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _welcomeContent(adminName),
                                const SizedBox(height: 18),
                                _welcomeDate(),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child:
                                      _welcomeContent(
                                    adminName,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                _welcomeDate(),
                              ],
                            );
                    },
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroOrb({
    required double size,
    required double opacity,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(
                alpha: opacity * 0.7,
              ),
              blurRadius: 55,
              spreadRadius: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeContent(String adminName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 8,
          children: [
            _heroChip(
              icon: Icons.verified_rounded,
              iconColor: const Color(0xFF4ADE80),
              text: 'ADMIN COMMAND CENTER',
            ),
            _heroChip(
              icon: Icons.bolt_rounded,
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
            letterSpacing: -0.7,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          "Your live GoDigital command center for clients, people, billing, tasks and productivity.",
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: 0.84),
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            _heroStatusDot(),
            const SizedBox(width: 8),
            Text(
              _loading
                  ? 'Synchronizing live data...'
                  : 'All dashboard systems synchronized',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroStatusDot() {
    return AnimatedBuilder(
      animation: _heroController,
      builder: (context, child) {
        final scale = 0.88 +
            (_heroController.value * 0.16);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4ADE80),
            ),
          ),
        );
      },
    );
  }

  Widget _heroChip({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeDate() {
    final now = DateTime.now();

    final dateStr = DateFormat(
      'MMMM dd, yyyy',
    ).format(now);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'TODAY',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // SIX KPI CARDS
  // ---------------------------------------------------------------------

// ---------------------------------------------------------------------
  // SUMMARY KPI CARDS (Filtered by Role & Responsive 3-Column Layout)
  // ---------------------------------------------------------------------

  Widget _summaryCards() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isMainAdmin = authService.user?['isMainAdmin'] == true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns;

        if (width >= 720) {
          columns = 3;
        } else if (width >= 600) {
          columns = 3;
        } else {
          columns = 1; // 1 item per row on mobile
        }

        final gap = width >= 720 ? 15.0 : 12.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;

        // Base list of all 6 KPI cards
        final allCards = [
          _KpiData(
            title: 'Total Active Clients',
            value: _loading
                ? '—'
                : _activeClients.toString().padLeft(2, '0'),
            label: 'Currently active',
            icon: Icons.groups_rounded,
            color: _Palette.primary,
            route: '/client',
          ),
          _KpiData(
            title: 'Total Employees',
            value: _loading
                ? '—'
                : _totalEmployees.toString().padLeft(2, '0'),
            label: 'Team members',
            icon: Icons.badge_rounded,
            color: _Palette.purple,
            route: '/employee-status',
          ),
          _KpiData(
            title: 'Invoice Collected',
            value: _loading ? '—' : _formatCurrency(_invoiceCollected),
            label: 'Paid / collected',
            icon: Icons.payments_rounded,
            color: _Palette.completed,
            route: '/invoice',
          ),
          _KpiData(
            title: 'Invoice Pending',
            value: _loading ? '—' : _formatCurrency(_invoicePending),
            label: 'Outstanding amount',
            icon: Icons.account_balance_wallet_rounded,
            color: _Palette.onHold,
            route: '/invoice',
          ),
          _KpiData(
            title: 'Pending Tasks',
            value: _loading
                ? '—'
                : _totalPendingTasks.toString().padLeft(2, '0'),
            label: 'Needs attention',
            icon: Icons.pending_actions_rounded,
            color: _Palette.rejected,
            route: '/tasks',
          ),
          _KpiData(
            title: 'Team Productivity',
            value: _loading
                ? '—'
                : '${_avgPerformance.toStringAsFixed(0)}%',
            label: 'Average today',
            icon: Icons.insights_rounded,
            color: _Palette.primary2,
            route: '/performance',
          ),
        ];

        // Filter cards based on whether the user is the Main Admin
        final cards = allCards.where((card) {
          if (isMainAdmin) return true;
          // For non-main admins, exclude Total Employees, Pending Tasks, and Team Productivity
          if (card.title == 'Total Employees' ||
              card.title == 'Pending Tasks' ||
              card.title == 'Team Productivity') {
            return false;
          }
          return true;
        }).toList();

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map(
            (card) {
              return SizedBox(
                width: cardWidth,
                child: _AnimatedKpiCard(
                  data: card,
                  loading: _loading,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      card.route,
                    );
                  },
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    }

    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }

    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }

    return '₹${value.toStringAsFixed(0)}';
  }

  // ---------------------------------------------------------------------
  // ERROR
  // ---------------------------------------------------------------------

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B)
                  .withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retry',
            onPressed: _fetchDashboardData,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // TOP SECTION
  // ---------------------------------------------------------------------

  Widget _buildTopSectionRow(bool isMobile) {
    final left = _buildTopPerformers(isMobile);
    final right = _buildPlannerSubmissions(isMobile);

    if (isMobile) {
      return Column(
        children: [
          left,
          const SizedBox(height: 14),
          right,
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  Widget _premiumSectionCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5ECF6),
        ),
        boxShadow: [
          BoxShadow(
            color: _Palette.primary.withValues(alpha: 0.055),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPlannerSubmissions(bool isMobile) {
    return _premiumSectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(
                Icons.calendar_today_rounded,
                _Palette.primary2,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Today's Day Planner",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _Palette.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/daily-planner',
                  );
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _Palette.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 3),

          Text(
            '${_plannerSubmittedToday.length} member${_plannerSubmittedToday.length == 1 ? '' : 's'} submitted',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _Palette.muted,
            ),
          ),

          const SizedBox(height: 11),

          if (_plannerSubmittedToday.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 20,
              ),
              child: Center(
                child: Text(
                  'No planner submissions yet today',
                  style: TextStyle(
                    fontSize: 12,
                    color: _Palette.muted,
                  ),
                ),
              ),
            )
          else
            ...List.generate(
              _plannerSubmittedToday.length,
              (i) {
                final entry =
                    _plannerSubmittedToday[i];

                final morning =
                    entry['morning'] == true;

                final evening =
                    entry['evening'] == true;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 27,
                        height: 27,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _Palette.completed
                              .withValues(alpha: 0.09),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: _Palette.completed,
                        ),
                      ),

                      const SizedBox(width: 9),

                      Expanded(
                        child: Text(
                          entry['name'] ?? '',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _Palette.ink,
                          ),
                        ),
                      ),

                      if (morning)
                        _plannerBadge(
                          'AM',
                          _Palette.primary2,
                        ),

                      if (morning && evening)
                        const SizedBox(width: 4),

                      if (evening)
                        _plannerBadge(
                          'PM',
                          _Palette.onHold,
                        ),

                      const SizedBox(width: 9),

                      Text(
                        _formatHours(
                          _toInt(
                            entry['workingSecs'],
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _Palette.muted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _sectionIcon(
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 35,
      height: 35,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        size: 17,
        color: color,
      ),
    );
  }

  Widget _plannerBadge(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTopPerformers(bool isMobile) {
    return _premiumSectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(
                Icons.insights_rounded,
                _Palette.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Today's Top Performers",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _Palette.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/performance',
                  );
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _Palette.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          ...List.generate(
            _topPerformers.length,
            (i) {
              final emp =
                  _topPerformers[i];

              final score = _toDouble(
                emp['performancePct'],
              ).clamp(0, 100);

              return Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _Palette.primary
                            .withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: _Palette.primary,
                        ),
                      ),
                    ),

                    const SizedBox(width: 9),

                    Expanded(
                      child: Text(
                        emp['fullName'] ??
                            emp['employeeName'] ??
                            'Employee',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _Palette.ink,
                        ),
                      ),
                    ),

                    SizedBox(
                      width: isMobile ? 80 : 150,
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(7),
                        child:
                            TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: score / 100,
                          ),
                          duration: const Duration(
                            milliseconds: 800,
                          ),
                          curve:
                              Curves.easeOutCubic,
                          builder:
                              (
                                context,
                                value,
                                child,
                              ) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 7,
                              backgroundColor:
                                  const Color(
                                0xFFF1F5F9,
                              ),
                             valueColor: AlwaysStoppedAnimation<Color>(
  _performanceColor(
    score.toDouble(),
  ),
),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    SizedBox(
                      width: 35,
                      child: Text(
                        '${score.toInt()}%',
                        textAlign:
                            TextAlign.right,
                        style:
                            const TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w900,
                          color: _Palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _performanceColor(double score) {
    if (score >= 70) {
      return _Palette.completed;
    }

    if (score >= 50) {
      return _Palette.onHold;
    }

    return _Palette.rejected;
  }

  String _formatHours(int secs) {
    final hrs = secs ~/ 3600;
    final mins = (secs % 3600) ~/ 60;

    if (hrs > 0) {
      return '${hrs}h ${mins}m';
    }

    return '${mins}m';
  }

  // ---------------------------------------------------------------------
  // QUICK ACCESS
  // ---------------------------------------------------------------------

 Widget _buildNavHub(
    bool isMobile,
    bool isTablet,
    bool isMainAdmin,
    List<String> allowedPages,
  ) {
    // 🟢 Responsive columns: 1 for mobile, 2 for tablet, and 4 to 6 for desktop based on screen width
    final screenWidth = MediaQuery.sizeOf(context).width;
    
    int crossAxisCount;
    double childAspectRatio;

    if (screenWidth >= 1600) {
      crossAxisCount = 6; // Ultra-wide desktop
      childAspectRatio = 3.2;
    } else if (screenWidth >= 1300) {
      crossAxisCount = 5; // Large desktop
      childAspectRatio = 3.1;
    } else if (screenWidth >= 1100) {
      crossAxisCount = 4; // Standard desktop
      childAspectRatio = 3.0;
    } else if (screenWidth >= 720) {
      crossAxisCount = 2; // Tablet (keeps your preferred layout size)
      childAspectRatio = 2.9;
    } else {
      crossAxisCount = 1; // Mobile single column
      childAspectRatio = 3.55;
    }

    bool tileAllowed(_NavTile tile) {
      if (isMainAdmin) return true;

      if (!_controllableRoutes.contains(tile.route)) {
        return true;
      }

      return allowedPages.contains(tile.route);
    }

    final visibleGroups = <String, List<_NavTile>>{};

    for (final group in _navGroups.entries) {
      final visibleTiles = group.value.where(tileAllowed).toList();

      if (visibleTiles.isNotEmpty) {
        visibleGroups[group.key] = visibleTiles;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: _Palette.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: _Palette.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 13,
                    color: _Palette.primary,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Interactive',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: _Palette.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          isMainAdmin
              ? 'Every admin page, one tap away.'
              : 'The pages your role has access to.',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _Palette.muted,
          ),
        ),

        const SizedBox(height: 16),

        if (visibleGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 30,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _Palette.border,
              ),
            ),
            child: const Center(
              child: Text(
                'No pages have been granted to your role yet.',
                style: TextStyle(
                  fontSize: 12,
                  color: _Palette.muted,
                ),
              ),
            ),
          )
        else
          for (final group in visibleGroups.entries) ...[
            Row(
              children: [
                Container(
                  width: 4,
                  height: 15,
                  decoration: BoxDecoration(
                    color: _Palette.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  group.key,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: _Palette.muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            GridView.builder(
              itemCount: group.value.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                return _navTile(
                  group.value[index],
                );
              },
            ),

            const SizedBox(height: 19),
          ],
      ],
    );
  }
  
  Widget _navTile(_NavTile tile) {
    return _AnimatedNavCard(
      tile: tile,
      onTap: () {
        Navigator.pushNamed(
          context,
          tile.route,
          arguments: tile.arguments,
        );
      },
    );
  }
}

// =======================================================================
// ANIMATED KPI CARD
// =======================================================================

class _AnimatedKpiCard extends StatefulWidget {
  final _KpiData data;
  final bool loading;
  final VoidCallback onTap;

  const _AnimatedKpiCard({
    required this.data,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_AnimatedKpiCard> createState() =>
      _AnimatedKpiCardState();
}

class _AnimatedKpiCardState
    extends State<_AnimatedKpiCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed
              ? 0.975
              : (_hovered ? 1.012 : 1.0),
          duration:
              const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(21),
              border: Border.all(
                color: active
                    ? widget.data.color
                        .withValues(alpha: 0.35)
                    : const Color(0xFFE5ECF6),
                width: active ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.data.color
                      .withValues(
                    alpha: active ? 0.13 : 0.045,
                  ),
                  blurRadius:
                      active ? 26 : 18,
                  offset: Offset(
                    0,
                    active ? 11 : 7,
                  ),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -38,
                  child: AnimatedOpacity(
                    opacity:
                        active ? 0.08 : 0.035,
                    duration:
                        const Duration(
                      milliseconds: 220,
                    ),
                    child: Container(
                      width: 105,
                      height: 105,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color:
                            widget.data.color,
                      ),
                    ),
                  ),
                ),

                Row(
                  children: [
                    AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 220,
                      ),
                      width: active ? 50 : 46,
                      height: active ? 50 : 46,
                      decoration:
                          BoxDecoration(
                        color: widget
                            .data.color
                            .withValues(
                          alpha: active
                              ? 0.15
                              : 0.09,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Icon(
                        widget.data.icon,
                        size: active
                            ? 22
                            : 20,
                        color:
                            widget.data.color,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            widget.data.title,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  _Palette.muted,
                            ),
                          ),

                          const SizedBox(height: 5),

                          AnimatedSwitcher(
                            duration:
                                const Duration(
                              milliseconds: 250,
                            ),
                            child: Text(
                              widget.loading
                                  ? '—'
                                  : widget.data.value,
                              key: ValueKey(
                                widget.loading
                                    ? 'loading'
                                    : widget
                                        .data
                                        .value,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  TextStyle(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.w900,
                                letterSpacing:
                                    -0.6,
                                color:
                                    widget.data.color,
                              ),
                            ),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            widget.data.label,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 9.5,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  _Palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    AnimatedSlide(
                      offset: active
                          ? const Offset(0.15, 0)
                          : Offset.zero,
                      duration:
                          const Duration(
                        milliseconds: 180,
                      ),
                      child: Icon(
                        Icons
                            .arrow_forward_ios_rounded,
                        size: 13,
                        color: active
                            ? widget.data.color
                            : const Color(
                                0xFF94A3B8,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// ANIMATED QUICK ACCESS CARD
// =======================================================================

class _AnimatedNavCard extends StatefulWidget {
  final _NavTile tile;
  final VoidCallback onTap;

  const _AnimatedNavCard({
    required this.tile,
    required this.onTap,
  });

  @override
  State<_AnimatedNavCard> createState() =>
      _AnimatedNavCardState();
}

class _AnimatedNavCardState
    extends State<_AnimatedNavCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed
              ? 0.975
              : (_hovered ? 1.015 : 1),
          duration:
              const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active
                  ? widget.tile.color
                      .withValues(alpha: 0.025)
                  : Colors.white,
              borderRadius:
                  BorderRadius.circular(17),
              border: Border.all(
                color: active
                    ? widget.tile.color
                        .withValues(alpha: 0.40)
                    : _Palette.border,
                width: active ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.tile.color
                      .withValues(
                    alpha: active ? 0.12 : 0.035,
                  ),
                  blurRadius:
                      active ? 24 : 13,
                  offset: Offset(
                    0,
                    active ? 10 : 5,
                  ),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 220,
                  ),
                  width: active ? 44 : 40,
                  height: active ? 44 : 40,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(
                    color: widget.tile.color
                        .withValues(
                      alpha: active ? 0.14 : 0.085,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: AnimatedScale(
                    scale: active ? 1.10 : 1,
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    child: Icon(
                      widget.tile.icon,
                      size: 19,
                      color:
                          widget.tile.color,
                    ),
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tile.title,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              FontWeight.w900,
                          color: active
                              ? widget
                                  .tile
                                  .color
                              : _Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.tile.subtitle,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight:
                              FontWeight.w600,
                          color:
                              _Palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                AnimatedSlide(
                  offset: active
                      ? const Offset(0.18, 0)
                      : Offset.zero,
                  duration:
                      const Duration(
                    milliseconds: 180,
                  ),
                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(
                      color: active
                          ? widget.tile.color
                              .withValues(alpha: 0.10)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons
                          .arrow_forward_rounded,
                      size: 16,
                      color: active
                          ? widget.tile.color
                          : const Color(
                              0xFF94A3B8,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
