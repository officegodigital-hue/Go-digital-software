import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../services/api_config.dart';
import '../../../services/auth_service.dart';
import '../../shared/employee_ui.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  static Widget builder(BuildContext context) => const AttendancePage();

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _attendanceKey = GlobalKey<_AttendanceViewState>();

  @override
  Widget build(BuildContext context) => EmployeeScaffold(
        route: '/employee/attendance',
        title: 'Attendance Calendar',
        subtitle: 'View your monthly attendance records and calendar',
        desktopHeaderAction: FilledButton.icon(
          onPressed: () => _attendanceKey.currentState?._openCorrectionRequest(),
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('Request Correction'),
          style: FilledButton.styleFrom(backgroundColor: employeeBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
        desktop: _AttendanceView(key: _attendanceKey, mobile: false),
        mobile: const _AttendanceView(mobile: true),
      );
}

class _AttendanceView extends StatefulWidget {
  const _AttendanceView({super.key, required this.mobile});
  final bool mobile;

  @override
  State<_AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<_AttendanceView> {
  late int year;
  late int month;
  bool _loading = false;
  Map<int, Map<String, dynamic>> _monthDays = {};
  int _presentCount = 0;
  int _lateCount = 0;
  String? _token;

  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    year = now.year;
    month = now.month;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthService>().token;
    if (_token != token) {
      _token = token;
      if (token != null && token.isNotEmpty) {
        _fetchMonthData();
      }
    }
  }

  String get monthLabel => '${monthNames[month - 1]} $year';
  String get monthQuery => '$year-${month.toString().padLeft(2, '0')}';

  Future<void> _fetchMonthData() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    setState(() => _loading = true);
    try {
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/attendance/dashboard?month=$monthQuery');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];
          final overview = data['month_overview'] as Map?;
          _presentCount = (overview?['present_days'] as num?)?.toInt() ?? 0;
          _lateCount = (overview?['late_days'] as num?)?.toInt() ?? 0;

          final Map<int, Map<String, dynamic>> daysMap = {};

          final calendarData = data['calendarData'] as Map? ?? const {};
          calendarData.forEach((date, raw) {
            final parts = date.toString().split('-');
            if (parts.length != 3 || int.tryParse(parts[0]) != year || int.tryParse(parts[1]) != month) return;
            final item = raw is Map ? raw : const {};
            final attendanceStatus = item['attendance_status']?.toString().toLowerCase();
            final status = attendanceStatus == 'off' ? 'OFF'
                : attendanceStatus == 'h' ? 'H'
                : attendanceStatus == 'absent' ? 'A'
                : item['is_late'] == true ? 'L'
                : item['clock_in_at'] != null || item['punch_in'] != null ? 'P'
                : '';
            daysMap[int.parse(parts[2])] = {
              'status': status,
              'clock_in': item['clock_in_at'] ?? item['punch_in'],
            };
          });

          if (mounted) {
            setState(() {
              _monthDays = daysMap;
            });
          }
        }
      }
    } catch (_) {
      // Fallback gracefully on network error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void changeMonth(int offset) {
    setState(() {
      month += offset;
      if (month == 0) {
        month = 12;
        year--;
      } else if (month == 13) {
        month = 1;
        year++;
      }
    });
    _fetchMonthData();
  }

  Map<String, dynamic> dataFor(int day) {
    if (_monthDays.containsKey(day)) {
      return _monthDays[day]!;
    }
    return {'status': '', 'clock_in': null};
  }

  Future<void> _pickCorrectionTime(TextEditingController controller) async {
    final parts = controller.text.trim().split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? TimeOfDay.now().hour,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? TimeOfDay.now().minute,
    );
    final picked = await showDialog<TimeOfDay>(context: context, builder: (_) => _CorrectionTimePicker(initialTime: initial));
    if (picked != null) controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openCorrectionRequest() async {
    DateTime selected = DateTime.now().subtract(const Duration(days: 1));
    String type = 'automatic_absence';
    final checkIn = TextEditingController();
    final checkOut = TextEditingController();
    final reason = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => Theme(
          data: Theme.of(context).copyWith(inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFFF7F9FD), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: employeeLine)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: employeeLine)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: employeeBlue, width: 1.5)))),
          child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8), contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4), actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          title: const Row(children: [Icon(Icons.edit_calendar_outlined, color: employeeBlue), SizedBox(width: 10), Text('Request Correction', style: TextStyle(color: employeeNavy, fontWeight: FontWeight.w800))]),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Attendance date', style: TextStyle(fontSize: 13, color: employeeMuted)),
                subtitle: Text(DateFormat('dd MMM yyyy').format(selected), style: const TextStyle(fontWeight: FontWeight.w600, color: employeeNavy)),
                trailing: const Icon(Icons.calendar_today_outlined, color: employeeBlue),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime.now().subtract(const Duration(days: 7)),
                    lastDate: DateTime.now().subtract(const Duration(days: 1)),
                  );
                  if (picked != null) update(() => selected = picked);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(hintText: 'Choose correction type'),
                items: const [
                  DropdownMenuItem(value: 'missed_check_in', child: Text('Missed check-in')),
                  DropdownMenuItem(value: 'missed_check_out', child: Text('Missed check-out')),
                  DropdownMenuItem(value: 'incorrect_time', child: Text('Incorrect time')),
                  DropdownMenuItem(value: 'automatic_absence', child: Text('Incorrect automatic absence')),
                ],
                onChanged: (value) => update(() => type = value!),
              ),
              const SizedBox(height: 12),
              if (type == 'incorrect_time') ...[
                Row(children: [
                  Expanded(child: _CorrectionTimeField(label: 'Check-in', value: checkIn.text, onTap: () async { await _pickCorrectionTime(checkIn); update(() {}); })),
                  const SizedBox(width: 12),
                  Expanded(child: _CorrectionTimeField(label: 'Check-out', value: checkOut.text, onTap: () async { await _pickCorrectionTime(checkOut); update(() {}); })),
                ]),
                const SizedBox(height: 12),
              ] else ...[
                if (type != 'missed_check_out') _CorrectionTimeField(label: 'Correct check-in time', value: checkIn.text, onTap: () async { await _pickCorrectionTime(checkIn); update(() {}); }),
                if (type != 'missed_check_out') const SizedBox(height: 12),
                if (type == 'missed_check_out') _CorrectionTimeField(label: 'Correct check-out time', value: checkOut.text, onTap: () async { await _pickCorrectionTime(checkOut); update(() {}); }),
                if (type == 'missed_check_out') const SizedBox(height: 12),
              ],
              TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(hintText: 'Reason for this correction')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: employeeBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
          ],
        ),
        ),
      ),
    );

    if (submitted != true || _token == null) {
      checkIn.dispose();
      checkOut.dispose();
      reason.dispose();
      return;
    }
    final payload = {
      'attendanceDate': DateFormat('yyyy-MM-dd').format(selected),
      'requestType': type,
      'checkInTime': checkIn.text.trim(),
      'checkOutTime': checkOut.text.trim(),
      'reason': reason.text.trim(),
    };
    checkIn.dispose();
    checkOut.dispose();
    reason.dispose();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/attendance/corrections'),
        headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      final body = jsonDecode(response.body) as Map;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        body['message']?.toString() ?? (response.statusCode < 300 ? 'Correction request submitted.' : 'Unable to submit request'),
      )));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to submit correction request.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = _CalendarCard(
      year: year,
      month: month,
      label: monthLabel,
      mobile: widget.mobile,
      dataFor: dataFor,
      onPrevious: () => changeMonth(-1),
      onNext: () => changeMonth(1),
    );

    final details = Column(children: [
      _SummaryCard(
        monthLabel: monthLabel,
        present: _presentCount,
        late: _lateCount,
      ),
      const SizedBox(height: 16),
      _RecentAttendanceCard(year: year, month: month, days: _monthDays),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.mobile) ...[
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _openCorrectionRequest,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Request Correction'),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (_loading) const LinearProgressIndicator(),
      if (widget.mobile) ...[
        const MobileEmployeeHeader(showGreeting: false),
        const SizedBox(height: 24),
        const Text('Attendance Calendar',
            style: TextStyle(
                color: employeeNavy,
                fontSize: 28,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('Your attendance for $monthLabel',
            style: const TextStyle(color: employeeMuted, fontSize: 16)),
        const SizedBox(height: 18),
        calendar,
        const SizedBox(height: 16),
        details,
      ] else
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 980) {
            return Column(
                children: [calendar, const SizedBox(height: 18), details]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: calendar),
            const SizedBox(width: 20),
            Expanded(flex: 4, child: details),
          ]);
        }),
    ]);
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.year,
    required this.month,
    required this.label,
    required this.mobile,
    required this.dataFor,
    required this.onPrevious,
    required this.onNext,
  });

  final int year;
  final int month;
  final String label;
  final bool mobile;
  final Map<String, dynamic> Function(int day) dataFor;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => EmployeeCard(
        padding: EdgeInsets.all(mobile ? 14 : 22),
        child: Column(children: [
          Row(children: [
            _CalendarArrow(
                icon: Icons.chevron_left_rounded, onPressed: onPrevious),
            Expanded(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: employeeBlue,
                      fontSize: mobile ? 22 : 25,
                      fontWeight: FontWeight.w800)),
            ),
            _CalendarArrow(
                icon: Icons.chevron_right_rounded, onPressed: onNext),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: employeeLine),
          const SizedBox(height: 8),
          _AttendanceCalendar(
              year: year, month: month, mobile: mobile, dataFor: dataFor),
          const SizedBox(height: 14),
          const Wrap(
              alignment: WrapAlignment.center,
              spacing: 15,
              runSpacing: 9,
              children: [
                _LegendStatus('P', 'Present', employeeBlue),
                _LegendStatus('A', 'Absent', Color(0xFFF2212F)),
                _LegendStatus('L', 'Late', employeeOrange),
                _LegendStatus('HL', 'Half Leave', employeePurple),
                _LegendStatus('OFF', 'Weekly Off', Color(0xFF7D8FAA)),
              ]),
        ]),
      );
}

