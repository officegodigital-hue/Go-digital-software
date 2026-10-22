// lib/screens/employee_dashboard/dashboard_work_tables.dart
//
// Dashboard work tables (left / right):
//   Designer, Video Editor, Videographer, Developer …  → Pending · This Week · Rework
//   Page Handler / Ads Handler → Pending · This Week · Task Review pending ·
//                                Content Calendar pending (· Rework when any)
//
// Data: GET /workspace-tasks/dashboard?employee=
// START / HOLD / COMPLETE / RESTART use TaskActions — the same calls as the
// Employee Workspace, so a start here adds the task to today's Day Planner,
// holds the running one, and every open page (Workspace, Day Planner, Live
// Tracking, top bar) refreshes through the 'task_updated' socket event.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../services/api_config.dart';
import 'task_actions.dart';

const _kBlue = Color(0xFF0757D5);
const _kNavy = Color(0xFF04296B);
const _kInk = Color(0xFF14213D);
const _kBody = Color(0xFF334155);
const _kMuted = Color(0xFF64748B);
const _kLine = Color(0xFFE5ECF6);
const _kHead = Color(0xFFF6F9FE);
const _kGreen = Color(0xFF16A34A);
const _kOrange = Color(0xFFEA580C);
const _kRed = Color(0xFFDC2626);
const _kPurple = Color(0xFF7C3AED);
const _kAmber = Color(0xFFB45309);

class DashboardWorkTables extends StatefulWidget {
  final String employeeName;
  final String token;

  /// Page / Ads Handler → also Task Review + Content Calendar tables.
  final bool isHandler;

  /// Opens the task in Employee Workspace: {client, due_date, section}.
  final ValueChanged<Map<String, dynamic>>? onOpenWorkspace;

  const DashboardWorkTables({
    super.key,
    required this.employeeName,
    this.token = '',
    this.isHandler = false,
    this.onOpenWorkspace,
    this.filter = 'Today',
    this.onCards,
  });

  /// Hero filter: Today | This Week | This Month (New Clients card period).
  final String filter;

  /// Hold Task + New Clients card data from the same request:
  /// {hold_count, hold_list, new_clients_count, new_clients}.
  final ValueChanged<Map<String, dynamic>>? onCards;

  @override
  State<DashboardWorkTables> createState() => _DashboardWorkTablesState();
}

class _DashboardWorkTablesState extends State<DashboardWorkTables> {
  Map<String, List<Map<String, dynamic>>> _data = {};
  bool _loading = true;
  String? _error;
  String _weekFrom = '';
  String _weekTo = '';
  int _weekOpen = 0;
  io.Socket? _socket;
  Timer? _debounce;
  Timer? _ticker;

