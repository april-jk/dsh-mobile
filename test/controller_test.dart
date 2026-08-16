import 'dart:async';

import 'package:dsh_mobile/core/api_exception.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/token_store.dart';
import 'package:dsh_mobile/domain/models.dart';
import 'package:dsh_mobile/features/auth/auth_controller.dart';
import 'package:dsh_mobile/features/devices/device_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claimed pairing waits through delayed device confirmation', () async {
    final service = _FakeRelayService(deviceAppearsAfter: 2);
    final controller = DeviceController(service);

    final device = await controller.waitForDevice(
      'device-1',
      retryDelays: const [Duration.zero, Duration.zero],
    );

    expect(device?.id, 'device-1');
    expect(service.listCalls, 3);
    expect(controller.state.value?.single.id, 'device-1');
  });

  test('session expiry clears storage and returns auth to login', () async {
    final store = MemoryTokenStore();
    await store.write(
      const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      email: 'test@example.com',
    );
    final service = _FakeRelayService();
    final controller = AuthController(service: service, tokenStore: store);
    addTearDown(controller.dispose);

    service.expireSession();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.state.errorMessage, '登录已过期，请重新登录。');
    expect(await store.readRefreshToken(), isNull);
  });
}

class _FakeRelayService implements RelayService {
  _FakeRelayService({this.deviceAppearsAfter = 0});

  final int deviceAppearsAfter;
  final StreamController<void> _sessionExpired = StreamController.broadcast();
  int listCalls = 0;

  void expireSession() => _sessionExpired.add(null);

  @override
  Stream<void> get sessionExpired => _sessionExpired.stream;

  @override
  Future<List<Device>> listDevices() async {
    listCalls += 1;
    if (listCalls <= deviceAppearsAfter) return const [];
    return const [
      Device(
        id: 'device-1',
        name: 'Test Mac',
        online: true,
        dshStatus: 'online',
      ),
    ];
  }

  @override
  Future<AuthTokens> login(String email, String password) =>
      throw const ApiException('not_implemented');

  @override
  Future<AuthTokens> register(String email, String password) =>
      throw const ApiException('not_implemented');

  @override
  Future<AuthTokens> refresh(String refreshToken) =>
      throw const ApiException('not_implemented');

  @override
  Future<String> claimPair(String code) =>
      throw const ApiException('not_implemented');

  @override
  Future<WebTicket> createWebTicket(String deviceId) =>
      throw const ApiException('not_implemented');

  @override
  Future<void> renameDevice(String id, String name) =>
      throw const ApiException('not_implemented');

  @override
  Future<void> unbindDevice(String id) =>
      throw const ApiException('not_implemented');
}