class _AttendanceCalendar extends StatelessWidget {
  const _AttendanceCalendar({
    required this.year,
    required this.month,
    required this.mobile,
    required this.dataFor,
  });

  final int year;
  final int month;
  final bool mobile;
  final Map<String, dynamic> Function(int day) dataFor;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final days = DateTime(year, month + 1, 0).day;
    final leading = DateTime(year, month, 1).weekday - 1;
    final used = leading + days;
    final trailing = (7 - used % 7) % 7;
    final cells = <Widget>[
      ...List.generate(leading, (_) => const _EmptyCalendarDay()),
      ...List.generate(days, (index) {
        final day = index + 1;
        final info = dataFor(day);
        return _CalendarDay(
          day: day,
          status: info['status']?.toString() ?? '',
          clockIn: info['clock_in']?.toString(),
        );
      }),
      ...List.generate(trailing, (_) => const _EmptyCalendarDay()),
    ];

    return Column(children: [
      Row(
        children: weekdays
            .map((day) => Expanded(
                  child: SizedBox(
                    height: 34,
                    child: Center(
                      child: Text(day,
                          style: TextStyle(
                              color: employeeMuted,
                              fontSize: mobile ? 9 : 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ))
            .toList(),
      ),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: mobile ? .65 : 1.05,
        children: cells,
      ),
    ]);
  }
}

class _EmptyCalendarDay extends StatelessWidget {
  const _EmptyCalendarDay();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: employeeLine, width: .7),
        ),
      );
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.status,
    this.clockIn,
  });

  final int day;
  final String status;
  final String? clockIn;

  Color get color => switch (status) {
        'A' => const Color(0xFFF2212F),
        'L' => employeeOrange,
        'HL' => employeePurple,
        'H' => employeePurple,
        'OFF' => const Color(0xFF7D8FAA),
        _ => employeeBlue,
      };

  String? get formattedTime {
    if (clockIn == null || clockIn!.isEmpty) return null;
    try {
      final dt = DateTime.parse(clockIn!).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return clockIn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStatus = status.isNotEmpty;
    final timeStr = formattedTime;

    return Container(
      decoration: BoxDecoration(
        color: status == 'OFF' ? const Color(0xFFF6F9FD) : Colors.white,
        border: Border.all(color: employeeLine, width: .7),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: const TextStyle(
                color: employeeNavy, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (status == 'OFF')
            Text('OFF',
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w600))
          else if (status == 'H')
            Text('Holiday', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600))
          else if (hasStatus)
            Container(
              width: status == 'HL' ? 31 : 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                status,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
              ),
            ),
          if (timeStr != null) ...[
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: employeeNavy,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarArrow extends StatelessWidget {
  const _CalendarArrow({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 42,
        height: 42,
        child: IconButton.outlined(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: employeeBlue, size: 27),
          style: IconButton.styleFrom(
              side: const BorderSide(color: employeeLine),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        ),
      );
}

class _LegendStatus extends StatelessWidget {
  const _LegendStatus(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: code == 'OFF' ? 34 : 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: code == 'OFF' ? const Color(0xFFEAF0F8) : color,
              shape: code == 'OFF' ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: code == 'OFF' ? BorderRadius.circular(14) : null,
            ),
            child: Text(code,
                style: TextStyle(
                    color: code == 'OFF' ? employeeMuted : Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(color: employeeNavy, fontSize: 11)),
        ],
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.monthLabel,
    required this.present,
    required this.late,
  });

  final String monthLabel;
  final int present;
  final int late;

  @override
  Widget build(BuildContext context) => EmployeeCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${monthLabel.split(' ').first} Summary',
              style: const TextStyle(
                  color: employeeBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _SummaryCell(
                    'Working Days', '26', employeeBlue)),
            Expanded(
                child: _SummaryCell(
                    'Present', '$present', employeeBlue)),
            Expanded(
                child: _SummaryCell(
                    'Absent', '—', const Color(0xFFF04438))),
            Expanded(
                child: _SummaryCell(
                    'Late', '$late', employeeOrange, last: true)),
          ]),
        ]),
      );
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell(this.label, this.value, this.color, {this.last = false});
  final String label;
  final String value;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(right: BorderSide(color: employeeLine)),
        ),
        child: Column(children: [
          Text(label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(color: employeeMuted, fontSize: 10)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 25, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _RecentAttendanceCard extends StatelessWidget {
  const _RecentAttendanceCard({required this.year, required this.month, required this.days});
  final int year;
  final int month;
  final Map<int, Map<String, dynamic>> days;

  @override
  Widget build(BuildContext context) {
    final records = days.entries.where((entry) => const {'P', 'L', 'A'}.contains(entry.value['status'])).toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return EmployeeCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Attendance',
            style: TextStyle(
                color: employeeBlue,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const _RecentAttendanceRow('No attendance records', 'None', '—', employeeMuted)
        else
          ...records.take(5).map((entry) {
            final code = entry.value['status']?.toString() ?? '';
            final status = code == 'A' ? 'Absent' : code == 'L' ? 'Late' : 'Present';
            final color = code == 'A' ? const Color(0xFFF0182A) : code == 'L' ? employeeOrange : employeeBlue;
            final rawTime = entry.value['clock_in'];
            String time = 'No check-in';
            if (rawTime != null) {
              try { time = DateFormat('hh:mm a').format(DateTime.parse(rawTime.toString().replaceFirst(' ', 'T')).toLocal()); }
              catch (_) { time = rawTime.toString(); }
            }
            final now = DateTime.now();
            final label = year == now.year && month == now.month && entry.key == now.day ? 'Today' : DateFormat('d MMM').format(DateTime(year, month, entry.key));
            return _RecentAttendanceRow(label, status, time, color);
          }),
      ]),
    );
  }
}

class _RecentAttendanceRow extends StatelessWidget {
  const _RecentAttendanceRow(this.date, this.status, this.time, this.color);
  final String date;
  final String status;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: employeeBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(date,
                  style: const TextStyle(
                      color: employeeNavy, fontWeight: FontWeight.w700))),
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(color: color)),
          const SizedBox(width: 14),
          Text(time, style: const TextStyle(color: employeeMuted)),
        ]),
      );
}

