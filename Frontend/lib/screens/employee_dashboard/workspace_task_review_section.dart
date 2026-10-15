// lib/screens/employee_dashboard/workspace_task_review_section.dart
//
// Employee Workspace → Client → "Task Review".
// Every row the employee completed for this client + submit date, with the
// reviewer's decision:
//   PENDING  – completed, waiting for the manager
//   REWORK   – manager asked for changes → restart it from My Tasks
//   APPROVED – final; shown as COMPLETED in My Tasks and locked
//   REJECTED – rejected by the manager
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../services/api_config.dart';

const _kPrimary = Color(0xFF004AAD);
const _kInk = Color(0xFF0F172A);
const _kBody = Color(0xFF334155);
const _kMuted = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

String _str(dynamic v) {
  final s = v?.toString() ?? '';
  return s == 'null' ? '' : s;
}

int _asInt(dynamic v) => v is int
    ? v
    : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtDuration(int sec) =>
    '${_two(sec ~/ 3600)}:${_two((sec % 3600) ~/ 60)}:${_two(sec % 60)}';

String _fmtDateTime(dynamic v) {
  final parsed = DateTime.tryParse(_str(v));
  if (parsed == null) return '—';
  final d = parsed.toLocal();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(d.day)}/${_two(d.month)}/${d.year} '
      '${_two(hour)}:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

class WorkspaceTaskReviewSection extends StatefulWidget {
  final String clientName;
  final String submissionDate;
  final String employeeName;
  final String authToken;

  const WorkspaceTaskReviewSection({
    super.key,
    required this.clientName,
    required this.submissionDate,
    required this.employeeName,
    required this.authToken,
  });

  @override
  State<WorkspaceTaskReviewSection> createState() =>
      _WorkspaceTaskReviewSectionState();
}

