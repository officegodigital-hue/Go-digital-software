import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_config.dart';

class AuthService {
  String get baseUrl => ApiConfig.baseUrl;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final token = data['token']?.toString() ?? '';

      if (token.isEmpty) {
        throw Exception('Login success but token missing from backend');
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', token);

      if (data['user'] != null) {
        await prefs.setString('user', jsonEncode(data['user']));
      }

      return data;
    }

    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }
}