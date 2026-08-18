import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/models.dart';
import 'e2ee_codec.dart';
import 'secure_tunnel.dart';

class LocalSessionProxy {
  LocalSessionProxy._({required this.tunnel, required this.capability});

  static const _cookieName = 'dsh_local_session';
  static const _maxRequestBytes = 2 * 1024 * 1024;
  static const _maxResponseBytes = 32 * 1024 * 1024;
  static const _maxHttpChannels = 32;
  static const _maxWebSocketChannels = 16;

  final SecureTunnelTransport tunnel;
  final String capability;
  final Map<String, _PendingHttp> _pendingHttp = {};
  final Map<String, WebSocket> _webSockets = {};
  HttpServer? _server;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<void>? _closedSubscription;
  bool _bootstrapped = false;
  bool _disposed = false;

  Uri get origin {
    final server = _server;
    if (server == null) throw StateError('proxy not started');
    return Uri(scheme: 'http', host: '127.0.0.1', port: server.port);
  }

  Uri get startUrl =>
      origin.replace(queryParameters: {'bootstrap': capability});

  static Future<LocalSessionProxy> start({
    required WebTicket ticket,
    required String masterKey,
  }) async {
    final tunnel = SecureTunnel(ticket: ticket, masterKey: masterKey);
    return startWithTunnel(tunnel);
  }

