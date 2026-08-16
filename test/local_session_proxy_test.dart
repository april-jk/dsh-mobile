import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dsh_mobile/features/session/local_session_proxy.dart';
import 'package:dsh_mobile/features/session/secure_tunnel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstraps once and forwards HTTP over the secure tunnel', () async {
    final tunnel = _FakeTunnel();
    final proxy = await LocalSessionProxy.startWithTunnel(
      tunnel,
      capability: 'test-capability',
    );
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await proxy.close();
    });

    final cookie = await _bootstrap(client, proxy.startUrl);
    final unauthorized = await client.getUrl(proxy.origin.resolve('/private'));
    final unauthorizedResponse = await unauthorized.close();
    expect(unauthorizedResponse.statusCode, HttpStatus.unauthorized);
    await unauthorizedResponse.drain<void>();

    final forwarded = tunnel.next('http_req');
    final request = await client.postUrl(proxy.origin.resolve('/api/task?q=1'));
    request.cookies.add(cookie);
    request.headers.set('x-test', 'private-header');
    request.write('private-body');
    final responseFuture = request.close();

    final outbound = await forwarded;
    expect(outbound.payload['method'], 'POST');
    expect(outbound.payload['path'], '/api/task?q=1');
    expect(
      outbound.payload['bodyB64'],
      base64.encode(utf8.encode('private-body')),
    );
    expect((outbound.payload['headers'] as Map)['x-test'], 'private-header');
    expect((outbound.payload['headers'] as Map).containsKey('cookie'), isFalse);

    tunnel.emit({
      'v': 1,
      'type': 'http_res',
      'channel': outbound.channel,
      'payload': {
        'status': 201,
        'headers': {'content-type': 'text/plain'},
        'bodyB64': base64.encode(utf8.encode('created')),
        'seq': 0,
        'final': true,
      },
    });
    final response = await responseFuture;
    expect(response.statusCode, 201);
    expect(await utf8.decoder.bind(response).join(), 'created');
  });

  test('forwards WebSocket text frames in both directions', () async {
    final tunnel = _FakeTunnel();
    final proxy = await LocalSessionProxy.startWithTunnel(
      tunnel,
      capability: 'test-capability',
    );
    final client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await proxy.close();
    });
    final cookie = await _bootstrap(client, proxy.startUrl);

    final opened = tunnel.next('ws_open');
    final socket = await WebSocket.connect(
      proxy.origin.replace(scheme: 'ws', path: '/socket').toString(),
      headers: {HttpHeaders.cookieHeader: '${cookie.name}=${cookie.value}'},
    );
    addTearDown(socket.close);
    final openMessage = await opened;
    expect(openMessage.payload['path'], '/socket');

    final sentFrame = tunnel.next('ws_frame');
    socket.add('new task');
    final frame = await sentFrame;
    expect(frame.channel, openMessage.channel);
    expect(frame.payload['opcode'], 1);
    expect(
      utf8.decode(base64.decode(frame.payload['dataB64'] as String)),
      'new task',
    );

    final receivedFrame = socket.first;
    tunnel.emit({
      'v': 1,
      'type': 'ws_frame',
      'channel': openMessage.channel,
      'payload': {
        'dataB64': base64.encode(utf8.encode('accepted')),
        'opcode': 1,
      },
    });
    expect(await receivedFrame, 'accepted');
  });
}

Future<Cookie> _bootstrap(HttpClient client, Uri startUrl) async {
  final request = await client.getUrl(startUrl);
  request.followRedirects = false;
  final response = await request.close();
  expect(response.statusCode, HttpStatus.found);
  final cookie = response.cookies.single;
  await response.drain<void>();
  return cookie;
}

class _SentInner {
  const _SentInner(this.type, this.payload, this.channel);

  final String type;
  final Map<String, dynamic> payload;
  final String? channel;
}

class _FakeTunnel implements SecureTunnelTransport {
  final _messages = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final _closed = StreamController<void>.broadcast(sync: true);
  final _sent = StreamController<_SentInner>.broadcast(sync: true);
  bool disposed = false;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Stream<void> get closed => _closed.stream;

  Future<_SentInner> next(String type) =>
      _sent.stream.firstWhere((message) => message.type == type);

  void emit(Map<String, dynamic> message) => _messages.add(message);

  @override
  Future<void> connect() async {}

  @override
  Future<void> sendInner(
    String type,
    Map<String, dynamic> payload, {
    String? channel,
  }) async {
    _sent.add(_SentInner(type, payload, channel));
  }

  @override
  Future<void> close() async {
    if (disposed) return;
    disposed = true;
    await _messages.close();
    await _closed.close();
    await _sent.close();
  }
}
