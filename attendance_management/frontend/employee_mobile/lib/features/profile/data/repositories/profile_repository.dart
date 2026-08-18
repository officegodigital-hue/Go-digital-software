import 'package:dio/dio.dart';
import 'package:employee_mobile/core/network/api_client.dart';
import 'package:employee_mobile/features/profile/data/models/profile_response.dart';

class ProfileRepository {
  ProfileRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  /// Load the currently logged-in employee profile.
  ///
  /// Backend endpoint:
  /// GET /api/v1/auth/me
  Future<EmployeeProfile> getProfile() async {
    try {
      final response = await _dio.get<dynamic>('/auth/me');

      final responseJson = _toMap(response.data);

      if (responseJson == null) {
        throw const ProfileRepositoryException(
          'Invalid employee profile response.',
        );
      }

      _validateApiResponse(responseJson);

      final profileResponse = ProfileResponse.fromJson(responseJson);

      final profile = profileResponse.profile;

      if (profile == null) {
        throw const ProfileRepositoryException(
          'Employee profile details were not found.',
        );
      }

      return profile;
    } on DioException catch (error) {
      throw ProfileRepositoryException(
        _extractDioErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } on ProfileRepositoryException {
      rethrow;
    } catch (error) {
      throw ProfileRepositoryException(
        'Unable to load employee profile: $error',
      );
    }
  }

  /// Reload the current employee profile.
  Future<EmployeeProfile> refreshProfile() async {
    return getProfile();
  }

  void _validateApiResponse(Map<String, dynamic> json) {
    final successValue = json['success'];

    final requestFailed =
        successValue == false ||
        successValue == 0 ||
        successValue?.toString().trim().toLowerCase() == 'false';

    if (!requestFailed) {
      return;
    }

    throw ProfileRepositoryException(
      _extractApiMessage(json) ?? 'Unable to load employee profile.',
    );
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map<String, dynamic>((dynamic key, dynamic item) {
        return MapEntry<String, dynamic>(key.toString(), item);
      });
    }

    return null;
  }

  String? _extractApiMessage(dynamic source) {
    final json = _toMap(source);

    if (json == null) {
      return null;
    }

    final value =
        json['message'] ?? json['error'] ?? json['details'] ?? json['msg'];

    if (value == null || value is Map || value is List) {
      return null;
    }

    final message = value.toString().trim();

    if (message.isEmpty) {
      return null;
    }

    return message;
  }

  String _extractDioErrorMessage(DioException error) {
    final apiMessage = _extractApiMessage(error.response?.data);

    if (apiMessage != null && apiMessage.isNotEmpty) {
      return apiMessage;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Profile request connection timed out.';

      case DioExceptionType.sendTimeout:
        return 'Profile request could not be sent.';

      case DioExceptionType.receiveTimeout:
        return 'Profile server response timed out.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the profile server.';

      case DioExceptionType.cancel:
        return 'Profile request was cancelled.';

      case DioExceptionType.badCertificate:
        return 'Unable to verify the profile server certificate.';

      case DioExceptionType.badResponse:
        return _messageForStatusCode(error.response?.statusCode);

      case DioExceptionType.transformTimeout:
        return 'Profile response processing timed out.';

      case DioExceptionType.unknown:
        return error.message ?? 'An unexpected profile error occurred.';
    }
  }

  String _messageForStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid profile request.';

      case 401:
        return 'Your login session has expired. Please log in again.';

      case 403:
        return 'You do not have permission to view this profile.';

      case 404:
        return 'Employee profile was not found.';

      case 422:
        return 'Profile request validation failed.';

      case 500:
        return 'An unexpected profile server error occurred.';

      case 502:
      case 503:
      case 504:
        return 'Profile service is temporarily unavailable.';

      default:
        return 'Profile request failed with status '
            '${statusCode ?? 'unknown'}.';
    }
  }
}

class ProfileRepositoryException implements Exception {
  const ProfileRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized {
    return statusCode == 401;
  }

  @override
  String toString() {
    return message;
  }
}
