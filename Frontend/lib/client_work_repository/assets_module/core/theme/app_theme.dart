import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF2563EB);
  static const darkNavy = Color(0xFF0B2348);
  static const background = Color(0xFFEEF2F7);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textBody = Color(0xFF374151);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const lightGray = Color(0xFFF3F4F6);
  static const digitalMarketing = Color(0xFF8B3DFF);
  static const digitalMarketingLight = Color(0xFFF3E9FF);
  static const softwareDevelopment = Color(0xFF16A86B);
  static const softwareDevelopmentLight = Color(0xFFE4F8EF);
  static const danger = Color(0xFFDC3545);
}

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFEEF2F7),
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
    ),
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return const Color(0xFFD1D5DB);
      }),
      trackOutlineColor:
          WidgetStateProperty.all(Colors.transparent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(
          color: AppColors.textSecondary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7)),
      ),
    ),
    iconTheme: const IconThemeData(
      color: AppColors.textSecondary,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      space: 1,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textBody),
      bodyMedium: TextStyle(fontSize: 15, color: AppColors.textBody),
      bodySmall: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 14),
      labelSmall: TextStyle(fontSize: 13),
      titleLarge: TextStyle(fontSize: 20, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontSize: 17, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 15, color: AppColors.textPrimary),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    ),
  );
}
