import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_storage.dart';

class HrmsDashboardApi {
  HrmsDashboardApi._();

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

  static Future<Map<String, dynamic>> month({
    required int year,
    required int month,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/hrms/dashboard',
    ).replace(queryParameters: {'year': '$year', 'month': '$month'});
    final response = await http.get(uri, headers: await _headers());
    return _decode(response);
  }

  static Future<Map<String, dynamic>> year({required int year}) async {
    final months = <Map<String, dynamic>>[];
    for (var m = 1; m <= 12; m++) {
      months.add(await month(year: year, month: m));
    }
    return aggregateYear(months);
  }

  static Map<String, dynamic> aggregateYear(List<Map<String, dynamic>> months) {
    const fields = [
      'present',
      'unexcused',
      'late',
      'approvedLeave',
      'halfLeave',
      'earnedLeave',
      'excused',
      'paidLeaveDays',
      'lopLeaveDays',
    ];
    num number(dynamic value) =>
        value is num ? value : num.tryParse('$value') ?? 0;
    final employees = <String, Map<String, dynamic>>{};
    num workingDays = 0;
    for (final month in months) {
      workingDays += number((month['kpis'] as Map?)?['workingDays']);
      for (final raw in month['employees'] as List? ?? []) {
        final row = Map<String, dynamic>.from(raw as Map);
        final key =
            '${row['employeeUserId'] ?? row['employeeId'] ?? row['id']}';
        final previous = employees[key];
        employees[key] = {
          ...row,
          'days': <String>[],
          for (final field in fields)
            field: number(previous?[field]) + number(row[field]),
        };
      }
    }
    final rows = employees.values.toList()
      ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    num total(String field) =>
        rows.fold<num>(0, (sum, row) => sum + number(row[field]));
    return {
      'employees': rows,
      'kpis': {
        'totalEmployees': rows.length,
        'workingDays': workingDays,
        'present': total('present'),
        'absent': total('unexcused'),
        'late': total('late'),
      },
    };
  }

  static Future<Map<String, dynamic>> calendar() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/dashboard/calendar'),
      headers: await _headers(),
    );
    return _decode(response);
  }

  static Future<Map<String, dynamic>> saveCalendar({
    int? weeklyOffDay,
    Map<String, dynamic>? override,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/hrms/dashboard/calendar'),
      headers: await _headers(),
      body: jsonEncode({'weeklyOffDay': ?weeklyOffDay, 'override': ?override}),
    );
    return _decode(response);
  }
}
