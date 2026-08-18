import 'package:employee_mobile/features/profile/data/models/profile_response.dart';
import 'package:employee_mobile/features/profile/data/repositories/profile_repository.dart';
import 'package:flutter/foundation.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    ProfileRepository? repository,
  }) : _repository =
            repository ?? ProfileRepository();

  final ProfileRepository _repository;

  EmployeeProfile? _profile;

  bool _isLoading = false;
  bool _isRefreshing = false;

  String? _errorMessage;
  String? _successMessage;

  bool _isDisposed = false;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  EmployeeProfile? get profile {
    return _profile;
  }

  bool get isLoading {
    return _isLoading;
  }

  bool get isRefreshing {
    return _isRefreshing;
  }

  bool get isBusy {
    return _isLoading || _isRefreshing;
  }

  bool get hasProfile {
    return _profile != null;
  }

  bool get hasError {
    return _errorMessage != null &&
        _errorMessage!.trim().isNotEmpty;
  }

  String? get errorMessage {
    return _errorMessage;
  }

  String? get successMessage {
    return _successMessage;
  }

  String get displayName {
    return _profile?.displayName ?? 'Employee';
  }

  String get initials {
    return _profile?.initials ?? 'E';
  }

  String get employeeCode {
    final value =
        _profile?.employeeCode.trim() ?? '';

    return value.isEmpty ? 'Not available' : value;
  }

  String get email {
    final value = _profile?.email.trim() ?? '';

    return value.isEmpty ? 'Not available' : value;
  }

  String get phone {
    final value = _profile?.phone.trim() ?? '';

    return value.isEmpty ? 'Not available' : value;
  }

  String get designation {
    return _profile?.designationLabel ??
        'Employee';
  }

  String get department {
    return _profile?.departmentLabel ??
        'Not assigned';
  }

  String get branch {
    return _profile?.branchLabel ??
        'Not assigned';
  }

  String get company {
    return _profile?.companyLabel ??
        'Not available';
  }

  String get joiningDate {
    return _profile?.joiningDateLabel ??
        'Not available';
  }

  String get role {
    final value = _profile?.role.trim() ?? '';

    if (value.isEmpty) {
      return 'Employee';
    }

    return _capitalizeWords(value);
  }

  String get profileImageUrl {
    return _profile?.profileImageUrl.trim() ??
        '';
  }

  bool get hasProfileImage {
    return profileImageUrl.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Initial load
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    await loadProfile();
  }

  Future<void> loadProfile({
    bool showLoading = true,
  }) async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    if (showLoading) {
      _isLoading = true;
    }

    _errorMessage = null;
    _successMessage = null;

    _notifySafely();

    try {
      final employeeProfile =
          await _repository.getProfile();

      _profile = employeeProfile;
    } on ProfileRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage =
          'Unable to load employee profile: $error';
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  Future<bool> refreshProfile() async {
    if (_isLoading || _isRefreshing) {
      return false;
    }

    _isRefreshing = true;
    _errorMessage = null;
    _successMessage = null;

    _notifySafely();

    try {
      final employeeProfile =
          await _repository.refreshProfile();

      _profile = employeeProfile;

      _successMessage =
          'Profile refreshed successfully.';

      return true;
    } on ProfileRepositoryException catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (error) {
      _errorMessage =
          'Unable to refresh employee profile: $error';

      return false;
    } finally {
      _isRefreshing = false;
      _notifySafely();
    }
  }

  // ---------------------------------------------------------------------------
  // Local profile update
  // ---------------------------------------------------------------------------

  void updateProfileLocally(
    EmployeeProfile updatedProfile,
  ) {
    _profile = updatedProfile;
    _successMessage =
        'Profile updated successfully.';
    _errorMessage = null;

    _notifySafely();
  }

  void updatePhoneLocally(
    String phone,
  ) {
    final currentProfile = _profile;

    if (currentProfile == null) {
      return;
    }

    _profile = currentProfile.copyWith(
      phone: phone.trim(),
    );

    _notifySafely();
  }

  void updateProfileImageLocally(
    String imageUrl,
  ) {
    final currentProfile = _profile;

    if (currentProfile == null) {
      return;
    }

    _profile = currentProfile.copyWith(
      profileImageUrl: imageUrl.trim(),
    );

    _notifySafely();
  }

  // ---------------------------------------------------------------------------
  // Error and success messages
  // ---------------------------------------------------------------------------

  void clearErrorMessage() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    _notifySafely();
  }

  void clearSuccessMessage() {
    if (_successMessage == null) {
      return;
    }

    _successMessage = null;
    _notifySafely();
  }

  void clearMessages() {
    if (_errorMessage == null &&
        _successMessage == null) {
      return;
    }

    _errorMessage = null;
    _successMessage = null;

    _notifySafely();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _capitalizeWords(
    String value,
  ) {
    return value
        .trim()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where(
          (String word) {
            return word.isNotEmpty;
          },
        )
        .map(
          (String word) {
            if (word.length == 1) {
              return word.toUpperCase();
            }

            return '${word[0].toUpperCase()}'
                '${word.substring(1).toLowerCase()}';
          },
        )
        .join(' ');
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}