class ApiConstants {
  static const String baseUrl = 'http://localhost:5000/api';

  static const String login = '$baseUrl/auth/login';
  static const String signup = '$baseUrl/auth/signup';
  static const String me = '$baseUrl/auth/me';

  static const String assets = '$baseUrl/assets';
  static const String repository = '$baseUrl/assets/repository';
}