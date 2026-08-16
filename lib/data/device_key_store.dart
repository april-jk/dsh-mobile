import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final deviceKeyStoreProvider = Provider<DeviceKeyStore>(
  (ref) => SecureDeviceKeyStore(),
);

abstract interface class DeviceKeyStore {
  Future<String?> read(String deviceId);
  Future<void> write(String deviceId, String key);
  Future<void> delete(String deviceId);
  Future<void> clear();
}

class SecureDeviceKeyStore implements DeviceKeyStore {
  SecureDeviceKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'dsh_e2ee_device_';
  final FlutterSecureStorage _storage;

  String _key(String deviceId) => '$_prefix$deviceId';

  @override
  Future<String?> read(String deviceId) => _storage.read(key: _key(deviceId));

  @override
  Future<void> write(String deviceId, String key) =>
      _storage.write(key: _key(deviceId), value: key);

  @override
  Future<void> delete(String deviceId) => _storage.delete(key: _key(deviceId));

  @override
  Future<void> clear() async {
    final values = await _storage.readAll();
    await Future.wait(
      values.keys
          .where((key) => key.startsWith(_prefix))
          .map((key) => _storage.delete(key: key)),
    );
  }
}

class MemoryDeviceKeyStore implements DeviceKeyStore {
  final Map<String, String> values = {};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String deviceId) async => values.remove(deviceId);

  @override
  Future<String?> read(String deviceId) async => values[deviceId];

  @override
  Future<void> write(String deviceId, String key) async {
    values[deviceId] = key;
  }
}
