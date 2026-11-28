import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../log/redactor.dart';
import 'ws_connect_web.dart' if (dart.library.io) 'ws_connect_io.dart';
import 'ws_protocol.dart';

/// Opens a channel; inject for tests or custom transports.
typedef WebSocketConnector =
    WebSocketChannel Function(
      Uri uri,
      Iterable<String>? protocols,
      Map<String, String> headers,
    );

/// Connection state of an [OmniWebSocket].
enum WebSocketState {
  /// Opening a connection.
  connecting,

  /// Connected.
  open,

  /// Lost; waiting before the next attempt.
  reconnecting,

  /// Closed for good (by you, by a normal server close, or after giving up).
  closed,
}

/// A WebSocket that reconnects with backoff, optional heartbeats, browser auth
/// fallback, and typed event / RPC messaging (`on<T>`, `emit`, `request<T>`).
final class OmniWebSocket {
  /// Connects immediately.
  OmniWebSocket(
    this.uri, {
    this.protocols,
    FutureOr<Map<String, String>> Function()? headers,
    this.minDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.maxReconnects,
    this.bufferWhileDisconnected = false,
    this.maxBuffered = 100,
    this.heartbeatInterval,
    this.pongTimeout = const Duration(seconds: 10),
    this.connectTimeout,
    this.protocol = const DefaultWsProtocol(),
    this.webAuthMode = const WsWebAuthMode.none(),
    this.onOpen,
    WebSocketConnector? connector,
    Object? Function()? customClientFactory,
    void Function(String direction, String summary)? onLog,
    Random? random,
  }) : _headersProvider = headers,
       _customConnector = connector,
       _clientFactory = customClientFactory,
       _logCallback = onLog,
       _random = random ?? Random() {
    unawaited(_loop());
  }

  /// Server URL (`ws:` or `wss:`).
  final Uri uri;

  /// Sub-protocols offered.
  final Iterable<String>? protocols;

  /// Initial reconnect delay.
  final Duration minDelay;

  /// Maximum reconnect delay.
  final Duration maxDelay;

  /// Consecutive failed attempts allowed (`null` = unlimited).
  final int? maxReconnects;

  /// Keep messages sent while disconnected (explicit opt-in).
  final bool bufferWhileDisconnected;

  /// Buffer limit when [bufferWhileDisconnected].
  final int maxBuffered;

  /// Optional periodic ping/heartbeat interval.
  final Duration? heartbeatInterval;

  /// Max idle duration after a heartbeat before considering the socket dead.
  final Duration pongTimeout;

  /// Connection handshake timeout.
  final Duration? connectTimeout;

  /// Protocol used by [on], [emit], and [request].
  final WsProtocol protocol;

  /// Strategy for authenticating WebSockets on Web browsers when headers are
  /// stripped.
  final WsWebAuthMode webAuthMode;

  /// Runs after every successful connect.
  final FutureOr<void> Function(OmniWebSocket socket)? onOpen;

  /// Whether this platform can send handshake headers.
  static bool get supportsHandshakeHeaders => handshakeHeadersSupported;

  final FutureOr<Map<String, String>> Function()? _headersProvider;
  final WebSocketConnector? _customConnector;
  final Object? Function()? _clientFactory;
  final void Function(String direction, String summary)? _logCallback;
  final Random _random;

  final _messages = StreamController<Object>.broadcast();
  final _packets = StreamController<WsInboundPacket>.broadcast();
  final _states = StreamController<WebSocketState>.broadcast(sync: true);
  final List<Object> _buffer = [];
  final Map<String, Completer<WsInboundPacket>> _pendingRpc = {};

  WebSocketChannel? _channel;
  Object? _attemptClient;
  StreamSubscription<dynamic>? _inboundSub;
  void Function(Object? error)? _abortStream;
  WebSocketState _state = WebSocketState.connecting;
  Completer<void>? _wait;
  Timer? _heartbeatTimer;
  DateTime _lastInboundAt = DateTime.now();
  bool _closed = false;
  int _connects = 0;
  int _rpcSeq = 0;

  /// Incoming messages (`String` or `List<int>`), broadcast. Errors that
  /// end reconnecting are delivered as stream errors.
  Stream<Object> get messages => _messages.stream;

  /// Incoming text messages parsed as JSON.
  Stream<Object?> get jsonMessages =>
      messages.where((m) => m is String).map((m) => jsonDecode(m as String));

  /// State changes, broadcast.
  Stream<WebSocketState> get states => _states.stream;

  /// Current state.
  WebSocketState get state => _state;

  /// Successful connects so far (diagnostics/tests).
  int get connectCount => _connects;

  /// Messages waiting to be sent after reconnect.
  int get buffered => _buffer.length;

  /// Close code of the last connection, if any.
  int? get lastCloseCode => _lastCloseCode;
  int? _lastCloseCode;

