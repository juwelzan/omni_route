import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'cache_store.dart';

/// File extension of one cached entry.
const String _ext = '.omc';

/// Format tag written at the start of every entry file.
const int _magic = 0x4F4D4331; // "OMC1"

/// Header bytes: 4 magic + 4 metadata length.
const int _headerBytes = 8;

/// Persistent file-backed [CacheStore] bounded by entry count and total bytes.
///
/// Keys are hashed with SHA-256 so long URLs and query strings never exceed
/// filesystem filename limits. Corrupted cache files are automatically removed.
///
/// Each entry is one binary file: a small JSON metadata header followed by the
/// raw body bytes (no base64, no whole-file JSON parse). The directory is
/// scanned once, lazily, into an in-memory index, so [get] misses, [set]
/// eviction and [removeUrl] never re-read the whole cache. Use one store
/// instance per [directory].
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

  /// file name → index record. Insertion order = least recently used first.
  final Map<String, _IndexRecord> _index = <String, _IndexRecord>{};

  /// url → file names stored for it (several when `Vary`/auth scopes differ).
  final Map<String, Set<String>> _byUrl = <String, Set<String>>{};

  int _totalBytes = 0;
  Future<void>? _loading;

  /// Serializes mutations so the index and the files never disagree.
  Future<void> _tail = Future<void>.value();

  Future<T> _locked<T>(Future<T> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  String _fileName(String key) => '${sha256.convert(utf8.encode(key))}$_ext';

  File _file(String name) => File('${_dir.path}${Platform.pathSeparator}$name');

  Future<void> _ensureIndex() => _loading ??= _loadIndex();

  Future<void> _loadIndex() async {
    if (!await _dir.exists()) return;
    final entries = <({String name, String url, int size, DateTime used})>[];
    await for (final entity in _dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.endsWith(_ext)) {
        // Leftover temp files from an interrupted write, and the old
        // base64-JSON format (`*.json`), are dropped.
        if (name.contains('.tmp.') || name.endsWith('.json')) {
          await _deleteQuietly(entity);
        }
        continue;
      }
      try {
        final stat = await entity.stat();
        final url = await _readUrl(entity);
        if (url == null) {
          await _deleteQuietly(entity);
          continue;
        }
        entries.add((
          name: name,
          url: url,
          size: stat.size,
          used: stat.modified,
        ));
      } catch (_) {
        await _deleteQuietly(entity);
      }
    }
    entries.sort((a, b) => a.used.compareTo(b.used));
    for (final e in entries) {
      _put(e.name, e.url, e.size);
    }
  }

  /// Reads only the metadata header of [file] and returns its url.
  Future<String?> _readUrl(File file) async {
    final raf = await file.open();
    try {
      final header = await raf.read(_headerBytes);
      if (header.length != _headerBytes) return null;
      final view = ByteData.sublistView(header);
      if (view.getUint32(0) != _magic) return null;
      final metaLen = view.getUint32(4);
      final meta = await raf.read(metaLen);
      if (meta.length != metaLen) return null;
      final decoded = jsonDecode(utf8.decode(meta));
      return decoded is Map && decoded['url'] is String
          ? decoded['url'] as String
          : null;
    } finally {
      await raf.close();
    }
  }

  void _put(String name, String url, int size) {
    _drop(name);
    _index[name] = _IndexRecord(url, size);
    (_byUrl[url] ??= <String>{}).add(name);
    _totalBytes += size;
  }

  void _drop(String name) {
    final old = _index.remove(name);
    if (old == null) return;
    _totalBytes -= old.size;
    final names = _byUrl[old.url];
    if (names != null) {
      names.remove(name);
      if (names.isEmpty) _byUrl.remove(old.url);
    }
  }

  void _touch(String name) {
    final rec = _index.remove(name);
    if (rec != null) _index[name] = rec;
  }

  @override
  Future<CacheEntry?> get(String key) async {
    await _ensureIndex();
    final name = _fileName(key);
    if (!_index.containsKey(name)) return null;
    final file = _file(name);
    try {
      final bytes = await file.readAsBytes();
      final entry = _decode(bytes);
      if (entry == null) {
        await _locked(() async {
          _drop(name);
          await _deleteQuietly(file);
        });
        return null;
      }
      _touch(name);
      // Persist LRU order across restarts without blocking the caller.
      unawaited(
        file
            .setLastModified(DateTime.now())
            .then<void>((_) {}, onError: (Object _) {}),
      );
      return entry;
    } catch (_) {
      await _locked(() async {
        _drop(name);
        await _deleteQuietly(file);
      });
      return null;
    }
  }

  @override
  Future<void> set(String key, CacheEntry entry) async {
    if (entry.size > maxBytes) return;
    await _ensureIndex();
    final bytes = _encode(entry);
    if (bytes.length > maxBytes) return;
    final name = _fileName(key);
    await _locked(() async {
      await _dir.create(recursive: true);
      final target = _file(name);
      final temp = File('${target.path}.tmp.${pid}_${identityHashCode(entry)}');
      try {
        await temp.writeAsBytes(bytes, flush: true);
        // rename() replaces the target atomically on every IO platform.
        await temp.rename(target.path);
      } catch (_) {
        await _deleteQuietly(temp);
        rethrow;
      }
      _put(name, entry.url, bytes.length);
      await _evictOverLimits();
    });
  }

  @override
  Future<void> remove(String key) async {
    await _ensureIndex();
    final name = _fileName(key);
    await _locked(() async {
      _drop(name);
      await _deleteQuietly(_file(name));
    });
  }

  @override
  Future<void> removeUrl(String url) async {
    await _ensureIndex();
    final names = _byUrl[url];
    if (names == null || names.isEmpty) return;
    await _locked(() async {
      for (final name in List<String>.of(_byUrl[url] ?? const <String>{})) {
        _drop(name);
        await _deleteQuietly(_file(name));
      }
    });
  }

  @override
  Future<void> clear() async {
    await _ensureIndex();
    await _locked(() async {
      _index.clear();
      _byUrl.clear();
      _totalBytes = 0;
      if (!await _dir.exists()) return;
      await for (final entity in _dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith(_ext) ||
            name.endsWith('.json') ||
            name.contains('.tmp.')) {
          await _deleteQuietly(entity);
        }
      }
    });
  }

  Future<void> _evictOverLimits() async {
    while (_index.length > maxEntries || _totalBytes > maxBytes) {
      final oldest = _index.keys.first;
      _drop(oldest);
      await _deleteQuietly(_file(oldest));
    }
  }

  static Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      await entity.delete();
    } catch (_) {
      // Already gone or locked: nothing useful to do for a cache.
    }
  }

  static Uint8List _encode(CacheEntry entry) {
    final meta = utf8.encode(
      jsonEncode({
        'url': entry.url,
        'statusCode': entry.statusCode,
        'headers': entry.headers,
        'storedAt': entry.storedAt.toUtc().toIso8601String(),
        'expiresAt': entry.expiresAt.toUtc().toIso8601String(),
        if (entry.vary.isNotEmpty) 'vary': entry.vary,
      }),
    );
    final out = Uint8List(_headerBytes + meta.length + entry.body.length);
    ByteData.sublistView(out)
      ..setUint32(0, _magic)
      ..setUint32(4, meta.length);
    out.setRange(_headerBytes, _headerBytes + meta.length, meta);
    out.setRange(_headerBytes + meta.length, out.length, entry.body);
    return out;
  }

  static CacheEntry? _decode(Uint8List bytes) {
    if (bytes.length < _headerBytes) return null;
    final view = ByteData.sublistView(bytes);
    if (view.getUint32(0) != _magic) return null;
    final metaLen = view.getUint32(4);
    final bodyStart = _headerBytes + metaLen;
    if (bodyStart > bytes.length) return null;
    final decoded = jsonDecode(
      utf8.decode(Uint8List.sublistView(bytes, _headerBytes, bodyStart)),
    );
    if (decoded is! Map<String, Object?>) return null;
    return CacheEntry(
      url: decoded['url']! as String,
      statusCode: decoded['statusCode']! as int,
      headers: Map<String, String>.from(decoded['headers']! as Map),
      body: Uint8List.sublistView(bytes, bodyStart),
      storedAt: DateTime.parse(decoded['storedAt']! as String),
      expiresAt: DateTime.parse(decoded['expiresAt']! as String),
      vary: decoded['vary'] is Map
          ? Map<String, String>.from(decoded['vary']! as Map)
          : const {},
    );
  }
}

final class _IndexRecord {
  _IndexRecord(this.url, this.size);
  final String url;
  final int size;
}
