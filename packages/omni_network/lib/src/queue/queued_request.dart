import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

export 'file_queue_store_stub.dart'
    if (dart.library.io) 'file_queue_store_io.dart';

import '../core/omni_request.dart';

/// Headers never written to a queue store (credentials are re-added by the
/// client's auth when the request is replayed).
const Set<String> unpersistedHeaders = {
  'authorization',
  'proxy-authorization',
  'cookie',
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

  /// Headers, without credentials (see [unpersistedHeaders]); includes the
  /// `Idempotency-Key`.
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
    'headers': headers,
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
      headers: Map<String, String>.from(json['headers']! as Map),
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
/// for durability (store `QueuedRequest.toJson()`); credentials are never
/// part of a [QueuedRequest].
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
