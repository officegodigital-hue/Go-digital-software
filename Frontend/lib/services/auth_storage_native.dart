import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage._();
  static String? cachedToken;

  static Future<String?> getString(
    String key,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final value = prefs.getString(key);
    if (key == 'auth_token') cachedToken = value;
    return value;
  }

  static Future<void> setString(
    String key,
    String value,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    if (key == 'auth_token') cachedToken = value;
    await prefs.setString(key, value);
  }

  static Future<bool?> getBool(
    String key,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getBool(key);
  }

  static Future<void> setBool(
    String key,
    bool value,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(key, value);
  }

  static Future<void> remove(
    String key,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    if (key == 'auth_token') cachedToken = null;
    await prefs.remove(key);
  }

  static Future<void> clear() async {
    cachedToken = null;
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.clear();
  }
}