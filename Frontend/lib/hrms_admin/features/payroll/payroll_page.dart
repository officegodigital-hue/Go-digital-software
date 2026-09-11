import 'package:flutter/material.dart';

import '../../../services/hrms_payroll_api.dart';
import '../../shared/widgets/admin_top_nav.dart';

abstract final class _PayrollColors {
  static const blue = Color(0xFF075EF7);
  static const navy = Color(0xFF061457);
  static const page = Color(0xFFF7F9FD);
}

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key});

  static Widget builder(BuildContext context) => const PayrollPage();

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  late int year;
  late int month;
  String employee = 'All Employees';
  String status = 'All Status';
  List<_PayrollRow> rows = [];
  List<String> employeeNames = const ['All Employees'];
  List<_MonthOption> months = [];
  String kpiTotal = '₹0';
  int kpiEmployees = 0;
  int kpiPaid = 0;
  int kpiPending = 0;
  bool loading = true;
  bool generating = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    year = now.year;
    month = now.month;
    _load();
  }

  String get _monthKey => '$year-${month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await HrmsPayrollApi.list(
        year: year,
        month: month,
        employee: employee,
        status: status,
      );
      final items = (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => _PayrollRow.fromApi(Map<String, dynamic>.from(item)))
          .toList();
      final kpis = Map<String, dynamic>.from(data['kpis'] as Map? ?? {});
      final names = <String>{'All Employees'};
      names.addAll((data['employees'] as List? ?? []).map((e) => e.toString()));
      final monthItems = (data['months'] as List? ?? [])
          .whereType<Map>()
          .map((item) => _MonthOption.fromApi(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        rows = items;
        employeeNames = names.toList();
        if (!employeeNames.contains(employee)) employee = 'All Employees';
        months = monthItems;
        year = _asInt(data['year'], year);
        month = _asInt(data['month'], month);
        kpiTotal = (kpis['totalPayrollLabel'] ?? '₹0').toString();
        kpiEmployees = _asInt(kpis['employees'], 0);
        kpiPaid = _asInt(kpis['paid'], 0);
        kpiPending = _asInt(kpis['pending'], 0) + _asInt(kpis['draft'], 0);
        loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        error = err.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }

  Future<void> _generate() async {
    setState(() => generating = true);
    try {
      await HrmsPayrollApi.generate(year: year, month: month);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payroll generated. You can now mark rows as paid.')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> _markPaid(_PayrollRow row) async {
    if (row.itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Generate payroll for this month first.')),
      );
      return;
    }
    try {
      await HrmsPayrollApi.markPaid(row.itemId!);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: _PayrollColors.page,
      body: Column(
        children: [
          const AdminTopNav(activeRoute: '/admin/payroll'),
          Expanded(
            child: loading && rows.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : error != null && rows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(error!, textAlign: TextAlign.center),
                            ),
                            FilledButton(
                                onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                            mobile ? 16 : 28, 18, mobile ? 16 : 28, 28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1580),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PayrollHeader(
                                  generating: generating,
                                  onGenerate: _generate,
                                ),
                                const SizedBox(height: 17),
                                _PayrollKpis(
                                  total: kpiTotal,
                                  employees: kpiEmployees,
                                  paid: kpiPaid,
                                  pending: kpiPending,
                                ),
                                const SizedBox(height: 16),
                                if (loading)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: LinearProgressIndicator(minHeight: 2),
                                  ),
                                _PayrollPanel(
                                  monthKey: _monthKey,
                                  months: months,
                                  employee: employee,
                                  status: status,
                                  employees: employeeNames,
                                  rows: rows,
                                  onMonthChanged: (value) {
                                    if (value == null) return;
                                    final parts = value.split('-');
                                    year = int.parse(parts[0]);
                                    month = int.parse(parts[1]);
                                    _load();
                                  },
                                  onEmployeeChanged: (value) {
                                    employee = value!;
                                    _load();
                                  },
                                  onStatusChanged: (value) {
                                    status = value!;
                                    _load();
                                  },
                                  onReset: () {
                                    employee = 'All Employees';
                                    status = 'All Status';
                                    _load();
                                  },
                                  onMarkPaid: _markPaid,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _MonthOption {
  const _MonthOption({
    required this.year,
    required this.month,
    required this.label,
  });
  final int year, month;
  final String label;
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  factory _MonthOption.fromApi(Map<String, dynamic> json) {
    int asInt(dynamic value) =>
        value is int ? value : int.tryParse('$value') ?? 0;
    return _MonthOption(
      year: asInt(json['year']),
      month: asInt(json['month']),
      label: (json['label'] ?? '').toString(),
    );
  }
}

class _PayrollHeader extends StatelessWidget {
  const _PayrollHeader({required this.generating, required this.onGenerate});
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: AdminPageHeader(title: 'Payroll')),
        FilledButton.icon(
          onPressed: generating ? null : onGenerate,
          icon: generating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.playlist_add_check_rounded),
          label: Text(generating ? 'Generating…' : 'Generate payroll'),
          style: FilledButton.styleFrom(
            backgroundColor: _PayrollColors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _PayrollKpis extends StatelessWidget {
  const _PayrollKpis({
    required this.total,
    required this.employees,
    required this.paid,
    required this.pending,
  });
  final String total;
  final int employees, paid, pending;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PayrollKpi('This month net', total, 'Present + late days vs working days',
          Icons.account_balance_wallet_outlined, _PayrollColors.blue),
      _PayrollKpi('Employees', '$employees', 'Active / on leave staff',
          Icons.groups_outlined, const Color(0xFF158C20)),
      _PayrollKpi('Paid', '$paid', 'Marked paid in MySQL',
          Icons.check_circle_outline_rounded, const Color(0xFF158C20)),
      _PayrollKpi('Unpaid', '$pending', 'Draft or pending rows',
          Icons.pending_actions_outlined, const Color(0xFFFF6500)),
    ];
    return LayoutBuilder(builder: (_, constraints) {
      final columns = constraints.maxWidth < 700
          ? 1
          : constraints.maxWidth < 1100
              ? 2
              : 4;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards
            .map((card) => SizedBox(width: width, child: card))
            .toList(),
      );
    });
  }
}

class _PayrollKpi extends StatelessWidget {
  const _PayrollKpi(
      this.label, this.value, this.caption, this.icon, this.color);
  final String label, value, caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 116,
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E8EF)),
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0C071A72), blurRadius: 16, offset: Offset(0, 6))
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Color(0xFF596176), fontSize: 14)),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF090B12),
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF596176), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 55,
                height: 3,
                decoration: BoxDecoration(
                    color: _PayrollColors.blue,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
      );
}

