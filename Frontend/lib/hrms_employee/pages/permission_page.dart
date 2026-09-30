import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/api_config.dart';
import '../../services/auth_service.dart';
import '../shared/employee_ui.dart';

class EmployeePermissionPage extends StatefulWidget {
  const EmployeePermissionPage({super.key});

  @override
  State<EmployeePermissionPage> createState() => _EmployeePermissionPageState();
}

class _EmployeePermissionPageState extends State<EmployeePermissionPage> {
  List<dynamic> _history = [];
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchHistory());
  }

  Future<void> _fetchHistory() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _historyLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/attendance/permissions/mine'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true && mounted) {
        setState(() => _history = List<dynamic>.from(body['data'] as List? ?? []));
      }
    } catch (_) {}
    if (mounted) setState(() => _historyLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final logOnly = ModalRoute.of(context)?.settings.arguments == 'log';
    return EmployeeScaffold(
      route: '/employee/permission',
      title: 'Permission',
      subtitle: logOnly
          ? 'Review your permission history'
          : 'Request short personal permission and review your history',
      desktopHeaderAction: logOnly ? null : GestureDetector(
        onTap: () => _showPermissionHistoryDialog(context, _history, _historyLoading),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD0E1FF)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 13, color: Color(0xFF0B72F5)),
              SizedBox(width: 6),
              Text('View History', style: TextStyle(fontSize: 12, color: Color(0xFF0B72F5), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      desktop: _PermissionContent(logOnly: logOnly, history: _history, historyLoading: _historyLoading),
      mobile: _PermissionContent(mobile: true, logOnly: logOnly, history: _history, historyLoading: _historyLoading),
    );
  }
}

void _showPermissionHistoryDialog(BuildContext context, List<dynamic> history, bool loading) {
  String _fmtDate(String? v) {
    final dt = DateTime.tryParse(v ?? '');
    return dt == null ? (v ?? '--') : DateFormat('dd/MM/yyyy').format(dt);
  }

  String _fmtTime(String? start, String? end) {
    String fmt(String? v) {
      if (v == null || v.isEmpty) return '';
      final parts = v.split(':');
      if (parts.length < 2) return v;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return v;
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, h, m);
      return DateFormat('hh:mm a').format(dt);
    }
    final from = fmt(start);
    final to = fmt(end);
    return from.isEmpty || to.isEmpty ? 'Time not recorded' : '$from – $to';
  }

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.history_rounded, color: employeePurple, size: 20),
                const SizedBox(width: 8),
                const Expanded(child: Text('Permission History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 18),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFF4F6FB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ]),
              const SizedBox(height: 4),
              const Text('Past and pending permission requests', style: TextStyle(fontSize: 12, color: employeeMuted)),
              const SizedBox(height: 16),
              if (loading)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No permission requests recorded.', style: TextStyle(color: employeeMuted))),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = history[i];
                      final status = r['status']?.toString() ?? 'Pending';
                      final normalizedStatus = status.toUpperCase();
                      final color = normalizedStatus == 'APPROVED'
                          ? employeeGreen
                          : (normalizedStatus == 'REJECTED' ? const Color(0xFFF12B46) : employeeOrange);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          const Icon(Icons.shield_outlined, color: employeePurple, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_fmtDate(r['date']?.toString()), style: const TextStyle(color: employeeNavy, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('${r['reason'] ?? ''} · ${_fmtTime(r['start_time']?.toString(), r['end_time']?.toString())}',
                              style: const TextStyle(color: employeeMuted, fontSize: 11)),
                          ])),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(5)),
                            child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PermissionContent extends StatefulWidget {
  const _PermissionContent({this.mobile = false, this.logOnly = false, this.history = const [], this.historyLoading = false});
  final bool mobile;
  final bool logOnly;
  final List<dynamic> history;
  final bool historyLoading;

  @override
  State<_PermissionContent> createState() => _PermissionContentState();
}