  /// Subscribes to decoded protocol events matching [eventName].
  Stream<T> on<T>(
    String eventName, {
    T Function(Map<String, dynamic> json)? decoder,
  }) => _packets.stream
      .where((p) => p.event == eventName && !p.isError)
      .map((p) => _decodePacket<T>(p, decoder));

  T _decodePacket<T>(
    WsInboundPacket packet,
    T Function(Map<String, dynamic> json)? decoder,
  ) {
    final data = packet.data;
    if (decoder != null) {
      if (data is! Map) {
        throw FormatException(
          'Expected JSON object for WS event "${packet.event}"',
        );
      }
      return decoder(Map<String, dynamic>.from(data));
    }
    if (data is T) return data;
    if (T == dynamic) return data as T;
    throw FormatException(
      'Cannot cast WS event "${packet.event}" (${data.runtimeType}) to $T',
    );
  }

  /// Sends a structured event via [protocol].
  void emit(String eventName, [Object? data]) {
    if (_closed) throw StateError('OmniWebSocket is closed');
    send(protocol.encodeEvent(eventName, data));
  }

  /// Sends an RPC request over this WebSocket and waits for the matching
  /// correlated response packet.
  Future<T> request<T>(
    String eventName, {
    Object? data,
    Duration timeout = const Duration(seconds: 10),
    T Function(Map<String, dynamic> json)? decoder,
  }) async {
    if (_closed) throw StateError('OmniWebSocket is closed');
    final id = 'rpc_${++_rpcSeq}';
    final completer = Completer<WsInboundPacket>();
    _pendingRpc[id] = completer;
    try {
      send(protocol.encodeRequest(id, eventName, data));
      final packet = await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'WebSocket RPC "$eventName" timed out after $timeout',
        ),
      );
      if (packet.isError) {
        throw StateError(
          packet.errorMessage ?? 'WebSocket RPC "$eventName" failed',
        );
      }
      return _decodePacket<T>(packet, decoder);
    } finally {
      _pendingRpc.remove(id);
    }
  }

  void _set(WebSocketState s) {
    if (_state == s) return;
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  void _abortConnection([Object? error]) {
    final abort = _abortStream;
    _abortStream = null;
    abort?.call(error);
    final sub = _inboundSub;
    _inboundSub = null;
    if (sub != null) unawaited(sub.cancel());
    platformCloseClient(_attemptClient);
    _attemptClient = null;
  }

  void _startHeartbeat(WebSocketChannel channel) {
    _heartbeatTimer?.cancel();
    final interval = heartbeatInterval;
    if (interval == null) return;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      if (_closed || !identical(_channel, channel)) return;
      final now = DateTime.now();
      if (now.difference(_lastInboundAt) > interval + pongTimeout) {
        _logCallback?.call('ws', 'heartbeat timeout; closing socket');
        unawaited(
          channel.sink
              .close(4000, 'heartbeat_timeout')
              .timeout(const Duration(seconds: 1), onTimeout: () {}),
        );
        _abortConnection(StateError('WebSocket heartbeat timeout'));
        return;
      }
      final pingFrame = protocol.encodePing();
      if (pingFrame != null && _state == WebSocketState.open) {
        try {
          channel.sink.add(pingFrame);
        } catch (_) {}
      }
    });
  }

  Future<void> _loop() async {
    var failures = 0;
    while (!_closed) {
      _set(WebSocketState.connecting);
      WebSocketChannel? channel;
      Object? attemptClient;
      try {
        final rawHeaders =
            await _headersProvider?.call() ?? const <String, String>{};
        if (_closed) break;
        final (
          connectUri,
          connectHeaders,
          firstAuthFrame,
        ) = resolveWsAuthForPlatform(
          uri: uri,
          headers: rawHeaders,
          webAuthMode: webAuthMode,
          supportsHandshakeHeaders:
              supportsHandshakeHeaders || _customConnector != null,
          bearerOrToken: null,
        );
        attemptClient = _attemptClient = _clientFactory?.call();
        channel = _customConnector != null
            ? _customConnector(connectUri, protocols, connectHeaders)
            : platformConnect(
                connectUri,
                protocols,
                connectHeaders,
                pingInterval: heartbeatInterval,
                connectTimeout: connectTimeout,
                customClient: attemptClient,
              );
        await channel.ready;
        if (_closed) {
          await channel.sink
              .close(1000)
              .timeout(const Duration(seconds: 1), onTimeout: () {});
          break;
        }
        _channel = channel;
        _connects++;
        final openedAt = DateTime.now();
        var hadInbound = false;
        _lastInboundAt = openedAt;
        _set(WebSocketState.open);
        _logCallback?.call('open', _wsRedactor.uri(connectUri));
        if (firstAuthFrame != null) {
          channel.sink.add(firstAuthFrame);
        }
        while (_buffer.isNotEmpty) {
          channel.sink.add(_buffer.removeAt(0));
        }

        final streamDone = Completer<void>();
        _abortStream = (Object? err) {
          if (!streamDone.isCompleted) {
            if (err != null) {
              streamDone.completeError(err);
            } else {
              streamDone.complete();
            }
          }
        };
        _inboundSub = channel.stream.listen(
          (m) {
            hadInbound = true;
            _lastInboundAt = DateTime.now();
            final msg = m as Object;
            _logCallback?.call(
              'in',
              msg is String ? msg : '<${(msg as List<int>).length} bytes>',
            );
            final packet = protocol.decode(msg);
            if (packet != null) {
              final pendingId = packet.requestId;
              if (pendingId != null && _pendingRpc.containsKey(pendingId)) {
                _pendingRpc.remove(pendingId)!.complete(packet);
              }
              if (!_packets.isClosed) _packets.add(packet);
            }
            if (!_messages.isClosed) _messages.add(msg);
          },
          onError: (Object e, StackTrace st) {
            if (!streamDone.isCompleted) streamDone.completeError(e, st);
          },
          onDone: () {
            if (!streamDone.isCompleted) streamDone.complete();
          },
          cancelOnError: true,
        );

        _startHeartbeat(channel);
        try {
          await onOpen?.call(this);
        } catch (e) {
          unawaited(
            channel.sink
                .close(1011, 'onOpen_error')
                .timeout(const Duration(seconds: 1), onTimeout: () {}),
          );
          rethrow;
        }

        await streamDone.future;
        _lastCloseCode = channel.closeCode;
        final healthyDuration =
            DateTime.now().difference(openedAt) >= const Duration(seconds: 5);
        if (healthyDuration && hadInbound) {
          failures = 0;
        }
        if (_closed || channel.closeCode == 1000) break;
        failures++;
      } catch (e) {
        if (_closed) break;
        failures++;
        _logCallback?.call('err', _wsRedactor.text('$e'));
      } finally {
        _heartbeatTimer?.cancel();
        _abortStream = null;
        final sub = _inboundSub;
        _inboundSub = null;
        if (sub != null) {
          await sub.cancel().catchError((Object _) {});
        }
        _channel = null;
        platformCloseClient(attemptClient);
        if (identical(_attemptClient, attemptClient)) _attemptClient = null;
      }
      if (maxReconnects case final max? when failures > max) {
        if (!_messages.isClosed) {
          _messages.addError(
            StateError('WebSocket: gave up after $max reconnect attempts'),
          );
        }
        break;
      }
      _set(WebSocketState.reconnecting);
      await _sleep(_delay(max(1, failures)));
    }
    _closed = true;
    _heartbeatTimer?.cancel();
    for (final c in _pendingRpc.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('OmniWebSocket closed before RPC reply'));
      }
    }
    _pendingRpc.clear();
    _set(WebSocketState.closed);
    _buffer.clear();
    if (!_packets.isClosed) await _packets.close();
    if (!_messages.isClosed) await _messages.close();
    if (!_states.isClosed) await _states.close();
  }

  Duration _delay(int attempt) {
    final ms = min(
      minDelay.inMilliseconds * pow(2, attempt - 1).toDouble(),
      maxDelay.inMilliseconds.toDouble(),
    );
    return Duration(
      milliseconds: (ms * (0.8 + _random.nextDouble() * 0.2)).round(),
    );
  }

  Future<void> _sleep(Duration d) {
    final c = _wait = Completer<void>();
    final t = Timer(d, () {
      if (!c.isCompleted) c.complete();
    });
    return c.future.whenComplete(t.cancel);
  }

  static const _wsRedactor = Redactor();

  /// Sends a text or binary message. See the class docs for behaviour while
  /// disconnected.
  void send(Object message) {
    if (message is! String && message is! List<int>) {
      throw ArgumentError.value(
        message,
        'message',
        'must be String or List<int>',
      );
    }
    if (_closed) throw StateError('OmniWebSocket is closed');
    _logCallback?.call(
      'out',
      message is String ? message : '<${(message as List<int>).length} bytes>',
    );
    final ch = _channel;
    if (ch != null && _state == WebSocketState.open) {
      ch.sink.add(message);
      return;
    }
    if (!bufferWhileDisconnected) {
      throw StateError(
        'OmniWebSocket is not connected (state: ${_state.name})',
      );
    }
    if (_buffer.length >= maxBuffered) {
      throw StateError('OmniWebSocket buffer is full ($maxBuffered messages)');
    }
    _buffer.add(message);
  }

  /// Sends [value] encoded as JSON text.
  void sendJson(Object? value) => send(jsonEncode(value));

  /// Closes for good with [code]; buffered messages are dropped.
  Future<void> close([int code = 1000, String? reason]) async {
    if (_closed && _state == WebSocketState.closed) return;
    _closed = true;
    _heartbeatTimer?.cancel();
    final w = _wait;
    if (w != null && !w.isCompleted) w.complete();
    final ch = _channel;
    if (ch != null) {
      await ch.sink
          .close(code, reason)
          .timeout(const Duration(seconds: 1), onTimeout: () {});
    }
    _abortConnection();
    await _states.done.timeout(const Duration(seconds: 5), onTimeout: () {});
  }
}