class _CorrectionTimeField extends StatelessWidget {
  const _CorrectionTimeField({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FD), borderRadius: BorderRadius.circular(10), border: Border.all(color: employeeLine)),
            child: Row(children: [
              Expanded(child: Text(value.isEmpty ? '$label (HH:MM)' : value, overflow: TextOverflow.ellipsis, style: TextStyle(color: value.isEmpty ? const Color(0xFF596174) : employeeNavy, fontSize: 16, fontWeight: value.isEmpty ? FontWeight.w400 : FontWeight.w700))),
              const Icon(Icons.schedule_outlined, color: employeeBlue, size: 23),
            ]),
          ),
        ),
      );
}

class _CorrectionTimePicker extends StatefulWidget {
  const _CorrectionTimePicker({required this.initialTime});
  final TimeOfDay initialTime;

  @override
  State<_CorrectionTimePicker> createState() => _CorrectionTimePickerState();
}

class _CorrectionTimePickerState extends State<_CorrectionTimePicker> {
  late int _hour24;
  late int _minute;
  @override
  void initState() { super.initState(); _hour24 = widget.initialTime.hour; _minute = widget.initialTime.minute; }
  void _hour(int amount) => setState(() => _hour24 = (_hour24 + amount + 24) % 24);
  void _minutes(int amount) => setState(() => _minute = (_minute + amount + 60) % 60);

