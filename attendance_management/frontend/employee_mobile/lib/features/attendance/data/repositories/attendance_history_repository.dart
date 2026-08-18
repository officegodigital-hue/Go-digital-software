import 'package:dio/dio.dart';
import 'package:employee_mobile/core/constants/api_constants.dart';
import 'package:employee_mobile/core/network/api_client.dart';
import 'package:employee_mobile/features/attendance/data/models/attendance_history_response.dart';

class AttendanceHistoryRepository {
  AttendanceHistoryRepository({
    Dio? dio,
  }) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<AttendanceHistoryResponse>
      getAttendanceHistory({
    String? month,
  }) async {
    try {
      final normalizedMonth = month?.trim();

      final response = await _dio.get<dynamic>(
        ApiConstants.attendanceHistory,
        queryParameters:
            normalizedMonth == null ||
                    normalizedMonth.isEmpty
                ? null
                : <String, dynamic>{
                    'month': normalizedMonth,
                  },
      );

      return _parseResponse(response.data);
    } on AttendanceHistoryRepositoryException {
      rethrow;
    } on DioException catch (error) {
      throw AttendanceHistoryRepositoryException(
        _messageFromDioException(error),
      );
    } catch (_) {
      throw const AttendanceHistoryRepositoryException(
        'Unable to load attendance history.',
      );
    }
  }

  AttendanceHistoryResponse _parseResponse(
    Object? responseData,
  ) {
    if (responseData is! Map) {
      throw const AttendanceHistoryRepositoryException(
        'Invalid response received from the server.',
      );
    }

    final json = Map<String, dynamic>.from(
      responseData,
    );

    final parsedResponse =
        AttendanceHistoryResponse.fromJson(json);

    if (!parsedResponse.success) {
      final message =
          parsedResponse.message.trim();

      throw AttendanceHistoryRepositoryException(
        message.isEmpty
            ? 'Attendance history request failed.'
            : message,
      );
    }

    if (parsedResponse.data == null) {
      throw const AttendanceHistoryRepositoryException(
        'Attendance history details were not received.',
      );
    }

    return parsedResponse;
  }

  String _messageFromDioException(
    DioException error,
  ) {
    final serverMessage = _extractServerMessage(
      error.response?.data,
    );

    if (serverMessage != null) {
      return serverMessage;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Please try again.';

      case DioExceptionType.sendTimeout:
        return 'The history request took too long to send.';

      case DioExceptionType.receiveTimeout:
        return 'The server took too long to return attendance history.';

      case DioExceptionType.transformTimeout:
        return 'The server response took too long to process.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the attendance server. Check whether the backend is running.';

      case DioExceptionType.badResponse:
        return _messageForStatusCode(
          error.response?.statusCode,
        );

      case DioExceptionType.cancel:
        return 'The attendance history request was cancelled.';

      case DioExceptionType.badCertificate:
        return 'The server security certificate is invalid.';

      case DioExceptionType.unknown:
        return 'An unexpected attendance history error occurred.';
    }
  }

  String? _extractServerMessage(
    Object? responseData,
  ) {
    if (responseData is! Map) {
      return null;
    }

    final json = Map<String, dynamic>.from(
      responseData,
    );

    final message = json['message'];

    if (message is String &&
        message.trim().isNotEmpty) {
      return message.trim();
    }

    final errorData = json['error'];

    if (errorData is Map) {
      final errorJson =
          Map<String, dynamic>.from(
        errorData,
      );

      final errorMessage =
          errorJson['message'];

      if (errorMessage is String &&
          errorMessage.trim().isNotEmpty) {
        return errorMessage.trim();
      }
    }

    return null;
  }

  String _messageForStatusCode(
    int? statusCode,
  ) {
    switch (statusCode) {
      case 400:
        return 'Invalid attendance-history request.';

      case 401:
        return 'Your login session has expired. Please sign in again.';

      case 403:
        return 'You are not permitted to view this attendance history.';

      case 404:
        return 'The attendance-history API was not found.';

      case 422:
        return 'Enter the month using YYYY-MM format.';

      case 429:
        return 'Too many requests. Please wait and try again.';

      case 500:
      case 502:
      case 503:
        return 'The attendance server is temporarily unavailable.';

      default:
        return 'Unable to fetch attendance history.';
    }
  }
}

class AttendanceHistoryRepositoryException
    implements Exception {
  const AttendanceHistoryRepositoryException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}