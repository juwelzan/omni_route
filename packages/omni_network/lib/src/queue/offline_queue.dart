import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_request.dart';
import '../core/omni_response.dart';
import '../resilience/retry_policy.dart';
import '../transfer/multipart.dart';
import 'queued_request.dart';

/// What happened to a queued request.
enum QueueEventKind {
  /// Added to the queue.
  enqueued,

  /// Replayed successfully (2xx/3xx) and removed.
  sent,

  /// The server rejected it (4xx other than 408/429); removed.
  rejected,

  /// Replay failed temporarily; kept for the next flush.
  deferred,

  /// Gave up after `maxAttempts`; removed.
  deadLettered,
}

/// An [OfflineQueue] notification.
final class QueueEvent {
  /// Creates an event.
  const QueueEvent(this.kind, this.item, {this.response, this.error});

  /// What happened.
  final QueueEventKind kind;

  /// The request concerned.
  final QueuedRequest item;

  /// Server response, when one was received.
  final OmniRawResponse? response;

  /// Failure, when no response was received.
  final OmniNetworkException? error;

  @override
  String toString() => 'QueueEvent(${kind.name}, ${item.id})';
}

/// Outcome of [OfflineQueue.sendOrQueue].
sealed class QueueResult {
  const QueueResult();
}

/// The request reached the server (any status).
final class SentNow extends QueueResult {
  /// Wraps [response].
  const SentNow(this.response);

  /// The server's response.
  final OmniRawResponse response;
}

/// The server was unreachable; the request was queued.
final class Queued extends QueueResult {
  /// Wraps [item].
  const Queued(this.item);

  /// The queued request.
  final QueuedRequest item;
}

/// Holds write requests made while offline and replays them later.
///
/// Nothing is ever queued implicitly: only [enqueue] and [sendOrQueue]
/// add items, and only for the requests you pass.
///
/// Safety rules:
/// * `GET`/`HEAD` are not queued (use `CachePolicy.networkFirst`).
/// * Every queued request carries an `Idempotency-Key` (generated if
///   missing), so a replay of a request that did reach the server can be
///   de-duplicated server side.
/// * `PUT`, `PATCH` and `DELETE` change or remove existing data and need
///   `allowDestructive: true`.
/// * Multipart/streamed bodies cannot be queued.
/// * Credential headers are never stored: `Authorization`, `Cookie`,
///   `X-API-Key`, CSRF and session headers, any header whose name holds
///   `token`, `secret`, `session`, `apikey`, `password` or `signature`, and
///   your own [sensitiveHeaders] (all case-insensitive; `Idempotency-Key`
///   is kept). They are also removed from items before a replay, so the
///   client's `auth`, default headers and interceptors supply current
///   values. Put credentials there, not on the individual request, or a
///   replay is sent without them.
///
/// [flush] replays oldest first, one at a time, and stops at the first
/// temporary failure so order is preserved. Connectivity detection is not
/// part of the core: call [flush] yourself or [attach] a `Stream<bool>`
/// (e.g. from a Flutter connectivity plugin).
final class OfflineQueue {
  /// Creates a queue that replays through [client].
  OfflineQueue({
    required this.client,
    QueueStore? store,
    this.maxAttempts = 5,
    this.sensitiveHeaders = const {},
  }) : store = store ?? MemoryQueueStore();

  /// Client used for replays.
  final OmniNetwork client;

  /// Persistence.
  final QueueStore store;

  /// Temporary failures tolerated per item before it is dead-lettered.
  final int maxAttempts;

  /// Extra header names (case-insensitive) never stored, in addition to
  /// the built-in credential headers (see the class notes).
  final Set<String> sensitiveHeaders;

  final StreamController<QueueEvent> _events = StreamController.broadcast();
  Future<void>? _flushing;
  StreamSubscription<bool>? _online;
  bool _closed = false;

  /// Queue notifications.
  Stream<QueueEvent> get events => _events.stream;

  /// Items waiting, oldest first.
  Future<List<QueuedRequest>> get pending async => store.all();

  void _emit(QueueEvent e) {
    if (!_closed) _events.add(e);
  }

  static const _destructive = {
    HttpMethod.put,
    HttpMethod.patch,
    HttpMethod.delete,
  };

  /// Adds [request] to the queue (see class rules). Returns the stored
  /// item; when [id] already exists, the existing item is returned and
  /// nothing is added.
  ///
  /// Throws [ArgumentError] for requests that may not be queued.
  Future<QueuedRequest> enqueue(
    OmniRequest request, {
    bool allowDestructive = false,
    String? id,
    String? tag,
  }) async {
    _checkOpen();
    final item = _toItem(request, allowDestructive, id, tag);
    final existing = (await store.all()).where((e) => e.id == item.id);
    if (existing.isNotEmpty) return existing.first;
    await store.add(item);
    _emit(QueueEvent(QueueEventKind.enqueued, item));
    return item;
  }

