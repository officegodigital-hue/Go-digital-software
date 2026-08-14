import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../services/mobile_service.dart';
import 'home_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final MobileService mobileService = MobileService();

  String username = 'user@example.com';

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('mobile_username');

    if (!mounted) return;

    setState(() {
      username = savedUsername ?? 'user@example.com';
    });
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text('Are you sure you want to logout from this app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await mobileService.logoutMobileApp();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  void showAboutApp() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('About App'),
          content: const Text(
            'Go Digital Client Work Repository app helps clients view their Digital Marketing and Software Development project files, links, portfolios, packages, photos, and credentials in one place.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Privacy Policy'),
          content: const Text(
            'Your project details, links, and login information are used only to display client work inside this app. We do not share your data with third parties. Please keep your login details confidential.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Container(
                      width: 74,
                      height: 74,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Go Digital User',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      username,
                      style: const TextStyle(
                        color: AppColors.greyText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    profileTile(
                      icon: Icons.info_outline,
                      title: 'About App',
                      iconColor: AppColors.primary,
                      textColor: AppColors.darkText,
                      onTap: showAboutApp,
                    ),
                    profileTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      iconColor: AppColors.primary,
                      textColor: AppColors.darkText,
                      onTap: showPrivacyPolicy,
                    ),
                    profileTile(
                      icon: Icons.logout,
                      title: 'Logout',
                      iconColor: Colors.red,
                      textColor: Colors.red,
                      onTap: logout,
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget profileTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 17,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFB8C0CC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget bottomNavigation() {
    return Container(
      height: 70,
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: goHome,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.home_outlined,
                    color: Color(0xFFB8C0CC),
                    size: 23,
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Home',
                    style: TextStyle(
                      color: Color(0xFFB8C0CC),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 23,
                ),
                SizedBox(height: 3),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}