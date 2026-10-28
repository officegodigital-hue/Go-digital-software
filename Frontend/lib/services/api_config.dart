import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;

    if (kIsWeb) {
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:3000/api';
      }

      return '/api';
    }

    if (kReleaseMode) {
      return 'https://godigitalindia.co/api';
    }

    return 'http://10.0.2.2:3000/api';
  }

  static String get socketUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    }

    if (kIsWeb) {
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:3000';
      }

      return Uri.base.origin;
    }

    if (kReleaseMode) {
      return 'https://godigitalindia.co';
    }

    return 'http://10.0.2.2:3000';
  }
}
