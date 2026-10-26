import 'package:flutter/material.dart';

import '../../../services/hrms_clock_logs_api.dart';

const _blue = Color(0xFF1264F5);
const _navy = Color(0xFF081C67);
const _line = Color(0xFFD8E1F0);

class EmployeeClockCalendarDrawer extends StatefulWidget {
  const EmployeeClockCalendarDrawer({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.staffId,
    required this.initialMonth,
    required this.onSaved,
  });

  final int employeeId;
  final String employeeName;
  final String staffId;
  final DateTime initialMonth;
  final Future<void> Function() onSaved;

  @override
  State<EmployeeClockCalendarDrawer> createState() =>
      _EmployeeClockCalendarDrawerState();
}

class _EmployeeClockCalendarDrawerState
    extends State<EmployeeClockCalendarDrawer> {
  late DateTime _month;
  final _reason = TextEditingController();
  List<Map<String, dynamic>> _days = const [];
  String? _selectedDate;
  String _selectedStatus = 'present';
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await HrmsClockLogsApi.calendar(
        employeeId: widget.employeeId,
        month: _month,
      );
      if (!mounted) return;
      setState(() {
        _days = (data['days'] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selectedDate = null;
      _reason.clear();
      _notice = null;
    });
    _load();
  }

  Map<String, dynamic>? get _selectedDay {
    for (final day in _days) {
      if (day['date'] == _selectedDate) return day;
    }
    return null;
  }

  void _select(Map<String, dynamic> day) {
    setState(() {
      _selectedDate = day['date']?.toString();
      _selectedStatus = day['status']?.toString().toLowerCase() == 'present'
          ? 'absent'
          : 'present';
      _reason.clear();
      _error = null;
      _notice = null;
    });
  }

  Future<void> _save() async {
    final day = _selectedDay;
    if (day == null || day['editable'] != true) return;
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Enter an Admin reason.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await HrmsClockLogsApi.correctStatus(
        employeeId: widget.employeeId,
        date: day['date'].toString(),
        status: _selectedStatus,
        reason: _reason.text.trim(),
      );
      await _load();
      await widget.onSaved();
      if (!mounted) return;
      setState(() {
        _reason.clear();
        _notice =
            result['payrollWarning']?.toString() ??
            'Attendance saved. Unpaid payroll recalculated.';
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value == 'present') return const Color(0xFF159447);
    if (value == 'absent') return const Color(0xFFD92845);
    if (value == 'late' || value == 'early exit') {
      return const Color(0xFFE87900);
    }
    if (value == 'leave' || value == 'holiday' || value == 'on leave') {
      return const Color(0xFF7C3AED);
    }
    return const Color(0xFF667085);
  }

  Widget _calendar() {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final cells = <Map<String, dynamic>?>[
      ...List<Map<String, dynamic>?>.filled(firstWeekday, null),
      ..._days,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _monthLabel(_month),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final label in [
              'Sun',
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
            ])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Color(0xFF52638E)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: .90,
          ),
          itemBuilder: (context, index) {
            final day = cells[index];
            if (day == null) return const SizedBox.shrink();
            final status = day['status']?.toString() ?? 'No record';
            final selected = day['date'] == _selectedDate;
            final color = _statusColor(status);
            return InkWell(
              onTap: () => _select(day),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEAF1FF) : Colors.white,
                  border: Border.all(
                    color: selected ? _blue : _line,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day['day']}',
                      style: TextStyle(
                        color: selected ? _blue : _navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (status != 'Future') ...[
                      const SizedBox(height: 3),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 58),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _correctionForm() {
    final day = _selectedDay;
    if (day == null) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'Select a date to see its attendance and make a correction.',
        ),
      );
    }
    final editable = day['editable'] == true;
    final date = day['date']?.toString() ?? '';
    final status = day['status']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Correct attendance — $date',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: _navy,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Current: $status   •   Check in: ${day['checkIn']}   •   Check out: ${day['checkOut']}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF52638E)),
        ),
        if ((day['adminReason']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Previous Admin reason: ${day['adminReason']}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF52638E)),
          ),
        ],
        const SizedBox(height: 14),
        if (!editable)
          const Text(
            'This date cannot be corrected here (future date, leave, holiday, or weekly off).',
            style: TextStyle(color: Color(0xFF667085)),
          )
        else ...[
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Present'),
                selected: _selectedStatus == 'present',
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _selectedStatus = 'present'),
              ),
              ChoiceChip(
                label: const Text('Absent'),
                selected: _selectedStatus == 'absent',
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _selectedStatus = 'absent'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            maxLines: 3,
            maxLength: 1000,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Admin reason (required)',
              hintText: 'This reason appears in the employee day popup',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_notice != null)
            Text(
              _notice!,
              style: TextStyle(
                color: _notice!.contains('failed')
                    ? Colors.red
                    : const Color(0xFF159447),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save correction'),
            ),
          ),
        ],
      ],
    );
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.employeeName} — ${_monthLabel(_month)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Employee ID: ${widget.staffId}',
                        style: const TextStyle(
                          color: Color(0xFF52638E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(),
                    )
                  else if (_error != null && _days.isEmpty)
                    Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else ...[
                    _calendar(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: _line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _correctionForm(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
