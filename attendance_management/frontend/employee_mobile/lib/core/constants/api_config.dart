import 'package:flutter/foundation.dart';

class ApiConfig {
  // ==============================
  // BASE URL
  // ==============================

  static String get baseUrl {
    // Flutter Web
    if (kIsWeb) {
      // Local Web
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:3000/api';
      }

      // Production Web
      return 'https://attendance.godigitalindia.co/api';
    }

    // Android Release APK
    if (kReleaseMode) {
      return 'https://attendance.godigitalindia.co/api';
    }

    // Android Debug - Emulator
    return 'http://10.0.2.2:3000/api';

    // Android Debug - Physical Phone
    // return 'http://YOUR_PC_IP:3000/api';
  }

  // ==============================
  // SOCKET URL
  // ==============================

  static String get socketUrl {
    // Flutter Web
    if (kIsWeb) {
      // Local Web
      if (Uri.base.host == 'localhost' ||
          Uri.base.host == '127.0.0.1') {
        return 'http://localhost:3000';
      }

      // Production Web
      return 'https://attendance.godigitalindia.co';
    }

    // Android Release APK
    if (kReleaseMode) {
      return 'https://attendance.godigitalindia.co';
    }

    // Android Debug - Emulator
    return 'http://10.0.2.2:3000';

    // Android Debug - Physical Phone
    // return 'http://YOUR_PC_IP:3000';
  }
}