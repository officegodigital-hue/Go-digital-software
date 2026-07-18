import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      // Running on localhost
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
        return 'http://localhost:5000/api';
      }

      // Running from EC2/server
      // return 'http://${Uri.base.host}:3000/api';
       return '/api';
    }

    // Android Emulator
    return 'http://10.0.2.2:3000/api';

    // Physical Android Phone
    // return 'http://192.168.1.100:5000/api';
  }
}

