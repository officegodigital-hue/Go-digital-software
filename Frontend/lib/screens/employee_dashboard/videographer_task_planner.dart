import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:godigital_portal/core/constants/app_colors.dart';
import 'package:godigital_portal/core/constants/app_text_styles.dart';
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
  // static const String _baseUrl = '/api/videographer-planner';
  // static const String _employeesUrl = '/api/employees';
  static String get _baseUrl => '${ApiConfig.baseUrl}/videographer-planner';
  static String get _employeesUrl => '${ApiConfig.baseUrl}/employees';

  List<_EmpModel> employees = [];
  List<_RowModel> rows = [];
  bool _loading = true;
  bool _employeesLoading = true;
  String? _employeeName;
  int? _employeeId;

  // Color mapping for roles
  static const Map<String, Color> roleColors = {
    'designer': Color(0xFF6366F1),
    'page_handler': Color(0xFF8B5CF6),
    'ads_handler': Color(0xFFEC4899),
    'videographer': Color(0xFFF59E0B),
    'admin': Color(0xFF10B981),  // Green for admin
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      _employeeName = auth.user?['fullName'] ?? '';
      _employeeId = auth.user?['id'] as int?;
      
      // Load employees from backend, then load rows
      _loadEmployees().then((_) => _loadRows());
    });
  }

  // ── FETCH EMPLOYEES FROM BACKEND (FILTERED BY ADMIN ROLE) ────────────────
  Future<void> _loadEmployees() async {
    setState(() => _employeesLoading = true);
    try {
      final r = await http.get(Uri.parse(_employeesUrl));
      if (r.statusCode == 200) {
        final data = List<dynamic>.from(jsonDecode(r.body)['data'] ?? []);
        
        // FILTER: Only show employees with user_type = 'admin' OR role = 'admin'
        final filteredData = data.where((emp) {
          final userType = (emp['user_type'] as String? ?? '').toLowerCase();
          final role = (emp['role'] as String? ?? '').toLowerCase();
          
          // Include only admin users
          return userType == 'admin' || role == 'admin';
        }).toList();

        // Convert filtered backend employee data to _EmpModel
        final loadedEmployees = filteredData.map((emp) {
          final role = (emp['role'] as String? ?? '').toLowerCase();
          final userType = (emp['user_type'] as String? ?? '').toLowerCase();
          final roleKey = _getRoleKey(role);
          final color = roleColors[roleKey] ?? const Color(0xFF10B981);  // Default to admin green
          
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

        if (loadedEmployees.isEmpty) {
          _snack('No admin employees available', success: false);
        }
      } else {
        setState(() => _employeesLoading = false);
        _snack('Failed to load employees', success: false);
      }
    } catch (e) {
      setState(() => _employeesLoading = false);
      _snack('Error loading employees: ${e.toString()}', success: false);
      print('Load employees error: $e');
    }
  }

  // ── HELPER: Get role key for color mapping ────────────────────────────────
  String _getRoleKey(String role) {
    if (role.contains('designer')) return 'designer';
    if (role.contains('page') && role.contains('handler')) return 'page_handler';
    if (role.contains('ads') && role.contains('handler')) return 'ads_handler';
    if (role.contains('videographer')) return 'videographer';
    if (role.contains('admin')) return 'admin';
    return 'admin';  // Default to admin color
  }

  // ── HELPER: Generate initials from username or name ──────────────────────
  String _getInitials(String input) {
    if (input.isEmpty) return '?';
    final parts = input.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return input.substring(0, 1).toUpperCase();
  }

  // ── LOAD ROWS (Task data) ─────────────────────────────────────────────────
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
          for (int i = 0; i < 5; i++) {
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
        _snack('Failed to load tasks. Check connection.', success: false);
      }
    } catch (e) {
      setState(() => _loading = false);
      _snack('Connection error.', success: false);
      print('Load rows error: $e');
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
      print('Share error: $e');
    }
  }

  Future<void> _resetRow(_RowModel row) async {
    try {
      await http.patch(Uri.parse('$_baseUrl/${row.id}/reset'));
      setState(() {
        row.clientCtrl.clear();
        row.schedCtrl.clear();
        row.showAvatars = false;
      });
    } catch (_) {
      _snack('Reset failed.', success: false);
    }
  }

  Future<void> _deleteRow(_RowModel row) async {
    try {
      final r = await http.delete(Uri.parse('$_baseUrl/${row.id}'));
      if (r.statusCode == 200) {
        setState(() => rows.remove(row));
        row.dispose();
      }
    } catch (_) {
      _snack('Delete failed.', success: false);
    }
  }

  // void _openHistory() {
  //   Navigator.push(context, MaterialPageRoute(
  //     builder: (_) => _HistoryScreen(
  //       baseUrl: _baseUrl,
  //       employeeName: _employeeName ?? '',
  //     ),
  //   ));
  // }

