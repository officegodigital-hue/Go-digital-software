// lib/screens/admin_dashboard/performance_screen.dart
//
// Employee Performance — v3.
// Data: GET /workspace-tasks/performance/overview and /performance/detail,
// built from the same tracking data as Employee Workspace, Live Tracking and
// the top bar (office days, sessions cut at the day they started, the same
// task visibility as My Tasks).

import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────

class _P {
  static const primary = Color(0xFF0759D4);
  static const primary2 = Color(0xFF1D74E8);
  static const primaryDark = Color(0xFF0B3B91);
  static const sky = Color(0xFFEAF4FF);
  static const completed = Color(0xFF16A34A);
  static const processing = Color(0xFF0369A1);
  static const onHold = Color(0xFFD97706);
  static const pending = Color(0xFF64748B);
  static const rejected = Color(0xFFDC2626);
  static const purple = Color(0xFF7C3AED);
  static const ink = Color(0xFF14213D);
  static const text = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFDCE6F2);
  static const bg = Color(0xFFF4F8FD);

  static Color forScore(num score) {
    if (score >= 85) return completed;
    if (score >= 70) return primary;
    if (score >= 50) return onHold;
    return rejected;
  }

  static Color forGroup(String group) => switch (group) {
        'completed' => completed,
        'processing' => processing,
        'onHold' => onHold,
        'rejected' => rejected,
        _ => pending,
      };
}

// Safe readers for JSON maps.
num _n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
String _s(dynamic v, [String fallback = '']) {
  final t = '${v ?? ''}'.trim();
  return t.isEmpty || t == 'null' ? fallback : t;
}

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
String _pctText(dynamic v) {
  final x = _n(v).toDouble();
  return x == x.roundToDouble() ? '${x.toInt()}%' : '${x.toStringAsFixed(1)}%';
}

