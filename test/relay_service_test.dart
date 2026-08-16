import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dsh_mobile/core/api_exception.dart';
import 'package:dsh_mobile/core/app_config.dart';
import 'package:dsh_mobile/data/relay_service.dart';
import 'package:dsh_mobile/data/token_store.dart';
import 'package:dsh_mobile/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryTokenStore tokenStore;

  setUp(() async {
    tokenStore = MemoryTokenStore();
    await tokenStore.write(
      const AuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-1',
      ),
      email: 'test@example.com',
    );
  });

  test('register uses no Bearer token and parses Relay tokens', () async {
    final adapter = _RelayAdapter();
    final service = _service(tokenStore, adapter);
    addTearDown(service.dispose);

    final tokens = await service.register('new@example.com', 'password123');

    expect(tokens.accessToken, 'registered-access');
    expect(adapter.registerAuthorization, isNull);
  });

  test('concurrent 401 responses rotate refresh token only once', () async {
    final adapter = _RelayAdapter();
    final service = _service(tokenStore, adapter);
    addTearDown(service.dispose);

    final results = await Future.wait([
      service.listDevices(),
      service.listDevices(),
    ]);

    expect(results.expand((items) => items), hasLength(2));
    expect(adapter.refreshCalls, 1);
    expect(await tokenStore.readAccessToken(), 'fresh-access');
    expect(await tokenStore.readRefreshToken(), 'refresh-2');
    expect(adapter.deviceAuthorizations, contains('Bearer fresh-access'));
  });

  test('invalid refresh clears credentials and emits session expiry', () async {
    final adapter = _RelayAdapter(refreshFails: true);
    final service = _service(tokenStore, adapter);
    addTearDown(service.dispose);
    final expired = service.sessionExpired.first;

    await expectLater(service.listDevices(), throwsA(isA<ApiException>()));
    await expired.timeout(const Duration(seconds: 1));

    expect(await tokenStore.readAccessToken(), isNull);
    expect(await tokenStore.readRefreshToken(), isNull);
    expect(await tokenStore.readEmail(), isNull);
  });

  test(
    'web ticket request uses Bearer and returns single-use ticket',
    () async {
      final adapter = _RelayAdapter(acceptExpiredAccess: true);
      final service = _service(tokenStore, adapter);
      addTearDown(service.dispose);

      final ticket = await service.createWebTicket('device-1');

      expect(ticket.ticket, 'ticket-1');
      expect(adapter.ticketAuthorization, 'Bearer expired-access');
    },
  );

  test('remove pairing sends authenticated device DELETE', () async {
    final adapter = _RelayAdapter(acceptExpiredAccess: true);
    final service = _service(tokenStore, adapter);
    addTearDown(service.dispose);

    await service.unbindDevice('device-1');

    expect(adapter.unbindMethod, 'DELETE');
    expect(adapter.unbindAuthorization, 'Bearer expired-access');
  });
}

DioRelayService _service(
  MemoryTokenStore tokenStore,
  HttpClientAdapter adapter,
) {
  return DioRelayService(
    config: const AppConfig(
      relayBaseUrl: 'https://relay.example.com',
      useMock: false,
    ),
    tokenStore: tokenStore,
    httpClientAdapter: adapter,
  );
}

class _RelayAdapter implements HttpClientAdapter {
  _RelayAdapter({this.refreshFails = false, this.acceptExpiredAccess = false});

  final bool refreshFails;
  final bool acceptExpiredAccess;
  int refreshCalls = 0;
  String? registerAuthorization;
  String? ticketAuthorization;
  String? unbindMethod;
  String? unbindAuthorization;
  final List<String?> deviceAuthorizations = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    switch (options.uri.path) {
      case '/auth/register':
        registerAuthorization = options.headers['authorization'] as String?;
        return _json(201, {
          'accessToken': 'registered-access',
          'refreshToken': 'registered-refresh',
        });
      case '/auth/refresh':
        refreshCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (refreshFails) {
          return _json(401, {'error': 'invalid_refresh_token'});
        }
        return _json(200, {
          'accessToken': 'fresh-access',
          'refreshToken': 'refresh-2',
        });
      case '/devices':
        final authorization = options.headers['authorization'] as String?;
        deviceAuthorizations.add(authorization);
        if (authorization == 'Bearer fresh-access' ||
            acceptExpiredAccess && authorization == 'Bearer expired-access') {
          return _json(200, {
            'devices': [
              {
                'id': 'device-1',
                'name': 'Test Mac',
                'online': true,
                'dshStatus': 'online',
                'lastSeenAt': 1786860000000,
              },
            ],
          });
        }
        return _json(401, {'error': 'invalid_access_token'});
      case '/web-ticket':
        ticketAuthorization = options.headers['authorization'] as String?;
        return _json(200, {'ticket': 'ticket-1', 'expiresIn': 60});
      case '/devices/device-1':
        unbindMethod = options.method;
        unbindAuthorization = options.headers['authorization'] as String?;
        return _json(200, {'ok': true});
      default:
        return _json(404, {'error': 'not_found'});
    }
  }

  ResponseBody _json(int statusCode, Map<String, dynamic> body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
