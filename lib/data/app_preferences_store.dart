import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted language and theme choices. A null locale follows the system.
@immutable
class AppPreferences {
  const AppPreferences({this.locale, this.themeMode = ThemeMode.light});

  final Locale? locale;
  final ThemeMode themeMode;

  static const supportedLocales = {'en', 'pl', 'zh'};

  /// Unknown or stale stored values fall back to the defaults instead of
  /// leaving the UI without a matching item.
  static Locale? decodeLocale(String? value) {
    final code = value?.trim().toLowerCase();
    return code != null && supportedLocales.contains(code)
        ? Locale(code)
        : null;
  }

  static ThemeMode decodeThemeMode(String? value) =>
      value?.trim().toLowerCase() == 'dark' ? ThemeMode.dark : ThemeMode.light;

  static String? encodeLocale(Locale? locale) =>
      locale != null && supportedLocales.contains(locale.languageCode)
      ? locale.languageCode
      : null;

  static String encodeThemeMode(ThemeMode mode) =>
      mode == ThemeMode.dark ? 'dark' : 'light';
}

final appPreferencesStoreProvider = Provider<AppPreferencesStore>(
  (ref) => SecureAppPreferencesStore(),
);

abstract interface class AppPreferencesStore {
  Future<AppPreferences> read();
  Future<void> writeLocale(Locale? locale);
  Future<void> writeThemeMode(ThemeMode mode);
}

/// The app already owns secure storage for credentials and the Relay URL, so
/// preferences share it instead of adding a second persistence dependency.
class SecureAppPreferencesStore implements AppPreferencesStore {
  SecureAppPreferencesStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _localeKey = 'dsh_app_locale';
  static const _themeKey = 'dsh_app_theme';

  final FlutterSecureStorage _storage;

  @override
  Future<AppPreferences> read() async {
    final values = await Future.wait([
      _storage.read(key: _localeKey),
      _storage.read(key: _themeKey),
    ]);
    return AppPreferences(
      locale: AppPreferences.decodeLocale(values[0]),
      themeMode: AppPreferences.decodeThemeMode(values[1]),
    );
  }

  @override
  Future<void> writeLocale(Locale? locale) {
    final value = AppPreferences.encodeLocale(locale);
    return value == null
        ? _storage.delete(key: _localeKey)
        : _storage.write(key: _localeKey, value: value);
  }

  @override
  Future<void> writeThemeMode(ThemeMode mode) => _storage.write(
    key: _themeKey,
    value: AppPreferences.encodeThemeMode(mode),
  );
}

class MemoryAppPreferencesStore implements AppPreferencesStore {
  MemoryAppPreferencesStore([this.locale, this.themeMode = ThemeMode.light]);

  Locale? locale;
  ThemeMode themeMode;

  @override
  Future<AppPreferences> read() async =>
      AppPreferences(locale: locale, themeMode: themeMode);

  @override
  Future<void> writeLocale(Locale? value) async => locale = value;

  @override
  Future<void> writeThemeMode(ThemeMode value) async => themeMode = value;
}
