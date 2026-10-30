import 'package:godigital_portal/services/socket_auth.dart';
import 'package:godigital_portal/services/auth_storage.dart';
// lib/screens/employee_dashboard/task_actions.dart
//
// One place for Start / Hold / Complete / Restart, used by the Day Planner,
// the Live Tracking page, the Employee Workspace and the top bar.
// Works for both kinds of item returned by /workspace-tasks/*:
//   kind = 'TASK'              → /tracking-items/:id/<action>
//   kind = 'CONTENT_CALENDAR'  → /tasks/content-calendar/sheet-<action>
// Hold asks for a reason; starting while something else runs asks why the
// running item should be held (AUTO_HOLD_REASON_REQUIRED). Every action makes
// the server broadcast 'task_updated', so all open pages refresh themselves.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../services/api_config.dart';

class TaskActions {
  TaskActions._();

  static List<String> availableFor(Map<String, dynamic> item) {
    final status = '${item['status'] ?? ''}'.toUpperCase();
    return switch (status) {
      'IDLE' => ['start'],
      'IN PROGRESS' => ['hold', 'complete'],
      'ON HOLD' || 'REWORK' || 'REJECTED' => ['restart'],
      _ => const [],
    };
  }

  static Future<String?> _askReason(BuildContext context, String title, String hint) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Reason *',
                hintText: hint,
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setD(() => error = 'Reason is required');
                  return;
                }
                Navigator.pop(c, controller.text.trim());
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  /// "Add this task to today's Day Planner?" — true when the user agrees.
  static Future<bool> confirmDayPlan(BuildContext context, http.Response res) async {
    var title = 'This task';
    var client = '';
    try {
      final task = jsonDecode(res.body)['task'];
      if (task is Map) {
        title = '${task['title'] ?? title}';
        client = '${task['client'] ?? ''}';
      }
    } catch (_) {}
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.event_note_rounded, color: Color(0xFF004AAD)),
        title: const Text('Add to today\'s Day Planner?'),
        content: Text(
          '$title${client.isEmpty ? '' : ' · $client'} is not in today\'s Day Planner.\n'
          'It will be added as its own row and the timer starts.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add & start')),
        ],
      ),
    );
    return ok == true;
  }

  static String _message(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) return '${body['message']}';
    } catch (_) {}
    return fallback;
  }

  /// Runs [action] on [item]. Returns true when the server accepted it.
  static Future<bool> run(
    BuildContext context,
    Map<String, dynamic> item,
    String action, {
    String token = '',
  }) async {
    final isCalendar = item['kind'] == 'CONTENT_CALENDAR';
    final title = '${item['title'] ?? 'task'}';
    final body = <String, dynamic>{};
    if (action == 'hold') {
      final reason = await _askReason(context, 'Hold $title', 'Why are you putting this on hold?');
      if (reason == null) return false;
      body['reason'] = reason;
    }
    if (action == 'complete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Complete $title?'),
          content: Text(isCalendar
              ? 'The category is marked prepared. Assign it from the Content Calendar.'
              : 'It moves to Task Review and is completed once approved.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Complete')),
          ],
        ),
      );
      if (ok != true) return false;
    }

    late final Uri uri;
    final manualCalendarRow = isCalendar && item['source_assignment_id'] == null;
    if (manualCalendarRow) {
      // Handler-written row: single-row endpoints.
      final rowAction = action == 'restart' ? 'start' : action;
      uri = Uri.parse('${ApiConfig.baseUrl}/tasks/content-calendar/$rowAction');
      final ids = item['calendar_ids'];
      body['task_item_id'] = ids is List && ids.isNotEmpty ? ids.first : null;
      if (rowAction == 'start') body['day_planner_confirmed'] = true;
    } else if (isCalendar) {
      final sheetAction = action == 'restart' ? 'start' : action;
      uri = Uri.parse('${ApiConfig.baseUrl}/tasks/content-calendar/sheet-$sheetAction');
      body.addAll({
        'source_assignment_id': item['source_assignment_id'],
        'source_role': item['source_role'],
        'source_task_index': item['source_task_index'],
        if (sheetAction == 'start') 'day_planner_confirmed': true,
      });
    } else {
      final id = item['task_id'] ?? item['trackingItemId'];
      uri = Uri.parse('${ApiConfig.baseUrl}/tracking-items/$id/$action');
    }
    final headers = {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    try {
      var res = await http.post(uri, headers: headers, body: jsonEncode(body));
      if (res.statusCode == 409 && res.body.contains('DAY_PLAN_CONFIRM_REQUIRED')) {
        if (!context.mounted || !await confirmDayPlan(context, res)) return false;
        body['day_planner_confirmed'] = true;
        res = await http.post(uri, headers: headers, body: jsonEncode(body));
      }
      if (res.statusCode == 409 && res.body.contains('AUTO_HOLD_REASON_REQUIRED')) {
        var running = 'Your running task';
        try {
          final list = (jsonDecode(res.body)['running'] as List? ?? []).whereType<Map>();
          if (list.isNotEmpty) running = list.map((r) => '${r['title']}').join(', ');
        } catch (_) {}
        if (!context.mounted) return false;
        final reason = await _askReason(
          context,
          'Put the running task on hold?',
          '$running will be held so this one can start. Why?',
        );
        if (reason == null) return false;
        res = await http.post(uri, headers: headers, body: jsonEncode({...body, 'auto_hold_reason': reason}));
      }
      if (res.statusCode != 200) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_message(res, 'Unable to $action'))),
          );
        }
        return false;
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to $action. Check your connection.')),
        );
      }
      return false;
    }
  }
}

