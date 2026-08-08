import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:godigital_portal/services/auth_service.dart';
import 'package:godigital_portal/screens/login_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/admin_dashboard.dart';
import 'package:godigital_portal/screens/employee_dashboard/employee_layout_page.dart';
import 'package:godigital_portal/screens/admin_dashboard/client_history_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/client_onboarding_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/Package_Quotation_admin.dart';
import 'package:godigital_portal/screens/admin_dashboard/create_quotation_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/invoice_admin_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/add_invoice_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/tasks_assign_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/employee_status_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/manager_review_screen.dart';
import 'package:godigital_portal/screens/notifications_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/admin_panel_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/time_management_screen.dart';
import 'package:godigital_portal/screens/admin_dashboard/performance_page.dart';
// import 'package:godigital_portal/screens/home_screen.dart';
import 'package:godigital_portal/screens/SettingsPage.dart';
import 'package:godigital_portal/screens/admin_dashboard/AdminDayPlannerScreen.dart';

import 'package:godigital_portal/screens/Attentance_admin/attendance_dashboard.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ChangeNotifierProvider for AuthService
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "GoDigital Portal",
        initialRoute: '/',
        onUnknownRoute: (settings) {
          debugPrint("ERROR: Route not found: ${settings.name}");
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: Text("Route ${settings.name} not found"),
              ),
            ),
          );
        },
        routes: {
          // Authentication
          '/': (context) => const LoginScreen(),

          // Home Screen (After Login)
          // '/home': (context) => const HomeScreen(),


          // Admin Dashboard
          // '/admin': (context) => const AdminDashboard(),
          '/admin': (context) => const AdminGuard(
  child: AdminDashboard(),
),

          // Employee Dashboard (General)
          '/employee': (context) => const EmployeeLayoutPage(),

          // Role-specific employee dashboards
          // These can all use EmployeeLayoutPage since it dynamically loads
          // the correct dashboard based on the user's role from AuthService
          '/designer': (context) => const EmployeeLayoutPage(),
          '/pageHandler': (context) => const EmployeeLayoutPage(),
          '/adsHandler': (context) => const EmployeeLayoutPage(),
          '/videographer': (context) => const EmployeeLayoutPage(),

          // Admin Management Routes
          '/client': (context) => const AdminGuard(
  child: ClientOnboardingScreen(),),
          '/client-history': (context) => const AdminGuard(
  child: ClientHistoryScreen(),),
          '/quotation': (context) => const AdminGuard(
  child: PackageQuotationAdmin(),),
          '/create-quotation': (context) => const AdminGuard(
  child: CreateQuotationScreen(),),
          '/invoice': (context) => const AdminGuard(
  child: InvoiceAdminScreen(),),
          '/add-invoice': (context) => const AdminGuard(
  child: AddInvoiceScreen(),),
          '/tasks': (context) => const AdminGuard(
  child: TasksAssignScreen(),),
          '/daily-planner': (context) => const AdminGuard(
  child: AdminDayPlannerScreen(),),
          '/employee-status': (context) => const AdminGuard(
  child: EmployeeStatusScreen(),),
          '/manager-review': (context) => const AdminGuard(
  child: ManagerReviewScreen(),),
          '/notifications': (context) => const AdminGuard(
  child: NotificationsScreen(),),
          '/admin-panel': (context) => const AdminGuard(
  child: AdminPanelScreen(),),
          '/time-manager': (context) => const AdminGuard(
  child: TimeManagerScreen(),),
          '/performance': (context) => const AdminGuard(
  child: PerformanceScreen(),),
          '/settings':(context) => const AdminGuard(
  child: SettingsPage(),),

          '/attendance': (context) => const AttendanceDashboard(),
        },
      ),
    );
  }
}



class AdminGuard extends StatelessWidget {
  final Widget child;

  const AdminGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        if (auth.userType?.toLowerCase().trim() != 'admin') {
          return const LoginScreen();
        }

        return child;
      },
    );
  }
}


