import 'package:godigital_portal/web_stub.dart'
    if (dart.library.html) 'dart:html'
    as html;
import 'package:godigital_portal/ui_web_stub.dart'
    if (dart.library.html) 'dart:ui_web'
    as ui;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../models/asset_model.dart';
import '../../../models/company_model.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs/add_asset_dialog.dart';
import '../../../services/download_helper.dart';

class CompanyAssetsPage extends StatefulWidget {
  final CompanyModel company;
  final String section;
  final VoidCallback? onBack;

  const CompanyAssetsPage({
    super.key,
    required this.company,
    required this.section,
    this.onBack,
  });

  @override
  State<CompanyAssetsPage> createState() => _CompanyAssetsPageState();
}

class _CompanyAssetsPageState extends State<CompanyAssetsPage> {
  String _search = '';
  String _filter = 'All';

  bool _isLoading = true;
  String? _errorMessage;

  List<AssetModel> _allAssets = [];

  bool _isAddingAsset = false;

  bool _canViewAsset = false;
  bool _canDownloadAsset = false;
  bool _canCreateAsset = false;
  bool _canEditAsset = false;
  bool _canDeleteAsset = false;

  // Company-level permissions.
  bool _canEditCompany = false;
  bool _canDeleteCompany = false;

  // When set, the inline Asset Preview is shown (keeps the shared navbar).
  AssetModel? _previewAsset;

  late String _companyName;

  // All asset types are shown for a company, regardless of section,
  // so one company view lists every approved asset it owns.
  List<String> get _filters => const [
    'All',
    AppConstants.poster,
    AppConstants.reelVideo,
    AppConstants.document,
    AppConstants.websiteLink,
    AppConstants.webApplication,
    AppConstants.mobileApplication,
    AppConstants.others,
  ];

  // Every asset that belongs to this company (any section).
  List<AssetModel> get _companyAllAssets =>
      _allAssets.where((a) => a.companyId == widget.company.id).toList();

  int _countForType(String type) {
    if (type == 'All') return _companyAllAssets.length;
    return _companyAllAssets.where((a) => a.type == type).length;
  }

  @override
  void initState() {
    super.initState();

    _companyName = widget.company.name;

    _loadPermissions();
    _loadAssets();
  }

  // ============================================================
  // LOAD CURRENT USER PERMISSIONS
  // ============================================================

  Future<void> _loadPermissions() async {
    try {
      final permissions = await ApiService.getMyPermissions();

      if (!mounted) {
        return;
      }

      setState(() {
        _canViewAsset = _permissionEnabled(permissions['can_view']);
        _canDownloadAsset = _permissionEnabled(permissions['can_download']);
        _canCreateAsset = _permissionEnabled(permissions['can_create']);
        _canEditAsset = _permissionEnabled(permissions['can_edit']);
        _canDeleteAsset = _permissionEnabled(permissions['can_delete']);

        // The same Edit/Delete permissions also control
        // company-level Edit/Delete actions on this screen.
        _canEditCompany = _permissionEnabled(permissions['can_edit']);
        _canDeleteCompany = _permissionEnabled(permissions['can_delete']);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _canViewAsset = false;
        _canDownloadAsset = false;
        _canCreateAsset = false;
        _canEditAsset = false;
        _canDeleteAsset = false;
        _canEditCompany = false;
        _canDeleteCompany = false;
      });
    }
  }

  bool _permissionEnabled(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value == 1;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }

    return false;
  }

  // ============================================================
  // LOAD ASSETS FROM API
  // ============================================================

  Future<void> _loadAssets() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await ApiService.getAssets();

      final assets = <AssetModel>[];

      for (final item in response) {
        if (item is! Map) {
          continue;
        }

        final data = Map<String, dynamic>.from(item);

        try {
          final asset = _assetFromJson(data);

          assets.add(asset);
        } catch (_) {
          // Ignore malformed asset records.
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _allAssets = assets;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  // ============================================================
  // EDIT COMPANY
  //
  // User can edit the company when can_edit is granted.
  // Admin is also supported because /api/permissions/me returns
  // all permissions as true for Admin.
  // ============================================================

  Future<void> _editCompany() async {
    if (!_canEditCompany) {
      _showMessage('You do not have permission to edit this company.');
      return;
    }

    final controller = TextEditingController(text: _companyName);

    final selectedSections = <String>{
      ...widget.company.allSections.isNotEmpty
          ? widget.company.allSections
          : (widget.company.section != null ? [widget.company.section!] : []),
    };

    String? pickedLogoFileName;
    Uint8List? pickedLogoBytes;

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text(
                  'Edit Company',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo picker
                        const Text(
                          'Company Logo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final input = html.FileUploadInputElement()
                              ..accept = 'image/*';
                            input.click();
                            await input.onChange.first;
                            final file = input.files?.first;
                            if (file != null) {
                              final reader = html.FileReader();
                              reader.readAsArrayBuffer(file);
                              await reader.onLoad.first;
                              final bytes = Uint8List.fromList(
                                (reader.result as List<dynamic>).cast<int>(),
                              );
                              setDialogState(() {
                                pickedLogoFileName = file.name;
                                pickedLogoBytes = bytes;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F9FD),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                // Preview
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: pickedLogoBytes != null
                                      ? Image.memory(
                                          pickedLogoBytes!,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        )
                                      : (widget.company.logoUrl != null &&
                                                widget
                                                    .company
                                                    .logoUrl!
                                                    .isNotEmpty
                                            ? Image.network(
                                                '${ApiService.baseUrl.replaceFirst('/client-repository', '').replaceFirst('/api', '')}${widget.company.logoUrl!.startsWith('/') ? widget.company.logoUrl! : '/${widget.company.logoUrl!}'}',
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    _logoPlaceholder(),
                                              )
                                            : _logoPlaceholder()),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pickedLogoFileName ?? 'Change Logo',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        pickedLogoFileName != null
                                            ? 'New logo selected'
                                            : 'Tap to upload a new logo',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.upload_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          autofocus: false,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            hintText: 'Enter company name',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              Navigator.of(dialogContext).pop({
                                'name': value.trim(),
                                'sections': selectedSections.toList(),
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a company name.'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(dialogContext).pop({
                        'name': value,
                        'sections': selectedSections.toList(),
                      });
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      final newName = result?['name'] as String?;
      final newSections = result?['sections'] as List<String>?;

      if (newName == null || newName.trim().isEmpty || !mounted) {
        return;
      }

      await ApiService.updateCompany(
        companyId: widget.company.id,
        name: newName.trim(),
        sections: newSections,
        logoFileName: pickedLogoFileName,
        logoBytes: pickedLogoBytes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _companyName = newName.trim();
      });

      _showMessage('Company updated successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to update company: $error');
    } finally {
      controller.dispose();
    }
  }

  // ============================================================
  // DELETE COMPANY
  //
  // User can delete the company when can_delete is granted.
  // The backend performs the final authorization check.
  // ============================================================

  Future<void> _deleteCompany() async {
    if (!_canDeleteCompany) {
      _showMessage('You do not have permission to delete this company.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Entire Company',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Are you sure you want to delete '
            '"$_companyName"?\n\n'
            'This will permanently delete the entire company '
            'and all of its assets. This action cannot be undone.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ApiService.deleteCompany(widget.company.id);

      if (!mounted) {
        return;
      }

      _showMessage('Company deleted successfully.');

      // Tell the previous Asset Library page that the company
      // was deleted so it can refresh its company list.
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to delete company: $error');
    }
  }

  // ============================================================
  // ADD ASSET
  // ============================================================

  Future<void> _addAsset() async {
    if (!_canCreateAsset) {
      _showMessage('You do not have permission to add assets.');
      return;
    }

    if (_isAddingAsset) {
      return;
    }

    setState(() {
      _isAddingAsset = true;
    });

    try {
      final asset = await showAddAssetDialog(
        context,
        companies: [widget.company],
        initialSection: widget.section,
      );

      if (asset == null) {
        return;
      }

      await _loadAssets();

      if (!mounted) {
        return;
      }

      _showMessage('"${asset.name}" added successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to add asset: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isAddingAsset = false;
        });
      }
    }
  }

  // ============================================================
  // CONVERT API JSON TO ASSET MODEL
  // ============================================================

  AssetModel _assetFromJson(Map<String, dynamic> data) {
    final createdAt = _parseDate(data['created_at'] ?? data['createdAt']);

    final updatedAt = _parseDate(
      data['updated_at'] ??
          data['updatedAt'] ??
          data['created_at'] ??
          data['createdAt'],
    );

    return AssetModel(
      id: _stringValue(data['id']),
      companyId: _stringValue(data['company_id'] ?? data['companyId']),
      companyName: _stringValue(data['company_name'] ?? data['companyName']),
      section: _stringValue(data['section']),
      type: _stringValue(data['type']),
      name: _stringValue(data['name']),
      link: _nullableString(data['link']),
      username: _nullableString(data['username']),
      password: _nullableString(data['password']),
      description: _nullableString(data['description']),
      filePath: _nullableString(
        data['file_url'] ?? data['file_path'] ?? data['filePath'],
      ),
      fileName: _nullableString(data['file_name'] ?? data['fileName']),
      mimeType: _nullableString(data['mime_type'] ?? data['mimeType']),
      fileSize: data['file_size'] is num
          ? (data['file_size'] as num).toInt()
          : null,
      createdByEmployeeId: _nullableString(
        data['created_by_employee_id'] ?? data['createdByEmployeeId'],
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    if (result.isEmpty || result.toLowerCase() == 'null') {
      return null;
    }

    return result;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value;
    }

    final parsed = DateTime.tryParse(value.toString());

    return parsed ?? DateTime.now();
  }

  // ============================================================
  // FILTER COMPANY ASSETS
  // ============================================================

  List<AssetModel> get _companyAssets {
    final query = _search.trim().toLowerCase();

    return _allAssets.where((asset) {
      // Company filter.
      if (asset.companyId != widget.company.id) {
        return false;
      }

      // Type filter.
      if (_filter != 'All' && asset.type != _filter) {
        return false;
      }

      // Search filter.
      if (query.isNotEmpty) {
        final matchesName = asset.name.toLowerCase().contains(query);

        final matchesType = asset.type.toLowerCase().contains(query);

        final matchesCompany = asset.companyName.toLowerCase().contains(query);

        if (!matchesName && !matchesType && !matchesCompany) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final mobile = width < 760;

    if (_previewAsset != null) {
      return AssetPreviewPage(
        asset: _previewAsset!,
        onBack: () => setState(() => _previewAsset = null),
      );
    }

    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: _buildBody(mobile),
    );
  }

  Widget _buildBody(bool mobile) {
    if (_isLoading) {
      return const PremiumBackground(
        child: PremiumLoading(label: 'Loading assets...'),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final assets = _companyAssets;

    return PremiumPage(
      builder: (context, bp) => [
        _buildBreadcrumb(),
        const SizedBox(height: 10),
        Reveal(child: _buildCompanyHeader(bp.mobile)),
        SizedBox(height: bp.gap),
        Reveal(
          delay: const Duration(milliseconds: 160),
          child: PremiumPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearch(),
                      const SizedBox(height: 10),
                      _buildFilters(),
                    ],
                  ),
                ),
                const Divider(height: 1, color: PremiumColors.line),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: KeyedSubtree(
                    key: ValueKey('$_filter|$_search|${assets.length}'),
                    child: assets.isEmpty
                        ? _buildEmptyState()
                        : LayoutBuilder(
                            builder: (context, box) => box.maxWidth < 720
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        for (final asset in assets)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: _buildAssetCard(asset, true),
                                          ),
                                      ],
                                    ),
                                  )
                                : _buildAssetsTable(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BREADCRUMB
  // ============================================================

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildBreadcrumb() {
    return Row(
      children: [
        PremiumIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back to Asset Library',
          onPressed: _goBack,
        ),
        const SizedBox(width: 6),
        HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder: (context, hovered) => GestureDetector(
            onTap: _goBack,
            child: Text(
              'Asset Library',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hovered ? PremiumColors.blue : PremiumColors.muted,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: PremiumColors.faint,
          ),
        ),
        Flexible(
          child: Text(
            _companyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PremiumColors.blue,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ASSETS TABLE (desktop) - fixed height, pinned header
  // ============================================================

  static const _actionsWidth = 210.0;

  Widget _buildAssetsTable() {
    final assets = _companyAssets;
    const p = EdgeInsets.symmetric(horizontal: 12);
    Widget head(int flex, String label) => Expanded(
      flex: flex,
      child: Padding(
        padding: p,
        child: Text(label.toUpperCase(), style: PremiumColors.tableHeaderStyle),
      ),
    );
    return PremiumTable(
      minWidth: 820,
      header: PremiumTableHeader(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            head(30, 'Asset'),
            head(14, 'Type'),
            head(28, 'Description'),
            head(14, 'Updated'),
            const SizedBox(
              width: _actionsWidth,
              child: Padding(
                padding: p,
                child: Text(
                  'ACTIONS',
                  textAlign: TextAlign.right,
                  style: PremiumColors.tableHeaderStyle,
                ),
              ),
            ),
          ],
        ),
      ),
      itemCount: assets.length,
      itemBuilder: (context, i) => _buildTableRow(assets[i]),
      footer: PremiumTableFooter(
        child: Text(
          'Showing ${assets.length} of ${_companyAllAssets.length} assets',
        ),
      ),
    );
  }

  Widget _buildTableRow(AssetModel asset) {
    const p = EdgeInsets.symmetric(horizontal: 12);
    return PremiumTableRow(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Asset (icon + name + filename)
          Expanded(
            flex: 30,
            child: Padding(
              padding: p,
              child: Row(
                children: [
                  _buildAssetIcon(asset),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PremiumColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          asset.fileName ?? asset.link ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: PremiumColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Type chip
          Expanded(
            flex: 14,
            child: Padding(padding: p, child: _buildTypeChip(asset.type)),
          ),
          // Description
          Expanded(
            flex: 28,
            child: Padding(
              padding: p,
              child: Text(
                asset.description?.trim().isNotEmpty == true
                    ? asset.description!.trim()
                    : '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: PremiumColors.muted,
                ),
              ),
            ),
          ),
          // Updated
          Expanded(
            flex: 14,
            child: Padding(
              padding: p,
              child: Text(
                _formatDate(asset.updatedAt),
                style: const TextStyle(fontSize: 13, color: PremiumColors.body),
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: _actionsWidth,
            child: Padding(
              padding: p,
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildActions(asset),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PremiumBadge(
        label: _shortTypeLabel(type),
        icon: _getAssetIcon(type),
        accent: _typeAccent(type),
        maxWidth: 150,
      ),
    );
  }

  PremiumAccent _typeAccent(String type) {
    switch (type) {
      case AppConstants.poster:
        return PremiumAccent.blue;
      case AppConstants.reelVideo:
        return PremiumAccent.violet;
      case AppConstants.document:
        return PremiumAccent.amber;
      case AppConstants.websiteLink:
        return PremiumAccent.cyan;
      case AppConstants.webApplication:
        return PremiumAccent.green;
      case AppConstants.mobileApplication:
        return PremiumAccent.violet;
      default:
        return PremiumAccent.slate;
    }
  }

  String _shortTypeLabel(String type) {
    switch (type) {
      case AppConstants.poster:
        return 'Poster';
      case AppConstants.reelVideo:
        return 'Video';
      case AppConstants.document:
        return 'Document';
      case AppConstants.websiteLink:
        return 'Website Link';
      case AppConstants.webApplication:
        return 'Web App';
      case AppConstants.mobileApplication:
        return 'Mobile App';
      default:
        return type;
    }
  }

  // ============================================================
  // COMPANY HEADER
  // ============================================================

  Widget _buildCompanyHeader(bool mobile) {
    final companyName = _companyName.trim();
    final firstLetter = companyName.isNotEmpty
        ? companyName.substring(0, 1).toUpperCase()
        : 'C';

    final count = _companyAllAssets.length;
    var updated = widget.company.updatedAt;
    for (final a in _companyAllAssets) {
      if (a.updatedAt.isAfter(updated)) updated = a.updatedAt;
    }

    final sections = widget.company.allSections.isNotEmpty
        ? widget.company.allSections.join(' · ')
        : widget.section;

    return PremiumHero(
      compact: mobile,
      leading: _buildCompanyLogo(mobile, firstLetter),
      eyebrow: sections,
      eyebrowIcon: widget.section == AppConstants.softwareDevelopment
          ? Icons.code_rounded
          : Icons.campaign_rounded,
      title: companyName,
      subtitle:
          '$count ${count == 1 ? 'asset' : 'assets'}  ·  Last updated ${_formatDate(updated)}',
      actions: _buildPermissionActions(mobile),
    );
  }

  // Permission-based company actions, shown on the header banner.
  List<Widget> _buildPermissionActions(bool mobile) {
    final list = <Widget>[];

    if (_canEditCompany) {
      list.add(
        PremiumButton(
          label: 'Edit company',
          icon: Icons.edit_outlined,
          iconLeading: true,
          small: mobile,
          variant: PremiumButtonVariant.glass,
          onPressed: _editCompany,
        ),
      );
    }
    if (_canDeleteCompany) {
      list.add(
        PremiumButton(
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          iconLeading: true,
          small: mobile,
          variant: PremiumButtonVariant.glass,
          onPressed: _deleteCompany,
        ),
      );
    }
    if (_canCreateAsset) {
      list.add(
        PremiumButton(
          label: _isAddingAsset ? 'Adding...' : 'Add asset',
          icon: Icons.add_rounded,
          iconLeading: true,
          small: mobile,
          loading: _isAddingAsset,
          variant: PremiumButtonVariant.light,
          onPressed: _isAddingAsset ? null : _addAsset,
        ),
      );
    }
    return list;
  }

  Widget _buildCompanyLogo(bool mobile, String firstLetter) {
    final size = mobile ? 46.0 : 52.0;
    final initials = Container(
      alignment: Alignment.center,
      color: const Color(0x26FFFFFF),
      child: Text(
        firstLetter,
        style: TextStyle(
          fontSize: mobile ? 20 : 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
    Widget frame(Widget child) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66FFFFFF), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    final logoUrl = widget.company.logoUrl?.trim();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final parsed = Uri.tryParse(logoUrl);
      final imageUrl = parsed != null && parsed.hasScheme
          ? logoUrl
          : '${ApiService.baseUrl.replaceFirst('/client-repository', '').replaceFirst('/api', '')}${logoUrl.startsWith('/') ? logoUrl : '/$logoUrl'}';
      return frame(
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              ColoredBox(color: PremiumColors.blue, child: initials),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66FFFFFF), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: initials,
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearch() {
    return PremiumSearchField(
      controller: _searchController,
      hint: 'Search assets...',
      onChanged: (value) {
        setState(() {
          _search = value;
        });
      },
      onClear: () => setState(() => _search = ''),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PremiumFilterChip(
                label: '${_filterLabel(filter)} (${_countForType(filter)})',
                selected: _filter == filter,
                onTap: () => setState(() => _filter = filter),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ASSET CARD (mobile)
  // ============================================================

  Widget _buildAssetCard(AssetModel asset, bool mobile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PremiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAssetIcon(asset),
              const SizedBox(width: 12),
              Expanded(child: _buildAssetInformation(asset)),
            ],
          ),
          if (_hasLink(asset)) ...[
            const SizedBox(height: 10),
            _buildLinkPreview(asset),
          ],
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: _buildActions(asset)),
        ],
      ),
    );
  }

  Widget _buildAssetIcon(AssetModel asset) {
    return PremiumIconTile(
      icon: _getAssetIcon(asset.type),
      accent: _typeAccent(asset.type),
      size: 38,
    );
  }

  Widget _buildAssetInformation(AssetModel asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          asset.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: PremiumColors.ink,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PremiumBadge(
              label: _shortTypeLabel(asset.type),
              icon: _getAssetIcon(asset.type),
              accent: _typeAccent(asset.type),
              maxWidth: 150,
            ),
            Text(
              _formatDate(asset.updatedAt),
              style: const TextStyle(fontSize: 12, color: PremiumColors.muted),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // LINK PREVIEW
  // ============================================================

  Widget _buildLinkPreview(AssetModel asset) {
    final link = asset.link?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PremiumColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PremiumColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, size: 16, color: PremiumColors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: PremiumColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Widget _buildActions(AssetModel asset) {
    final isLink = _hasLink(asset);
    // An uploaded file can be downloaded even when the asset also has a link.
    final hasFile = asset.filePath?.trim().isNotEmpty ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canViewAsset)
          PremiumIconButton(
            icon: Icons.visibility_outlined,
            tooltip: 'View',
            onPressed: () => _viewAsset(asset),
          ),
        if (_canDownloadAsset && (hasFile || !isLink))
          PremiumIconButton(
            icon: Icons.download_outlined,
            tooltip: 'Download',
            onPressed: () => _downloadAsset(asset),
          ),
        if (isLink)
          PremiumIconButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open link',
            accent: PremiumAccent.cyan,
            onPressed: () => _openLink(asset.link!.trim()),
          ),
        if (_canEditAsset)
          PremiumIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit Asset',
            onPressed: () => _editAsset(asset),
          ),
        if (_canDeleteAsset)
          PremiumIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete Asset',
            accent: PremiumAccent.rose,
            onPressed: () => _deleteAsset(asset),
          ),
      ],
    );
  }

  // ============================================================
  // EDIT ASSET
  // ============================================================

  Future<void> _editAsset(AssetModel asset) async {
    if (!_canEditAsset) {
      _showMessage('You do not have permission to edit assets.');
      return;
    }

    final nameController = TextEditingController(text: asset.name);
    final linkController = TextEditingController(text: asset.link ?? '');
    final usernameController = TextEditingController(
      text: asset.username ?? '',
    );
    final passwordController = TextEditingController(
      text: asset.password ?? '',
    );

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Edit Asset',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Asset Name',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: linkController,
                      decoration: const InputDecoration(
                        labelText: 'Link',
                        hintText: 'https://',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username / Login ID',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (saved != true || !mounted) {
        return;
      }

      await ApiService.updateAsset(
        assetId: asset.id,
        companyId: asset.companyId,
        companyName: asset.companyName,
        section: asset.section,
        type: asset.type,
        name: nameController.text.trim(),
        description: asset.description,
        link: linkController.text.trim().isEmpty
            ? null
            : linkController.text.trim(),
        username: usernameController.text.trim().isEmpty
            ? null
            : usernameController.text.trim(),
        password: passwordController.text.trim().isEmpty
            ? null
            : passwordController.text.trim(),
      );

      await _loadAssets();

      if (!mounted) {
        return;
      }

      _showMessage('Asset updated successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Unable to update asset: $error');
    } finally {
      nameController.dispose();
      linkController.dispose();
      usernameController.dispose();
      passwordController.dispose();
    }
  }

  // ============================================================
  // VIEW
  // ============================================================

  void _viewAsset(AssetModel asset) {
    if (!_canViewAsset) {
      _showMessage('You do not have permission to view assets.');
      return;
    }

    setState(() => _previewAsset = asset);
  }

  // ============================================================
  // DELETE ASSET
  // ============================================================

  Future<void> _deleteAsset(AssetModel asset) async {
    if (!_canDeleteAsset) {
      _showMessage('You do not have permission to delete assets.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Asset',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Are you sure you want to delete "${asset.name}"? This action cannot be undone.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ApiService.deleteAsset(asset.id);

      await _loadAssets();

      if (!mounted) {
        return;
      }

      _showMessage('Asset deleted successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to delete asset: $error');
    }
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  Future<void> _downloadAsset(AssetModel asset) async {
    if (!_canDownloadAsset) {
      _showMessage('You do not have permission to download assets.');
      return;
    }

    final filePath = asset.filePath?.trim() ?? '';

    if (filePath.isEmpty) {
      _showMessage('No uploaded file is available for this asset.');
      return;
    }

    try {
      _showMessage('Preparing download...');

      final bytes = await ApiService.downloadAsset(asset.id);

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        _showMessage('The downloaded file is empty.');
        return;
      }

      final fileName = _getDownloadFileName(asset);

      final success = await _downloadBytes(bytes, fileName);

      if (!mounted) {
        return;
      }

      if (success) {
        _showMessage('Download started for "$fileName".');
      } else {
        _showMessage('Unable to download this asset.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Download failed: $error');
    }
  }

  Future<bool> _downloadBytes(Uint8List bytes, String fileName) async {
    return downloadFileBytes(bytes, fileName, _mimeTypeForFile(fileName));
  }

  // ============================================================
  // OPEN LINK
  // ============================================================

  Future<void> _openLink(String link) async {
    var cleanLink = link.trim();

    if (cleanLink.isEmpty) {
      return;
    }

    if (!cleanLink.startsWith('http://') && !cleanLink.startsWith('https://')) {
      cleanLink = 'https://$cleanLink';
    }

    final uri = Uri.tryParse(cleanLink);

    if (uri == null) {
      _showMessage('Invalid link.');
      return;
    }

    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!success && mounted) {
      _showMessage('Unable to open the link.');
    }
  }

  // ============================================================
  // FILE NAME
  // ============================================================

  String _getDownloadFileName(AssetModel asset) {
    final existingPath = asset.filePath?.trim() ?? '';

    if (existingPath.isNotEmpty) {
      final normalized = existingPath.replaceAll('\\', '/');

      final parts = normalized.split('/');

      final last = parts.isNotEmpty ? parts.last : '';

      if (last.isNotEmpty && last.contains('.')) {
        return last;
      }
    }

    final safeName = asset.name.trim().isEmpty ? 'asset' : asset.name.trim();

    switch (asset.type) {
      case AppConstants.poster:
        return '$safeName.png';

      case AppConstants.reelVideo:
        return '$safeName.mp4';

      case AppConstants.document:
        return '$safeName.pdf';

      case AppConstants.mobileApplication:
        return '$safeName.apk';

      case AppConstants.others:
        return '$safeName.file';

      default:
        return safeName;
    }
  }

  // ============================================================
  // MIME TYPE
  // ============================================================

  String _mimeTypeForFile(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }

    if (lower.endsWith('.webm')) {
      return 'video/webm';
    }

    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }

    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }

    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    if (lower.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }

    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }

    if (lower.endsWith('.apk')) {
      return 'application/vnd.android.package-archive';
    }

    if (lower.endsWith('.aab')) {
      return 'application/octet-stream';
    }

    if (lower.endsWith('.ipa')) {
      return 'application/octet-stream';
    }

    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return 'text/html';
    }

    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }

    if (lower.endsWith('.csv')) {
      return 'text/csv';
    }

    if (lower.endsWith('.json')) {
      return 'application/json';
    }

    return 'application/octet-stream';
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return PremiumEmptyState(
      icon: Icons.folder_open_outlined,
      title: 'No assets found',
      message: _search.isNotEmpty || _filter != 'All'
          ? 'There are no assets matching your search or filter.'
          : 'There are no assets in this company.',
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return PremiumBackground(
      child: PremiumErrorState(
        title: 'Unable to load assets',
        message: _errorMessage ?? 'Something went wrong.',
        retryLabel: 'Try Again',
        onRetry: _loadAssets,
      ),
    );
  }

  // ============================================================
  // ICON
  // ============================================================

  IconData _getAssetIcon(String type) {
    switch (type) {
      case AppConstants.poster:
        return Icons.image_outlined;

      case AppConstants.reelVideo:
        return Icons.video_library_outlined;

      case AppConstants.document:
        return Icons.description_outlined;

      case AppConstants.websiteLink:
        return Icons.language_outlined;

      case AppConstants.webApplication:
        return Icons.language_outlined;

      case AppConstants.mobileApplication:
        return Icons.phone_android_outlined;

      case AppConstants.others:
        return Icons.apps_outlined;

      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  // ============================================================
  // FILTER LABEL
  // ============================================================

  String _filterLabel(String value) {
    switch (value) {
      case AppConstants.poster:
        return 'Posters';

      case AppConstants.reelVideo:
        return 'Videos';

      case AppConstants.document:
        return 'Documents';

      case AppConstants.websiteLink:
        return 'Links';

      case AppConstants.webApplication:
        return 'Web Apps';

      case AppConstants.mobileApplication:
        return 'Mobile Apps';

      default:
        return value;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _hasLink(AssetModel asset) {
    return asset.link != null && asset.link!.trim().isNotEmpty;
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.primary.withValues(alpha: 0.10),
      child: const Icon(
        Icons.business_rounded,
        size: 24,
        color: AppColors.primary,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// ASSET PREVIEW PAGE
// ============================================================================

class AssetPreviewPage extends StatefulWidget {
  final AssetModel asset;
  final VoidCallback? onBack;

  const AssetPreviewPage({super.key, required this.asset, this.onBack});

  @override
  State<AssetPreviewPage> createState() => _AssetPreviewPageState();
}

class _AssetPreviewPageState extends State<AssetPreviewPage> {
  bool _isDownloading = false;

  AssetModel get asset => widget.asset;

  void _back() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumColors.surface,
      body: PremiumPage(
        builder: (context, bp) => [
          _buildBreadcrumb(),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 900;
              if (mobile) {
                return Column(
                  children: [
                    Reveal(child: _buildPreviewArea()),
                    SizedBox(height: bp.gap),
                    Reveal(
                      delay: const Duration(milliseconds: 120),
                      child: _buildDetailsPanel(),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: Reveal(child: _buildPreviewArea())),
                  SizedBox(width: bp.gap),
                  SizedBox(
                    width: 380,
                    child: Reveal(
                      delay: const Duration(milliseconds: 120),
                      child: _buildDetailsPanel(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Preview height that keeps the whole page inside a laptop screen.
  double get _previewHeight {
    final size = MediaQuery.of(context).size;
    if (size.width < 700) return 300;
    return (size.height - 190).clamp(300.0, 560.0);
  }

  // ── Breadcrumb ──────────────────────────────────────────────
  Widget _buildBreadcrumb() {
    Widget link(String label) => HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: _back,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: hovered ? PremiumColors.blue : PremiumColors.muted,
          ),
        ),
      ),
    );
    const chevron = Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: PremiumColors.faint,
      ),
    );
    return Row(
      children: [
        PremiumIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back to assets',
          onPressed: _back,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              link('Asset Library'),
              chevron,
              link(asset.companyName),
              chevron,
              Text(
                asset.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PremiumColors.blue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Details panel (right column) ────────────────────────────
  Widget _buildDetailsPanel() {
    final hasFile = (asset.filePath?.trim().isNotEmpty ?? false);
    final link = asset.link?.trim() ?? '';
    final hasLink = link.isNotEmpty;
    final description = asset.description?.trim() ?? '';

    return PremiumPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Blue title strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: PremiumColors.heroGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getAssetIcon(asset.type),
                        size: 13,
                        color: const Color(0xFFBFDBFE),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        asset.type,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  asset.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: PremiumColors.body,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // File info
                if (hasFile) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PremiumColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PremiumColors.line),
                    ),
                    child: Row(
                      children: [
                        const PremiumIconTile(
                          icon: Icons.insert_drive_file_outlined,
                          accent: PremiumAccent.blue,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_displayFileName(asset.filePath!.trim())}'
                                '${asset.fileSize != null ? '  ·  ${_formatBytes(asset.fileSize!)}' : ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: PremiumColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Updated ${_formatDateTime(asset.updatedAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PremiumColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Company / Section
                _infoRow('Company', asset.companyName),
                _infoRow('Section', asset.section),
                const SizedBox(height: 6),
                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hasFile)
                      PremiumButton(
                        label: _isDownloading ? 'Downloading...' : 'Download',
                        icon: Icons.download_rounded,
                        iconLeading: true,
                        loading: _isDownloading,
                        onPressed: _isDownloading ? null : _download,
                      ),
                    if (hasLink)
                      PremiumButton(
                        label: 'Open original',
                        icon: Icons.open_in_new_rounded,
                        iconLeading: true,
                        variant: PremiumButtonVariant.soft,
                        onPressed: () => _openLink(link),
                      ),
                    PremiumButton(
                      label: 'Back to assets',
                      icon: Icons.arrow_back_rounded,
                      iconLeading: true,
                      variant: PremiumButtonVariant.outlined,
                      onPressed: _back,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Info note
                const PremiumInfoNote(
                  text:
                      'This preview adapts to the asset type. Links, web apps and '
                      'mobile apps open in a safe link card. Documents and videos '
                      'use their respective previews with playback and download '
                      'options.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    int hour = local.hour % 12;
    if (hour == 0) hour = 12;
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(local)}, $hour:$min $ampm';
  }

  // ============================================================
  // PREVIEW
  // ============================================================

  String? _fileFullUrl() {
    final path = asset.filePath?.trim();
    if (path == null || path.isEmpty) return null;
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) return path;
    final root = ApiService.baseUrl
        .replaceFirst('/client-repository', '')
        .replaceFirst('/api', '');
    return '$root${path.startsWith('/') ? path : '/$path'}';
  }

  static const _imageExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'tiff',
    'tif',
    'svg',
    'heic',
    'heif',
    'avif',
  };
  static const _videoExts = {
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
    'wmv',
    'flv',
    'm4v',
    'ts',
    'mpeg',
    'mpg',
    '3gp',
  };

  Widget _buildPreviewArea() {
    // 1. Uploaded file takes priority
    final url = _fileFullUrl();
    if (url != null) {
      final ext = url.split('.').last.toLowerCase().split('?').first;
      if (_imageExts.contains(ext)) return _buildImagePreview(url);
      if (_videoExts.contains(ext)) return _buildVideoPreview(url);
    }

    // 2. If no uploaded file, try rendering the link as an image
    final link = asset.link?.trim();
    if (link != null && link.isNotEmpty) {
      final linkExt = link.split('?').first.split('.').last.toLowerCase();
      if (_imageExts.contains(linkExt)) {
        // Direct image URL — render it
        return _buildImagePreview(link);
      }
      // Non-image link (Google Drive, Google Photos, etc.) — try loading anyway,
      // fall back to a link-preview card on error
      return _buildLinkImagePreview(link);
    }

    return _buildPlaceholderPreview();
  }

  BoxDecoration get _stageDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: PremiumColors.line),
    boxShadow: const [
      BoxShadow(color: Color(0x0F1E40AF), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );

  Widget _buildLinkImagePreview(String link) {
    if (kIsWeb) {
      return _buildLinkFallbackCard(link);
    }
    // Non-web fallback: try as image, else link card
    return Container(
      width: double.infinity,
      height: _previewHeight,
      decoration: _stageDecoration,
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        link,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _buildLinkFallbackCard(link),
      ),
    );
  }

  Widget _buildLinkFallbackCard(String link) {
    final host = Uri.tryParse(link)?.host ?? link;
    return Container(
      width: double.infinity,
      height: _previewHeight,
      decoration: _stageDecoration.copyWith(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF2FF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumFloat(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: PremiumAccent.blue.gradient,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x402563EB),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'External Link',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PremiumColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              PremiumBadge(label: host, icon: Icons.link_rounded),
              const SizedBox(height: 8),
              const Text(
                'Live preview is not available for external websites.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: PremiumColors.muted),
              ),
              const SizedBox(height: 18),
              PremiumButton(
                label: 'Open in Browser',
                icon: Icons.open_in_new_rounded,
                iconLeading: true,
                onPressed: () async {
                  final uri = Uri.tryParse(link);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String url) {
    return Container(
      width: double.infinity,
      height: _previewHeight,
      decoration: _stageDecoration.copyWith(color: PremiumColors.surface),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Center(
                child: CircularProgressIndicator(
                  color: PremiumColors.blue,
                  backgroundColor: const Color(0xFFDCE8FF),
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                      : null,
                ),
              ),
        errorBuilder: (_, _, _) => _buildPlaceholderPreview(),
      ),
    );
  }

  Widget _buildVideoPreview(String url) {
    return Container(
      width: double.infinity,
      height: _previewHeight,
      decoration: BoxDecoration(
        gradient: PremiumColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumFloat(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x40000F3D),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 46,
                    color: PremiumColors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Video File',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                url.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF)),
              ),
              const SizedBox(height: 16),
              PremiumButton(
                label: 'Open / Download',
                icon: Icons.open_in_new_rounded,
                iconLeading: true,
                variant: PremiumButtonVariant.light,
                onPressed: () async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderPreview() {
    return Container(
      width: double.infinity,
      height: _previewHeight,
      decoration: _stageDecoration.copyWith(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FF), Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumFloat(
                child: Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: PremiumAccent.blue.gradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x402563EB),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getAssetIcon(asset.type),
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                asset.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PremiumColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              PremiumBadge(
                label: _previewMessage(),
                icon: _getAssetIcon(asset.type),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewMessage() {
    switch (asset.type) {
      case AppConstants.poster:
        return 'Poster preview';

      case AppConstants.reelVideo:
        return 'Video asset';

      case AppConstants.document:
        return 'Document preview';

      case AppConstants.websiteLink:
        return 'Website link';

      case AppConstants.webApplication:
        return 'Web application';

      case AppConstants.mobileApplication:
        return 'Mobile application';

      default:
        return 'Asset preview';
    }
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PremiumColors.rowLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label.toUpperCase(),
              style: PremiumColors.tableHeaderStyle,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: PremiumColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  Future<void> _download() async {
    final filePath = asset.filePath?.trim() ?? '';

    if (filePath.isEmpty) {
      _showMessage('No uploaded file is available.');
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final Uint8List bytes = await ApiService.downloadAsset(asset.id);

      if (bytes.isEmpty) {
        throw Exception('The server returned an empty file.');
      }

      final fileName = _getDownloadFileName();

      final success = await _downloadBytes(bytes, fileName);

      if (!mounted) {
        return;
      }

      if (success) {
        _showMessage('Download started: $fileName');
      } else {
        _showMessage('Unable to download this asset.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Download failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<bool> _downloadBytes(Uint8List bytes, String fileName) async {
    return downloadFileBytes(bytes, fileName, _mimeTypeForFile(fileName));
  }

  // ============================================================
  // OPEN LINK
  // ============================================================

  Future<void> _openLink(String link) async {
    var cleanLink = link.trim();

    if (!cleanLink.startsWith('http://') && !cleanLink.startsWith('https://')) {
      cleanLink = 'https://$cleanLink';
    }

    final uri = Uri.tryParse(cleanLink);

    if (uri == null) {
      _showMessage('Invalid link.');
      return;
    }

    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!success && mounted) {
      _showMessage('Unable to open the link.');
    }
  }

  // ============================================================
  // COPY LINK
  // ============================================================

  String _getDownloadFileName() {
    final existingPath = asset.filePath?.trim() ?? '';

    if (existingPath.isNotEmpty) {
      final normalized = existingPath.replaceAll('\\', '/');

      final parts = normalized.split('/');

      final last = parts.isNotEmpty ? parts.last : '';

      if (last.isNotEmpty && last.contains('.')) {
        return last;
      }
    }

    final name = asset.name.trim().isEmpty ? 'asset' : asset.name.trim();

    switch (asset.type) {
      case AppConstants.poster:
        return '$name.png';

      case AppConstants.reelVideo:
        return '$name.mp4';

      case AppConstants.document:
        return '$name.pdf';

      case AppConstants.mobileApplication:
        return '$name.apk';

      case AppConstants.others:
        return '$name.file';

      default:
        return name;
    }
  }

  String _displayFileName(String path) {
    final normalized = path.replaceAll('\\', '/');

    final parts = normalized.split('/');

    if (parts.isEmpty) {
      return path;
    }

    return parts.last;
  }

  String _mimeTypeForFile(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }

    if (lower.endsWith('.webm')) {
      return 'video/webm';
    }

    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }

    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }

    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    if (lower.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }

    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }

    if (lower.endsWith('.apk')) {
      return 'application/vnd.android.package-archive';
    }

    if (lower.endsWith('.aab')) {
      return 'application/octet-stream';
    }

    if (lower.endsWith('.ipa')) {
      return 'application/octet-stream';
    }

    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      return 'text/html';
    }

    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }

    if (lower.endsWith('.csv')) {
      return 'text/csv';
    }

    if (lower.endsWith('.json')) {
      return 'application/json';
    }

    return 'application/octet-stream';
  }

  // ============================================================
  // ICON
  // ============================================================

  IconData _getAssetIcon(String type) {
    switch (type) {
      case AppConstants.poster:
        return Icons.image_outlined;

      case AppConstants.reelVideo:
        return Icons.video_library_outlined;

      case AppConstants.document:
        return Icons.description_outlined;

      case AppConstants.websiteLink:
        return Icons.language_outlined;

      case AppConstants.webApplication:
        return Icons.language_outlined;

      case AppConstants.mobileApplication:
        return Icons.phone_android_outlined;

      case AppConstants.others:
        return Icons.apps_outlined;

      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Iframe preview widget — tries to embed the link; shows hint if refused
// ---------------------------------------------------------------------------
class _IframePreview extends StatelessWidget {
  final String viewId;
  final String link;
  const _IframePreview({required this.viewId, required this.link});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          HtmlElementView(viewType: viewId),
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'If blank, the site blocks embedding — use Open Link',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(link);
                if (uri != null)
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Open Link', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
