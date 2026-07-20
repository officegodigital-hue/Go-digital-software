import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/constants/app_text_styles.dart';
import 'package:godigital_portal/services/task_planner_service.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import '../../services/api_config.dart';
import 'dart:async';

final ScrollController _employeeScrollController = ScrollController();

class TaskPlannerPage extends StatefulWidget {
  const TaskPlannerPage({super.key});

  @override
  State<TaskPlannerPage> createState() => _TaskPlannerPageState();
}

class _TaskPlannerPageState extends State<TaskPlannerPage> {
  // static const String _employeesUrl = '/api/employees';
  static String get _employeesUrl => '${ApiConfig.baseUrl}/employees';

  // Color mapping for roles
  static const Map<String, Color> roleColors = {
    'designer': Color(0xFF6366F1),
    'page_handler': Color(0xFF8B5CF6),
    'ads_handler': Color(0xFFEC4899),
    'videographer': Color(0xFFF59E0B),
  };

  // ── Dynamically loaded from backend ──────────────────────────────────────
  List<EmployeeShareModel> employees = [];

  List<TaskPlannerRowModel> rows = [];
  bool _loading = true;
  bool _employeesLoading = true;
  String? _employeeName;
  int? _employeeId; // ← sender's DB id from auth service

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      _employeeName = authService.user?['fullName'] ?? '';
      _employeeId = authService.user?['id'] as int?;

      // Load employees from backend FIRST, then load rows
      _loadEmployeesFromBackend().then((_) => _loadRowsFromBackend());
    });
  }

  // ── FETCH EMPLOYEES FROM BACKEND ────────────────────────────────────────
  Future<void> _loadEmployeesFromBackend() async {
    setState(() => _employeesLoading = true);
    try {
      final r = await http.get(Uri.parse(_employeesUrl));
      if (r.statusCode == 200) {
        final data = List<dynamic>.from(jsonDecode(r.body)['data'] ?? []);

        // Convert backend employee data to EmployeeShareModel
        final loadedEmployees = data.map((emp) {
          final role = (emp['role'] as String? ?? '').toLowerCase();
          final roleKey = _getRoleKey(role);
          final color = roleColors[roleKey] ?? const Color(0xFF6366F1);

          return EmployeeShareModel(
            id: emp['id'] as int,
            name: emp['role'] as String? ?? 'Unknown', // Role (Designer, Page Handler, etc)
            shortName: _getInitials(emp['username'] as String? ?? ''), // Auto-generated initials
            employeeName: emp['full_name'] as String? ?? 'Unknown', // Full name
            image: '', // No images from backend (fallback to color + initials)
            color: color,
            role: role, // Store role for reference
          );
        }).toList();

        setState(() {
          employees = loadedEmployees;
          _employeesLoading = false;
        });
      } else {
        setState(() => _employeesLoading = false);
        _showErrorSnack('Failed to load employees');
      }
    } catch (e) {
      setState(() => _employeesLoading = false);
      _showErrorSnack('Error loading employees: ${e.toString()}');
      print('Load employees error: $e');
    }
  }

  // ── HELPER: Get role key for color mapping ──────────────────────────────
  String _getRoleKey(String role) {
    if (role.contains('designer')) return 'designer';
    if (role.contains('page') && role.contains('handler')) return 'page_handler';
    if (role.contains('ads') && role.contains('handler')) return 'ads_handler';
    if (role.contains('videographer')) return 'videographer';
    return 'designer'; // default
  }

  // ── HELPER: Generate initials from username or name ─────────────────────
  String _getInitials(String input) {
    if (input.isEmpty) return '?';
    final parts = input.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return input.substring(0, 1).toUpperCase();
  }

  // ── LOAD ROWS (Task Planner data) ──────────────────────────────────────
  Future<void> _loadRowsFromBackend() async {
    if (_employeeName == null || _employeeName!.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await TaskPlannerService.getPlannerRows(_employeeName!);
      final loaded = data.map((d) => TaskPlannerRowModel.fromJson(d)).toList();

      // Seed 5 default sections if DB is empty
      if (loaded.isEmpty) {
        for (final ct in [
          'Landing Page Content',
          'Blogs Content',
          'Poster Content',
          'Reels Content',
          'E-Book Content'
        ]) {
          try {
            final id = await TaskPlannerService.createPlannerRow(_employeeName!, ct);
            loaded.add(TaskPlannerRowModel(id: id, contentType: ct));
          } catch (_) {}
        }
      }
      setState(() {
  rows = loaded;
  _loading = false;
});

_attachListeners();
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnack('Failed to load tasks. Check your connection.');
      print('Load rows error: $e');
    }
  }

void _attachListeners() {

  for (final row in rows) {

    if (row.saveListener != null) continue;

    row.saveListener = () {

      row.saveTimer?.cancel();

      row.saveTimer = Timer(
        const Duration(milliseconds: 700),
        () {
          _autoSaveRow(row);
        },
      );

    };

    row.contentTypeController.addListener(row.saveListener!);

    row.contentController.addListener(row.saveListener!);

  }

}

