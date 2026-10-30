import 'dart:convert';
import 'dart:typed_data';
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'api_config.dart';
import 'auth_storage.dart';

class EmployeeLifecycleApi {
  static Future<Uint8List> payslip(int employeeId, int payrollId) async {
    final token = await AuthStorage.getString('auth_token');
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/employees/$employeeId/payroll/$payrollId/payslip',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200)
      throw Exception('Could not load the paid payslip');
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final token = await AuthStorage.getString('auth_token');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}/employees/$path');
    final response = method == 'POST'
        ? await http.post(uri, headers: headers, body: jsonEncode(body))
        : method == 'PATCH'
        ? await http.patch(uri, headers: headers, body: jsonEncode(body))
        : await http.get(uri, headers: headers);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || result['success'] == false) {
      throw Exception(result['message'] ?? 'Request failed');
    }
    return Map<String, dynamic>.from(result['data'] as Map? ?? {});
  }
}
