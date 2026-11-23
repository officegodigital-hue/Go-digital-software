import 'package:flutter/material.dart';

import 'admin_client_manager.dart';
import 'admin_template_manager.dart';
import 'client_monthly_reports_screen.dart';
import 'clients_full_report_screen.dart';
import 'client_report_business_dialog.dart';
import 'data/full_report_service.dart';
import 'report_admin_shell.dart';
import 'report_notifications_screen.dart';
import 'report_approvals_screen.dart';
import 'report_brand.dart';
import 'report_route_names.dart';
import 'package:godigital_portal/core/widgets/notification_robot.dart';

const _adminNavy = Color(0xff082d61);
const _adminBlue = Color(0xff0866e8);
const _adminElectric = Color(0xff2491ff);

enum _AdminPage { dashboard, clients, reports, approvals, notifications }

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    this.canReview = true,
    this.initialPage = 'dashboard',
  });

  final bool canReview;
  final String initialPage;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _service = const FullReportService();
  final _robot = ReportRobotController();
  // Drill-downs (a client's monthly reports, preview, the report builder) are
  // pushed onto this nested navigator so they render inside the shell body,
  // keeping the sidebar + top bar visible on every report page.
  final _nestedNav = GlobalKey<NavigatorState>();
  // The nested navigator's root route is generated once; this notifier forces
  // its body to rebuild whenever report state (data, page, filter, search)
  // changes via setState.
  final _rev = ValueNotifier<int>(0);
  // Drill-down depth + current title drive the shell's back button so the
  // sub-screens no longer need their own top bar.
  int _drillDepth = 0;
  String? _drillTitle;
  late final _navObserver = ReportShellNavObserver((depth) {
    if (!mounted) return;
    setState(() {
      _drillDepth = depth;
      if (depth == 0) _drillTitle = null;
    });
  });
  late _AdminPage _page = switch (widget.initialPage) {
    'clients' || 'assigned-clients' => _AdminPage.clients,
    'reports' || 'client-workspace' => _AdminPage.reports,
    'approvals' => _AdminPage.approvals,
    'notifications' => _AdminPage.notifications,
    _ => _AdminPage.dashboard,
  };
  String _dashFilter = 'all';
  String _query = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = const [];
  List<Map<String, dynamic>> _submissions = const [];
  DateTime _dashPeriod = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Every state change also bumps the nested navigator's root so its body
  // (the dashboard / clients / reports / approvals content) stays current.
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (mounted) _rev.value++;
  }

  @override
  void dispose() {
    _rev.dispose();
    super.dispose();
  }

  // Named report routes keep the selected section on the browser URL.
  void _goPage(_AdminPage page) {
    if (_page == page) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacementNamed(reportRouteName(page.name));
  }

  List<Map<String, dynamic>> _applyQuery(List<Map<String, dynamic>> rows) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows
        .where(
          (r) =>
              (r['company_name']?.toString() ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _service.savedClients(),
        _service.listSubmissions(),
      ]);
      if (!mounted) return;
      setState(() {
        _clients = values[0];
        _submissions = values[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _dashPeriodSubmissions =>
      _submissions.where((item) {
        final month = int.tryParse('${item['report_month'] ?? ''}');
        final year = int.tryParse('${item['report_year'] ?? ''}');
        return month == _dashPeriod.month && year == _dashPeriod.year;
      }).toList();

  int _statusCount(String status) => _dashPeriodSubmissions
      .where((item) => item['status']?.toString().toLowerCase() == status)
      .length;

  Future<void> _addClient() async {
    final business = await showClientReportBusinessDialog(context);
    if (business == null || !mounted) return;
    final name = business['name']?.toString().trim() ?? '';
    if (name.isEmpty) return;
    if (_clients.any(
      (client) =>
          (client['name']?.toString() ?? '').toLowerCase() ==
          name.toLowerCase(),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This client is already in the list.')),
      );
      return;
    }
    try {
      await _service.saveClientProfile(
        name,
        logoBase64: business['companyLogoBase64']?.toString(),
        logoMimeType: business['companyLogoMimeType']?.toString(),
      );
      if (!mounted) return;
      _robot.play(RobotEvent.taskCompleted, 'Client "$name" added.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client added.')));
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _openClient(Map<String, dynamic> client) async {
    _drillTitle = client['name']?.toString();
    await (_nestedNav.currentState ?? Navigator.of(context)).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ClientMonthlyReportsScreen(
          client: client,
          canManageReports: widget.canReview,
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
      MaterialPageRoute<void>(
        builder: (_) => ClientsFullReportScreen(
          business: <String, dynamic>{
            ...business,
            'canManageReports': widget.canReview,
          },
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _manageReportTemplate() async {
    await showReportTemplateManager(context);
    if (mounted) _load();
  }

  void _selectPage(_AdminPage page) => _goPage(page);

  @override
  Widget build(BuildContext context) {
    return ReportAdminShell(
      brandTitle: 'GoDigital Reports',
      robotController: _robot,
      onBack: _drillDepth > 0
          ? () => _nestedNav.currentState?.maybePop()
          : null,
      contextTitle: _drillTitle,
      searchHint: 'Search clients, reports...',
      onSearch: (q) => setState(() => _query = q),
      quickAddLabel: 'Quick Add',
      onQuickAdd: _addClient,
      onNotificationsTap: () => _goPage(_AdminPage.notifications),
      topActions: [
        if (widget.canReview)
          IconButton(
            tooltip: 'Report template',
            icon: const Icon(
              Icons.description_outlined,
              size: 20,
              color: Color(0xFF475569),
            ),
            onPressed: _manageReportTemplate,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(
            Icons.refresh_rounded,
            size: 20,
            color: Color(0xFF475569),
          ),
          onPressed: _loading ? null : _load,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 2),
      ],
      navItems: [
        ReportNavItem(
          icon: Icons.space_dashboard_rounded,
          label: 'Dashboard',
          selected: _page == _AdminPage.dashboard,
          onTap: () => _goPage(_AdminPage.dashboard),
        ),
        ReportNavItem(
          icon: Icons.business_rounded,
          label: 'Clients',
          selected: _page == _AdminPage.clients,
          onTap: () => _goPage(_AdminPage.clients),
        ),
        ReportNavItem(
          icon: Icons.description_rounded,
          label: 'Reports',
          selected: _page == _AdminPage.reports,
          onTap: () => _goPage(_AdminPage.reports),
        ),
        if (widget.canReview)
          ReportNavItem(
            icon: Icons.fact_check_rounded,
            label: 'Report Approvals',
            selected: _page == _AdminPage.approvals,
            onTap: () => _goPage(_AdminPage.approvals),
          ),
        ReportNavItem(
          icon: Icons.notifications_rounded,
          label: 'Notifications',
          selected: _page == _AdminPage.notifications,
          onTap: () => _goPage(_AdminPage.notifications),
        ),
      ],
      // Nested navigator: drill-downs push here so they stay inside the shell.
      child: Navigator(
        key: _nestedNav,
        observers: [_navObserver],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => ValueListenableBuilder<int>(
            valueListenable: _rev,
            builder: (_, __, ___) => DecoratedBox(
              decoration: ReportBrand.pageBackground,
              child: _content(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    switch (_page) {
      case _AdminPage.approvals:
        return const ReportApprovalsScreen();
      case _AdminPage.notifications:
        return const ReportNotificationsScreen();
      case _AdminPage.clients:
        return _clientsPage();
      case _AdminPage.reports:
        return _reportsPage();
      case _AdminPage.dashboard:
        return _dashboard();
    }
  }

  List<Map<String, dynamic>> get _dashReports {
    final periodReports = _dashPeriodSubmissions;
    final base = _dashFilter == 'all'
        ? periodReports
        : periodReports
              .where(
                (s) => s['status']?.toString().toLowerCase() == _dashFilter,
              )
              .toList();
    return _applyQuery(base);
  }

  String get _dashSectionTitle => switch (_dashFilter) {
    'pending' => 'Pending approval',
    'approved' => 'Approved reports',
    'rejected' => 'Rejected reports',
    _ => 'All reports',
  };

  Widget _dashboard() => _pageScaffold(
    title: 'Admin Dashboard',
    subtitle: 'A clear overview of your client reports and review activity.',
    action: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (widget.canReview)
          OutlinedButton.icon(
            onPressed: _manageReportTemplate,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Report template'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _adminNavy,
              side: const BorderSide(color: Color(0xffd4e2f7)),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: _addClient,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add client'),
          style: _primaryButtonStyle(),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _periodSelector(
                label: _monthName(_dashPeriod.month),
                icon: Icons.calendar_month_rounded,
                onPrevious: () => setState(() {
                  _dashPeriod = DateTime(
                    _dashPeriod.year,
                    _dashPeriod.month - 1,
                  );
                }),
                onNext: () => setState(() {
                  _dashPeriod = DateTime(
                    _dashPeriod.year,
                    _dashPeriod.month + 1,
                  );
                }),
              ),
              _periodSelector(
                label: '${_dashPeriod.year}',
                icon: Icons.date_range_rounded,
                onPrevious: () => setState(() {
                  _dashPeriod = DateTime(
                    _dashPeriod.year - 1,
                    _dashPeriod.month,
                  );
                }),
                onNext: () => setState(() {
                  _dashPeriod = DateTime(
                    _dashPeriod.year + 1,
                    _dashPeriod.month,
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          child: LayoutBuilder(
            builder: (_, c) {
              final cards = <Widget>[
                _statCard(
                  'Clients',
                  _clients.length,
                  Icons.groups_rounded,
                  const Color(0xff486bf0),
                  selected: false,
                  onTap: () => _selectPage(_AdminPage.clients),
                ),
                _statCard(
                  'Total reports',
                  _dashPeriodSubmissions.length,
                  Icons.description_rounded,
                  _adminBlue,
                  selected: _dashFilter == 'all',
                  onTap: () => setState(() => _dashFilter = 'all'),
                ),
                _statCard(
                  'Pending approval',
                  _statusCount('pending'),
                  Icons.schedule_rounded,
                  const Color(0xfff59e0b),
                  selected: _dashFilter == 'pending',
                  onTap: () => setState(() => _dashFilter = 'pending'),
                ),
                _statCard(
                  'Approved',
                  _statusCount('approved'),
                  Icons.check_circle_rounded,
                  const Color(0xff10a76b),
                  selected: _dashFilter == 'approved',
                  onTap: () => setState(() => _dashFilter = 'approved'),
                ),
                _statCard(
                  'Rejected',
                  _statusCount('rejected'),
                  Icons.cancel_rounded,
                  const Color(0xffe5484d),
                  selected: _dashFilter == 'rejected',
                  onTap: () => setState(() => _dashFilter = 'rejected'),
                ),
              ];
              final cols = c.maxWidth >= 1000
                  ? 5
                  : c.maxWidth > 780
                  ? 3
                  : c.maxWidth > 460
                  ? 2
                  : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: c.maxWidth < 460 ? 3.2 : 1.8,
                children: cards,
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        SectionTitle(
          title: _dashSectionTitle,
          subtitle: '${_monthName(_dashPeriod.month)} ${_dashPeriod.year}',
          icon: Icons.inbox_rounded,
        ),
        const SizedBox(height: 14),
        _reportList(_dashReports),
      ],
    ),
  );

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

  Widget _periodSelector({
    required String label,
    required IconData icon,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xffd9e7fb)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10082d61),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: _adminBlue),
          IconButton(
            tooltip: 'Previous $label',
            onPressed: onPrevious,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded, color: _adminBlue),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _adminNavy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            tooltip: 'Next $label',
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded, color: _adminBlue),
          ),
        ],
      ),
    );
  }

  Widget _clientsPage() => _loading
      ? const Center(child: CircularProgressIndicator(color: _adminBlue))
      : _error != null
      ? _message('Could not load client data', _error!, onRetry: _load)
      : ReportWorkspace(
          child: RefreshIndicator(
            onRefresh: _load,
            color: _adminBlue,
            child: ListView(
            padding: const EdgeInsets.all(24),
            children: [ReportClientManager(onChanged: _load)],
            ),
          ),
        );

  Widget _reportsPage() => _pageScaffold(
    title: 'Reports',
    subtitle: 'Review submissions and open each client’s monthly reports.',
    action: FilledButton.icon(
      onPressed: _newReport,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New report'),
      style: _primaryButtonStyle(),
    ),
    child: _reportList(_applyQuery(_submissions)),
  );

  Widget _pageScaffold({
    required String title,
    required Widget child,
    String? subtitle,
    Widget? action,
  }) => _loading
      ? const Center(child: CircularProgressIndicator(color: _adminBlue))
      : _error != null
      ? _message('Could not load report data', _error!, onRetry: _load)
      : ReportWorkspace(
          child: RefreshIndicator(
            onRefresh: _load,
            color: _adminBlue,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _pageHeading(title, subtitle ?? '', action: action),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        );

  Widget _pageHeading(
    String title,
    String subtitle, {
    Widget? action,
    IconData icon = Icons.analytics_rounded,
  }) {
    return ReportHeroHeader(
      title: title,
      subtitle: subtitle,
      icon: icon,
      action: action,
    );
  }

  ButtonStyle _primaryButtonStyle() => FilledButton.styleFrom(
    backgroundColor: _adminBlue,
    foregroundColor: Colors.white,
    elevation: 2,
    shadowColor: _adminBlue.withValues(alpha: .25),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  );

  Widget _statCard(
    String title,
    int value,
    IconData icon,
    Color color, {
    required bool selected,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color.withValues(alpha: .12), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Colors.white, Color(0xfffbfdff)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xffe1eaf7),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? color.withValues(alpha: .15)
                  : const Color(0x10082d61),
              blurRadius: selected ? 20 : 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: .78)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '$value',
                      key: ValueKey(value),
                      style: const TextStyle(
                        fontSize: 27,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        color: _adminNavy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff627594),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    ),
  );

  Widget _reportList(List<Map<String, dynamic>> reports) {
    if (reports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: BrandEmptyState(
          icon: Icons.description_outlined,
          title: 'No reports found',
          subtitle: 'Reports your team submits will appear here.',
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < reports.length; i++)
          FadeSlideIn(
            delay: Duration(milliseconds: 40 * i),
            child: _ReportRow(
              report: reports[i],
              shortDate: _shortDate,
              onTap: () => _openClient({
                'name': reports[i]['company_name']?.toString() ?? 'Client',
              }),
            ),
          ),
      ],
    );
  }

  static String _shortDate(Object? raw) {
    if (raw == null) return '';
    final text = raw.toString();
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  Widget _message(
    String title,
    String details, {
    required VoidCallback onRetry,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffe0eafa)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10082d61),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xffffeeee),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xffe5484d),
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: _adminNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              details,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4, color: Color(0xff627594)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: _primaryButtonStyle(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.shortDate,
    required this.onTap,
  });

  final Map<String, dynamic> report;
  final String Function(Object?) shortDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final company = report['company_name']?.toString() ?? 'Client';
    final period =
        '${report['report_month'] ?? ''}/${report['report_year'] ?? ''}';
    final status = report['status']?.toString().toLowerCase() ?? 'pending';
    final who = report['submitted_by_name']?.toString() ?? 'Employee';
    final when = shortDate(report['created_at']);
    final reviewer = report['reviewed_by_name']?.toString();
    final note = report['review_note']?.toString();
    final statusColor = switch (status) {
      'approved' => const Color(0xff109b65),
      'rejected' => const Color(0xffd9364f),
      _ => const Color(0xffd58a08),
    };
    final statusIcon = switch (status) {
      'approved' => Icons.check_circle_rounded,
      'rejected' => Icons.cancel_rounded,
      _ => Icons.schedule_rounded,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffe0eafa)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0c082d61),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final details = Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _adminNavy,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 14,
                            color: Color(0xff6c7e9b),
                          ),
                          Text(
                            period,
                            style: const TextStyle(
                              color: Color(0xff627594),
                              fontSize: 12,
                            ),
                          ),
                          const Text(
                            '•',
                            style: TextStyle(color: Color(0xff9aabc3)),
                          ),
                          Text(
                            'by $who',
                            style: const TextStyle(
                              color: Color(0xff627594),
                              fontSize: 12,
                            ),
                          ),
                          if (when.isNotEmpty)
                            Text(
                              '• $when',
                              style: const TextStyle(
                                color: Color(0xff627594),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      if (status == 'rejected' &&
                          note != null &&
                          note.isNotEmpty)
                        _noteLine('Rejected: $note', const Color(0xffd9364f))
                      else if (status == 'approved' &&
                          reviewer != null &&
                          reviewer.isNotEmpty)
                        _noteLine(
                          'Approved by $reviewer',
                          const Color(0xff109b65),
                        ),
                    ],
                  ),
                );
                final statusChip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: statusColor.withValues(alpha: .22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        status.isEmpty
                            ? 'Pending'
                            : status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );
                final rowContent = Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _adminElectric.withValues(alpha: .16),
                            _adminBlue.withValues(alpha: .08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: _adminBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    details,
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      statusChip,
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xff8ca0bf),
                      ),
                    ],
                  ],
                );
                if (!compact) return rowContent;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    rowContent,
                    const SizedBox(height: 12),
                    statusChip,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _noteLine(String text, Color color) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}
