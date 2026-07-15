import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../layouts/admin_layout.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {

  static const String _baseUrl = '/api';

  List<Map<String, dynamic>> employeeUsers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  // ── FETCH ─────────────────────────────────────────────────────────────────────
  Future<void> _fetchEmployees() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(Uri.parse('$_baseUrl/employees'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          employeeUsers = List<Map<String, dynamic>>.from(body['data']);
          _loading = false;
        });
      } else {
        setState(() { _error = 'Server returned ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── CREATE — returns null on success, error string on failure ─────────────────
  Future<String?> _createEmployee(Map<String, String> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/employees'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) { _fetchEmployees(); return null; }
      return jsonDecode(response.body)['message'] ?? 'Failed to create employee';
    } catch (e) {
      return 'Cannot connect to server';
    }
  }

  // ── UPDATE — PUT /api/employees/:id ────────────────────────────────────────────
  Future<String?> _updateEmployee(int id, Map<String, String> data) async {
  try {
    final url = Uri.parse('$_baseUrl/employees/$id');
    print('PUT URL: $url');
    print('PUT Body: ${jsonEncode(data)}');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    print('PUT Status: ${response.statusCode}');
    print('PUT Response: ${response.body}');

    if (response.statusCode == 200) {
      _fetchEmployees();
      return null;
    }
    return jsonDecode(response.body)['message'] ?? 'Failed to update employee';
  } catch (e) {
    print('PUT Error: $e');           // ← real error shows here
    return e.toString();              // ← shows in modal instead of generic message
  }
}
  // ── FETCH single employee for edit (gets first/middle/last names) ─────────────
  Future<Map<String, dynamic>?> _fetchSingleEmployee(int id) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/employees/$id'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── TOGGLE STATUS ─────────────────────────────────────────────────────────────
  Future<void> _toggleStatus(int id, bool currentStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/employees/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isActive': !currentStatus}),
      );
      if (response.statusCode == 200) {
        _fetchEmployees();
      } else {
        _showSnack('Failed to update status');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────────
  Future<void> _deleteEmployee(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/employees/$id'));
      if (response.statusCode == 200) {
        _fetchEmployees();
        _showSnack('Employee deleted', success: true);
      } else {
        _showSnack('Failed to delete employee');
      }
    } catch (e) {
      _showSnack('Cannot connect to server');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF16A34A) : Colors.redAccent,
    ));
  }

  // ── MODAL — used for both Create and Edit ─────────────────────────────────────
  // editEmployee: null = Create mode, non-null = Edit mode
