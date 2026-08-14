import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'screens/splash_page.dart';

void main() {
  runApp(const GoDigitalMobileApp());
}

class GoDigitalMobileApp extends StatelessWidget {
  const GoDigitalMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}