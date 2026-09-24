import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/asset_model.dart';
import '../../../models/company_model.dart';
import '../../../services/api_service.dart';
import '../../../services/download_helper.dart';
import '../../../widgets/dialogs/add_asset_dialog.dart';
import '../../../widgets/dialogs/edit_asset_dialog.dart';

class CompanyDetailPage extends StatefulWidget {
  final CompanyModel company;
  final String section;
  final bool embedded;

  const CompanyDetailPage({
    super.key,
    required this.company,
    required this.section,
    this.embedded = false,
  });

  @override
  State<CompanyDetailPage> createState() =>
      _CompanyDetailPageState();
}

class _CompanyDetailPageState
    extends State<CompanyDetailPage> {
  String _search = '';
  String _filter = 'All';

  bool _isLoading = true;
  bool _isDeletingCompany = false;

  List<AssetModel> _assets = [];

  static const double companyNameSize = 22;
  static const double assetNameSize = 15;
  static const double normalTextSize = 14;
  static const double smallTextSize = 13;
  static const double chipTextSize = 12;
  static const double dateTextSize = 13;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  // ============================================================
  // LOAD ASSETS
  // ============================================================

  Future<void> _loadAssets() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final rawAssets = await ApiService.getAssets();

      final parsedAssets = <AssetModel>[];
      final now = DateTime.now();

      for (final item in rawAssets) {
        if (item is! Map) {
          continue;
        }

        final data = Map<String, dynamic>.from(item);

        final companyId =
            data['company_id']?.toString() ??
                data['companyId']?.toString() ??
                '';

        final section =
            data['section']?.toString() ?? '';

        if (companyId != widget.company.id) {
          continue;
        }

        if (section != widget.section) {
          continue;
        }

        final id =
            data['id']?.toString() ?? '';

        final companyName =
            data['company_name']?.toString() ??
                data['companyName']?.toString() ??
                widget.company.name;

        final type =
            data['type']?.toString() ?? '';

        final name =
            data['name']?.toString() ?? '';

        final link =
            _nullableString(data['link']);

        final username =
            _nullableString(data['username']);

        final password =
            _nullableString(data['password']);

        final createdAt =
            DateTime.tryParse(
                  data['created_at']?.toString() ??
                      data['createdAt']?.toString() ??
                      '',
                ) ??
                now;

        final updatedAt =
            DateTime.tryParse(
                  data['updated_at']?.toString() ??
                      data['updatedAt']?.toString() ??
                      '',
                ) ??
                createdAt;

        final filePath =
            _nullableString(
          data['file_url'] ??
              data['file_path'] ??
              data['filePath'] ??
              data['file_name'],
        );

        parsedAssets.add(
          AssetModel(
            id: id,
            companyId: companyId,
            companyName: companyName,
            section: section,
            type: type,
            name: name,
            link: link,
            username: username,
            password: password,
            description: _nullableString(data['description']),
            filePath: filePath,
            fileName: _nullableString(data['file_name'] ?? data['fileName']),
            mimeType: _nullableString(data['mime_type'] ?? data['mimeType']),
            fileSize: data['file_size'] is num ? (data['file_size'] as num).toInt() : null,
            createdByEmployeeId: _nullableString(data['created_by_employee_id'] ?? data['createdByEmployeeId']),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
      }

      parsedAssets.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _assets = parsedAssets;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _assets = [];
        _isLoading = false;
      });

      _showMessage(_cleanError(error));
    }
  }

  String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  // ============================================================
  // FILTERED ASSETS
  // ============================================================

  List<AssetModel> get _companyAssets {
    final query = _search.trim().toLowerCase();

    final assets = _assets.where((asset) {
      if (asset.companyId != widget.company.id) {
        return false;
      }

      if (asset.section != widget.section) {
        return false;
      }

      if (_filter != 'All' &&
          asset.type != _filter) {
        return false;
      }

      if (query.isNotEmpty) {
        final matchesName =
            asset.name.toLowerCase().contains(query);

        final matchesType =
            asset.type.toLowerCase().contains(query);

        final matchesCompany =
            asset.companyName.toLowerCase().contains(query);

        final matchesLink =
            asset.link?.toLowerCase().contains(query) ?? false;

        if (!matchesName &&
            !matchesType &&
            !matchesCompany &&
            !matchesLink) {
          return false;
        }
      }

      return true;
    }).toList();

    assets.sort(
      (a, b) => b.updatedAt.compareTo(a.updatedAt),
    );

    return assets;
  }

  // ============================================================
  // FILTERS
  // ============================================================

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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final mobile = width < 650;

    final content = SingleChildScrollView(
      padding: EdgeInsets.all(
        mobile ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildCompanyHeader(),

          const SizedBox(height: 22),

          _buildToolbar(),

          const SizedBox(height: 18),

          _buildAssetContent(),
        ],
      ),
    );

    if (widget.embedded) {
      return Material(
        color: AppColors.background,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Company Assets',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: content,
    );
  }

  // ============================================================
  // COMPANY HEADER
  // ============================================================

  // ============================================================
  // COMPANY LOGO + HEADER
  // ============================================================

  Widget _buildCompanyHeader() {
    final isDigitalMarketing =
        widget.section ==
            AppConstants.digitalMarketing;

    final color = isDigitalMarketing
        ? AppColors.digitalMarketing
        : AppColors.softwareDevelopment;

    final lightColor = isDigitalMarketing
        ? AppColors.digitalMarketingLight
        : AppColors.softwareDevelopmentLight;

    final companyName =
        widget.company.name.trim();

    final firstLetter =
        companyName.isNotEmpty
            ? companyName
                .substring(0, 1)
                .toUpperCase()
            : 'C';

    final logoUrl =
        widget.company.logoUrl?.trim();

    Widget logoFallback() {
      return Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Text(
          firstLetter,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
    }

    Widget companyLogo() {
      if (logoUrl == null || logoUrl.isEmpty) {
        return logoFallback();
      }

      final parsed =
          Uri.tryParse(logoUrl);

      final imageUrl =
          parsed != null &&
                  parsed.hasScheme
              ? logoUrl
              : Uri.parse(
                  ApiService.baseUrl,
                ).replace(
                  path: logoUrl.startsWith('/')
                      ? logoUrl
                      : '/$logoUrl',
                  query: '',
                  fragment: '',
                ).toString();

      return Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        clipBehavior:
            Clip.antiAlias,
        child: Image.network(
          imageUrl,
          width: 62,
          height: 62,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) {
            return logoFallback();
          },
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            companyLogo(),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.company.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize:
                                companyNameSize,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                AppColors.textPrimary,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton(
                        tooltip:
                            'Edit company name',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color:
                              AppColors.primary,
                        ),
                        onPressed:
                            _editCompanyName,
                      ),

                      IconButton(
                        tooltip:
                            'Delete company',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color:
                              AppColors.danger,
                        ),
                        onPressed:
                            _isDeletingCompany
                                ? null
                                : _deleteCompany,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Text(
                        '${_companyAssets.length} assets',
                        style:
                            const TextStyle(
                          fontSize:
                              smallTextSize,
                          color:
                              AppColors
                                  .textSecondary,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Container(
                        width: 4,
                        height: 4,
                        decoration:
                            const BoxDecoration(
                          color:
                              AppColors
                                  .textSecondary,
                          shape:
                              BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Flexible(
                        child: Text(
                          'Last updated: ${_latestDate()}',
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize:
                                smallTextSize,
                            color:
                                AppColors
                                    .textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (MediaQuery.of(context)
                    .size
                    .width >
                650)
              OutlinedButton.icon(
                onPressed: _addAsset,
                icon: const Icon(
                  Icons.add,
                  size: 20,
                ),
                label: const Text(
                  'Add Asset',
                  style: TextStyle(
                    fontSize:
                        normalTextSize,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(
                    color: color,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EDIT COMPANY NAME
  // ============================================================

  Future<void> _editCompanyName() async {
    final controller =
        TextEditingController(
      text: widget.company.name,
    );

    final selectedSections = <String>{
      ...widget.company.allSections.isNotEmpty
          ? widget.company.allSections
          : (widget.company.section != null
              ? [widget.company.section!]
              : []),
    };

    final result =
        await showDialog<Map<String, dynamic>>(
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
                          value: selectedSections.contains(sectionOption),
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
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        decoration:
                            const InputDecoration(
                          labelText: 'Company Name',
                          hintText:
                              'Enter company name',
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            Navigator.pop(dialogContext, {
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
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = controller.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    if (selectedSections.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one section.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'name': name,
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

    controller.dispose();

    final newName = result?['name'] as String?;
    final newSections = result?['sections'] as List<String>?;

    if (newName == null ||
        newName.trim().isEmpty) {
      return;
    }

    try {
      await ApiService.updateCompany(
        companyId: widget.company.id,
        name: newName.trim(),
        sections: newSections,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        widget.company.name =
            newName.trim();
      });

      await _loadAssets();

      if (!mounted) {
        return;
      }

      _showMessage(
        'Company updated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(error),
      );
    }
  }

  // ============================================================
  // DELETE COMPANY
  // ============================================================

  Future<void> _deleteCompany() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Company',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete '
            '"${widget.company.name}" and all of its assets?\n\n'
            'Uploaded files for this company will also be removed '
            'from the server.',
            style: const TextStyle(
              fontSize: normalTextSize,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _isDeletingCompany = true;
    });

    bool progressOpen = false;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Deleting company...',
                  ),
                ),
              ],
            ),
          );
        },
      );

      progressOpen = true;

      await ApiService.deleteCompany(
        widget.company.id,
      );

      if (!mounted) {
        return;
      }

      if (progressOpen) {
        Navigator.of(context).pop();
        progressOpen = false;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Company and all its assets deleted successfully.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (progressOpen) {
        Navigator.of(context).pop();
        progressOpen = false;
      }

      setState(() {
        _isDeletingCompany = false;
      });

      _showMessage(
        'Failed to delete company: ${_cleanError(error)}',
      );
    }
  }

  // ============================================================
  // ADD ASSET
  // ============================================================

  Future<void> _addAsset() async {
    final asset =
        await showAddAssetDialog(
      context,
      companies: [
        widget.company,
      ],
      initialSection:
          widget.section,
    );

    if (asset == null) {
      return;
    }

    await _loadAssets();

    if (!mounted) {
      return;
    }

    _showMessage(
      '${asset.name} added successfully.',
    );
  }

  // ============================================================
  // TOOLBAR
  // ============================================================

  Widget _buildToolbar() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  _search = value;
                });
              },
              decoration:
                  const InputDecoration(
                hintText:
                    'Search assets...',
                prefixIcon:
                    Icon(Icons.search),
              ),
            ),

            const SizedBox(height: 14),

            SingleChildScrollView(
              scrollDirection:
                  Axis.horizontal,
              child: Row(
                children:
                    _filters.map(
                  (filter) {
                    final selected =
                        _filter == filter;

                    return Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        right: 8,
                      ),
                      child: InkWell(
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                        onTap: () {
                          setState(() {
                            _filter =
                                filter;
                          });
                        },
                        child:
                            Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration:
                              BoxDecoration(
                            color: selected
                                ? AppColors
                                    .primary
                                : const Color(
                                    0xFFF5F7FA,
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
                          child:
                              Text(
                            filter,
                            style:
                                TextStyle(
                              fontSize:
                                  chipTextSize,
                              fontWeight:
                                  FontWeight
                                      .w600,
                              color: selected
                                  ? Colors
                                      .white
                                  : AppColors
                                      .textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ASSET CONTENT
  // ============================================================

  Widget _buildAssetContent() {
    if (_isLoading) {
      return Card(
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(
            vertical: 70,
          ),
          child: const Center(
            child:
                CircularProgressIndicator(),
          ),
        ),
      );
    }

    final assets =
        _companyAssets;

    if (assets.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children:
          assets.map((asset) {
        return Padding(
          padding:
              const EdgeInsets.only(
            bottom: 12,
          ),
          child:
              _buildAssetCard(asset),
        );
      }).toList(),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Card(
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          vertical: 65,
          horizontal: 20,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 52,
              color:
                  AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 7),
            Text(
              _search.trim().isNotEmpty ||
                      _filter != 'All'
                  ? 'No assets match the current search or filter.'
                  : 'Add an asset to this company to see it here.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize:
                    normalTextSize,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),
            if (_search.trim().isEmpty &&
                _filter == 'All') ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _addAsset,
                icon: const Icon(
                  Icons.add,
                ),
                label: const Text(
                  'Add Asset',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ASSET CARD
  // ============================================================

  Widget _buildAssetCard(
    AssetModel asset,
  ) {
    final hasFile =
        asset.filePath != null &&
            asset.filePath!
                .trim()
                .isNotEmpty;

    final hasLink =
        asset.link != null &&
            asset.link!
                .trim()
                .isNotEmpty;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF0F5FF,
                ),
                borderRadius:
                    BorderRadius.circular(
                  10,
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

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize:
                          assetNameSize,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          AppColors
                              .textPrimary,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    crossAxisAlignment:
                        WrapCrossAlignment
                            .center,
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
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                        child: Text(
                          asset.type,
                          style:
                              const TextStyle(
                            fontSize:
                                chipTextSize,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                AppColors
                                    .primary,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(
                          asset.updatedAt,
                        ),
                        style:
                            const TextStyle(
                          fontSize:
                              dateTextSize,
                          color:
                              AppColors
                                  .textSecondary,
                        ),
                      ),
                    ],
                  ),

                  if (hasLink)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        top: 6,
                      ),
                      child:
                          InkWell(
                        onTap: () =>
                            _openLink(
                          asset.link!,
                        ),
                        child: Text(
                          asset.link!,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize:
                                smallTextSize,
                            color:
                                AppColors
                                    .primary,
                            decoration:
                                TextDecoration
                                    .underline,
                          ),
                        ),
                      ),
                    ),

                  if (asset.username !=
                          null &&
                      asset.username!
                          .trim()
                          .isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        top: 5,
                      ),
                      child: Text(
                        'Username: ${asset.username}',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize:
                              smallTextSize,
                          color:
                              AppColors
                                  .textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 5),

            _actionButton(
              tooltip: 'View',
              icon:
                  Icons.visibility_outlined,
              onPressed: () =>
                  _viewAsset(asset),
            ),

            _actionButton(
              tooltip: 'Edit',
              icon:
                  Icons.edit_outlined,
              onPressed: () =>
                  _editAsset(asset),
            ),

            if (hasFile)
              _actionButton(
                tooltip: 'Download',
                icon:
                    Icons.download_outlined,
                onPressed: () =>
                    _downloadAsset(asset),
              ),

            if (hasLink)
              _actionButton(
                tooltip: 'Open Link',
                icon:
                    Icons.open_in_new_outlined,
                onPressed: () =>
                    _openLink(
                  asset.link!,
                ),
              ),

            _actionButton(
              tooltip: 'Delete',
              icon:
                  Icons.delete_outline,
              color:
                  AppColors.danger,
              onPressed: () =>
                  _deleteAsset(asset),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 20,
        color:
            color ??
                AppColors
                    .textSecondary,
      ),
    );
  }

  // ============================================================
  // VIEW ASSET
  // ============================================================

  void _viewAsset(
    AssetModel asset,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            asset.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 560,
            child:
                SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  _detailRow(
                    'Company',
                    asset.companyName,
                  ),
                  _detailRow(
                    'Type',
                    asset.type,
                  ),

                  if (asset.username != null &&
                      asset.username!
                          .trim()
                          .isNotEmpty)
                    _detailRow(
                      'Username',
                      asset.username!,
                    ),

                  if (asset.password != null &&
                      asset.password!
                          .trim()
                          .isNotEmpty)
                    _detailRow(
                      'Password',
                      asset.password!,
                    ),

                  _detailRow(
                    'Created',
                    _formatDate(
                      asset.createdAt,
                    ),
                  ),

                  _detailRow(
                    'Updated',
                    _formatDate(
                      asset.updatedAt,
                    ),
                  ),

                  if (asset.filePath != null &&
                      asset.filePath!
                          .trim()
                          .isNotEmpty)
                    _detailFileRow(
                      asset,
                    ),

                  if (asset.link != null &&
                      asset.link!
                          .trim()
                          .isNotEmpty)
                    _detailLinkRow(
                      asset.link!,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (asset.link != null &&
                asset.link!
                    .trim()
                    .isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  _openLink(
                    asset.link!,
                  );
                },
                icon:
                    const Icon(
                  Icons.open_in_new,
                ),
                label:
                    const Text(
                  'Open Link',
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 13,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize:
                    normalTextSize,
                fontWeight:
                    FontWeight.w700,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style:
                  const TextStyle(
                fontSize:
                    normalTextSize,
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

  Widget _detailFileRow(
    AssetModel asset,
  ) {
    final value = asset.filePath?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 13,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 95,
            child: Text(
              'File',
              style: TextStyle(
                fontSize:
                    normalTextSize,
                fontWeight:
                    FontWeight.w700,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _openFileInNewTab(
                asset,
              ),
              child: Text(
                value,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize:
                      normalTextSize,
                  color:
                      AppColors.primary,
                  decoration:
                      TextDecoration
                          .underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFileInNewTab(
    AssetModel asset,
  ) async {
    try {
      _showMessage(
        'Opening file...',
      );

      final Uint8List bytes =
          await ApiService.downloadAsset(
        asset.id,
      );

      if (!mounted) {
        return;
      }

      if (bytes.isEmpty) {
        _showMessage(
          'The file is empty.',
        );
        return;
      }

      final fileName =
          _getDownloadFileName(asset);

      final success = await downloadFileBytes(
        bytes,
        fileName,
        _mimeTypeForFile(fileName),
      );

      if (!success && mounted) {
        _showMessage(
          'Unable to download the file.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to open the file: ${_cleanError(error)}',
      );
    }
  }

  Widget _detailLinkRow(
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 95,
            child: Text(
              'Link',
              style: TextStyle(
                fontSize:
                    normalTextSize,
                fontWeight:
                    FontWeight.w700,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () =>
                  _openLink(value),
              child: Text(
                value,
                style:
                    const TextStyle(
                  fontSize:
                      normalTextSize,
                  color:
                      AppColors.primary,
                  decoration:
                      TextDecoration
                          .underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT ASSET
  // ============================================================

  Future<void> _editAsset(
    AssetModel asset,
  ) async {
    final updatedAsset =
        await showEditAssetDialog(
      context,
      asset: asset,
    );

    if (updatedAsset == null) {
      return;
    }

    try {
      await ApiService.updateAsset(
        assetId: asset.id,
        companyId: updatedAsset.companyId,
        companyName: updatedAsset.companyName,
        section: updatedAsset.section,
        type: updatedAsset.type,
        name: updatedAsset.name,
        description: updatedAsset.description,
        link: updatedAsset.link,
        username: updatedAsset.username,
        password: updatedAsset.password,
        fileName: updatedAsset.pendingFileBytes != null ? updatedAsset.fileName : null,
        fileBytes: updatedAsset.pendingFileBytes != null
            ? Uint8List.fromList(updatedAsset.pendingFileBytes!)
            : null,
      );

      await _loadAssets();

      if (!mounted) {
        return;
      }

      _showMessage(
        'Asset updated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Update failed: ${_cleanError(error)}',
      );
    }
  }

  // ============================================================
  // DELETE ASSET
  // ============================================================

  Future<void> _deleteAsset(
    AssetModel asset,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Asset',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete '
            '"${asset.name}"?\n\n'
            'The asset record and uploaded file '
            'will be permanently deleted.',
            style: const TextStyle(
              fontSize:
                  normalTextSize,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    bool progressOpen = false;

    try {
      if (!mounted) {
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Deleting asset...',
                  ),
                ),
              ],
            ),
          );
        },
      );

      progressOpen = true;

      await ApiService.deleteAsset(
        asset.id,
      );

      await _loadAssets();

      if (!mounted) {
        return;
      }

      if (progressOpen) {
        Navigator.of(context).pop();
        progressOpen = false;
      }

      _showMessage(
        'Asset deleted successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (progressOpen) {
        Navigator.of(context).pop();
        progressOpen = false;
      }

      _showMessage(
        'Delete failed: ${_cleanError(error)}',
      );
    }
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

    if (!cleanLink.startsWith('http://') &&
        !cleanLink.startsWith('https://')) {
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

    try {
      final success =
          await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );

      if (!success &&
          mounted) {
        _showMessage(
          'Unable to open the link.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to open the link.',
      );
    }
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  Future<void> _downloadAsset(
    AssetModel asset,
  ) async {
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

      final Uint8List bytes =
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
        'Download failed: ${_cleanError(error)}',
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

      if (parts.isNotEmpty) {
        final last =
            parts.last.trim();

        if (last.isNotEmpty &&
            last.contains('.')) {
          return last;
        }
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

      case AppConstants.webApplication:
        return '$name.html';

      default:
        return '$name.file';
    }
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

    if (lower.endsWith('.mov')) {
      return 'video/quicktime';
    }

    if (lower.endsWith('.avi')) {
      return 'video/x-msvideo';
    }

    if (lower.endsWith('.mkv')) {
      return 'video/x-matroska';
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

    if (lower.endsWith('.ppt')) {
      return 'application/vnd.ms-powerpoint';
    }

    if (lower.endsWith('.pptx')) {
      return
          'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }

    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }

    if (lower.endsWith('.apk')) {
      return
          'application/vnd.android.package-archive';
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

    if (lower.endsWith('.html') ||
        lower.endsWith('.htm')) {
      return 'text/html';
    }

    return 'application/octet-stream';
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
        'No link is available for this asset.',
      );
      return;
    }

    await _openLink(link);
  }

  // ============================================================
  // ASSET ICON
  // ============================================================

  IconData _getAssetIcon(
    String type,
  ) {
    switch (type) {
      case AppConstants.poster:
        return Icons.image_outlined;

      case AppConstants.reelVideo:
        return Icons.video_library_outlined;

      case AppConstants.document:
        return Icons.description_outlined;

      case AppConstants.websiteLink:
        return Icons.link_outlined;

      case AppConstants.webApplication:
        return Icons.language_outlined;

      case AppConstants.mobileApplication:
        return Icons.phone_android_outlined;

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
        date.day.toString().padLeft(
              2,
              '0',
            );

    final month =
        date.month.toString().padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }

  String _latestDate() {
    if (_assets.isEmpty) {
      return _formatDate(
        widget.company.updatedAt,
      );
    }

    final sorted =
        List<AssetModel>.from(
      _assets,
    );

    sorted.sort(
      (a, b) =>
          b.updatedAt.compareTo(
        a.updatedAt,
      ),
    );

    return _formatDate(
      sorted.first.updatedAt,
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:
              const TextStyle(
            fontSize:
                normalTextSize,
          ),
        ),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }
}