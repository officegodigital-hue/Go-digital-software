import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/asset_model.dart';
import '../../models/company_model.dart';
import '../../services/api_service.dart';

Future<AssetModel?> showAddAssetDialog(
  BuildContext context, {
  required List<CompanyModel> companies,
  required String initialSection,
}) {
  return showDialog<AssetModel>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _AddAssetDialog(
        companies: companies,
        initialSection: initialSection,
      );
    },
  );
}

class _AddAssetDialog extends StatefulWidget {
  final List<CompanyModel> companies;
  final String initialSection;

  const _AddAssetDialog({
    required this.companies,
    required this.initialSection,
  });

  @override
  State<_AddAssetDialog> createState() => _AddAssetDialogState();
}

class _AddAssetDialogState extends State<_AddAssetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------------
  // CONTROLLERS
  // ---------------------------------------------------------------------------

  final TextEditingController _fileNameController =
      TextEditingController();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _linkController =
      TextEditingController();

  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _contentController =
      TextEditingController();

  late String _section;
  late String _selectedType;

  String? _selectedFileName;
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;

  bool _isSaving = false;

  // ---------------------------------------------------------------------------
  // INIT / DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _section = widget.initialSection;

    if (_section == AppConstants.digitalMarketing) {
      _selectedType = AppConstants.poster;
    } else {
      _selectedType = AppConstants.webApplication;
    }
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _nameController.dispose();
    _linkController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _contentController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // COMPANY
  // ---------------------------------------------------------------------------

  CompanyModel? get _company {
    if (widget.companies.isEmpty) {
      return null;
    }

    // Company is automatically selected from the company detail page.
    return widget.companies.first;
  }

  // ---------------------------------------------------------------------------
  // ASSET TYPES
  // ---------------------------------------------------------------------------

  List<String> get _types {
    if (_section == AppConstants.digitalMarketing) {
      return const [
        AppConstants.poster,
        AppConstants.reelVideo,
        AppConstants.document,
        AppConstants.websiteLink,
        AppConstants.others,
      ];
    }

    return const [
      AppConstants.webApplication,
      AppConstants.mobileApplication,
      AppConstants.others,
    ];
  }

  String _typeDescription(String type) {
    switch (type) {
      case AppConstants.poster:
        return 'Add marketing posters';

      case AppConstants.reelVideo:
        return 'Add reels or videos';

      case AppConstants.document:
        return 'Add documents';

      case AppConstants.websiteLink:
        return 'Add website links';

      case AppConstants.webApplication:
        return 'Add web applications';

      case AppConstants.mobileApplication:
        return 'Add mobile applications';

      case AppConstants.others:
        return 'Add other assets';

      default:
        return 'Add asset';
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final dialogWidth =
        screenWidth >= 900 ? 760.0 : screenWidth * 0.94;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: screenHeight * 0.94,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              16,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(),
                  const SizedBox(height: 15),
                  _buildStepOne(),
                  const SizedBox(height: 16),
                  _buildStepTwo(),
                  const SizedBox(height: 18),
                  _buildButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TITLE
  // ---------------------------------------------------------------------------

  Widget _buildTitle() {
    String title;

    if (_section == AppConstants.digitalMarketing) {
      switch (_selectedType) {
        case AppConstants.poster:
          title = 'Add Poster Asset';
          break;

        case AppConstants.reelVideo:
          title = 'Add Reel / Video Asset';
          break;

        case AppConstants.document:
          title = 'Add Document Asset';
          break;

        case AppConstants.websiteLink:
          title = 'Add Website Link Asset';
          break;

        case AppConstants.others:
          title = 'Add Others Asset';
          break;

        default:
          title = 'Add Digital Marketing Asset';
      }
    } else {
      switch (_selectedType) {
        case AppConstants.webApplication:
          title = 'Add Web Application Asset';
          break;

        case AppConstants.mobileApplication:
          title = 'Add Mobile Application Asset';
          break;

        case AppConstants.others:
          title = 'Add Others Asset';
          break;

        default:
          title = 'Add Software Development Asset';
      }
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          icon: const Icon(
            Icons.close,
            size: 22,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP ONE
  // ---------------------------------------------------------------------------

  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          number: '1',
          title: 'Select Asset Type',
        ),
        const SizedBox(height: 10),
        _buildTypeCards(),
      ],
    );
  }

  Widget _buildStepHeader({
    required String number,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TYPE CARDS
  // ---------------------------------------------------------------------------

  Widget _buildTypeCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _types.map((type) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 145,
              child: _buildTypeCard(type),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypeCard(String type) {
    final selected = _selectedType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isSaving
          ? null
          : () {
              setState(() {
                _selectedType = type;

                _selectedFileName = null;
                _selectedFilePath = null;
                _selectedFileBytes = null;

                _fileNameController.clear();
                _nameController.clear();
                _linkController.clear();
                _contentController.clear();
                _usernameController.clear();
                _passwordController.clear();
              });
            },
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF4F8FF)
              : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _typeIcon(type),
              size: 28,
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              type,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Text(
                _typeDescription(type),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP TWO
  // ---------------------------------------------------------------------------

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          number: '2',
          title: 'Asset Details',
        ),
        const SizedBox(height: 12),
        _buildSelectedCompany(),
        const SizedBox(height: 14),
        _buildAssetDetails(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // COMPANY
  // ---------------------------------------------------------------------------

  Widget _buildSelectedCompany() {
    final company = _company;

    if (company == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.danger,
          ),
        ),
        child: const Text(
          'No company selected.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.danger,
          ),
        ),
      );
    }

    final isDigitalMarketing =
        _section == AppConstants.digitalMarketing;

    final sectionColor = isDigitalMarketing
        ? AppColors.digitalMarketing
        : AppColors.softwareDevelopment;

    final sectionLightColor = isDigitalMarketing
        ? AppColors.digitalMarketingLight
        : AppColors.softwareDevelopmentLight;

    final trimmedName = company.name.trim();

    final firstLetter = trimmedName.isNotEmpty
        ? trimmedName.substring(0, 1).toUpperCase()
        : 'C';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: sectionLightColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sectionColor.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  firstLetter,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: sectionColor,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _section,
                      style: TextStyle(
                        fontSize: 12,
                        color: sectionColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ASSET DETAILS SWITCH
  // ---------------------------------------------------------------------------

  Widget _buildAssetDetails() {
    if (_section == AppConstants.digitalMarketing) {
      switch (_selectedType) {
        case AppConstants.poster:
          return _buildPosterDetails();

        case AppConstants.reelVideo:
          return _buildVideoDetails();

        case AppConstants.document:
          return _buildDocumentDetails();

        case AppConstants.websiteLink:
          return _buildWebsiteDetails();

        case AppConstants.others:
          return _buildOthersDetails();
      }
    }

    switch (_selectedType) {
      case AppConstants.webApplication:
        return _buildWebApplicationDetails();

      case AppConstants.mobileApplication:
        return _buildMobileApplicationDetails();

      case AppConstants.others:
        return _buildOthersDetails();
    }

    return const SizedBox();
  }

  // ---------------------------------------------------------------------------
  // FILE NAME
  // ---------------------------------------------------------------------------

  Widget _buildFileNameField() {
    return _buildTextField(
      label: 'File Name *',
      controller: _fileNameController,
      hint: 'Enter file/asset name',
    );
  }

  // ---------------------------------------------------------------------------
  // LINK FIELD
  // ---------------------------------------------------------------------------

  Widget _buildLinkField() {
    return _buildTextField(
      label: 'Link (Optional)',
      controller: _linkController,
      hint: 'https://',
    );
  }

  // ---------------------------------------------------------------------------
  // POSTER
  // ---------------------------------------------------------------------------

  Widget _buildPosterDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFileNameField(),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Link *',
          controller: _linkController,
          hint: 'https://',
        ),
        const SizedBox(height: 14),

        _fieldLabel('Poster File (Optional)'),
        const SizedBox(height: 7),

        _buildUploadBox(
          extensions: const [
            'png',
            'pdf',
          ],
          helper: 'PNG, PDF (Optional, Max 50MB)',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // VIDEO
  // ---------------------------------------------------------------------------

  Widget _buildVideoDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFileNameField(),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Link *',
          controller: _linkController,
          hint: 'https://',
        ),
        const SizedBox(height: 14),

        _fieldLabel('Video File (Optional)'),
        const SizedBox(height: 7),

        _buildUploadBox(
          extensions: const [
            'mp4',
            'mov',
          ],
          helper: 'MP4, MOV (Optional, Max 200MB)',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DOCUMENT
  // ---------------------------------------------------------------------------

  Widget _buildDocumentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFileNameField(),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Link *',
          controller: _linkController,
          hint: 'https://',
        ),
        const SizedBox(height: 14),

        _fieldLabel('Document File (Optional)'),
        const SizedBox(height: 7),

        _buildUploadBox(
          extensions: const [
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
          ],
          helper:
              'PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX (Optional, Max 50MB)',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WEBSITE LINK
  // ---------------------------------------------------------------------------

  Widget _buildWebsiteDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFileNameField(),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Website Link *',
          controller: _linkController,
          hint: 'https://',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // OTHERS
  // ---------------------------------------------------------------------------

  Widget _buildOthersDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFileNameField(),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Field Name *',
          controller: _nameController,
          hint:
              'Enter name (e.g. Notes, Credentials, Design File)',
        ),
        const SizedBox(height: 14),

        _fieldLabel('Content *'),
        const SizedBox(height: 7),

        _buildOthersContentBox(),
      ],
    );
  }

  Widget _buildOthersContentBox() {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isSaving ? null : _pickOthersFile,
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBFE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    AppColors.primary.withValues(alpha: 0.40),
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedFileName ??
                      'Click to upload or enter content',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Upload file, paste a link or enter text below',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _contentController,
          minLines: 2,
          maxLines: 4,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            hintText: 'Enter text or paste a link',
            hintStyle: TextStyle(
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // WEB APPLICATION
  // ---------------------------------------------------------------------------

  Widget _buildWebApplicationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFileNameField(),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Application Name *',
          controller: _nameController,
          hint: 'Website / Application name',
        ),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Website Link',
          controller: _linkController,
          hint: 'https://',
        ),
        const SizedBox(height: 14),

        _buildCredentials(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE APPLICATION
  // ---------------------------------------------------------------------------

  Widget _buildMobileApplicationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFileNameField(),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Application Name *',
          controller: _nameController,
          hint: 'Mobile Application name',
        ),
        const SizedBox(height: 14),

        _buildTextField(
          label: 'Play Store / APK Link',
          controller: _linkController,
          hint: 'https://',
        ),
        const SizedBox(height: 14),

        _buildCredentials(),
        const SizedBox(height: 14),

        _fieldLabel('APK File (Optional)'),
        const SizedBox(height: 7),

        _buildUploadBox(
          extensions: const [
            'apk',
          ],
          helper: 'APK file (Max 200MB)',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CREDENTIALS
  // ---------------------------------------------------------------------------

  Widget _buildCredentials() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildTextField(
                label: 'ID / Username',
                controller: _usernameController,
                hint: 'Username',
              ),
              const SizedBox(height: 14),
              _buildPasswordField(),
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                label: 'ID / Username',
                controller: _usernameController,
                hint: 'Username',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildPasswordField(),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TEXT FIELD
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PASSWORD
  // ---------------------------------------------------------------------------

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Password'),
        const SizedBox(height: 7),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            hintText: 'Password',
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FIELD LABEL
  // ---------------------------------------------------------------------------

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UPLOAD BOX
  // ---------------------------------------------------------------------------

  Widget _buildUploadBox({
    required List<String> extensions,
    required String helper,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isSaving
          ? null
          : () {
              _pickFile(extensions);
            },
      child: Container(
        height: 105,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBFE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                AppColors.primary.withValues(alpha: 0.40),
          ),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.primary,
                size: 21,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              child: Text(
                _selectedFileName ??
                    'Click to upload or drag and drop',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              helper,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILE PICKER
  // ---------------------------------------------------------------------------

  Future<void> _pickFile(
    List<String> extensions,
  ) async {
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      final file = selection?.files.singleOrNull;
      if (file == null) {
        return;
      }

      final fileExtension = file.extension?.toLowerCase() ?? '';
      final allowed = extensions
          .map((extension) => extension.toLowerCase())
          .contains(fileExtension);

      if (!allowed) {
        if (!mounted) {
          return;
        }

        _showMessage(
          'Please select a supported file: ${extensions.join(', ').toUpperCase()}.',
        );
        return;
      }

      final bytes = file.bytes;
      if (bytes == null) {
        _showMessage('Unable to read the selected file.');
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _selectedFilePath = file.path;
        _selectedFileBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to select file: $error',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // OTHERS FILE PICKER
  // ---------------------------------------------------------------------------

  Future<void> _pickOthersFile() async {
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      final file = selection?.files.singleOrNull;
      if (file == null) {
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        _showMessage('Unable to read the selected file.');
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _selectedFilePath = file.path;
        _selectedFileBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to select file: $error',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUTTONS
  // ---------------------------------------------------------------------------

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _buttonText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BUTTON TEXT
  // ---------------------------------------------------------------------------

  String get _buttonText {
    switch (_selectedType) {
      case AppConstants.poster:
        return 'Add Poster';

      case AppConstants.reelVideo:
        return 'Add Video';

      case AppConstants.document:
        return 'Add Document';

      case AppConstants.websiteLink:
        return 'Add Link';

      case AppConstants.webApplication:
        return 'Add Web Application';

      case AppConstants.mobileApplication:
        return 'Add Mobile Application';

      default:
        return 'Add Asset';
    }
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final company = _company;

    if (company == null) {
      _showMessage(
        'No company selected.',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // FILE NAME VALIDATION
    // -------------------------------------------------------------------------

    final fileNameText =
        _fileNameController.text.trim();

    if (fileNameText.isEmpty) {
      _showMessage(
        'Please enter the file name.',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // REEL / VIDEO + DOCUMENT LINK VALIDATION
    // -------------------------------------------------------------------------

    if ((_selectedType == AppConstants.reelVideo ||
            _selectedType == AppConstants.document) &&
        _linkController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the link.',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // POSTER LINK VALIDATION
    // -------------------------------------------------------------------------

    if (_selectedType == AppConstants.poster &&
        _linkController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the poster link.',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // WEBSITE LINK VALIDATION
    // -------------------------------------------------------------------------

    if (_selectedType ==
            AppConstants.websiteLink &&
        _linkController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the website link.',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // WEB APPLICATION VALIDATION
    // -------------------------------------------------------------------------

    if (_selectedType ==
            AppConstants.webApplication &&
        _nameController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the application name.',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // MOBILE APPLICATION VALIDATION
    // -------------------------------------------------------------------------

    if (_selectedType ==
            AppConstants.mobileApplication &&
        _nameController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the application name.',
      );
      return;
    }

    if (_selectedType ==
            AppConstants.mobileApplication &&
        _linkController.text.trim().isEmpty &&
        _selectedFileName == null) {
      _showMessage(
        'Please enter a Play Store / APK link '
        'or upload an APK file.',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // OTHERS VALIDATION
    // -------------------------------------------------------------------------

    if (_selectedType == AppConstants.others &&
        _nameController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the field name.',
      );
      return;
    }

    // -------------------------------------------------------------------------
    // ASSET NAME
    // -------------------------------------------------------------------------
    //
    // IMPORTANT:
    // The user-entered File Name is now the asset's name.
    // It is NOT replaced by the physical uploaded filename.
    // -------------------------------------------------------------------------

    final String name = fileNameText;

    // -------------------------------------------------------------------------
    // LINK / CONTENT
    // -------------------------------------------------------------------------

    String? link;

    if (_selectedType == AppConstants.others) {
      final content =
          _contentController.text.trim();

      if (content.isNotEmpty) {
        link = content;
      }
    } else {
      final value =
          _linkController.text.trim();

      if (value.isNotEmpty) {
        link = value;
      }
    }

    // -------------------------------------------------------------------------
    // START API REQUEST
    // -------------------------------------------------------------------------

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response =
          await ApiService.createAsset(
        companyId: company.id,
        companyName: company.name,
        section: _section,
        type: _selectedType,
        name: name,
        description:
            _contentController.text.trim().isEmpty
                ? null
                : _contentController.text.trim(),
        link: link,
        username:
            _usernameController.text.trim().isEmpty
                ? null
                : _usernameController.text.trim(),
        password:
            _passwordController.text.trim().isEmpty
                ? null
                : _passwordController.text.trim(),
        fileName: _selectedFileName,
        fileBytes: _selectedFileBytes,
      );

      final asset =
          _assetFromApiResponse(response);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(asset);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        _cleanErrorMessage(error),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // API RESPONSE -> ASSET MODEL
  // ---------------------------------------------------------------------------

  AssetModel _assetFromApiResponse(
    Map<String, dynamic> data,
  ) {
    final now = DateTime.now();

    final id =
        data['id']?.toString() ??
        now.microsecondsSinceEpoch.toString();

    final companyId =
        data['company_id']?.toString() ??
        _company?.id ??
        '';

    final companyName =
        data['company_name']?.toString() ??
        _company?.name ??
        '';

    final section =
        data['section']?.toString() ??
        _section;

    final type =
        data['type']?.toString() ??
        _selectedType;

    final name =
        data['name']?.toString() ??
        _fileNameController.text.trim();

    final linkValue = data['link'];

    final usernameValue = data['username'];

    final passwordValue = data['password'];

    final fileUrlValue = data['file_url'];

    final fileNameValue = data['file_name'];

    final createdAt = _parseDate(
      data['created_at'],
      now,
    );

    final updatedAt = _parseDate(
      data['updated_at'],
      now,
    );

    String? filePath;

    if (fileUrlValue != null &&
        fileUrlValue.toString().trim().isNotEmpty) {
      filePath = fileUrlValue.toString();
    } else if (fileNameValue != null &&
        fileNameValue.toString().trim().isNotEmpty) {
      filePath = fileNameValue.toString();
    } else {
      filePath =
          _selectedFilePath ??
          _selectedFileName;
    }

    return AssetModel(
      id: id,
      companyId: companyId,
      companyName: companyName,
      section: section,
      type: type,
      name: name,
      link: _nullableString(linkValue),
      username: _nullableString(usernameValue),
      password: _nullableString(passwordValue),
      createdAt: createdAt,
      updatedAt: updatedAt,
      filePath: filePath,
    );
  }

  // ---------------------------------------------------------------------------
  // DATE
  // ---------------------------------------------------------------------------

  DateTime _parseDate(
    dynamic value,
    DateTime fallback,
  ) {
    if (value == null) {
      return fallback;
    }

    final parsed =
        DateTime.tryParse(value.toString());

    return parsed ?? fallback;
  }

  // ---------------------------------------------------------------------------
  // NULLABLE STRING
  // ---------------------------------------------------------------------------

  String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  // ---------------------------------------------------------------------------
  // ERROR MESSAGE
  // ---------------------------------------------------------------------------

  String _cleanErrorMessage(
    Object error,
  ) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ---------------------------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------------------------

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ICONS
  // ---------------------------------------------------------------------------

  IconData _typeIcon(
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
        return Icons.insert_drive_file_outlined;
    }
  }
}
