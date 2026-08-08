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
        ChangeNotifierProvider(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "GoDigital Portal",

        // Always start from auth checking.
        initialRoute: '/',

        onUnknownRoute: (settings) {
          debugPrint("ERROR: Route not found: ${settings.name}");

          return MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: Text(
                  "Route ${settings.name} not found",
                ),
              ),
            ),
          );
        },

        routes: {
          // ─────────────────────────────────────────────
          // LOGIN
          // ─────────────────────────────────────────────
          '/': (context) => const LoginGate(),

          // ─────────────────────────────────────────────
          // HOME
          // ─────────────────────────────────────────────
          // '/home': (context) => const AuthGuard(
          //       child: HomeScreen(),
          //     ),

          // ─────────────────────────────────────────────
          // ADMIN DASHBOARD
          // ─────────────────────────────────────────────
          '/admin': (context) => const AdminGuard(
                child: AdminDashboard(),
              ),

          // ─────────────────────────────────────────────
          // EMPLOYEE
          // ─────────────────────────────────────────────
          '/employee': (context) => const EmployeeGuard(
                child: EmployeeLayoutPage(),
              ),

          '/designer': (context) => const EmployeeGuard(
                child: EmployeeLayoutPage(),
              ),

          '/pageHandler': (context) => const EmployeeGuard(
                child: EmployeeLayoutPage(),
              ),

          '/adsHandler': (context) => const EmployeeGuard(
                child: EmployeeLayoutPage(),
              ),

          '/videographer': (context) => const EmployeeGuard(
                child: EmployeeLayoutPage(),
              ),

          // ─────────────────────────────────────────────
          // ADMIN MANAGEMENT ROUTES
          // ─────────────────────────────────────────────
          '/client': (context) => const AdminGuard(
                child: ClientOnboardingScreen(),
              ),

          '/client-history': (context) => const AdminGuard(
                child: ClientHistoryScreen(),
              ),

          '/quotation': (context) => const AdminGuard(
                child: PackageQuotationAdmin(),
              ),

          '/create-quotation': (context) => const AdminGuard(
                child: CreateQuotationScreen(),
              ),

          '/invoice': (context) => const AdminGuard(
                child: InvoiceAdminScreen(),
              ),

          '/add-invoice': (context) => const AdminGuard(
                child: AddInvoiceScreen(),
              ),

          '/tasks': (context) => const AdminGuard(
                child: TasksAssignScreen(),
              ),

          '/daily-planner': (context) => const AdminGuard(
                child: AdminDayPlannerScreen(),
              ),

          '/employee-status': (context) => const AdminGuard(
                child: EmployeeStatusScreen(),
              ),

          '/manager-review': (context) => const AdminGuard(
                child: ManagerReviewScreen(),
              ),

          '/notifications': (context) => const AuthGuard(
                child: NotificationsScreen(),
              ),

          '/admin-panel': (context) => const AdminGuard(
                child: AdminPanelScreen(),
              ),

          '/time-manager': (context) => const AdminGuard(
                child: TimeManagerScreen(),
              ),

          '/performance': (context) => const AdminGuard(
                child: PerformanceScreen(),
              ),

          '/settings': (context) => const AuthGuard(
                child: SettingsPage(),
              ),

          '/attendance': (context) => const AdminGuard(
                child: AttendanceDashboard(),
              ),
        },
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════
// LOGIN GATE
// ═══════════════════════════════════════════════════════

class LoginGate extends StatelessWidget {
  const LoginGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        // Wait until stored session is loaded.
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // No login → Login page.
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        // Already logged in.
        return const LoggedInRedirect();
      },
    );
  }
}


// ═══════════════════════════════════════════════════════
// LOGGED-IN REDIRECT
// ═══════════════════════════════════════════════════════

class LoggedInRedirect extends StatefulWidget {
  const LoggedInRedirect({super.key});

  @override
  State<LoggedInRedirect> createState() => _LoggedInRedirectState();
}

class _LoggedInRedirectState extends State<LoggedInRedirect> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirect();
    });
  }

  void _redirect() {
    if (!mounted) return;

    final auth = context.read<AuthService>();

    final userType =
        auth.userType?.toLowerCase().trim() ?? '';

    final role =
        auth.userRole?.toLowerCase().trim() ?? '';

    debugPrint(
      '🔐 Existing session found: '
      'userType=$userType, role=$role',
    );

    // Admin
    if (userType == 'admin') {
      Navigator.pushReplacementNamed(
        context,
        '/admin',
      );
      return;
    }

    // Employee
    Navigator.pushReplacementNamed(
      context,
      '/home',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════
// COMMON AUTH GUARD
// ═══════════════════════════════════════════════════════

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({
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

        return child;
      },
    );
  }
}


// ═══════════════════════════════════════════════════════
// ADMIN GUARD
// ═══════════════════════════════════════════════════════

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
        // Wait for stored auth data.
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Not logged in → Login page.
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        final userType =
            auth.userType?.toLowerCase().trim() ?? '';

        // Logged in but not admin.
        if (userType != 'admin') {
          debugPrint(
            '🚫 Admin access denied for userType: $userType',
          );

          return const AccessDeniedScreen();
        }

        // Correct admin session.
        return child;
      },
    );
  }
}


// ═══════════════════════════════════════════════════════
// EMPLOYEE GUARD
// ═══════════════════════════════════════════════════════

class EmployeeGuard extends StatelessWidget {
  final Widget child;

  const EmployeeGuard({
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

        final userType =
            auth.userType?.toLowerCase().trim() ?? '';

        if (userType == 'admin') {
          return const AccessDeniedScreen();
        }

        return child;
      },
    );
  }
}


// ═══════════════════════════════════════════════════════
// ACCESS DENIED
// ═══════════════════════════════════════════════════════

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 60,
              color: Colors.redAccent,
            ),

            const SizedBox(height: 16),

            const Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'You do not have permission to access this page.',
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                await context.read<AuthService>().logout();

                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }
}