Future<void> _autoSaveRow(TaskPlannerRowModel row) async {

  try {

    await TaskPlannerService.updatePlannerRow(
  id: row.id,
  contentType: row.contentTypeController.text,
  content: row.contentController.text,
);

  } catch (_) {}

}

  Future<void> addSection() async {
    try {
      final id = await TaskPlannerService.createPlannerRow(
          _employeeName ?? '', 'New Content Type');
     final newRow = TaskPlannerRowModel(
  id: id,
  contentType: 'New Content Type',
);

setState(() {
  rows.add(newRow);
});

_attachListeners();
    } catch (e) {
      _showErrorSnack('Could not add section. Try again.');
    }
  }

  // ── SHARE — INSERT new record, never update ────────────────────────────
  Future<void> shareToEmployee(
      TaskPlannerRowModel row, EmployeeShareModel employee) async {
    if (row.contentTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter content type.'),
          backgroundColor: Colors.red));
      return;
    }
    if (row.contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please type content before sharing.'),
          backgroundColor: Colors.red));
      return;
    }

    try {
      // ── Every call = 1 new INSERT into task_planner_shares ──────────────
      await TaskPlannerService.sharePlannerRow(
        id: row.id,

        // Sender = logged-in employee
        senderEmployeeName: _employeeName ?? '',
        senderEmployeeId: _employeeId,

        // Content being shared
        contentType: row.contentTypeController.text,
        content: row.contentController.text,

        // Receiver = selected employee from the avatar picker
        receiverEmployeeName: employee.employeeName,
        receiverEmployeeId: employee.id, // ← DB id from EmployeeShareModel
        receiverRole: employee.name,
        receiverShort: employee.shortName,
      );

      // ── Reset row to fresh state — Share button reappears ──────────────
      setState(() {
       row.saveTimer?.cancel();

row.contentController.removeListener(row.saveListener!);

row.contentController.clear();

row.contentController.addListener(row.saveListener!);
        row.isShared = false;
        row.showAvatars = false;
        row.sharedEmployee = null;
        row.sharedTo = null;
        row.sharedTime = null;
        row.sharedToRole = null;
        row.sharedToName = null;
        row.sharedToShort = null;
      });

      // ── Success snackbar ────────────────────────────────────────────────
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Assigned to ${employee.employeeName}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: AppColors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      _showErrorSnack('Share failed. Try again.');
      print('Share error: $e');
    }
  }

  Future<void> _resetRow(TaskPlannerRowModel row) async {
    try {
      await TaskPlannerService.resetPlannerRow(row.id);
      setState(() {
        row.contentController.clear();
        row.isShared = false;
        row.showAvatars = false;
        row.sharedEmployee = null;
        row.sharedTo = null;
        row.sharedToRole = null;
        row.sharedToName = null;
        row.sharedToShort = null;
      });
    } catch (e) {
      _showErrorSnack('Reset failed. Try again.');
    }
  }

  Future<void> _deleteRow(TaskPlannerRowModel row) async {
    try {
      await TaskPlannerService.deletePlannerRow(row.id);
      setState(() => rows.remove(row));
      row.dispose();
    } catch (e) {
      _showErrorSnack('Delete failed. Try again.');
    }
  }

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    for (final row in rows) {

  row.contentTypeController.removeListener(
      row.saveListener ?? () {});

  row.contentController.removeListener(
      row.saveListener ?? () {});

  row.saveTimer?.cancel();

  row.dispose();

}
    _employeeScrollController.dispose();
    super.dispose();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading || _employeesLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF004AAD)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader(),
          const SizedBox(height: 28),
          _plannerTable(),
        ],
      ),
    );
  }

  // ── PAGE HEADER ────────────────────────────────────────────────────────
  Widget _pageHeader() {
    return Row(children: [
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tasks Planner', style: AppTextStyles.heading),
          SizedBox(height: 6),
          Text(
              'Organize, assign, and track tasks efficiently to ensure timely completion and improved team productivity.',
              style: AppTextStyles.subHeading),
        ],
      ),
      const Spacer(),
      ElevatedButton(
        onPressed: addSection,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF004AAD),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        child: const Text('+ Add Sections',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    ]);
  }

  // ── PLANNER TABLE ──────────────────────────────────────────────────────
  Widget _plannerTable() {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.card, border: Border.all(color: AppColors.border)),
      child: Column(
        children: [_tableHeader(), ...rows.map((row) => _plannerRow(row))],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      height: 50,
      color: AppColors.lightBlue,
      child: const Row(children: [
        SizedBox(
          width: 250,
          child: Center(
            child: Text('Content Type',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
          ),
        ),
        Expanded(
          child: Center(
            child: Text('Contents',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
          ),
        ),
        SizedBox(
          width: 250,
          child: Center(
            child: Text('Action',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
          ),
        ),
      ]),
    );
  }

  Widget _plannerRow(TaskPlannerRowModel row) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Container(
          width: 250,
          color: AppColors.lightBlue,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: TextField(
            controller: row.contentTypeController,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'Enter Content Type',
              border: InputBorder.none,
              hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textDark),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            alignment: Alignment.center,
            child: TextField(
              controller: row.contentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Paste Your content here',
                hintStyle: TextStyle(color: Color(0xFFE1E5EA), fontSize: 16),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        Container(
          width: 250,
          decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.border))),
          child: Center(
            child: row.isShared
                ? _assignedStatusWidget(row)
                : _shareActionWidget(row),
          ),
        ),
      ]),
    );
  }

  // ── SHARE ACTION WIDGET (Show Share button + employee avatars) ────────
  Widget _shareActionWidget(TaskPlannerRowModel row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => row.showAvatars = !row.showAvatars),
            child: Container(
              height: 34,
              width: 85,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0057E7),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Text(row.showAvatars ? 'Hide' : 'Share',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          if (row.showAvatars) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 90,
              child: Scrollbar(
                controller: _employeeScrollController,
                thumbVisibility: true,
                child: employees.isEmpty
                    ? const Center(
                        child: Text('No employees',
                            style: TextStyle(fontSize: 12)))
                    : ListView.builder(
                        controller: _employeeScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: employees.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (context, index) => SizedBox(
                          width: 60,
                          child: _employeeAvatarButton(
                            employee: employees[index],
                            onTap: () =>
                                shareToEmployee(row, employees[index]),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── EMPLOYEE AVATAR BUTTON ─────────────────────────────────────────────
  Widget _employeeAvatarButton({
    required EmployeeShareModel employee,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: '${employee.employeeName} - ${employee.name}',
      showDuration: const Duration(seconds: 2),
      textStyle: const TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      decoration:
          BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: employee.color.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: ClipOval(
                  child: Container(
                    decoration: BoxDecoration(
                      color: employee.color,
                      image: employee.image.isNotEmpty
                          ? DecorationImage(
                              image: AssetImage(employee.image),
                              fit: BoxFit.cover,
                              onError: (e, s) {},
                            )
                          : null,
                    ),
                    child: (employee.image.isEmpty || employee.image == '')
                        ? Center(
                            child: Text(employee.shortName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 55,
                child: Text(employee.employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ASSIGNED STATUS WIDGET (Show who it was shared to) ────────────────
  Widget _assignedStatusWidget(TaskPlannerRowModel row) {
    final employee = row.sharedEmployee;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: employee?.color ?? AppColors.primary, width: 3),
              boxShadow: [
                BoxShadow(
                    color: (employee?.color ?? AppColors.primary)
                        .withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: ClipOval(
              child: Container(
                decoration: BoxDecoration(
                  color: employee?.color ?? AppColors.primary,
                  image: (employee?.image.isNotEmpty ?? false)
                      ? DecorationImage(
                          image: AssetImage(employee?.image ?? ''),
                          fit: BoxFit.cover,
                          onError: (e, s) {},
                        )
                      : null,
                ),
                child: ((employee?.image.isEmpty ?? true) || employee?.image == '')
                    ? Center(
                        child: Text(employee?.shortName ?? 'A',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(employee?.employeeName ?? 'Unknown',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
              textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text(employee?.name ?? '',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TaskPlannerRowModel
// ════════════════════════════════════════════════════════════════════════════
class TaskPlannerRowModel {
  VoidCallback? saveListener;
Timer? saveTimer;
  final int id;
  final TextEditingController contentTypeController;
  final TextEditingController contentController;
  bool isShared;
  bool showAvatars;
  String? sharedTo;
  EmployeeShareModel? sharedEmployee;
  DateTime? sharedTime;
  String? sharedToRole;
  String? sharedToName;
  String? sharedToShort;
  DateTime? sharedAt;
  bool isRunning = false;

  bool isHold = false;
 Duration elapsed = Duration.zero;

  TaskPlannerRowModel({
    required this.id,
    required String contentType,
    String content = '',
    this.isShared = false,
    this.showAvatars = false,
    this.sharedTo,
    this.sharedEmployee,
    this.sharedTime,
    this.sharedToRole,
    this.sharedToName,
    this.sharedToShort,
    this.sharedAt,
  })  : contentTypeController = TextEditingController(text: contentType),
        contentController = TextEditingController(text: content);

  factory TaskPlannerRowModel.fromJson(Map<String, dynamic> json) {
    // task_planner table no longer has share columns — rows always load as fresh
    return TaskPlannerRowModel(
      id: json['id'] as int,
      contentType: (json['content_type'] as String? ?? ''),
      content: (json['content'] as String? ?? ''),
      isShared: false, // always false — share state is in task_planner_shares
      sharedEmployee:
          null, // always null on load — row always shows Share button
    );
  }

  void dispose() {
    contentTypeController.dispose();
    contentController.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EmployeeShareModel — now fetched from backend, includes id for DB reference
// ════════════════════════════════════════════════════════════════════════════
class EmployeeShareModel {
  final int id; // ← DB id from employee_users table
  final String name; // ← Role name (Designer, Page Handler, etc)
  final String shortName; // ← Auto-generated initials
  final String employeeName; // ← Full name from backend
  final String image; // ← Image path (empty for backend data)
  final Color color; // ← Color based on role
  final String role; // ← Role for reference

  EmployeeShareModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.employeeName,
    required this.image,
    required this.color,
    required this.role,
  });
}