class _PayrollPanel extends StatelessWidget {
  const _PayrollPanel({
    required this.monthKey,
    required this.months,
    required this.employee,
    required this.status,
    required this.employees,
    required this.rows,
    required this.onMonthChanged,
    required this.onEmployeeChanged,
    required this.onStatusChanged,
    required this.onReset,
    required this.onMarkPaid,
  });

  final String monthKey;
  final List<_MonthOption> months;
  final String employee, status;
  final List<String> employees;
  final List<_PayrollRow> rows;
  final ValueChanged<String?> onMonthChanged, onEmployeeChanged, onStatusChanged;
  final VoidCallback onReset;
  final ValueChanged<_PayrollRow> onMarkPaid;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 600 ? 14 : 28,
          20,
          MediaQuery.sizeOf(context).width < 600 ? 14 : 28,
          18,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E7EE)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A071A72), blurRadius: 16, offset: Offset(0, 6))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly payroll',
                style: TextStyle(
                    color: _PayrollColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Net pay = (present + late days ÷ working days) × monthly salary. Sundays are weekly off. Generate to save the month, then mark paid.',
              style: TextStyle(color: Color(0xFF596176), fontSize: 13),
            ),
            const SizedBox(height: 16),
            _PayrollFilters(
              monthKey: monthKey,
              months: months,
              employee: employee,
              employees: employees,
              status: status,
              onMonthChanged: onMonthChanged,
              onEmployeeChanged: onEmployeeChanged,
              onStatusChanged: onStatusChanged,
              onReset: onReset,
            ),
            const SizedBox(height: 16),
            if (MediaQuery.sizeOf(context).width < 600)
              _MobilePayrollList(rows: rows, onMarkPaid: onMarkPaid)
            else
              _PayrollTable(rows: rows, onMarkPaid: onMarkPaid),
            const SizedBox(height: 16),
            Text(
              rows.isEmpty
                  ? 'No payroll rows for these filters.'
                  : 'Showing ${rows.length} employee${rows.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Color(0xFF596176), fontSize: 13),
            ),
          ],
        ),
      );
}

class _PayrollFilters extends StatelessWidget {
  const _PayrollFilters({
    required this.monthKey,
    required this.months,
    required this.employee,
    required this.employees,
    required this.status,
    required this.onMonthChanged,
    required this.onEmployeeChanged,
    required this.onStatusChanged,
    required this.onReset,
  });

