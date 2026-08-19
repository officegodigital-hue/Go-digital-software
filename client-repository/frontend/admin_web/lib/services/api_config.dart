import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // Local development
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5001/api';
      } 

      // Production
      // Nginx proxies /api to Node.js backend
      return '/api';
    }

    // Android Emulator
    return 'http://10.0.2.2:5001/api';
  }

  static String get socketUrl {
    if (kIsWeb) {
      // Local development
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5001';
      }

      // Production
      return Uri.base.origin;
    }

    // Android Emulator
    return 'http://10.0.2.2:5001';
  }
}