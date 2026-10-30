import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../services/employee_lifecycle_api.dart';
import '../../../services/hrms_employees_api.dart';
import '../../../services/hrms_payroll_api.dart';
import 'employee_exit_dialog.dart';
import 'employee_profile_page.dart';

class EmployeeArchivePage extends StatefulWidget {
  const EmployeeArchivePage({super.key, this.employeeId, this.name});
  final int? employeeId;
  final String? name;
  @override
  State<EmployeeArchivePage> createState() => _EmployeeArchivePageState();
}

class _EmployeeArchivePageState extends State<EmployeeArchivePage> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = widget.employeeId != null
          ? await EmployeeLifecycleApi.request('${widget.employeeId}/lifecycle')
          : <String, dynamic>{
              'employees': await HrmsEmployeesApi.list(
                status: 'Inactive',
                limit: 1000,
              ),
              'settlements': await EmployeeLifecycleApi.request(
                'settlements/outstanding',
              ),
            };
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Map<String, dynamic>> rows(dynamic value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  String label(String key) =>
      {
        'attendance_records': 'Attendance',
        'hrms_attendance_sessions': 'Clock logs',
        'employee_leaves': 'Leave history',
        'attendance_permission_requests': 'Permissions',
        'hrms_field_tracking_sessions': 'Tracking sessions',
        'hrms_location_pings': 'Location history',
        'task_list': 'Assigned tasks',
        'time_tracking_task_items': 'Task work and reviews',
        'task_assignments': 'Client assignments',
        'task_tracker': 'Task history',
        'task_tracking_details': 'Completed work',
        'content_calendar': 'Content calendar',
        'employee_assignment_events': 'Assignment history',
        'day_plan_rows': 'Day planner',
      }[key] ??
      key.replaceAll('_', ' ');
  Widget records(
    String title,
    List<Map<String, dynamic>> values,
  ) => ExpansionTile(
    title: Text('$title (${values.length})'),
    children: values.isEmpty
        ? [const ListTile(title: Text('No records'))]
        : values
              .map(
                (r) => ListTile(
                  title: Text(
                    '${r['client_name'] ?? r['name'] ?? r['attendance_date'] ?? r['work_date'] ?? r['pay_year'] ?? 'Record'}'
                    '${r['id'] != null ? ' #${r['id']}' : ''}',
                  ),
                  subtitle: Text(
                    '${r['status'] ?? r['attendance_status'] ?? r['employment_status'] ?? ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(title),
                      content: SizedBox(
                        width: 600,
                        child: SingleChildScrollView(
                          child: SelectableText(
                            r.entries
                                .map(
                                  (e) => '${label(e.key)}: ${e.value ?? '—'}',
                                )
                                .join('\n\n'),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
  );
  Future<void> generateFinal(Map<String, dynamic> exit) async {
    try {
      final periods = rows(
        data?['finalSalary'],
      ).where((p) => p['exitId'] == exit['id']).toList();
      if (periods.isEmpty)
        throw Exception('Configure the employee salary and cycle first.');
      for (final period in periods) {
        await HrmsPayrollApi.generate(
          year: (period['payYear'] as num).toInt(),
          month: (period['payMonth'] as num).toInt(),
          employeeId: widget.employeeId,
        );
      }
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> pay(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Review final salary'),
        content: Text(
          'Pay ${item['net_pay']} for ${item['period_start']} – ${item['period_end']}? Confirm that the last working date and attendance deductions have been reviewed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reviewed — mark paid'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await HrmsPayrollApi.markPaid(
        (item['id'] as num).toInt(),
        reviewedSettlement: true,
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> completeSettlement() async {
    try {
      await EmployeeLifecycleApi.request(
        '${widget.employeeId}/settlement/complete',
        method: 'POST',
        body: {},
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> resolveAdjustment(Map<String, dynamic> item) async {
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Record salary adjustment'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paid: ${item['paid_amount']} • Calculated: ${item['calculated_amount']} • Difference: ${item['difference']}',
              ),
              const Text(
                'The paid payslip stays unchanged. Record the payment, recovery, or approved adjustment reference.',
              ),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Decision and reference *',
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
            child: const Text('Record adjustment'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      try {
        await EmployeeLifecycleApi.request(
          'adjustments/${item['id']}/resolve',
          method: 'POST',
          body: {'resolution': note.text.trim()},
        );
        await load();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    note.dispose();
  }

  Widget detail() {
    final employee = data!['employee'] as Map;
    final exits = rows(data!['exits']);
    final history = rows(data!['history']);
    final payroll = rows(data!['payroll']);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${employee['full_name']} • ${employee['is_active'] == 1 ? 'Active' : 'Inactive'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('Joining date: ${employee['joining_date'] ?? 'Not recorded'}'),
        if (data!['exitDateRequired'] == true)
          ListTile(
            title: const Text('Exit date required'),
            subtitle: const Text(
              'History is retained. Record the last working date before final settlement or reactivation.',
            ),
            trailing: TextButton(
              onPressed: () async {
                if (await showEmployeeExitDialog(
                  context,
                  widget.employeeId!,
                  inactive: false,
                  name: '${employee['full_name']}',
                ))
                  await load();
              },
              child: const Text('Record exit'),
            ),
          ),
        ...exits.map(
          (exit) => Card(
            child: ListTile(
              title: Text(
                'Last working date: ${exit['last_working_date'].toString().substring(0, 10)}',
              ),
              subtitle: Text(
                '${exit['reason']}\nAccess disabled: ${exit['disabled_at']}\nSettlement: ${exit['settlement_status']}',
              ),
              trailing: TextButton(
                onPressed: () => generateFinal(exit),
                child: const Text('Refresh unpaid salary'),
              ),
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EmployeeProfilePage(
                profileId: 0,
                employeeUserId: widget.employeeId,
              ),
            ),
          ),
          child: const Text('Open attendance and payroll profile'),
        ),
        records('Employment periods', rows(data!['periods'])),
        ...history.map(
          (section) =>
              records(label('${section['source']}'), rows(section['records'])),
        ),
        records('Salary history / paid payslips', payroll),
        ...payroll
            .where((p) => p['status'] == 'paid')
            .map(
              (p) => ListTile(
                title: Text(
                  'Paid payslip • ${p['pay_month']}/${p['pay_year']}',
                ),
                trailing: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Paid payslip')),
                        body: PdfPreview(
                          build: (_) => EmployeeLifecycleApi.payslip(
                            widget.employeeId!,
                            (p['id'] as num).toInt(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('View payslip'),
                ),
              ),
            ),
        ...payroll
            .where((p) => p['status'] != 'paid')
            .map(
              (p) => ListTile(
                title: Text('Outstanding salary: ${p['net_pay']}'),
                subtitle: Text('${p['period_start']} – ${p['period_end']}'),
                trailing: TextButton(
                  onPressed: () => pay(p),
                  child: const Text('Review payment'),
                ),
              ),
            ),
        ...rows(data!['adjustments']).map(
          (a) => ListTile(
            title: Text('Salary adjustment: ${a['difference']}'),
            subtitle: Text(
              '${a['resolution'] ?? 'Requires audited review; original paid salary is retained.'}',
            ),
            trailing: a['resolved_at'] == null
                ? TextButton(
                    onPressed: () => resolveAdjustment(a),
                    child: const Text('Review adjustment'),
                  )
                : const Icon(Icons.check),
          ),
        ),
        if (exits.any((exit) => exit['settlement_status'] != 'Settled'))
          OutlinedButton(
            onPressed: completeSettlement,
            child: const Text('Complete final settlement'),
          ),
        const Divider(),
        records('Exit and correction audit', rows(data!['audit'])),
      ],
    );
  }

  Widget overview() {
    final employees = rows((data!['employees'] as Map)['items']);
    final settlements = rows((data!['settlements'] as Map)['items']);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Inactive Employees'),
              Tab(text: 'Outstanding / Final Settlements'),
            ],
            isScrollable: true,
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  children: [
                    if (employees.isEmpty)
                      const ListTile(title: Text('No inactive employees')),
                    ...employees.map(
                      (e) => ListTile(
                        title: Text('${e['name']}'),
                        subtitle: Text('${e['employeeCode']} • Inactive'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => EmployeeArchivePage(
                                employeeId: (e['employeeUserId'] as num)
                                    .toInt(),
                                name: '${e['name']}',
                              ),
                            ),
                          );
                          await load();
                        },
                      ),
                    ),
                  ],
                ),
                ListView(
                  children: [
                    if (settlements.isEmpty)
                      const ListTile(title: Text('No outstanding settlements')),
                    ...settlements.map(
                      (e) => ListTile(
                        title: Text('${e['full_name']}'),
                        subtitle: Text(
                          '${e['settlement_status']} • Last working date: ${e['last_working_date'] ?? 'Required'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => EmployeeArchivePage(
                                employeeId: (e['employee_user_id'] as num)
                                    .toInt(),
                                name: '${e['full_name']}',
                              ),
                            ),
                          );
                          await load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.name ?? 'Employee exits and history'),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: busy
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: load, child: const Text('Retry')),
              ],
            ),
          )
        : widget.employeeId != null
        ? detail()
        : overview(),
  );
}
