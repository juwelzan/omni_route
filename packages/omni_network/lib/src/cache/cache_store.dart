import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:meta/meta.dart';

export 'file_cache_store_stub.dart'
    if (dart.library.io) 'file_cache_store_io.dart';

/// One stored response.
@immutable
final class CacheEntry {
  /// Creates an entry.
  const CacheEntry({
    required this.url,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.storedAt,
    required this.expiresAt,
    this.vary = const {},
  });

  /// Request URL (without auth scope or vary data).
  final String url;

  /// Status code (200).
  final int statusCode;

  /// Response headers (lower-case names).
  final Map<String, String> headers;

  /// Body bytes.
  final Uint8List body;

  /// When it was stored or last revalidated.
  final DateTime storedAt;

  /// Until when it is fresh; at or before [storedAt] means "revalidate".
  final DateTime expiresAt;

  /// Request header values named by the response's `Vary` header.
  final Map<String, String> vary;

  /// `ETag` validator, if any.
  String? get etag => headers['etag'];

  /// `Last-Modified` validator, if any.
  String? get lastModified => headers['last-modified'];

  /// Whether it can be revalidated with a conditional request.
  bool get hasValidators => etag != null || lastModified != null;

  /// Whether it is fresh at [now].
  bool isFresh(DateTime now) => now.isBefore(expiresAt);

  /// Approximate memory size in bytes.
  int get size =>
      body.length +
      headers.entries.fold(0, (n, e) => n + e.key.length + e.value.length);
}

/// Storage for cached responses. Implement for disk/database persistence;
/// keys may be long and must be treated as opaque.
abstract interface class CacheStore {
  /// Returns the entry for [key], or `null`.
  FutureOr<CacheEntry?> get(String key);

  /// Stores [entry] under [key].
  FutureOr<void> set(String key, CacheEntry entry);

  /// Removes [key].
  FutureOr<void> remove(String key);

  /// Removes every entry whose [CacheEntry.url] equals [url].
  FutureOr<void> removeUrl(String url);

  /// Removes everything (e.g. on logout).
  FutureOr<void> clear();
}

/// In-memory LRU [CacheStore] bounded by entry count and total bytes.
final class MemoryCacheStore implements CacheStore {
  /// Creates a store.
  MemoryCacheStore({this.maxEntries = 200, this.maxBytes = 20 * 1024 * 1024});

  /// Maximum number of entries.
  final int maxEntries;

  /// Maximum total size in bytes.
  final int maxBytes;

  final LinkedHashMap<String, CacheEntry> _map = LinkedHashMap();
  int _bytes = 0;

  /// Current entry count.
  int get length => _map.length;

  /// Current total size in bytes.
  int get bytes => _bytes;

  @override
  CacheEntry? get(String key) {
    final e = _map.remove(key);
    if (e != null) _map[key] = e; // mark most recently used
    return e;
  }

  @override
  void set(String key, CacheEntry entry) {
    remove(key);
    if (entry.size > maxBytes) return;
    _map[key] = entry;
    _bytes += entry.size;
    while (_map.length > maxEntries || _bytes > maxBytes) {
      remove(_map.keys.first);
    }
  }

  @override
  void remove(String key) {
    final e = _map.remove(key);
    if (e != null) _bytes -= e.size;
  }

  @override
  void removeUrl(String url) {
    for (final k in [
      for (final e in _map.entries)
        if (e.value.url == url) e.key,
    ]) {
      remove(k);
    }
  }

  @override
  void clear() {
    _map.clear();
    _bytes = 0;
  }
}
