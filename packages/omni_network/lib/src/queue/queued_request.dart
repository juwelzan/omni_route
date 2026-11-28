import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

export 'file_queue_store_stub.dart'
    if (dart.library.io) 'file_queue_store_io.dart';

import '../core/omni_request.dart';
import '../log/redactor.dart';

/// Credential headers never written to a queue store, in lower case.
///
/// [isUnpersistedHeader] also drops any header the log [Redactor] treats as
/// secret (names containing `token`, `secret`, `session`, `apikey`,
/// `password`, `signature`, …). Credentials belong on the client (its
/// `auth`, default headers or an interceptor): those are applied again when
/// a request is replayed, so a replay always carries current values.
const Set<String> unpersistedHeaders = {
  'authorization',
  'proxy-authorization',
  'cookie',
  'x-api-key',
  'api-key',
  'x-auth-token',
  'x-access-token',
  'x-refresh-token',
  'x-session-token',
  'x-csrf-token',
  'x-xsrf-token',
  'x-amz-security-token',
};

const _redactor = Redactor();

/// Whether header [name] must not be persisted by an `OfflineQueue`:
/// one of [unpersistedHeaders], a header the log [Redactor] treats as
/// secret, or one of [extra] (all case-insensitive). The
/// `Idempotency-Key` is always kept.
bool isUnpersistedHeader(String name, [Set<String> extra = const {}]) {
  final lower = name.toLowerCase();
  if (lower == 'idempotency-key') return false;
  return unpersistedHeaders.contains(lower) ||
      _redactor.isSecretHeader(lower) ||
      extra.any((h) => h.toLowerCase() == lower);
}

/// Copy of [headers] without the ones [isUnpersistedHeader] rejects.
Map<String, String> persistableHeaders(
  Map<String, String> headers, [
  Set<String> extra = const {},
]) => {
  for (final e in headers.entries)
    if (!isUnpersistedHeader(e.key, extra)) e.key: e.value,
};

/// A request waiting in an `OfflineQueue`. Serialisable with [toJson].
@immutable
final class QueuedRequest {
  /// Creates a queued request.
  const QueuedRequest({
    required this.id,
    required this.method,
    required this.path,
    required this.createdAt,
    this.query = const {},
    this.headers = const {},
    this.body,
    this.attempts = 0,
    this.tag,
  });

  /// Unique id; enqueuing an existing id is ignored (dedupe).
  final String id;

  /// HTTP method.
  final HttpMethod method;

  /// Path or absolute URL.
  final String path;

  /// Query parameters (strings or lists of strings).
  final Map<String, Object?> query;

  /// Headers, without credentials (see `OfflineQueue`); includes the
  /// `Idempotency-Key`. [toJson] and [fromJson] drop credentials again, so
  /// an item built by hand or written by an older version never stores or
  /// restores them.
  final Map<String, String> headers;

  /// Body: a JSON value, a `String`, a `Uint8List`, or `null`.
  final Object? body;

  /// When it was queued.
  final DateTime createdAt;

  /// Failed replay attempts so far.
  final int attempts;

  /// Optional app label (e.g. `note:42`) for grouping in UI.
  final String? tag;

  /// The `Idempotency-Key` header value.
  String? get idempotencyKey {
    for (final e in headers.entries) {
      if (e.key.toLowerCase() == 'idempotency-key') return e.value;
    }
    return null;
  }

  /// The request to send on replay.
  OmniRequest toRequest() =>
      OmniRequest(method, path, query: query, headers: headers, body: body);

  /// Copy with [attempts] replaced.
  QueuedRequest withAttempts(int attempts) => QueuedRequest(
    id: id,
    method: method,
    path: path,
    createdAt: createdAt,
    query: query,
    headers: headers,
    body: body,
    attempts: attempts,
    tag: tag,
  );

  /// JSON-compatible map for persistence.
  Map<String, Object?> toJson() => {
    'id': id,
    'method': method.name,
    'path': path,
    'query': query,
    'headers': persistableHeaders(headers),
    'body': switch (body) {
      null => null,
      Uint8List() => {'bytes': base64Encode(body! as Uint8List)},
      String() => {'text': body},
      _ => {'json': body},
    },
    'createdAt': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
    'tag': tag,
  };

  /// Restores a request written by [toJson].
  factory QueuedRequest.fromJson(Map<String, Object?> json) {
    final b = json['body'] as Map<String, Object?>?;
    return QueuedRequest(
      id: json['id']! as String,
      method: HttpMethod.values.byName(json['method']! as String),
      path: json['path']! as String,
      query: Map<String, Object?>.from(json['query']! as Map),
      headers: persistableHeaders(
        Map<String, String>.from(json['headers']! as Map),
      ),
      body: b == null
          ? null
          : b.containsKey('bytes')
          ? base64Decode(b['bytes']! as String)
          : b.containsKey('text')
          ? b['text']
          : b['json'],
      createdAt: DateTime.parse(json['createdAt']! as String),
      attempts: json['attempts']! as int,
      tag: json['tag'] as String?,
    );
  }

  static final _rand = Random.secure();

  /// A random 128-bit hex id.
  static String randomId() => List.generate(
    16,
    (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Persistence for an `OfflineQueue`, in FIFO order. Implement on disk
/// for durability (store `QueuedRequest.toJson()`, which never contains
/// credential headers).
abstract interface class QueueStore {
  /// All items, oldest first.
  FutureOr<List<QueuedRequest>> all();

  /// Appends [item].
  FutureOr<void> add(QueuedRequest item);

  /// Replaces the item with the same id.
  FutureOr<void> update(QueuedRequest item);

  /// Removes the item with [id].
  FutureOr<void> remove(String id);
}

/// In-memory [QueueStore] (lost on restart).
final class MemoryQueueStore implements QueueStore {
  final List<QueuedRequest> _items = [];

  @override
  List<QueuedRequest> all() => List.unmodifiable(_items);

  @override
  void add(QueuedRequest item) => _items.add(item);

  @override
  void update(QueuedRequest item) {
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i >= 0) _items[i] = item;
  }

  @override
  void remove(String id) => _items.removeWhere((e) => e.id == id);
}
