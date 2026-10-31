import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/employee_lifecycle_api.dart';
import 'employee_records_widgets.dart';

class EmployeeRecordsPanel extends StatefulWidget {
  const EmployeeRecordsPanel({super.key, required this.onOpenRecord});
  final Future<void> Function(int id, String name) onOpenRecord;
  @override
  State<EmployeeRecordsPanel> createState() => _EmployeeRecordsPanelState();
}

class _EmployeeRecordsPanelState extends State<EmployeeRecordsPanel> {
  final search = TextEditingController();
  List<Map<String, dynamic>> items = [];
  bool loading = true, opening = false;
  String? error;
  int group = 0;
  String department = 'All Departments', settlement = 'All Settlements';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await EmployeeLifecycleApi.request('records');
      if (!mounted) return;
      setState(() {
        items = (result['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (department != 'All Departments' &&
            !items.any((row) => row['department'] == department)) {
          department = 'All Departments';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool active(Map row) => row['isActive'] == true || row['isActive'] == 1;
  bool complete(Map row) => row['settlementStatus'] == 'Settled';
  String date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    return parsed == null
        ? 'Not recorded'
        : DateFormat('dd MMM yyyy').format(parsed);
  }

  Future<void> open(Map row) async {
    final id = int.tryParse('${row['employeeUserId']}');
    if (id == null || opening) return;
    setState(() => opening = true);
    try {
      await widget.onOpenRecord(id, '${row['name']}');
      if (mounted) await load();
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Widget metric(
    String title,
    int count,
    IconData icon,
    Color color,
    double width, {
    bool compact = false,
  }) => SizedBox(
    width: width,
    child: RecordSurface(
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 19),
                    const Spacer(),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: RecordStyle.navy,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: RecordStyle.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: RecordStyle.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$count',
                        style: const TextStyle(
                          color: RecordStyle.navy,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
  Widget filter(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> changed,
    double width,
  ) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: RecordStyle.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          key: ValueKey('$label:$value'),
          initialValue: options.contains(value) ? value : options.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            fontSize: 13,
            color: RecordStyle.navy,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            constraints: const BoxConstraints.tightFor(height: 48),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 0,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RecordStyle.line),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: options
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) changed(value);
          },
        ),
      ],
    ),
  );
  Widget identity(Map row) => Row(
    children: [
      Container(
        width: 39,
        height: 39,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: RecordStyle.pale,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          '${row['name'] ?? 'E'}'.isEmpty
              ? 'E'
              : '${row['name']}'.characters.first.toUpperCase(),
          style: const TextStyle(
            color: RecordStyle.blue,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['name']}',
              style: const TextStyle(
                color: RecordStyle.navy,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${row['employeeCode'] ?? '—'}',
              style: const TextStyle(color: RecordStyle.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
  Widget status(Map row) => RecordPill(
    complete(row)
        ? 'Completed'
        : row['settlementStatus'] == 'Exit date required'
        ? 'Exit date required'
        : 'Pending review',
    color: complete(row) ? const Color(0xFF20815A) : const Color(0xFFB16A13),
  );
  Widget desktopRow(Map row, {bool header = false}) {
    Widget cell(int flex, Widget child) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: child,
      ),
    );
    const heading = TextStyle(
      color: RecordStyle.muted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    const body = TextStyle(color: RecordStyle.navy, fontSize: 13);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: header ? 10 : 14, horizontal: 8),
      child: Row(
        children: [
          cell(
            26,
            header ? const Text('EMPLOYEE', style: heading) : identity(row),
          ),
          cell(
            16,
            Text(
              header ? 'DEPARTMENT' : '${row['department'] ?? '—'}',
              style: header ? heading : body,
            ),
          ),
          cell(
            18,
            header
                ? const Text('LAST WORKING DAY', style: heading)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date(row['lastWorkingDate']), style: body),
                      if (active(row))
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            'Rejoined ${date(row['latestJoiningDate'])}',
                            style: const TextStyle(
                              color: RecordStyle.blue,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          cell(
            22,
            Text(
              header
                  ? 'EXIT REASON'
                  : '${row['reason'] ?? 'Exit details required'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: header ? heading : body,
            ),
          ),
          cell(
            18,
            header
                ? const Text('FINAL SETTLEMENT', style: heading)
                : Align(alignment: Alignment.centerLeft, child: status(row)),
          ),
          cell(
            17,
            header
                ? const Text('RECORD', style: heading)
                : RecordAction(
                    label: 'View Record',
                    onPressed: opening ? null : () => open(row),
                  ),
          ),
        ],
      ),
    );
  }

  Widget mobileRow(Map row) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        identity(row),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            RecordPill(
              active(row) ? 'Rejoined' : 'Inactive',
              color: RecordStyle.muted,
            ),
            status(row),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${row['department'] ?? '—'}  •  ${row['workMode'] ?? '—'}',
          style: const TextStyle(color: RecordStyle.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        const Text(
          'LAST WORKING DAY',
          style: TextStyle(
            color: RecordStyle.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          date(row['lastWorkingDate']),
          style: const TextStyle(
            color: RecordStyle.navy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (active(row))
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Rejoined ${date(row['latestJoiningDate'])}',
              style: const TextStyle(color: RecordStyle.blue, fontSize: 12),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          '${row['reason'] ?? 'Exit details required'}',
          style: const TextStyle(
            color: RecordStyle.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: RecordAction(
            label: 'View Record',
            icon: Icons.arrow_forward_rounded,
            onPressed: opening ? null : () => open(row),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final inactive = items.where((e) => !active(e)).length;
    final pending = items.where((e) => !complete(e)).length;
    final departmentValues =
        items
            .map((e) => '${e['department'] ?? ''}')
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final departments = ['All Departments', ...departmentValues];
    final query = search.text.trim().toLowerCase();
    final visible = items
        .where(
          (row) =>
              active(row) == (group == 1) &&
              (query.isEmpty ||
                  '${row['name']} ${row['employeeCode']}'
                      .toLowerCase()
                      .contains(query)) &&
              (department == 'All Departments' ||
                  row['department'] == department) &&
              (settlement == 'All Settlements' ||
                  (settlement == 'Completed' && complete(row)) ||
                  (settlement == 'Pending' && !complete(row)) ||
                  (settlement == 'Exit date required' &&
                      row['settlementStatus'] == settlement)),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        final small = constraints.maxWidth < 600;
        final cardWidth = (constraints.maxWidth - 28) / 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                metric(
                  small ? 'Inactive' : 'Currently inactive',
                  inactive,
                  Icons.person_off_outlined,
                  RecordStyle.blue,
                  cardWidth,
                  compact: small,
                ),
                metric(
                  small ? 'Pending' : 'Settlement pending',
                  pending,
                  Icons.receipt_long_outlined,
                  const Color(0xFFB16A13),
                  cardWidth,
                  compact: small,
                ),
                metric(
                  small ? 'Completed' : 'Settlement completed',
                  items.length - pending,
                  Icons.task_alt_rounded,
                  const Color(0xFF20815A),
                  cardWidth,
                  compact: small,
                ),
              ],
            ),
            const SizedBox(height: 24),
            RecordSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 20,
                      runSpacing: 10,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Employee records',
                              style: TextStyle(
                                color: RecordStyle.navy,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Attendance, employment history and final salary — kept together.',
                              style: const TextStyle(
                                color: RecordStyle.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: RecordTabs(
                                labels: const [
                                  'Currently Inactive',
                                  'Rejoined Employees',
                                ],
                                selected: group,
                                onSelect: (i) => setState(() => group = i),
                              ),
                            ),
                            const SizedBox(width: 12),
                            RecordAction(
                              label: 'Refresh',
                              icon: Icons.refresh_rounded,
                              onPressed: loading ? null : load,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, box) {
                      final width = box.maxWidth;
                      final narrow = width < 800;
                      return Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          SizedBox(
                            width: narrow ? width : width * .43 - 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Search records',
                                  style: TextStyle(
                                    color: RecordStyle.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  textAlignVertical: TextAlignVertical.center,
                                  controller: search,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    constraints: const BoxConstraints.tightFor(
                                      height: 48,
                                    ),
                                    hintText: 'Search by name or employee ID',
                                    hintStyle: const TextStyle(
                                      fontSize: 13,
                                      color: RecordStyle.muted,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 21,
                                      color: RecordStyle.blue,
                                    ),
                                    suffixIcon: search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Clear search',
                                            onPressed: () =>
                                                setState(search.clear),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 17,
                                            ),
                                          ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 0,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: RecordStyle.line,
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          filter(
                            'Department',
                            department,
                            departments,
                            (v) => setState(() => department = v),
                            narrow
                                ? (width < 300 ? width : (width - 14) / 2)
                                : width * .27 - 7,
                          ),
                          filter(
                            'Settlement',
                            settlement,
                            const [
                              'All Settlements',
                              'Pending',
                              'Completed',
                              'Exit date required',
                            ],
                            (v) => setState(() => settlement = v),
                            narrow
                                ? (width < 300 ? width : (width - 14) / 2)
                                : width * .30 - 7,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            RecordSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Text(
                          group == 0
                              ? 'Inactive employees'
                              : 'Rejoined employees',
                          style: const TextStyle(
                            color: RecordStyle.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 9),
                        RecordPill('${visible.length}'),
                      ],
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(35),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (error != null) ...[
                    RecordEmpty(
                      title: 'Records could not be loaded',
                      message: error!,
                      icon: Icons.cloud_off_outlined,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: RecordAction(label: 'Try again', onPressed: load),
                    ),
                  ] else if (visible.isEmpty)
                    RecordEmpty(
                      title: group == 0
                          ? 'No inactive records found'
                          : 'No rejoined records found',
                      message:
                          'Try another name or adjust the filters. Existing records are always retained.',
                    )
                  else ...[
                    if (!compact)
                      Container(
                        color: RecordStyle.page,
                        child: desktopRow({}, header: true),
                      ),
                    ...visible.expand(
                      (row) => [
                        const Divider(height: 1, color: RecordStyle.line),
                        compact ? mobileRow(row) : desktopRow(row),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: RecordStyle.muted,
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Admin access only. Rejoining an employee does not remove their previous records.',
                    style: TextStyle(color: RecordStyle.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
