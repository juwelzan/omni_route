import 'cache_store.dart';

/// Persistent disk [CacheStore] (IO platforms only).
///
/// Throws [UnsupportedError] on Web.
final class FileCacheStore implements CacheStore {
  /// Creates a stub store on unsupported platforms.
  FileCacheStore({
    required this.directory,
    this.maxEntries = 200,
    this.maxBytes = 50 * 1024 * 1024,
  });

  /// Directory path configured for persistent cache storage.
  final String directory;

  /// Maximum number of cached entries kept on disk.
  final int maxEntries;

  /// Maximum total size in bytes kept on disk.
  final int maxBytes;

  Never _unsupported() => throw UnsupportedError(
    'FileCacheStore is not supported on this platform ($directory); '
    'use MemoryCacheStore instead',
  );

  @override
  Future<CacheEntry?> get(String key) => _unsupported();

  @override
  Future<void> set(String key, CacheEntry entry) => _unsupported();

  @override
  Future<void> remove(String key) => _unsupported();

  @override
  Future<void> removeUrl(String url) => _unsupported();

  @override
  Future<void> clear() => _unsupported();
}
