import 'package:flutter/material.dart';

/// Color tokens read directly off the approved reference screens
/// (Admin Dashboard / Employees / Approvals / Payroll / Tracking, and the
/// Employee web + mobile app). Keep every screen deriving from these
/// instead of picking new colors ad hoc.
class HrmsColors {
  HrmsColors._();

  // Brand
  static const Color primary = Color(0xFF2F6BFF);       // active nav pill, primary buttons
  static const Color primaryDark = Color(0xFF14213D);    // employee-app dark header / navy blocks
  static const Color accentPurple = Color(0xFF7C3AED);   // Leave section header
  static const Color accentOrange = Color(0xFFF97316);   // Extra Hours section header
  static const Color accentTeal = Color(0xFF0D9488);     // Tracking section header

  // Surfaces
  static const Color pageBackground = Color(0xFFF4F6FA);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE5E9F0);

  // Text
  static const Color textPrimary = Color(0xFF14213D);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Status — each has a foreground (text/icon) and a soft background
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);

  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);

  static const Color neutral = Color(0xFF6B7280);
  static const Color neutralBg = Color(0xFFF1F5F9);
}
