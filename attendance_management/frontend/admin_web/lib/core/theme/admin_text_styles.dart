import 'package:flutter/material.dart';

class AdminTextStyles {
  const AdminTextStyles._();

  static const Color _primaryText = Color(0xFF20232A);
  static const Color _secondaryText = Color(0xFF555B68);
  static const Color _mutedText = Color(0xFF717784);
  static const Color _primaryBlue = Color(0xFF1919EC);
  static const Color _success = Color(0xFF168B55);
  static const Color _warning = Color(0xFFA7651B);
  static const Color _danger = Color(0xFFCF2028);

  // ---------------------------------------------------------------------------
  // Page headings
  // ---------------------------------------------------------------------------

  static const TextStyle pageTitle = TextStyle(
    color: _primaryText,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.35,
  );

  static const TextStyle pageSubtitle = TextStyle(
    color: _mutedText,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: _primaryText,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.15,
  );

  static const TextStyle sectionSubtitle = TextStyle(
    color: _mutedText,
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  // ---------------------------------------------------------------------------
  // Dashboard cards
  // ---------------------------------------------------------------------------

  static const TextStyle cardTitle = TextStyle(
    color: _primaryText,
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: _mutedText,
    fontSize: 10,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle metricLabel = TextStyle(
    color: Colors.white,
    fontSize: 9,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.15,
  );

  static const TextStyle metricValue = TextStyle(
    color: _primaryText,
    fontSize: 24,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static const TextStyle metricDescription = TextStyle(
    color: _mutedText,
    fontSize: 9,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  // ---------------------------------------------------------------------------
  // Top bar
  // ---------------------------------------------------------------------------

  static const TextStyle topBarTitle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static const TextStyle searchText = TextStyle(
    color: _primaryText,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle searchHint = TextStyle(
    color: Color(0xFF7C818D),
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle profileName = TextStyle(
    color: Colors.white,
    fontSize: 11,
    height: 1.15,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle profileRole = TextStyle(
    color: Color(0xFFD5DEE7),
    fontSize: 9,
    height: 1.15,
    fontWeight: FontWeight.w500,
  );

  // ---------------------------------------------------------------------------
  // Sidebar
  // ---------------------------------------------------------------------------

  static const TextStyle sidebarBrand = TextStyle(
    color: Colors.white,
    fontSize: 14,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
  );

  static const TextStyle sidebarCaption = TextStyle(
    color: Color(0xFFD2DCE5),
    fontSize: 9,
    height: 1.15,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle sidebarItem = TextStyle(
    color: Colors.white,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle sidebarItemActive = TextStyle(
    color: Colors.white,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  // ---------------------------------------------------------------------------
  // Body text
  // ---------------------------------------------------------------------------

  static const TextStyle bodyLarge = TextStyle(
    color: _primaryText,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: _secondaryText,
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySmall = TextStyle(
    color: _mutedText,
    fontSize: 10,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    color: _mutedText,
    fontSize: 9,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  // ---------------------------------------------------------------------------
  // Form labels and inputs
  // ---------------------------------------------------------------------------

  static const TextStyle fieldLabel = TextStyle(
    color: _secondaryText,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle fieldValue = TextStyle(
    color: _primaryText,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle fieldHint = TextStyle(
    color: Color(0xFF8A8F99),
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle helperText = TextStyle(
    color: _mutedText,
    fontSize: 9,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle errorText = TextStyle(
    color: _danger,
    fontSize: 9,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  // ---------------------------------------------------------------------------
  // Buttons and links
  // ---------------------------------------------------------------------------

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 11,
    height: 1.15,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle buttonLabelSmall = TextStyle(
    fontSize: 9,
    height: 1.15,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle link = TextStyle(
    color: _primaryBlue,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle linkSmall = TextStyle(
    color: _primaryBlue,
    fontSize: 9,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  // ---------------------------------------------------------------------------
  // Tables
  // ---------------------------------------------------------------------------

  static const TextStyle tableHeader = TextStyle(
    color: _primaryText,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.15,
  );

  static const TextStyle tableBody = TextStyle(
    color: _secondaryText,
    fontSize: 10,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tableBodyStrong = TextStyle(
    color: _primaryText,
    fontSize: 10,
    height: 1.35,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle tableCaption = TextStyle(
    color: _mutedText,
    fontSize: 9,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  // ---------------------------------------------------------------------------
  // Employees
  // ---------------------------------------------------------------------------

  static const TextStyle employeeName = TextStyle(
    color: _primaryText,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle employeeDetails = TextStyle(
    color: _mutedText,
    fontSize: 9,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle employeeCode = TextStyle(
    color: _primaryBlue,
    fontSize: 9,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  // ---------------------------------------------------------------------------
  // Badges
  // ---------------------------------------------------------------------------

  static const TextStyle badgeText = TextStyle(
    fontSize: 8,
    height: 1,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle statusActive = TextStyle(
    color: _success,
    fontSize: 8,
    height: 1,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle statusPending = TextStyle(
    color: _warning,
    fontSize: 8,
    height: 1,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle statusInactive = TextStyle(
    color: _danger,
    fontSize: 8,
    height: 1,
    fontWeight: FontWeight.w700,
  );

  // ---------------------------------------------------------------------------
  // Activity and permissions
  // ---------------------------------------------------------------------------

  static const TextStyle activityName = TextStyle(
    color: _primaryText,
    fontSize: 10,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle activityDescription = TextStyle(
    color: _secondaryText,
    fontSize: 9,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle activityTime = TextStyle(
    color: _mutedText,
    fontSize: 8,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle permissionTitle = TextStyle(
    color: _primaryText,
    fontSize: 10,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle permissionDescription = TextStyle(
    color: _mutedText,
    fontSize: 9,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  static const TextStyle dialogTitle = TextStyle(
    color: _primaryText,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle dialogBody = TextStyle(
    color: _secondaryText,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  // ---------------------------------------------------------------------------
  // Empty, loading and error states
  // ---------------------------------------------------------------------------

  static const TextStyle emptyStateTitle = TextStyle(
    color: _primaryText,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle emptyStateBody = TextStyle(
    color: _mutedText,
    fontSize: 11,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle successMessage = TextStyle(
    color: _success,
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle warningMessage = TextStyle(
    color: _warning,
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle dangerMessage = TextStyle(
    color: _danger,
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
}