/// START / HOLD / COMPLETE / RESTART buttons for one item.
class TaskActionButtons extends StatefulWidget {
  final Map<String, dynamic> item;
  final String token;
  final VoidCallback? onDone;
  final bool dense;

  /// When set, START / RESTART / REWORK are disabled and this text is shown
  /// as the reason (e.g. "Check in first", "Submit the Day Planner first").
  /// HOLD and COMPLETE always stay available.
  final String? startBlockedReason;

  const TaskActionButtons({
    super.key,
    required this.item,
    this.token = '',
    this.onDone,
    this.dense = false,
    this.startBlockedReason,
  });

  @override
  State<TaskActionButtons> createState() => _TaskActionButtonsState();
}

class _TaskActionButtonsState extends State<TaskActionButtons> {
  bool _busy = false;

  static const _style = {
    'start': ('START', Icons.play_arrow_rounded, Color(0xFF004AAD)),
    'hold': ('HOLD', Icons.pause_rounded, Color(0xFFEA580C)),
    'complete': ('COMPLETE', Icons.check_rounded, Color(0xFF16A34A)),
    'restart': ('RESTART', Icons.replay_rounded, Color(0xFFB45309)),
  };

  Future<void> _go(String action) async {
    setState(() => _busy = true);
    final ok = await TaskActions.run(context, widget.item, action, token: widget.token);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final actions = TaskActions.availableFor(widget.item);
    if (actions.isEmpty) {
      return Text(
        '${widget.item['status'] ?? ''}'.toUpperCase() == 'IN REVIEW' ? 'In review' : '—',
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final a in actions)
          Builder(builder: (context) {
            final locked = widget.startBlockedReason != null &&
                (a == 'start' || a == 'restart');
            final button = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _style[a]!.$3,
                side: BorderSide(
                    color: locked
                        ? const Color(0xFFCBD5E1)
                        : _style[a]!.$3.withValues(alpha: 0.6)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(horizontal: widget.dense ? 6 : 8),
                minimumSize: const Size(0, 30),
              ),
              onPressed: _busy || locked ? null : () => _go(a),
              icon: Icon(locked ? Icons.lock_outline_rounded : _style[a]!.$2, size: 14),
              label: Text(
                  a == 'restart' &&
                          ['REWORK', 'REJECTED'].contains('${widget.item['status']}'.toUpperCase())
                      ? 'REWORK'
                      : _style[a]!.$1,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            );
            return locked
                ? Tooltip(message: widget.startBlockedReason!, child: button)
                : button;
          }),
      ],
    );
  }
}

/// Bottom sheet listing everything the employee can act on for a client
/// (running first). Used from the Day Planner STATUS column.
class TaskActionsSheet extends StatefulWidget {
  final String employeeName;
  final String clientName;
  final String token;
  final String? startBlockedReason;

  const TaskActionsSheet({
    super.key,
    required this.employeeName,
    required this.clientName,
    this.token = '',
    this.startBlockedReason,
  });

  static Future<void> show(
    BuildContext context, {
    required String employeeName,
    required String clientName,
    String token = '',
    String? startBlockedReason,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: TaskActionsSheet(
          employeeName: employeeName,
          clientName: clientName,
          token: token,
          startBlockedReason: startBlockedReason,
        ),
      ),
    );
  }

  @override
  State<TaskActionsSheet> createState() => _TaskActionsSheetState();
}

class _TaskActionsSheetState extends State<TaskActionsSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  io.Socket? _socket;
  Timer? _debounce;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder().setAuthFn(authenticateSocket).setTransports(['websocket']).enableForceNew().disableAutoConnect().build(),
    )..connect();
    _socket!.on('task_updated', (_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _load(silent: true);
      });
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      var changed = false;
      for (final i in _items) {
        if (i['running'] == true) {
          i['duration_secs'] = (int.tryParse('${i['duration_secs'] ?? 0}') ?? 0) + 1;
          changed = true;
        }
      }
      if (changed) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ticker?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/actionable').replace(
        queryParameters: {'employee': widget.employeeName, 'client': widget.clientName},
      ));
      if (res.statusCode != 200) throw Exception('Request failed (${res.statusCode})');
      final items = (jsonDecode(res.body)['data'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = '$e';
      });
    }
  }

  String _fmt(dynamic v) {
    final s = int.tryParse('${v ?? 0}') ?? 0;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.clientName} · tasks',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Start, hold or complete work here — My Tasks, Live Tracking and the Day Planner update together.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          if (widget.startBlockedReason != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.startBlockedReason!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
              ),
            ]),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Could not load tasks: $_error'))
                    : _items.isEmpty
                        ? const Center(
                            child: Text('Nothing to work on for this client right now.',
                                style: TextStyle(color: Color(0xFF64748B))))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              final running = item['running'] == true;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: running ? const Color(0xFFEFF6FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: running ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item['kind'] == 'CONTENT_CALENDAR'
                                          ? Icons.calendar_month_rounded
                                          : Icons.task_alt_rounded,
                                      size: 20,
                                      color: const Color(0xFF004AAD),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${item['title'] ?? ''}',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                          Text(
                                            '${item['status']} · ${_fmt(item['duration_secs'])}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TaskActionButtons(
                                      item: item,
                                      token: widget.token,
                                      startBlockedReason: widget.startBlockedReason,
                                      onDone: () => _load(silent: true),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
