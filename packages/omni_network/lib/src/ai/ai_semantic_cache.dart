import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'ai_models.dart';
import 'vector_store.dart';

/// Semantic + exact-hash cache for [OmniAi] prompts, powered by any
/// [AiVectorStore] (`MemoryVectorStore` or `FileVectorStore`).
///
/// When [embedder] is supplied, incoming prompts are embedded and matched by
/// cosine similarity (>= [similarityThreshold]). When omitted (or if similarity
/// matching is skipped), falls back cleanly to normalized exact prompt hash
/// matching (`exactMatch: true`).
final class AiSemanticCache {
  /// Creates a semantic prompt cache.
  AiSemanticCache({
    AiVectorStore? store,
    this.embedder,
    this.similarityThreshold = 0.94,
    this.ttl = const Duration(hours: 24),
    this.maxEntries = 500,
    this.exactMatch = true,
    DateTime Function()? now,
  }) : store = store ?? MemoryVectorStore(),
       _now = now ?? DateTime.now;

  /// Backing vector document store.
  final AiVectorStore store;

  /// Optional text embedder enabling semantic similarity hits across paraphrased
  /// prompts. When `null`, normalized exact prompt matching is used.
  final TextEmbedder? embedder;

  /// Minimum cosine similarity (`0.0`..`1.0`) required for a semantic cache hit.
  final double similarityThreshold;

  /// Entry expiration window.
  final Duration ttl;

  /// Maximum cached prompt/response entries retained cleanly.
  final int maxEntries;

  /// Enables normalized exact prompt-key lookup even without an embedder.
  final bool exactMatch;

  final DateTime Function() _now;
  final Map<String, ({String response, String model, DateTime storedAt})>
  _exactIndex = {};

  static String _cacheKey(String modelKey, String prompt) =>
      sha256.convert(utf8.encode('$modelKey\n${prompt.trim()}')).toString();

  /// Looks up a fresh cached reply matching [prompt] for [modelKey], or `null`.
  Future<AiResponse?> lookup({
    required String modelKey,
    required String prompt,
  }) async {
    final now = _now();
    final key = _cacheKey(modelKey, prompt);
    if (exactMatch) {
      final hit = _exactIndex[key];
      if (hit != null) {
        if (now.difference(hit.storedAt) <= ttl) {
          return AiResponse(
            text: hit.response,
            model: hit.model,
            providerId: 'semantic_cache',
          );
        }
        _exactIndex.remove(key);
      }
    }

    final embFn = embedder;
    if (embFn != null) {
      final queryVec = await embFn(prompt);
      final hits = await store.searchByVector(
        queryVec,
        topK: 3,
        minScore: similarityThreshold,
        where: {'modelKey': modelKey},
      );
      for (final h in hits) {
        final storedAtMs = h.document.metadata['storedAtMs'] as int?;
        if (storedAtMs == null) continue;
        final age = now.difference(
          DateTime.fromMillisecondsSinceEpoch(storedAtMs, isUtc: true),
        );
        if (age > ttl) {
          await store.delete(h.document.id);
          continue;
        }
        final responseText = h.document.metadata['response'] as String?;
        final model = h.document.metadata['model'] as String? ?? modelKey;
        if (responseText != null) {
          return AiResponse(
            text: responseText,
            model: model,
            providerId: 'semantic_cache',
          );
        }
      }
    }
    return null;
  }

  /// Stores a prompt/response pair for subsequent semantic or exact cache hits.
  Future<void> put({
    required String modelKey,
    required String prompt,
    required AiResponse response,
  }) async {
    final now = _now().toUtc();
    final key = _cacheKey(modelKey, prompt);
    if (exactMatch) {
      _exactIndex[key] = (
        response: response.text,
        model: response.model,
        storedAt: now,
      );
      while (_exactIndex.length > maxEntries) {
        _exactIndex.remove(_exactIndex.keys.first);
      }
    }

    final embFn = embedder;
    if (embFn != null) {
      final vec = await embFn(prompt);
      await store.upsert(
        VectorDocument(
          id: key,
          text: prompt,
          embedding: vec,
          metadata: {
            'modelKey': modelKey,
            'model': response.model,
            'response': response.text,
            'storedAtMs': now.millisecondsSinceEpoch,
          },
        ),
      );
      final allDocs = await store.all();
      if (allDocs.length > maxEntries) {
        final sorted = [...allDocs]
          ..sort(
            (a, b) => ((a.metadata['storedAtMs'] as int?) ?? 0).compareTo(
              (b.metadata['storedAtMs'] as int?) ?? 0,
            ),
          );
        final excess = sorted.length - maxEntries;
        for (var i = 0; i < excess; i++) {
          await store.delete(sorted[i].id);
        }
      }
    }
  }

  /// Clears all cached entries.
  Future<void> clear() async {
    _exactIndex.clear();
    await store.clear();
  }
}
