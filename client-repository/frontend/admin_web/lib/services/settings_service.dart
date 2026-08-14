import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';

class SettingsService {
  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Login token missing. Please login again.');
    }

    return token;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final token = await _token();

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/settings'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data['data']);
    }

    throw Exception(data['message'] ?? 'Failed to load settings');
  }

  Future<void> updateAdminProfile({
    required String name,
    required String email,
    required String password,
  }) async {
    final token = await _token();

    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/settings/admin-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to update admin profile');
  }

  Future<void> updateMobileCredentials({
    required String username,
    required String password,
  }) async {
    final token = await _token();

    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/settings/mobile-credentials'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'app_username': username,
        'app_password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to update mobile login');
  }

  Future<List<dynamic>> getMobileSessions() async {
    final token = await _token();

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/settings/mobile-sessions'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return List<dynamic>.from(data['data']);
    }

    throw Exception(data['message'] ?? 'Failed to load mobile devices');
  }

  Future<void> removeMobileSession(int id) async {
    final token = await _token();

    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/settings/mobile-sessions/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to remove mobile device');
  }

  Future<void> removeAllMobileSessions() async {
    final token = await _token();

    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/settings/mobile-sessions'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to remove all mobile devices');
  }
}