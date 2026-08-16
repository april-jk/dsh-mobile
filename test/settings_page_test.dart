import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/device_key_store.dart';
import 'package:dsh_mobile/data/token_store.dart';
import 'package:dsh_mobile/data/relay_config_store.dart';
import 'package:dsh_mobile/features/auth/auth_controller.dart';
import 'package:dsh_mobile/features/settings/settings_page.dart';
import 'package:dsh_mobile/features/update/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the installed app version and build number', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          relayServiceProvider.overrideWithValue(MockRelayService()),
          installedAppVersionProvider.overrideWith(
            (ref) async =>
                const InstalledAppVersion(version: '1.2.3', buildNumber: '42'),
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('版本'), findsOneWidget);
    expect(find.text('1.2.3 (42)'), findsOneWidget);
    expect(find.text('点击检查更新'), findsOneWidget);
  });

  testWidgets('changes and persists a private Relay URL', (tester) async {
    final relayStore = MemoryRelayConfigStore();
    final container = ProviderContainer(
      overrides: [
        deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        relayConfigStoreProvider.overrideWithValue(relayStore),
        relayServiceProvider.overrideWithValue(MockRelayService()),
        installedAppVersionProvider.overrideWith(
          (ref) async =>
              const InstalledAppVersion(version: '1.2.3', buildNumber: '42'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Relay 服务器'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('relay-url-field')),
      'https://private.example.com/',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(relayStore.relayUrl, 'https://private.example.com');
    expect(find.text('https://private.example.com'), findsOneWidget);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });
}
