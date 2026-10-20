import 'package:dsh_mobile/core/app_config.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/domain/models.dart';
import 'package:dsh_mobile/features/session/session_webview_page.dart';
import 'package:dsh_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _device = Device(
  id: 'computer-1',
  name: 'Test computer',
  online: true,
  dshStatus: 'online',
);

Widget _sessionApp() => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const SessionWebViewPage(device: _device),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.preload();
  });

  testWidgets('session body ends above the system navigation bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(
            (ref) => const AppConfig(
              relayBaseUrl: 'http://127.0.0.1:8787',
              useMock: true,
            ),
          ),
        ],
        child: _sessionApp(),
      ),
    );
    // The loading progress bar animates indefinitely in this state, so pump
    // fixed frames instead of waiting for the tree to settle.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 16));

    final content = tester.getRect(
      find
          .ancestor(
            of: find.text(_localizedMockText(tester)),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;

    // The AppBar owns the status-bar inset; the body must not repeat it.
    expect(content.top, appBarBottom);
    // The system navigation bar occupies the bottom 48 logical pixels, so the
    // embedded DSH surface has to stop above it instead of underneath it.
    expect(content.bottom, 800 - 48);
  });
}

String _localizedMockText(WidgetTester tester) {
  final context = tester.element(find.byType(SessionWebViewPage));
  return AppLocalizations.of(context).text('mockConnected');
}
