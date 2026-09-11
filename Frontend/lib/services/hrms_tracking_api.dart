import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_storage.dart';

class HrmsTrackingApi {
  HrmsTrackingApi._();

  static Future<Map<String, dynamic>?> myHomeLocation() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/home-location'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _decode(response);
    return data['employee_user_id'] == null ? null : data;
  }

  static Future<void> submitHomeLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
    required String capturedAt,
    String? address,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/home-location'),
      headers: await _headers(),
      body: jsonEncode({
        'latitude': latitude, 'longitude': longitude,
        'accuracy': accuracy, 'capturedAt': capturedAt,
        'address': address,
      }),
    ).timeout(const Duration(seconds: 15));
    _decode(response);
  }

  static Future<List<Map<String, dynamic>>> homeLocations() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/home-locations'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final data = _decode(response);
    return (data['items'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<void> reviewHomeLocation({
    required int employeeUserId,
    required bool approve,
    required double latitude,
    required double longitude,
    String? rejectionReason,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/home-locations/$employeeUserId'),
      headers: await _headers(),
      body: jsonEncode({
        'approvalStatus': approve ? 'approved' : 'rejected',
        'latitude': latitude, 'longitude': longitude,
        'rejectionReason': rejectionReason,
      }),
    ).timeout(const Duration(seconds: 15));
    _decode(response);
  }

  static Future<void> updateOfficeRadius(int radiusMeters) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/settings'),
      headers: await _headers(),
      body: jsonEncode({'officeRadiusMeters': radiusMeters}),
    ).timeout(const Duration(seconds: 15));
    _decode(response);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.getString('auth_token');

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);

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

  static Future<Map<String, dynamic>> live() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/live'),
      headers: await _headers(),
    );

    return _decode(response);
  }

  static Future<Map<String, dynamic>> route({
    required int employeeUserId,
    required String date,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/hrms/tracking/route/$employeeUserId',
    ).replace(queryParameters: {'date': date});

    final response = await http.get(uri, headers: await _headers());

    return _decode(response);
  }

  static Future<void> setStatus(String status) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/status'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    );

    _decode(response);
  }

  static Future<void> ping({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/ping'),
      headers: await _headers(),
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      }),
    );

    _decode(response);
  }

  static Future<Map<String, dynamic>> fieldSession() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/field-session'),
      headers: await _headers(),
    );

    return _decode(response);
  }

  static Future<Map<String, dynamic>> startFieldSession({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/field-session/start'),
      headers: await _headers(),
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      }),
    );

    return _decode(response);
  }

  static Future<Map<String, dynamic>> stopFieldSession({
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/field-session/stop'),
      headers: await _headers(),
      body: jsonEncode({
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      }),
    );

    return _decode(response);
  }

  static Future<Map<String, dynamic>?> waitingAlert() async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/hrms/tracking/field-waiting-alert',
      ),
      headers: await _headers(),
    );

    final data = _decode(response);

    // When no alert exists, backend returns { success: true, data: null }.
    if (data['id'] == null) {
      return null;
    }

    return data;
  }

  static Future<void> submitWaitingReason({
    required int reasonId,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/hrms/tracking/field-waiting-reasons/$reasonId',
      ),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );

    _decode(response);
  }

  static Future<Map<String, dynamic>> trackingSettings() async {
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/settings'),
    headers: await _headers(),
  );

  return _decode(response);

  }

static Future<Map<String, dynamic>> updateFieldWaitingSettings({
  required int fieldWaitingMinutes,
  required int stationaryRadiusMeters,
  required int fieldPingIntervalMinutes,
}) async {
  final response = await http.put(
    Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/settings'),
    headers: await _headers(),
    body: jsonEncode({
      'fieldWaitingMinutes': fieldWaitingMinutes,
      'stationaryRadiusMeters': stationaryRadiusMeters,
      'fieldPingIntervalMinutes': fieldPingIntervalMinutes,
    }),
  );

  return _decode(response);
}
static Future<List<Map<String, dynamic>>> fieldWaitingReasons() async {
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/hrms/tracking/field-waiting-reasons'),
    headers: await _headers(),
  );

  final data = _decode(response);
  final items = data['items'] as List? ?? [];

  return items
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

static Future<void> reviewFieldWaitingReason(int reasonId) async {
  final response = await http.patch(
    Uri.parse(
      '${ApiConfig.baseUrl}/hrms/tracking/field-waiting-reasons/$reasonId/review',
    ),
    headers: await _headers(),
  );

  _decode(response);
}
}
