import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

import '../core/theme/app_theme.dart';
import '../features/user/asset_library/asset_library_page.dart';
import '../features/user/company_assets/company_assets_page.dart';
import '../features/user/dashboard/dashboard_page.dart';
import '../features/user/downloads/downloads_page.dart';
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
      backgroundColor: AppColors.background,
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
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: Colors.white,
      child: Row(
        children: [
          _buildLogo(),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Go Digital',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'User Portal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          _buildNotificationButton(),

          const SizedBox(width: 8),

          _buildUserAvatar(),
        ],
      ),
    );
  }

  // ============================================================
  // DESKTOP LAYOUT
  // ============================================================

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
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
    const navItems = [(0, 'Dashboard'), (1, 'Assets'), (2, 'Downloads')];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Logo (left)
          _buildLogo(),
          const SizedBox(width: 10),
          const Text(
            'Go Digital',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),

          // Centered tabs
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in navItems) ...[
                    _buildTopNavTab(index: item.$1, label: item.$2),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),

          // Right actions
          _buildNotificationButton(),
          const SizedBox(width: 12),
          _buildDesktopUserInfo(),
          const SizedBox(width: 12),
          _buildAvatarMenu(),
        ],
      ),
    );
  }

  Widget _buildTopNavTab({required int index, required String label}) {
    final selected = _selectedIndex == index;
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _selectPage(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'logout') {
          _confirmLogout();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 19, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Logout', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
      child: _buildAvatar(size: 38, fontSize: 15),
    );
  }

  // ============================================================
  // DESKTOP USER INFO
  // ============================================================

  Widget _buildDesktopUserInfo() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/home', (route) => false),
      icon: const Icon(Icons.grid_view_rounded, size: 19),
      label: const Text('Workspace'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============================================================
  // LOGO
  // ============================================================

  Widget _buildLogo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/godigital_logo.png',
        width: 52,
        height: 52,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.primary,
              size: 24,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showNotifications,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none_outlined,
                  size: 25,
                  color: AppColors.primary,
                ),
              ),

              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
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

  Widget _buildUserAvatar() {
    return _buildAvatar(size: 42, fontSize: 18);
  }

  Widget _buildAvatar({required double size, required double fontSize}) {
    final photoBytes = _profilePhotoBytes;
    final photoUrl = _profilePhotoUrl;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
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
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
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
              selectedIcon: Icons.folder,
              label: 'Assets',
            ),

            // DOWNLOADS
            _buildBottomNavItem(
              index: 2,
              icon: Icons.download_outlined,
              selectedIcon: Icons.download,
              label: 'Downloads',
            ),
          ],
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
        child: SizedBox(
          height: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 25,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),

              const SizedBox(height: 4),

              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
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
            color: const Color(0xFFF8FAFC),
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
            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
          const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
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
      color = const Color(0xFFDC2626);
      bg = const Color(0xFFFDE7EC);
    } else if (_dlArchiveExts.contains(ext)) {
      icon = Icons.folder_zip_outlined;
      color = const Color(0xFFB45309);
      bg = const Color(0xFFFEF3C7);
    } else if (_dlAppExts.contains(ext)) {
      icon = Icons.android;
      color = const Color(0xFF16A34A);
      bg = const Color(0xFFE7F8EF);
    } else if (_dlImageExts.contains(ext)) {
      icon = Icons.image_outlined;
      color = AppColors.primary;
      bg = const Color(0xFFEFF6FF);
    } else if (_dlVideoExts.contains(ext)) {
      icon = Icons.play_circle_outline;
      color = const Color(0xFF7C3AED);
      bg = const Color(0xFFEDE9FE);
    } else if (assetType == 'Web Application' || assetType == 'Website Links') {
      icon = Icons.language_outlined;
      color = AppColors.primary;
      bg = const Color(0xFFEFF6FF);
    } else {
      icon = Icons.insert_drive_file_outlined;
      color = AppColors.textSecondary;
      bg = const Color(0xFFF1F5F9);
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
      bg = const Color(0xFFFDE7EC);
      fg = const Color(0xFFDC2626);
    } else if (_dlArchiveExts.contains(ext)) {
      label = 'Archive';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (_dlAppExts.contains(ext)) {
      label = 'App';
      bg = const Color(0xFFE7F8EF);
      fg = const Color(0xFF16A34A);
    } else if (_dlVideoExts.contains(ext) || assetType == 'Reels / Videos') {
      label = 'Video';
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF7C3AED);
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
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF7C3AED);
    } else if (assetType == 'Documents') {
      label = 'Document';
      bg = const Color(0xFFE7F8EF);
      fg = const Color(0xFF15803D);
    } else {
      label = assetType.isNotEmpty ? assetType : 'File';
      bg = const Color(0xFFF1F5F9);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: AppColors.primary,
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'No new notifications.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
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
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                widget.onLogout();
              },
              child: const Text('Logout'),
            ),
          ],
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
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}
