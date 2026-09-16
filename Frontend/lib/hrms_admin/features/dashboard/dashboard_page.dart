import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/hrms_dashboard_api.dart';
import '../../shared/widgets/admin_top_nav.dart';
import 'widgets/attendance_grid.dart';
import 'widgets/manage_calendar_dialog.dart';
import 'widgets/manage_time_dialog.dart';

const _navy = Color(0xFF07186F);
const _blue = Color(0xFF0767F2);
const _green = Color(0xFF008A32);
const _red = Color(0xFFE00012);
const _orange = Color(0xFFFF6A00);
const _purple = Color(0xFF7E20E8);
const _line = Color(0xFFD9E2F1);
const _muted = Color(0xFF52638E);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  static Widget builder(BuildContext context) => const DashboardPage();

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ScrollController _tableScrollController = ScrollController();
  bool _monthly = true;
  late String _month;
  late int _year;
  int _weeklyOffDay = DateTime.sunday;
  List<Map<String, dynamic>> _calendarOverrides = [];
  List<_EmployeeAttendance> _employees = [];
  int _kpiTotal = 0;
  int _kpiPresent = 0;
  int _kpiAbsent = 0;
  int _kpiLate = 0;
  bool _loading = true;
  String? _error;

  static const _monthCodes = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _year = today.year;
    _month = _monthCodes[today.month - 1];
    _boot();
  }

  Future<void> _boot() async {
    await _loadCalendarSettings();
    await _loadDashboard();
  }

  Future<void> _loadCalendarSettings() async {
    final weeklyOff = await CalendarStore.loadWeeklyOff();
    final overrides = await CalendarStore.loadOverrides();
    if (!mounted) return;
    setState(() {
      _weeklyOffDay = weeklyOff;
      _calendarOverrides = overrides;
    });
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await HrmsDashboardApi.month(
        year: _year,
        month: _monthCodes.indexOf(_month) + 1,
        weeklyOff: _weeklyOffDay,
      );
      final kpis = Map<String, dynamic>.from(data['kpis'] as Map? ?? {});
      final items = (data['employees'] as List? ?? [])
          .whereType<Map>()
          .map((item) =>
              _EmployeeAttendance.fromApi(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        _employees = items;
        _kpiTotal = _asInt(kpis['totalEmployees']);
        _kpiPresent = _asInt(kpis['present']);
        _kpiAbsent = _asInt(kpis['absent']);
        _kpiLate = _asInt(kpis['late']);
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  int _asInt(dynamic value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  Future<void> _openManageTime() async {
    await showManageTimeDialog(context);
  }
  Future<void> _openManageCalendar() async {
    final saved = await showManageCalendarDialog(context);
    if (saved) {
      await _loadCalendarSettings();
      await _loadDashboard();
    }
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
      return _MobileDashboard(
        monthly: _monthly,
        onMonthlyChanged: (value) => setState(() => _monthly = value),
        year: _year,
        onYearChanged: (value) {
          setState(() => _year = value);
          _loadDashboard();
        },
        onManageCalendar: _openManageCalendar,
        total: _kpiTotal,
        present: _kpiPresent,
        absent: _kpiAbsent,
        late: _kpiLate,
        loading: _loading,
        error: _error,
        onRetry: _loadDashboard,
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const _DashboardTopBar(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                width < 1100 ? 20 : 32,
                22,
                width < 1100 ? 20 : 32,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageHeading(),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 116,
                    child: _KpiRow(
                      monthly: _monthly,
                      total: _kpiTotal,
                      present: _kpiPresent,
                      absent: _kpiAbsent,
                      late: _kpiLate,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Expanded(child: _attendancePanel()),
                  if (_monthly) ...[
                    const SizedBox(height: 12),
                    SizedBox(height: 50, child: _monthSelector()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageHeading() => AdminPageHeader(
        title: 'Admin Dashboard',
        breadcrumb: 'Dashboard',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeriodToggle(
              monthly: _monthly,
              onChanged: (value) => setState(() => _monthly = value),
            ),
            const SizedBox(width: 14),
            _YearSelector(
              value: _year,
              onChanged: (value) {
                setState(() => _year = value);
                _loadDashboard();
              },
            ),
          ],
        ),
      );

  Widget _attendancePanel() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFBFD2F2)),
          borderRadius: BorderRadius.circular(9),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 68,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: _blue, size: 25),
                    const SizedBox(width: 18),
                    Text(
                      _monthly
                          ? '${_monthName(_month)} $_year Attendance'
                          : '$_year Yearly Attendance',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 30),
                    const Expanded(child: _AttendanceLegend()),
                    const SizedBox(width: 14),
                    OutlinedButton.icon(
                      onPressed: _openManageTime,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: Color(0xFFBFD2F2)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.schedule_rounded, size: 23),
                      label: const Text('Manage Time', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _openManageCalendar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: const BorderSide(color: _blue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.edit_calendar_outlined, size: 23),
                      label: const Text('Manage Calendar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: _line),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child:
                                    Text(_error!, textAlign: TextAlign.center),
                              ),
                              FilledButton(
                                onPressed: _loadDashboard,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _monthly
                          ? _AttendanceTable(
                              horizontalController: _tableScrollController,
                              year: _year,
                              month: _monthCodes.indexOf(_month) + 1,
                              weeklyOffDay: _weeklyOffDay,
                              overrides: _calendarOverrides,
                              employees: _employees,
                            )
                          : _YearlyAttendanceSummary(employees: _employees),
            ),
          ],
        ),
      );

  Widget _monthSelector() {
    const months = _monthCodes;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final month in months)
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _month = month);
                  _loadDashboard();
                },
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: month == _month ? _blue : Colors.white,
                    border: const Border(left: BorderSide(color: _line)),
                    borderRadius: month == _month
                        ? BorderRadius.circular(7)
                        : BorderRadius.zero,
                  ),
                  child: Text(
                    '$month $_year',
                    style: TextStyle(
                      color: month == _month ? Colors.white : _navy,
                      fontSize: 12,
                      fontWeight:
                          month == _month ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _monthName(String month) => const {
        'Jan': 'January',
        'Feb': 'February',
        'Mar': 'March',
        'Apr': 'April',
        'May': 'May',
        'Jun': 'June',
        'Jul': 'July',
        'Aug': 'August',
        'Sep': 'September',
        'Oct': 'October',
        'Nov': 'November',
        'Dec': 'December',
      }[month]!;
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.monthly,
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
  });

  final bool monthly;
  final int total, present, absent, late;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _KpiCard(
              label: 'Total Employees',
              value: '$total',
              subtitle: 'Current',
              color: _blue,
              icon: Icons.groups_2_outlined,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _KpiCard(
              label: 'Present',
              value: '$present',
              subtitle: monthly ? 'This Month' : 'This Year',
              color: _green,
              icon: Icons.check_rounded,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _KpiCard(
              label: 'Absent',
              value: '$absent',
              subtitle: monthly ? 'This Month' : 'This Year',
              color: _red,
              icon: Icons.person_off_outlined,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _KpiCard(
              label: 'Late',
              value: '$late',
              subtitle: monthly ? 'This Month' : 'This Year',
              color: _orange,
              icon: Icons.schedule_rounded,
            ),
          ),
        ],
      );
}

