import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-only, like the language override: the platform default is the
/// initial state, so no stored value has to be migrated.
final appThemeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// Every surface, text and status color of the mobile UI. Both themes carry the
/// same roles, so widgets never branch on brightness themselves.
@immutable
class DshPalette extends ThemeExtension<DshPalette> {
  const DshPalette({
    required this.canvas,
    required this.surface,
    required this.softSurface,
    required this.brand,
    required this.navy,
    required this.accent,
    required this.accentSoft,
    required this.text,
    required this.secondaryText,
    required this.mutedText,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color canvas;
  final Color surface;
  final Color softSurface;

  /// Background behind the brand mark and other brand-colored blocks.
  final Color brand;

  /// Secondary brand tint used for icons and the color scheme's secondary.
  final Color navy;

  final Color accent;
  final Color accentSoft;
  final Color text;
  final Color secondaryText;
  final Color mutedText;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;

  static const light = DshPalette(
    canvas: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    softSurface: Color(0xFFF1F3F5),
    brand: Color(0xFF224665),
    navy: Color(0xFF224665),
    accent: Color(0xFF4E82E8),
    accentSoft: Color(0xFFE9F0FF),
    text: Color(0xFF202124),
    secondaryText: Color(0xFF747C88),
    mutedText: Color(0xFF9AA1AB),
    border: Color(0xFFE2E5E9),
    success: Color(0xFF249C63),
    warning: Color(0xFFD39A29),
    danger: Color(0xFFC84C4C),
  );

  /// Mirrors the tokens of the remote file browser so both surfaces match.
  static const dark = DshPalette(
    canvas: Color(0xFF0F1115),
    surface: Color(0xFF171A20),
    softSurface: Color(0xFF1E222A),
    brand: Color(0xFF3E6FA6),
    navy: Color(0xFF9DB8D6),
    accent: Color(0xFF7AA2F7),
    accentSoft: Color(0xFF1D2A44),
    text: Color(0xFFE8EAEE),
    secondaryText: Color(0xFF9AA3AF),
    mutedText: Color(0xFF7C8592),
    border: Color(0xFF2A2F38),
    success: Color(0xFF59C08F),
    warning: Color(0xFFE0B45C),
    danger: Color(0xFFF08A8A),
  );

  @override
  DshPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? softSurface,
    Color? brand,
    Color? navy,
    Color? accent,
    Color? accentSoft,
    Color? text,
    Color? secondaryText,
    Color? mutedText,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return DshPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      softSurface: softSurface ?? this.softSurface,
      brand: brand ?? this.brand,
      navy: navy ?? this.navy,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      text: text ?? this.text,
      secondaryText: secondaryText ?? this.secondaryText,
      mutedText: mutedText ?? this.mutedText,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  DshPalette lerp(ThemeExtension<DshPalette>? other, double t) {
    if (other is! DshPalette) return this;
    return DshPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      softSurface: Color.lerp(softSurface, other.softSurface, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      navy: Color.lerp(navy, other.navy, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension DshPaletteContext on BuildContext {
  /// Falls back to the light palette so widgets stay usable when embedded in a
  /// host theme that did not install [DshPalette].
  DshPalette get dsh =>
      Theme.of(this).extension<DshPalette>() ?? DshPalette.light;
}

ThemeData buildDshTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? DshPalette.dark : DshPalette.light;
  final onAccent = isDark ? const Color(0xFF0B1220) : Colors.white;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: palette.accent,
    onPrimary: onAccent,
    primaryContainer: palette.accentSoft,
    onPrimaryContainer: isDark ? palette.accent : palette.text,
    secondary: palette.navy,
    onSecondary: onAccent,
    secondaryContainer: palette.accentSoft,
    onSecondaryContainer: isDark ? palette.accent : palette.text,
    tertiary: palette.navy,
    onTertiary: onAccent,
    error: palette.danger,
    onError: const Color(0xFF2A0F0F),
    surface: palette.surface,
    onSurface: palette.text,
    surfaceContainerHighest: palette.softSurface,
    onSurfaceVariant: palette.secondaryText,
    outline: palette.border,
    outlineVariant: palette.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.canvas,
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

  final textTheme = normalizedTextTheme.copyWith(
    headlineLarge: TextStyle(
      fontFamily: 'Montserrat',
      fontSize: 30,
      height: 1.18,
      fontWeight: FontWeight.w600,
      color: palette.text,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Montserrat',
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: palette.text,
      letterSpacing: 0,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: palette.text,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: palette.text,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: palette.text,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: palette.text,
      letterSpacing: 0,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.4,
      color: palette.secondaryText,
      letterSpacing: 0,
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: palette.surface,
      foregroundColor: palette.text,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.text,
        letterSpacing: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: palette.mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: isDark ? palette.accent : palette.navy,
        foregroundColor: onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: palette.text,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.accent),
    ),
    dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? palette.softSurface : palette.navy,
      contentTextStyle: TextStyle(color: isDark ? palette.text : Colors.white),
    ),
  );
}
