import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/token_storage_service.dart';
import '../models/login_response.dart';

class AuthRepository {
  AuthRepository({Dio? dio, TokenStorageService? tokenStorageService})
    : _dio = dio ?? ApiClient.instance.dio,
      _tokenStorageService =
          tokenStorageService ?? TokenStorageService.instance;

  final Dio _dio;
  final TokenStorageService _tokenStorageService;

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      throw const AuthRepositoryException('Email address is required.');
    }

    if (password.isEmpty) {
      throw const AuthRepositoryException('Password is required.');
    }

    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.login,
        data: <String, dynamic>{'email': normalizedEmail, 'password': password},
      );

      final responseJson = _toJsonMap(response.data);

      final loginResponse = LoginResponse.fromJson(responseJson);

      final accessToken = loginResponse.accessToken.trim();

      if (accessToken.isEmpty) {
        throw const AuthRepositoryException(
          'The server did not return an access token.',
        );
      }

      await _tokenStorageService.saveAccessToken(accessToken);

      return loginResponse;
    } on AuthRepositoryException {
      rethrow;
    } on DioException catch (error) {
      throw AuthRepositoryException(_messageFromDioException(error));
    } catch (error) {
      throw const AuthRepositoryException(
        'Unable to sign in. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    try {
      await _tokenStorageService.deleteAccessToken();
    } catch (error) {
      throw const AuthRepositoryException(
        'Unable to sign out. Please try again.',
      );
    }
  }

  Future<String?> getSavedAccessToken() async {
    try {
      return await _tokenStorageService.getAccessToken();
    } catch (error) {
      return null;
    }
  }

  Future<bool> hasSavedSession() async {
    final token = await getSavedAccessToken();

    return token != null && token.trim().isNotEmpty;
  }

  Map<String, dynamic> _toJsonMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const AuthRepositoryException(
      'Invalid response received from the server.',
    );
  }

  String _messageFromDioException(DioException error) {
    final serverMessage = _extractServerMessage(error.response?.data);

    if (serverMessage != null) {
      return serverMessage;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Please try again.';

      case DioExceptionType.sendTimeout:
        return 'The login request took too long to send.';

      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond.';

      case DioExceptionType.transformTimeout:
        return 'The server response took too long to process.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Check whether the backend is running.';

      case DioExceptionType.badResponse:
        return _messageFromStatusCode(error.response?.statusCode);

      case DioExceptionType.cancel:
        return 'The login request was cancelled.';

      case DioExceptionType.badCertificate:
        return 'The server security certificate is invalid.';

      case DioExceptionType.unknown:
        return 'An unexpected login error occurred.';
    }
  }

  String? _extractServerMessage(Object? responseData) {
    if (responseData is! Map) {
      return null;
    }

    final json = Map<String, dynamic>.from(responseData);

    final message = json['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final error = json['error'];

    if (error is Map) {
      final errorJson = Map<String, dynamic>.from(error);

      final errorMessage = errorJson['message'];

      if (errorMessage is String && errorMessage.trim().isNotEmpty) {
        return errorMessage.trim();
      }
    }

    return null;
  }

  String _messageFromStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Please enter a valid email address and password.';

      case 401:
        return 'Incorrect email address or password.';

      case 403:
        return 'Your account does not have permission to sign in.';

      case 404:
        return 'The login service was not found.';

      case 409:
        return 'This login request could not be completed.';

      case 422:
        return 'Please check the login information and try again.';

      case 429:
        return 'Too many login attempts. Please wait and try again.';

      case 500:
      case 502:
      case 503:
        return 'The server is temporarily unavailable. Please try again.';

      default:
        return 'Login failed. Please try again.';
    }
  }
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
