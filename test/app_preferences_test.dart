import 'package:dsh_mobile/app.dart';
import 'package:dsh_mobile/core/theme.dart';
import 'package:dsh_mobile/data/app_preferences_store.dart';
import 'package:dsh_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes only shipped languages and supported themes', () {
    expect(AppPreferences.decodeLocale('pl')?.languageCode, 'pl');
    expect(AppPreferences.decodeLocale('ZH')?.languageCode, 'zh');
    expect(AppPreferences.decodeLocale('de'), isNull);
    expect(AppPreferences.decodeLocale(''), isNull);
    expect(AppPreferences.decodeLocale(null), isNull);

    expect(AppPreferences.decodeThemeMode('dark'), ThemeMode.dark);
    expect(AppPreferences.decodeThemeMode(' LIGHT '), ThemeMode.light);
    expect(AppPreferences.decodeThemeMode('system'), ThemeMode.light);
    expect(AppPreferences.decodeThemeMode(null), ThemeMode.light);
  });

  test('encodes language and theme back to storage values', () {
    expect(AppPreferences.encodeLocale(const Locale('en')), 'en');
    expect(AppPreferences.encodeLocale(const Locale('de')), isNull);
    expect(AppPreferences.encodeLocale(null), isNull);
    expect(AppPreferences.encodeThemeMode(ThemeMode.dark), 'dark');
    expect(AppPreferences.encodeThemeMode(ThemeMode.light), 'light');
  });

  test('memory store rounds trips both preferences', () async {
    final store = MemoryAppPreferencesStore();
    expect((await store.read()).locale, isNull);
    expect((await store.read()).themeMode, ThemeMode.light);

    await store.writeLocale(const Locale('zh'));
    await store.writeThemeMode(ThemeMode.dark);
    final preferences = await store.read();
    expect(preferences.locale?.languageCode, 'zh');
    expect(preferences.themeMode, ThemeMode.dark);

    await store.writeLocale(null);
    expect((await store.read()).locale, isNull);
  });

  test('secure store reads stored values and writes changes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({
      'dsh_app_locale': 'zh',
      'dsh_app_theme': 'dark',
    });
    final store = SecureAppPreferencesStore();

    final loaded = await store.read();
    expect(loaded.locale?.languageCode, 'zh');
    expect(loaded.themeMode, ThemeMode.dark);

    await store.writeLocale(null);
    await store.writeThemeMode(ThemeMode.light);
    final cleared = await store.read();
    expect(cleared.locale, isNull);
    expect(cleared.themeMode, ThemeMode.light);
  });

  test('stored preferences seed the language and theme providers', () async {
    final store = MemoryAppPreferencesStore(const Locale('pl'), ThemeMode.dark);
    final container = ProviderContainer(
      overrides: appPreferenceOverrides(await store.read()),
    );
    addTearDown(container.dispose);

    expect(container.read(appLocaleProvider)?.languageCode, 'pl');
    expect(container.read(appThemeProvider), ThemeMode.dark);
  });
}
