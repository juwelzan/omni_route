import 'package:web_socket_channel/web_socket_channel.dart';

/// Web WebSocket connector: browsers forbid handshake headers.
WebSocketChannel platformConnect(
  Uri uri,
  Iterable<String>? protocols,
  Map<String, String> headers, {
  Duration? pingInterval,
  Duration? connectTimeout,
  Object? customClient,
}) {
  if (headers.isNotEmpty) {
    throw UnsupportedError(
      'Browsers cannot send WebSocket handshake headers; configure '
      'WsWebAuthMode.queryParam or WsWebAuthMode.firstMessage instead',
    );
  }
  return WebSocketChannel.connect(uri, protocols: protocols);
}

/// Whether WebSocket handshake headers are supported on this platform.
const bool handshakeHeadersSupported = false;

/// Web connections have no dedicated HTTP client handle to force-close.
void platformCloseClient(Object? client) {}
