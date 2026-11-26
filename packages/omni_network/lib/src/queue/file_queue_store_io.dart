import 'dart:convert';
import 'dart:io';

import 'queued_request.dart';

/// Persistent FIFO file-backed [QueueStore] for [OfflineQueue].
///
/// Stores pending requests atomically in a JSON file inside [directory] so
/// unsent offline writes survive app restarts. Credentials remain excluded
/// via [QueuedRequest.toJson].
final class FileQueueStore implements QueueStore {
  /// Creates a disk-backed queue store rooted at [directory].
  FileQueueStore({required this.directory});

  /// Directory holding the serialized queue file (`queue.json`).
  final String directory;

  File get _file => File('$directory${Platform.pathSeparator}queue.json');

  Future<void> _writeAll(List<QueuedRequest> items) async {
    await Directory(directory).create(recursive: true);
    final payload = jsonEncode([for (final item in items) item.toJson()]);
    final temp = File('${_file.path}.tmp.${pid}_${identityHashCode(items)}');
    await temp.writeAsString(payload, flush: true);
    await temp.rename(_file.path);
  }

  @override
  Future<List<QueuedRequest>> all() async {
    if (!await _file.exists()) return const [];
    try {
      final raw = await _file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return List.unmodifiable([
        for (final e in decoded)
          if (e is Map) QueuedRequest.fromJson(Map<String, Object?>.from(e)),
      ]);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> add(QueuedRequest item) async {
    final items = [...await all()];
    if (items.any((e) => e.id == item.id)) return;
    items.add(item);
    await _writeAll(items);
  }

  @override
  Future<void> update(QueuedRequest item) async {
    final items = [...await all()];
    final i = items.indexWhere((e) => e.id == item.id);
    if (i < 0) return;
    items[i] = item;
    await _writeAll(items);
  }

  @override
  Future<void> remove(String id) async {
    final items = [...await all()];
    final before = items.length;
    items.removeWhere((e) => e.id == id);
    if (items.length != before) {
      await _writeAll(items);
    }
  }
}
