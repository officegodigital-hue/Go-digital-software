import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';



  class AuthService extends ChangeNotifier {
  static String get baseUrl => ApiConfig.baseUrl;

  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;
  

  // Getters
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;
  String? get userRole => _user?['role'];
  String? get userId => _user?['id'].toString();

  bool _isInitialized = false; // Add this
  bool get isInitialized => _isInitialized; // Add this getter

  AuthService() {
    _loadStoredToken();
  } 

  // Load stored token from local storage
 Future<void> _loadStoredToken() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    _token = prefs.getString('auth_token');

    final userJson = prefs.getString('user_data');

    if (_token != null && userJson != null) {
      _user = jsonDecode(userJson);
    }

    _isInitialized = true;
    notifyListeners();
  } catch (e) {
    debugPrint('Error loading stored token: $e');
    _isInitialized = true;
    notifyListeners();
  }
}
  


  // Login with email and password
  // Future<bool> login(String email, String password, bool isAdmin) async {
  //   _isLoading = true;
  //   _error = null;
  //   notifyListeners();

  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/auth/login'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'email': email,
  //         'password': password,
  //         'userType': isAdmin ? 'admin' : 'employee',
  //       }),
  //     ).timeout(const Duration(seconds: 10));

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
        
  //       if (data['success'] == true && data['token'] != null) {
  //         _token = data['token'];
  //         _user = data['user'];

  //         // Store token and user data
  //         final prefs = await SharedPreferences.getInstance();
  //         await prefs.setString('auth_token', _token!);
  //         await prefs.setString('user_data', jsonEncode(_user));
  //         await prefs.setBool('isLoggedIn', true);
  //         await prefs.setString('role', _user?['role'] ?? '');

  //         _isLoading = false;
  //         notifyListeners();
  //         return true;
  //       } else {
  //         _error = data['message'] ?? 'Login failed';
  //         _isLoading = false;
  //         notifyListeners();
  //         return false;
  //       }
  //     } else {
  //       _error = 'Server error: ${response.statusCode}';
  //       _isLoading = false;
  //       notifyListeners();
  //       return false;
  //     }
  //   } catch (e) {
  //     _error = 'Connection error: $e';
  //     _isLoading = false;
  //     notifyListeners();
  //     return false;
  //   }
  // }

  Future<bool> login(String email, String password, bool isAdmin) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'userType': isAdmin ? 'admin' : 'employee',
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      _token = data['token'];
      _user = data['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await prefs.setString('user_data', jsonEncode(_user));
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('role', _user?['role'] ?? '');

      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      // Show the exact message from the backend
      _error = data['message'] ?? 'Login failed';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Unable to connect to server.';
    _isLoading = false;
    notifyListeners();
    return false;
  }
}

  // Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('isLoggedIn');
      await prefs.remove('role');
      await prefs.remove('employeeMenu');
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
    }

    _token = null;
    _user = null;
    notifyListeners();
  }



  // Verify token is still valid
  Future<bool> verifyToken() async {
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/verify'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        await logout();
        return false;
      }
      return false;
    } catch (e) {
      debugPrint('Token verification error: $e');
      return false;
    }
  }

  // Get user data from backend
  Future<void> refreshUserData() async {
    if (_token == null || _user == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/${_user!['id']}'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _user = data['data'];
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(_user));
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
    }
  }
}