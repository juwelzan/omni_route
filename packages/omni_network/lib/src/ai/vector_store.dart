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

/// Ranked similarity match returned by [AiVectorStore.searchByVector] and
/// [AiVectorStore.searchHybrid].
@immutable
final class VectorSearchHit {
  /// Creates a search hit.
  const VectorSearchHit({required this.document, required this.score});

  /// Matched document.
  final VectorDocument document;

  /// Similarity/hybrid relevance score (highest first).
  final double score;
}

/// Splits long documents/articles into overlapping chunks for RAG indexing
/// while respecting paragraph and sentence boundaries when possible.
abstract final class TextSplitter {
  /// Splits [text] into overlapping segments up to [chunkSize] characters,
  /// preserving [overlap] trailing characters from the prior chunk.
  static List<String> split(
    String text, {
    int chunkSize = 800,
    int overlap = 120,
    String separator = '\n',
  }) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be > 0');
    }
    if (overlap < 0 || overlap >= chunkSize) {
      throw ArgumentError.value(
        overlap,
        'overlap',
        'must be in [0, chunkSize)',
      );
    }
    final clean = text.trim();
    if (clean.isEmpty) return const [];
    if (clean.length <= chunkSize) return [clean];

    final chunks = <String>[];
    var start = 0;
    while (start < clean.length) {
      var end = min(start + chunkSize, clean.length);
      if (end < clean.length) {
        final sepIdx = clean.lastIndexOf(separator, end);
        if (sepIdx > start + (chunkSize ~/ 2)) {
          end = sepIdx + separator.length;
        } else {
          final spaceIdx = clean.lastIndexOf(' ', end);
          if (spaceIdx > start + (chunkSize ~/ 2)) {
            end = spaceIdx;
          }
        }
      }
      final part = clean.substring(start, end).trim();
      if (part.isNotEmpty) chunks.add(part);
      if (end >= clean.length) break;
      final nextStart = end - overlap;
      start = nextStart > start ? nextStart : end;
    }
    return chunks;
  }
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

/// Callback turning a batch of text strings into dense embedding vectors.
typedef BatchTextEmbedder =
    Future<List<List<double>>> Function(List<String> texts);

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
  /// matches at or above [minScore], optionally filtered by metadata [where].
  Future<List<VectorSearchHit>> searchByVector(
    List<double> queryEmbedding, {
    int topK = 5,
    double minScore = -1.0,
    Map<String, Object?>? where,
  });

  /// Embeds [query] using [embedder] and returns top matching documents.
  Future<List<VectorSearchHit>> search(
    String query, {
    required TextEmbedder embedder,
    int topK = 5,
    double minScore = -1.0,
    Map<String, Object?>? where,
  });

  /// Combines dense vector similarity (`vectorWeight`) with keyword token
  /// overlap (`1 - vectorWeight`) for higher-precision RAG retrieval.
  Future<List<VectorSearchHit>> searchHybrid(
    String query, {
    required TextEmbedder embedder,
    int topK = 5,
    double minScore = 0.0,
    double vectorWeight = 0.7,
    Map<String, Object?>? where,
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
    Map<String, Object?>? where,
  }) async => rankVectorDocuments(
    _docs.values,
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
      _docs.values,
      query: query,
      queryEmbedding: vec,
      topK: topK,
      minScore: minScore,
      vectorWeight: vectorWeight,
      where: where,
    );
  }
}

bool _matchesMetadata(VectorDocument doc, Map<String, Object?>? where) {
  if (where == null || where.isEmpty) return true;
  for (final e in where.entries) {
    if (doc.metadata[e.key] != e.value) return false;
  }
  return true;
}

/// Shared vector ranking helper used by both [MemoryVectorStore] and
/// `FileVectorStore`.
List<VectorSearchHit> rankVectorDocuments(
  Iterable<VectorDocument> docs,
  List<double> queryEmbedding, {
  int topK = 5,
  double minScore = -1.0,
  Map<String, Object?>? where,
}) {
  final hits = <VectorSearchHit>[];
  for (final doc in docs) {
    if (!_matchesMetadata(doc, where)) continue;
    final score = cosineSimilarity(queryEmbedding, doc.embedding);
    if (score >= minScore) {
      hits.add(VectorSearchHit(document: doc, score: score));
    }
  }
  hits.sort((a, b) => b.score.compareTo(a.score));
  return hits.length <= topK ? hits : hits.sublist(0, topK);
}

Set<String> _tokenize(String s) => RegExp(
  r'[a-z0-9]+',
).allMatches(s.toLowerCase()).map((m) => m.group(0)!).toSet();

/// Shared hybrid vector + keyword ranking helper.
List<VectorSearchHit> rankHybridVectorDocuments(
  Iterable<VectorDocument> docs, {
  required String query,
  required List<double> queryEmbedding,
  int topK = 5,
  double minScore = 0.0,
  double vectorWeight = 0.7,
  Map<String, Object?>? where,
}) {
  final qTokens = _tokenize(query);
  final kwWeight = (1.0 - vectorWeight).clamp(0.0, 1.0);
  final vWeight = vectorWeight.clamp(0.0, 1.0);
  final hits = <VectorSearchHit>[];

  for (final doc in docs) {
    if (!_matchesMetadata(doc, where)) continue;
    final cos = cosineSimilarity(queryEmbedding, doc.embedding);
    final normCos = ((cos + 1.0) / 2.0).clamp(0.0, 1.0);
    var kwScore = 0.0;
    if (qTokens.isNotEmpty) {
      final dTokens = _tokenize(doc.text);
      if (dTokens.isNotEmpty) {
        final overlap = qTokens.where(dTokens.contains).length;
        kwScore = overlap / qTokens.length;
      }
    }
    final combined = vWeight * normCos + kwWeight * kwScore;
    if (combined >= minScore) {
      hits.add(VectorSearchHit(document: doc, score: combined));
    }
  }
  hits.sort((a, b) => b.score.compareTo(a.score));
  return hits.length <= topK ? hits : hits.sublist(0, topK);
}
