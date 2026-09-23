import 'package:flutter/material.dart';
import '../../../services/hrms_employee_profile_api.dart';

// ── palette ───────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF061457);
const _blue    = Color(0xFF075EF7);
const _blueLt  = Color(0xFFEEF3FF);
const _page    = Color(0xFFF4F6FB);
const _border  = Color(0xFFE3E8F4);
const _muted   = Color(0xFF8A94A6);
const _green   = Color(0xFF148B1A);
const _greenLt = Color(0xFFE8F7E9);
const _amber   = Color(0xFFD97706);
const _amberLt = Color(0xFFFFF8E6);
const _red     = Color(0xFFD42B2B);
const _redLt   = Color(0xFFFDEAEA);
const _orange  = Color(0xFFC95800);
const _orangeLt= Color(0xFFFFF1E8);
const _purple  = Color(0xFF6B21A8);
const _purpleLt= Color(0xFFF3E8FF);

const _months = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
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
  late int _year  = DateTime.now().year;
  late int _month = DateTime.now().month;

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final d = await HrmsEmployeeProfileApi.getProfile(
        widget.profileId,
        year: _year,
        month: _month,
        employeeUserId: widget.employeeUserId,
      );
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) { _month = 1; _year++; }
      if (_month < 1)  { _month = 12; _year--; }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _blue));
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);
    if (_data == null)  return const Center(child: Text('No data'));

    final emp     = Map<String, dynamic>.from(_data!['employee']       as Map? ?? {});
    final summary = Map<String, dynamic>.from(_data!['summary']        as Map? ?? {});
    final daily   = (_data!['dailyAttendance'] as List? ?? []).cast<Map<String, dynamic>>();
    final leaves  = (_data!['leaves']          as List? ?? []).cast<Map<String, dynamic>>();
    final payroll = (_data!['payrollHistory']  as List? ?? []).cast<Map<String, dynamic>>();

    return Column(
      children: [
        _TopBar(
          emp: emp,
          year: _year, month: _month,
          onBack: () => Navigator.pop(context),
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),
        Expanded(
          child: Column(
            children: [
              _OverviewCard(summary: summary, year: _year, month: _month),
              const SizedBox(height: 16),
              // flat tab bar
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    TabBar(
                      controller: _tab,
                      labelColor: _blue,
                      unselectedLabelColor: _muted,
                      indicatorColor: _blue,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                      tabs: const [
                        Tab(text: 'Attendance'),
                        Tab(text: 'Leaves & Permissions'),
                        Tab(text: 'Payroll History'),
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
                    _AttendanceTab(days: daily, month: _month, year: _year),
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
// Top bar — matches mockup exactly
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.emp,
    required this.year,
    required this.month,
    required this.onBack,
    required this.onPrev,
    required this.onNext,
  });
  final Map<String, dynamic> emp;
  final int year, month;
  final VoidCallback onBack, onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final name    = emp['name']         as String? ?? '';
    final code    = emp['employeeCode'] as String? ?? '';
    final dept    = emp['department']   as String? ?? '';
    final mode    = emp['workMode']     as String? ?? '';
    final status  = emp['status']       as String? ?? 'Active';
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final inactive = status.toLowerCase() == 'inactive';
    final active   = status.toLowerCase() == 'active';
    final sc = inactive ? _red : active ? _green : _amber;
    final sb = inactive ? _redLt : active ? _greenLt : _amberLt;

    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          // back arrow
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, size: 22, color: _navy),
            ),
          ),
          const SizedBox(width: 14),
          // avatar
          Container(
            width: 48, height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: _blueLt, shape: BoxShape.circle),
            child: Text(initial,
              style: const TextStyle(
                  color: _blue, fontSize: 19, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          // name
          Text(name,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(width: 4),
          // meta with pipe separators
          if (code.isNotEmpty) ...[
            _pipe(),
            Text('Employee ID $code',
                style: const TextStyle(fontSize: 14, color: _muted)),
          ],
          if (dept.isNotEmpty) ...[
            _pipe(),
            Text(dept, style: const TextStyle(fontSize: 14, color: _muted)),
          ],
          if (mode.isNotEmpty) ...[
            _pipe(),
            Text(mode, style: const TextStyle(fontSize: 14, color: _muted)),
          ],
          _pipe(),
          // status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
                color: sb, borderRadius: BorderRadius.circular(20)),
            child: Text(status,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: sc)),
          ),
          const Spacer(),
          // dropdown-style month picker
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onPrev,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(Icons.chevron_left, size: 20, color: _muted),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.calendar_today_outlined, size: 16, color: _muted),
                const SizedBox(width: 8),
                Text('${_months[month - 1]} $year',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onNext,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(Icons.chevron_right, size: 20, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pipe() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Container(width: 1, height: 18, color: _border),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview section — individual KPI cards (matches Clock Logs style)
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewCard extends StatelessWidget {
  const _OverviewCard(
      {required this.summary, required this.year, required this.month});
  final Map<String, dynamic> summary;
  final int year, month;

  @override
  Widget build(BuildContext context) {
    final ps      = (summary['payrollStatus'] as String? ?? 'draft').toLowerCase();
    final psLabel = ps.isEmpty ? 'Draft' : ps[0].toUpperCase() + ps.substring(1);
    final psColor = ps == 'paid' ? _green : ps == 'pending' ? _orange : _muted;
    final netPay  = summary['netPayLabel'] as String? ?? '–';

    return Container(
      color: _page,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // section label
          Text('${_months[month - 1]} $year overview',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _muted)),
          const SizedBox(height: 10),
          // top row — 4 KPI cards
          Row(children: [
            _kpiCard('Working days',   '${summary['workingDays'] ?? 0}', _blue,   null,       null),
            const SizedBox(width: 12),
            _kpiCard('Paid days',      '${summary['paidDays']    ?? 0}', _navy,   'of ${summary['workingDays'] ?? 0} working', _muted),
            const SizedBox(width: 12),
            _kpiCard('Payroll status', psLabel,                           psColor, null,       null),
            const SizedBox(width: 12),
            _kpiCard('Net pay',        netPay,                            _navy,   'this month', _green),
          ]),
          const SizedBox(height: 12),
          // bottom row — 5 attendance cards
          Row(children: [
            _kpiCard('Present',    '${summary['present']     ?? 0}', _green,  null, null),
            const SizedBox(width: 12),
            _kpiCard('Late',       '${summary['late']        ?? 0}', _amber,  null, null),
            const SizedBox(width: 12),
            _kpiCard('Absent',     '${summary['absent']      ?? 0}', _red,    null, null),
            const SizedBox(width: 12),
            _kpiCard('LOP',        '${summary['lopDays']     ?? 0}', _red,    null, null),
            const SizedBox(width: 12),
            _kpiCard('Permission', '${summary['permissions'] ?? 0}', _purple, null, null),
          ]),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, Color valueColor,
      String? sub, Color? subColor) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: const TextStyle(fontSize: 12, color: _muted,
                    fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                    color: valueColor, height: 1.1)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub,
                  style: TextStyle(fontSize: 12,
                      color: subColor ?? _muted)),
              ],
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance tab
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab(
      {required this.days, required this.month, required this.year});
  final List<Map<String, dynamic>> days;
  final int month, year;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const _Empty('No attendance records for this month');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      children: [
        // section title
        Row(children: [
          const Text('Daily attendance',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: _border),
          const SizedBox(width: 16),
          Text('${_months[month - 1]} $year',
            style: const TextStyle(fontSize: 14, color: _muted)),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (ctx, bc) {
          final minW = bc.maxWidth.isFinite ? bc.maxWidth : 1000.0;
          return _FlatTable(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minW),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF2F5FB)),
                  headingTextStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _muted),
                  dataTextStyle:
                      const TextStyle(fontSize: 14, color: _navy),
                  columnSpacing: 16,
                  horizontalMargin: 24,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  dividerThickness: 1,
                  columns: const [
                    DataColumn(label: SizedBox(width: 130, child: Text('Date'))),
                    DataColumn(label: SizedBox(width: 90,  child: Text('Check In'))),
                    DataColumn(label: SizedBox(width: 90,  child: Text('Check Out'))),
                    DataColumn(label: SizedBox(width: 80,  child: Text('Worked'))),
                    DataColumn(label: SizedBox(width: 90,  child: Text('Break Start'))),
                    DataColumn(label: SizedBox(width: 90,  child: Text('Break End'))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Break'))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Status'))),
                    DataColumn(label: SizedBox(width: 56,  child: Text('LOP'))),
                    DataColumn(label: SizedBox(width: 80,  child: Text('Method'))),
                  ],
                  rows: days.map(_row).toList(),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  DataRow _row(Map<String, dynamic> d) {
    final isOff     = d['isWeeklyOff'] == true;
    final dateLabel = _fmtDate(d['date'] as String? ?? '');

    if (isOff) {
      return DataRow(cells: [
        DataCell(SizedBox(width: 130,
            child: Text(dateLabel,
                style: const TextStyle(
                    color: _blue, fontWeight: FontWeight.w500)))),
        ..._dash(90), ..._dash(90), ..._dash(80),
        ..._dash(90), ..._dash(90), ..._dash(110),
        DataCell(SizedBox(width: 110,
            child: const Text('Weekly Off',
                style: TextStyle(color: _muted, fontSize: 13)))),
        ..._dash(56), ..._dash(80),
      ]);
    }

    final overdue  = (d['breakOverdue']  as num? ?? 0).toInt();
    final breakMin = (d['breakMinutes']  as num? ?? 0).toInt();

    return DataRow(cells: [
      DataCell(SizedBox(width: 130,
          child: Text(dateLabel,
              style: const TextStyle(
                  color: _blue, fontWeight: FontWeight.w500)))),
      DataCell(SizedBox(width: 90,  child: Text(d['checkIn']     as String? ?? '–'))),
      DataCell(SizedBox(width: 90,  child: Text(d['checkOut']    as String? ?? '–'))),
      DataCell(SizedBox(width: 80,  child: Text(d['workedLabel'] as String? ?? '–'))),
      DataCell(SizedBox(width: 90,  child: Text(d['breakStart']  as String? ?? '–'))),
      DataCell(SizedBox(width: 90,  child: Text(d['breakEnd']    as String? ?? '–'))),
      DataCell(SizedBox(width: 110,
          child: breakMin > 0
              ? _BreakPill(minutes: breakMin, overdue: overdue)
              : const Text('–', style: TextStyle(color: _muted)))),
      DataCell(SizedBox(width: 110,
          child: _StatusPill(status: d['status'] as String? ?? ''))),
      DataCell(SizedBox(width: 56,
          child: _LopDot(isLop: d['isLop'] == true))),
      DataCell(SizedBox(width: 80,
          child: Text(d['method'] as String? ?? '–',
              style: const TextStyle(fontSize: 13, color: _muted)))),
    ]);
  }

  List<DataCell> _dash(double w) => [
    DataCell(SizedBox(width: w,
        child: const Text('–', style: TextStyle(color: _muted))))
  ];

  String _fmtDate(String iso) {
    if (iso.length < 10) return iso;
    final p = iso.split('-');
    if (p.length < 3) return iso;
    const mons = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const wds  = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    final m  = int.tryParse(p[1]) ?? 1;
    final dy = int.tryParse(p[2]) ?? 1;
    final wd = DateTime.utc(int.parse(p[0]), m, dy).weekday % 7;
    return '${wds[wd]}, ${p[2]} ${mons[m - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leaves tab
// ─────────────────────────────────────────────────────────────────────────────
class _LeavesTab extends StatelessWidget {
  const _LeavesTab(
      {required this.leaves, required this.month, required this.year});
  final List<Map<String, dynamic>> leaves;
  final int month, year;

  @override
  Widget build(BuildContext context) {
    if (leaves.isEmpty) return const _Empty('No leave or permission records');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      children: [
        Row(children: [
          const Text('Leaves & Permissions',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: _border),
          const SizedBox(width: 16),
          Text('${_months[month - 1]} $year',
              style: const TextStyle(fontSize: 14, color: _muted)),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (ctx, bc) {
          final minW = bc.maxWidth.isFinite ? bc.maxWidth : 920.0;
          return _FlatTable(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minW),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF2F5FB)),
                  headingTextStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
                  dataTextStyle:
                      const TextStyle(fontSize: 14, color: _navy),
                  columnSpacing: 16,
                  horizontalMargin: 24,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: SizedBox(width: 130, child: Text('Type'))),
                    DataColumn(label: SizedBox(width: 150, child: Text('Period'))),
                    DataColumn(label: SizedBox(width: 90,  child: Text('Duration'))),
                    DataColumn(label: SizedBox(width: 170, child: Text('Reason'))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Applied On'))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Reviewed By'))),
                    DataColumn(label: SizedBox(width: 100, child: Text('Status'))),
                    DataColumn(label: SizedBox(width: 56,  child: Text('LOP'))),
                  ],
                  rows: leaves.map(_row).toList(),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  DataRow _row(Map<String, dynamic> l) {
    final from   = l['fromDate']  as String? ?? '';
    final to     = l['toDate']    as String? ?? '';
    final period = (from == to || to.isEmpty)
        ? _sd(from)
        : '${_sd(from)} – ${_sd(to)}';
    final days = (l['durationDays'] as num? ?? 1).toInt();
    final dt   = (l['durationType'] as String? ?? '').toLowerCase();
    final dur  = dt == 'half day' ? 'Half Day' : (days == 1 ? '1 day' : '$days days');
    final isPerm = l['isPermission'] == true;

    return DataRow(cells: [
      DataCell(SizedBox(width: 130,
          child: _LeaveTypeBadge(
              type: l['type'] as String? ?? '',
              isPermission: isPerm))),
      DataCell(SizedBox(width: 150, child: Text(period))),
      DataCell(SizedBox(width: 90,  child: Text(dur))),
      DataCell(SizedBox(width: 170,
          child: Text(l['reason'] as String? ?? '–',
              overflow: TextOverflow.ellipsis))),
      DataCell(SizedBox(width: 110,
          child: Text(_sd(l['appliedOn'] as String? ?? '')))),
      DataCell(SizedBox(width: 110,
          child: Text(l['reviewedBy']?.toString() ?? '–'))),
      DataCell(SizedBox(width: 100,
          child: _ReqStatus(status: l['status'] as String? ?? 'pending'))),
      DataCell(SizedBox(width: 56,
          child: _LopDot(isLop: l['isLopImpact'] == true))),
    ]);
  }

  String _sd(String iso) {
    if (iso.length < 10) return '–';
    final p = iso.split('-');
    if (p.length < 3) return iso;
    const mons = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final m = int.tryParse(p[1]) ?? 1;
    return '${p[2]} ${mons[m - 1]} ${p[0]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payroll tab
// ─────────────────────────────────────────────────────────────────────────────
class _PayrollTab extends StatelessWidget {
  const _PayrollTab({required this.history});
  final List<Map<String, dynamic>> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const _Empty('No payroll history');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      children: [
        const Row(children: [
          Text('Payroll History',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
          SizedBox(width: 16),
          SizedBox(width: 1, height: 18),
          SizedBox(width: 16),
          Text('Last 6 months',
              style: TextStyle(fontSize: 14, color: _muted)),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (ctx, bc) {
          final minW = bc.maxWidth.isFinite ? bc.maxWidth : 900.0;
          return _FlatTable(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minW),
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF2F5FB)),
                  headingTextStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _muted),
                  dataTextStyle:
                      const TextStyle(fontSize: 14, color: _navy),
                  columnSpacing: 16,
                  horizontalMargin: 24,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: SizedBox(width: 130, child: Text('Month'))),
                    DataColumn(label: SizedBox(width: 120, child: Text('Period'))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Salary'))),
                    DataColumn(label: SizedBox(width: 80,  child: Text('Working'))),
                    DataColumn(label: SizedBox(width: 80,  child: Text('Paid Days'))),
                    DataColumn(label: SizedBox(width: 56,  child: Text('LOP'))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Deduction'))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Net Pay'))),
                    DataColumn(label: SizedBox(width: 100, child: Text('Status'))),
                  ],
                  rows: history.map(_row).toList(),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  DataRow _row(Map<String, dynamic> h) {
    final lop    = (h['lopDays'] as num? ?? 0).toInt();
    final ps     = h['periodStart'] as String? ?? '';
    final pe     = h['periodEnd']   as String? ?? '';
    final period = (ps.isNotEmpty && pe.isNotEmpty)
        ? '${_sp(ps)} – ${_sp(pe)}'
        : '–';

    return DataRow(cells: [
      DataCell(SizedBox(width: 130,
          child: Text(h['monthLabel'] as String? ?? '–',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: _blue)))),
      DataCell(SizedBox(width: 120,
          child: Text(period,
              style: const TextStyle(fontSize: 13, color: _muted)))),
      DataCell(SizedBox(width: 110,
          child: Text(h['salaryLabel'] as String? ?? '–',
              style: const TextStyle(fontWeight: FontWeight.w600)))),
      DataCell(SizedBox(width: 80,  child: Text('${h['workingDays'] ?? 0}'))),
      DataCell(SizedBox(width: 80,  child: Text('${h['paidDays']    ?? 0}'))),
      DataCell(SizedBox(width: 56,
          child: Text('$lop',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: lop > 0 ? _red : _muted)))),
      DataCell(SizedBox(width: 110,
          child: Text(
              lop > 0 ? (h['deductionsLabel'] as String? ?? '–') : '–',
              style: TextStyle(color: lop > 0 ? _red : _muted)))),
      DataCell(SizedBox(width: 110,
          child: Text(h['netPayLabel'] as String? ?? '–',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: _blue)))),
      DataCell(SizedBox(width: 100,
          child: _PayStatus(status: h['status'] as String? ?? 'draft'))),
    ]);
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

// Flat table card — white, rounded, border, no header
class _FlatTable extends StatelessWidget {
  const _FlatTable({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _BreakPill extends StatelessWidget {
  const _BreakPill({required this.minutes, required this.overdue});
  final int minutes, overdue;
  @override
  Widget build(BuildContext context) {
    final over = overdue > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: over ? _redLt : _blueLt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(over ? '${minutes}m +${overdue}m over' : '${minutes}m',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: over ? _red : _blue)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  static const _map = <String, List<Color>>{
    'present':    [_greenLt, _green],
    'late':       [_amberLt, _amber],
    'absent':     [_redLt,   _red],
    'early_exit': [_orangeLt,_orange],
    'leave':      [_purpleLt,_purple],
    'no_record':  [Color(0xFFF0F2F7), _muted],
  };

  @override
  Widget build(BuildContext context) {
    final c = _map[status] ?? [const Color(0xFFF0F2F7), _muted];
    final label = status.replaceAll('_', ' ').split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration:
          BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: c[1])),
    );
  }
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
    child: Text(isLop ? 'Yes' : 'No',
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isLop ? _red : _green)),
  );
}

class _LeaveTypeBadge extends StatelessWidget {
  const _LeaveTypeBadge({required this.type, required this.isPermission});
  final String type;
  final bool isPermission;
  @override
  Widget build(BuildContext context) {
    final color = isPermission ? _blue : _purple;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(type,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(_cap(status),
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
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
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(_cap(status),
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child:
        Text(message, style: const TextStyle(color: _muted, fontSize: 14)),
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
          child: Text(message,
              style: const TextStyle(color: _muted, fontSize: 13),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );
}

String _cap(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
