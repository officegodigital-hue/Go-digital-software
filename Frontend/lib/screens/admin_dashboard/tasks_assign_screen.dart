import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../layouts/admin_layout.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart'; 
import 'package:flutter/gestures.dart';
import '../../services/api_config.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class TasksAssignScreen extends StatefulWidget {
  const TasksAssignScreen({super.key});

  @override
  State<TasksAssignScreen> createState() => _TasksAssignScreenState();
}

class _TasksAssignScreenState extends State<TasksAssignScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  // ────────────────────────────────────────────────────────────────────────────
  // 2050 TABLE SCROLL CONTROLLERS
  // Separate controllers keep the frozen CLIENT column and the scrollable
  // columns perfectly aligned without allowing the client column to move
  // horizontally.
  // ────────────────────────────────────────────────────────────────────────────
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _leftVerticalController = ScrollController();

  bool _syncingHorizontal = false;
  bool _syncingVertical = false;

  List<Map<String, dynamic>> taskRows = [];
  List<String> employees = [];
  List<String> clients = [];
  List<Map<String, dynamic>> taskMaster = [];
  List<Map<String, dynamic>> packagesList = [];
  bool _loadingPackages = true;

  List<Map<String, dynamic>> allClientsData = []; // Store full client objects
  
  Map<String, String> taskRoles = {};
  bool _loadingRoles = true;

  bool _showAssigned = false;
  bool _loadingTasks = true;
  bool _loadingEmployees = true;
  bool _loadingClients = true;
  bool _loadingTaskMaster = true;
  String? _error;
  String? _adminName;
  String _searchQuery = '';

  String _toSnakeCase(String text) {
    return text
        .replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1_$2')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase()
        .trim();
  }

  @override
  void initState() {
    super.initState();

    _adminName = context.read<AuthService>().user?['fullName'] as String? ?? 'Admin';

    // Keep header + body horizontal positions locked together.

    // Keep the frozen client column vertically aligned with the right-side rows.
    _leftVerticalController.addListener(_syncLeftToRight);
    _verticalController.addListener(_syncRightToLeft);

    _fetchTaskRoles();
    _fetchAll();
  }

  void _syncLeftToRight() {
    if (_syncingVertical || !_verticalController.hasClients) return;
    _syncingVertical = true;
    final target = _leftVerticalController.offset.clamp(
      0.0,
      _verticalController.position.maxScrollExtent,
    );
    if ((_verticalController.offset - target).abs() > 0.1) {
      _verticalController.jumpTo(target);
    }
    _syncingVertical = false;
  }

  void _syncRightToLeft() {
    if (_syncingVertical || !_leftVerticalController.hasClients) return;
    _syncingVertical = true;
    final target = _verticalController.offset.clamp(
      0.0,
      _leftVerticalController.position.maxScrollExtent,
    );
    if ((_leftVerticalController.offset - target).abs() > 0.1) {
      _leftVerticalController.jumpTo(target);
    }
    _syncingVertical = false;
  }

  @override
  void dispose() {
    _leftVerticalController.removeListener(_syncLeftToRight);
    _verticalController.removeListener(_syncRightToLeft);

    _horizontalController.dispose();
    _verticalController.dispose();
    _leftVerticalController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchEmployees(),
      _fetchClients(), 
      _fetchPackagesData(),  
      _fetchTaskMaster(),
      _fetchTasks(),
    ]);
  }

  // ✅ FIXED: Fetch active clients from /api/clients and filter company_name where is_active == 1
//   Future<void> _fetchClients() async {
//   setState(() => _loadingClients = true);
//   try {
//     final r = await http.get(Uri.parse('$_baseUrl/clients'));
//     if (r.statusCode == 200) {
//       final body = jsonDecode(r.body);
//       final data = List<Map<String, dynamic>>.from(body['data'] ?? []);
//       setState(() {
//         allClientsData = data; // Keep full client data to check status later
        
//         // Active clients for dropdowns
//         clients = data
//             .where((c) => c['is_active'] == 1 || c['is_active'] == true)
//             .map((c) => (c['company_name'] ?? '').toString().trim())
//             .where((name) => name.isNotEmpty)
//             .toSet()
//             .toList()
//           ..sort();
//         _loadingClients = false;
//       });
//     } else {
//       setState(() => _loadingClients = false);
//     }
//   } catch (e) {
//     setState(() => _loadingClients = false);
//   }
// }

