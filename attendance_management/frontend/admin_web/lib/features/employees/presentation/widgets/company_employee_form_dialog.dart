import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_text_styles.dart';
import '../../data/models/company_employee.dart';
import '../controllers/company_employee_controller.dart';

Future<CompanyEmployee?> showCompanyEmployeeFormDialog({
  required BuildContext context,
  required CompanyEmployeeController controller,
  CompanyEmployee? employee,
}) {
  return showDialog<CompanyEmployee>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return CompanyEmployeeFormDialog(
        controller: controller,
        employee: employee,
      );
    },
  );
}

class CompanyEmployeeFormDialog extends StatefulWidget {
  const CompanyEmployeeFormDialog({
    required this.controller,
    this.employee,
    super.key,
  });

  final CompanyEmployeeController controller;
  final CompanyEmployee? employee;

  bool get isEditing => employee != null;

  @override
  State<CompanyEmployeeFormDialog> createState() {
    return _CompanyEmployeeFormDialogState();
  }
}

class _CompanyEmployeeFormDialogState extends State<CompanyEmployeeFormDialog> {
  static const int _maximumProfileImageBytes = 5 * 1024 * 1024;

  static const Set<String> _allowedImageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'avif',
  };

static const List<String> _employeeRoles = <String>[
  'UI/UX Designer',
  'Graphic Designer',
  'Digital Marketing',
  'Video Editor',
  'Web Developer',
  'Page Handler',
  'Ads Handler',
  'Video Grapher',
  'Web Designer',
  'Intern',
  'Manager',
];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _employeeCodeController;

  late final TextEditingController _fullNameController;

  late final TextEditingController _emailController;

  late final TextEditingController _phoneController;

  late final TextEditingController _roleController;

  late final TextEditingController _usernameController;

  late final TextEditingController _passwordController;

  late final TextEditingController _joiningDateController;

  DateTime? _dateOfJoining;

  Uint8List? _selectedProfileImageBytes;
  String? _selectedProfileImageName;
  String _profileImageUrl = '';

  bool _isDraggingProfileImage = false;

  bool _isActive = true;
  bool _isLoginEnabled = true;
  bool _mustChangePassword = true;
  bool _obscurePassword = true;

  String? _formError;
  String? _profileImageError;

  bool get _isEditing => widget.isEditing;

  bool get _isSaving => widget.controller.isSaving;

  bool get _isUploadingProfileImage {
    return widget.controller.isUploadingProfileImage;
  }

  bool get _isBusy {
    return _isSaving || _isUploadingProfileImage;
  }

  @override
  void initState() {
    super.initState();

    final CompanyEmployeeFormData initialData = widget.employee == null
        ? CompanyEmployeeFormData.empty()
        : CompanyEmployeeFormData.fromEmployee(widget.employee!);

    _employeeCodeController = TextEditingController(
      text: initialData.employeeCode,
    );

    _fullNameController = TextEditingController(text: initialData.fullName);

    _emailController = TextEditingController(text: initialData.email);

    _phoneController = TextEditingController(text: initialData.phone);

    _roleController = TextEditingController(text: initialData.role);

    _usernameController = TextEditingController(text: initialData.username);

    _passwordController = TextEditingController(
      text: initialData.temporaryPassword,
    );

    _profileImageUrl = initialData.profileImageUrl.trim();

    _dateOfJoining = initialData.dateOfJoining;

    _joiningDateController = TextEditingController(
      text: _formatDate(_dateOfJoining),
    );

    _isActive = initialData.isActive;
    _isLoginEnabled = initialData.isLoginEnabled;

    _mustChangePassword = initialData.mustChangePassword;

    if (!_isActive) {
      _isLoginEnabled = false;
    }

    widget.controller.resetProfileImageUploadState();

    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);

    _employeeCodeController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _joiningDateController.dispose();

    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _selectJoiningDate() async {
    final DateTime now = DateTime.now();

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _dateOfJoining ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Select Date of Joining',
      confirmText: 'Select',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _dateOfJoining = selectedDate;

      _joiningDateController.text = _formatDate(selectedDate);
    });
  }

  void _clearJoiningDate() {
    setState(() {
      _dateOfJoining = null;
      _joiningDateController.clear();
    });
  }

  Future<void> _browseProfileImage() async {
    if (_isBusy) {
      return;
    }

    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: _allowedImageExtensions.toList(),
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }

      final PlatformFile selectedFile = result.files.single;

      final Uint8List? bytes = selectedFile.bytes;

      if (bytes == null) {
        setState(() {
          _profileImageError = 'The selected image could not be read.';
        });

        return;
      }

      await _prepareAndUploadProfileImage(
        bytes: bytes,
        fileName: selectedFile.name,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _profileImageError = 'Unable to select the image: $error';
      });
    }
  }

  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    if (_isBusy || details.files.isEmpty) {
      return;
    }

    final XFile droppedFile = details.files.first;

    try {
      final Uint8List bytes = await droppedFile.readAsBytes();

      if (!mounted) {
        return;
      }

      await _prepareAndUploadProfileImage(
        bytes: bytes,
        fileName: droppedFile.name,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _profileImageError = 'Unable to read the dropped image: $error';
      });
    }
  }

  Future<void> _prepareAndUploadProfileImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String normalizedFileName = fileName.trim();

    final String extension = _fileExtension(normalizedFileName);

    if (!_allowedImageExtensions.contains(extension)) {
      setState(() {
        _profileImageError =
            'Select a JPG, JPEG, PNG, WEBP, GIF or AVIF image.';
      });

      return;
    }

    if (bytes.isEmpty) {
      setState(() {
        _profileImageError = 'The selected image is empty.';
      });

      return;
    }

    if (bytes.lengthInBytes > _maximumProfileImageBytes) {
      setState(() {
        _profileImageError = 'Profile image size cannot exceed 5 MB.';
      });

      return;
    }

    setState(() {
      _selectedProfileImageBytes = bytes;

      _selectedProfileImageName = normalizedFileName;

      _profileImageError = null;
      _formError = null;
    });

    final String? uploadedUrl = await widget.controller
        .uploadEmployeeProfileImage(bytes: bytes, fileName: normalizedFileName);

    if (!mounted) {
      return;
    }

    if (uploadedUrl == null || uploadedUrl.trim().isEmpty) {
      setState(() {
        _profileImageError =
            widget.controller.errorMessage ??
            'Unable to upload the profile image.';
      });

      return;
    }

    setState(() {
      _profileImageUrl = uploadedUrl.trim();

      _profileImageError = null;
    });
  }

  void _removeProfileImage() {
    if (_isBusy) {
      return;
    }

    setState(() {
      _selectedProfileImageBytes = null;

      _selectedProfileImageName = null;

      _profileImageUrl = '';
      _profileImageError = null;
    });

    widget.controller.resetProfileImageUploadState();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isUploadingProfileImage) {
      setState(() {
        _formError = 'Wait for the profile image upload to finish.';
      });

      return;
    }

    setState(() {
      _formError = null;
    });

    final bool isFormValid = _formKey.currentState?.validate() ?? false;

    if (!isFormValid) {
      setState(() {
        _formError = 'Complete all required employee fields.';
      });

      return;
    }

    final CompanyEmployeeFormData formData = CompanyEmployeeFormData(
      employeeCode: _employeeCodeController.text.trim(),

      fullName: _fullNameController.text.trim(),

      email: _emailController.text.trim(),

      phone: _phoneController.text.trim(),

      role: _roleController.text.trim(),

      username: _usernameController.text.trim(),

      temporaryPassword: _passwordController.text.trim(),

      profileImageUrl: _profileImageUrl.trim(),

      dateOfJoining: _dateOfJoining,

      isActive: _isActive,

      isLoginEnabled: _isActive && _isLoginEnabled,

      mustChangePassword: _mustChangePassword,

      /*
       * Compatibility values.
       *
       * Company, branch and shift are
       * fixed by the backend.
       *
       * Department and designation
       * are removed.
       */
      companyId: widget.employee?.companyId,

      branchId: widget.employee?.branchId,

      departmentId: null,
      designationId: null,

      shiftId: widget.employee?.shiftId,
    );

    final String? validationMessage = formData.validate(
      passwordRequired: !_isEditing,
    );

    if (validationMessage != null) {
      setState(() {
        _formError = validationMessage;
      });

      return;
    }

    CompanyEmployee? savedEmployee;

    if (_isEditing) {
      final int? employeeId = widget.employee?.employeeId;

      if (employeeId == null || employeeId <= 0) {
        setState(() {
          _formError = 'A valid employee ID is required.';
        });

        return;
      }

      savedEmployee = await widget.controller.updateEmployee(
        employeeId,
        formData,
      );
    } else {
      savedEmployee = await widget.controller.createEmployee(formData);
    }

    if (!mounted) {
      return;
    }

    if (savedEmployee == null) {
      setState(() {
        _formError =
            widget.controller.errorMessage ??
            'Unable to save the employee record.';
      });

      return;
    }

    Navigator.of(context).pop(savedEmployee);
  }

  void _closeDialog() {
    if (_isBusy) {
      return;
    }

    Navigator.of(context).pop();
  }

  void _handleActiveChanged(bool value) {
    setState(() {
      _isActive = value;

      if (!value) {
        _isLoginEnabled = false;
      }
    });
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _roleValidator(String? value) {
    final String role = value?.trim() ?? '';

    if (role.isEmpty) {
      return 'Employee role is required.';
    }

    if (role.length < 2) {
      return 'Role must contain at least 2 characters.';
    }

    if (role.length > 100) {
      return 'Role cannot exceed 100 characters.';
    }

    return null;
  }

  String? _emailValidator(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email address is required.';
    }

    final RegExp emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _phoneValidator(String? value) {
    final String phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Mobile number is required.';
    }

    final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid mobile number.';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    final String password = value?.trim() ?? '';

    if (!_isEditing && password.isEmpty) {
      return 'Temporary password is required.';
    }

    if (password.isNotEmpty && password.length < 6) {
      return 'Use at least 6 characters.';
    }

    return null;
  }

  String _fileExtension(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == fileName.length - 1) {
      return '';
    }

    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }

    final String day = date.day.toString().padLeft(2, '0');

    final String month = date.month.toString().padLeft(2, '0');

    return '$day-$month-${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 840),
        child: Container(
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: AdminColors.shadow,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              _buildHeader(),
              Expanded(child: _buildFormContent()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 14, 16),
      decoration: const BoxDecoration(
        color: AdminColors.navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isEditing ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isEditing
                      ? 'Edit GoDigital Employee'
                      : 'Add GoDigital Employee',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditing
                      ? 'Update employee details, role, profile image and mobile app access.'
                      : 'Create an employee account for the Guduvanchery branch.',
                  style: const TextStyle(
                    color: AdminColors.textOnDarkMuted,
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _isBusy ? null : _closeDialog,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_formError != null) ...<Widget>[
              _FormMessage(message: _formError!),
              const SizedBox(height: 16),
            ],
            _FormSection(
              title: 'Employee Information',
              subtitle:
                  'Basic employee identity, contact details and manually entered work role.',
              icon: Icons.person_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _ResponsiveFields(
                    children: <Widget>[
                      _FormTextField(
                        controller: _employeeCodeController,
                        label: 'Employee Code',
                        hintText: 'Example: EMP-0001',
                        requiredField: true,
                        prefixIcon: Icons.badge_outlined,
                        validator: _requiredValidator,
                      ),
                      _FormTextField(
                        controller: _fullNameController,
                        label: 'Full Name',
                        hintText: 'Enter employee full name',
                        requiredField: true,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: _requiredValidator,
                      ),


                    _DropdownFormField(
  controller: _roleController,
  label: 'Work Role',
  requiredField: true,
  prefixIcon: Icons.work_outline_rounded,
  items: _employeeRoles,
  validator: _roleValidator,
),

                      _FormTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hintText: 'employee@godigitalindia.co',
                        requiredField: true,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: _emailValidator,
                      ),
                      _FormTextField(
                        controller: _phoneController,
                        label: 'Mobile Number',
                        hintText: '+91 98765 43210',
                        requiredField: true,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: _phoneValidator,
                      ),
                      _DateFormField(
                        controller: _joiningDateController,
                        onPressed: _selectJoiningDate,
                        onClear: _dateOfJoining == null
                            ? null
                            : _clearJoiningDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _FieldLabel(
                    label: 'Profile Image',
                    helper: 'Optional • Maximum 5 MB',
                  ),
                  const SizedBox(height: 7),
                  _ProfileImageUploadField(
                    selectedBytes: _selectedProfileImageBytes,
                    existingImageUrl: _profileImageUrl,
                    selectedFileName: _selectedProfileImageName,
                    errorMessage: _profileImageError,
                    isDragging: _isDraggingProfileImage,
                    isUploading: _isUploadingProfileImage,
                    uploadProgress:
                        widget.controller.profileImageUploadProgress,
                    onBrowse: _browseProfileImage,
                    onRemove: _removeProfileImage,
                    onDragEntered: () {
                      if (_isBusy) {
                        return;
                      }

                      setState(() {
                        _isDraggingProfileImage = true;
                      });
                    },
                    onDragExited: () {
                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        _isDraggingProfileImage = false;
                      });
                    },
                    onDragDone: _handleDroppedFiles,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _FormSection(
              title: 'Fixed Company Assignment',
              subtitle:
                  'These values are fixed for every employee and cannot be changed.',
              icon: Icons.apartment_rounded,
              child: _FixedAssignmentPanel(),
            ),
            const SizedBox(height: 18),
            _FormSection(
              title: 'Employee Mobile App Login',
              subtitle:
                  'Create the username and temporary password used in the employee app.',
              icon: Icons.phone_android_rounded,
              child: Column(
                children: <Widget>[
                  _ResponsiveFields(
                    children: <Widget>[
                      _FormTextField(
                        controller: _usernameController,
                        label: 'Mobile App Username',
                        hintText: 'Enter login username',
                        requiredField: true,
                        prefixIcon: Icons.account_circle_outlined,
                        validator: _requiredValidator,
                      ),
                      _FormTextField(
                        controller: _passwordController,
                        label: _isEditing
                            ? 'New Temporary Password'
                            : 'Temporary Password',
                        hintText: _isEditing
                            ? 'Leave blank to keep existing password'
                            : 'Minimum 6 characters',
                        requiredField: !_isEditing,
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: _passwordValidator,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SettingsPanel(
                    isActive: _isActive,
                    isLoginEnabled: _isLoginEnabled,
                    mustChangePassword: _mustChangePassword,
                    onActiveChanged: _handleActiveChanged,
                    onLoginEnabledChanged: (bool value) {
                      setState(() {
                        _isLoginEnabled = value;
                      });
                    },
                    onPasswordChangeChanged: (bool value) {
                      setState(() {
                        _mustChangePassword = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final double progress = widget.controller.profileImageUploadProgress
        .clamp(0.0, 1.0)
        .toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      decoration: const BoxDecoration(
        color: AdminColors.surface,
        border: Border(top: BorderSide(color: AdminColors.divider)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_isUploadingProfileImage) ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: AdminColors.primary,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Uploading profile image ${(progress * 100).round()}%',
                    style: AdminTextStyles.helperText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(value: progress > 0 ? progress : null),
            const SizedBox(height: 12),
          ],
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '* Required fields',
                  style: AdminTextStyles.helperText,
                ),
              ),
              OutlinedButton(
                onPressed: _isBusy ? null : _closeDialog,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _isBusy ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isEditing
                            ? Icons.save_outlined
                            : Icons.person_add_alt_1_rounded,
                        size: 17,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : _isUploadingProfileImage
                      ? 'Uploading...'
                      : _isEditing
                      ? 'Save Changes'
                      : 'Add Employee',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileImageUploadField extends StatelessWidget {
  const _ProfileImageUploadField({
    required this.selectedBytes,
    required this.existingImageUrl,
    required this.selectedFileName,
    required this.errorMessage,
    required this.isDragging,
    required this.isUploading,
    required this.uploadProgress,
    required this.onBrowse,
    required this.onRemove,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDragDone,
  });

  final Uint8List? selectedBytes;
  final String existingImageUrl;
  final String? selectedFileName;
  final String? errorMessage;

  final bool isDragging;
  final bool isUploading;
  final double uploadProgress;

  final VoidCallback onBrowse;
  final VoidCallback onRemove;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final ValueChanged<DropDoneDetails> onDragDone;

  bool get hasImage {
    return selectedBytes != null || existingImageUrl.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final double normalizedProgress = uploadProgress.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropTarget(
          onDragEntered: (DropEventDetails details) {
            onDragEntered();
          },
          onDragExited: (DropEventDetails details) {
            onDragExited();
          },
          onDragDone: (DropDoneDetails details) {
            onDragExited();
            onDragDone(details);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 178),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDragging
                  ? AdminColors.primaryLight
                  : AdminColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: errorMessage != null
                    ? AdminColors.danger
                    : isDragging
                    ? AdminColors.primary
                    : AdminColors.inputBorder,
                width: isDragging ? 2 : 1,
              ),
            ),
            child: hasImage
                ? _buildImagePreview(normalizedProgress)
                : _buildEmptyState(),
          ),
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                color: AdminColors.danger,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorMessage!,
                  style: AdminTextStyles.dangerMessage,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return InkWell(
      onTap: isUploading ? null : onBrowse,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AdminColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AdminColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isDragging
                  ? 'Drop the image here'
                  : 'Drag and drop a profile image',
              textAlign: TextAlign.center,
              style: AdminTextStyles.cardTitle,
            ),
            const SizedBox(height: 5),
            const Text(
              'or click to browse from your computer',
              textAlign: TextAlign.center,
              style: AdminTextStyles.helperText,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isUploading ? null : onBrowse,
              icon: const Icon(Icons.folder_open_outlined, size: 17),
              label: const Text('Browse Image'),
            ),
            const SizedBox(height: 8),
            const Text(
              'JPG, JPEG, PNG, WEBP, GIF or AVIF • Maximum 5 MB',
              textAlign: TextAlign.center,
              style: AdminTextStyles.helperText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(double normalizedProgress) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 132,
          height: 132,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.border),
          ),
          child: selectedBytes != null
              ? Image.memory(selectedBytes!, fit: BoxFit.cover)
              : Image.network(
                  existingImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AdminColors.textMuted,
                            size: 34,
                          ),
                        );
                      },
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                selectedFileName ?? 'Saved profile image',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AdminTextStyles.cardTitle,
              ),
              const SizedBox(height: 6),
              Text(
                isUploading
                    ? 'Uploading profile image...'
                    : 'Image ready to save with this employee.',
                style: AdminTextStyles.helperText,
              ),
              if (isUploading) ...<Widget>[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: normalizedProgress > 0 ? normalizedProgress : null,
                ),
                const SizedBox(height: 5),
                Text(
                  '${(normalizedProgress * 100).round()}%',
                  style: AdminTextStyles.helperText,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: isUploading ? null : onBrowse,
                    icon: const Icon(
                      Icons.published_with_changes_outlined,
                      size: 16,
                    ),
                    label: const Text('Replace'),
                  ),
                  TextButton.icon(
                    onPressed: isUploading ? null : onRemove,
                    style: TextButton.styleFrom(
                      foregroundColor: AdminColors.danger,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 37,
                height: 37,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AdminColors.primaryLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: AdminColors.primary, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AdminTextStyles.cardTitle),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AdminTextStyles.cardSubtitle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 700
            ? 3
            : constraints.maxWidth >= 440
            ? 2
            : 1;

        const double gap = 13;

        final double fieldWidth =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: 15,
          children: children.map((Widget child) {
            return SizedBox(width: fieldWidth, child: child);
          }).toList(),
        );
      },
    );
  }
}

class _FormTextField extends StatelessWidget {
  const _FormTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    this.requiredField = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool requiredField;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(label: label, requiredField: requiredField),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _DateFormField extends StatelessWidget {
  const _DateFormField({
    required this.controller,
    required this.onPressed,
    this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _FieldLabel(label: 'Date of Joining'),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onPressed,
          decoration: InputDecoration(
            hintText: 'Select joining date',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            suffixIcon: onClear == null
                ? IconButton(
                    tooltip: 'Select date',
                    onPressed: onPressed,
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                  )
                : IconButton(
                    tooltip: 'Clear date',
                    onPressed: onClear,
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
      ],
    );
  }
}

class _FixedAssignmentPanel extends StatelessWidget {
  const _FixedAssignmentPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 680
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;

        const double gap = 12;

        final double itemWidth =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: itemWidth,
              child: const _FixedAssignmentItem(
                icon: Icons.business_outlined,
                label: 'Company',
                value: fixedEmployeeCompanyName,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: const _FixedAssignmentItem(
                icon: Icons.location_on_outlined,
                label: 'Branch',
                value: fixedEmployeeBranchName,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: const _FixedAssignmentItem(
                icon: Icons.schedule_outlined,
                label: 'Shift',
                value: fixedEmployeeShiftName,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FixedAssignmentItem extends StatelessWidget {
  const _FixedAssignmentItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AdminColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AdminColors.borderLight),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminColors.primaryLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: AdminColors.primary, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: AdminTextStyles.helperText),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTextStyles.fieldValue,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AdminColors.primary,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
    this.requiredField = false,
    this.helper,
  });

  final String label;
  final bool requiredField;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AdminTextStyles.fieldLabel,
              children: <InlineSpan>[
                TextSpan(text: label),
                if (requiredField)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: AdminColors.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (helper != null) Text(helper!, style: AdminTextStyles.helperText),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.isActive,
    required this.isLoginEnabled,
    required this.mustChangePassword,
    required this.onActiveChanged,
    required this.onLoginEnabledChanged,
    required this.onPasswordChangeChanged,
  });

  final bool isActive;
  final bool isLoginEnabled;
  final bool mustChangePassword;

  final ValueChanged<bool> onActiveChanged;

  final ValueChanged<bool> onLoginEnabledChanged;

  final ValueChanged<bool> onPasswordChangeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AdminColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.borderLight),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = constraints.maxWidth >= 720
              ? 3
              : constraints.maxWidth >= 480
              ? 2
              : 1;

          const double gap = 12;

          final double itemWidth =
              (constraints.maxWidth - ((columns - 1) * gap)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: 12,
            children: <Widget>[
              SizedBox(
                width: itemWidth,
                child: _SwitchSetting(
                  title: 'Employee Account Active',
                  subtitle: 'Keep this employee record active.',
                  value: isActive,
                  onChanged: onActiveChanged,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _SwitchSetting(
                  title: 'Enable Mobile Login',
                  subtitle: isActive
                      ? 'Allow login in the employee mobile app.'
                      : 'Activate the employee before enabling login.',
                  value: isLoginEnabled,
                  enabled: isActive,
                  onChanged: onLoginEnabledChanged,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _SwitchSetting(
                  title: 'Change Password on Next Login',
                  subtitle: 'Require a new password after signing in.',
                  value: mustChangePassword,
                  onChanged: onPasswordChangeChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AdminColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AdminTextStyles.fieldLabel),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AdminTextStyles.helperText),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: enabled ? value : false,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormMessage extends StatelessWidget {
  const _FormMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AdminColors.dangerBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminColors.dangerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AdminColors.danger,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AdminTextStyles.dangerMessage)),
        ],
      ),
    );
  }
  
}
class _DropdownFormField extends StatelessWidget {
  const _DropdownFormField({
    required this.controller,
    required this.label,
    required this.items,
    this.requiredField = false,
    this.prefixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final List<String> items;
  final bool requiredField;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;


  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _FieldLabel(
          label: label,
          requiredField: requiredField,
        ),

        const SizedBox(height: 6),


        DropdownButtonFormField<String>(

          value: controller.text.isEmpty
              ? null
              : controller.text,


          isExpanded: true,


          itemHeight: 52,


          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Color(0xff6B7280),
          ),


          dropdownColor: Colors.white,


          decoration: InputDecoration(

            hintText: 'Select $label',


            hintStyle: const TextStyle(
              color: Color(0xff9CA3AF),
              fontSize: 16,
            ),


            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    size: 20,
                    color: Color(0xff6B7280),
                  )
                : null,


            prefixIconConstraints: const BoxConstraints(
              minWidth: 45,
              minHeight: 52,
            ),


            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),


            isDense: false,


            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xffD5D9E2),
              ),
            ),


            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xffD5D9E2),
              ),
            ),


            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xff2F46FF),
                width: 1.5,
              ),
            ),

          ),



          items: items.map((String item){

            return DropdownMenuItem<String>(

              value: item,


              child: Text(
                item,

                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xff4B5563),
                ),

              ),

            );

          }).toList(),



          onChanged: (String? value){

            if(value != null){

              controller.text = value;

            }

          },


          validator: validator,

        ),

      ],

    );

  }
}