class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable({
    required this.horizontalController,
    required this.year,
    required this.month,
    required this.weeklyOffDay,
    required this.overrides,
    required this.employees,
  });

  final ScrollController horizontalController;
  final int year;
  final int month;
  final int weeklyOffDay;
  final List<Map<String, dynamic>> overrides;
  final List<_EmployeeAttendance> employees;

  @override
  Widget build(BuildContext context) {
    final days =
        List.generate(DateTime(year, month + 1, 0).day, (index) => index + 1);
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (employees.isEmpty) {
      return const Center(child: Text('No employees to show.'));
    }
    return AttendanceGrid(
      days: days,
      dayLabels: [
        for (final day in days)
          weekdayNames[DateTime(year, month, day).weekday - 1]
      ],
      rows: [
        for (final employee in employees)
          AttendanceRowData(
            name: employee.name,
            designation: employee.designation,
            days: [
              for (var i = 0; i < days.length; i++)
                AttendanceDayMark(_markForDay(
                  i,
                  employee,
                  year,
                  month,
                  weeklyOffDay,
                  overrides,
                ))
            ],
            present: employee.present,
            late: employee.late,
            excused: employee.excused,
            unexcused: employee.unexcused,
            halfLeave: employee.halfLeave,
            salaryPerMonth: employee.salary,
            totalSalaryAfterLeaves:
                '${employee.daysPaid} ${employee.afterLeaves}',
            updatedSalary: employee.updatedSalary,
          ),
      ],
    );
  }

  String _markForDay(
    int index,
    _EmployeeAttendance employee,
    int year,
    int month,
    int weeklyOffDay,
    List<Map<String, dynamic>> overrides,
  ) {
    final day = index + 1;
    final dateKey =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final changes =
        overrides.where((item) => item['date'] == dateKey).toList();
    if (changes.isNotEmpty) {
      final status = changes.last['status'] as String;
      if (status == 'Weekly Off') return 'OFF';
      if (status == 'Holiday') return 'H';
    }
    if (index < employee.days.length) return employee.days[index];
    if (DateTime(year, month, day).weekday == weeklyOffDay) return 'OFF';
    return '';
  }
}

