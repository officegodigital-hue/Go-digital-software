import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:godigital_portal/services/authenticated_http.dart' as http;

import '../../layouts/admin_layout.dart';
import '../../core/keyboard/keyboard_shortcuts.dart';
import '../../services/api_config.dart';
import '../role_sop_viewer_dialog.dart';
import 'widgets/role_sop_card.dart';

class RoleSopMasterScreen extends StatefulWidget {
  const RoleSopMasterScreen({super.key});

  @override
  State<RoleSopMasterScreen> createState() => _RoleSopMasterScreenState();
}

class _RoleSopMasterScreenState extends State<RoleSopMasterScreen> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final TextEditingController _titleController = TextEditingController();
  List<Map<String, dynamic>> _roles = [];
  Map<int, Map<String, dynamic>> _sopsByRole = {};
  int? _selectedRoleId;
  int? _editingRoleId;
  PlatformFile? _selectedFile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rolesResponse = await http.get(
        Uri.parse('$_baseUrl/employees/user-roles'),
        headers: const {'Accept': 'application/json'},
      );
      final sopsResponse = await http.get(
        Uri.parse('$_baseUrl/role-sops'),
        headers: const {'Accept': 'application/json'},
      );
      if (rolesResponse.statusCode != 200 || sopsResponse.statusCode != 200) {
        throw Exception(
          'Server returned ${rolesResponse.statusCode}/${sopsResponse.statusCode}.',
        );
      }

      final rolesBody = jsonDecode(rolesResponse.body);
      final sopsBody = jsonDecode(sopsResponse.body);
      final rawRoles = rolesBody is Map ? rolesBody['data'] : rolesBody;
      final rawSops = sopsBody is Map ? sopsBody['data'] : sopsBody;
      final roles = rawRoles is List
          ? rawRoles.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      final sops = rawSops is List
          ? rawSops.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      final sopsByRole = <int, Map<String, dynamic>>{};
      for (final sop in sops) {
        final id = int.tryParse('${sop['role_id'] ?? ''}');
        if (id != null) sopsByRole[id] = sop;
      }
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _sopsByRole = sopsByRole;
        final availableRoleIds = roles
            .map((role) => int.tryParse('${role['id'] ?? ''}'))
            .whereType<int>()
            .toList();
        if (_selectedRoleId == null ||
            !availableRoleIds.contains(_selectedRoleId)) {
          _selectedRoleId = availableRoleIds.isEmpty
              ? null
              : availableRoleIds.first;
        }
        _syncSelectedRole();
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to load role SOPs: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncSelectedRole() {
    final sop = _selectedRoleId == null ? null : _sopsByRole[_selectedRoleId];
    _titleController.text =
        sop?['title']?.toString() ?? _roleName(_selectedRoleId) ?? '';
    _selectedFile = null;
  }

  void _editRole(int roleId) {
    setState(() {
      _selectedRoleId = roleId;
      _syncSelectedRole();
      _editingRoleId = roleId;
    });
  }

  void _goBack() {
    if (_editingRoleId != null) {
      setState(() {
        _editingRoleId = null;
        _selectedFile = null;
      });
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/admin-panel');
    }
  }

  Future<void> _viewSop(Map<String, dynamic> document) async {
    await showDialog<void>(
      context: context,
      builder: (_) => RoleSopViewerDialog(documents: [document]),
    );
  }

  Future<void> _deleteSop(int roleId) async {
    final roleName = _roleName(roleId) ?? 'this role';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => KeyboardSubmit(
        autofocus: true,
        onSubmit: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
        child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('Delete SOP PDF'),
        content: Text(
          'Remove the SOP PDF for $roleName? Employees with this role will no '
          'longer see it. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/role-sops/$roleId'),
        headers: const {'Accept': 'application/json'},
      );
      final body = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true) {
        throw Exception(
          body['message'] ?? 'Server returned ${response.statusCode}.',
        );
      }
      if (!mounted) return;
      _showMessage('SOP deleted for $roleName.');
      await _load();
    } catch (error) {
      if (mounted) _showMessage('Unable to delete SOP: $error');
    }
  }

  String? _roleName(int? roleId) {
    for (final role in _roles) {
      if (int.tryParse('${role['id'] ?? ''}') == roleId) {
        return role['role_name']?.toString();
      }
    }
    return null;
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      _showMessage('Unable to read the selected PDF.');
      return;
    }
    setState(() => _selectedFile = file);
  }

  Future<void> _save() async {
    final roleId = _selectedRoleId;
    final file = _selectedFile;
    if (roleId == null || file?.bytes == null) {
      _showMessage('Select a role and PDF file before saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      final request =
          http.MultipartRequest('PUT', Uri.parse('$_baseUrl/role-sops/$roleId'))
            ..fields['title'] = _titleController.text.trim()
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                file!.bytes!,
                filename: file.name,
              ),
            );
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final body = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true) {
        throw Exception(
          body['message'] ?? 'Server returned ${response.statusCode}.',
        );
      }
      if (!mounted) return;
      setState(() => _selectedFile = null);
      _showMessage('SOP saved for ${_roleName(roleId)}.');
      await _load();
      if (mounted) setState(() => _editingRoleId = null);
    } catch (error) {
      if (mounted) _showMessage('Unable to save SOP: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Role-Based SOP',
      currentRoute: '/role-sop-master',
      onSearch: (_) {},
      child: KeyboardSaveScope(
        onSave: () {
          if (!_saving && _editingRoleId != null) _save();
        },
        child: _buildSopBody(),
      ),
    );
  }

  Widget _buildSopBody() {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _roles.isEmpty
          ? _buildEmptyState()
          : _editingRoleId == null
          ? _buildRoleCards()
          : _buildEditor();
  }

  Widget _buildPageHeader(String subtitle) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: _editingRoleId == null ? 'Back' : 'Back to roles',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editingRoleId == null
                    ? 'Role-Based SOP'
                    : 'Edit ${_roleName(_editingRoleId)} SOP',
                style: const TextStyle(
                  color: Color(0xFF14213D),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPageHeader('Add a role-specific procedure for your team.'),
          const Expanded(
            child: Center(
              child: Text('Create a role in Role Master before adding an SOP.'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(
                    'Choose a role to add, update, or view its SOP PDF.',
                  ),
                  const SizedBox(height: 22),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _roles.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: columns == 1 ? 1.8 : 1.45,
                    ),
                    itemBuilder: (context, index) {
                      final role = _roles[index];
                      final roleId = int.tryParse('${role['id'] ?? ''}');
                      if (roleId == null) return const SizedBox.shrink();
                      final document = _sopsByRole[roleId];
                      return RoleSopCard(
                        roleName: _roleName(roleId) ?? 'Role',
                        document: document,
                        colorIndex: index,
                        onAddOrEdit: () => _editRole(roleId),
                        onView: document == null
                            ? null
                            : () => _viewSop(document),
                        onDelete: document == null
                            ? null
                            : () => _deleteSop(roleId),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditor() {
    final currentSop = _selectedRoleId == null
        ? null
        : _sopsByRole[_selectedRoleId];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(
                'Upload a new PDF or replace the current one for this role.',
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFD9E5FF)),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF4F7FF), Colors.white],
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF315EF6), Color(0xFF7C4DFF)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _roleName(_selectedRoleId) ?? 'Selected role',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFF14213D),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload one PDF for each role. Employees assigned that role can open it from their home workspace.',
                        style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _titleController,
                        maxLength: 180,
                        decoration: const InputDecoration(
                          labelText: 'SOP title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (currentSop != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFB8E8D8)),
                          ),
                          child: Text(
                            'Current PDF: ${currentSop['file_name'] ?? 'Uploaded'}',
                            style: const TextStyle(
                              color: Color(0xFF166B50),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (currentSop != null) ...[
                        const SizedBox(height: 2),
                        OutlinedButton.icon(
                          onPressed: () => _viewSop(currentSop),
                          icon: const Icon(Icons.visibility_rounded),
                          label: const Text('View current PDF'),
                        ),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _selectedFile?.name ??
                              (currentSop == null
                                  ? 'Choose PDF'
                                  : 'Choose replacement PDF'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'PDF only, maximum 25 MB. Saving replaces the current SOP for this role.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _editingRoleId = null),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _saving
                                    ? 'Saving...'
                                    : currentSop == null
                                    ? 'Add SOP PDF'
                                    : 'Update SOP PDF',
                              ),
                            ),
                          ),
                        ],
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
  }
}
