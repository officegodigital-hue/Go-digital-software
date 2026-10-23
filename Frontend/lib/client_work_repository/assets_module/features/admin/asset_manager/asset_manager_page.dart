import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/asset_model.dart';
import '../../../models/company_model.dart';
import '../../../services/api_service.dart';
import '../company_detail/company_detail_page.dart';

class AssetManagerPage extends StatefulWidget {
  const AssetManagerPage({super.key});

  @override
  State<AssetManagerPage> createState() => _AssetManagerPageState();
}

class _AssetManagerPageState extends State<AssetManagerPage> {
  // ── State ──────────────────────────────────────────────────────
  String _digitalMarketingFilter = 'All';
  String _softwareDevelopmentFilter = 'All';
  String _digitalMarketingSearch = '';
  String _softwareDevelopmentSearch = '';

  final TextEditingController _digitalSearchController =
      TextEditingController();
  final TextEditingController _softwareSearchController =
      TextEditingController();

  List<CompanyModel> _companies = [];
  List<AssetModel> _assets = [];
  final Map<String, String> _companyLogoUrls = <String, String>{};

  bool _isLoading = true;
  String? _loadError;
  int _selectedTabIndex = 0;

  // ── Filter lists ───────────────────────────────────────────────
  final List<String> _digitalFilters = const [
    'All',
    AppConstants.poster,
    AppConstants.reelVideo,
    AppConstants.document,
    AppConstants.websiteLink,
    AppConstants.others,
  ];

  final List<String> _softwareFilters = const [
    'All',
    AppConstants.webApplication,
    AppConstants.mobileApplication,
    AppConstants.others,
  ];

  // ── Lifecycle ──────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _digitalSearchController.dispose();
    _softwareSearchController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (_loadError != null) return _buildError();

    final isDigital = _selectedTabIndex == 0;
    final section = isDigital
        ? AppConstants.digitalMarketing
        : AppConstants.softwareDevelopment;
    final filter = isDigital
        ? _digitalMarketingFilter
        : _softwareDevelopmentFilter;
    final filters = isDigital ? _digitalFilters : _softwareFilters;
    final searchController = isDigital
        ? _digitalSearchController
        : _softwareSearchController;
    final searchValue = isDigital
        ? _digitalMarketingSearch
        : _softwareDevelopmentSearch;

    final digitalCount = _getCompanies(
      section: AppConstants.digitalMarketing,
      filter: 'All',
      search: '',
    ).length;
    final softwareCount = _getCompanies(
      section: AppConstants.softwareDevelopment,
      filter: 'All',
      search: '',
    ).length;

    final companies = _getCompanies(
      section: section,
      filter: filter,
      search: searchValue,
    );

