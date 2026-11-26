import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

export 'vector_store_file_stub.dart'
    if (dart.library.io) 'vector_store_file_io.dart';

/// Text document paired with its embedding vector and metadata for lightweight
/// local RAG (Retrieval-Augmented Generation).
@immutable
final class VectorDocument {
  /// Creates a vector document.
  const VectorDocument({
    required this.id,
    required this.text,
    required this.embedding,
    this.metadata = const {},
  });

  /// Unique document identifier.
  final String id;

  /// Original text content.
  final String text;

  /// Dense embedding vector.
  final List<double> embedding;

  /// Arbitrary document metadata (title, source, page, tags…).
  final Map<String, Object?> metadata;

  /// Serializes to JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'embedding': embedding,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  /// Restores a document written by [toJson].
  factory VectorDocument.fromJson(Map<String, Object?> json) => VectorDocument(
    id: json['id']! as String,
    text: json['text']! as String,
    embedding: [
      for (final n in json['embedding']! as List) (n as num).toDouble(),
    ],
    metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
  );
}

/// Ranked similarity match returned by [AiVectorStore.searchByVector].
@immutable
final class VectorSearchHit {
  /// Creates a search hit.
  const VectorSearchHit({required this.document, required this.score});

  /// Matched document.
  final VectorDocument document;

  /// Cosine similarity score in `[-1.0, 1.0]`.
  final double score;
}

/// Computes cosine similarity between two equal-length vectors (`0.0` when
/// empty, zero-norm, or mismatched lengths).
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || a.length != b.length) return 0.0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  return denom == 0.0 ? 0.0 : dot / denom;
}

/// Callback turning raw text strings into dense vector embeddings.
typedef TextEmbedder = Future<List<double>> Function(String text);

/// Storage backend for vector similarity search.
abstract interface class AiVectorStore {
  /// Stores or replaces a single [document].
  FutureOr<void> upsert(VectorDocument document);

  /// Stores or replaces multiple [documents].
  FutureOr<void> upsertAll(List<VectorDocument> documents);

  /// Returns all stored documents.
  FutureOr<List<VectorDocument>> all();

  /// Removes a document by [id].
  FutureOr<void> delete(String id);

  /// Removes all stored documents.
  FutureOr<void> clear();

  /// Searches by dense [queryEmbedding], returning up to [topK] highest-scoring
  /// matches at or above [minScore].
  Future<List<VectorSearchHit>> searchByVector(
    List<double> queryEmbedding, {
    int topK = 5,
    double minScore = -1.0,
  });

  /// Embeds [query] using [embedder] and returns top matching documents.
  Future<List<VectorSearchHit>> search(
    String query, {
    required TextEmbedder embedder,
    int topK = 5,
    double minScore = -1.0,
  });
}

/// Pure-Dart in-memory [AiVectorStore] supporting mobile, desktop, and Web.
final class MemoryVectorStore implements AiVectorStore {
  final Map<String, VectorDocument> _docs = {};

  @override
  void upsert(VectorDocument document) => _docs[document.id] = document;

  @override
  void upsertAll(List<VectorDocument> documents) {
    for (final d in documents) {
      _docs[d.id] = d;
    }
  }

  @override
  List<VectorDocument> all() => List.unmodifiable(_docs.values);

  @override
  void delete(String id) => _docs.remove(id);

  @override
  void clear() => _docs.clear();

  @override
  Future<List<VectorSearchHit>> searchByVector(
    List<double> queryEmbedding, {
    int topK = 5,
    double minScore = -1.0,
  }) async => rankVectorDocuments(
    _docs.values,
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

/// Shared ranking helper used by both [MemoryVectorStore] and `FileVectorStore`.
List<VectorSearchHit> rankVectorDocuments(
  Iterable<VectorDocument> docs,
  List<double> queryEmbedding, {
  int topK = 5,
  double minScore = -1.0,
}) {
  final hits = <VectorSearchHit>[];
  for (final doc in docs) {
    final score = cosineSimilarity(queryEmbedding, doc.embedding);
    if (score >= minScore) {
      hits.add(VectorSearchHit(document: doc, score: score));
    }
  }
  hits.sort((a, b) => b.score.compareTo(a.score));
  return hits.length <= topK ? hits : hits.sublist(0, topK);
}
