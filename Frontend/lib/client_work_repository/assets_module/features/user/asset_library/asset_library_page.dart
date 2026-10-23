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
  final void Function(CompanyModel company, String section)? onOpenCompany;

  const UserAssetLibraryPage({super.key, this.onOpenCompany});

  @override
  State<UserAssetLibraryPage> createState() => _UserAssetLibraryPageState();
}

class _UserAssetLibraryPageState extends State<UserAssetLibraryPage> {
  // ── Search + filter (unified) ──────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _filter = 'All';

  // Unified filter chips → asset types they match.
  static const _filterChips = [
    'All',
    'Posters',
    'Videos',
    'Documents',
    'Links',
    'Applications',
  ];

  List<String> _typesForFilter(String chip) {
    switch (chip) {
      case 'Posters':
        return const [AppConstants.poster];
      case 'Videos':
        return const [AppConstants.reelVideo];
      case 'Documents':
        return const [AppConstants.document];
      case 'Links':
        return const [AppConstants.websiteLink];
      case 'Applications':
        return const [
          AppConstants.webApplication,
          AppConstants.mobileApplication,
        ];
      default:
        return const [];
    }
  }

  // ── API data ───────────────────────────────────────────────
  List<CompanyModel> _companies = [];
  List<AssetModel> _assets = [];

  bool _isLoading = true;
  String? _loadError;

  bool _canDownload = false;
  bool _canCreateCompany = false;

  // ── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    try {
      final permissions = await ApiService.getMyPermissions();
      if (!mounted) return;
      bool toBool(dynamic v) => v == true || v == 1;
      setState(() {
        _canDownload = toBool(permissions['can_download']);
        _canCreateCompany = toBool(permissions['can_create_company']);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canDownload = false;
        _canCreateCompany = false;
      });
    }
  }

  // ============================================================
  // LOAD DATA FROM BACKEND / MYSQL  (unchanged logic)
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
            DateTime.tryParse(data['created_at']?.toString() ?? '') ?? now;
        final updatedAt =
            DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
            createdAt;

        final rawSections = data['sections'];
        final sections = <String>[];
        if (rawSections is List) {
          for (final value in rawSections) {
            final section = value?.toString().trim() ?? '';
            if (section.isNotEmpty && !sections.contains(section)) {
              sections.add(section);
            }
          }
        }

        final singleSection = data['section']?.toString().trim();
        if (sections.isEmpty &&
            singleSection != null &&
            singleSection.isNotEmpty) {
          sections.add(singleSection);
        }

        if (sections.isEmpty) continue;

        final validSections = sections
            .where(
              (s) =>
                  s == AppConstants.digitalMarketing ||
                  s == AppConstants.softwareDevelopment,
            )
            .toList();

        for (final section in validSections) {
          loadedCompanies.add(
            CompanyModel(
              id: id,
              name: name,
              createdAt: createdAt,
              updatedAt: updatedAt,
              section: section,
              logoUrl: logoUrl,
              allSections: validSections,
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

        final companyId = data['company_id']?.toString() ?? '';
        final companyName = data['company_name']?.toString() ?? '';
        final section = data['section']?.toString() ?? '';
        final type = data['type']?.toString() ?? '';
        final name = data['name']?.toString() ?? '';

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
            description: data['description']?.toString(),
            filePath: data['file_url']?.toString(),
            fileName: data['file_name']?.toString(),
            mimeType: data['mime_type']?.toString(),
            fileSize: data['file_size'] is num
                ? (data['file_size'] as num).toInt()
                : null,
            createdByEmployeeId: data['created_by_employee_id']?.toString(),
            createdAt:
                DateTime.tryParse(data['created_at']?.toString() ?? '') ?? now,
            updatedAt:
                DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? now,
          ),
        );
      }

      // Older records can have assets before a matching company_sections row
      // was created.  Do not hide those live assets from employees: derive the
      // section from the authoritative asset record as a safe fallback.
      for (final asset in loadedAssets) {
        final alreadyListed = loadedCompanies.any(
          (company) =>
              company.id == asset.companyId && company.section == asset.section,
        );
        if (alreadyListed) continue;

        CompanyModel? source;
        for (final company in loadedCompanies) {
          if (company.id == asset.companyId) {
            source = company;
            break;
          }
        }
        final allSections = <String>{
          ...?source?.allSections,
          asset.section,
        }.toList();

        loadedCompanies.add(
          CompanyModel(
            id: asset.companyId,
            name: source?.name.isNotEmpty == true
                ? source!.name
                : (asset.companyName.isNotEmpty
                      ? asset.companyName
                      : 'Company'),
            createdAt: source?.createdAt ?? asset.createdAt,
            updatedAt: source?.updatedAt ?? asset.updatedAt,
            section: asset.section,
            logoUrl: source?.logoUrl,
            allSections: allSections,
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
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // UNIQUE COMPANIES (dedup by id) + aggregation
  // ============================================================

  List<CompanyModel> get _uniqueCompanies {
    final seen = <String>{};
    final result = <CompanyModel>[];
    for (final c in _companies) {
      if (seen.add(c.id)) result.add(c);
    }
    return result;
  }

  List<AssetModel> _assetsOf(String companyId) =>
      _assets.where((a) => a.companyId == companyId).toList();

  DateTime _lastUpdated(CompanyModel company) {
    var latest = company.updatedAt;
    for (final a in _assetsOf(company.id)) {
      if (a.updatedAt.isAfter(latest)) latest = a.updatedAt;
    }
    return latest;
  }

  List<CompanyModel> get _visibleCompanies {
    final query = _search.trim().toLowerCase();
    final types = _typesForFilter(_filter);

    final list = _uniqueCompanies.where((company) {
      final companyAssets = _assetsOf(company.id);

      if (types.isNotEmpty) {
        final hasType = companyAssets.any((a) => types.contains(a.type));
        if (!hasType) return false;
      }

      if (query.isNotEmpty) {
        final nameMatch = company.name.toLowerCase().contains(query);
        final assetMatch = companyAssets.any(
          (a) =>
              a.name.toLowerCase().contains(query) ||
              a.type.toLowerCase().contains(query),
        );
        if (!nameMatch && !assetMatch) return false;
      }

      return true;
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_loadError != null) {
      return _buildErrorState();
    }

    return Container(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isMobile = w < 640;
          final pad = isMobile ? 16.0 : 32.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, isMobile ? 20 : 28, pad, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 22),
                _buildSearchBar(),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 22),
                _buildCompanyGrid(w),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset Library',
          style: TextStyle(
            fontSize: isMobile ? 26 : 34,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Find approved company assets and downloads',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    );

    if (!_canCreateCompany) return title;

    final createButton = _buildCreateCompanyButton();
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: createButton),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        createButton,
      ],
    );
  }

  Widget _buildCreateCompanyButton() {
    return PopupMenuButton<String>(
      tooltip: 'Create Company',
      onSelected: _showCreateCompanyDialog,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AppConstants.digitalMarketing,
          child: Text('In Digital Marketing'),
        ),
        PopupMenuItem(
          value: AppConstants.softwareDevelopment,
          child: Text('In Software Development'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Create Company',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search assets or companies',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips ────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterChips.map((chip) {
          final selected = _filter == chip;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _filter = chip),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Company grid ────────────────────────────────────────────
  Widget _buildCompanyGrid(double _) {
    final companies = _visibleCompanies;
    if (companies.isEmpty) return _buildEmptyCompanies();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1040
            ? 3
            : width >= 680
            ? 2
            : 1;
        const gap = 20.0;
        final cardWidth = (width - (cols - 1) * gap) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: companies.map((company) {
            return SizedBox(
              width: cols == 1 ? double.infinity : cardWidth,
              child: _buildCompanyCard(company),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCompanyCard(CompanyModel company) {
    final count = _assetsOf(company.id).length;
    final updated = _lastUpdated(company);
    final section = company.allSections.isNotEmpty
        ? company.allSections.first
        : (company.section ?? AppConstants.digitalMarketing);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openCompany(company, section),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCompanyLogo(company: company),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                company.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$count ${count == 1 ? 'asset' : 'assets'}  ·  Updated ${_formatDate(updated)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _accessBadge(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              // Open assets footer
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Open assets',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accessBadge() {
    final enabled = _canDownload;
    final bg = enabled ? const Color(0xFFE7F8EF) : const Color(0xFFF1F5F9);
    final fg = enabled ? const Color(0xFF15803D) : AppColors.textSecondary;
    final icon = enabled ? Icons.check_circle : Icons.visibility_outlined;
    final label = enabled ? 'Download access enabled' : 'View only access';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CREATE COMPANY  (unchanged logic)
  // ============================================================

  Future<void> _showCreateCompanyDialog(String section) async {
    if (!_canCreateCompany) return;

    final controller = TextEditingController();
    String? selectedLogoName;
    Uint8List? selectedLogoBytes;
    bool companyCreated = false;
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
                  final file = selection != null && selection.files.isNotEmpty
                      ? selection.files.first
                      : null;
                  final bytes = file?.bytes;
                  if (file == null || bytes == null) return;

                  if (bytes.isEmpty) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to read the selected image.'),
                      ),
                    );
                    return;
                  }

                  if (bytes.length > 5 * 1024 * 1024) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Company logo must be 5 MB or smaller.'),
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
                    logoFileName: selectedLogoName,
                    logoBytes: selectedLogoBytes,
                  );
                  companyCreated = true;
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() => isCreating = false);
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
                title: Text(
                  'Create Company · $section',
                  style: const TextStyle(
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
                              child: selectedLogoBytes != null
                                  ? Image.memory(
                                      selectedLogoBytes!,
                                      fit: BoxFit.cover,
                                    )
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
                    onPressed: isCreating ? null : saveCompany,
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

      if (!companyCreated || !mounted) return;

      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company created successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // ── Open company (unchanged) ────────────────────────────────
  void _openCompany(CompanyModel company, String section) {
    if (widget.onOpenCompany != null) {
      widget.onOpenCompany!(company, section);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyAssetsPage(company: company, section: section),
      ),
    );
  }

  // ── Company logo (unchanged) ────────────────────────────────
  Widget _buildCompanyLogo({required CompanyModel company}) {
    final logoUrl = company.logoUrl?.trim();

    if (logoUrl == null || logoUrl.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _companyInitials(company.name),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    final parsed = Uri.tryParse(logoUrl);
    final imageUrl = parsed != null && parsed.hasScheme
        ? logoUrl
        : '${ApiService.baseUrl.replaceFirst('/client-repository', '').replaceFirst('/api', '')}${logoUrl.startsWith('/') ? logoUrl : '/$logoUrl'}';

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            alignment: Alignment.center,
            color: AppColors.primary,
            child: Text(
              _companyInitials(company.name),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
    );
  }

  String _companyInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'CO';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return ('${words[0][0]}${words[1][0]}').toUpperCase();
    }
    if (trimmed.length >= 2) return trimmed.substring(0, 2).toUpperCase();
    return trimmed[0].toUpperCase();
  }

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ── Empty + error states ────────────────────────────────────
  Widget _buildEmptyCompanies() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.business_outlined,
            size: 44,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'No companies found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try changing the search or filter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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
}