Future<void> _openHistory() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString(
    'employeeMenu',
    'Video Task Planner History',
  );

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const EmployeeLayoutPage(),
    ),
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

  @override
  Widget build(BuildContext context) {
    if (_loading || _employeesLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF004AAD)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 28),
          _table(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(children: [
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tasks Planner', style: AppTextStyles.heading),
          SizedBox(height: 6),
          Text(
            'Organize, assign, and track tasks efficiently to ensure timely completion and improved team productivity.',
            style: AppTextStyles.subHeading,
          ),
        ],
      ),
      const Spacer(),
      OutlinedButton.icon(
        onPressed: _openHistory,
        icon: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF004AAD)),
        label: const Text('View History',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF004AAD))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF004AAD)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
      ),
      const SizedBox(width: 12),
      ElevatedButton(
        onPressed: _addSection,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF004AAD),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        child: const Text('+ Add Sections', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    ]);
  }

  Widget _table() {
    return Container(
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Container(
          height: 50,
          color: AppColors.lightBlue,
          child: const Row(children: [
            SizedBox(
              width: 250,
              child: Center(
                child: Text('Client Details',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ),
            ),
            Expanded(
              child: Center(
                child: Text('Scheduling Details',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ),
            ),
            SizedBox(
              width: 250,
              child: Center(
                child: Text('Action',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ),
            ),
          ]),
        ),
        ...rows.map(_buildRow),
      ]),
    );
  }

  Widget _buildRow(_RowModel row) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Container(
          width: 250,
          color: AppColors.lightBlue,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: TextField(
            controller: row.clientCtrl,
            textAlign: TextAlign.center,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter client name',
              border: InputBorder.none,
              hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            alignment: Alignment.center,
            child: TextField(
              controller: row.schedCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter scheduling details',
                hintStyle: TextStyle(color: Color(0xFFE1E5EA), fontSize: 16),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        Container(
          width: 250,
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.border))),
          child: Center(child: _shareWidget(row)),
        ),
      ]),
    );
  }

  Widget _shareWidget(_RowModel row) {
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))
                ],
              ),
              child: Text(row.showAvatars ? 'Hide' : 'Share',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
          if (row.showAvatars) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 90,
              child: Scrollbar(
                controller: _vidEmpScrollController,
                thumbVisibility: true,
                child: employees.isEmpty
                    ? const Center(
                        child: Text('No admin employees available',
                            style: TextStyle(fontSize: 12, color: Colors.red)))
                    : ListView.builder(
                        controller: _vidEmpScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: employees.length,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemBuilder: (_, i) => SizedBox(
                          width: 60,
                          child: _avatarTile(employees[i], () => _share(row, employees[i])),
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarTile(_EmpModel emp, VoidCallback onTap) {
    return Tooltip(
      message: '${emp.fullName} - ${emp.name} (${emp.userType})',
      showDuration: const Duration(seconds: 2),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
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
                  color: emp.color,
                  boxShadow: [
                    BoxShadow(color: emp.color.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 3))
                  ],
                ),
                alignment: Alignment.center,
                child: Text(emp.short,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 55,
                child: Text(emp.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HISTORY SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class _HistoryScreen extends StatefulWidget {
  final String baseUrl;
  final String employeeName;

  const _HistoryScreen({required this.baseUrl, required this.employeeName});

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  bool _loading = true;
  String _selectedMonth = 'All';
  DateTime? _selectedDate;
  List<String> _availableMonths = ['All'];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(
        Uri.parse('${widget.baseUrl}/shares?employee=${widget.employeeName}'),
      );
      if (r.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data'] ?? []);
        final months = <String>{'All'};
        for (final row in data) {
          final raw = row['shared_at'] as String? ?? '';
          if (raw.length >= 7) months.add(raw.substring(0, 7));
        }
        final sortedMonths = months.toList()
          ..sort((a, b) {
            if (a == 'All') return -1;
            if (b == 'All') return 1;
            return b.compareTo(a);
          });
        setState(() {
          _allRecords = data;
          _availableMonths = sortedMonths;
          _loading = false;
        });
        _applyFilters();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRecords = _allRecords.where((row) {
        final raw = row['shared_at'] as String? ?? '';
        final dt = DateTime.tryParse(raw);
        if (dt == null) return false;

        if (_selectedMonth != 'All') {
          final rowMonth = raw.substring(0, 7);
          if (rowMonth != _selectedMonth) return false;
        }

        if (_selectedDate != null) {
          if (dt.year != _selectedDate!.year || dt.month != _selectedDate!.month || dt.day != _selectedDate!.day) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedMonth = 'All';
      _selectedDate = null;
    });
    _applyFilters();
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy  $hh:$min';
  }

  String _monthLabel(String m) {
    if (m == 'All') return 'All Months';
    final parts = m.split('-');
    if (parts.length < 2) return m;
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final idx = int.tryParse(parts[1]) ?? 0;
    return '${months[idx]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF004AAD)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Share History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF172554))),
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF004AAD)),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: Colors.white,
          child: Row(children: [
            const Text('Month:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
            const SizedBox(width: 10),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  items: _availableMonths
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(_monthLabel(m), style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedMonth = v!;
                      _selectedDate = null;
                    });
                    _applyFilters();
                  },
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            ),
            const SizedBox(width: 20),
            const Text('Date:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  builder: (c, child) => Theme(
                    data: Theme.of(c)
                        .copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF004AAD))),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _selectedMonth = 'All';
                  });
                  _applyFilters();
                }
              },
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedDate != null ? const Color(0xFF004AAD) : const Color(0xFFCBD5E1),
                  ),
                  borderRadius: BorderRadius.circular(6),
                  color: _selectedDate != null ? const Color(0xFFEFF6FF) : Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF004AAD)),
                    const SizedBox(width: 8),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                            '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                            '${_selectedDate!.year}'
                          : 'Pick date',
                      style: TextStyle(
                        fontSize: 13,
                        color: _selectedDate != null ? const Color(0xFF004AAD) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            if (_selectedMonth != 'All' || _selectedDate != null)
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.close_rounded, size: 15, color: Colors.redAccent),
                label: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration:
                  BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
              child: Text('${_filteredRecords.length} record${_filteredRecords.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF004AAD))),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Container(
          height: 44,
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const Row(children: [
            SizedBox(width: 50, child: Text('#', style: _hStyle, textAlign: TextAlign.center)),
            SizedBox(width: 170, child: Text('Client Name', style: _hStyle)),
            Expanded(child: Text('Scheduling', style: _hStyle)),
            SizedBox(width: 160, child: Text('Shared To', style: _hStyle)),
            SizedBox(width: 100, child: Text('Role', style: _hStyle)),
            SizedBox(width: 160, child: Text('Date & Time', style: _hStyle)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF004AAD)))
              : _filteredRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _allRecords.isEmpty ? 'No share history yet.' : 'No records match the filter.',
                            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                          ),
                          if (_allRecords.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters',
                                  style: TextStyle(color: Color(0xFF004AAD))),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: _filteredRecords.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (_, idx) {
                        final rec = _filteredRecords[idx];
                        final client = rec['client_name'] as String? ?? '--';
                        final sched = rec['scheduling_details'] as String? ?? '--';
                        final receiverName = rec['receiver_employee_name'] as String? ?? '--';
                        final role = rec['receiver_role'] as String? ?? '--';
                        final sharedAt = _formatDateTime(rec['shared_at'] as String?);

                        const roleColors = {
                          'Designer': Color(0xFF6366F1),
                          'Page Handler': Color(0xFF8B5CF6),
                          'Ads Handler': Color(0xFFEC4899),
                          'Videographer': Color(0xFFF59E0B),
                          'Admin': Color(0xFF10B981),
                        };
                        final roleColor = roleColors[role] ?? const Color(0xFF6366F1);
                        final shortName = (rec['receiver_short'] as String? ?? '?');

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: idx.isEven ? Colors.white : const Color(0xFFFAFAFC),
                          child: Row(children: [
                            SizedBox(
                              width: 50,
                              child: Text('${idx + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ),
                            SizedBox(
                              width: 170,
                              child: Text(client,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2),
                            ),
                            Expanded(
                              child: Text(sched,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2),
                            ),
                            SizedBox(
                              width: 160,
                              child: Row(children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: roleColor),
                                  alignment: Alignment.center,
                                  child: Text(shortName,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(receiverName,
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ),
                            SizedBox(
                              width: 100,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(role,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w700, color: roleColor),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            SizedBox(
                              width: 160,
                              child: Text(sharedAt,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ),
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

const TextStyle _hStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569));

// ── MODELS ────────────────────────────────────────────────────────────────────
class _RowModel {
  final int id;
  final TextEditingController clientCtrl;
  final TextEditingController schedCtrl;
  bool showAvatars;

  _RowModel(
      {required this.id, String clientName = '', String schedulingDetails = ''})
      : showAvatars = false, clientCtrl = TextEditingController(text: clientName),
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