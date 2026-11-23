// lib/report/admin_client_manager.dart
//
// Admin client management for the report module: create a client (name, logo,
// business category), assign employee(s), and assign providers (shown with
// brand logos). Supports reassign, revoke and delete-when-no-history. Wired to
// the /report-export/report-clients endpoints via FullReportService.
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'client_monthly_reports_screen.dart';
import 'data/full_report_service.dart';
import 'report_brand.dart';
import 'report_providers.dart';

const _navy = Color(0xff082d61);
const _blue = Color(0xff0866e8);
const _sky = Color(0xff35a4ff);
const _paleBlue = Color(0xfff1f7ff);
const _lineBlue = Color(0xffdce8fb);
const _mutedBlue = Color(0xff647b9f);

class ReportClientManager extends StatefulWidget {
  const ReportClientManager({super.key, this.onChanged});

  /// Called after any create/assign/revoke/delete so the parent can refresh
  /// its own counts.
  final VoidCallback? onChanged;

  @override
  State<ReportClientManager> createState() => _ReportClientManagerState();
}

class _ReportClientManagerState extends State<ReportClientManager> {
  final _service = const FullReportService();
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = const [];
  List<Map<String, dynamic>> _employees = const [];

  // Clients list defaults to showing only ACTIVE clients. Switching this to
  // 'inactive' or 'hold' shows only clients in that state instead.
  String _statusFilter = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<List<Map<String, dynamic>>>([
        _service.reportClients(),
        _service.reportEmployees(),
        _service.taskManagerClientCards(),
      ]);
      if (!mounted) return;
      final clientsByName = <String, Map<String, dynamic>>{
        for (final client in values[0])
          (client['companyName']?.toString() ?? '').trim().toLowerCase():
              <String, dynamic>{...client, '_reportClient': true},
      };
      for (final card in values[2]) {
        final name = (card['client_name']?.toString() ?? '').trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        final client = clientsByName.putIfAbsent(
          key,
          () => <String, dynamic>{
            'companyName': name,
            'businessCategory': '',
            'status': 'active',
            'reportCount': 0,
            'employees': <Map<String, dynamic>>[],
            'providers': <String>[],
            '_reportClient': false,
          },
        );
        final cards =
            client.putIfAbsent('taskManagerCards', () => <Map<String, dynamic>>[])
                as List;
        cards.add(card);
      }
      final clients = clientsByName.values.toList()
        ..sort(
          (a, b) => (a['companyName']?.toString() ?? '')
              .toLowerCase()
              .compareTo((b['companyName']?.toString() ?? '').toLowerCase()),
        );
      for (final client in clients) {
        final providerNames = <String>{
          for (final provider in (client['providers'] as List? ?? const []))
            '$provider',
        };
        final employeeNames = <String>{};
        for (final rawCard
            in (client['taskManagerCards'] as List? ?? const <dynamic>[])
                .whereType<Map>()) {
          for (final rawTask in (rawCard['tasks'] as List? ?? const [])) {
            if (rawTask is! Map) continue;
            final taskName = rawTask['name']?.toString().trim() ?? '';
            if (taskName.isNotEmpty && providerForName(taskName) != null) {
              providerNames.add(taskName);
            }
            final employee = rawTask['employee']?.toString().trim() ?? '';
            if (employee.isNotEmpty) employeeNames.add(employee);
          }
          for (final rawMember in (rawCard['team'] as List? ?? const [])) {
            if (rawMember is Map) {
              final employee = rawMember['employee']?.toString().trim() ?? '';
              if (employee.isNotEmpty) employeeNames.add(employee);
            }
          }
        }
        client['providers'] = providerNames.toList()..sort();
        client['taskManagerEmployees'] = employeeNames.toList()..sort();
      }
      setState(() {
        _clients = clients;
        _employees = values[1];
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

  void _notify() => widget.onChanged?.call();

  // Admin flow: tapping a client card opens its month-wise reports (existing
  // reports as cards + a "Create new report" card, each with on-screen preview).
  Future<void> _openMonthly(Map<String, dynamic> client) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ClientMonthlyReportsScreen(
          client: <String, dynamic>{
            'name': client['companyName']?.toString() ?? 'Client',
            // Provider keys resolve to brand logos in the monthly view.
            'assignedTasks': client['providers'],
            'taskManagerCards': client['taskManagerCards'],
            if (client['logoBase64'] != null)
              'logoBase64': client['logoBase64'],
          },
          canManageReports: true,
        ),
      ),
    );
    if (mounted) {
      await _load();
      _notify();
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _clients.where((c) {
      final status = (c['status']?.toString() ?? 'active').toLowerCase();
      if (status != _statusFilter) return false;
      if (q.isEmpty) return true;
      return (c['companyName']?.toString() ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int _statusCount(String status) => _clients
      .where((c) => (c['status']?.toString() ?? 'active').toLowerCase() == status)
      .length;

  Widget _statusFilterChip(String label, String value, int count) {
    final bool selected = _statusFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _statusFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_blue, _sky],
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.transparent : _lineBlue),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _blue.withValues(alpha: .24),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _mutedBlue,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: .22)
                    : _paleBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : _blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ClientEditorDialog(
        service: _service,
        employees: _employees,
        existing: existing,
      ),
    );
    if (saved == true) {
      await _load();
      _notify();
    }
  }

