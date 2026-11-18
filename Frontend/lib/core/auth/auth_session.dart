// lib/core/auth/auth_session.dart

class AuthSession {
  static String? _token;
  static bool _isEmployee = false;
  static bool _isAdmin = false;

  /// Initialize or update the session details upon login
  static void initialize({
    required String? token,
    bool isEmployee = false,
    bool isAdmin = false,
  }) {
    _token = token;
    _isEmployee = isEmployee;
    _isAdmin = isAdmin;
  }

  /// Clears session data on logout
  static void clear() {
    _token = null;
    _isEmployee = false;
    _isAdmin = false;
  }

  /// Returns the current token or throws an exception if unavailable
  static String requireToken() {
    if (_token == null || _token!.trim().isEmpty) {
      throw Exception('Authentication token is required. Please log in again.');
    }
    return _token!;
  }

  static bool get isEmployee => _isEmployee;
  static bool get isAdmin => _isAdmin;
}