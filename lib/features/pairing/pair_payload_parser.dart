import 'dart:convert';

import '../../core/api_exception.dart';
import '../../domain/models.dart';

PairPayload parsePairPayload(String raw) {
  final trimmed = raw.trim();
  try {
    final json = jsonDecode(trimmed) as Map<String, dynamic>;
    final code = json['code']?.toString() ?? '';
    final e2eeKey = json['e2eeKey']?.toString() ?? '';
    if (json['v'] != 2 ||
        !RegExp(r'^\d{6}$').hasMatch(code) ||
        !_validMasterKey(e2eeKey)) {
      throw const FormatException();
    }
    final relayValue = json['relay']?.toString();
    final relay = relayValue == null ? null : Uri.tryParse(relayValue);
    if (relayValue != null &&
        (relay == null || !{'http', 'https'}.contains(relay.scheme))) {
      throw const FormatException();
    }
    return PairPayload(code: code, relay: relay, e2eeKey: e2eeKey);
  } catch (_) {
    throw const ApiException(
      'e2ee_pairing_required',
      message: '0.1.3 必须扫描电脑上的加密配对二维码。',
    );
  }
}

bool _validMasterKey(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) return false;
  try {
    final padded = value.padRight((value.length + 3) ~/ 4 * 4, '=');
    final decoded = base64Url.decode(padded);
    return decoded.length == 32 &&
        base64Url.encode(decoded).replaceAll('=', '') == value;
  } catch (_) {
    return false;
  }
}

bool relayMatches(Uri? qrRelay, Uri configuredRelay) {
  if (qrRelay == null) return true;
  return qrRelay.scheme == configuredRelay.scheme &&
      qrRelay.host == configuredRelay.host &&
      _effectivePort(qrRelay) == _effectivePort(configuredRelay);
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return uri.scheme == 'https' ? 443 : 80;
}
