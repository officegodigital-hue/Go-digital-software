import 'dart:convert';

import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class HrmsAnnouncementsApi {
  HrmsAnnouncementsApi._();

  static Future<Map<String, String>> _headers(AuthService auth) async {
    final token = auth.token;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) throw Exception('Unexpected response');
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode >= 400 || map['success'] == false) {
      throw Exception(map['message']?.toString() ?? 'Request failed');
    }
    return map;
  }

  static Future<List<dynamic>> list(AuthService auth) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/announcements'),
      headers: await _headers(auth),
    );
    final data = _decode(response);
    return (data['data'] as List?) ?? [];
  }

  static Future<List<dynamic>> employees(AuthService auth) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/announcements/employees'),
      headers: await _headers(auth),
    );
    final data = _decode(response);
    return (data['data'] as List?) ?? [];
  }

  static Future<void> create(
    AuthService auth,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/hrms/announcements'),
      headers: await _headers(auth),
      body: jsonEncode(body),
    );
    _decode(response);
  }

  static Future<List<dynamic>> recipients(
    AuthService auth,
    dynamic announcementId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/hrms/announcements/$announcementId/recipients',
      ),
      headers: await _headers(auth),
    );
    final data = _decode(response);
    return (data['data'] as List?) ?? [];
  }
}
