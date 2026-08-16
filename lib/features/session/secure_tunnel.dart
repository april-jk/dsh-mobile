import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/models.dart';
import 'e2ee_codec.dart';

abstract interface class SecureTunnelTransport {
  Stream<Map<String, dynamic>> get messages;
  Stream<void> get closed;

  Future<void> connect();

  Future<void> sendInner(
    String type,
    Map<String, dynamic> payload, {
    String? channel,
  });

  Future<void> close();
}

class SecureTunnel implements SecureTunnelTransport {
  SecureTunnel({required this.ticket, required this.masterKey});

  final WebTicket ticket;
  final String masterKey;
  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _closed = StreamController<void>.broadcast();
  final Completer<void> _ready = Completer<void>();
  WebSocket? _socket;
  SecureCipher? _cipher;
  bool _disposed = false;
  Future<void> _sendQueue = Future<void>.value();

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  @override
  Stream<void> get closed => _closed.stream;
  Future<void> get ready => _ready.future;

  @override
  Future<void> connect() async {
    decodeBase64Url(masterKey, length: 32);
    final handshake = await ClientHandshake.start(
      masterKeyB64: masterKey,
      accessSessionId: ticket.accessSessionId,
    );
    final socket = await WebSocket.connect(
      ticket.tunnelUrl.toString(),
      headers: {'Authorization': 'WebTicket ${ticket.ticket}'},
    );
    _socket = socket;
    unawaited(_readLoop(socket, handshake));
    _sendOuter('client_hello', handshake.toJson());
    await ready.timeout(const Duration(seconds: 10));
  }

  Future<void> _readLoop(WebSocket socket, ClientHandshake handshake) async {
    try {
      await for (final raw in socket) {
        if (raw is! String) throw const E2eeException('non-json frame');
        await _handleRaw(raw, handshake);
      }
      if (!_disposed) _fail(const E2eeException('secure tunnel closed'));
    } catch (error, stackTrace) {
      if (!_disposed) _fail(error, stackTrace);
    }
  }

  Future<void> _handleRaw(String raw, ClientHandshake handshake) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['v'] != 1 ||
        decoded['type'] is! String ||
        decoded['payload'] is! Map) {
      throw const E2eeException('invalid outer envelope');
    }
    final type = decoded['type'] as String;
    final payload = Map<String, dynamic>.from(decoded['payload'] as Map);
    if (payload['accessSessionId'] != ticket.accessSessionId) {
      throw const E2eeException('session mismatch');
    }
    if (type == 'server_hello') {
      if (_cipher != null) throw const E2eeException('duplicate server hello');
      _cipher = await handshake.acceptServerHello(payload);
      if (!_ready.isCompleted) _ready.complete();
      return;
    }
    if (type == 'sealed') {
      final cipher = _cipher;
      if (cipher == null ||
          payload['seq'] is! String ||
          payload['ciphertextB64'] is! String) {
        throw const E2eeException('sealed frame before handshake');
      }
      final inner = await cipher.open(
        SealedPayload(
          seq: payload['seq'] as String,
          ciphertextB64: payload['ciphertextB64'] as String,
        ),
      );
      if (inner is! Map || inner['v'] != 1 || inner['type'] is! String) {
        throw const E2eeException('invalid inner envelope');
      }
      _messages.add(Map<String, dynamic>.from(inner));
      return;
    }
    if (type == 'device_close') {
      throw E2eeException(payload['reason']?.toString() ?? 'device closed');
    }
    throw const E2eeException('unsupported outer message');
  }

  @override
  Future<void> sendInner(
    String type,
    Map<String, dynamic> payload, {
    String? channel,
  }) {
    final completer = Completer<void>();
    _sendQueue = _sendQueue
        .then((_) async {
          if (_disposed) throw const E2eeException('secure tunnel closed');
          await ready;
          final sealed = await _cipher!.seal({
            'v': 1,
            'type': type,
            'channel': ?channel,
            'id': _id(),
            'ts': DateTime.now().millisecondsSinceEpoch,
            'payload': payload,
          });
          _sendOuter('sealed', {
            'accessSessionId': ticket.accessSessionId,
            ...sealed.toJson(),
          });
        })
        .then(completer.complete, onError: completer.completeError);
    return completer.future;
  }

  void _sendOuter(String type, Map<String, dynamic> payload) {
    final socket = _socket;
    if (_disposed || socket == null || socket.readyState != WebSocket.open) {
      throw const E2eeException('secure tunnel unavailable');
    }
    socket.add(
      jsonEncode({
        'v': 1,
        'type': type,
        'id': _id(),
        'ts': 0,
        'payload': payload,
      }),
    );
  }

  String _id() => 'm_${encodeBase64Url(secureRandomBytes(16))}';

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (!_ready.isCompleted) _ready.completeError(error, stackTrace);
    if (!_messages.isClosed) _messages.addError(error, stackTrace);
    if (!_closed.isClosed) _closed.add(null);
    unawaited(close(notify: false));
  }

  @override
  Future<void> close({bool notify = true}) async {
    if (_disposed) return;
    if (notify && _socket?.readyState == WebSocket.open) {
      try {
        _sendOuter('client_close', {
          'accessSessionId': ticket.accessSessionId,
          'reason': 'client_closed',
        });
      } catch (_) {}
    }
    _disposed = true;
    await _socket?.close(WebSocketStatus.normalClosure, 'client closed');
    if (!_ready.isCompleted) {
      _ready.completeError(const E2eeException('secure tunnel closed'));
    }
    if (!_closed.isClosed) _closed.add(null);
    await _messages.close();
    await _closed.close();
  }
}
