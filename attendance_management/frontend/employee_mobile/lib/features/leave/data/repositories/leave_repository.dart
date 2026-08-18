import 'package:dio/dio.dart';
import 'package:employee_mobile/core/constants/api_constants.dart';
import 'package:employee_mobile/core/network/api_client.dart';
import 'package:employee_mobile/features/leave/data/models/apply_leave_response.dart';
import 'package:employee_mobile/features/leave/data/models/cancel_leave_response.dart';
import 'package:employee_mobile/features/leave/data/models/leave_dashboard_response.dart';
import 'package:employee_mobile/features/leave/data/models/leave_history_response.dart';

class LeaveRepository {
  LeaveRepository({
    Dio? dio,
  }) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<LeaveDashboardResponse> getLeaveDashboard({
    int? year,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};

      if (year != null) {
        queryParameters['year'] = year;
      }

      final response = await _dio.get<dynamic>(
        ApiConstants.leaveDashboard,
        queryParameters: queryParameters,
      );

      return LeaveDashboardResponse.fromJson(
        _toMap(response.data),
      );
    } on DioException catch (error) {
      throw LeaveRepositoryException(
        message: _extractErrorMessage(error),
        statusCode: error.response?.statusCode,
        code: _extractErrorCode(error),
      );
    } catch (error) {
      throw LeaveRepositoryException(
        message:
            'Unable to load leave dashboard: $error',
      );
    }
  }

  Future<LeaveHistoryResponse> getLeaveHistory({
    int? year,
    String? status,
  }) async {
    try {
      final normalizedStatus =
          status?.trim().toLowerCase();

      final queryParameters = <String, dynamic>{};

      if (year != null) {
        queryParameters['year'] = year;
      }

      if (normalizedStatus != null &&
          normalizedStatus.isNotEmpty) {
        queryParameters['status'] =
            normalizedStatus;
      }

      final response = await _dio.get<dynamic>(
        ApiConstants.leaveHistory,
        queryParameters: queryParameters,
      );

      return LeaveHistoryResponse.fromJson(
        _toMap(response.data),
      );
    } on DioException catch (error) {
      throw LeaveRepositoryException(
        message: _extractErrorMessage(error),
        statusCode: error.response?.statusCode,
        code: _extractErrorCode(error),
      );
    } catch (error) {
      throw LeaveRepositoryException(
        message:
            'Unable to load leave history: $error',
      );
    }
  }

  Future<ApplyLeaveResponse> applyLeave({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    required String dayType,
    required String reason,
    String? attachmentUrl,
  }) async {
    try {
      final normalizedAttachment =
          attachmentUrl?.trim();

      final response =
          await _dio.post<dynamic>(
        ApiConstants.leaveApply,
        data: <String, dynamic>{
          'leave_type_id': leaveTypeId,
          'start_date': startDate,
          'end_date': endDate,
          'day_type': dayType,
          'reason': reason.trim(),
          'attachment_url':
              normalizedAttachment == null ||
                      normalizedAttachment.isEmpty
                  ? null
                  : normalizedAttachment,
        },
      );

      return ApplyLeaveResponse.fromJson(
        _toMap(response.data),
      );
    } on DioException catch (error) {
      throw LeaveRepositoryException(
        message: _extractErrorMessage(error),
        statusCode: error.response?.statusCode,
        code: _extractErrorCode(error),
      );
    } catch (error) {
      throw LeaveRepositoryException(
        message:
            'Unable to submit leave request: $error',
      );
    }
  }

  Future<CancelLeaveResponse> cancelLeave({
    required int leaveRequestId,
    required String cancellationReason,
  }) async {
    try {
      final response =
          await _dio.patch<dynamic>(
        ApiConstants.leaveCancel(
          leaveRequestId,
        ),
        data: <String, dynamic>{
          'cancellation_reason':
              cancellationReason.trim(),
        },
      );

      return CancelLeaveResponse.fromJson(
        _toMap(response.data),
      );
    } on DioException catch (error) {
      throw LeaveRepositoryException(
        message: _extractErrorMessage(error),
        statusCode: error.response?.statusCode,
        code: _extractErrorCode(error),
      );
    } catch (error) {
      throw LeaveRepositoryException(
        message:
            'Unable to cancel leave request: $error',
      );
    }
  }
}

class LeaveRepositoryException
    implements Exception {
  const LeaveRepositoryException({
    required this.message,
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() {
    return message;
  }
}

Map<String, dynamic> _toMap(
  dynamic value,
) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(
      value,
    );
  }

  return <String, dynamic>{};
}

String _extractErrorMessage(
  DioException error,
) {
  final responseData = _toMap(
    error.response?.data,
  );

  final directMessage =
      responseData['message']
          ?.toString()
          .trim();

  if (directMessage != null &&
      directMessage.isNotEmpty) {
    return directMessage;
  }

  final nestedError =
      responseData['error'];

  if (nestedError is Map) {
    final nestedMessage =
        nestedError['message']
            ?.toString()
            .trim();

    if (nestedMessage != null &&
        nestedMessage.isNotEmpty) {
      return nestedMessage;
    }
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
      return 'Connection timed out. Please try again.';

    case DioExceptionType.transformTimeout:
      return 'Response processing timed out. Please try again.';

    case DioExceptionType.sendTimeout:
      return 'Request timed out. Please try again.';

    case DioExceptionType.receiveTimeout:
      return 'Server response timed out. Please try again.';

    case DioExceptionType.connectionError:
      return 'Unable to connect to the server.';

    case DioExceptionType.cancel:
      return 'The request was cancelled.';

    case DioExceptionType.badCertificate:
      return 'Unable to establish a secure connection.';

    case DioExceptionType.badResponse:
      return 'The server returned an error.';

    case DioExceptionType.unknown:
      return error.message ??
          'Something went wrong. Please try again.';
  }
}

String? _extractErrorCode(
  DioException error,
) {
  final responseData = _toMap(
    error.response?.data,
  );

  final directCode =
      responseData['code']
          ?.toString()
          .trim();

  if (directCode != null &&
      directCode.isNotEmpty) {
    return directCode;
  }

  final nestedError =
      responseData['error'];

  if (nestedError is Map) {
    final nestedCode =
        nestedError['code']
            ?.toString()
            .trim();

    if (nestedCode != null &&
        nestedCode.isNotEmpty) {
      return nestedCode;
    }
  }

  return null;
}