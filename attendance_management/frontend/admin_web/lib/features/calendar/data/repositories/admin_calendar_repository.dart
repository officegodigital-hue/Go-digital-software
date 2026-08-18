import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/auth/admin_auth_session.dart';
import '../models/admin_holiday_models.dart';
import '../../../../core/constants/api_config.dart';
typedef AdminCalendarAccessTokenProvider =
    FutureOr<String?> Function();

class AdminCalendarRepository {
  AdminCalendarRepository({
    Dio? dio,
    this._accessTokenProvider,
  }) : _dio =
            dio ??
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

  static const String _endpoint = '/admin/calendar';

  final Dio _dio;

  final AdminCalendarAccessTokenProvider?
      _accessTokenProvider;

  Future<AdminHolidayCalendarPage> getCalendar({
    int? year,
    int? month,
    DateTime? fromDate,
    DateTime? toDate,
    String search = '',
    String holidayType = 'all',
    bool upcoming = false,
    bool includeInactive = false,
    CancelToken? cancelToken,
  }) async {
    _validateCalendarFilters(
      year: year,
      month: month,
      fromDate: fromDate,
      toDate: toDate,
    );

    final Map<String, dynamic> queryParameters =
        <String, dynamic>{
      'year': ?year,
      'month': ?month,
      if (fromDate != null)
        'from_date': _formatDate(fromDate),
      if (toDate != null)
        'to_date': _formatDate(toDate),
      if (search.trim().isNotEmpty)
        'search': search.trim(),
      if (holidayType.trim().isNotEmpty &&
          holidayType.trim().toLowerCase() != 'all')
        'type': holidayType.trim().toLowerCase(),
      if (upcoming) 'upcoming': true,
      if (includeInactive)
        'include_inactive': true,
    };

    final dynamic responseData =
        await _executeRequest(
      () async {
        return _dio.get<dynamic>(
          _endpoint,
          queryParameters: queryParameters,
          options: await _authorizedOptions(),
          cancelToken: cancelToken,
        );
      },
    );

    final Map<String, dynamic> payload =
        _extractCalendarPayload(
      responseData,
    );

    return AdminHolidayCalendarPage.fromJson(
      payload,
    );
  }

  Future<AdminHolidayCalendarPage>
      fetchCalendar({
    int? year,
    int? month,
    DateTime? fromDate,
    DateTime? toDate,
    String search = '',
    String holidayType = 'all',
    bool upcoming = false,
    bool includeInactive = false,
    CancelToken? cancelToken,
  }) {
    return getCalendar(
      year: year,
      month: month,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
      holidayType: holidayType,
      upcoming: upcoming,
      includeInactive: includeInactive,
      cancelToken: cancelToken,
    );
  }

  Future<AdminHoliday> getHolidayById({
    required int holidayId,
    CancelToken? cancelToken,
  }) async {
    _validateHolidayId(holidayId);

    final dynamic responseData =
        await _executeRequest(
      () async {
        return _dio.get<dynamic>(
          '$_endpoint/$holidayId',
          options: await _authorizedOptions(),
          cancelToken: cancelToken,
        );
      },
    );

    final Map<String, dynamic> payload =
        _extractHolidayPayload(
      responseData,
    );

    return AdminHoliday.fromJson(payload);
  }

  Future<AdminHoliday> createHoliday({
    required AdminHolidayPayload payload,
    CancelToken? cancelToken,
  }) async {
    _validateHolidayPayload(payload);

    final dynamic responseData =
        await _executeRequest(
      () async {
        return _dio.post<dynamic>(
          _endpoint,
          data: payload.toJson(),
          options: await _authorizedOptions(),
          cancelToken: cancelToken,
        );
      },
    );

    final Map<String, dynamic> holidayPayload =
        _extractHolidayPayload(
      responseData,
    );

    return AdminHoliday.fromJson(
      holidayPayload,
    );
  }

  Future<AdminHoliday> updateHoliday({
    required int holidayId,
    required AdminHolidayPayload payload,
    CancelToken? cancelToken,
  }) async {
    _validateHolidayId(holidayId);
    _validateHolidayPayload(payload);

    final dynamic responseData =
        await _executeRequest(
      () async {
        return _dio.put<dynamic>(
          '$_endpoint/$holidayId',
          data: payload.toJson(),
          options: await _authorizedOptions(),
          cancelToken: cancelToken,
        );
      },
    );

    final Map<String, dynamic> holidayPayload =
        _extractHolidayPayload(
      responseData,
    );

    return AdminHoliday.fromJson(
      holidayPayload,
    );
  }

