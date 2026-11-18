import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/auth/auth_session.dart';
import '../../core/colors/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../workspace_dashboard/data/workspace_dashboard_service.dart';
import '../../shared/widgets/app_svg_icon.dart';
import '../../shared/widgets/client_report_business_dialog.dart';
// ✅ Correct package import
import 'package:godigital_portal/report/data/full_report_service.dart';
import 'package:godigital_portal/report/report_dashboard_screen.dart';

class EmployeeWorkspaceScreen extends StatefulWidget {
  const EmployeeWorkspaceScreen({super.key});

  @override
  State<EmployeeWorkspaceScreen> createState() =>
      _EmployeeWorkspaceScreenState();
}

class _EmployeeWorkspaceScreenState extends State<EmployeeWorkspaceScreen> {
  final _service = const WorkspaceDashboardService();
  Map<String, dynamic>? _portfolio;
  Map<String, dynamic>? _business;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _period = 30;

  @override
  void initState() {
    super.initState();
    if (AuthSession.userRole == 'EMPLOYEE') _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final portfolio = await _service.portfolio();
      if (!mounted) return;
      setState(() => _portfolio = portfolio);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBusiness(Map<String, dynamic> business) async {
    final id = _id(business['id']);
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await _service.business(id, period: _period);
      if (mounted) setState(() => _business = details);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    final business = _map(_business?['business']);
    final id = _id(business['id']);
    if (id == null || business['can_take_action'] != true || _refreshing)
      return;
    setState(() => _refreshing = true);
    try {
      final details = await _service.refreshBusiness(id, period: _period);
      if (mounted) setState(() => _business = details);
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _updateAction(Map<String, dynamic> action, String status) async {
    final businessId = _id(_map(_business?['business'])['id']);
    final actionId = _id(action['id']);
    if (businessId == null || actionId == null) return;
    try {
      await _service.updateAction(
        businessId: businessId,
        actionId: actionId,
        status: status,
      );
      await _openBusiness(_map(_business?['business']));
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  void _logout() {
    AuthSession.clear();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  Future<void> _openClientsFullReport() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportDashboardScreen()),
    );
  }

  Future<void> _uploadReportTemplate() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pptx'], withData: true);
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    try { await const FullReportService().uploadSharedReportTemplate(file.bytes!, file.name); if (mounted) _showMessage('Shared report template saved.'); } catch (error) { if (mounted) _showMessage(_errorMessage(error)); }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthSession.userRole != 'EMPLOYEE')
      return _AccessDenied(onExit: _logout);
    final narrow = MediaQuery.sizeOf(context).width < 850;
    final activeBusiness = _map(_business?['business']);
    void openConnections() {
      if (_id(activeBusiness['id']) == null) return;
      Navigator.pushNamed(
        context,
        AppRoutes.accountConnections,
        arguments: activeBusiness,
      );
    }

    void openReport() {
      if (_id(activeBusiness['id']) == null) return;
      Navigator.pushNamed(
        context,
        AppRoutes.fullReport,
        arguments: activeBusiness,
      );
    }
    void openHome() {
      setState(() => _business = null);
      if (narrow) Navigator.pop(context);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: narrow
          ? Drawer(
              child: _BusinessDrawer(
                items: _list(_portfolio?['businesses']),
                selectedId: _id(activeBusiness['id']),
                showClientWorkspace: activeBusiness.isNotEmpty,
                onHome: openHome,
                onSelect: (business) {
                  Navigator.pop(context);
                  _openBusiness(business);
                },
                onOpenConnections: openConnections,
                onOpenReport: openReport,
                onOpenClientReportHistory: _openClientsFullReport,
                onLogout: _logout,
              ),
            )
          : null,
      body: Row(
        children: [
          if (!narrow)
            SizedBox(
              width: 260,
              child: _BusinessDrawer(
                items: _list(_portfolio?['businesses']),
                selectedId: _id(activeBusiness['id']),
                showClientWorkspace: activeBusiness.isNotEmpty,
                onHome: openHome,
                onSelect: _openBusiness,
                onOpenConnections: openConnections,
                onOpenReport: openReport,
                onOpenClientReportHistory: _openClientsFullReport,
                onLogout: _logout,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                Builder(
                  builder: (scaffoldContext) => _Header(
                    narrow: narrow,
                    onMenu: () => Scaffold.of(scaffoldContext).openDrawer(),
                    onClientsFullReport: _openClientsFullReport,
                    onReportTemplate: _uploadReportTemplate,
                    onLogout: _logout,
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _portfolio == null)
      return const Center(child: CircularProgressIndicator());
    final assigned = _list(_portfolio?['businesses']);
    if (_error != null && _business == null)
      return _ErrorState(message: _error!, onRetry: _loadPortfolio);
    if (assigned.isEmpty) return const _EmptyAssignments();
    if (_business == null)
      return _EmployeeCompanyHome(items: assigned, onOpen: _openBusiness);
    return RefreshIndicator(
      onRefresh: () => _openBusiness(_map(_business?['business'])),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: _details(),
          ),
        ),
      ),
    );
  }

  Widget _details() {
    final business = _map(_business?['business']);
    final metrics = _map(_business?['metrics']);
    final canAct = business['can_take_action'] == true;
    final permission = '${business['permission_level'] ?? 'VIEW'}';
    final address = [
      business['address'],
      business['city'],
      business['state'],
    ].where((item) => item != null && '$item'.trim().isNotEmpty).join(', ');
    final charts = _list(_business?['charts']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${business['name'] ?? 'Assigned business'}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    address.isEmpty
                        ? 'Business details assigned by your administrator.'
                        : address,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            _PermissionChip(level: permission),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...[7, 30, 90].map(
              (days) => ChoiceChip(
                label: Text('${days}D'),
                selected: _period == days,
                onSelected: (_) async {
                  setState(() => _period = days);
                  await _openBusiness(business);
                },
              ),
            ),
            if (canAct)
              OutlinedButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh data'),
              ),
          ],
        ),
        if (!canAct) ...[
          const SizedBox(height: 10),
          const Text(
            'Your assignment is view-only. Ask an administrator if you need action access.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 22),
        _section(
          'Current business health',
          'Only verified saved data is shown.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 1000
                ? 3
                : constraints.maxWidth > 620
                ? 2
                : 1;
            const metricItems = [
              ('Public audit', 'public_audit', Icons.fact_check_outlined),
              (
                'Local visibility',
                'local_visibility',
                Icons.location_searching_outlined,
              ),
              ('Reputation', 'reputation', Icons.star_outline_rounded),
              ('Website demand', 'website_demand', Icons.language_rounded),
              (
                'Customer actions',
                'customer_actions',
                Icons.ads_click_outlined,
              ),
              ('Connected sources', 'integrations', Icons.hub_outlined),
            ];
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: constraints.maxWidth > 620 ? 1.85 : 2.3,
              children: metricItems
                  .map(
                    (item) => _MetricCard(
                      title: item.$1,
                      data: _map(metrics[item.$2]),
                      icon: item.$3,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        _section(
          'Verified performance',
          'Trends appear only when the assigned business has saved history.',
        ),
        const SizedBox(height: 12),
        if (charts.isEmpty)
          _Panel(
            child: const Text(
              'No verified performance history is available for this business yet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: charts
                  .map(
                    (chart) => SizedBox(
                      width: constraints.maxWidth > 800
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth,
                      child: _TrendCard(chart: _map(chart)),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: constraints.maxWidth > 800
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth,
                child: _AttentionPanel(items: _list(_business?['attention'])),
              ),
              SizedBox(
                width: constraints.maxWidth > 800
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth,
                child: _ActionsPanel(
                  actions: _list(_business?['actions']),
                  canAct: canAct,
                  onUpdate: _updateAction,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ],
  );
}

class _EmployeeCompanyHome extends StatelessWidget {
  const _EmployeeCompanyHome({required this.items, required this.onOpen});
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My client assignments',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Companies are grouped by how they became a client.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(builder: (_, box) {
              final onboarded = items.where((item) {
                final business = _map(item['business']);
                return business['client_lifecycle'] == 'ONBOARDED' &&
                    business['client_origin'] == 'LEAD_QUEUE';
              }).toList();
              final companies = items.where((item) {
                final business = _map(item['business']);
                return business['client_lifecycle'] == 'ONBOARDED' &&
                    business['client_origin'] == 'COMPANY';
              }).toList();
              final clientColumns = [
                _EmployeeClientGroup(
                  title: 'Onboarded clients',
                  subtitle: 'Leads moved from the follow-up queue.',
                  items: onboarded,
                  onOpen: onOpen,
                ),
                _EmployeeClientGroup(
                  title: 'Company clients',
                  subtitle: 'Companies created directly by the admin team.',
                  items: companies,
                  onOpen: onOpen,
                ),
              ];
              return box.maxWidth >= 900
                  ? Row(children: [Expanded(child: clientColumns[0]), const SizedBox(width: 18), Expanded(child: clientColumns[1])])
                  : Column(children: [clientColumns[0], const SizedBox(height: 18), clientColumns[1]]);
            }),
          ],
        ),
      ),
    ),
  );
}

class _EmployeeClientGroup extends StatelessWidget {
  const _EmployeeClientGroup({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onOpen,
  });
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAFF),
      border: Border.all(color: const Color(0xFFDCE8FC)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No assigned clients in this category.', style: TextStyle(color: AppColors.textSecondary))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: 12,
              mainAxisExtent: 160,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final business = _map(items[index]['business']);
              return InkWell(
                onTap: () => onOpen(business),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDCE8FC)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.business_outlined, color: AppColors.primaryBlue, size: 30),
                      const SizedBox(height: 13),
                      Text('${business['name'] ?? 'Assigned company'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('${business['city'] ?? 'Company workspace'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const Spacer(),
                      const Row(children: [Text('Open company', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryBlue)), SizedBox(width: 5), Icon(Icons.arrow_forward_rounded, color: AppColors.primaryBlue, size: 17)]),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}

class _EmployeeClientAccess extends StatelessWidget {
  const _EmployeeClientAccess({required this.business});
  final Map<String, dynamic> business;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${business['name'] ?? 'Assigned company'}',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Connect the client’s accounts, then open the generated full report.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDCE8FC)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.menu_open_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Use the Client Workspace menu in the sidebar to open Account Connections or Full Report for this company.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BusinessDrawer extends StatelessWidget {
  const _BusinessDrawer({
    required this.items,
    required this.selectedId,
    required this.showClientWorkspace,
    required this.onHome,
    required this.onSelect,
    required this.onOpenConnections,
    required this.onOpenReport,
    required this.onOpenClientReportHistory,
    required this.onLogout,
  });

  final List<Map<String, dynamic>> items;
  final int? selectedId;
  final bool showClientWorkspace;
  final VoidCallback onHome;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onOpenConnections, onOpenReport, onOpenClientReportHistory;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF102354),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  height: 66,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/go_digital_brand_logo.webp',
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _EmployeeNavItem(
                icon: const AppMenuSvg(asset: 'assets/icons/app_menu/home.svg', size: 20),
                label: 'Home',
                onTap: onHome,
              ),
              const SizedBox(height: 20),
              if (showClientWorkspace) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'CLIENT WORKSPACE',
                    style: TextStyle(
                      color: Color(0xFFBBD2FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _EmployeeNavItem(
                  icon: const AppMenuSvg(asset: 'assets/icons/app_menu/connections.svg', size: 20),
                  label: 'Account connections',
                  onTap: onOpenConnections,
                ),
                const SizedBox(height: 5),
                _EmployeeNavItem(
                  icon: const AppMenuSvg(asset: 'assets/icons/app_menu/full_report.svg', size: 20),
                  label: 'Full report',
                  onTap: onOpenReport,
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 28),
              _EmployeeNavItem(
                icon: const AppMenuSvg(asset: 'assets/icons/app_menu/full_report.svg', size: 20),
                label: 'Clients Full Report',
                onTap: onOpenClientReportHistory,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'ASSIGNED BUSINESSES',
                  style: TextStyle(
                    color: Color(0xFFBBD2FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'No assigned businesses',
                          style: TextStyle(color: Color(0xFFBBD2FF)),
                        ),
                      )
                    : ListView(
                        children: items.map((item) {
                          final business = _map(item['business']);
                          final selected = _id(business['id']) == selectedId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              selected: selected,
                              selectedTileColor: const Color(0xFF2866F2),
                              leading: Icon(
                                Icons.check_circle_outline_rounded,
                                color: selected ? Colors.white : const Color(0xFFBBD2FF),
                                size: 20,
                              ),
                              title: Text(
                                '${business['name'] ?? 'Business'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${business['permission_level'] ?? 'VIEW'} access',
                                style: const TextStyle(
                                  color: Color(0xFFD9E6FF),
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () => onSelect(business),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              Divider(color: Colors.white.withOpacity(.18)),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.white),
                title: const Text(
                  'Sign out',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeNavItem extends StatelessWidget {
  const _EmployeeNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    leading: icon,
    title: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFE4EEFF),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
    onTap: onTap,
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.narrow,
    required this.onMenu,
    required this.onClientsFullReport,
    required this.onReportTemplate,
    required this.onLogout,
  });
  final bool narrow;
  final VoidCallback onMenu, onClientsFullReport, onReportTemplate, onLogout;
  @override
  Widget build(BuildContext context) => Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFDCE8FC))),
    ),
    child: Row(
      children: [
        if (narrow)
          IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
        const Expanded(
          child: Text(
            'Employee workspace',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onReportTemplate,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('Report template'),
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          backgroundColor: const Color(0xFFE8F1FF),
          child: Text(
            AuthSession.initials,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onLogout,
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.data,
    required this.icon,
  });
  final String title;
  final Map<String, dynamic> data;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final available = data['status'] == 'DATA_AVAILABLE';
    final value = data['value'];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            available ? _value(value) : 'Unavailable',
            style: TextStyle(
              fontSize: available ? 25 : 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            available
                ? 'Updated ${_date(data['updated_at'])}'
                : '${data['next_step'] ?? 'No verified data yet.'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.chart});
  final Map<String, dynamic> chart;
  @override
  Widget build(BuildContext context) {
    final series = _list(chart['series']);
    final first = series.isEmpty ? <String, dynamic>{} : _map(series.first);
    final points = _list(first['points']);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${chart['title'] ?? 'Performance'}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 3),
          Text(
            '${chart['source'] ?? 'Verified source'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 105,
            width: double.infinity,
            child: points.length < 2
                ? const Center(
                    child: Text(
                      'More verified history is needed.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : CustomPaint(painter: _LinePainter(points)),
          ),
          const SizedBox(height: 8),
          Text(
            points.isEmpty
                ? 'No verified values'
                : '${first['label'] ?? 'Latest'}: ${_value(_map(points.last)['value'])}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    final item = items.isEmpty ? <String, dynamic>{} : items.first;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'What needs attention',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.isEmpty ? 'Everything looks stable' : '${item['title']}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            item.isEmpty
                ? 'No verified risks need attention right now.'
                : '${item['detail']}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel({
    required this.actions,
    required this.canAct,
    required this.onUpdate,
  });
  final List<Map<String, dynamic>> actions;
  final bool canAct;
  final Future<void> Function(Map<String, dynamic>, String) onUpdate;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.trending_up_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text(
              'Recommended actions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (actions.isEmpty)
          const Text(
            'No saved recommendations are available yet.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...actions
              .take(3)
              .map(
                (action) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${action['title'] ?? 'Recommended action'}'),
                  subtitle: Text(
                    '${action['reason_text'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: canAct && action['status'] == 'RECOMMENDED'
                      ? TextButton(
                          onPressed: () => onUpdate(action, 'STARTED'),
                          child: const Text('Start'),
                        )
                      : canAct && action['status'] == 'STARTED'
                      ? FilledButton(
                          onPressed: () => onUpdate(action, 'COMPLETED'),
                          child: const Text('Complete'),
                        )
                      : Text(
                          '${action['status'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
              ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD5E4FF)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C145CF2),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.level});
  final String level;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text('$level access'),
    backgroundColor: level == 'VIEW'
        ? const Color(0xFFF1F4FA)
        : const Color(0xFFE7F2FF),
    side: const BorderSide(color: Color(0xFFC8DEFF)),
  );
}

class _EmptyAssignments extends StatelessWidget {
  const _EmptyAssignments();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.business_center_outlined,
            size: 54,
            color: AppColors.primaryBlue,
          ),
          SizedBox(height: 14),
          Text(
            'No business has been assigned yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'Ask an administrator to assign you to a business before using this workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load your assigned businesses',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.onExit});
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: OutlinedButton(
        onPressed: onExit,
        child: const Text('Return home'),
      ),
    ),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.points);
  final List<Map<String, dynamic>> points;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points
        .map((point) => _number(point['value']))
        .whereType<double>()
        .toList();
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1 : max - min;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y =
          size.height - ((values[i] - min) / range * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primaryBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.points != points;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : const [];
int? _id(dynamic value) => int.tryParse('$value');
double? _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value');
String _value(dynamic value) {
  final number = _number(value);
  return number == null
      ? '—'
      : number == number.roundToDouble()
      ? number.toInt().toString()
      : number.toStringAsFixed(1);
}

String _date(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return 'not available';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _errorMessage(Object error) => error
    .toString()
    .replaceFirst('WorkspaceDashboardException: ', '')
    .replaceFirst('Exception: ', '');
