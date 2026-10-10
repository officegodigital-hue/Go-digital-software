import 'package:flutter/material.dart';
import '../../../../services/hrms_dashboard_api.dart';
import '../../../../services/hrms_employees_api.dart';

const _blue = Color(0xFF075EF7);
const _navy = Color(0xFF061457);
const _line = Color(0xFFD8E1F1);
const _green = Color(0xFF138B2B);
const _purple = Color(0xFF8500C8);
const _off = Color(0xFF63718F);

abstract final class HrmsColors {
  static const blue = _blue;
  static const navy = _navy;
  static const line = _line;
}

class CalendarStore {
  // Single API call — returns weeklyOffDay, weeklyOffDays set, and overrides together
  static Future<({int weeklyOffDay, Set<int> weeklyOffDays, List<Map<String, dynamic>> overrides})> load() async {
    final calendar = await HrmsDashboardApi.calendar();
    final single = (calendar['weeklyOffDay'] as num?)?.toInt() ?? DateTime.sunday;
    final days = calendar['weeklyOffDays'];
    final Set<int> offDays;
    if (days is List && days.isNotEmpty) {
      offDays = days.map((d) {
        final v = (d as num).toInt();
        return v == 0 ? 7 : v;
      }).toSet();
    } else {
      offDays = {single};
    }
    final overrides = (calendar['overrides'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return (weeklyOffDay: single, weeklyOffDays: offDays, overrides: overrides);
  }

  // Keep legacy methods for any other callers
  static Future<int> loadWeeklyOff() async {
    final r = await load();
    return r.weeklyOffDay;
  }

  static Future<Set<int>> loadWeeklyOffDays() async {
    final r = await load();
    return r.weeklyOffDays;
  }

  static Future<List<Map<String, dynamic>>> loadOverrides() async {
    final r = await load();
    return r.overrides;
  }

  static Future<void> saveWeeklyOff(int weekday) async {
    await HrmsDashboardApi.saveCalendar(weeklyOffDay: weekday);
  }
}

Future<bool> showManageCalendarDialog(BuildContext context) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xA607163E),
    builder: (_) => const ManageCalendarDialog(),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calendar override saved successfully')),
    );
  }
  return saved == true;
}

class ManageCalendarDialog extends StatefulWidget {
  const ManageCalendarDialog({super.key});

  @override
  State<ManageCalendarDialog> createState() => _ManageCalendarDialogState();
}

class _ManageCalendarDialogState extends State<ManageCalendarDialog> {
  late DateTime visibleMonth;
  late int selectedDay;
  int weeklyOffDay = DateTime.sunday;
  Set<int> weeklyOffDays = {DateTime.sunday};
  int? _cachedWorkingDays; // null = loading, shows placeholder until ready
  bool _calendarLoading = true;
  String selectedStatus = 'Working Day';
  String scope = 'All Employees';
  bool notifyEmployees = true;
  bool saving = false;
  bool showEditor = true;
  List<Map<String, dynamic>> overrides = [];
  List<Map<String, dynamic>> employees = [];
  List<String> departments = [];
  String? selectedDepartment;
  Set<int> selectedEmployeeIds = <int>{};
  final reasonController = TextEditingController(text: 'Special working day');

  int _workingDaysForVisibleMonth() {
    final year = visibleMonth.year;
    final month = visibleMonth.month;
    final totalDays = DateUtils.getDaysInMonth(year, month);
    // Only company-wide overrides affect the global working days count
    final overrideMap = <String, String>{};
    for (final o in overrides) {
      final scopeType = o['scopeType'] as String?;
      final scope = o['scope'] as String?;
      final isCompanyWide =
          scopeType == 'all' || scope == 'All Employees' || (scopeType == null && scope == null);
      if (!isCompanyWide) continue;
      final d = o['date'] as String?;
      final s = o['status'] as String?;
      if (d != null && s != null) overrideMap[d] = s;
    }
    int count = 0;
    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(year, month, day);
      final key =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final overrideStatus = overrideMap[key];
      final isOff = overrideStatus != null
          ? overrideStatus != 'Working Day'
          : weeklyOffDays.contains(date.weekday);
      if (!isOff) count++;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    visibleMonth = DateTime(today.year, today.month);
    selectedDay = today.day;
    _loadCalendar();
    _loadTargets();
  }

