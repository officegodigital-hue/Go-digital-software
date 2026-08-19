class ApiConstants {
  const ApiConstants._();

  // ==============================
  // BASE URL
  // ==============================

static String get baseUrl {
  return 'https://attendance.godigitalindia.co/api/v1';
}

  // ==============================
  // TIMEOUT
  // ==============================

  static const Duration connectTimeout =
      Duration(seconds: 20);

  static const Duration receiveTimeout =
      Duration(seconds: 20);

  static const Duration sendTimeout =
      Duration(seconds: 20);

  // ==============================
  // AUTHENTICATION
  // ==============================

  static const String login =
      '/auth/login';

  static const String currentUser =
      '/auth/me';

  // ==============================
  // ATTENDANCE
  // ==============================

  static const String attendanceToday =
      '/attendance/today';

  static const String attendanceCheckIn =
      '/attendance/check-in';

  static const String attendanceCheckOut =
      '/attendance/check-out';

  static const String attendanceStartBreak =
      '/attendance/breaks/start';

  static const String attendanceEndBreak =
      '/attendance/breaks/end';

  // ==============================
  // ATTENDANCE HISTORY
  // ==============================

  static const String attendanceHistory =
      '/attendance/history';

  // ==============================
  // LEAVE MANAGEMENT
  // ==============================

  static const String leaveDashboard =
      '/leaves/dashboard';

  static const String leaveHistory =
      '/leaves/history';

  static const String leaveApply =
      '/leaves';

  static String leaveCancel(int leaveRequestId) {
    return '/leaves/$leaveRequestId/cancel';
  }

  // ==============================
  // HELPER
  // ==============================

  static String imageUrl(String path) {
    return '$baseUrl/$path';
  }
}