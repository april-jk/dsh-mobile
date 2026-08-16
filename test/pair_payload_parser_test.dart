import 'package:dsh_mobile/core/api_exception.dart';
import 'package:dsh_mobile/features/pairing/pair_payload_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a v2 QR payload with a 256-bit E2EE key', () {
    final payload = parsePairPayload(
      '{"v":2,"relay":"https://relay.example.com","code":"482913","e2eeKey":"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"}',
    );

    expect(payload.code, '482913');
    expect(payload.relay?.host, 'relay.example.com');
    expect(payload.e2eeKey, hasLength(43));
  });

  test('rejects a manual six-digit code', () {
    expect(() => parsePairPayload('482913'), throwsA(isA<ApiException>()));
  });

  test('rejects unsupported payloads', () {
    expect(
      () => parsePairPayload('{"v":1,"code":"482913"}'),
      throwsA(isA<ApiException>()),
    );
  });

  test('compares Relay host and effective port', () {
    expect(
      relayMatches(
        Uri.parse('https://relay.example.com'),
        Uri.parse('https://relay.example.com:443'),
      ),
      isTrue,
    );
  });

  test('rejects a Relay scheme downgrade on the same host and port', () {
    expect(
      relayMatches(
        Uri.parse('http://relay.example.com:443'),
        Uri.parse('https://relay.example.com:443'),
      ),
      isFalse,
    );
  });
}
