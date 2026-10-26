import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/hrms_employee_profile_api.dart';
import '../clock_logs/employee_clock_calendar_drawer.dart';

// ── palette ───────────────────────────────────────────────────────────────────
const _purple = Color(0xFF534AB7);
const _purpleDk = Color(0xFF3C3489);
const _page = Color(0xFFF4F6FB);
const _border = Color(0xFFE3E8F4);
const _muted = Color(0xFF8A94A6);
const _green = Color(0xFF148B1A);
const _greenLt = Color(0xFFE8F7E9);
const _amber = Color(0xFFD97706);
const _amberLt = Color(0xFFFFF8E6);
const _red = Color(0xFFD42B2B);
const _redLt = Color(0xFFFDEAEA);
const _orange = Color(0xFFC95800);
const _orangeLt = Color(0xFFFFF1E8);

// kept for leaves/payroll tabs
const _navy = Color(0xFF061457);
const _blue = Color(0xFF075EF7);
const _blueLt = Color(0xFFEAF2FF);

const _months = [
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

// ─────────────────────────────────────────────────────────────────────────────
class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({
    super.key,
    required this.profileId,
    this.initialName,
    this.employeeUserId,
  });

  final int profileId;
  final String? initialName;
  final int? employeeUserId;

  @override
  State<EmployeeProfilePage> createState() => _State();
}