  // Task Review + Content Calendar tables: Page / Ads Handler role only.
  bool get _handler => widget.isHandler;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (widget.token.isNotEmpty) 'Authorization': 'Bearer ${widget.token}',
      };

  @override
  void initState() {
    super.initState();
    _load();
    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder().setTransports(['websocket']).enableForceNew().disableAutoConnect().build(),
    )..connect();
    void refresh(dynamic _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _load(silent: true);
      });
    }
    _socket!
      ..on('task_updated', refresh)
      ..on('taskAssigned', refresh)
      ..on('calendar:assigned', refresh);
    // Live timer on running rows.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      var changed = false;
      for (final list in _data.values) {
        for (final i in list) {
          if (i['running'] == true) {
            i['duration_secs'] = (int.tryParse('${i['duration_secs'] ?? 0}') ?? 0) + 1;
            changed = true;
          }
        }
      }
      if (changed) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant DashboardWorkTables oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeName != widget.employeeName || oldWidget.filter != widget.filter) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ticker?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (widget.employeeName.trim().isEmpty) return;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/dashboard')
            .replace(queryParameters: {
              'employee': widget.employeeName.trim(),
              if (widget.isHandler) 'handler': '1',
              'filter': widget.filter,
            }),
        headers: _headers,
      );
      if (res.statusCode != 200) throw Exception('Request failed (${res.statusCode})');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = body['data'] as Map? ?? {};
      List<Map<String, dynamic>> list(String k) => (raw[k] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (!mounted) return;
      if (body['cards'] is Map) {
        widget.onCards?.call(Map<String, dynamic>.from(body['cards'] as Map));
      }
      setState(() {
        _data = {
          for (final k in ['pending', 'week', 'rework', 'shared', 'review_pending', 'calendar_pending'])
            k: list(k),
        };
        _weekOpen = int.tryParse('${raw['week_open'] ?? ''}') ??
            (_data['week'] ?? const []).where((w) => w['done'] != true).length;
        _weekFrom = '${body['week_from'] ?? ''}';
        _weekTo = '${body['week_to'] ?? ''}';
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = 'Could not load your tasks. ${e is Exception ? '' : e}';
      });
    }
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  Future<void> _run(Map<String, dynamic> item, String action) async {
    final ok = await TaskActions.run(context, item, action, token: widget.token);
    if (ok) await _load(silent: true);
  }

  Future<void> _decide(Map<String, dynamic> item, String action) async {
    final id = item['review_id'];
    String comment = '';
    if (action != 'APPROVED') {
      final controller = TextEditingController();
      String? err;
      final text = await showDialog<String>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setD) => AlertDialog(
            title: Text('${action == 'REWORK' ? 'Rework' : 'Reject'} · ${item['title'] ?? ''}'),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Comment for ${item['employee_name'] ?? 'the employee'} *',
                  errorText: err,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) {
                    setD(() => err = 'Comment is required');
                    return;
                  }
                  Navigator.pop(c, controller.text.trim());
                },
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      );
      controller.dispose();
      if (text == null) return;
      comment = text;
    }
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/review/$id/decision'),
        headers: _headers,
        body: jsonEncode({'employee': widget.employeeName, 'action': action, 'comment': comment}),
      );
      var msg = res.statusCode == 200 ? 'Saved' : 'Unable to save the review';
      try {
        msg = '${jsonDecode(res.body)['message'] ?? msg}';
      } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load(silent: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the review. Check your connection.')),
        );
      }
    }
  }

  void _openWorkspace(Map<String, dynamic> item) {
    widget.onOpenWorkspace?.call({
      'client': item['client'],
      'due_date': item['due_date'] ?? item['submit_date'],
      'section': item['section'] ?? 'My Tasks',
    });
  }

  // ─── Formatting ───────────────────────────────────────────────────────────
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _date(dynamic v, {bool year = false}) {
    final s = '${v ?? ''}'.trim();
    final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
    if (d == null) return '--';
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';
  }

  static String _clock(dynamic v) {
    final s = int.tryParse('${v ?? 0}') ?? 0;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  static (String, Color) _statusLook(Map<String, dynamic> i) {
    final st = '${i['status'] ?? 'IDLE'}'.toUpperCase();
    if (i['kind'] == 'CONTENT_CALENDAR' && st == 'COMPLETED') return ('READY TO SHARE', _kGreen);
    return switch (st) {
      'IN PROGRESS' => ('RUNNING', _kBlue),
      'ON HOLD' => ('ON HOLD', _kOrange),
      'IN REVIEW' => ('IN REVIEW', _kPurple),
      'REWORK' => ('REWORK', _kAmber),
      'REJECTED' => ('REJECTED', _kRed),
      'APPROVED' || 'COMPLETED' => (st, _kGreen),
      _ => ('PENDING', _kMuted),
    };
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading && _data.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: _cardBox(),
        child: const CircularProgressIndicator(strokeWidth: 2.5, color: _kBlue),
      );
    }
    if (_error != null && _data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardBox(),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: _kRed),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!, style: const TextStyle(color: _kMuted, fontSize: 12.5))),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final week = _weekFrom.isEmpty
        ? 'Submit date this week · done at bottom'
        : 'Submit ${_date(_weekFrom)} – ${_date(_weekTo)} · done at bottom';
    final tables = <Widget>[
      _QueueTable(
        title: 'Pending Tasks',
        subtitle: 'Not completed yet · running first',
        icon: Icons.pending_actions_rounded,
        color: _kBlue,
        items: _data['pending'] ?? const [],
        emptyText: 'No pending tasks 🎉',
        state: this,
      ),
      _QueueTable(
        title: 'This Week',
        subtitle: week,
        icon: Icons.date_range_rounded,
        color: _kNavy,
        items: _data['week'] ?? const [],
        count: _weekOpen,
        emptyText: 'No tasks with a submit date this week',
        state: this,
      ),
      if (_handler) ...[
        _QueueTable(
          title: 'Task Review Pending',
          subtitle: 'Team work waiting for your decision',
          icon: Icons.fact_check_rounded,
          color: _kPurple,
          items: _data['review_pending'] ?? const [],
          emptyText: 'No reviews waiting',
          review: true,
          state: this,
        ),
        _QueueTable(
          title: 'Content Calendar Pending',
          subtitle: 'Categories to prepare / share',
          icon: Icons.event_note_rounded,
          color: _kGreen,
          items: _data['calendar_pending'] ?? const [],
          emptyText: 'All content calendars are shared',
          state: this,
        ),
      ],
      if (!_handler || (_data['rework'] ?? const []).isNotEmpty)
        _QueueTable(
          title: 'Rework Tasks',
          subtitle: 'Sent back by review — restart and fix',
          icon: Icons.replay_circle_filled_rounded,
          color: _kAmber,
          items: _data['rework'] ?? const [],
          emptyText: 'No rework 👍',
          state: this,
        ),
      // Designer / Video Editor / others: what the Page / Ads Handler shared.
      if (!_handler || (_data['shared'] ?? const []).isNotEmpty)
        _QueueTable(
          title: 'Content Calendar Shared',
          subtitle: 'Shared with you by Page / Ads Handler',
          icon: Icons.mark_email_read_rounded,
          color: const Color(0xFF0891B2),
          items: _data['shared'] ?? const [],
          emptyText: 'Nothing shared with you yet',
          shared: true,
          state: this,
        ),
    ];

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 980) {
        return Column(
          children: [
            for (final t in tables) Padding(padding: const EdgeInsets.only(bottom: 14), child: t),
          ],
        );
      }
      final rows = <Widget>[];
      for (var i = 0; i < tables.length; i += 2) {
        rows.add(Padding(
          padding: EdgeInsets.only(bottom: i + 2 < tables.length ? 16 : 0),
          child: i + 1 < tables.length
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tables[i]),
                    const SizedBox(width: 16),
                    Expanded(child: tables[i + 1]),
                  ],
                )
              : tables[i],
        ));
      }
      return Column(children: rows);
    });
  }

  // ─── Row details popup ────────────────────────────────────────────────────
  Future<void> _showDetails(Map<String, dynamic> item) async {
    final isReview = item['kind'] == 'REVIEW';
    final isCalendar = item['kind'] == 'CONTENT_CALENDAR';
    final (statusText, statusColor) = _statusLook(item);
    Widget info(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Text(label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
              ),
              Expanded(
                child: Text(value.trim().isEmpty ? '—' : value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? _kInk)),
              ),
            ],
          ),
        );

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_kNavy, _kBlue]),
                ),
                child: Row(children: [
                  Icon(
                    isReview
                        ? Icons.fact_check_rounded
                        : isCalendar
                            ? Icons.event_note_rounded
                            : Icons.task_alt_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['client'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                        Text('${item['title'] ?? item['deliverable'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFDCE8FF), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _pathSteps(item),
                      const SizedBox(height: 12),
                      info('Client', '${item['client'] ?? ''}'),
                      info('Deliverable', '${item['deliverable'] ?? ''}'),
                      info(isCalendar ? 'Rows' : 'Row no.', '${item['display_no'] ?? ''}'),
                      info('Submit date', _date(item['submit_date'], year: true),
                          color: item['overdue'] == true ? _kRed : null),
                      if ('${item['due_date'] ?? ''}'.isNotEmpty &&
                          '${item['due_date']}' != '${item['submit_date']}')
                        info('Client card', _date(item['due_date'], year: true)),
                      info('Status',
                          item['running'] == true ? '$statusText · ${_clock(item['duration_secs'])}' : statusText,
                          color: statusColor),
                      if (!isReview) info('Time spent', _clock(item['duration_secs'])),
                      if (isReview) info('Employee', '${item['employee_name'] ?? ''}'),
                      if ('${item['heading'] ?? ''}'.trim().isNotEmpty) info('Headline', '${item['heading']}'),
                      if ('${item['description'] ?? ''}'.trim().isNotEmpty)
                        info('Description', '${item['description']}'),
                      if ('${item['hold_reason'] ?? ''}'.trim().isNotEmpty)
                        info('Hold reason', '${item['hold_reason']}', color: _kOrange),
                      if ('${item['comment'] ?? ''}'.trim().isNotEmpty)
                        info('Review comment', '${item['comment']}', color: _kAmber),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (isReview)
                      Wrap(spacing: 6, children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: _kGreen),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _decide(item, 'APPROVED');
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Approve'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: _kAmber),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _decide(item, 'REWORK');
                          },
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Rework'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: _kRed),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _decide(item, 'REJECTED');
                          },
                          icon: const Icon(Icons.block_rounded, size: 16),
                          label: const Text('Reject'),
                        ),
                      ])
                    else
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        // No Complete here — finish the task in Employee Workspace.
                        for (final a in TaskActions.availableFor(item).where((a) => a != 'complete'))
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: a == 'start'
                                  ? _kBlue
                                  : a == 'hold'
                                      ? _kOrange
                                      : _kAmber,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _run(item, a);
                            },
                            icon: Icon(
                              a == 'start'
                                  ? Icons.play_arrow_rounded
                                  : a == 'hold'
                                      ? Icons.pause_rounded
                                      : Icons.replay_rounded,
                              size: 16,
                            ),
                            label: Text(
                              a == 'start'
                                  ? 'Start'
                                  : a == 'hold'
                                      ? 'Hold'
                                      : (['REWORK', 'REJECTED'].contains('${item['status']}'.toUpperCase())
                                          ? 'Rework'
                                          : 'Restart'),
                            ),
                          ),
                      ]),
                    if (widget.onOpenWorkspace != null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openWorkspace(item);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open in Employee Workspace'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Employee Workspace › CLIENT · 28 Oct › My Tasks › POSTER · Row 3"
Widget _pathSteps(Map<String, dynamic> item) {
  final card = '${item['due_date'] ?? item['submit_date'] ?? ''}';
  final steps = <String>[
    'Employee Workspace',
    '${item['client'] ?? ''}${card.isEmpty ? '' : ' · ${_DashboardWorkTablesState._date(card)}'}',
    '${item['section'] ?? 'My Tasks'}',
    item['kind'] == 'CONTENT_CALENDAR'
        ? '${item['deliverable'] ?? ''}'
        : '${item['deliverable'] ?? ''} · Row ${item['display_no'] ?? ''}',
  ];
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF5FF),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFBFDBFE)),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: i == steps.length - 1 ? _kBlue : Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${i + 1}. ${steps[i]}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: i == steps.length - 1 ? Colors.white : _kBlue,
              ),
            ),
          ),
          if (i < steps.length - 1) const Icon(Icons.chevron_right_rounded, size: 16, color: _kBlue),
        ],
      ],
    ),
  );
}

