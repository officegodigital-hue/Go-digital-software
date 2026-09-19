import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/asset_model.dart';
import '../../../models/company_model.dart';
import '../../../services/api_service.dart';
import '../company_assets/company_assets_page.dart';

class UserAssetLibraryPage extends StatefulWidget {
  const UserAssetLibraryPage({
    super.key,
  });

  @override
  State<UserAssetLibraryPage> createState() =>
      _UserAssetLibraryPageState();
}

class _UserAssetLibraryPageState
    extends State<UserAssetLibraryPage> {
  // ============================================================
  // SEARCH
  // ============================================================

  String _digitalMarketingSearch = '';
  String _softwareDevelopmentSearch = '';

  // ============================================================
  // FILTERS
  // ============================================================

  String _digitalMarketingFilter = 'All';
  String _softwareDevelopmentFilter = 'All';

  // ============================================================
  // API DATA
  // ============================================================

  List<CompanyModel> _companies = [];
  List<AssetModel> _assets = [];

  bool _isLoading = true;
  String? _loadError;

  bool _canView = false;
  bool _canDownload = false;
  bool _canCreateCompany = false;

  // Explicit controller shared by the internal company ListView
  // and its Scrollbar.
  final ScrollController _companyScrollController =
      ScrollController();

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
  }

  @override
  void dispose() {
    _companyScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await ApiService.getMyPermissions();

      if (!mounted) return;

      setState(() {
        _canView = permissions['can_view'] == true;
        _canDownload = permissions['can_download'] == true;
        _canCreateCompany =
            permissions['can_create_company'] == true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _canView = false;
        _canDownload = false;
        _canCreateCompany = false;
      });
    }
  }

  // ============================================================
  // LOAD DATA FROM BACKEND / MYSQL
  // ============================================================

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final companyResponse = await ApiService.getCompanies();
      final assetResponse = await ApiService.getAssets();

      final loadedCompanies = <CompanyModel>[];

      for (final item in companyResponse) {
        if (item is! Map) continue;

        final data = Map<String, dynamic>.from(item);
        final id = data['id']?.toString();

        if (id == null || id.isEmpty) continue;

        final name = data['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;

        final logoUrl = data['logo_url']?.toString().trim();

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

        // New backend returns a sections array because one
        // company can belong to both portal sections.
        final rawSections = data['sections'];

        final sections = <String>[];

        if (rawSections is List) {
          for (final value in rawSections) {
            final section = value?.toString().trim() ?? '';
            if (section.isNotEmpty &&
                !sections.contains(section)) {
              sections.add(section);
            }
          }
        }

        // Backward compatibility if the API returns one section.
        final singleSection =
            data['section']?.toString().trim();

        if (sections.isEmpty &&
            singleSection != null &&
            singleSection.isNotEmpty) {
          sections.add(singleSection);
        }

        // If no section was returned, don't guess one.
        // The company will simply not appear in either section.
        if (sections.isEmpty) {
          continue;
        }

        for (final section in sections) {
          if (section != AppConstants.digitalMarketing &&
              section != AppConstants.softwareDevelopment) {
            continue;
          }

          loadedCompanies.add(
            CompanyModel(
              id: id,
              name: name,
              createdAt: createdAt,
              updatedAt: updatedAt,
              section: section,
              logoUrl: logoUrl,
            ),
          );
        }
      }

      final loadedAssets = <AssetModel>[];

      for (final item in assetResponse) {
        if (item is! Map) continue;

        final data = Map<String, dynamic>.from(item);
        final id = data['id']?.toString();

        if (id == null || id.isEmpty) continue;

        final companyId =
            data['company_id']?.toString() ?? '';

        final companyName =
            data['company_name']?.toString() ?? '';

        final section =
            data['section']?.toString() ?? '';

        final type =
            data['type']?.toString() ?? '';

        final name =
            data['name']?.toString() ?? '';

        if (companyId.isEmpty ||
            section.isEmpty ||
            type.isEmpty ||
            name.isEmpty) {
          continue;
        }

        final now = DateTime.now();

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
            createdAt:
                DateTime.tryParse(
                  data['created_at']?.toString() ?? '',
                ) ??
                now,
            updatedAt:
                DateTime.tryParse(
                  data['updated_at']?.toString() ?? '',
                ) ??
                now,
            filePath:
                data['file_url']?.toString() ??
                data['file_name']?.toString(),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _companies = loadedCompanies;
        _assets = loadedAssets;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError =
            error.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;
    final isCompactDesktop = width < 1200;

    if (_isLoading) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_loadError != null) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 42,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load assets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 18 : 24,
          isMobile ? 16 : 24,
          32,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildPageHeader(),

            const SizedBox(height: 24),

            if (isMobile || isCompactDesktop)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDigitalMarketingSection(),

                  const SizedBox(height: 18),

                  _buildSoftwareDevelopmentSection(),
                ],
              )
            else
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        _buildDigitalMarketingSection(),
                  ),

                  const SizedBox(width: 18),

                  Expanded(
                    child:
                        _buildSoftwareDevelopmentSection(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAGE HEADER
  // ============================================================

  Widget _buildPageHeader() {
    return const Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Asset Library',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: 6),

              Text(
                'Access your digital marketing and software development assets.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }


  // ============================================================
  // DIGITAL MARKETING
  // ============================================================

  Widget _buildDigitalMarketingSection() {
    return _buildSectionCard(
      section: AppConstants.digitalMarketing,
      title: AppConstants.digitalMarketing,
      description:
          'Posters, reels, documents, website links and other marketing assets.',
      icon: Icons.campaign_outlined,
      color: AppColors.digitalMarketing,
      lightColor:
          AppColors.digitalMarketingLight,
      filters: const [
        'All',
        'Poster',
        'Reel / Video',
        'Document',
        'Website Link',
        'Others',
      ],
      selectedFilter:
          _digitalMarketingFilter,
      search: _digitalMarketingSearch,
      onSearchChanged: (value) {
        setState(() {
          _digitalMarketingSearch = value;
        });
      },
      onFilterChanged: (value) {
        setState(() {
          _digitalMarketingFilter = value;
        });
      },
    );
  }

  // ============================================================
  // SOFTWARE DEVELOPMENT
  // ============================================================

  Widget _buildSoftwareDevelopmentSection() {
    return _buildSectionCard(
      section: AppConstants.softwareDevelopment,
      title: AppConstants.softwareDevelopment,
      description:
          'Web applications, mobile applications and other software assets.',
      icon: Icons.code_outlined,
      color: AppColors.softwareDevelopment,
      lightColor:
          AppColors.softwareDevelopmentLight,
      filters: const [
        'All',
        'Web Application',
        'Mobile Application',
        'Others',
      ],
      selectedFilter:
          _softwareDevelopmentFilter,
      search: _softwareDevelopmentSearch,
      onSearchChanged: (value) {
        setState(() {
          _softwareDevelopmentSearch = value;
        });
      },
      onFilterChanged: (value) {
        setState(() {
          _softwareDevelopmentFilter = value;
        });
      },
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _buildSectionCard({
    required String section,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required Color lightColor,
    required List<String> filters,
    required String selectedFilter,
    required String search,
    required ValueChanged<String> onSearchChanged,
    required ValueChanged<String> onFilterChanged,
  }) {
    final companies = _getCompanies(
      section: section,
      filter: selectedFilter,
      search: search,
    );

    final totalAssets =
        _getSectionAssets(section).length;

    // ============================================================
    // FIXED WHITE PANEL HEIGHT
    // ============================================================

    final width = MediaQuery.of(context).size.width;

    final bool isMobile = width < 800;

    final double sectionHeight =
        isMobile ? 620 : 650;

    return SizedBox(
      width: double.infinity,
      height: sectionHeight,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER - FIXED
              // ==================================================

              // ==================================================
              // HEADER
              //
              // Keep the section title/description on the left and
              // keep Create Company + asset count aligned at the
              // top-right when the user has can_create_company.
              // On smaller screens the actions move below the
              // description so they never collide or overflow.
              // ==================================================

              if (isMobile)
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: lightColor,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            size: 28,
                            color: color,
                          ),
                        ),

                        const SizedBox(width: 13),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: color,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                description,
                                maxLines: 3,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color:
                                      AppColors
                                          .textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [
                        if (_canCreateCompany)
                          OutlinedButton.icon(
                            onPressed: () {
                              _showCreateCompanyDialog(section);
                            },
                            icon: const Icon(
                              Icons.add,
                              size: 17,
                            ),
                            label: const Text(
                              'Create Company',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: color,
                              side: BorderSide(color: color),
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                            ),
                          ),

                        if (_canCreateCompany)
                          const SizedBox(width: 8),

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: lightColor,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$totalAssets Assets',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: lightColor,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: color,
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ==================================================
                    // RIGHT-SIDE ACTIONS
                    //
                    // Asset count stays at the top-right.
                    // Create Company is positioned below it, matching
                    // the requested design shown in the reference.
                    // ==================================================
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: lightColor,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$totalAssets Assets',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          if (_canCreateCompany)
                            OutlinedButton.icon(
                              onPressed: () {
                                _showCreateCompanyDialog(section);
                              },
                              icon: const Icon(
                                Icons.add,
                                size: 17,
                              ),
                              label: const Text(
                                'Create Company',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: color,
                                side: BorderSide(color: color),
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 18),

              // ==================================================
              // FILTERS - FIXED
              // ==================================================

              SingleChildScrollView(
                scrollDirection:
                    Axis.horizontal,
                child: Row(
                  children: filters.map(
                    (filter) {
                      final bool selected =
                          selectedFilter ==
                              filter;

                      return Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          right: 7,
                        ),
                        child: InkWell(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                          onTap: () {
                            onFilterChanged(
                              filter,
                            );
                          },
                          child: Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration:
                                BoxDecoration(
                              color: selected
                                  ? AppColors
                                      .primary
                                  : const Color(
                                      0xFFF5F7FB,
                                    ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                              border:
                                  Border.all(
                                color: selected
                                    ? AppColors
                                        .primary
                                    : AppColors
                                        .border,
                              ),
                            ),
                            child: Text(
                              _filterLabel(
                                filter,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight
                                        .w600,
                                color: selected
                                    ? Colors
                                        .white
                                    : AppColors
                                        .textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // SEARCH - FIXED
              // ==================================================

              TextField(
                onChanged:
                    onSearchChanged,
                controller:
                    TextEditingController(
                  text: search,
                )..selection =
                    TextSelection.collapsed(
                  offset: search.length,
                ),
                style:
                    const TextStyle(
                  fontSize: 13,
                ),
                decoration:
                    InputDecoration(
                  hintText:
                      'Search companies or assets...',
                  hintStyle:
                      const TextStyle(
                    fontSize: 13,
                    color:
                        AppColors
                            .textSecondary,
                  ),
                  prefixIcon:
                      const Icon(
                    Icons.search,
                    size: 20,
                  ),
                  filled: true,
                  fillColor:
                      const Color(
                    0xFFF8FAFD,
                  ),
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          AppColors.border,
                    ),
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    borderSide:
                        BorderSide(
                      color: color,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // COMPANY LIST - INTERNAL SCROLL
              // ==================================================

              Expanded(
                child: companies.isEmpty
                    ? Center(
                        child:
                            _buildEmptyCompanies(),
                      )
                    : ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                        child: Scrollbar(
                          controller: _companyScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          interactive: true,
                          child:
                              ListView.builder(
                            controller: _companyScrollController,
                            primary: false,
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets
                                    .only(
                              right: 8,
                              bottom: 8,
                            ),
                            itemCount:
                                companies.length,
                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              final company =
                                  companies[
                                      index];

                              return Padding(
                                padding:
                                    const EdgeInsets
                                        .only(
                                  bottom: 10,
                                ),
                                child:
                                    _buildCompanyCard(
                                  company:
                                      company,
                                  section:
                                      section,
                                  color:
                                      color,
                                ),
                              );
                            },
                          ),
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
  // COMPANY CARD
  // ============================================================

  Widget _buildCompanyCard({
    required CompanyModel company,
    required String section,
    required Color color,
  }) {
    final assets =
        _assets.where(
      (asset) =>
          asset.companyId ==
              company.id &&
          asset.section ==
              section,
    ).toList();

    return Material(
      color:
          const Color(0xFFFAFBFD),
      borderRadius:
          BorderRadius.circular(12),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: () {
          _openCompany(
            company,
            section,
          );
        },
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color:
                  AppColors.border,
            ),
          ),
          child: Row(
            children: [
              // ================================================
              // COMPANY INITIAL
              // ================================================

              _buildCompanyLogo(
                company: company,
                color: color,
              ),

              const SizedBox(
                width: 12,
              ),

              // ================================================
              // COMPANY DETAILS
              // ================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      company.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors
                                .textPrimary,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      '${assets.length} ${assets.length == 1 ? 'asset' : 'assets'}',
                      style:
                          const TextStyle(
                        fontSize: 13,
                        color:
                            AppColors
                                .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // ================================================
              // OPEN ARROW
              // ================================================

              Container(
                width: 36,
                height: 36,
                alignment:
                    Alignment.center,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                  border: Border.all(
                    color:
                        AppColors.border,
                  ),
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CREATE COMPANY
  // ============================================================

  Future<void> _showCreateCompanyDialog(
    String section,
  ) async {
    if (!_canCreateCompany) {
      return;
    }

    final controller = TextEditingController();

    String? selectedLogoName;
    Uint8List? selectedLogoBytes;
    bool companyCreated = false;

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
                  final file = selection != null && selection.files.isNotEmpty
                      ? selection.files.first
                      : null;
                  final bytes = file?.bytes;
                  if (file == null || bytes == null) {
                    return;
                  }

                  if (bytes.isEmpty) {
                    if (!dialogContext.mounted) return;

                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to read the selected image.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (bytes.length > 5 * 1024 * 1024) {
                    if (!dialogContext.mounted) return;

                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Company logo must be 5 MB or smaller.',
                        ),
                      ),
                    );
                    return;
                  }

                  setDialogState(() {
                    selectedLogoName = file.name;
                    selectedLogoBytes = bytes;
                  });
                } catch (error) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Unable to select logo: '
                        '${error.toString().replaceFirst('Exception: ', '')}',
                      ),
                    ),
                  );
                }
              }

              Future<void> saveCompany() async {
                final name = controller.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
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
                    logoFileName: selectedLogoName,
                    logoBytes: selectedLogoBytes,
                  );

                  companyCreated = true;

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop();
                } catch (error) {
                  if (!dialogContext.mounted) return;

                  setDialogState(() {
                    isCreating = false;
                  });

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to create company: '
                        '${error.toString().replaceFirst('Exception: ', '')}',
                      ),
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
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create a company under $section.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
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
                            fontSize: 14,
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
                              clipBehavior:
                                  Clip.antiAlias,
                              child: selectedLogoBytes != null
                                  ? Image.memory(
                                      selectedLogoBytes!,
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
                                      selectedLogoBytes != null
                                          ? 'Change Logo'
                                          : 'Upload Logo',
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    selectedLogoName ??
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
                        : () =>
                            Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        isCreating ? null : saveCompany,
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

      if (!companyCreated || !mounted) {
        return;
      }

      await _loadData();

      if (!mounted) {
        return;
      }

      // Reloading here keeps the new company immediately visible.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Company created successfully.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // OPEN COMPANY
  // ============================================================

  void _openCompany(
    CompanyModel company,
    String section,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return CompanyAssetsPage(
            company: company,
            section: section,
          );
        },
      ),
    );
  }

  // ============================================================
  // GET COMPANIES
  // ============================================================

  List<CompanyModel> _getCompanies({
    required String section,
    required String filter,
    required String search,
  }) {
    final query = search.trim().toLowerCase();

    final matchingCompanies = <CompanyModel>[];

    for (final company in _companies) {
      if (company.section != section) {
        continue;
      }

      final companyAssets = _assets.where(
        (asset) {
          return asset.companyId == company.id &&
              asset.section == section;
        },
      ).toList();

      if (filter != 'All') {
        final hasMatchingType = companyAssets.any(
          (asset) => asset.type == filter,
        );

        if (!hasMatchingType) {
          continue;
        }
      }

      if (query.isNotEmpty) {
        final companyMatches =
            company.name.toLowerCase().contains(query);

        final assetMatches = companyAssets.any(
          (asset) {
            return asset.name
                    .toLowerCase()
                    .contains(query) ||
                asset.type
                    .toLowerCase()
                    .contains(query);
          },
        );

        if (!companyMatches && !assetMatches) {
          continue;
        }
      }

      matchingCompanies.add(company);
    }

    matchingCompanies.sort(
      (a, b) {
        return a.name
            .toLowerCase()
            .compareTo(
              b.name.toLowerCase(),
            );
      },
    );

    return matchingCompanies;
  }

  // ============================================================
  // GET SECTION ASSETS
  // ============================================================

  List<AssetModel> _getSectionAssets(
    String section,
  ) {
    return _assets
        .where(
          (asset) =>
              asset.section == section,
        )
        .toList();
  }

  // ============================================================
  // COMPANY LOGO
  // ============================================================

  Widget _buildCompanyLogo({
    required CompanyModel company,
    required Color color,
  }) {
    final logoUrl = company.logoUrl?.trim();

    if (logoUrl == null || logoUrl.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          _companyInitials(company.name),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    final parsed = Uri.tryParse(logoUrl);

    final imageUrl =
        parsed != null && parsed.hasScheme
            ? logoUrl
            : '${ApiService.baseUrl.replaceFirst('/api', '')}${
                logoUrl.startsWith('/') ? logoUrl : '/$logoUrl'
              }';

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            alignment: Alignment.center,
            color: color,
            child: Text(
              _companyInitials(company.name),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // COMPANY INITIALS
  // ============================================================

  String _companyInitials(
    String name,
  ) {
    final trimmed =
        name.trim();

    if (trimmed.isEmpty) {
      return 'CO';
    }

    final words =
        trimmed.split(
      RegExp(r'\s+'),
    );

    if (words.length >= 2) {
      return (
        '${words[0][0]}${words[1][0]}'
      ).toUpperCase();
    }

    if (trimmed.length >= 2) {
      return trimmed
          .substring(0, 2)
          .toUpperCase();
    }

    return trimmed[0]
        .toUpperCase();
  }

  // ============================================================
  // FILTER LABEL
  // ============================================================

  String _filterLabel(
    String filter,
  ) {
    switch (filter) {
      case 'Poster':
        return 'Posters';

      case 'Reel / Video':
        return 'Reels / Videos';

      case 'Document':
        return 'Documents';

      case 'Website Link':
        return 'Website Links';

      case 'Web Application':
        return 'Web Applications';

      case 'Mobile Application':
        return 'Mobile Applications';

      default:
        return filter;
    }
  }

  // ============================================================
  // EMPTY COMPANY STATE
  // ============================================================

  Widget _buildEmptyCompanies() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 30,
        horizontal: 15,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF8FAFD),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: const Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons.business_outlined,
            size: 38,
            color:
                AppColors
                    .textSecondary,
          ),

          SizedBox(height: 10),

          Text(
            'No companies found',
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors
                      .textPrimary,
            ),
          ),

          SizedBox(height: 4),

          Text(
            'Try changing the search or filter.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:
                  AppColors
                      .textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
