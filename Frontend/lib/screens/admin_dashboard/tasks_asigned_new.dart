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

  final ScrollController _horizontalController = ScrollController();

  List<Map<String, dynamic>> taskRows = [];
  List<String> employees = [];
  List<String> clients = [];
  List<Map<String, dynamic>> taskMaster = [];
  List<Map<String, dynamic>> packagesList = [];
  bool _loadingPackages = true;

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
    _fetchTaskRoles();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchEmployees(),
      _fetchActiveClients(), 
      _fetchPackagesData(),  
      _fetchTaskMaster(),
      _fetchTasks(),
    ]);
  }

  // ✅ FIXED: Fetch active clients from /api/clients and filter company_name where is_active == 1
  Future<void> _fetchActiveClients() async {
    setState(() => _loadingClients = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/clients'));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final data = List<Map<String, dynamic>>.from(body['data'] ?? []);
        setState(() {
          clients = data
              .where((c) => c['is_active'] == 1 || c['is_active'] == true)
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
  Future<void> _showTaskMasterDialog() async {
    // Create controllers ONCE for the entire dialog lifecycle
    final roleController = TextEditingController();
    final taskController = TextEditingController();
 

    String newRoleName = '';
    String selectedRole = taskRoles.entries.isNotEmpty
        ? taskRoles.entries.first.key
        : '';
    String taskName = '';
    bool isEditing = false;
    int? editingTaskId;

    // Fetch fresh roles from backend when dialog opens
    await _fetchTaskRoles();

    await showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0052CC),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Task Master Manager',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══════════════════════════════════════════════════════
                          // SECTION 1: ADD NEW TASK ROLE
                          // ═══════════════════════════════════════════════════════
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              border: Border.all(color: const Color(0xFFFFD700)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '📌 Create New Task Role',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Role Name:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: roleController,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      newRoleName = val;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'e.g., Content Creator Task, SEO Specialist Task',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        newRoleName.isEmpty
                                            ? '(Role key will auto-generate in snake_case)'
                                            : '(Key: ${_toSnakeCase(newRoleName)})',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF64748B),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      onPressed: newRoleName.trim().isEmpty
                                          ? null
                                          : () async {
                                              final roleKey = _toSnakeCase(newRoleName);
                                              final roleName = newRoleName;

                                              // Save to backend
                                              final success = await _addNewRoleToBackend(roleName, roleKey);

                                              if (success) {
                                                // Clear input after successful save
                                                setDialogState(() {
                                                  roleController.clear();
                                                  newRoleName = '';
                                                  selectedRole = roleKey;
                                                });

                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('✅ Role "$roleName" created!'),
                                                      backgroundColor: Colors.green,
                                                      duration: const Duration(seconds: 2),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      icon: const Icon(Icons.add, size: 16),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: newRoleName.trim().isEmpty ? Colors.grey : const Color(0xFFFFA500),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      label: const Text('Add New Role',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 16),

                          // ═══════════════════════════════════════════════════════
                          // SECTION 2: ADD TASK TO ROLE
                          // ═══════════════════════════════════════════════════════
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '✏️ Manage Tasks for Role',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text('Select Task Role:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: taskRoles.containsKey(selectedRole) ? selectedRole : (taskRoles.isNotEmpty ? taskRoles.entries.first.key : null),
                                      isExpanded: true,
                                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
                                      items: taskRoles.entries
                                          .map((e) => DropdownMenuItem(
                                              value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 11))))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() {
                                            selectedRole = val;
                                            taskController.clear();
                                            taskName = '';
                                            isEditing = false;
                                            editingTaskId = null;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text('Task Name:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: taskController,
                                  onChanged: (val) {
                                    setDialogState(() => taskName = val);
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Enter task name (e.g., Poster, Video, Reels)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 14),
                                const Text('Existing Tasks:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.white,
                                  ),
                                  child: getTasksForRole(selectedRole).isEmpty
                                      ? Center(
                                          child: Text(
                                            'No tasks yet. Add one above! ⬆️',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                        )
                                      : ListView(
                                          children: getTasksForRole(selectedRole).map((task) {
                                            return ListTile(
                                              dense: true,
                                              title: Text(task['task_name'] ?? '',
                                                  style: const TextStyle(fontSize: 11)),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 14, color: Color(0xFF0052CC)),
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        taskName = task['task_name'] ?? '';
                                                        taskController.text = taskName;
                                                        isEditing = true;
                                                        editingTaskId = task['id'];
                                                      });
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, size: 14, color: Color(0xFFDC2626)),
                                                    onPressed: () async {
                                                      await _deleteTask(task['id']);
                                                      await _fetchTaskMaster();
                                                      setDialogState(() {
                                                        taskController.clear();
                                                        taskName = '';
                                                        isEditing = false;
                                                        editingTaskId = null;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
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

                // Footer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          roleController.dispose();
                          taskController.dispose();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: taskName.trim().isEmpty
                            ? null
                            : () async {
                                if (isEditing) {
                                  await _updateTask(editingTaskId!, taskName, selectedRole);
                                } else {
                                  await _addNewTask(taskName, selectedRole);
                                }

                                // Refresh tasks immediately
                                await _fetchTaskMaster();

                                // Clear input and update dialog state
                                setDialogState(() {
                                  taskController.clear();
                                  taskName = '';
                                  isEditing = false;
                                  editingTaskId = null;
                                });

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEditing ? '✅ Task updated!' : '✅ Task added!'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: taskName.trim().isEmpty ? Colors.grey : const Color(0xFF0052CC),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(isEditing ? 'Update' : 'Add Task',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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

    // Dispose controllers when dialog closes
    roleController.dispose();
    taskController.dispose();
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
          'adsSubmitDate': row['ads_submit_date'] ?? '',
          
          // Page Handler fields
          'pageHandling': _cleanRoleValue(row['page_handling']),
          'pagesPlatform': row['pages_platform'] ?? '',
          'pageSubmitDate': row['page_submit_date'] ?? '',
          
          // Designer fields
          'designer': _cleanRoleValue(row['designer']),
          'designerTasks': row['designer_tasks'] ?? '',
          'designerSubmitDate': row['designer_submit_date'] ?? '',
          
          // Videographer fields
          'videographer': _cleanRoleValue(row['videographer']),
          'videographerTasks': row['videographer_tasks'] ?? '',
          'videographerSubmitDate': row['videographer_submit_date'] ?? '',
          
          // Video Editor fields
          'videoEditor': _cleanRoleValue(row['video_editor']),
          'videoEditorTask': row['video_editor_task'] ?? '',
          'videoEditorSubmitDate': row['video_editor_submit_date'] ?? '',
          
          // UI/UX Designer fields
          'uiUxDesigner': _cleanRoleValue(row['ui_ux_designer']),
          'uiUxTasks': row['ui_ux_tasks'] ?? '',
          'uiUxSubmitDate': row['ui_ux_submit_date'] ?? '',
          
          // Developer fields
          'developer': _cleanRoleValue(row['developer']),
          'developerTasks': row['developer_tasks'] ?? '',
          'developerSubmitDate': row['developer_submit_date'] ?? '',
          
          // Website Designer fields
          'websiteDesigner':_cleanRoleValue(row['website_designer']),
          'websiteDesignerTasks':row['website_designer_tasks'] ?? '',
          'websiteDesignerSubmitDate':row['website_designer_submit_date'] ?? '',
          
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

  @override
  Widget build(BuildContext context) {
    final bool loading = _loadingTasks || _loadingEmployees || _loadingClients || _loadingPackages || _loadingTaskMaster || _loadingRoles;

    // final visibleRows = taskRows.where((r) {
    //   final assigned = r['is_assigned'] == 1 || r['is_assigned'] == true;
    //   if (_showAssigned != assigned) return false;
    //   if (_searchQuery.trim().isEmpty) return true;
    //   final query = _searchQuery.trim().toLowerCase();
    //   final clientName = (r['client_name'] ?? '').toString().toLowerCase();
    //   return clientName.contains(query);
    // }).toList();
    final visibleRows = taskRows.where((r) {
      final assigned = r['is_assigned'] == 1 || r['is_assigned'] == true;
      if (_showAssigned != assigned) return false;
      if (_searchQuery.trim().isEmpty) return true;
      
      final query = _searchQuery.trim().toLowerCase();
      
      // 🔍 Client Name check
      final clientName = (r['client_name'] ?? '').toString().toLowerCase();
      if (clientName.contains(query)) return true;

      // 🔍 Employee Names check across all role columns
      final roleFields = [
        'ads_handling',
        'page_handling',
        'designer',
        'videographer',
        'video_editor',
        'ui_ux_designer',
        'developer',
        'website_designer'
      ];

      for (final field in roleFields) {
        final empValue = (r[field] ?? '').toString().toLowerCase();
        if (empValue.contains(query)) return true;
      }

      return false;
    }).toList();

    return AdminLayout(
      pageTitle: "Tasks Assign",
      currentRoute: "/tasks",
      onSearch: (query) => setState(() => _searchQuery = query),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text("Task Assign - Employees", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                SizedBox(height: 4),
                Text("Assign, monitor, and manage employee tasks based on departments and client deliverables.", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ]),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAssigned = !_showAssigned),
                  icon: Icon(_showAssigned ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded, size: 16, color: const Color(0xFF0052CC)),
                  label: Text(_showAssigned ? "Show Pending" : "Show Assigned", style: const TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF0052CC))),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _fetchAll, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0052CC))),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: _showTaskMasterDialog,
                  icon: const Icon(Icons.settings, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA500)),
                  label: const Text("Task Master", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: loading ? null : _addRow,
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                  label: const Text("Add Section", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
            ],
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
                    ? "Showing ${visibleRows.length} assigned task(s)"
                    : "Showing ${visibleRows.length} pending task(s) — assigned rows are hidden",
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
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 60), child: CircularProgressIndicator(color: Color(0xFF0052CC))))
          else
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Scrollbar(
                controller: _horizontalController, 
                thumbVisibility: true,
                trackVisibility: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch, 
                        children: [
                          Container(
                            height: 48,
                            color: const Color(0xFF0052CC),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            child: const Text("CLIENT NAME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                          ),
                          ...visibleRows.map((row) => _buildClientCell(row)),
                          ...List.generate(4, (_) => _buildClientCell(null)),
                        ]
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _horizontalController, 
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 4400,
                              height: 48,
                              child: Row(children: const [
                                 _HeaderCell(width: 200, label: "DELIVERABLES"),
                                 _HeaderCell(width: 200, label: "MAINTENANCE DATE"),
                                 _HeaderCell(width: 140, label: "ADS HANDLER"),
                                 _HeaderCell(width: 160, label: "ADS TASKS"),
                                 _HeaderCell(width: 140, label: "ADS DATE"),
                                 _HeaderCell(width: 140, label: "PAGE HANDLER"),
                                 _HeaderCell(width: 160, label: "PAGE TASKS"),
                                 _HeaderCell(width: 140, label: "PAGE DATE"),
                                 _HeaderCell(width: 140, label: "DESIGNER"),
                                 _HeaderCell(width: 160, label: "DESIGN TASKS"),
                                 _HeaderCell(width: 140, label: "DESIGN DATE"),
                                 _HeaderCell(width: 140, label: "VIDEOGRAPHER"),
                                 _HeaderCell(width: 160, label: "VIDEO TASKS"),
                                 _HeaderCell(width: 140, label: "VIDEO DATE"),
                                 _HeaderCell(width: 140, label: "VIDEO EDITOR"),
                                 _HeaderCell(width: 160, label: "VIDEO EDIT TASKS"),
                                 _HeaderCell(width: 140, label: "VIDEO EDIT DATE"),
                                 _HeaderCell(width: 140, label: "UI/UX DESIGNER"),
                                 _HeaderCell(width: 160, label: "UI/UX TASKS"),
                                 _HeaderCell(width: 140, label: "UI/UX DATE"),
                                 _HeaderCell(width: 140, label: "DEVELOPER"),
                                 _HeaderCell(width: 160, label: "DEV TASKS"),
                                 _HeaderCell(width: 140, label: "DEV DATE"),
                                 _HeaderCell(width: 140,label: "WEBSITE DESIGNER",),
                                 _HeaderCell(width: 160,label: "WEBSITE DESIGNER TASKS",),
                                 _HeaderCell(width: 140,label: "WEBSITE DESIGNER DATE",),
                                 _HeaderCell(width: 140, label: "DEADLINE"),
                                 _HeaderCell(width: 160, label: "COMMENTS"),
                                 _HeaderCell(width: 140, label: "ACTION"),
                              ]),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            ...visibleRows.map((row) => SizedBox(width: 4400, child: _buildDataRow(row))),
                            ...List.generate(4, (_) => SizedBox(width: 4400, child: _buildEmptyRow())),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
                      row['maintenance_date']?.toString().isEmpty ?? true ? '—' : row['maintenance_date'].toString(),
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
        SizedBox(width: 140, child: _dateCell(140, 'ads_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('page_handling'), empItems, onChanged: (v) { setState(() => row['page_handling'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'page_handler_task', 'pages_platform')),
        SizedBox(width: 140, child: _dateCell(140, 'page_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('designer'), empItems, onChanged: (v) { setState(() => row['designer'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'graphic_designer_task', 'designer_tasks')),
        SizedBox(width: 140, child: _dateCell(140, 'designer_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('videographer'), empItems, onChanged: (v) { setState(() => row['videographer'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'videographer_task', 'videographer_tasks')),
        SizedBox(width: 140, child: _dateCell(140, 'videographer_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('video_editor'), empItems, onChanged: (v) { setState(() => row['video_editor'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'video_editor_task', 'video_editor_task')),
        SizedBox(width: 140, child: _dateCell(140, 'video_editor_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('ui_ux_designer'), empItems, onChanged: (v) { setState(() => row['ui_ux_designer'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'ui_ux_designer_task', 'ui_ux_tasks')),
        SizedBox(width: 140, child: _dateCell(140, 'ui_ux_submit_date', row)),
        SizedBox(width: 140, child: _empDropCell(140, empVal('developer'), empItems, onChanged: (v) { setState(() => row['developer'] = v); _saveRow(row); })),
        SizedBox(width: 160, child: taskCell(160, 'developer_task', 'developer_tasks')),
        SizedBox(width: 140, child: _dateCell(140, 'developer_submit_date', row)),
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

SizedBox(
  width: 140,
  child: _dateCell(
    140,
    'website_designer_submit_date',
    row,
  ),
),
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

  Widget _actionCell(double width, Map<String, dynamic> row, bool assigned) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
          ],
          GestureDetector(
            onTap: () => _deleteRow(row['id']),
            child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.delete_outline, size: 12, color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
  }

  Widget _empDropCell(double width, String current, List<DropdownMenuItem<String>> items, {required ValueChanged<String> onChanged}) {
    final bool isUnselected = current.isEmpty;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))), color: isUnselected ? const Color(0xFFFFF7ED) : null),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current.isEmpty ? '' : current,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0052CC)),
          items: items,
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _buildEmptyRow() {
    const widths = [200, 200, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140];
    return Row(children: widths.map((w) => SizedBox(width: w.toDouble(), height: 54, child: Container(decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0))))))).toList());
  }
}

class _HeaderCell extends StatelessWidget {
  final double? width;
  final String label;
  const _HeaderCell({this.width, required this.label});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
      alignment: Alignment.centerLeft,
      child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3), maxLines: 2, overflow: TextOverflow.ellipsis),
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(child: child);
  }
}