class _PermissionContentState extends State<_PermissionContent> {
  final _reasonCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    _updateTimeText();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _updateTimeText() {
    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _formatTimeOfDay(_endTime);
    _timeCtrl.text = '$startStr – $endStr';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2028),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickTimeRange() async {
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'SELECT START TIME',
    );
    if (pickedStart == null || !mounted) return;

    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'SELECT END TIME',
    );
    if (pickedEnd == null || !mounted) return;

    setState(() {
      _startTime = pickedStart;
      _endTime = pickedEnd;
      _updateTimeText();
    });
  }

  Future<void> _submit() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;

    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for your permission.')),
      );
      return;
    }

    setState(() => _submitting = true);

    if (_startTime.hour == _endTime.hour && _startTime.minute == _endTime.minute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an end time later than the start time.')),
      );
      return;
    }

    final payload = {
      'type': 'permission',
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'start_time': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'end_time': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      'reason': _reasonCtrl.text.trim(),
    };

    var ok = false;
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/attendance/permissions'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 12));
      ok = res.statusCode == 200 && (jsonDecode(res.body)['success'] == true);
    } catch (_) {}

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        _reasonCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission request submitted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit permission request.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mobile) ...[
            const MobileEmployeeHeader(showGreeting: false),
            const SizedBox(height: 18),
            const Text('Permission',
                style: TextStyle(color: employeeNavy, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
          ],
          if (!widget.logOnly)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: EmployeeCard(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6637E8), Color(0xFF3558D8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Color(0x333558D8), blurRadius: 18, offset: Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x55FFFFFF)),
                          ),
                          child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 27),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Permission request', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              const Text('Select your time away and send it for approval.', style: TextStyle(color: Color(0xD1FFFFFF), fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(color: const Color(0x2AFFFFFF), borderRadius: BorderRadius.circular(20)),
                          child: const Text('MANAGER APPROVAL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(builder: (context, constraints) {
                    final dateField = InkWell(
                      onTap: _pickDate,
                      child: IgnorePointer(
                        child: TextField(
                          controller: _dateCtrl,
                          decoration: const InputDecoration(labelText: 'Permission date', prefixIcon: Icon(Icons.calendar_today_outlined), border: OutlineInputBorder()),
                        ),
                      ),
                    );
                    final timeField = InkWell(
                      onTap: _pickTimeRange,
                      child: IgnorePointer(
                        child: TextField(
                          controller: _timeCtrl,
                          decoration: const InputDecoration(labelText: 'Time away', prefixIcon: Icon(Icons.schedule_outlined), border: OutlineInputBorder()),
                        ),
                      ),
                    );
                    if (constraints.maxWidth < 620) {
                      return Column(children: [dateField, const SizedBox(height: 14), timeField]);
                    }
                    return Row(children: [Expanded(child: dateField), const SizedBox(width: 14), Expanded(child: timeField)]);
                  }),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _reasonCtrl,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Briefly describe your request...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_outlined, size: 16),
                      label: Text(_submitting ? 'Submitting…' : 'Submit Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B72F5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
                  ),
                ),
              ),
            ),
          if (widget.logOnly) ...[
            const SizedBox(height: 18),
            EmployeeCard(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Permission Log', subtitle: 'Past and pending permission requests'),
                const SizedBox(height: 12),
                if (widget.historyLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (widget.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No permission requests recorded.', style: TextStyle(color: employeeMuted)),
                    ),
                  )
                else
                  ...widget.history.map((r) {
                    final status = r['status']?.toString() ?? 'Pending';
                    final normalizedStatus = status.toUpperCase();
                    final color = normalizedStatus == 'APPROVED'
                        ? employeeGreen
                        : (normalizedStatus == 'REJECTED' ? const Color(0xFFF12B46) : employeeOrange);
                    return _row(
                      _formatHistoryDate(r['date']?.toString() ?? ''),
                      r['reason']?.toString() ?? '',
                      _formatStoredTime(r['start_time']?.toString(), r['end_time']?.toString()),
                      status,
                      color,
                    );
                  }),
              ],
              ),
            ),
          ],
        ],
      );

  String _formatHistoryDate(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatStoredTime(String? start, String? end) {
    String format(String? value) {
      if (value == null || value.isEmpty) return '';
      final parts = value.split(':');
      if (parts.length < 2) return value;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return value;
      return _formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
    }
    final from = format(start);
    final to = format(end);
    return from.isEmpty || to.isEmpty ? 'Time not recorded' : '$from – $to';
  }

  Widget _row(String date, String reason, String time, String status, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: employeePurple),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: const TextStyle(color: employeeNavy, fontWeight: FontWeight.w700)),
                  Text('$reason · $time', style: const TextStyle(color: employeeMuted, fontSize: 12)),
                ],
              ),
            ),
            StatusPill(status, color),
          ],
        ),
      );
}
