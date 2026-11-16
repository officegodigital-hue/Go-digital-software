import 'dart:convert';
import 'package:godigital_portal/web_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:godigital_portal/services/authenticated_http.dart' as http;
import 'api_config.dart';
import 'auth_storage.dart';
import 'attendance_api.dart';

class HrmsPayslipApi {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getString('auth_token');
    return {'Content-Type': 'application/json', if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'};
  }
  static Future<List<Map<String, dynamic>>> mine() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/hrms/payslips/my'), headers: await _headers());
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400 || body['success'] != true) throw Exception(body['message'] ?? 'Unable to load payslips');
    final data = body['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  static Future<Map<String, dynamic>> summary() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/hrms/payslips/my/summary'), headers: await _headers());
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400 || body['success'] != true) throw Exception(body['message'] ?? 'Unable to load salary');
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }
  static Future<Map<String, dynamic>> history(DateTime month) async {
    final period = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/payslips/my/history?month=$period'),
      headers: await _headers(),
    );
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? const <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      if (response.statusCode == 404 || response.statusCode >= 500) {
        return _attendanceHistoryFallback(month);
      }
      rethrow;
    }
    final body = decoded is Map ? Map<String, dynamic>.from(decoded) : const <String, dynamic>{};
    if (response.statusCode < 400 && body['success'] == true) {
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    }
    // Older running API servers do not yet have the salary-history route.
    // The fallback stays read-only and uses the established employee attendance
    // history, so the employee can still see live monthly data during rollout.
    if (response.statusCode == 404 || response.statusCode >= 500) {
      return _attendanceHistoryFallback(month);
    }
    throw Exception(body['message'] ?? 'Unable to load salary history');
  }

  static Future<Map<String, dynamic>> _attendanceHistoryFallback(DateTime month) async {
    final attendance = await AttendanceApi.myHistory(month);
    final records = (attendance['records'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final byDate = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final rawDate = '${record['date'] ?? ''}';
      if (rawDate.length >= 10) byDate[rawDate.substring(0, 10)] = record;
    }
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    final days = <Map<String, dynamic>>[];
    for (var day = 1; day <= totalDays; day += 1) {
      final date = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final record = byDate[date];
      final status = '${record?['status'] ?? 'No attendance recorded'}';
      final absent = status.toLowerCase() == 'absent';
      final worked = status.toLowerCase() == 'present' || status.toLowerCase() == 'late' || status.toLowerCase() == 'early exit';
      days.add({
        'date': date,
        'status': record == null ? 'No attendance recorded' : status,
        'source': record == null ? 'Attendance record unavailable from this server' : worked ? 'Attendance recorded' : absent ? 'Attendance status' : 'Attendance record',
        'direction': 'none',
        'amount': 0,
        'checkIn': record?['checkIn'],
        'checkOut': record?['checkOut'],
      });
    }
    return {'month': '${month.year}-${month.month.toString().padLeft(2, '0')}', 'payroll': const <String, dynamic>{}, 'days': days, 'fallback': true};
  }
  static Future<void> request(int payrollId) async {
    final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/hrms/payslips/$payrollId/request'), headers: await _headers());
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400 || body['success'] != true) throw Exception(body['message'] ?? 'Unable to send request');
  }
  static Future<void> download(int payrollId) async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/hrms/payslips/$payrollId/download'), headers: await _headers());
    if (response.statusCode >= 400) { final body = jsonDecode(response.body); throw Exception(body['message'] ?? 'Unable to download payslip'); }
    final bytes = response.bodyBytes;
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().startsWith('application/pdf') ||
        bytes.length < 5 || ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-') {
      throw Exception('The server did not return a PDF. No file was downloaded. Please contact your administrator.');
    }
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = 'Salary-Slip-$payrollId.pdf'
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    Future<void>.delayed(const Duration(seconds: 60), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
