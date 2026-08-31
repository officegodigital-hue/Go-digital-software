
// name=admin_panel_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../layouts/admin_layout.dart';
import '../../services/api_config.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

enum _TableSortMode { sNo, teamMember }

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  static const Color _primary = Color(0xFF0052CC);
  static const Color _primaryDark = Color(0xFF003B95);
  static const Color _primaryLight = Color(0xFFEAF2FF);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF7F9FC);

  List<Map<String, dynamic>> employeeUsers = [];
  List<String> employeeRoleOptions = [];
  List<String> adminRoleOptions = [];
  List<Map<String, dynamic>> allUserRolesMaster = [];

  bool _loading = true;
  bool _loadingRoles = false;
  bool _isFormView = false;
  bool _isSubmitting = false;

  String? _error;
  String? _modalError;
  String _searchQuery = '';

  String _tableUserTypeFilter = 'all';
  String _tableStatusFilter = 'active';
  bool _isSNoAscending = true;
  bool _isTeamMemberAscending = true;
  _TableSortMode _sortMode = _TableSortMode.sNo;

  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _middleNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _staffIdCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  String _selectedUserType = 'employee';
  bool _isMainAdmin = false;
  String _selectedRole = '';
  List<String> _selectedPermissions = [];
  Map<String, dynamic>? _editingEmployee;

  final List<Map<String, String>> availablePages = [
    {'title': 'Dashboard', 'route': '/admin'},
    {'title': 'Client Onboarding', 'route': '/client-history'},
    {'title': 'Client Credentials', 'route': '/client-credentials'},
    {'title': 'Packages', 'route': '/packages'},
    {'title': 'Quotations', 'route': '/quotations'},
    {'title': 'Package & Quotation', 'route': '/quotation'},
    {'title': 'Invoice', 'route': '/invoice'},
    {'title': 'Tasks Assign', 'route': '/tasks'},
    {'title': 'Daily Planner', 'route': '/daily-planner'},
    {'title': 'Employee Status', 'route': '/employee-status'},
    {'title': 'Manager Review', 'route': '/manager-review'},
    {'title': 'Notifications', 'route': '/notifications'},
    {'title': 'Performance', 'route': '/performance'},
    {'title': 'Employee Management', 'route': '/admin-panel'},
    {'title': 'Time Manager', 'route': '/time-manager'},
  ];

  final List<Map<String, String>> adminPages = [
    {'title': 'Dashboard', 'route': '/admin'},
    {'title': 'Client Onboarding', 'route': '/client-history'},
    {'title': 'Client Credentials', 'route': '/client-credentials'},
    {'title': 'Packages', 'route': '/packages'},
    {'title': 'Quotations', 'route': '/quotations'},
    {'title': 'Package & Quotation', 'route': '/quotation'},
    {'title': 'Invoice', 'route': '/invoice'},
    {'title': 'Tasks Assign', 'route': '/tasks'},
    {'title': 'Daily Planner', 'route': '/daily-planner'},
    {'title': 'Employee Status', 'route': '/employee-status'},
    {'title': 'Manager Review', 'route': '/manager-review'},
    {'title': 'Notifications', 'route': '/notifications'},
    {'title': 'Performance', 'route': '/performance'},
    {'title': 'Employee Management', 'route': '/admin-panel'},
    {'title': 'Time Manager', 'route': '/time-manager'},
  ];

  final List<Map<String, String>> employeePages = [
    {'title': 'Dashboard', 'route': 'Dashboard'},
    {'title': 'Day Planner', 'route': 'Day Planner'},
    {'title': 'Assigned Task', 'route': 'Assigned Task'},
    {'title': 'Live Tracking Tasks', 'route': 'Live Tracking Tasks'},
    {'title': 'Daily Reports', 'route': 'Daily Reports'},
    {'title': 'Task Planner', 'route': 'Task Planner'},
    {'title': 'Video Task Planner', 'route': 'Video Task Planner'},
    {'title': 'Task Review', 'route': 'Task Review'},
    {'title': 'Task Status', 'route': 'Task Status'},
    {'title': 'Notifications', 'route': 'Notifications'},
    {'title': 'Feedback', 'route': 'Feedback'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserRolesMaster();
    _fetchEmployees();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _staffIdCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isTrue(dynamic value) {
    return value == true || value == 1 || value == '1';
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String _normalizeUserType(dynamic value) {
    final type = value?.toString().trim().toLowerCase() ?? '';
    return type == 'admin' ? 'admin' : 'employee';
  }

  List<String> _parseAllowedPages(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }

    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return [];

      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    return [];
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        backgroundColor: success ? const Color(0xFF0F9D73) : const Color(0xFFDC2626),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getActiveRoleOptions() {
    return _selectedUserType == 'admin'
        ? adminRoleOptions
        : employeeRoleOptions;
  }

  int get _activeCount {
    return employeeUsers
        .where((e) => _isTrue(e['is_active']))
        .length;
  }

  int get _adminCount {
    return employeeUsers
        .where((e) => _normalizeUserType(e['user_type']) == 'admin')
        .length;
  }

  int get _employeeCount {
    return employeeUsers
        .where((e) => _normalizeUserType(e['user_type']) == 'employee')
        .length;
  }

  void _openForm({Map<String, dynamic>? employee}) async {
    await _fetchUserRolesMaster();
    if (!mounted) return;

    setState(() {
      _editingEmployee = employee;

      _firstNameCtrl.text =
          employee?['first_name']?.toString() ?? '';
      _middleNameCtrl.text =
          employee?['middle_name']?.toString() ?? '';
      _lastNameCtrl.text =
          employee?['last_name']?.toString() ?? '';
      _staffIdCtrl.text =
          employee?['staff_id']?.toString() ?? '';
      _emailCtrl.text =
          employee?['email']?.toString() ?? '';
      _usernameCtrl.text =
          employee?['username']?.toString() ?? '';
      _passwordCtrl.clear();

      _selectedUserType =
          _normalizeUserType(employee?['user_type']);

      _isMainAdmin =
          _isTrue(employee?['is_main_admin']);

      final activeRoles = _getActiveRoleOptions();

      _selectedRole =
          employee?['role']?.toString() ?? '';

      if (!activeRoles.contains(_selectedRole)) {
        _selectedRole =
            activeRoles.isNotEmpty ? activeRoles.first : '';
      }

      _selectedPermissions =
          _parseAllowedPages(employee?['allowed_pages']);

      if (_isMainAdmin) {
        _selectedPermissions =
            availablePages.map((p) => p['route']!).toList();
      }

      _modalError = null;
      _isFormView = true;
    });
  }

  void _closeForm() {
    setState(() {
      _isFormView = false;
      _editingEmployee = null;
      _modalError = null;
    });
  }

  Future<void> _fetchUserRolesMaster() async {
    if (!mounted) return;

    setState(() => _loadingRoles = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/employees/user-roles'),
        headers: const {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() => _loadingRoles = false);
        }
        return;
      }

      final decoded = jsonDecode(response.body);
      List<dynamic> rows = [];

      if (decoded is List) {
        rows = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is List) {
          rows = decoded['data'];
        } else if (decoded['roles'] is List) {
          rows = decoded['roles'];
        }
      }

      final normalizedRoles =
          rows.whereType<Map>().map<Map<String, dynamic>>((item) {
        final map = Map<String, dynamic>.from(item);

        return {
          ...map,
          'id': _toInt(map['id']),
          'role_name':
              (map['role_name'] ?? map['roleName'] ?? '')
                  .toString()
                  .trim(),
          'user_type':
              (map['user_type'] ??
                      map['userType'] ??
                      'employee')
                  .toString()
                  .trim()
                  .toLowerCase(),
        };
      }).toList();

      final employeeRoles = normalizedRoles
          .where((role) => role['user_type'] == 'employee')
          .map((role) => role['role_name'].toString())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final adminRoles = normalizedRoles
          .where((role) => role['user_type'] == 'admin')
          .map((role) => role['role_name'].toString())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (!mounted) return;

      setState(() {
        allUserRolesMaster = normalizedRoles;
        employeeRoleOptions = employeeRoles;
        adminRoleOptions = adminRoles;
        _loadingRoles = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingRoles = false);
      }
    }
  }

  Future<bool> _addNewUserRole(
    String roleName,
    String userType,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/employees/user-roles'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'roleName': roleName.trim(),
          'userType': userType,
        }),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        await _fetchUserRolesMaster();
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _updateUserRole(
    int roleId,
    String roleName,
    String userType,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/employees/user-roles/$roleId'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'roleName': roleName.trim(),
          'userType': userType,
        }),
      );

      if (response.statusCode == 200) {
        await _fetchUserRolesMaster();
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _deleteUserRole(int roleId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/employees/user-roles/$roleId'),
        headers: const {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _fetchUserRolesMaster();
        _showSnack(
          'Role deleted successfully',
          success: true,
        );
        return true;
      }

      _showSnack('Failed to delete role');
      return false;
    } catch (_) {
      _showSnack('Failed to delete role');
      return false;
    }
  }

  Future<void> _showUserRoleMasterDialog() async {
    final roleNameController = TextEditingController();

    String selectedDialogUserType = 'employee';
    bool isEditingRole = false;
    int? editingRoleId;

    await _fetchUserRolesMaster();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final width = MediaQuery.of(dialogContext).size.width;

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: Container(
                width: width > 600 ? 560 : double.infinity,
                constraints: const BoxConstraints(maxHeight: 700),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primary,
                            _primaryDark,
                          ],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              isEditingRole
                                  ? 'Edit User Role'
                                  : 'User Role Master',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _sectionLabel(
                              'Role Configuration',
                              Icons.tune_rounded,
                            ),
                            const SizedBox(height: 16),

                            _buildDialogDropdown(
                              label: 'User Type',
                              value: selectedDialogUserType,
                              items: const [
                                DropdownMenuItem(
                                  value: 'employee',
                                  child: Text('Employee Role'),
                                ),
                                DropdownMenuItem(
                                  value: 'admin',
                                  child: Text('Admin Role'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedDialogUserType = value;
                                });
                              },
                            ),

                            const SizedBox(height: 14),

                            _modernTextField(
                              controller: roleNameController,
                              label: 'Role Name',
                              hint: 'Enter role name',
                              icon: Icons.badge_outlined,
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final name =
                                      roleNameController.text
                                          .trim();

                                  if (name.isEmpty) {
                                    _showSnack(
                                      'Please enter role name',
                                    );
                                    return;
                                  }

                                  bool success = false;

                                  if (isEditingRole &&
                                      editingRoleId != null) {
                                    success =
                                        await _updateUserRole(
                                      editingRoleId!,
                                      name,
                                      selectedDialogUserType,
                                    );
                                  } else {
                                    success =
                                        await _addNewUserRole(
                                      name,
                                      selectedDialogUserType,
                                    );
                                  }

                                  if (!mounted) return;

                                  if (success) {
                                    roleNameController.clear();

                                    setDialogState(() {
                                      isEditingRole = false;
                                      editingRoleId = null;
                                    });

                                    _showSnack(
                                      'Operation successful',
                                      success: true,
                                    );
                                  } else {
                                    _showSnack(
                                      'Operation failed',
                                    );
                                  }
                                },
                                icon: Icon(
                                  isEditingRole
                                      ? Icons.update_rounded
                                      : Icons.add_rounded,
                                ),
                                label: Text(
                                  isEditingRole
                                      ? 'Update Role'
                                      : 'Add New Role',
                                ),
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            _sectionLabel(
                              'Existing Roles',
                              Icons.folder_shared_outlined,
                            ),

                            const SizedBox(height: 12),

                            Container(
                              height: 250,
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius:
                                    BorderRadius.circular(18),
                                border:
                                    Border.all(color: _border),
                              ),
                              child: _loadingRoles
                                  ? const Center(
                                      child:
                                          CircularProgressIndicator(
                                        color: _primary,
                                      ),
                                    )
                                  : allUserRolesMaster.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No roles found',
                                            style: TextStyle(
                                              color: _muted,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding:
                                              const EdgeInsets.all(
                                            10,
                                          ),
                                          itemCount:
                                              allUserRolesMaster
                                                  .length,
                                          separatorBuilder:
                                              (_, __) =>
                                                  const SizedBox(
                                            height: 8,
                                          ),
                                          itemBuilder:
                                              (context, index) {
                                            final roleItem =
                                                allUserRolesMaster[
                                                    index];

                                            final roleId =
                                                _toInt(
                                              roleItem['id'],
                                            );

                                            final isAdmin =
                                                _normalizeUserType(
                                                      roleItem[
                                                          'user_type'],
                                                    ) ==
                                                    'admin';

                                            return Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                              decoration:
                                                  BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(12),
                                                border: Border.all(
                                                  color: _border,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration:
                                                        BoxDecoration(
                                                      color: isAdmin
                                                          ? const Color(
                                                              0xFFFFF3E0,
                                                            )
                                                          : _primaryLight,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                        10,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      isAdmin
                                                          ? Icons
                                                              .shield_outlined
                                                          : Icons
                                                              .person_outline_rounded,
                                                      size: 18,
                                                      color: isAdmin
                                                          ? const Color(
                                                              0xFFE67E22,
                                                            )
                                                          : _primary,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: 12,
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          roleItem[
                                                                  'role_name']
                                                              .toString(),
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: _ink,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          isAdmin
                                                              ? 'ADMIN'
                                                              : 'EMPLOYEE',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800,
                                                            letterSpacing:
                                                                0.8,
                                                            color: isAdmin
                                                                ? const Color(
                                                                    0xFFE67E22,
                                                                  )
                                                                : _primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Edit',
                                                    onPressed: () {
                                                      setDialogState(
                                                        () {
                                                          isEditingRole =
                                                              true;

                                                          editingRoleId =
                                                              roleId;

                                                          roleNameController
                                                              .text = roleItem[
                                                                  'role_name']
                                                              .toString();

                                                          selectedDialogUserType =
                                                              _normalizeUserType(
                                                            roleItem[
                                                                'user_type'],
                                                          );
                                                        },
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 19,
                                                      color: _primary,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Delete',
                                                    onPressed:
                                                        roleId == null
                                                            ? null
                                                            : () async {
                                                                final confirm =
                                                                    await _showConfirmDialog(
                                                                  title:
                                                                      'Delete Role',
                                                                  message:
                                                                      'Are you sure you want to delete this role?',
                                                                  confirmText:
                                                                      'Delete',
                                                                );

                                                                if (confirm !=
                                                                    true) {
                                                                  return;
                                                                }

                                                                await _deleteUserRole(
                                                                  roleId,
                                                                );

                                                                if (mounted) {
                                                                  setDialogState(
                                                                    () {},
                                                                  );
                                                                }
                                                              },
                                                    icon: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 19,
                                                      color: Color(
                                                        0xFFDC2626,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: _border),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
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

    roleNameController.dispose();
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    final query = _searchQuery.trim().toLowerCase();

    final records = employeeUsers.where((item) {
      if (query.isNotEmpty) {
        final name = (item['full_name'] ?? '').toString().toLowerCase();
        final staffId = (item['staff_id'] ?? '').toString().toLowerCase();
        final role = (item['role'] ?? '').toString().toLowerCase();
        final email = (item['email'] ?? '').toString().toLowerCase();

        if (!name.contains(query) &&
            !staffId.contains(query) &&
            !role.contains(query) &&
            !email.contains(query)) return false;
      }

      final userType = _normalizeUserType(item['user_type']);
      if (_tableUserTypeFilter != 'all' &&
          userType != _tableUserTypeFilter) return false;

      final isActive = _isTrue(item['is_active']);
      if (_tableStatusFilter == 'active' && !isActive) return false;
      if (_tableStatusFilter == 'inactive' && isActive) return false;

      return true;
    }).toList();

    if (_sortMode == _TableSortMode.teamMember) {
      records.sort((a, b) {
        final aName = (a['full_name'] ?? '').toString().toLowerCase();
        final bName = (b['full_name'] ?? '').toString().toLowerCase();
        return _isTeamMemberAscending
            ? aName.compareTo(bName)
            : bName.compareTo(aName);
      });
    } else {
      records.sort((a, b) {
        final aId = _toInt(a['id']) ?? 0;
        final bId = _toInt(b['id']) ?? 0;
        return _isSNoAscending ? aId.compareTo(bId) : bId.compareTo(aId);
      });
    }

    return records;
  }

  void _toggleSNoSort() {
    setState(() {
      if (_sortMode != _TableSortMode.sNo) {
        _sortMode = _TableSortMode.sNo;
        _isSNoAscending = true;
      } else {
        _isSNoAscending = !_isSNoAscending;
      }
    });
  }

  void _toggleTeamMemberSort() {
    setState(() {
      if (_sortMode != _TableSortMode.teamMember) {
        _sortMode = _TableSortMode.teamMember;
        _isTeamMemberAscending = true;
      } else {
        _isTeamMemberAscending = !_isTeamMemberAscending;
      }
    });
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/employees'));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        setState(() {
          employeeUsers =
              List<Map<String, dynamic>>.from(body['data']);
          _loading = false;
        });
      } else {
        setState(() {
          _error =
              'Server returned ${response.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_firstNameCtrl.text.trim().isEmpty ||
        _lastNameCtrl.text.trim().isEmpty ||
        _staffIdCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _usernameCtrl.text.trim().isEmpty) {
      setState(() {
        _modalError =
            'Please fill all required fields (*)';
      });
      return;
    }

    if (_selectedRole.trim().isEmpty) {
      setState(() {
        _modalError =
            'Please select a role. Add a role in User Role Master first.';
      });
      return;
    }

    final isEditMode = _editingEmployee != null;

    if (!isEditMode &&
        _passwordCtrl.text.trim().isEmpty) {
      setState(() {
        _modalError = 'Password is required';
      });
      return;
    }

    if (_passwordCtrl.text.isNotEmpty &&
        _passwordCtrl.text.length < 6) {
      setState(() {
        _modalError =
            'Password must be at least 6 characters';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _modalError = null;
    });

    final finalPermissions =
        (_selectedUserType == 'admin' &&
                _isMainAdmin)
            ? availablePages
                .map((page) => page['route']!)
                .toList()
            : _selectedPermissions;

    final data = {
      'firstName': _firstNameCtrl.text.trim(),
      'middleName': _middleNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'staffId': _staffIdCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'username': _usernameCtrl.text.trim(),
      'role': _selectedRole.trim(),
      'userType': _selectedUserType,
      'isMainAdmin': _isMainAdmin ? 1 : 0,
      'allowedPages': finalPermissions,
      if (_passwordCtrl.text.trim().isNotEmpty)
        'password': _passwordCtrl.text,
    };

    String? error;

    if (isEditMode) {
      final id = _toInt(_editingEmployee!['id']);

      if (id == null) {
        setState(() {
          _isSubmitting = false;
          _modalError = 'Invalid user ID';
        });
        return;
      }

      error = await _updateEmployeeApi(id, data);
    } else {
      error = await _createEmployeeApi(data);
    }

    if (!mounted) return;

    if (error == null) {
      _closeForm();
      await _fetchEmployees();

      _showSnack(
        isEditMode
            ? 'Employee updated successfully'
            : 'Employee created successfully',
        success: true,
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _modalError = error;
      });
    }
  }

  Future<String?> _createEmployeeApi(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/employees'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        return null;
      }

      try {
        final body = jsonDecode(response.body);

        if (body is Map<String, dynamic>) {
          return body['message']?.toString() ??
              'Failed to create employee';
        }
      } catch (_) {}

      return 'Failed to create employee';
    } catch (_) {
      return 'Cannot connect to server';
    }
  }

  Future<String?> _updateEmployeeApi(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/employees/$id'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return null;
      }

      try {
        final body = jsonDecode(response.body);

        if (body is Map<String, dynamic>) {
          return body['message']?.toString() ??
              'Failed to update employee';
        }
      } catch (_) {}

      return 'Failed to update employee';
    } catch (_) {
      return 'Cannot connect to server';
    }
  }

  Future<void> _toggleStatus(
    int id,
    bool currentStatus,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/employees/$id'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'isActive': !currentStatus,
        }),
      );

      if (response.statusCode == 200) {
        _fetchEmployees();

        _showSnack(
          currentStatus
              ? 'User deactivated successfully'
              : 'User activated successfully',
          success: true,
        );
      } else {
        _showSnack('Failed to update status');
      }
    } catch (_) {
      _showSnack('Cannot connect to server');
    }
  }

  Future<void> _deleteEmployee(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/employees/$id'),
      );

      if (response.statusCode == 200) {
        _fetchEmployees();
        _showSnack(
          'Employee deleted',
          success: true,
        );
      } else {
        _showSnack('Failed to delete employee');
      }
    } catch (_) {
      _showSnack('Cannot connect to server');
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: _muted,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchSingleEmployee(
    int id,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/employees/$id'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map) {
            return Map<String, dynamic>.from(
              decoded['data'],
            );
          }

          if (decoded['employee'] is Map) {
            return Map<String, dynamic>.from(
              decoded['employee'],
            );
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Admin Panel',
      currentRoute: '/admin-panel',
      onSearch: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      child: _isFormView
          ? _buildFormView()
          : _buildTableView(),
    );
  }

  Widget _buildTableView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;

        return SingleChildScrollView(
          padding: EdgeInsets.all(
            isMobile ? 14 : 24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildHeroHeader(isMobile),

              const SizedBox(height: 20),

              _buildStats(isMobile),

              const SizedBox(height: 20),

              if (isMobile)
                _buildMobileActionPanel()
              else
                _buildDesktopActionPanel(),

              const SizedBox(height: 20),

              if (isMobile)
                _buildMobileEmployees()
              else
                _buildDesktopEmployees(),

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryDark,
            _primary,
            Color(0xFF1267E8),
          ],
        ),
        borderRadius: BorderRadius.circular(
          isMobile ? 22 : 28,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 52 : 62,
                height: isMobile ? 52 : 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: 0.20,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: isMobile ? 27 : 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Access Management',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Manage your digital workforce, roles and access permissions.',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        height: 1.5,
                        color: Colors.white.withValues(
                          alpha: 0.82,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.13,
              ),
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.18,
                ),
              ),
            ),
            child: Text(
              '${_filteredEmployees.length} USERS FOUND',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(bool isMobile) {
    final stats = [
      {
        'label': 'Total Users',
        'value': '${employeeUsers.length}',
        'icon': Icons.groups_rounded,
        'color': _primary,
      },
      {
        'label': 'Active Users',
        'value': '$_activeCount',
        'icon': Icons.verified_user_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Administrators',
        'value': '$_adminCount',
        'icon': Icons.admin_panel_settings_rounded,
        'color': const Color(0xFFF59E0B),
      },      {
        'label': 'Employees',
        'value': '$_employeeCount',
        'icon': Icons.badge_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio:
            isMobile ? 1.45 : 2.1,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        final color = stat['color'] as Color;

        return Container(
          padding: EdgeInsets.all(
            isMobile ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: _border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.025,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 38 : 46,
                height: isMobile ? 38 : 46,
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  stat['icon'] as IconData,
                  color: color,
                  size: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat['value'] as String,
                      style: TextStyle(
                        fontSize:
                            isMobile ? 19 : 24,
                        fontWeight:
                            FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat['label'] as String,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            isMobile ? 10 : 11,
                        color: _muted,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopActionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Manage team accounts and platform access'
                  : 'Showing results for "$_searchQuery"',
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _fetchEmployees,
            style: IconButton.styleFrom(
              backgroundColor: _primaryLight,
              foregroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed:
                _showUserRoleMasterDialog,
            icon: const Icon(
              Icons.settings_suggest_rounded,
              size: 18,
            ),
            label: const Text('Role Master'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  const Color(0xFFE67E22),
              side: const BorderSide(
                color: Color(0xFFFCD9A6),
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              size: 18,
            ),
            label: const Text(
              'Add Employee',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 17,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActionPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _showUserRoleMasterDialog,
                  icon: const Icon(
                    Icons.settings_suggest_rounded,
                    size: 17,
                  ),
                  label: const Text(
                    'Role Master',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        const Color(0xFFE67E22),
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _fetchEmployees,
                style: IconButton.styleFrom(
                  backgroundColor:
                      _primaryLight,
                  foregroundColor: _primary,
                  minimumSize:
                      const Size(52, 52),
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
              ),
              label: const Text(
                'Add New Employee',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopEmployees() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  child: _buildSortableTableHeader(
                    label: 'S.NO',
                    ascending: _isSNoAscending,
                    active: _sortMode == _TableSortMode.sNo,
                    onTap: _toggleSNoSort,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _buildSortableTableHeader(
                    label: 'TEAM MEMBER',
                    ascending: _isTeamMemberAscending,
                    active: _sortMode == _TableSortMode.teamMember,
                    onTap: _toggleTeamMemberSort,
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('STAFF ID', style: _tableHeading),
                ),
                Expanded(
                  flex: 2,
                  child: _buildHeaderFilter(
                    label: 'USER TYPE',
                    value: _tableUserTypeFilter,
                    items: const ['all', 'employee', 'admin'],
                    onChanged: (value) =>
                        setState(() => _tableUserTypeFilter = value),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Center(
                  child: Text('ROLE', style: _tableHeading),
                ),
                ),
                SizedBox(
                  width: 132,
                  child: _buildHeaderFilter(
                    label: 'STATUS',
                    value: _tableStatusFilter,
                    items: const ['active', 'inactive', 'all'],
                    onChanged: (value) =>
                        setState(() => _tableStatusFilter = value),
                  ),
                ),
                const SizedBox(
                  width: 110,
                  child: Text('ACTIONS',
                      textAlign: TextAlign.center, style: _tableHeading),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator(color: _primary)),
            )
          else if (_error != null)
            _buildErrorState()
          else if (_filteredEmployees.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredEmployees.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _border),
              itemBuilder: (_, index) =>
                  _buildDesktopEmployeeRow(_filteredEmployees[index], index),
            ),
        ],
      ),
    );
  }

  Widget _buildSortableTableHeader({
    required String label,
    required bool ascending,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: active ? _primary : _muted,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            ascending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
            size: 18,
            color: active ? _primary : _muted,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFilter({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Filter $label',
      initialValue: value,
      offset: const Offset(0, 36),
      onSelected: onChanged,
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(
                    item == value
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 16,
                    color: item == value ? _primary : _muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$label · ${value.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: value == 'all' ? _muted : _primary,
                letterSpacing: 0.45,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: value == 'all' ? _muted : _primary),
        ],
      ),
    );
  }

  Widget _buildDesktopEmployeeRow(
    Map<String, dynamic> item,
    int index,
  ) {
    final active =
        _isTrue(item['is_active']);

    final id = _toInt(item['id']) ?? 0;

    final isMain =
        _isTrue(item['is_main_admin']);

    final userType =
        _normalizeUserType(item['user_type']);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      color: index.isEven
          ? Colors.white
          : const Color(0xFFFBFCFE),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Align(
  alignment: Alignment.centerLeft,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: _employeeIdentity(item),
          ),
          Expanded(
  flex: 2,
  child: Align(
    alignment: Alignment.centerLeft,
    child: Text(
      item['staff_id']?.toString() ?? '-',
      style: const TextStyle(
        color: _muted,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
),
         Expanded(
  flex: 2,
    child: _userTypeBadge(
      userType,
      isMain,
    ),
  ),
          Expanded(
            flex: 3,child: Center(
    // alignment: Alignment.center,
            child: Text(
              item['role']?.toString() ?? '-',
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ),
          
          SizedBox(
            width: 110,
            child: Align(
    alignment: Alignment.centerLeft,
              child: _statusButton(
                id: id,
                active: active,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Center(
              child: _actionButtons(
                item,
                id,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileEmployees() {
    if (_loading) {
      return const SizedBox(
        height: 260,
        child: Center(
          child:
              CircularProgressIndicator(
            color: _primary,
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_filteredEmployees.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildMobileTableFilters(),
        const SizedBox(height: 12),
        ListView.separated(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: _filteredEmployees.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
      itemBuilder: (context, index) {
          return _buildMobileEmployeeCard(
            _filteredEmployees[index],
            index,
          );
        },
      ),
      ],
    );
  }

  Widget _buildMobileTableFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMobileFilterDropdown(
                  value: _tableUserTypeFilter,
                  icon: Icons.badge_outlined,
                  items: const {
                    'all': 'All Types',
                    'employee': 'Employee',
                    'admin': 'Admin',
                  },
                  onChanged: (value) =>
                      setState(() => _tableUserTypeFilter = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMobileFilterDropdown(
                  value: _tableStatusFilter,
                  icon: Icons.verified_outlined,
                  items: const {
                    'active': 'Active',
                    'inactive': 'Inactive',
                    'all': 'All Status',
                  },
                  onChanged: (value) =>
                      setState(() => _tableStatusFilter = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMobileSortButton(
                  label: 'S.No',
                  active: _sortMode == _TableSortMode.sNo,
                  ascending: _isSNoAscending,
                  onTap: _toggleSNoSort,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMobileSortButton(
                  label: 'Team Member',
                  active: _sortMode == _TableSortMode.teamMember,
                  ascending: _isTeamMemberAscending,
                  onTap: _toggleTeamMemberSort,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilterDropdown({
    required String value,
    required IconData icon,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
          items: items.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: _primary),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ),
    );
  }

  Widget _buildMobileSortButton({
    required String label,
    required bool active,
    required bool ascending,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        ascending
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        size: 15,
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? _primary : _muted,
        side: BorderSide(
          color: active ? _primary.withValues(alpha: 0.35) : _border,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildMobileEmployeeCard(
    Map<String, dynamic> item,
    int index,
  ) {
    final active =
        _isTrue(item['is_active']);

    final id = _toInt(item['id']) ?? 0;

    final isMain =
        _isTrue(item['is_main_admin']);

    final userType =
        _normalizeUserType(item['user_type']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _employeeIdentity(item),
              ),
              const SizedBox(width: 10),
              _statusButton(
                id: id,
                active: active,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            height: 1,
            color: _border,
          ),

          const SizedBox(height: 14),

          _mobileInfoRow(
            Icons.badge_outlined,
            'Staff ID',
            item['staff_id']?.toString() ?? '-',
          ),

          const SizedBox(height: 10),

          _mobileInfoRow(
            Icons.work_outline_rounded,
            'Role',
            item['role']?.toString() ?? '-',
          ),

          const SizedBox(height: 12),

          _userTypeBadge(
            userType,
            isMain,
          ),

          const SizedBox(height: 14),

          Container(
            height: 1,
            color: _border,
          ),

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerRight,
            child: _actionButtons(
              item,
              id,
              mobile: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeIdentity(
    Map<String, dynamic> item,
  ) {
    final name =
        item['full_name']?.toString() ?? '';

    final initials =
        item['initials']?.toString().isNotEmpty == true
            ? item['initials'].toString()
            : _getInitials(name);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primary,
                Color(0xFF2879EE),
              ],
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Unknown User' : name,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item['email']?.toString() ?? '',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _userTypeBadge(
    String userType,
    bool isMain,
  ) {
    final isAdmin = userType == 'admin';

    final label = isAdmin
        ? (isMain ? 'MAIN ADMIN' : 'ADMIN')
        : 'EMPLOYEE';

    final color = isAdmin
        ? const Color(0xFFE67E22)
        : _primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _statusButton({
    required int id,
    required bool active,
  }) {
    return InkWell(
      onTap: id == 0
          ? null
          : () => _toggleStatus(id, active),
      borderRadius:
          BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE9F9F2)
              : const Color(0xFFF1F5F9),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? const Color(0xFFB7EFD8)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_outline_rounded,
              size: 13,
              color: active
                  ? const Color(0xFF059669)
                  : _muted,
            ),
            const SizedBox(width: 5),
            Text(
              active ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: active
                    ? const Color(0xFF059669)
                    : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButtons(
    Map<String, dynamic> item,
    int id, {
    bool mobile = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit Employee',
          onPressed: id == 0
              ? null
              : () async {
                  final data =
                      await _fetchSingleEmployee(
                    id,
                  );

                  if (data != null &&
                      context.mounted) {
                    _openForm(
                      employee: data,
                    );
                  } else {
                    _showSnack(
                      'Failed to load employee data',
                    );
                  }
                },
          style: IconButton.styleFrom(
            backgroundColor:
                _primaryLight,
            foregroundColor: _primary,
            minimumSize: Size(
              mobile ? 44 : 38,
              mobile ? 44 : 38,
            ),
          ),
          icon: const Icon(
            Icons.edit_outlined,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Delete Employee',
          onPressed: id == 0
              ? null
              : () async {
                  final confirm =
                      await _showConfirmDialog(
                    title: 'Delete Employee',
                    message:
                        'Remove ${item['full_name']} from the platform?',
                    confirmText: 'Delete',
                  );

                  if (confirm == true) {
                    _deleteEmployee(id);
                  }
                },
          style: IconButton.styleFrom(
            backgroundColor:
                const Color(0xFFFFEEEE),
            foregroundColor:
                const Color(0xFFDC2626),
            minimumSize: Size(
              mobile ? 44 : 38,
              mobile ? 44 : 38,
            ),
          ),
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _mobileInfoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: _primary,
        ),
        const SizedBox(width: 9),
        Text(
          '$label:',
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 50,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Something went wrong',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchEmployees,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(45),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              color: _primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No users found',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create a new employee account to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    final isEditMode =
        _editingEmployee != null;

    final activeRoles =
        _getActiveRoleOptions();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < 760;

        return SingleChildScrollView(
          padding: EdgeInsets.all(
            isMobile ? 14 : 24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildFormHero(
                isEditMode,
                isMobile,
              ),

              const SizedBox(height: 20),

              if (_modalError != null)
                _buildFormError(),

              if (_modalError != null)
                const SizedBox(height: 16),

              Container(
                padding: EdgeInsets.all(
                  isMobile ? 18 : 28,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    isMobile ? 20 : 24,
                  ),
                  border: Border.all(
                    color: _border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.025,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(
                      'Personal Information',
                      Icons.person_outline_rounded,
                    ),

                    const SizedBox(height: 18),

                    _responsiveFields(
                      isMobile: isMobile,
                      children: [
                        _modernTextField(
                          controller:
                              _firstNameCtrl,
                          label: 'First Name *',
                          hint: 'Enter first name',
                          icon:
                              Icons.person_outline_rounded,
                        ),
                        _modernTextField(
                          controller:
                              _middleNameCtrl,
                          label: 'Middle Name',
                          hint: 'Optional',
                          icon:
                              Icons.person_outline_rounded,
                        ),
                        _modernTextField(
                          controller:
                              _lastNameCtrl,
                          label: 'Last Name *',
                          hint: 'Enter last name',
                          icon:
                              Icons.person_outline_rounded,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    _sectionLabel(
                      'Account Configuration',
                      Icons.manage_accounts_outlined,
                    ),

                    const SizedBox(height: 18),

                    _responsiveFields(
                      isMobile: isMobile,
                      children: [
                        _buildUserTypeSelector(),
                        _modernDropdown(
                          label: 'Role *',
                          icon:
                              Icons.work_outline_rounded,
                          value:
                              activeRoles.contains(
                            _selectedRole,
                          )
                                  ? _selectedRole
                                  : null,
                          hint: activeRoles.isEmpty
                              ? 'No roles available'
                              : 'Select role',
                          items: activeRoles,
                          onChanged: (value) {
                            if (value == null) return;

                            setState(() {
                              _selectedRole = value;
                            });
                          },
                        ),
                        _modernTextField(
                          controller:
                              _staffIdCtrl,
                          label: 'Staff ID *',
                          hint: 'Enter staff ID',
                          icon:
                              Icons.badge_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _responsiveFields(
                      isMobile: isMobile,
                      children: [
                        _modernTextField(
                          controller: _emailCtrl,
                          label: 'Email Address *',
                          hint: 'employee@godigital.in',
                          icon:
                              Icons.email_outlined,
                        ),
                        _modernTextField(
                          controller:
                              _usernameCtrl,
                          label: 'Username *',
                          hint: 'Enter username',
                          icon:
                              Icons.alternate_email_rounded,
                        ),
                        _modernTextField(
                          controller:
                              _passwordCtrl,
                          label: isEditMode
                              ? 'New Password'
                              : 'Password *',
                          hint: isEditMode
                              ? 'Leave blank to keep current'
                              : 'Minimum 6 characters',
                          icon:
                              Icons.lock_outline_rounded,
                          isPassword: true,
                        ),
                      ],
                    ),

                    if (_selectedUserType ==
                        'admin') ...[
                      const SizedBox(height: 20),
                      _buildMainAdminToggle(),
                    ],

                    const SizedBox(height: 30),

                    _sectionLabel(
                      _selectedUserType == 'admin'
                          ? 'Admin Access Permissions'
                          : 'Employee Access Permissions',
                      Icons.security_rounded,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _isMainAdmin &&
                              _selectedUserType ==
                                  'admin'
                          ? 'Main admin has complete access to all platform modules.'
                          : 'Select the modules this user can access.',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildPermissionGrid(
                      isMobile,
                    ),

                    const SizedBox(height: 28),

                    Container(
                      height: 1,
                      color: _border,
                    ),

                    const SizedBox(height: 18),

                    isMobile
                        ? Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child:
                                    OutlinedButton(
                                  onPressed:
                                      _isSubmitting
                                          ? null
                                          : _closeForm,
                                  style:
                                      OutlinedButton.styleFrom(
                                    foregroundColor:
                                        _muted,
                                    side:
                                        const BorderSide(
                                      color: _border,
                                    ),
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      vertical: 16,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        14,
                                      ),
                                    ),
                                  ),
                                  child:
                                      const Text(
                                    'Cancel',
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              SizedBox(
                                width: double.infinity,
                                child:
                                    _buildSubmitButton(
                                  isEditMode,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment:
                                MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed:
                                    _isSubmitting
                                        ? null
                                        : _closeForm,
                                style:
                                    OutlinedButton.styleFrom(
                                  foregroundColor:
                                      _muted,
                                  side:
                                      const BorderSide(
                                    color: _border,
                                  ),
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      14,
                                    ),
                                  ),
                                ),
                                child:
                                    const Text('Cancel'),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              _buildSubmitButton(
                                isEditMode,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormHero(
    bool isEditMode,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isMobile ? 20 : 24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _primaryDark,
            _primary,
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Wrap(
        alignment:
            WrapAlignment.spaceBetween,
        runSpacing: 16,
        crossAxisAlignment:
            WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Icon(
                  isEditMode
                      ? Icons.edit_rounded
                      : Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditMode
                        ? 'Edit Employee'
                        : 'Create Employee',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          isMobile ? 21 : 25,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEditMode
                        ? 'Update account details and permissions.'
                        : 'Configure a new secure employee account.',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.78,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _closeForm,
            icon: const Icon(
              Icons.arrow_back_rounded,
              size: 17,
            ),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(
                  alpha: 0.40,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _modalError!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTypeSelector() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'User Type *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: _border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _typeChoice(
                  label: 'Employee',
                  icon:
                      Icons.person_outline_rounded,
                  selected:
                      _selectedUserType ==
                          'employee',
                  onTap: () {
                    setState(() {
                      _selectedUserType =
                          'employee';
                      _isMainAdmin = false;

                      final roles =
                          _getActiveRoleOptions();

                      _selectedRole =
                          roles.isNotEmpty
                              ? roles.first
                              : '';
                    });
                  },
                ),
              ),
              Expanded(
                child: _typeChoice(
                  label: 'Admin',
                  icon:
                      Icons.admin_panel_settings_outlined,
                  selected:
                      _selectedUserType ==
                          'admin',
                  onTap: () {
                    setState(() {
                      _selectedUserType =
                          'admin';

                      final roles =
                          _getActiveRoleOptions();

                      _selectedRole =
                          roles.isNotEmpty
                              ? roles.first
                              : '';
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeChoice({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? _primary
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Colors.white
                  : _muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainAdminToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8ED),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFBE1B4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE9C5),
              borderRadius:
                  BorderRadius.all(
                Radius.circular(13),
              ),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Color(0xFFE67E22),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Main Administrator',
                  style: TextStyle(
                    color: _ink,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Full access to all platform modules',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isMainAdmin,
            activeThumbColor: Colors.white,
            activeTrackColor:
                const Color(0xFFE67E22),
            onChanged: (value) {
              setState(() {
                _isMainAdmin = value;

                if (_isMainAdmin) {
                  _selectedPermissions =
                      availablePages
                          .map(
                            (page) =>
                                page['route']!,
                          )
                          .toList();
                } else {
                  _selectedPermissions.clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionGrid(
    bool isMobile,
  ) {
    final currentPagesList =
        _selectedUserType == 'admin'
            ? adminPages
            : employeePages;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: _border,
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: currentPagesList.map((page) {
          final route = page['route']!;

          final isLocked =
              _selectedUserType == 'admin' &&
                  _isMainAdmin;

          final isChecked = isLocked ||
              _selectedPermissions
                  .contains(route);

          return SizedBox(
            width: isMobile
                ? double.infinity
                : 250,
            child: InkWell(
              onTap: isLocked
                  ? null
                  : () {
                      setState(() {
                        if (isChecked) {
                          _selectedPermissions
                              .remove(route);
                        } else {
                          _selectedPermissions
                              .add(route);
                        }
                      });
                    },
              borderRadius:
                  BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 160,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isChecked
                      ? _primaryLight
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color: isChecked
                        ? _primary.withValues(
                            alpha: 0.35,
                          )
                        : _border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isChecked
                          ? Icons
                              .check_circle_rounded
                          : Icons
                              .radio_button_unchecked_rounded,
                      size: 18,
                      color: isChecked
                          ? _primary
                          : const Color(
                              0xFF94A3B8,
                            ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        page['title']!,
                        style: TextStyle(
                          color: isChecked
                              ? _primaryDark
                              : _muted,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isLocked)
                      const Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: Color(0xFFE67E22),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubmitButton(
    bool isEditMode,
  ) {
    return ElevatedButton(
      onPressed:
          _isSubmitting ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 17,
        ),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isEditMode
                      ? Icons
                          .save_as_rounded
                      : Icons
                          .person_add_alt_1_rounded,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditMode
                      ? 'Update Employee'
                      : 'Create Employee',
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _responsiveFields({
    required bool isMobile,
    required List<Widget> children,
  }) {
    if (isMobile) {
      return Column(
        children: [
          for (int i = 0;
              i < children.length;
              i++) ...[
            children[i],
            if (i != children.length - 1)
              const SizedBox(height: 16),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        for (int i = 0;
            i < children.length;
            i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1)
            const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _sectionLabel(
    String text,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: _primaryLight,
            borderRadius:
                BorderRadius.all(
              Radius.circular(10),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: _primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _modernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(
            fontSize: 13,
            color: _ink,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
            prefixIcon: Icon(
              icon,
              size: 19,
              color: _primary,
            ),
            filled: true,
            fillColor: _surface,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: _border,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: _primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modernDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _primary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 19,
              color: _primary,
            ),
            filled: true,
            fillColor: _surface,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: _border,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: _primary,
                width: 1.5,
              ),
            ),
          ),
          hint: Text(
            hint,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          items: items
              .map(
                (role) =>
                    DropdownMenuItem<String>(
                  value: role,
                  child: Text(
                    role,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _ink,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged:
              items.isEmpty ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildDialogDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>>
        items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: _surface,
            prefixIcon: const Icon(
              Icons.category_outlined,
              color: _primary,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: _border,
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: _border,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts.first
          .substring(0, 1)
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }

  static const TextStyle _tableHeading =
      TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    color: _muted,
    letterSpacing: 0.7,
  );
}
