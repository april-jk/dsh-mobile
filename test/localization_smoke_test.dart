import 'package:dsh_mobile/app.dart';
import 'package:dsh_mobile/data/device_key_store.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/token_store.dart';
import 'package:dsh_mobile/features/update/app_update_service.dart';
import 'package:dsh_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        relayServiceProvider.overrideWithValue(MockRelayService()),
        appUpdateCheckProvider.overrideWith((ref) async => null),
        appLocaleProvider.overrideWith((ref) => locale),
      ],
      child: const DshRemoteApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.preload();
  });

  testWidgets('Polish locale renders the login screen in Polish', (
    tester,
  ) async {
    await _pumpApp(tester, const Locale('pl'));

    expect(find.text('Połącz się ze swoim DSH'), findsOneWidget);
    expect(find.text('Zaloguj się'), findsWidgets);
    expect(find.text('Zarejestruj się'), findsOneWidget);
    expect(find.text('Adres e-mail'), findsOneWidget);
    // The language switch lives in settings only; the sign-in screen must not
    // carry it back.
    expect(find.text('Język'), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.text('Connect to your DSH'), findsNothing);
  });

  testWidgets('unsupported system locale falls back to English', (
    tester,
  ) async {
    await _pumpApp(tester, const Locale('de'));

    expect(find.text('Connect to your DSH'), findsOneWidget);
  });
}
