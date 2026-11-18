// lib/report/report_dashboard_screen.dart
//
// The Report section entry point. Shows a dashboard of saved clients (previous
// records) with their logos and report counts. From here the user can:
//   - open a client to see their report history (view / download / delete), or
//   - start a new report (which opens the create-client dialog for new clients).
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/auth/auth_session.dart';
import 'client_report_business_dialog.dart';
import 'clients_full_report_screen.dart';
import 'report_approvals_screen.dart';
import 'data/full_report_service.dart';

const _navy = Color(0xFF142F61);
const _accent = Color(0xFF2563EB);
const _bg = Color(0xFFF4F7FC);
const _muted = Color(0xFF64748B);

const _months = <String>[
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _monthLabel(dynamic month, dynamic year) {
  final m = int.tryParse('${month ?? ''}') ?? 0;
  final name = (m >= 1 && m <= 12) ? _months[m] : '';
  return [name, '$year'].where((p) => p.trim().isNotEmpty).join(' ');
}

String _dateLabel(dynamic value) {
  final text = value?.toString() ?? '';
  final dt = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (dt == null) return '';
  final d = dt.toLocal();
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month].substring(0, 3)} ${d.year}';
}

ImageProvider? _logoProvider(Map<String, dynamic> source) {
  final encoded = source['logoBase64']?.toString() ?? source['companyLogoBase64']?.toString();
  if (encoded == null || encoded.isEmpty) return null;
  try {
    return MemoryImage(base64Decode(encoded));
  } catch (_) {
    return null;
  }
}

class ReportDashboardScreen extends StatefulWidget {
  const ReportDashboardScreen({super.key});

  @override
  State<ReportDashboardScreen> createState() => _ReportDashboardScreenState();
}

