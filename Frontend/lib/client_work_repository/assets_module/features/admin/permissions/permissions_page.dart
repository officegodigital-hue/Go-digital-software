import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({
    super.key,
  });

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _isLoading = true;
  bool _isSaving = false;

  String _searchQuery = '';

  List<Map<String, dynamic>> _permissions = [];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  // ============================================================
  // LOAD PERMISSIONS
  // ============================================================

  Future<void> _loadPermissions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await ApiService.getPermissions();

      final rows = result
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _permissions = rows;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showError(
        _errorMessage(error),
      );
    }
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String _errorMessage(
    Object error,
  ) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> get _filteredPermissions {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _permissions;
    }

    return _permissions.where((user) {
      final name = (user['user_name'] ?? '')
          .toString()
          .toLowerCase();

      final email = (user['email'] ?? '')
          .toString()
          .toLowerCase();

      final mobile = (user['mobile'] ?? '')
          .toString()
          .toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          mobile.contains(query);
    }).toList();
  }

  // ============================================================
  // PERMISSION VALUE
  // ============================================================

  bool _permissionValue(
    Map<String, dynamic> user,
    String key,
  ) {
    final value = user[key];

    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value == 1;
    }

    if (value is String) {
      return value == '1' ||
          value.toLowerCase() == 'true';
    }

    return false;
  }

  // ============================================================
  // UPDATE LOCAL VALUE
  // ============================================================

  void _updateLocalPermission(
    Map<String, dynamic> user,
    String key,
    bool value,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      user[key] = value;
    });
  }

  // ============================================================
  // SAVE USER PERMISSIONS
  // ============================================================

  Future<void> _savePermissions(
    Map<String, dynamic> user,
  ) async {
    if (_isSaving) {
      return;
    }

    final userId = user['user_id']?.toString();

    if (userId == null || userId.isEmpty) {
      _showError(
        'User ID not found.',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }

    try {
      await ApiService.updateUserPermissions(
        userId: userId,
        canView: _permissionValue(
          user,
          'can_view',
        ),
        canCreate: _permissionValue(
          user,
          'can_create',
        ),
        canEdit: _permissionValue(
          user,
          'can_edit',
        ),
        canDelete: _permissionValue(
          user,
          'can_delete',
        ),
        canDownload: _permissionValue(
          user,
          'can_download',
        ),
        canCreateCompany: _permissionValue(
          user,
          'can_create_company',
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permissions updated successfully.',
          ),
        ),
      );

      await _loadPermissions();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        _errorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // ERROR SNACKBAR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isMobile = constraints.maxWidth < 700;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(
                isMobile ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildHeader(
                    isMobile,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildSearch(
                    isMobile,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child:
                                CircularProgressIndicator(),
                          )
                        : _filteredPermissions.isEmpty
                            ? _buildEmptyState()
                            : isMobile
                                ? _buildMobileList()
                                : _buildDesktopTable(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    bool isMobile,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Permissions',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                'Manage permissions for each user.',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Refresh',
          onPressed: _isLoading
              ? null
              : _loadPermissions,
          icon: const Icon(
            Icons.refresh,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch(
    bool isMobile,
  ) {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText:
            'Search users by name, email or mobile...',
        prefixIcon: const Icon(
          Icons.search,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(
                  Icons.clear,
                ),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP TABLE
  // ============================================================

  Widget _buildDesktopTable() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection:
              Axis.horizontal,
          child: SizedBox(
            width: 1180,
            child: Column(
              children: [
                _buildTableHeader(),

                Expanded(
                  child: ListView.separated(
                    itemCount:
                        _filteredPermissions.length,
                    separatorBuilder:
                        (
                      context,
                      index,
                    ) {
                      return Divider(
                        height: 1,
                        color:
                            Colors.grey.shade200,
                      );
                    },
                    itemBuilder:
                        (
                      context,
                      index,
                    ) {
                      return _buildTableRow(
                        _filteredPermissions[
                            index],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget _buildTableHeader() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      color:
          const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _headerCell(
            'User',
            2.2,
          ),

          _headerCell(
            'View',
            1,
          ),

          _headerCell(
            'Download',
            1,
          ),

          _headerCell(
            'Add Asset',
            1,
          ),

          _headerCell(
            'Add Company',
            1,
          ),

          _headerCell(
            'Edit',
            1,
          ),

          _headerCell(
            'Delete',
            1,
          ),

          _headerCell(
            'Action',
            1.3,
          ),
        ],
      ),
    );
  }

  Widget _headerCell(
    String title,
    double flex,
  ) {
    return Expanded(
      flex: (flex * 10).round(),
      child: Text(
        title,
        style:
            const TextStyle(
          fontSize: 13,
          fontWeight:
              FontWeight.w700,
          color:
              AppColors.textSecondary,
        ),
      ),
    );
  }

  // ============================================================
  // TABLE ROW
  // ============================================================

  Widget _buildTableRow(
    Map<String, dynamic> user,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 22,
            child: _buildUserInfo(
              user,
            ),
          ),

          Expanded(
            flex: 10,
            child:
                _buildPermissionSwitch(
              user,
              'can_view',
            ),
          ),

          Expanded(
            flex: 10,
            child:
                _buildPermissionSwitch(
              user,
              'can_download',
            ),
          ),

          Expanded(
            flex: 10,
            child:
                _buildPermissionSwitch(
              user,
              'can_create',
            ),
          ),

          Expanded(
            flex: 10,
            child:
                _buildPermissionSwitch(
              user,
              'can_create_company',
            ),
          ),

          Expanded(
            flex: 10,
            child:
                _buildPermissionSwitch(
              user,
              'can_edit',
            ),
          ),

          Expanded(
            flex: 10,
            child:
                _buildPermissionSwitch(
              user,
              'can_delete',
            ),
          ),

          Expanded(
            flex: 13,
            child: Align(
              alignment:
                  Alignment.centerLeft,
              child:
                  _buildSaveButton(
                user,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USER INFO
  // ============================================================

  Widget _buildUserInfo(
    Map<String, dynamic> user,
  ) {
    final name =
        (user['user_name'] ?? '')
            .toString();

    final email =
        (user['email'] ?? '')
            .toString();

    final mobile =
        (user['mobile'] ?? '')
            .toString();

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor:
              const Color(0xFFEAF2FF),
          child: Text(
            _initials(name),
            style:
                const TextStyle(
              color:
                  AppColors.primary,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty
                    ? 'Unknown User'
                    : name,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      AppColors.textPrimary,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                email,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 12,
                  color:
                      AppColors.textSecondary,
                ),
              ),

              if (mobile.isNotEmpty) ...[
                const SizedBox(
                  height: 2,
                ),

                Text(
                  mobile,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PERMISSION SWITCH
  // ============================================================

  Widget _buildPermissionSwitch(
    Map<String, dynamic> user,
    String key,
  ) {
    final value =
        _permissionValue(
      user,
      key,
    );

    return Align(
      alignment:
          Alignment.centerLeft,
      child: Switch(
        value: value,
        onChanged: (newValue) {
          _updateLocalPermission(
            user,
            key,
            newValue,
          );
        },
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton(
    Map<String, dynamic> user,
  ) {
    return ElevatedButton(
      onPressed: _isSaving
          ? null
          : () {
              _savePermissions(
                user,
              );
            },
      style:
          ElevatedButton.styleFrom(
        backgroundColor:
            AppColors.primary,
        foregroundColor:
            Colors.white,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            9,
          ),
        ),
      ),
      child: const Text(
        'Save',
        style: TextStyle(
          fontSize: 13,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE LIST
  // ============================================================

  Widget _buildMobileList() {
    return ListView.separated(
      itemCount:
          _filteredPermissions.length,
      separatorBuilder:
          (
        context,
        index,
      ) {
        return const SizedBox(
          height: 12,
        );
      },
      itemBuilder:
          (
        context,
        index,
      ) {
        return _buildMobileCard(
          _filteredPermissions[
              index],
        );
      },
    );
  }

  // ============================================================
  // MOBILE CARD
  // ============================================================

  Widget _buildMobileCard(
    Map<String, dynamic> user,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        side: BorderSide(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          children: [
            _buildUserInfo(
              user,
            ),

            const SizedBox(
              height: 16,
            ),

            Divider(
              color:
                  Colors.grey.shade200,
            ),

            const SizedBox(
              height: 8,
            ),

            _buildMobilePermissionRow(
              user,
              'View',
              'can_view',
              Icons.visibility_outlined,
            ),

            _buildMobilePermissionRow(
              user,
              'Download',
              'can_download',
              Icons.download_outlined,
            ),

            _buildMobilePermissionRow(
              user,
              'Add Asset',
              'can_create',
              Icons.add_box_outlined,
            ),

            _buildMobilePermissionRow(
              user,
              'Add Company',
              'can_create_company',
              Icons.business_outlined,
            ),

            _buildMobilePermissionRow(
              user,
              'Edit',
              'can_edit',
              Icons.edit_outlined,
            ),

            _buildMobilePermissionRow(
              user,
              'Delete',
              'can_delete',
              Icons.delete_outline,
            ),

            const SizedBox(
              height: 12,
            ),

            SizedBox(
              width: double.infinity,
              child:
                  _buildSaveButton(
                user,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE PERMISSION ROW
  // ============================================================

  Widget _buildMobilePermissionRow(
    Map<String, dynamic> user,
    String label,
    String key,
    IconData icon,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color:
                AppColors.textSecondary,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.w500,
                color:
                    AppColors.textPrimary,
              ),
            ),
          ),

          Switch(
            value:
                _permissionValue(
              user,
              key,
            ),
            onChanged: (value) {
              _updateLocalPermission(
                user,
                key,
                value,
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons
                .admin_panel_settings_outlined,
            size: 56,
            color:
                Colors.grey.shade400,
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            _searchQuery.isEmpty
                ? 'No active users found.'
                : 'No users match your search.',
            style:
                const TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w600,
              color:
                  AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String _initials(
    String name,
  ) {
    final trimmed =
        name.trim();

    if (trimmed.isEmpty) {
      return '?';
    }

    final parts =
        trimmed.split(
      RegExp(r'\s+'),
    );

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            parts.first.length >= 2
                ? 2
                : 1,
          )
          .toUpperCase();
    }

    return (
      parts.first[0] +
      parts.last[0]
    ).toUpperCase();
  }
}