// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html;
// // ignore: avoid_web_libraries_in_flutter
// import 'dart:ui_web' as ui;

import 'package:godigital_portal/web_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:godigital_portal/ui_web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
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
                backgroundColor: Colors.red,
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
      backgroundColor: AppColors.background,
      body: _buildBody(mobile),
    );
  }

  Widget _buildBody(bool mobile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : 32,
        mobile ? 16 : 24,
        mobile ? 16 : 32,
        36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumb(),
          const SizedBox(height: 16),
          _buildCompanyHeader(mobile),
          const SizedBox(height: 20),
          _buildSearch(),
          const SizedBox(height: 16),
          _buildFilters(),
          const SizedBox(height: 18),
          if (_companyAssets.isEmpty)
            _buildEmptyState()
          else if (mobile)
            Column(
              children: _companyAssets
                  .map(
                    (asset) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAssetCard(asset, true),
                    ),
                  )
                  .toList(),
            )
          else
            _buildAssetsTable(),
        ],
      ),
    );
  }

  // ============================================================
  // BREADCRUMB
  // ============================================================

  Widget _buildBreadcrumb() {
    return Row(
      children: [
        InkWell(
          onTap: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).pop();
            }
          },
          child: const Text(
            'Asset Library',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('/', style: TextStyle(color: AppColors.textSecondary)),
        ),
        Flexible(
          child: Text(
            _companyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ASSETS TABLE (desktop)
  // ============================================================

  Widget _buildAssetsTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(flex: 30, child: _ColHead('Asset')),
                Expanded(flex: 14, child: _ColHead('Type')),
                Expanded(flex: 28, child: _ColHead('Description')),
                Expanded(flex: 14, child: _ColHead('Updated')),
                Expanded(flex: 16, child: _ColHead('Actions')),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Rows
          for (int i = 0; i < _companyAssets.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildTableRow(_companyAssets[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTableRow(AssetModel asset) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Asset (icon + name + filename)
          Expanded(
            flex: 30,
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
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        asset.fileName ?? asset.link ?? '—',
                        maxLines: 1,
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
          ),
          // Type chip
          Expanded(flex: 14, child: _buildTypeChip(asset.type)),
          // Description
          Expanded(
            flex: 28,
            child: Text(
              asset.description?.trim().isNotEmpty == true
                  ? asset.description!.trim()
                  : '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          // Updated
          Expanded(
            flex: 14,
            child: Text(
              _formatDate(asset.updatedAt),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Actions
          Expanded(flex: 16, child: _buildActions(asset)),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final (bg, fg) = _typeChipColors(type);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getAssetIcon(type), size: 13, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _shortTypeLabel(type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _typeChipColors(String type) {
    switch (type) {
      case AppConstants.poster:
        return (const Color(0xFFFDE7EC), const Color(0xFFE11D48));
      case AppConstants.reelVideo:
        return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      case AppConstants.document:
        return (const Color(0xFFE7F8EF), const Color(0xFF15803D));
      case AppConstants.websiteLink:
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case AppConstants.webApplication:
        return (const Color(0xFFDBEAFE), const Color(0xFF2563EB));
      case AppConstants.mobileApplication:
        return (const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      default:
        return (const Color(0xFFF1F5F9), AppColors.textSecondary);
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
    final color = widget.section == AppConstants.softwareDevelopment
        ? AppColors.softwareDevelopment
        : AppColors.digitalMarketing;
    final lightColor = widget.section == AppConstants.softwareDevelopment
        ? AppColors.softwareDevelopmentLight
        : AppColors.digitalMarketingLight;

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

    final meta = Text(
      '$sections  ·  $count ${count == 1 ? 'asset' : 'assets'}  ·  Last updated ${_formatDate(updated)}',
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );

    final identity = Row(
      children: [
        _buildCompanyLogo(mobile, color, lightColor, firstLetter),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: mobile ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              meta,
            ],
          ),
        ),
      ],
    );

    final actions = _buildPermissionActions(mobile);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                if (_canEditCompany ||
                    _canDeleteCompany ||
                    _canCreateAsset) ...[
                  const SizedBox(height: 14),
                  _buildCompactActions(),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: identity),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  // Compact mobile actions: small icon buttons for edit/delete + an
  // Add asset button, with no "PERMISSION BASED" captions (saves height).
  Widget _buildCompactActions() {
    Widget iconBtn({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      Color? color,
    }) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color == Colors.red
                ? const Color(0xFFFECACA)
                : AppColors.border,
          ),
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, size: 19, color: color ?? AppColors.textPrimary),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
        ),
      );
    }

    return Row(
      children: [
        if (_canEditCompany)
          iconBtn(
            icon: Icons.edit_outlined,
            tooltip: 'Edit company',
            onTap: _editCompany,
          ),
        if (_canEditCompany) const SizedBox(width: 10),
        if (_canDeleteCompany)
          iconBtn(
            icon: Icons.delete_outline,
            tooltip: 'Delete company',
            color: Colors.red,
            onTap: _deleteCompany,
          ),
        if (_canDeleteCompany) const SizedBox(width: 10),
        if (_canCreateAsset)
          Expanded(
            child: FilledButton.icon(
              onPressed: _isAddingAsset ? null : _addAsset,
              icon: _isAddingAsset
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add, size: 18),
              label: Text(_isAddingAsset ? 'Adding...' : 'Add asset'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
      ],
    );
  }

  // Permission-based company actions, each labelled "PERMISSION BASED".
  List<Widget> _buildPermissionActions(bool mobile) {
    final list = <Widget>[];

    if (_canEditCompany) {
      list.add(
        _permissionAction(
          label: 'Edit company',
          icon: Icons.edit_outlined,
          onTap: _editCompany,
        ),
      );
    }
    if (_canDeleteCompany) {
      list.add(
        _permissionAction(
          label: 'Delete',
          icon: Icons.delete_outline,
          danger: true,
          onTap: _deleteCompany,
        ),
      );
    }
    if (_canCreateAsset) {
      list.add(
        _permissionAction(
          label: _isAddingAsset ? 'Adding...' : 'Add asset',
          icon: Icons.add,
          filled: true,
          onTap: _isAddingAsset ? null : _addAsset,
        ),
      );
    }
    return list;
  }

  Widget _permissionAction({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool filled = false,
    bool danger = false,
  }) {
    final accent = danger ? Colors.red : AppColors.primary;
    final button = filled
        ? FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18, color: accent),
            label: Text(label, style: TextStyle(color: accent)),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(
                color: danger ? const Color(0xFFFECACA) : AppColors.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PERMISSION BASED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        button,
      ],
    );
  }

  Widget _buildCompanyLogo(
    bool mobile,
    Color color,
    Color lightColor,
    String firstLetter,
  ) {
    final size = mobile ? 54.0 : 64.0;
    final logoUrl = widget.company.logoUrl?.trim();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final parsed = Uri.tryParse(logoUrl);
      final imageUrl = parsed != null && parsed.hasScheme
          ? logoUrl
          : '${ApiService.baseUrl.replaceFirst('/client-repository', '').replaceFirst('/api', '')}${logoUrl.startsWith('/') ? logoUrl : '/$logoUrl'}';
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            alignment: Alignment.center,
            color: lightColor,
            child: Text(
              firstLetter,
              style: TextStyle(
                fontSize: mobile ? 22 : 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        firstLetter,
        style: TextStyle(
          fontSize: mobile ? 22 : 26,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _search = value;
        });
      },
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: const InputDecoration(
        hintText: 'Search assets...',
        prefixIcon: Icon(Icons.search, size: 22),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final selected = _filter == filter;
          final count = _countForType(filter);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _filter = filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
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
                  '${_filterLabel(filter)} ($count)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

  // ============================================================
  // ASSET CARD
  // ============================================================

  Widget _buildAssetCard(AssetModel asset, bool mobile) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: mobile
            ? _buildMobileAssetCard(asset)
            : _buildDesktopAssetCard(asset),
      ),
    );
  }

  Widget _buildDesktopAssetCard(AssetModel asset) {
    return Row(
      children: [
        _buildAssetIcon(asset),

        const SizedBox(width: 14),

        Expanded(child: _buildAssetInformation(asset)),

        const SizedBox(width: 15),

        if (_hasLink(asset))
          SizedBox(width: 210, child: _buildLinkPreview(asset)),

        const SizedBox(width: 10),

        _buildActions(asset),
      ],
    );
  }

  Widget _buildMobileAssetCard(AssetModel asset) {
    return Column(
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
          const SizedBox(height: 13),
          _buildLinkPreview(asset),
        ],

        const SizedBox(height: 13),

        Align(alignment: Alignment.centerRight, child: _buildActions(asset)),
      ],
    );
  }

  Widget _buildAssetIcon(AssetModel asset) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        _getAssetIcon(asset.type),
        color: AppColors.primary,
        size: 27,
      ),
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
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 7),

        Wrap(
          spacing: 9,
          runSpacing: 5,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _filterLabel(asset.type),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),

            Text(
              _formatDate(asset.updatedAt),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_outlined, size: 18, color: AppColors.primary),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
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
    Widget btn({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      Color? color,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      );
    }

    final isLink = _hasLink(asset);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canViewAsset)
          btn(
            icon: Icons.visibility_outlined,
            tooltip: 'View',
            onTap: () => _viewAsset(asset),
          ),
        if (_canDownloadAsset && !isLink)
          btn(
            icon: Icons.download_outlined,
            tooltip: 'Download',
            onTap: () => _downloadAsset(asset),
          ),
        if (isLink)
          btn(
            icon: Icons.open_in_new,
            tooltip: 'Open link',
            onTap: () => _openLink(asset.link!.trim()),
          ),
        if (_canEditAsset)
          btn(
            icon: Icons.edit_outlined,
            tooltip: 'Edit Asset',
            onTap: () => _editAsset(asset),
          ),
        if (_canDeleteAsset)
          btn(
            icon: Icons.delete_outline,
            tooltip: 'Delete Asset',
            color: Colors.red,
            onTap: () => _deleteAsset(asset),
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
                backgroundColor: Colors.red,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),

          const SizedBox(height: 12),

          const Text(
            'No assets found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _search.isNotEmpty || _filter != 'All'
                ? 'There are no assets matching your search or filter.'
                : 'There are no assets in this company.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Colors.redAccent,
              ),

              const SizedBox(height: 16),

              const Text(
                'Unable to load assets',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: _loadAssets,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
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

// Column header label for the assets table.
class _ColHead extends StatelessWidget {
  final String label;
  const _ColHead(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
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
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 900;
          final pad = constraints.maxWidth < 700 ? 16.0 : 32.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumb(),
                const SizedBox(height: 16),
                if (mobile)
                  Column(
                    children: [
                      _buildPreviewArea(),
                      const SizedBox(height: 18),
                      _buildDetailsPanel(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildPreviewArea()),
                      const SizedBox(width: 20),
                      SizedBox(width: 380, child: _buildDetailsPanel()),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Breadcrumb ──────────────────────────────────────────────
  Widget _buildBreadcrumb() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: _back,
          child: const Text(
            'Asset Library',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('/', style: TextStyle(color: AppColors.textSecondary)),
        ),
        InkWell(
          onTap: _back,
          child: Text(
            asset.companyName,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('/', style: TextStyle(color: AppColors.textSecondary)),
        ),
        Text(
          asset.name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            asset.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Type chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              asset.type,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          // File info
          if (hasFile)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_displayFileName(asset.filePath!.trim())}'
                        '${asset.fileSize != null ? '  ·  ${_formatBytes(asset.fileSize!)}' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Updated ${_formatDateTime(asset.updatedAt)}',
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
          if (hasFile) const SizedBox(height: 16),
          // Company / Section
          _infoRow('Company', asset.companyName),
          _infoRow('Section', asset.section),
          const SizedBox(height: 8),
          // Action buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to assets'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
              ),
              if (hasFile)
                FilledButton.icon(
                  onPressed: _isDownloading ? null : _download,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(_isDownloading ? 'Downloading...' : 'Download'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                ),
              if (hasLink)
                OutlinedButton.icon(
                  onPressed: () => _openLink(link),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open original'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          // Info note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This preview adapts to the asset type. Links, web apps and '
                    'mobile apps open in a safe link card. Documents and videos '
                    'use their respective previews with playback and download '
                    'options.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
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

  Widget _buildLinkImagePreview(String link) {
    if (kIsWeb) {
      return _buildLinkFallbackCard(link);
    }
    // Non-web fallback: try as image, else link card
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260, maxHeight: 520),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F4FF), Color(0xFFEEF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.language_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'External Link',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            host,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Live preview is not available for external websites.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.tryParse(link);
              if (uri != null)
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Open in Browser'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String url) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260, maxHeight: 520),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Center(
                child: CircularProgressIndicator(
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
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Video File',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            url.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.tryParse(url);
              if (uri != null)
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Open / Download',
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPreview() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              _getAssetIcon(asset.type),
              size: 42,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 17),

          Text(
            asset.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _previewMessage(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
  // LINK CARD
  // ============================================================

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
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
