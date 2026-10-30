import 'package:flutter/material.dart';
import '../../../services/employee_lifecycle_api.dart';

Future<bool> showEmployeeExitDialog(
  BuildContext context,
  int employeeId, {
  required bool inactive,
  required String name,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _ExitDialog(employeeId: employeeId, inactive: inactive, name: name),
      ) ??
      false;
}

class _ExitDialog extends StatefulWidget {
  const _ExitDialog({
    required this.employeeId,
    required this.inactive,
    required this.name,
  });
  final int employeeId;
  final bool inactive;
  final String name;
  @override
  State<_ExitDialog> createState() => _ExitDialogState();
}

class _ExitDialogState extends State<_ExitDialog> {
  final reason = TextEditingController();
  Map<String, dynamic>? preview;
  String? error;
  bool busy = false;
  String get automaticStartDate => DateTime.now()
      .toUtc()
      .add(const Duration(hours: 5, minutes: 30))
      .toIso8601String()
      .substring(0, 10);
  String get automaticDate {
    final today = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    return DateTime.utc(
      today.year,
      today.month,
      today.day - 1,
    ).toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> submit({bool confirm = false}) async {
    if (!widget.inactive && reason.text.trim().isEmpty) {
      setState(() => error = 'Enter an exit reason.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final body = widget.inactive
          ? <String, dynamic>{}
          : {'reason': reason.text.trim()};
      final result = await EmployeeLifecycleApi.request(
        '${widget.employeeId}/${widget.inactive
            ? 'reactivate'
            : confirm
            ? 'exit'
            : 'exit-preview'}',
        method: 'POST',
        body: body,
      );
      if (!mounted) return;
      if (widget.inactive || confirm) {
        Navigator.pop(context, true);
        return;
      }
      setState(() => preview = result);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resolveConflict(Map conflict) async {
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Resolve record outside employment'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The original record will be retained as an exception. It will not add salary after the last working date. Explain the reviewed outcome below.',
              ),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Resolution reason *',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (note.text.trim().isNotEmpty) Navigator.pop(c, true);
            },
            child: const Text('Record resolution'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      try {
        await EmployeeLifecycleApi.request(
          '${widget.employeeId}/exit-exceptions',
          method: 'POST',
          body: {
            'lastWorkingDate': preview?['lastWorkingDate'] ?? automaticDate,
            'source': conflict['source'],
            'sourceId': conflict['id'],
            'resolution': note.text.trim(),
          },
        );
        await submit();
      } catch (e) {
        if (mounted) setState(() => error = '$e');
      }
    }
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = preview?['conflicts'] as List? ?? [];
    final salary = preview?['salary'] as List? ?? [];
    return AlertDialog(
      title: Text(
        '${widget.inactive ? 'Reactivate' : 'Deactivate'} ${widget.name}',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.inactive
                    ? 'The new joining date is automatically today. Previous history and the inactive gap will be retained.'
                    : 'Access stops immediately. The last working date is automatically yesterday. Records are retained.',
              ),
              const SizedBox(height: 16),
              if (!widget.inactive)
                Text(
                  'Last working date: ${preview?["lastWorkingDate"] ?? automaticDate} (yesterday, India time)',
                ),
              if (widget.inactive)
                Text(
                  'New joining date: $automaticStartDate (today, India time)',
                ),
              if (!widget.inactive) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  enabled: !busy,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Exit reason *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => preview = null),
                ),
              ],
              if (preview != null) ...[
                const Divider(),
                const Text(
                  'Final salary preview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (salary.isEmpty)
                  const Text(
                    'Needs review: salary or employment details are missing.',
                  ),
                ...salary.map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${s['periodStart']} – ${s['periodEnd']}\n'
                      'Eligible days: ${s['eligibleWorkingDays'] ?? 'Review required'} / ${s['workingDays']} • '
                      'Salary: ${s['netPayLabel'] ?? 'Needs review'}'
                      '${s['paidAdjustmentRequired'] == true ? '\nAlready paid salary requires an audited adjustment.' : ''}',
                    ),
                  ),
                ),
                if (conflicts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Resolve these records after the last working date before confirming:',
                    style: TextStyle(color: Colors.red),
                  ),
                  ...conflicts.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${_sourceLabel(c['source'])} #${c['id']} • ${c['date']}',
                      ),
                      subtitle: c['resolved'] == true
                          ? Text('Resolved: ${c['resolution']}')
                          : null,
                      trailing: c['resolved'] == true
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : TextButton(
                              onPressed: busy
                                  ? null
                                  : () => resolveConflict(c as Map),
                              child: const Text('Resolve'),
                            ),
                    ),
                  ),
                ],
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy || conflicts.any((c) => c['resolved'] != true)
              ? null
              : () => submit(confirm: preview != null),
          child: Text(
            widget.inactive
                ? 'Confirm reactivation'
                : preview == null
                ? 'Preview exit'
                : 'Confirm exit',
          ),
        ),
      ],
    );
  }
}

String _sourceLabel(dynamic value) => switch (value) {
  'attendance_records' ||
  'hrms_attendance_sessions' => 'Attendance / clock session',
  'employee_leaves' => 'Leave request',
  'task_assignments' => 'Client assignment',
  'task_list' ||
  'time_tracking_task_items' ||
  'task_tracker' ||
  'task_tracking_details' => 'Task',
  'day_plan_rows' => 'Day planner',
  'content_calendar' => 'Content calendar',
  'hrms_field_tracking_sessions' => 'Tracking session',
  _ => 'Record',
};
