import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/services/auth_service.dart';
import '../../services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_layout_page.dart';

final ScrollController _vidEmpScrollController = ScrollController();

class VideographerTaskPlannerPage extends StatefulWidget {
  const VideographerTaskPlannerPage({super.key});

  @override
  State<VideographerTaskPlannerPage> createState() => _VideographerTaskPlannerPageState();
} 

class _VideographerTaskPlannerPageState extends State<VideographerTaskPlannerPage> {
  static String get _baseUrl => '${ApiConfig.baseUrl}/videographer-planner';
  static String get _employeesUrl => '${ApiConfig.baseUrl}/employees';

  List<_EmpModel> employees = [];
  List<_RowModel> rows = [];
  bool _loading = true;
  bool _employeesLoading = true;
  String? _employeeName;
  int? _employeeId;

  static const Map<String, Color> roleColors = {
    'designer': Color(0xFF6366F1),
    'page_handler': Color(0xFF8B5CF6),
    'ads_handler': Color(0xFFEC4899),
    'videographer': Color(0xFFF59E0B),
    'admin': Color(0xFF0052CC),  // Modern Royal Blue for admin
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      _employeeName = auth.user?['fullName'] ?? '';
      _employeeId = auth.user?['id'] as int?;
      
      _loadEmployees().then((_) => _loadRows());
    });
  }

  Future<void> _loadEmployees() async {
    setState(() => _employeesLoading = true);
    try {
      final r = await http.get(Uri.parse(_employeesUrl));
      if (r.statusCode == 200) {
        final data = List<dynamic>.from(jsonDecode(r.body)['data'] ?? []);
        
        final filteredData = data.where((emp) {
          final userType = (emp['user_type'] as String? ?? '').toLowerCase();
          final role = (emp['role'] as String? ?? '').toLowerCase();
          return userType == 'admin' || role == 'admin';
        }).toList();

        final loadedEmployees = filteredData.map((emp) {
          final role = (emp['role'] as String? ?? '').toLowerCase();
          final userType = (emp['user_type'] as String? ?? '').toLowerCase();
          final roleKey = _getRoleKey(role);
          final color = roleColors[roleKey] ?? const Color(0xFF0052CC);
          
          return _EmpModel(
            id: emp['id'] as int,
            name: emp['role'] as String? ?? 'Admin',
            short: _getInitials(emp['username'] as String? ?? ''),
            fullName: emp['full_name'] as String? ?? 'Unknown',
            color: color,
            role: role,
            userType: userType,
          );
        }).toList();

        setState(() {
          employees = loadedEmployees;
          _employeesLoading = false;
        });
      } else {
        setState(() => _employeesLoading = false);
        _snack('Failed to load employees', success: false);
      }
    } catch (e) {
      setState(() => _employeesLoading = false);
      _snack('Error loading employees: ${e.toString()}', success: false);
    }
  }

  String _getRoleKey(String role) {
    if (role.contains('designer')) return 'designer';
    if (role.contains('page') && role.contains('handler')) return 'page_handler';
    if (role.contains('ads') && role.contains('handler')) return 'ads_handler';
    if (role.contains('videographer')) return 'videographer';
    if (role.contains('admin')) return 'admin';
    return 'admin';
  }

  String _getInitials(String input) {
    if (input.isEmpty) return '?';
    final parts = input.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return input.substring(0, 1).toUpperCase();
  }

  Future<void> _loadRows() async {
    if (_employeeName == null || _employeeName!.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl?employee=$_employeeName'));
      if (r.statusCode == 200) {
        final data = List<dynamic>.from(jsonDecode(r.body)['data'] ?? []);
        final loaded = data.map((d) => _RowModel.fromJson(d)).toList();
        if (loaded.isEmpty) {
          for (int i = 0; i < 3; i++) {
            final id = await _createRow();
            if (id != null) loaded.add(_RowModel(id: id));
          }
        }
        setState(() {
          rows = loaded;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _snack('Failed to load tasks.', success: false);
      }
    } catch (e) {
      setState(() => _loading = false);
      _snack('Connection error.', success: false);
    }
  }

  Future<int?> _createRow() async {
    try {
      final r = await http.post(Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'employeeName': _employeeName, 'clientName': '', 'schedulingDetails': ''}),
      );
      if (r.statusCode == 201) return jsonDecode(r.body)['data']['id'] as int;
    } catch (_) {}
    return null;
  }

  Future<void> _addSection() async {
    final id = await _createRow();
    if (id != null) {
      setState(() => rows.add(_RowModel(id: id)));
    } else {
      _snack('Could not add section.', success: false);
    }
  }

  Future<void> _deleteRow(_RowModel row) async {
    try {
      final r = await http.delete(Uri.parse('$_baseUrl/${row.id}'));
      if (r.statusCode == 200) {
        setState(() => rows.remove(row));
        row.dispose();
        _snack('Task section deleted successfully', success: true);
      } else {
        _snack('Failed to delete section', success: false);
      }
    } catch (e) {
      _snack('Delete error: $e', success: false);
    }
  }

  Future<void> _share(_RowModel row, _EmpModel emp) async {
    if (row.clientCtrl.text.trim().isEmpty) {
      _snack('Please enter client name.', success: false);
      return;
    }
    if (row.schedCtrl.text.trim().isEmpty) {
      _snack('Please enter scheduling details.', success: false);
      return;
    }
    try {
      final r = await http.patch(
        Uri.parse('$_baseUrl/${row.id}/share'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderEmployeeName': _employeeName,
          'senderEmployeeId': _employeeId,
          'clientName': row.clientCtrl.text,
          'schedulingDetails': row.schedCtrl.text,
          'receiverEmployeeName': emp.fullName,
          'receiverEmployeeId': emp.id,
          'receiverRole': emp.name,
          'receiverShort': emp.short,
        }),
      );
      if (r.statusCode == 200) {
        setState(() {
          row.clientCtrl.clear();
          row.schedCtrl.clear();
          row.showAvatars = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Assigned to ${emp.fullName}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        _snack('Share failed. Try again.', success: false);
      }
    } catch (e) {
      _snack('Share failed. Try again.', success: false);
    }
  }

  Future<void> _openHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employeeMenu', 'Video Task Planner History');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EmployeeLayoutPage()),
    );
  }

  void _snack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.green : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _vidEmpScrollController.dispose();
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  // ===== FUTURISTIC 2050 UI SYSTEM =====
  static const Color _brand = Color(0xFF0052CC);
  static const Color _brandDeep = Color(0xFF003B95);
  static const Color _cyan = Color(0xFF00B8D9);
  static const Color _ink = Color(0xFF0A1020);
  static const Color _muted = Color(0xFF64748B);
  static const Color _surface = Color(0xFFF6F8FC);

  @override
  Widget build(BuildContext context) {
    if (_loading || _employeesLoading) {
      return const Center(child: CircularProgressIndicator(color: _brand));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        return Container(
          color: _surface,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 28,
              isMobile ? 18 : 30,
              isMobile ? 14 : 28,
              40,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroHeader(isMobile),
                  const SizedBox(height: 22),
                  _commandBar(isMobile),
                  const SizedBox(height: 18),
                  _workspace(isMobile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heroHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [_ink, _brandDeep, _brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: .22),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -55,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .055),
              ),
            ),
          ),
          Positioned(
            right: 110,
            bottom: -75,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cyan.withValues(alpha: .11),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 54 : 66,
                height: isMobile ? 54 : 66,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: .16)),
                ),
                child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video Command Center',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 23 : 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Plan production. Assign instantly. Keep every shoot moving.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: isMobile ? 12 : 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) _liveStatus(),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 18),
            _liveStatus(),
          ],
        ],
      ),
    );
  }

  Widget _liveStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFF48E5C2), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '${rows.length} ACTIVE SECTIONS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commandBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7ECF5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .025), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Wrap(
        alignment: isMobile ? WrapAlignment.start : WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: _brand, size: 20),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Production workspace', style: TextStyle(fontWeight: FontWeight.w800, color: _ink, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Create and route task sections in real time', style: TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _openHistory,
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: BorderSide(color: _brand.withValues(alpha: .28)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('New Section'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workspace(bool isMobile) {
    return isMobile ? _mobileListView() : _desktopTableView();
  }

  Widget _desktopTableView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7ECF5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .025), blurRadius: 26, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 58),
                Expanded(flex: 3, child: _DeskHeader(icon: Icons.business_rounded, label: 'CLIENT / PROJECT')),
                SizedBox(width: 24),
                Expanded(flex: 5, child: _DeskHeader(icon: Icons.calendar_month_rounded, label: 'SCHEDULING INTELLIGENCE')),
                SizedBox(width: 24),
                SizedBox(width: 250, child: _DeskHeader(icon: Icons.send_rounded, label: 'ASSIGNMENT')),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE7ECF5)),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(50),
              child: Text('No production sections yet'),
            ),
          ...List.generate(rows.length, (index) => _buildDesktopRow(rows[index], index)),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(_RowModel row, int index) {
    final isLast = index == rows.length - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFEFF2F7))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _indexBadge(index),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: _fieldShell(
              icon: Icons.business_rounded,
              label: 'CLIENT NAME',
              child: TextField(
                controller: row.clientCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Who is this project for?',
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: _fieldShell(
              icon: Icons.movie_filter_rounded,
              label: 'PRODUCTION NOTES',
              child: TextField(
                controller: row.schedCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Shoot date, time, location, deliverables and priority...',
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(width: 250, child: _shareWidget(row)),
        ],
      ),
    );
  }

  Widget _indexBadge(int index) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '${index + 1}'.padLeft(2, '0'),
        style: const TextStyle(color: _brand, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _fieldShell({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: _brand),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _muted, letterSpacing: .7)),
            ],
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }

  Widget _mobileListView() {
    return Column(
      children: List.generate(rows.length, (index) {
        final row = rows[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7ECF5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .02), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _indexBadge(index),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Production Section ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _ink)),
                  ),
                  IconButton(
                    tooltip: 'Delete section',
                    onPressed: () => _deleteRow(row),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _fieldShell(
                icon: Icons.business_rounded,
                label: 'CLIENT NAME',
                child: TextField(
                  controller: row.clientCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Enter client or project name',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
              const SizedBox(height: 12),
              _fieldShell(
                icon: Icons.movie_filter_rounded,
                label: 'SCHEDULING & PRODUCTION NOTES',
                child: TextField(
                  controller: row.schedCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Date, time, location, deliverables...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(color: Color(0xFF334155), height: 1.45),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFEFF2F7)),
              const SizedBox(height: 12),
              Center(child: _shareWidget(row)),
            ],
          ),
        );
      }),
    );
  }

  Widget _shareWidget(_RowModel row) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() => row.showAvatars = !row.showAvatars),
          icon: Icon(row.showAvatars ? Icons.close_rounded : Icons.send_rounded, size: 17),
          label: Text(row.showAvatars ? 'Close' : 'Assign to Admin'),
          style: ElevatedButton.styleFrom(
            backgroundColor: row.showAvatars ? const Color(0xFFE9EEF8) : _brand,
            foregroundColor: row.showAvatars ? _ink : Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: row.showAvatars
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _adminRail(row),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _adminRail(_RowModel row) {
    if (employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('No admins available', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
      );
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF5)),
      ),
      child: SizedBox(
        height: 82,
        child: Scrollbar(
          controller: _vidEmpScrollController,
          thumbVisibility: true,
          child: ListView.builder(
            controller: _vidEmpScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: employees.length,
            itemBuilder: (_, i) => SizedBox(
              width: 72,
              child: _avatarTile(employees[i], () => _share(row, employees[i])),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarTile(_EmpModel emp, VoidCallback onTap) {
    return Tooltip(
      message: '${emp.fullName} • ${emp.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: emp.color,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: emp.color.withValues(alpha: .25), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(emp.short, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 66,
                child: Text(
                  emp.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeskHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DeskHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Color(0xFF64748B)),
        SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .75, color: Color(0xFF64748B))),
      ],
    );
  }
}

class _RowModel {
  final int id;
  final TextEditingController clientCtrl;
  final TextEditingController schedCtrl;
  bool showAvatars;

  _RowModel({required this.id, String clientName = '', String schedulingDetails = ''})
      : showAvatars = false,
        clientCtrl = TextEditingController(text: clientName),
        schedCtrl = TextEditingController(text: schedulingDetails);

  factory _RowModel.fromJson(Map<String, dynamic> json) => _RowModel(
        id: json['id'] as int,
        clientName: (json['client_name'] as String? ?? ''),
        schedulingDetails: (json['scheduling_details'] as String? ?? ''),
      );

  void dispose() {
    clientCtrl.dispose();
    schedCtrl.dispose();
  }
}

class _EmpModel {
  final int id;
  final String name;
  final String short;
  final String fullName;
  final Color color;
  final String role;
  final String userType;

  const _EmpModel({
    required this.id,
    required this.name,
    required this.short,
    required this.fullName,
    required this.color,
    required this.role,
    required this.userType,
  });
}