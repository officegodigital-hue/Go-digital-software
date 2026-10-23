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
            .map((user) => Map<String, dynamic>.from(user))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e), isError: true);
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
      final name = user['name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      final mobile = user['mobile']?.toString().toLowerCase() ?? '';
      final role = user['role']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          email.contains(query) ||
          mobile.contains(query) ||
          role.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 700;
        final inset = narrow ? 16.0 : 32.0;
        return ColoredBox(
          color: const Color(0xFFF3F4F6),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(inset, 28, inset, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(narrow ? 16 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildSearch(),
                      const SizedBox(height: 20),
                      _buildUserList(users),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final title = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Users',
          style: TextStyle(
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Manage user access to company assets.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
    final addButton = ElevatedButton.icon(
      onPressed: _showCreateUserDialog,
      icon: const Icon(Icons.add, size: 17, color: Colors.white),
      label: const Text('Add user'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 14), addButton],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            addButton,
          ],
        );
      },
    );
  }

  Widget _buildSearch() {
    final search = SizedBox(
      height: 40,
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: 'Search users...',
          hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(
            Icons.search,
            size: 16,
            color: Color(0xFF9CA3AF),
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _searchQuery = ''),
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
          ),
        ),
      ),
    );
    final count = Text(
      '${_filteredUsers.length} users',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Color(0xFF6B7280),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [search, const SizedBox(height: 12), count],
          );
        }
        return Row(
          children: [
            SizedBox(width: 280, child: search),
            const Spacer(),
            count,
          ],
        );
      },
    );
  }

  /*
  Widget _buildHeaderLegacy() {
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
                  fontSize: 30,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage user access to company assets.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        // Right: Add user button
        ElevatedButton.icon(
          onPressed: _showCreateUserDialog,
          icon: const Icon(Icons.add, size: 17, color: Colors.white),
          label: const Text('Add user'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Search input — 280px, pill shape
        SizedBox(
          width: 280,
          height: 40,
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: const TextStyle(
                fontSize: 15,
                color: Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 16,
                color: Color(0xFF9CA3AF),
              ),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _searchQuery = ''),
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
              ),
            ),
          ),
        ),
        // User count
        Text(
          '${_filteredUsers.length} users',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  */

  // Colors for user avatars — cycles through a palette per index

  Widget _buildUserList(List<Map<String, dynamic>> users) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              for (int i = 0; i < users.length; i++) ...[
                _buildMobileUserCard(users[i]),
                if (i < users.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 840 ? 840 : constraints.maxWidth,
            child: Container(
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                children: [
                  _buildTableHeader(),
                  for (int i = 0; i < users.length; i++)
                    _buildUserRow(users[i], i),
                  // Footer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Text(
                      'Showing ${users.length} users.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
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
  }

  Widget _buildMobileUserCard(Map<String, dynamic> user) {
    final userId = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'Unknown User';
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'User';
    final isActive = _readActiveStatus(user);
    final initial = name.trim().isEmpty ? 'U' : name.trim()[0].toUpperCase();
    final (avatarBg, avatarFg) = _avatarColors(name);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: avatarFg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(_roleIcon(role), size: 16, color: const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  role,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              GestureDetector(
                onTap: userId.isEmpty
                    ? null
                    : () => _changeStatus(userId, !isActive),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: userId.isEmpty
                      ? null
                      : () => _showEditUserDialog(user),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: userId.isEmpty
                    ? null
                    : () => _confirmDeleteUser(user),
                tooltip: 'Delete user',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6B7280),
      letterSpacing: 0.5,
    );
    const p = EdgeInsets.symmetric(horizontal: 16);
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 28,
            child: Padding(
              padding: p,
              child: const Text('USER', style: style),
            ),
          ),
          Expanded(
            flex: 28,
            child: Padding(
              padding: p,
              child: const Text('EMAIL', style: style),
            ),
          ),
          Expanded(
            flex: 20,
            child: Padding(
              padding: p,
              child: const Text('ROLE', style: style),
            ),
          ),
          Expanded(
            flex: 14,
            child: Padding(
              padding: p,
              child: const Text('STATUS', style: style),
            ),
          ),
          Expanded(
            flex: 10,
            child: Padding(
              padding: p,
              child: const Text(
                'ACTIONS',
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Avatar color map by first initial
  static const _avatarColorMap = <String, (Color, Color)>{
    'A': (Color(0xFFEDE9FE), Color(0xFF7C3AED)),
    'G': (Color(0xFFEDE9FE), Color(0xFF7C3AED)),
    'H': (Color(0xFFDCFCE7), Color(0xFF16A34A)),
    'J': (Color(0xFFFEF3C7), Color(0xFFD97706)),
    'K': (Color(0xFFDCFCE7), Color(0xFF16A34A)),
    'M': (Color(0xFFFEE2E2), Color(0xFFDC2626)),
  };

  (Color, Color) _avatarColors(String name) {
    final ch = name.trim().isEmpty ? '' : name.trim()[0].toUpperCase();
    return _avatarColorMap[ch] ??
        (const Color(0xFFEFF6FF), const Color(0xFF2563EB));
  }

  IconData _roleIcon(String role) {
    switch (role.trim().toLowerCase()) {
      case 'page handler':
        return Icons.description_outlined;
      case 'ads handler':
        return Icons.campaign_outlined;
      case 'designer':
        return Icons.palette_outlined;
      case 'manager':
        return Icons.settings_outlined;
      default:
        return Icons.person_outline;
    }
  }

  Widget _buildUserRow(Map<String, dynamic> user, int index) {
    final userId = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'Unknown User';
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'User';
    final isActive = _readActiveStatus(user);
    final initial = name.trim().isEmpty ? 'U' : name.trim()[0].toUpperCase();
    final (avatarBg, avatarFg) = _avatarColors(name);
    const p = EdgeInsets.symmetric(horizontal: 16);

    return Container(
      height: 74,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Col 1: User (flex 28)
          Expanded(
            flex: 28,
            child: Padding(
              padding: p,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: avatarBg,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: avatarFg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Col 2: Email (flex 28)
          Expanded(
            flex: 28,
            child: Padding(
              padding: p,
              child: Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ),
          ),
          // Col 3: Role (flex 20)
          Expanded(
            flex: 20,
            child: Padding(
              padding: p,
              child: Row(
                children: [
                  Icon(
                    _roleIcon(role),
                    size: 15,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      role,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Col 4: Status (flex 14)
          Expanded(
            flex: 14,
            child: Padding(
              padding: p,
              child: GestureDetector(
                onTap: userId.isEmpty
                    ? null
                    : () => _changeStatus(userId, !isActive),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Col 5: Actions (flex 10)
          Expanded(
            flex: 10,
            child: Padding(
              padding: p,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: userId.isEmpty
                          ? null
                          : () => _showEditUserDialog(user),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: userId.isEmpty
                          ? null
                          : () => _confirmDeleteUser(user),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 17,
                        color: Color(0xFFDC2626),
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

  bool _readActiveStatus(Map<String, dynamic> user) {
    final value = user['is_active'] ?? user['isActive'];

    if (value == true || value == 1) {
      return true;
    }

    if (value?.toString() == '1' || value?.toString().toLowerCase() == 'true') {
      return true;
    }

    return false;
  }

  void _showCreateUserDialog() {
    _showUserDialog();
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    _showUserDialog(user: user);
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
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

    final passwordController = TextEditingController();

    String selectedRole = user?['role']?.toString() ?? 'User';

    bool obscurePassword = true;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveUser() async {
              final name = nameController.text.trim();

              final email = emailController.text.trim();

              final mobile = mobileController.text.trim();

              final password = passwordController.text;

              if (name.isEmpty) {
                _dialogError(dialogContext, 'Please enter the name.');
                return;
              }

              if (email.isEmpty) {
                _dialogError(dialogContext, 'Please enter the email.');
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
                _dialogError(dialogContext, 'Please enter a password.');
                return;
              }

              if (password.isNotEmpty && password.length < 6) {
                _dialogError(
                  dialogContext,
                  'Password must contain at least 6 characters.',
                );
                return;
              }

              final userId = user?['id']?.toString();

              if (isEdit && (userId == null || userId.isEmpty)) {
                _dialogError(dialogContext, 'Invalid user ID.');
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
                    mobile: mobile.isEmpty ? null : mobile,
                    role: selectedRole,
                    password: password.isEmpty ? null : password,
                  );
                } else {
                  await ApiService.createUser(
                    name: name,
                    email: email,
                    mobile: mobile.isEmpty ? null : mobile,
                    password: password,
                    role: selectedRole,
                  );
                }

                if (!mounted || !dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                _showMessage(
                  isEdit
                      ? 'User updated successfully.'
                      : 'User created successfully.',
                );

                await _loadUsers();
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  saving = false;
                });

                _dialogError(dialogContext, _cleanError(e));
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit User' : 'Create User'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        enabled: !saving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'Enter full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        enabled: !saving,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter email address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: mobileController,
                        enabled: !saving,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Mobile',
                          hintText: 'Enter mobile number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        enabled: !saving,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: isEdit
                              ? 'New Password (optional)'
                              : 'Password',
                          hintText: isEdit
                              ? 'Leave blank to keep current password'
                              : 'Enter password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'User', child: Text('User')),
                          DropdownMenuItem(
                            value: 'Admin',
                            child: Text('Admin'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }

                                setDialogState(() {
                                  selectedRole = value;
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
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : saveUser,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Create'),
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

  Future<void> _changeStatus(String userId, bool isActive) async {
    try {
      await ApiService.updateUserStatus(userId: userId, isActive: isActive);

      if (!mounted) return;

      _showMessage(
        isActive
            ? 'User activated successfully.'
            : 'User deactivated successfully.',
      );

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e), isError: true);
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';

    if (userId.isEmpty) {
      _showMessage('Invalid user ID.', isError: true);
      return;
    }

    final name = user['name']?.toString() ?? 'this user';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text(
            'Are you sure you want to delete '
            '"$name"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteUser(userId);

      if (!mounted) return;

      _showMessage('User deleted successfully.');

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e), isError: true);
    }
  }

  void _dialogError(BuildContext dialogContext, String message) {
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}
