import 'package:flutter/material.dart';

class AdminTheme {
  const AdminTheme._();

  static const Color primary = Color(0xFF1919EC);
  static const Color navy = Color(0xFF03233D);

  static const Color success = Color(0xFF168B55);
  static const Color warning = Color(0xFFA7651B);
  static const Color danger = Color(0xFFCF2028);

  static const Color pageBackground = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF20232A);
  static const Color textSecondary = Color(0xFF555B68);
  static const Color textMuted = Color(0xFF717784);

  static const Color border = Color(0xFFD8DBE2);
  static const Color divider = Color(0xFFE7E9EE);

  static ThemeData get lightTheme {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE7E8FF),
      onPrimaryContainer: Color(0xFF11118E),
      secondary: navy,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
      onError: Colors.white,
      outline: border,
      outlineVariant: divider,
    );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pageBackground,
      canvasColor: surface,
      dividerColor: divider,
      disabledColor: const Color(0xFFB0B4BD),
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
    );

    return baseTheme.copyWith(
      textTheme: _textTheme,
      primaryTextTheme: _textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 20),
      primaryIconTheme: const IconThemeData(color: Colors.white, size: 20),
      inputDecorationTheme: _inputDecorationTheme,
      filledButtonTheme: _filledButtonTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      iconButtonTheme: _iconButtonTheme,
      dropdownMenuTheme: _dropdownMenuTheme,
      checkboxTheme: _checkboxTheme,
      radioTheme: _radioTheme,
      switchTheme: _switchTheme,
      chipTheme: _chipTheme,
      dialogTheme: _dialogTheme,
      snackBarTheme: _snackBarTheme,
      tooltipTheme: _tooltipTheme,
      popupMenuTheme: _popupMenuTheme,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFFE4E6EB),
        circularTrackColor: Color(0xFFE4E6EB),
      ),
      dataTableTheme: _dataTableTheme,
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      color: textPrimary,
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    ),
    displayMedium: TextStyle(
      color: textPrimary,
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    displaySmall: TextStyle(
      color: textPrimary,
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    headlineLarge: TextStyle(
      color: textPrimary,
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    headlineMedium: TextStyle(
      color: textPrimary,
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
    ),
    headlineSmall: TextStyle(
      color: textPrimary,
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleLarge: TextStyle(
      color: textPrimary,
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(
      color: textPrimary,
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: TextStyle(
      color: textPrimary,
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      color: textPrimary,
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: TextStyle(
      color: textSecondary,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w500,
    ),
    bodySmall: TextStyle(
      color: textMuted,
      fontSize: 11,
      height: 1.4,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      color: textPrimary,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      color: textSecondary,
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      color: textMuted,
      fontSize: 9,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
  );

  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 13,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF868B96),
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: primary,
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: const TextStyle(
          color: textMuted,
          fontSize: 10,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(
          color: danger,
          fontSize: 10,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: Color(0xFFE4E6EB), width: 1),
        ),
      );

  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      backgroundColor: primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFB9BBC7),
      disabledForegroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      textStyle: const TextStyle(
        fontSize: 12,
        height: 1.1,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );

  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 40),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB9BBC7),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          textStyle: const TextStyle(
            fontSize: 12,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      );

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          textStyle: const TextStyle(
            fontSize: 12,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primary,
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      textStyle: const TextStyle(
        fontSize: 12,
        height: 1.1,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );

  static final IconButtonThemeData _iconButtonTheme = IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: textSecondary,
      minimumSize: const Size(38, 38),
      iconSize: 20,
      padding: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );

  static const DropdownMenuThemeData _dropdownMenuTheme = DropdownMenuThemeData(
    textStyle: TextStyle(
      color: textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
    ),
  );

  static final CheckboxThemeData _checkboxTheme = CheckboxThemeData(
    visualDensity: VisualDensity.compact,
    side: const BorderSide(color: Color(0xFF9DA2AD), width: 1.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    fillColor: WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return primary;
      }

      return null;
    }),
    checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
  );

  static final RadioThemeData _radioTheme = RadioThemeData(
    visualDensity: VisualDensity.compact,
    fillColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return primary;
      }

      return const Color(0xFF9DA2AD);
    }),
  );

  static final SwitchThemeData _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      return Colors.white;
    }),
    trackColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return primary;
      }

      return const Color(0xFFC6C9D0);
    }),
    trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
  );

  static final ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: const Color(0xFFF1F2F5),
    selectedColor: const Color(0xFFE7E8FF),
    disabledColor: const Color(0xFFF0F1F3),
    side: const BorderSide(color: border, width: 1),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    labelStyle: const TextStyle(
      color: textPrimary,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    ),
    secondaryLabelStyle: const TextStyle(
      color: primary,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
  );

  static final DialogThemeData _dialogTheme = DialogThemeData(
    elevation: 12,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: 0.15),
    titleTextStyle: const TextStyle(
      color: textPrimary,
      fontSize: 18,
      height: 1.25,
      fontWeight: FontWeight.w800,
    ),
    contentTextStyle: const TextStyle(
      color: textSecondary,
      fontSize: 13,
      height: 1.5,
      fontWeight: FontWeight.w500,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: navy,
    actionTextColor: Colors.white,
    contentTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );

  static final TooltipThemeData _tooltipTheme = TooltipThemeData(
    waitDuration: const Duration(milliseconds: 350),
    showDuration: const Duration(seconds: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF25272D),
      borderRadius: BorderRadius.circular(4),
    ),
    textStyle: const TextStyle(
      color: Colors.white,
      fontSize: 10,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
  );

  static final PopupMenuThemeData _popupMenuTheme = PopupMenuThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    textStyle: const TextStyle(
      color: textPrimary,
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: const BorderSide(color: border, width: 1),
    ),
  );

  static const DataTableThemeData _dataTableTheme = DataTableThemeData(
    headingRowColor: WidgetStatePropertyAll<Color>(Color(0xFFF4F5F7)),
    headingTextStyle: TextStyle(
      color: textPrimary,
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    dataTextStyle: TextStyle(
      color: textSecondary,
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
    dividerThickness: 1,
    horizontalMargin: 14,
    columnSpacing: 20,
    headingRowHeight: 44,
    dataRowMinHeight: 48,
    dataRowMaxHeight: 58,
  );
}
