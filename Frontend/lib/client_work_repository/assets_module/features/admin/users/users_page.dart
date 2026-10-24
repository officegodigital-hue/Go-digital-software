import 'package:flutter/material.dart';

import '../../../core/widgets/premium_ui.dart';
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;

    return PremiumPage(
      builder: (context, bp) => [
        Reveal(child: _buildHeader(bp.mobile)),
        SizedBox(height: bp.gap),
        _buildSummaryStats(),
        SizedBox(height: bp.gap),
        Reveal(
          delay: const Duration(milliseconds: 360),
          child: PremiumPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: _buildSearch(),
                ),
                const Divider(height: 1, color: PremiumColors.line),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: KeyedSubtree(
                    key: ValueKey(
                      _isLoading
                          ? 'loading'
                          : users.isEmpty
                          ? 'empty'
                          : 'list',
                    ),
                    child: _buildUserList(users),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool compact) {
    return PremiumHero(
      compact: compact,
      eyebrow: 'Team',
      eyebrowIcon: Icons.groups_rounded,
      title: 'Users',
      subtitle: 'Manage user access to company assets.',
      actions: [
        PremiumButton(
          label: 'Add user',
          icon: Icons.person_add_alt_1_rounded,
          iconLeading: true,
          variant: PremiumButtonVariant.light,
          onPressed: _showCreateUserDialog,
        ),
        PremiumButton(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          iconLeading: true,
          variant: PremiumButtonVariant.glass,
          loading: _isLoading,
          onPressed: _isLoading ? null : _loadUsers,
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final active = _users.where(_readActiveStatus).length;
    final admins = _users
        .where((u) => u['role']?.toString().trim().toLowerCase() == 'admin')
        .length;
    return PremiumStatRow(
      stats: [
        PremiumStat(
          label: 'Total users',
          value: _users.length,
          icon: Icons.people_alt_rounded,
          accent: PremiumAccent.blue,
          caption: 'Everyone in the workspace',
        ),
        PremiumStat(
          label: 'Active',
          value: active,
          icon: Icons.check_circle_rounded,
          accent: PremiumAccent.green,
          caption: 'Can sign in',
        ),
        PremiumStat(
          label: 'Inactive',
          value: _users.length - active,
          icon: Icons.pause_circle_rounded,
          accent: PremiumAccent.rose,
          caption: 'Access paused',
        ),
        PremiumStat(
          label: 'Admins',
          value: admins,
          icon: Icons.admin_panel_settings_rounded,
          accent: PremiumAccent.violet,
          caption: 'Full workspace control',
        ),
      ],
    );
  }

  Widget _buildSearch() {
    final search = PremiumSearchField(
      controller: _searchController,
      hint: 'Search users...',
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      onClear: () => setState(() => _searchQuery = ''),
    );
    final count = PremiumBadge(
      label: '${_filteredUsers.length} users',
      icon: Icons.people_alt_rounded,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [search, const SizedBox(height: 10), count],
          );
        }
        return Row(
          children: [
            SizedBox(width: 340, child: search),
            const Spacer(),
            count,
          ],
        );
      },
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: PremiumLoading(label: 'Loading users...'),
      );
    }

    if (users.isEmpty) {
      return PremiumEmptyState(
        icon: _searchQuery.isEmpty
            ? Icons.people_outline_rounded
            : Icons.search_off_rounded,
        title: _searchQuery.isEmpty
            ? 'No users found.'
            : 'No users match your search.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (int i = 0; i < users.length; i++) ...[
                  _buildMobileUserCard(users[i]),
                  if (i < users.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          );
        }
        return PremiumTable(
          minWidth: 720,
          header: _buildTableHeader(),
          itemCount: users.length,
          itemBuilder: (context, i) => _buildUserRow(users[i], i),
          footer: PremiumTableFooter(
            child: Text('Showing ${users.length} users.'),
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
    final (_, avatarFg) = _avatarColors(name);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PremiumColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PremiumAvatar(
                text: initial,
                accent: PremiumAccent.fromColor(avatarFg),
                size: 40,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PremiumColors.ink,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: PremiumColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusPill(userId, isActive),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: PremiumColors.line),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _roleChip(role),
                ),
              ),
              const SizedBox(width: 8),
              PremiumButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                iconLeading: true,
                small: true,
                variant: PremiumButtonVariant.soft,
                onPressed: userId.isEmpty
                    ? null
                    : () => _showEditUserDialog(user),
              ),
              const SizedBox(width: 6),
              PremiumIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete user',
                accent: PremiumAccent.rose,
                onPressed: userId.isEmpty
                    ? null
                    : () => _confirmDeleteUser(user),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const p = EdgeInsets.symmetric(horizontal: 12);
    Widget cell(int flex, String label) => Expanded(
      flex: flex,
      child: Padding(
        padding: p,
        child: Text(label, style: PremiumColors.tableHeaderStyle),
      ),
    );
    return PremiumTableHeader(
      child: Row(
        children: [
          cell(26, 'USER'),
          cell(28, 'EMAIL'),
          cell(18, 'ROLE'),
          cell(18, 'STATUS'),
          const SizedBox(
            width: 120,
            child: Padding(
              padding: p,
              child: Text(
                'ACTIONS',
                style: PremiumColors.tableHeaderStyle,
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

  PremiumAccent _roleAccent(String role) => role.trim().toLowerCase() == 'admin'
      ? PremiumAccent.violet
      : PremiumAccent.blue;

  Widget _roleChip(String role) => PremiumBadge(
    label: role,
    icon: role.trim().toLowerCase() == 'admin'
        ? Icons.admin_panel_settings_outlined
        : _roleIcon(role),
    accent: _roleAccent(role),
    maxWidth: 170,
  );

  /// Tap to switch a user between active and inactive.
  Widget _statusPill(String userId, bool isActive) {
    final accent = isActive ? PremiumAccent.green : PremiumAccent.rose;
    final enabled = userId.isNotEmpty;
    return Tooltip(
      message: isActive ? 'Click to deactivate' : 'Click to activate',
      child: HoverBuilder(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        builder: (context, hovered) => GestureDetector(
          onTap: enabled ? () => _changeStatus(userId, !isActive) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: hovered && enabled
                  ? Color.lerp(accent.soft, accent.start, 0.12)
                  : accent.soft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.start.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.start,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: accent.start,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user, int index) {
    final userId = user['id']?.toString() ?? '';
    final name = user['name']?.toString() ?? 'Unknown User';
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'User';
    final isActive = _readActiveStatus(user);
    final initial = name.trim().isEmpty ? 'U' : name.trim()[0].toUpperCase();
    final (_, avatarFg) = _avatarColors(name);
    const p = EdgeInsets.symmetric(horizontal: 12);

    return PremiumTableRow(
      minHeight: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // User
          Expanded(
            flex: 26,
            child: Padding(
              padding: p,
              child: Row(
                children: [
                  PremiumAvatar(
                    text: initial,
                    accent: PremiumAccent.fromColor(avatarFg),
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PremiumColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Email
          Expanded(
            flex: 28,
            child: Padding(
              padding: p,
              child: Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: PremiumColors.muted,
                ),
              ),
            ),
          ),
          // Role
          Expanded(
            flex: 18,
            child: Padding(
              padding: p,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _roleChip(role),
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 18,
            child: Padding(
              padding: p,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _statusPill(userId, isActive),
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 120,
            child: Padding(
              padding: p,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PremiumIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit user',
                    onPressed: userId.isEmpty
                        ? null
                        : () => _showEditUserDialog(user),
                  ),
                  const SizedBox(width: 6),
                  PremiumIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete user',
                    accent: PremiumAccent.rose,
                    onPressed: userId.isEmpty
                        ? null
                        : () => _confirmDeleteUser(user),
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
