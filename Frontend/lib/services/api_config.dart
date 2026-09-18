import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
        return 'http://localhost:3000/api';
      }

      return '/api';
    }

    return 'http://10.0.2.2:3000/api';
  }

  static String get socketUrl {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
        return 'http://localhost:3000';
      }

      return Uri.base.origin;
    }

    return 'http://10.0.2.2:3000';
  }
}