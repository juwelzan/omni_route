import 'dart:convert';

import 'package:meta/meta.dart';

/// Redacted WebSocket activity record emitted for logging & Flutter Inspector.
@immutable
final class WsLogRecord {
  /// Creates a WebSocket activity record.
  const WsLogRecord({
    required this.uri,
    required this.direction,
    required this.summary,
    required this.timestamp,
  });

  /// Redacted target WebSocket URI.
  final String uri;

  /// `'open'`, `'in'`, `'out'`, `'ws'`, or `'err'`.
  final String direction;

  /// Redacted message/frame summary.
  final String summary;

  /// When the event occurred.
  final DateTime timestamp;
}

/// Strategy used on Web browsers (where custom WebSocket handshake headers are
/// forbidden) to pass auth credentials safely.
sealed class WsWebAuthMode {
  const WsWebAuthMode();

  /// Do not attempt to pass auth headers in browsers.
  const factory WsWebAuthMode.none() = _WsNoneAuthMode;

  /// Append the resolved credential/token as query parameter [paramName] when
  /// handshake headers are unsupported (`Web`).
  const factory WsWebAuthMode.queryParam({String paramName}) =
      _WsQueryAuthMode;

  /// Connect first, then send `{typeKey: event, tokenKey: token}` as the first
  /// text frame when handshake headers are unsupported (`Web`).
  const factory WsWebAuthMode.firstMessage({
    String event,
    String typeKey,
    String tokenKey,
  }) = _WsFirstMessageAuthMode;
}

final class _WsNoneAuthMode extends WsWebAuthMode {
  const _WsNoneAuthMode();
}

final class _WsQueryAuthMode extends WsWebAuthMode {
  const _WsQueryAuthMode({this.paramName = 'token'});
  final String paramName;
}

final class _WsFirstMessageAuthMode extends WsWebAuthMode {
  const _WsFirstMessageAuthMode({
    this.event = 'auth',
    this.typeKey = 'event',
    this.tokenKey = 'token',
  });

  final String event;
  final String typeKey;
  final String tokenKey;
}

/// Decoded inbound message from a [WsProtocol].
@immutable
final class WsInboundPacket {
  /// Creates a decoded WebSocket event/RPC packet.
  const WsInboundPacket({
    this.event,
    this.data,
    this.requestId,
    this.isError = false,
    this.errorMessage,
  });

  /// Event name, if present.
  final String? event;

  /// Decoded payload object (`Map`, `List`, primitive, etc.).
  final Object? data;

  /// Correlation identifier for RPC replies.
  final String? requestId;

  /// Whether this packet represents an RPC/protocol error.
  final bool isError;

  /// Optional error message when [isError] is `true`.
  final String? errorMessage;
}

/// Encodes outbound events/RPC requests and decodes inbound frames for
/// `OmniWebSocket` (`on<T>`, `emit`, `request<T>`).
abstract interface class WsProtocol {
  /// Encodes a one-way event message.
  Object encodeEvent(String event, Object? data);

  /// Encodes an RPC request carrying a correlation [requestId].
  Object encodeRequest(String requestId, String event, Object? data);

  /// Encodes an application-level ping message, or returns `null` to skip.
  Object? encodePing();

  /// Parses an incoming frame, or returns `null` if it is not structured for
  /// this protocol (raw frames remain visible on `messages`).
  WsInboundPacket? decode(Object rawMessage);
}

/// Default JSON envelope WebSocket protocol:
/// `{ "event": "...", "data": ..., "id": "..." }`.
final class DefaultWsProtocol implements WsProtocol {
  /// Creates a JSON WebSocket protocol with customizable key names.
  const DefaultWsProtocol({
    this.eventKey = 'event',
    this.dataKey = 'data',
    this.idKey = 'id',
    this.errorKey = 'error',
    this.pingEvent = 'ping',
    this.pongEvent = 'pong',
  });

  /// Key carrying the event name (default `'event'`).
  final String eventKey;

  /// Key carrying the payload (default `'data'`).
  final String dataKey;

  /// Key carrying the RPC correlation id (default `'id'`).
  final String idKey;

  /// Key carrying an error message/object in RPC error replies.
  final String errorKey;

  /// Event name emitted for application-level heartbeats (`null` disables).
  final String? pingEvent;

  /// Event name recognized as a heartbeat reply.
  final String? pongEvent;

  @override
  Object encodeEvent(String event, Object? data) => jsonEncode({
    eventKey: event,
    dataKey: ?data,
  });

  @override
  Object encodeRequest(String requestId, String event, Object? data) =>
      jsonEncode({
        idKey: requestId,
        eventKey: event,
        dataKey: ?data,
      });

  @override
  Object? encodePing() =>
      pingEvent == null ? null : jsonEncode({eventKey: pingEvent});

  @override
  WsInboundPacket? decode(Object rawMessage) {
    if (rawMessage is! String) return null;
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) return null;
      final event = decoded[eventKey]?.toString();
      final requestId = decoded[idKey]?.toString();
      final err = decoded[errorKey];
      final isError = err != null;
      final data = decoded.containsKey(dataKey) ? decoded[dataKey] : decoded;
      return WsInboundPacket(
        event: event,
        data: data,
        requestId: requestId,
        isError: isError,
        errorMessage: err is Map ? (err['message']?.toString() ?? '$err') : err?.toString(),
      );
    } on FormatException {
      return null;
    }
  }
}

/// Applies [WsWebAuthMode] to resolved WebSocket [uri] and [headers] when
/// handshake headers are unsupported (`Web`), returning updated `(uri, headers,
/// firstMessagePayload)`. Internal helper.
(Uri, Map<String, String>, String?) resolveWsAuthForPlatform({
  required Uri uri,
  required Map<String, String> headers,
  required WsWebAuthMode webAuthMode,
  required bool supportsHandshakeHeaders,
  required String? bearerOrToken,
}) {
  if (supportsHandshakeHeaders || headers.isEmpty) {
    return (uri, headers, null);
  }
  final tokenValue =
      bearerOrToken ??
      headers['authorization'] ??
      headers['Authorization'] ??
      headers['x-api-key'] ??
      headers['X-API-Key'];
  final strippedHeaders = const <String, String>{};
  switch (webAuthMode) {
    case _WsNoneAuthMode():
      return (uri, strippedHeaders, null);
    case _WsQueryAuthMode(:final paramName):
      if (tokenValue == null || tokenValue.isEmpty) {
        return (uri, strippedHeaders, null);
      }
      final clean = tokenValue.startsWith('Bearer ')
          ? tokenValue.substring(7)
          : tokenValue;
      return (
        uri.replace(queryParameters: {...uri.queryParameters, paramName: clean}),
        strippedHeaders,
        null,
      );
    case _WsFirstMessageAuthMode(:final event, :final typeKey, :final tokenKey):
      if (tokenValue == null || tokenValue.isEmpty) {
        return (uri, strippedHeaders, null);
      }
      final clean = tokenValue.startsWith('Bearer ')
          ? tokenValue.substring(7)
          : tokenValue;
      return (
        uri,
        strippedHeaders,
        jsonEncode({typeKey: event, tokenKey: clean}),
      );
  }
}
