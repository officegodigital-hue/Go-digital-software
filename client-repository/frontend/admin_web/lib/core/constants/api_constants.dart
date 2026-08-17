import '../../services/api_config.dart';

class ApiConstants {
  static String get baseUrl => ApiConfig.baseUrl;

  static String get login => '$baseUrl/auth/login';
  static String get signup => '$baseUrl/auth/signup';
  static String get me => '$baseUrl/auth/me';

  static String get assets => '$baseUrl/assets';
  static String get repository => '$baseUrl/assets/repository';
}