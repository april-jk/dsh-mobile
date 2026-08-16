import 'package:dsh_mobile/app.dart';
import 'package:dsh_mobile/data/device_key_store.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/token_store.dart';
import 'package:dsh_mobile/features/update/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logs in and opens the device list with the mock Relay', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          relayServiceProvider.overrideWithValue(MockRelayService()),
          appUpdateCheckProvider.overrideWith((ref) async => null),
        ],
        child: const DshRemoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('连接你的 DSH'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'watson@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('我的电脑'), findsOneWidget);
    expect(find.text("Watson's MacBook Air"), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除配对'));
    await tester.pumpAndSettle();

    expect(find.text('移除配对'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(FilledButton, '移除配对'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text("Watson's MacBook Air"), findsNothing);
  });
}
