import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'cache_store.dart';

/// Persistent file-backed [CacheStore] bounded by entry count and total bytes.
///
/// Keys are hashed with SHA-256 so long URLs and query strings never exceed
/// filesystem filename limits. Corrupted cache files are automatically removed.
final class FileCacheStore implements CacheStore {
  /// Creates a disk cache rooted at [directory].
  FileCacheStore({
    required this.directory,
    this.maxEntries = 200,
    this.maxBytes = 50 * 1024 * 1024,
  }) : assert(maxEntries >= 1 && maxBytes >= 1);

  /// Directory where cached response files are stored.
  final String directory;

  /// Maximum number of entries retained on disk.
  final int maxEntries;

  /// Maximum approximate total size retained on disk.
  final int maxBytes;

  Directory get _dir => Directory(directory);

  String _filePath(String key) {
    final hash = sha256.convert(utf8.encode(key)).toString();
    return '${_dir.path}${Platform.pathSeparator}$hash.json';
  }

  @override
  Future<CacheEntry?> get(String key) async {
    final file = File(_filePath(key));
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        await file.delete().catchError((_) => file);
        return null;
      }
      final entry = CacheEntry(
        url: decoded['url']! as String,
        statusCode: decoded['statusCode']! as int,
        headers: Map<String, String>.from(decoded['headers']! as Map),
        body: base64Decode(decoded['body']! as String),
        storedAt: DateTime.parse(decoded['storedAt']! as String),
        expiresAt: DateTime.parse(decoded['expiresAt']! as String),
        vary: decoded['vary'] is Map
            ? Map<String, String>.from(decoded['vary']! as Map)
            : const {},
      );
      // Touch modification timestamp for approximate LRU ordering.
      await file.setLastModified(DateTime.now()).catchError((_) => file);
      return entry;
    } catch (_) {
      await file.delete().catchError((_) => file);
      return null;
    }
  }

  @override
  Future<void> set(String key, CacheEntry entry) async {
    if (entry.size > maxBytes) return;
    await _dir.create(recursive: true);
    final payload = jsonEncode({
      'url': entry.url,
      'statusCode': entry.statusCode,
      'headers': entry.headers,
      'body': base64Encode(entry.body),
      'storedAt': entry.storedAt.toUtc().toIso8601String(),
      'expiresAt': entry.expiresAt.toUtc().toIso8601String(),
      if (entry.vary.isNotEmpty) 'vary': entry.vary,
    });
    final target = File(_filePath(key));
    final temp = File('${target.path}.tmp.${pid}_${identityHashCode(entry)}');
    await temp.writeAsString(payload, flush: true);
    if (await target.exists()) {
      await target.delete().catchError((_) => target);
    }
    await temp.rename(target.path);
    await _enforceLimits();
  }

  @override
  Future<void> remove(String key) async {
    final file = File(_filePath(key));
    if (await file.exists()) {
      await file.delete().catchError((_) => file);
    }
  }

  @override
  Future<void> removeUrl(String url) async {
    if (!await _dir.exists()) return;
    await for (final entity in _dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final map = jsonDecode(await entity.readAsString());
        if (map is Map && map['url'] == url) {
          await entity.delete().catchError((_) => entity);
        }
      } catch (_) {
        await entity.delete().catchError((_) => entity);
      }
    }
  }

  @override
  Future<void> clear() async {
    if (!await _dir.exists()) return;
    await for (final entity in _dir.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.json')) {
        await entity.delete().catchError((_) => entity);
      }
    }
  }

  Future<void> _enforceLimits() async {
    final items = <({File file, DateTime modified, int size})>[];
    var total = 0;
    await for (final entity in _dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final stat = await entity.stat();
      items.add((file: entity, modified: stat.modified, size: stat.size));
      total += stat.size;
    }
    if (items.length <= maxEntries && total <= maxBytes) return;
    items.sort((a, b) => a.modified.compareTo(b.modified));
    var count = items.length;
    for (final item in items) {
      if (count <= maxEntries && total <= maxBytes) break;
      await item.file.delete().catchError((_) => item.file);
      count--;
      total -= item.size;
    }
  }
}