  Future<void> _revokeOrReassign(
      String company, Map<String, dynamic> employee) async {
    final others = _employees
        .where((e) => (e['id'] as num?)?.toInt() != employee['employeeId'])
        .toList();
    final result = await showDialog<_RevokeResult>(
      context: context,
      builder: (_) => _RevokeDialog(
        employeeName: employee['employeeName']?.toString() ?? 'employee',
        others: others,
      ),
    );
    if (result == null) return;
    try {
      await _service.revokeReportAssignment(
        companyName: company,
        employeeId: (employee['employeeId'] as num).toInt(),
        reassignToEmployeeId: result.reassignTo,
      );
      await _load();
      _notify();
      _toast(result.reassignTo != null
          ? 'Reassigned.'
          : 'Assignment revoked.');
    } catch (error) {
      _toast('$error');
    }
  }

  Future<void> _delete(Map<String, dynamic> client) async {
    final company = client['companyName']?.toString() ?? '';
    final reports = (client['reportCount'] as num?)?.toInt() ?? 0;
    if (reports > 0) {
      _toast('This client has report history and cannot be deleted. '
          'Revoke or reassign instead.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text('Remove "$company" and its assignments? '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteReportClient(company);
      await _load();
      _notify();
      _toast('Client deleted.');
    } catch (error) {
      _toast('$error');
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_blue, _sky]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: _blue.withValues(alpha: .22), blurRadius: 22, offset: const Offset(0, 8)),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Loading clients...', style: TextStyle(color: _mutedBlue, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _lineBlue),
            boxShadow: const [BoxShadow(color: Color(0x0c082d61), blurRadius: 28, offset: Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(color: const Color(0xfffff0f0), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.cloud_off_rounded, color: Color(0xffd9485f), size: 30),
              ),
              const SizedBox(height: 16),
              const Text('Couldn’t load clients', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _mutedBlue, height: 1.5)),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xfff4f8ff), Color(0xffeaf3ff)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xffdce8fb)),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: .12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Soft gradient glow accents (white-dominant surface).
              Positioned(
                right: -40,
                top: -55,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _sky.withValues(alpha: .18),
                        _blue.withValues(alpha: .04),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_blue, _sky],
                        ),
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withValues(alpha: .28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLIENT WORKSPACE',
                            style: TextStyle(
                              color: _blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [_navy, _blue],
                            ).createShader(bounds),
                            child: const Text(
                              'Manage clients',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Report access and platform assignments',
                            style: TextStyle(
                              color: _mutedBlue,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_blue, _sky],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withValues(alpha: .26),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_clients.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'CLIENTS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .85),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, color: _blue),
                  hintText: 'Search clients by company name...',
                  hintStyle: const TextStyle(color: Color(0xff91a4c0), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _lineBlue)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _lineBlue)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _blue, width: 1.6)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_blue, _sky],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: .30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 19, vertical: 17),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Add client',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _statusFilterChip('Active', 'active', _statusCount('active')),
            const SizedBox(width: 10),
            _statusFilterChip('Inactive', 'inactive', _statusCount('inactive')),
            const SizedBox(width: 10),
            _statusFilterChip('On Hold', 'hold', _statusCount('hold')),
          ],
        ),
        const SizedBox(height: 18),
        if (_filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _lineBlue)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 68, height: 68, decoration: BoxDecoration(color: _paleBlue, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.business_center_outlined, size: 32, color: _blue)),
              const SizedBox(height: 14),
              Text(
                _search.text.trim().isNotEmpty
                    ? 'No matching clients'
                    : _statusFilter == 'active'
                        ? 'No clients added yet'
                        : 'No ${_statusFilter == 'hold' ? 'on-hold' : 'inactive'} clients',
                style: const TextStyle(color: _navy, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _search.text.trim().isNotEmpty
                    ? 'Try another company name or clear your search.'
                    : _statusFilter == 'active'
                        ? 'Add your first client to start managing reports.'
                        : 'There are no clients in this state right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _mutedBlue, height: 1.5),
              ),
              if (_search.text.trim().isEmpty && _statusFilter == 'active') ...[
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: () => _openEditor(), icon: const Icon(Icons.add_rounded), label: const Text('Add your first client'), style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13))),
              ],
            ]),
          )
        else
          LayoutBuilder(
            builder: (_, c) {
              final cols = c.maxWidth > 1100 ? 3 : c.maxWidth > 720 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 292,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (_, i) => FadeSlideIn(
                  delay: Duration(milliseconds: 45 * i),
                  child: _ClientCard(
                    client: _filtered[i],
                    onOpen: () => _openMonthly(_filtered[i]),
                    onEdit: () => _openEditor(_filtered[i]),
                    onDelete: () => _delete(_filtered[i]),
                    onRevoke: (emp) => _revokeOrReassign(_filtered[i]['companyName']?.toString() ?? '', emp),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Client card ─────────────────────────────────────────────────────────────
class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onRevoke,
  });
  final Map<String, dynamic> client;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Map<String, dynamic>> onRevoke;

  @override
  Widget build(BuildContext context) {
    final name = client['companyName']?.toString() ?? 'Client';
    final category = client['businessCategory']?.toString() ?? '';
    final reports = (client['reportCount'] as num?)?.toInt() ?? 0;
    final providers = (client['providers'] as List? ?? const []).map((e) => '$e').toList();
    final employees = (client['employees'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['active'] == true)
        .toList();
    final employeeNames = employees
        .map((e) => e['employeeName']?.toString() ?? '')
        .toSet();
    for (final rawName in
        (client['taskManagerEmployees'] as List? ?? const [])) {
      final employeeName = rawName.toString();
      if (employeeName.isNotEmpty && employeeNames.add(employeeName)) {
        employees.add({
          'employeeName': employeeName,
          'active': true,
          'taskManagerAssignment': true,
        });
      }
    }
    final logoBytes = _decodeLogo(client['logoBase64']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _lineBlue),
            boxShadow: const [BoxShadow(color: Color(0x0d082d61), blurRadius: 22, offset: Offset(0, 8))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 5, decoration: const BoxDecoration(gradient: LinearGradient(colors: [_navy, _blue, _sky]))),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_blue, _sky]), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: _blue.withValues(alpha: .17), blurRadius: 12, offset: const Offset(0, 4))]),
                          clipBehavior: Clip.antiAlias,
                          child: logoBytes != null
                              ? Image.memory(logoBytes, fit: BoxFit.cover)
                              : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _navy)),
                          const SizedBox(height: 4),
                          Text(category.isEmpty ? 'Business category not set' : category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _mutedBlue, fontSize: 11.5)),
                        ])),
                        PopupMenuButton<String>(
                          tooltip: 'Client actions',
                          icon: const Icon(Icons.more_horiz_rounded, color: _mutedBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18, color: _blue),
                                  SizedBox(width: 10),
                                  Text('Edit / assign'),
                                ],
                              ),
                            ),
                            if (client['_reportClient'] == true)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                    SizedBox(width: 10),
                                    Text('Delete client'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 13),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: _paleBlue, borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xffe4efff))),
                        child: Row(children: [
                          Container(width: 31, height: 31, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.description_outlined, size: 17, color: _blue)),
                          const SizedBox(width: 9),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$reports report${reports == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12.5, color: _navy, fontWeight: FontWeight.w800)), const Text('Report history', style: TextStyle(fontSize: 10.5, color: _mutedBlue))])),
                          const Icon(Icons.arrow_forward_rounded, size: 17, color: _blue),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [const Icon(Icons.hub_outlined, size: 15, color: _blue), const SizedBox(width: 6), const Text('CONNECTED PLATFORMS', style: TextStyle(fontSize: 10, letterSpacing: .7, fontWeight: FontWeight.w900, color: _navy))]),
                      const SizedBox(height: 7),
                      if (providers.isEmpty)
                        const Text('No platforms assigned', style: TextStyle(color: _mutedBlue, fontSize: 11.5))
                      else
                        Wrap(spacing: 7, runSpacing: 6, children: providers.map((p) => Tooltip(message: providerForName(p)?.label ?? p, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _paleBlue, borderRadius: BorderRadius.circular(9), border: Border.all(color: _lineBlue)), child: ProviderLogo.fromName(p, size: 19, padded: true)))).toList()),
                      const SizedBox(height: 10),
                      Row(children: [const Icon(Icons.people_alt_outlined, size: 15, color: _blue), const SizedBox(width: 6), const Text('ASSIGNED TEAM', style: TextStyle(fontSize: 10, letterSpacing: .7, fontWeight: FontWeight.w900, color: _navy)), const Spacer(), Text('${employees.length}', style: const TextStyle(fontSize: 10.5, color: _mutedBlue, fontWeight: FontWeight.w800))]),
                      const SizedBox(height: 6),
                      Expanded(
                        child: employees.isEmpty
                            ? Row(children: [Icon(Icons.person_off_outlined, size: 15, color: _mutedBlue.withValues(alpha: .8)), const SizedBox(width: 6), const Text('No employees assigned', style: TextStyle(color: _mutedBlue, fontSize: 11.5))])
                            : SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 5, children: employees.map((e) => InputChip(
                                label: Text(e['employeeName']?.toString() ?? 'Employee', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                avatar: const Icon(Icons.person_rounded, size: 14, color: _blue),
                                backgroundColor: _paleBlue,
                                side: const BorderSide(color: _lineBlue),
                                visualDensity: VisualDensity.compact,
                                onDeleted: e['taskManagerAssignment'] == true
                                    ? null
                                    : () => onRevoke(e),
                                deleteIcon: const Icon(Icons.close_rounded, size: 13),
                                deleteButtonTooltipMessage:
                                    'Revoke / reassign',
                              )).toList())),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(color: Color(0xfff8fbff), border: Border(top: BorderSide(color: _lineBlue))),
                child: const Row(children: [Text('Open monthly reports', style: TextStyle(color: _blue, fontSize: 11.5, fontWeight: FontWeight.w800)), Spacer(), Icon(Icons.arrow_outward_rounded, color: _blue, size: 16)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Uint8List? _decodeLogo(Object? base64) {
  if (base64 is! String || base64.isEmpty) return null;
  try {
    return base64Decode(base64);
  } catch (_) {
    return null;
  }
}

// ── Add / edit client dialog ─────────────────────────────────────────────────
class _ClientEditorDialog extends StatefulWidget {
  const _ClientEditorDialog({
    required this.service,
    required this.employees,
    this.existing,
  });
  final FullReportService service;
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic>? existing;

  @override
  State<_ClientEditorDialog> createState() => _ClientEditorDialogState();
}

class _ClientEditorDialogState extends State<_ClientEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  final Set<String> _providers = {};
  final Set<int> _employeeIds = {};
  String? _logoBase64;
  String? _logoMime;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['companyName']?.toString() ?? '');
    _category =
        TextEditingController(text: e?['businessCategory']?.toString() ?? '');
    if (e != null) {
      for (final p in (e['providers'] as List? ?? const [])) {
        final match = providerForName('$p');
        if (match != null) _providers.add(match.key);
      }
      for (final emp in (e['employees'] as List? ?? const [])) {
        if (emp is Map && emp['active'] == true) {
          final id = (emp['employeeId'] as num?)?.toInt();
          if (id != null) _employeeIds.add(id);
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    final file = res?.files.single;
    if (file?.bytes == null) return;
    setState(() {
      _logoBase64 = base64Encode(file!.bytes!);
      final ext = file.extension?.toLowerCase() ?? 'png';
      _logoMime = ext == 'jpg' || ext == 'jpeg'
          ? 'image/jpeg'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/png';
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Company name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final providers = _providers.toList();
      final assignments = _employeeIds.map((id) {
        final emp = widget.employees.firstWhere(
          (e) => (e['id'] as num?)?.toInt() == id,
          orElse: () => <String, dynamic>{},
        );
        return <String, dynamic>{
          'employeeId': id,
          'employeeName': emp['name']?.toString(),
          'providers': providers,
        };
      }).toList();
      await widget.service.saveReportClient(
        companyName: name,
        businessCategory: _category.text.trim(),
        logoBase64: _logoBase64,
        logoMimeType: _logoMime,
        assignments: assignments,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: _lineBlue)),
      titleTextStyle: const TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.w900),
      title: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_blue, _sky]), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.business_rounded, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Text(_isEdit ? 'Edit client & assignment' : 'Add client'))]),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                enabled: !_isEdit,
                decoration: InputDecoration(labelText: 'Company name', prefixIcon: const Icon(Icons.business_outlined, color: _blue), filled: true, fillColor: _paleBlue.withValues(alpha: .55), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _lineBlue)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _lineBlue)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _blue, width: 1.5))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _category,
                decoration: InputDecoration(labelText: 'Business category', prefixIcon: const Icon(Icons.category_outlined, color: _blue), filled: true, fillColor: _paleBlue.withValues(alpha: .55), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _lineBlue)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _lineBlue)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _blue, width: 1.5))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_logoBase64 == null ? 'Client logo' : 'Logo selected'),
                  ),
                  const SizedBox(width: 10),
                  if (_logoBase64 != null)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Providers',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kReportProviders.map((p) {
                  final selected = _providers.contains(p.key);
                  return FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: ProviderLogo(provider: p, size: 18),
                    label: Text(p.label),
                    selectedColor: p.color.withValues(alpha: .16),
                    side: BorderSide(
                      color: selected ? p.color : const Color(0xffd3deef),
                      width: selected ? 1.6 : 1,
                    ),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _providers.add(p.key);
                      } else {
                        _providers.remove(p.key);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text('Assign employees',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 4),
              if (widget.employees.isEmpty)
                const Text('No employees available.',
                    style: TextStyle(color: Color(0xff8aa0c6)))
              else
                ...widget.employees.map((e) {
                  final id = (e['id'] as num?)?.toInt() ?? -1;
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _employeeIds.contains(id),
                    title: Text(e['name']?.toString() ?? 'Employee'),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _employeeIds.add(id);
                      } else {
                        _employeeIds.remove(id);
                      }
                    }),
                  );
                }),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEdit ? 'Save' : 'Create client'),
        ),
      ],
    );
  }
}

