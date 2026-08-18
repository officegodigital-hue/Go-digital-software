import 'dart:async';

import 'package:flutter/material.dart';

import 'core/auth/admin_auth_controller.dart';
import 'core/auth/admin_login_page.dart';
import 'core/theme/admin_theme.dart';
import 'features/dashboard/presentation/screens/admin_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const AdminWebApp());
}

class AdminWebApp extends StatefulWidget {
  const AdminWebApp({
    super.key,
  });

  @override
  State<AdminWebApp> createState() {
    return _AdminWebAppState();
  }
}

class _AdminWebAppState extends State<AdminWebApp> {
  late final AdminAuthController _authController;

  @override
  void initState() {
    super.initState();

    _authController = AdminAuthController();
    _authController.addListener(
      _handleAuthChanged,
    );

    unawaited(
      _authController.initialize(),
    );
  }

  @override
  void dispose() {
    _authController
      ..removeListener(
        _handleAuthChanged,
      )
      ..dispose();

    super.dispose();
  }

  void _handleAuthChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      title: 'Attendance Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.lightTheme,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        final MediaQueryData mediaQuery =
            MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler:
                const TextScaler.linear(
              1.28,
            ),
          ),
          child:
              child ??
              const SizedBox.shrink(),
        );
      },
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_authController.isInitializing) {
      return const _AdminSessionLoadingPage();
    }

    if (!_authController.isAuthenticated) {
      return AdminLoginPage(
        controller: _authController,
        onLoginSuccess: () {
          /*
           * AdminAuthController notifies this
           * widget automatically after login.
           */
        },
      );
    }

    return AdminDashboardScreen(
      authController: _authController,
    );
  }
}

class _AdminSessionLoadingPage
    extends StatelessWidget {
  const _AdminSessionLoadingPage();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Checking admin session...',
            ),
          ],
        ),
      ),
    );
  }
}