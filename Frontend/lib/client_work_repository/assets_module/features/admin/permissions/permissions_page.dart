import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _permissions = [];
  final Set<int> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  // ── Backend: load ──────────────────────────────────────────────
  Future<void> _loadPermissions() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final result = await ApiService.getPermissions();
      final rows = result
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _permissions = rows;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(_errorMessage(error));
    }
  }

  // ── Backend: helpers ───────────────────────────────────────────
  String _errorMessage(Object error) {
    final msg = error.toString();
    return msg.startsWith('Exception: ')
        ? msg.substring('Exception: '.length)
        : msg;
  }

  List<Map<String, dynamic>> get _filteredPermissions {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _permissions;
    return _permissions.where((u) {
      final name = (u['user_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final mobile = (u['mobile'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || mobile.contains(q);
    }).toList();
  }

  bool _permissionValue(Map<String, dynamic> user, String key) {
    final v = user[key];
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  void _updateLocalPermission(
    Map<String, dynamic> user,
    String key,
    bool value,
  ) {
    if (!mounted) return;
    setState(() => user[key] = value);
  }

  Future<void> _savePermissions(Map<String, dynamic> user) async {
    if (_isSaving) return;
    final userId = user['user_id']?.toString();
    if (userId == null || userId.isEmpty) {
      _showError('User ID not found.');
      return;
    }
    if (mounted) setState(() => _isSaving = true);
    try {
      await ApiService.updateUserPermissions(
        userId: userId,
        canView: _permissionValue(user, 'can_view'),
        canCreate: _permissionValue(user, 'can_create'),
        canEdit: _permissionValue(user, 'can_edit'),
        canDelete: _permissionValue(user, 'can_delete'),
        canDownload: _permissionValue(user, 'can_download'),
        canCreateCompany: _permissionValue(user, 'can_create_company'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions updated successfully.')),
      );
      await _loadPermissions();
    } catch (error) {
      if (!mounted) return;
      _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool _hasAnyPermission(Map<String, dynamic> user) {
    return _permissionValue(user, 'can_view') ||
        _permissionValue(user, 'can_download') ||
        _permissionValue(user, 'can_create') ||
        _permissionValue(user, 'can_create_company') ||
        _permissionValue(user, 'can_edit') ||
        _permissionValue(user, 'can_delete');
  }

  // ── Avatar color per initials ──────────────────────────────────
  static const _avatarColors = <String, Color>{
    'A': Color(0xFF2563EB),
    'G': Color(0xFF7C3AED),
    'H': Color(0xFF16A34A),
    'J': Color(0xFFD97706),
    'K': Color(0xFF16A34A),
    'M': Color(0xFFDC2626),
    'P': Color(0xFF0891B2),
    'S': Color(0xFF059669),
  };
  static const _avatarPalette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
  ];
  Color _avatarColor(String name) {
    if (name.isEmpty) return _avatarPalette[0];
    final key = name.trim()[0].toUpperCase();
    return _avatarColors[key] ??
        _avatarPalette[key.codeUnitAt(0) % _avatarPalette.length];
  }

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 32,
                28,
                isMobile ? 16 : 32,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildSearchRow(),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _filteredPermissions.isEmpty
                      ? _buildEmptyState()
                      : isMobile
                      ? _buildMobileList()
                      : _buildDesktopTable(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  height: 1.2,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Control what each user can do with company assets.',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _loadPermissions,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF374151),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── Search + Legend row ─────────────────────────────────────────
  Widget _buildSearchRow() {
    final isNarrow = MediaQuery.sizeOf(context).width < 700;
    return Flex(
      direction: isNarrow ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: isNarrow
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        // Search input
        isNarrow
            ? SizedBox(
                height: 44,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                  decoration: _permissionSearchDecoration(),
                ),
              )
            : Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                    decoration: _permissionSearchDecoration(),
                  ),
                ),
              ),
        SizedBox(width: isNarrow ? 0 : 20, height: isNarrow ? 12 : 0),
        // Legend
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Allowed',
              style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
            const SizedBox(width: 16),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFD1D5DB),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Not allowed',
              style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
            const SizedBox(width: 16),
            Text(
              '${_filteredPermissions.length} users',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _permissionSearchDecoration() => InputDecoration(
    hintText: 'Search by name, email or mobile...',
    hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
    suffixIcon: _searchQuery.isEmpty
        ? null
        : IconButton(
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
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
    ),
  );

  // ── Desktop table ───────────────────────────────────────────────
  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildGroupHeader(),
            _buildColumnHeader(),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredPermissions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (_, i) => _buildTableRow(_filteredPermissions[i]),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Group header (ASSET ACCESS / COMPANY ACCESS / MANAGEMENT) ──
  Widget _buildGroupHeader() {
    const labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6B7280),
      letterSpacing: 0.5,
    );
    return Container(
      height: 36,
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // USER column — no group label
          const Expanded(flex: 26, child: SizedBox()),
          // ASSET ACCESS spans View + Download + Add Asset
          Expanded(
            flex: 33,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text('ASSET ACCESS', style: labelStyle),
              ),
            ),
          ),
          // COMPANY ACCESS spans Add Company
          Expanded(
            flex: 13,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Text('COMPANY ACCESS', style: labelStyle),
              ),
            ),
          ),
          // MANAGEMENT spans Edit + Delete
          Expanded(
            flex: 18,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text('MANAGEMENT', style: labelStyle),
              ),
            ),
          ),
          // ACTION — no group label
          const Expanded(flex: 16, child: SizedBox()),
        ],
      ),
    );
  }

  // ── Column header with icons ───────────────────────────────────
  Widget _buildColumnHeader() {
    return Container(
      height: 52,
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 26,
            child: _colHeaderLabel('USER', null, crossStart: true),
          ),
          Expanded(
            flex: 11,
            child: _colHeaderLabel('View', Icons.visibility_outlined),
          ),
          Expanded(
            flex: 11,
            child: _colHeaderLabel('Download', Icons.download_outlined),
          ),
          Expanded(
            flex: 11,
            child: _colHeaderLabel(
              'Add Asset',
              Icons.add_photo_alternate_outlined,
            ),
          ),
          Expanded(
            flex: 13,
            child: _colHeaderLabel('Add Company', Icons.business_outlined),
          ),
          Expanded(
            flex: 9,
            child: _colHeaderLabel('Edit', Icons.edit_outlined),
          ),
          Expanded(
            flex: 9,
            child: _colHeaderLabel('Delete', Icons.delete_outline),
          ),
          Expanded(
            flex: 16,
            child: _colHeaderLabel('ACTION', null, crossStart: true),
          ),
        ],
      ),
    );
  }

  Widget _colHeaderLabel(
    String label,
    IconData? icon, {
    bool crossStart = false,
  }) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: crossStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 3),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
    return crossStart
        ? Align(alignment: Alignment.centerLeft, child: content)
        : content;
  }

  // ── Table row ──────────────────────────────────────────────────
  Widget _buildTableRow(Map<String, dynamic> user) {
    final name = (user['user_name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final mobile = (user['mobile'] ?? '').toString();
    final avatarColor = _avatarColor(name);
    final hasAny = _hasAnyPermission(user);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // USER
          Expanded(
            flex: 26,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Unknown User' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (mobile.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          mobile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // View
          Expanded(flex: 11, child: _permSwitch(user, 'can_view')),
          // Download
          Expanded(flex: 11, child: _permSwitch(user, 'can_download')),
          // Add Asset
          Expanded(flex: 11, child: _permSwitch(user, 'can_create')),
          // Add Company
          Expanded(flex: 13, child: _permSwitch(user, 'can_create_company')),
          // Edit
          Expanded(flex: 9, child: _permSwitch(user, 'can_edit')),
          // Delete
          Expanded(flex: 9, child: _permSwitch(user, 'can_delete')),
          // Action
          Expanded(
            flex: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _saveButton(user, hasAny),
            ),
          ),
        ],
      ),
    );
  }

  // ── Permission switch ──────────────────────────────────────────
  Widget _permSwitch(Map<String, dynamic> user, String key) {
    final on = _permissionValue(user, key);
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _updateLocalPermission(user, key, !on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 26,
          decoration: BoxDecoration(
            color: on ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            children: [
              Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: on
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Color(0xFF2563EB),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────
  Widget _saveButton(Map<String, dynamic> user, bool hasAny) {
    if (hasAny) {
      return ElevatedButton(
        onPressed: _isSaving ? null : () => _savePermissions(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(88, 40),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: const Text('Save'),
      );
    }
    return OutlinedButton(
      onPressed: _isSaving ? null : () => _savePermissions(user),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2563EB),
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        minimumSize: const Size(88, 40),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: const Text('Save'),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_filteredPermissions.length} users',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const Text(
            'Save applies to one user at a time.',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  // ── Mobile list ────────────────────────────────────────────────
  Widget _buildMobileList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredPermissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildMobileCard(_filteredPermissions[i], i),
    );
  }

  static const _permDefs = [
    ('View', 'can_view', Icons.visibility_outlined),
    ('Download', 'can_download', Icons.download_outlined),
    ('Add Asset', 'can_create', Icons.add_photo_alternate_outlined),
    ('Add Company', 'can_create_company', Icons.business_outlined),
    ('Edit', 'can_edit', Icons.edit_outlined),
    ('Delete', 'can_delete', Icons.delete_outline),
  ];

  Widget _buildMobileCard(Map<String, dynamic> user, int index) {
    final name = (user['user_name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final hasAny = _hasAnyPermission(user);
    final isOpen = _expandedCards.contains(index);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpen ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
        ),
        boxShadow: isOpen
            ? [
                const BoxShadow(
                  color: Color(0x0A2563EB),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // ── Collapsed header (always visible) ──
          InkWell(
            onTap: () => setState(() {
              if (isOpen)
                _expandedCards.remove(index);
              else
                _expandedCards.add(index);
            }),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _avatarColor(name),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Unknown User' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 6 permission dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _permDefs.map((p) {
                      final on = _permissionValue(user, p.$2);
                      return Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD1D5DB),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 8),
                  // Chevron
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    children: [
                      // 2-column perm grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 3.2,
                        children: _permDefs.map((p) {
                          final (label, key, icon) = p;
                          final enabled = _permissionValue(user, key);
                          return GestureDetector(
                            onTap: () =>
                                _updateLocalPermission(user, key, !enabled),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: enabled
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: enabled
                                      ? const Color(0xFFBFDBFE)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 14,
                                    color: enabled
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: enabled
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Compact on/off dot indicator
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: enabled
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFE5E7EB),
                                    ),
                                    child: enabled
                                        ? const Icon(
                                            Icons.check,
                                            size: 11,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _saveButton(user, hasAny),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isEmpty
                ? 'No active users found.'
                : 'No users match your search.',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
