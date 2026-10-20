import 'package:dsh_mobile/app.dart';
import 'package:dsh_mobile/core/theme.dart';
import 'package:dsh_mobile/data/device_key_store.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/token_store.dart';
import 'package:dsh_mobile/features/settings/settings_page.dart';
import 'package:dsh_mobile/features/update/app_update_service.dart';
import 'package:dsh_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.preload();
  });

  test('both themes expose their palette and surfaces', () {
    final light = buildDshTheme();
    expect(light.brightness, Brightness.light);
    expect(light.extension<DshPalette>(), DshPalette.light);
    expect(light.scaffoldBackgroundColor, DshPalette.light.canvas);

    final dark = buildDshTheme(brightness: Brightness.dark);
    expect(dark.brightness, Brightness.dark);
    expect(dark.extension<DshPalette>(), DshPalette.dark);
    expect(dark.scaffoldBackgroundColor, DshPalette.dark.canvas);
    expect(dark.colorScheme.onSurface, DshPalette.dark.text);
  });

  testWidgets('the app follows the selected theme mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          relayServiceProvider.overrideWithValue(MockRelayService()),
          appUpdateCheckProvider.overrideWith((ref) async => null),
          appThemeProvider.overrideWith((ref) => ThemeMode.dark),
        ],
        child: const DshRemoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);
  });

  testWidgets('settings cards use the dark surfaces when dark is selected', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        relayServiceProvider.overrideWithValue(MockRelayService()),
        installedAppVersionProvider.overrideWith(
          (ref) async =>
              const InstalledAppVersion(version: '1.2.3', buildNumber: '42'),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildDshTheme(),
          darkTheme: buildDshTheme(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Language'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).extension<DshPalette>(), DshPalette.dark);
    expect(Theme.of(context).scaffoldBackgroundColor, DshPalette.dark.canvas);
    expect(
      tester
          .widgetList<Material>(find.byType(Material))
          .any((material) => material.color == DshPalette.dark.surface),
      isTrue,
    );
  });
}
