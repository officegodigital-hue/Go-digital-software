import 'dart:async';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_config.dart';
import '../../../../core/auth/admin_auth_session.dart';
import '../models/admin_attendance_models.dart';

typedef AdminAttendanceAccessTokenProvider =
    FutureOr<String?> Function();

class AdminAttendanceRepository {
  AdminAttendanceRepository({
    Dio? dio,
    this._accessTokenProvider,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: '${ApiConfig.baseUrl}/v1',
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                responseType: ResponseType.json,
                headers: const <String, dynamic>{
                  'Accept': 'application/json',
                },
              ),
            );

  static const String _endpoint = '/admin/attendance';

  final Dio _dio;

  final AdminAttendanceAccessTokenProvider?
      _accessTokenProvider;

  Future<AdminAttendancePage>
      getAttendanceLog({
    int page = 1,
    int limit = 20,
    DateTime? fromDate,
    DateTime? toDate,
    String search = '',
    String status = 'all',
    String sessionStatus = 'all',
    CancelToken? cancelToken,
  }) async {
    _validatePagination(
      page: page,
      limit: limit,
    );

    _validateDateRange(
      fromDate: fromDate,
      toDate: toDate,
    );

    final Map<String, dynamic>
        queryParameters =
        _buildQueryParameters(
      page: page,
      limit: limit,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
      status: status,
      sessionStatus: sessionStatus,
      export: false,
    );

    final dynamic responseData =
        await _executeRequest(
      () async {
        return _dio.get<dynamic>(
          _endpoint,
          queryParameters:
              queryParameters,
          options:
              await _authorizedOptions(),
          cancelToken: cancelToken,
        );
      },
    );

    final Map<String, dynamic>
        attendancePayload =
        _extractAttendancePayload(
      responseData,
    );

    return AdminAttendancePage.fromJson(
      attendancePayload,
    );
  }

  Future<AdminAttendancePage>
      fetchAttendanceLog({
    int page = 1,
    int limit = 20,
    DateTime? fromDate,
    DateTime? toDate,
    String search = '',
    String status = 'all',
    String sessionStatus = 'all',
    CancelToken? cancelToken,
  }) {
    return getAttendanceLog(
      page: page,
      limit: limit,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
      status: status,
      sessionStatus: sessionStatus,
      cancelToken: cancelToken,
    );
  }

  Future<List<AdminAttendanceRecord>>
      getAttendanceExportRecords({
    DateTime? fromDate,
    DateTime? toDate,
    String search = '',
    String status = 'all',
    String sessionStatus = 'all',
    CancelToken? cancelToken,
  }) async {
    _validateDateRange(
      fromDate: fromDate,
      toDate: toDate,
    );

    final Map<String, dynamic>
        queryParameters =
        _buildQueryParameters(
      page: 1,
      limit: 100,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
      status: status,
      sessionStatus: sessionStatus,
      export: true,
    );

    final dynamic responseData =
        await _executeRequest(
      () async {
        return _dio.get<dynamic>(
          _endpoint,
          queryParameters:
              queryParameters,
          options:
              await _authorizedOptions(),
          cancelToken: cancelToken,
        );
      },
    );

    final Map<String, dynamic>
        attendancePayload =
        _extractAttendancePayload(
      responseData,
    );

    return AdminAttendancePage.fromJson(
      attendancePayload,
    ).records;
  }

  Future<List<AdminAttendanceRecord>>
      fetchExportRecords({
    DateTime? fromDate,
    DateTime? toDate,
    String search = '',
    String status = 'all',
    String sessionStatus = 'all',
    CancelToken? cancelToken,
  }) {
    return getAttendanceExportRecords(
      fromDate: fromDate,
      toDate: toDate,
      search: search,
      status: status,
      sessionStatus: sessionStatus,
      cancelToken: cancelToken,
    );
  }

  Map<String, dynamic>
      _buildQueryParameters({
    required int page,
    required int limit,
    required DateTime? fromDate,
    required DateTime? toDate,
    required String search,
    required String status,
    required String sessionStatus,
    required bool export,
  }) {
    final String normalizedSearch =
        search.trim();

    final String normalizedStatus =
        status.trim().toLowerCase();

    final String
        normalizedSessionStatus =
        sessionStatus
            .trim()
            .toLowerCase();

    return <String, dynamic>{
      'page': page,
      'limit': limit,
      if (fromDate != null)
        'from_date':
            _formatDate(fromDate),
      if (toDate != null)
        'to_date':
            _formatDate(toDate),
      if (normalizedSearch.isNotEmpty)
        'search':
            normalizedSearch,
      if (normalizedStatus.isNotEmpty &&
          normalizedStatus != 'all')
        'status':
            normalizedStatus,
      if (normalizedSessionStatus
              .isNotEmpty &&
          normalizedSessionStatus != 'all')
        'session_status':
            normalizedSessionStatus,
      if (export) 'export': true,
    };
  }

  Future<Options>
      _authorizedOptions() async {
    final AdminAttendanceAccessTokenProvider
        tokenProvider =
        _accessTokenProvider ??
            AdminAuthSession
                .getAccessToken;

    final String? token =
        await tokenProvider();

    final String normalizedToken =
        token?.trim() ?? '';

    if (normalizedToken.isEmpty) {
      throw const AdminAttendanceRepositoryException(
        'Your admin login session is missing. Please log in again.',
        statusCode: 401,
      );
    }

    return Options(
      contentType:
          Headers.jsonContentType,
      headers: <String, dynamic>{
        'Accept':
            'application/json',
        'Authorization':
            'Bearer $normalizedToken',
      },
    );
  }

