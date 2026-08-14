import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../services/mobile_service.dart';
import 'deliverable_files_page.dart';

class DeliverablesPage extends StatefulWidget {
  final int clientId;
  final String clientName;
  final String categorySlug;

  const DeliverablesPage({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.categorySlug,
  });

  @override
  State<DeliverablesPage> createState() => _DeliverablesPageState();
}

class _DeliverablesPageState extends State<DeliverablesPage> {
  final MobileService mobileService = MobileService();

  bool isLoading = true;
  String errorMessage = '';

  Map<String, dynamic> client = {};
  List<Map<String, dynamic>> deliverables = [];

  @override
  void initState() {
    super.initState();
    loadDeliverables();
  }

  Future<void> loadDeliverables() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final data = await mobileService.getClientDeliverables(
        clientId: widget.clientId,
        categorySlug: widget.categorySlug,
      );

      if (!mounted) return;

      setState(() {
        client = Map<String, dynamic>.from(data['client'] ?? {});
        deliverables = List<dynamic>.from(data['deliverables'] ?? [])
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString().replaceAll('Exception:', '').trim();
        isLoading = false;
      });
    }
  }

  String get pageTitle {
    if (widget.categorySlug == 'software-development') {
      return 'Software Development';
    }

    return 'Digital Marketing';
  }

  String normalizeType(String type) {
    final value = type.trim().toLowerCase();

    switch (value) {
      case 'poster':
      case 'poster design':
      case 'poster-design':
      case 'poster_design':
        return 'poster_design';

      case 'landing page':
      case 'landing-page':
      case 'landing_page':
        return 'landing_page';

      case 'other link':
      case 'other-link':
      case 'other_link':
        return 'other_link';

      case 'photo':
      case 'photos':
      case 'image':
      case 'images':
        return 'photos';

      case 'package':
      case 'packages':
        return 'packages';

      case 'portfolio':
      case 'apk':
      case 'apk file':
      case 'apk file upload':
        return 'portfolio';

      case 'mobile application':
      case 'mobile-application':
      case 'mobile_application':
      case 'mobile app':
      case 'mobile-app':
      case 'mobile_app':
        return 'mobile_application';

      case 'website application':
      case 'website-application':
      case 'website_application':
      case 'web application':
      case 'web-application':
      case 'web_application':
      case 'web app':
      case 'web-app':
      case 'web_app':
        return 'website_application';

      default:
        return value.replaceAll('-', '_').replaceAll(' ', '_');
    }
  }

  Map<String, List<Map<String, dynamic>>> groupedDeliverables() {
    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (final item in deliverables) {
      final type = normalizeType(item['deliverable_type']?.toString() ?? '');

      if (type.isEmpty) continue;

      groups.putIfAbsent(type, () => []);
      groups[type]!.add(item);
    }

    return groups;
  }

  List<FolderItem> folders() {
    final groups = groupedDeliverables();

    final List<String> order = widget.categorySlug == 'software-development'
        ? [
            'mobile_application',
            'website_application',
          ]
        : [
            'poster_design',
            'landing_page',
            'website',
            'other_link',
            'packages',
            'portfolio',
            'photos',
          ];

    final List<FolderItem> list = [];

    for (final type in order) {
      final files = groups[type] ?? [];

      if (files.isEmpty) continue;

      list.add(
        FolderItem(
          type: type,
          title: getFolderTitle(type),
          icon: getFolderIcon(type),
          files: files,
        ),
      );
    }

    // Add any future/new types safely.
    for (final entry in groups.entries) {
      final alreadyAdded = list.any((item) => item.type == entry.key);

      if (alreadyAdded || entry.value.isEmpty) continue;

      list.add(
        FolderItem(
          type: entry.key,
          title: getFolderTitle(entry.key),
          icon: getFolderIcon(entry.key),
          files: entry.value,
        ),
      );
    }

    return list;
  }

  String getFolderTitle(String type) {
    switch (type) {
      case 'poster_design':
        return 'Poster Designs';

      case 'landing_page':
        return 'Landing Page';

      case 'video':
        return 'Videos';

      case 'website':
        return 'Websites';

      case 'other_link':
        return 'Other Links';

      case 'packages':
        return 'Packages';

      case 'portfolio':
        return 'APK File Upload';

      case 'photos':
        return 'Photos';

      case 'mobile_application':
        return 'Mobile Application';

      case 'website_application':
        return 'Website Application';

      default:
        return cleanTitle(type);
    }
  }

  IconData getFolderIcon(String type) {
    switch (type) {
      case 'poster_design':
        return Icons.brush_outlined;

      case 'landing_page':
        return Icons.insert_drive_file_outlined;

      case 'video':
        return Icons.video_library_outlined;

      case 'website':
        return Icons.language;

      case 'other_link':
        return Icons.link;

      case 'packages':
        return Icons.inventory_2_outlined;

      case 'portfolio':
        return Icons.android_outlined;

      case 'photos':
        return Icons.photo_library_outlined;

      case 'mobile_application':
        return Icons.phone_android;

      case 'website_application':
        return Icons.web_asset_outlined;

      default:
        return Icons.folder_outlined;
    }
  }

  String cleanTitle(String value) {
    final words = value.replaceAll('_', ' ').split(' ');

    return words
        .where((word) => word.trim().isNotEmpty)
        .map((word) {
          final clean = word.trim();

          if (clean.isEmpty) return clean;

          return clean[0].toUpperCase() + clean.substring(1);
        })
        .join(' ');
  }

  void openFolder(FolderItem folder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeliverableFilesPage(
          title: folder.title,
          files: folder.files,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderList = folders();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            pageHeader(),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : errorMessage.isNotEmpty
                      ? errorView()
                      : folderList.isEmpty
                          ? emptyView()
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(38, 14, 20, 24),
                              itemCount: folderList.length,
                              separatorBuilder: (context, index) {
                                return const SizedBox(height: 14);
                              },
                              itemBuilder: (context, index) {
                                return folderCard(folderList[index]);
                              },
                            ),
            ),
            bottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget pageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          Expanded(
            child: Text(
              '$pageTitle\nDeliverables',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ),
          IconButton(
            onPressed: loadDeliverables,
            icon: const Icon(
              Icons.refresh,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget folderCard(FolderItem folder) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => openFolder(folder),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                folder.icon,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                folder.title,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${folder.files.length} item(s)',
              style: const TextStyle(
                color: AppColors.greyText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFB8C0CC),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: loadDeliverables,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyView() {
    return const Center(
      child: Text(
        'No deliverables found',
        style: TextStyle(
          color: AppColors.greyText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget bottomNavigation() {
    return Container(
      height: 64,
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: bottomNavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ),
          Expanded(
            child: bottomNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: false,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget bottomNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: selected ? AppColors.primary : AppColors.greyText,
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.greyText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class FolderItem {
  final String type;
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> files;

  FolderItem({
    required this.type,
    required this.title,
    required this.icon,
    required this.files,
  });
}