String _dmy(String ymd) {
  final d = DateTime.tryParse(ymd);
  return d == null ? ymd : DateFormat('dd MMM yyyy').format(d);
}

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  static String get _api => '${ApiConfig.baseUrl}/workspace-tasks/performance';

  // Period
  String _quick = 'today'; // today | week | month | custom
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();

  // Overview
  bool _loadingOverview = true;
  String? _overviewError;
  Map<String, dynamic> _team = {};
  List<Map<String, dynamic>> _weights = [];
  List<Map<String, dynamic>> _employees = [];
  String _search = '';
  String _sortBy = 'score_desc';

  // Detail
  String? _selected;
  bool _loadingDetail = false;
  String? _detailError;
  Map<String, dynamic>? _detail;
  final Set<String> _openClients = {};
  bool _exporting = false;

  Timer? _autoRefresh;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fetchOverview();
    // Keeps "running now" and today's hours fresh without hammering the server.
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      if (_selected == null) {
        _fetchOverview(silent: true);
      } else {
        _fetchDetail(_selected!, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // DATA
  // ─────────────────────────────────────────────────────────────

  Map<String, String> get _headers {
    final token = Provider.of<AuthService>(context, listen: false).token;
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  Map<String, String> get _rangeParams {
    final f = DateFormat('yyyy-MM-dd');
    if (_quick == 'today') return {'mode': 'daily', 'date': f.format(_from)};
    return {'mode': 'monthly', 'fromDate': f.format(_from), 'toDate': f.format(_to)};
  }

  String get _rangeLabel {
    final f = DateFormat('dd MMM yyyy');
    if (_quick == 'today') return 'Today · ${f.format(_from)}';
    return '${f.format(_from)} – ${f.format(_to)}';
  }

  Future<void> _fetchOverview({bool silent = false}) async {
    final id = ++_requestId;
    if (!silent) {
      setState(() {
        _loadingOverview = true;
        _overviewError = null;
      });
    }
    try {
      final res = await http
          .get(Uri.parse('$_api/overview').replace(queryParameters: _rangeParams), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (!mounted || id != _requestId) return;
      final body = jsonDecode(res.body);
      if (res.statusCode != 200 || body is! Map) {
        throw Exception(body is Map ? body['message'] ?? 'Failed (${res.statusCode})' : 'Failed (${res.statusCode})');
      }
      final data = _m(body['data']);
      setState(() {
        _team = _m(data['team']);
        _weights = _l(data['weights']);
        _employees = _l(data['employees']);
        _loadingOverview = false;
        _overviewError = null;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loadingOverview = false;
        if (!silent) _overviewError = 'Could not load performance. $e';
      });
    }
  }

  Future<void> _fetchDetail(String name, {bool silent = false}) async {
    final id = ++_requestId;
    setState(() {
      _selected = name;
      if (!silent) {
        _loadingDetail = true;
        _detailError = null;
        _detail = null;
        _openClients.clear();
      }
    });
    try {
      final res = await http
          .get(
            Uri.parse('$_api/detail').replace(queryParameters: {'employeeName': name, ..._rangeParams}),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted || id != _requestId) return;
      final body = jsonDecode(res.body);
      if (res.statusCode != 200 || body is! Map) {
        throw Exception(body is Map ? body['message'] ?? 'Failed (${res.statusCode})' : 'Failed (${res.statusCode})');
      }
      final data = _m(body['data']);
      setState(() {
        _detail = data;
        if (_weights.isEmpty) _weights = _l(data['weights']);
        _loadingDetail = false;
        _detailError = null;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loadingDetail = false;
        if (!silent) _detailError = 'Could not load this employee. $e';
      });
    }
  }

  void _refresh() {
    if (_selected == null) {
      _fetchOverview();
    } else {
      _fetchDetail(_selected!);
    }
  }

  void _backToList() {
    setState(() {
      _selected = null;
      _detail = null;
      _detailError = null;
    });
    _fetchOverview(silent: _employees.isNotEmpty);
  }

  void _setQuick(String key) {
    final now = DateTime.now();
    setState(() {
      _quick = key;
      switch (key) {
        case 'today':
          _from = now;
          _to = now;
        case 'week':
          _from = now.subtract(Duration(days: now.weekday - 1));
          _to = now;
        case 'month':
          _from = DateTime(now.year, now.month, 1);
          _to = now;
      }
    });
    _refresh();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to.isBefore(_from) ? _from : _to),
    );
    if (picked == null) return;
    setState(() {
      _quick = 'custom';
      _from = picked.start;
      _to = picked.end;
    });
    _refresh();
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.toLowerCase();
    final list = _employees.where((e) {
      if (q.isEmpty) return true;
      return _s(e['fullName']).toLowerCase().contains(q) || _s(e['role']).toLowerCase().contains(q);
    }).toList();
    int desc(String k, Map a, Map b) => _n(b[k]).compareTo(_n(a[k]));
    // Employees with no activity always go to the bottom.
    int activity(Map a, Map b) {
      final aa = _n(a['totalTasks']) > 0 || _n(a['workingSecs']) > 0 ? 0 : 1;
      final bb = _n(b['totalTasks']) > 0 || _n(b['workingSecs']) > 0 ? 0 : 1;
      return aa - bb;
    }

    list.sort((a, b) {
      final act = activity(a, b);
      if (act != 0) return act;
      return switch (_sortBy) {
        'score_asc' => _n(a['performancePct']).compareTo(_n(b['performancePct'])),
        'hours_desc' => desc('workingSecs', a, b),
        'completed_desc' => desc('completed', a, b),
        'overdue_desc' => desc('overdue', a, b),
        'name' => _s(a['fullName']).compareTo(_s(b['fullName'])),
        _ => desc('performancePct', a, b),
      };
    });
    return list;
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Employee Performance',
      currentRoute: '/performance',
      onSearch: (v) => setState(() => _search = v.trim()),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final mobile = w < 720;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(mobile),
              const SizedBox(height: 14),
              _filterBar(mobile),
              const SizedBox(height: 14),
              if (_selected == null) _overview(w, mobile) else _detailView(w, mobile),
              const SizedBox(height: 28),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO + FILTERS
  // ─────────────────────────────────────────────────────────────

  Widget _hero(bool mobile) {
    final detail = _selected != null;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 16 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_P.primaryDark, _P.primary, _P.primary2],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _P.primary.withValues(alpha: .22), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          if (detail)
            _heroButton(Icons.arrow_back_rounded, 'Back to all employees', _backToList)
          else
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.insights_rounded, color: Colors.white),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail ? _selected! : 'Employee Performance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: mobile ? 18 : 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _rangeLabel,
                  style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (detail) ...[
            _heroButton(
              Icons.picture_as_pdf_rounded,
              'Export PDF report',
              _exporting || _detail == null ? null : _exportPdf,
              busy: _exporting,
            ),
            const SizedBox(width: 8),
          ],
          _heroButton(Icons.refresh_rounded, 'Refresh', _refresh),
        ],
      ),
    );
  }

  Widget _heroButton(IconData icon, String tip, VoidCallback? onTap, {bool busy = false}) {
    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _filterBar(bool mobile) {
    final overview = _selected == null;
    return _panel(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _chip('Today', _quick == 'today', () => _setQuick('today')),
          _chip('This Week', _quick == 'week', () => _setQuick('week')),
          _chip('This Month', _quick == 'month', () => _setQuick('month')),
          _chip(
            _quick == 'custom' ? '${DateFormat('dd/MM').format(_from)} – ${DateFormat('dd/MM').format(_to)}' : 'Custom range',
            _quick == 'custom',
            _pickRange,
            icon: Icons.date_range_rounded,
          ),
          if (overview) ...[
            SizedBox(
              width: mobile ? double.infinity : 230,
              child: TextField(
                onChanged: (v) => setState(() => _search = v.trim()),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search employee or role…',
                  hintStyle: const TextStyle(fontSize: 12, color: _P.muted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _P.primary),
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  filled: true,
                  fillColor: _P.bg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _P.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _P.primary, width: 1.4),
                  ),
                ),
              ),
            ),
            _sortMenu(),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _P.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _P.primary : _P.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? Colors.white : _P.muted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : _P.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortMenu() {
    const options = {
      'score_desc': 'Highest score',
      'score_asc': 'Lowest score',
      'hours_desc': 'Most hours',
      'completed_desc': 'Most completed',
      'overdue_desc': 'Most overdue',
      'name': 'Name A–Z',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _P.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isDense: true,
          icon: const Icon(Icons.sort_rounded, size: 16, color: _P.primary),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink),
          items: [
            for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _sortBy = v ?? _sortBy),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // OVERVIEW
  // ─────────────────────────────────────────────────────────────

  Widget _overview(double w, bool mobile) {
    if (_loadingOverview && _employees.isEmpty) return _loading();
    if (_overviewError != null && _employees.isEmpty) return _errorBox(_overviewError!, _fetchOverview);

    final list = _visible;
    final cols = w >= 1250 ? 3 : w >= 760 ? 2 : 1;
    const gap = 14.0;
    final cardW = (w - gap * (cols - 1)) / cols;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _teamStrip(w),
        const SizedBox(height: 12),
        _scoreRules(),
        const SizedBox(height: 14),
        _sectionTitle(Icons.groups_rounded, 'Employees', '${list.length} shown · tap a card for full details'),
        const SizedBox(height: 10),
        if (list.isEmpty)
          _emptyBox('No employees found', 'Try another name or role.')
        else
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final e in list) SizedBox(width: cardW, child: _employeeCard(e))],
          ),
      ],
    );
  }

  Widget _teamStrip(double w) {
    final items = [
      _Stat('Active employees', '${_n(_team['activeEmployees'])} / ${_n(_team['employees'])}', Icons.groups_rounded, _P.primary),
      _Stat('Working now', '${_n(_team['runningNow'])}', Icons.play_circle_rounded, _P.processing),
      _Stat('Tasks completed', '${_n(_team['completed'])} / ${_n(_team['totalTasks'])}', Icons.task_alt_rounded, _P.completed),
      _Stat('Overdue tasks', '${_n(_team['overdue'])}', Icons.warning_amber_rounded, _P.rejected),
      _Stat('Team working time', _s(_team['workingHours'], '0m'), Icons.timer_rounded, _P.purple),
      _Stat('Average score', '${_n(_team['avgScore'])}%', Icons.speed_rounded, _P.forScore(_n(_team['avgScore']))),
    ];
    return _statGrid(items, w);
  }

  Widget _statGrid(List<_Stat> items, double w) {
    final cols = w >= 1100 ? items.length : w >= 700 ? 3 : 2;
    const gap = 10.0;
    final cw = (w - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final s in items) SizedBox(width: cw, child: _statTile(s))],
    );
  }

  Widget _statTile(_Stat s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: s.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
            child: Icon(s.icon, size: 18, color: s.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: s.color),
                ),
                Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: _P.muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // How the score is worked out — so every number on the page can be checked.
  Widget _scoreRules() {
    final weights = _weights.isEmpty
        ? [
            {'label': 'Task completion', 'weight': 35},
            {'label': 'Productive time', 'weight': 20},
            {'label': 'On-time delivery', 'weight': 20},
            {'label': 'Manager approval', 'weight': 15},
            {'label': 'Day Planner', 'weight': 10},
          ]
        : _weights;
    return _panel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(Icons.info_outline_rounded, color: _P.primary, size: 20),
          title: const Text(
            'How performance is calculated',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _P.ink),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in weights) _badge('${_s(w['label'])} · ${_n(w['weight'])}%', _P.primary),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Tasks in the period = tasks due in it, plus tasks started, held, restarted, completed or reviewed in it.\n'
              '• Productive time = tracked task time. A session counts only up to the end of the day it started '
              '(max 10 h), so a task left running overnight must be held and restarted.\n'
              '• Available time = working days (Mon–Sat, up to today) × 8 h. Idle = available − productive.\n'
              '• On-time = completed on or before the submit date. Approval = approved ÷ reviewed.\n'
              '• Day Planner = working days with a submitted plan. Parts with no data are left out and the rest re-weighted.',
              style: TextStyle(fontSize: 11.5, height: 1.55, color: _P.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _employeeCard(Map<String, dynamic> e) {
    final score = _n(e['performancePct']);
    final active = _n(e['totalTasks']) > 0 || _n(e['workingSecs']) > 0;
    final color = active ? _P.forScore(score) : _P.pending;
    final running = e['running'] == true;
    final overdue = _n(e['overdue']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _fetchDetail(_s(e['fullName'])),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: running ? _P.processing.withValues(alpha: .4) : _P.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(_s(e['initials'], '?'), 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _s(e['fullName']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _P.ink),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _s(e['role'], '—'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: _P.muted, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (running) ...[
                              const SizedBox(width: 6),
                              _badge('● Working now', _P.processing),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _Ring(percent: active ? score.toDouble() : 0, color: color, size: 50, stroke: 5, label: active ? '${score.toInt()}' : '—'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniStat('${_n(e['totalTasks'])}', 'Tasks'),
                  _miniStat('${_n(e['completed'])}', 'Done'),
                  _miniStat(_s(e['workingHours'], '0m'), 'Worked'),
                  _miniStat(_pctText(e['productivityPct']), 'Productive'),
                ],
              ),
              const SizedBox(height: 10),
              _segmentBar([
                (_n(e['completed']).toDouble(), _P.completed),
                (_n(e['processing']).toDouble(), _P.processing),
                (_n(e['onHold']).toDouble(), _P.onHold),
                (_n(e['pending']).toDouble(), _P.pending),
                (_n(e['rejected']).toDouble(), _P.rejected),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _s(e['performanceGrade'], '—'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
                  ),
                  const Spacer(),
                  if (overdue > 0) ...[
                    _badge('$overdue overdue', _P.rejected),
                    const SizedBox(width: 6),
                  ],
                  if (active) _badge('On-time ${_pctText(e['onTimePct'])}', _P.completed),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _P.ink),
          ),
          const SizedBox(height: 1),
          Text(label, style: const TextStyle(fontSize: 9.5, color: _P.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DETAIL
  // ─────────────────────────────────────────────────────────────

  Widget _detailView(double w, bool mobile) {
    if (_loadingDetail && _detail == null) return _loading();
    if (_detailError != null && _detail == null) {
      return _errorBox(_detailError!, () => _fetchDetail(_selected!));
    }
    final d = _detail;
    if (d == null) return const SizedBox.shrink();
    final twoCol = w >= 980;

    Widget pair(Widget a, Widget b) => twoCol
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: a), const SizedBox(width: 14), Expanded(child: b)],
          )
        : Column(children: [a, const SizedBox(height: 14), b]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pair(_profileCard(d, mobile), _scoreBreakdown(d)),
        const SizedBox(height: 14),
        _taskKpis(d, w),
        const SizedBox(height: 14),
        _timeCard(d, w),
        const SizedBox(height: 14),
        _trendCard(d),
        const SizedBox(height: 14),
        pair(_reviewCard(d), _plannerCard(d)),
        const SizedBox(height: 14),
        _clientsCard(d, mobile),
        const SizedBox(height: 14),
        _timelineCard(d),
      ],
    );
  }

  Widget _profileCard(Map<String, dynamic> d, bool mobile) {
    final emp = _m(d['employee']);
    final perf = _m(d['performance']);
    final hours = _m(d['workingHours']);
    final score = _n(perf['score']);
    final active = _n(_m(d['summary'])['totalTasks']) > 0 || _n(hours['totalSecs']) > 0;
    final color = active ? _P.forScore(score) : _P.pending;
    return _card(
      icon: Icons.badge_rounded,
      title: 'Employee',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(_s(emp['initials'], '?'), 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _s(emp['fullName']),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _P.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        _s(emp['role']),
                        if (_s(emp['staffId']).isNotEmpty) 'ID ${_s(emp['staffId'])}',
                      ].where((x) => x.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: _P.muted, fontWeight: FontWeight.w600),
                    ),
                    if (d['running'] == true) ...[
                      const SizedBox(height: 6),
                      _badge('● Working on a task now', _P.processing),
                    ],
                    if (_n(d['staleRunning']) > 0) ...[
                      const SizedBox(height: 6),
                      _badge('${_n(d['staleRunning'])} task left running from an earlier day', _P.rejected),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Ring(percent: active ? score.toDouble() : 0, color: color, size: 78, stroke: 8, label: active ? '${score.toInt()}%' : '—'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Performance score', style: TextStyle(fontSize: 11, color: _P.muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_s(perf['grade'], '—'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                    const SizedBox(height: 4),
                    Text(
                      'Worked ${_s(hours['total'], '0m')} of ${_s(hours['available'], '0m')} available',
                      style: const TextStyle(fontSize: 11.5, color: _P.text, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreBreakdown(Map<String, dynamic> d) {
    final parts = _l(_m(d['performance'])['parts']);
    return _card(
      icon: Icons.stacked_bar_chart_rounded,
      title: 'Score breakdown',
      subtitle: 'Each part × its weight',
      child: Column(
        children: [
          for (final p in parts) ...[
            _partRow(p),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _partRow(Map<String, dynamic> p) {
    final has = p['valuePct'] != null;
    final v = has ? _n(p['valuePct']).toDouble() : 0.0;
    final color = has ? _P.forScore(v) : _P.pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_s(p['label'])}  ·  ${_n(p['weight'])}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ),
            Text(
              has ? '${_pctText(v)}  →  ${_n(p['points'])} pts' : 'No data · not counted',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: has ? color : _P.muted),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _bar(v / 100, color),
      ],
    );
  }

  Widget _taskKpis(Map<String, dynamic> d, double w) {
    final s = _m(d['summary']);
    String pc(String k) => _pctText(s[k]);
    return _statGrid([
      _Stat('Clients', '${_n(s['totalClients'])}', Icons.apartment_rounded, _P.primary),
      _Stat('Tasks in period', '${_n(s['totalTasks'])}', Icons.list_alt_rounded, _P.ink),
      _Stat('Completed · ${pc('completedPct')}', '${_n(s['completed'])}', Icons.check_circle_rounded, _P.completed),
      _Stat('In progress · ${pc('processingPct')}', '${_n(s['processing'])}', Icons.play_circle_rounded, _P.processing),
      _Stat('On hold · ${pc('onHoldPct')}', '${_n(s['onHold'])}', Icons.pause_circle_rounded, _P.onHold),
      _Stat('Not started · ${pc('pendingPct')}', '${_n(s['pending'])}', Icons.hourglass_empty_rounded, _P.pending),
      _Stat('Rework / rejected', '${_n(s['rejected'])}', Icons.replay_rounded, _P.rejected),
      _Stat('Overdue', '${_n(s['overdue'])}', Icons.warning_amber_rounded, _P.rejected),
    ], w);
  }

  Widget _timeCard(Map<String, dynamic> d, double w) {
    final h = _m(d['workingHours']);
    final prod = _n(h['productivityPct']).toDouble();
    final tiles = [
      _Stat('Productive (tracked)', _s(h['total'], '0m'), Icons.bolt_rounded, _P.completed),
      _Stat('Available (${_n(h['workingDays'])} days × ${_n(h['dayHours'])}h)', _s(h['available'], '0m'), Icons.event_available_rounded, _P.primary),
      _Stat('Idle', _s(h['idle'], '0m'), Icons.pause_circle_outline_rounded, _P.onHold),
      _Stat('Avg per active day (${_n(h['activeDays'])})', _s(h['avgDaily'], '0m'), Icons.today_rounded, _P.processing),
      _Stat('Avg per completed task', _s(h['avgTask'], '0m'), Icons.task_alt_rounded, _P.purple),
      _Stat('On-time delivery', _pctText(h['efficiencyPct']), Icons.alarm_on_rounded, _P.completed),
    ];
    return _card(
      icon: Icons.timer_rounded,
      title: 'Working time & productivity',
      subtitle: 'From Start / Hold / Restart / Complete on each task',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) => _statGrid(tiles, c.maxWidth)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Productive time used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
              const Spacer(),
              Text(_pctText(prod), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _P.forScore(prod))),
            ],
          ),
          const SizedBox(height: 6),
          _bar(prod / 100, _P.forScore(prod), height: 10),
        ],
      ),
    );
  }

  Widget _trendCard(Map<String, dynamic> d) {
    final trend = _l(d['trend']);
    final dayHours = _n(_m(d['workingHours'])['dayHours']).toDouble();
    final target = dayHours > 0 ? dayHours : 8.0;
    final hasData = trend.any((t) => _n(t['workedSecs']) > 0);
    return _card(
      icon: Icons.bar_chart_rounded,
      title: 'Hours worked per day',
      subtitle: 'Dashed line = ${target.toStringAsFixed(0)} h working day',
      child: !hasData
          ? const SizedBox(
              height: 140,
              child: Center(child: Text('No tracked time in this period', style: TextStyle(fontSize: 12, color: _P.muted))),
            )
          : SizedBox(
              height: 230,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: [
                    target + 2,
                    ...trend.map((t) => _n(t['workedSecs']) / 3600 + 1),
                  ].reduce((a, b) => a > b ? a : b).ceilToDouble(),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(y: target, color: _P.completed.withValues(alpha: .6), strokeWidth: 1.2, dashArray: [5, 4]),
                  ]),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gi, rod, ri) {
                        final t = trend[group.x.toInt()];
                        return BarTooltipItem(
                          '${_dmy(_s(t['date']))}\n${_s(t['worked'], '0m')} · ${_n(t['completed'])} done',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 2,
                        getTitlesWidget: (v, m) =>
                            Text('${v.toInt()}h', style: const TextStyle(fontSize: 9.5, color: _P.muted)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                          final every = (trend.length / 10).ceil();
                          if (every > 1 && i % every != 0) return const SizedBox.shrink();
                          final date = DateTime.tryParse(_s(trend[i]['date']));
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              date == null ? '' : DateFormat('dd/MM').format(date),
                              style: const TextStyle(fontSize: 9.5, color: _P.muted),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < trend.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: _n(trend[i]['workedSecs']) / 3600,
                          width: trend.length > 20 ? 7 : 14,
                          color: _n(trend[i]['workedSecs']) / 3600 >= target ? _P.completed : _P.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> d) {
    final r = _m(d['managerReview']);
    final rate = _n(r['approvalRatePct']).toDouble();
    return _card(
      icon: Icons.verified_rounded,
      title: 'Manager review',
      subtitle: '${_n(r['reviewed'])} reviewed in this period',
      child: Column(
        children: [
          Row(
            children: [
              _countCol('Approved', r['approved'], _P.completed),
              _countCol('Rework', r['rework'], _P.onHold),
              _countCol('Rejected', r['rejected'], _P.rejected),
              _countCol('Waiting', r['pendingReview'], _P.pending),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Approval rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
              const Spacer(),
              Text(
                _n(r['reviewed']) > 0 ? _pctText(rate) : 'No reviews yet',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _P.completed),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _bar(rate / 100, _P.completed),
        ],
      ),
    );
  }

  Widget _plannerCard(Map<String, dynamic> d) {
    final p = _m(d['dayPlanner']);
    final days = _l(p['days']);
    return _card(
      icon: Icons.event_note_rounded,
      title: 'Day Planner',
      subtitle: '${_n(p['submittedDays'])} of ${_n(p['workingDays'])} working days submitted',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _countCol('Submitted', p['submittedDays'], _P.completed),
              _countCol('Missed', p['missedDays'], _P.rejected),
              _countCol('Morning', p['morningSubmittedCount'], _P.processing),
              _countCol('Evening', p['eveningSubmittedCount'], _P.primary),
            ],
          ),
          const SizedBox(height: 12),
          if (days.isNotEmpty)
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final day in days)
                  Builder(builder: (context) {
                    final m = day['morningSubmitted'] == true;
                    final e = day['eveningSubmitted'] == true;
                    final c = m && e ? _P.completed : (m || e ? _P.onHold : const Color(0xFFE2E8F0));
                    final date = DateTime.tryParse(_s(day['date']));
                    return Tooltip(
                      message: '${date == null ? _s(day['date']) : DateFormat('EEE, dd MMM').format(date)}\n'
                          'Morning: ${m ? 'submitted' : '—'}   Evening: ${e ? 'submitted' : '—'}',
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          date == null ? '' : '${date.day}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: m || e ? Colors.white : _P.muted,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              _legend(_P.completed, 'Both'),
              _legend(_P.onHold, 'One report'),
              _legend(const Color(0xFFE2E8F0), 'Missed'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Consistency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
              const Spacer(),
              Text(_pctText(p['consistencyPct']),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _P.primary)),
            ],
          ),
          const SizedBox(height: 6),
          _bar(_n(p['consistencyPct']) / 100, _P.primary),
        ],
      ),
    );
  }

  Widget _clientsCard(Map<String, dynamic> d, bool mobile) {
    final clients = _l(d['clients']);
    return _card(
      icon: Icons.apartment_rounded,
      title: 'Clients & tasks',
      subtitle: 'Tap a client to see every task, its time, due date and review',
      child: clients.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No tasks in this period', style: TextStyle(fontSize: 12, color: _P.muted))),
            )
          : Column(children: [for (final c in clients) _clientTile(c, mobile)]),
    );
  }

  Widget _clientTile(Map<String, dynamic> c, bool mobile) {
    final name = _s(c['clientName']);
    final open = _openClients.contains(name);
    final tasks = _l(c['tasks']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _P.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => open ? _openClients.remove(name) : _openClients.add(name)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: _P.sky, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.apartment_rounded, size: 18, color: _P.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _P.ink)),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _badge('${_n(c['totalTasks'])} tasks', _P.muted),
                            _badge('${_n(c['completionPct'])}% done', _P.completed),
                            _badge(_s(c['totalDuration'], '0m'), _P.processing),
                            if (_n(c['onHold']) > 0) _badge('${_n(c['onHold'])} on hold', _P.onHold),
                            if (_n(c['rejected']) > 0) _badge('${_n(c['rejected'])} rework', _P.rejected),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: _P.muted),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(children: [for (final t in tasks) _taskRow(t, mobile)]),
            ),
        ],
      ),
    );
  }

  Widget _taskRow(Map<String, dynamic> t, bool mobile) {
    final color = _P.forGroup(_s(t['statusGroup']));
    final timing = _s(t['timing'], '—');
    final timingColor = switch (timing) {
      'On time' => _P.completed,
      'Late' || 'Overdue' => _P.rejected,
      'Due today' => _P.onHold,
      _ => _P.muted,
    };
    final review = _s(t['reviewStatus'], '-');
    final due = _s(t['due']);

    final info = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _badge(_s(t['statusLabel']), color),
        _badge('⏱ ${_s(t['duration'], '0m')}', _P.processing),
        if (due.isNotEmpty) _badge('Due ${DateFormat('dd/MM').format(DateTime.tryParse(due) ?? DateTime.now())}', _P.muted),
        if (timing != '—') _badge(timing, timingColor),
        if (review != '-') _badge('Review: ${review[0]}${review.substring(1).toLowerCase()}', _P.primary2),
        if (t['staleRunning'] == true) _badge('Left running', _P.rejected),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _P.border),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_s(t['deliverable'])} · ${_s(t['rowLabel'])}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink),
                ),
                const SizedBox(height: 6),
                info,
              ],
            )
          : Row(
              children: [
                Container(
                  width: 4,
                  height: 30,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
                SizedBox(
                  width: 250,
                  child: Text(
                    '${_s(t['deliverable'])} · ${_s(t['rowLabel'])}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: info),
              ],
            ),
    );
  }

  Widget _timelineCard(Map<String, dynamic> d) {
    final items = _l(d['timeline']);
    const icons = {
      'TASK_STARTED': (Icons.play_circle_rounded, _P.processing),
      'TASK_HELD': (Icons.pause_circle_rounded, _P.onHold),
      'TASK_RESTARTED': (Icons.replay_circle_filled_rounded, _P.primary),
      'TASK_COMPLETED': (Icons.check_circle_rounded, _P.completed),
      'MANAGER_APPROVED': (Icons.verified_rounded, _P.completed),
      'MANAGER_REWORK': (Icons.assignment_return_rounded, _P.onHold),
      'MANAGER_REJECTED': (Icons.cancel_rounded, _P.rejected),
      'PLANNER_SUBMITTED': (Icons.assignment_turned_in_rounded, _P.purple),
    };
    return _card(
      icon: Icons.history_rounded,
      title: 'Activity timeline',
      subtitle: 'Latest first',
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No activity in this period', style: TextStyle(fontSize: 12, color: _P.muted))),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length && i < 40; i++)
                  Builder(builder: (context) {
                    final e = items[i];
                    final style = icons[_s(e['type'])] ?? (Icons.circle, _P.muted);
                    final at = DateTime.tryParse(_s(e['date']))?.toLocal();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(style.$1, size: 17, color: style.$2),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_s(e['label']), style: const TextStyle(fontSize: 12, color: _P.ink, height: 1.35)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            at == null ? '' : DateFormat('dd/MM  hh:mm a').format(at),
                            style: const TextStyle(fontSize: 10.5, color: _P.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SMALL PIECES
  // ─────────────────────────────────────────────────────────────

  Widget _panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border),
      ),
      child: child,
    );
  }

  Widget _card({required IconData icon, required String title, String? subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .025), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(icon, title, subtitle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title, String? subtitle) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: _P.sky, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: _P.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _P.ink)),
              if (subtitle != null)
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _P.muted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(String initials, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _P.sky,
      child: Text(
        initials,
        style: TextStyle(fontSize: radius * 0.62, fontWeight: FontWeight.w900, color: _P.primary),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _countCol(String label, dynamic value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('${_n(value)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10.5, color: _P.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5, color: _P.muted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _bar(num fraction, Color color, {double height = 8}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.toDouble().clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: const Color(0xFFE8EEF6),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }

  Widget _segmentBar(List<(double, Color)> parts) {
    final total = parts.fold<double>(0, (s, p) => s + p.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: total <= 0
            ? Container(color: const Color(0xFFE8EEF6))
            : Row(
                children: [
                  for (final p in parts)
                    if (p.$1 > 0) Expanded(flex: (p.$1 * 100).round().clamp(1, 1 << 30), child: Container(color: p.$2)),
                ],
              ),
      ),
    );
  }

  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator(color: _P.primary)),
    );
  }

  Widget _errorBox(String message, VoidCallback onRetry) {
    return _panel(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 32, color: _P.muted),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _P.muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _emptyBox(String title, String subtitle) {
    return _panel(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded, size: 32, color: _P.muted),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _P.ink)),
          Text(subtitle, style: const TextStyle(fontSize: 11.5, color: _P.muted)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PDF
  // ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    final d = _detail;
    if (d == null) return;
    setState(() => _exporting = true);
    try {
      final emp = _m(d['employee']);
      final perf = _m(d['performance']);
      final s = _m(d['summary']);
      final h = _m(d['workingHours']);
      final r = _m(d['managerReview']);
      final p = _m(d['dayPlanner']);
      final clients = _l(d['clients']);
      final parts = _l(perf['parts']);

      final font = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      const blue = PdfColor.fromInt(0xFF0759D4);
      const ink = PdfColor.fromInt(0xFF14213D);
      const grey = PdfColor.fromInt(0xFF64748B);
      const line = PdfColor.fromInt(0xFFDCE6F2);
      const soft = PdfColor.fromInt(0xFFF4F8FD);

      pw.TextStyle st(double size, {bool b = false, PdfColor color = ink}) =>
          pw.TextStyle(font: b ? bold : font, fontSize: size, color: color);

      pw.Widget box(String label, String value) => pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.all(2),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: soft,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: line),
              ),
              child: pw.Column(children: [
                pw.Text(value, style: st(12, b: true, color: blue)),
                pw.SizedBox(height: 2),
                pw.Text(label, style: st(7.5, color: grey), textAlign: pw.TextAlign.center),
              ]),
            ),
          );

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: blue, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('GODIGITAL · Employee Performance Report', style: st(10, b: true, color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text(_s(emp['fullName']), style: st(17, b: true, color: PdfColors.white)),
                    pw.Text('${_s(emp['role'])}   ·   $_rangeLabel', style: st(9.5, color: PdfColors.white)),
                  ]),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(children: [
                      pw.Text('${_n(perf['score'])}%', style: st(16, b: true, color: blue)),
                      pw.Text(_s(perf['grade']), style: st(9, b: true)),
                    ]),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text('Score breakdown', style: st(12, b: true)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: st(9, b: true, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: blue),
              cellStyle: st(9),
              headers: ['Part', 'Weight', 'Result', 'Points'],
              data: [
                for (final x in parts)
                  [
                    _s(x['label']),
                    '${_n(x['weight'])}%',
                    x['valuePct'] == null ? 'No data' : _pctText(x['valuePct']),
                    x['points'] == null ? '—' : '${_n(x['points'])}',
                  ],
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text('Tasks', style: st(12, b: true)),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              box('Clients', '${_n(s['totalClients'])}'),
              box('Tasks', '${_n(s['totalTasks'])}'),
              box('Completed', '${_n(s['completed'])}'),
              box('In progress', '${_n(s['processing'])}'),
              box('On hold', '${_n(s['onHold'])}'),
              box('Not started', '${_n(s['pending'])}'),
              box('Overdue', '${_n(s['overdue'])}'),
            ]),
            pw.SizedBox(height: 10),
            pw.Text('Working time', style: st(12, b: true)),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              box('Productive', _s(h['total'], '0m')),
              box('Available', _s(h['available'], '0m')),
              box('Idle', _s(h['idle'], '0m')),
              box('Productive %', _pctText(h['productivityPct'])),
              box('On-time', _pctText(h['efficiencyPct'])),
            ]),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              box('Approved', '${_n(r['approved'])}'),
              box('Rework', '${_n(r['rework'])}'),
              box('Rejected', '${_n(r['rejected'])}'),
              box('Approval rate', _pctText(r['approvalRatePct'])),
              box('Planner days', '${_n(p['submittedDays'])}/${_n(p['workingDays'])}'),
            ]),
            pw.SizedBox(height: 14),
            pw.Text('Clients & tasks', style: st(12, b: true)),
            pw.SizedBox(height: 6),
            if (clients.isEmpty) pw.Text('No tasks in this period.', style: st(9.5, color: grey)),
            for (final c in clients) ...[
              pw.Text(
                '${_s(c['clientName'])}   ·   ${_n(c['totalTasks'])} tasks · ${_n(c['completionPct'])}% done · ${_s(c['totalDuration'])}',
                style: st(10, b: true, color: blue),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headerStyle: st(8.5, b: true),
                headerDecoration: const pw.BoxDecoration(color: soft),
                cellStyle: st(8.5),
                headers: ['Task', 'Status', 'Time', 'Due', 'Timing', 'Review'],
                data: [
                  for (final t in _l(c['tasks']))
                    [
                      '${_s(t['deliverable'])} · ${_s(t['rowLabel'])}',
                      _s(t['statusLabel']),
                      _s(t['duration']),
                      _s(t['due'], '—'),
                      _s(t['timing'], '—'),
                      _s(t['reviewStatus'], '-'),
                    ],
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'Performance_${_s(emp['fullName']).replaceAll(' ', '_')}',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SMALL TYPES
// ─────────────────────────────────────────────────────────────

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
}

class _Ring extends StatelessWidget {
  final double percent;
  final Color color;
  final double size;
  final double stroke;
  final String label;

  const _Ring({
    required this.percent,
    required this.color,
    required this.size,
    required this.stroke,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (percent / 100).clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: stroke,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(label, style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}
