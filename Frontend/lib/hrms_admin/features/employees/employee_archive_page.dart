import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../services/employee_lifecycle_api.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/admin_top_nav.dart';
import '../../shared/widgets/admin_page_scroll_view.dart';
import 'employee_records_widgets.dart';
import 'employee_records_panel.dart';
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
          : <String, dynamic>{};
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
        'hrms_tracking_points': 'Tracking route history',
        'hrms_tracking_locations': 'Saved tracking locations',
        'live_tracking_sessions': 'Live tracking sessions',
        'task_list': 'Assigned tasks',
        'time_tracking_task_items': 'Task work and reviews',
        'task_assignments': 'Client assignments',
        'task_tracker': 'Task history',
        'task_tracking_details': 'Completed work',
        'content_calendar': 'Content calendar',
        'employee_assignment_events': 'Assignment history',
        'day_plan_rows': 'Day planner',
      }[key] ??
      key
          .split('_')
          .map(
            (word) => word.isEmpty
                ? ''
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' ');
  String date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    return parsed == null
        ? 'Not recorded'
        : DateFormat('dd MMM yyyy').format(parsed);
  }

  String money(dynamic value) => value == null
      ? 'Not set'
      : NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        ).format(num.tryParse('$value') ?? 0);
  bool get isActive =>
      data?['employee']?['is_active'] == 1 ||
      data?['employee']?['is_active'] == true;
  String display(dynamic value) {
    if (value == null || '$value'.isEmpty) return '—';
    return '$value';
  }

  Widget records(String title, List<Map<String, dynamic>> values) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: RecordSurface(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: RecordStyle.pale,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              color: RecordStyle.blue,
              size: 19,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: RecordStyle.navy,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${values.length} saved records',
            style: const TextStyle(color: RecordStyle.muted, fontSize: 12),
          ),
          children: values.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No records for this section.',
                      style: TextStyle(color: RecordStyle.muted, fontSize: 13),
                    ),
                  ),
                ]
              : values
                    .map(
                      (r) => InkWell(
                        onTap: () => showRecord(title, r),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 15,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: RecordStyle.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${r['attendance_date'] != null
                                          ? date(r['attendance_date'])
                                          : r['work_date'] != null
                                          ? date(r['work_date'])
                                          : r['request_date'] != null
                                          ? date(r['request_date'])
                                          : r['action'] != null
                                          ? label('${r['action']}'.toLowerCase())
                                          : r['pay_year'] != null
                                          ? '${r['pay_month']}/${r['pay_year']}'
                                          : r['created_at'] != null
                                          ? date(r['created_at'])
                                          : 'Record #${r['id'] ?? ''}'}',
                                      style: const TextStyle(
                                        color: RecordStyle.navy,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${r['status'] ?? r['attendance_status'] ?? r['admin_name'] ?? 'View saved details'}',
                                      style: const TextStyle(
                                        color: RecordStyle.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: RecordStyle.blue,
                                size: 17,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
        ),
      ),
    ),
  );
  Future<void> showRecord(String title, Map<String, dynamic> record) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 650),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: RecordStyle.navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close record',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: RecordStyle.muted,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Saved employee record',
                    style: TextStyle(color: RecordStyle.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: record.entries
                            .where(
                              (e) => !const {
                                'employee_id',
                                'employee_user_id',
                                'profile_id',
                                'event_key',
                                'record_hash',
                              }.contains(e.key),
                            )
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 17),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label(e.key),
                                      style: const TextStyle(
                                        color: RecordStyle.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    SelectableText(
                                      display(e.value),
                                      style: const TextStyle(
                                        color: RecordStyle.navy,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: RecordStyle.navy,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
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

  int detailTab = 0;
  Future<void> reactivate() async {
    final employee = data!['employee'] as Map;
    if (await showEmployeeExitDialog(
      context,
      widget.employeeId!,
      inactive: true,
      name: '${employee['full_name']}',
    ))
      await load();
  }

  Future<void> openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EmployeeProfilePage(
          profileId: 0,
          employeeUserId: widget.employeeId,
        ),
      ),
    );
    await load();
  }

  void viewPayslip(Map<String, dynamic> p) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: RecordStyle.page,
        appBar: AppBar(
          title: const Text('Paid payslip'),
          backgroundColor: Colors.white,
          foregroundColor: RecordStyle.navy,
          elevation: 0,
        ),
        body: PdfPreview(
          build: (_) => EmployeeLifecycleApi.payslip(
            widget.employeeId!,
            (p['id'] as num).toInt(),
          ),
        ),
      ),
    ),
  );
  Widget sectionTitle(String title, String subtitle, {Widget? action}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: LayoutBuilder(
          builder: (context, box) {
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RecordStyle.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RecordStyle.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            );
            if (box.maxWidth < 700)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  if (action != null) ...[const SizedBox(height: 14), action],
                ],
              );
            return Row(
              children: [
                Expanded(child: text),
                if (action != null) ...[const SizedBox(width: 20), action],
              ],
            );
          },
        ),
      );
  Widget field(String title, String value, double width) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: RecordStyle.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: RecordStyle.navy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
  Widget employeeHeader() {
    final employee = data!['employee'] as Map;
    final profile = data!['profile'] as Map? ?? {};
    final exits = rows(data!['exits']);
    final latest = exits.isEmpty ? <String, dynamic>{} : exits.first;
    final periods = rows(data!['periods']);
    final name = '${employee['full_name'] ?? widget.name ?? 'Employee'}';
    return RecordSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final identity = Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: RecordStyle.pale,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      name.isEmpty ? 'E' : name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: RecordStyle.blue,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 17),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: RecordStyle.navy,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${profile['employee_code'] ?? 'Employee #${widget.employeeId}'}  •  ${profile['department'] ?? 'Department not recorded'}',
                          style: const TextStyle(
                            color: RecordStyle.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RecordPill(
                    isActive
                        ? (exits.isEmpty ? 'Active' : 'Rejoined')
                        : 'Inactive',
                    color: isActive
                        ? const Color(0xFF20815A)
                        : RecordStyle.muted,
                  ),
                  if (!isActive && data!['exitDateRequired'] != true)
                    RecordAction(
                      label: 'Reactivate Employee',
                      icon: Icons.person_add_alt_rounded,
                      primary: true,
                      onPressed: reactivate,
                    ),
                ],
              );
              if (box.maxWidth < 750)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 18), actions],
                );
              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 18),
                  actions,
                ],
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: RecordStyle.line),
          ),
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth < 700
                  ? (box.maxWidth - 20) / 2
                  : (box.maxWidth - 60) / 4;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  field(
                    'Original joining date',
                    date(
                      employee['joining_date'] ??
                          (periods.isEmpty
                              ? null
                              : periods.first['started_on']),
                    ),
                    width,
                  ),
                  field(
                    'Last working date',
                    latest.isEmpty && isActive
                        ? '—'
                        : date(latest['last_working_date']),
                    width,
                  ),
                  field(
                    'New joining date',
                    isActive && exits.isNotEmpty && periods.length > 1
                        ? date(periods.last['started_on'])
                        : '—',
                    width,
                  ),
                  field(
                    'Final settlement',
                    '${latest['settlement_status'] ?? (isActive ? 'Not applicable' : 'Exit date required')}',
                    width,
                  ),
                ],
              );
            },
          ),
          if (latest.isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RecordStyle.page,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXIT REASON',
                    style: TextStyle(
                      color: RecordStyle.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${latest['reason'] ?? 'Not recorded'}',
                    style: const TextStyle(
                      color: RecordStyle.navy,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recorded by ${latest['changed_by_name'] ?? 'Admin #${latest['created_by'] ?? '—'}'} • ${date(latest['disabled_at'])}',
                    style: const TextStyle(
                      color: RecordStyle.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget attendanceTab() {
    final history = rows(data!['history']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'Attendance history',
          'Saved attendance, leave, permissions and location records.',
          action: RecordAction(
            label: 'Open attendance profile',
            icon: Icons.open_in_new_rounded,
            onPressed: openProfile,
          ),
        ),
        if (history.isEmpty)
          const RecordSurface(
            child: RecordEmpty(
              title: 'No attendance history',
              message: 'Any saved attendance records will appear here.',
            ),
          ),
        ...history.map(
          (section) =>
              records(label('${section['source']}'), rows(section['records'])),
        ),
      ],
    );
  }

  Widget paymentCard(
    String title,
    String subtitle,
    Widget action, {
    String? amount,
    Widget? badge,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: RecordSurface(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, box) {
          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: RecordStyle.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: const TextStyle(
                  color: RecordStyle.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              if (amount != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    amount,
                    style: const TextStyle(
                      color: RecordStyle.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (badge != null)
                Padding(padding: const EdgeInsets.only(top: 10), child: badge),
            ],
          );
          if (box.maxWidth < 620)
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [information, const SizedBox(height: 16), action],
            );
          return Row(
            children: [
              Expanded(child: information),
              const SizedBox(width: 20),
              action,
            ],
          );
        },
      ),
    ),
  );
  Widget salaryTab() {
    final payroll = rows(data!['payroll']);
    final exits = rows(data!['exits']);
    final adjustments = rows(data!['adjustments']);
    final finalSalary = rows(data!['finalSalary']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'Final salary & settlement',
          'Review the saved calculations, payments and adjustments before completing settlement.',
          action: RecordAction(
            label: 'Open payroll profile',
            icon: Icons.open_in_new_rounded,
            onPressed: openProfile,
          ),
        ),
        ...exits.map(
          (exit) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              paymentCard(
                'Final salary period',
                'Last working date: ${date(exit['last_working_date'])}',
                RecordAction(
                  label: 'Refresh unpaid salary',
                  icon: Icons.refresh_rounded,
                  onPressed: () => generateFinal(exit),
                ),
                badge: RecordPill('${exit['settlement_status']}'),
              ),
              ...finalSalary
                  .where((p) => p['exitId'] == exit['id'])
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: RecordSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${date(p['periodStart'])} — ${date(p['periodEnd'])}',
                              style: const TextStyle(
                                color: RecordStyle.navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, box) {
                                final width = box.maxWidth < 700
                                    ? (box.maxWidth - 20) / 2
                                    : (box.maxWidth - 60) / 4;
                                return Wrap(
                                  spacing: 20,
                                  runSpacing: 20,
                                  children: [
                                    field(
                                      'Monthly salary',
                                      money(p['monthlySalary']),
                                      width,
                                    ),
                                    field(
                                      'Daily rate',
                                      money(p['dailyRate']),
                                      width,
                                    ),
                                    field(
                                      'Eligible working days',
                                      display(p['eligibleWorkingDays']),
                                      width,
                                    ),
                                    field(
                                      'Unpaid days',
                                      display(p['lopDays']),
                                      width,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: RecordStyle.pale,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Wrap(
                                spacing: 20,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Calculated final salary',
                                    style: TextStyle(
                                      color: RecordStyle.blue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${p['netPayLabel'] ?? 'Review required'}',
                                    style: const TextStyle(
                                      color: RecordStyle.blue,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        sectionTitle(
          'Saved payroll',
          'Payments and payslips retain their original history.',
        ),
        if (payroll.isEmpty)
          const RecordSurface(
            child: RecordEmpty(
              title: 'No saved payroll yet',
              message:
                  'Use Refresh unpaid salary to prepare the employee’s final salary.',
            ),
          ),
        ...payroll.map(
          (p) => paymentCard(
            '${p['status'] == 'paid' ? 'Paid payslip' : 'Outstanding salary'} • ${p['pay_month']}/${p['pay_year']}',
            '${date(p['period_start'])} — ${date(p['period_end'])}',
            p['status'] == 'paid'
                ? RecordAction(
                    label: 'View payslip',
                    icon: Icons.description_outlined,
                    onPressed: () => viewPayslip(p),
                  )
                : RecordAction(
                    label: 'Review payment',
                    primary: true,
                    onPressed: () => pay(p),
                  ),
            amount: money(p['net_pay']),
            badge: RecordPill(
              p['status'] == 'paid' ? 'Paid' : 'Unpaid',
              color: p['status'] == 'paid'
                  ? const Color(0xFF20815A)
                  : const Color(0xFFB16A13),
            ),
          ),
        ),
        if (adjustments.isNotEmpty) ...[
          const SizedBox(height: 18),
          sectionTitle(
            'Salary adjustments',
            'Original paid amounts are retained. Review each recorded difference.',
          ),
          ...adjustments.map(
            (a) => paymentCard(
              'Salary adjustment',
              '${a['resolution'] ?? 'Decision and payment or recovery reference required.'}',
              a['resolved_at'] == null
                  ? RecordAction(
                      label: 'Review adjustment',
                      onPressed: () => resolveAdjustment(a),
                    )
                  : const RecordPill('Resolved', color: Color(0xFF20815A)),
              amount: money(a['difference']),
            ),
          ),
        ],
        if (exits.any((exit) => exit['settlement_status'] != 'Settled')) ...[
          const SizedBox(height: 20),
          RecordSurface(
            child: sectionTitle(
              'Close final settlement',
              'All required payroll payments and adjustments must be resolved first.',
              action: RecordAction(
                label: 'Complete final settlement',
                icon: Icons.task_alt_rounded,
                primary: true,
                onPressed: completeSettlement,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget employmentTab() {
    final periods = rows(data!['periods']);
    final exits = rows(data!['exits']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'Employment history',
          'Every employment period stays saved, including gaps and previous exits.',
        ),
        if (periods.isEmpty)
          const RecordSurface(
            child: RecordEmpty(
              title: 'No employment periods recorded',
              message: 'Recorded joining and leaving dates will appear here.',
            ),
          ),
        ...periods.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RecordSurface(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: RecordStyle.pale,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.work_history_outlined,
                      color: RecordStyle.blue,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key == 0
                              ? 'Original employment'
                              : 'Rejoined • period ${entry.key + 1}',
                          style: const TextStyle(
                            color: RecordStyle.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '${date(entry.value['started_on'])} — ${entry.value['ended_on'] == null ? 'Present' : date(entry.value['ended_on'])}',
                          style: const TextStyle(
                            color: RecordStyle.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 11),
                        RecordPill(
                          entry.value['ended_on'] == null
                              ? 'Current period'
                              : 'Closed period',
                          color: entry.value['ended_on'] == null
                              ? const Color(0xFF20815A)
                              : RecordStyle.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        sectionTitle(
          'Exit history',
          'Last working dates, reasons and the admin who recorded each exit.',
        ),
        ...exits.map(
          (exit) => paymentCard(
            'Last working day • ${date(exit['last_working_date'])}',
            '${exit['reason']}\nRecorded by ${exit['changed_by_name'] ?? 'Admin #${exit['created_by']}'} on ${date(exit['disabled_at'])}',
            RecordPill('${exit['settlement_status']}'),
          ),
        ),
        const SizedBox(height: 15),
        records('Recorded changes', rows(data!['audit'])),
      ],
    );
  }

  Widget detail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      employeeHeader(),
      const SizedBox(height: 22),
      if (data!['exitDateRequired'] == true) ...[
        RecordSurface(
          child: sectionTitle(
            'Exit date required',
            'Previous history is retained. Record the exit before final settlement or reactivation.',
            action: RecordAction(
              label: 'Record exit',
              onPressed: () async {
                if (await showEmployeeExitDialog(
                  context,
                  widget.employeeId!,
                  inactive: false,
                  name: '${data!['employee']['full_name']}',
                ))
                  await load();
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
      RecordTabs(
        labels: const ['Attendance', 'Salary', 'Employment History'],
        selected: detailTab,
        onSelect: (i) => setState(() => detailTab = i),
      ),
      const SizedBox(height: 24),
      if (detailTab == 0)
        attendanceTab()
      else if (detailTab == 1)
        salaryTab()
      else
        employmentTab(),
    ],
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: RecordStyle.navy,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    child: Scaffold(
      backgroundColor: RecordStyle.page,
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 600
          ? const AdminMobileBottomNav(activeRoute: '/admin/employees')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            const AdminTopNav(activeRoute: '/admin/employees'),
            Expanded(
              child: AdminPageScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 38,
                  vertical: 22,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                              ),
                              label: const Text('Employees'),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: RecordStyle.muted,
                              size: 16,
                            ),
                            const Text(
                              'Inactive Records',
                              style: TextStyle(
                                color: RecordStyle.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        sectionTitle(
                          widget.employeeId == null
                              ? 'Inactive records'
                              : 'Employee record',
                          'A complete view of retained attendance, salary and employment history.',
                          action: RecordAction(
                            label: 'Refresh',
                            icon: Icons.refresh_rounded,
                            onPressed: busy ? null : load,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (busy)
                          const RecordSurface(
                            child: Padding(
                              padding: EdgeInsets.all(50),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else if (error != null)
                          RecordSurface(
                            child: Column(
                              children: [
                                RecordEmpty(
                                  title: 'Record could not be loaded',
                                  message: error!,
                                  icon: Icons.cloud_off_outlined,
                                ),
                                RecordAction(
                                  label: 'Try again',
                                  onPressed: load,
                                ),
                              ],
                            ),
                          )
                        else if (widget.employeeId != null)
                          detail()
                        else
                          EmployeeRecordsPanel(
                            onOpenRecord: (id, name) async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => EmployeeProfilePage(
                                    profileId: 0,
                                    employeeUserId: id,
                                    initialName: name,
                                    sourceLabel: 'Inactive Records',
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