class _YearlyAttendanceSummary extends StatelessWidget {
  const _YearlyAttendanceSummary({required this.employees});
  final List<_EmployeeAttendance> employees;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const headerHeight = 52.0;
          if (employees.isEmpty) {
            return const Center(child: Text('No employees to show.'));
          }
          return SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(constraints.maxWidth, 1050),
                child: Column(
                  children: [
                    const SizedBox(
                        height: headerHeight, child: _YearlyHeaderRow()),
                    for (final employee in employees)
                      SizedBox(
                        height: 42,
                        child: _YearlyEmployeeRow(employee: employee),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _EmployeeAttendance {
  const _EmployeeAttendance({
    required this.name,
    required this.designation,
    required this.present,
    required this.late,
    required this.halfLeave,
    required this.excused,
    required this.unexcused,
    required this.salary,
    required this.daysPaid,
    required this.afterLeaves,
    required this.updatedSalary,
    required this.days,
  });

  final String name;
  final String designation;
  final int present;
  final int late;
  final int halfLeave;
  final int excused;
  final int unexcused;
  final String salary;
  final String daysPaid;
  final String afterLeaves;
  final String updatedSalary;
  final List<String> days;

  factory _EmployeeAttendance.fromApi(Map<String, dynamic> json) {
    int asInt(dynamic value) =>
        value is int ? value : int.tryParse('$value') ?? 0;
    return _EmployeeAttendance(
      name: (json['name'] ?? '').toString(),
      designation: (json['designation'] ?? '').toString(),
      present: asInt(json['present']),
      late: asInt(json['late']),
      halfLeave: asInt(json['halfLeave']),
      excused: asInt(json['excused']),
      unexcused: asInt(json['unexcused']),
      salary: (json['salary'] ?? 'Not Set').toString(),
      daysPaid: (json['daysPaid'] ?? '0').toString(),
      afterLeaves: (json['afterLeaves'] ?? '–').toString(),
      updatedSalary: (json['updatedSalary'] ?? 'Not Set').toString(),
      days: (json['days'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class _MobileDashboard extends StatelessWidget {
  const _MobileDashboard({
    required this.monthly,
    required this.onMonthlyChanged,
    required this.year,
    required this.onYearChanged,
    required this.onManageCalendar,
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final bool monthly;
  final ValueChanged<bool> onMonthlyChanged;
  final int year;
  final ValueChanged<int> onYearChanged;
  final VoidCallback onManageCalendar;
  final int total, present, absent, late;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Image.asset('assets/images/godigital_logo.png', height: 44),
          actions: const [
            Icon(Icons.notifications_none_rounded, color: _navy),
            SizedBox(width: 12)
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(error!, textAlign: TextAlign.center),
                        ),
                        FilledButton(
                            onPressed: onRetry, child: const Text('Retry')),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin Dashboard',
                            style: TextStyle(
                                color: _navy,
                                fontSize: 25,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Employee attendance and payroll overview',
                            style: TextStyle(color: _muted)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _PeriodToggle(
                              monthly: monthly,
                              onChanged: onMonthlyChanged,
                            ),
                            _YearSelector(
                                value: year, onChanged: onYearChanged),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 480,
                          child: GridView.count(
                            crossAxisCount: 2,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.15,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: [
                              _KpiCard(
                                  label: 'Total Employees',
                                  value: '$total',
                                  subtitle: 'Current',
                                  color: _blue,
                                  icon: Icons.groups_2_outlined),
                              _KpiCard(
                                  label: 'Present',
                                  value: '$present',
                                  subtitle: monthly ? 'This Month' : 'This Year',
                                  color: _green,
                                  icon: Icons.check_rounded),
                              _KpiCard(
                                  label: 'Absent',
                                  value: '$absent',
                                  subtitle: monthly ? 'This Month' : 'This Year',
                                  color: _red,
                                  icon: Icons.person_off_outlined),
                              _KpiCard(
                                  label: 'Late',
                                  value: '$late',
                                  subtitle: monthly ? 'This Month' : 'This Year',
                                  color: _orange,
                                  icon: Icons.schedule_rounded),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onManageCalendar,
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: const Text('Manage Calendar'),
                          ),
                        ),
                      ],
                    ),
                  ),
      );
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar();

  static const items = <(String, String)>[
    ('Dashboard', '/admin/dashboard'),
    ('Employees', '/admin/employees'),
    ('Approvals', '/admin/approvals'),
    ('Payroll', '/admin/payroll'),
    ('Tracking', '/admin/tracking'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _line)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0E07186F),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images/godigital_logo.png',
              width: 160,
              height: 68,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(width: 30),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFC9D9F3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in items)
                          _DashboardNavItem(
                            label: item.$1,
                            route: item.$2,
                            active: item.$1 == 'Dashboard',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 30),
            const AdminNotificationBell(mobile: false),
            const SizedBox(width: 25),
            const AdminLogoutButton(),
          ],
        ),
      );
}

class _DashboardNavItem extends StatelessWidget {
  const _DashboardNavItem({
    required this.label,
    required this.route,
    required this.active,
  });

  final String label;
  final String route;
  final bool active;

  @override
  Widget build(BuildContext context) => Material(
        color: active ? _blue : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: active
              ? null
              : () => Navigator.pushReplacementNamed(context, route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _navy,
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.monthly, required this.onChanged});

  final bool monthly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: 224,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFC9D9F3)),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            _PeriodButton(
              label: 'Monthly',
              active: monthly,
              onTap: () => onChanged(true),
            ),
            _PeriodButton(
              label: 'Yearly',
              active: !monthly,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      );
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: double.infinity,
            alignment: Alignment.center,
            color: active ? _blue : Colors.white,
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
}

class _YearSelector extends StatelessWidget {
  const _YearSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFC9D9F3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, color: _blue, size: 23),
            const SizedBox(width: 14),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                borderRadius: BorderRadius.circular(10),
                icon: const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: _navy, size: 20),
                ),
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                items: List.generate(
                  7,
                  (index) => DateTime.now().year - 3 + index,
                )
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text('$year'),
                      ),
                    )
                    .toList(),
                onChanged: (year) {
                  if (year != null) onChanged(year);
                },
              ),
            ),
          ],
        ),
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    this.subtitle = 'Today',
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 245;
          final iconSize = compact ? 44.0 : 54.0;
          return Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: color.withValues(alpha: .27)),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .22),
                        blurRadius: 0,
                        spreadRadius: compact ? 5 : 8,
                      ),
                    ],
                  ),
                  child:
                      Icon(icon, color: Colors.white, size: compact ? 24 : 30),
                ),
                SizedBox(width: compact ? 12 : 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: color,
                              fontSize: compact ? 11 : 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(value,
                          style: TextStyle(
                              color: _navy,
                              fontSize: compact ? 20 : 24,
                              fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          style: TextStyle(
                              color: _navy, fontSize: compact ? 10 : 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _AttendanceLegend extends StatelessWidget {
  const _AttendanceLegend();

  static const items = <(String, String, Color)>[
    ('P', 'Present', _green),
    ('A', 'Absent', Color(0xFFB0000B)),
    ('L', 'Late', _orange),
    ('H', 'Holiday', _purple),
    ('L', 'Leave', _purple),
    ('HL', 'Half Leave', _purple),
    ('OFF', 'Weekly Off (Sunday)', Color(0xFF8C9AB8)),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in items) ...[
              Container(
                width: item.$1.length > 2 ? 25 : 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.$3.withValues(alpha: item.$1 == 'OFF' ? .18 : 1),
                  shape: item.$1 == 'OFF'
                      ? BoxShape.rectangle
                      : BoxShape.circle,
                  borderRadius:
                      item.$1 == 'OFF' ? BorderRadius.circular(10) : null,
                ),
                child: Text(item.$1,
                    style: TextStyle(
                        color: item.$1 == 'OFF' ? _navy : Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 7),
              Text(item.$2,
                  style: const TextStyle(color: _navy, fontSize: 10)),
              const SizedBox(width: 20),
            ],
          ],
        ),
      );
}

class _YearlyHeaderRow extends StatelessWidget {
  const _YearlyHeaderRow();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFBFCFE),
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: const Row(
          children: [
            _YearHeaderCell('Employee Name', flex: 22),
            _YearHeaderCell('Designation', flex: 20),
            _YearHeaderCell('Present', flex: 11, color: _green),
            _YearHeaderCell('Absent', flex: 11, color: _red),
            _YearHeaderCell('Late', flex: 11, color: _orange),
            _YearHeaderCell('Half Leave', flex: 11, color: _purple),
            _YearHeaderCell('Annual Salary', flex: 14),
          ],
        ),
      );
}

