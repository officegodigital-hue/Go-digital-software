import 'leave_policy_dialog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../shared/widgets/admin_top_nav.dart';
import '../../../services/hrms_employees_api.dart';
import '../../../services/api_config.dart';
import '../../../services/auth_storage.dart';

abstract final class HrmsColors {
  static const blue = Color(0xFF075EF7);
  static const navy = Color(0xFF061457);
  static const page = Color(0xFFFCFDFF);
  static const line = Color(0xFFD8E1F1);
}

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  static Widget builder(BuildContext context) => const EmployeesPage();

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final searchController = TextEditingController();
  String query = '';
  String department = 'All Departments';
  String status = 'All Status';
  String workMode = 'All Work Modes';
  int currentPage = 1;
  static const pageSize = 6;
  Timer? _searchDebounce;

  List<_Employee> employees = [];
  List<String> departmentOptions = const [];
  int filteredTotal = 0;
  int totalPages = 1;
  int kpiTotal = 0;
  int kpiActive = 0;
  int kpiOnLeave = 0;
  int kpiInactive = 0;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await HrmsEmployeesApi.list(
        search: query,
        department: department,
        status: status,
        workMode: workMode,
        page: currentPage,
        limit: pageSize,
      );
      final items = (data['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => _Employee.fromApi(Map<String, dynamic>.from(item)))
          .toList();
      final kpis = Map<String, dynamic>.from(data['kpis'] as Map? ?? {});
      final departments =
          (data['departments'] as List? ?? [])
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        employees = items;
        departmentOptions = departments;
        filteredTotal = data['total'] is int
            ? data['total'] as int
            : int.tryParse('${data['total']}') ?? items.length;
        totalPages = data['totalPages'] is int
            ? data['totalPages'] as int
            : int.tryParse('${data['totalPages']}') ?? 1;
        currentPage = data['page'] is int
            ? data['page'] as int
            : int.tryParse('${data['page']}') ?? currentPage;
        kpiTotal = _asInt(kpis['total']);
        kpiActive = _asInt(kpis['active']);
        kpiOnLeave = _asInt(kpis['onLeave']);
        kpiInactive = _asInt(kpis['inactive']);
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

  int _asInt(dynamic value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  void _resetPageAndLoad() {
    currentPage = 1;
    _loadEmployees();
  }

  void _onSearchChanged(String value) {
    query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _resetPageAndLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: HrmsColors.page,
      bottomNavigationBar: mobile ? const AdminMobileBottomNav(activeRoute: '/admin/employees') : null,
      body: Column(
        children: [
          const AdminTopNav(activeRoute: '/admin/employees'),
          Expanded(
            child: loading && employees.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : error != null && employees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(error!, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadEmployees,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 16 : 38,
                      18,
                      mobile ? 16 : 38,
                      28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1580),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PageHeader(
                              onAdd: () => _showEmployeeForm(),
                              onExport: _exportEmployees,
                              onLeavePolicy: _showLeavePolicies,
                            ),
                            const SizedBox(height: 18),
                            _EmployeeKpis(
                              mobile: mobile,
                              total: kpiTotal,
                              active: kpiActive,
                              onLeave: kpiOnLeave,
                              inactive: kpiInactive,
                            ),
                            const SizedBox(height: 18),
                            _Filters(
                              searchController: searchController,
                              department: department,
                              departmentOptions: departmentOptions,
                              status: status,
                              workMode: workMode,
                              onSearch: _onSearchChanged,
                              onDepartment: (value) {
                                department = value!;
                                _resetPageAndLoad();
                              },
                              onStatus: (value) {
                                status = value!;
                                _resetPageAndLoad();
                              },
                              onMode: (value) {
                                workMode = value!;
                                _resetPageAndLoad();
                              },
                              onReset: _resetFilters,
                            ),
                            const SizedBox(height: 14),
                            if (loading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            _EmployeeTable(
                              employees: employees,
                              total: filteredTotal,
                              currentPage: currentPage
                                  .clamp(1, totalPages)
                                  .toInt(),
                              totalPages: totalPages,
                              mobile: mobile,
                              onPageChanged: (page) {
                                currentPage = page.clamp(1, totalPages).toInt();
                                _loadEmployees();
                              },
                              onView: _showEmployeeDetails,
                              onEdit: (employee) =>
                                  _showEmployeeForm(employee: employee),
                              onToggle: _toggleEmployee,
                              onDelete: _confirmDelete,
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

  void _resetFilters() {
    query = '';
    department = 'All Departments';
    status = 'All Status';
    workMode = 'All Work Modes';
    currentPage = 1;
    searchController.clear();
    _loadEmployees();
  }

  Future<void> _exportEmployees() async {
    try {
      final csv = await HrmsEmployeesApi.exportCsv();
      final rows = _parseCsv(csv);
      if (rows.length <= 1) throw Exception('No employees available to export.');
      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/godigital_logo.png')).buffer.asUint8List(),
      );
      final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      final document = pw.Document();
      document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 30),
        header: (context) => pw.Column(children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Container(width: 54, height: 54, padding: const pw.EdgeInsets.all(6), child: pw.Image(logo, fit: pw.BoxFit.contain)),
            pw.SizedBox(width: 12),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('GO DIGITAL', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.Text('Employee Directory', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ]),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('EMPLOYEE MANAGEMENT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
              pw.Text('Generated $generatedAt', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ]),
          ]),
          pw.SizedBox(height: 12),
          pw.Container(height: 2, color: PdfColors.blue700),
          pw.SizedBox(height: 14),
        ]),
        footer: (context) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('GoDigital - Confidential internal record', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ]),
        build: (context) => [
          pw.Text('Employee Directory', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 5),
          pw.Text('${rows.length - 1} employees', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: rows.first,
            data: rows.skip(1).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF075EF7)),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.blue900),
            cellHeight: 26,
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD8E1F1), width: .6),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F7FC)),
          ),
        ],
      ));
      await Printing.layoutPdf(onLayout: (_) => document.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Professional employee PDF is ready.')));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    for (final line in input.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) continue;
      final values = line.contains('"')
          ? RegExp(r'"((?:""|[^"])*)"').allMatches(line).map((match) => match.group(1)!.replaceAll('""', '"')).toList()
          : line.split(',').map((value) => value.trim()).toList();
      if (values.isNotEmpty) rows.add(values);
    }
    return rows;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      await _loadEmployees();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _showLeavePolicies() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const LeavePolicyDialog());
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave policies saved.')));
    }
  }
  Future<void> _showEmployeeForm({_Employee? employee}) async {
    final name = TextEditingController(text: employee?.name ?? '');
    final id = TextEditingController(
      text: employee?.id ?? 'EMP${1001 + kpiTotal}',
    );
    final salary = TextEditingController(
      text: employee?.salary == 'Not Set'
          ? ''
          : employee?.salary.replaceAll(RegExp(r'[^0-9]'), '') ?? '',
    );
    final availableDepartments = <String>{
      ...departmentOptions,
      if (employee?.department != null) employee!.department,
    }.toList()..sort();
    var selectedDepartment =
        employee?.department ??
        (availableDepartments.isNotEmpty
            ? availableDepartments.first
            : 'Engineering');
    var selectedMode = employee?.workMode ?? 'Office';
    var selectedStatus = employee?.status ?? 'Active';
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(employee == null ? 'Add Employee' : 'Edit Employee'),
          content: SizedBox(
            width: 470,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _formField(name, 'Employee name'),
                    const SizedBox(height: 12),
                    _formField(id, 'Employee ID'),
                    const SizedBox(height: 12),
                    _formDropdown(
                      'Department',
                      selectedDepartment,
                      availableDepartments,
                      (value) =>
                          setDialogState(() => selectedDepartment = value!),
                      onAddRole: () async {
                        final role = await _showAddRoleDialog(dialogContext);
                        if (role == null || !mounted) return;
                        try {
                          await HrmsEmployeesApi.createRole(role);
                          if (!mounted) return;
                          setState(() {
                            departmentOptions = {
                              ...departmentOptions,
                              role,
                            }.toList()..sort();
                          });
                          setDialogState(() {
                            if (!availableDepartments.contains(role)) {
                              availableDepartments.add(role);
                              availableDepartments.sort();
                            }
                            selectedDepartment = role;
                          });
                        } catch (err) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                err.toString().replaceFirst('Exception: ', ''),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _formDropdown('Work mode', selectedMode, const [
                      'Office',
                      'Home',
                      'Field',
                    ], (value) => setDialogState(() => selectedMode = value!)),
                    const SizedBox(height: 12),
                    _formDropdown(
                      'Employment status',
                      selectedStatus,
                      const ['Active', 'On Leave', 'Inactive'],
                      (value) => setDialogState(() => selectedStatus = value!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: salary,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly salary (optional)',
                        prefixText: '₹',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(employee == null ? 'Add Employee' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final body = {
      'name': name.text.trim(),
      'employeeCode': id.text.trim(),
      'department': selectedDepartment,
      'workMode': selectedMode,
      'status': selectedStatus,
      'salary': salary.text.trim(),
    };
    await _runAction(() async {
      if (employee == null) {
        await HrmsEmployeesApi.create(body);
      } else {
        await HrmsEmployeesApi.update(employee.profileId, body);
      }
    });
  }

  Widget _formField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? '$label is required' : null,
      );

  Future<String?> _showAddRoleDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add new role'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Role name',
            hintText: 'e.g. Content Writer',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final role = controller.text.trim();
              if (role.isNotEmpty) Navigator.pop(dialogContext, role);
            },
            child: const Text('Add role'),
          ),
        ],
      ),
    );
  }

  Widget _formDropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged, {
    Future<void> Function()? onAddRole,
  }) {
    // Keep the employee's current designation even when it is a custom value,
    // and ensure each dropdown value appears only once.
    final dropdownValues = <String>{...values, value}.toList();
    const addRoleValue = '__add_new_role__';
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (onAddRole != null)
          const DropdownMenuItem(
            value: addRoleValue,
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, color: HrmsColors.blue),
                SizedBox(width: 8),
                Text('Add new role'),
              ],
            ),
          ),
        ...dropdownValues.map(
          (item) => DropdownMenuItem(value: item, child: Text(item)),
        ),
      ],
      onChanged: (selected) {
        if (selected == addRoleValue) {
          onAddRole?.call();
          return;
        }
        onChanged(selected);
      },
    );
  }

  Future<void> _showEmployeeDetails(_Employee employee) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(employee.name),
      content: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('Employee ID', employee.id),
            _detailRow('Department', employee.department),
            _detailRow('Work mode', employee.workMode),
            _detailRow('Monthly salary', employee.salary),
            _detailRow('Status', employee.status),
          ],
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

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF657087))),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Future<void> _toggleEmployee(_Employee employee) async {
    final next = employee.status == 'Inactive' ? 'Active' : 'Inactive';
    await _runAction(
      () => HrmsEmployeesApi.updateStatus(employee.profileId, next),
    );
  }

  Future<void> _confirmDelete(_Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text(
          '${employee.name} will be removed from the employee list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAction(() => HrmsEmployeesApi.delete(employee.profileId));
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onAdd, required this.onExport, required this.onLeavePolicy});

  final VoidCallback onAdd, onExport, onLeavePolicy;

  @override
  Widget build(BuildContext context) => AdminPageHeader(
    title: 'Employee Management',
    breadcrumb: 'Employees',
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(onPressed: onLeavePolicy, icon: const Icon(Icons.event_available_outlined), label: const Text('Leave Policy'), style: OutlinedButton.styleFrom(foregroundColor: HrmsColors.navy, side: const BorderSide(color: HrmsColors.line), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)))),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 25),
          label: const Text('Add Employee'),
          style: FilledButton.styleFrom(
            backgroundColor: HrmsColors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
        const SizedBox(width: 14),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HrmsColors.blue,
            side: const BorderSide(color: Color(0xFF9FBCFF)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmployeeKpis extends StatelessWidget {
  const _EmployeeKpis({
    required this.mobile,
    required this.total,
    required this.active,
    required this.onLeave,
    required this.inactive,
  });
  final bool mobile;
  final int total, active, onLeave, inactive;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _EmployeeKpi(
        'Total Employees',
        '$total',
        'Across all departments',
        Icons.groups_outlined,
        HrmsColors.blue,
      ),
      _EmployeeKpi(
        'Active',
        '$active',
        _percentage(active, total),
        Icons.person_outline_rounded,
        const Color(0xFF148B1A),
      ),
      _EmployeeKpi(
        'On Leave',
        '$onLeave',
        _percentage(onLeave, total),
        Icons.event_busy_outlined,
        const Color(0xFFFF6500),
      ),
      _EmployeeKpi(
        'Inactive',
        '$inactive',
        _percentage(inactive, total),
        Icons.person_off_outlined,
        const Color(0xFFF0182A),
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = mobile
            ? 4
            : constraints.maxWidth < 650
            ? 2
            : constraints.maxWidth < 1100
            ? 2
            : 4;
        final spacing = mobile ? 8.0 : 20.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: mobile ? 8 : 16,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }

  String _percentage(int value, int total) => total == 0
      ? '0% of total'
      : '${(value * 100 / total).toStringAsFixed(1)}% of total';
}

class _EmployeeKpi extends StatelessWidget {
  const _EmployeeKpi(
    this.label,
    this.value,
    this.caption,
    this.icon,
    this.color,
  );
  final String label, value, caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      final mobileLabel = label == 'Total Employees' ? 'Employees' : label;
      return Container(
        height: 80,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: .25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mobileLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF50649E), fontSize: 11)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 25, fontWeight: FontWeight.w800)),
        ]),
      );
    }
    return LayoutBuilder(
    builder: (_, constraints) {
      final compact = constraints.maxWidth < 220;
      return Container(
        height: 116,
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16,
          14,
          compact ? 12 : 16,
          9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: .28)),
          borderRadius: BorderRadius.circular(13),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08071A72),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 42 : 54,
                  height: compact ? 42 : 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: compact ? 23 : 29),
                ),
                SizedBox(width: compact ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HrmsColors.navy,
                          fontSize: compact ? 11 : 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: TextStyle(
                          color: HrmsColors.navy,
                          fontSize: compact ? 23 : 27,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!compact)
                        Text(
                          caption,
                          style: const TextStyle(
                            color: Color(0xFF50649E),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: compact ? 40 : 55,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.department,
    required this.departmentOptions,
    required this.status,
    required this.workMode,
    required this.onSearch,
    required this.onDepartment,
    required this.onStatus,
    required this.onMode,
    required this.onReset,
  });

  final TextEditingController searchController;
  final String department, status, workMode;
  final List<String> departmentOptions;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onDepartment, onStatus, onMode;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 0 : 20),
    decoration: BoxDecoration(
      color: MediaQuery.sizeOf(context).width < 600 ? Colors.transparent : Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: MediaQuery.sizeOf(context).width < 600 ? const [] : const [
        BoxShadow(
          color: Color(0x0C071A72),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (_, constraints) {
        final narrow = constraints.maxWidth < 850;
        final search = TextField(
          controller: searchController,
          onChanged: onSearch,
          decoration: _inputDecoration('Search by name, employee ID or email', Icons.search_rounded),
        );
        final departmentField = _FilterDropdown(label: 'Department', value: department, values: ['All Departments', ...departmentOptions], onChanged: onDepartment);
        final statusField = _FilterDropdown(label: 'Status', value: status, values: const ['All Status', 'Active', 'On Leave', 'Inactive'], onChanged: onStatus);
        final modeField = _FilterDropdown(label: 'Work Mode', value: workMode, values: const ['All Work Modes', 'Office', 'Home', 'Field'], onChanged: onMode);
        final reset = Tooltip(
          message: 'Reset filters',
          child: OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(56, 56),
              side: const BorderSide(color: Color(0xFFA8C0F8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: const Icon(Icons.restart_alt_rounded, color: HrmsColors.blue),
          ),
        );
        final mobile = MediaQuery.sizeOf(context).width < 600;
        if (mobile) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            search,
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () => _openMobileFilters(context),
                icon: const Icon(Icons.tune_rounded, size: 20),
                label: const Text('Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HrmsColors.blue,
                  side: const BorderSide(color: HrmsColors.blue),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset'),
              ),
            ]),
          ]);
        }
        if (narrow) {
          final stackFilters = constraints.maxWidth < 410;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            search,
            const SizedBox(height: 14),
            if (stackFilters) ...[
              departmentField,
              const SizedBox(height: 12),
              statusField,
            ] else
              Row(children: [Expanded(child: departmentField), const SizedBox(width: 12), Expanded(child: statusField)]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: modeField), const SizedBox(width: 12), reset]),
          ]);
        }
        final fields = [SizedBox(width: 430, child: search), departmentField, statusField, modeField, reset];
        return Wrap(
          spacing: 26,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: fields,
        );
      },
    ),
  );

  void _openMobileFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFFD8E1F0), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            const Text('Filter employees', style: TextStyle(color: HrmsColors.navy, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _FilterDropdown(label: 'Department', value: department, values: ['All Departments', ...departmentOptions], onChanged: onDepartment),
            const SizedBox(height: 12),
            _FilterDropdown(label: 'Status', value: status, values: const ['All Status', 'Active', 'On Leave', 'Inactive'], onChanged: onStatus),
            const SizedBox(height: 12),
            _FilterDropdown(label: 'Work Mode', value: workMode, values: const ['All Work Modes', 'Office', 'Home', 'Field'], onChanged: onMode),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () { onReset(); Navigator.pop(sheetContext); }, child: const Text('Reset'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Apply filters'))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MobileFilterChip extends StatelessWidget {
  const _MobileFilterChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    onPressed: onTap,
    backgroundColor: const Color(0xFFEAF2FF),
    side: BorderSide.none,
    avatar: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF50649E)),
    label: Text(label, style: const TextStyle(color: HrmsColors.navy, fontSize: 13)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );
}

InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF50649E), fontSize: 14),
  prefixIcon: Icon(icon, color: HrmsColors.navy),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(vertical: 18),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: HrmsColors.line),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: HrmsColors.blue),
  ),
);

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label, value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 600 ? double.infinity : 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(color: HrmsColors.navy, fontSize: 13),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          decoration: _inputDecoration('', Icons.filter_alt_outlined).copyWith(
            prefixIcon: null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 17,
            ),
          ),
          items: values
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
        ),
      ],
    ),
  );
}

class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({
    required this.employees,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    required this.mobile,
    required this.onPageChanged,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final List<_Employee> employees;
  final int total, currentPage, totalPages;
  final bool mobile;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<_Employee> onView, onEdit, onToggle, onDelete;

  @override
  Widget build(BuildContext context) => mobile
      ? _MobileEmployeeList(
          employees: employees,
          total: total,
          onView: onView,
          onEdit: onEdit,
          onToggle: onToggle,
          onDelete: onDelete,
        )
      : Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE6EAF2)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0B071A72),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1480,
                  child: Column(
                    children: [
                      const _TableHeader(),
                      if (employees.isEmpty)
                        const SizedBox(
                          height: 170,
                          child: Center(
                            child: Text('No employees match these filters.'),
                          ),
                        )
                      else
                        ...employees.map(
                          (employee) => _EmployeeRow(
                            employee: employee,
                            onView: () => onView(employee),
                            onEdit: () => onEdit(employee),
                            onToggle: () => onToggle(employee),
                            onDelete: () => onDelete(employee),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Text(
                      _showingText(),
                      style: const TextStyle(
                        color: Color(0xFF50649E),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    _PageButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: currentPage > 1,
                      onTap: () => onPageChanged(currentPage - 1),
                    ),
                    ..._visiblePages().map(
                      (page) => page == 0
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('...'),
                            )
                          : _PageButton(
                              text: '$page',
                              active: page == currentPage,
                              onTap: () => onPageChanged(page),
                            ),
                    ),
                    _PageButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: currentPage < totalPages,
                      onTap: () => onPageChanged(currentPage + 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

  String _showingText() {
    if (total == 0) return 'Showing 0 of 0 employees';
    final first = (currentPage - 1) * _EmployeesPageState.pageSize + 1;
    final last = (first + employees.length - 1).clamp(0, total).toInt();
    return 'Showing $first–$last of $total employees';
  }

  List<int> _visiblePages() {
    if (totalPages <= 5) {
      return List.generate(totalPages, (index) => index + 1);
    }
    if (currentPage <= 3) return [1, 2, 3, 0, totalPages];
    if (currentPage >= totalPages - 2) {
      return [1, 0, totalPages - 2, totalPages - 1, totalPages];
    }
    return [1, 0, currentPage, 0, totalPages];
  }
}

class _MobileEmployeeList extends StatelessWidget {
  const _MobileEmployeeList({
    required this.employees,
    required this.total,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final List<_Employee> employees;
  final int total;
  final ValueChanged<_Employee> onView, onEdit, onToggle, onDelete;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No employees match these filters.')),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5EAF3)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x08071A72), blurRadius: 14, offset: Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 12),
          child: Row(children: [
            Expanded(child: Text('Employees ($total)', style: const TextStyle(color: HrmsColors.navy, fontSize: 17, fontWeight: FontWeight.w800))),
            const Text('Sort by', style: TextStyle(color: Color(0xFF657087), fontSize: 12)),
            TextButton.icon(onPressed: () {}, iconAlignment: IconAlignment.end, icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18), label: const Text('Name')),
          ]),
        ),
        const _MobileEmployeeHeader(),
        ...employees.map((employee) => _CompactMobileEmployeeRow(
          employee: employee,
          onView: () => onView(employee),
          onEdit: () => onEdit(employee),
          onToggle: () => onToggle(employee),
          onDelete: () => onDelete(employee),
        )),
      ]),
    );
  }
}

