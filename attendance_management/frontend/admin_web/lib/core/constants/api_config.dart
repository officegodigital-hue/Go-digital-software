import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // ==============================
    // WEB
    // ==============================
    if (kIsWeb) {
      // Local development
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5002/api/v1';
      }

      // Production - Nginx
      return '/api/v1';
    }

    // ==============================
    // ANDROID
    // ==============================

    // Release APK
    if (kReleaseMode) {
      return 'https://attendance.godigitalindia.co/api/v1';
    }

    // Debug APK / Android Emulator
    return 'http://10.0.2.2:5002/api/v1';
  }

  static String get socketUrl {
    // ==============================
    // WEB
    // ==============================
    if (kIsWeb) {
      // Local development
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5002';
      }

      // Production
      return Uri.base.origin;
    }

    // ==============================
    // ANDROID
    // ==============================

    // Release APK
    if (kReleaseMode) {
      return 'https://attendance.godigitalindia.co';
    }

    // Debug APK / Android Emulator
    return 'http://10.0.2.2:5002';
  }
}