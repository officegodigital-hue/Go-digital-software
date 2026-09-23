import 'package:flutter/material.dart';

import '../../../../services/hrms_clock_logs_api.dart';

class AttendancePolicyDialog extends StatefulWidget {
  const AttendancePolicyDialog({super.key});

  @override
  State<AttendancePolicyDialog> createState() => _AttendancePolicyDialogState();
}

class _AttendancePolicyDialogState extends State<AttendancePolicyDialog> {
  final _work = TextEditingController();
  final _fixed = TextEditingController();
  final _minimum = TextEditingController();
  final _maximum = TextEditingController();
  final _grace = TextEditingController();
  final _reason = TextEditingController();
  Map<String, dynamic> _policy = <String, dynamic>{};
  bool _loading = true;
  bool _saving = false;
  bool _outsideRadiusAllowed = true;
  String _mode = 'actual_break';
  String _checkInTime = '09:00:00';
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final controller in <TextEditingController>[_work, _fixed, _minimum, _maximum, _grace]) {
      controller.addListener(_refreshPreview);
    }
    _load();
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _work.dispose();
    _fixed.dispose();
    _minimum.dispose();
    _maximum.dispose();
    _grace.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait(<Future<Map<String, dynamic>>>[
        HrmsClockLogsApi.attendancePolicies(),
        HrmsClockLogsApi.attendanceTimeSettings(),
      ]);
      final data = results[0];
      final timeSettings = results[1];
      _checkInTime = '${timeSettings['shiftStart'] ?? timeSettings['shift_start'] ?? _checkInTime}';
      final policies = (data['policies'] as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _policy = policies.firstWhere(
        (item) => item['scope_type'] == 'global' && item['is_active'].toString() != '0',
        orElse: () => <String, dynamic>{},
      );
      _work.text = '${_policy['required_work_minutes'] ?? 480}';
      _fixed.text = '${_policy['fixed_break_minutes'] ?? 60}';
      _minimum.text = '${_policy['min_break_minutes'] ?? 0}';
      _maximum.text = '${_policy['max_break_minutes'] ?? 60}';
      _grace.text = '${_policy['auto_checkout_grace_minutes'] ?? 5}';
      _mode = '${_policy['break_calculation_mode'] ?? 'actual_break'}';
      _outsideRadiusAllowed = _policy['allow_outside_radius_during_break'] != 0;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  int _asMinutes(TextEditingController controller, int fallback) =>
      int.tryParse(controller.text.trim()) ?? fallback;

  String _displayTime(int minutes) {
    final hour = (minutes ~/ 60) % 24;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '${((hour + 11) % 12) + 1}:${(minutes % 60).toString().padLeft(2, '0')} $suffix';
  }

  int get _checkInMinutes {
    final values = _checkInTime.split(':');
    final hour = int.tryParse(values.isEmpty ? '' : values.first) ?? 9;
    final minute = int.tryParse(values.length > 1 ? values[1] : '') ?? 0;
    return (hour * 60) + minute;
  }

  String get _checkInLabel => _displayTime(_checkInMinutes);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await HrmsClockLogsApi.saveAttendancePolicy(<String, dynamic>{
        ..._policy,
        'scope_type': 'global',
        'required_work_minutes': _asMinutes(_work, 480),
        'break_calculation_mode': _mode,
        'fixed_break_minutes': _asMinutes(_fixed, 60),
        'min_break_minutes': _asMinutes(_minimum, 0),
        'max_break_minutes': _asMinutes(_maximum, 60),
        'allow_outside_radius_during_break': _outsideRadiusAllowed,
        'auto_checkout_grace_minutes': _asMinutes(_grace, 5),
        'effective_from': DateTime.now().toIso8601String().substring(0, 10),
        'reason': _reason.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, String help, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF081C67))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            helperText: help,
            suffixText: 'minutes',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _step(String label, String value, IconData icon) {
    return Column(
      children: <Widget>[
        CircleAvatar(backgroundColor: const Color(0xFFDDEBFF), child: Icon(icon, color: const Color(0xFF1264F5))),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF52638E))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1264F5))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final workMinutes = _asMinutes(_work, 480);
    final breakMinutes = _mode == 'fixed_schedule' ? _asMinutes(_fixed, 60) : 30;
    final checkoutTime = _displayTime(_checkInMinutes + workMinutes + breakMinutes);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const SizedBox(height: 260, child: Center(child: CircularProgressIndicator()))
              : SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[
                      const Icon(Icons.schedule_rounded, color: Color(0xFF1264F5)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Attendance Policy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF081C67)))),
                      IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ]),
                    const Text('Configure working hours, breaks and automatic checkout.', style: TextStyle(color: Color(0xFF52638E))),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    const SizedBox(height: 20),
                    LayoutBuilder(builder: (context, constraints) {
                      final leftWidth = constraints.maxWidth > 700 ? 420.0 : constraints.maxWidth;
                      return Wrap(spacing: 22, runSpacing: 16, children: <Widget>[
                        SizedBox(width: leftWidth, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          _field('Required work hours', '480 minutes = 8 hours', _work),
                          const SizedBox(height: 14),
                          const Text('Break calculation', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF081C67))),
                          DropdownButtonFormField<String>(
                            value: _mode,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(value: 'actual_break', child: Text('Actual break duration')),
                              DropdownMenuItem(value: 'fixed_schedule', child: Text('Fixed schedule duration')),
                            ],
                            onChanged: (value) => setState(() => _mode = value ?? 'actual_break'),
                            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                          if (_mode == 'fixed_schedule') ...<Widget>[const SizedBox(height: 14), _field('Fixed lunch break', 'Used for every checkout calculation', _fixed)],
                          const SizedBox(height: 14),
                          Row(children: <Widget>[
                            Expanded(child: _field('Minimum break', 'Optional', _minimum)),
                            const SizedBox(width: 12),
                            Expanded(child: _field('Maximum break', 'Allowed', _maximum)),
                          ]),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Allow outside radius during break'),
                            subtitle: const Text('Geofence auto-checkout is paused during an active break.'),
                            value: _outsideRadiusAllowed,
                            onChanged: (value) => setState(() => _outsideRadiusAllowed = value),
                          ),
                          _field('Auto-checkout grace period', 'Wait outside the radius before automatic checkout', _grace),
                        ])),
                        SizedBox(width: constraints.maxWidth > 700 ? 390 : constraints.maxWidth, child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFFF2F7FF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD8E6FF))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            const Text("Today's calculation", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF081C67))),
                            const SizedBox(height: 8),
                            Text('Check in $_checkInLabel', style: const TextStyle(color: Color(0xFF52638E))),
                            const SizedBox(height: 18),
                            Row(children: <Widget>[
                              _step('Check in', _checkInLabel, Icons.login_rounded),
                              const Expanded(child: Divider()),
                              _step('Lunch', '$breakMinutes min', Icons.restaurant_rounded),
                              const Expanded(child: Divider()),
                              _step('Eligible checkout', checkoutTime, Icons.logout_rounded),
                            ]),
                            const SizedBox(height: 18),
                            Text('$_checkInLabel + $workMinutes work minutes + $breakMinutes break minutes', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF081C67))),
                          ]),
                        )),
                      ]);
                    }),
                    const SizedBox(height: 16),
                    TextField(controller: _reason, maxLength: 500, decoration: InputDecoration(labelText: 'Change reason (audit history)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save Policy'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1264F5), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                    )),
                  ],
                  ),
                ),
        ),
      ),
    );
  }
}