class _MobileEmployeeHeader extends StatelessWidget {
  const _MobileEmployeeHeader();
  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    color: const Color(0xFFF6F8FC),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: const Row(children: [
      Expanded(flex: 4, child: Text('EMPLOYEE', style: TextStyle(color: Color(0xFF657087), fontSize: 10, fontWeight: FontWeight.w700))),
      Expanded(flex: 3, child: Text('DEPARTMENT', style: TextStyle(color: Color(0xFF657087), fontSize: 10, fontWeight: FontWeight.w700))),
      Expanded(flex: 2, child: Text('STATUS', style: TextStyle(color: Color(0xFF657087), fontSize: 10, fontWeight: FontWeight.w700))),
      SizedBox(width: 24),
    ]),
  );
}

class _CompactMobileEmployeeRow extends StatelessWidget {
  const _CompactMobileEmployeeRow({required this.employee, required this.onView, required this.onEdit, required this.onToggle, required this.onDelete});
  final _Employee employee;
  final VoidCallback onView, onEdit, onToggle, onDelete;

  @override
  Widget build(BuildContext context) => Container(
    height: 66,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5EAF3)))),
    child: Row(children: [
      Expanded(flex: 4, child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: const Color(0xFFEAF1FF), child: Text(employee.name.isEmpty ? '?' : employee.name[0].toUpperCase(), style: const TextStyle(color: HrmsColors.navy, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(employee.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: HrmsColors.navy, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(employee.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF657087), fontSize: 10)),
        ])),
      ])),
      Expanded(flex: 3, child: Text(employee.department, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF50649E), fontSize: 11))),
      Expanded(flex: 2, child: FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: _StatusBadge(status: employee.status))),
      PopupMenuButton<String>(
        tooltip: 'Employee actions',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert_rounded, color: HrmsColors.navy, size: 21),
        onSelected: (value) { if (value == 'view') onView(); if (value == 'edit') onEdit(); if (value == 'toggle') onToggle(); if (value == 'delete') onDelete(); },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'view', child: Text('View employee')),
          const PopupMenuItem(value: 'edit', child: Text('Edit employee')),
          PopupMenuItem(value: 'toggle', child: Text(employee.status == 'Inactive' ? 'Reactivate' : 'Deactivate')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    ]),
  );
}

