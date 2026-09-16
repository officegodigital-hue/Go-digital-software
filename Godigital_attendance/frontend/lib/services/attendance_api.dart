import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

//import 'api_config.dart';
import 'auth_storage.dart';

class AttendanceApi {
  AttendanceApi._();

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getString('auth_token');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> _post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );
    return _decode(response);
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Unexpected response');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode >= 400 || map['success'] == false) {
      throw Exception(map['message']?.toString() ?? 'Request failed');
    }
    final data = map['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return map;
  }

  static Future<Map<String, dynamic>> dashboard(DateTime date) {
    final day =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _get('/attendance/dashboard?date=$day');
  }

  static Future<Map<String, dynamic>> myHistory(DateTime month) {
    final value =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return _get('/attendance/me?month=$value');
  }

  static Future<void> checkIn({String method = 'mobile'}) {
    return _post('/attendance/check-in', {'method': method});
  }

  static Future<void> checkOut() {
    return _post('/attendance/check-out');
  }

  static Future<void> createRequest({
    required String type,
    required DateTime date,
    required String reason,
  }) {
    final day =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _post('/attendance/permissions', {
      'type': type,
      'date': day,
      'reason': reason,
    });
  }

  static Future<String> downloadExport(DateTime date) async {
    final day =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/attendance/export?date=$day'),
      headers: await _headers(),
    );
    if (response.statusCode >= 400) {
      throw Exception('Export failed');
    }
    return response.body;
  }

  static Future<String> downloadMyExport(DateTime month) async {
    final value =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/attendance/me/export?month=$value'),
      headers: await _headers(),
    );
    if (response.statusCode >= 400) {
      throw Exception('Export failed');
    }
    return response.body;
  }
}