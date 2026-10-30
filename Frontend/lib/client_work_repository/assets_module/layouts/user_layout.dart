import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/premium_ui.dart';
import '../features/user/asset_library/asset_library_page.dart';
import '../features/user/company_assets/company_assets_page.dart';
import '../features/user/dashboard/dashboard_page.dart';
import '../features/user/downloads/downloads_page.dart';
import '../../../profile_page.dart';
import '../models/company_model.dart';

class UserLayout extends StatefulWidget {
  final VoidCallback onLogout;

  const UserLayout({super.key, required this.onLogout});

  @override
  State<UserLayout> createState() => _UserLayoutState();
}

class _UserLayoutState extends State<UserLayout> {
  // ============================================================
  // NAVIGATION
  // ============================================================

  int _selectedIndex = 0;

  CompanyModel? _openCompany;
  String? _openSection;

  void _handleOpenCompany(CompanyModel company, String section) {
    setState(() {
      _openCompany = company;
      _openSection = section;
    });
  }

  void _handleCloseCompany() {
    setState(() {
      _openCompany = null;
      _openSection = null;
    });
  }

  // ============================================================
  // DOWNLOAD HISTORY
  // ============================================================

  List<Map<String, dynamic>> _downloadHistory = [];
  bool _isLoadingDownloads = false;
  String? _downloadError;
  String _downloadSearch = '';
  final TextEditingController _downloadSearchController =
      TextEditingController();

  // ============================================================
  // PROFILE
  // ============================================================

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;

  String? _profilePhotoUrl;
  Uint8List? _profilePhotoBytes;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _mobileController = TextEditingController();

