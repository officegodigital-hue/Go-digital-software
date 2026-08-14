import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';

class MobileService {
  /* MOBILE APP LOGIN */
  Future<void> loginMobileApp({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.mobileLogin),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
        'device_name': kIsWeb ? 'Chrome Browser' : 'Android Mobile',
        'device_type': kIsWeb ? 'Web' : 'Android',
        'device_id': DateTime.now().millisecondsSinceEpoch.toString(),
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mobile_logged_in', true);
      await prefs.setString('mobile_username', username);
      return;
    }

    throw Exception(data['message'] ?? 'Login failed');
  }

  /* CHECK LOGIN STATUS */
  Future<bool> isMobileLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('mobile_logged_in') ?? false;
  }

  /* LOGOUT MOBILE APP */
  Future<void> logoutMobileApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mobile_logged_in');
    await prefs.remove('mobile_username');
  }

  /* GET CLIENT FOLDERS BY CATEGORY */
  Future<List<dynamic>> getClientsByCategory(String categorySlug) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.clientsByCategory}?category=$categorySlug'),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['data']);
    }

    throw Exception(data['message'] ?? 'Failed to load clients');
  }

  /* GET CLIENT DELIVERABLES */
  Future<Map<String, dynamic>> getClientDeliverables({
    required int clientId,
    required String categorySlug,
  }) async {
    final response = await http.get(
      Uri.parse(
        ApiConstants.clientDeliverables(
          clientId: clientId,
          categorySlug: categorySlug,
        ),
      ),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data['data']);
    }

    throw Exception(data['message'] ?? 'Failed to load deliverables');
  }
}