void _showUserModal(BuildContext context, {Map<String, dynamic>? editEmployee}) {
    final isEditMode = editEmployee != null;

    final firstNameCtrl  = TextEditingController(text: editEmployee?['first_name']  ?? '');
    final middleNameCtrl = TextEditingController(text: editEmployee?['middle_name'] ?? '');
    final lastNameCtrl   = TextEditingController(text: editEmployee?['last_name']   ?? '');
    final staffIdCtrl    = TextEditingController(text: editEmployee?['staff_id']    ?? '');
    final emailCtrl      = TextEditingController(text: editEmployee?['email']       ?? '');
    final usernameCtrl   = TextEditingController(text: editEmployee?['username']    ?? '');
    final passwordCtrl   = TextEditingController();

    String selectedRole = editEmployee?['role'] ?? 'Graphic Designer';
    String selectedUserType = editEmployee?['user_type'] ?? 'employee'; // NEW

    final roleOptions = ['UI/ UX Designer', 'Graphic Designer', 'Digital Marketing',
                         'Video Editor', 'Web Developer', 'Page Handler', 'Ads Handler'];
    final userTypeOptions = ['employee', 'admin']; // NEW

    if (!roleOptions.contains(selectedRole)) selectedRole = 'Graphic Designer';
    if (!userTypeOptions.contains(selectedUserType)) selectedUserType = 'employee'; // NEW

    bool sendEmail    = true;
    bool isSubmitting = false;
    String? modalError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {

          Future<void> handleSubmit() async {
            if (firstNameCtrl.text.isEmpty || lastNameCtrl.text.isEmpty ||
                staffIdCtrl.text.isEmpty   || emailCtrl.text.isEmpty    ||
                usernameCtrl.text.isEmpty) {
              setModal(() => modalError = 'Please fill all required fields (*)');
              return;
            }
            if (!isEditMode && passwordCtrl.text.isEmpty) {
              setModal(() => modalError = 'Password is required');
              return;
            }

            setModal(() { isSubmitting = true; modalError = null; });

            final data = {
              'firstName':  firstNameCtrl.text.trim(),
              'middleName': middleNameCtrl.text.trim(),
              'lastName':   lastNameCtrl.text.trim(),
              'staffId':    staffIdCtrl.text.trim(),
              'email':      emailCtrl.text.trim(),
              'username':   usernameCtrl.text.trim(),
              'role':       selectedRole,
              'userType':   selectedUserType, // NEW
              if (passwordCtrl.text.isNotEmpty) 'password': passwordCtrl.text,
            };

            String? error;
            if (isEditMode) {
              error = await _updateEmployee(editEmployee!['id'], data);
            } else {
              error = await _createEmployee({...data, 'password': passwordCtrl.text});
            }

            if (error == null) {
              if (ctx.mounted) Navigator.pop(ctx);
              _showSnack(
                isEditMode ? 'Employee updated successfully' : 'Employee created successfully',
                success: true,
              );
            } else {
              setModal(() { isSubmitting = false; modalError = error; });
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 24,
            child: Container(
              width: 680,
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditMode ? 'Edit Staff User' : 'Create Staff User',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),

                    if (modalError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 18, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(modalError!,
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600, color: Color(0xFFDC2626)))),
                          GestureDetector(
                            onTap: () => setModal(() => modalError = null),
                            child: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Name row
                    Row(children: [
                      Expanded(child: _field('First Name *',  firstNameCtrl,  hint: 'Pavithra')),
                      const SizedBox(width: 12),
                      Expanded(child: _field('Middle Name',   middleNameCtrl, hint: 'C')),
                      const SizedBox(width: 12),
                      Expanded(child: _field('Last Name *',   lastNameCtrl,   hint: 'Employee')),
                    ]),
                    const SizedBox(height: 16),

                    // Staff ID + Role
                    Row(children: [
                      Expanded(child: _field('Staff ID *', staffIdCtrl, hint: '4509836')),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Role *', style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedRole,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 18, color: Color(0xFF64748B)),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A)),
                              items: roleOptions
                                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                  .toList(),
                              onChanged: (v) => setModal(() => selectedRole = v!),
                            ),
                          ),
                        ),
                      ])),
                    ]),
                    const SizedBox(height: 16),

                    // Email + User Type (NEW)
                    Row(children: [
                      Expanded(child: _field('Email Address *', emailCtrl, hint: 'staff@godigital.in')),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('User Type *', style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedUserType,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 18, color: Color(0xFF64748B)),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A)),
                              items: userTypeOptions
                                  .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u[0].toUpperCase() + u.substring(1)), // Capitalize
                                  ))
                                  .toList(),
                              onChanged: (v) => setModal(() => selectedUserType = v!),
                            ),
                          ),
                        ),
                      ])),
                    ]),
                    const SizedBox(height: 16),

                    // Username
                    _field('Username *', usernameCtrl, hint: 'pavithra'),
                    const SizedBox(height: 16),

                    // Password
                    _field(
                      isEditMode ? 'New Password (leave blank to keep current)' : 'Password *',
                      passwordCtrl,
                      hint: isEditMode ? 'Leave blank to keep existing' : 'Min 8 chars',
                      isPassword: true,
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(
                          isEditMode ? Icons.edit_note_rounded : Icons.lock_outline_rounded,
                          size: 18, color: const Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(
                          isEditMode
                              ? 'Editing employee details. Leave the password field blank to keep the current password unchanged.'
                              : 'Password will be hashed and stored securely. Ask the employee to change it on first login.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                        )),
                      ]),
                    ),

                    if (!isEditMode) ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        SizedBox(width: 20, height: 20,
                          child: Checkbox(
                            value: sendEmail,
                            activeColor: const Color(0xFF0052CC),
                            onChanged: (v) => setModal(() => sendEmail = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Send welcome email to staff user',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: Color(0xFF334155))),
                      ]),
                    ],

                    const SizedBox(height: 24),

                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEditMode
                              ? const Color(0xFF0052CC)
                              : const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                isEditMode ? 'Update' : 'Create',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Admin Panel',
      currentRoute: '/admin-panel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('User Access Management',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A))),
                SizedBox(height: 4),
                Text('Securely manage user roles, permissions, and access across the platform.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ]),
              Row(children: [
                IconButton(
                  onPressed: _fetchEmployees,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0052CC)),
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showUserModal(context),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052CC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    elevation: 0,
                  ),
                  label: const Text('Create Employee User',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
            ],
          ),

          const SizedBox(height: 28),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFFF8FAFC),
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: const [
                    Expanded(flex: 4, child: Text('Employee Name', style: _headingStyle)),
                    Expanded(flex: 3, child: Text('Employee ID',   style: _headingStyle)),
                    Expanded(flex: 4, child: Text('Role',          style: _headingStyle)),
                    Expanded(flex: 2, child: Text('Status',
                        textAlign: TextAlign.center, style: _headingStyle)),
                    SizedBox(width: 100, child: Text('Actions',
                        textAlign: TextAlign.center, style: _headingStyle)),
                  ]),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                if (_loading)
                  const Padding(padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0052CC))))
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Column(children: [
                      const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchEmployees,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052CC)),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ])),
                  )
                else if (employeeUsers.isEmpty)
                  const Padding(padding: EdgeInsets.all(40),
                    child: Center(child: Text('No employees yet. Create one to get started.',
                        style: TextStyle(color: Color(0xFF94A3B8)))))
                else
                  SizedBox(
                    height: 420,
                    child: ListView.separated(
                      itemCount: employeeUsers.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (_, index) {
                        final item   = employeeUsers[index];
                        final bool active =
                            (item['is_active'] == 1 || item['is_active'] == true);
                        final int id = item['id'] ?? 0;

                        return Container(
                          height: 62,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          color: Colors.white,
                          child: Row(children: [

                            // Avatar + Name
                            Expanded(flex: 4, child: Row(children: [
                              Container(
                                width: 26, height: 26,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFDCE4F7), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text(item['initials'] ?? '?',
                                    style: const TextStyle(fontSize: 10,
                                        fontWeight: FontWeight.w700, color: Color(0xFF4A69B3))),
                              ),
                              const SizedBox(width: 12),
                              Text(item['full_name'] ?? '',
                                  style: const TextStyle(fontSize: 13,
                                      color: Color(0xFF1E293B), fontWeight: FontWeight.w600)),
                            ])),

                            // Staff ID
                            Expanded(flex: 3, child: Text(item['staff_id'] ?? '',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155),
                                    fontWeight: FontWeight.w500))),

                            // Role
                            Expanded(flex: 4, child: Text(item['role'] ?? '',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155),
                                    fontWeight: FontWeight.w500))),

                            // Status toggle
                            Expanded(flex: 2, child: Center(
                              child: GestureDetector(
                                onTap: () => _toggleStatus(id, active),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    active ? 'ACTIVE' : 'IN-ACTIVE',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                                        color: active
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF64748B),
                                        letterSpacing: 0.2),
                                  ),
                                ),
                              ),
                            )),

                            // ── ACTIONS: Edit + Delete ───────────────────────
                            SizedBox(
                              width: 100,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [

                                  // Edit button
                                  Tooltip(
                                    message: 'Edit',
                                    child: GestureDetector(
                                      onTap: () async {
                                        // Fetch full employee data (includes first/last names)
                                        final data = await _fetchSingleEmployee(id);
                                        if (data != null && context.mounted) {
                                          _showUserModal(context, editEmployee: data);
                                        } else {
                                          _showSnack('Failed to load employee data');
                                        }
                                      },
                                      child: Container(
                                        width: 30, height: 30,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.edit_outlined,
                                            size: 15, color: Color(0xFF2563EB)),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Delete button
                                  Tooltip(
                                    message: 'Delete',
                                    child: GestureDetector(
                                      onTap: () => showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Delete Employee'),
                                          content: Text('Remove ${item['full_name']}?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _deleteEmployee(id);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFDC2626)),
                                              child: const Text('Delete',
                                                  style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      child: Container(
                                        width: 30, height: 30,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded,
                                            size: 15, color: Color(0xFFDC2626)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {required String hint, bool isPassword = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: Color(0xFF475569))),
      const SizedBox(height: 6),
      SizedBox(
        height: 38,
        child: TextField(
          controller: ctrl,
          obscureText: isPassword,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF0052CC))),
          ),
        ),
      ),
    ]);
  }

  static const TextStyle _headingStyle = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569));
}