// lib/report/report_home_screen.dart
//
// Reskinned Client Report Management home, matching the sample project's look
// (dark sidebar, blue header, welcome banner, month/year selector, KPI cards
// and a clients table) but wired to this app's existing, JWT-secured report
// endpoints. It reuses the existing report builder / history / approvals
// screens for the actual work.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/screens/login_screen.dart';
import 'package:godigital_portal/services/auth_service.dart';

import '../services/api_config.dart';
import '../services/authenticated_http.dart' as http;
import 'client_report_business_dialog.dart';
import 'clients_full_report_screen.dart';
import 'client_monthly_reports_screen.dart';
import 'admin_dashboard_page.dart';
import 'report_admin_shell.dart';
import 'report_notifications_screen.dart';
import 'report_approvals_screen.dart';
import 'report_brand.dart';
import 'report_providers.dart';
import 'report_route_names.dart';

const _navy = Color(0xff071c54);
const _blue = Color(0xff0866e8);

String _monthName(int month) => const [
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
][(month - 1).clamp(0, 11)];

enum _Section { dashboard, clients, reports, approvals, notifications }

class ReportHomeRoute extends StatelessWidget {
  const ReportHomeRoute({super.key, required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!auth.isAuthenticated) return const LoginScreen();

        final user = auth.user ?? const <String, dynamic>{};
        final userType = auth.userType?.toLowerCase().trim() ?? '';
        final isMainAdmin = user['is_main_admin'] == true ||
            user['is_main_admin'] == 1 ||
            user['is_main_admin']?.toString() == '1' ||
            user['isMainAdmin'] == true;
        final applicationAccess = user['application_access'];
        final reportAccess = applicationAccess is Map
            ? applicationAccess['reports']
            : null;
        final accessType = reportAccess is Map
            ? (reportAccess['access_type'] ?? reportAccess['accessType'])
                    ?.toString()
                    .toLowerCase()
                    .trim() ??
                'none'
            : 'none';
        final isAdmin =
            userType == 'admin' || isMainAdmin || accessType == 'admin';
        if (!isAdmin && accessType == 'none') {
          return _reportAccessDenied();
        }
        if (section == 'approvals' && !isAdmin) {
          return _reportAccessDenied();
        }

        return ReportHomeScreen(
          isAdmin: isAdmin,
          canReview: isAdmin &&
              (userType == 'admin' || isMainAdmin || accessType == 'admin'),
          initialSection: section,
        );
      },
    );
  }

  Widget _reportAccessDenied() => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You do not have access to Reports.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}

class ReportHomeScreen extends StatefulWidget {
  const ReportHomeScreen({
    super.key,
    this.isAdmin = false,
    this.canReview = false,
    this.initialSection = 'dashboard',
  });

  final bool isAdmin;
  final bool canReview;
  final String initialSection;

  @override
  State<ReportHomeScreen> createState() => _ReportHomeScreenState();
}

class _ReportHomeScreenState extends State<ReportHomeScreen> {
  late _Section _section = _sectionFromName(widget.initialSection);
  DateTime _month = DateTime.now();
  int _activeCard = 1;
  final _search = TextEditingController();

  // Shell + nested navigator so the sidebar/top bar persist on every page.
  final _robot = ReportRobotController();
  final _nestedNav = GlobalKey<NavigatorState>();
  final _rev = ValueNotifier<int>(0);
  int _drillDepth = 0;
  String? _drillTitle;
  late final _navObserver = ReportShellNavObserver((depth) {
    if (!mounted) return;
    setState(() {
      _drillDepth = depth;
      if (depth == 0) _drillTitle = null;
    });
  });

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _assigned = const [];
  List<Map<String, dynamic>> _saved = const [];
  List<Map<String, dynamic>> _subs = const [];

  bool get _canManage => widget.isAdmin || widget.canReview;

  _Section _sectionFromName(String name) => switch (name) {
        'clients' || 'assigned-clients' => _Section.clients,
        'reports' || 'client-workspace' => _Section.reports,
        'approvals' => _Section.approvals,
        'notifications' => _Section.notifications,
        _ => _Section.dashboard,
      };

  @override
  void initState() {
    super.initState();
    if (!_canManage) _load();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (mounted) _rev.value++;
  }

  @override
  void dispose() {
    _search.dispose();
    _rev.dispose();
    super.dispose();
  }