class _State extends State<EmployeeProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await HrmsEmployeeProfileApi.getProfile(
        widget.profileId,
        year: _year,
        month: _month,
        employeeUserId: widget.employeeUserId,
      );
      if (mounted && request == _loadRequest)
        setState(() {
          _data = d;
          _loading = false;
        });
    } catch (e) {
      if (mounted && request == _loadRequest) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _load();
  }

  void _openAttendanceEditor(Map<String, dynamic> employee) {
    final employeeId = (employee['employeeUserId'] as num?)?.toInt() ??
        widget.employeeUserId;
    if (employeeId == null) return;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close employee calendar',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: MediaQuery.sizeOf(dialogContext).width < 600
              ? MediaQuery.sizeOf(dialogContext).width
              : 530,
          height: MediaQuery.sizeOf(dialogContext).height,
          child: EmployeeClockCalendarDrawer(
            employeeId: employeeId,
            employeeName: employee['name']?.toString() ?? 'Employee',
            staffId: employee['employeeCode']?.toString() ?? '$employeeId',
            initialMonth: DateTime(_year, _month),
            onSaved: _load,
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _page, body: _body());
  }

  Widget _body() {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _purple));
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);
    if (_data == null) return const Center(child: Text('No data'));

    final emp = Map<String, dynamic>.from(_data!['employee'] as Map? ?? {});
    final summary = Map<String, dynamic>.from(_data!['summary'] as Map? ?? {});
    final daily = (_data!['dailyAttendance'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final leaves = (_data!['leaves'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final payroll = (_data!['payrollHistory'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return Column(
      children: [
        _TopBar(
          emp: emp,
          summary: summary,
          year: _year,
          month: _month,
          onBack: () => Navigator.pop(context),
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),
        Expanded(
          child: Column(
            children: [
              // tab bar
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    TabBar(
                      controller: _tab,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: _blue,
                      unselectedLabelColor: _muted,
                      indicatorColor: _blue,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      tabs: const [
                        Tab(
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_outlined, size: 19),
                              SizedBox(width: 8),
                              Text('Attendance'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            children: [
                              Icon(Icons.description_outlined, size: 19),
                              SizedBox(width: 8),
                              Text('Leaves & Permissions'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 19),
                              SizedBox(width: 8),
                              Text('Payroll History'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: _border),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _AttendanceTab(
                      days: daily,
                      summary: summary,
                      month: _month,
                      year: _year,
                      onEditAttendance:
                          emp['employeeUserId'] == null &&
                              widget.employeeUserId == null
                          ? null
                          : () => _openAttendanceEditor(emp),
                    ),
                    _LeavesTab(leaves: leaves, month: _month, year: _year),
                    _PayrollTab(history: payroll),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar — employee banner + stat pills + month nav
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.emp,
    required this.summary,
    required this.year,
    required this.month,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
  });
  final Map<String, dynamic> emp;
  final Map<String, dynamic> summary;
  final int year, month;
  final VoidCallback onBack, onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final name = emp['name'] as String? ?? '';
    final code = emp['employeeCode'] as String? ?? '';
    final dept = emp['department'] as String? ?? '';
    final mode = emp['workMode'] as String? ?? '';
    final status = emp['status'] as String? ?? 'Active';
    final initials = _initials(name);
    final inactive = status.toLowerCase() == 'inactive';
    final active = status.toLowerCase() == 'active';
    final sc = inactive
        ? _red
        : active
        ? _green
        : _amber;
    final sb = inactive
        ? _redLt
        : active
        ? _greenLt
        : _amberLt;

    // stat pill data
    final workingDays = summary['workingDays'] ?? 0;
    final paidDays = summary['paidDays'] ?? 0;
    final present = summary['present'] ?? 0;
    final absent = summary['absent'] ?? 0;
    final late = summary['late'] ?? 0;
    final lop = summary['lopDays'] ?? 0;
    final permission = summary['permissions'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.arrow_back, size: 20, color: _blue),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Clock logs',
                style: TextStyle(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 9),
                child: Text('/', style: TextStyle(color: _muted, fontSize: 15)),
              ),
              const Text(
                'Employee overview',
                style: TextStyle(
                  color: Color(0xFF5B6F9D),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // square avatar
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _blueLt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: _blue,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sb,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sc,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (code.isNotEmpty) 'ID $code',
                        if (dept.isNotEmpty) dept,
                        if (mode.isNotEmpty) mode,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5B6F9D),
                      ),
                    ),
                  ],
                ),
              ),
              // month nav
              _monthArrow(Icons.chevron_left, onPrev),
              const SizedBox(width: 8),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 17,
                      color: _blue,
                    ),
                    const SizedBox(width: 11),
                    Text(
                      '${_months[month - 1]} $year',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _monthArrow(Icons.chevron_right, onNext),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(flex: 31, child: _workingSummary(workingDays, paidDays)),
              const SizedBox(width: 12),
              Expanded(
                flex: 43,
                child: _attendanceSummary(
                  present: present,
                  late: late,
                  absent: absent,
                  lop: lop,
                  permission: permission,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 28, child: _payrollSummary(summary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthArrow(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: _border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _blue, size: 22),
    ),
  );

  Widget _workingSummary(dynamic workingDays, dynamic paidDays) => Container(
    height: 118,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1264F5), Color(0xFF0755DB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.calendar_month_outlined,
          color: Colors.white,
          size: 23,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Working days',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '$workingDays',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, height: 54, color: Colors.white38),
        const SizedBox(width: 22),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Paid days',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '$paidDays / $workingDays',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _attendanceSummary({
    required dynamic present,
    required dynamic late,
    required dynamic absent,
    required dynamic lop,
    required dynamic permission,
  }) => Container(
    height: 118,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance · ${_months[month - 1]} $year',
          style: const TextStyle(
            color: _navy,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            _attendanceValue('Present', present, _green),
            _attendanceValue('Late', late, const Color(0xFFFF9800)),
            _attendanceValue('Absent', absent, _red),
            _attendanceValue('LOP', lop, const Color(0xFFFF5964)),
            _attendanceValue('Permission', permission, const Color(0xFF5B22E8)),
          ],
        ),
      ],
    ),
  );

  Widget _attendanceValue(String label, dynamic value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5B6F9D),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '$value',
            style: const TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _payrollSummary(Map<String, dynamic> summary) {
    final status = summary['payrollStatus']?.toString() ?? 'draft';
    final salary = summary['netPayLabel']?.toString() ?? '–';
    return Container(
      height: 118,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payroll · ${_months[month - 1]} $year',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.isEmpty
                      ? 'Draft'
                      : '${status[0].toUpperCase()}${status.substring(1)}',
                  style: const TextStyle(
                    color: Color(0xFF50649E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF50649E),
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Salary',
                    style: TextStyle(color: Color(0xFF5B6F9D), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    salary,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance tab — timeline cards + ring panel
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({
    required this.days,
    required this.summary,
    required this.month,
    required this.year,
    required this.onEditAttendance,
  });
  final List<Map<String, dynamic>> days;
  final Map<String, dynamic> summary;
  final int month, year;
  final VoidCallback? onEditAttendance;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty)
      return const _Empty('No attendance records for this month');

    final groups = _weekGroups(days);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // left — timeline
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                children: [
                  Row(
                    children: [
                      const Text(
                        'Daily log',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _purpleDk,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 16, color: _border),
                      const SizedBox(width: 12),
                      Text(
                        '${_months[month - 1]} $year',
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final g in groups) ...[
                    _WeekLabel(label: g.label),
                    const SizedBox(height: 8),
                    for (final d in g.days)
                      _DayCard(day: d, onEditAttendance: onEditAttendance),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // right — ring panel
          _RingPanel(summary: summary, month: month, year: year),
        ],
      ),
    );
  }

  List<_WeekGroup> _weekGroups(List<Map<String, dynamic>> days) {
    final groups = <_WeekGroup>[];
    _WeekGroup? cur;
    int? curWeek;

    for (final d in days) {
      final iso = d['date'] as String? ?? '';
      final wn = _weekNum(iso);
      if (wn != curWeek) {
        if (cur != null) groups.add(cur);
        final range = _weekRange(iso);
        cur = _WeekGroup(label: 'Week ${groups.length + 1} · $range', days: []);
        curWeek = wn;
      }
      cur!.days.add(d);
    }
    if (cur != null) groups.add(cur);
    return groups;
  }

  int _weekNum(String iso) {
    if (iso.length < 10) return 0;
    final p = iso.split('-');
    if (p.length < 3) return 0;
    final d = DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return ((d.difference(DateTime.utc(d.year, 1, 1)).inDays) / 7).floor();
  }

  String _weekRange(String firstIso) {
    if (firstIso.length < 10) return '';
    final p = firstIso.split('-');
    final d = DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    const mons = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    // find Monday of this week
    final mon = d.subtract(Duration(days: (d.weekday - 1) % 7));
    final sun = mon.add(const Duration(days: 6));
    if (mon.month == sun.month) {
      return '${mons[mon.month - 1]} ${mon.day}–${sun.day}';
    }
    return '${mons[mon.month - 1]} ${mon.day} – ${mons[sun.month - 1]} ${sun.day}';
  }
}

class _WeekGroup {
  _WeekGroup({required this.label, required this.days});
  final String label;
  final List<Map<String, dynamic>> days;
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: _muted,
        letterSpacing: 0.06,
      ),
    ),
  );
}

class _DayCard extends StatefulWidget {
  const _DayCard({required this.day, required this.onEditAttendance});
  final Map<String, dynamic> day;
  final VoidCallback? onEditAttendance;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final date = DateTime.tryParse(day['date']?.toString() ?? '');
    final dayNumber = date?.day.toString().padLeft(2, '0') ?? '--';
    final month = date == null ? '' : _months[date.month - 1].substring(0, 3);
    final weekday = day['weekday']?.toString() ?? '';
    final isOff = day['isWeeklyOff'] == true;
    final status = isOff
        ? 'weekly off'
        : (day['status']?.toString() ?? 'no record');
    final checkIn = day['checkIn']?.toString() ?? '–';
    final checkOut = day['checkOut']?.toString() ?? '–';
    final worked = day['workedLabel']?.toString() ?? '–';
    final breakLabel = day['breakLabel']?.toString() ?? '–';

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          Container(
            color: _expanded ? const Color(0xFFF3F7FF) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayNumber,
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        month,
                        style: const TextStyle(
                          color: Color(0xFF5B6F9D),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _separator(),
                SizedBox(
                  width: 58,
                  child: Text(
                    weekday,
                    style: const TextStyle(
                      color: Color(0xFF4F6596),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _separator(),
                Expanded(child: _timeValue('Check in', checkIn)),
                _separator(),
                Expanded(child: _timeValue('Check out', checkOut)),
                _separator(),
                Expanded(child: _timeValue('Worked', worked, emphasized: true)),
                _separator(),
                Expanded(child: _timeValue('Break', breakLabel)),
                _separator(),
                Expanded(child: _statusValue(status)),
                if (widget.onEditAttendance != null) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: widget.onEditAttendance,
                    tooltip: 'Edit attendance',
                    icon: const Icon(Icons.edit_calendar_outlined, size: 19),
                    style: IconButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: Color(0xFFB8D3FF)),
                      minimumSize: const Size(38, 38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  tooltip: _expanded ? 'Hide details' : 'Show details',
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: Color(0xFFC9D9F2)),
                    minimumSize: const Size(38, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_expanded)
            Container(
              margin: const EdgeInsets.fromLTRB(44, 0, 12, 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                border: Border.all(color: const Color(0xFFDDE8F8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _timeValue(
                      'Break start',
                      day['breakStart']?.toString() ?? '–',
                    ),
                  ),
                  _separator(height: 30),
                  Expanded(
                    child: _timeValue(
                      'Break end',
                      day['breakEnd']?.toString() ?? '–',
                    ),
                  ),
                  _separator(height: 30),
                  Expanded(
                    child: _timeValue(
                      'Method',
                      day['method']?.toString() ?? '–',
                    ),
                  ),
                  _separator(height: 30),
                  Expanded(
                    child: _timeValue(
                      'LOP',
                      day['isLop'] == true ? 'Yes' : 'No',
                      emphasized: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _separator({double height = 42}) => Container(
    width: 1,
    height: height,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: _border,
  );

  Widget _timeValue(String label, String value, {bool emphasized = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF60729A), fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _navy,
              fontSize: 13,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );

  Widget _statusValue(String raw) {
    final status = raw.toLowerCase().replaceAll('_', ' ');
    final absent = status.contains('absent');
    final late = status.contains('late') || status.contains('early exit');
    final present = status == 'present';
    final color = absent
        ? _red
        : late
        ? _amber
        : present
        ? _green
        : const Color(0xFF667085);
    final background = absent
        ? _redLt
        : late
        ? _amberLt
        : present
        ? _greenLt
        : const Color(0xFFF0F2F6);
    final label = status
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Status',
          style: TextStyle(color: Color(0xFF60729A), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring side panel
// ─────────────────────────────────────────────────────────────────────────────
class _RingPanel extends StatelessWidget {
  const _RingPanel({
    required this.summary,
    required this.month,
    required this.year,
  });
  final Map<String, dynamic> summary;
  final int month, year;

  @override
  Widget build(BuildContext context) {
    final workingDays = (summary['workingDays'] as num? ?? 0).toInt();
    final present = (summary['present'] as num? ?? 0).toInt();
    final absent = (summary['absent'] as num? ?? 0).toInt();
    final late = (summary['late'] as num? ?? 0).toInt();
    final onLeave = (summary['onLeave'] as num? ?? 0).toInt();
    final weekend = (summary['weekendDays'] as num? ?? 0).toInt();

    final totalPresent = present + late;
    final pct = workingDays > 0
        ? (totalPresent / workingDays * 100).round()
        : 0;
    final fraction = workingDays > 0 ? totalPresent / workingDays : 0.0;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          const Text(
            'Attendance rate',
            style: TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          // ring
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _RingPainter(fraction: fraction.toDouble()),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: _blue,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'present',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // breakdown
          _bkRow(
            _green,
            'Present',
            '$present day${present == 1 ? '' : 's'}',
            _green,
          ),
          if (late > 0)
            _bkRow(_amber, 'Late', '$late day${late == 1 ? '' : 's'}', _amber),
          _bkRow(_red, 'Absent', '$absent day${absent == 1 ? '' : 's'}', _red),
          if (onLeave > 0)
            _bkRow(
              _purple,
              'Leave',
              '$onLeave day${onLeave == 1 ? '' : 's'}',
              _purple,
            ),
          if (weekend > 0)
            _bkRow(
              const Color(0xFFCFD4E0),
              'Weekend',
              '$weekend day${weekend == 1 ? '' : 's'}',
              _muted,
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _bkRow(Color dot, String label, String value, Color valueColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction});
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 10;
    const stroke = 12.0;

    // track
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = const Color(0xFFE5EDFA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // arc
    if (fraction > 0) {
      final sweep = 2 * math.pi * fraction.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = _blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

// ─────────────────────────────────────────────────────────────────────────────
// Leaves tab
// ─────────────────────────────────────────────────────────────────────────────
class _LeavesTab extends StatefulWidget {
  const _LeavesTab({
    required this.leaves,
    required this.month,
    required this.year,
  });
  final List<Map<String, dynamic>> leaves;
  final int month, year;

  @override
  State<_LeavesTab> createState() => _LeavesTabState();
}

class _LeavesTabState extends State<_LeavesTab> {

  @override
  Widget build(BuildContext context) {
    if (widget.leaves.isEmpty)
      return const _Empty('No leave or permission records');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      children: [
        Row(
          children: [
            const Text(
              'Leaves & Permissions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 18, color: _border),
            const SizedBox(width: 16),
            Text(
              '${_months[widget.month - 1]} ${widget.year}',
              style: const TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...widget.leaves.map(_card),
      ],
    );
  }

  Widget _card(Map<String, dynamic> l) {
    final from = l['fromDate'] as String? ?? '';
    final to = l['toDate'] as String? ?? '';
    final period = (from == to || to.isEmpty)
        ? _sd(from)
        : '${_sd(from)} – ${_sd(to)}';
    final days = (l['durationDays'] as num? ?? 1).toInt();
    final dt = (l['durationType'] as String? ?? '').toLowerCase();
    final dur = dt == 'half day'
        ? 'Half Day'
        : (days == 1 ? '1 day' : '$days days');
    final isPerm = l['isPermission'] == true;

    final date = DateTime.tryParse(from);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
        child: LayoutBuilder(builder: (context, c) {
          final compact = c.maxWidth < 760;
          final tile = Container(
            width: compact ? double.infinity : 94,
            height: compact ? 76 : 104,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_blue, Color(0xFF0046C8)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(date == null ? '–' : date.day.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
              Text(date == null ? '–' : '${_months[date.month - 1].substring(0, 3)} ${date.year}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5), const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 18),
            ]),
          );
          final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 6, children: [Text(l['type'] as String? ?? 'Leave', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _navy)), _ReqStatus(status: l['status'] as String? ?? 'pending')]),
            const SizedBox(height: 5), Row(children: [const Icon(Icons.schedule, size: 16, color: _muted), const SizedBox(width: 6), Text(dur, style: const TextStyle(fontSize: 13, color: _muted))]),
            const SizedBox(height: 9), Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: _blueLt, borderRadius: BorderRadius.circular(8)), child: Text('${isPerm ? 'Permission' : (l['type'] ?? 'Leave')} · ${l['reason'] ?? '–'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _navy, fontWeight: FontWeight.w500))),
          ]);
          final facts = Wrap(spacing: 18, runSpacing: 12, children: [
            _ProfileFact(icon: Icons.calendar_today_outlined, label: 'Applied on', value: _sd(l['appliedOn'] as String? ?? '')),
            _ProfileFact(icon: Icons.person_outline, label: 'Reviewed by', value: l['reviewedBy']?.toString() ?? '–'),
            _ProfileFact(icon: Icons.date_range_outlined, label: 'Period', value: period),
            _ProfileFact(icon: Icons.description_outlined, label: 'LOP', child: _LopDot(isLop: l['isLopImpact'] == true)),
          ]);
          if (compact) return Column(children: [tile, const SizedBox(height: 16), details, const SizedBox(height: 18), facts]);
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [tile, const SizedBox(width: 18), Expanded(flex: 5, child: details), const SizedBox(width: 22), Expanded(flex: 5, child: facts)]);
        }),
      ),
    );
  }

  String _sd(String iso) {
    if (iso.length < 10) return '–';
    final p = iso.split('-');
    if (p.length < 3) return iso;
    const mons = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = int.tryParse(p[1]) ?? 1;
    return '${p[2]} ${mons[m - 1]} ${p[0]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payroll tab
// ─────────────────────────────────────────────────────────────────────────────
class _PayrollTab extends StatefulWidget {
  const _PayrollTab({required this.history});
  final List<Map<String, dynamic>> history;

  @override
  State<_PayrollTab> createState() => _PayrollTabState();
}

class _PayrollTabState extends State<_PayrollTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) return const _Empty('No payroll history');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      children: [
        const Row(
          children: [
            Text(
              'Payroll History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            SizedBox(width: 16),
            SizedBox(width: 1, height: 18),
            SizedBox(width: 16),
            Text(
              'Last 6 months',
              style: TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...widget.history.take(6).map(_card),
      ],
    );
  }

  Widget _card(Map<String, dynamic> h) {
    final lop = (h['lopDays'] as num? ?? 0).toInt();
    final ps = h['periodStart'] as String? ?? '';
    final pe = h['periodEnd'] as String? ?? '';
    final period = (ps.isNotEmpty && pe.isNotEmpty)
        ? '${_sp(ps)} – ${_sp(pe)}'
        : '–';

    final monthLabel = h['monthLabel'] as String? ?? '–';
    final year = h['year']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, c) {
          final compact = c.maxWidth < 820;
          final monthTile = Container(width: compact ? double.infinity : 100, height: compact ? 76 : 104, padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: _blueLt, border: Border(left: BorderSide(color: _blue, width: 4))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(monthLabel.length >= 3 ? monthLabel.substring(0, 3).toUpperCase() : monthLabel.toUpperCase(), style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w700)), Text(year, style: const TextStyle(color: _navy, fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 4), const Icon(Icons.calendar_month_outlined, color: _blue, size: 18)]));
          final displayMonth = monthLabel.contains(year) ? monthLabel : '$monthLabel $year';
          final overview = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(displayMonth, style: const TextStyle(color: _navy, fontSize: 17, fontWeight: FontWeight.w700)), _PayStatus(status: h['status'] as String? ?? 'draft')]), const SizedBox(height: 8), Row(children: [const Icon(Icons.calendar_today_outlined, color: _muted, size: 16), const SizedBox(width: 6), Expanded(child: Text('Period  $period', style: const TextStyle(fontSize: 13, color: _muted)))])]);
          final metrics = Row(children: [Expanded(child: _PayrollMetric(icon: Icons.business_center_outlined, label: 'Working', value: '${h['workingDays'] ?? 0}')), Expanded(child: _PayrollMetric(icon: Icons.calendar_today_outlined, label: 'Paid days', value: '${h['paidDays'] ?? 0}')), Expanded(child: _PayrollMetric(icon: Icons.description_outlined, label: 'LOP', value: '$lop', valueColor: lop > 0 ? _red : _navy))]);
          final pay = Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF3F7FF), borderRadius: BorderRadius.circular(9)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Net pay', style: TextStyle(fontSize: 12, color: _muted)), const SizedBox(height: 2), Text(h['netPayLabel'] as String? ?? '–', style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 16)), const Divider(height: 14), Row(children: [Expanded(child: _PayValue(label: 'Salary', value: h['salaryLabel'] as String? ?? '–')), Expanded(child: _PayValue(label: 'Deduction', value: lop > 0 ? (h['deductionsLabel'] as String? ?? '–') : '–'))])])) ;
          if (compact) return Padding(padding: const EdgeInsets.all(16), child: Column(children: [monthTile, const SizedBox(height: 16), overview, const SizedBox(height: 20), metrics, const SizedBox(height: 18), pay]));
          return Padding(padding: const EdgeInsets.all(12), child: Row(children: [monthTile, const SizedBox(width: 18), Expanded(flex: 4, child: overview), Expanded(flex: 5, child: metrics), const SizedBox(width: 16), Expanded(flex: 3, child: pay)]));
        }),
      ),
    );
  }

  String _sp(String iso) {
    if (iso.length < 10) return '–';
    final p = iso.split('-');
    return '${int.parse(p[1])}/${p[2]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({required this.icon, required this.label, this.value, this.child});
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: _blue),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
        const SizedBox(height: 5),
        child ?? Text(value ?? '–', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _navy, fontWeight: FontWeight.w600)),
      ])),
    ]),
  );
}

class _PayrollMetric extends StatelessWidget {
  const _PayrollMetric({required this.icon, required this.label, required this.value, this.valueColor = _navy});
  final IconData icon;
  final String label, value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 16, color: _blue), const SizedBox(width: 5), Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12)))]),
      const SizedBox(height: 6),
      Center(child: Text(value, style: TextStyle(color: valueColor, fontSize: 22, fontWeight: FontWeight.w800))),
    ]),
  );
}

class _PayValue extends StatelessWidget {
  const _PayValue({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
    const SizedBox(height: 4),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
  ]);
}

class _LopDot extends StatelessWidget {
  const _LopDot({required this.isLop});
  final bool isLop;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: isLop ? _redLt : _greenLt,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      isLop ? 'Yes' : 'No',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isLop ? _red : _green,
      ),
    ),
  );
}

class _ReqStatus extends StatelessWidget {
  const _ReqStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final (bg, fg) = s == 'approved'
        ? (_greenLt, _green)
        : s == 'rejected'
        ? (_redLt, _red)
        : (_amberLt, _amber);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _cap(status),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

class _PayStatus extends StatelessWidget {
  const _PayStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final (bg, fg) = s == 'paid'
        ? (_greenLt, _green)
        : s == 'pending'
        ? (_orangeLt, _orange)
        : (const Color(0xFFF0F2F7), _muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _cap(status),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(message, style: const TextStyle(color: _muted, fontSize: 14)),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 40, color: _red),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            style: const TextStyle(color: _muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ),
  );
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
