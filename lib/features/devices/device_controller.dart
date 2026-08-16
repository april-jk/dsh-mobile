import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/relay_service.dart';
import '../../data/device_key_store.dart';
import '../../domain/models.dart';

final deviceControllerProvider =
    StateNotifierProvider<DeviceController, AsyncValue<List<Device>>>((ref) {
      return DeviceController(
        ref.watch(relayServiceProvider),
        keyStore: ref.watch(deviceKeyStoreProvider),
      );
    });

class DeviceController extends StateNotifier<AsyncValue<List<Device>>> {
  DeviceController(this._service, {DeviceKeyStore? keyStore})
    : _keyStore = keyStore,
      super(const AsyncValue.loading());

  final RelayService _service;
  final DeviceKeyStore? _keyStore;

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.listDevices);
  }

  Future<void> rename(String id, String name) async {
    await _service.renameDevice(id, name);
    await load(showLoading: false);
  }

  Future<void> unbind(String id) async {
    await _service.unbindDevice(id);
    await _keyStore?.delete(id);
    await load(showLoading: false);
  }

  Future<Device?> waitForDevice(
    String id, {
    List<Duration> retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 5),
      Duration(seconds: 5),
      Duration(seconds: 5),
      Duration(seconds: 5),
      Duration(seconds: 5),
      Duration(seconds: 5),
      Duration(seconds: 5),
      Duration(seconds: 5),
      Duration(seconds: 5),
    ],
  }) async {
    for (final delay in retryDelays) {
      final devices = await _service.listDevices();
      final device = devices.where((item) => item.id == id).firstOrNull;
      if (device != null) {
        state = AsyncValue.data(devices);
        return device;
      }
      await Future<void>.delayed(delay);
    }
    final devices = await _service.listDevices();
    state = AsyncValue.data(devices);
    return devices.where((item) => item.id == id).firstOrNull;
  }
}