  Future<AdminHoliday> patchHoliday({
    required int holidayId,
    required Map<String, dynamic> changes,
    CancelToken? cancelToken,
  }) async {
    _validateHolidayId(holidayId);

    if (changes.isEmpty) {
      throw const AdminCalendarRepositoryException(
        'At least one holiday field must be provided.',
      );
    }

    final dynamic responseData =
        await _executeRequest(
      () async {
        return _dio.patch<dynamic>(
          '$_endpoint/$holidayId',
          data: changes,
          options: await _authorizedOptions(),
          cancelToken: cancelToken,
        );
      },
    );

    final Map<String, dynamic> holidayPayload =
        _extractHolidayPayload(
      responseData,
    );

    return AdminHoliday.fromJson(
      holidayPayload,
    );
  }

  Future<void> deleteHoliday({
    required int holidayId,
    CancelToken? cancelToken,
  }) async {
    _validateHolidayId(holidayId);

    await _executeRequest(
      () async {
        return _dio.delete<dynamic>(
          '$_endpoint/$holidayId',
          options: await _authorizedOptions(),
          cancelToken: cancelToken,
        );
      },
    );
  }

  Future<Options> _authorizedOptions() async {
    final AdminCalendarAccessTokenProvider
        tokenProvider =
        _accessTokenProvider ??
        AdminAuthSession.getAccessToken;

    final String? token =
        await tokenProvider();

    final String normalizedToken =
        token?.trim() ?? '';

    if (normalizedToken.isEmpty) {
      throw const AdminCalendarRepositoryException(
        'Your admin login session is missing. Please log in again.',
        statusCode: 401,
      );
    }

    return Options(
      contentType: Headers.jsonContentType,
      headers: <String, dynamic>{
        'Accept': 'application/json',
        'Authorization':
            'Bearer $normalizedToken',
      },
    );
  }

  Future<dynamic> _executeRequest(
    Future<Response<dynamic>> Function()
        request,
  ) async {
    try {
      final Response<dynamic> response =
          await request();

      return _validatedResponseData(
        response,
      );
    } on AdminCalendarRepositoryException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException catch (error) {
      throw AdminCalendarRepositoryException(
        error.message,
      );
    } catch (error) {
      throw AdminCalendarRepositoryException(
        'Unexpected calendar request error: $error',
      );
    }
  }

  dynamic _validatedResponseData(
    Response<dynamic> response,
  ) {
    final dynamic data = response.data;

    if (data is Map) {
      final dynamic success =
          data['success'];

      if (success == false) {
        throw AdminCalendarRepositoryException(
          _extractMessage(data) ??
              'The calendar request failed.',
          statusCode: response.statusCode,
          responseData: data,
        );
      }
    }

    return data;
  }

  Map<String, dynamic>
      _extractCalendarPayload(
    dynamic data,
  ) {
    if (data is Map) {
      final Map<String, dynamic> normalized =
          Map<String, dynamic>.from(data);

      if (_looksLikeCalendarPayload(
        normalized,
      )) {
        return normalized;
      }

      for (final String key
          in <String>[
        'data',
        'result',
        'payload',
      ]) {
        final dynamic nested =
            normalized[key];

        if (nested == null) {
          continue;
        }

        try {
          return _extractCalendarPayload(
            nested,
          );
        } on AdminCalendarRepositoryException {
          // Continue to the next supported wrapper.
        }
      }
    }

    throw AdminCalendarRepositoryException(
      'The calendar server returned an invalid response.',
      responseData: data,
    );
  }

  Map<String, dynamic>
      _extractHolidayPayload(
    dynamic data,
  ) {
    if (data is Map) {
      final Map<String, dynamic> normalized =
          Map<String, dynamic>.from(data);

      if (_looksLikeHolidayPayload(
        normalized,
      )) {
        return normalized;
      }

      for (final String key
          in <String>[
        'data',
        'result',
        'holiday',
        'payload',
      ]) {
        final dynamic nested =
            normalized[key];

        if (nested == null) {
          continue;
        }

        try {
          return _extractHolidayPayload(
            nested,
          );
        } on AdminCalendarRepositoryException {
          // Continue to the next supported wrapper.
        }
      }
    }

    throw AdminCalendarRepositoryException(
      'The holiday server returned an invalid response.',
      responseData: data,
    );
  }

