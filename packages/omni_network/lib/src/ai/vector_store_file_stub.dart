import 'vector_store.dart';

/// Web fallback for `FileVectorStore`: keeps embeddings in memory where direct
/// filesystem I/O is unavailable.
final class FileVectorStore implements AiVectorStore {
  /// Creates an in-memory fallback vector store on Web.
  FileVectorStore({required this.directory});

  /// Ignored on Web.
  final String directory;

  final MemoryVectorStore _inner = MemoryVectorStore();

  @override
  Future<void> upsert(VectorDocument document) async => _inner.upsert(document);

  @override
  Future<void> upsertAll(List<VectorDocument> documents) async =>
      _inner.upsertAll(documents);

  @override
  Future<List<VectorDocument>> all() async => _inner.all();

  @override
  Future<void> delete(String id) async => _inner.delete(id);

  @override
  Future<void> clear() async => _inner.clear();

  @override
  Future<List<VectorSearchHit>> searchByVector(
    List<double> queryEmbedding, {
    int topK = 5,
    double minScore = -1.0,
    Map<String, Object?>? where,
  }) => _inner.searchByVector(
    queryEmbedding,
    topK: topK,
    minScore: minScore,
    where: where,
  );

  @override
  Future<List<VectorSearchHit>> search(
    String query, {
    required TextEmbedder embedder,
    int topK = 5,
    double minScore = -1.0,
    Map<String, Object?>? where,
  }) => _inner.search(
    query,
    embedder: embedder,
    topK: topK,
    minScore: minScore,
    where: where,
  );

  @override
  Future<List<VectorSearchHit>> searchHybrid(
    String query, {
    required TextEmbedder embedder,
    int topK = 5,
    double minScore = 0.0,
    double vectorWeight = 0.7,
    Map<String, Object?>? where,
  }) => _inner.searchHybrid(
    query,
    embedder: embedder,
    topK: topK,
    minScore: minScore,
    vectorWeight: vectorWeight,
    where: where,
  );
}
