import 'dart:html' as html;

class AuthStorage {
  AuthStorage._();
  static String? cachedToken;

  static Future<String?> getString(
    String key,
  ) async {
    final value = html.window.sessionStorage[key];
    if (key == 'auth_token') cachedToken = value;
    return value;
  }

  static Future<void> setString(
    String key,
    String value,
  ) async {
    if (key == 'auth_token') cachedToken = value;
    html.window.sessionStorage[key] = value;
  }

  static Future<bool?> getBool(
    String key,
  ) async {
    final value = html.window.sessionStorage[key];

    if (value == null) {
      return null;
    }

    return value == 'true';
  }

  static Future<void> setBool(
    String key,
    bool value,
  ) async {
    html.window.sessionStorage[key] = value.toString();
  }

  static Future<void> remove(
    String key,
  ) async {
    if (key == 'auth_token') cachedToken = null;
    html.window.sessionStorage.remove(key);
  }

  static Future<void> clear() async {
    cachedToken = null;
    html.window.sessionStorage.clear();
  }
}