  Future<dynamic> _executeRequest(
    Future<Response<dynamic>>
        Function() request,
  ) async {
    try {
      final Response<dynamic> response =
          await request();

      return _validatedResponseData(
        response,
      );
    } on AdminAttendanceRepositoryException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException catch (error) {
      throw AdminAttendanceRepositoryException(
        error.message,
      );
    } catch (error) {
      throw AdminAttendanceRepositoryException(
        'Unexpected attendance request error: $error',
      );
    }
  }

  dynamic _validatedResponseData(
    Response<dynamic> response,
  ) {
    final dynamic data =
        response.data;

    if (data is Map) {
      final dynamic success =
          data['success'];

      if (success == false) {
        throw AdminAttendanceRepositoryException(
          _extractMessage(data) ??
              'The attendance request failed.',
          statusCode:
              response.statusCode,
          responseData: data,
        );
      }
    }

    return data;
  }

  Map<String, dynamic>
      _extractAttendancePayload(
    dynamic data,
  ) {
    if (data is Map) {
      final Map<String, dynamic>
          normalized =
          Map<String, dynamic>.from(
        data,
      );

      if (_looksLikeAttendancePayload(
        normalized,
      )) {
        return normalized;
      }

      final dynamic nestedData =
          normalized['data'];

      if (nestedData != null) {
        final Map<String, dynamic>
            nestedPayload =
            _extractAttendancePayload(
          nestedData,
        );

        if (nestedPayload.isNotEmpty) {
          return nestedPayload;
        }
      }

      final dynamic result =
          normalized['result'];

      if (result != null) {
        final Map<String, dynamic>
            resultPayload =
            _extractAttendancePayload(
          result,
        );

        if (resultPayload.isNotEmpty) {
          return resultPayload;
        }
      }
    }

    throw AdminAttendanceRepositoryException(
      'The attendance server returned an invalid response.',
      responseData: data,
    );
  }

  bool _looksLikeAttendancePayload(
    Map<String, dynamic> data,
  ) {
    return data.containsKey('records') ||
        data.containsKey(
          'attendance_records',
        ) ||
        data.containsKey(
          'attendanceRecords',
        ) ||
        data.containsKey('pagination') ||
        data.containsKey('summary');
  }

  AdminAttendanceRepositoryException
      _mapDioException(
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
      case DioExceptionType
            .connectionTimeout:
        return AdminAttendanceRepositoryException(
          'The attendance server connection timed out.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.sendTimeout:
        return AdminAttendanceRepositoryException(
          'The attendance request took too long to send.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType
            .receiveTimeout:
        return AdminAttendanceRepositoryException(
          'The attendance server took too long to respond.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType
            .connectionError:
        return AdminAttendanceRepositoryException(
          'Unable to connect to the backend at '
          '${_dio.options.baseUrl}. Ensure the Node server is running.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.badResponse:
        return AdminAttendanceRepositoryException(
          serverMessage ??
              _messageForStatusCode(
                statusCode,
              ),
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.cancel:
        return AdminAttendanceRepositoryException(
          'The attendance request was cancelled.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType
            .badCertificate:
        return AdminAttendanceRepositoryException(
          'The backend security certificate is invalid.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.unknown:
        return AdminAttendanceRepositoryException(
          serverMessage ??
              error.message ??
              'An unknown attendance request error occurred.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType
            .transformTimeout:
        return AdminAttendanceRepositoryException(
          'Attendance response processing timed out.',
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
        return 'The attendance filters contain invalid information.';
      case 401:
        return 'Your admin login session is missing or expired.';
      case 403:
        return 'You do not have permission to view attendance records.';
      case 404:
        return 'The Admin Attendance endpoint was not found.';
      case 500:
        return 'The backend could not load attendance records.';
      default:
        return 'The attendance request failed.';
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
      for (final String key
          in <String>[
        'message',
        'detail',
        'error',
      ]) {
        final dynamic value =
            data[key];

        if (value is String &&
            value.trim().isNotEmpty) {
          return value.trim();
        }

        if (value is Map) {
          final String?
              nestedMessage =
              _extractMessage(value);

          if (nestedMessage != null) {
            return nestedMessage;
          }
        }
      }

      final dynamic nestedData =
          data['data'];

      if (nestedData != null) {
        return _extractMessage(
          nestedData,
        );
      }
    }

    return null;
  }

  void _validatePagination({
    required int page,
    required int limit,
  }) {
    if (page <= 0) {
      throw const AdminAttendanceRepositoryException(
        'Attendance page must be greater than zero.',
      );
    }

    if (limit <= 0 || limit > 100) {
      throw const AdminAttendanceRepositoryException(
        'Attendance page size must be between 1 and 100.',
      );
    }
  }

  void _validateDateRange({
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    if (fromDate == null ||
        toDate == null) {
      return;
    }

    final DateTime normalizedFrom =
        DateTime(
      fromDate.year,
      fromDate.month,
      fromDate.day,
    );

    final DateTime normalizedTo =
        DateTime(
      toDate.year,
      toDate.month,
      toDate.day,
    );

    if (normalizedFrom.isAfter(
      normalizedTo,
    )) {
      throw const AdminAttendanceRepositoryException(
        'The start date cannot be after the end date.',
      );
    }
  }

  String _formatDate(
    DateTime value,
  ) {
    final String month =
        value.month
            .toString()
            .padLeft(2, '0');

    final String day =
        value.day
            .toString()
            .padLeft(2, '0');

    return '${value.year}-$month-$day';
  }
}

class AdminAttendanceRepositoryException
    implements Exception {
  const AdminAttendanceRepositoryException(
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