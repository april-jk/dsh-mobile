import 'package:dsh_mobile/features/session/session_policy.dart';
import 'package:dsh_mobile/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sessionOrigin = Uri.parse('http://127.0.0.1:49152');

  test('injects iOS-safe CJK and symbol font fallbacks at document start', () {
    expect(dshMobileFontCss, contains('PingFang SC'));
    expect(dshMobileFontCss, contains('Apple Color Emoji'));
    expect(dshFontBootstrapScript(), contains('dsh-mobile-font-fallback'));
  });

  test('requires the exact loopback session origin', () {
    expect(
      classifySessionNavigation(
        Uri.parse('http://127.0.0.1:49152/assets/app.js'),
        sessionOrigin,
      ),
      SessionNavigation.session,
    );
    expect(
      classifySessionNavigation(
        Uri.parse('http://127.0.0.1:49153'),
        sessionOrigin,
      ),
      SessionNavigation.external,
    );
  });

  test('allows safe external schemes and blocks active or local schemes', () {
    for (final value in [
      'https://example.com',
      'http://example.com',
      'mailto:test@example.com',
    ]) {
      expect(
        classifySessionNavigation(Uri.parse(value), sessionOrigin),
        SessionNavigation.external,
      );
    }
    for (final value in [
      'file:///tmp/test',
      'javascript:alert(1)',
      'data:text/plain,test',
      'intent://example.com',
      'custom:test',
    ]) {
      expect(
        classifySessionNavigation(Uri.parse(value), sessionOrigin),
        SessionNavigation.blocked,
      );
    }
  });

  test('maps main-document HTTP failures to recoverable actions', () {
    expect(sessionHttpAction(401), SessionHttpAction.renewTicket);
    expect(sessionHttpAction(503), SessionHttpAction.refreshDeviceStatus);
    expect(sessionHttpAction(504), SessionHttpAction.tunnelTimeout);
    expect(sessionHttpAction(404), SessionHttpAction.failed);
    expect(sessionHttpAction(200), SessionHttpAction.ignore);
  });

  test('renews a failed Cookie session only once per opened session', () {
    final guard = TicketRenewalGuard();

    expect(guard.take(), isTrue);
    expect(guard.take(), isFalse);
    guard.reset();
    expect(guard.take(), isTrue);
  });

  test('uses the latest fetched device state after a 503', () {
    const devices = [
      Device(
        id: 'device-1',
        name: 'Test Mac',
        online: false,
        dshStatus: 'online',
      ),
    ];

    expect(
      latestDeviceAvailability(devices, 'device-1'),
      DeviceAvailability.offline,
    );
    expect(latestDeviceAvailability(devices, 'missing'), isNull);
  });
}
