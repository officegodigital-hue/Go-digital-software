import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/hrms_clock_logs_api.dart';
import '../../shared/widgets/admin_top_nav.dart';

abstract final class _Colors {
  static const blue = Color(0xFF075EF7);
  static const navy = Color(0xFF061457);
  static const page = Color(0xFFF7F9FD);
  static const line = Color(0xFFDDE5F2);
}

class ClockLogsPage extends StatefulWidget {
  const ClockLogsPage({super.key});
  static Widget builder(BuildContext context) => const ClockLogsPage();
  @override
  State<ClockLogsPage> createState() => _ClockLogsPageState();
}

class _ClockLogsPageState extends State<ClockLogsPage> {
  DateTime selectedDate = DateTime.now();
  String view = 'day';
  int? employeeId;
  List<_ClockLog> logs = [];
  List<_EmployeeOption> employees = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await HrmsClockLogsApi.list(
        view: view,
        selectedDate: selectedDate,
        employeeId: employeeId,
      );
      final nextLogs = (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => _ClockLog.fromApi(Map<String, dynamic>.from(item)))
          .toList();
      final nextEmployees = (data['employees'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) => _EmployeeOption.fromApi(Map<String, dynamic>.from(item)),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        logs = nextLogs;
        employees = nextEmployees;
        if (employeeId != null &&
            !employees.any((item) => item.id == employeeId))
          employeeId = null;
        loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = err.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked == null || !mounted) return;
    setState(
      () => selectedDate = view == 'month'
          ? DateTime(picked.year, picked.month)
          : picked,
    );
    _load();
  }

  String get _dateLabel => view == 'month'
      ? DateFormat('MMMM yyyy').format(selectedDate)
      : DateFormat('dd MMM yyyy').format(selectedDate);

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: _Colors.page,
      body: Column(
        children: [
          const AdminTopNav(activeRoute: '/admin/clock-logs'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  mobile ? 16 : 28,
                  20,
                  mobile ? 16 : 28,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1580),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee Clock Logs',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: _Colors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Review employee check-in and check-out records from attendance data.',
                        ),
                        const SizedBox(height: 20),
                        _Filters(
                          view: view,
                          dateLabel: _dateLabel,
                          employeeId: employeeId,
                          employees: employees,
                          onViewChanged: (value) {
                            setState(() {
                              view = value;
                              if (value == 'month')
                                selectedDate = DateTime(
                                  selectedDate.year,
                                  selectedDate.month,
                                );
                            });
                            _load();
                          },
                          onDatePick: _pickDate,
                          onEmployeeChanged: (value) {
                            setState(() => employeeId = value);
                            _load();
                          },
                        ),
                        const SizedBox(height: 18),
                        _LogPanel(
                          loading: loading,
                          error: error,
                          logs: logs,
                          onRetry: _load,
                        ),
                      ],
                    ),
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

class _Filters extends StatelessWidget {
  const _Filters({
    required this.view,
    required this.dateLabel,
    required this.employeeId,
    required this.employees,
    required this.onViewChanged,
    required this.onDatePick,
    required this.onEmployeeChanged,
  });
  final String view;
  final String dateLabel;
  final int? employeeId;
  final List<_EmployeeOption> employees;
  final ValueChanged<String> onViewChanged;
  final VoidCallback onDatePick;
  final ValueChanged<int?> onEmployeeChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _Colors.line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'day', label: Text('Day')),
            ButtonSegment(value: 'month', label: Text('Month')),
          ],
          selected: {view},
          onSelectionChanged: (value) => onViewChanged(value.first),
        ),
        OutlinedButton.icon(
          onPressed: onDatePick,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(dateLabel),
        ),
        SizedBox(
          width: 250,
          child: DropdownButtonFormField<int?>(
            value: employeeId,
            decoration: const InputDecoration(
              labelText: 'Employee',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All employees'),
              ),
              ...employees.map(
                (employee) => DropdownMenuItem<int?>(
                  value: employee.id,
                  child: Text(employee.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: onEmployeeChanged,
          ),
        ),
      ],
    ),
  );
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({
    required this.loading,
    required this.error,
    required this.logs,
    required this.onRetry,
  });
  final bool loading;
  final String? error;
  final List<_ClockLog> logs;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _Colors.line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: loading
        ? const Padding(
            padding: EdgeInsets.all(56),
            child: Center(child: CircularProgressIndicator()),
          )
        : error != null
        ? Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          )
        : logs.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(56),
            child: Center(
              child: Text('No clock records found for this filter.'),
            ),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(_Colors.page),
              columns: const [
                DataColumn(label: Text('Employee')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Check In')),
                DataColumn(label: Text('Check Out')),
                DataColumn(label: Text('Worked')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Method')),
              ],
              rows: logs
                  .map(
                    (log) => DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.employeeName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  log.staffId ?? log.role,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(Text(log.date)),
                        DataCell(Text(log.checkIn)),
                        DataCell(Text(log.checkOut)),
                        DataCell(Text(log.workedLabel)),
                        DataCell(_StatusBadge(status: log.status)),
                        DataCell(Text(log.method)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final color = lower.contains('late')
        ? Colors.orange
        : lower.contains('absent')
        ? Colors.red
        : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmployeeOption {
  const _EmployeeOption({required this.id, required this.label});
  final int id;
  final String label;
  factory _EmployeeOption.fromApi(Map<String, dynamic> json) {
    final name = (json['name'] ?? 'Unnamed employee').toString();
    final staffId = json['staffId']?.toString();
    return _EmployeeOption(
      id: int.tryParse('${json['id']}') ?? 0,
      label: staffId == null || staffId.isEmpty ? name : '$name ($staffId)',
    );
  }
}

class _ClockLog {
  const _ClockLog({
    required this.employeeName,
    required this.staffId,
    required this.role,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.workingMinutes,
    required this.status,
    required this.method,
  });
  final String employeeName;
  final String? staffId;
  final String role;
  final String date;
  final String checkIn;
  final String checkOut;
  final int workingMinutes;
  final String status;
  final String method;
  String get workedLabel =>
      '${workingMinutes ~/ 60}h ${(workingMinutes % 60).toString().padLeft(2, '0')}m';
  factory _ClockLog.fromApi(Map<String, dynamic> json) => _ClockLog(
    employeeName: (json['employeeName'] ?? 'Former employee').toString(),
    staffId: json['staffId']?.toString(),
    role: (json['role'] ?? 'Unassigned').toString(),
    date: (json['date'] ?? '-').toString(),
    checkIn: (json['checkIn'] ?? '--').toString(),
    checkOut: (json['checkOut'] ?? '--').toString(),
    workingMinutes: int.tryParse('${json['workingMinutes']}') ?? 0,
    status: (json['status'] ?? 'Absent').toString(),
    method: (json['method'] ?? '-').toString(),
  );
}
