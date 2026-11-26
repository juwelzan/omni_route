import 'queued_request.dart';

/// Persistent disk [QueueStore] (IO platforms only).
///
/// Throws [UnsupportedError] on Web.
final class FileQueueStore implements QueueStore {
  /// Creates a stub store on unsupported platforms.
  FileQueueStore({required this.directory});

  /// Directory where queued requests are stored.
  final String directory;

  Never _unsupported() => throw UnsupportedError(
    'FileQueueStore is not supported on this platform ($directory); '
    'use MemoryQueueStore instead',
  );

  @override
  Future<List<QueuedRequest>> all() => _unsupported();

  @override
  Future<void> add(QueuedRequest item) => _unsupported();

  @override
  Future<void> update(QueuedRequest item) => _unsupported();

  @override
  Future<void> remove(String id) => _unsupported();
}
