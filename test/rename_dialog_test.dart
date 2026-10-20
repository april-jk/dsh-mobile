import 'package:dsh_mobile/app.dart';
import 'package:dsh_mobile/core/api_exception.dart';
import 'package:dsh_mobile/data/device_key_store.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/token_store.dart';
import 'package:dsh_mobile/domain/models.dart';
import 'package:dsh_mobile/features/update/app_update_service.dart';
import 'package:dsh_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RenamableRelayService extends MockRelayService {
  final List<Device> _plain = [
    Device(
      id: 'dev_plain',
      name: 'Laptop',
      online: true,
      dshStatus: 'online',
      lastSeenAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Device>> listDevices() async => List.unmodifiable(_plain);

  @override
  Future<void> renameDevice(String id, String name) async {
    final index = _plain.indexWhere((device) => device.id == id);
    if (index < 0) throw const ApiException('not_found', statusCode: 404);
    _plain[index] = _plain[index].copyWith(name: name);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.preload();
  });

  testWidgets('renames a paired computer without a framework exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceKeyStoreProvider.overrideWithValue(MemoryDeviceKeyStore()),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          relayServiceProvider.overrideWithValue(_RenamableRelayService()),
          appUpdateCheckProvider.overrideWith((ref) async => null),
        ],
        child: const DshRemoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'watson@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password123',
    );
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('My computers'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Domowy komputer');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Domowy komputer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
