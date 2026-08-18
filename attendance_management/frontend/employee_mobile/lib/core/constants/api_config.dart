import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5002/api';
      }

      return 'https://attendance.godigitalindia.co/api';
    }

    // Release APK
    if (kReleaseMode) {
      return 'https://attendance.godigitalindia.co/api';
    }

    // Debug Android Emulator
    return 'http://10.0.2.2:5002/api';
  }

  static String get socketUrl {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5002';
      }

      return 'https://attendance.godigitalindia.co';
    }

    // Release APK
    if (kReleaseMode) {
      return 'https://attendance.godigitalindia.co';
    }

    // Debug Android Emulator
    return 'http://10.0.2.2:5002';
  }
}