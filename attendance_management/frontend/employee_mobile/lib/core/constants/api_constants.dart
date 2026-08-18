class ApiConstants {
  const ApiConstants._();

  // ==============================
  // BASE URL
  // ==============================

  // Android Emulator
static const String baseUrl =
    'http://127.0.0.1:3000/api/v1';


  // For real mobile device use your PC IP:
  // Example:
  // static const String baseUrl =
  //     'http://192.168.1.25:3000/api/v1';



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

  // Login
  // POST /api/v1/auth/login

  static const String login =
      '/auth/login';


  // Current logged-in employee
  // GET /api/v1/auth/me

  static const String currentUser =
      '/auth/me';



  // ==============================
  // ATTENDANCE
  // ==============================


  // Today's attendance
  // GET /attendance/today

  static const String attendanceToday =
      '/attendance/today';



  // Check In
  // POST /attendance/check-in

  static const String attendanceCheckIn =
      '/attendance/check-in';



  // Check Out
  // POST /attendance/check-out

  static const String attendanceCheckOut =
      '/attendance/check-out';



  // Start Break
  // POST /attendance/breaks/start

  static const String attendanceStartBreak =
      '/attendance/breaks/start';



  // End Break
  // POST /attendance/breaks/end

  static const String attendanceEndBreak =
      '/attendance/breaks/end';



  // ==============================
  // ATTENDANCE HISTORY
  // ==============================


  // GET /attendance/history

  static const String attendanceHistory =
      '/attendance/history';



  // ==============================
  // LEAVE MANAGEMENT
  // ==============================


  // Leave Dashboard

  static const String leaveDashboard =
      '/leaves/dashboard';



  // Leave History

  static const String leaveHistory =
      '/leaves/history';



  // Apply Leave

  static const String leaveApply =
      '/leaves';



  // Cancel Leave

  static String leaveCancel(
    int leaveRequestId,
  ) {
    return '/leaves/$leaveRequestId/cancel';
  }



  // ==============================
  // HELPER
  // ==============================


  static String imageUrl(
    String path,
  ) {
    return '$baseUrl/$path';
  }

}