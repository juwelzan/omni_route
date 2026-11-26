import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';

import '../cache/omni_cache.dart' show CachePolicy;
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_request.dart';
import '../resilience/retry_policy.dart';
import '../transfer/stream_target.dart';

/// One Server-Sent Event.
@immutable
final class SseEvent {
  /// Creates an event.
  const SseEvent({this.event = 'message', required this.data, this.id});

  /// Event type (`event:` field), default `message`.
  final String event;

  /// Data (`data:` lines joined with `\n`).
  final String data;

  /// Last event id in effect when this event was dispatched.
  final String? id;

  /// [data] parsed as JSON.
  Object? get json => jsonDecode(data);

  @override
  String toString() =>
      'SseEvent($event, $data${id == null ? '' : ', id: $id'})';
}

/// Parses a single-shot byte stream (e.g. an AI POST SSE response) into typed
/// [SseEvent] items using [SseParser].
Stream<SseEvent> parseSseByteStream(
  Stream<List<int>> byteStream, {
  int maxEventBytes = 1024 * 1024,
}) async* {
  final controller = StreamController<SseEvent>(sync: true);
  final parser = SseParser(maxEventBytes: maxEventBytes);
  final parserSub = parser.events.listen(
    controller.add,
    onError: controller.addError,
  );
  final byteSub = utf8.decoder
      .bind(byteStream)
      .listen(
        parser.add,
        onError: controller.addError,
        onDone: () async {
          await parser.close();
          await parserSub.cancel();
          if (!controller.isClosed) await controller.close();
        },
        cancelOnError: false,
      );
  controller.onCancel = () async {
    await byteSub.cancel();
    await parserSub.cancel();
    await parser.close();
  };
  yield* controller.stream;
}

/// Incremental `text/event-stream` parser (WHATWG HTML §9.2.6).
///
/// Feed decoded text with [add]; events come out of [events]. `retry:`
/// values are reported through [onRetry]; the last id is kept in [lastId].
final class SseParser {
  /// Creates a parser.
  SseParser({this.onRetry, this.maxEventBytes = 1024 * 1024});

  /// Called with a valid `retry:` value.
  final void Function(Duration retry)? onRetry;

  /// Upper bound for one event's data (and one unterminated line). A server
  /// that exceeds it gets a `FormatException` on [events] instead of
  /// unbounded memory use; the oversized event is dropped.
  final int maxEventBytes;
  var _oversized = false;

  final _out = StreamController<SseEvent>(sync: true);
  final _data = StringBuffer();
  var _hasData = false;
  var _event = '';
  var _pending = '';
  var _skipLf = false;
  var _first = true;

  /// Last `id:` seen (survives across events, like the browser).
  String? lastId;

  /// Parsed events.
  Stream<SseEvent> get events => _out.stream;

  /// Feeds decoded text.
  void add(String chunk) {
    var text = chunk;
    if (_first && text.isNotEmpty) {
      _first = false;
      if (text.startsWith('\uFEFF')) text = text.substring(1);
    }
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (_skipLf) {
        _skipLf = false;
        if (c == 0x0A) {
          start = i + 1;
          continue;
        }
      }
      if (c == 0x0A || c == 0x0D) {
        _line(_pending + text.substring(start, i));
        _pending = '';
        start = i + 1;
        if (c == 0x0D) _skipLf = true;
      }
    }
    _pending += text.substring(start);
    if (_pending.length > maxEventBytes) {
      _pending = '';
      _overflow();
    }
  }

  void _overflow() {
    _data.clear();
    _hasData = false;
    if (!_oversized) {
      _oversized = true;
      _out.addError(
        FormatException(
          'SSE event larger than $maxEventBytes characters; dropped',
        ),
      );
    }
  }

  void _line(String line) {
    if (line.isEmpty) {
      _dispatch();
      return;
    }
    if (line.startsWith(':')) return;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        if (_oversized) return;
        if (_hasData) _data.write('\n');
        _data.write(value);
        _hasData = true;
        if (_data.length > maxEventBytes) _overflow();
      case 'id':
        if (!value.contains('\u0000')) lastId = value;
      case 'retry':
        if (RegExp(r'^\d+$').hasMatch(value)) {
          onRetry?.call(Duration(milliseconds: int.parse(value)));
        }
    }
  }

  void _dispatch() {
    if (_oversized) {
      _oversized = false;
      _event = '';
      return;
    }
    if (!_hasData) {
      _event = '';
      return;
    }
    _out.add(
      SseEvent(
        event: _event.isEmpty ? 'message' : _event,
        data: '$_data',
        id: lastId,
      ),
    );
    _data.clear();
    _hasData = false;
    _event = '';
  }

  /// Ends the input; an incomplete trailing event is discarded (per spec).
  Future<void> close() => _out.close();
}

/// Connection state of an [SseConnection].
enum SseState {
  /// Connecting (first time or after a drop).
  connecting,

  /// Receiving events.
  open,