class _YearlyEmployeeRow extends StatelessWidget {
  const _YearlyEmployeeRow({required this.employee});

  final _EmployeeAttendance employee;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            _YearBodyCell(
              flex: 22,
              alignment: Alignment.centerLeft,
              child: Text(
                employee.name,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _YearBodyCell(
              flex: 20,
              alignment: Alignment.centerLeft,
              child: Text(
                employee.designation,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
            _YearStatCell('${employee.present}', _green, 11),
            _YearStatCell('${employee.unexcused}', _red, 11),
            _YearStatCell('${employee.late}', _orange, 11),
            _YearStatCell('${employee.halfLeave}', _purple, 11),
            _YearBodyCell(
              flex: 14,
              child: Text(
                _annualSalary(employee.salary),
                style: const TextStyle(
                  color: _navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );

  static String _annualSalary(String salary) {
    final amount = int.tryParse(salary.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null) return '–';
    final text = (amount * 12).toString();
    final buffer = StringBuffer();
    for (var index = 0; index < text.length; index++) {
      if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
      buffer.write(text[index]);
    }
    return '₹$buffer';
  }
}

class _YearHeaderCell extends StatelessWidget {
  const _YearHeaderCell(this.text, {required this.flex, this.color = _navy});

  final String text;
  final int flex;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

class _YearBodyCell extends StatelessWidget {
  const _YearBodyCell({
    required this.flex,
    required this.child,
    this.alignment = Alignment.center,
  });

  final int flex;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Container(
          height: double.infinity,
          alignment: alignment,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: _line)),
          ),
          child: child,
        ),
      );
}

class _YearStatCell extends StatelessWidget {
  const _YearStatCell(this.value, this.color, this.flex);

  final String value;
  final Color color;
  final int flex;

  @override
  Widget build(BuildContext context) => _YearBodyCell(
        flex: flex,
        child: Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
