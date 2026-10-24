import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/widgets/premium_ui.dart';
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

  // ── Permission groups ──────────────────────────────────────────
  static const _assetAccent = PremiumAccent.blue;
  static const _companyAccent = PremiumAccent.green;
  static const _manageAccent = PremiumAccent.amber;

  PremiumAccent _accentForKey(String key) => switch (key) {
    'can_create_company' => _companyAccent,
    'can_edit' || 'can_delete' => _manageAccent,
    _ => _assetAccent,
  };

  bool _hasAllPermissions(Map<String, dynamic> user) =>
      _permDefs.every((p) => _permissionValue(user, p.$2));

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: SafeArea(
        child: PremiumPage(
          builder: (context, bp) {
            final isMobile = bp.width < 700;
            return [
              Reveal(child: _buildHeader(bp.mobile)),
              SizedBox(height: bp.gap),
              _buildSummaryStats(),
              SizedBox(height: bp.gap),
              Reveal(
                delay: const Duration(milliseconds: 380),
                child: _buildSearchRow(isMobile),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: ValueKey(
                    _isLoading
                        ? 'loading'
                        : _filteredPermissions.isEmpty
                        ? 'empty'
                        : isMobile
                        ? 'mobile'
                        : 'desktop',
                  ),
                  child: _isLoading
                      ? const PremiumPanel(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: PremiumLoading(
                            label: 'Loading permissions...',
                          ),
                        )
                      : _filteredPermissions.isEmpty
                      ? _buildEmptyState()
                      : isMobile
                      ? _buildMobileList()
                      : _buildDesktopTable(),
                ),
              ),
            ];
          },
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader(bool compact) {
    return PremiumHero(
      compact: compact,
      eyebrow: 'Access control',
      eyebrowIcon: Icons.verified_user_rounded,
      title: 'Permissions',
      subtitle: 'Control what each user can do with company assets.',
      actions: [
        PremiumButton(
          label: 'Refresh',
          icon: Icons.refresh_rounded,
          iconLeading: true,
          variant: PremiumButtonVariant.glass,
          loading: _isLoading,
          onPressed: _isLoading ? null : _loadPermissions,
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final total = _permissions.length;
    final full = _permissions.where(_hasAllPermissions).length;
    final none = _permissions.where((u) => !_hasAnyPermission(u)).length;
    return PremiumStatRow(
      stats: [
        PremiumStat(
          label: 'Users',
          value: total,
          icon: Icons.people_alt_rounded,
          accent: PremiumAccent.blue,
          caption: 'Active users',
        ),
        PremiumStat(
          label: 'Full access',
          value: full,
          icon: Icons.verified_rounded,
          accent: PremiumAccent.green,
          caption: 'Every permission on',
        ),
        PremiumStat(
          label: 'No access',
          value: none,
          icon: Icons.block_rounded,
          accent: PremiumAccent.amber,
          caption: 'Every permission off',
        ),
      ],
    );
  }

  // ── Search + Legend row ─────────────────────────────────────────
  Widget _buildSearchRow(bool isNarrow) {
    final search = PremiumSearchField(
      controller: _searchController,
      hint: 'Search by name, email or mobile...',
      onChanged: (v) => setState(() => _searchQuery = v),
      onClear: () => setState(() => _searchQuery = ''),
    );
    final legend = Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _legendDot(
          'Allowed',
          const LinearGradient(colors: [PremiumColors.blue, Color(0xFF38BDF8)]),
        ),
        _legendDot(
          'Not allowed',
          const LinearGradient(colors: [Color(0xFFCBD5E1), Color(0xFFE2E8F0)]),
        ),
        PremiumBadge(
          label: '${_filteredPermissions.length} users',
          icon: Icons.people_alt_rounded,
        ),
      ],
    );
    return PremiumPanel(
      padding: const EdgeInsets.all(12),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 12), legend],
            )
          : Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 20),
                legend,
              ],
            ),
    );
  }

  Widget _legendDot(String label, Gradient gradient) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 14, color: PremiumColors.body),
      ),
    ],
  );

  // ── Desktop table ───────────────────────────────────────────────
  Widget _buildDesktopTable() {
    final users = _filteredPermissions;
    return PremiumPanel(
      padding: EdgeInsets.zero,
      child: PremiumTable(
        minWidth: 980,
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildGroupHeader(), _buildColumnHeader()],
        ),
        itemCount: users.length,
        itemBuilder: (context, i) => _buildTableRow(users[i]),
        footer: _buildFooter(),
      ),
    );
  }

  // ── Group header (ASSET ACCESS / COMPANY ACCESS / MANAGEMENT) ──
  Widget _buildGroupHeader() {
    Widget pill(String label, PremiumAccent accent) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: accent.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.start.withAlpha(60)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: accent.start,
          letterSpacing: 0.6,
        ),
      ),
    );
    return Container(
      height: 34,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // USER column — no group label
          const Expanded(flex: 26, child: SizedBox()),
          // ASSET ACCESS spans View + Download + Add Asset
          Expanded(
            flex: 33,
            child: Center(child: pill('ASSET ACCESS', _assetAccent)),
          ),
          // COMPANY ACCESS spans Add Company
          Expanded(
            flex: 13,
            child: Center(child: pill('COMPANY ACCESS', _companyAccent)),
          ),
          // MANAGEMENT spans Edit + Delete
          Expanded(
            flex: 18,
            child: Center(child: pill('MANAGEMENT', _manageAccent)),
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
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        gradient: PremiumColors.tableHeaderGradient,
        border: Border(top: BorderSide(color: PremiumColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 26,
            child: _colHeaderLabel('USER', null, crossStart: true),
          ),
          for (final p in _permDefs)
            Expanded(
              flex: _flexForKey(p.$2),
              child: _colHeaderLabel(p.$1, p.$3, accent: _accentForKey(p.$2)),
            ),
          Expanded(
            flex: 16,
            child: _colHeaderLabel('ACTION', null, crossStart: true),
          ),
        ],
      ),
    );
  }

  int _flexForKey(String key) => switch (key) {
    'can_create_company' => 13,
    'can_edit' || 'can_delete' => 9,
    _ => 11,
  };

  Widget _colHeaderLabel(
    String label,
    IconData? icon, {
    bool crossStart = false,
    PremiumAccent accent = PremiumAccent.blue,
  }) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: crossStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: accent.start),
          const SizedBox(height: 4),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3B5B9A),
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
    final hasAny = _hasAnyPermission(user);

    return HoverBuilder(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: hovered ? const Color(0xFFF5F9FF) : Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFEDF2FA))),
        ),
        child: Row(
          children: [
            // USER
            Expanded(
              flex: 26,
              child: Row(
                children: [
                  PremiumAvatar(
                    text: _initials(name),
                    accent: PremiumAccent.fromColor(_avatarColor(name)),
                    size: 36,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PremiumColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: PremiumColors.muted,
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
                              color: PremiumColors.faint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final p in _permDefs)
              Expanded(flex: _flexForKey(p.$2), child: _permSwitch(user, p.$2)),
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
      ),
    );
  }

  // ── Permission switch ──────────────────────────────────────────
  Widget _permSwitch(Map<String, dynamic> user, String key) {
    final on = _permissionValue(user, key);
    return Align(
      alignment: Alignment.center,
      child: PremiumToggle(
        value: on,
        accent: _accentForKey(key),
        onChanged: (value) => _updateLocalPermission(user, key, value),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────
  Widget _saveButton(
    Map<String, dynamic> user,
    bool hasAny, {
    bool expand = false,
  }) {
    return PremiumButton(
      label: 'Save',
      icon: Icons.check_rounded,
      iconLeading: true,
      small: true,
      expand: expand,
      variant: hasAny
          ? PremiumButtonVariant.filled
          : PremiumButtonVariant.outlined,
      onPressed: _isSaving ? null : () => _savePermissions(user),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        gradient: PremiumColors.tableHeaderGradient,
        border: Border(top: BorderSide(color: PremiumColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_filteredPermissions.length} users',
            style: const TextStyle(fontSize: 14, color: PremiumColors.muted),
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: PremiumColors.faint,
              ),
              SizedBox(width: 6),
              Text(
                'Save applies to one user at a time.',
                style: TextStyle(fontSize: 14, color: PremiumColors.faint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mobile list ────────────────────────────────────────────────
  Widget _buildMobileList() {
    return Column(
      children: [
        for (var i = 0; i < _filteredPermissions.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Reveal(
            delay: Duration(milliseconds: 40 * math.min(i, 10)),
            child: _buildMobileCard(_filteredPermissions[i], i),
          ),
        ],
      ],
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
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen ? const Color(0xFF93C5FD) : PremiumColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: PremiumColors.blue.withAlpha(isOpen ? 36 : 10),
            blurRadius: isOpen ? 24 : 12,
            offset: Offset(0, isOpen ? 10 : 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            // ── Collapsed header (always visible) ──
            InkWell(
              onTap: () => setState(() {
                if (isOpen) {
                  _expandedCards.remove(index);
                } else {
                  _expandedCards.add(index);
                }
              }),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    PremiumAvatar(
                      text: _initials(name),
                      accent: PremiumAccent.fromColor(_avatarColor(name)),
                      size: 38,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: PremiumColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: PremiumColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 6 permission dots
                          Row(
                            children: [
                              for (final p in _permDefs)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _permissionValue(user, p.$2)
                                        ? _accentForKey(p.$2).gradient
                                        : null,
                                    color: _permissionValue(user, p.$2)
                                        ? null
                                        : const Color(0xFFD9E1EC),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chevron
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isOpen ? PremiumColors.blue : PremiumColors.soft,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isOpen ? Colors.white : PremiumColors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded body ──
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 240),
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeIn,
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: isOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                children: [
                  const Divider(height: 1, color: PremiumColors.line),
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
                            return _mobilePermTile(user, label, key, icon);
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: _saveButton(user, hasAny, expand: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobilePermTile(
    Map<String, dynamic> user,
    String label,
    String key,
    IconData icon,
  ) {
    final enabled = _permissionValue(user, key);
    final accent = _accentForKey(key);
    return GestureDetector(
      onTap: () => _updateLocalPermission(user, key, !enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? accent.soft : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? accent.start.withAlpha(80) : PremiumColors.line,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: enabled ? accent.start : PremiumColors.faint,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: enabled ? accent.start : PremiumColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: enabled ? accent.gradient : null,
                color: enabled ? null : const Color(0xFFE2E8F0),
              ),
              child: AnimatedOpacity(
                opacity: enabled ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return PremiumPanel(
      child: PremiumEmptyState(
        icon: _searchQuery.isEmpty
            ? Icons.admin_panel_settings_rounded
            : Icons.search_off_rounded,
        title: _searchQuery.isEmpty
            ? 'No active users found.'
            : 'No users match your search.',
      ),
    );
  }
}
