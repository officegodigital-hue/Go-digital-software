import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
<<<<<<< HEAD
        return 'http://localhost:5000/api';
=======
        return 'http://localhost:3000/api';
>>>>>>> 455b2ca5f53a51c29bae443c43d3689fdfb1072b
      }

      return '/api';
    }

<<<<<<< HEAD
    return 'http://10.0.2.2:5000/api';
=======
    return 'http://10.0.2.2:3000/api';
>>>>>>> 455b2ca5f53a51c29bae443c43d3689fdfb1072b
  }

  static String get socketUrl {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
<<<<<<< HEAD
        return 'http://localhost:5000';
=======
        return 'http://localhost:3000';
>>>>>>> 455b2ca5f53a51c29bae443c43d3689fdfb1072b
      }

      return Uri.base.origin;
    }

<<<<<<< HEAD
    return 'http://10.0.2.2:5000';
=======
    return 'http://10.0.2.2:3000';
>>>>>>> 455b2ca5f53a51c29bae443c43d3689fdfb1072b
  }
}