  bool _looksLikeCalendarPayload(
    Map<String, dynamic> data,
  ) {
    return data.containsKey('holidays') ||
        data.containsKey('records') ||
        data.containsKey('items') ||
        data.containsKey('filters');
  }

  bool _looksLikeHolidayPayload(
    Map<String, dynamic> data,
  ) {
    return data.containsKey('holiday_name') ||
        data.containsKey('holidayName') ||
        data.containsKey('holiday_date') ||
        data.containsKey('holidayDate');
  }

  AdminCalendarRepositoryException
      _mapDioException(
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
        return AdminCalendarRepositoryException(
          'The calendar server connection timed out.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.sendTimeout:
        return AdminCalendarRepositoryException(
          'The calendar request took too long to send.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.receiveTimeout:
        return AdminCalendarRepositoryException(
          'The calendar server took too long to respond.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.connectionError:
        return AdminCalendarRepositoryException(
          'Unable to connect to the backend at '
          '${_dio.options.baseUrl}. Ensure the Node server is running.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.badResponse:
        return AdminCalendarRepositoryException(
          serverMessage ??
              _messageForStatusCode(
                statusCode,
              ),
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.cancel:
        return AdminCalendarRepositoryException(
          'The calendar request was cancelled.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.badCertificate:
        return AdminCalendarRepositoryException(
          'The backend security certificate is invalid.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.unknown:
        return AdminCalendarRepositoryException(
          serverMessage ??
              error.message ??
              'An unknown calendar request error occurred.',
          statusCode: statusCode,
          responseData: responseData,
        );

      case DioExceptionType.transformTimeout:
        return AdminCalendarRepositoryException(
          'Calendar response processing timed out.',
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
        return 'The holiday information is invalid.';
      case 401:
        return 'Your admin login session is missing or expired.';
      case 403:
        return 'You do not have permission to manage holidays.';
      case 404:
        return 'The holiday or calendar endpoint was not found.';
      case 409:
        return 'A holiday with the same name and date already exists.';
      case 500:
        return 'The backend could not process the holiday request.';
      default:
        return 'The calendar request failed.';
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

  void _validateCalendarFilters({
    required int? year,
    required int? month,
    required DateTime? fromDate,
    required DateTime? toDate,
  }) {
    if (year != null &&
        (year < 2000 || year > 2200)) {
      throw const AdminCalendarRepositoryException(
        'Calendar year must be between 2000 and 2200.',
      );
    }

    if (month != null &&
        (month < 1 || month > 12)) {
      throw const AdminCalendarRepositoryException(
        'Calendar month must be between 1 and 12.',
      );
    }

    if (fromDate != null &&
        toDate != null &&
        _dateOnly(fromDate).isAfter(
          _dateOnly(toDate),
        )) {
      throw const AdminCalendarRepositoryException(
        'The start date cannot be after the end date.',
      );
    }
  }

  void _validateHolidayPayload(
    AdminHolidayPayload payload,
  ) {
    if (payload.holidayName.trim().isEmpty) {
      throw const AdminCalendarRepositoryException(
        'Holiday name is required.',
      );
    }

    if (payload.holidayName.trim().length >
        150) {
      throw const AdminCalendarRepositoryException(
        'Holiday name cannot exceed 150 characters.',
      );
    }

    const Set<String> supportedTypes =
        <String>{
      'public',
      'optional',
      'company',
      'regional',
    };

    if (!supportedTypes.contains(
      payload.holidayType.trim().toLowerCase(),
    )) {
      throw const AdminCalendarRepositoryException(
        'Holiday type must be public, optional, company, or regional.',
      );
    }

    if (payload.description.trim().length >
        500) {
      throw const AdminCalendarRepositoryException(
        'Holiday description cannot exceed 500 characters.',
      );
    }
  }

  void _validateHolidayId(
    int holidayId,
  ) {
    if (holidayId <= 0) {
      throw const AdminCalendarRepositoryException(
        'Holiday ID must be greater than zero.',
      );
    }
  }

  DateTime _dateOnly(
    DateTime value,
  ) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  String _formatDate(
    DateTime value,
  ) {
    final String month =
        value.month.toString().padLeft(2, '0');

    final String day =
        value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }
}

class AdminCalendarRepositoryException
    implements Exception {
  const AdminCalendarRepositoryException(
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