  Future<void> _loadCalendar() async {
    // Single API call — prevents multiple setState rebuilds causing blink
    final result = await CalendarStore.load();
    if (!mounted) return;
    setState(() {
      weeklyOffDay = result.weeklyOffDay;
      weeklyOffDays = result.weeklyOffDays;
      overrides = result.overrides;
      _calendarLoading = false;
      _cachedWorkingDays = _workingDaysForVisibleMonth();
      _loadSelectedDate(_selectedDate);
    });
  }

  Future<void> _loadTargets() async {
    try {
      final data = await HrmsEmployeesApi.list(limit: 50, status: 'Active');
      final allItems = <dynamic>[...(data['items'] as List? ?? const [])];
      final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
      for (var page = 2; page <= totalPages; page++) {
        final more = await HrmsEmployeesApi.list(
          limit: 50,
          status: 'Active',
          page: page,
        );
        allItems.addAll(more['items'] as List? ?? const []);
      }
      if (!mounted) return;
      setState(() {
        employees = allItems
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['employeeUserId'] is num)
            .toList();
        departments = (data['departments'] as List? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 800;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 32,
        vertical: 18,
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 916, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogHeader(onClose: () => Navigator.pop(context)),
              const SizedBox(height: 18),
              _DefaultWeeklyOff(
                day: _weekdayName(weeklyOffDay),
                onEdit: _showEditDefault,
                workingDays: _cachedWorkingDays,
              ),
              const SizedBox(height: 12),
              if (compact) ...[
                _CalendarPanel(
                  month: visibleMonth,
                  selectedDay: selectedDay,
                  onPrevious: _previousMonth,
                  onNext: _nextMonth,
                  weeklyOffDay: weeklyOffDay,
                  presentationForDate: _calendarPresentation,
                  onSelected: _selectDay,
                ),
                const SizedBox(height: 12),
                showEditor
                    ? _EditDatePanel(
                        selectedDay: selectedDay,
                        month: visibleMonth,
                        status: selectedStatus,
                        currentStatus: _statusFor(_selectedDate),
                        scope: scope,
                        department: selectedDepartment,
                        departments: departments,
                        selectedEmployeeCount: selectedEmployeeIds.length,
                        notifyEmployees: notifyEmployees,
                        reasonController: reasonController,
                        onStatusChanged: (value) =>
                            setState(() => selectedStatus = value!),
                        onScopeChanged: (value) =>
                            setState(() => scope = value),
                        onDepartmentChanged: (value) =>
                            setState(() => selectedDepartment = value),
                        onSelectEmployees: _selectEmployees,
                        onNotifyChanged: (value) =>
                            setState(() => notifyEmployees = value),
                      )
                    : _ScopedOverridesPanel(
                        rules: _scopedRulesFor(_selectedDate),
                        onAddOrEdit: () => setState(() => showEditor = true),
                        onEditRule: _editRule,
                      ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _CalendarPanel(
                        month: visibleMonth,
                        selectedDay: selectedDay,
                        onPrevious: _previousMonth,
                        onNext: _nextMonth,
                        weeklyOffDay: weeklyOffDay,
                        presentationForDate: _calendarPresentation,
                        onSelected: _selectDay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: showEditor
                          ? _EditDatePanel(
                              selectedDay: selectedDay,
                              month: visibleMonth,
                              status: selectedStatus,
                              currentStatus: _statusFor(_selectedDate),
                              scope: scope,
                              department: selectedDepartment,
                              departments: departments,
                              selectedEmployeeCount: selectedEmployeeIds.length,
                              notifyEmployees: notifyEmployees,
                              reasonController: reasonController,
                              onStatusChanged: (value) =>
                                  setState(() => selectedStatus = value!),
                              onScopeChanged: (value) =>
                                  setState(() => scope = value),
                              onDepartmentChanged: (value) =>
                                  setState(() => selectedDepartment = value),
                              onSelectEmployees: _selectEmployees,
                              onNotifyChanged: (value) =>
                                  setState(() => notifyEmployees = value),
                            )
                          : _ScopedOverridesPanel(
                              rules: _scopedRulesFor(_selectedDate),
                              onAddOrEdit: () =>
                                  setState(() => showEditor = true),
                              onEditRule: _editRule,
                            ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              if (showEditor)
                _DialogFooter(
                  compact: compact,
                  onHistory: _showHistory,
                  onCancel: () => Navigator.pop(context),
                  onSave: _saveOverride,
                )
              else
                _ScopedFooter(
                  onHistory: _showHistory,
                  onClose: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1);
      _loadSelectedDate(DateTime(visibleMonth.year, visibleMonth.month, 1));
      if (!_calendarLoading) _cachedWorkingDays = _workingDaysForVisibleMonth();
    });
  }

  DateTime get _selectedDate =>
      DateTime(visibleMonth.year, visibleMonth.month, selectedDay);

  void _selectDay(int day) {
    final date = DateTime(visibleMonth.year, visibleMonth.month, day);
    setState(() {
      _loadSelectedDate(date);
    });
  }

  void _loadSelectedDate(DateTime date) {
    selectedDay = date.day;
    selectedStatus = _statusFor(date);
    final rules = _scopedRulesFor(date);
    showEditor = rules.isEmpty;
  }

  String _statusFor(DateTime date) {
    final key = _dateKey(date);
    final companyRule = overrides
        .where((item) => item['date'] == key && item['scopeType'] == 'all')
        .toList();
    if (companyRule.isNotEmpty) return companyRule.last['status'] as String;
    return date.weekday == weeklyOffDay ? 'Weekly Off' : 'Working Day';
  }

  List<Map<String, dynamic>> _scopedRulesFor(DateTime date) => overrides
      .where(
        (item) => item['date'] == _dateKey(date) && item['scopeType'] != 'all',
      )
      .toList();

  _CalendarDatePresentation _calendarPresentation(DateTime date) {
    final rules = _scopedRulesFor(date);
    final scopedLabel = rules.isEmpty
        ? null
        : '${rules.length} employee overrides';
    return _CalendarDatePresentation(
      mainStatus: _statusFor(date),
      scopedLabel: scopedLabel,
    );
  }

  void _editRule(Map<String, dynamic> rule) {
    setState(() {
      selectedStatus = rule['status']?.toString() ?? selectedStatus;
      scope = rule['scope']?.toString() ?? 'All Employees';
      selectedDepartment = rule['department']?.toString();
      selectedEmployeeIds = ((rule['employeeIds'] as List? ?? const []))
          .whereType<num>()
          .map((id) => id.toInt())
          .toSet();
      reasonController.text = rule['reason']?.toString() ?? '';
      notifyEmployees =
          rule['notifyEmployees'] == true || rule['notifyEmployees'] == 1;
      showEditor = true;
    });
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _weekdayName(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];

  void _nextMonth() {
    setState(() {
      visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + 1);
      _loadSelectedDate(DateTime(visibleMonth.year, visibleMonth.month, 1));
      if (!_calendarLoading) _cachedWorkingDays = _workingDaysForVisibleMonth();
    });
  }

  Future<void> _showEditDefault() async {
    var chosenDay = weeklyOffDay;
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Default Weekly Off'),
        content: StatefulBuilder(
          builder: (context, updateDialog) => DropdownButtonFormField<int>(
            initialValue: chosenDay,
            decoration: const InputDecoration(labelText: 'Weekly off day'),
            items: List.generate(7, (index) => index + 1)
                .map(
                  (day) => DropdownMenuItem(
                    value: day,
                    child: Text(_weekdayName(day)),
                  ),
                )
                .toList(),
            onChanged: (day) => updateDialog(() => chosenDay = day!),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _blue),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (changed == true) {
      await CalendarStore.saveWeeklyOff(chosenDay);
      if (!mounted) return;
      setState(() => weeklyOffDay = chosenDay);
    }
  }

  Future<void> _showHistory() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Calendar change history'),
        content: SizedBox(
          width: 420,
          child: overrides.isEmpty
              ? const Text('No calendar overrides have been saved yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: overrides.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) {
                    final item = overrides.reversed.toList()[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item['date']} • ${item['status']}'),
                      subtitle: Text('${item['scope']} — ${item['reason']}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOverride() async {
    if (saving) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for this change.')),
      );
      return;
    }
    if (scope == 'Department' &&
        (selectedDepartment == null || selectedDepartment!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a department.')));
      return;
    }
    if (scope == 'Selected Employees' && selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose at least one employee.')),
      );
      return;
    }
    final item = <String, dynamic>{
      'date': _dateKey(_selectedDate),
      'status': selectedStatus,
      'scope': scope,
      'department': selectedDepartment,
      'employeeIds': selectedEmployeeIds.toList(),
      'reason': reason,
      'notifyEmployees': notifyEmployees,
      'savedAt': DateTime.now().toIso8601String(),
    };
    setState(() => saving = true);
    try {
      await HrmsDashboardApi.saveCalendar(override: item);
      if (!mounted) return;
      await _loadCalendar();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _selectEmployees() async {
    final chosen = Set<int>.from(selectedEmployeeIds);
    final searchController = TextEditingController();
    var search = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final filteredEmployees = employees.where((employee) {
            final haystack =
                '${employee['name'] ?? ''} ${employee['department'] ?? ''}'
                    .toLowerCase();
            return haystack.contains(search.toLowerCase());
          }).toList();
          return AlertDialog(
            title: const Text('Select employees'),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (value) => update(() => search = value.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search by employee or department',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: employees.isEmpty
                        ? const Center(
                            child: Text('No active employees available.'),
                          )
                        : filteredEmployees.isEmpty
                        ? const Center(
                            child: Text('No employees match your search.'),
                          )
                        : ListView(
                            children: filteredEmployees.map((employee) {
                              final id = (employee['employeeUserId'] as num)
                                  .toInt();
                              return CheckboxListTile(
                                value: chosen.contains(id),
                                title: Text(
                                  employee['name']?.toString() ?? 'Employee',
                                ),
                                subtitle: Text(
                                  employee['department']?.toString() ?? '',
                                ),
                                onChanged: (checked) => update(
                                  () => checked == true
                                      ? chosen.add(id)
                                      : chosen.remove(id),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    searchController.dispose();
    if (saved == true && mounted) setState(() => selectedEmployeeIds = chosen);
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.edit_calendar_outlined,
        color: HrmsColors.blue,
        size: 38,
      ),
      const SizedBox(width: 18),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Calendar',
              style: TextStyle(
                color: HrmsColors.navy,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Set weekly offs and change specific working days',
              style: TextStyle(color: Color(0xFF50649E), fontSize: 13),
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: onClose,
        icon: const Icon(Icons.close_rounded, color: HrmsColors.navy, size: 25),
      ),
    ],
  );
}

class _DefaultWeeklyOff extends StatelessWidget {
  const _DefaultWeeklyOff({required this.day, required this.onEdit, required this.workingDays});

  final String day;
  final VoidCallback onEdit;
  final int? workingDays;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 18, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: HrmsColors.line),
      borderRadius: BorderRadius.circular(9),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08071A72),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Default Weekly Off',
          style: TextStyle(
            color: HrmsColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (_, constraints) {
            final compact = constraints.maxWidth < 650;
            final details = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DefaultItem(label: 'Day', value: day),
                _VerticalRule(),
                _DefaultItem(label: 'Status', value: 'OFF', badge: true),
                _VerticalRule(),
                _DefaultItem(label: 'Applies To', value: 'All Employees'),
                _VerticalRule(),
                _DefaultItem(label: 'Working Days', value: workingDays != null ? '$workingDays days' : '–'),
              ],
            );
            final edit = OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 19),
              label: const Text('Edit Default'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HrmsColors.blue,
                side: const BorderSide(color: HrmsColors.blue),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      _DefaultItem(label: 'Day', value: day, compact: true),
                      _DefaultItem(
                        label: 'Status',
                        value: 'OFF',
                        badge: true,
                        compact: true,
                      ),
                      _DefaultItem(
                        label: 'Applies To',
                        value: 'All Employees',
                        compact: true,
                      ),
                      _DefaultItem(
                        label: 'Working Days',
                        value: workingDays != null ? '$workingDays days' : '–',
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  edit,
                ],
              );
            }
            return Row(children: [details, const Spacer(), edit]);
          },
        ),
      ],
    ),
  );
}

class _DefaultItem extends StatelessWidget {
  const _DefaultItem({
    required this.label,
    required this.value,
    this.badge = false,
    this.compact = false,
  });
  final String label, value;
  final bool badge;
  final bool compact;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 118 : 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: HrmsColors.navy, fontSize: 11),
        ),
        const SizedBox(height: 6),
        badge
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECF4),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  value,
                  style: const TextStyle(color: HrmsColors.navy, fontSize: 11),
                ),
              )
            : Text(
                value,
                style: const TextStyle(color: HrmsColors.navy, fontSize: 13),
              ),
      ],
    ),
  );
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 39,
    margin: const EdgeInsets.only(right: 18),
    color: HrmsColors.line,
  );
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.month,
    required this.selectedDay,
    required this.onPrevious,
    required this.onNext,
    required this.weeklyOffDay,
    required this.presentationForDate,
    required this.onSelected,
  });

  final DateTime month;
  final int selectedDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final int weeklyOffDay;
  final _CalendarDatePresentation Function(DateTime) presentationForDate;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: HrmsColors.line),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      children: [
        Row(
          children: [
            _ArrowButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
            const SizedBox(width: 14),
            Text(
              '${_monthName(month.month)} ${month.year}',
              style: const TextStyle(
                color: HrmsColors.blue,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            _ArrowButton(icon: Icons.chevron_right_rounded, onTap: onNext),
          ],
        ),
        const Divider(height: 15, color: HrmsColors.line),
        Row(
          children: [
            for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'])
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: HrmsColors.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.04,
          ),
          itemCount: 42,
          itemBuilder: (_, index) {
            final offset = DateTime(month.year, month.month, 1).weekday - 1;
            final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
            final day = index - offset + 1;
            if (day < 1 || day > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = DateTime(month.year, month.month, day);
            return _CalendarDay(
              date: date,
              day: day,
              weeklyOffDay: weeklyOffDay,
              presentation: presentationForDate(date),
              selected: day == selectedDay,
              onTap: () => onSelected(day),
            );
          },
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 24,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _CalendarLegend('Working Day', HrmsColors.blue),
            _CalendarLegend('Weekly Off', Color(0xFF63718F)),
            _CalendarLegend('Holiday', Color(0xFF8500C8)),
            _CalendarLegend('Saved change', Color(0xFF168B2A)),
          ],
        ),
      ],
    ),
  );

  static String _monthName(int month) => const [
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
  ][month - 1];
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: 30,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: HrmsColors.line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, color: HrmsColors.blue, size: 20),
    ),
  );
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.day,
    required this.weeklyOffDay,
    required this.presentation,
    required this.selected,
    required this.onTap,
  });
  final DateTime date;
  final int day;
  final int weeklyOffDay;
  final _CalendarDatePresentation presentation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weeklyOff = presentation.mainStatus == 'Weekly Off';
    final holiday = presentation.mainStatus == 'Holiday';
    final color = holiday
        ? _purple
        : weeklyOff
        ? _off
        : HrmsColors.blue;
    final label = holiday
        ? 'Holiday'
        : weeklyOff
        ? 'OFF'
        : 'Working Day';
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: weeklyOff ? const Color(0xFFF6F8FC) : Colors.white,
          border: Border.all(
            color: selected ? HrmsColors.blue : const Color(0xFFE4E9F2),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: selected ? BorderRadius.circular(6) : BorderRadius.zero,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: holiday ? _purple : HrmsColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: HrmsColors.navy, fontSize: 7),
                  ),
                ),
              ],
            ),
            if (presentation.scopedLabel != null) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E9FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  presentation.scopedLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _purple,
                    fontSize: 6.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarDatePresentation {
  const _CalendarDatePresentation({required this.mainStatus, this.scopedLabel});
  final String mainStatus;
  final String? scopedLabel;
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: HrmsColors.navy, fontSize: 10)),
    ],
  );
}