  @override
  Widget build(BuildContext context) {
    final h = _hour24 % 12 == 0 ? 12 : _hour24 % 12;
    final suffix = _hour24 >= 12 ? 'PM' : 'AM';
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [const Expanded(child: Text('Set time', style: TextStyle(color: employeeNavy, fontSize: 23, fontWeight: FontWeight.w800))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: employeeMuted))]),
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 22), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF5F8FC), borderRadius: BorderRadius.circular(12)), child: Text('${h.toString().padLeft(2, '0')} : ${_minute.toString().padLeft(2, '0')} $suffix', style: const TextStyle(color: employeeNavy, fontSize: 36, fontWeight: FontWeight.w800))),
            const SizedBox(height: 22),
            Row(children: [Expanded(child: _TimeStepper(label: 'Hour', value: h.toString().padLeft(2, '0'), onMinus: () => _hour(-1), onPlus: () => _hour(1))), const SizedBox(width: 18), Expanded(child: _TimeStepper(label: 'Minute', value: _minute.toString().padLeft(2, '0'), onMinus: () => _minutes(-1), onPlus: () => _minutes(1)))]),
            const SizedBox(height: 18),
            Row(children: [Expanded(child: OutlinedButton(onPressed: () => setState(() => _hour24 = _hour24 >= 12 ? _hour24 - 12 : _hour24 + 12), child: Text(suffix))), const SizedBox(width: 12), Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: employeeBlue, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, TimeOfDay(hour: _hour24, minute: _minute)), child: const Text('Apply')))]),
          ]),
        ),
      ),
    );
  }
}

class _TimeStepper extends StatelessWidget {
  const _TimeStepper({required this.label, required this.value, required this.onMinus, required this.onPlus});
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label, style: const TextStyle(color: employeeMuted, fontWeight: FontWeight.w700)), const SizedBox(height: 7),
        Container(height: 52, decoration: BoxDecoration(border: Border.all(color: employeeLine), borderRadius: BorderRadius.circular(10)), child: Row(children: [Expanded(child: IconButton(onPressed: onMinus, icon: const Icon(Icons.remove, color: employeeBlue))), Container(width: 1, color: employeeLine), Expanded(child: Center(child: Text(value, style: const TextStyle(color: employeeNavy, fontWeight: FontWeight.w800, fontSize: 20)))), Container(width: 1, color: employeeLine), Expanded(child: IconButton(onPressed: onPlus, icon: const Icon(Icons.add, color: employeeBlue)))])),
      ]);
}
