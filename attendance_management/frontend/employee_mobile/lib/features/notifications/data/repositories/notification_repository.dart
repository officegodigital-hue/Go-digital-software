import 'package:dio/dio.dart';
import 'package:employee_mobile/core/network/api_client.dart';
import 'package:employee_mobile/features/notifications/data/models/notification_response.dart';

class NotificationRepository {
  NotificationRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  // ============================================================
  // GET ALL NOTIFICATIONS
  // ============================================================

  Future<NotificationListResponse> getNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/notifications',
        queryParameters: <String, dynamic>{if (unreadOnly) 'unread_only': true},
      );

      final Map<String, dynamic> root =
          _toMap(response.data) ?? <String, dynamic>{};

      _validateResponse(root);

      final Map<String, dynamic> data =
          _toMap(root['data']) ?? <String, dynamic>{};

      return NotificationListResponse.fromJson(<String, dynamic>{
        'success': root['success'] ?? true,

        'message': root['message'] ?? '',

        'notifications': data['notifications'] ?? <dynamic>[],

        'total_count': data['total_count'] ?? 0,

        'unread_count': data['unread_count'] ?? 0,
      });
    } on DioException catch (error) {
      throw NotificationRepositoryException(
        _extractDioErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } on NotificationRepositoryException {
      rethrow;
    } catch (error) {
      throw NotificationRepositoryException(
        'Unable to load notifications: $error',
      );
    }
  }

  // ============================================================
  // GET UNREAD COUNT
  // ============================================================

  Future<int> getUnreadCount() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        '/notifications/unread-count',
      );

      final Map<String, dynamic> root =
          _toMap(response.data) ?? <String, dynamic>{};

      _validateResponse(root);

      final Map<String, dynamic> data =
          _toMap(root['data']) ?? <String, dynamic>{};

      return _toInt(data['unread_count']);
    } on DioException catch (error) {
      throw NotificationRepositoryException(
        _extractDioErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } on NotificationRepositoryException {
      rethrow;
    } catch (error) {
      throw NotificationRepositoryException(
        'Unable to load unread notification count: $error',
      );
    }
  }

  // ============================================================
  // MARK ONE AS READ
  // ============================================================

  Future<String> markAsRead(int notificationId) async {
    try {
      final Response<dynamic> response = await _dio.patch<dynamic>(
        '/notifications/$notificationId/read',
      );

      final Map<String, dynamic>? root = _toMap(response.data);

      if (root != null) {
        _validateResponse(root);
      }

      return _extractResponseMessage(response.data) ??
          'Notification marked as read.';
    } on DioException catch (error) {
      throw NotificationRepositoryException(
        _extractDioErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } on NotificationRepositoryException {
      rethrow;
    } catch (error) {
      throw NotificationRepositoryException(
        'Unable to mark notification as read: $error',
      );
    }
  }

  // ============================================================
  // MARK ALL AS READ
  // ============================================================

  Future<String> markAllAsRead() async {
    try {
      final Response<dynamic> response = await _dio.patch<dynamic>(
        '/notifications/read-all',
      );

      final Map<String, dynamic>? root = _toMap(response.data);

      if (root != null) {
        _validateResponse(root);
      }

      return _extractResponseMessage(response.data) ??
          'All notifications marked as read.';
    } on DioException catch (error) {
      throw NotificationRepositoryException(
        _extractDioErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } on NotificationRepositoryException {
      rethrow;
    } catch (error) {
      throw NotificationRepositoryException(
        'Unable to mark all notifications as read: $error',
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<String> deleteNotification(int notificationId) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        '/notifications/$notificationId',
      );

      final Map<String, dynamic>? root = _toMap(response.data);

      if (root != null) {
        _validateResponse(root);
      }

      return _extractResponseMessage(response.data) ??
          'Notification deleted successfully.';
    } on DioException catch (error) {
      throw NotificationRepositoryException(
        _extractDioErrorMessage(error),
        statusCode: error.response?.statusCode,
      );
    } on NotificationRepositoryException {
      rethrow;
    } catch (error) {
      throw NotificationRepositoryException(
        'Unable to delete notification: $error',
      );
    }
  }

  // ============================================================
  // RESPONSE HELPERS
  // ============================================================

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

  void _validateResponse(Map<String, dynamic> json) {
    final dynamic success = json['success'];

    final bool failed =
        success == false ||
        success == 0 ||
        success?.toString().trim().toLowerCase() == 'false';

    if (!failed) {
      return;
    }

    throw NotificationRepositoryException(
      _extractResponseMessage(json) ?? 'Notification request failed.',
    );
  }

  String? _extractResponseMessage(dynamic source) {
    final Map<String, dynamic>? json = _toMap(source);

    if (json == null) {
      return null;
    }

    final dynamic value =
        json['message'] ?? json['error'] ?? json['details'] ?? json['msg'];

    if (value == null || value is Map || value is List) {
      return null;
    }

    final String text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  String _extractDioErrorMessage(DioException error) {
    final String? responseMessage = _extractResponseMessage(
      error.response?.data,
    );

    if (responseMessage != null && responseMessage.isNotEmpty) {
      return responseMessage;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Notification request timed out.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the notification server.';

      case DioExceptionType.cancel:
        return 'Notification request was cancelled.';

      case DioExceptionType.badResponse:
        return 'Notification request failed with status '
            '${error.response?.statusCode ?? 'unknown'}.';

      default:
        return error.message ?? 'Unable to complete the notification request.';
    }
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class NotificationRepositoryException implements Exception {
  const NotificationRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    return message;
  }
}