class _ScopedOverridesPanel extends StatelessWidget {
  const _ScopedOverridesPanel({
    required this.rules,
    required this.onAddOrEdit,
    required this.onEditRule,
  });
  final List<Map<String, dynamic>> rules;
  final VoidCallback onAddOrEdit;
  final ValueChanged<Map<String, dynamic>> onEditRule;

  @override
  Widget build(BuildContext context) {
    final departmentRows =
        <
          (String name, String source, String status, Map<String, dynamic> rule)
        >[];
    final employeeRows =
        <
          (String name, String source, String status, Map<String, dynamic> rule)
        >[];
    for (final rule in rules) {
      if (rule['scopeType'] == 'employees') {
        for (final target in (rule['targetEmployees'] as List? ?? const [])) {
          final map = Map<String, dynamic>.from(target as Map);
          employeeRows.add((
            map['name']?.toString() ?? 'Employee',
            'Selected employee',
            rule['status']?.toString() ?? '',
            rule,
          ));
        }
      } else {
        departmentRows.add((
          rule['department']?.toString() ?? 'Department',
          'Department',
          rule['status']?.toString() ?? '',
          rule,
        ));
      }
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HrmsColors.line),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Scoped overrides',
                  style: TextStyle(
                    color: HrmsColors.blue,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: onAddOrEdit,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: HrmsColors.blue),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Add override',
                    style: TextStyle(
                      color: HrmsColors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'These rules affect only their listed department or employee. The more specific employee rule wins.',
            style: TextStyle(
              color: Color(0xFF50649E),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (departmentRows.isNotEmpty) ...[
            const _OverrideSectionTitle('Department overrides'),
            for (final row in departmentRows)
              _ScopedOverrideRow(
                row: row,
                icon: Icons.account_tree_outlined,
                onEdit: onEditRule,
              ),
          ],
          if (employeeRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _OverrideSectionTitle('Employee overrides'),
            for (final row in employeeRows)
              _ScopedOverrideRow(
                row: row,
                icon: Icons.person_outline,
                onEdit: onEditRule,
              ),
          ],
        ],
      ),
    );
  }
}