  final String monthKey;
  final List<_MonthOption> months;
  final String employee, status;
  final List<String> employees;
  final ValueChanged<String?> onMonthChanged, onEmployeeChanged, onStatusChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final monthValue = months.any((item) => item.key == monthKey)
        ? monthKey
        : (months.isEmpty ? monthKey : months.first.key);
    return LayoutBuilder(builder: (_, constraints) {
      final width = constraints.maxWidth < 900 ? constraints.maxWidth : 280.0;
      return Wrap(
        spacing: 24,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          _FilterField(
            label: 'Month',
            width: width,
            child: DropdownButtonFormField<String>(
              initialValue: monthValue,
              onChanged: onMonthChanged,
              decoration: _fieldDecoration(),
              items: (months.isEmpty
                      ? [
                          _MonthOption(
                              year: DateTime.now().year,
                              month: DateTime.now().month,
                              label: 'This month')
                        ]
                      : months)
                  .map((item) => DropdownMenuItem(
                      value: item.key, child: Text(item.label)))
                  .toList(),
            ),
          ),
          _FilterField(
            label: 'Employee',
            width: width,
            child: DropdownButtonFormField<String>(
              initialValue: employee,
              onChanged: onEmployeeChanged,
              decoration: _fieldDecoration(),
              items: employees
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
            ),
          ),
          _FilterField(
            label: 'Status',
            width: width,
            child: DropdownButtonFormField<String>(
              initialValue: status,
              onChanged: onStatusChanged,
              decoration: _fieldDecoration(),
              items: const [
                'All Status',
                'Draft',
                'Pending',
                'Paid',
              ]
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _PayrollColors.blue,
              side: const BorderSide(color: Color(0xFFD6DDEA)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
            ),
          ),
        ],
      );
    });
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField(
      {required this.label, required this.width, required this.child});
  final String label;
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF596176), fontSize: 13)),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

InputDecoration _fieldDecoration() => InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFD8DEE9))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _PayrollColors.blue)),
    );

class _MobilePayrollList extends StatelessWidget {
  const _MobilePayrollList({required this.rows, required this.onMarkPaid});
  final List<_PayrollRow> rows;
  final ValueChanged<_PayrollRow> onMarkPaid;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox(
          height: 140,
          child: Center(child: Text('No payroll rows match these filters.')));
    }
    return Column(
      children: rows
          .map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5EAF3)),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEAF1FF),
                        child: Text(
                            row.name.isEmpty ? '?' : row.name.substring(0, 1),
                            style: const TextStyle(
                                color: _PayrollColors.blue,
                                fontWeight: FontWeight.w800))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(row.name,
                              style: const TextStyle(
                                  color: _PayrollColors.navy,
                                  fontWeight: FontWeight.w700)),
                          Text('${row.code} • ${row.department}',
                              style: const TextStyle(
                                  color: Color(0xFF657087), fontSize: 11)),
                        ])),
                    _PayStatus(status: row.status),
                  ]),
                  const SizedBox(height: 10),
                  Text('Salary ${row.salary}  →  Net ${row.netPay}',
                      style: const TextStyle(
                          color: _PayrollColors.navy,
                          fontWeight: FontWeight.w600)),
                  Text(
                      'Paid ${row.paidDays}/${row.workingDays} days • LOP ${row.lopDays}',
                      style: const TextStyle(
                          color: Color(0xFF657087), fontSize: 12)),
                  if (row.status != 'Paid') ...[
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => onMarkPaid(row),
                      style: FilledButton.styleFrom(
                          backgroundColor: _PayrollColors.blue),
                      child: const Text('Mark paid'),
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PayrollTable extends StatelessWidget {
  const _PayrollTable({required this.rows, required this.onMarkPaid});
  final List<_PayrollRow> rows;
  final ValueChanged<_PayrollRow> onMarkPaid;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE3E7EF)),
            borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1480,
            child: Column(
              children: [
                const _PayrollTableHeader(),
                if (rows.isEmpty)
                  const SizedBox(
                      height: 160,
                      child: Center(
                          child: Text(
                              'No payroll rows match these filters.')))
                else
                  ...rows.map((row) =>
                      _PayrollTableRow(row: row, onMarkPaid: onMarkPaid)),
              ],
            ),
          ),
        ),
      );
}

