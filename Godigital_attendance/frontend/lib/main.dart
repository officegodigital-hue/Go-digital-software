import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/screens/login_screen.dart';
import 'package:godigital_portal/hrms_admin/app/app.dart' as hrms_admin;
import 'package:godigital_portal/hrms_employee/pages/dashboard_page.dart';
import 'package:godigital_portal/hrms_employee/pages/attendance_page.dart';
import 'package:godigital_portal/hrms_employee/pages/clock_page.dart';
import 'package:godigital_portal/hrms_employee/pages/leave_page.dart';
import 'package:godigital_portal/hrms_employee/pages/permission_page.dart';
import 'package:godigital_portal/hrms_employee/pages/extra_hours_page.dart';
import 'package:godigital_portal/hrms_employee/pages/salary_page.dart';
import 'package:godigital_portal/hrms_employee/pages/tracking_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AuthService(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoDigital Attendance',
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGate(),
        '/home': (_) => const AttendanceEntry(),
        '/attendance': (_) => const AttendanceEntry(),
        '/employee/dashboard': (_) => const EmployeeDashboardPage(),
        '/employee/attendance': (_) => const EmployeeAttendancePage(),
        '/employee/clock-log': (_) => const EmployeeClockPage(),
        '/employee/leave': (_) => const EmployeeLeavePage(),
        '/employee/permission': (_) => const EmployeePermissionPage(),
        '/employee/extra-hours': (_) => const EmployeeExtraHoursPage(),
        '/employee/salary': (_) => const EmployeeSalaryPage(),
        '/employee/tracking': (_) => const EmployeeTrackingPage(),
      },
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => Consumer<AuthService>(
    builder: (_, auth, __) {
      if (!auth.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return auth.isAuthenticated ? const AttendanceEntry() : const LoginScreen();
    },
  );
}

class AttendanceEntry extends StatelessWidget {
  const AttendanceEntry({super.key});
  @override
  Widget build(BuildContext context) => Consumer<AuthService>(
    builder: (_, auth, __) {
      if (!auth.isAuthenticated) return const LoginScreen();
      return auth.userType?.toLowerCase().trim() == 'admin'
        ? hrms_admin.AdminPortalApp()
        : const EmployeeDashboardPage();
    },
  );
}
