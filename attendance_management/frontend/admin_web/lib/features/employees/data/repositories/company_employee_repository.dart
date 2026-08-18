import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/auth/admin_auth_session.dart';

import '../models/company_employee.dart';

typedef AccessTokenProvider = FutureOr<String?> Function();

class CompanyEmployeeRepository {
  CompanyEmployeeRepository({
    Dio? dio,
    this._accessTokenProvider,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'http://localhost:3000/api/v1',
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                responseType: ResponseType.json,
                headers: const <String, dynamic>{
                  'Accept': 'application/json',
                },
              ),
            );

  static const int maximumProfileImageBytes = 5 * 1024 * 1024;

  static const String _employeeEndpoint = '/admin/employees';
  static const String _profileImageEndpoint =
      '/admin/employees/profile-image';

  final Dio _dio;
  final AccessTokenProvider? _accessTokenProvider;

  /// Employee list API.
  ///
  /// Company, branch, department, designation and shift parameters are kept
  /// temporarily so the existing controller continues to compile.
  ///
  /// GoDigital, Guduvanchery and the 9 AM–6 PM shift are fixed by the backend,
  /// so those values are not sent as filters.
  Future<dynamic> getEmployees({
    int page = 1,
    int limit = 20,
    String search = '',
    String? status,
    int? companyId,
    int? branchId,
    int? departmentId,
    int? designationId,
    int? shiftId,
  }) async {
    return _executeRequest(
      () async {
        return _dio.get<dynamic>(
          _employeeEndpoint,
          queryParameters: <String, dynamic>{
            'page': page,
            'limit': limit,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (status != null && status.trim().isNotEmpty)
              'status': status.trim(),
          },
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> fetchEmployees({
    int page = 1,
    int limit = 20,
    String search = '',
    String? status,
    int? companyId,
    int? branchId,
    int? departmentId,
    int? designationId,
    int? shiftId,
  }) {
    return getEmployees(
      page: page,
      limit: limit,
      search: search,
      status: status,
      companyId: companyId,
      branchId: branchId,
      departmentId: departmentId,
      designationId: designationId,
      shiftId: shiftId,
    );
  }

  Future<dynamic> loadEmployees({
    int page = 1,
    int limit = 20,
    String search = '',
    String? status,
    int? companyId,
    int? branchId,
    int? departmentId,
    int? designationId,
    int? shiftId,
  }) {
    return getEmployees(
      page: page,
      limit: limit,
      search: search,
      status: status,
      companyId: companyId,
      branchId: branchId,
      departmentId: departmentId,
      designationId: designationId,
      shiftId: shiftId,
    );
  }

  Future<dynamic> getEmployeeById(
    int employeeId,
  ) async {
    _validateEmployeeId(employeeId);

    return _executeRequest(
      () async {
        return _dio.get<dynamic>(
          '$_employeeEndpoint/$employeeId',
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> getEmployee(
    int employeeId,
  ) {
    return getEmployeeById(employeeId);
  }

  Future<dynamic> fetchEmployee(
    int employeeId,
  ) {
    return getEmployeeById(employeeId);
  }

  Future<dynamic> loadEmployeeDetails(
    int employeeId,
  ) {
    return getEmployeeById(employeeId);
  }

  Future<dynamic> createEmployee(
    CompanyEmployeeFormData formData,
  ) async {
    return _executeRequest(
      () async {
        return _dio.post<dynamic>(
          _employeeEndpoint,
          data: _formDataToJson(formData),
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> updateEmployee(
    int employeeId,
    CompanyEmployeeFormData formData,
  ) async {
    _validateEmployeeId(employeeId);

    return _executeRequest(
      () async {
        return _dio.put<dynamic>(
          '$_employeeEndpoint/$employeeId',
          data: _formDataToJson(formData),
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> updateEmployeeStatus(
    int employeeId, {
    required bool isActive,
  }) async {
    _validateEmployeeId(employeeId);

    return _executeRequest(
      () async {
        return _dio.patch<dynamic>(
          '$_employeeEndpoint/$employeeId/status',
          data: <String, dynamic>{
            'is_active': isActive,
            'status': isActive ? 'active' : 'inactive',
          },
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> changeEmployeeStatus(
    int employeeId,
    bool isActive,
  ) {
    return updateEmployeeStatus(
      employeeId,
      isActive: isActive,
    );
  }

  Future<dynamic> updateEmployeeCredentials(
    int employeeId, {
    required String username,
    String temporaryPassword = '',
    bool mustChangePassword = false,
    bool isLoginEnabled = true,
  }) async {
    _validateEmployeeId(employeeId);

    final String normalizedUsername = username.trim();
    final String normalizedPassword = temporaryPassword.trim();

    if (normalizedUsername.isEmpty) {
      throw const CompanyEmployeeRepositoryException(
        'Mobile app username is required.',
      );
    }

    if (normalizedPassword.isNotEmpty &&
        normalizedPassword.length < 6) {
      throw const CompanyEmployeeRepositoryException(
        'The temporary password must contain at least 6 characters.',
      );
    }

    return _executeRequest(
      () async {
        return _dio.patch<dynamic>(
          '$_employeeEndpoint/$employeeId/credentials',
          data: <String, dynamic>{
            'username': normalizedUsername,
            'must_change_password': mustChangePassword,
            'is_login_enabled': isLoginEnabled,
            if (normalizedPassword.isNotEmpty)
              'temporary_password': normalizedPassword,
            if (normalizedPassword.isNotEmpty)
              'password': normalizedPassword,
          },
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> resetEmployeePassword(
    int employeeId, {
    required String temporaryPassword,
    required bool mustChangePassword,
  }) async {
    _validateEmployeeId(employeeId);

    final String normalizedPassword = temporaryPassword.trim();

    if (normalizedPassword.length < 6) {
      throw const CompanyEmployeeRepositoryException(
        'The temporary password must contain at least 6 characters.',
      );
    }

    return _executeRequest(
      () async {
        return _dio.patch<dynamic>(
          '$_employeeEndpoint/$employeeId/reset-password',
          data: <String, dynamic>{
            'temporary_password': normalizedPassword,
            'password': normalizedPassword,
            'must_change_password': mustChangePassword,
          },
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> updateEmployeePassword(
    int employeeId,
    String temporaryPassword,
    bool mustChangePassword,
  ) {
    return resetEmployeePassword(
      employeeId,
      temporaryPassword: temporaryPassword,
      mustChangePassword: mustChangePassword,
    );
  }

  Future<dynamic> updateEmployeeLoginStatus(
    int employeeId, {
    required bool isLoginEnabled,
  }) async {
    _validateEmployeeId(employeeId);

    return _executeRequest(
      () async {
        return _dio.patch<dynamic>(
          '$_employeeEndpoint/$employeeId/login-status',
          data: <String, dynamic>{
            'is_login_enabled': isLoginEnabled,
          },
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> deleteEmployee(
    int employeeId,
  ) async {
    _validateEmployeeId(employeeId);

    return _executeRequest(
      () async {
        return _dio.delete<dynamic>(
          '$_employeeEndpoint/$employeeId',
          options: await _authorizedOptions(),
        );
      },
    );
  }

  Future<dynamic> removeEmployee(
    int employeeId,
  ) {
    return deleteEmployee(employeeId);
  }

  /// Upload a profile image selected through browse or drag-and-drop.
  ///
  /// The backend expects multipart field name:
  /// profile_image
  ///
  /// Returns the final public image URL.
  Future<String> uploadEmployeeProfileImage({
    required Uint8List bytes,
    required String fileName,
    ProgressCallback? onSendProgress,
  }) async {
    if (bytes.isEmpty) {
      throw const CompanyEmployeeRepositoryException(
        'Select a profile image to upload.',
      );
    }

    if (bytes.lengthInBytes > maximumProfileImageBytes) {
      throw const CompanyEmployeeRepositoryException(
        'Profile image size cannot exceed 5 MB.',
      );
    }

    final String normalizedFileName = _normalizeFileName(fileName);
    final String extension = _fileExtension(normalizedFileName);
    final String? mimeType = _mimeTypeForExtension(extension);

    if (mimeType == null) {
      throw const CompanyEmployeeRepositoryException(
        'Select a JPG, JPEG, PNG, WEBP, GIF or AVIF image.',
      );
    }

    final MultipartFile multipartFile = MultipartFile.fromBytes(
      bytes,
      filename: normalizedFileName,
      contentType: DioMediaType.parse(mimeType),
    );

    final FormData uploadFormData = FormData.fromMap(
      <String, dynamic>{
        'profile_image': multipartFile,
      },
    );

    final dynamic responseData = await _executeRequest(
      () async {
        return _dio.post<dynamic>(
          _profileImageEndpoint,
          data: uploadFormData,
          options: await _authorizedOptions(
            multipart: true,
          ),
          onSendProgress: onSendProgress,
        );
      },
    );

    final String uploadedUrl = _extractProfileImageUrl(
      responseData,
    );

    if (uploadedUrl.isEmpty) {
      throw CompanyEmployeeRepositoryException(
        'The server did not return the uploaded profile image URL.',
        responseData: responseData,
      );
    }

    return _toAbsoluteUrl(uploadedUrl);
  }

  /// Fixed lookup values retained for compatibility with the existing
  /// controller. No lookup API calls are required.
  Future<dynamic> getCompanies() async {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': fixedEmployeeCompanyName,
        'company_name': fixedEmployeeCompanyName,
        'code': 'GODIGITAL',
        'company_code': 'GODIGITAL',
        'is_active': true,
      },
    ];
  }

  Future<dynamic> fetchCompanies() {
    return getCompanies();
  }

  Future<dynamic> loadCompanies() {
    return getCompanies();
  }

  Future<dynamic> getBranches({
    int? companyId,
  }) async {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': fixedEmployeeBranchName,
        'branch_name': fixedEmployeeBranchName,
        'code': 'GUDUVANCHERY',
        'branch_code': 'GUDUVANCHERY',
        'is_active': true,
      },
    ];
  }

  Future<dynamic> fetchBranches({
    int? companyId,
  }) {
    return getBranches(
      companyId: companyId,
    );
  }

  Future<dynamic> loadBranches({
    int? companyId,
  }) {
    return getBranches(
      companyId: companyId,
    );
  }

  Future<dynamic> getDepartments({
    int? companyId,
    int? branchId,
  }) async {
    return <Map<String, dynamic>>[];
  }

  Future<dynamic> fetchDepartments({
    int? companyId,
    int? branchId,
  }) {
    return getDepartments(
      companyId: companyId,
      branchId: branchId,
    );
  }

  Future<dynamic> loadDepartments({
    int? companyId,
    int? branchId,
  }) {
    return getDepartments(
      companyId: companyId,
      branchId: branchId,
    );
  }

  Future<dynamic> getDesignations({
    int? companyId,
    int? departmentId,
  }) async {
    return <Map<String, dynamic>>[];
  }

  Future<dynamic> fetchDesignations({
    int? companyId,
    int? departmentId,
  }) {
    return getDesignations(
      companyId: companyId,
      departmentId: departmentId,
    );
  }

  Future<dynamic> loadDesignations({
    int? companyId,
    int? departmentId,
  }) {
    return getDesignations(
      companyId: companyId,
      departmentId: departmentId,
    );
  }

  Future<dynamic> getShifts({
    int? companyId,
    int? branchId,
  }) async {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': fixedEmployeeShiftName,
        'shift_name': fixedEmployeeShiftName,
        'code': 'GENERAL_9_TO_6',
        'shift_code': 'GENERAL_9_TO_6',
        'is_active': true,
      },
    ];
  }

  Future<dynamic> fetchShifts({
    int? companyId,
    int? branchId,
  }) {
    return getShifts(
      companyId: companyId,
      branchId: branchId,
    );
  }

  Future<dynamic> loadShifts({
    int? companyId,
    int? branchId,
  }) {
    return getShifts(
      companyId: companyId,
      branchId: branchId,
    );
  }

  Future<Options> _authorizedOptions({
    bool multipart = false,
  }) async {
    final AccessTokenProvider tokenProvider =
        _accessTokenProvider ??
        AdminAuthSession.getAccessToken;

    final String? token =
        await tokenProvider();

    final String normalizedToken =
        token?.trim() ?? '';

    return Options(
      contentType: multipart
          ? Headers.multipartFormDataContentType
          : Headers.jsonContentType,
      headers: <String, dynamic>{
        'Accept': 'application/json',
        if (normalizedToken.isNotEmpty)
          'Authorization': 'Bearer $normalizedToken',
      },
    );
  }

  Future<dynamic> _executeRequest(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final Response<dynamic> response =
          await request();

      return _validatedData(response);
    } on CompanyEmployeeRepositoryException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException catch (error) {
      throw CompanyEmployeeRepositoryException(
        error.message,
      );
    } catch (error) {
      throw CompanyEmployeeRepositoryException(
        'Unexpected employee request error: $error',
      );
    }
  }

  Map<String, dynamic> _formDataToJson(
    CompanyEmployeeFormData formData,
  ) {
    final dynamic rawJson = formData.toJson();

    if (rawJson is Map<String, dynamic>) {
      return rawJson;
    }

    if (rawJson is Map) {
      return rawJson.map<String, dynamic>(
        (
          dynamic key,
          dynamic value,
        ) {
          return MapEntry<String, dynamic>(
            key.toString(),
            value,
          );
        },
      );
    }

    throw const CompanyEmployeeRepositoryException(
      'Employee form data could not be converted to JSON.',
    );
  }

  dynamic _validatedData(
    Response<dynamic> response,
  ) {
    final dynamic data = response.data;

    if (data is Map) {
      final dynamic success = data['success'];

      if (success == false) {
        throw CompanyEmployeeRepositoryException(
          _extractMessage(data) ??
              'The employee request failed.',
          statusCode: response.statusCode,
          responseData: data,
        );
      }
    }

    return data;
  }

  CompanyEmployeeRepositoryException _mapDioException(
    DioException error,
  ) {
    final int? statusCode =
        error.response?.statusCode;

    final dynamic responseData =
        error.response?.data;

    final String? serverMessage =
        _extractMessage(responseData);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return CompanyEmployeeRepositoryException(
          'The employee server connection timed out.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.sendTimeout:
        return CompanyEmployeeRepositoryException(
          'The employee request took too long to send.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.receiveTimeout:
        return CompanyEmployeeRepositoryException(
          'The employee server took too long to respond.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.connectionError:
        return CompanyEmployeeRepositoryException(
          'Unable to connect to the backend at '
          '${_dio.options.baseUrl}. Ensure the Node server is running.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.badResponse:
        return CompanyEmployeeRepositoryException(
          serverMessage ??
              _messageForStatusCode(statusCode),
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.cancel:
        return CompanyEmployeeRepositoryException(
          'The employee request was cancelled.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.badCertificate:
        return CompanyEmployeeRepositoryException(
          'The backend security certificate is invalid.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.unknown:
        return CompanyEmployeeRepositoryException(
          serverMessage ??
              error.message ??
              'An unknown employee request error occurred.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.transformTimeout:
        return CompanyEmployeeRepositoryException(
          'The employee response processing timed out.',
          statusCode: statusCode,
          responseData: responseData,
        );
    }
  }

  String _messageForStatusCode(
    int? statusCode,
  ) {
    switch (statusCode) {
      case 400:
        return 'The employee request contains invalid information.';
      case 401:
        return 'Your login session is missing or expired.';
      case 403:
        return 'You do not have permission to manage employees.';
      case 404:
        return 'The requested employee record was not found.';
      case 409:
        return 'An employee with the same code, email or username already exists.';
      case 413:
        return 'The selected profile image is too large.';
      case 500:
        return 'The backend could not complete the employee request.';
      default:
        return 'The employee request failed.';
    }
  }

  String? _extractMessage(
    dynamic data,
  ) {
    if (data is String &&
        data.trim().isNotEmpty) {
      return data.trim();
    }

    if (data is Map) {
      for (final String key in <String>[
        'message',
        'error',
        'detail',
      ]) {
        final dynamic value = data[key];

        if (value is String &&
            value.trim().isNotEmpty) {
          return value.trim();
        }

        if (value is Map) {
          final String? nestedMessage =
              _extractMessage(value);

          if (nestedMessage != null) {
            return nestedMessage;
          }
        }
      }

      final dynamic nestedData = data['data'];

      if (nestedData != null) {
        return _extractMessage(nestedData);
      }
    }

    return null;
  }

  String _extractProfileImageUrl(
    dynamic data,
  ) {
    if (data is Map) {
      for (final String key in <String>[
        'profile_image_url',
        'profileImageUrl',
        'image_url',
        'imageUrl',
        'url',
        'relative_url',
      ]) {
        final dynamic value = data[key];

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }

      final dynamic nestedData = data['data'];

      if (nestedData != null) {
        return _extractProfileImageUrl(
          nestedData,
        );
      }
    }

    return '';
  }

  String _toAbsoluteUrl(
    String source,
  ) {
    final String normalized =
        source.trim();

    final Uri? sourceUri =
        Uri.tryParse(normalized);

    if (sourceUri != null &&
        sourceUri.hasScheme) {
      return normalized;
    }

    final Uri baseUri = Uri.parse(
      _dio.options.baseUrl,
    );

    final String authority =
        baseUri.hasPort
            ? '${baseUri.host}:${baseUri.port}'
            : baseUri.host;

    final String origin =
        '${baseUri.scheme}://$authority';

    final String relativePath =
        normalized.startsWith('/')
            ? normalized
            : '/$normalized';

    return '$origin$relativePath';
  }

  String _normalizeFileName(
    String fileName,
  ) {
    final String normalized = fileName
        .trim()
        .replaceAll('\\', '/')
        .split('/')
        .last;

    if (normalized.isEmpty) {
      throw const CompanyEmployeeRepositoryException(
        'The selected image filename is invalid.',
      );
    }

    return normalized;
  }

  String _fileExtension(
    String fileName,
  ) {
    final int dotIndex =
        fileName.lastIndexOf('.');

    if (dotIndex < 0 ||
        dotIndex == fileName.length - 1) {
      return '';
    }

    return fileName
        .substring(dotIndex)
        .toLowerCase();
  }

  String? _mimeTypeForExtension(
    String extension,
  ) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.avif':
        return 'image/avif';
      default:
        return null;
    }
  }

  void _validateEmployeeId(
    int employeeId,
  ) {
    if (employeeId <= 0) {
      throw const CompanyEmployeeRepositoryException(
        'A valid employee ID is required.',
      );
    }
  }
}

class CompanyEmployeeRepositoryException
    implements Exception {
  const CompanyEmployeeRepositoryException(
    this.message, {
    this.statusCode,
    this.responseData,
  });

  final String message;
  final int? statusCode;
  final dynamic responseData;

  @override
  String toString() {
    return message;
  }
}