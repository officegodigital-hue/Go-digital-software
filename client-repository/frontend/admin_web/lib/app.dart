import 'package:flutter/material.dart';
import 'config/routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';

class GoDigitalAdminApp extends StatelessWidget {
  const GoDigitalAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoDigital Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: AppRoutes.routes,
      home: const LoginPage(),
    );
  }
}