  /// Waiting before reconnecting.
  waiting,

  /// Stopped: closed by you, by the server (`204`), or by a fatal error.
  closed,
}

/// A reconnecting Server-Sent Events subscription through an
/// [OmniNetwork] client (so auth, interceptors and logging apply).
///
/// Supports both standard `GET` subscriptions and `POST` SSE endpoints (such as
/// streaming AI completions).
final class SseConnection {
  /// Opens the subscription immediately.
  SseConnection(
    this.client,
    this.path, {
    this.method = HttpMethod.get,
    this.body,
    this.query = const {},
    this.headers = const {},
    this.lastEventId,
    this.retry = const Duration(seconds: 3),
    this.maxRetry = const Duration(seconds: 60),
    this.maxReconnects,
    this.auth = true,
    Random? random,
  }) : _random = random ?? Random() {
    _events = StreamController.broadcast(onCancel: () {});
    unawaited(_loop());
  }

  /// Client used for every (re)connection.
  final OmniNetwork client;

  /// Event-stream path or URL.
  final String path;

  /// HTTP verb (`HttpMethod.get` default, or `HttpMethod.post` with [body]).
  final HttpMethod method;

  /// Optional request body for POST SSE streams.
  final Object? body;

  /// Query parameters.
  final Map<String, Object?> query;

  /// Extra headers.
  final Map<String, String> headers;

  /// Whether client auth should be applied to this connection.
  final bool auth;

  /// Default reconnect delay (until the server sends `retry:`).
  Duration retry;

  /// Upper bound for the backoff delay.
  final Duration maxRetry;

  /// Consecutive failed reconnects allowed before stopping.
  final int? maxReconnects;

  /// The id sent as `Last-Event-ID` on the next connection.
  String? lastEventId;

  final Random _random;
  late final StreamController<SseEvent> _events;
  final _states = StreamController<SseState>.broadcast(sync: true);
  SseState _state = SseState.connecting;
  OmniStreamResponse? _current;
  Completer<void>? _wait;
  bool _closed = false;

  /// Events (broadcast). Errors are delivered as stream errors.
  Stream<SseEvent> get events => _events.stream;

  /// State changes (broadcast).
  Stream<SseState> get states => _states.stream;

  /// Current state.
  SseState get state => _state;

  void _set(SseState s) {
    if (_state == s) return;
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  Future<void> _loop() async {
    var failures = 0;
    while (!_closed) {
      _set(SseState.connecting);
      try {
        final res = await client.openStream(
          OmniRequest(
            method,
            path,
            body: body,
            query: query,
            headers: {
              'accept': 'text/event-stream',
              'cache-control': 'no-cache',
              ...headers,
              'last-event-id': ?lastEventId,
            },
            retry: RetryPolicy.none,
            cachePolicy: CachePolicy.noCache,
            skipAuth: !auth,
          ),
        );
        if (_closed) {
          res.cancel();
          break;
        }
        if (res.statusCode == 204) break;
        _current = res;
        _set(SseState.open);
        failures = 0;
        final parser = SseParser(onRetry: (d) => retry = d);
        final sub = parser.events.listen((e) {
          lastEventId = parser.lastId;
          if (!_events.isClosed) _events.add(e);
        }, onError: _addError);
        try {
          await for (final text in utf8.decoder.bind(res.body)) {
            parser.add(text);
          }
        } finally {
          await parser.close();
          await sub.cancel();
          lastEventId = parser.lastId ?? lastEventId;
          _current = null;
        }
      } on HttpFailure catch (e) {
        final s = e.statusCode;
        if (s == 204) break;
        if (s < 500 && s != 408 && s != 429) {
          _addError(e);
          break;
        }
        failures++;
      } on OmniNetworkException catch (e) {
        if (_closed || e is ClosedFailure || e is CancelledFailure) break;
        if (e is AuthFailure || e is RequestFailure) {
          _addError(e);
          break;
        }
        failures++;
      }
      if (_closed) break;
      if (maxReconnects case final max? when failures > max) {
        _addError(StateError('SSE: gave up after $max reconnect attempts'));
        break;
      }
      _set(SseState.waiting);
      await _sleep(_delay(failures));
    }
    _set(SseState.closed);
    if (!_events.isClosed) await _events.close();
    if (!_states.isClosed) await _states.close();
  }

  void _addError(Object e) {
    if (!_events.isClosed) _events.addError(e);
  }

  Duration _delay(int failures) {
    final factor = pow(2, max(0, failures - 1)).toDouble();
    final ms = min(
      retry.inMilliseconds * factor,
      maxRetry.inMilliseconds.toDouble(),
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

  /// Stops the subscription; [events] and [states] complete.
  Future<void> close() async {
    if (_closed && _state == SseState.closed) return;
    _closed = true;
    final w = _wait;
    if (w != null && !w.isCompleted) w.complete();
    _current?.cancel();
    await _states.done.timeout(const Duration(seconds: 5), onTimeout: () {});
  }
}
