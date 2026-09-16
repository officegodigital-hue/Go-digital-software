import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_storage.dart';

class HrmsClockLogsApi {
  HrmsClockLogsApi._();

  static Future<Map<String, dynamic>> list({
    required String view,
    required DateTime selectedDate,
    int? employeeId,
  }) async {
    final date = _date(selectedDate);
    final month = date.substring(0, 7);
    final uri = Uri.parse('${ApiConfig.baseUrl}/attendance/clock-logs').replace(
      queryParameters: {
        'view': view,
        'date': date,
        'month': month,
        if (employeeId != null) 'employee_id': '$employeeId',
      },
    );
    final response = await http.get(uri, headers: await _headers());
    return _decode(response);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getString('auth_token');
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
    return Map<String, dynamic>.from(map['data'] as Map? ?? {});
  }
}
