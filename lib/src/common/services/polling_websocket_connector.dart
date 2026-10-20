// ignore_for_file: implementation_imports, depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:socket_io_client/src/engine/transport/default_ws_connector.dart';
import 'package:web_socket/web_socket.dart' as ws;

/// Resilient Engine.IO / Socket.IO WebSocket connector that seamlessly falls back
/// to Engine.IO HTTP polling if raw WebSocket upgrade is blocked (e.g. Cloudflare 502 Bad Gateway).
Future<ws.WebSocket> resilientWebSocketConnector(
  Uri uri, {
  Iterable<String>? protocols,
  Map<String, String>? headers,
}) async {
  if (kIsWeb) {
    return connectWebSocket(uri, protocols: protocols, headers: headers);
  }

  try {
    // Attempt native WebSocket connection first with a 1500ms timeout
    final socket = await connectWebSocket(
      uri,
      protocols: protocols,
      headers: headers,
    ).timeout(const Duration(milliseconds: 1500));
    return socket;
  } catch (e) {
    Logger().d(
      'resilientWebSocketConnector::Native WebSocket failed ($e). Falling back to PollingWebSocket for $uri',
    );
    return PollingWebSocket.connect(uri, protocols: protocols, headers: headers);
  }
}

/// Emulates a [ws.WebSocket] interface over Engine.IO v4 HTTP long-polling.
///
/// Ensures real-time Socket.IO bidirectional communication works reliably even behind
/// reverse proxies (like Cloudflare) that drop or reject `Upgrade: websocket`.
class PollingWebSocket implements ws.WebSocket {
  final Uri serverUri;
  final Map<String, String> headers;
  final HttpClient _client = HttpClient();
  final Logger _log = Logger();

  late final StreamController<ws.WebSocketEvent> _eventController =
      StreamController<ws.WebSocketEvent>.broadcast(
    onListen: () {
      if (_initialOpenPacket != null) {
        _eventController.add(ws.TextDataReceived(_initialOpenPacket!));
        _initialOpenPacket = null;
      }
    },
  );

  String? _initialOpenPacket;
  String? _sid;
  bool _closed = false;
  bool _isPolling = false;

  PollingWebSocket(this.serverUri, {Map<String, String>? headers})
      : headers = headers ?? {};

  /// Connects via Engine.IO HTTP polling and returns an active [PollingWebSocket].
  static Future<ws.WebSocket> connect(
    Uri uri, {
    Iterable<String>? protocols,
    Map<String, String>? headers,
  }) async {
    final socket = PollingWebSocket(uri, headers: headers);
    await socket._init();
    return socket;
  }

  Future<void> _init() async {
    final scheme = serverUri.scheme == 'wss'
        ? 'https'
        : serverUri.scheme == 'ws'
            ? 'http'
            : serverUri.scheme;
    final queryMap = Map<String, String>.from(serverUri.queryParameters);
    queryMap['transport'] = 'polling';
    queryMap['EIO'] = '4';

    final pollUri = Uri(
      scheme: scheme,
      host: serverUri.host,
      port: (serverUri.hasPort && serverUri.port != 0) ? serverUri.port : null,
      path: serverUri.path,
      queryParameters: queryMap,
    );

    _log.d('PollingWebSocket::_init::Connecting to $pollUri');
    final req = await _client.getUrl(pollUri);
    headers.forEach((k, v) => req.headers.set(k, v));
    req.headers.set('User-Agent', 'Mozilla/5.0 (Mobile; ShearHeaven)');
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();

    if (resp.statusCode != 200) {
      throw ws.WebSocketException(
        'Handshake failed with status ${resp.statusCode}: $body',
      );
    }

    final openBrace = body.indexOf('{');
    if (openBrace == -1) {
      throw ws.WebSocketException('Invalid handshake body: $body');
    }
    final jsonStr = body.substring(openBrace);
    final data = jsonDecode(jsonStr);
    _sid = data['sid'] as String?;

    if (_sid == null || _sid!.isEmpty) {
      throw ws.WebSocketException('Failed to extract Engine.IO SID from handshake: $body');
    }

    _log.i('PollingWebSocket::_init::Connected successfully with SID: $_sid');
    _initialOpenPacket = body;
    _startPollingLoop();
  }

  void _startPollingLoop() async {
    while (!_closed && _sid != null) {
      if (_isPolling) {
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }
      _isPolling = true;
      try {
        final scheme = serverUri.scheme == 'wss'
            ? 'https'
            : serverUri.scheme == 'ws'
                ? 'http'
                : serverUri.scheme;
        final queryMap = Map<String, String>.from(serverUri.queryParameters);
        queryMap['transport'] = 'polling';
        queryMap['EIO'] = '4';
        queryMap['sid'] = _sid!;

        final pollUri = Uri(
          scheme: scheme,
          host: serverUri.host,
          port: (serverUri.hasPort && serverUri.port != 0) ? serverUri.port : null,
          path: serverUri.path,
          queryParameters: queryMap,
        );

        final req = await _client.getUrl(pollUri);
        headers.forEach((k, v) => req.headers.set(k, v));
        req.headers.set('User-Agent', 'Mozilla/5.0 (Mobile; ShearHeaven)');
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();

        if (resp.statusCode == 200 && body.isNotEmpty) {
          // In Engine.IO v4, packets in polling response are separated by \x1e (record separator)
          final packets = body.split('\x1e');
          for (final packet in packets) {
            if (packet.trim().isNotEmpty) {
              _eventController.add(ws.TextDataReceived(packet));
            }
          }
        } else if (resp.statusCode != 200) {
          _log.w('PollingWebSocket::_startPollingLoop::Poll returned status ${resp.statusCode}: $body');
          if (resp.statusCode == 400 || resp.statusCode == 401 || resp.statusCode == 403) {
            close(resp.statusCode, 'HTTP ${resp.statusCode}');
            break;
          }
        }
      } catch (e) {
        if (!_closed) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } finally {
        _isPolling = false;
      }
    }
  }

  @override
  Stream<ws.WebSocketEvent> get events => _eventController.stream;

  @override
  String get protocol => '';

  @override
  void sendText(String s) async {
    if (_closed || _sid == null) return;
    try {
      final scheme = serverUri.scheme == 'wss'
          ? 'https'
          : serverUri.scheme == 'ws'
              ? 'http'
              : serverUri.scheme;
      final queryMap = Map<String, String>.from(serverUri.queryParameters);
      queryMap['transport'] = 'polling';
      queryMap['EIO'] = '4';
      queryMap['sid'] = _sid!;

      final postUri = Uri(
        scheme: scheme,
        host: serverUri.host,
        port: (serverUri.hasPort && serverUri.port != 0) ? serverUri.port : null,
        path: serverUri.path,
        queryParameters: queryMap,
      );

      final req = await _client.postUrl(postUri);
      headers.forEach((k, v) => req.headers.set(k, v));
      req.headers.set('User-Agent', 'Mozilla/5.0 (Mobile; ShearHeaven)');
      req.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
      req.write(s);
      final resp = await req.close();
      await resp.drain();
    } catch (e) {
      _log.w('PollingWebSocket::sendText::Error sending packet: $e');
    }
  }

  @override
  void sendBytes(Uint8List b) {
    sendText(base64Encode(b));
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_closed) return;
    _closed = true;
    _client.close(force: true);
    _eventController.add(ws.CloseReceived(code, reason ?? ''));
    await _eventController.close();
  }
}
