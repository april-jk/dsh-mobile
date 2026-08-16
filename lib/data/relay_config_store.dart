import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final relayConfigStoreProvider = Provider<RelayConfigStore>(
  (ref) => SecureRelayConfigStore(),
);

abstract interface class RelayConfigStore {
  Future<String?> readRelayUrl();
  Future<void> writeRelayUrl(String? value);
}

class SecureRelayConfigStore implements RelayConfigStore {
  SecureRelayConfigStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _relayKey = 'dsh_relay_url';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRelayUrl() => _storage.read(key: _relayKey);

  @override
  Future<void> writeRelayUrl(String? value) => value == null
      ? _storage.delete(key: _relayKey)
      : _storage.write(key: _relayKey, value: value);
}

class MemoryRelayConfigStore implements RelayConfigStore {
  String? relayUrl;

  @override
  Future<String?> readRelayUrl() async => relayUrl;

  @override
  Future<void> writeRelayUrl(String? value) async => relayUrl = value;
}
