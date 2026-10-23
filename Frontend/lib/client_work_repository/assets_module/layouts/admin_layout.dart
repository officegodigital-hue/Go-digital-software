import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/company_model.dart';
import '../features/admin/company_detail/company_detail_page.dart';
import '../services/api_service.dart';
import '../widgets/navigation/top_bar.dart';

class _MobileNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _MobileNavItem({required this.icon, required this.activeIcon, required this.label});
}

class AdminLayout extends StatefulWidget {
  final Widget Function(int index, void Function(int index) onNavigate)
  childBuilder;

  final VoidCallback onLogout;

  const AdminLayout({
    super.key,
    required this.childBuilder,
    required this.onLogout,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int selectedIndex = 0;

  void _selectPage(int index) {
    if (!mounted) {
      return;
    }

    setState(() {
      selectedIndex = index;
    });
  }

  void _selectPageFromDrawer(BuildContext drawerContext, int index) {
    Navigator.of(drawerContext).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _selectPage(index);
    });
  }

  Future<void> _handleGlobalSearch(String value) async {
    final query = value.trim();

    if (query.isEmpty) {
      return;
    }

    try {
      final results = await Future.wait([
        ApiService.getCompanies(),
        ApiService.getAssets(),
      ]);

      final companies = results[0];
      final assets = results[1];

      final q = query.toLowerCase();

      final matchingCompanies = companies.where((item) {
        if (item is! Map) return false;

        final name = item['name']?.toString().toLowerCase() ?? '';
        return name.contains(q);
      }).toList();

      final matchingAssets = assets.where((item) {
        if (item is! Map) return false;

        final name = item['name']?.toString().toLowerCase() ?? '';
        final type = item['type']?.toString().toLowerCase() ?? '';
        final company = item['company_name']?.toString().toLowerCase() ?? '';
        final link = item['link']?.toString().toLowerCase() ?? '';

        return name.contains(q) ||
            type.contains(q) ||
            company.contains(q) ||
            link.contains(q);
      }).toList();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search results for "$query"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: (matchingCompanies.isEmpty && matchingAssets.isEmpty)
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'No matching companies or assets found.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (matchingCompanies.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Companies',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          for (final company in matchingCompanies.take(10))
                            ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 18,
                                child: Icon(Icons.business_outlined, size: 18),
                              ),
                              title: Text(
                                company['name']?.toString() ?? 'Company',
                              ),
                              subtitle: const Text('Company'),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 15,
                              ),
                              onTap: () async {
                                Navigator.of(dialogContext).pop();
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 120),
                                );
                                if (!mounted) return;
                                await _openSearchCompany(
                                  companyData: Map<dynamic, dynamic>.from(
                                    company,
                                  ),
                                  assets: assets,
                                );
                              },
                            ),
                        ],
                        if (matchingAssets.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Assets',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          for (final asset in matchingAssets.take(15))
                            ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 18,
                                child: Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 18,
                                ),
                              ),
                              title: Text(asset['name']?.toString() ?? 'Asset'),
                              subtitle: Text(
                                '${asset['company_name'] ?? 'Company'} • ${asset['type'] ?? 'Asset'}',
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 15,
                              ),
                              onTap: () async {
                                Navigator.of(dialogContext).pop();
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 120),
                                );
                                if (!mounted) return;
                                await _openSearchAsset(
                                  assetData: Map<dynamic, dynamic>.from(asset),
                                  companies: companies,
                                  assets: assets,
                                );
                              },
                            ),
                        ],
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Search failed: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openSearchCompany({
    required Map companyData,
    required List<dynamic> assets,
  }) async {
    if (!mounted) return;

    final companyId = companyData['id']?.toString() ?? '';
    final companyName = companyData['name']?.toString().trim() ?? '';

    if (companyId.isEmpty || companyName.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final createdAt =
        DateTime.tryParse(companyData['created_at']?.toString() ?? '') ?? now;
    final updatedAt =
        DateTime.tryParse(companyData['updated_at']?.toString() ?? '') ??
        createdAt;

    final sections = <String>[];
    final rawSections = companyData['sections'];
    if (rawSections is List) {
      for (final value in rawSections) {
        final section = value?.toString().trim() ?? '';
        if (section.isNotEmpty && !sections.contains(section)) {
          sections.add(section);
        }
      }
    }

    // Prefer the section from the matching asset. This makes an asset search
    // result open the same section where that asset is stored.
    String section = '';
    for (final item in assets) {
      if (item is! Map) continue;
      if (item['company_id']?.toString() != companyId) continue;

      final assetSection = item['section']?.toString().trim() ?? '';
      if (assetSection.isNotEmpty) {
        section = assetSection;
        break;
      }
    }

    if (section.isEmpty && sections.isNotEmpty) {
      section = sections.first;
    }

    // A company without existing assets/sections can still be opened.
    if (section.isEmpty) {
      section = 'Digital Marketing';
    }

    final company = CompanyModel(
      id: companyId,
      name: companyName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      section: section,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          backgroundColor: AppColors.background,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: MediaQuery.sizeOf(dialogContext).height - 40,
            ),
            child: CompanyDetailPage(
              company: company,
              section: section,
              embedded: true,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSearchAsset({
    required Map assetData,
    required List<dynamic> companies,
    required List<dynamic> assets,
  }) async {
    if (!mounted) return;

    final companyId = assetData['company_id']?.toString() ?? '';
    final companyName = assetData['company_name']?.toString().trim() ?? '';
    final assetSection = assetData['section']?.toString().trim() ?? '';

    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This asset is not linked to a company.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Map? companyData;
    for (final item in companies) {
      if (item is Map && item['id']?.toString() == companyId) {
        companyData = item;
        break;
      }
    }

    // Build a minimal company object if the company is not present in the
    // current company response.
    companyData ??= <String, dynamic>{
      'id': companyId,
      'name': companyName.isEmpty ? 'Company' : companyName,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'sections': assetSection.isEmpty ? <String>[] : <String>[assetSection],
    };

    if (assetSection.isNotEmpty) {
      companyData['sections'] = <String>[assetSection];
    }

    await _openSearchCompany(companyData: companyData, assets: assets);
  }

  void _logoutFromDrawer(BuildContext drawerContext) {
    Navigator.of(drawerContext).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.onLogout();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;

        if (isDesktop) {
          return _buildDesktopLayout();
        }

        return _buildMobileLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          NavbarWidget(
            onSearch: _handleGlobalSearch,
            onLogout: widget.onLogout,
            selectedIndex: selectedIndex,
            onNavigate: _selectPage,
          ),

          Expanded(child: widget.childBuilder(selectedIndex, _selectPage)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    const navItems = [
      _MobileNavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Assets'),
      _MobileNavItem(icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Users'),
      _MobileNavItem(icon: Icons.shield_outlined, activeIcon: Icons.shield_rounded, label: 'Permissions'),
      _MobileNavItem(icon: Icons.download_outlined, activeIcon: Icons.download_rounded, label: 'Downloads'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          bottom: false,
          child: NavbarWidget(
            onMenu: () {},
            onSearch: _handleGlobalSearch,
            onLogout: widget.onLogout,
            selectedIndex: selectedIndex,
            onNavigate: _selectPage,
          ),
        ),
      ),
      body: widget.childBuilder(selectedIndex, _selectPage),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(navItems.length, (i) {
                final item = navItems[i];
                final isActive = selectedIndex == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => _selectPage(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          size: 22,
                          color: isActive ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
