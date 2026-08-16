import 'package:dsh_mobile/features/session/session_policy.dart';
import 'package:dsh_mobile/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final relay = Uri.parse('https://relay.example.com');

  test('injects iOS-safe CJK and symbol font fallbacks at document start', () {
    expect(dshMobileFontCss, contains('PingFang SC'));
    expect(dshMobileFontCss, contains('Apple Color Emoji'));
    expect(dshFontBootstrapScript(), contains('dsh-mobile-font-fallback'));
  });

  test('builds the ticket URL without privileged credentials', () {
    final url = buildSessionUrl(relay, 'device-1', 'single-use-ticket');

    expect(url.path, '/s/device-1/');
    expect(url.queryParameters, {'ticket': 'single-use-ticket'});
    expect(url.toString(), isNot(contains('Bearer')));
    expect(url.toString(), isNot(contains('deviceSecret')));
  });

  test('requires exact Relay scheme, host, and effective port', () {
    expect(
      classifySessionNavigation(
        Uri.parse('https://relay.example.com:443/assets/app.js'),
        relay,
      ),
      SessionNavigation.relay,
    );
    expect(
      classifySessionNavigation(Uri.parse('http://relay.example.com'), relay),
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
        classifySessionNavigation(Uri.parse(value), relay),
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
        classifySessionNavigation(Uri.parse(value), relay),
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
