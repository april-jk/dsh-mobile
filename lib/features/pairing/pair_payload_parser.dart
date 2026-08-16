import 'dart:convert';

import '../../core/api_exception.dart';
import '../../domain/models.dart';

PairPayload parsePairPayload(String raw) {
  final trimmed = raw.trim();
  if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
    return PairPayload(code: trimmed);
  }
  try {
    final json = jsonDecode(trimmed) as Map<String, dynamic>;
    final code = json['code']?.toString() ?? '';
    if (json['v'] != 1 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException();
    }
    final relayValue = json['relay']?.toString();
    final relay = relayValue == null ? null : Uri.tryParse(relayValue);
    if (relayValue != null &&
        (relay == null || !{'http', 'https'}.contains(relay.scheme))) {
      throw const FormatException();
    }
    return PairPayload(code: code, relay: relay);
  } catch (_) {
    throw const ApiException('invalid_pair_payload', message: '无法识别这个配对二维码。');
  }
}

bool relayMatches(Uri? qrRelay, Uri configuredRelay) {
  if (qrRelay == null) return true;
  return qrRelay.host == configuredRelay.host &&
      _effectivePort(qrRelay) == _effectivePort(configuredRelay);
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return uri.scheme == 'https' ? 443 : 80;
}