// ── Revoke / reassign dialog ─────────────────────────────────────────────────
class _RevokeResult {
  const _RevokeResult(this.reassignTo);
  final int? reassignTo;
}

class _RevokeDialog extends StatefulWidget {
  const _RevokeDialog({required this.employeeName, required this.others});
  final String employeeName;
  final List<Map<String, dynamic>> others;

  @override
  State<_RevokeDialog> createState() => _RevokeDialogState();
}

class _RevokeDialogState extends State<_RevokeDialog> {
  int? _reassignTo;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: _lineBlue)),
      titleTextStyle: const TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.w900),
      title: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: _paleBlue, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.person_remove_alt_1_rounded, color: _blue)), const SizedBox(width: 12), Expanded(child: Text('Revoke ${widget.employeeName}'))]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Optionally reassign this client to another employee '
              '(their providers are preserved).'),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _reassignTo,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Reassign to (optional)', prefixIcon: const Icon(Icons.swap_horiz_rounded, color: _blue), filled: true, fillColor: _paleBlue, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _lineBlue)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _lineBlue)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _blue, width: 1.5))),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('Just revoke (no reassign)')),
              ...widget.others.map((e) => DropdownMenuItem<int?>(
                    value: (e['id'] as num?)?.toInt(),
                    child: Text(e['name']?.toString() ?? 'Employee'),
                  )),
            ],
            onChanged: (v) => setState(() => _reassignTo = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _reassignTo == null ? Colors.red : _blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          onPressed: () => Navigator.pop(context, _RevokeResult(_reassignTo)),
          child: Text(_reassignTo == null ? 'Revoke' : 'Reassign'),
        ),
      ],
    );
  }
}
