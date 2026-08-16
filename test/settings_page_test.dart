import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/token_store.dart';
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
}