class _WorkspaceTaskReviewSectionState extends State<WorkspaceTaskReviewSection> {
  static const _filters = ['ALL', 'PENDING', 'REWORK', 'APPROVED', 'REJECTED'];

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _team = [];
  bool _isReviewer = false;
  bool _showTeam = false;
  final Set<int> _deciding = {};
  String _filter = 'ALL';
  io.Socket? _socket;
  Timer? _refreshDebounce;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (widget.authToken.isNotEmpty)
          'Authorization': 'Bearer ${widget.authToken}',
      };

  @override
  void initState() {
    super.initState();
    _load();
    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    )..connect();
    _socket!.on('task_updated', (_) {
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _load(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/review').replace(
        queryParameters: {
          'employee': widget.employeeName,
          'client': widget.clientName,
          'date': widget.submissionDate.length >= 10
              ? widget.submissionDate.substring(0, 10)
              : widget.submissionDate,
        },
      );
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) {
        throw Exception('Unable to load task review (${res.statusCode})');
      }
      final decoded = jsonDecode(res.body);
      List<Map<String, dynamic>> list(dynamic v) => (v as List? ?? [])
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      final rows = list(decoded['data']);
      final team = list(decoded['team']);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _team = team;
        _isReviewer = decoded['is_reviewer'] == true;
        if (!_isReviewer) _showTeam = false;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _source => _showTeam ? _team : _rows;

  int _count(String state) => state == 'ALL'
      ? _source.length
      : _source.where((r) => r['review_state'] == state).length;

  Future<void> _decide(Map<String, dynamic> row, String action) async {
    final id = _asInt(row['id']);
    if (_deciding.contains(id)) return;
    String comment = '';
    if (action == 'PENDING') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Move back to pending?'),
          content: const Text('The previous decision is cleared and the task waits for review again.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Set pending')),
          ],
        ),
      );
      if (ok != true) return;
    } else if (action != 'APPROVED') {
      final text = await _askComment(action, row);
      if (text == null) return;
      comment = text;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Approve this task?'),
          content: Text(
            '${_str(row['deliverable'])} · Row ${_str(row['display_no'])} by '
            '${_str(row['employee_name'])} will be marked Completed and locked.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Approve')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _deciding.add(id));
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/workspace-tasks/review/$id/decision'),
        headers: _headers,
        body: jsonEncode({
          'employee': widget.employeeName,
          'action': action,
          'comment': comment,
        }),
      );
      if (!mounted) return;
      String msg = 'Saved';
      try {
        msg = '${jsonDecode(res.body)['message'] ?? msg}';
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _load(silent: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the review. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deciding.remove(id));
    }
  }

  Future<String?> _askComment(String action, Map<String, dynamic> row) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(action == 'REWORK' ? 'Request rework' : 'Reject task'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Comment *',
                hintText: action == 'REWORK'
                    ? 'What should ${_str(row['employee_name'])} change?'
                    : 'Why is this rejected?',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = controller.text.trim();
                if (v.isEmpty) {
                  setD(() => error = 'Comment is required');
                  return;
                }
                Navigator.pop(c, v);
              },
              child: Text(action == 'REWORK' ? 'Send rework' : 'Reject'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final visible = _filter == 'ALL'
        ? _source
        : _source.where((r) => r['review_state'] == _filter).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        children: [
          const Text(
            'Task review',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk),
          ),
          const SizedBox(height: 4),
          const Text(
            'Completed rows wait here for approval. Approved rows become '
            'Completed in My Tasks; rework rows can be restarted from My Tasks.',
            style: TextStyle(fontSize: 12, color: _kMuted),
          ),
          if (_isReviewer) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: Text('My work (${_rows.length})'),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.groups_outlined, size: 16),
                  label: Text(
                    'Team review (${_team.where((r) => r['review_state'] == 'PENDING').length} pending)',
                  ),
                ),
              ],
              selected: {_showTeam},
              onSelectionChanged: (v) => setState(() {
                _showTeam = v.first;
                _filter = 'ALL';
              }),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _filters)
                ChoiceChip(
                  label: Text('${_label(f)} (${_count(f)})'),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: const Color(0xFFDBEAFE),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _filter == f ? _kPrimary : _kBody,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                _showTeam
                    ? 'No team work is waiting for review for this client and date.'
                    : 'Nothing here yet. Rows you complete in My Tasks appear here.',
                style: const TextStyle(color: _kMuted),
              ),
            )
          else
            for (final row in visible) _reviewTile(row),
        ],
      ),
    );
  }

  Widget _decisionButton(
    Map<String, dynamic> row,
    String action,
    String label,
    IconData icon,
    Color color,
  ) {
    final busy = _deciding.contains(_asInt(row['id']));
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: busy ? null : () => _decide(row, action),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  String _label(String state) => switch (state) {
        'ALL' => 'All',
        'PENDING' => 'Pending review',
        'REWORK' => 'Rework',
        'APPROVED' => 'Approved',
        'REJECTED' => 'Rejected',
        _ => state,
      };

  Widget _reviewTile(Map<String, dynamic> row) {
    final reviewState = _str(row['review_state']);
    final reworkRunning = reviewState == 'REWORK' && _str(row['state']) != 'REWORK';
    final (label, bg, fg, icon) = switch (reviewState) {
      'APPROVED' => ('Approved · Completed', const Color(0xFFDCFCE7),
          const Color(0xFF15803D), Icons.verified_rounded),
      'REWORK' => (reworkRunning ? 'Rework in progress' : 'Rework requested',
          const Color(0xFFFFEDD5), const Color(0xFFC2410C), Icons.replay_rounded),
      'REJECTED' => ('Rejected', const Color(0xFFFEE2E2),
          const Color(0xFFB91C1C), Icons.block_rounded),
      _ => ('Pending review', const Color(0xFFEDE9FE),
          const Color(0xFF6D28D9), Icons.hourglass_top_rounded),
    };
    final headline = _str(row['hook_headline']);
    final description = _str(row['description_points']);
    final comment = _str(row['manager_comment']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: fg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_str(row['deliverable'])} · Row ${_str(row['display_no'])}'
                  '${_showTeam && _str(row['employee_name']).isNotEmpty ? ' · ${_str(row['employee_name'])}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _kInk),
                ),
                if (headline.isNotEmpty || description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [headline, description].where((s) => s.isNotEmpty).join(' — '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _kBody),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Duration ${_fmtDuration(_asInt(row['current_secs']))}'
                  ' · Performance ${_str(row['performance']).isEmpty ? 'N/A' : _str(row['performance'])}'
                  ' · Completed ${_fmtDateTime(row['complete_time'])}',
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                ),
                if (_showTeam &&
                    row['can_review'] == true &&
                    reviewState != 'APPROVED' &&
                    (_str(row['status']) == 'COMPLETED' ||
                        _str(row['status']) == 'REWORK')) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _decisionButton(row, 'APPROVED', 'Approve', Icons.check_circle_outline,
                          const Color(0xFF15803D)),
                      if (reviewState != 'PENDING')
                        _decisionButton(row, 'PENDING', 'Pending', Icons.hourglass_top_rounded,
                            const Color(0xFF6D28D9)),
                      if (reviewState != 'REWORK')
                        _decisionButton(row, 'REWORK', 'Rework', Icons.replay_rounded,
                            const Color(0xFFC2410C)),
                      if (reviewState != 'REJECTED')
                        _decisionButton(row, 'REJECTED', 'Reject', Icons.block_rounded,
                            const Color(0xFFB91C1C)),
                    ],
                  ),
                ],
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text(
                      'Reviewer: $comment',
                      style: const TextStyle(fontSize: 12, color: _kBody),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(
              label,
              style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
