import 'dart:async';
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

  int _tmpSeq = 0;
  Future<void> _lock = Future<void>.value();

  Future<T> _synchronized<T>(Future<T> Function() op) {
    final prev = _lock;
    final run = prev.catchError((Object _) {}).then((_) => op());
    _lock = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  File get _file => File('$directory${Platform.pathSeparator}queue.json');

  Future<void> _writeAll(List<QueuedRequest> items) async {
    await Directory(directory).create(recursive: true);
    final payload = jsonEncode([for (final item in items) item.toJson()]);
    final temp = File('${_file.path}.tmp.${pid}_${++_tmpSeq}');
    try {
      await temp.writeAsString(payload, flush: true);
      await temp.rename(_file.path);
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete().catchError((Object _) => temp);
      }
      rethrow;
    }
  }

  Future<List<QueuedRequest>> _readAll() async {
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
  Future<List<QueuedRequest>> all() => _synchronized(_readAll);

  @override
  Future<void> add(QueuedRequest item) => _synchronized(() async {
    final items = [...await _readAll()];
    if (items.any((e) => e.id == item.id)) return;
    items.add(item);
    await _writeAll(items);
  });

  @override
  Future<void> update(QueuedRequest item) => _synchronized(() async {
    final items = [...await _readAll()];
    final i = items.indexWhere((e) => e.id == item.id);
    if (i < 0) return;
    items[i] = item;
    await _writeAll(items);
  });

  @override
  Future<void> remove(String id) => _synchronized(() async {
    final items = [...await _readAll()];
    final before = items.length;
    items.removeWhere((e) => e.id == id);
    if (items.length != before) {
      await _writeAll(items);
    }
  });
}
