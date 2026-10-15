import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage.dart';

class CalendarNotificationsApi {
  CalendarNotificationsApi._();

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> mine() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/attendance/calendar-notifications'),
      headers: await _headers(),
    );
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode >= 400 ||
        body is! Map ||
        body['success'] == false) {
      throw Exception(
        body is Map
            ? body['message'] ?? 'Could not load notifications'
            : 'Could not load notifications',
      );
    }
    return Map<String, dynamic>.from(body['data'] as Map? ?? const {});
  }

  static Future<void> markRead(int id) async {
    final response = await http.patch(
      Uri.parse(
        '${ApiConfig.baseUrl}/attendance/calendar-notifications/$id/read',
      ),
      headers: await _headers(),
    );
    if (response.statusCode >= 400) {
      throw Exception('Could not update notification');
    }
  }
}