  void _goSection(_Section s) {
    if (_section == s) return;
    Navigator.of(context, rootNavigator: true)
        .pushReplacementNamed(reportRouteName(s.name));
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<List<Map<String, dynamic>>> _fetch(String path, String key) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: const {'Accept': 'application/json'},
    );
    final body = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        (body is Map ? body['message']?.toString() : null) ??
            'Request failed (${res.statusCode}).',
      );
    }
    final rows = body is Map ? body[key] : null;
    return rows is List
        ? rows
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Assigned clients drive the employee view; saved clients give report
      // counts + history. The admin view falls back to saved clients.
      final assigned = widget.isAdmin
          ? <Map<String, dynamic>>[]
          : await _fetch('/report-export/assigned-clients', 'clients');
      final saved = await _fetch('/report-export/clients', 'clients');
      // Submissions drive the "completed this month" / "pending follow-ups"
      // counts from real approval status.
      final subs = await _fetch('/report-export/submissions', 'submissions')
          .catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      setState(() {
        _assigned = assigned;
        _saved = saved;
        _subs = subs;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  int _reportsFor(String name) {
    for (final c in _saved) {
      if ((c['name']?.toString() ?? '').toLowerCase() == name.toLowerCase()) {
        return (c['reportCount'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  // Latest submission status for [name] in the selected month: 'approved',
  // 'rejected' or 'pending'; null when nothing has been passed to admin yet.
  String? _statusFor(String name) {
    Map<String, dynamic>? latest;
    for (final s in _subs) {
      if ((s['company_name']?.toString() ?? '').toLowerCase() !=
          name.toLowerCase()) {
        continue;
      }
      final m = (s['report_month'] as num?)?.toInt();
      final y = (s['report_year'] as num?)?.toInt();
      if (m != _month.month || y != _month.year) continue;
      if (latest == null) {
        latest = s;
      } else {
        final a = DateTime.tryParse('${s['created_at']}'.replaceFirst(' ', 'T'));
        final b = DateTime.tryParse(
          '${latest['created_at']}'.replaceFirst(' ', 'T'),
        );
        if (a != null && b != null && a.isAfter(b)) latest = s;
      }
    }
    return latest?['status']?.toString().toLowerCase();
  }

  // Merge assigned + saved into the rows the clients table shows.
  List<_ClientRow> get _rows {
    final rows = <_ClientRow>[];
    if (widget.isAdmin) {
      for (final c in _saved) {
        final name = c['name']?.toString() ?? 'Client';
        rows.add(
          _ClientRow(
            id: (c['id'] as num?)?.toInt(),
            name: name,
            providers: const [],
            reports: (c['reportCount'] as num?)?.toInt() ?? 0,
            status: _statusFor(name),
            raw: c,
          ),
        );
      }
    } else {
      for (final c in _assigned) {
        final name = c['name']?.toString() ?? 'Client';
        final tasks = c['assignedTasks'];
        rows.add(
          _ClientRow(
            id: (c['id'] as num?)?.toInt(),
            name: name,
            providers: tasks is List
                ? tasks
                      .map(
                        (e) => e is Map
                            ? (e['task']?.toString() ?? '')
                            : e.toString(),
                      )
                      .where((e) => e.isNotEmpty)
                      .toSet()
                      .toList()
                : const [],
            reports: _reportsFor(name),
            status: _statusFor(name),
            raw: c,
          ),
        );
      }
    }
    return rows;
  }

  // Companies that have a submission with one of [statuses] in the selected
  // month/year — the real source for completed / pending counts.
  Set<String> _companiesWithStatus(Set<String> statuses) {
    final out = <String>{};
    for (final s in _subs) {
      final st = s['status']?.toString().toLowerCase() ?? '';
      final m = (s['report_month'] as num?)?.toInt();
      final y = (s['report_year'] as num?)?.toInt();
      if (statuses.contains(st) && m == _month.month && y == _month.year) {
        out.add((s['company_name']?.toString() ?? '').toLowerCase());
      }
    }
    return out;
  }

  int get _completedThisMonth => _companiesWithStatus({'approved'}).length;
  int get _pendingFollowups =>
      _companiesWithStatus({'pending', 'rejected'}).length;

  List<_ClientRow> get _filtered {
    final q = _search.text.trim().toLowerCase();
    var list = _rows;
    switch (_activeCard) {
      case 2: // completed this month (approved submission)
        final done = _companiesWithStatus({'approved'});
        list = list.where((r) => done.contains(r.name.toLowerCase())).toList();
        break;
      case 3: // pending follow-ups (pending/rejected submission)
        final todo = _companiesWithStatus({'pending', 'rejected'});
        list = list.where((r) => todo.contains(r.name.toLowerCase())).toList();
        break;
    }
    if (q.isEmpty) return list;
    return list.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  String get _cardTitle => switch (_activeCard) {
    2 => widget.isAdmin ? 'Clients with Reports' : 'Completed This Month',
    3 => 'Pending Follow-ups',
    0 => 'All Clients Handled',
    _ => widget.isAdmin ? 'All Clients' : 'Assigned Clients',
  };

  // Employee flow: a client card opens its month-wise reports (existing
  // reports as cards + a "Create new report" card).
  Future<void> _openMonthly(_ClientRow row) async {
    _drillTitle = row.name;
    await (_nestedNav.currentState ?? Navigator.of(context)).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ClientMonthlyReportsScreen(
          client: <String, dynamic>{
            if (row.id != null) 'id': row.id,
            'name': row.name,
            'assignedTasks': row.raw['assignedTasks'],
            'assignedHandlers': row.raw['assignedHandlers'],
            if (row.raw['logoBase64'] != null)
              'logoBase64': row.raw['logoBase64'],
            if (row.raw['logoMimeType'] != null)
              'logoMimeType': row.raw['logoMimeType'],
          },
          canManageReports: _canManage,
          embedded: true,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _newReport() async {
    final business = await showClientReportBusinessDialog(context);
    if (business == null || !mounted) return;
    _drillTitle = business['name']?.toString() ?? 'New report';
    await (_nestedNav.currentState ?? Navigator.of(context)).push<void>(
      MaterialPageRoute(
        builder: (_) => ClientsFullReportScreen(
          business: <String, dynamic>{
            ...business,
            'canManageReports': _canManage,
          },
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_canManage) {
      return AdminDashboardPage(
        canReview: widget.canReview || widget.isAdmin,
        initialPage: widget.initialSection,
      );
    }
    return ReportAdminShell(
      brandTitle: 'GoDigital Reports',
      robotController: _robot,
      onBack: _drillDepth > 0
          ? () => _nestedNav.currentState?.maybePop()
          : null,
      contextTitle: _drillTitle,
      searchHint: 'Search assigned clients...',
      onSearch: (q) {
        _search.text = q;
        setState(() {});
      },
      onNotificationsTap: () => _goSection(_Section.notifications),
      topActions: [
        OutlinedButton.icon(
          onPressed: _pickMonth,
          icon: const Icon(Icons.calendar_month_rounded, size: 16),
          label: Text('${_monthName(_month.month)} ${_month.year}'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0757D5),
            side: const BorderSide(color: Color(0xFFD6E5FB)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 8),
      ],
      navItems: [
        ReportNavItem(
          icon: Icons.home_rounded,
          label: 'Home',
          selected: _section == _Section.dashboard,
          onTap: () => _goSection(_Section.dashboard),
        ),
        ReportNavItem(
          icon: Icons.groups_rounded,
          label: 'Assigned Clients',
          selected: _section == _Section.clients,
          onTap: () => _goSection(_Section.clients),
        ),
        ReportNavItem(
          icon: Icons.notifications_rounded,
          label: 'Notifications',
          selected: _section == _Section.notifications,
          onTap: () => _goSection(_Section.notifications),
        ),
      ],
      child: Navigator(
        key: _nestedNav,
        observers: [_navObserver],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => ValueListenableBuilder<int>(
            valueListenable: _rev,
            builder: (_, __, ___) => DecoratedBox(
              decoration: ReportBrand.pageBackground,
              child: _body(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (value != null)
      setState(() => _month = DateTime(value.year, value.month));
  }

  Widget _body() {
    switch (_section) {
      case _Section.approvals:
        return const ReportApprovalsScreen();
      case _Section.notifications:
        return const ReportNotificationsScreen();
      case _Section.clients:
      case _Section.reports:
      case _Section.dashboard:
        return _dashboard();
    }
  }

  Widget _dashboard() {
    final showClientsOnly =
        _section == _Section.clients || _section == _Section.reports;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!showClientsOnly) ...[
            FadeSlideIn(child: _Welcome(greeting: _greeting, month: _month)),
            const SizedBox(height: 20),
            _MonthYearSelector(
              value: _month,
              onChanged: (v) => setState(() => _month = v),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(delay: const Duration(milliseconds: 80), child: _kpis()),
            const SizedBox(height: 24),
          ],
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: _ClientsPanel(
            title: showClientsOnly
                ? (widget.isAdmin ? 'All Clients' : 'Assigned Clients')
                : _cardTitle,
            rows: _filtered,
            loading: _loading,
            error: _error,
            search: _search,
            onSearch: (_) => setState(() {}),
            onReset: () => setState(() {
              _search.clear();
              _activeCard = 1;
            }),
            onOpen: _openMonthly,
            onNew: _newReport,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis() {
    final total = _rows.length;
    final withReports = _rows.where((r) => r.reports > 0).length;
    final pending = _rows.where((r) => r.reports == 0).length;
    final generated = _rows.fold<int>(0, (s, r) => s + r.reports);
    return LayoutBuilder(
      builder: (_, c) {
        final n = c.maxWidth >= 1000
            ? 5
            : c.maxWidth > 600
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: n,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: n == 5
              ? 1.65
              : n == 1
                  ? 3
                  : 2.05,
          children: [
            _Kpi(
              icon: Icons.groups_rounded,
              title: widget.isAdmin ? 'Total Clients' : 'Total Handled',
              value: total,
              color: const Color(0xff486bf0),
              selected: _activeCard == 0,
              compact: n == 5,
              onTap: () => setState(() => _activeCard = 0),
            ),
            _Kpi(
              icon: Icons.assignment_rounded,
              title: widget.isAdmin ? 'With Reports' : 'Assigned Clients',
              value: widget.isAdmin ? withReports : total,
              color: const Color(0xff168af0),
              selected: _activeCard == 1,
              compact: n == 5,
              onTap: () => setState(() => _activeCard = 1),
            ),
            _Kpi(
              icon: Icons.check_circle_rounded,
              title: widget.isAdmin ? 'Clients with Reports' : 'Completed This Month',
              value: widget.isAdmin ? withReports : _completedThisMonth,
              color: const Color(0xff14b96b),
              selected: _activeCard == 2,
              compact: n == 5,
              onTap: () => setState(() => _activeCard = 2),
            ),
            _Kpi(
              icon: Icons.schedule_rounded,
              title: 'Pending Follow-ups',
              value: widget.isAdmin ? pending : _pendingFollowups,
              color: const Color(0xffffa014),
              selected: _activeCard == 3,
              compact: n == 5,
              onTap: () => setState(() => _activeCard = 3),
            ),
            _Kpi(
              icon: Icons.description_rounded,
              title: 'Reports Generated',
              value: generated,
              color: const Color(0xff7452d8),
              selected: false,
              compact: n == 5,
              onTap: () => setState(() => _activeCard = 0),
            ),
          ],
        );
      },
    );
  }

}

class _ClientRow {
  _ClientRow({
    required this.id,
    required this.name,
    required this.providers,
    required this.reports,
    required this.raw,
    this.status,
  });
  final int? id;
  final String name;
  final List<String> providers;
  final int reports;
  final Map<String, dynamic> raw;

  /// Latest submission status for the selected month: 'approved' | 'rejected'
  /// | 'pending', or null when nothing has been passed to admin yet.
  final String? status;
}

// ---------------------------------------------------------------------------
// Welcome banner
// ---------------------------------------------------------------------------
class _Welcome extends StatelessWidget {
  const _Welcome({required this.greeting, required this.month});
  final String greeting;
  final DateTime month;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 165,
    padding: const EdgeInsets.all(27),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      gradient: const LinearGradient(
        colors: [Colors.white, Color(0xffd9efff), Color(0xff9ed5ff)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x220866e8),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: 32,
          bottom: 8,
          child: Icon(
            Icons.wb_sunny_rounded,
            color: const Color(0xffffc333).withValues(alpha: .9),
            size: 100,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$greeting 👋',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Welcome to Client Report Management',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Here's your reporting overview for ${_monthName(month.month)} ${month.year}.",
              style: const TextStyle(color: Color(0xff173263), fontSize: 16),
            ),
          ],
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// KPI card
// ---------------------------------------------------------------------------
class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.selected,
    this.compact = false,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final int value;
  final Color color;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: .13) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : color.withValues(alpha: .25),
          width: selected ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? color.withValues(alpha: .28)
                : const Color(0x150b2850),
            blurRadius: selected ? 22 : 14,
            offset: Offset(0, selected ? 9 : 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 22 : 27,
            backgroundColor: selected ? color : color.withValues(alpha: .13),
            child: Icon(
              icon,
              color: selected ? Colors.white : color,
              size: compact ? 25 : 30,
            ),
          ),
          SizedBox(width: compact ? 10 : 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: compact ? 28 : 32,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                Text(
                  title,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff152850),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Month / year selector (from the sample's widget)
// ---------------------------------------------------------------------------
class _MonthYearSelector extends StatelessWidget {
  const _MonthYearSelector({required this.value, required this.onChanged});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  static const _m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 14,
    children: [
      _control(
        'Month',
        Icons.calendar_month,
        _m[value.month - 1],
        value.month == 1 ? 'Dec' : _m[value.month - 2],
        value.month == 12 ? 'Jan' : _m[value.month],
        (d) => onChanged(DateTime(value.year, value.month + d)),
      ),
      _control(
        'Year',
        Icons.event,
        '${value.year}',
        '${value.year - 1}',
        '${value.year + 1}',
        (d) => onChanged(DateTime(value.year + d, value.month)),
      ),
    ],
  );

  Widget _control(
    String label,
    IconData icon,
    String selected,
    String previous,
    String next,
    ValueChanged<int> change,
  ) => GestureDetector(
    onHorizontalDragEnd: (details) {
      final v = details.primaryVelocity ?? 0;
      if (v < 0) change(1);
      if (v > 0) change(-1);
    },
    child: MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: Container(
        width: 440,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xfff2f7ff), Color(0xffd9eaff)],
          ),
          border: Border.all(color: const Color(0xffb8d5ff)),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26126be8),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: _blue, size: 27),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff073d91),
                ),
              ),
            ),
            IconButton(
              onPressed: () => change(-1),
              icon: const Icon(Icons.chevron_left_rounded, color: _blue),
            ),
            _period(selected, active: true),
            IconButton(
              onPressed: () => change(1),
              icon: const Icon(Icons.chevron_right_rounded, color: _blue),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _period(String text, {bool active = false}) => Container(
    width: 60,
    height: 50,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? null : Colors.white,
      gradient: active
          ? const LinearGradient(colors: [Color(0xff248dff), Color(0xff0758d5)])
          : null,
      border: Border.all(
        color: active ? Colors.transparent : const Color(0xffc9dcff),
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: active ? Colors.white : const Color(0xff3d6093),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Clients panel (table)
// ---------------------------------------------------------------------------
class _ClientsPanel extends StatelessWidget {
  const _ClientsPanel({
    required this.title,
    required this.rows,
    required this.loading,
    required this.error,
    required this.search,
    required this.onSearch,
    required this.onReset,
    required this.onOpen,
    required this.onNew,
  });
  final String title;
  final List<_ClientRow> rows;
  final bool loading;
  final String? error;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onReset;
  final ValueChanged<_ClientRow> onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x160b2850),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups_rounded, size: 29, color: _blue),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(width: 9),
                Chip(label: Text('${rows.length} Clients')),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: search,
                    onChanged: onSearch,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by client name...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  tooltip: 'Reset filters',
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: onNew,
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  icon: const Icon(Icons.add),
                  label: const Text('New report'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (rows.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1100
                  ? 4
                  : constraints.maxWidth > 760
                  ? 3
                  : constraints.maxWidth > 500
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.42,
                ),
                itemCount: rows.length,
                itemBuilder: (context, i) => FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i),
                  child: _ClientCard(row: rows[i], onTap: () => onOpen(rows[i])),
                ),
              );
            },
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.folder_open_rounded,
                    color: Color(0xff8aa9d5),
                    size: 48,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    error ?? 'No clients match the selected filter.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff173263),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// Status chip reflecting the client's latest submission for the selected month.
Widget _statusChip(String? status) {
  final s = (status ?? '').toLowerCase();
  final (Color color, String label, IconData icon) = switch (s) {
    'approved' => (
      const Color(0xff14b96b),
      'Approved',
      Icons.check_circle_rounded,
    ),
    'rejected' => (
      const Color(0xffe5484d),
      'Rejected',
      Icons.cancel_rounded,
    ),
    'pending' => (
      const Color(0xffffa014),
      'In review',
      Icons.schedule_rounded,
    ),
    _ => (
      const Color(0xff8094b8),
      'Not sent',
      Icons.remove_circle_outline_rounded,
    ),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .34)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// A single client shown as a card: logo/initial, name, assigned-provider
// brand logos, and report count. Tapping opens the month-wise reports view.
class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.row, required this.onTap});
  final _ClientRow row;
  final VoidCallback onTap;

  ImageProvider? get _logo {
    final encoded = (row.raw['logoBase64'] ?? row.raw['companyLogoBase64'])
        ?.toString();
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = providersFromTaskNames(row.providers);
    final logo = _logo;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffE6ECF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xffEFF3FB),
                    backgroundImage: logo,
                    child: logo == null
                        ? Text(
                            row.name.isNotEmpty
                                ? row.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const Spacer(),
                  _statusChip(row.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 10),
              if (providers.isEmpty)
                const Text(
                  'No providers assigned',
                  style: TextStyle(color: Color(0xff8094b8), fontSize: 12),
                )
              else
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in providers.take(7))
                          Tooltip(
                            message: p.label,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: p.color.withValues(alpha: .09),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ProviderLogo(provider: p, size: 17),
                            ),
                          ),
                        if (providers.length > 7)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffEFF3FB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${providers.length - 7}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _navy,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
