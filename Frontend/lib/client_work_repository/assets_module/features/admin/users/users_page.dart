import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<Map<String, dynamic>> _users = [];

  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await ApiService.getUsers();

      if (!mounted) return;

      setState(() {
        _users = result
            .whereType<Map>()
            .map(
              (user) => Map<String, dynamic>.from(user),
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _cleanError(e),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _users;
    }

    return _users.where((user) {
      final name =
          user['name']?.toString().toLowerCase() ?? '';
      final email =
          user['email']?.toString().toLowerCase() ?? '';
      final mobile =
          user['mobile']?.toString().toLowerCase() ?? '';
      final role =
          user['role']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          email.contains(query) ||
          mobile.contains(query) ||
          role.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSearch(),
          const SizedBox(height: 20),
          _buildUserList(users),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Users',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Manage portal users and their access.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _showCreateUserDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add User'),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isLoading ? null : _loadUsers,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText:
            'Search by name, email, mobile or role...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.clear),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users,
  ) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (users.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 52,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 14),
                Text(
                  _searchQuery.isEmpty
                      ? 'No users found.'
                      : 'No users match your search.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < users.length; i++) ...[
            _buildUserTile(users[i]),
            if (i < users.length - 1)
              const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildUserTile(
    Map<String, dynamic> user,
  ) {
    final userId = user['id']?.toString() ?? '';

    final name =
        user['name']?.toString() ?? 'Unknown User';

    final email =
        user['email']?.toString() ?? '';

    final mobile =
        user['mobile']?.toString() ?? '';

    final role =
        user['role']?.toString() ?? 'User';

    final isActive = _readActiveStatus(user);

    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      leading: CircleAvatar(
        child: Text(initial),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 5,
          crossAxisAlignment:
              WrapCrossAlignment.center,
          children: [
            Text(email),
            if (mobile.isNotEmpty)
              Text('• $mobile'),
            _roleBadge(role),
            _statusBadge(isActive),
          ],
        ),
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          Switch(
            value: isActive,
            onChanged: userId.isEmpty
                ? null
                : (value) {
                    _changeStatus(
                      userId,
                      value,
                    );
                  },
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: userId.isEmpty
                ? null
                : () {
                    _showEditUserDialog(user);
                  },
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: userId.isEmpty
                ? null
                : () {
                    _confirmDeleteUser(user);
                  },
            icon: const Icon(
              Icons.delete_outline,
            ),
          ),
        ],
      ),
    );
  }

  bool _readActiveStatus(
    Map<String, dynamic> user,
  ) {
    final value =
        user['is_active'] ?? user['isActive'];

    if (value == true || value == 1) {
      return true;
    }

    if (value?.toString() == '1' ||
        value?.toString().toLowerCase() == 'true') {
      return true;
    }

    return false;
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color:
            AppColors.primary.withValues(alpha: 0.10),
      ),
      child: Text(
        role,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: active
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.red.withValues(alpha: 0.10),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active
              ? Colors.green.shade700
              : Colors.red.shade700,
        ),
      ),
    );
  }

  void _showCreateUserDialog() {
    _showUserDialog();
  }

  void _showEditUserDialog(
    Map<String, dynamic> user,
  ) {
    _showUserDialog(user: user);
  }

  void _showUserDialog({
    Map<String, dynamic>? user,
  }) {
    final isEdit = user != null;

    final nameController = TextEditingController(
      text: user?['name']?.toString() ?? '',
    );

    final emailController = TextEditingController(
      text: user?['email']?.toString() ?? '',
    );

    final mobileController = TextEditingController(
      text: user?['mobile']?.toString() ?? '',
    );

    final passwordController =
        TextEditingController();

    String selectedRole =
        user?['role']?.toString() ?? 'User';

    bool obscurePassword = true;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            Future<void> saveUser() async {
              final name =
                  nameController.text.trim();

              final email =
                  emailController.text.trim();

              final mobile =
                  mobileController.text.trim();

              final password =
                  passwordController.text;

              if (name.isEmpty) {
                _dialogError(
                  dialogContext,
                  'Please enter the name.',
                );
                return;
              }

              if (email.isEmpty) {
                _dialogError(
                  dialogContext,
                  'Please enter the email.',
                );
                return;
              }

              if (!email.contains('@')) {
                _dialogError(
                  dialogContext,
                  'Please enter a valid email address.',
                );
                return;
              }

              if (!isEdit && password.isEmpty) {
                _dialogError(
                  dialogContext,
                  'Please enter a password.',
                );
                return;
              }

              if (password.isNotEmpty &&
                  password.length < 6) {
                _dialogError(
                  dialogContext,
                  'Password must contain at least 6 characters.',
                );
                return;
              }

              final userId =
                  user?['id']?.toString();

              if (isEdit &&
                  (userId == null ||
                      userId.isEmpty)) {
                _dialogError(
                  dialogContext,
                  'Invalid user ID.',
                );
                return;
              }

              setDialogState(() {
                saving = true;
              });

              try {
                if (isEdit) {
                  await ApiService.updateUser(
                    userId: userId!,
                    name: name,
                    email: email,
                    mobile: mobile.isEmpty
                        ? null
                        : mobile,
                    role: selectedRole,
                    password: password.isEmpty
                        ? null
                        : password,
                  );
                } else {
                  await ApiService.createUser(
                    name: name,
                    email: email,
                    mobile: mobile.isEmpty
                        ? null
                        : mobile,
                    password: password,
                    role: selectedRole,
                  );
                }

                if (!mounted) return;

                Navigator.of(
                  dialogContext,
                ).pop();

                _showMessage(
                  isEdit
                      ? 'User updated successfully.'
                      : 'User created successfully.',
                );

                await _loadUsers();
              } catch (e) {
                setDialogState(() {
                  saving = false;
                });

                _dialogError(
                  dialogContext,
                  _cleanError(e),
                );
              }
            }

            return AlertDialog(
              title: Text(
                isEdit
                    ? 'Edit User'
                    : 'Create User',
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      TextField(
                        controller:
                            nameController,
                        enabled: !saving,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          labelText: 'Name',
                          hintText:
                              'Enter full name',
                          prefixIcon: Icon(
                            Icons.person_outline,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      TextField(
                        controller:
                            emailController,
                        enabled: !saving,
                        keyboardType:
                            TextInputType
                                .emailAddress,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          labelText: 'Email',
                          hintText:
                              'Enter email address',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      TextField(
                        controller:
                            mobileController,
                        enabled: !saving,
                        keyboardType:
                            TextInputType.phone,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            const InputDecoration(
                          labelText: 'Mobile',
                          hintText:
                              'Enter mobile number',
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      TextField(
                        controller:
                            passwordController,
                        enabled: !saving,
                        obscureText:
                            obscurePassword,
                        decoration:
                            InputDecoration(
                          labelText: isEdit
                              ? 'New Password (optional)'
                              : 'Password',
                          hintText: isEdit
                              ? 'Leave blank to keep current password'
                              : 'Enter password',
                          prefixIcon:
                              const Icon(
                            Icons.lock_outline,
                          ),
                          suffixIcon:
                              IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword =
                                    !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons
                                      .visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      DropdownButtonFormField<
                          String>(
                        initialValue:
                            selectedRole,
                        decoration:
                            const InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(
                            Icons
                                .admin_panel_settings_outlined,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'User',
                            child:
                                Text('User'),
                          ),
                          DropdownMenuItem(
                            value: 'Admin',
                            child:
                                Text('Admin'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                setDialogState(() {
                                  selectedRole =
                                      value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child:
                      const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      saving ? null : saveUser,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit
                              ? 'Save Changes'
                              : 'Create',
                        ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      emailController.dispose();
      mobileController.dispose();
      passwordController.dispose();
    });
  }

  Future<void> _changeStatus(
    String userId,
    bool isActive,
  ) async {
    try {
      await ApiService.updateUserStatus(
        userId: userId,
        isActive: isActive,
      );

      if (!mounted) return;

      _showMessage(
        isActive
            ? 'User activated successfully.'
            : 'User deactivated successfully.',
      );

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _cleanError(e),
        isError: true,
      );
    }
  }

  Future<void> _confirmDeleteUser(
    Map<String, dynamic> user,
  ) async {
    final userId =
        user['id']?.toString() ?? '';

    if (userId.isEmpty) {
      _showMessage(
        'Invalid user ID.',
        isError: true,
      );
      return;
    }

    final name =
        user['name']?.toString() ??
            'this user';

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Delete User'),
          content: Text(
            'Are you sure you want to delete '
            '"$name"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteUser(userId);

      if (!mounted) return;

      _showMessage(
        'User deleted successfully.',
      );

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _cleanError(e),
        isError: true,
      );
    }
  }

  void _dialogError(
    BuildContext dialogContext,
    String message,
  ) {
    ScaffoldMessenger.of(
      dialogContext,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : null,
      ),
    );
  }
}