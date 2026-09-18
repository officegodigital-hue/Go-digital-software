import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_storage.dart';

abstract final class HrmsClockLogsApi {
  static Future<Map<String, dynamic>> list({
    required DateTime date,
    required bool monthly,
    int? employeeId,
  }) async {
    final query = <String, String>{
      'view': monthly ? 'month' : 'day',
      'date': _date(date),
      'month': '${date.year}-${date.month.toString().padLeft(2, '0')}',
      if (employeeId != null) 'employeeId': '$employeeId',
    };
    final token = await AuthStorage.getString('auth_token');
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/attendance/clock-logs')
          .replace(queryParameters: query),
      headers: {if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'},
    );
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final map = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    if (response.statusCode >= 400 || map['success'] == false) {
      throw Exception(map['message']?.toString() ?? 'Could not load clock logs');
    }
    return map['data'] is Map ? Map<String, dynamic>.from(map['data']) : map;
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