class _ReportDashboardScreenState extends State<ReportDashboardScreen> {
  final _service = const FullReportService();
  late Future<List<Map<String, dynamic>>> _clientsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _clientsFuture = _service.savedClients();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _clientsFuture.catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> _startNewReport() async {
    final business = await showClientReportBusinessDialog(context);
    if (business == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientsFullReportScreen(business: business)),
    );
    if (mounted) _refresh();
  }

  Future<void> _openClient(Map<String, dynamic> client) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientReportHistoryScreen(client: client)),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0.5,
        title: const Text('Client Reports', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (AuthSession.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportApprovalsScreen())),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Approvals'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _clientsFuture,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final clients = snapshot.data ?? const <Map<String, dynamic>>[];
            final filtered = _query.trim().isEmpty
                ? clients
                : clients.where((c) => (c['name']?.toString() ?? '').toLowerCase().contains(_query.toLowerCase())).toList();
            final totalReports = clients.fold<int>(0, (sum, c) => sum + ((c['reportCount'] as int?) ?? 0));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                _HeaderCard(onNewReport: _startNewReport),
                const SizedBox(height: 18),
                Row(children: [
                  _StatChip(icon: Icons.groups_rounded, label: 'Clients', value: '${clients.length}'),
                  const SizedBox(width: 14),
                  _StatChip(icon: Icons.description_rounded, label: 'Reports generated', value: '$totalReports'),
                ]),
                const SizedBox(height: 22),
                Row(children: [
                  const Text('Your clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  if (clients.isNotEmpty)
                    SizedBox(
                      width: 240,
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search clients',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),
                if (loading)
                  const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  _EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load clients',
                    subtitle: '${snapshot.error}',
                    actionLabel: 'Retry',
                    onAction: _refresh,
                  )
                else if (clients.isEmpty)
                  _EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: 'No client reports yet',
                    subtitle: 'Create your first client report to see it here.',
                    actionLabel: 'New report',
                    onAction: _startNewReport,
                  )
                else if (filtered.isEmpty)
                  const _EmptyState(icon: Icons.search_off_rounded, title: 'No matching clients', subtitle: 'Try a different search term.')
                else
                  LayoutBuilder(builder: (context, constraints) {
                    final cols = constraints.maxWidth > 1100 ? 4 : constraints.maxWidth > 760 ? 3 : constraints.maxWidth > 500 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.45,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _ClientCard(client: filtered[i], onTap: () => _openClient(filtered[i])),
                    );
                  }),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewReport,
        backgroundColor: _accent,
        icon: const Icon(Icons.add),
        label: const Text('New report'),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.onNewReport});
  final VoidCallback onNewReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [_navy, Color(0xFF2747B8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CLIENT MONTHLY REPORTS', style: TextStyle(color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Generate & manage client reports', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Pick a client to view past reports, or start a new monthly report.', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onNewReport,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _navy, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              icon: const Icon(Icons.add_chart_rounded),
              label: const Text('New report', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.insights_rounded, color: Colors.white24, size: 92),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F1E3D14), blurRadius: 14, offset: Offset(0, 6))]),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _accent)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _navy)),
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.client, required this.onTap});
  final Map<String, dynamic> client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = client['name']?.toString() ?? 'Client';
    final count = (client['reportCount'] as int?) ?? 0;
    final last = _dateLabel(client['lastReportAt']);
    final logo = _logoProvider(client);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE6ECF6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 26, backgroundColor: const Color(0xFFEFF3FB), backgroundImage: logo, child: logo == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 20)) : null),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ]),
            const Spacer(),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 4),
            Text('$count report${count == 1 ? '' : 's'}${last.isEmpty ? '' : '  •  $last'}', style: const TextStyle(color: _muted, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Center(
        child: Column(children: [
          Icon(icon, size: 56, color: _muted.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 6),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted))),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, style: FilledButton.styleFrom(backgroundColor: _accent), child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-client report history / dashboard
// ---------------------------------------------------------------------------
class ClientReportHistoryScreen extends StatefulWidget {
  const ClientReportHistoryScreen({super.key, required this.client});
  final Map<String, dynamic> client;

  @override
  State<ClientReportHistoryScreen> createState() => _ClientReportHistoryScreenState();
}

class _ClientReportHistoryScreenState extends State<ClientReportHistoryScreen> {
  final _service = const FullReportService();
  late Future<List<dynamic>> _reportsFuture;

  String get _name => widget.client['name']?.toString() ?? 'Client';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _reportsFuture = _service.clientReportHistory(companyName: _name);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _reportsFuture.catchError((_) => <dynamic>[]);
  }

  void _toast(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _newReport() async {
    final now = DateTime.now();
    final business = <String, dynamic>{
      'name': _name,
      'reportMonth': now.month,
      'reportYear': now.year,
      'existingReports': <dynamic>[],
      if (widget.client['logoBase64'] != null) 'companyLogoBase64': widget.client['logoBase64'],
      if (widget.client['logoMimeType'] != null) 'companyLogoMimeType': widget.client['logoMimeType'],
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClientsFullReportScreen(business: business)));
    if (mounted) _refresh();
  }

  Future<void> _download(Map<String, dynamic> item) async {
    try {
      await _service.downloadClientHistoryItem(item);
    } catch (error) {
      _toast(error.toString());
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete report?'),
        content: const Text('This permanently deletes the saved report.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.deleteClientHistoryItem(item);
      _refresh();
    } catch (error) {
      _toast(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final logo = _logoProvider(widget.client);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _navy,
        elevation: 0.5,
        title: Text(_name, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0F1E3D14), blurRadius: 14, offset: Offset(0, 6))]),
              child: Row(children: [
                CircleAvatar(radius: 32, backgroundColor: const Color(0xFFEFF3FB), backgroundImage: logo, child: logo == null ? Text(_name.isNotEmpty ? _name[0].toUpperCase() : '?', style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 24)) : null),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
                  const SizedBox(height: 4),
                  const Text('Report history', style: TextStyle(color: _muted)),
                ])),
                FilledButton.icon(onPressed: _newReport, style: FilledButton.styleFrom(backgroundColor: _accent), icon: const Icon(Icons.add), label: const Text('New report')),
              ]),
            ),
            const SizedBox(height: 22),
            const Text('Previous reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: _reportsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return _EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load reports', subtitle: '${snapshot.error}', actionLabel: 'Retry', onAction: _refresh);
                }
                final reports = (snapshot.data ?? const <dynamic>[]).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                if (reports.isEmpty) {
                  return _EmptyState(icon: Icons.description_outlined, title: 'No reports yet', subtitle: 'Create a report for $_name to see it here.', actionLabel: 'New report', onAction: _newReport);
                }
                return Column(children: [for (final item in reports) _ReportTile(item: item, onDownload: () => _download(item), onDelete: () => _delete(item))]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.item, required this.onDownload, required this.onDelete});
  final Map<String, dynamic> item;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final format = (item['file_format']?.toString() ?? 'pdf').toUpperCase();
    final name = item['file_name']?.toString() ?? 'Report.$format';
    final period = _monthLabel(item['report_month'], item['report_year']);
    final created = _dateLabel(item['created_at']);
    final color = format == 'PDF' ? const Color(0xFFE11D48) : format == 'DOCX' ? const Color(0xFF2563EB) : const Color(0xFFEA580C);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE6ECF6))),
      child: Row(children: [
        Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Text(format, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 3),
          Text([period, created].where((p) => p.isNotEmpty).join('  •  '), style: const TextStyle(color: _muted, fontSize: 12.5)),
        ])),
        IconButton(onPressed: onDownload, icon: const Icon(Icons.download_rounded), color: _accent, tooltip: 'Download'),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded), color: _muted, tooltip: 'Delete'),
      ]),
    );
  }
}
