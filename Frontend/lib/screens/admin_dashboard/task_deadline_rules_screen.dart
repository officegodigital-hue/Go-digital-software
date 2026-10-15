// lib/screens/admin_dashboard/task_deadline_rules_screen.dart
//
// Admin → Task Deadline Rules.
// For each role + task the admin sets:
//   • Start within N days of assignment        (e.g. Google Ads → 4 days)
//   • Complete within N days of assignment     (e.g. Content Calendar → 3 days)
//   • Weekly pace: X per week, or spread over N weeks (8 posters / 4 → 2 a week)
// Tasks that break a rule are listed for the admin (Admin Workspace →
// Pending list) and highlighted for the employee in My Tasks.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:godigital_portal/layouts/admin_layout.dart';
import 'package:godigital_portal/services/api_config.dart';

const _kBlue = Color(0xFF0052CC);
const _kDeep = Color(0xFF003B95);
const _kInk = Color(0xFF0F172A);
const _kMuted = Color(0xFF64748B);
const _kLine = Color(0xFFE2E8F0);

class TaskDeadlineRulesScreen extends StatefulWidget {
  const TaskDeadlineRulesScreen({super.key});

  @override
  State<TaskDeadlineRulesScreen> createState() => _TaskDeadlineRulesScreenState();
}

class _TaskDeadlineRulesScreenState extends State<TaskDeadlineRulesScreen> {
  static String get _base => ApiConfig.baseUrl;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _roles = [];
  List<String> _taskNames = [];
  String _roleFilter = 'ALL';

