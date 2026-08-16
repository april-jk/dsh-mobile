import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class E2eeException implements Exception {
  const E2eeException(this.message);

  final String message;

  @override
  String toString() => 'E2eeException($message)';
}

class SealedPayload {
  const SealedPayload({required this.seq, required this.ciphertextB64});

  final String seq;
  final String ciphertextB64;

  Map<String, dynamic> toJson() => {'seq': seq, 'ciphertextB64': ciphertextB64};
}

String encodeBase64Url(List<int> value) =>
    base64Url.encode(value).replaceAll('=', '');

Uint8List decodeBase64Url(String value, {int? length}) {
  if (!RegExp(r'^[A-Za-z0-9_-]*$').hasMatch(value)) {
    throw const E2eeException('invalid base64url');
  }
  try {
    final padded = value.padRight((value.length + 3) ~/ 4 * 4, '=');
    final decoded = Uint8List.fromList(base64Url.decode(padded));
    if (encodeBase64Url(decoded) != value ||
        length != null && decoded.length != length) {
      throw const E2eeException('invalid base64url');
    }
    return decoded;
  } on E2eeException {
    rethrow;
  } catch (_) {
    throw const E2eeException('invalid base64url');
  }
}

Uint8List secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

List<int> _canonical(List<Object> value) => utf8.encode(jsonEncode(value));

Future<Mac> _hmac(List<int> key, List<Object> value) =>
    Hmac.sha256().calculateMac(_canonical(value), secretKey: SecretKey(key));

Future<String> createClientProof(
  String masterKeyB64,
  String accessSessionId,
  String clientRandomB64,
) async {
  final key = decodeBase64Url(masterKeyB64, length: 32);
  decodeBase64Url(clientRandomB64, length: 32);
  final mac = await _hmac(key, [
    'dsh-e2ee-client',
    1,
    accessSessionId,
    clientRandomB64,
  ]);
  return encodeBase64Url(mac.bytes);
}

Future<String> createServerProof(
  String masterKeyB64,
  String accessSessionId,
  String clientRandomB64,
  String serverRandomB64,
) async {
  final key = decodeBase64Url(masterKeyB64, length: 32);
  decodeBase64Url(clientRandomB64, length: 32);
  decodeBase64Url(serverRandomB64, length: 32);
  final mac = await _hmac(key, [
    'dsh-e2ee-server',
    1,
    accessSessionId,
    clientRandomB64,
    serverRandomB64,
  ]);
  return encodeBase64Url(mac.bytes);
}

class _KeyMaterial {
  const _KeyMaterial({
    required this.c2dKey,
    required this.d2cKey,
    required this.c2dNonceBase,
    required this.d2cNonceBase,
  });

  final SecretKey c2dKey;
  final SecretKey d2cKey;
  final Uint8List c2dNonceBase;
  final Uint8List d2cNonceBase;
}

Future<_KeyMaterial> _deriveMaterial(
  String masterKeyB64,
  String accessSessionId,
  String clientRandomB64,
  String serverRandomB64,
) async {
  final master = decodeBase64Url(masterKeyB64, length: 32);
  decodeBase64Url(clientRandomB64, length: 32);
  decodeBase64Url(serverRandomB64, length: 32);
  final salt = await Sha256().hash(
    _canonical([
      'dsh-e2ee-salt',
      1,
      accessSessionId,
      clientRandomB64,
      serverRandomB64,
    ]),
  );
  Future<SecretKeyData> expand(String info, int length) =>
      Hkdf(hmac: Hmac.sha256(), outputLength: length).deriveKey(
        secretKey: SecretKey(master),
        nonce: salt.bytes,
        info: utf8.encode(info),
      );
  final results = await Future.wait([
    expand('dsh-e2ee-v1:c2d:key', 32),
    expand('dsh-e2ee-v1:d2c:key', 32),
    expand('dsh-e2ee-v1:c2d:nonce', 4),
    expand('dsh-e2ee-v1:d2c:nonce', 4),
  ]);
  return _KeyMaterial(
    c2dKey: results[0],
    d2cKey: results[1],
    c2dNonceBase: Uint8List.fromList(results[2].bytes),
    d2cNonceBase: Uint8List.fromList(results[3].bytes),
  );
}

class ClientHandshake {
  ClientHandshake._({
    required this.masterKeyB64,
    required this.accessSessionId,
    required this.clientRandomB64,
    required this.clientProofB64,
  });

  final String masterKeyB64;
  final String accessSessionId;
  final String clientRandomB64;
  final String clientProofB64;

