import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/asset_model.dart';

Future<AssetModel?> showEditAssetDialog(
  BuildContext context, {
  required AssetModel asset,
}) {
  return showDialog<AssetModel>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _EditAssetDialog(asset: asset);
    },
  );
}

class _EditAssetDialog extends StatefulWidget {
  final AssetModel asset;

  const _EditAssetDialog({
    required this.asset,
  });

  @override
  State<_EditAssetDialog> createState() => _EditAssetDialogState();
}

class _EditAssetDialogState extends State<_EditAssetDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _linkController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  String? _selectedFileName;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.asset.name,
    );

    _linkController = TextEditingController(
      text: widget.asset.link ?? '',
    );

    _usernameController = TextEditingController(
      text: widget.asset.username ?? '',
    );

    _passwordController = TextEditingController(
      text: widget.asset.password ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _linkController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? files;

    if (widget.asset.type == AppConstants.poster) {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'pdf',
        ],
      );
    } else if (widget.asset.type == AppConstants.reelVideo) {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4',
          'mov',
          'avi',
          'mkv',
        ],
      );
    } else if (widget.asset.type == AppConstants.document) {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
        ],
      );
    } else if (widget.asset.type == AppConstants.mobileApplication) {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'apk',
        ],
      );
    } else {
      files = await FilePicker.pickFiles(
        type: FileType.any,
      );
    }

    final selectedFiles = files?.files;
    if (selectedFiles == null || selectedFiles.isEmpty) {
      return;
    }

    setState(() {
      _selectedFileName = selectedFiles.first.name;
    });
  }

  bool get _needsFileUpload {
    return widget.asset.type == AppConstants.poster ||
        widget.asset.type == AppConstants.reelVideo ||
        widget.asset.type == AppConstants.document ||
        widget.asset.type == AppConstants.mobileApplication;
  }

  bool get _needsCredentials {
    return widget.asset.type == AppConstants.webApplication ||
        widget.asset.type == AppConstants.mobileApplication;
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 720,
          maxHeight: 850,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------------------
              // HEADER
              // ------------------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit ${asset.type} Asset',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              const Text(
                'Update the asset details below.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // ------------------------------------------------------------
              // CURRENT COMPANY
              // ------------------------------------------------------------
              const Text(
                'Company',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Text(
                  asset.companyName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------------------
              // ASSET TYPE
              // ------------------------------------------------------------
              const Text(
                'Asset Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Text(
                  asset.type,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------------------
              // NAME
              // ------------------------------------------------------------
              _buildLabel('Name'),

              const SizedBox(height: 8),

              TextField(
                controller: _nameController,
                style: const TextStyle(
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter asset name',
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------------------
              // LINK
              // ------------------------------------------------------------
              if (asset.type != AppConstants.others) ...[
                _buildLabel(
                  asset.type == AppConstants.websiteLink ||
                          asset.type == AppConstants.webApplication
                      ? 'Website Link'
                      : 'Link',
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _linkController,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter link',
                  ),
                ),

                const SizedBox(height: 20),
              ],

              // ------------------------------------------------------------
              // CREDENTIALS
              // ------------------------------------------------------------
              if (_needsCredentials) ...[
                _buildLabel('Username / ID'),

                const SizedBox(height: 8),

                TextField(
                  controller: _usernameController,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter username or ID',
                  ),
                ),

                const SizedBox(height: 20),

                _buildLabel('Password'),

                const SizedBox(height: 8),

                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],

              // ------------------------------------------------------------
              // FILE UPLOAD
              // ------------------------------------------------------------
              if (_needsFileUpload) ...[
                _buildLabel(
                  asset.type == AppConstants.mobileApplication
                      ? 'APK File'
                      : 'Replace File',
                ),

                const SizedBox(height: 8),

                InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            color: AppColors.primary,
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFileName ??
                                    'Choose a new file',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedFileName == null
                                    ? 'Click to select a file'
                                    : 'New file selected',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          Icons.attach_file,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                if (asset.filePath != null &&
                    asset.filePath!.isNotEmpty)
                  Text(
                    'Current file: ${asset.filePath}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),

                const SizedBox(height: 20),
              ],

              // ------------------------------------------------------------
              // BUTTONS
              // ------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  ElevatedButton(
                    onPressed: _save,
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  void _save() {
    final updatedAsset = AssetModel(
      id: widget.asset.id,
      companyId: widget.asset.companyId,
      companyName: widget.asset.companyName,
      section: widget.asset.section,
      type: widget.asset.type,
      name: _nameController.text.trim(),
      link: _linkController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      createdAt: widget.asset.createdAt,
      updatedAt: DateTime.now(),
      filePath: _selectedFileName ?? widget.asset.filePath,
    );

    Navigator.pop(
      context,
      updatedAsset,
    );
  }
}
