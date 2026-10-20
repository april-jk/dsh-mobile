import 'dart:async';

import 'package:dsh_mobile/core/api_exception.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/domain/models.dart';
import 'package:dsh_mobile/features/pairing/pair_page.dart';
import 'package:dsh_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.preload();
  });

  testWidgets('manual pairing cannot bypass the encrypted QR bootstrap', (
    tester,
  ) async {
    final service = _ClaimTrackingRelayService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [relayServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PairPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Enter manually'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('pair-code-field')), '482913');
    await tester.tap(find.widgetWithText(FilledButton, 'Pair computer'));
    await tester.pump();

    expect(service.claimedCodes, isEmpty);
    expect(find.textContaining('only supports scanning'), findsOneWidget);
  });
}

class _ClaimTrackingRelayService implements RelayService {
  final List<String> claimedCodes = [];
  final Completer<String> _pendingClaim = Completer<String>();

  @override
  Stream<void> get sessionExpired => const Stream<void>.empty();

  @override
  Future<String> claimPair(String code) {
    claimedCodes.add(code);
    return _pendingClaim.future;
  }

  @override
  Future<AuthTokens> login(String email, String password) =>
      throw const ApiException('not_implemented');

  @override
  Future<AuthTokens> register(String email, String password) =>
      throw const ApiException('not_implemented');

  @override
  Future<AuthTokens> refresh(String refreshToken) =>
      throw const ApiException('not_implemented');

  @override
  Future<List<Device>> listDevices() =>
      throw const ApiException('not_implemented');

  @override
  Future<WebTicket> createWebTicket(String deviceId) =>
      throw const ApiException('not_implemented');

  @override
  Future<void> renameDevice(String id, String name) =>
      throw const ApiException('not_implemented');

  @override
  Future<void> unbindDevice(String id) =>
      throw const ApiException('not_implemented');
}
