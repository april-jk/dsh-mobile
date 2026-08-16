import 'dart:typed_data';

import 'package:dsh_mobile/features/session/e2ee_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const masterKey = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
  const accessSessionId = 'access_test_vector';
  final clientRandom = Uint8List.fromList(
    List<int>.generate(32, (index) => index + 32),
  );

  test('matches the Node handshake and AES-GCM known-answer vector', () async {
    final handshake = await ClientHandshake.start(
      masterKeyB64: masterKey,
      accessSessionId: accessSessionId,
      clientRandom: clientRandom,
    );
    expect(
      handshake.clientRandomB64,
      'ICEiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj8',
    );
    expect(
      handshake.clientProofB64,
      'F3mAmAuR30RnLXq7TMUeMNWZquo8GPHVyCxWycTDW80',
    );
    final cipher = await handshake.acceptServerHello({
      'accessSessionId': accessSessionId,
      'serverRandomB64': 'QEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl8',
      'serverProofB64': 'IXvvgrKVbAjjW-M2rLOmf-blsUwmbgLa6y79lEj1vNA',
    });
    final sealed = await cipher.seal({
      'v': 1,
      'type': 'http_req',
      'channel': 'ch_test',
      'id': 'request_1',
      'ts': 0,
      'payload': {'method': 'POST', 'path': '/canary', 'bodyB64': 'c2VjcmV0'},
    });
    expect(sealed.seq, '0');
    expect(
      sealed.ciphertextB64,
      'voqHzLsUCWC__C-NBr-s0t1AshPpTEwNwSoOrhx_ihApnwkPlwKxr7EX28kmqOjoVQus161QnjXyzjxDil_WXgnkvu0pgQfiGV27QIgL97KPe2X0nv9vlzLUmwMll0ipeUo2IZKgM-Rt_WRa_-TyyL9SEkozijz1Z6HBxk1hfLiwQEb602fzHVGQP4Wh3Q2B41mrL_-AGQ',
    );
  });

  test('rejects a modified server proof', () async {
    final handshake = await ClientHandshake.start(
      masterKeyB64: masterKey,
      accessSessionId: accessSessionId,
      clientRandom: clientRandom,
    );
    await expectLater(
      handshake.acceptServerHello({
        'accessSessionId': accessSessionId,
        'serverRandomB64': 'QEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl8',
        'serverProofB64': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      }),
      throwsA(isA<E2eeException>()),
    );
  });
}