  // form
  int? _editingId;
  String? _role;
  String _taskChoice = '*'; // '*', a task name, or '__other__'
  final _otherTask = TextEditingController();
  final _qty = TextEditingController();
  final _startDays = TextEditingController();
  final _completeDays = TextEditingController();
  final _perWeek = TextEditingController();
  final _weeks = TextEditingController();
  final _notes = TextEditingController();
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTaskNames();
    for (final c in [_otherTask, _qty, _startDays, _completeDays, _perWeek, _weeks]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_otherTask, _qty, _startDays, _completeDays, _perWeek, _weeks, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse('$_base/task-rules'));
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) throw Exception(body['message'] ?? 'Server ${res.statusCode}');
      setState(() {
        _rules = List<Map<String, dynamic>>.from(
            (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        _roles = List<Map<String, dynamic>>.from(
            (body['roles'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadTaskNames() async {
    try {
      final res = await http.get(Uri.parse('$_base/task-master'));
      if (res.statusCode != 200) return;
      final data = (jsonDecode(res.body)['data'] as List? ?? []);
      final names = data
          .map((t) => '${(t as Map)['task_name'] ?? ''}'.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      // Ads platforms are usually typed as plain names.
      for (final extra in ['Meta Ads', 'Google Ads', 'Landing Page', 'Poster']) {
        if (!names.any((n) => n.toLowerCase() == extra.toLowerCase())) names.add(extra);
      }
      if (mounted) setState(() => _taskNames = names);
    } catch (_) {}
  }

  String _roleLabel(String? key) =>
      _roles.firstWhere((r) => r['key'] == key, orElse: () => {'label': key ?? ''})['label']
          .toString();

  int? _int(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    return v == null || v < 0 ? null : v;
  }

  String get _taskName {
    if (_taskChoice == '__other__') {
      final t = _otherTask.text.trim();
      return t.isEmpty ? '*' : t;
    }
    return _taskChoice;
  }

  void _clear() {
    setState(() {
      _editingId = null;
      _role = null;
      _taskChoice = '*';
      _active = true;
      for (final c in [_otherTask, _qty, _startDays, _completeDays, _perWeek, _weeks, _notes]) {
        c.clear();
      }
    });
  }

  void _edit(Map<String, dynamic> r) {
    String s(dynamic v) => v == null ? '' : '$v';
    final task = '${r['task_name'] ?? '*'}';
    setState(() {
      _editingId = r['id'] as int?;
      _role = '${r['role_key']}';
      if (task == '*' || _taskNames.contains(task)) {
        _taskChoice = task;
        _otherTask.clear();
      } else {
        _taskChoice = '__other__';
        _otherTask.text = task;
      }
      _qty.text = s(r['qty']);
      _startDays.text = s(r['start_within_days']);
      _completeDays.text = s(r['complete_within_days']);
      _perWeek.text = s(r['per_week']);
      _weeks.text = s(r['weeks']);
      _notes.text = s(r['notes']);
      _active = r['is_active'] == null || r['is_active'] == 1 || r['is_active'] == true;
    });
  }

  Future<void> _save() async {
    if (_role == null) return _snack('Choose a role');
    final payload = {
      'role_key': _role,
      'task_name': _taskName,
      'qty': _int(_qty),
      'start_within_days': _int(_startDays),
      'complete_within_days': _int(_completeDays),
      'per_week': _int(_perWeek),
      'weeks': _int(_weeks),
      'notes': _notes.text.trim(),
      'is_active': _active,
    };
    setState(() => _saving = true);
    try {
      final res = _editingId == null
          ? await http.post(Uri.parse('$_base/task-rules'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
          : await http.put(Uri.parse('$_base/task-rules/$_editingId'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      final body = jsonDecode(res.body);
      if (res.statusCode >= 300) throw Exception(body['message'] ?? 'Failed');
      _snack(_editingId == null ? 'Rule created' : 'Rule updated', ok: true);
      _clear();
      await _load();
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('${_roleLabel('${r['role_key']}')} · ${r['task_name']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await http.delete(Uri.parse('$_base/task-rules/${r['id']}'));
    if (res.statusCode == 200) {
      if (_editingId == r['id']) _clear();
      _snack('Rule deleted', ok: true);
      _load();
    } else {
      _snack('Could not delete the rule');
    }
  }

  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF16A34A) : Colors.redAccent,
    ));
  }

  /// Plain-language summary of a rule ("Google Ads must start within 4 days…").
  static String describe(Map<String, dynamic> r) {
    final task = '${r['task_name'] ?? '*'}' == '*' ? 'Every task' : '${r['task_name']}';
    final qty = r['qty'] == null ? '' : ' (qty ${r['qty']})';
    final parts = <String>[];
    if (r['start_within_days'] != null) parts.add('start within ${r['start_within_days']} day(s)');
    if (r['complete_within_days'] != null) parts.add('complete within ${r['complete_within_days']} day(s)');
    if (r['per_week'] != null) {
      parts.add('${r['per_week']} per week');
    } else if (r['weeks'] != null) {
      parts.add('spread over ${r['weeks']} week(s) (total ÷ ${r['weeks']} per week)');
    }
    return '$task$qty: ${parts.isEmpty ? 'no limit' : parts.join(', ')} after assignment';
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Task Deadline Rules',
      currentRoute: '/task-deadline-rules',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hero(mobile),
              const SizedBox(height: 18),
              if (mobile) ...[
                _formPanel(),
                const SizedBox(height: 16),
                _rulesPanel(),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _rulesPanel()),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _formPanel()),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(bool mobile) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(mobile ? 18 : 26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kDeep, _kBlue, Color(0xFF1267E8)]),
          borderRadius: BorderRadius.circular(mobile ? 20 : 24),
          boxShadow: [BoxShadow(color: _kBlue.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Task Deadline Rules',
                      style: TextStyle(
                          color: Colors.white, fontSize: mobile ? 20 : 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    'When each task must start, finish, or how many per week — counted from the day it is assigned.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (!mobile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_rules.length} rules',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
          ],
        ),
      );

  Widget _panel({required String title, required IconData icon, Widget? action, required Widget child}) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kLine),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_kDeep, _kBlue]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  if (action != null) action,
                ],
              ),
            ),
            child,
          ],
        ),
      );

  Widget _rulesPanel() {
    final roleKeys = {'ALL', ..._rules.map((r) => '${r['role_key']}')};
    final visible = _rules.where((r) => _roleFilter == 'ALL' || r['role_key'] == _roleFilter).toList();
    return _panel(
      title: 'Rules',
      icon: Icons.rule_rounded,
      action: IconButton(
        tooltip: 'Refresh',
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 19),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in roleKeys)
                  ChoiceChip(
                    label: Text(k == 'ALL' ? 'All roles' : _roleLabel(k), style: const TextStyle(fontSize: 11.5)),
                    selected: _roleFilter == k,
                    onSelected: (_) => setState(() => _roleFilter = k),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(_error!, style: const TextStyle(color: _kMuted)),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ]),
              )
            else if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No rules yet. Create one with the form.', style: TextStyle(color: _kMuted))),
              )
            else
              for (final r in visible) _ruleTile(r),
          ],
        ),
      ),
    );
  }

  Widget _ruleTile(Map<String, dynamic> r) {
    final editing = _editingId == r['id'];
    final active = r['is_active'] == null || r['is_active'] == 1 || r['is_active'] == true;
    Widget chip(String text, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)),
          child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: editing ? const Color(0xFFF0F5FF) : (active ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: editing ? const Color(0xFF9DBCF5) : _kLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(_roleLabel('${r['role_key']}'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _kInk)),
                  chip('${r['task_name']}' == '*' ? 'Any task' : '${r['task_name']}', _kBlue),
                  if (r['qty'] != null) chip('Qty ${r['qty']}', const Color(0xFF7C3AED)),
                  if (!active) chip('Inactive', _kMuted),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (r['start_within_days'] != null)
                    chip('Start ≤ ${r['start_within_days']} d', const Color(0xFF0891B2)),
                  if (r['complete_within_days'] != null)
                    chip('Complete ≤ ${r['complete_within_days']} d', const Color(0xFF16A34A)),
                  if (r['per_week'] != null) chip('${r['per_week']} / week', const Color(0xFFD97706)),
                  if (r['per_week'] == null && r['weeks'] != null)
                    chip('Total ÷ ${r['weeks']} weeks', const Color(0xFFD97706)),
                ]),
                if ('${r['notes'] ?? ''}'.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${r['notes']}', style: const TextStyle(fontSize: 11.5, color: _kMuted)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _edit(r),
            icon: const Icon(Icons.edit_outlined, size: 18, color: _kBlue),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _delete(r),
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, {String? hint, String? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue, width: 1.4),
        ),
      );

  Widget _num(TextEditingController c, String label, {String? hint, String? suffix}) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: _deco(label, hint: hint, suffix: suffix),
      );

  Widget _formPanel() {
    final editing = _editingId != null;
    final preview = describe({
      'task_name': _taskName,
      'qty': _int(_qty),
      'start_within_days': _int(_startDays),
      'complete_within_days': _int(_completeDays),
      'per_week': _int(_perWeek),
      'weeks': _int(_weeks),
    });
    final perWeekExample = _int(_weeks) != null && _int(_perWeek) == null
        ? 'e.g. 8 → ${(8 / _int(_weeks)!).ceil()} a week, 12 → ${(12 / _int(_weeks)!).ceil()} a week'
        : null;
    return _panel(
      title: editing ? 'Edit rule' : 'New rule',
      icon: editing ? Icons.edit_note_rounded : Icons.add_alarm_rounded,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _roles.any((r) => r['key'] == _role) ? _role : null,
              isExpanded: true,
              decoration: _deco('Role *'),
              items: [
                for (final r in _roles)
                  DropdownMenuItem(value: '${r['key']}', child: Text('${r['label']}')),
              ],
              onChanged: (v) => setState(() => _role = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _taskChoice == '*' || _taskChoice == '__other__' || _taskNames.contains(_taskChoice)
                  ? _taskChoice
                  : '__other__',
              isExpanded: true,
              decoration: _deco('Task'),
              items: [
                const DropdownMenuItem(value: '*', child: Text('Any task of this role')),
                for (final n in _taskNames) DropdownMenuItem(value: n, child: Text(n)),
                const DropdownMenuItem(value: '__other__', child: Text('Other…')),
              ],
              onChanged: (v) => setState(() => _taskChoice = v ?? '*'),
            ),
            if (_taskChoice == '__other__') ...[
              const SizedBox(height: 12),
              TextField(controller: _otherTask, decoration: _deco('Task name *', hint: 'e.g. Google Ads')),
            ],
            const SizedBox(height: 12),
            _num(_qty, 'Only for quantity (optional)', hint: 'e.g. 12'),
            const SizedBox(height: 16),
            const Text('DEADLINES (from the day it is assigned)',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: _kMuted, letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _num(_startDays, 'Start within', suffix: 'days')),
              const SizedBox(width: 10),
              Expanded(child: _num(_completeDays, 'Complete within', suffix: 'days')),
            ]),
            const SizedBox(height: 16),
            const Text('WEEKLY PACE',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: _kMuted, letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _num(_perWeek, 'Fixed per week', hint: 'e.g. 3')),
              const SizedBox(width: 10),
              Expanded(child: _num(_weeks, 'or spread over', suffix: 'weeks', hint: '4')),
            ]),
            if (perWeekExample != null) ...[
              const SizedBox(height: 6),
              Text(perWeekExample, style: const TextStyle(fontSize: 11, color: _kMuted)),
            ],
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 2, decoration: _deco('Notes (optional)')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF5FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _kBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${_role == null ? 'Role' : _roleLabel(_role)} · $preview',
                      style: const TextStyle(fontSize: 12, color: _kInk, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _clear,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: _kBlue, minimumSize: const Size.fromHeight(44)),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(editing ? 'Update rule' : 'Create rule'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
