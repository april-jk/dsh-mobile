import 'package:flutter/material.dart';

abstract final class DshColors {
  static const canvas = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const softSurface = Color(0xFFF1F3F5);
  static const navy = Color(0xFF224665);
  static const accent = Color(0xFF4E82E8);
  static const accentSoft = Color(0xFFE9F0FF);
  static const text = Color(0xFF202124);
  static const secondaryText = Color(0xFF747C88);
  static const mutedText = Color(0xFF9AA1AB);
  static const border = Color(0xFFE2E5E9);
  static const success = Color(0xFF249C63);
  static const warning = Color(0xFFD39A29);
  static const danger = Color(0xFFC84C4C);
}

ThemeData buildDshTheme() {
  const scheme = ColorScheme.light(
    primary: DshColors.accent,
    onPrimary: Colors.white,
    secondary: DshColors.navy,
    onSecondary: Colors.white,
    error: DshColors.danger,
    onError: Colors.white,
    surface: DshColors.surface,
    onSurface: DshColors.text,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: DshColors.canvas,
    fontFamily: 'DMSans',
    fontFamilyFallback: const ['PingFang SC', 'Noto Sans SC', 'sans-serif'],
  );

  final normalizedTextTheme = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(letterSpacing: 0),
    displayMedium: base.textTheme.displayMedium?.copyWith(letterSpacing: 0),
    displaySmall: base.textTheme.displaySmall?.copyWith(letterSpacing: 0),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(letterSpacing: 0),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(letterSpacing: 0),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(letterSpacing: 0),
    titleLarge: base.textTheme.titleLarge?.copyWith(letterSpacing: 0),
    titleMedium: base.textTheme.titleMedium?.copyWith(letterSpacing: 0),
    titleSmall: base.textTheme.titleSmall?.copyWith(letterSpacing: 0),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(letterSpacing: 0),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
    bodySmall: base.textTheme.bodySmall?.copyWith(letterSpacing: 0),
    labelLarge: base.textTheme.labelLarge?.copyWith(letterSpacing: 0),
    labelMedium: base.textTheme.labelMedium?.copyWith(letterSpacing: 0),
    labelSmall: base.textTheme.labelSmall?.copyWith(letterSpacing: 0),
  );

  return base.copyWith(
    textTheme: normalizedTextTheme.copyWith(
      headlineLarge: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 30,
        height: 1.18,
        fontWeight: FontWeight.w600,
        color: DshColors.text,
        letterSpacing: 0,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: DshColors.text,
        letterSpacing: 0,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: DshColors.text,
        letterSpacing: 0,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: DshColors.text,
        letterSpacing: 0,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: DshColors.text,
        letterSpacing: 0,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: DshColors.text,
        letterSpacing: 0,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: DshColors.secondaryText,
        letterSpacing: 0,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: DshColors.surface,
      foregroundColor: DshColors.text,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: DshColors.text,
        letterSpacing: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DshColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DshColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DshColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DshColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: DshColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: DshColors.navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: DshColors.text,
        side: const BorderSide(color: DshColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: DshColors.border, thickness: 1),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: DshColors.navy,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
