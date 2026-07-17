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


class TasksAssignScreen extends StatefulWidget {
  const TasksAssignScreen({super.key});

  @override
  State<TasksAssignScreen> createState() => _TasksAssignScreenState();
}


class _TasksAssignScreenState extends State<TasksAssignScreen> {
  // static const String _baseUrl = '/api';
  static String get _baseUrl => ApiConfig.baseUrl;

  final ScrollController _horizontalController = ScrollController();


  List<Map<String, dynamic>> taskRows = [];
  List<String> employees = [];
  List<String> clients = [];
  List<Map<String, dynamic>> taskMaster = [];

  // Task roles mapping
  Map<String, String> taskRoles = {};
  bool _loadingRoles = true;

  bool _showAssigned = false;
  bool _loadingTasks = true;
  bool _loadingEmployees = true;
  bool _loadingClients = true;
  bool _loadingTaskMaster = true;
  String? _error;
  String? _adminName;

  // ── CONVERT TEXT TO SNAKE_CASE ───────────────────────────────────────────
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
      _fetchClientsFromInvoices(),
      _fetchTaskMaster(),
      _fetchTasks(),
    ]);
  }

  // ── FETCH TASK ROLES FROM BACKEND ──────────────────────────────────────
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
        debugPrint('✅ Loaded ${taskRoles.length} roles from backend');
      } else {
        setState(() => _loadingRoles = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching roles: $e');
      setState(() => _loadingRoles = false);
    }
  }

  // ── ADD NEW ROLE TO BACKEND ──────────────────────────────────────────────
  Future<bool> _addNewRoleToBackend(String roleName, String roleKey) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/task-roles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role_name': roleName,
          'role_key': roleKey,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Role saved successfully');
        // Refresh roles from backend to sync
        await _fetchTaskRoles();
        return true;
      }

      // Duplicate role or other backend message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['message'] ?? 'Failed to create role'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error saving role: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }

  // ── FETCH CLIENTS FROM INVOICES TABLE ──────────────────────────────────
  Future<void> _fetchClientsFromInvoices() async {
  setState(() => _loadingClients = true);
  try {
    final r = await http.get(Uri.parse('$_baseUrl/invoices'));
    if (r.statusCode == 200) {
      final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
      
      // ✅ NEW: Get current month and year
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;
      
      final uniqueClients = <String>{};
      
      for (var invoice in data) {
        // ✅ NEW: Parse invoice date and check if it's from current month
        final invoiceDate = invoice['invoice_date']?.toString() ?? '';
        
        if (invoiceDate.isNotEmpty) {
          try {
            // Parse date in format dd/MM/yyyy
            final dateParts = invoiceDate.split('/');
            if (dateParts.length == 3) {
              final day = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);
              
              // ✅ NEW: Only include clients with invoices from current month
              if (month == currentMonth && year == currentYear) {
                final clientName = invoice['client_name']?.toString() ?? '';
                if (clientName.isNotEmpty) {
                  uniqueClients.add(clientName);
                }
              }
            }
          } catch (e) {
            debugPrint('Error parsing date: $invoiceDate - $e');
          }
        }
      }
      
      setState(() {
        clients = uniqueClients.toList();
        _loadingClients = false;
      });
      
      debugPrint('✅ Loaded ${clients.length} unique clients from CURRENT MONTH invoices');
    } else {
      setState(() => _loadingClients = false);
    }
  } catch (e) {
    debugPrint('❌ Error fetching clients: $e');
    setState(() => _loadingClients = false);
  }
}

  // ── FETCH TASK MASTER (Task roles and their tasks) ──────────────────────
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
        debugPrint('✅ Loaded ${taskMaster.length} tasks from task master');
      } else {
        setState(() => _loadingTaskMaster = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching task master: $e');
      setState(() => _loadingTaskMaster = false);
    }
  }

  // ── GET TASKS FOR A SPECIFIC ROLE ──────────────────────────────────────
  List<Map<String, dynamic>> getTasksForRole(String roleKey) {
    return taskMaster.where((task) => task['role_key'] == roleKey).toList();
  }

  // ── LOAD CLIENT DATA FROM INVOICES ──────────────────────────────────────
  Future<void> _loadClientInvoiceData(Map<String, dynamic> row) async {
    try {
      final clientName = row['client_name'];
      if (clientName == null || clientName.isEmpty) return;

      debugPrint('👤 Client selected: $clientName');
      debugPrint('📥 Fetching invoice data for client: $clientName');

      final response = await http.get(
        Uri.parse('$_baseUrl/invoices/client-details/$clientName'),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] ?? jsonData;

        final packages = (data['packages'] ?? data['deliverables'] ?? '').toString();
        final maintenanceDate = (data['maintenance_date'] ?? data['maintenanceDate'] ?? '').toString();

        debugPrint('✅ Invoice Data Received:');
        debugPrint('   Packages: $packages');
        debugPrint('   Maintenance Date: $maintenanceDate');

        setState(() {
          row['deliverables'] = packages;
          row['maintenance_date'] = maintenanceDate;
          debugPrint('🔄 State updated - row data refreshed');
        });

        await _saveRow(row);
        debugPrint('💾 Data saved to database');
      } else {
        debugPrint('❌ Error: Server returned ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch client details: ${response.statusCode}')),
          );
        }
      }
    } on TimeoutException {
      debugPrint('❌ Request timeout');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timeout. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _fetchEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final r = await http.get(Uri.parse('$_baseUrl/employees'));
      if (r.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(r.body)['data']);
        setState(() {
          employees = data.map((e) => (e['full_name'] ?? '').toString().toUpperCase()).toList();
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
    // ✅ FIXED: Send a placeholder value that backend accepts
    final r = await http.post(
      Uri.parse('$_baseUrl/tasks'),
      headers: {'Content-Type': 'application/json'},
      // ✅ Send "PENDING_SELECTION" instead of empty string
      body: jsonEncode({'clientName': 'PENDING_SELECTION'}),
    );
    
    debugPrint('📡 Add Row Response: ${r.statusCode} - ${r.body}');
 
    if (r.statusCode == 201 || r.statusCode == 200) {
      await _fetchTasks(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ New section added. Select a client name to begin.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add section: ${r.body}')),
        );
      }
    }
  } catch (e) {
    debugPrint('❌ Error in _addRow: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

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

    await showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
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
                      Text(taskRoles[roleKey] ?? roleKey,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Task List
                Expanded(
                  child: ListView.builder(
                    itemCount: availableTasks.length,
                    itemBuilder: (context, index) {
                      final task = availableTasks[index];
                      final taskId = task['id'];
                      final isSelected = selectedTasks.any((t) => t['id'] == taskId);

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
                                    selectedTasks.add({'id': taskId, 'name': task['task_name'], 'count': 1});
                                  } else {
                                    selectedTasks.removeWhere((t) => t['id'] == taskId);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Text(task['task_name'] ?? '',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            ),
                            if (isSelected)
                              Container(
                                width: 60,
                                height: 32,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    hintText: '1',
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                  onChanged: (val) {
                                    final idx = selectedTasks.indexWhere((t) => t['id'] == taskId);
                                    if (idx != -1) {
                                      setDialogState(() {
                                        selectedTasks[idx]['count'] = int.tryParse(val) ?? 1;
                                      });
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

                // Footer
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
                          // Format selected tasks as string
                          final taskString = selectedTasks.map((t) => '${t['name']} (${t['count']})').join(', ');

                          setState(() {
                            row[dbFieldKey] = taskString;
                          });
                          _saveRow(row);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0052CC),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Apply', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
    // Convert "PENDING_SELECTION" (client never picked) to empty string.
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
        'adsHandling': _cleanRoleValue(row['ads_handling']),
        'adsPlatform': row['ads_platform'] ?? '',
        'adsSubmitDate': row['ads_submit_date'] ?? '',
        'pageHandling': _cleanRoleValue(row['page_handling']),
        'pagesPlatform': row['pages_platform'] ?? '',
        'pageSubmitDate': row['page_submit_date'] ?? '',
        'designer': _cleanRoleValue(row['designer']),
        'designerTasks': row['designer_tasks'] ?? '',
        'designerSubmitDate': row['designer_submit_date'] ?? '',
        'videographer': _cleanRoleValue(row['videographer']),
        'videographerTasks': row['videographer_tasks'] ?? '',
        'videographerSubmitDate': row['videographer_submit_date'] ?? '',
        'videoEditor': _cleanRoleValue(row['video_editor']),
        'videoEditorTask': row['video_editor_task'] ?? '',
        'videoEditorSubmitDate': row['video_editor_submit_date'] ?? '',
        'uiUxDesigner': _cleanRoleValue(row['ui_ux_designer']),
        'uiUxTasks': row['ui_ux_tasks'] ?? '',
        'uiUxSubmitDate': row['ui_ux_submit_date'] ?? '',
        'developer': _cleanRoleValue(row['developer']),
        'developerTasks': row['developer_tasks'] ?? '',
        'developerSubmitDate': row['developer_submit_date'] ?? '',
        // FIX: deadline needed the same 'NONE' → '' cleanup as every role field.
        'deadline': _cleanRoleValue(row['deadline']),
        'comments': row['comments'] ?? '',
        'isAssigned': row['is_assigned'] == 1 || row['is_assigned'] == true,
        // FIX: attributes the resulting notification to whoever is actually
        // logged in, instead of the backend's generic 'Admin' fallback.
        'assignedByName': _adminName,
      }),
    );
  } catch (e) {
    debugPrint("Save error: $e");
  }
}
// FIX: every one of these must be EXPLICITLY set before a task can be
  // assigned — either to a real value, or to 'NONE' (meaning "I looked at
  // this and I'm intentionally not assigning it"). Left at '' (never
  // touched) blocks the save entirely.
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

    // Client is a hard requirement — there's no "None" option for it,
    // since a task with no client makes no sense to assign at all.
    final clientName = (row['client_name'] ?? '').toString();
    if (clientName.isEmpty || clientName == 'PENDING_SELECTION') {
      missing.add('Client');
    }

    _requiredRoleFields.forEach((key, label) {
      final value = (row[key] ?? '').toString();
      if (value.isEmpty) missing.add(label);
    });

    return missing;
  }

Future<void> _toggleAssign(Map<String, dynamic> row) async {
    final newVal = !(row['is_assigned'] == 1 || row['is_assigned'] == true);

    // Only enforce validation when actually assigning — unassigning is
    // always allowed with no checks, so a mistake can always be undone.
    if (newVal) {
      final missing = _missingFieldsFor(row);
      if (missing.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please fill in or select "None" for: ${missing.join(", ")} before assigning.',
              ),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return; // blocks the save — nothing reaches the backend
      }
    }

    setState(() => row['is_assigned'] = newVal ? 1 : 0);
    await _saveRow(row);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newVal ? '✅ Task assigned and saved' : 'Task unassigned and saved'),
          backgroundColor: newVal ? const Color(0xFF16A34A) : const Color(0xFF64748B),
          duration: const Duration(seconds: 2),
        ),
      );
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      final formattedDate = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      setState(() => row[fieldKey] = formattedDate);
      await _saveRow(row);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool loading = _loadingTasks || _loadingEmployees || _loadingClients || _loadingTaskMaster || _loadingRoles;

    final visibleRows = taskRows.where((r) {
  final assigned = r['is_assigned'] == 1 || r['is_assigned'] == true;
  return _showAssigned ? assigned : !assigned;
}).toList();

    return AdminLayout(
      pageTitle: "Tasks Assign",
      currentRoute: "/tasks",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text("Task Assign - Employees",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                SizedBox(height: 4),
                Text("Assign, monitor, and manage employee tasks based on departments and client deliverables.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ]),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAssigned = !_showAssigned),
                  icon: Icon(
                    _showAssigned ? Icons.pending_actions_rounded : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: const Color(0xFF0052CC),
                  ),
                  label: Text(
                    _showAssigned ? "Show Pending" : "Show Assigned",
                    style: const TextStyle(color: Color(0xFF0052CC), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0052CC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _fetchAll,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0052CC)),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: _showTaskMasterDialog,
                  icon: const Icon(Icons.settings, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    elevation: 0,
                  ),
                  label: const Text("Task Master",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: loading ? null : _addRow,
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    elevation: 0,
                  ),
                  label: const Text("Add Section",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
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
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: CircularProgressIndicator(color: Color(0xFF0052CC)),
            ))
          else if (_error != null)
            Center(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _fetchAll,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ))
          // else
          //   Container(
          //     decoration: BoxDecoration(
          //       color: Colors.white,
          //       borderRadius: BorderRadius.circular(8),
          //       border: Border.all(color: const Color(0xFFE2E8F0)),
          //     ),
          //     child: ClipRRect(
          //       borderRadius: BorderRadius.circular(8),
          //       child: Row(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           SizedBox(
          //             width: 200,
          //             child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          //               Container(
          //                 height: 48,
          //                 color: const Color(0xFF0052CC),
          //                 padding: const EdgeInsets.symmetric(horizontal: 16),
          //                 alignment: Alignment.centerLeft,
          //                 child: const Text("CLIENT NAME",
          //                     style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
          //               ),
          //               ...visibleRows.map((row) => _buildClientCell(row)),
          //               ...List.generate(4, (_) => _buildClientCell(null)),
          //             ]),
          //           ),
          //           const VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
          //           Expanded(
          //             child: SingleChildScrollView(
          //               scrollDirection: Axis.horizontal,
          //               dragStartBehavior: DragStartBehavior.start, 
          //               physics: const AlwaysScrollableScrollPhysics(),
          //               child: Column(
          //                 crossAxisAlignment: CrossAxisAlignment.start,
          //                 children: [
          //                   SizedBox(
          //                     width: 4400,
          //                     height: 48,
          //                     child: Row(children: const [
          //                       _HeaderCell(width: 200, label: "DELIVERABLES"),
          //                       _HeaderCell(width: 200, label: "MAINTENANCE DATE"),
          //                       _HeaderCell(width: 140, label: "ADS HANDLER"),
          //                       _HeaderCell(width: 160, label: "ADS TASKS"),
          //                       _HeaderCell(width: 140, label: "ADS DATE"),
          //                       _HeaderCell(width: 140, label: "PAGE HANDLER"),
          //                       _HeaderCell(width: 160, label: "PAGE TASKS"),
          //                       _HeaderCell(width: 140, label: "PAGE DATE"),
          //                       _HeaderCell(width: 140, label: "DESIGNER"),
          //                       _HeaderCell(width: 160, label: "DESIGN TASKS"),
          //                       _HeaderCell(width: 140, label: "DESIGN DATE"),
          //                       _HeaderCell(width: 140, label: "VIDEOGRAPHER"),
          //                       _HeaderCell(width: 160, label: "VIDEO TASKS"),
          //                       _HeaderCell(width: 140, label: "VIDEO DATE"),
          //                        _HeaderCell(width: 140, label: "VIDEO EDITOR"),
          //                       _HeaderCell(width: 160, label: "VIDEO EDIT TASKS"),
          //                       _HeaderCell(width: 140, label: "VIDEO EDIT DATE"),
                               
          //                       _HeaderCell(width: 140, label: "UI/UX DESIGNER"),
          //                       _HeaderCell(width: 160, label: "UI/UX TASKS"),
          //                       _HeaderCell(width: 140, label: "UI/UX DATE"),
          //                       _HeaderCell(width: 140, label: "DEVELOPER"),
          //                       _HeaderCell(width: 160, label: "DEV TASKS"),
          //                       _HeaderCell(width: 140, label: "DEV `DATE"),
          //                       _HeaderCell(width: 140, label: "DEADLINE"),
          //                       _HeaderCell(width: 160, label: "COMMENTS"),
          //                       _HeaderCell(width: 140, label: "ACTION"),
          //                     ]),
          //                   ),
          //                   const Divider(height: 1, color: Color(0xFFE2E8F0)),
          //                   ...visibleRows.map((row) => SizedBox(width: 4400, child: _buildDataRow(row))),
          //                   ...List.generate(4, (_) => SizedBox(width: 4400, child: _buildEmptyRow())),
          //                 ],
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),

          else
  Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Scrollbar(
      controller: _horizontalController, 
      thumbVisibility: true,
      trackVisibility: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Name column 
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
                  child: const Text("CLIENT NAME",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
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
  
  // ✅ NEW: Treat "PENDING_SELECTION" as empty
  if (currentClient == 'PENDING_SELECTION') {
    currentClient = '';
  }
  
  // Check if currentClient exists in clients list
  if (currentClient.isNotEmpty && !clients.contains(currentClient)) {
    final caseInsensitiveMatch = clients.firstWhere(
      (c) => c.toUpperCase() == currentClient.toUpperCase(),
      orElse: () => '',
    );
    
    if (caseInsensitiveMatch.isNotEmpty) {
      currentClient = caseInsensitiveMatch;
      row['client_name'] = caseInsensitiveMatch;
    } else {
      currentClient = '';
    }
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
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: Colors.white70,
          ),
        ),
        dropdownColor: const Color(0xFF1A5FCC),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
        style: const TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.bold, 
          color: Colors.white,
        ),
        items: [
          const DropdownMenuItem(
            value: '',
            child: Text(
              '— Select client name —',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          ...clients.map((c) => DropdownMenuItem(
            value: c,
            child: Text(c),
          )).toList(),
        ],
        onChanged: (val) async {
          if (val != null && val.isNotEmpty && val != currentClient) {
            setState(() => row['client_name'] = val);
            await Future.delayed(const Duration(milliseconds: 100));
            await _loadClientInvoiceData(row);
          }
        },
      ),
    ),
  );
}

  Widget _buildDataRow(Map<String, dynamic> row) {
    final bool assigned = row['is_assigned'] == 1 || row['is_assigned'] == true;
    // final empItems = <DropdownMenuItem<String>>[
    //   const DropdownMenuItem(value: '', child: Text('—', style: TextStyle(color: Color(0xFFCBD5E1)))),
    //   ...employees.map((e) => DropdownMenuItem(value: e, child: Text(e))),
    // ];

    // String empVal(String key) {
    //   final v = (row[key] ?? '').toString().toUpperCase();
    //   return employees.contains(v) ? v : '';
    // }
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

    // FIX: distinguishes "never touched" ('') from "explicitly set to None"
    // ('NONE') — previously both collapsed to the same empty value, so
    // there was no way to tell "forgot to assign" apart from "intentionally
    // not assigning."
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
        SizedBox(
          width: 200,
          height: 54,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
            alignment: Alignment.centerLeft,
            child: Text(
              row['deliverables']?.toString().isEmpty ?? true ? '—' : row['deliverables'].toString(),
              style: TextStyle(
                fontSize: 10,
                color: (row['deliverables']?.toString().isEmpty ?? true) ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                fontWeight: (row['deliverables']?.toString().isEmpty ?? true) ? FontWeight.normal : FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
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
        SizedBox(
          width: 140,
          child: _empDropCell(140, empVal('ads_handling'), empItems, onChanged: (v) {
            setState(() => row['ads_handling'] = v);
            _saveRow(row);
          }),
        ),
        SizedBox(width: 160, child: taskCell(160, 'ads_handler_task', 'ads_platform')),
        SizedBox(width: 140, child: _dateCell(140, 'ads_submit_date', row)),
        SizedBox(
          width: 140,
          child: _empDropCell(140, empVal('page_handling'), empItems, onChanged: (v) {
            setState(() => row['page_handling'] = v);
            _saveRow(row);
          }),
        ),
        SizedBox(width: 160, child: taskCell(160, 'page_handler_task', 'pages_platform')),
        SizedBox(width: 140, child: _dateCell(140, 'page_submit_date', row)),
        SizedBox(
          width: 140,
          child: _empDropCell(140, empVal('designer'), empItems, onChanged: (v) {
            setState(() => row['designer'] = v);
            _saveRow(row);
          }),
        ),
        SizedBox(width: 160, child: taskCell(160, 'graphic_designer_task', 'designer_tasks')),
        SizedBox(width: 140, child: _dateCell(140, 'designer_submit_date', row)),
        SizedBox(
          width: 140,
          child: _empDropCell(140, empVal('videographer'), empItems, onChanged: (v) {
            setState(() => row['videographer'] = v);
            _saveRow(row);
          }),
        ),
        SizedBox(width: 160, child: taskCell(160, 'videographer_task', 'videographer_tasks')),
        SizedBox(width: 140, child: _dateCell(140, 'videographer_submit_date', row)),
        SizedBox(
          width: 140,
          child: _empDropCell(140, empVal('video_editor'), empItems, onChanged: (v) {
            setState(() => row['video_editor'] = v);
            _saveRow(row);
          }),
        ),
        SizedBox(width: 160, child: taskCell(160, 'video_editor_task', 'video_editor_task')),
        SizedBox(width: 140, child: _dateCell(140, 'video_editor_submit_date', row)),
        SizedBox(
          width: 140,
          child: _empDropCell(140, empVal('ui_ux_designer'), empItems, onChanged: (v) {
            setState(() => row['ui_ux_designer'] = v);
            _saveRow(row);
          }),
        ),
        SizedBox(width: 160, child: taskCell(160, 'ui_ux_designer_task', 'ui_ux_tasks')),
        SizedBox(width: 140, child: _dateCell(140, 'ui_ux_submit_date', row)),
        SizedBox(
          width: 140,
          child: _empDropCell(140, empVal('developer'), empItems, onChanged: (v) {
            setState(() => row['developer'] = v);
            _saveRow(row);
          }),
        ),
        SizedBox(width: 160, child: taskCell(160, 'developer_task', 'developer_tasks')),
        SizedBox(width: 140, child: _dateCell(140, 'developer_submit_date', row)),
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
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(fontSize: 11, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today, size: 14, color: value.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0052CC)),
          ],
        ),
      ),
    );
  }

  // Widget _deadlineCell(double width, Map<String, dynamic> row) {
  //   return Container(
  //     width: width,
  //     padding: const EdgeInsets.symmetric(horizontal: 10),
  //     decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
  //     child: DropdownButtonHideUnderline(
  //       child: DropdownButton<String>(
  //         value: (row['deadline'] ?? '').isEmpty ? null : row['deadline'],
  //         isExpanded: true,
  //         hint: const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
  //         icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
  //         items: ['1 WEEK', '15 DAYS', '1 MONTH', '2 MONTHS'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
  //         onChanged: (v) {
  //           if (v != null) {
  //             setState(() => row['deadline'] = v);
  //             _saveRow(row);
  //           }
  //         },
  //       ),
  //     ),
  //   );
  // }

  Widget _deadlineCell(double width, Map<String, dynamic> row) {
    final current = (row['deadline'] ?? '').toString();
    final bool isUnselected = current.isEmpty;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
        color: isUnselected ? const Color(0xFFFFF7ED) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current.isEmpty ? null : current,
          isExpanded: true,
          hint: const Text('— Select —', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
          items: [
            const DropdownMenuItem(
              value: 'NONE',
              child: Text('None', style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
            ),
            ...['1 WEEK', '15 DAYS', '1 MONTH', '2 MONTHS'].map((o) => DropdownMenuItem(value: o, child: Text(o))),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => row['deadline'] = v);
            }
          },
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
            onSubmitted: (v) {
              row['comments'] = v;
              _saveRow(row);
            },
          ),
        ),
      ),
    );
  }

  Widget _actionCell(double width, Map<String, dynamic> row, bool assigned) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _toggleAssign(row),
              style: ElevatedButton.styleFrom(
                backgroundColor: assigned ? const Color(0xFF00C853) : const Color(0xFF0052CC),
                padding: EdgeInsets.zero,
              ),
              child: FittedBox(
                child: Text(
                  assigned ? "EDIT" : "ASSIGN",
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _deleteRow(row['id']),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.delete_outline, size: 12, color: Color(0xFFDC2626)),
          ),
        ),
      ]),
    );
  }

