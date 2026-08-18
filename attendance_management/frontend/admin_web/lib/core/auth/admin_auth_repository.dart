import 'package:dio/dio.dart';
import '../constants/api_config.dart';
import 'admin_auth_session.dart';

class AdminAuthRepository {
  AdminAuthRepository({
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: '${ApiConfig.baseUrl}/v1',
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
                headers: const <String, dynamic>{
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<AdminLoginResult> login({
    required String email,
    required String password,
  }) async {
    final String normalizedEmail =
        email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const AdminAuthException(
        'Email address is required.',
      );
    }

    if (password.isEmpty) {
      throw const AdminAuthException(
        'Password is required.',
      );
    }

    try {
      final Response<dynamic> response =
          await _dio.post<dynamic>(
        '/auth/login',
        data: <String, dynamic>{
          'email': normalizedEmail,
          'password': password,
        },
        options: Options(
          contentType:
              Headers.jsonContentType,
        ),
      );

      final dynamic responseData =
          _validatedData(response);

      await AdminAuthSession
          .saveLoginResponse(
        responseData,
      );

      final Map<String, dynamic> data =
          _extractDataMap(
        responseData,
      );

      final Map<String, dynamic> user =
          _asStringMap(
        data['user'],
      );

      final String accessToken =
          _readString(
        data,
        <String>[
          'access_token',
          'accessToken',
          'token',
        ],
      );

      if (accessToken.isEmpty) {
        await AdminAuthSession.clear();

        throw const AdminAuthException(
          'The backend did not return an access token.',
        );
      }

      return AdminLoginResult(
        accessToken: accessToken,
        tokenType: _readString(
          data,
          <String>[
            'token_type',
            'tokenType',
          ],
          fallback: 'Bearer',
        ),
        expiresIn: _readString(
          data,
          <String>[
            'expires_in',
            'expiresIn',
          ],
        ),
        user: user,
      );
    } on AdminAuthException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    } catch (error) {
      throw AdminAuthException(
        'Unable to sign in: $error',
      );
    }
  }

  Future<Map<String, dynamic>>
      getCurrentUser() async {
    final String? accessToken =
        await AdminAuthSession
            .getAccessToken();

    if (accessToken == null ||
        accessToken.trim().isEmpty) {
      throw const AdminAuthException(
        'Authentication token is required.',
        statusCode: 401,
      );
    }

    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>(
        '/auth/me',
        options: Options(
          headers: <String, dynamic>{
            'Authorization':
                'Bearer ${accessToken.trim()}',
          },
        ),
      );

      final dynamic responseData =
          _validatedData(response);

      final Map<String, dynamic> data =
          _extractDataMap(
        responseData,
      );

      final Map<String, dynamic> user =
          _asStringMap(
        data['user'] ?? data,
      );

      if (user.isEmpty) {
        throw const AdminAuthException(
          'The backend did not return the current user.',
        );
      }

      await AdminAuthSession.saveSession(
        accessToken:
            accessToken.trim(),
        tokenType:
            await AdminAuthSession
                .getTokenType(),
        expiresIn:
            await AdminAuthSession
                .getExpiresIn(),
        user: user,
      );

      return user;
    } on AdminAuthException {
      rethrow;
    } on DioException catch (error) {
      if (error.response?.statusCode ==
          401) {
        await AdminAuthSession.clear();
      }

      throw _mapDioException(error);
    } catch (error) {
      throw AdminAuthException(
        'Unable to load the signed-in admin: $error',
      );
    }
  }

  Future<bool> hasActiveSession() async {
    return AdminAuthSession
        .isAuthenticated();
  }

  Future<String?> getAccessToken() async {
    return AdminAuthSession
        .getAccessToken();
  }

  Future<Map<String, dynamic>>
      getSavedUser() async {
    return AdminAuthSession.getUser();
  }

  Future<void> logout() async {
    await AdminAuthSession.clear();
  }

