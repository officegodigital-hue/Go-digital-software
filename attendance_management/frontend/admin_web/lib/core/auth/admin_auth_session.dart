import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AdminAuthSession {
  const AdminAuthSession._();

  static const String _accessTokenKey = 'admin_access_token';

  static const String _tokenTypeKey = 'admin_token_type';

  static const String _expiresInKey = 'admin_token_expires_in';

  static const String _userJsonKey = 'admin_user_json';

  static Future<void> saveLoginResponse(dynamic response) async {
    final Map<String, dynamic> root = _asStringMap(response);

    final Map<String, dynamic> data = _asStringMap(root['data'] ?? root);

    final String accessToken = _readString(data, <String>[
      'access_token',
      'accessToken',
      'token',
    ]);

    if (accessToken.isEmpty) {
      throw StateError('The login response did not include an access token.');
    }

    final String tokenType = _readString(data, <String>[
      'token_type',
      'tokenType',
    ], fallback: 'Bearer');

    final String expiresIn = _readString(data, <String>[
      'expires_in',
      'expiresIn',
    ]);

    final Map<String, dynamic> user = _asStringMap(data['user']);

    await saveSession(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
      user: user,
    );
  }

  static Future<void> saveSession({
    required String accessToken,
    String tokenType = 'Bearer',
    String expiresIn = '',
    Map<String, dynamic> user = const <String, dynamic>{},
  }) async {
    final String normalizedToken = accessToken.trim();

    if (normalizedToken.isEmpty) {
      throw ArgumentError('Access token cannot be empty.');
    }

    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await preferences.setString(_accessTokenKey, normalizedToken);

    await preferences.setString(
      _tokenTypeKey,
      tokenType.trim().isEmpty ? 'Bearer' : tokenType.trim(),
    );

    await preferences.setString(_expiresInKey, expiresIn.trim());

    await preferences.setString(_userJsonKey, jsonEncode(user));
  }

  static Future<String?> getAccessToken() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String token = preferences.getString(_accessTokenKey)?.trim() ?? '';

    return token.isEmpty ? null : token;
  }

  static Future<String> getTokenType() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String value = preferences.getString(_tokenTypeKey)?.trim() ?? '';

    return value.isEmpty ? 'Bearer' : value;
  }

  static Future<String> getExpiresIn() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    return preferences.getString(_expiresInKey)?.trim() ?? '';
  }

  static Future<Map<String, dynamic>> getUser() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final String rawJson = preferences.getString(_userJsonKey)?.trim() ?? '';

    if (rawJson.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final dynamic decoded = jsonDecode(rawJson);

      return _asStringMap(decoded);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<String> getUserName() async {
    final Map<String, dynamic> user = await getUser();

    return _readString(user, <String>['name', 'full_name', 'fullName']);
  }

  static Future<String> getUserEmail() async {
    final Map<String, dynamic> user = await getUser();

    return _readString(user, <String>['email']);
  }

  static Future<String> getUserRole() async {
    final Map<String, dynamic> user = await getUser();

    return _readString(user, <String>['role']);
  }

  static Future<bool> isAuthenticated() async {
    final String? token = await getAccessToken();

    return token != null && token.trim().isNotEmpty;
  }

  static Future<void> clear() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await Future.wait<bool>(<Future<bool>>[
      preferences.remove(_accessTokenKey),
      preferences.remove(_tokenTypeKey),
      preferences.remove(_expiresInKey),
      preferences.remove(_userJsonKey),
    ]);
  }

  static Map<String, dynamic> _asStringMap(dynamic source) {
    if (source is Map<String, dynamic>) {
      return source;
    }

    if (source is Map) {
      return source.map<String, dynamic>((dynamic key, dynamic value) {
        return MapEntry<String, dynamic>(key.toString(), value);
      });
    }

    return <String, dynamic>{};
  }

  static String _readString(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final String key in keys) {
      final dynamic value = source[key];

      if (value == null) {
        continue;
      }

      final String normalized = value.toString().trim();

      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return fallback;
  }
}
