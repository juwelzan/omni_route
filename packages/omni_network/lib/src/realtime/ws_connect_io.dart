import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// IO WebSocket connector: supports handshake [headers], [pingInterval],
/// [connectTimeout], and a configured `HttpClient` ([customClient]).
WebSocketChannel platformConnect(
  Uri uri,
  Iterable<String>? protocols,
  Map<String, String> headers, {
  Duration? pingInterval,
  Duration? connectTimeout,
  Object? customClient,
}) => IOWebSocketChannel.connect(
  uri,
  protocols: protocols,
  headers: headers,
  pingInterval: pingInterval,
  connectTimeout: connectTimeout,
  customClient: customClient is HttpClient ? customClient : null,
);

/// Whether WebSocket handshake headers are supported on this platform.
const bool handshakeHeadersSupported = true;

/// Immediately closes an IO HTTP client backing a WebSocket attempt.
void platformCloseClient(Object? client) {
  if (client is HttpClient) client.close(force: true);
}
