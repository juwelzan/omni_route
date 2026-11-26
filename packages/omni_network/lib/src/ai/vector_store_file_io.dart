import 'dart:convert';
import 'dart:io';

import 'vector_store.dart';

/// Persistent JSON-backed [AiVectorStore] for IO platforms so embeddings
/// survive app restarts without needing native SQLite/FFI dependencies.
final class FileVectorStore implements AiVectorStore {
  /// Creates a disk-backed vector store inside [directory].
  FileVectorStore({required this.directory});

  /// Directory holding `vectors.json`.
  final String directory;

  File get _file => File('$directory${Platform.pathSeparator}vectors.json');

  Future<Map<String, VectorDocument>> _readMap() async {
    if (!await _file.exists()) return {};
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! List) return {};
      final map = <String, VectorDocument>{};
      for (final raw in decoded) {
        if (raw is Map) {
          final doc = VectorDocument.fromJson(Map<String, Object?>.from(raw));
          map[doc.id] = doc;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMap(Map<String, VectorDocument> docs) async {
    await Directory(directory).create(recursive: true);
    final temp = File('${_file.path}.tmp.${pid}_${identityHashCode(docs)}');
    await temp.writeAsString(
      jsonEncode([for (final d in docs.values) d.toJson()]),
      flush: true,
    );
    await temp.rename(_file.path);
  }

  @override
  Future<void> upsert(VectorDocument document) => upsertAll([document]);

  @override
  Future<void> upsertAll(List<VectorDocument> documents) async {
    final map = await _readMap();
    for (final d in documents) {
      map[d.id] = d;
    }
    await _writeMap(map);
  }

  @override
  Future<List<VectorDocument>> all() async =>
      List.unmodifiable((await _readMap()).values);

  @override
  Future<void> delete(String id) async {
    final map = await _readMap();
    if (map.remove(id) != null) {
      await _writeMap(map);
    }
  }

  @override
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  @override
  Future<List<VectorSearchHit>> searchByVector(
    List<double> queryEmbedding, {
    int topK = 5,
    double minScore = -1.0,
  }) async => rankVectorDocuments(
    (await _readMap()).values,
    queryEmbedding,
    topK: topK,
    minScore: minScore,
  );

  @override
  Future<List<VectorSearchHit>> search(
    String query, {
    required TextEmbedder embedder,
    int topK = 5,
    double minScore = -1.0,
  }) async {
    final vec = await embedder(query);
    return searchByVector(vec, topK: topK, minScore: minScore);
  }
}
