import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'vector_store.dart';

/// Persistent JSON-backed [AiVectorStore] for IO platforms with lazy
/// in-memory read caching so embeddings survive app restarts without requiring
/// native SQLite/FFI dependencies.
final class FileVectorStore implements AiVectorStore {
  /// Creates a disk-backed vector store inside [directory].
  FileVectorStore({required this.directory});

  /// Directory holding `vectors.json`.
  final String directory;

  Map<String, VectorDocument>? _cache;
  int _tmpSeq = 0;
  Future<void> _lock = Future<void>.value();

  Future<T> _synchronized<T>(Future<T> Function() op) {
    final prev = _lock;
    final run = prev.catchError((Object _) {}).then((_) => op());
    _lock = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  File get _file => File('$directory${Platform.pathSeparator}vectors.json');

  Future<Map<String, VectorDocument>> _readMap() async {
    final cached = _cache;
    if (cached != null) return cached;
    if (!await _file.exists()) return _cache = {};
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! List) return _cache = {};
      final map = <String, VectorDocument>{};
      for (final raw in decoded) {
        if (raw is Map) {
          final doc = VectorDocument.fromJson(Map<String, Object?>.from(raw));
          map[doc.id] = doc;
        }
      }
      return _cache = map;
    } catch (_) {
      return _cache = {};
    }
  }

  Future<void> _writeMap(Map<String, VectorDocument> docs) async {
    await Directory(directory).create(recursive: true);
    final temp = File('${_file.path}.tmp.${pid}_${++_tmpSeq}');
    try {
      await temp.writeAsString(
        jsonEncode([for (final d in docs.values) d.toJson()]),
        flush: true,
      );
      await temp.rename(_file.path);
      _cache = docs;
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete().catchError((Object _) => temp);
      }
      rethrow;
    }
  }

  @override
  Future<void> upsert(VectorDocument document) => upsertAll([document]);

  @override
  Future<void> upsertAll(List<VectorDocument> documents) =>
      _synchronized(() async {
        final map = Map<String, VectorDocument>.of(await _readMap());
        for (final d in documents) {
          map[d.id] = d;
        }
        await _writeMap(map);
      });

  @override
  Future<List<VectorDocument>> all() =>
      _synchronized(() async => List.unmodifiable((await _readMap()).values));

  @override
  Future<void> delete(String id) => _synchronized(() async {
    final map = Map<String, VectorDocument>.of(await _readMap());
    if (map.remove(id) != null) {
      await _writeMap(map);
    }
  });

  @override
  Future<void> clear() => _synchronized(() async {
    _cache = {};
    if (await _file.exists()) {
      await _file.delete();
    }
  });

  @override
  Future<List<VectorSearchHit>> searchByVector(
    List<double> queryEmbedding, {
    int topK = 5,
    double minScore = -1.0,
    Map<String, Object?>? where,
  }) => _synchronized(
    () async => rankVectorDocuments(
      (await _readMap()).values,
      queryEmbedding,
      topK: topK,
      minScore: minScore,
      where: where,
    ),
  );

  @override
  Future<List<VectorSearchHit>> search(
    String query, {
    required TextEmbedder embedder,
    int topK = 5,
    double minScore = -1.0,
    Map<String, Object?>? where,
  }) async {
    final vec = await embedder(query);
    return searchByVector(vec, topK: topK, minScore: minScore, where: where);
  }

  @override
  Future<List<VectorSearchHit>> searchHybrid(
    String query, {
    required TextEmbedder embedder,
    int topK = 5,
    double minScore = 0.0,
    double vectorWeight = 0.7,
    Map<String, Object?>? where,
  }) async {
    final vec = await embedder(query);
    return rankHybridVectorDocuments(
      (await _readMap()).values,
      query: query,
      queryEmbedding: vec,
      topK: topK,
      minScore: minScore,
      vectorWeight: vectorWeight,
      where: where,
    );
  }
}
