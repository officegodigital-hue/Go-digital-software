import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_storage.dart';

class HrmsEmployeeProfileApi {
  HrmsEmployeeProfileApi._();

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> getProfile(
    int profileId, {
    required int year,
    required int month,
    int? employeeUserId,
  }) async {
    final params = <String, String>{'year': '$year', 'month': '$month'};
    // If profileId is 0 (not in HRMS yet), pass employeeUserId so the backend
    // can look up by employee_user_id instead.
    if (profileId == 0 && employeeUserId != null) {
      params['employeeUserId'] = '$employeeUserId';
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/hrms/employees/${profileId == 0 ? 0 : profileId}/profile')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers());
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final map = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    if (response.statusCode >= 400 || map['success'] == false) {
      throw Exception(map['message']?.toString() ?? 'Request failed');
    }
    final data = map['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }
}
