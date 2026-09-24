
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/asset_model.dart';
import '../../../models/company_model.dart';
import '../../../services/api_service.dart';
import '../../../services/download_history.dart';
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
  State<CompanyAssetsPage> createState() =>
      _CompanyAssetsPageState();
}

class _CompanyAssetsPageState
    extends State<CompanyAssetsPage> {
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

  late String _companyName;

  List<String> get _filters {
    if (widget.section ==
        AppConstants.digitalMarketing) {
      return const [
        'All',
        AppConstants.poster,
        AppConstants.reelVideo,
        AppConstants.document,
        AppConstants.websiteLink,
        AppConstants.others,
      ];
    }

    return const [
      'All',
      AppConstants.webApplication,
      AppConstants.mobileApplication,
      AppConstants.others,
    ];
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
      final permissions =
          await ApiService.getMyPermissions();

      if (!mounted) {
        return;
      }

      setState(() {
        _canViewAsset =
            _permissionEnabled(permissions['can_view']);
        _canDownloadAsset =
            _permissionEnabled(permissions['can_download']);
        _canCreateAsset =
            _permissionEnabled(permissions['can_create']);
        _canEditAsset =
            _permissionEnabled(permissions['can_edit']);
        _canDeleteAsset =
            _permissionEnabled(permissions['can_delete']);

        // The same Edit/Delete permissions also control
        // company-level Edit/Delete actions on this screen.
        _canEditCompany =
            _permissionEnabled(permissions['can_edit']);
        _canDeleteCompany =
            _permissionEnabled(permissions['can_delete']);
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
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes';
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

        final data =
            Map<String, dynamic>.from(item);

        try {
          final asset =
              _assetFromJson(data);

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
        _errorMessage =
            error.toString();
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
      _showMessage(
        'You do not have permission to edit this company.',
      );
      return;
    }

    final controller =
        TextEditingController(text: _companyName);

    final selectedSections = <String>{
      ...widget.company.allSections.isNotEmpty
          ? widget.company.allSections
          : (widget.company.section != null
              ? [widget.company.section!]
              : []),
    };

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text(
                  'Edit Company',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sections',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final sectionOption in [
                          AppConstants.digitalMarketing,
                          AppConstants.softwareDevelopment,
                        ])
                          CheckboxListTile(
                            value: selectedSections
                                .contains(sectionOption),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedSections.add(sectionOption);
                                } else {
                                  selectedSections.remove(sectionOption);
                                }
                              });
                            },
                            title: Text(
                              sectionOption,
                              style: const TextStyle(fontSize: 14),
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Company Name',
                            hintText: 'Enter company name',
                            prefixIcon:
                                Icon(Icons.business_outlined),
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
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();

                      if (value.isEmpty) {
                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a company name.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (selectedSections.isEmpty) {
                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select at least one section.',
                            ),
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

      if (newName == null ||
          newName.trim().isEmpty ||
          !mounted) {
        return;
      }

      await ApiService.updateCompany(
        companyId: widget.company.id,
        name: newName.trim(),
        sections: newSections,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _companyName = newName.trim();
      });

      _showMessage(
        'Company updated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to update company: $error',
      );
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
      _showMessage(
        'You do not have permission to delete this company.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Entire Company',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete '
            '"$_companyName"?\n\n'
            'This will permanently delete the entire company '
            'and all of its assets. This action cannot be undone.',
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
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
      await ApiService.deleteCompany(
        widget.company.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Company deleted successfully.',
      );

      // Tell the previous Asset Library page that the company
      // was deleted so it can refresh its company list.
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to delete company: $error',
      );
    }
  }

  // ============================================================
  // ADD ASSET
  // ============================================================

  Future<void> _addAsset() async {
    if (!_canCreateAsset) {
      _showMessage(
        'You do not have permission to add assets.',
      );
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

      _showMessage(
        '"${asset.name}" added successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to add asset: $error',
      );
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

  AssetModel _assetFromJson(
    Map<String, dynamic> data,
  ) {
    final createdAt =
        _parseDate(
      data['created_at'] ??
          data['createdAt'],
    );

    final updatedAt =
        _parseDate(
      data['updated_at'] ??
          data['updatedAt'] ??
          data['created_at'] ??
          data['createdAt'],
    );

    return AssetModel(
      id: _stringValue(
        data['id'],
      ),
      companyId: _stringValue(
        data['company_id'] ??
            data['companyId'],
      ),
      companyName: _stringValue(
        data['company_name'] ??
            data['companyName'],
      ),
      section: _stringValue(
        data['section'],
      ),
      type: _stringValue(
        data['type'],
      ),
      name: _stringValue(
        data['name'],
      ),
      link: _nullableString(
        data['link'],
      ),
      username: _nullableString(
        data['username'],
      ),
      password: _nullableString(
        data['password'],
      ),
      description: _nullableString(data['description']),
      filePath: _nullableString(data['file_url'] ?? data['file_path'] ?? data['filePath']),
      fileName: _nullableString(data['file_name'] ?? data['fileName']),
      mimeType: _nullableString(data['mime_type'] ?? data['mimeType']),
      fileSize: data['file_size'] is num ? (data['file_size'] as num).toInt() : null,
      createdByEmployeeId: _nullableString(data['created_by_employee_id'] ?? data['createdByEmployeeId']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String _stringValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final result =
        value.toString().trim();

    if (result.isEmpty ||
        result.toLowerCase() == 'null') {
      return null;
    }

    return result;
  }

  DateTime _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value;
    }

    final parsed =
        DateTime.tryParse(
      value.toString(),
    );

    return parsed ??
        DateTime.now();
  }

  // ============================================================
  // FILTER COMPANY ASSETS
  // ============================================================

  List<AssetModel> get _companyAssets {
    final query =
        _search.trim().toLowerCase();

    return _allAssets.where((asset) {
      // Company filter.
      if (asset.companyId !=
          widget.company.id) {
        return false;
      }

      // Section filter.
      if (asset.section !=
          widget.section) {
        return false;
      }

      // Type filter.
      if (_filter != 'All' &&
          asset.type != _filter) {
        return false;
      }

      // Search filter.
      if (query.isNotEmpty) {
        final matchesName =
            asset.name
                .toLowerCase()
                .contains(query);

        final matchesType =
            asset.type
                .toLowerCase()
                .contains(query);

        final matchesCompany =
            asset.companyName
                .toLowerCase()
                .contains(query);

        if (!matchesName &&
            !matchesType &&
            !matchesCompany) {
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
  Widget build(
    BuildContext context,
  ) {
    final width =
        MediaQuery.of(context).size.width;

    final mobile = width < 700;

    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,
        titleSpacing:
            mobile ? 0 : 20,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'Company Assets',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.w700,
            color:
                AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading
                ? null
                : () async {
                    await _loadPermissions();
                    await _loadAssets();
                  },
            icon: const Icon(
              Icons.refresh,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(mobile),
    );
  }

  Widget _buildBody(
    bool mobile,
  ) {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        mobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildCompanyHeader(
            mobile,
          ),

          const SizedBox(
            height: 22,
          ),

          _buildSearch(),

          const SizedBox(
            height: 14,
          ),

          _buildFilters(),

          const SizedBox(
            height: 20,
          ),

          if (_companyAssets.isEmpty)
            _buildEmptyState()
          else
            Column(
              children:
                  _companyAssets.map(
                (asset) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child:
                        _buildAssetCard(
                      asset,
                      mobile,
                    ),
                  );
                },
              ).toList(),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPANY HEADER
  // ============================================================

  Widget _buildCompanyHeader(
    bool mobile,
  ) {
    final digitalMarketing =
        widget.section ==
            AppConstants.digitalMarketing;

    final color = digitalMarketing
        ? AppColors.digitalMarketing
        : AppColors.softwareDevelopment;

    final lightColor = digitalMarketing
        ? AppColors.digitalMarketingLight
        : AppColors.softwareDevelopmentLight;

    final companyName =
        _companyName.trim();

    final firstLetter =
        companyName.isNotEmpty
            ? companyName
                .substring(0, 1)
                .toUpperCase()
            : 'C';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        mobile ? 18 : 22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          _buildCompanyLogo(mobile, color, lightColor, firstLetter),

          const SizedBox(
            width: 15,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:
                        mobile ? 20 : 23,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        AppColors.textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  widget.section,
                  style: TextStyle(
                    fontSize:
                        mobile ? 13 : 14,
                    color: color,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  '${_companyAssets.length} '
                  '${_companyAssets.length == 1 ? 'asset' : 'assets'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ==========================================================
          // COMPANY ACTIONS
          //
          // Edit/Delete use the same user permissions:
          //   can_edit   -> Edit Company
          //   can_delete -> Delete Company
          //
          // These are placed immediately before Add Asset, matching
          // the marked location in the requested design.
          // ==========================================================

          if (_canEditCompany)
            Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: IconButton(
                tooltip: 'Edit Company Name',
                padding: EdgeInsets.zero,
                onPressed: _editCompany,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

          if (_canDeleteCompany)
            Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: IconButton(
                tooltip: 'Delete Entire Company',
                padding: EdgeInsets.zero,
                onPressed: _deleteCompany,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red,
                ),
              ),
            ),

          if (_canCreateAsset)
            if (mobile)
              IconButton.filled(
                tooltip: 'Add Asset',
                onPressed:
                    _isAddingAsset ? null : _addAsset,
                icon: _isAddingAsset
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
              )
            else
              FilledButton.icon(
                onPressed:
                    _isAddingAsset ? null : _addAsset,
                icon: _isAddingAsset
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _isAddingAsset
                      ? 'Adding...'
                      : 'Add Asset',
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildCompanyLogo(bool mobile, Color color, Color lightColor, String firstLetter) {
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
          errorBuilder: (_, __, ___) => Container(
            alignment: Alignment.center,
            color: lightColor,
            child: Text(firstLetter, style: TextStyle(fontSize: mobile ? 22 : 26, fontWeight: FontWeight.w800, color: color)),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: lightColor, borderRadius: BorderRadius.circular(13)),
      child: Text(firstLetter, style: TextStyle(fontSize: mobile ? 22 : 26, fontWeight: FontWeight.w800, color: color)),
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
      style: const TextStyle(
        fontSize: 14,
        color:
            AppColors.textPrimary,
      ),
      decoration:
          const InputDecoration(
        hintText:
            'Search assets...',
        prefixIcon: Icon(
          Icons.search,
          size: 22,
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,
      child: Row(
        children:
            _filters.map((filter) {
          final selected =
              _filter == filter;

          return Padding(
            padding:
                const EdgeInsets.only(
              right: 8,
            ),
            child: ChoiceChip(
              label: Text(
                _filterLabel(
                  filter,
                ),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : AppColors
                          .textSecondary,
                ),
              ),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _filter = filter;
                });
              },
              selectedColor:
                  AppColors.primary,
              backgroundColor:
                  Colors.white,
              side: BorderSide(
                color: selected
                    ? AppColors.primary
                    : AppColors.border,
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 8,
                vertical: 4,
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

  Widget _buildAssetCard(
    AssetModel asset,
    bool mobile,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding:
            const EdgeInsets.all(15),
        child: mobile
            ? _buildMobileAssetCard(
                asset,
              )
            : _buildDesktopAssetCard(
                asset,
              ),
      ),
    );
  }

  Widget _buildDesktopAssetCard(
    AssetModel asset,
  ) {
    return Row(
      children: [
        _buildAssetIcon(asset),

        const SizedBox(
          width: 14,
        ),

        Expanded(
          child:
              _buildAssetInformation(
            asset,
          ),
        ),

        const SizedBox(
          width: 15,
        ),

        if (_hasLink(asset))
          SizedBox(
            width: 210,
            child:
                _buildLinkPreview(
              asset,
            ),
          ),

        const SizedBox(
          width: 10,
        ),

        _buildActions(asset),
      ],
    );
  }

  Widget _buildMobileAssetCard(
    AssetModel asset,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildAssetIcon(asset),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  _buildAssetInformation(
                asset,
              ),
            ),
          ],
        ),

        if (_hasLink(asset)) ...[
          const SizedBox(
            height: 13,
          ),
          _buildLinkPreview(asset),
        ],

        const SizedBox(
          height: 13,
        ),

        Align(
          alignment:
              Alignment.centerRight,
          child:
              _buildActions(asset),
        ),
      ],
    );
  }

  Widget _buildAssetIcon(
    AssetModel asset,
  ) {
    return Container(
      width: 56,
      height: 56,
      alignment:
          Alignment.center,
      decoration: BoxDecoration(
        color:
            const Color(0xFFF0F5FF),
        borderRadius:
            BorderRadius.circular(11),
      ),
      child: Icon(
        _getAssetIcon(
          asset.type,
        ),
        color:
            AppColors.primary,
        size: 27,
      ),
    );
  }

  Widget _buildAssetInformation(
    AssetModel asset,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          asset.name,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w700,
            color:
                AppColors.textPrimary,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        Wrap(
          spacing: 9,
          runSpacing: 5,
          children: [
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFEAF2FF,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Text(
                _filterLabel(
                  asset.type,
                ),
                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      AppColors.primary,
                ),
              ),
            ),

            Text(
              _formatDate(
                asset.updatedAt,
              ),
              style:
                  const TextStyle(
                fontSize: 13,
                color:
                    AppColors.textSecondary,
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

  Widget _buildLinkPreview(
    AssetModel asset,
  ) {
    final link =
        asset.link?.trim() ?? '';

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF8FAFD),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.link_outlined,
            size: 18,
            color:
                AppColors.primary,
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: Text(
              link,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 12,
                color:
                    AppColors.textSecondary,
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

  Widget _buildActions(
    AssetModel asset,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        if (_canViewAsset)
          IconButton(
            tooltip: 'View',
            onPressed: () {
              _viewAsset(asset);
            },
            icon: const Icon(
              Icons.visibility_outlined,
              size: 21,
            ),
          ),

        if (_canDownloadAsset)
          IconButton(
            tooltip: 'Download',
            onPressed: () {
              _downloadAsset(asset);
            },
            icon: const Icon(
              Icons.download_outlined,
              size: 21,
            ),
          ),

        IconButton(
          tooltip: 'Share',
          onPressed: () {
            _shareAsset(asset);
          },
          icon: const Icon(
            Icons.share_outlined,
            size: 21,
          ),
        ),

        if (_canEditAsset)
          IconButton(
            tooltip: 'Edit Asset',
            onPressed: () {
              _editAsset(asset);
            },
            icon: const Icon(
              Icons.edit_outlined,
              size: 21,
            ),
          ),

        if (_canDeleteAsset)
          IconButton(
            tooltip: 'Delete Asset',
            onPressed: () {
              _deleteAsset(asset);
            },
            icon: const Icon(
              Icons.delete_outline,
              size: 21,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // EDIT ASSET
  // ============================================================

  Future<void> _editAsset(AssetModel asset) async {
    if (!_canEditAsset) {
      _showMessage(
        'You do not have permission to edit assets.',
      );
      return;
    }

    final nameController =
        TextEditingController(text: asset.name);
    final linkController =
        TextEditingController(text: asset.link ?? '');
    final usernameController =
        TextEditingController(text: asset.username ?? '');
    final passwordController =
        TextEditingController(text: asset.password ?? '');

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Edit Asset',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
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
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
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

  void _viewAsset(
    AssetModel asset,
  ) {
    if (!_canViewAsset) {
      _showMessage(
        'You do not have permission to view assets.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AssetPreviewPage(
          asset: asset,
        ),
      ),
    );
  }

  // ============================================================
  // DELETE ASSET
  // ============================================================

  Future<void> _deleteAsset(
    AssetModel asset,
  ) async {
    if (!_canDeleteAsset) {
      _showMessage(
        'You do not have permission to delete assets.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Asset',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${asset.name}"? This action cannot be undone.',
            style: const TextStyle(
              fontSize: 14,
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

      _showMessage(
        'Asset deleted successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to delete asset: $error',
      );
    }
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  Future<void> _downloadAsset(
    AssetModel asset,
  ) async {
    if (!_canDownloadAsset) {
      _showMessage(
        'You do not have permission to download assets.',
      );
      return;
    }

    final filePath =
        asset.filePath?.trim() ?? '';

    if (filePath.isEmpty) {
      _showMessage(
        'No uploaded file is available for this asset.',
      );
      return;
    }

    try {
      _showMessage(
        'Preparing download...',
      );

      final bytes =
          await ApiService.downloadAsset(
        asset.id,
      );

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        _showMessage(
          'The downloaded file is empty.',
        );
        return;
      }

      final fileName =
          _getDownloadFileName(
        asset,
      );

      final success =
          await _downloadBytes(
        bytes,
        fileName,
      );

      if (!mounted) {
        return;
      }

      if (success) {
        await DownloadHistory.add(
          assetId: asset.id,
          fileName: fileName,
          assetName: asset.name,
          assetType: asset.type,
          companyName: asset.companyName,
        );

        _showMessage(
          'Download started for "$fileName".',
        );
      } else {
        _showMessage(
          'Unable to download this asset.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Download failed: $error',
      );
    }
  }

  Future<bool> _downloadBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    return downloadFileBytes(
      bytes,
      fileName,
      _mimeTypeForFile(fileName),
    );
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareAsset(
    AssetModel asset,
  ) async {
    final link =
        asset.link?.trim() ?? '';

    if (link.isEmpty) {
      _showMessage(
        'No link is available to share.',
      );
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: link,
      ),
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      'Asset link copied to clipboard.',
    );
  }

  // ============================================================
  // OPEN LINK
  // ============================================================

  Future<void> _openLink(
    String link,
  ) async {
    var cleanLink =
        link.trim();

    if (cleanLink.isEmpty) {
      return;
    }

    if (!cleanLink.startsWith(
          'http://',
        ) &&
        !cleanLink.startsWith(
          'https://',
        )) {
      cleanLink =
          'https://$cleanLink';
    }

    final uri =
        Uri.tryParse(cleanLink);

    if (uri == null) {
      _showMessage(
        'Invalid link.',
      );
      return;
    }

    final success =
        await launchUrl(
      uri,
      mode:
          LaunchMode
              .externalApplication,
    );

    if (!success && mounted) {
      _showMessage(
        'Unable to open the link.',
      );
    }
  }

  Future<void> _copyLink(
    String link,
  ) async {
    await Clipboard.setData(
      ClipboardData(
        text: link,
      ),
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      'Link copied.',
    );
  }

  // ============================================================
  // FILE NAME
  // ============================================================

  String _getDownloadFileName(
    AssetModel asset,
  ) {
    final existingPath =
        asset.filePath?.trim() ?? '';

    if (existingPath.isNotEmpty) {
      final normalized =
          existingPath.replaceAll(
        '\\',
        '/',
      );

      final parts =
          normalized.split('/');

      final last =
          parts.isNotEmpty
              ? parts.last
              : '';

      if (last.isNotEmpty &&
          last.contains('.')) {
        return last;
      }
    }

    final safeName =
        asset.name.trim().isEmpty
            ? 'asset'
            : asset.name.trim();

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

  String _mimeTypeForFile(
    String fileName,
  ) {
    final lower =
        fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
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
      return
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    if (lower.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }

    if (lower.endsWith('.xlsx')) {
      return
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }

    if (lower.endsWith('.apk')) {
      return
          'application/vnd.android.package-archive';
    }

    if (lower.endsWith('.aab')) {
      return 'application/octet-stream';
    }

    if (lower.endsWith('.ipa')) {
      return 'application/octet-stream';
    }

    if (lower.endsWith('.html') ||
        lower.endsWith('.htm')) {
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
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 50,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_open_outlined,
            size: 48,
            color:
                AppColors.textSecondary,
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'No assets found',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.textPrimary,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            _search.isNotEmpty ||
                    _filter != 'All'
                ? 'There are no assets matching your search or filter.'
                : 'There are no assets in this company.',
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color:
                  AppColors.textSecondary,
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
        padding:
            const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints:
              const BoxConstraints(
            maxWidth: 600,
          ),
          padding:
              const EdgeInsets.all(28),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color:
                  AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                size: 52,
                color: Colors.redAccent,
              ),

              const SizedBox(
                height: 16,
              ),

              const Text(
                'Unable to load assets',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      AppColors.textPrimary,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                _errorMessage ??
                    'Something went wrong.',
                textAlign:
                    TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color:
                      AppColors.textSecondary,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              FilledButton.icon(
                onPressed:
                    _loadAssets,
                icon: const Icon(
                  Icons.refresh,
                ),
                label:
                    const Text(
                  'Try Again',
                ),
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

  IconData _getAssetIcon(
    String type,
  ) {
    switch (type) {
      case AppConstants.poster:
        return Icons.image_outlined;

      case AppConstants.reelVideo:
        return Icons
            .video_library_outlined;

      case AppConstants.document:
        return Icons
            .description_outlined;

      case AppConstants.websiteLink:
        return Icons.language_outlined;

      case AppConstants.webApplication:
        return Icons.language_outlined;

      case AppConstants.mobileApplication:
        return Icons
            .phone_android_outlined;

      case AppConstants.others:
        return Icons.apps_outlined;

      default:
        return Icons
            .insert_drive_file_outlined;
    }
  }

  // ============================================================
  // FILTER LABEL
  // ============================================================

  String _filterLabel(
    String value,
  ) {
    switch (value) {
      case AppConstants.poster:
        return 'Posters';

      case AppConstants.reelVideo:
        return 'Reels / Videos';

      case AppConstants.document:
        return 'Documents';

      case AppConstants.websiteLink:
        return 'Website Links';

      default:
        return value;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final day =
        date.day
            .toString()
            .padLeft(2, '0');

    final month =
        date.month
            .toString()
            .padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _hasLink(
    AssetModel asset,
  ) {
    return asset.link != null &&
        asset.link!.trim().isNotEmpty;
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(
            fontSize: 14,
          ),
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }
}

// ============================================================================
// ASSET PREVIEW PAGE
// ============================================================================

class AssetPreviewPage
    extends StatefulWidget {
  final AssetModel asset;

  const AssetPreviewPage({
    super.key,
    required this.asset,
  });

  @override
  State<AssetPreviewPage>
      createState() =>
          _AssetPreviewPageState();
}

class _AssetPreviewPageState
    extends State<AssetPreviewPage> {
  bool _isDownloading = false;

  AssetModel get asset =>
      widget.asset;

  @override
  Widget build(
    BuildContext context,
  ) {
    final width =
        MediaQuery.of(context).size.width;

    final mobile = width < 700;

    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            Navigator.of(context)
                .pop();
          },
        ),
        title: const Text(
          'Asset Preview',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.w700,
            color:
                AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.all(
          mobile ? 16 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 850,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                _buildHeader(),

                const SizedBox(
                  height: 18,
                ),

                _buildPreviewArea(),

                const SizedBox(
                  height: 18,
                ),

                _buildLinkCard(),

                const SizedBox(
                  height: 18,
                ),

                _buildInformationCard(),

                const SizedBox(
                  height: 20,
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFEAF2FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              _getAssetIcon(
                asset.type,
              ),
              color:
                  AppColors.primary,
              size: 27,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  asset.name,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 21,
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
                  asset.type,
                  style:
                      const TextStyle(
                    fontSize: 14,
                    color:
                        AppColors
                            .textSecondary,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  asset.companyName,
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
        ],
      ),
    );
  }

  // ============================================================
  // PREVIEW
  // ============================================================

  Widget _buildPreviewArea() {
    return _buildPlaceholderPreview();
  }

  Widget _buildPlaceholderPreview() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color:
            const Color(0xFFF6F8FC),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              border: Border.all(
                color:
                    AppColors.border,
              ),
            ),
            child: Icon(
              _getAssetIcon(
                asset.type,
              ),
              size: 42,
              color:
                  AppColors.primary,
            ),
          ),

          const SizedBox(
            height: 17,
          ),

          Text(
            asset.name,
            textAlign:
                TextAlign.center,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.textPrimary,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            _previewMessage(),
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 13,
              color:
                  AppColors.textSecondary,
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

  Widget _buildLinkCard() {
    final link =
        asset.link?.trim() ?? '';

    if (link.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Asset Link',
            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.textPrimary,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(
              12,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF7F9FC,
              ),
              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),
            child: Text(
              link,
              maxLines: 3,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 13,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  _openLink(link);
                },
                icon: const Icon(
                  Icons.open_in_new,
                  size: 18,
                ),
                label:
                    const Text(
                  'Open Link',
                ),
              ),

              OutlinedButton.icon(
                onPressed: () {
                  _copyLink(link);
                },
                icon: const Icon(
                  Icons.copy_outlined,
                  size: 18,
                ),
                label:
                    const Text(
                  'Copy Link',
                ),
              ),

              OutlinedButton.icon(
                onPressed: () {
                  _shareLink(link);
                },
                icon: const Icon(
                  Icons.share_outlined,
                  size: 18,
                ),
                label:
                    const Text(
                  'Share',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFORMATION
  // ============================================================

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Asset Information',
            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.textPrimary,
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          _infoRow(
            'Company',
            asset.companyName,
          ),

          _infoRow(
            'Type',
            asset.type,
          ),

          if (asset.username != null &&
              asset.username!.trim().isNotEmpty)
            _infoRow(
              'Username',
              asset.username!,
            ),

          if (asset.password != null &&
              asset.password!.trim().isNotEmpty)
            _infoRow(
              'Password',
              asset.password!,
            ),

          _infoRow(
            'Created',
            _formatDate(
              asset.createdAt,
            ),
          ),

          _infoRow(
            'Updated',
            _formatDate(
              asset.updatedAt,
            ),
          ),

          _buildFileInfoRow(),
        ],
      ),
    );
  }

  Widget _buildFileInfoRow() {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 90,
            child: Text(
              'File',
              style:
                  TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color:
                    AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              asset.filePath != null &&
                      asset.filePath!.trim().isNotEmpty
                  ? _displayFileName(
                      asset.filePath!.trim(),
                    )
                  : 'No uploaded file',
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 14,
                color:
                    AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed:
                  _isDownloading
                      ? null
                      : _download,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      size: 18,
                    ),
              label: Text(
                _isDownloading
                    ? 'Downloading...'
                    : 'Download',
                style:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.primary,
                foregroundColor:
                    Colors.white,
                disabledBackgroundColor:
                    AppColors.primary
                        .withValues(
                  alpha: 0.65,
                ),
                disabledForegroundColor:
                    Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontSize: 14,
                color:
                    AppColors
                        .textPrimary,
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
    final filePath =
        asset.filePath?.trim() ?? '';

    if (filePath.isEmpty) {
      _showMessage(
        'No uploaded file is available.',
      );
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final Uint8List bytes =
          await ApiService.downloadAsset(
        asset.id,
      );

      if (bytes.isEmpty) {
        throw Exception(
          'The server returned an empty file.',
        );
      }

      final fileName =
          _getDownloadFileName();

      final success =
          await _downloadBytes(
        bytes,
        fileName,
      );

      if (!mounted) {
        return;
      }

      if (success) {
        await DownloadHistory.add(
          assetId: asset.id,
          fileName: fileName,
          assetName: asset.name,
          assetType: asset.type,
          companyName: asset.companyName,
        );

        _showMessage(
          'Download started: $fileName',
        );
      } else {
        _showMessage(
          'Unable to download this asset.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Download failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<bool> _downloadBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    return downloadFileBytes(
      bytes,
      fileName,
      _mimeTypeForFile(fileName),
    );
  }

  // ============================================================
  // OPEN LINK
  // ============================================================

  Future<void> _openLink(
    String link,
  ) async {
    var cleanLink =
        link.trim();

    if (!cleanLink.startsWith(
          'http://',
        ) &&
        !cleanLink.startsWith(
          'https://',
        )) {
      cleanLink =
          'https://$cleanLink';
    }

    final uri =
        Uri.tryParse(cleanLink);

    if (uri == null) {
      _showMessage(
        'Invalid link.',
      );
      return;
    }

    final success =
        await launchUrl(
      uri,
      mode:
          LaunchMode
              .externalApplication,
    );

    if (!success &&
        mounted) {
      _showMessage(
        'Unable to open the link.',
      );
    }
  }

  // ============================================================
  // COPY LINK
  // ============================================================

  Future<void> _copyLink(
    String link,
  ) async {
    await Clipboard.setData(
      ClipboardData(
        text: link,
      ),
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      'Link copied.',
    );
  }

  // ============================================================
  // SHARE LINK
  // ============================================================

  Future<void> _shareLink(
    String link,
  ) async {
    await Clipboard.setData(
      ClipboardData(
        text: link,
      ),
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      'Link copied. You can now share it.',
    );
  }

  // ============================================================
  // FILE NAME
  // ============================================================

  String _getDownloadFileName() {
    final existingPath =
        asset.filePath?.trim() ?? '';

    if (existingPath.isNotEmpty) {
      final normalized =
          existingPath.replaceAll(
        '\\',
        '/',
      );

      final parts =
          normalized.split('/');

      final last =
          parts.isNotEmpty
              ? parts.last
              : '';

      if (last.isNotEmpty &&
          last.contains('.')) {
        return last;
      }
    }

    final name =
        asset.name.trim().isEmpty
            ? 'asset'
            : asset.name.trim();

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

  String _displayFileName(
    String path,
  ) {
    final normalized =
        path.replaceAll(
      '\\',
      '/',
    );

    final parts =
        normalized.split('/');

    if (parts.isEmpty) {
      return path;
    }

    return parts.last;
  }

  String _mimeTypeForFile(
    String fileName,
  ) {
    final lower =
        fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
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
      return
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    if (lower.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }

    if (lower.endsWith('.xlsx')) {
      return
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }

    if (lower.endsWith('.apk')) {
      return
          'application/vnd.android.package-archive';
    }

    if (lower.endsWith('.aab')) {
      return 'application/octet-stream';
    }

    if (lower.endsWith('.ipa')) {
      return 'application/octet-stream';
    }

    if (lower.endsWith('.html') ||
        lower.endsWith('.htm')) {
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

  IconData _getAssetIcon(
    String type,
  ) {
    switch (type) {
      case AppConstants.poster:
        return Icons.image_outlined;

      case AppConstants.reelVideo:
        return Icons
            .video_library_outlined;

      case AppConstants.document:
        return Icons
            .description_outlined;

      case AppConstants.websiteLink:
        return Icons.language_outlined;

      case AppConstants.webApplication:
        return Icons.language_outlined;

      case AppConstants.mobileApplication:
        return Icons
            .phone_android_outlined;

      case AppConstants.others:
        return Icons.apps_outlined;

      default:
        return Icons
            .insert_drive_file_outlined;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final day =
        date.day
            .toString()
            .padLeft(
          2,
          '0',
        );

    final month =
        date.month
            .toString()
            .padLeft(
          2,
          '0',
        );

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(
            fontSize: 14,
          ),
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }
}