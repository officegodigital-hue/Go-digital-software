import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // ==============================
    // FLUTTER WEB
    // ==============================
    if (kIsWeb) {
      // Local web
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5002/api';
      }

      // Production web
      return 'https://attendance.godigitalindia.co/api';
    }

    // ==============================
    // ANDROID MOBILE
    // ==============================

    // Release APK -> Production server
    if (kReleaseMode) {
      return 'https://attendance.godigitalindia.co/api';
    }

    // Debug APK -> Local backend
    // Android Emulator
    return 'http://10.0.2.2:5002/api';

    // Physical Android phone:
    // return 'http://192.168.1.100:5002/api';
  }

  static String get socketUrl {
    // ==============================
    // FLUTTER WEB
    // ==============================
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5002';
      }

      return 'https://attendance.godigitalindia.co';
    }

    // ==============================
    // ANDROID MOBILE
    // ==============================

    // Release APK -> Production
    if (kReleaseMode) {
      return 'https://attendance.godigitalindia.co';
    }

    // Debug APK -> Local
    return 'http://10.0.2.2:5002';

    // Physical Android phone:
    // return 'http://192.168.1.100:5002';
  }
}