//  Widget _empDropCell(
//   double width, 
//   String current, 
//   List<DropdownMenuItem<String>> items,
//   {required ValueChanged<String> onChanged}
// ) {
//   return Container(
//     width: width,
//     padding: const EdgeInsets.symmetric(horizontal: 10),
//     decoration: const BoxDecoration(
//       border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
//     ),
//     child: DropdownButtonHideUnderline(
//       child: DropdownButton<String>(
//         value: current.isEmpty ? null : current,
//         isExpanded: true,
//         hint: const Text(
//           'NIL',  // ✅ NEW: Show "NIL" as hint
//           style: TextStyle(
//             fontSize: 10, 
//             color: Color(0xFFCBD5E1),
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
//         style: const TextStyle(
//           fontSize: 10, 
//           fontWeight: FontWeight.w700, 
//           color: Color(0xFF0052CC),
//         ),
//         items: [
//           // ✅ NEW: Add "NIL" option for empty/not applicable
//           const DropdownMenuItem(
//             value: 'NIL',
//             child: Text(
//               'NIL',
//               style: TextStyle(
//                 fontSize: 10,
//                 color: Color(0xFF9CA3AF),
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           // All employees
//           ...items,
//         ],
//         onChanged: (v) {
//           if (v != null) onChanged(v);
//         },
//       ),
//     ),
//   );
// }

Widget _empDropCell(double width, String current, List<DropdownMenuItem<String>> items,
      {required ValueChanged<String> onChanged}) {
    // FIX: subtle tint while the field is still unselected, so it's
    // visually obvious which columns still need a choice before ASSIGN
    // will succeed.
    final bool isUnselected = current.isEmpty;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
        color: isUnselected ? const Color(0xFFFFF7ED) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current.isEmpty ? '' : current,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0052CC)),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
  Widget _buildEmptyRow() {
    const widths = [200, 200, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140, 140, 160, 140];
    return Row(
      children: widths
          .map((w) => SizedBox(
            width: w.toDouble(),
            height: 54,
            child: Container(
              decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)))),
            ),
          ))
          .toList(),
    );
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
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Color(0xFF475569),
          letterSpacing: 0.3,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(child: child);
  }
}