  static Future<LocalSessionProxy> startWithTunnel(
    SecureTunnelTransport tunnel, {
    String? capability,
  }) async {
    final proxy = LocalSessionProxy._(
      tunnel: tunnel,
      capability: capability ?? encodeBase64Url(secureRandomBytes(16)),
    );
    proxy._messageSubscription = tunnel.messages.listen(
      (message) => unawaited(proxy._handleInnerSafely(message)),
      onError: (_) => unawaited(proxy.close()),
    );
    proxy._closedSubscription = tunnel.closed.listen(
      (_) => unawaited(proxy.close()),
    );
    try {
      await tunnel.connect();
      proxy._server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
      unawaited(proxy._serve());
      return proxy;
    } catch (_) {
      await proxy.close();
      rethrow;
    }
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    try {
      await for (final request in server) {
        unawaited(_handleRequest(request));
      }
    } catch (_) {
      if (!_disposed) await close();
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (!_validHost(request)) {
        await _jsonError(request.response, 403, 'invalid_local_origin');
        return;
      }
      if (!_authorized(request)) {
        final bootstrap = request.uri.queryParameters['bootstrap'];
        if (!_bootstrapped && bootstrap == capability) {
          _bootstrapped = true;
          final cookie = Cookie(_cookieName, capability)
            ..httpOnly = true
            ..sameSite = SameSite.strict
            ..path = '/';
          request.response.cookies.add(cookie);
          final query = Map<String, String>.from(request.uri.queryParameters)
            ..remove('bootstrap');
          await request.response.redirect(
            origin.replace(path: request.uri.path, queryParameters: query),
          );
          return;
        }
        await _jsonError(request.response, 401, 'invalid_local_session');
        return;
      }
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        await _openWebSocket(request);
      } else {
        await _forwardHttp(request);
      }
    } catch (_) {
      try {
        await _jsonError(request.response, 502, 'secure_tunnel_failed');
      } catch (_) {}
    }
  }

  bool _validHost(HttpRequest request) =>
      request.headers.value(HttpHeaders.hostHeader) ==
      '127.0.0.1:${_server?.port}';

  bool _authorized(HttpRequest request) => request.cookies.any(
    (cookie) => cookie.name == _cookieName && cookie.value == capability,
  );

  Map<String, dynamic> _headers(HttpHeaders headers) {
    const removed = {
      'host',
      'connection',
      'upgrade',
      'content-length',
      'transfer-encoding',
      'sec-websocket-key',
      'sec-websocket-version',
      'sec-websocket-extensions',
    };
    final result = <String, dynamic>{};
    headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (removed.contains(lower)) return;
      if (lower == 'cookie') {
        final cookies = values
            .join(';')
            .split(';')
            .map((value) => value.trim())
            .where(
              (value) => value.isNotEmpty && !value.startsWith('$_cookieName='),
            )
            .toList(growable: false);
        if (cookies.isNotEmpty) result[name] = cookies.join('; ');
        return;
      }
      result[name] = values.length == 1 ? values.single : values;
    });
    return result;
  }

  Future<Uint8List> _readBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > _maxRequestBytes) {
        throw const _ProxyLimitException();
      }
    }
    return builder.takeBytes();
  }

  Future<void> _forwardHttp(HttpRequest request) async {
    if (_pendingHttp.length >= _maxHttpChannels) {
      await _jsonError(request.response, 429, 'too_many_tunnels');
      return;
    }
    Uint8List body;
    try {
      body = await _readBody(request);
    } on _ProxyLimitException {
      await _jsonError(request.response, 413, 'request_too_large');
      return;
    }
    final channel = _channel();
    final pending = _PendingHttp(
      response: request.response,
      timer: Timer(const Duration(seconds: 60), () {
        final current = _pendingHttp.remove(channel);
        if (current == null) return;
        unawaited(_jsonError(current.response, 504, 'tunnel_timeout'));
        unawaited(tunnel.sendInner('http_close', const {}, channel: channel));
      }),
    );
    _pendingHttp[channel] = pending;
    unawaited(
      request.response.done.whenComplete(() {
        final current = _pendingHttp.remove(channel);
        if (current == null) return;
        current.timer.cancel();
        unawaited(tunnel.sendInner('http_close', const {}, channel: channel));
      }),
    );
    await tunnel.sendInner('http_req', {
      'method': request.method,
      'path': request.uri.toString(),
      'headers': _headers(request.headers),
      'bodyB64': base64.encode(body),
    }, channel: channel);
  }

  Future<void> _openWebSocket(HttpRequest request) async {
    if (_webSockets.length >= _maxWebSocketChannels) {
      request.response.statusCode = HttpStatus.tooManyRequests;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    final channel = _channel();
    _webSockets[channel] = socket;
    await tunnel.sendInner('ws_open', {
      'path': request.uri.toString(),
      'headers': _headers(request.headers),
    }, channel: channel);
    try {
      await for (final data in socket) {
        if (data is String) {
          await tunnel.sendInner('ws_frame', {
            'dataB64': base64.encode(utf8.encode(data)),
            'opcode': 1,
          }, channel: channel);
        } else if (data is List<int>) {
          await tunnel.sendInner('ws_frame', {
            'dataB64': base64.encode(data),
            'opcode': 2,
          }, channel: channel);
        }
      }
    } finally {
      if (_webSockets.remove(channel) != null) {
        await tunnel.sendInner('ws_close', {
          'code': socket.closeCode,
          'reason': socket.closeReason ?? '',
        }, channel: channel);
      }
    }
  }

  Future<void> _handleInner(Map<String, dynamic> message) async {
    final type = message['type'];
    final channel = message['channel'];
    final payload = message['payload'];
    if (type is! String || channel is! String || payload is! Map) {
      throw const E2eeException('invalid inner message');
    }
    final data = Map<String, dynamic>.from(payload);
    switch (type) {
      case 'http_res':
        await _httpResponse(channel, data);
      case 'ws_open_ok':
        return;
      case 'ws_frame':
        final socket = _webSockets[channel];
        if (socket == null) return;
        final bytes = base64.decode(data['dataB64']?.toString() ?? '');
        if (data['opcode'] == 2) {
          socket.add(bytes);
        } else {
          socket.add(utf8.decode(bytes));
        }
      case 'ws_close':
        final socket = _webSockets.remove(channel);
        await socket?.close(
          _normalizeCloseCode(data['code']),
          data['reason']?.toString(),
        );
      default:
        throw const E2eeException('unsupported inner message');
    }
  }

  Future<void> _handleInnerSafely(Map<String, dynamic> message) async {
    try {
      await _handleInner(message);
    } catch (_) {
      await close();
    }
  }

  Future<void> _httpResponse(String channel, Map<String, dynamic> data) async {
    final pending = _pendingHttp[channel];
    if (pending == null) return;
    final sequence = data['seq'];
    if (sequence is! int || sequence != pending.sequence) {
      await close();
      return;
    }
    pending.sequence += 1;
    if (!pending.started) {
      pending.started = true;
      pending.response.statusCode = data['status'] is int
          ? data['status'] as int
          : HttpStatus.badGateway;
      final headers = data['headers'];
      if (headers is Map) _applyResponseHeaders(pending.response, headers);
    }
    final body = base64.decode(data['bodyB64']?.toString() ?? '');
    pending.bytes += body.length;
    if (pending.bytes > _maxResponseBytes) {
      _pendingHttp.remove(channel);
      pending.timer.cancel();
      await pending.response.close();
      await tunnel.sendInner('http_close', const {}, channel: channel);
      return;
    }
    if (body.isNotEmpty) pending.response.add(body);
    if (data['final'] != false) {
      _pendingHttp.remove(channel);
      pending.timer.cancel();
      await pending.response.close();
    } else {
      pending.timer.cancel();
      pending.timer = Timer(const Duration(seconds: 60), () {
        final current = _pendingHttp.remove(channel);
        if (current != null) unawaited(current.response.close());
      });
    }
  }

  void _applyResponseHeaders(HttpResponse response, Map headers) {
    const removed = {'content-length', 'transfer-encoding', 'connection'};
    for (final entry in headers.entries) {
      final name = entry.key.toString();
      if (removed.contains(name.toLowerCase())) continue;
      Object value = entry.value;
      if (name.toLowerCase() == 'location' && value is String) {
        final location = Uri.tryParse(value);
        if (location != null && location.host == '127.0.0.1') {
          value = origin
              .resolve(location.path)
              .replace(query: location.query)
              .toString();
        }
      }
      if (value is List) {
        for (final item in value) {
          response.headers.add(name, item.toString());
        }
      } else {
        response.headers.set(name, value.toString());
      }
    }
  }

  int? _normalizeCloseCode(Object? value) {
    if (value is! int) return null;
    if ({1000, 1001, 1002, 1003}.contains(value) ||
        value >= 1007 && value <= 1014 ||
        value >= 3000 && value <= 4999) {
      return value;
    }
    return null;
  }

  String _channel() => 'ch_${encodeBase64Url(secureRandomBytes(16))}';

  Future<void> _jsonError(
    HttpResponse response,
    int status,
    String reason,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'reason': reason}));
    await response.close();
  }

  Future<void> _failOpenRequests(String reason) async {
    for (final pending in _pendingHttp.values) {
      pending.timer.cancel();
      try {
        await _jsonError(pending.response, 502, reason);
      } catch (_) {}
    }
    _pendingHttp.clear();
    for (final socket in _webSockets.values) {
      await socket.close(1013, reason);
    }
    _webSockets.clear();
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    await _server?.close(force: true);
    await _failOpenRequests('session_closed');
    await _messageSubscription?.cancel();
    await _closedSubscription?.cancel();
    await tunnel.close();
  }
}

class _PendingHttp {
  _PendingHttp({required this.response, required this.timer});

  final HttpResponse response;
  Timer timer;
  bool started = false;
  int sequence = 0;
  int bytes = 0;
}

class _ProxyLimitException implements Exception {
  const _ProxyLimitException();
}
