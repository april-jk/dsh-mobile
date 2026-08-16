import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/relay_service.dart';
import '../../domain/models.dart';

final deviceControllerProvider =
    StateNotifierProvider<DeviceController, AsyncValue<List<Device>>>((ref) {
      return DeviceController(ref.watch(relayServiceProvider));
    });

class DeviceController extends StateNotifier<AsyncValue<List<Device>>> {
  DeviceController(this._service) : super(const AsyncValue.loading());

  final RelayService _service;

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
    await load(showLoading: false);
  }

  Future<Device?> waitForDevice(String id) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final devices = await _service.listDevices();
      final device = devices.where((item) => item.id == id).firstOrNull;
      if (device != null) {
        state = AsyncValue.data(devices);
        return device;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    await load(showLoading: false);
    return null;
  }
}
