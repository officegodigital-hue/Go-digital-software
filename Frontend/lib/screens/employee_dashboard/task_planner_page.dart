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
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_layout_page.dart';

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
  final Set<int> _hoveredEmployeePickers = <int>{};
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
 // ── FETCH EMPLOYEES FROM BACKEND (Active only, exclude admin) ────────────
  Future<void> _loadEmployeesFromBackend() async {
    setState(() => _employeesLoading = true);
    try {
      final r = await http.get(Uri.parse(_employeesUrl));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final data = List<dynamic>.from(body['data'] ?? []);

        // Filter: Only active employees (is_active == 1 or true) and exclude Admin role if needed
        final loadedEmployees = data
            .where((emp) {
              final isActive = emp['is_active'] == 1 || emp['is_active'] == true;
              final role = (emp['role'] as String? ?? '').toLowerCase();
              // Exclude admin if admin shouldn't be shared to from planner
              final isAdmin = role.contains('admin'); 
              return isActive && !isAdmin;
            })
            .map((emp) {
              final role = (emp['role'] as String? ?? '').toLowerCase();
              final roleKey = _getRoleKey(role);
              final color = roleColors[roleKey] ?? const Color(0xFF6366F1);

              return EmployeeShareModel(
                id: emp['id'] as int,
                name: emp['role'] as String? ?? 'Unknown', // Role (Designer, Page Handler, etc)
                shortName: _getInitials(emp['username'] as String? ?? ''), // Auto-generated initials
                employeeName: emp['full_name'] as String? ?? 'Unknown', // Full name
                image: '', // No images from backend
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

      // Keep the planner UI useful even when an older DB row has an empty content type.
      // This is only a display/default value; it does not overwrite existing non-empty data.
      for (final row in loaded) {
        if (row.contentTypeController.text.trim().isEmpty) {
          row.contentTypeController.text = 'Content Type';
        }
      }

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
          _employeeName ?? '', 'Content Type');
     final newRow = TaskPlannerRowModel(
  id: id,
  contentType: 'Content Type',
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

  // ── PREMIUM RESPONSIVE UI ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 650;
        final isTablet = width >= 650 && width < 1050;
        final horizontal = isMobile ? 14.0 : (isTablet ? 24.0 : 38.0);

        if (_loading || _employeesLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1769FF)),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8FBFF), Color(0xFFF0F6FF)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -70,
                child: _softOrb(220, const Color(0xFFBBD7FF)),
              ),
              Positioned(
                top: 260,
                left: -100,
                child: _softOrb(180, const Color(0xFFDDEBFF)),
              ),
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  isMobile ? 16 : 24,
                  horizontal,
                  isMobile ? 28 : 36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroHeader(isMobile),
                    SizedBox(height: isMobile ? 16 : 22),
                    _plannerSurface(isMobile: isMobile, isTablet: isTablet),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _softOrb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.28),
        ),
      ),
    );
  }

  Widget _heroHeader(bool isMobile) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isMobile ? 18 : 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF073B9E),
              Color(0xFF1264E8),
              Color(0xFF2A8CFF),
            ],
          ),
          borderRadius: BorderRadius.circular(isMobile ? 22 : 26),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1769FF).withValues(alpha: 0.20),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroIcon(),
                  const SizedBox(height: 14),
                  _heroText(),
                  const SizedBox(height: 18),
                  _heroActions(true),
                ],
              )
            : Row(
                children: [
                  _heroIcon(),
                  const SizedBox(width: 16),
                  Expanded(child: _heroText()),
                  const SizedBox(width: 18),
                  _heroActions(false),
                ],
              ),
      ),
    );
  }

  Widget _heroIcon() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: const Icon(Icons.view_quilt_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _heroText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TASK PLANNER',
          style: TextStyle(
            color: Color(0xFFBFD9FF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Plan. Create. Share.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Organize your content, manage sections and assign work to your team.',
          style: TextStyle(
            color: Color(0xFFDCEAFF),
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _heroActions(bool mobile) {
    final buttons = [
      OutlinedButton.icon(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('employeeMenu', 'Task Planner History');
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EmployeeLayoutPage()),
          );
        },
        icon: const Icon(Icons.history_rounded, size: 17),
        label: const Text('View History'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      ElevatedButton.icon(
        onPressed: addSection,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add Section'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0751C9),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
    ];

    return mobile
        ? Wrap(spacing: 9, runSpacing: 9, children: buttons)
        : Row(mainAxisSize: MainAxisSize.min, children: [
            buttons[0],
            const SizedBox(width: 9),
            buttons[1],
          ]);
  }

  Widget _plannerSurface({required bool isMobile, required bool isTablet}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1.0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, alignment: Alignment.topCenter, child: child),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          border: Border.all(color: const Color(0xFFD7E6FF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D4EAF).withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 10 : 14),
          child: Column(
            children: [
              _plannerToolbar(isMobile),
              const SizedBox(height: 10),
              if (isMobile)
                ...rows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _mobilePlannerCard(row),
                    ))
              else
                _desktopPlannerTable(isTablet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plannerToolbar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEAFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE1EEFF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.layers_rounded, color: Color(0xFF1769FF), size: 20),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planner Sections',
                  style: TextStyle(
                    color: Color(0xFF102A56),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your content workspace',
                  style: TextStyle(color: Color(0xFF7185A3), fontSize: 10.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD5E5FF)),
            ),
            child: Text(
              '${rows.length} ${rows.length == 1 ? 'section' : 'sections'}',
              style: const TextStyle(
                color: Color(0xFF1769FF),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopPlannerTable(bool isTablet) {
    return Column(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEAF3FF), Color(0xFFF6FAFF)],
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              SizedBox(
                width: isTablet ? 190 : 245,
                child: _headerCell(Icons.category_rounded, 'Content Type'),
              ),
              Expanded(child: _headerCell(Icons.notes_rounded, 'Contents')),
              SizedBox(
                width: isTablet ? 205 : 245,
                child: _headerCell(Icons.send_rounded, 'Action'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _desktopPlannerRow(row, isTablet),
            )),
      ],
    );
  }

  Widget _headerCell(IconData icon, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1769FF)),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF19355F),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _desktopPlannerRow(TaskPlannerRowModel row, bool isTablet) {
    return Container(
      constraints: const BoxConstraints(minHeight: 154),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0EBFA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D4EAF).withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 190 : 245,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF6FAFF),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            child: _plannerTextField(
              controller: row.contentTypeController,
              hint: 'Enter content type',
              icon: Icons.label_outline_rounded,
              maxLines: 3,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _plannerTextField(
                controller: row.contentController,
                hint: 'Paste or type your content here...',
                icon: Icons.edit_note_rounded,
                maxLines: 5,
              ),
            ),
          ),
          Container(
            width: isTablet ? 205 : 245,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFE4ECF8))),
            ),
            child: Center(
              child: row.isShared
                  ? _assignedStatusWidget(row)
                  : _shareActionWidget(row),
            ),
          ),
        ],
      ),
    );
  }

  Widget _plannerTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required int maxLines,
  }) {
    final isContentType = hint.toLowerCase().contains('content type');

    return TextField(
      controller: controller,
      minLines: isContentType ? 1 : 4,
      maxLines: maxLines,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: isContentType
          ? TextInputType.text
          : TextInputType.multiline,
      style: const TextStyle(
        color: Color(0xFF182B49),
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      decoration: InputDecoration(
        labelText: isContentType ? 'Content Type' : 'Contents',
        hintText: isContentType
            ? 'Content Type'
            : 'Paste or type your content here...',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          color: Color(0xFF1769FF),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFA2B1C5),
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 10, right: 7),
          child: Icon(icon, size: 18, color: const Color(0xFF78A7E8)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        filled: true,
        fillColor: const Color(0xFFFCFDFF),
        contentPadding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE9F8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE9F8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4B91FF), width: 1.5),
        ),
      ),
    );
  }

  Widget _mobilePlannerCard(TaskPlannerRowModel row) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFDCE9FA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1769FF).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.layers_rounded,
                    size: 17, color: Color(0xFF1769FF)),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Content Section',
                  style: TextStyle(
                    color: Color(0xFF17325C),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _plannerTextField(
            controller: row.contentTypeController,
            hint: 'Enter content type',
            icon: Icons.label_outline_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          _plannerTextField(
            controller: row.contentController,
            hint: 'Paste or type your content here...',
            icon: Icons.edit_note_rounded,
            maxLines: 5,
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAFF),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE0EBFA)),
            ),
            child: row.isShared
                ? _assignedStatusWidget(row)
                : _shareActionWidget(row),
          ),
        ],
      ),
    );
  }

  // ── SHARE ACTION WIDGET ─────────────────────────────────────────────────
  Widget _shareActionWidget(TaskPlannerRowModel row) {
    final isHovered = _hoveredEmployeePickers.contains(row.id);

    void scrollEmployees(double offset) {
      if (!_employeeScrollController.hasClients) return;
      final target = (_employeeScrollController.offset + offset).clamp(
        0.0,
        _employeeScrollController.position.maxScrollExtent,
      );
      _employeeScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => row.showAvatars = !row.showAvatars),
              icon: Icon(
                row.showAvatars
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.send_rounded,
                size: 17,
              ),
              label: Text(row.showAvatars ? 'Hide Team' : 'Share Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769FF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (row.showAvatars) ...[
            const SizedBox(height: 10),
            MouseRegion(
              onEnter: (_) => setState(() => _hoveredEmployeePickers.add(row.id)),
              onExit: (_) => setState(() => _hoveredEmployeePickers.remove(row.id)),
              child: Container(
                height: 88,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFDDE9F8)),
                ),
                child: Row(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: isHovered ? 1 : 0.55,
                      child: _employeeScrollArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => scrollEmployees(-145),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: employees.isEmpty
                          ? const Center(
                              child: Text(
                                'No employees available',
                                style: TextStyle(
                                  color: Color(0xFF7A8CA5),
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: _employeeScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: employees.length,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final employee = employees[index];
                                return _employeeAvatarButton(
                                  employee: employee,
                                  onTap: () => shareToEmployee(row, employee),
                                );
                              },
                            ),
                    ),
                    const SizedBox(width: 3),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: isHovered ? 1 : 0.55,
                      child: _employeeScrollArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => scrollEmployees(145),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _employeeScrollArrow({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFEAF3FF),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, color: const Color(0xFF1769FF), size: 22),
        ),
      ),
    );
  }

  // ── EMPLOYEE AVATAR BUTTON ───────────────────────────────────────────────
  Widget _employeeAvatarButton({
    required EmployeeShareModel employee,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: '${employee.employeeName} - ${employee.name}',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    employee.color.withValues(alpha: 0.75),
                    employee.color,
                  ],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: employee.color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  employee.shortName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 58,
              child: Text(
                employee.employeeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF405574),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ASSIGNED STATUS WIDGET ──────────────────────────────────────────────
  Widget _assignedStatusWidget(TaskPlannerRowModel row) {
    final employee = row.sharedEmployee;
    final employeeColor = employee?.color ?? const Color(0xFF1769FF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFCFE2FF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: employeeColor,
              boxShadow: [
                BoxShadow(
                  color: employeeColor.withValues(alpha: 0.22),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                employee?.shortName ?? 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assigned',
                  style: TextStyle(
                    color: Color(0xFF1769FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  employee?.employeeName ?? 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17325C),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  employee?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7A8CA5),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
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