Future<void> _fetchClients() async {
  setState(() => _loadingClients = true);
  try {
    final r = await http.get(Uri.parse('$_baseUrl/clients/active-list')); // 🟢 Updated route
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      final data = List<Map<String, dynamic>>.from(body['data'] ?? []);
      setState(() {
        allClientsData = data; 
        clients = data
            .map((c) => (c['company_name'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _loadingClients = false;
      });
    } else {
      setState(() => _loadingClients = false);
    }
  } catch (e) {
    setState(() => _loadingClients = false);
  }
}

  Future<void> _fetchPackagesData() async {
    setState(() => _loadingPackages = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/packages'));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        setState(() {
          packagesList = List<Map<String, dynamic>>.from(body['data'] ?? []);
          _loadingPackages = false;
        });
      } else {
        setState(() => _loadingPackages = false);
      }
    } catch (e) {
      setState(() => _loadingPackages = false);
    }
  }

  Future<void> _onPackageSelected(Map<String, dynamic> row, String packageName) async {
    setState(() {
      row['deliverables'] = packageName;
    });

    final selectedPkg = packagesList.firstWhere(
      (p) => (p['title'] ?? '').toString() == packageName,
      orElse: () => {},
    );

    if (selectedPkg.isNotEmpty && selectedPkg['package_tasks'] != null) {
      final pTasks = List<dynamic>.from(selectedPkg['package_tasks']);

      row['ads_platform'] = '';
      row['pages_platform'] = '';
      row['designer_tasks'] = '';
      row['videographer_tasks'] = '';
      row['video_editor_task'] = '';
      row['ui_ux_tasks'] = '';
      row['developer_tasks'] = '';
      row['website_designer_tasks'] = '';

      Map<String, List<String>> roleTaskMap = {};

      for (var pt in pTasks) {
        if (pt is Map) {
          final tName = pt['task_name']?.toString() ?? '';
          final count = pt['count'] ?? 1;
          final rKey = pt['role_key']?.toString() ?? '';

          if (tName.isNotEmpty && rKey.isNotEmpty) {
            roleTaskMap.putIfAbsent(rKey, () => []).add('$tName ($count)');
          }
        }
      }

      if (roleTaskMap.containsKey('ads_handler_task')) row['ads_platform'] = roleTaskMap['ads_handler_task']!.join(', ');
      if (roleTaskMap.containsKey('page_handler_task')) row['pages_platform'] = roleTaskMap['page_handler_task']!.join(', ');
      if (roleTaskMap.containsKey('graphic_designer_task')) row['designer_tasks'] = roleTaskMap['graphic_designer_task']!.join(', ');
      if (roleTaskMap.containsKey('videographer_task')) row['videographer_tasks'] = roleTaskMap['videographer_task']!.join(', ');
      if (roleTaskMap.containsKey('video_editor_task')) row['video_editor_task'] = roleTaskMap['video_editor_task']!.join(', ');
      if (roleTaskMap.containsKey('ui_ux_designer_task')) row['ui_ux_tasks'] = roleTaskMap['ui_ux_designer_task']!.join(', ');
      if (roleTaskMap.containsKey('developer_task')) row['developer_tasks'] = roleTaskMap['developer_task']!.join(', ');
      if (roleTaskMap.containsKey('website_designer_task')) row['website_designer_tasks'] = roleTaskMap['website_designer_task']!.join(', ');
    }

    await _saveRow(row);
  }

  Future<void> _fetchTaskRoles() async {
    setState(() => _loadingRoles = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/task-roles'));
      if (r.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
        setState(() {
          taskRoles = {};
          for (var role in data) {
            taskRoles[role['role_key']] = role['role_name'];
          }
          _loadingRoles = false;
        });
      } else {
        setState(() => _loadingRoles = false);
      }
    } catch (e) {
      setState(() => _loadingRoles = false);
    }
  }

  Future<bool> _addNewRoleToBackend(String roleName, String roleKey) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/task-roles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'role_name': roleName, 'role_key': roleKey}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchTaskRoles();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _fetchTaskMaster() async {
    setState(() => _loadingTaskMaster = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/task-master'));
      if (r.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
        setState(() {
          taskMaster = data;
          _loadingTaskMaster = false;
        });
      } else {
        setState(() => _loadingTaskMaster = false);
      }
    } catch (e) {
      setState(() => _loadingTaskMaster = false);
    }
  }

  List<Map<String, dynamic>> getTasksForRole(String roleKey) {
    return taskMaster.where((task) => task['role_key'] == roleKey).toList();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/employees'));
      if (r.statusCode == 200) {
        // final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
        // setState(() {
        //   employees = data.map((e) => (e['full_name'] ?? '').toString().toUpperCase()).toList();
        //   _loadingEmployees = false;
        // });
        final data =
    List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);

setState(() {
  employees = data
      .where((e) =>
          e['is_active'] == 1 ||
          e['is_active'] == true)
      .map((e) =>
          (e['full_name'] ?? '').toString().toUpperCase())
      .where((name) => name.isNotEmpty)
      .toList();

  _loadingEmployees = false;
});
      } else {
        setState(() => _loadingEmployees = false);
      }
    } catch (_) {
      setState(() => _loadingEmployees = false);
    }
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _loadingTasks = true;
      _error = null;
    });
    try {
      final r = await http.get(Uri.parse('$_baseUrl/tasks'));
      if (r.statusCode == 200) {
        setState(() {
          taskRows = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
          _loadingTasks = false;
        });
      } else {
        setState(() {
          _error = 'Server error ${r.statusCode}';
          _loadingTasks = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Cannot connect to server';
        _loadingTasks = false;
      });
    }
  }

  Future<void> _addRow() async {
    try {
      final r = await http.post(
        Uri.parse('$_baseUrl/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'clientName': 'PENDING_SELECTION'}),
      );
      if (r.statusCode == 201 || r.statusCode == 200) {
        await _fetchTasks(); 
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // Future<void> _showTaskMasterDialog() async {
  //   final roleController = TextEditingController();
  //   final taskController = TextEditingController();
  //   String newRoleName = '';
  //   String selectedRole = taskRoles.entries.isNotEmpty ? taskRoles.entries.first.key : '';
  //   String taskName = '';
  //   bool isEditing = false;
  //   int? editingTaskId;

  //   await _fetchTaskRoles();

  //   await showDialog(
  //     context: context,
  //     barrierColor: Colors.black12,
  //     builder: (ctx) => StatefulBuilder(
  //       builder: (ctx, setDialogState) => Dialog(
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //         child: ConstrainedBox(
  //           constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //                 decoration: const BoxDecoration(
  //                   color: Color(0xFF0052CC),
  //                   borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
  //                 ),
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: [
  //                     const Text('Task Master Manager', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
  //                     GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, size: 18, color: Colors.white)),
  //                   ],
  //                 ), 
  //               ),
  //               Expanded(
  //                 child: SingleChildScrollView(
  //                   child: Padding(
  //                     padding: const EdgeInsets.all(16),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Container(
  //                           padding: const EdgeInsets.all(12),
  //                           decoration: BoxDecoration(
  //                             color: const Color(0xFFFFF3CD),
  //                             border: Border.all(color: const Color(0xFFFFD700)),
  //                             borderRadius: BorderRadius.circular(6),
  //                           ),
  //                           child: Column(
  //                             crossAxisAlignment: CrossAxisAlignment.start,
  //                             children: [
  //                               const Text('📌 Create New Task Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF856404))),
  //                               const SizedBox(height: 12),
  //                               const Text('Role Name:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
  //                               const SizedBox(height: 8),
  //                               TextField(
  //                                 controller: roleController,
  //                                 onChanged: (val) => setDialogState(() => newRoleName = val),
  //                                 decoration: InputDecoration(
  //                                   hintText: 'e.g., Content Creator Task',
  //                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
  //                                   contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  //                                   filled: true,
  //                                   fillColor: Colors.white,
  //                                 ),
  //                                 style: const TextStyle(fontSize: 11),
  //                               ),
  //                               const SizedBox(height: 12),
  //                               Row(
  //                                 children: [
  //                                   const Spacer(),
  //                                   ElevatedButton.icon(
  //                                     onPressed: newRoleName.trim().isEmpty ? null : () async {
  //                                       final roleKey = _toSnakeCase(newRoleName);
  //                                       final success = await _addNewRoleToBackend(newRoleName, roleKey);
  //                                       if (success) {
  //                                         setDialogState(() {
  //                                           roleController.clear();
  //                                           newRoleName = '';
  //                                           selectedRole = roleKey;
  //                                         });
  //                                       }
  //                                     },
  //                                     icon: const Icon(Icons.add, size: 16),
  //                                     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA500)),
  //                                     label: const Text('Add New Role', style: TextStyle(color: Colors.white, fontSize: 11)),
  //                                   ),
  //                                 ],
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               Container(
  //                 padding: const EdgeInsets.all(12),
  //                 decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.end,
  //                   children: [
  //                     TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B)))),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  //   roleController.dispose();
  //   taskController.dispose();
  // }


    // ── SHOW TASK MASTER MANAGEMENT DIALOG ──────────────────────────────────
 // ════════════════════════════════════════════════════════════════════════════
// 2050 TASK MASTER MANAGER
// Same visual language as User Role Master
// Responsive + mobile friendly + safe internal scrolling
// TABLE SCROLL CODE IS NOT TOUCHED
// ════════════════════════════════════════════════════════════════════════════
Future<void> _showTaskMasterDialog() async {
  final roleController = TextEditingController();
  final taskController = TextEditingController();

  String newRoleName = '';
  String selectedRole = taskRoles.entries.isNotEmpty
      ? taskRoles.entries.first.key
      : '';

  String taskName = '';
  bool isEditing = false;
  int? editingTaskId;

  await _fetchTaskRoles();

  if (!mounted) return;

  // After fresh API fetch, make sure selected role is valid.
  if (selectedRole.isEmpty && taskRoles.isNotEmpty) {
    selectedRole = taskRoles.entries.first.key;
  }

  await showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (dialogContext) {
      final screenSize = MediaQuery.of(dialogContext).size;
      final isMobile = screenSize.width < 600;

      final dialogWidth = isMobile
          ? screenSize.width - 24
          : screenSize.width > 1000
              ? 620.0
              : 560.0;

      final dialogHeight = isMobile
          ? screenSize.height * 0.88
          : screenSize.height > 850
              ? 720.0
              : screenSize.height * 0.84;

      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final roleTaskList = getTasksForRole(selectedRole);

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 14 : 24,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(
                  isMobile ? 26 : 28,
                ),
                child: Column(
                  children: [

                    // ═══════════════════════════════════════════════════════
                    // HEADER
                    // ═══════════════════════════════════════════════════════
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 18 : 24,
                        isMobile ? 18 : 20,
                        isMobile ? 14 : 18,
                        isMobile ? 18 : 20,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF0759D5),
                            Color(0xFF0042A8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [

                          Container(
                            width: isMobile ? 46 : 52,
                            height: isMobile ? 46 : 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.assignment_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),

                          const SizedBox(width: 13),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Task Master Manager',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -.3,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Create roles and manage tasks',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            tooltip: 'Close',
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ═══════════════════════════════════════════════════════
                    // SCROLLABLE CONTENT
                    // ═══════════════════════════════════════════════════════
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: !isMobile,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isMobile ? 16 : 24,
                            20,
                            isMobile ? 16 : 24,
                            24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // ═══════════════════════════════════════════
                              // CREATE NEW ROLE
                              // ═══════════════════════════════════════════
                              _taskMasterSectionCard(
                                icon: Icons.push_pin_rounded,
                                title: 'Create New Task Role',
                                subtitle:
                                    'Create a new role for organising task types.',
                                iconBackground: const Color(0xFFFFF1C7),
                                iconColor: const Color(0xFFD97706),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [

                                    const Text(
                                      'Role Name',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),

                                    const SizedBox(height: 7),

                                    _taskMasterTextField(
                                      controller: roleController,
                                      hint:
                                          'e.g. Content Creator Task',
                                      icon: Icons.badge_outlined,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          newRoleName = value;
                                        });
                                      },
                                    ),

                                    const SizedBox(height: 8),

                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 13,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            newRoleName.trim().isEmpty
                                                ? 'Role key will auto-generate in snake_case'
                                                : 'Key: ${_toSnakeCase(newRoleName)}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF64748B),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 14),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            newRoleName.trim().isEmpty
                                                ? null
                                                : () async {
                                                    final roleName =
                                                        newRoleName.trim();

                                                    final roleKey =
                                                        _toSnakeCase(
                                                      roleName,
                                                    );

                                                    final success =
                                                        await _addNewRoleToBackend(
                                                      roleName,
                                                      roleKey,
                                                    );

                                                    if (!mounted) return;

                                                    if (success) {
                                                      await _fetchTaskRoles();

                                                      setDialogState(() {
                                                        roleController.clear();
                                                        newRoleName = '';
                                                        selectedRole = roleKey;

                                                        if (!taskRoles
                                                            .containsKey(
                                                                selectedRole)) {
                                                          selectedRole =
                                                              taskRoles
                                                                      .isNotEmpty
                                                                  ? taskRoles
                                                                      .entries
                                                                      .first
                                                                      .key
                                                                  : '';
                                                        }
                                                      });

                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Role "$roleName" created successfully.',
                                                          ),
                                                          backgroundColor:
                                                              const Color(
                                                                  0xFF16A34A),
                                                        ),
                                                      );
                                                    }
                                                  },
                                        icon: const Icon(
                                          Icons.add_rounded,
                                          size: 19,
                                        ),
                                        label: const Text(
                                          'Add New Role',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF0052CC),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              const Color(0xFFE2E8F0),
                                          disabledForegroundColor:
                                              const Color(0xFF94A3B8),
                                          elevation: 0,
                                          padding:
                                              const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // ═══════════════════════════════════════════
                              // MANAGE TASKS
                              // ═══════════════════════════════════════════
                              _taskMasterSectionCard(
                                icon: Icons.tune_rounded,
                                title: 'Manage Tasks for Role',
                                subtitle:
                                    'Add, edit and remove tasks under a role.',
                                iconBackground: const Color(0xFFEFF6FF),
                                iconColor: const Color(0xFF0052CC),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [

                                    const Text(
                                      'Select Task Role',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),

                                    const SizedBox(height: 7),

                                    Container(
                                      height: 52,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius:
                                            BorderRadius.circular(13),
                                        border: Border.all(
                                          color: const Color(0xFFDCE5F0),
                                        ),
                                      ),
                                      child:
                                          DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: taskRoles.containsKey(
                                            selectedRole,
                                          )
                                              ? selectedRole
                                              : taskRoles.isNotEmpty
                                                  ? taskRoles
                                                      .entries
                                                      .first
                                                      .key
                                                  : null,
                                          isExpanded: true,
                                          icon: const Icon(
                                            Icons
                                                .keyboard_arrow_down_rounded,
                                            color: Color(0xFF64748B),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                          dropdownColor: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          items: taskRoles.entries
                                              .map(
                                                (entry) =>
                                                    DropdownMenuItem<String>(
                                                  value: entry.key,
                                                  child: Text(
                                                    entry.value,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            if (value == null) return;

                                            setDialogState(() {
                                              selectedRole = value;
                                              taskController.clear();
                                              taskName = '';
                                              isEditing = false;
                                              editingTaskId = null;
                                            });
                                          },
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // TASK NAME
                                    const Text(
                                      'Task Name',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),

                                    const SizedBox(height: 7),

                                    _taskMasterTextField(
                                      controller: taskController,
                                      hint:
                                          'Enter task name e.g. Poster, Video, Reels',
                                      icon: Icons.task_alt_rounded,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          taskName = value;
                                        });
                                      },
                                    ),

                                    const SizedBox(height: 18),

                                    // EXISTING TASKS HEADER
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.list_alt_rounded,
                                            size: 17,
                                            color: Color(0xFF0052CC),
                                          ),
                                        ),
                                        const SizedBox(width: 9),
                                        const Expanded(
                                          child: Text(
                                            'Existing Tasks',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${roleTaskList.length}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0052CC),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // EXISTING TASK LIST
                                    Container(
                                      constraints: BoxConstraints(
                                        maxHeight: isMobile ? 250 : 280,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius:
                                            BorderRadius.circular(15),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: roleTaskList.isEmpty
                                          ? const Center(
                                              child: Padding(
                                                padding:
                                                    EdgeInsets.all(30),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      size: 34,
                                                      color:
                                                          Color(0xFFCBD5E1),
                                                    ),
                                                    SizedBox(height: 9),
                                                    Text(
                                                      'No tasks yet',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            Color(0xFF64748B),
                                                      ),
                                                    ),
                                                    SizedBox(height: 3),
                                                    Text(
                                                      'Add a task using the field above.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Color(0xFF94A3B8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Scrollbar(
                                              thumbVisibility: !isMobile,
                                              child: ListView.separated(
                                                padding:
                                                    const EdgeInsets.all(9),
                                                itemCount:
                                                    roleTaskList.length,
                                                separatorBuilder:
                                                    (_, __) =>
                                                        const SizedBox(
                                                            height: 7),
                                                itemBuilder:
                                                    (context, index) {
                                                  final task =
                                                      roleTaskList[index];

                                                  final id = task['id'];
                                                  final name =
                                                      (task['task_name'] ??
                                                              '')
                                                          .toString();

                                                  return Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(12),
                                                      border: Border.all(
                                                        color: const Color(
                                                            0xFFE2E8F0),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [

                                                        Container(
                                                          width: 36,
                                                          height: 36,
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                const Color(
                                                                    0xFFEFF6FF),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .checklist_rounded,
                                                            size: 18,
                                                            color: Color(
                                                                0xFF0052CC),
                                                          ),
                                                        ),

                                                        const SizedBox(
                                                            width: 10),

                                                        Expanded(
                                                          child: Text(
                                                            name,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: Color(
                                                                  0xFF0F172A),
                                                            ),
                                                          ),
                                                        ),

                                                        const SizedBox(
                                                            width: 6),

                                                        IconButton(
                                                          tooltip: 'Edit',
                                                          onPressed: () {
                                                            setDialogState(
                                                              () {
                                                                taskName =
                                                                    name;
                                                                taskController
                                                                        .text =
                                                                    name;
                                                                isEditing =
                                                                    true;
                                                                editingTaskId =
                                                                    id;
                                                              },
                                                            );
                                                          },
                                                          icon: const Icon(
                                                            Icons
                                                                .edit_rounded,
                                                            size: 18,
                                                            color: Color(
                                                                0xFF0052CC),
                                                          ),
                                                        ),

                                                        IconButton(
                                                          tooltip: 'Delete',
                                                          onPressed: () async {
                                                            final confirmed =
                                                                await showDialog<
                                                                    bool>(
                                                              context:
                                                                  dialogContext,
                                                              builder:
                                                                  (confirmContext) {
                                                                return AlertDialog(
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            18),
                                                                  ),
                                                                  title:
                                                                      const Text(
                                                                    'Delete Task?',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          17,
                                                                      fontWeight:
                                                                          FontWeight.w800,
                                                                    ),
                                                                  ),
                                                                  content:
                                                                      Text(
                                                                    'Remove "$name" from this role?',
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Color(
                                                                          0xFF64748B),
                                                                    ),
                                                                  ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.pop(confirmContext, false),
                                                                      child:
                                                                          const Text(
                                                                        'Cancel',
                                                                      ),
                                                                    ),
                                                                    ElevatedButton(
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.pop(confirmContext, true),
                                                                      style:
                                                                          ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            const Color(0xFFDC2626),
                                                                        foregroundColor:
                                                                            Colors.white,
                                                                      ),
                                                                      child:
                                                                          const Text(
                                                                        'Delete',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );

                                                            if (confirmed !=
                                                                true) {
                                                              return;
                                                            }

                                                            await _deleteTask(
                                                                id);
                                                            await _fetchTaskMaster();

                                                            setDialogState(() {
                                                              taskController
                                                                  .clear();
                                                              taskName = '';
                                                              isEditing = false;
                                                              editingTaskId =
                                                                  null;
                                                            });
                                                          },
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline_rounded,
                                                            size: 19,
                                                            color: Color(
                                                                0xFFDC2626),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
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

                    // ═══════════════════════════════════════════════════════
                    // FOOTER
                    // ═══════════════════════════════════════════════════════
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 24,
                        12,
                        isMobile ? 16 : 24,
                        14,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [

                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      const Color(0xFF64748B),
                                  side: const BorderSide(
                                    color: Color(0xFFD7E0EA),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: taskName.trim().isEmpty
                                    ? null
                                    : () async {
                                        final currentName =
                                            taskName.trim();

                                        final wasEditing = isEditing;

                                        if (wasEditing &&
                                            editingTaskId != null) {
                                          await _updateTask(
                                            editingTaskId!,
                                            currentName,
                                            selectedRole,
                                          );
                                        } else {
                                          await _addNewTask(
                                            currentName,
                                            selectedRole,
                                          );
                                        }

                                        await _fetchTaskMaster();

                                        setDialogState(() {
                                          taskController.clear();
                                          taskName = '';
                                          isEditing = false;
                                          editingTaskId = null;
                                        });

                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                wasEditing
                                                    ? 'Task updated successfully.'
                                                    : 'Task added successfully.',
                                              ),
                                              backgroundColor:
                                                  const Color(0xFF16A34A),
                                            ),
                                          );
                                        }
                                      },
                                icon: Icon(
                                  isEditing
                                      ? Icons.update_rounded
                                      : Icons.add_task_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  isEditing
                                      ? 'Update Task'
                                      : 'Add Task',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF0052CC),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFFE2E8F0),
                                  disabledForegroundColor:
                                      const Color(0xFF94A3B8),
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  // IMPORTANT:
  // Dispose only AFTER the dialog is completely closed.
  roleController.dispose();
  taskController.dispose();
}


// ════════════════════════════════════════════════════════════════════════════
// TASK MASTER SECTION CARD
// ════════════════════════════════════════════════════════════════════════════
Widget _taskMasterSectionCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color iconBackground,
  required Color iconColor,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFE2E8F0),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: .035),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 19,
                color: iconColor,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        child,
      ],
    ),
  );
}


// ════════════════════════════════════════════════════════════════════════════
// TASK MASTER TEXT FIELD
// ════════════════════════════════════════════════════════════════════════════
Widget _taskMasterTextField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  required ValueChanged<String> onChanged,
}) {
  return TextField(
    controller: controller,
    onChanged: onChanged,
    textInputAction: TextInputAction.next,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: Color(0xFF0F172A),
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 11.5,
        color: Color(0xFF94A3B8),
      ),
      prefixIcon: Icon(
        icon,
        size: 18,
        color: const Color(0xFF0052CC),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFFDCE5F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFFDCE5F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: Color(0xFF0052CC),
          width: 1.5,
        ),
      ),
    ),
  );
}
  
  // ── ADD NEW TASK TO TASK MASTER ────────────────────────────────────────
  Future<void> _addNewTask(String taskName, String roleKey) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/task-master'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_name': taskName,
          'role_key': roleKey,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        final body = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['message'] ?? 'Failed to add task'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error adding task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── UPDATE EXISTING TASK ────────────────────────────────────────────────
  Future<void> _updateTask(int taskId, String taskName, String roleKey) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/task-master/$taskId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_name': taskName,
          'role_key': roleKey,
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['message'] ?? 'Failed to update task'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── DELETE TASK FROM TASK MASTER ───────────────────────────────────────
  Future<void> _deleteTask(int taskId) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/task-master/$taskId'));

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['message'] ?? 'Failed to delete task'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


 // ── SHOW TASK SELECTION POPUP WITH ROLE & COUNT ────────────────────────
  Future<void> _showTaskSelectionPopup({
    required String roleKey,
    required Map<String, dynamic> row,
    required String dbFieldKey,
  }) async {
    final availableTasks = getTasksForRole(roleKey);

    if (availableTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No tasks found for ${taskRoles[roleKey] ?? roleKey}. Please add tasks in Task Master.')),
      );
      return;
    }

    final selectedTasks = <Map<String, dynamic>>[];
    final existingValue = (row[dbFieldKey] ?? '').toString();

    if (existingValue.isNotEmpty) {
      final items = existingValue.split(',');
      for (final item in items) {
        final match = RegExp(r'^(.*?)\s*\((\d+)\)$').firstMatch(item.trim());
        if (match != null) {
          final taskName = match.group(1)!.trim();
          final count = int.parse(match.group(2)!);

          final task = availableTasks.firstWhere(
            (e) => e['task_name'] == taskName,
            orElse: () => <String, dynamic>{},
          );

          if (task.isNotEmpty) {
            selectedTasks.add({
              'id': task['id'],
              'name': taskName,
              'count': count,
            });
          }
        }
      }
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0052CC),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(taskRoles[roleKey] ?? roleKey,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // ✅ Select All Checkbox Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectedTasks.length == availableTasks.length && availableTasks.isNotEmpty,
                        tristate: false,
                        activeColor: const Color(0xFF0052CC),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedTasks.clear();
                            if (val == true) {
                              for (final task in availableTasks) {
                                selectedTasks.add({
                                  'id': task['id'],
                                  'name': task['task_name'],
                                  'count': 1,
                                });
                              }
                            }
                          });
                        },
                      ),
                      const Text(
                        "Select All",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: availableTasks.length,
                    itemBuilder: (context, index) {
                      final task = availableTasks[index];
                      final taskId = task['id'];
                      final taskName = task['task_name'] ?? '';
                      
                      final selectedIndex = selectedTasks.indexWhere((t) => t['id'] == taskId);
                      final isSelected = selectedIndex != -1;
                      
                      int currentCount = isSelected ? (selectedTasks[selectedIndex]['count'] ?? 1) : 1;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF0052CC),
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedTasks.add({
                                      'id': taskId,
                                      'name': taskName,
                                      'count': 1,
                                    });
                                  } else {
                                    selectedTasks.removeWhere((t) => t['id'] == taskId);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                taskName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              ),
                            ),
                            if (isSelected)
                              SizedBox(
                                width: 70,
                                height: 32,
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  controller: TextEditingController(text: currentCount.toString())..selection = TextSelection.fromPosition(TextPosition(offset: currentCount.toString().length)),
                                  decoration: const InputDecoration(
                                    labelText: 'Count',
                                    labelStyle: TextStyle(fontSize: 10),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val);
                                    if (parsed != null && parsed > 0) {
                                      selectedTasks[selectedIndex]['count'] = parsed;
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final taskString = selectedTasks.map((t) => '${t['name']} (${t['count']})').join(', ');
                          setState(() => row[dbFieldKey] = taskString);
                          _saveRow(row);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0052CC),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Apply', style: TextStyle(color: Color(0xFFFFFFFF)),),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveRow(Map<String, dynamic> row) async {
    try {
      String clientName = row['client_name'] ?? '';
      if (clientName == 'PENDING_SELECTION') {
        clientName = '';
      }

      await http.put(
        Uri.parse('$_baseUrl/tasks/${row["id"]}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clientName': clientName,
          'deliverables': row['deliverables'] ?? '',
          'maintenanceDate': row['maintenance_date'] ?? '',
          
          // Ads Handler fields
          'adsHandling': _cleanRoleValue(row['ads_handling']),
          'adsPlatform': row['ads_platform'] ?? '',
          // 'adsSubmitDate': row['ads_submit_date'] ?? '',
          
          // Page Handler fields
          'pageHandling': _cleanRoleValue(row['page_handling']),
          'pagesPlatform': row['pages_platform'] ?? '',
          // 'pageSubmitDate': row['page_submit_date'] ?? '',
          
          // Designer fields
          'designer': _cleanRoleValue(row['designer']),
          'designerTasks': row['designer_tasks'] ?? '',
          // 'designerSubmitDate': row['designer_submit_date'] ?? '',
          
          // Videographer fields
          'videographer': _cleanRoleValue(row['videographer']),
          'videographerTasks': row['videographer_tasks'] ?? '',
          // 'videographerSubmitDate': row['videographer_submit_date'] ?? '',
          
          // Video Editor fields
          'videoEditor': _cleanRoleValue(row['video_editor']),
          'videoEditorTask': row['video_editor_task'] ?? '',
          // 'videoEditorSubmitDate': row['video_editor_submit_date'] ?? '',
          
          // UI/UX Designer fields
          'uiUxDesigner': _cleanRoleValue(row['ui_ux_designer']),
          'uiUxTasks': row['ui_ux_tasks'] ?? '',
          // 'uiUxSubmitDate': row['ui_ux_submit_date'] ?? '',
          
          // Developer fields
          'developer': _cleanRoleValue(row['developer']),
          'developerTasks': row['developer_tasks'] ?? '',
          // 'developerSubmitDate': row['developer_submit_date'] ?? '',
          
          // Website Designer fields
          'websiteDesigner':_cleanRoleValue(row['website_designer']),
          'websiteDesignerTasks':row['website_designer_tasks'] ?? '',
          // 'websiteDesignerSubmitDate':row['website_designer_submit_date'] ?? '',
          
          // Others
          'deadline': _cleanRoleValue(row['deadline']),
          'comments': row['comments'] ?? '',
          'isAssigned': row['is_assigned'] == 1 || row['is_assigned'] == true,
          'assignedByName': _adminName,
        }),
      );
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  
  static const Map<String, String> _requiredRoleFields = {
    'ads_handling': 'Ads Handler',
    'page_handling': 'Page Handler',
    'designer': 'Designer',
    'videographer': 'Videographer',
    'video_editor': 'Video Editor',
    'ui_ux_designer': 'UI/UX Designer',
    'developer': 'Developer',
    'deadline': 'Deadline',
  };

  List<String> _missingFieldsFor(Map<String, dynamic> row) {
    final missing = <String>[];
    final clientName = (row['client_name'] ?? '').toString();
    if (clientName.isEmpty || clientName == 'PENDING_SELECTION') missing.add('Client');
    _requiredRoleFields.forEach((key, label) {
      if ((row[key] ?? '').toString().isEmpty) missing.add(label);
    });
    return missing;
  }

  Future<void> _toggleAssign(Map<String, dynamic> row) async {
    final newVal = !(row['is_assigned'] == 1 || row['is_assigned'] == true);
    if (newVal) {
      final missing = _missingFieldsFor(row);
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill: ${missing.join(", ")} before assigning.'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/tasks/${row["id"]}/assign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isAssigned': newVal, 'assignedByName': _adminName}),
      );
      if (response.statusCode == 200) {
        setState(() => row['is_assigned'] = newVal ? 1 : 0);
      }
    } catch (e) {
      debugPrint("Toggle error: $e");
    }
  }

  String _cleanRoleValue(dynamic v) {
    final s = (v ?? '').toString();
    return s.toUpperCase() == 'NONE' ? '' : s;
  }

  Future<void> _deleteRow(int id) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/tasks/$id'));
      await _fetchTasks();
    } catch (_) {}
  }

  Future<void> _pickDate(Map<String, dynamic> row, String fieldKey) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) {
      setState(() => row[fieldKey] = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}');
      await _saveRow(row);
    }
  }

  String formatDisplayDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(value.toString()).toLocal());
    } catch (e) {
      return value.toString();
    }
  }

  List<Map<String, dynamic>> get _visibleRows {
    return taskRows.where((r) {
      final assigned = r['is_assigned'] == 1 || r['is_assigned'] == true;
      if (_showAssigned != assigned) return false;

      final clientName = (r['client_name'] ?? '').toString().trim();
      if (clientName.isEmpty || clientName == 'PENDING_SELECTION') {
        return _searchQuery.trim().isEmpty;
      }

      final clientMatch = allClientsData.firstWhere(
        (c) => (c['company_name'] ?? '').toString().trim().toLowerCase() == clientName.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (clientMatch.isEmpty) return false;

      final isActive = clientMatch['is_active'] == 1 || clientMatch['is_active'] == true;
      if (!isActive) return false;

      if (_showAssigned) {
        final currentClient = clientName.toLowerCase();
        final currentId = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString()) ?? 0;
        final hasNewerTaskForSameClient = taskRows.any((other) {
          final otherAssigned = other['is_assigned'] == 1 || other['is_assigned'] == true;
          if (!otherAssigned) return false;
          final otherClient = (other['client_name'] ?? '').toString().trim().toLowerCase();
          if (otherClient != currentClient) return false;
          final otherId = other['id'] is int ? other['id'] as int : int.tryParse(other['id'].toString()) ?? 0;
          return otherId > currentId;
        });
        if (hasNewerTaskForSameClient) return false;
      }

      if (_searchQuery.trim().isEmpty) return true;
      return clientName.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool loading = _loadingTasks || _loadingEmployees || _loadingClients || _loadingPackages || _loadingTaskMaster || _loadingRoles;

    return AdminLayout(
      pageTitle: "Tasks Assign",
      currentRoute: "/tasks",
      onSearch: (query) => setState(() => _searchQuery = query),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 900;

              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Task Assign - Employees',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -.4,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Assign, monitor, and manage employee tasks based on departments and client deliverables.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showAssigned = !_showAssigned),
                    icon: Icon(
                      _showAssigned ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: const Color(0xFF0052CC),
                    ),
                    label: Text(
                      _showAssigned ? 'New Assigned Tasks' : 'Assigned Tasks',
                      style: const TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      backgroundColor: const Color(0xFFF8FBFF),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _fetchAll,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF0052CC),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showTaskMasterDialog,
                    icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA500),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    label: const Text('Task Master', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  ElevatedButton.icon(
                    onPressed: loading ? null : _addRow,
                    icon: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    label: const Text('Add Section', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              );

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 14),
                    actionButtons,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 20),
                  actionButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _showAssigned ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _showAssigned
                    ? "Showing ${_visibleRows.length} assigned task(s)"
                    : "Showing ${_visibleRows.length} pending task(s) — assigned rows are hidden",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _showAssigned ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
       if (loading && taskRows.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: CircularProgressIndicator(color: Color(0xFF0052CC)),
              ),
            )
          else
            _buildResponsiveAssignmentTable(),

            

        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2050 ASSIGNMENT TABLE
  // • CLIENT NAME is frozen horizontally.
  // • Header stays fixed while rows scroll vertically.
  // • Header and body share one horizontal position.
  // • Left and right columns share one vertical position.
  // • Horizontal scrollbar is always visible at the bottom.
  // • Extra rows never get hidden; they are reached with the right scrollbar.
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildResponsiveAssignmentTable() {
    const double tableWidth = 3240.0;
    const double clientWidth = 200.0;
    const double headerHeight = 50.0;
    const double rowHeight = 60.0;
    const double rightWidth = tableWidth ;
    final double bodyHeight = MediaQuery.of(context).size.width < 700 ? 500.0 : 560.0;

    Widget clientColumn() => SizedBox(
      width: clientWidth,
      child: Column(children: [
        Container(
          width: clientWidth,
          height: headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(color: Color(0xFF0052CC), border: Border(right: BorderSide(color: Color(0xFF0044B3)))),
          child: const Row(children: [
            Icon(Icons.business_rounded, size: 15, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('CLIENT NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .6))),
          ]),
        ),
        SizedBox(
          height: bodyHeight,
          child: SingleChildScrollView(
            controller: _leftVerticalController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [
              ..._visibleRows.map((row) => SizedBox(height: rowHeight, child: _buildClientCell(row))),
              ...List.generate(4, (_) => SizedBox(width: 4400,height: rowHeight, child: _buildClientCell(null))),
            ]),
          ),
        ),
      ]),
    );

    Widget rightColumn() => SizedBox(
      width: rightWidth,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: rightWidth,
          height: headerHeight,
          child: Row(children: const [
            _HeaderCell(width: 200, label: 'DELIVERABLES'),
            _HeaderCell(width: 200, label: 'MAINTENANCE DATE'),
            _HeaderCell(width: 140, label: 'ADS HANDLER'),
            _HeaderCell(width: 160, label: 'ADS TASKS'),
            _HeaderCell(width: 140, label: 'PAGE HANDLER'),
            _HeaderCell(width: 160, label: 'PAGE TASKS'),
            _HeaderCell(width: 140, label: 'DESIGNER'),
            _HeaderCell(width: 160, label: 'DESIGN TASKS'),
            _HeaderCell(width: 140, label: 'VIDEOGRAPHER'),
            _HeaderCell(width: 160, label: 'VIDEO TASKS'),
            _HeaderCell(width: 140, label: 'VIDEO EDITOR'),
            _HeaderCell(width: 160, label: 'VIDEO EDIT TASKS'),
            _HeaderCell(width: 140, label: 'UI/UX DESIGNER'),
            _HeaderCell(width: 160, label: 'UI/UX TASKS'),
            _HeaderCell(width: 140, label: 'DEVELOPER'),
            _HeaderCell(width: 160, label: 'DEV TASKS'),
            _HeaderCell(width: 140, label: 'WEBSITE DESIGNER'),
            _HeaderCell(width: 160, label: 'WEBSITE DESIGNER TASKS'),
            _HeaderCell(width: 140, label: 'DEADLINE'),
            _HeaderCell(width: 160, label: 'COMMENTS'),
            _HeaderCell(width: 140, label: 'ACTION'),
          ]),
        ),
        Container(height: 1, width: rightWidth, color: const Color(0xFFE2E8F0)),
        SizedBox(
          height: bodyHeight,
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            thickness: 9,
            radius: const Radius.circular(10),
            scrollbarOrientation: ScrollbarOrientation.right,
            child: SingleChildScrollView(
              controller: _verticalController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                ..._visibleRows.map((row) => SizedBox(width: rightWidth, height: rowHeight, child: _buildDataRow(row))),
                ...List.generate(4, (_) => SizedBox(width: rightWidth, height: rowHeight, child: _buildEmptyRow())),
              ]),
            ),
          ),
        ),
      ]),
    );

    // A SINGLE horizontal ScrollView owns the right header + right body.
    // Client column is completely outside it, so CLIENT NAME stays fixed.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E2F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: headerHeight + bodyHeight,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            clientColumn(),
            Expanded(
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                thickness: 9,
                radius: const Radius.circular(10),
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: rightColumn(),
                ),
              ),
            ),
          ]),
        ),
        Container(
          height: 46,
          decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Row(children: [
            SizedBox(
              width: clientWidth,
              child: const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Row(children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF0052CC)),
                  SizedBox(width: 6),
                  Text('CLIENT FIXED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFF0052CC), letterSpacing: .4)),
                ]),
              ),
            ),
            const Expanded(child: Center(child: Text('←  Swipe / Shift + Mouse Wheel  →', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))))),
          ]),
        ),
      ]),
    );
  }

  // ✅ Client dropdown listing active company names properly
  Widget _buildClientCell(Map<String, dynamic>? row) {
    if (row == null) {
      return Container(
        height: 54,
        decoration: const BoxDecoration(
          color: Color(0xFF0052CC),
          border: Border(bottom: BorderSide(color: Color(0xFF0044B3))),
        ),
      );
    }
   
    String currentClient = row['client_name'] ?? '';
    if (currentClient == 'PENDING_SELECTION') {
      currentClient = '';
    }
   
    if (currentClient.isNotEmpty && !clients.contains(currentClient)) {
      currentClient = '';
    }
   
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0052CC),
        border: Border(bottom: BorderSide(color: Color(0xFF0044B3))),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentClient.isEmpty ? null : currentClient,
          isExpanded: true,
          hint: const Text(
            '— Select client name —',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          dropdownColor: const Color(0xFF1A5FCC),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('— Select client name —', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
            ),
            ...clients.map((c) => DropdownMenuItem(value: c, child: Text(c))),
          ],
          onChanged: (val) async {
            if (val != null && val != currentClient) {
              setState(() => row['client_name'] = val);
              await _saveRow(row);
            }
          },
        ),
      ),
    );
  }

  // ✅ Deliverables Dropdown mapping to Packages and auto-filling tasks
  Widget _buildDeliverablesCell(double width, Map<String, dynamic> row) {
    String currentPkg = row['deliverables'] ?? '';
    List<String> packageTitles = packagesList.map((p) => (p['title'] ?? '').toString()).toList();

    if (currentPkg.isNotEmpty && !packageTitles.contains(currentPkg)) {
      currentPkg = '';
    }

    return Container(
      width: width,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentPkg.isEmpty ? null : currentPkg,
          isExpanded: true,
          hint: const Text('— Select Package —', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
          items: packageTitles.map((title) => DropdownMenuItem(value: title, child: Text(title, style: const TextStyle(fontSize: 10)))).toList(),
          onChanged: (val) async {
            if (val != null) {
              await _onPackageSelected(row, val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> row) {
    final bool assigned = row['is_assigned'] == 1 || row['is_assigned'] == true;
   
    const noneMarker = 'NONE';
    final empItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        enabled: false,
        child: Text('— Select —', style: TextStyle(color: Color(0xFFCBD5E1))),
      ),
      const DropdownMenuItem(
        value: noneMarker,
        child: Text('None (Not Assigned)', style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
      ),
      ...employees.map((e) => DropdownMenuItem(value: e, child: Text(e))),
    ];

    String empVal(String key) {
      final raw = (row[key] ?? '').toString();
      if (raw.isEmpty) return '';
      final upper = raw.toUpperCase();
      if (upper == noneMarker) return noneMarker;
      return employees.contains(upper) ? upper : '';
    }
    // 🟢 Date string-la irunthu day number mattum (e.g., "24") extract panra function
  String _formatOnlyDay(dynamic rawDate) {
    if (rawDate == null || rawDate.toString().trim().isEmpty) return '—';
    final val = rawDate.toString().trim();
    
    // If format is DD/MM/YYYY
    if (val.contains('/')) {
      final parts = val.split('/');
      if (parts.isNotEmpty) {
        return parts[0]; // Day part mattum return aagum (e.g., "24")
      }
    }
    
    // If format is ISO or something else, try parsing
    try {
      final parsed = DateTime.parse(val);
      return parsed.day.toString().padLeft(2, '0');
    } catch (_) {
      return val;
    }
  }

    Widget taskCell(double width, String roleKey, String dbFieldKey) {
      return GestureDetector(
        onTap: () => _showTaskSelectionPopup(roleKey: roleKey, row: row, dbFieldKey: dbFieldKey),
        child: Container(
          width: width,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Row(children: [
            Expanded(
              child: Text(
                row[dbFieldKey]?.toString().isEmpty ?? true ? '—' : row[dbFieldKey].toString(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: (row[dbFieldKey]?.toString().isEmpty ?? true) ? FontWeight.normal : FontWeight.w600,
                  color: (row[dbFieldKey]?.toString().isEmpty ?? true) ? const Color(0xFFCBD5E1) : const Color(0xFF1D4ED8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
          ]),
        ),
      );
    }

    return Row(
      children: [
        _buildDeliverablesCell(200, row), // ✅ Interactive deliverables package dropdown
        // SizedBox(
        //   width: 200,
        //   height: 54,
        //   child: GestureDetector(
        //     onTap: () => _pickDate(row, 'maintenance_date'),
        //     child: Container(
        //       padding: const EdgeInsets.symmetric(horizontal: 10),
        //       decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
        //       alignment: Alignment.centerLeft,
        //       child: Row(
        //         children: [
        //           Expanded(
        //             child: Text(
        //               row['maintenance_date']?.toString().isEmpty ?? true ? '—' : row['maintenance_date'].toString(),
        //               style: TextStyle(
        //                 fontSize: 11,
        //                 fontWeight: (row['maintenance_date']?.toString().isEmpty ?? true) ? FontWeight.normal : FontWeight.w600,
        //                 color: (row['maintenance_date']?.toString().isEmpty ?? true) ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        //               ),
        //             ),
        //           ),
        //           const SizedBox(width: 8),
        //           Icon(Icons.calendar_today, size: 14, color: (row['maintenance_date']?.toString().isEmpty ?? true) ? const Color(0xFFCBD5E1) : const Color(0xFF0052CC)),
        //         ],
        //       ),
        //     ),
        //   ),
        // ),
       
       SizedBox(
          width: 200,
          height: 54,
          child: GestureDetector(
            onTap: () => _pickDate(row, 'maintenance_date'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      // 🟢 Day (Date) mattum eduthu kaattum (e.g. "24")
                      _formatOnlyDay(row['maintenance_date']),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (row['maintenance_date']?.toString().isEmpty ?? true) ? FontWeight.normal : FontWeight.w600,
                        color: (row['maintenance_date']?.toString().isEmpty ?? true) ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today, size: 14, color: (row['maintenance_date']?.toString().isEmpty ?? true) ? const Color(0xFFCBD5E1) : const Color(0xFF0052CC)),
                ],
              ),
            ),
          ),
        ),
       
        SizedBox(width: 140, child: _empDropCell(140, empVal('ads_handling'), empItems, onChanged: (v) { setState(() => row['ads_handling'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'ads_handler_task', 'ads_platform')),
        // SizedBox(width: 140, child: _dateCell(140, 'ads_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('page_handling'), empItems, onChanged: (v) { setState(() => row['page_handling'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'page_handler_task', 'pages_platform')),
        // SizedBox(width: 140, child: _dateCell(140, 'page_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('designer'), empItems, onChanged: (v) { setState(() => row['designer'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'graphic_designer_task', 'designer_tasks')),
        // SizedBox(width: 140, child: _dateCell(140, 'designer_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('videographer'), empItems, onChanged: (v) { setState(() => row['videographer'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'videographer_task', 'videographer_tasks')),
        // SizedBox(width: 140, child: _dateCell(140, 'videographer_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('video_editor'), empItems, onChanged: (v) { setState(() => row['video_editor'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'video_editor_task', 'video_editor_task')),
        // SizedBox(width: 140, child: _dateCell(140, 'video_editor_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('ui_ux_designer'), empItems, onChanged: (v) { setState(() => row['ui_ux_designer'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'ui_ux_designer_task', 'ui_ux_tasks')),
        // SizedBox(width: 140, child: _dateCell(140, 'ui_ux_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('developer'), empItems, onChanged: (v) { setState(() => row['developer'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'developer_task', 'developer_tasks')),
        // SizedBox(width: 140, child: _dateCell(140, 'developer_submit_date', row)),
        SizedBox(
  width: 140,
  child: _empDropCell(
    140,
    empVal('website_designer'),
    empItems,
    onChanged: (v) {
      setState(() {
        row['website_designer'] = v;
      });
      _saveRow(row);
    },
  ),
),

SizedBox(
  width: 160,
  child: taskCell(
    160,
    'website_designer_task',
    'website_designer_tasks',
  ),
),

// SizedBox(
//   width: 140,
//   child: _dateCell(
//     140,
//     'website_designer_submit_date',
//     row,
//   ),
// ),
        SizedBox(width: 140, child: _deadlineCell(140, row)),
        SizedBox(width: 160, child: _commentCell(160, row)),
        SizedBox(width: 140, child: _actionCell(140, row, assigned)),
      ],
    );
  }

  Widget _dateCell(double width, String key, Map<String, dynamic> row) {
    final value = row[key] ?? '';
    return GestureDetector(
      onTap: () => _pickDate(row, key),
      child: Container(
        width: width,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(child: Text(formatDisplayDate(value), style: TextStyle(fontSize: 11, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today, size: 14, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0052CC)),
          ],
        ),
      ),
    );
  }

  Widget _deadlineCell(double width, Map<String, dynamic> row) {
    final value = row['deadline'] ?? '';
    return GestureDetector(
      onTap: () => _pickDate(row, 'deadline'),
      child: Container(
        width: width,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(child: Text(value.isEmpty ? '—' : value, style: TextStyle(fontSize: 11, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today, size: 14, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0052CC)),
          ],
        ),
      ),
    );
  }

  Widget _commentCell(double width, Map<String, dynamic> row) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Center(
        child: SizedBox(
          height: 32,
          child: TextField(
            controller: TextEditingController(text: row['comments'] ?? ''),
            style: const TextStyle(fontSize: 10),
            onSubmitted: (v) { row['comments'] = v; _saveRow(row); },
          ),
        ),
      ),
    );
  }

  // Widget _actionCell(double width, Map<String, dynamic> row, bool assigned) {
  //   return Container(
  //     width: width,
  //     padding: const EdgeInsets.symmetric(horizontal: 8),
  //     child: Row(
  //       children: [
  //         if (!assigned) ...[
  //           Expanded(
  //             child: SizedBox(
  //               height: 32,
  //               child: ElevatedButton(
  //                 onPressed: () => _toggleAssign(row),
  //                 style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), padding: EdgeInsets.zero),
  //                 child: const FittedBox(child: Text("ASSIGN", style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900))),
  //               ),
  //             ),
  //           ),
  //           const SizedBox(width: 4),
  //         ],
  //         GestureDetector(
  //           onTap: () => _deleteRow(row['id']),
  //           child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.delete_outline, size: 12, color: Color(0xFFDC2626))),
  //         ),
  //       ],
  //     ),
  //   );
  // }


Widget _actionCell(double width, Map<String, dynamic> row, bool assigned) {
    // 🟢 Deadline complete aayirukka (expired-ah) nu check panrathu
    bool isDeadlinePassed = false;
    if (row['deadline'] != null && row['deadline'].toString().trim().isNotEmpty) {
      try {
        DateTime deadlineDate = DateTime.parse(row['deadline'].toString());
        if (deadlineDate.isBefore(DateTime.now())) {
          isDeadlinePassed = true;
        }
      } catch (_) {}
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          if (!assigned) ...[
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _toggleAssign(row),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC), padding: EdgeInsets.zero),
                  child: const FittedBox(child: Text("ASSIGN", style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900))),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ] else if (assigned && isDeadlinePassed) ...[
            // 🟢 Assigned aagi, DEADLINE DATE COMPLETE AANATHU MATTUM "NEXT CYCLE" button show aagum
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () async {
  final res = await http.post(Uri.parse('$_baseUrl/tasks/${row['id']}/duplicate-next-month'));
  if (res.statusCode == 200 || res.statusCode == 201) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ New task successfully added for next cycle!'), backgroundColor: Colors.green)
    );
    await _fetchTasks(); // 🟢 Table data-va fresh-ah backend-il irunthu eduthu state-ai update seiyum
    setState(() {}); // 🟢 Screen-ai re-render seiyum
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Failed: ${res.body}'), backgroundColor: Colors.red)
    );
  }
},
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: EdgeInsets.zero),
                  child: const FittedBox(child: Text("NEXT CYCLE", style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w900))),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          GestureDetector(
            onTap: () => _deleteRow(row['id']),
            child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.delete_outline, size: 12, color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2050 EMPLOYEE PICKER
  // Native DropdownButton overlays are easy to clip inside a wide table. This
  // picker opens a responsive dialog instead, so it works cleanly on desktop,
  // tablet and mobile and provides search + clear visual selection.
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _showEmployeePicker({
    required String current,
    required ValueChanged<String> onChanged,
  }) async {
    final searchController = TextEditingController();
    String query = '';

    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final all = <String>['NONE', ...employees.where((e) => e.trim().isNotEmpty)];
            final filtered = all.where((name) {
              if (query.trim().isEmpty) return true;
              return name.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430, maxHeight: 650),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0052CC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_search_rounded, color: Colors.white, size: 21),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Select Employee', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                                SizedBox(height: 3),
                                Text('Choose who should handle this role', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (value) => setDialogState(() => query = value),
                        decoration: InputDecoration(
                          hintText: 'Search employee...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() => query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded, size: 17),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0052CC), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_off_outlined, size: 32, color: Color(0xFFCBD5E1)),
                                  SizedBox(height: 8),
                                  Text('No employee found', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 2, 12, 14),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 5),
                              itemBuilder: (_, index) {
                                final name = filtered[index];
                                final isNone = name == 'NONE';
                                final selected = current.toUpperCase() == name.toUpperCase();

                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.pop(dialogContext, name),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFFEFF6FF)
                                          : isNone
                                              ? const Color(0xFFF8FAFC)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: isNone ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(11),
                                          ),
                                          child: Icon(
                                            isNone ? Icons.person_off_outlined : Icons.person_outline_rounded,
                                            size: 19,
                                            color: isNone ? const Color(0xFF64748B) : const Color(0xFF0052CC),
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isNone ? 'None (Not Assigned)' : name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  fontStyle: isNone ? FontStyle.italic : FontStyle.normal,
                                                  color: isNone ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                isNone ? 'Leave this role unassigned' : 'Available employee',
                                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (selected)
                                          const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF0052CC)),
                                        const SizedBox(width: 3),
                                        if (!selected)
                                          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 13),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 15, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text('Tap an employee to assign this role.', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, 'NONE'),
                            child: const Text('Clear', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
    if (result != null) onChanged(result);
  }

  Widget _empDropCell(
    double width,
    String current,
    List<DropdownMenuItem<String>> items, {
    required ValueChanged<String> onChanged,
  }) {
    final isUnselected = current.isEmpty || current.toUpperCase() == 'NONE';
    final display = current.isEmpty || current.toUpperCase() == 'NONE' ? '— Select —' : current;

    return InkWell(
      onTap: () => _showEmployeePicker(current: current, onChanged: onChanged),
      child: Container(
        width: width,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: isUnselected ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
          border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: isUnselected ? const Color(0xFFFFFBEB) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUnselected ? const Color(0xFFFCD34D) : const Color(0xFFDCE5F0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isUnselected ? Icons.person_add_alt_1_rounded : Icons.person_rounded,
                size: 15,
                color: isUnselected ? const Color(0xFFD97706) : const Color(0xFF0052CC),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isUnselected ? const Color(0xFFB45309) : const Color(0xFF0052CC),
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRow() {
    const widths = [200, 200, 140, 160, 140, 160, 140, 160, 140, 160, 140, 160, 140, 160, 140, 160, 140, 160, 140, 160, 140];
    return Row(children: widths.map((w) => SizedBox(width: w.toDouble(), height: 54, child: Container(decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0))))))).toList());
  }
}

class _HeaderCell extends StatelessWidget {
  final double? width;
  final String label;

  const _HeaderCell({
    this.width,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,

      // 🔵 HEADER BACKGROUND
      decoration: const BoxDecoration(
        color: Color(0xFF0052CC),
        border: Border(
          right: BorderSide(
            color: Color(0xFF0044B3),
            width: 1,
          ),
        ),
      ),

      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (width != null) {
      return SizedBox(
        width: width,
        height: 50,
        child: child,
      );
    }

    return Expanded(
      child: SizedBox(
        height: 50,
        child: child,
      ),
    );
  }
}