  static Future<ClientHandshake> start({
    required String masterKeyB64,
    required String accessSessionId,
    Uint8List? clientRandom,
  }) async {
    decodeBase64Url(masterKeyB64, length: 32);
    final random = clientRandom ?? secureRandomBytes(32);
    if (random.length != 32) {
      throw const E2eeException('invalid client random');
    }
    final randomB64 = encodeBase64Url(random);
    return ClientHandshake._(
      masterKeyB64: masterKeyB64,
      accessSessionId: accessSessionId,
      clientRandomB64: randomB64,
      clientProofB64: await createClientProof(
        masterKeyB64,
        accessSessionId,
        randomB64,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'accessSessionId': accessSessionId,
    'clientRandomB64': clientRandomB64,
    'clientProofB64': clientProofB64,
  };

  Future<SecureCipher> acceptServerHello(Map<String, dynamic> payload) async {
    if (payload['accessSessionId'] != accessSessionId ||
        payload['serverRandomB64'] is! String ||
        payload['serverProofB64'] is! String) {
      throw const E2eeException('invalid server hello');
    }
    final serverRandomB64 = payload['serverRandomB64'] as String;
    final expected = await createServerProof(
      masterKeyB64,
      accessSessionId,
      clientRandomB64,
      serverRandomB64,
    );
    final actual = decodeBase64Url(
      payload['serverProofB64'] as String,
      length: 32,
    );
    if (Mac(decodeBase64Url(expected, length: 32)) != Mac(actual)) {
      throw const E2eeException('server proof failed');
    }
    final material = await _deriveMaterial(
      masterKeyB64,
      accessSessionId,
      clientRandomB64,
      serverRandomB64,
    );
    return SecureCipher._(
      accessSessionId: accessSessionId,
      sendDirection: 'c2d',
      sendKey: material.c2dKey,
      sendNonceBase: material.c2dNonceBase,
      receiveDirection: 'd2c',
      receiveKey: material.d2cKey,
      receiveNonceBase: material.d2cNonceBase,
    );
  }
}

class SecureCipher {
  SecureCipher._({
    required this.accessSessionId,
    required this.sendDirection,
    required this.sendKey,
    required this.sendNonceBase,
    required this.receiveDirection,
    required this.receiveKey,
    required this.receiveNonceBase,
  });

  final String accessSessionId;
  final String sendDirection;
  final SecretKey sendKey;
  final Uint8List sendNonceBase;
  final String receiveDirection;
  final SecretKey receiveKey;
  final Uint8List receiveNonceBase;
  final AesGcm _aes = AesGcm.with256bits();
  int _sendSequence = 0;
  int _receiveSequence = 0;

  List<int> _nonce(Uint8List prefix, int sequence) {
    if (sequence < 0) throw const E2eeException('sequence exhausted');
    final nonce = Uint8List(12)..setRange(0, 4, prefix);
    ByteData.sublistView(nonce).setUint64(4, sequence, Endian.big);
    return nonce;
  }

  List<int> _aad(String direction, int sequence) => _canonical([
    'dsh-e2ee',
    1,
    accessSessionId,
    direction,
    sequence.toString(),
  ]);

  Future<SealedPayload> seal(Object value) async {
    final sequence = _sendSequence;
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: sendKey,
      nonce: _nonce(sendNonceBase, sequence),
      aad: _aad(sendDirection, sequence),
    );
    _sendSequence += 1;
    return SealedPayload(
      seq: sequence.toString(),
      ciphertextB64: encodeBase64Url([...box.cipherText, ...box.mac.bytes]),
    );
  }

  Future<Object?> open(SealedPayload payload) async {
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(payload.seq)) {
      throw const E2eeException('invalid sequence');
    }
    final sequence = int.parse(payload.seq);
    if (sequence != _receiveSequence) {
      throw const E2eeException('unexpected sequence');
    }
    final sealed = decodeBase64Url(payload.ciphertextB64);
    if (sealed.length < 16) throw const E2eeException('truncated ciphertext');
    try {
      final plaintext = await _aes.decrypt(
        SecretBox(
          sealed.sublist(0, sealed.length - 16),
          nonce: _nonce(receiveNonceBase, sequence),
          mac: Mac(sealed.sublist(sealed.length - 16)),
        ),
        secretKey: receiveKey,
        aad: _aad(receiveDirection, sequence),
      );
      final value = jsonDecode(utf8.decode(plaintext));
      _receiveSequence += 1;
      return value;
    } catch (_) {
      throw const E2eeException('ciphertext authentication failed');
    }
  }
}
