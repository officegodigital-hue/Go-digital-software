import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';
import '../services/api_service.dart';

import '../core/theme/app_theme.dart';
import '../features/user/asset_library/asset_library_page.dart';
import '../services/download_history.dart';

class UserLayout extends StatefulWidget {
  final VoidCallback onLogout;

  const UserLayout({
    super.key,
    required this.onLogout,
  });

  @override
  State<UserLayout> createState() => _UserLayoutState();
}

class _UserLayoutState extends State<UserLayout> {
  // ============================================================
  // NAVIGATION
  // ============================================================

  int _selectedIndex = 0;

  final List<String> _pageTitles = const [
    'Assets',
    'Downloads',
    'Profile',
  ];

  // ============================================================
  // DOWNLOAD HISTORY
  // ============================================================

  List<Map<String, dynamic>> _downloadHistory = [];
  bool _isLoadingDownloads = false;

  // ============================================================
  // PROFILE
  // ============================================================

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;

  String? _profilePhotoUrl;
  Uint8List? _profilePhotoBytes;
  bool _isUploadingProfilePhoto = false;
  String _userRole = 'Employee';

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
      final role = profile['role']?.toString();
      final photoUrl = profile['profile_photo_url']?.toString();

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text =
            name != null && name.trim().isNotEmpty
                ? name.trim()
                : '';

        _emailController.text = email?.trim() ?? '';
        _mobileController.text = profile['mobile']?.toString().trim() ?? '';
        _userRole = role != null && role.trim().isNotEmpty
            ? role.trim()
            : 'Employee';
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