BoxDecoration _cardBox() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kLine),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0B5ED7).withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );

/// One table: header bar + column titles + scrolling rows (fixed height so the
/// left and right tables line up).
class _QueueTable extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final String emptyText;
  final bool review;
  final bool shared;
  /// Badge number (e.g. This Week shows only work still to finish).
  final int? count;
  final _DashboardWorkTablesState state;

  const _QueueTable({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyText,
    required this.state,
    this.review = false,
    this.shared = false,
    this.count,
  });

  static const double _bodyHeight = 292;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardBox(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.10), Colors.white]),
              border: const Border(bottom: BorderSide(color: _kLine)),
            ),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _kInk)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _kMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${count ?? items.length}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
              ),
            ]),
          ),
          // Column titles
          Container(
            color: _kHead,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(children: [
              _h('S.NO', width: 34),
              _h('CLIENT', flex: 22),
              _h('DELIVERABLE', flex: 24),
              _h(review ? 'EMPLOYEE' : 'SUBMIT', flex: 13),
              _h(shared ? 'SHARED BY' : 'STATUS', flex: 15),
              _h('ACTION', width: 92, right: true),
            ]),
          ),
          SizedBox(
            height: _bodyHeight,
            child: items.isEmpty
                ? Center(
                    child: Text(emptyText,
                        style: const TextStyle(color: _kMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemBuilder: (context, i) => _row(context, i, items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _h(String t, {int? flex, double? width, bool right = false}) {
    final text = Text(t,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _kMuted, letterSpacing: 0.5));
    return width != null ? SizedBox(width: width, child: text) : Expanded(flex: flex ?? 1, child: text);
  }

  Widget _row(BuildContext context, int index, Map<String, dynamic> item) {
    final (statusText, statusColor) = _DashboardWorkTablesState._statusLook(item);
    final running = item['running'] == true;
    final overdue = item['overdue'] == true;
    final done = item['done'] == true;
    final row = Material(
      color: done
          ? const Color(0xFFF6FBF7)
          : running
              ? const Color(0xFFF0F6FF)
              : (index.isOdd ? const Color(0xFFFBFCFE) : Colors.white),
      child: InkWell(
        onTap: () => shared ? state._openWorkspace(item) : state._showDetails(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEFF3F8)))),
          child: Row(children: [
            SizedBox(
              width: 34,
              child: Text('${index + 1}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _kMuted)),
            ),
            Expanded(
              flex: 22,
              child: Text('${item['client'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _kInk)),
            ),
            Expanded(
              flex: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item['deliverable'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kBody)),
                  Text(
                    item['kind'] == 'CONTENT_CALENDAR'
                        ? 'Content Calendar · ${item['display_no'] ?? ''}'
                        : item['kind'] == 'REVIEW'
                            ? 'Review · Row ${item['display_no'] ?? ''}'
                            : item['kind'] == 'SHARED'
                                ? '${item['display_no'] ?? ''}'
                                : 'Row ${item['display_no'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: _kMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 13,
              child: review
                  ? Text('${item['employee_name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kBody))
                  : Row(children: [
                      if (overdue)
                        const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Icon(Icons.warning_amber_rounded, size: 12, color: _kRed),
                        ),
                      Flexible(
                        child: Text(
                          _DashboardWorkTablesState._date(item['submit_date']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: overdue ? _kRed : _kBody,
                          ),
                        ),
                      ),
                    ]),
            ),
            Expanded(
              flex: 15,
              child: shared
                  ? Text(
                      '${item['shared_by'] ?? ''}'.isEmpty ? '—' : '${item['shared_by']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0E7490)),
                    )
                  : Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    running ? _DashboardWorkTablesState._clock(item['duration_secs']) : statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: statusColor),
                  ),
                ),
              ),
            ),
            SizedBox(width: 92, child: Align(alignment: Alignment.centerRight, child: _actions(context, item))),
          ]),
        ),
      ),
    );
    // Finished work sits at the bottom, faded.
    return done ? Opacity(opacity: 0.6, child: row) : row;
  }

  Widget _iconAction(String tip, IconData icon, Color color, VoidCallback onTap) => Tooltip(
        message: tip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );

  Widget _actions(BuildContext context, Map<String, dynamic> item) {
    if (shared) {
      return _iconAction('Open in Employee Workspace', Icons.open_in_new_rounded, const Color(0xFF0891B2),
          () => state._openWorkspace(item));
    }
    if (item['done'] == true) {
      return const Icon(Icons.check_circle_rounded, size: 20, color: _kGreen);
    }
    if (review || item['kind'] == 'REVIEW') {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _iconAction('Approve', Icons.check_rounded, _kGreen, () => state._decide(item, 'APPROVED')),
        _iconAction('Rework', Icons.replay_rounded, _kAmber, () => state._decide(item, 'REWORK')),
        _iconAction('Details', Icons.visibility_outlined, _kBlue, () => state._showDetails(item)),
      ]);
    }
    // Dashboard: Start / Hold / Restart only — Complete is done in Employee Workspace.
    final available = TaskActions.availableFor(item).where((a) => a != 'complete');
    final st = '${item['status'] ?? ''}'.toUpperCase();
    final buttons = <Widget>[
      for (final a in available)
        switch (a) {
          'start' => _iconAction('Start · adds to Day Planner', Icons.play_arrow_rounded, _kBlue,
              () => state._run(item, 'start')),
          'hold' => _iconAction('Hold', Icons.pause_rounded, _kOrange, () => state._run(item, 'hold')),
          'complete' =>
            _iconAction('Complete', Icons.check_rounded, _kGreen, () => state._run(item, 'complete')),
          _ => _iconAction(st == 'REWORK' || st == 'REJECTED' ? 'Rework (restart)' : 'Restart',
              Icons.replay_rounded, _kAmber, () => state._run(item, 'restart')),
        },
    ];
    if (item['kind'] == 'CONTENT_CALENDAR' && st == 'COMPLETED') {
      buttons.add(_iconAction('Share from Content Calendar', Icons.send_rounded, _kGreen,
          () => state._openWorkspace(item)));
    }
    if (buttons.isEmpty) {
      buttons.add(_iconAction('Details', Icons.visibility_outlined, _kBlue, () => state._showDetails(item)));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }
}