    _loadLoggedInUserProfile();
    _loadProfilePhoto();
  }

  // ============================================================
  // LOAD LOGGED-IN USER PROFILE
  // ============================================================

  Future<void> _loadLoggedInUserProfile() async {
    try {
      final profile = await ApiService.getMyProfile();
      final name = profile['name']?.toString();
      final email = profile['email']?.toString();
      final photoUrl = profile['profile_photo_url']?.toString();

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text = name != null && name.trim().isNotEmpty
            ? name.trim()
            : '';

        _emailController.text = email?.trim() ?? '';
        _mobileController.text = profile['mobile']?.toString().trim() ?? '';
        _profilePhotoUrl = photoUrl != null && photoUrl.trim().isNotEmpty
            ? photoUrl.trim()
            : _profilePhotoUrl;
      });
    } catch (_) {
      // Keep the fields empty if the saved logged-in
      // account information cannot be read.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _downloadSearchController.dispose();

    super.dispose();
  }

  // ============================================================
  // PAGE SELECTION
  // ============================================================

  void _selectPage(int index) {
    if (_selectedIndex == index && _openCompany == null) {
      return;
    }

    setState(() {
      _selectedIndex = index;
      _openCompany = null;
      _openSection = null;
    });
  }

  Future<void> _loadDownloadHistory() async {
    if (_isLoadingDownloads) {
      return;
    }

    setState(() {
      _isLoadingDownloads = true;
      _downloadError = null;
    });

    try {
      final history = await ApiService.getDownloadLogs();

      if (!mounted) {
        return;
      }

      setState(() {
        _downloadHistory = history.map<Map<String, dynamic>>((item) {
          final row = item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{};
          return <String, dynamic>{
            'fileName': row['file_name'],
            'assetName': row['asset_name'],
            'companyName': row['company_name'],
            'assetType': row['asset_type'],
            'downloadedAt': row['created_at'],
          };
        }).toList();
        _isLoadingDownloads = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _downloadHistory = [];
        _isLoadingDownloads = false;
        _downloadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredDownloads {
    final q = _downloadSearch.trim().toLowerCase();
    if (q.isEmpty) return _downloadHistory;
    return _downloadHistory.where((item) {
      final file = (item['fileName'] ?? '').toString().toLowerCase();
      final asset = (item['assetName'] ?? '').toString().toLowerCase();
      final company = (item['companyName'] ?? '').toString().toLowerCase();
      final type = (item['assetType'] ?? '').toString().toLowerCase();
      return file.contains(q) ||
          asset.contains(q) ||
          company.contains(q) ||
          type.contains(q);
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 700) {
          return _buildMobileLayout();
        }

        return _buildDesktopLayout();
      },
    );
  }

  // ============================================================
  // MOBILE LAYOUT
  // ============================================================

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildMobileTopBar(),

            Expanded(child: _buildPage()),
          ],
        ),
      ),
      bottomNavigationBar: _buildMobileBottomNavigation(),
    );
  }

  // ============================================================
  // MOBILE TOP BAR
  // ============================================================

  Widget _buildMobileTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: PremiumColors.line)),
      ),
      child: Row(
        children: [
          _buildLogo(size: 38),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Go Digital',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: PremiumColors.blueDeep,
                  ),
                ),
                Text(
                  'User Portal',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PremiumColors.muted,
                  ),
                ),
              ],
            ),
          ),

          _buildNotificationButton(),

          const SizedBox(width: 6),

          _buildAvatarMenu(size: 36),
        ],
      ),
    );
  }

  // ============================================================
  // DESKTOP LAYOUT
  // ============================================================

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: Column(
        children: [
          _buildDesktopTopNav(),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }

  // ============================================================
  // DESKTOP TOP NAVIGATION BAR
  // ============================================================

  Widget _buildDesktopTopNav() {
    const navItems = [
      (0, 'Dashboard', Icons.grid_view_rounded),
      (1, 'Assets', Icons.folder_rounded),
      (2, 'Downloads', Icons.download_rounded),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        // Narrow laptops and tablets drop the portal label and shrink the
        // Workspace button so the bar never overflows.
        final roomy = box.maxWidth >= 1000;
        final compact = box.maxWidth < 820;
        return Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: PremiumColors.line)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0D1E40AF),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Logo (left)
              _buildLogo(size: 38),
              const SizedBox(width: 10),
              const Text(
                'Go Digital',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: PremiumColors.blueDeep,
                ),
              ),
              if (roomy) ...[
                Container(
                  width: 1,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: PremiumColors.line,
                ),
                const Text(
                  'User Portal',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: PremiumColors.muted,
                  ),
                ),
              ],

              // Centered tabs
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: PremiumColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: PremiumColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in navItems)
                            _buildTopNavTab(
                              index: item.$1,
                              label: item.$2,
                              icon: item.$3,
                              compact: compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Right actions
              _buildNotificationButton(),
              const SizedBox(width: 10),
              if (roomy) ...[
                _buildDesktopUserInfo(),
                const SizedBox(width: 12),
              ] else ...[
                PremiumIconButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: 'Workspace',
                  onPressed: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamedAndRemoveUntil('/home', (route) => false),
                ),
                const SizedBox(width: 10),
              ],
              _buildAvatarMenu(size: 38),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopNavTab({
    required int index,
    required String label,
    required IconData icon,
    bool compact = false,
  }) {
    final selected = _selectedIndex == index;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: () => _selectPage(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            gradient: selected ? PremiumColors.heroGradient : null,
            color: selected
                ? null
                : hovered
                ? Colors.white
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (selected)
                const BoxShadow(
                  color: Color(0x401B5FE8),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : hovered
                    ? PremiumColors.blue
                    : PremiumColors.muted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : hovered
                      ? PremiumColors.blue
                      : PremiumColors.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarMenu({double size = 38}) {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: Offset(0, size + 10),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x401E40AF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: PremiumColors.line),
      ),
      onSelected: (value) {
        if (value == 'profile') {
          // Opens your existing Profile Settings screen (it has its own
          // back button).
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ProfilePage()));
        }
        if (value == 'logout') {
          _confirmLogout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              _buildAvatar(size: 40, fontSize: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.isEmpty ? 'My Account' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
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
                          fontSize: 12,
                          color: PremiumColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 19,
                color: PremiumColors.blue,
              ),
              SizedBox(width: 10),
              Text(
                'My Profile',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PremiumColors.ink,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 19, color: PremiumColors.blueDeep),
              SizedBox(width: 10),
              Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PremiumColors.blueDeep,
                ),
              ),
            ],
          ),
        ),
      ],
      child: _buildAvatar(size: size, fontSize: size * 0.4),
    );
  }

  // ============================================================
  // DESKTOP USER INFO
  // ============================================================

  Widget _buildDesktopUserInfo() {
    return PremiumButton(
      label: 'Workspace',
      icon: Icons.grid_view_rounded,
      iconLeading: true,
      small: true,
      variant: PremiumButtonVariant.outlined,
      onPressed: () => Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/home', (route) => false),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _buildLogo({double size = 40}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/godigital_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: PremiumColors.heroGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.view_in_ar_rounded,
              color: Colors.white,
              size: size * 0.55,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // NOTIFICATION BUTTON
  // ============================================================

  Widget _buildNotificationButton() {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: _showNotifications,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: hovered ? PremiumColors.soft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PremiumColors.line),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: PremiumColors.blue,
                ),
              ),

              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: PremiumColors.heroGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // USER AVATAR
  // ============================================================

  Widget _buildAvatar({required double size, required double fontSize}) {
    final photoBytes = _profilePhotoBytes;
    final photoUrl = _profilePhotoUrl;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: PremiumColors.heroGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331B5FE8),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: photoBytes != null
          ? Image.memory(
              photoBytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : photoUrl != null && photoUrl.isNotEmpty
          ? Image.network(
              _profilePhotoNetworkUrl(photoUrl),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Text(
              _initialsFromName(_nameController.text),
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  String _initialsFromName(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // ============================================================
  // MOBILE BOTTOM NAVIGATION
  // ============================================================

  Widget _buildMobileBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: PremiumColors.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x141E40AF),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // DASHBOARD
              _buildBottomNavItem(
                index: 0,
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view_rounded,
                label: 'Dashboard',
              ),

              // ASSETS
              _buildBottomNavItem(
                index: 1,
                icon: Icons.folder_outlined,
                selectedIcon: Icons.folder_rounded,
                label: 'Assets',
              ),

              // DOWNLOADS
              _buildBottomNavItem(
                index: 2,
                icon: Icons.download_outlined,
                selectedIcon: Icons.download_rounded,
                label: 'Downloads',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAV ITEM
  // ============================================================

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          _selectPage(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 52 : 40,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected ? PremiumColors.heroGradient : null,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  if (selected)
                    const BoxShadow(
                      color: Color(0x401B5FE8),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                ],
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: 20,
                color: selected ? Colors.white : PremiumColors.faint,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? PremiumColors.blue : PremiumColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAGE CONTENT
  // ============================================================

  Widget _buildPage() {
    if (_selectedIndex == 1 && _openCompany != null) {
      return CompanyAssetsPage(
        key: ValueKey(_openCompany!.id + (_openSection ?? '')),
        company: _openCompany!,
        section: _openSection ?? '',
        onBack: _handleCloseCompany,
      );
    }
    switch (_selectedIndex) {
      case 0:
        // Dashboard — tapping a section card jumps to the Assets library.
        return UserDashboardPage(onOpenSection: (_) => _selectPage(1));

      case 1:
        return UserAssetLibraryPage(onOpenCompany: _handleOpenCompany);

      case 2:
        // The API-backed page reads the server download log for this employee.
        return const DownloadsPage();

      default:
        return const UserAssetLibraryPage();
    }
  }

  // ============================================================
  // DOWNLOADS PAGE
  // ============================================================

  Widget _buildDownloadsPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 760;
        final pad = mobile ? 16.0 : 28.0;
        final total = _downloadHistory.length;
        final rows = _filteredDownloads;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, mobile ? 20 : 28, pad, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Downloads',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Your downloaded files from the asset library.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoadingDownloads
                        ? null
                        : _loadDownloadHistory,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        size: 26,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total Downloads',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Files available in your history',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Search
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _downloadSearchController,
                        onChanged: (v) => setState(() => _downloadSearch = v),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search file, asset or company...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    if (_downloadSearch.isNotEmpty)
                      InkWell(
                        onTap: () {
                          _downloadSearchController.clear();
                          setState(() => _downloadSearch = '');
                        },
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Body states
              if (_isLoadingDownloads)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 70),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_downloadError != null)
                _buildDownloadsError()
              else if (_downloadHistory.isEmpty)
                _buildDownloadsEmpty(
                  icon: Icons.download_outlined,
                  title: 'No downloads recorded yet.',
                  message: 'Assets that you download will be listed here.',
                )
              else if (rows.isEmpty)
                _buildDownloadsEmpty(
                  icon: Icons.search_off_outlined,
                  title: 'No matching download records found.',
                  message: 'Try a different file, asset or company name.',
                )
              else if (mobile)
                Column(
                  children: rows
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDownloadCard(item),
                        ),
                      )
                      .toList(),
                )
              else
                _buildDownloadsTable(rows),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadsTable(List<Map<String, dynamic>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFFF6F9FF),
            child: Row(
              children: const [
                Expanded(flex: 26, child: _DlHead('File')),
                Expanded(flex: 24, child: _DlHead('Asset')),
                Expanded(flex: 20, child: _DlHead('Company')),
                Expanded(flex: 14, child: _DlHead('Type')),
                Expanded(flex: 16, child: _DlHead('Downloaded at')),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEFF5FF)),
            _buildDownloadRow(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadRow(Map<String, dynamic> item) {
    final fileName = item['fileName']?.toString() ?? 'Downloaded file';
    final assetName = item['assetName']?.toString() ?? '—';
    final companyName = item['companyName']?.toString() ?? '—';
    final assetType = item['assetType']?.toString() ?? '';
    final downloadedAt = DateTime.tryParse(
      item['downloadedAt']?.toString() ?? '',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 26,
            child: Row(
              children: [
                _downloadFileIcon(fileName, assetType),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              assetName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(flex: 14, child: _downloadTypeBadge(fileName, assetType)),
          Expanded(
            flex: 16,
            child: Text(
              downloadedAt != null ? _formatDownloadDate(downloadedAt) : '—',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(Map<String, dynamic> item) {
    final fileName = item['fileName']?.toString() ?? 'Downloaded file';
    final assetName = item['assetName']?.toString() ?? '';
    final companyName = item['companyName']?.toString() ?? '';
    final assetType = item['assetType']?.toString() ?? '';
    final downloadedAt = DateTime.tryParse(
      item['downloadedAt']?.toString() ?? '',
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _downloadFileIcon(fileName, assetType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (assetName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        assetName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _downloadTypeBadge(fileName, assetType),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.business_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  companyName.isEmpty ? '—' : companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.schedule,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                downloadedAt != null ? _formatDownloadDate(downloadedAt) : '—',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsEmpty({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 44,
            color: PremiumColors.blueDeep,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load downloads',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _downloadError ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loadDownloadHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // File extension helpers for download rows.
  String _downloadExt(String fileName) {
    final clean = fileName.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0 || dot == clean.length - 1) return '';
    return clean.substring(dot + 1).toLowerCase();
  }

  static const _dlImageExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'heic',
    'avif',
  };
  static const _dlVideoExts = {
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    'm4v',
    'mpeg',
    'mpg',
    '3gp',
  };
  static const _dlArchiveExts = {'zip', 'rar', '7z', 'tar', 'gz'};
  static const _dlAppExts = {'apk', 'aab', 'ipa'};

  Widget _downloadFileIcon(String fileName, String assetType) {
    final ext = _downloadExt(fileName);
    IconData icon;
    Color color;
    Color bg;
    if (ext == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      color = const Color(0xFF1240C4);
      bg = const Color(0xFFE3ECFF);
    } else if (_dlArchiveExts.contains(ext)) {
      icon = Icons.folder_zip_outlined;
      color = const Color(0xFF1E3A8A);
      bg = const Color(0xFFE6EEFB);
    } else if (_dlAppExts.contains(ext)) {
      icon = Icons.android;
      color = const Color(0xFF0E7DC2);
      bg = const Color(0xFFE5F3FC);
    } else if (_dlImageExts.contains(ext)) {
      icon = Icons.image_outlined;
      color = AppColors.primary;
      bg = const Color(0xFFEFF6FF);
    } else if (_dlVideoExts.contains(ext)) {
      icon = Icons.play_circle_outline;
      color = const Color(0xFF3B4FD8);
      bg = const Color(0xFFE8EBFD);
    } else if (assetType == 'Web Application' || assetType == 'Website Links') {
      icon = Icons.language_outlined;
      color = AppColors.primary;
      bg = const Color(0xFFEFF6FF);
    } else {
      icon = Icons.insert_drive_file_outlined;
      color = AppColors.textSecondary;
      bg = const Color(0xFFEFF5FF);
    }
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _downloadTypeBadge(String fileName, String assetType) {
    final ext = _downloadExt(fileName);
    String label;
    Color bg;
    Color fg;
    if (ext == 'pdf') {
      label = 'PDF';
      bg = const Color(0xFFE3ECFF);
      fg = const Color(0xFF1240C4);
    } else if (_dlArchiveExts.contains(ext)) {
      label = 'Archive';
      bg = const Color(0xFFE6EEFB);
      fg = const Color(0xFF1E3A8A);
    } else if (_dlAppExts.contains(ext)) {
      label = 'App';
      bg = const Color(0xFFE5F3FC);
      fg = const Color(0xFF0E7DC2);
    } else if (_dlVideoExts.contains(ext) || assetType == 'Reels / Videos') {
      label = 'Video';
      bg = const Color(0xFFE8EBFD);
      fg = const Color(0xFF3B4FD8);
    } else if (_dlImageExts.contains(ext) || assetType == 'Posters') {
      label = assetType == 'Posters' ? 'Poster' : 'Image';
      bg = const Color(0xFFEFF6FF);
      fg = AppColors.primary;
    } else if (assetType == 'Web Application') {
      label = 'Web App';
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF2563EB);
    } else if (assetType == 'Mobile Application') {
      label = 'Mobile App';
      bg = const Color(0xFFE8EBFD);
      fg = const Color(0xFF3B4FD8);
    } else if (assetType == 'Documents') {
      label = 'Document';
      bg = const Color(0xFFE5F3FC);
      fg = const Color(0xFF1B5FE8);
    } else {
      label = assetType.isNotEmpty ? assetType : 'File';
      bg = const Color(0xFFEFF5FF);
      fg = AppColors.textSecondary;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  String _formatDownloadDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    int hour = local.hour % 12;
    if (hour == 0) hour = 12;
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} ${months[local.month - 1]} ${local.year} '
        '${hour.toString().padLeft(2, '0')}:$min $ampm';
  }

  // ============================================================
  // PROFILE PHOTO
  // ============================================================

  Future<void> _loadProfilePhoto() async {
    try {
      final email = await ApiService.getLoggedInUserEmail();
      if (email == null || email.trim().isEmpty) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = _profilePhotoStorageKey(email);
      final savedUrl = prefs.getString(key);

      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhotoUrl = savedUrl;
      });
    } catch (_) {
      // Keep the default avatar when local profile-photo loading fails.
    }
  }

  String _profilePhotoStorageKey(String email) {
    return 'profile_photo_url_${email.trim().toLowerCase()}';
  }

  String _profilePhotoNetworkUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final apiUri = Uri.parse(ApiService.baseUrl);
    final origin = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    );
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return origin.resolve(path).toString();
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PremiumColors.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PremiumSectionHeader(
                  title: 'Notifications',
                  icon: Icons.notifications_rounded,
                  subtitle: 'Updates about your assets and downloads',
                  compact: true,
                  trailing: PremiumIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PremiumColors.soft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCFE0FF)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: PremiumColors.blue,
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'No new notifications.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PremiumColors.body,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LOGOUT CONFIRMATION
  // ============================================================

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PremiumIconTile(icon: Icons.logout_rounded, size: 52),
                  const SizedBox(height: 14),
                  const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: PremiumColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Are you sure you want to logout?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: PremiumColors.muted),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: PremiumButton(
                          label: 'Cancel',
                          icon: Icons.close_rounded,
                          iconLeading: true,
                          expand: true,
                          variant: PremiumButtonVariant.outlined,
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PremiumButton(
                          label: 'Logout',
                          icon: Icons.logout_rounded,
                          iconLeading: true,
                          expand: true,
                          onPressed: () {
                            Navigator.pop(dialogContext);

                            widget.onLogout();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Column header label for the downloads table.
class _DlHead extends StatelessWidget {
  final String label;
  const _DlHead(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: PremiumColors.headerText,
        letterSpacing: 0.2,
      ),
    );
  }
}