  dynamic _validatedData(
    Response<dynamic> response,
  ) {
    final dynamic data = response.data;

    if (data is Map) {
      final dynamic success =
          data['success'];

      if (success == false) {
        throw AdminAuthException(
          _extractMessage(data) ??
              'The authentication request failed.',
          statusCode:
              response.statusCode,
          responseData: data,
        );
      }
    }

    return data;
  }

  AdminAuthException _mapDioException(
    DioException error,
  ) {
    final int? statusCode =
        error.response?.statusCode;

    final dynamic responseData =
        error.response?.data;

    final String? serverMessage =
        _extractMessage(
      responseData,
    );

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return AdminAuthException(
          'The backend connection timed out.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.sendTimeout:
        return AdminAuthException(
          'The login request took too long to send.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.receiveTimeout:
        return AdminAuthException(
          'The backend took too long to respond.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.connectionError:
        return AdminAuthException(
          'Unable to connect to the backend at '
          '${_dio.options.baseUrl}. Ensure the Node server is running.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.badResponse:
        return AdminAuthException(
          serverMessage ??
              _messageForStatusCode(
                statusCode,
              ),
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.cancel:
        return AdminAuthException(
          'The authentication request was cancelled.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.badCertificate:
        return AdminAuthException(
          'The backend security certificate is invalid.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.unknown:
        return AdminAuthException(
          serverMessage ??
              error.message ??
              'An unknown authentication error occurred.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.transformTimeout:
        return AdminAuthException(
          'The authentication response processing timed out.',
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
        return 'The login request is invalid.';
      case 401:
        return 'Invalid email address or password.';
      case 403:
        return 'This account is inactive or does not have access.';
      case 404:
        return 'The authentication endpoint was not found.';
      case 422:
        return 'Email and password are required.';
      case 500:
        return 'The backend could not complete the login request.';
      default:
        return 'The authentication request failed.';
    }
  }

  Map<String, dynamic> _extractDataMap(
    dynamic response,
  ) {
    final Map<String, dynamic> root =
        _asStringMap(response);

    final Map<String, dynamic> data =
        _asStringMap(
      root['data'],
    );

    return data.isEmpty
        ? root
        : data;
  }

  String? _extractMessage(
    dynamic source,
  ) {
    if (source is String &&
        source.trim().isNotEmpty) {
      return source.trim();
    }

    if (source is Map) {
      for (final String key in <String>[
        'message',
        'error',
        'detail',
      ]) {
        final dynamic value =
            source[key];

        if (value is String &&
            value.trim().isNotEmpty) {
          return value.trim();
        }

        if (value is Map) {
          final String? nested =
              _extractMessage(value);

          if (nested != null) {
            return nested;
          }
        }
      }

      if (source.containsKey('data')) {
        return _extractMessage(
          source['data'],
        );
      }
    }

    return null;
  }

  Map<String, dynamic> _asStringMap(
    dynamic source,
  ) {
    if (source
        is Map<String, dynamic>) {
      return source;
    }

    if (source is Map) {
      return source.map<String, dynamic>(
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

    return <String, dynamic>{};
  }

  String _readString(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final String key in keys) {
      final dynamic value =
          source[key];

      if (value == null) {
        continue;
      }

      final String normalized =
          value.toString().trim();

      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return fallback;
  }
}

class AdminLoginResult {
  const AdminLoginResult({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final String expiresIn;
  final Map<String, dynamic> user;

  String get userName {
    return _readUserValue(
      <String>[
        'name',
        'full_name',
        'fullName',
      ],
    );
  }

  String get email {
    return _readUserValue(
      <String>[
        'email',
      ],
    );
  }

  String get role {
    return _readUserValue(
      <String>[
        'role',
      ],
    );
  }

  String get employeeCode {
    return _readUserValue(
      <String>[
        'employee_code',
        'employeeCode',
      ],
    );
  }

  String _readUserValue(
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic value =
          user[key];

      if (value == null) {
        continue;
      }

      final String normalized =
          value.toString().trim();

      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return '';
  }
}

class AdminAuthException
    implements Exception {
  const AdminAuthException(
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