class _PayrollTableHeader extends StatelessWidget {
  const _PayrollTableHeader();
  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        color: const Color(0xFFFCFCFD),
        child: const Row(children: [
          _Cell(width: 250, child: Text('Employee', style: _headStyle)),
          _Cell(width: 150, child: Text('Department', style: _headStyle)),
          _Cell(width: 140, child: Text('Monthly salary', style: _headStyle)),
          _Cell(width: 110, child: Text('Working', style: _headStyle)),
          _Cell(width: 110, child: Text('Paid days', style: _headStyle)),
          _Cell(width: 90, child: Text('LOP', style: _headStyle)),
          _Cell(width: 140, child: Text('Deductions', style: _headStyle)),
          _Cell(width: 140, child: Text('Net pay', style: _headStyle)),
          _Cell(width: 120, child: Text('Status', style: _headStyle)),
          _Cell(width: 140, child: Text('Action', style: _headStyle)),
        ]),
      );
}

class _PayrollTableRow extends StatelessWidget {
  const _PayrollTableRow({required this.row, required this.onMarkPaid});
  final _PayrollRow row;
  final ValueChanged<_PayrollRow> onMarkPaid;

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE6E9EF)))),
        child: Row(
          children: [
            _Cell(
              width: 250,
              child: Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE8EEF8),
                    child: Text(
                        row.name.isEmpty ? '?' : row.name.substring(0, 1),
                        style: const TextStyle(
                            color: _PayrollColors.navy,
                            fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF11131A),
                                fontWeight: FontWeight.w600)),
                        Text(row.code,
                            style: const TextStyle(
                                color: Color(0xFF596176), fontSize: 12)),
                      ]),
                ),
              ]),
            ),
            _Cell(width: 150, child: Text(row.department, style: _cellStyle)),
            _Cell(width: 140, child: Text(row.salary, style: _cellStyle)),
            _Cell(
                width: 110,
                child: Text('${row.workingDays}', style: _cellStyle)),
            _Cell(
                width: 110, child: Text('${row.paidDays}', style: _cellStyle)),
            _Cell(width: 90, child: Text('${row.lopDays}', style: _cellStyle)),
            _Cell(
                width: 140, child: Text(row.deductions, style: _cellStyle)),
            _Cell(
                width: 140,
                child: Text(row.netPay,
                    style: const TextStyle(
                        color: _PayrollColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 13))),
            _Cell(width: 120, child: _PayStatus(status: row.status)),
            _Cell(
              width: 140,
              child: row.status == 'Paid'
                  ? const Text('–',
                      style: TextStyle(color: Color(0xFF596176)))
                  : FilledButton(
                      onPressed: () => onMarkPaid(row),
                      style: FilledButton.styleFrom(
                        backgroundColor: _PayrollColors.blue,
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Mark paid',
                          style: TextStyle(fontSize: 12)),
                    ),
            ),
          ],
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14), child: child));
}

class _PayStatus extends StatelessWidget {
  const _PayStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'Paid'
        ? const Color(0xFF188226)
        : status == 'Pending'
            ? const Color(0xFFFF6500)
            : const Color(0xFF596176);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(5)),
      child: Text(status, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _PayrollRow {
  const _PayrollRow({
    required this.itemId,
    required this.name,
    required this.code,
    required this.department,
    required this.salary,
    required this.workingDays,
    required this.paidDays,
    required this.lopDays,
    required this.deductions,
    required this.netPay,
    required this.status,
  });

  final int? itemId;
  final String name, code, department, salary, deductions, netPay, status;
  final int workingDays, paidDays, lopDays;

  factory _PayrollRow.fromApi(Map<String, dynamic> json) {
    int asInt(dynamic value) =>
        value is int ? value : int.tryParse('$value') ?? 0;
    final rawId = json['id'];
    return _PayrollRow(
      itemId: rawId == null ? null : asInt(rawId),
      name: (json['name'] ?? '').toString(),
      code: (json['employeeCode'] ?? '').toString(),
      department: (json['department'] ?? '').toString(),
      salary: (json['salary'] ?? 'Not Set').toString(),
      workingDays: asInt(json['workingDays']),
      paidDays: asInt(json['paidDays']),
      lopDays: asInt(json['lopDays']),
      deductions: (json['deductionsLabel'] ?? '–').toString(),
      netPay: (json['netPayLabel'] ?? '–').toString(),
      status: (json['status'] ?? 'Draft').toString(),
    );
  }
}

const _headStyle = TextStyle(
    color: Color(0xFF11131A), fontSize: 13, fontWeight: FontWeight.w600);
const _cellStyle = TextStyle(color: Color(0xFF272B35), fontSize: 13);