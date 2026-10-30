import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/premium_ui.dart';
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

  PremiumAccent _accentFor(String section) =>
      section == AppConstants.digitalMarketing
      ? PremiumAccent.blue
      : PremiumAccent.violet;

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
        ? PremiumAccent.blue.start
        : PremiumAccent.violet.start;
    final sectionLightColor = isDigital
        ? PremiumAccent.blue.soft
        : PremiumAccent.violet.soft;

    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: PremiumStickyPage(
        // 1–2. Header and stats scroll away.
        top: (context, bp) => [
          Reveal(child: _buildPageHeader(bp.mobile)),
          SizedBox(height: bp.gap),
          _buildStatCards(bp.mobile),
          const SizedBox(height: 4),
        ],
        // 3. Tabs, section header, search + filters stay pinned on top.
        pinnedHeight: _pinnedPanelHeight,
        pinned: (context, bp) => PremiumPanel(
          padding: EdgeInsets.all(bp.mobile ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabBar(digitalCount, softwareCount),
              const SizedBox(height: 10),
              _buildSectionHeader(
                section: section,
                companyCount: companies.length,
              ),
              const SizedBox(height: 10),
              _buildToolbar(
                section: section,
                filter: filter,
                filters: filters,
                searchController: searchController,
                compact: bp.mobile,
              ),
            ],
          ),
        ),
        // 4. Grid or empty state scrolls under the pinned panel.
        body: (context, bp) => [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            child: KeyedSubtree(
              key: ValueKey('$section|$filter|${companies.isEmpty}'),
              child: companies.isEmpty
                  ? _buildEmptySection(
                      section: section,
                      filter: filter,
                      search: searchValue,
                    )
                  : _buildCompanyGrid(
                      section: section,
                      companies: companies,
                      sectionColor: sectionColor,
                      sectionLightColor: sectionLightColor,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Height of the pinned panel; taller when search and chips stack.
  double _pinnedPanelHeight(PremiumBreakpoint bp) {
    final pad = bp.mobile ? 12.0 : 14.0;
    final inner = bp.width - bp.gutter * 2 - pad * 2;
    return inner < 760 ? 226.0 : 176.0;
  }

  // ══════════════════════════════════════════════════════════════
  // UI WIDGETS
  // ══════════════════════════════════════════════════════════════

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: PremiumColors.surface,
      body: PremiumBackground(
        child: PremiumLoading(label: 'Loading assets...'),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: PremiumBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Reveal(
                child: PremiumPanel(
                  child: PremiumErrorState(
                    title: 'Unable to load assets',
                    message: _loadError ?? 'An unexpected error occurred.',
                    onRetry: _loadData,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool compact) {
    return PremiumHero(
      compact: compact,
      eyebrow: 'Asset library',
      eyebrowIcon: Icons.folder_special_rounded,
      title: 'Asset Manager',
      subtitle: 'Browse every company\'s marketing and development assets in one place.',
      actions: [
        PremiumButton(
          label: 'Create Company',
          icon: Icons.add_rounded,
          iconLeading: true,
          variant: PremiumButtonVariant.light,
          onPressed: () => _showCreateCompanyDialog(
            _selectedTabIndex == 0
                ? AppConstants.digitalMarketing
                : AppConstants.softwareDevelopment,
          ),
        ),
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

    return PremiumStatRow(
      stats: [
        PremiumStat(
          label: 'Companies',
          value: totalCompanies,
          icon: Icons.business_rounded,
          accent: PremiumAccent.blue,
          caption: 'Unique companies',
        ),
        PremiumStat(
          label: 'Total Assets',
          value: totalAssets,
          icon: Icons.layers_rounded,
          accent: PremiumAccent.green,
          caption: 'Across both sections',
        ),
        PremiumStat(
          label: 'Updated This Week',
          value: updatedThisWeek,
          icon: Icons.bar_chart_rounded,
          accent: PremiumAccent.violet,
          caption: 'Since Monday',
        ),
      ],
    );
  }

  Widget _buildTabBar(int digitalCount, int softwareCount) {
    return PremiumSegmentedTabs(
      labels: const ['Digital Marketing', 'Software Development'],
      counts: [digitalCount, softwareCount],
      icons: const [Icons.campaign_rounded, Icons.code_rounded],
      selected: _selectedTabIndex,
      onChanged: (index) => setState(() => _selectedTabIndex = index),
    );
  }

  Widget _buildSectionHeader({
    required String section,
    required int companyCount,
  }) {
    final isDigital = section == AppConstants.digitalMarketing;
    return Row(
      children: [
        PremiumIconTile(
          icon: isDigital ? Icons.campaign_rounded : Icons.code_rounded,
          accent: _accentFor(section),
          size: 36,
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            section,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: PremiumColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 10),
        PremiumBadge(
          label: '$companyCount ${companyCount == 1 ? 'company' : 'companies'}',
          icon: Icons.business_rounded,
          accent: _accentFor(section),
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
    final search = PremiumSearchField(
      controller: searchController,
      hint: 'Search companies or assets',
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
      onClear: () {
        if (!mounted) return;
        setState(() {
          if (section == AppConstants.digitalMarketing) {
            _digitalMarketingSearch = '';
          } else {
            _softwareDevelopmentSearch = '';
          }
        });
      },
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
            children: [search, const SizedBox(height: 14), chips],
          );
        }
        return Row(
          children: [
            SizedBox(width: 340, child: search),
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
    return PremiumFilterChip(
      label: _filterLabel(item),
      selected: selected,
      accent: _accentFor(section),
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
        const spacing = 12.0;
        final cardWidth = ((w - spacing * (cols - 1)) / cols).floorToDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < companies.length; i++)
              Reveal(
                delay: Duration(milliseconds: 40 * math.min(i, 12)),
                child: SizedBox(
                  width: cardWidth,
                  child: _buildCompanyCard(
                    company: companies[i],
                    section: section,
                    stripe: sectionColor,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCompanyCard({
    required CompanyModel company,
    required String section,
    Color? stripe,
  }) {
    final assets = _assetsFor(
      section,
      'All',
    ).where((a) => a.companyId == company.id).toList();
    final latestDate = _getLatestDate(assets);
    final accent = _accentFor(section);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final logoSize = compact ? 42.0 : 48.0;

        return HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder: (context, hovered) => GestureDetector(
            onTap: () => _openCompany(company: company, section: section),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, hovered ? -5 : 0, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hovered
                      ? accent.start.withAlpha(100)
                      : PremiumColors.line,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.start.withAlpha(hovered ? 45 : 14),
                    blurRadius: hovered ? 28 : 16,
                    offset: Offset(0, hovered ? 14 : 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        width: hovered ? 5 : 3,
                        color: stripe ?? accent.start,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(compact ? 12 : 14),
                      child: Row(
                        children: [
                          AnimatedScale(
                            scale: hovered ? 1.06 : 1,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutBack,
                            child: _buildCompanyLogoSized(
                              company: company,
                              size: logoSize,
                            ),
                          ),
                          SizedBox(width: compact ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  company.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: compact ? 15.5 : 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: PremiumColors.ink,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                PremiumBadge(
                                  label:
                                      '${assets.length} asset${assets.length == 1 ? '' : 's'}',
                                  icon: Icons.layers_rounded,
                                  accent: PremiumAccent.green,
                                ),
                                const SizedBox(height: 6),
                                PremiumBadge(
                                  label: 'Updated $latestDate',
                                  icon: Icons.schedule_rounded,
                                  accent: PremiumAccent.slate,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: compact ? 8 : 12),
                          _viewAssetsPill(accent, hovered, compact),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _viewAssetsPill(PremiumAccent accent, bool hovered, bool compact) {
    final color = hovered ? Colors.white : accent.start;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        gradient: hovered ? accent.gradient : null,
        color: hovered ? null : accent.soft,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: accent.start.withAlpha(hovered ? 70 : 0),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: compact ? 15 : 16,
            color: color,
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            compact ? 'View' : 'View assets',
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSlide(
            offset: hovered ? const Offset(0.25, 0) : Offset.zero,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.arrow_forward_rounded, size: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySection({
    required String section,
    required String filter,
    required String search,
  }) {
    final hasSearch = search.trim().isNotEmpty;
    final hasFilter = filter != 'All';
    return PremiumPanel(
      child: PremiumEmptyState(
        icon: hasSearch || hasFilter
            ? Icons.search_off_rounded
            : Icons.folder_open_rounded,
        accent: _accentFor(section),
        title: 'No companies found',
        message: hasSearch || hasFilter
            ? 'Try different search or filter'
            : 'No companies have been created yet.',
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LOGO WIDGET
  // ══════════════════════════════════════════════════════════════

  // Named-company overrides (reference mockup companies)
  static const _logoColorMap = <String, Color>{
    'Apex Media': Color(0xFF0B1B3F),
    'Bloom Digital': Color(0xFF1E3A8A),
    'ClearView Marketing': Color(0xFF0284C7),
    'Elevate Brands': Color(0xFF1D4ED8),
    'Fusion Creative': Color(0xFF1E3A8A),
    'Nexa Marketing': Color(0xFF3B5B9A),
    'Orbit Digital': Color(0xFF2563EB),
    'Pulse Media': Color(0xFF0284C7),
    'Vivid Marketing': Color(0xFF1D4ED8),
  };

  // Palette for companies not in the named map — cycles by first letter
  static const _palette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF1D4ED8),
    Color(0xFF0284C7),
    Color(0xFF1E3A8A),
    Color(0xFF3B5B9A),
    Color(0xFF0369A1),
    Color(0xFF0284C7),
    Color(0xFF3B5B9A),
    Color(0xFF1D4ED8),
    Color(0xFF1D4ED8),
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
        : const Color(0xFF0B1B3F);
  }

  Widget _buildCompanyLogoSized({
    required CompanyModel company,
    required double size,
  }) {
    final rawLogo = _companyLogoUrls[company.id]?.trim();
    final initial = _companyInitial(company.name);
    final bgColor = _logoColorForName(company.name);
    final textColor = _logoTextColorForName(company.name);
    final radius = BorderRadius.circular(size * 0.28);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [bgColor, Color.lerp(bgColor, Colors.white, 0.3)!],
    );
    final shadow = [
      BoxShadow(
        color: bgColor.withAlpha(60),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ];

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: shadow,
      ),
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
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
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
