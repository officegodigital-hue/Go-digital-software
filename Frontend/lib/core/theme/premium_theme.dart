// lib/core/theme/premium_theme.dart
//
// White + blue "premium" look for every popup: dialogs, bottom sheets,
// popup menus, date/time pickers and snackbars.
//
// Use it once for the whole app (recommended) in main.dart:
//
//   MaterialApp(
//     ...
//     builder: (context, child) => PremiumTheme.wrap(context, child!),
//   )
//
// Pages can also wrap themselves with PremiumTheme.wrap(context, page).
import 'package:flutter/material.dart';

class PremiumTheme {
  PremiumTheme._();

  static const Color blue = Color(0xFF0757D5);
  static const Color deepBlue = Color(0xFF0A3D91);
  static const Color navy = Color(0xFF0A2A66);
  static const Color ink = Color(0xFF14213D);
  static const Color body = Color(0xFF334155);
  static const Color line = Color(0xFFDCE6F7);
  static const Color tint = Color(0xFFEFF5FF);

  static ThemeData of(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      primary: blue,
      onPrimary: Colors.white,
      secondary: blue,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Colors.white,
      surfaceContainerHigh: Colors.white,
      surfaceContainerHighest: tint,
      outline: const Color(0xFFCBD5E1),
      outlineVariant: line,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: line),
    );
    return base.copyWith(
      colorScheme: scheme,
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shadowColor: blue.withValues(alpha: 0.25),
        shape: shape,
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
        contentTextStyle: const TextStyle(color: body, fontSize: 13.5, height: 1.45),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: Color(0xFFBFDBFE),
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: blue.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: line),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: blue,
        headerForegroundColor: Colors.white,
        shape: shape,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        actionTextColor: const Color(0xFF93C5FD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: blue,
        selectionHandleColor: blue,
      ),
    );
  }

  static Widget wrap(BuildContext context, Widget child) =>
      Theme(data: of(Theme.of(context)), child: child);

  /// Blue gradient title bar used by custom popups.
  static Widget dialogHeader(String title, {IconData? icon, String? subtitle, VoidCallback? onClose}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [deepBlue, blue, Color(0xFF1E88E5)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5)),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
