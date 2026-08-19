// import 'package:flutter/foundation.dart';

// class ApiConstants {
//   static String get baseUrl {
//     if (kIsWeb) {
//       return 'http://localhost:5000/api';
//     }

//     if (defaultTargetPlatform == TargetPlatform.android) {
//       return 'http://10.0.2.2:5000/api';
//     }

//     return 'http://localhost:5000/api';
//   }

//   static String get mobileLogin => '$baseUrl/mobile/login';

//   static String get categories => '$baseUrl/mobile/categories';

//   static String get clientsByCategory => '$baseUrl/mobile/clients';

//   static String clientDeliverables({
//     required int clientId,
//     required String categorySlug,
//   }) {
//     return '$baseUrl/mobile/clients/$clientId/deliverables?category=$categorySlug';
//   }
// } 

import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    return 'https://client.godigitalindia.co/api';
  }

  static String get mobileLogin => '$baseUrl/mobile/login';

  static String get categories => '$baseUrl/mobile/categories';

  static String get clientsByCategory => '$baseUrl/mobile/clients';

  static String clientDeliverables({
    required int clientId,
    required String categorySlug,
  }) {
    return '$baseUrl/mobile/clients/$clientId/deliverables?category=$categorySlug';
  }
}


