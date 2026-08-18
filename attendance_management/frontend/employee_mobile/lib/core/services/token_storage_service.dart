import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  TokenStorageService._();

  static final TokenStorageService instance = TokenStorageService._();

  factory TokenStorageService() => instance;

  static const String _accessTokenKey = 'attendance_access_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Compatibility methods for existing repository code.

  Future<void> writeAccessToken(String token) {
    return saveAccessToken(token);
  }

  Future<String?> readAccessToken() {
    return getAccessToken();
  }

  Future<void> saveToken(String token) {
    return saveAccessToken(token);
  }

  Future<String?> getToken() {
    return getAccessToken();
  }

  Future<void> deleteToken() {
    return deleteAccessToken();
  }
}
