import 'package:flutter/material.dart';

class AdminColors {
  const AdminColors._();

  // ---------------------------------------------------------------------------
  // Brand colors
  // ---------------------------------------------------------------------------

  static const Color primary = Color(0xFF1919EC);
  static const Color primaryHover = Color(0xFF2929F2);
  static const Color primaryDark = Color(0xFF1010B8);
  static const Color primaryLight = Color(0xFFE8E9FF);

  static const Color navy = Color(0xFF03233D);
  static const Color navyLight = Color(0xFF0B3553);
  static const Color navyBorder = Color(0xFF0D3856);

  // ---------------------------------------------------------------------------
  // Page and surface colors
  // ---------------------------------------------------------------------------

  static const Color pageBackground = Color(0xFFF7F8FA);
  static const Color workspaceBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF4F5F7);
  static const Color surfaceMuted = Color(0xFFF0F1F3);
  static const Color surfaceHover = Color(0xFFF7F7FA);

  // ---------------------------------------------------------------------------
  // Text colors
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Color(0xFF20232A);
  static const Color textSecondary = Color(0xFF555B68);
  static const Color textMuted = Color(0xFF717784);
  static const Color textDisabled = Color(0xFFA8ADB7);

  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkMuted = Color(0xFFD2DCE5);

  // ---------------------------------------------------------------------------
  // Border and divider colors
  // ---------------------------------------------------------------------------

  static const Color border = Color(0xFFD8DBE2);
  static const Color borderLight = Color(0xFFE7E9EE);
  static const Color divider = Color(0xFFE7E9EE);
  static const Color inputBorder = Color(0xFFD8DBE2);
  static const Color inputDisabledBorder = Color(0xFFE4E6EB);

  // ---------------------------------------------------------------------------
  // Status colors
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF168B55);
  static const Color successDark = Color(0xFF0F7043);
  static const Color successBackground = Color(0xFFE4F5EA);
  static const Color successBorder = Color(0xFFB9E5C9);

  static const Color warning = Color(0xFFA7651B);
  static const Color warningDark = Color(0xFF815019);
  static const Color warningBackground = Color(0xFFFFF0D8);
  static const Color warningBorder = Color(0xFFF1D19A);

  static const Color danger = Color(0xFFCF2028);
  static const Color dangerDark = Color(0xFFA91920);
  static const Color dangerBackground = Color(0xFFFFE4E5);
  static const Color dangerBorder = Color(0xFFF1B9BC);

  static const Color info = Color(0xFF3546C5);
  static const Color infoDark = Color(0xFF26369E);
  static const Color infoBackground = Color(0xFFE5E9FF);
  static const Color infoBorder = Color(0xFFBEC7FA);

  // ---------------------------------------------------------------------------
  // Attendance status colors
  // ---------------------------------------------------------------------------

  static const Color present = Color(0xFF3B9A50);
  static const Color presentBackground = Color(0xFFE4F5EA);

  static const Color absent = Color(0xFFC72931);
  static const Color absentBackground = Color(0xFFFFE4E5);

  static const Color late = Color(0xFF9A601F);
  static const Color lateBackground = Color(0xFFFFF0D8);

  static const Color workFromHome = Color(0xFF3546C5);
  static const Color workFromHomeBackground = Color(0xFFE5E9FF);

  static const Color permission = Color(0xFF71717A);
  static const Color permissionBackground = Color(0xFFF0F1F3);

  // ---------------------------------------------------------------------------
  // Chart colors
  // ---------------------------------------------------------------------------

  static const Color chartBlue = Color(0xFF1919E5);
  static const Color chartGreen = Color(0xFF3B9A50);
  static const Color chartOrange = Color(0xFF9A601F);
  static const Color chartRed = Color(0xFFC72931);
  static const Color chartPurple = Color(0xFF6D45C8);
  static const Color chartGrey = Color(0xFFE7E7EB);
  static const Color chartGrid = Color(0xFFEBECF0);

  // ---------------------------------------------------------------------------
  // Avatar colors
  // ---------------------------------------------------------------------------

  static const Color avatarBlue = Color(0xFFE4E8FF);
  static const Color avatarBlueText = Color(0xFF3137C9);

  static const Color avatarGreen = Color(0xFFC9F2DF);
  static const Color avatarGreenText = Color(0xFF168B55);

  static const Color avatarRed = Color(0xFFFFD9CF);
  static const Color avatarRedText = Color(0xFFC8272F);

  static const Color avatarPurple = Color(0xFFE8E1FF);
  static const Color avatarPurpleText = Color(0xFF6643B5);

  static const Color avatarOrange = Color(0xFFFFE5C2);
  static const Color avatarOrangeText = Color(0xFF9A601F);

  // ---------------------------------------------------------------------------
  // Overlay and shadow colors
  // ---------------------------------------------------------------------------

  static const Color overlay = Color(0x73000000);
  static const Color lightOverlay = Color(0x14000000);
  static const Color shadow = Color(0x1F000000);

  // ---------------------------------------------------------------------------
  // Utility methods
  // ---------------------------------------------------------------------------

  static Color statusColor(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'active':
      case 'approved':
      case 'present':
      case 'completed':
      case 'success':
        return success;

      case 'pending':
      case 'late':
      case 'waiting':
      case 'in review':
        return warning;

      case 'inactive':
      case 'rejected':
      case 'absent':
      case 'failed':
      case 'disabled':
        return danger;

      case 'wfh':
      case 'work from home':
      case 'information':
        return info;

      default:
        return textMuted;
    }
  }

  static Color statusBackgroundColor(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'active':
      case 'approved':
      case 'present':
      case 'completed':
      case 'success':
        return successBackground;

      case 'pending':
      case 'late':
      case 'waiting':
      case 'in review':
        return warningBackground;

      case 'inactive':
      case 'rejected':
      case 'absent':
      case 'failed':
      case 'disabled':
        return dangerBackground;

      case 'wfh':
      case 'work from home':
      case 'information':
        return infoBackground;

      default:
        return surfaceMuted;
    }
  }

  static Color attendanceColor(String? attendanceStatus) {
    switch (attendanceStatus?.trim().toLowerCase()) {
      case 'present':
      case 'on time':
        return present;

      case 'absent':
        return absent;

      case 'late':
      case 'late login':
        return late;

      case 'wfh':
      case 'work from home':
        return workFromHome;

      case 'permission':
      case 'leave':
        return permission;

      default:
        return textMuted;
    }
  }
}