    super.dispose();
  }

  // ============================================================
  // PAGE SELECTION
  // ============================================================

  void _selectPage(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      _loadDownloadHistory();
    }
  }

  Future<void> _loadDownloadHistory() async {
    if (_isLoadingDownloads) {
      return;
    }

    setState(() {
      _isLoadingDownloads = true;
    });

    try {
      final history = await DownloadHistory.getAll();

      if (!mounted) {
        return;
      }

      setState(() {
        _downloadHistory = history;
        _isLoadingDownloads = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _downloadHistory = [];
        _isLoadingDownloads = false;
      });
    }
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

            Expanded(
              child: _buildPage(),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          _buildMobileBottomNavigation(),
    );
  }

  // ============================================================
  // MOBILE TOP BAR
  // ============================================================

  Widget _buildMobileTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
      ),
      color: Colors.white,
      child: Row(
        children: [
          _buildLogo(),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
                    color:
                        AppColors.textSecondary,
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
      body: Row(
        children: [
          _buildDesktopSidebar(),

          Expanded(
            child: Column(
              children: [
                _buildDesktopTopBar(),

                Expanded(
                  child: _buildPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DESKTOP SIDEBAR
  // ============================================================

  Widget _buildDesktopSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: Row(
              children: [
                _buildLogo(),

                const SizedBox(width: 10),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Go Digital',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'User Portal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                          color: AppColors
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              child: Column(
                children: [
                  // ASSETS
                  _buildDesktopNavItem(
                    index: 0,
                    icon: Icons.folder_outlined,
                    selectedIcon: Icons.folder,
                    title: 'Assets',
                  ),

                  // DOWNLOADS
                  _buildDesktopNavItem(
                    index: 1,
                    icon:
                        Icons.download_outlined,
                    selectedIcon:
                        Icons.download,
                    title: 'Downloads',
                  ),

                  // PROFILE
                  _buildDesktopNavItem(
                    index: 2,
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    title: 'Profile',
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: _buildLogoutButton(),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ============================================================
  // DESKTOP TOP BAR
  // ============================================================

  Widget _buildDesktopTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _pageTitles[_selectedIndex],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          _buildNotificationButton(),

          const SizedBox(width: 12),

          _buildDesktopUserInfo(),
        ],
      ),
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
        borderRadius:
            BorderRadius.circular(12),
        onTap: _showNotifications,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons
                      .notifications_none_outlined,
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
                  decoration:
                      const BoxDecoration(
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
    return _buildAvatar(
      size: 42,
      fontSize: 18,
    );
  }

  Widget _buildAvatar({
    required double size,
    required double fontSize,
  }) {
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
    final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  bool get _hasProfilePhoto =>
      _profilePhotoBytes != null || (_profilePhotoUrl?.trim().isNotEmpty ?? false);

  void _showProfilePhotoPreview() {
    if (!_hasProfilePhoto) {
      _showMessage('No profile photo is available yet.');
      return;
    }

    final photoBytes = _profilePhotoBytes;
    final photoUrl = _profilePhotoUrl?.trim();
    final name = _nameController.text.trim().isEmpty
        ? 'Profile photo'
        : _nameController.text.trim();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.66),
      builder: (dialogContext) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final photoSize = (screen.shortestSide * 0.62).clamp(220.0, 420.0).toDouble();
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: photoSize,
                    height: photoSize,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 28, offset: Offset(0, 12)),
                      ],
                    ),
                    child: photoBytes != null
                        ? Image.memory(photoBytes, fit: BoxFit.cover)
                        : Image.network(
                            _profilePhotoNetworkUrl(photoUrl!),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) => progress == null
                                ? child
                                : const Center(child: CircularProgressIndicator(color: Colors.white)),
                            errorBuilder: (context, error, stackTrace) => const ColoredBox(
                              color: AppColors.textSecondary,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.white),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _userRole,
                    style: const TextStyle(color: Color(0xFFD8E1F1), fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  TextButton.icon(
                    onPressed: _isUploadingProfilePhoto
                        ? null
                        : () async {
                            Navigator.of(dialogContext).pop();
                            await _confirmAndRemoveProfilePhoto();
                          },
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    label: const Text('Remove photo'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF7D7D),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: -8,
                top: -8,
                child: Material(
                  color: const Color(0x33111C2E),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndRemoveProfilePhoto() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text('Your profile will show your initials until you upload another photo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove != true || !mounted) return;

    setState(() => _isUploadingProfilePhoto = true);
    try {
      await ApiService.removeProfilePhoto();
      await context.read<AuthService>().updateProfileCache({
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'profile_photo_url': null,
      });
      final email = await ApiService.getLoggedInUserEmail();
      if (email != null && email.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_profilePhotoStorageKey(email));
      }
      if (!mounted) return;
      setState(() {
        _profilePhotoBytes = null;
        _profilePhotoUrl = null;
        _isUploadingProfilePhoto = false;
      });
      _showMessage('Profile photo removed');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingProfilePhoto = false);
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
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
            color:
                Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ASSETS
            _buildBottomNavItem(
              index: 0,
              icon: Icons.folder_outlined,
              selectedIcon: Icons.folder,
              label: 'Assets',
            ),

            // DOWNLOADS
            _buildBottomNavItem(
              index: 1,
              icon: Icons.download_outlined,
              selectedIcon: Icons.download,
              label: 'Downloads',
            ),

            // PROFILE
            _buildBottomNavItem(
              index: 2,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
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
    final selected =
        _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          _selectPage(index);
        },
        child: SizedBox(
          height: 76,
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? selectedIcon
                    : icon,
                size: 25,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),

              const SizedBox(height: 4),

              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP NAV ITEM
  // ============================================================

  Widget _buildDesktopNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String title,
  }) {
    final selected =
        _selectedIndex == index;

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? const Color(0xFFEAF2FF)
            : Colors.transparent,
        borderRadius:
            BorderRadius.circular(10),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(10),
          onTap: () {
            _selectPage(index);
          },
          child: Container(
            height: 48,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? selectedIcon
                      : icon,
                  size: 22,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),

                const SizedBox(width: 12),

                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
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
  // LOGOUT BUTTON
  // ============================================================

  Widget _buildLogoutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(10),
        onTap: _confirmLogout,
        child: Container(
          height: 46,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border,
            ),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.logout,
                size: 20,
                color: AppColors.danger,
              ),

              SizedBox(width: 10),

              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
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
    switch (_selectedIndex) {
      case 0:
        // Assets
        return const UserAssetLibraryPage();

      case 1:
        // Downloads
        return _buildDownloadsPage();

      case 2:
        // Profile
        return _buildProfilePage();

      default:
        return const UserAssetLibraryPage();
    }
  }

  // ============================================================
  // DOWNLOADS PAGE
  // ============================================================

  Widget _buildDownloadsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1050,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Downloads',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Your downloaded assets will appear here.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 26),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: _isLoadingDownloads
                    ? const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _downloadHistory.isEmpty
                        ? _buildEmptyDownloads()
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _downloadHistory.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildDownloadItem(
                                _downloadHistory[index],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDownloads() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 70,
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_outlined,
              size: 38,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'No Downloads Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Assets that you download will be listed here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadItem(Map<String, dynamic> item) {
    final fileName = item['fileName']?.toString() ?? 'Downloaded file';
    final assetName = item['assetName']?.toString() ?? '';
    final assetType = item['assetType']?.toString() ?? '';
    final companyName = item['companyName']?.toString() ?? '';
    final downloadedAt = DateTime.tryParse(
      item['downloadedAt']?.toString() ?? '',
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              borderRadius: BorderRadius.all(
                Radius.circular(10),
              ),
            ),
            child: const Icon(
              Icons.insert_drive_file_outlined,
              color: AppColors.primary,
              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                if (assetName.isNotEmpty) ...[
                  const SizedBox(height: 3),
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

                const SizedBox(height: 6),

                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (companyName.isNotEmpty)
                      _buildDownloadMeta(companyName),
                    if (assetType.isNotEmpty)
                      _buildDownloadMeta(assetType),
                    if (downloadedAt != null)
                      _buildDownloadMeta(
                        _formatDownloadDate(downloadedAt),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadMeta(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _formatDownloadDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ======================================================
          // PROFILE INFORMATION CARD
          // ======================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ==================================================
                // PROFILE HEADER
                // ==================================================

                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Semantics(
                            button: true,
                            label: 'View profile photo',
                            child: GestureDetector(
                              onTap: _showProfilePhotoPreview,
                              child: _buildAvatar(
                                size: 82,
                                fontSize: 32,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _isUploadingProfilePhoto
                                  ? null
                                  : _pickAndUploadProfilePhoto,
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: _isUploadingProfilePhoto
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 17,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (false)
                        OutlinedButton.icon(
                        onPressed: _isUploadingProfilePhoto
                            ? null
                            : _pickAndUploadProfilePhoto,
                        icon: const Icon(
                          Icons.upload_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Change Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 5),

                      const Text(
                        'Update your account information',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // NAME
                // ==================================================

                _buildProfileField(
                  label: 'Name',
                  controller: _nameController,
                  icon: Icons.person_outline,
                  hint: 'Enter your name',
                  keyboardType:
                      TextInputType.name,
                ),

                const SizedBox(height: 18),

                // ==================================================
                // EMAIL
                // ==================================================

                _buildProfileField(
                  label: 'Email',
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  hint: 'Enter your email',
                  keyboardType:
                      TextInputType.emailAddress,
                ),

                const SizedBox(height: 18),

                // ==================================================
                // MOBILE
                // ==================================================

                _buildProfileField(
                  label: 'Mobile Number',
                  controller:
                      _mobileController,
                  icon: Icons.phone_outlined,
                  hint: 'Enter mobile number',
                  keyboardType:
                      TextInputType.phone,
                ),

                const SizedBox(height: 24),

                // ==================================================
                // UPDATE PROFILE BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed:
                        _updateProfile,
                    icon: const Icon(
                      Icons.save_outlined,
                    ),
                    label: const Text(
                      'Update Profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ========================================================
          // ACCOUNT / LOGOUT CARD
          // ========================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Sign out of your Go Digital account.',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 15),

                // ==================================================
                // MOBILE LOGOUT BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed:
                        _confirmLogout,
                    icon: const Icon(
                      Icons.logout,
                      color:
                          AppColors.danger,
                    ),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.danger,
                      ),
                    ),
                    style:
                        OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color:
                            AppColors.danger,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE FIELD
  // ============================================================

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 7),

        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),

            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),

            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
              borderSide:
                  const BorderSide(
                color: AppColors.border,
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(10),
              borderSide:
                  const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
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

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_isUploadingProfilePhoto) {
      return;
    }

    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
        ],
      );

      final file = selection != null && selection.files.isNotEmpty
          ? selection.files.first
          : null;
      final bytes = file?.bytes;
      if (file == null || bytes == null) {
        return;
      }

      if (bytes.isEmpty) {
        _showMessage('Unable to read the selected photo');
        return;
      }

      if (bytes.length > 5 * 1024 * 1024) {
        _showMessage('Profile photo must be 5 MB or smaller');
        return;
      }

      final fileName = file.name.trim();
      final lastDot = fileName.lastIndexOf('.');

      final extension = lastDot >= 0 && lastDot < fileName.length - 1
          ? fileName.substring(lastDot + 1).toLowerCase()
          : '';

      if (!const ['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        _showMessage(
          'Only JPG, JPEG, PNG and WEBP photos are allowed',
        );
        return;
      }

      setState(() {
        _isUploadingProfilePhoto = true;
        _profilePhotoBytes = bytes;
      });

      final user = await ApiService.uploadProfilePhoto(
        photoBytes: bytes,
        fileName: file.name,
      );

      final returnedUrl = user['profile_photo_url']?.toString().trim();

      if (returnedUrl == null || returnedUrl.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _profilePhotoBytes = null;
          _isUploadingProfilePhoto = false;
        });
        _showMessage('Photo uploaded, but the server did not return a photo URL');
        return;
      }

      final email = await ApiService.getLoggedInUserEmail();
      if (email != null && email.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _profilePhotoStorageKey(email),
          returnedUrl,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhotoUrl = returnedUrl;
        _profilePhotoBytes = null;
        _isUploadingProfilePhoto = false;
      });

      _showMessage('Profile photo updated successfully');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhotoBytes = null;
        _isUploadingProfilePhoto = false;
      });

      final message = error.toString().replaceFirst('Exception: ', '').trim();
      _showMessage(
        message.isEmpty ? 'Unable to upload profile photo' : message,
      );
    }
  }

  String _profilePhotoStorageKey(String email) {
    return 'profile_photo_url_${email.trim().toLowerCase()}';
  }

  String _profilePhotoNetworkUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
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
  // UPDATE PROFILE
  // ============================================================

  Future<void> _updateProfile() async {
    final name =
        _nameController.text.trim();
    final email =
        _emailController.text.trim();
    final mobile =
        _mobileController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Name is required',
      );
      return;
    }

    if (email.isEmpty) {
      _showMessage(
        'Email is required',
      );
      return;
    }

    if (mobile.isEmpty) {
      _showMessage(
        'Mobile number is required',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    try {
      final profile = await ApiService.updateMyProfile(
        name: name,
        email: email,
        mobile: mobile,
      );
      if (!mounted) return;
      await context.read<AuthService>().updateProfileCache(profile);
      if (!mounted) return;
      setState(() {
        _nameController.text = profile['name']?.toString() ?? name;
        _emailController.text = profile['email']?.toString() ?? email;
        _mobileController.text = profile['mobile']?.toString() ?? mobile;
      });
      _showMessage('Profile updated across your GoDigital workspaces.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              AppColors.textPrimary,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },
                      icon: const Icon(
                        Icons.close,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFF5F8FF,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons
                            .notifications_outlined,
                        color:
                            AppColors.primary,
                      ),

                      SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'No new notifications.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors
                                .textSecondary,
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
          title: const Text(
            'Logout',
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                widget.onLogout();
              },
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );
  }
}