class _OverrideSectionTitle extends StatelessWidget {
  const _OverrideSectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF50649E),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
      ),
    ),
  );
}

class _ScopedOverrideRow extends StatelessWidget {
  const _ScopedOverrideRow({
    required this.row,
    required this.icon,
    required this.onEdit,
  });

  final (String, String, String, Map<String, dynamic>) row;
  final IconData icon;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onEdit(row.$4),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HrmsColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF3E9FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: _purple),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.$1,
                  style: const TextStyle(
                    color: HrmsColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  row.$2,
                  style: const TextStyle(
                    color: Color(0xFF7182A5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _ScopeStatus(status: row.$3),
        ],
      ),
    ),
  );
}

class _ScopeStatus extends StatelessWidget {
  const _ScopeStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'Holiday'
        ? _purple
        : status == 'Weekly Off'
        ? _off
        : _green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScopedFooter extends StatelessWidget {
  const _ScopedFooter({required this.onHistory, required this.onClose});
  final VoidCallback onHistory;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      InkWell(
        onTap: onHistory,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            'History',
            style: TextStyle(
              color: HrmsColors.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      InkWell(
        onTap: onClose,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: HrmsColors.blue,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Text(
            'Close',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );
}

class _EditDatePanel extends StatelessWidget {
  const _EditDatePanel({
    required this.selectedDay,
    required this.month,
    required this.status,
    required this.currentStatus,
    required this.scope,
    required this.department,
    required this.departments,
    required this.selectedEmployeeCount,
    required this.notifyEmployees,
    required this.reasonController,
    required this.onStatusChanged,
    required this.onScopeChanged,
    required this.onDepartmentChanged,
    required this.onSelectEmployees,
    required this.onNotifyChanged,
  });
  final int selectedDay;
  final DateTime month;
  final String status, currentStatus, scope;
  final String? department;
  final List<String> departments;
  final int selectedEmployeeCount;
  final bool notifyEmployees;
  final TextEditingController reasonController;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<String?> onDepartmentChanged;
  final VoidCallback onSelectEmployees;
  final ValueChanged<bool> onNotifyChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: HrmsColors.line),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Edit Selected Date',
          style: TextStyle(
            color: HrmsColors.blue,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _LabelValue(
                label: 'Selected Date',
                value:
                    '${_weekday(month, selectedDay)}, '
                    '$selectedDay ${_shortMonth(month.month)} ${month.year}',
              ),
            ),
            _LabelValue(
              label: 'Current Status',
              value: currentStatus,
              badge: true,
            ),
          ],
        ),
        const SizedBox(height: 13),
        const Text('Change Status', style: _fieldLabel),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: status,
          onChanged: onStatusChanged,
          decoration: _fieldDecoration(
            prefix: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
              ),
            ),
          ),
          items: const ['Working Day', 'Weekly Off', 'Holiday']
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
        ),
        const SizedBox(height: 13),
        const Text('Apply To', style: _fieldLabel),
        const SizedBox(height: 6),
        _ScopeSelector(scope: scope, onChanged: onScopeChanged),
        const SizedBox(height: 13),
        if (scope == 'Department') ...[
          const Text('Department', style: _fieldLabel),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey(department),
            initialValue: department,
            decoration: _fieldDecoration(),
            hint: const Text('Choose department'),
            items: departments
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: onDepartmentChanged,
          ),
          const SizedBox(height: 13),
        ],
        if (scope == 'Selected Employees') ...[
          const Text('Employees', style: _fieldLabel),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: onSelectEmployees,
            icon: const Icon(Icons.people_outline),
            label: Text(
              selectedEmployeeCount == 0
                  ? 'Choose employees'
                  : '$selectedEmployeeCount employees selected',
            ),
          ),
          const SizedBox(height: 13),
        ],
        const Text('Reason', style: _fieldLabel),
        const SizedBox(height: 6),
        TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: _fieldDecoration(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Notify affected employees',
                style: TextStyle(color: HrmsColors.navy, fontSize: 11),
              ),
            ),
            Switch(
              value: notifyEmployees,
              onChanged: onNotifyChanged,
              activeThumbColor: HrmsColors.blue,
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: HrmsColors.blue, size: 19),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This change updates working days, attendance totals and salary calculations.',
                  style: TextStyle(
                    color: HrmsColors.blue,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static String _weekday(DateTime month, int day) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][DateTime(month.year, month.month, day).weekday - 1];

  static String _shortMonth(int month) => const [
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
  ][month - 1];
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    this.badge = false,
  });
  final String label, value;
  final bool badge;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF50649E), fontSize: 10),
      ),
      const SizedBox(height: 6),
      badge
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE6EAF3),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                value,
                style: const TextStyle(color: HrmsColors.navy, fontSize: 9),
              ),
            )
          : Text(
              value,
              style: const TextStyle(
                color: HrmsColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
    ],
  );
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({required this.scope, required this.onChanged});
  final String scope;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    decoration: BoxDecoration(
      border: Border.all(color: HrmsColors.line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        for (final item in const [
          ('All Employees', Icons.groups_outlined),
          ('Department', Icons.apartment_outlined),
          ('Selected Employees', Icons.person_outline),
        ])
          Expanded(
            child: InkWell(
              onTap: () => onChanged(item.$1),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scope == item.$1 ? HrmsColors.blue : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.$2,
                      color: scope == item.$1 ? Colors.white : HrmsColors.navy,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        item.$1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scope == item.$1
                              ? Colors.white
                              : HrmsColors.navy,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

InputDecoration _fieldDecoration({Widget? prefix}) => InputDecoration(
  prefixIcon: prefix == null ? null : Center(widthFactor: 1, child: prefix),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: HrmsColors.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: HrmsColors.blue),
  ),
);

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.compact,
    required this.onHistory,
    required this.onCancel,
    required this.onSave,
  });
  final bool compact;
  final VoidCallback onHistory, onCancel, onSave;

  @override
  Widget build(BuildContext context) {
    final history = TextButton.icon(
      onPressed: onHistory,
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: const Text('View change history'),
      style: TextButton.styleFrom(foregroundColor: HrmsColors.blue),
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: HrmsColors.blue,
            side: const BorderSide(color: HrmsColors.blue),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 18),
        FilledButton(
          onPressed: onSave,
          style: FilledButton.styleFrom(
            backgroundColor: HrmsColors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 43, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: const Text('Save Override'),
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: history),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HrmsColors.blue,
                    side: const BorderSide(color: HrmsColors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: HrmsColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Override'),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Row(children: [history, const Spacer(), buttons]);
  }
}

const _fieldLabel = TextStyle(
  color: HrmsColors.navy,
  fontSize: 10,
  fontWeight: FontWeight.w600,
);
