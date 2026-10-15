import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class TrackingCommentsApi {
  TrackingCommentsApi._();

  static Future<List<Map<String, dynamic>>> adminComments(String token) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/field-waiting-reasons'),
      headers: headers,
    );

    if (response.statusCode >= 400) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(decoded['message']?.toString() ?? 'Request failed');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final items = data?['items'] as List?;
    if (items == null) return [];

    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((e) => {
              'fullName': e['full_name'] ?? e['fullName'],
              'employeeName': e['employee_code'],
              'comment': e['reason'] ?? e['comment'],
              'createdAt': e['submitted_at'] ?? e['waiting_detected_at'],
              'address': e['address'],
            })
        .toList();
  }
}
