import 'package:dio/dio.dart';
import 'package:employee_mobile/core/network/api_client.dart';
import 'package:employee_mobile/features/attendance/data/models/today_attendance_response.dart';

class AttendanceRepository {
  AttendanceRepository({
    Dio? dio,
  }) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  static const List<String> _todayEndpoints = <String>[
    '/attendance/today',
  ];

  static const List<String> _checkInEndpoints = <String>[
    '/attendance/check-in',
  ];

  static const List<String> _checkOutEndpoints = <String>[
    '/attendance/check-out',
  ];

  static const List<String> _startBreakEndpoints = <String>[
    '/attendance/breaks/start',
  ];

  static const List<String> _endBreakEndpoints = <String>[
    '/attendance/breaks/end',
  ];

  Future<TodayAttendanceResponse> getTodayAttendance() async {
    try {
      final response = await _getFirstAvailable(
        _todayEndpoints,
      );

      return _parseTodayResponse(
        response.data,
      );
    } on DioException catch (error) {
      throw AttendanceRepositoryException(
        _extractErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      if (error is AttendanceRepositoryException) {
        rethrow;
      }

      throw AttendanceRepositoryException(
        error.toString(),
      );
    }
  }

  Future<TodayAttendanceResponse> checkIn({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final payload = _buildLocationPayload(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );

    return _performAttendanceAction(
      endpoints: _checkInEndpoints,
      payload: payload,
      defaultMessage: 'Checked in successfully.',
    );
  }

  Future<TodayAttendanceResponse> startBreak() async {
    return _performAttendanceAction(
      endpoints: _startBreakEndpoints,
      payload: const <String, dynamic>{},
      defaultMessage: 'Break started successfully.',
    );
  }

  Future<TodayAttendanceResponse> endBreak() async {
    return _performAttendanceAction(
      endpoints: _endBreakEndpoints,
      payload: const <String, dynamic>{},
      defaultMessage: 'Break ended successfully.',
    );
  }

  Future<TodayAttendanceResponse> checkOut({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final payload = _buildLocationPayload(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );

    return _performAttendanceAction(
      endpoints: _checkOutEndpoints,
      payload: payload,
      defaultMessage: 'Checked out successfully.',
    );
  }

  Map<String, dynamic> _buildLocationPayload({
    required double? latitude,
    required double? longitude,
    required String? address,
  }) {
    if (latitude == null || longitude == null) {
      return const <String, dynamic>{};
    }

    final location = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
    };

    if (address != null && address.trim().isNotEmpty) {
      location['address'] = address.trim();
    }

    return <String, dynamic>{
      'location': location,
    };
  }

  Future<TodayAttendanceResponse> _performAttendanceAction({
    required List<String> endpoints,
    required Map<String, dynamic> payload,
    required String defaultMessage,
  }) async {
    try {
      final actionResponse = await _postFirstAvailable(
        endpoints,
        payload,
      );

      final actionMessage = _extractResponseMessage(
        actionResponse.data,
      );

      try {
        final refreshedResponse = await getTodayAttendance();

        return TodayAttendanceResponse(
          success: refreshedResponse.success,
          message: actionMessage == null || actionMessage.isEmpty
              ? defaultMessage
              : actionMessage,
          data: refreshedResponse.data,
        );
      } on AttendanceRepositoryException {
        final parsedActionResponse = _tryParseTodayResponse(
          actionResponse.data,
        );

        if (parsedActionResponse != null) {
          return TodayAttendanceResponse(
            success: parsedActionResponse.success,
            message: actionMessage ??
                (parsedActionResponse.message.trim().isEmpty
                    ? defaultMessage
                    : parsedActionResponse.message),
            data: parsedActionResponse.data,
          );
        }

        throw AttendanceRepositoryException(
          actionMessage ??
              'Attendance action succeeded, but today attendance could not be refreshed.',
        );
      }
    } on DioException catch (error) {
      throw AttendanceRepositoryException(
        _extractErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      if (error is AttendanceRepositoryException) {
        rethrow;
      }

      throw AttendanceRepositoryException(
        error.toString(),
      );
    }
  }

  Future<Response<dynamic>> _getFirstAvailable(
    List<String> endpoints,
  ) async {
    DioException? lastError;

    for (final endpoint in endpoints) {
      try {
        return await _dio.get<dynamic>(
          endpoint,
        );
      } on DioException catch (error) {
        lastError = error;

        final statusCode = error.response?.statusCode;

        if (statusCode == 404 || statusCode == 405) {
          continue;
        }

        rethrow;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw const AttendanceRepositoryException(
      'Attendance API endpoint is unavailable.',
    );
  }

  Future<Response<dynamic>> _postFirstAvailable(
    List<String> endpoints,
    Map<String, dynamic> payload,
  ) async {
    DioException? lastError;

    for (final endpoint in endpoints) {
      try {
        return await _dio.post<dynamic>(
          endpoint,
          data: payload,
        );
      } on DioException catch (error) {
        lastError = error;

        final statusCode = error.response?.statusCode;

        if (statusCode == 404 || statusCode == 405) {
          continue;
        }

        rethrow;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw const AttendanceRepositoryException(
      'Attendance action endpoint is unavailable.',
    );
  }

  TodayAttendanceResponse _parseTodayResponse(
    dynamic responseData,
  ) {
    final json = _toMap(responseData);

    if (json == null) {
      throw const AttendanceRepositoryException(
        'Invalid attendance response received.',
      );
    }

    return TodayAttendanceResponse.fromJson(
      json,
    );
  }

  TodayAttendanceResponse? _tryParseTodayResponse(
    dynamic responseData,
  ) {
    final json = _toMap(responseData);

    if (json == null) {
      return null;
    }

    final data = json['data'];

    final hasAttendanceData = _containsAttendanceInformation(
      data is Map ? data : json,
    );

    if (!hasAttendanceData) {
      return null;
    }

    return TodayAttendanceResponse.fromJson(
      json,
    );
  }

  bool _containsAttendanceInformation(
    dynamic value,
  ) {
    if (value is! Map) {
      return false;
    }

    final normalizedKeys = value.keys
        .map(
          (key) => key
              .toString()
              .toLowerCase()
              .replaceAll(
                RegExp(r'[^a-z0-9]'),
                '',
              ),
        )
        .toSet();

    const attendanceKeys = <String>{
      'today',
      'attendance',
      'todayattendance',
      'permissions',
      'attendanceid',
      'checkintime',
      'checkouttime',
      'checkinat',
      'checkoutat',
      'workedminutes',
      'workingminutes',
      'breakminutes',
      'overtimeminutes',
      'activebreak',
      'summary',
    };

    if (normalizedKeys.any(attendanceKeys.contains)) {
      return true;
    }

    for (final item in value.values) {
      if (item is Map && _containsAttendanceInformation(item)) {
        return true;
      }
    }

    return false;
  }

  Map<String, dynamic>? _toMap(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, item) {
          return MapEntry(
            key.toString(),
            item,
          );
        },
      );
    }

    return null;
  }

  String? _extractResponseMessage(
    dynamic responseData,
  ) {
    final json = _toMap(responseData);

    if (json == null) {
      return null;
    }

    final message = json['message'] ?? json['msg'] ?? json['error'];

    if (message == null || message is Map || message is List) {
      return null;
    }

    final text = message.toString().trim();

    return text.isEmpty ? null : text;
  }

  String _extractErrorMessage(
    DioException error,
  ) {
    final responseData = error.response?.data;
    final responseJson = _toMap(responseData);

    if (responseJson != null) {
      final message = responseJson['message'] ??
          responseJson['error'] ??
          responseJson['details'];

      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The attendance request timed out.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the attendance server.';

      case DioExceptionType.badResponse:
        return 'Attendance request failed with status ${error.response?.statusCode ?? 'unknown'}.';

      case DioExceptionType.cancel:
        return 'Attendance request was cancelled.';

      default:
        return error.message ??
            'Unable to complete the attendance request.';
    }
  }
}

class AttendanceRepositoryException implements Exception {
  const AttendanceRepositoryException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() {
    return message;
  }
}