  QueuedRequest _toItem(
    OmniRequest r,
    bool allowDestructive,
    String? id,
    String? tag,
  ) {
    if (r.method == HttpMethod.get || r.method == HttpMethod.head) {
      throw ArgumentError.value(
        r.method.verb,
        'request',
        'reads are not queued',
      );
    }
    if (_destructive.contains(r.method) && !allowDestructive) {
      throw ArgumentError.value(
        r.method.verb,
        'request',
        'destructive request; pass allowDestructive: true to queue it',
      );
    }
    final body = r.body;
    if (body is MultipartBody) {
      throw ArgumentError.value(
        body,
        'request',
        'multipart bodies cannot be queued',
      );
    }
    // The client sends any List<int> as raw bytes; keep that on replay.
    final Object? stored = body is List<int> && body is! Uint8List
        ? Uint8List.fromList(body)
        : body;
    if (stored != null && stored is! String && stored is! Uint8List) {
      try {
        jsonEncode(stored);
      } on JsonUnsupportedObjectError {
        throw ArgumentError.value(
          body,
          'request',
          'body is not JSON-encodable',
        );
      }
    }
    final headers = persistableHeaders(r.headers, sensitiveHeaders);
    if (r.header('idempotency-key') == null) {
      headers['Idempotency-Key'] = QueuedRequest.randomId();
    }
    return QueuedRequest(
      id: id ?? QueuedRequest.randomId(),
      method: r.method,
      path: r.path,
      query: r.query,
      headers: headers,
      body: stored,
      createdAt: DateTime.now(),
      tag: tag,
    );
  }

  /// Sends [request] now; when the server is unreachable (connection error
  /// or timeout) queues it instead. Any response from the server — even an
  /// error status — is returned as [SentNow], never queued.
  ///
  /// The queue rules are checked **before** sending, so a request that may
  /// not be queued fails fast with [ArgumentError].
  Future<QueueResult> sendOrQueue(
    OmniRequest request, {
    bool allowDestructive = false,
    String? id,
    String? tag,
  }) async {
    _checkOpen();
    final item = _toItem(request, allowDestructive, id, tag);
    try {
      // Send with the same Idempotency-Key the queued copy would carry.
      final key = item.idempotencyKey!;
      return SentNow(
        await client.sendRaw(
          request
              .withHeader('Idempotency-Key', key)
              .copyWith(retry: RetryPolicy.none),
        ),
      );
    } on OmniNetworkException catch (e) {
      if (e is! ConnectionFailure && e is! TimeoutFailure) rethrow;
      final existing = (await store.all()).where((x) => x.id == item.id);
      if (existing.isNotEmpty) return Queued(existing.first);
      await store.add(item);
      _emit(QueueEvent(QueueEventKind.enqueued, item, error: e));
      return Queued(item);
    }
  }

  /// Replays queued requests in order. Concurrent calls share one flush.
  Future<void> flush() {
    _checkOpen();
    return _flushing ??= _flush().whenComplete(() => _flushing = null);
  }

  Future<void> _flush() async {
    for (final item in await store.all()) {
      if (_closed) return;
      try {
        // Items from a store written by an older version (or by hand) may
        // still hold credentials; never let a stale one override the
        // client's current value.
        final res = await client.sendRaw(
          item.toRequest().copyWith(
            headers: persistableHeaders(item.headers, sensitiveHeaders),
            retry: RetryPolicy.none,
          ),
        );
        final s = res.statusCode;
        if (s < 400) {
          await store.remove(item.id);
          _emit(QueueEvent(QueueEventKind.sent, item, response: res));
        } else if (s >= 500 || s == 408 || s == 429) {
          if (!await _defer(item, response: res)) return;
        } else {
          await store.remove(item.id);
          _emit(QueueEvent(QueueEventKind.rejected, item, response: res));
        }
      } on OmniNetworkException catch (e) {
        if (e is ClosedFailure || e is CancelledFailure) return;
        if (e is ConnectionFailure || e is TimeoutFailure) {
          if (!await _defer(item, error: e)) return;
          continue;
        }
        // Auth or request-building failures: keep the item, stop flushing.
        _emit(QueueEvent(QueueEventKind.deferred, item, error: e));
        return;
      }
    }
  }

  /// Records a temporary failure. Returns whether flushing may continue
  /// (only after the item was dead-lettered and removed).
  Future<bool> _defer(
    QueuedRequest item, {
    OmniRawResponse? response,
    OmniNetworkException? error,
  }) async {
    final updated = item.withAttempts(item.attempts + 1);
    if (updated.attempts >= maxAttempts) {
      await store.remove(item.id);
      _emit(
        QueueEvent(
          QueueEventKind.deadLettered,
          updated,
          response: response,
          error: error,
        ),
      );
      return true;
    }
    await store.update(updated);
    _emit(
      QueueEvent(
        QueueEventKind.deferred,
        updated,
        response: response,
        error: error,
      ),
    );
    return false;
  }

  /// Removes [id] without sending it (e.g. the user discarded the change).
  Future<void> discard(String id) async => store.remove(id);

  /// Flushes whenever [online] emits `true`. Replaces a previous stream.
  void attach(Stream<bool> online) {
    _checkOpen();
    _online?.cancel();
    _online = online.listen((up) {
      if (up && !_closed) flush().ignore();
    });
  }

  void _checkOpen() {
    if (_closed) throw StateError('OfflineQueue is closed');
  }

  /// Stops listening and closes [events]; stored items are kept.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _online?.cancel();
    await _events.close();
  }
}