    final sectionColor = isDigital
        ? AppColors.digitalMarketing
        : AppColors.softwareDevelopment;
    final sectionLightColor = isDigital
        ? AppColors.digitalMarketingLight
        : AppColors.softwareDevelopmentLight;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final inset = compact ? 16.0 : 24.0;
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(inset, compact ? 20 : 24, inset, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Page header
                  _buildPageHeader(compact),
                  const SizedBox(height: 24),

                  // 2. Stat cards
                  _buildStatCards(compact),
                  const SizedBox(height: 24),

                  // 3. Category tabs
                  _buildTabBar(digitalCount, softwareCount),
                  const SizedBox(height: 16),

                  // 3. Section header
                  _buildSectionHeader(
                    section: section,
                    companyCount: companies.length,
                  ),
                  const SizedBox(height: 12),

                  // 4. Search + filter row
                  _buildToolbar(
                    section: section,
                    filter: filter,
                    filters: filters,
                    searchController: searchController,
                    compact: compact,
                  ),
                  const SizedBox(height: 16),

                  // 5. Grid or empty state
                  if (companies.isEmpty)
                    _buildEmptySection(
                      section: section,
                      filter: filter,
                      search: searchValue,
                    )
                  else
                    _buildCompanyGrid(
                      section: section,
                      companies: companies,
                      sectionColor: sectionColor,
                      sectionLightColor: sectionLightColor,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // UI WIDGETS
  // ══════════════════════════════════════════════════════════════

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 14),
            Text(
              'Loading assets...',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Unable to load assets',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? 'An unexpected error occurred.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool compact) {
    final title = const Text(
      'Asset Manager',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
    final createButton = ElevatedButton.icon(
      onPressed: () => _showCreateCompanyDialog(
        _selectedTabIndex == 0
            ? AppConstants.digitalMarketing
            : AppConstants.softwareDevelopment,
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Create Company'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 14), createButton],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Asset Manager',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        createButton,
      ],
    );
  }

  Widget _buildStatCards([bool compact = false]) {
    final totalCompanies = _companies.map((c) => c.id).toSet().length;
    final totalAssets = _assets.length;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final updatedThisWeek = _assets
        .where(
          (a) => a.updatedAt.isAfter(
            DateTime(weekStart.year, weekStart.month, weekStart.day),
          ),
        )
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 520;
        if (isMobile) {
          // Force all 3 in one row with equal widths
          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.business_outlined,
                  label: 'Companies',
                  value: '$totalCompanies',
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.layers_outlined,
                  label: 'Total Assets',
                  value: '$totalAssets',
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Updated This Week',
                  value: '$updatedThisWeek',
                  compact: true,
                ),
              ),
            ],
          );
        }
        final cardWidth = constraints.maxWidth >= 880
            ? (constraints.maxWidth - 48) / 3
            : (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                icon: Icons.business_outlined,
                label: 'Companies',
                value: '$totalCompanies',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                icon: Icons.layers_outlined,
                label: 'Total Assets',
                value: '$totalAssets',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                icon: Icons.bar_chart_rounded,
                label: 'Updated This Week',
                value: '$updatedThisWeek',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    bool compact = false,
  }) {
    if (compact) {
      // Mobile: stacked icon + label + value, all centered
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B7280),
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 26, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(int digitalCount, int softwareCount) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              index: 0,
              label: 'Digital Marketing',
              count: digitalCount,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTab(
              index: 1,
              label: 'Software Development',
              count: softwareCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required String label,
    required int count,
  }) {
    final isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$label ($count)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String section,
    required int companyCount,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            section,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '· $companyCount ${companyCount == 1 ? 'company' : 'companies'}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar({
    required String section,
    required String filter,
    required List<String> filters,
    required TextEditingController searchController,
    bool compact = false,
  }) {
    final search = SizedBox(
      width: 320,
      height: 44,
      child: TextField(
        controller: searchController,
        onChanged: (v) {
          if (!mounted) return;
          setState(() {
            if (section == AppConstants.digitalMarketing) {
              _digitalMarketingSearch = v;
            } else {
              _softwareDevelopmentSearch = v;
            }
          });
        },
        style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: 'Search companies or assets',
          hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(
            Icons.search,
            size: 16,
            color: Color(0xFF9CA3AF),
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    if (!mounted) return;
                    setState(() {
                      if (section == AppConstants.digitalMarketing) {
                        _digitalMarketingSearch = '';
                      } else {
                        _softwareDevelopmentSearch = '';
                      }
                    });
                  },
                  icon: const Icon(Icons.close, size: 16),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
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
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
          ),
        ),
      ),
    );
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildFilterChip(
              item: filters[i],
              selected: filter == filters[i],
              section: section,
            ),
          ],
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: search),
              const SizedBox(height: 12),
              chips,
            ],
          );
        }
        return Row(
          children: [
            search,
            const SizedBox(width: 16),
            Expanded(child: chips),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String item,
    required bool selected,
    required String section,
  }) {
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        setState(() {
          if (section == AppConstants.digitalMarketing) {
            _digitalMarketingFilter = item;
          } else {
            _softwareDevelopmentFilter = item;
          }
        });
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          _filterLabel(item),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyGrid({
    required String section,
    required List<CompanyModel> companies,
    required Color sectionColor,
    required Color sectionLightColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 900
            ? 3
            : w >= 580
            ? 2
            : 1;

        // On mobile (1-column), use a ListView so card height is unconstrained.
        if (cols == 1) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: companies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _buildCompanyCard(company: companies[i], section: section),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: w >= 1200
                ? 4.6
                : w >= 900
                ? 4.0
                : 3.2,
          ),
          itemCount: companies.length,
          itemBuilder: (context, i) =>
              _buildCompanyCard(company: companies[i], section: section),
        );
      },
    );
  }

  Widget _buildCompanyCard({
    required CompanyModel company,
    required String section,
  }) {
    final assets = _assetsFor(
      section,
      'All',
    ).where((a) => a.companyId == company.id).toList();
    final latestDate = _getLatestDate(assets);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final logoSize = compact ? 48.0 : 64.0;
        final hPad = compact ? 14.0 : 20.0;
        final vPad = compact ? 12.0 : 16.0;
        final nameFontSize = compact ? 15.0 : 16.0;
        final subFontSize = compact ? 13.0 : 14.0;
        final btnHPad = compact ? 10.0 : 14.0;
        final btnVPad = compact ? 7.0 : 8.0;
        final btnFontSize = compact ? 13.0 : 14.0;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _openCompany(company: company, section: section),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  _buildCompanyLogoSized(company: company, size: logoSize),
                  SizedBox(width: compact ? 12 : 16),

                  // Company info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          company.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${assets.length} assets',
                          style: TextStyle(
                            fontSize: subFontSize,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Updated $latestDate',
                          style: TextStyle(
                            fontSize: subFontSize,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),

                  // Open assets button
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: btnHPad,
                      vertical: btnVPad,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: compact ? 14 : 15,
                          color: const Color(0xFF2563EB),
                        ),
                        SizedBox(width: compact ? 4 : 6),
                        Text(
                          'View assets',
                          style: TextStyle(
                            fontSize: btnFontSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySection({
    required String section,
    required String filter,
    required String search,
  }) {
    final hasSearch = search.trim().isNotEmpty;
    final hasFilter = filter != 'All';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_outlined,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'No companies found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasSearch || hasFilter
                ? 'Try different search or filter'
                : 'No companies have been created yet.',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LOGO WIDGET
  // ══════════════════════════════════════════════════════════════

  // Named-company overrides (reference mockup companies)
  static const _logoColorMap = <String, Color>{
    'Apex Media': Color(0xFF1F2937),
    'Bloom Digital': Color(0xFFFF6B9D),
    'ClearView Marketing': Color(0xFF10B981),
    'Elevate Brands': Color(0xFF7C3AED),
    'Fusion Creative': Color(0xFFF59E0B),
    'Nexa Marketing': Color(0xFFEF4444),
    'Orbit Digital': Color(0xFF2563EB),
    'Pulse Media': Color(0xFF166534),
    'Vivid Marketing': Color(0xFF8B5CF6),
  };

  // Palette for companies not in the named map — cycles by first letter
  static const _palette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF10B981),
    Color(0xFFD97706),
    Color(0xFFEF4444),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFF4F46E5),
    Color(0xFF9333EA),
  ];

  Color _logoColorForName(String name) {
    final named = _logoColorMap[name.trim()];
    if (named != null) return named;
    final ch = name.trim().isEmpty ? 0 : name.trim().codeUnitAt(0);
    return _palette[ch % _palette.length];
  }

  Color _logoTextColorForName(String name) {
    final bg = _logoColorForName(name);
    return bg.computeLuminance() < 0.45
        ? Colors.white
        : const Color(0xFF111827);
  }

  Widget _buildCompanyLogoSized({
    required CompanyModel company,
    required double size,
  }) {
    final rawLogo = _companyLogoUrls[company.id]?.trim();
    final initial = _companyInitial(company.name);
    final bgColor = _logoColorForName(company.name);
    final textColor = _logoTextColorForName(company.name);
    final radius = BorderRadius.circular(size * 0.22);

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, borderRadius: radius),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.375,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );

    if (rawLogo == null || rawLogo.isEmpty) return fallback;

    final logoUrl = _resolveCompanyLogoUrl(rawLogo);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bgColor, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BACKEND — DO NOT MODIFY
  // ══════════════════════════════════════════════════════════════

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getCompanies(),
        ApiService.getAssets(),
      ]);

      final companyResponse = results[0];
      final assetResponse = results[1];

      final loadedCompanies = <CompanyModel>[];
      final loadedCompanyLogos = <String, String>{};

      for (final item in companyResponse) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final id = data['id']?.toString() ?? '';
        final name = data['name']?.toString().trim() ?? '';
        final logoUrl = data['logo_url']?.toString().trim() ?? '';

        if (id.isEmpty || name.isEmpty) continue;
        if (logoUrl.isNotEmpty) loadedCompanyLogos[id] = logoUrl;

        final now = DateTime.now();
        final createdAt =
            DateTime.tryParse(data['created_at']?.toString() ?? '') ?? now;
        final updatedAt =
            DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
            createdAt;
        final sections = <String>[];
        final rawSections = data['sections'];

        if (rawSections is List) {
          for (final value in rawSections) {
            final s = value?.toString().trim() ?? '';
            if (_isValidSection(s) && !sections.contains(s)) sections.add(s);
          }
        } else if (rawSections is String) {
          try {
            final decoded = jsonDecode(rawSections);
            if (decoded is List) {
              for (final value in decoded) {
                final s = value?.toString().trim() ?? '';
                if (_isValidSection(s) && !sections.contains(s))
                  sections.add(s);
              }
            }
          } catch (_) {}
        }

        final singleSection = data['section']?.toString().trim();
        if (sections.isEmpty &&
            singleSection != null &&
            _isValidSection(singleSection)) {
          sections.add(singleSection);
        }

        if (sections.isEmpty) {
          loadedCompanies.add(
            CompanyModel(
              id: id,
              name: name,
              createdAt: createdAt,
              updatedAt: updatedAt,
              section: null,
              logoUrl: logoUrl.isEmpty ? null : logoUrl,
            ),
          );
        } else {
          for (final s in sections) {
            loadedCompanies.add(
              CompanyModel(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                section: s,
                logoUrl: logoUrl.isEmpty ? null : logoUrl,
              ),
            );
          }
        }
      }

      final loadedAssets = <AssetModel>[];
      for (final item in assetResponse) {
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final id = data['id']?.toString() ?? '';
        final companyId = data['company_id']?.toString() ?? '';
        final companyName = data['company_name']?.toString() ?? '';
        final section = data['section']?.toString() ?? '';
        final type = data['type']?.toString() ?? '';
        final name = data['name']?.toString() ?? '';

        if (id.isEmpty ||
            companyId.isEmpty ||
            section.isEmpty ||
            type.isEmpty ||
            name.isEmpty) {
          continue;
        }

        final now = DateTime.now();
        final createdAt =
            DateTime.tryParse(data['created_at']?.toString() ?? '') ?? now;
        final updatedAt =
            DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
            createdAt;

        loadedAssets.add(
          AssetModel(
            id: id,
            companyId: companyId,
            companyName: companyName,
            section: section,
            type: type,
            name: name,
            description: data['description']?.toString(),
            link: data['link']?.toString(),
            username: data['username']?.toString(),
            password: data['password']?.toString(),
            filePath: data['file_url']?.toString(),
            fileName: data['file_name']?.toString(),
            mimeType: data['mime_type']?.toString(),
            fileSize: data['file_size'] is num
                ? (data['file_size'] as num).toInt()
                : null,
            createdByEmployeeId: data['created_by_employee_id']?.toString(),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
      }

      for (final asset in loadedAssets) {
        final exists = loadedCompanies.any(
          (c) => c.id == asset.companyId && c.section == asset.section,
        );
        if (exists) continue;

        CompanyModel? source;
        for (final c in loadedCompanies) {
          if (c.id == asset.companyId) {
            source = c;
            break;
          }
        }

        if (source != null) {
          loadedCompanies.add(
            CompanyModel(
              id: source.id,
              name: source.name,
              createdAt: source.createdAt,
              updatedAt: source.updatedAt,
              section: asset.section,
            ),
          );
        } else {
          loadedCompanies.add(
            CompanyModel(
              id: asset.companyId,
              name: asset.companyName.isNotEmpty
                  ? asset.companyName
                  : 'Company',
              createdAt: asset.createdAt,
              updatedAt: asset.updatedAt,
              section: asset.section,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _companies = loadedCompanies;
        _assets = loadedAssets;
        _companyLogoUrls
          ..clear()
          ..addAll(loadedCompanyLogos);
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool _isValidSection(String value) =>
      value == AppConstants.digitalMarketing ||
      value == AppConstants.softwareDevelopment;

  List<CompanyModel> _getCompanies({
    required String section,
    required String filter,
    required String search,
  }) {
    final query = search.trim().toLowerCase();
    final companies = _companies.where((company) {
      var belongs = company.section == section;
      if (!belongs && company.section == null) {
        belongs = _assets.any(
          (a) => a.companyId == company.id && a.section == section,
        );
      }
      if (!belongs) return false;

      final companyAssets = _assets.where(
        (a) => a.companyId == company.id && a.section == section,
      );

      if (filter != 'All') {
        if (!companyAssets.any((a) => _assetMatchesFilter(a, filter))) {
          return false;
        }
      }

      if (query.isNotEmpty) {
        final cm = company.name.toLowerCase().contains(query);
        final am = companyAssets.any(
          (a) =>
              a.name.toLowerCase().contains(query) ||
              a.type.toLowerCase().contains(query),
        );
        if (!cm && !am) return false;
      }

      return true;
    }).toList();

    companies.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return companies;
  }

  List<AssetModel> _assetsFor(String section, String filter) {
    return _assets.where((a) {
      if (a.section != section) return false;
      if (filter != 'All' && !_assetMatchesFilter(a, filter)) return false;
      return true;
    }).toList();
  }

  bool _assetMatchesFilter(AssetModel asset, String filter) {
    switch (filter) {
      case AppConstants.poster:
        return asset.type == AppConstants.poster;
      case AppConstants.reelVideo:
        return asset.type == AppConstants.reelVideo;
      case AppConstants.document:
        return asset.type == AppConstants.document;
      case AppConstants.websiteLink:
        return asset.type == AppConstants.websiteLink;
      case AppConstants.webApplication:
        return asset.type == AppConstants.webApplication;
      case AppConstants.mobileApplication:
        return asset.type == AppConstants.mobileApplication;
      case AppConstants.others:
        return asset.type == AppConstants.others;
      default:
        return true;
    }
  }

  String _filterLabel(String value) {
    switch (value) {
      case AppConstants.poster:
        return 'Poster';
      case AppConstants.reelVideo:
        return 'Reel Video';
      case AppConstants.document:
        return 'Document';
      case AppConstants.websiteLink:
        return 'Website Link';
      case AppConstants.webApplication:
        return 'Web Application';
      case AppConstants.mobileApplication:
        return 'Mobile Application';
      case AppConstants.others:
        return 'Others';
      default:
        return 'All';
    }
  }

  Future<void> _openCompany({
    required CompanyModel company,
    required String section,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
      ),
    );
    if (!mounted) return;
    await _loadData();
  }

  Future<void> _showCreateCompanyDialog(String section) async {
    if (!mounted) return;
    final controller = TextEditingController();
    String? logoFileName;
    Uint8List? logoBytes;
    final selectedSections = <String>{section};

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          bool isCreating = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> pickLogo() async {
                try {
                  final selection = await FilePicker.pickFiles(
                    type: FileType.image,
                    allowMultiple: false,
                    withData: true,
                  );
                  final picked = selection != null && selection.files.isNotEmpty
                      ? selection.files.first
                      : null;
                  final bytes = picked?.bytes;
                  if (picked == null || bytes == null) return;

                  if (bytes.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to read the selected image.'),
                      ),
                    );
                    return;
                  }

                  if (bytes.length > 5 * 1024 * 1024) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Company logo must be 5 MB or smaller.'),
                      ),
                    );
                    return;
                  }

                  if (!mounted) return;
                  setDialogState(() {
                    logoFileName = picked.name;
                    logoBytes = bytes;
                  });
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Unable to select logo: '
                        '${error.toString().replaceFirst('Exception: ', '')}',
                      ),
                    ),
                  );
                }
              }

              Future<void> createCompany() async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a company name.'),
                    ),
                  );
                  return;
                }

                setDialogState(() => isCreating = true);

                try {
                  await ApiService.createCompany(
                    name,
                    sections: selectedSections.toList(),
                    logoFileName: logoFileName,
                    logoBytes: logoBytes,
                  );

                  if (!mounted) return;
                  Navigator.of(dialogContext).pop();
                  await _loadData();

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name created successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  setDialogState(() => isCreating = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to create company: '
                        '${error.toString().replaceFirst('Exception: ', '')}',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }

              return AlertDialog(
                title: const Text(
                  'Create Company',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                content: SizedBox(
                  width: 430,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: controller,
                          autofocus: true,
                          enabled: !isCreating,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            hintText: 'Enter company name',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Company Logo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: logoBytes != null && logoBytes!.isNotEmpty
                                  ? Image.memory(logoBytes!, fit: BoxFit.cover)
                                  : const Icon(
                                      Icons.image_outlined,
                                      size: 30,
                                      color: AppColors.textSecondary,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: isCreating ? null : pickLogo,
                                    icon: const Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      logoBytes != null
                                          ? 'Change Logo'
                                          : 'Upload Logo',
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    logoFileName ??
                                        'Optional. JPG, JPEG, PNG, WEBP or GIF. Maximum 5 MB.',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isCreating
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: isCreating ? null : createCompany,
                    icon: isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_business_outlined, size: 18),
                    label: Text(isCreating ? 'Creating...' : 'Create'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  String _resolveCompanyLogoUrl(String logoUrl) {
    final parsed = Uri.tryParse(logoUrl);
    if (parsed != null && parsed.hasScheme) return logoUrl;
    final baseUri = Uri.parse(ApiService.baseUrl);
    final relativePath = logoUrl.startsWith('/') ? logoUrl : '/$logoUrl';
    return baseUri
        .replace(path: relativePath, query: '', fragment: '')
        .toString();
  }

  String _companyInitial(String name) {
    final value = name.trim();
    if (value.isEmpty) return 'C';
    return value.substring(0, 1).toUpperCase();
  }

  String _getLatestDate(Iterable<AssetModel> assets) {
    final list = assets.toList();
    if (list.isEmpty) return '—';
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _formatDate(list.first.updatedAt);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}


