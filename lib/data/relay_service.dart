import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/app_config.dart';
import '../domain/models.dart';
import 'token_store.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final relayServiceProvider = Provider<RelayService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) return MockRelayService();
  final service = DioRelayService(
    config: config,
    tokenStore: ref.watch(tokenStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

abstract interface class RelayService {
  Stream<void> get sessionExpired;
  Future<AuthTokens> register(String email, String password);
  Future<AuthTokens> login(String email, String password);
  Future<AuthTokens> refresh(String refreshToken);
  Future<List<Device>> listDevices();
  Future<String> claimPair(String code);
  Future<void> renameDevice(String id, String name);
  Future<void> unbindDevice(String id);
  Future<WebTicket> createWebTicket(String deviceId);
}

class DioRelayService implements RelayService {
  DioRelayService({
    required this.config,
    required this.tokenStore,
    HttpClientAdapter? httpClientAdapter,
  }) : _dio = Dio(BaseOptions(baseUrl: config.relayBaseUrl)),
       _authDio = Dio(BaseOptions(baseUrl: config.relayBaseUrl)) {
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
      _authDio.httpClientAdapter = httpClientAdapter;
    }
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await tokenStore.readAccessToken();
            if (token != null) {
              options.headers['authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          if (error.response?.statusCode != 401 ||
              options.extra['skipAuth'] == true ||
              options.extra['retried'] == true) {
            handler.next(error);
            return;
          }
          try {
            final currentToken = await tokenStore.readAccessToken();
            final failedToken = options.headers['authorization'];
            final accessToken =
                currentToken != null && failedToken != 'Bearer $currentToken'
                ? currentToken
                : await _refreshAccessToken();
            options.headers['authorization'] = 'Bearer $accessToken';
            options.extra['retried'] = true;
            handler.resolve(await _dio.fetch<dynamic>(options));
          } catch (refreshError) {
            if (refreshError is ApiException &&
                refreshError.statusCode == 401) {
              await tokenStore.clear();
              if (!_sessionExpiredController.isClosed) {
                _sessionExpiredController.add(null);
              }
            }
            handler.next(error);
          }
        },
      ),
    );
  }

  final AppConfig config;
  final TokenStore tokenStore;
  final Dio _dio;
  final Dio _authDio;
  Future<String>? _refreshInFlight;
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get sessionExpired => _sessionExpiredController.stream;

  void dispose() {
    _sessionExpiredController.close();
    _dio.close(force: true);
    _authDio.close(force: true);
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final data = error.response?.data;
      final map = data is Map ? data : const <String, dynamic>{};
      final code = (map['error'] ?? map['reason'] ?? 'network_error')
          .toString();
      throw ApiException(code, statusCode: error.response?.statusCode);
    }
  }

  Future<AuthTokens> _authenticate(String path, Map<String, dynamic> data) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(extra: {'skipAuth': true}),
      );
      return AuthTokens.fromJson(response.data!);
    });
  }

  @override
  Future<AuthTokens> register(String email, String password) =>
      _authenticate('/auth/register', {'email': email, 'password': password});

  @override
  Future<AuthTokens> login(String email, String password) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  @override
  Future<AuthTokens> refresh(String refreshToken) {
    return _guard(() async {
      final response = await _authDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      return AuthTokens.fromJson(response.data!);
    });
  }

  Future<String> _refreshAccessToken() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final operation = () async {
      final refreshToken = await tokenStore.readRefreshToken();
      final email = await tokenStore.readEmail();
      if (refreshToken == null || email == null) {
        throw const ApiException('invalid_refresh_token', statusCode: 401);
      }
      final tokens = await refresh(refreshToken);
      await tokenStore.write(tokens, email: email);
      return tokens.accessToken;
    }();
    _refreshInFlight = operation;
    return operation.whenComplete(() => _refreshInFlight = null);
  }

  @override
  Future<List<Device>> listDevices() => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/devices');
    final items = response.data?['devices'] as List<dynamic>? ?? const [];
    return items
        .map((item) => Device.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  });

  @override
  Future<String> claimPair(String code) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/pair/claim',
      data: {'code': code},
    );
    return response.data!['deviceId'] as String;
  });

  @override
  Future<void> renameDevice(String id, String name) => _guard(() async {
    await _dio.patch<void>('/devices/$id', data: {'name': name});
  });

  @override
  Future<void> unbindDevice(String id) => _guard(() async {
    await _dio.delete<void>('/devices/$id');
  });

  @override
  Future<WebTicket> createWebTicket(String deviceId) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/web-ticket',
      data: {'deviceId': deviceId},
    );
    return WebTicket(
      ticket: response.data!['ticket'] as String,
      expiresIn: response.data!['expiresIn'] as int? ?? 60,
    );
  });
}

class MockRelayService implements RelayService {
  final List<Device> _devices = [
    Device(
      id: 'dev_mock_primary',
      name: 'Watson\'s MacBook Air',
      online: true,
      dshStatus: 'online',
      lastSeenAt: DateTime.now(),
    ),
    Device(
      id: 'dev_mock_offline',
      name: '办公室 Mac mini',
      online: false,
      dshStatus: 'offline',
      lastSeenAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  @override
  Stream<void> get sessionExpired => const Stream<void>.empty();

  Future<T> _delay<T>(T value) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    return value;
  }

  AuthTokens _tokens() => const AuthTokens(
    accessToken: 'mock-access-token',
    refreshToken: 'mock-refresh-token',
  );

  @override
  Future<AuthTokens> register(String email, String password) async {
    if (password.length < 8) throw const ApiException('invalid_credentials');
    return _delay(_tokens());
  }

  @override
  Future<AuthTokens> login(String email, String password) async {
    if (!email.contains('@') || password.length < 8) {
      throw const ApiException('invalid_credentials', statusCode: 401);
    }
    return _delay(_tokens());
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    if (!refreshToken.startsWith('mock-')) {
      throw const ApiException('invalid_refresh_token', statusCode: 401);
    }
    return _delay(_tokens());
  }

  @override
  Future<List<Device>> listDevices() => _delay(List.unmodifiable(_devices));

  @override
  Future<String> claimPair(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ApiException('invalid_or_expired_code', statusCode: 409);
    }
    const id = 'dev_mock_paired';
    if (!_devices.any((device) => device.id == id)) {
      _devices.insert(
        0,
        Device(
          id: id,
          name: '新配对的 MacBook Pro',
          online: true,
          dshStatus: 'online',
          lastSeenAt: DateTime.now(),
        ),
      );
    }
    return _delay(id);
  }

  @override
  Future<void> renameDevice(String id, String name) async {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) throw const ApiException('not_found', statusCode: 404);
    _devices[index] = _devices[index].copyWith(name: name);
    await _delay(null);
  }

  @override
  Future<void> unbindDevice(String id) async {
    _devices.removeWhere((device) => device.id == id);
    await _delay(null);
  }

  @override
  Future<WebTicket> createWebTicket(String deviceId) =>
      _delay(const WebTicket(ticket: 'mock-ticket', expiresIn: 60));
}
