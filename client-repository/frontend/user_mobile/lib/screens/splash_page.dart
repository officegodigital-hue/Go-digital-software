import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../services/mobile_service.dart';
import 'home_page.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final MobileService mobileService = MobileService();

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    final isLoggedIn = await mobileService.isMobileLoggedIn();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? const HomePage() : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/godigital_logo.webp',
              width: 210,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 34),
            const CircularProgressIndicator(
              color: AppColors.primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'Loading...',
              style: TextStyle(
                color: AppColors.greyText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}