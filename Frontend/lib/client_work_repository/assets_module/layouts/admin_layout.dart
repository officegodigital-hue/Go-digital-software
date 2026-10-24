import 'package:flutter/material.dart';

import '../core/widgets/premium_ui.dart';
import '../models/company_model.dart';
import '../features/admin/company_detail/company_detail_page.dart';
import '../services/api_service.dart';
import '../widgets/navigation/top_bar.dart';

class _MobileNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _MobileNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
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
          final total = matchingCompanies.length + matchingAssets.length;
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            backgroundColor: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 600,
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchDialogHeader(
                    query: query,
                    total: total,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                  Flexible(
                    child: (matchingCompanies.isEmpty && matchingAssets.isEmpty)
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: PremiumEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No matching companies or assets found.',
                              message: 'Try a different name, type or link.',
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            children: [
                              if (matchingCompanies.isNotEmpty) ...[
                                _SearchSectionLabel(
                                  label: 'Companies',
                                  count: matchingCompanies.length,
                                ),
                                for (final company in matchingCompanies.take(
                                  10,
                                ))
                                  _SearchResultTile(
                                    icon: Icons.business_rounded,
                                    title:
                                        company['name']?.toString() ??
                                        'Company',
                                    subtitle: 'Company',
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
                                if (matchingCompanies.isNotEmpty)
                                  const SizedBox(height: 12),
                                _SearchSectionLabel(
                                  label: 'Assets',
                                  count: matchingAssets.length,
                                ),
                                for (final asset in matchingAssets.take(15))
                                  _SearchResultTile(
                                    icon: Icons.insert_drive_file_rounded,
                                    title: asset['name']?.toString() ?? 'Asset',
                                    subtitle:
                                        '${asset['company_name'] ?? 'Company'} • ${asset['type'] ?? 'Asset'}',
                                    onTap: () async {
                                      Navigator.of(dialogContext).pop();
                                      await Future<void>.delayed(
                                        const Duration(milliseconds: 120),
                                      );
                                      if (!mounted) return;
                                      await _openSearchAsset(
                                        assetData: Map<dynamic, dynamic>.from(
                                          asset,
                                        ),
                                        companies: companies,
                                        assets: assets,
                                      );
                                    },
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
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
          backgroundColor: PremiumColors.surface,
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
      backgroundColor: PremiumColors.surface,
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
      _MobileNavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder_rounded,
        label: 'Assets',
      ),
      _MobileNavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person_rounded,
        label: 'Users',
      ),
      _MobileNavItem(
        icon: Icons.shield_outlined,
        activeIcon: Icons.shield_rounded,
        label: 'Permissions',
      ),
      _MobileNavItem(
        icon: Icons.download_outlined,
        activeIcon: Icons.download_rounded,
        label: 'Downloads',
      ),
    ];

    return Scaffold(
      backgroundColor: PremiumColors.surface,
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
              children: List.generate(navItems.length, (i) {
                final item = navItems[i];
                final isActive = selectedIndex == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => _selectPage(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: isActive ? 52 : 40,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? PremiumColors.heroGradient
                                : null,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              if (isActive)
                                const BoxShadow(
                                  color: Color(0x401B5FE8),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            size: 20,
                            color: isActive
                                ? Colors.white
                                : PremiumColors.faint,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? PremiumColors.blue
                                : PremiumColors.muted,
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

// ── Global search dialog pieces ────────────────────────────────────────────

class _SearchDialogHeader extends StatelessWidget {
  final String query;
  final int total;
  final VoidCallback onClose;
  const _SearchDialogHeader({
    required this.query,
    required this.total,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: PremiumColors.heroGradient),
      child: Stack(
        children: [
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 180,
            child: PremiumDots(color: Color(0x40FFFFFF)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Search results for "$query"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$total result${total == 1 ? '' : 's'} across companies and assets',
                        style: const TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SearchSectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: PremiumColors.tableHeaderStyle),
          const SizedBox(width: 8),
          PremiumBadge(label: '$count'),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SearchResultTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: hovered ? PremiumColors.soft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovered ? const Color(0xFFCFE0FF) : PremiumColors.line,
            ),
          ),
          child: Row(
            children: [
              PremiumIconTile(icon: icon, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PremiumColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
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
              AnimatedSlide(
                offset: hovered ? const Offset(0.2, 0) : Offset.zero,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: hovered ? PremiumColors.blue : PremiumColors.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