class _MobileEmployeeDetail extends StatelessWidget {
  const _MobileEmployeeDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F8FE),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: HrmsColors.blue, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF657087), fontSize: 9),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HrmsColors.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 42,
    child: Row(
      children: [
        _TableCell(width: 350, child: Text('Employee', style: _tableHead)),
        _TableCell(width: 240, child: Text('Department', style: _tableHead)),
        _TableCell(width: 210, child: Text('Work Mode', style: _tableHead)),
        _TableCell(
          width: 260,
          child: Row(
            children: [
              Text('Monthly Salary', style: _tableHead),
              SizedBox(width: 10),
              Icon(
                Icons.lock_outline_rounded,
                color: HrmsColors.navy,
                size: 17,
              ),
            ],
          ),
        ),
        _TableCell(
          width: 210,
          child: Text('Employment Status', style: _tableHead),
        ),
        _TableCell(width: 210, child: Text('Actions', style: _tableHead)),
      ],
    ),
  );
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({
    required this.employee,
    required this.onView,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final _Employee employee;
  final VoidCallback onView, onEdit, onToggle, onDelete;

  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFE8EBF2))),
    ),
    child: Row(
      children: [
        _TableCell(
          width: 350,
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEAF0FA),
                child: Text(
                  employee.name.substring(0, 1),
                  style: const TextStyle(
                    color: HrmsColors.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      color: HrmsColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    employee.id,
                    style: const TextStyle(
                      color: Color(0xFF50649E),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _TableCell(
          width: 240,
          child: Text(employee.department, style: _cellStyle),
        ),
        _TableCell(
          width: 210,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(employee.modeColor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(employee.workMode, style: _cellStyle),
            ],
          ),
        ),
        _TableCell(
          width: 260,
          child: Text(
            employee.salary,
            style: TextStyle(
              color: employee.salary == 'Not Set'
                  ? const Color(0xFF8A90A3)
                  : HrmsColors.navy,
              fontSize: 16,
            ),
          ),
        ),
        _TableCell(width: 210, child: _StatusBadge(status: employee.status)),
        _TableCell(
          width: 210,
          child: Row(
            children: [
              IconButton(
                tooltip: 'View',
                onPressed: onView,
                icon: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: HrmsColors.blue,
                  size: 21,
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: HrmsColors.blue,
                  size: 20,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  if (value == 'toggle') onToggle();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      employee.status == 'Inactive'
                          ? 'Reactivate'
                          : 'Deactivate',
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: HrmsColors.navy,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.width, required this.child});
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: child,
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final active = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF6E6) : const Color(0xFFFFF0E4),
        border: Border.all(
          color: active ? const Color(0xFFD2EACB) : const Color(0xFFFFCFA9),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: active ? const Color(0xFF177020) : const Color(0xFFFF6500),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    this.text,
    this.icon,
    this.active = false,
    this.enabled = true,
    this.onTap,
  });
  final String? text;
  final IconData? icon;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 44,
        height: 40,
        decoration: BoxDecoration(
          color: active ? HrmsColors.blue : Colors.white,
          border: Border.all(
            color: active ? HrmsColors.blue : const Color(0xFFE1E6F0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(
                icon,
                color: enabled ? HrmsColors.navy : const Color(0xFFA9B0C0),
              )
            : Text(
                text!,
                style: TextStyle(
                  color: active ? Colors.white : HrmsColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ),
  );
}

class _Employee {
  const _Employee(
    this.profileId,
    this.name,
    this.id,
    this.department,
    this.workMode,
    this.salary,
    this.status,
    this.modeColor,
  );
  final int profileId;
  final String name, id, department, workMode, salary, status;
  final int modeColor;

  factory _Employee.fromApi(Map<String, dynamic> json) {
    final profileId = json['id'] is int
        ? json['id'] as int
        : int.tryParse('${json['id']}') ?? 0;
    final code = (json['employeeCode'] ?? json['employeeId'] ?? '').toString();
    final mode = (json['workMode'] ?? 'Office').toString();
    final color = json['modeColor'];
    return _Employee(
      profileId,
      (json['name'] ?? '').toString(),
      code,
      (json['department'] ?? '').toString(),
      mode,
      (json['salary'] ?? 'Not Set').toString(),
      (json['status'] ?? 'Active').toString(),
      color is int ? color : _modeColor(mode),
    );
  }
}

int _modeColor(String mode) => switch (mode) {
  'Home' => 0xFF0B8B16,
  'Field' => 0xFF16B9C5,
  _ => 0xFF0668F6,
};

const _tableHead = TextStyle(
  color: HrmsColors.navy,
  fontSize: 13,
  fontWeight: FontWeight.w600,
);
const _cellStyle = TextStyle(color: HrmsColors.navy, fontSize: 14);
