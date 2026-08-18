import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/auth/admin_auth_session.dart';
import '../models/admin_notification_model.dart';
import'../../../../core/constants/api_config.dart';

class AdminNotificationRepository {
  AdminNotificationRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static  String get _baseUrl =>
      '${ApiConfig.baseUrl}/v1/admin/notifications';

  Future<Map<String, String>> _headers() async {
    final String? token = await AdminAuthSession.getAccessToken();

    if (token == null || token.trim().isEmpty) {
      throw Exception('Admin authentication token is missing.');
    }

    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // GET ALL NOTIFICATIONS
  // ============================================================

  Future<AdminNotificationListResult> getNotifications() async {
    final Uri uri = Uri.parse(
      _baseUrl,
    ).replace(queryParameters: <String, String>{'page': '1', 'limit': '100'});

    final http.Response response = await _client.get(
      uri,
      headers: await _headers(),
    );

    final Map<String, dynamic> body = _decodeResponse(response);

    final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final List<dynamic> rawList = data['notifications'] is List
        ? data['notifications'] as List<dynamic>
        : <dynamic>[];

    final List<AdminNotificationModel> notifications = rawList
        .whereType<Map<String, dynamic>>()
        .map(AdminNotificationModel.fromJson)
        .toList();

    return AdminNotificationListResult(
      notifications: notifications,
      totalCount: _toInt(data['total_count']),
      unreadCount: _toInt(data['unread_count']),
    );
  }

  // ============================================================
  // UNREAD COUNT
  // ============================================================

  Future<int> getUnreadCount() async {
    final http.Response response = await _client.get(
      Uri.parse('$_baseUrl/unread-count'),
      headers: await _headers(),
    );

    final Map<String, dynamic> body = _decodeResponse(response);

    final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return _toInt(data['unread_count']);
  }

  // ============================================================
  // MARK ONE READ
  // ============================================================

  Future<void> markAsRead(int notificationId) async {
    final http.Response response = await _client.patch(
      Uri.parse('$_baseUrl/$notificationId/read'),
      headers: await _headers(),
    );

    _decodeResponse(response);
  }

  // ============================================================
  // MARK ALL READ
  // ============================================================

  Future<void> markAllAsRead() async {
    final http.Response response = await _client.patch(
      Uri.parse('$_baseUrl/read-all'),
      headers: await _headers(),
    );

    _decodeResponse(response);
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> deleteNotification(int notificationId) async {
    final http.Response response = await _client.delete(
      Uri.parse('$_baseUrl/$notificationId'),
      headers: await _headers(),
    );

    _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> body;

    try {
      final dynamic decoded = jsonDecode(response.body);

      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final String message = body['message']?.toString().trim() ?? '';

    throw Exception(
      message.isNotEmpty
          ? message
          : 'Admin notification API failed with status ${response.statusCode}.',
    );
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

  void dispose() {
    _client.close();
  }
}
