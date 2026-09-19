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

  // Company ID -> backend logo URL/path returned by the API.
  final Map<String, String> _companyLogoUrls = <String, String>{};

  bool _isLoading = true;
  String? _loadError;

  static const double pageTitleSize = 24;
  static const double sectionTitleSize = 19;
  static const double companyNameSize = 16;
  static const double normalTextSize = 14;
  static const double smallTextSize = 13;
  static const double chipTextSize = 12;
  static const double desktopSectionHeight = 700;

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

        if (logoUrl.isNotEmpty) {
          loadedCompanyLogos[id] = logoUrl;
        }

        final now = DateTime.now();

        final createdAt =
            DateTime.tryParse(
              data['created_at']?.toString() ?? '',
            ) ??
            now;

        final updatedAt =
            DateTime.tryParse(
              data['updated_at']?.toString() ?? '',
            ) ??
            createdAt;

        final sections = <String>[];

        final rawSections = data['sections'];

        if (rawSections is List) {
          for (final value in rawSections) {
            final section = value?.toString().trim() ?? '';

            if (_isValidSection(section) &&
                !sections.contains(section)) {
              sections.add(section);
            }
          }
        } else if (rawSections is String) {
          try {
            final decoded = jsonDecode(rawSections);

            if (decoded is List) {
              for (final value in decoded) {
                final section = value?.toString().trim() ?? '';

                if (_isValidSection(section) &&
                    !sections.contains(section)) {
                  sections.add(section);
                }
              }
            }
          } catch (_) {}
        }

        final singleSection =
            data['section']?.toString().trim();

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
          for (final section in sections) {
            loadedCompanies.add(
              CompanyModel(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                section: section,
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
            DateTime.tryParse(
              data['created_at']?.toString() ?? '',
            ) ??
            now;

        final updatedAt =
            DateTime.tryParse(
              data['updated_at']?.toString() ?? '',
            ) ??
            createdAt;

        loadedAssets.add(
          AssetModel(
            id: id,
            companyId: companyId,
            companyName: companyName,
            section: section,
            type: type,
            name: name,
            link: data['link']?.toString(),
            username: data['username']?.toString(),
            password: data['password']?.toString(),
            createdAt: createdAt,
            updatedAt: updatedAt,
            filePath:
                data['file_url']?.toString() ??
                data['file_name']?.toString(),
          ),
        );
      }

      for (final asset in loadedAssets) {
        final exists = loadedCompanies.any(
          (company) =>
              company.id == asset.companyId &&
              company.section == asset.section,
        );

        if (exists) continue;

        CompanyModel? sourceCompany;

        for (final company in loadedCompanies) {
          if (company.id == asset.companyId) {
            sourceCompany = company;
            break;
          }
        }

        if (sourceCompany != null) {
          loadedCompanies.add(
            CompanyModel(
              id: sourceCompany.id,
              name: sourceCompany.name,
              createdAt: sourceCompany.createdAt,
              updatedAt: sourceCompany.updatedAt,
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
        _loadError = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  bool _isValidSection(String value) {
    return value == AppConstants.digitalMarketing ||
        value == AppConstants.softwareDevelopment;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= 1024;

            final horizontalPadding = width < 600
                ? 16.0
                : width < 1024
                    ? 24.0
                    : 32.0;

            if (_isLoading) {
              return _buildLoadingState(horizontalPadding);
            }

            if (_loadError != null) {
              return _buildErrorState(horizontalPadding);
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                40,
              ),
              children: [
                _buildPageHeader(),
                const SizedBox(height: 26),
                if (isDesktop)
                  SizedBox(
                    height: desktopSectionHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildSection(
                            section: AppConstants.digitalMarketing,
                            filter: _digitalMarketingFilter,
                            filters: _digitalFilters,
                            searchController: _digitalSearchController,
                            searchValue: _digitalMarketingSearch,
                            fixedHeight: true,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildSection(
                            section: AppConstants.softwareDevelopment,
                            filter: _softwareDevelopmentFilter,
                            filters: _softwareFilters,
                            searchController:
                                _softwareSearchController,
                            searchValue:
                                _softwareDevelopmentSearch,
                            fixedHeight: true,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSection(
                        section: AppConstants.digitalMarketing,
                        filter: _digitalMarketingFilter,
                        filters: _digitalFilters,
                        searchController: _digitalSearchController,
                        searchValue: _digitalMarketingSearch,
                        fixedHeight: false,
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        section: AppConstants.softwareDevelopment,
                        filter: _softwareDevelopmentFilter,
                        filters: _softwareFilters,
                        searchController: _softwareSearchController,
                        searchValue: _softwareDevelopmentSearch,
                        fixedHeight: false,
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState(double horizontalPadding) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        24,
        horizontalPadding,
        40,
      ),
      children: [
        _buildPageHeader(),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 70),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Loading assets...',
                style: TextStyle(
                  fontSize: normalTextSize,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(double horizontalPadding) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        24,
        horizontalPadding,
        40,
      ),
      children: [
        _buildPageHeader(),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 50,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 42,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load assets',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _loadError ?? 'An unexpected error occurred.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: normalTextSize,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                ),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset Manager',
          style: TextStyle(
            fontSize: pageTitleSize,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Manage companies and their digital assets.',
          style: TextStyle(
            fontSize: normalTextSize,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String section,
    required String filter,
    required List<String> filters,
    required TextEditingController searchController,
    required String searchValue,
    required bool fixedHeight,
  }) {
    final isDigital = section == AppConstants.digitalMarketing;

    final sectionColor = isDigital
        ? AppColors.digitalMarketing
        : AppColors.softwareDevelopment;

    final sectionLightColor = isDigital
        ? AppColors.digitalMarketingLight
        : AppColors.softwareDevelopmentLight;

    final companies = _getCompanies(
      section: section,
      filter: filter,
      search: searchValue,
    );

    final assetCount = _assetsFor(section, 'All').length;

    return Container(
      width: double.infinity,
      height: fixedHeight ? double.infinity : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize:
              fixedHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              section: section,
              sectionColor: sectionColor,
              sectionLightColor: sectionLightColor,
              companyCount: companies.length,
              assetCount: assetCount,
            ),
            const SizedBox(height: 18),
            _buildToolbar(
              section: section,
              filter: filter,
              filters: filters,
              searchController: searchController,
            ),
            const SizedBox(height: 16),
            if (fixedHeight)
              Expanded(
                child: _buildCompanyScrollArea(
                  section: section,
                  companies: companies,
                  sectionColor: sectionColor,
                  sectionLightColor: sectionLightColor,
                ),
              )
            else if (companies.isEmpty)
              _buildEmptySection(
                section: section,
                filter: filter,
                search: searchValue,
              )
            else
              _buildCompanyList(
                section: section,
                companies: companies,
                sectionColor: sectionColor,
                sectionLightColor: sectionLightColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String section,
    required Color sectionColor,
    required Color sectionLightColor,
    required int companyCount,
    required int assetCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sectionLightColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                section == AppConstants.digitalMarketing
                    ? Icons.campaign_outlined
                    : Icons.code_outlined,
                color: sectionColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: sectionTitleSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$assetCount',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'Assets',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          section == AppConstants.digitalMarketing
              ? 'Manage posters, reels, documents, website links and other marketing assets.'
              : 'Manage web applications, mobile applications and other software assets.',
          style: const TextStyle(
            fontSize: normalTextSize,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),

        // IMPORTANT:
        // Row + Expanded keeps the company count on the left
        // and Create Company permanently on the right.
        Row(
          children: [
            Expanded(
              child: Text(
                '$companyCount ${companyCount == 1 ? 'company' : 'companies'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: smallTextSize,
                  fontWeight: FontWeight.w700,
                  color: sectionColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () {
                _showCreateCompanyDialog(section);
              },
              icon: const Icon(
                Icons.add,
                size: 18,
              ),
              label: const Text(
                'Create Company',
                style: TextStyle(
                  fontSize: normalTextSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: sectionColor,
                side: BorderSide(
                  color: sectionColor,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                minimumSize: Size.zero,
                tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar({
    required String section,
    required String filter,
    required List<String> filters,
    required TextEditingController searchController,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================================
        // FILTERS
        // ============================================================
        // Keep the filter area the same height in both sections.
        // Digital Marketing uses two rows on desktop, while Software
        // Development usually uses one row. The minimum height makes
        // the search bars and the company/asset lists start at exactly
        // the same vertical position in both sections.
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 87,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final item in filters)
                    _buildFilterChip(
                      item: item,
                      selected: filter == item,
                      section: section,
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ============================================================
        // SEARCH
        // ============================================================
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextField(
            controller: searchController,
            onChanged: (value) {
              if (!mounted) return;

              setState(() {
                if (section == AppConstants.digitalMarketing) {
                  _digitalMarketingSearch = value;
                } else {
                  _softwareDevelopmentSearch = value;
                }
              });
            },
            style: const TextStyle(
              fontSize: normalTextSize,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search company or asset',
              hintStyle: const TextStyle(
                fontSize: normalTextSize,
                color: AppColors.textSecondary,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();

                        if (!mounted) return;

                        setState(() {
                          if (section ==
                              AppConstants.digitalMarketing) {
                            _digitalMarketingSearch = '';
                          } else {
                            _softwareDevelopmentSearch = '';
                          }
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String item,
    required bool selected,
    required String section,
  }) {
    return ChoiceChip(
      label: Text(
        _filterLabel(item),
        maxLines: 1,
        style: TextStyle(
          fontSize: chipTextSize,
          fontWeight:
              selected ? FontWeight.w700 : FontWeight.w600,
          color:
              selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        if (!mounted) return;

        setState(() {
          if (section == AppConstants.digitalMarketing) {
            _digitalMarketingFilter = item;
          } else {
            _softwareDevelopmentFilter = item;
          }
        });
      },
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF5F7FA),
      side: BorderSide(
        color:
            selected ? AppColors.primary : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      materialTapTargetSize:
          MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(
        horizontal: -1,
        vertical: -1,
      ),
    );
  }

  Widget _buildCompanyScrollArea({
    required String section,
    required List<CompanyModel> companies,
    required Color sectionColor,
    required Color sectionLightColor,
  }) {
    if (companies.isEmpty) {
      return SingleChildScrollView(
        child: _buildEmptySection(
          section: section,
          filter: section == AppConstants.digitalMarketing
              ? _digitalMarketingFilter
              : _softwareDevelopmentFilter,
          search: section == AppConstants.digitalMarketing
              ? _digitalMarketingSearch
              : _softwareDevelopmentSearch,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(
        bottom: 4,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: companies.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildCompanyCard(
          company: companies[index],
          section: section,
          sectionColor: sectionColor,
          sectionLightColor: sectionLightColor,
        );
      },
    );
  }

  Widget _buildCompanyList({
    required String section,
    required List<CompanyModel> companies,
    required Color sectionColor,
    required Color sectionLightColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final company in companies)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCompanyCard(
              company: company,
              section: section,
              sectionColor: sectionColor,
              sectionLightColor: sectionLightColor,
            ),
          ),
      ],
    );
  }

  Widget _buildCompanyCard({
    required CompanyModel company,
    required String section,
    required Color sectionColor,
    required Color sectionLightColor,
  }) {
    final assets = _assetsFor(
      section,
      'All',
    ).where(
      (asset) => asset.companyId == company.id,
    ).toList();

    final latestDate = _getLatestDate(assets);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildCompanyLogo(
            company: company,
            sectionColor: sectionColor,
            sectionLightColor: sectionLightColor,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: companyNameSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${assets.length} ${assets.length == 1 ? 'asset' : 'assets'}',
                      style: const TextStyle(
                        fontSize: smallTextSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (assets.isNotEmpty)
                      Text(
                        'Updated: $latestDate',
                        style: const TextStyle(
                          fontSize: smallTextSize,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              _openCompany(
                company: company,
                section: section,
              );
            },
            icon: const Icon(
              Icons.folder_open_outlined,
              size: 17,
            ),
            label: const Text(
              'Open',
              style: TextStyle(
                fontSize: normalTextSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: sectionColor,
              side: BorderSide(
                color: sectionColor,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 9,
              ),
              minimumSize: Size.zero,
              tapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
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

    String message;

    if (hasSearch) {
      message = 'No companies or assets match your search.';
    } else if (hasFilter) {
      message = 'No companies contain this asset type.';
    } else {
      message = 'No companies have been created yet.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            section == AppConstants.digitalMarketing
                ? Icons.campaign_outlined
                : Icons.code_outlined,
            size: 34,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: normalTextSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<CompanyModel> _getCompanies({
    required String section,
    required String filter,
    required String search,
  }) {
    final query = search.trim().toLowerCase();

    final companies = _companies.where((company) {
      var belongsToSection = company.section == section;

      if (!belongsToSection && company.section == null) {
        belongsToSection = _assets.any(
          (asset) =>
              asset.companyId == company.id &&
              asset.section == section,
        );
      }

      if (!belongsToSection) return false;

      final companyAssets = _assets.where(
        (asset) =>
            asset.companyId == company.id &&
            asset.section == section,
      );

      if (filter != 'All') {
        final hasMatchingAsset = companyAssets.any(
          (asset) => _assetMatchesFilter(asset, filter),
        );

        if (!hasMatchingAsset) return false;
      }

      if (query.isNotEmpty) {
        final companyMatches =
            company.name.toLowerCase().contains(query);

        final assetMatches = companyAssets.any(
          (asset) =>
              asset.name.toLowerCase().contains(query) ||
              asset.type.toLowerCase().contains(query),
        );

        if (!companyMatches && !assetMatches) {
          return false;
        }
      }

      return true;
    }).toList();

    companies.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(b.name.toLowerCase()),
    );

    return companies;
  }

  List<AssetModel> _assetsFor(
    String section,
    String filter,
  ) {
    return _assets.where((asset) {
      if (asset.section != section) return false;

      if (filter != 'All' &&
          !_assetMatchesFilter(asset, filter)) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _assetMatchesFilter(
    AssetModel asset,
    String filter,
  ) {
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
        return 'Posters';

      case AppConstants.reelVideo:
        return 'Reels / Videos';

      case AppConstants.document:
        return 'Documents';

      case AppConstants.websiteLink:
        return 'Website Links';

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
              maxHeight:
                  MediaQuery.sizeOf(dialogContext).height - 40,
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

    if (!mounted) return;

    await _loadData();
  }

  Future<void> _showCreateCompanyDialog(
    String section,
  ) async {
    if (!mounted) return;

    final controller = TextEditingController();

    String? logoFileName;
    Uint8List? logoBytes;

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
                  if (picked == null || bytes == null) {
                    return;
                  }

                  if (bytes.isEmpty) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to read the selected image.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (bytes.length > 5 * 1024 * 1024) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Company logo must be 5 MB or smaller.',
                        ),
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
                      content: Text(
                        'Please enter a company name.',
                      ),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  isCreating = true;
                });

                try {
                  await ApiService.createCompany(
                    name,
                    section: section,
                    logoFileName: logoFileName,
                    logoBytes: logoBytes,
                  );

                  if (!mounted) return;

                  Navigator.of(dialogContext).pop();

                  await _loadData();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$name created successfully.',
                        style: const TextStyle(
                          fontSize: normalTextSize,
                        ),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;

                  setDialogState(() {
                    isCreating = false;
                  });

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
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create a company under $section.',
                          style: const TextStyle(
                            fontSize: normalTextSize,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          enabled: !isCreating,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            hintText: 'Enter company name',
                            prefixIcon: Icon(
                              Icons.business_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Company Logo',
                          style: TextStyle(
                            fontSize: normalTextSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.border,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: logoBytes != null &&
                                      logoBytes!.isNotEmpty
                                  ? Image.memory(
                                      logoBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.image_outlined,
                                      size: 30,
                                      color:
                                          AppColors.textSecondary,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed:
                                        isCreating
                                            ? null
                                            : pickLogo,
                                    icon: const Icon(
                                      Icons
                                          .cloud_upload_outlined,
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
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color:
                                          AppColors.textSecondary,
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
                        : () {
                            Navigator.of(
                              dialogContext,
                            ).pop();
                          },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        isCreating ? null : createCompany,
                    icon: isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.add_business_outlined,
                            size: 18,
                          ),
                    label: Text(
                      isCreating ? 'Creating...' : 'Create',
                    ),
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

  // ============================================================
  // COMPANY LOGO
  // ============================================================

  Widget _buildCompanyLogo({
    required CompanyModel company,
    required Color sectionColor,
    required Color sectionLightColor,
  }) {
    final rawLogo = _companyLogoUrls[company.id]?.trim();

    if (rawLogo == null || rawLogo.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sectionLightColor,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          _companyInitial(company.name),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: sectionColor,
          ),
        ),
      );
    }

    final logoUrl = _resolveCompanyLogoUrl(rawLogo);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: sectionLightColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        logoUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            alignment: Alignment.center,
            color: sectionLightColor,
            child: Text(
              _companyInitial(company.name),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: sectionColor,
              ),
            ),
          );
        },
      ),
    );
  }

  String _resolveCompanyLogoUrl(String logoUrl) {
    final parsed = Uri.tryParse(logoUrl);

    if (parsed != null && parsed.hasScheme) {
      return logoUrl;
    }

    final baseUri = Uri.parse(ApiService.baseUrl);

    final relativePath = logoUrl.startsWith('/')
        ? logoUrl
        : '/$logoUrl';

    return baseUri
        .replace(
          path: relativePath,
          query: '',
          fragment: '',
        )
        .toString();
  }

  String _companyInitial(String name) {
    final value = name.trim();

    if (value.isEmpty) {
      return 'C';
    }

    return value.substring(0, 1).toUpperCase();
  }

  String _getLatestDate(
    Iterable<AssetModel> assets,
  ) {
    final list = assets.toList();

    if (list.isEmpty) {
      return '—';
    }

    list.sort(
      (a, b) => b.updatedAt.compareTo(a.updatedAt),
    );

    return _formatDate(list.first.updatedAt);
  }

  String _formatDate(DateTime date) {
    final day = date.day
        .toString()
        .padLeft(2, '0');

    final month = date.month
        .toString()
        .padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}
