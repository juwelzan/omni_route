import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../core/cancel_token.dart';
import '../core/http_date.dart';
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import 'ai_guardrail.dart';
import 'ai_models.dart';
import 'ai_provider.dart';
import 'ai_semantic_cache.dart';
import 'vector_store.dart';

/// Configuration passed to `OmniNetwork(ai: ...)` or `OmniApiHub(ai: ...)`.
@immutable
final class AiConfig {
  /// Creates multi-AI routing, caching, guardrail, and budget configuration.
  const AiConfig({
    this.defaultModel,
    this.providers = const {},
    this.routes = const {},
    this.pricing = const {},
    this.maxSessionBudgetUsd,
    this.defaultTools = const [],
    this.maxToolRounds = 5,
    this.guardrail,
    this.semanticCache,
    this.rateLimitCooldown = const Duration(seconds: 15),
  });

  /// Logical model alias (e.g. `'smart'`) or `'provider:model'` string used
  /// when callers omit `model:`.
  final String? defaultModel;

  /// Registered AI provider adapters keyed by provider id (`'openai'`,
  /// `'gemini'`, `'claude'`, `'ollama'`, etc.).
  final Map<String, AiProvider> providers;

  /// Named routing rules & fallback chains (e.g. `'fast'`, `'smart'`).
  final Map<String, AiModelRoute> routes;

  /// Optional per-model USD cost table per 1M input/output tokens.
  final Map<String, AiModelCost> pricing;

  /// Optional session spend guard in USD.
  final double? maxSessionBudgetUsd;

  /// Default tools attached to every request unless overridden.
  final List<AiTool> defaultTools;

  /// Maximum tool-execution turns allowed per [OmniAi.chat] / [OmniAi.ask].
  final int maxToolRounds;

  /// Optional privacy/safety guardrail sanitizing prompts before calling
  /// external LLMs.
  final AiGuardrail? guardrail;

  /// Optional semantic / exact prompt cache avoiding duplicate LLM calls.
  final AiSemanticCache? semanticCache;

  /// Fallback cooldown duration applied to a target when HTTP `429` arrives
  /// without a `Retry-After` header.
  final Duration rateLimitCooldown;
}

/// Telemetry record emitted for every completed or failed AI generation call.
@immutable
final class AiCallLogRecord {
  /// Creates an AI call telemetry entry.
  const AiCallLogRecord({
    required this.providerId,
    required this.model,
    required this.usage,
    required this.latency,
    required this.timestamp,
    this.promptPreview,
    this.responsePreview,
    this.error,
    this.usedFallback = false,
  });

  /// Concrete provider identifier that answered (or failed).
  final String providerId;

  /// Concrete model identifier.
  final String model;

  /// Token & USD consumption.
  final AiUsage usage;

  /// Wall-clock duration.
  final Duration latency;

  /// Completion timestamp.
  final DateTime timestamp;

  /// Optional short redacted preview of the prompt.
  final String? promptPreview;

  /// Optional short redacted preview of the response.
  final String? responsePreview;

  /// Error description when the call failed.
  final String? error;

  /// Whether a fallback route model handled this call.
  final bool usedFallback;
}

/// Unified Multi-AI client supporting OpenAI, Google Gemini, Anthropic Claude,
/// Ollama, OpenAI-compatible servers, smart/hedged failover routes, streaming
/// tool calling, progressive JSON object streaming with auto-repair, voice &
/// image generation, semantic prompt caching, PII guardrails & RAG indexing.
final class OmniAi {
  /// Creates an AI coordinator backed by `OmniNetwork` [client].
  OmniAi({required OmniNetwork client, AiConfig config = const AiConfig()})
    : _client = client, // ignore: prefer_initializing_formals
      _providers = Map.of(config.providers),
      _routes = Map.of(config.routes),
      defaultModel = config.defaultModel,
      _defaultTools = List.of(config.defaultTools),
      _defaultMaxToolRounds = config.maxToolRounds,
      _guardrail = config.guardrail,
      _semanticCache = config.semanticCache,
      _rateLimitCooldown = config.rateLimitCooldown,
      usage = AiUsageTracker(
        maxSessionBudgetUsd: config.maxSessionBudgetUsd,
        pricing: config.pricing,
      );

  OmniAi._scoped({
    required OmniNetwork client,
    required Map<String, AiProvider> providers,
    required Map<String, AiModelRoute> routes,
    required this.defaultModel,
    required List<AiTool> defaultTools,
    required int defaultMaxToolRounds,
    required AiGuardrail? guardrail,
    required AiSemanticCache? semanticCache,
    required Duration rateLimitCooldown,
    required Map<String, DateTime> cooldownUntil,
    required Map<String, Duration> observedLatency,
    required this.usage,
    required StreamController<AiCallLogRecord> telemetryController,
  }) : _client = client, // ignore: prefer_initializing_formals
       _providers = providers, // ignore: prefer_initializing_formals
       _routes = routes, // ignore: prefer_initializing_formals
       _defaultTools = defaultTools, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _defaultMaxToolRounds = defaultMaxToolRounds,
       _guardrail = guardrail, // ignore: prefer_initializing_formals
       _semanticCache = semanticCache, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _rateLimitCooldown = rateLimitCooldown,
       _cooldownUntil = cooldownUntil, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _observedLatency = observedLatency,
       _telemetry = telemetryController;

  final OmniNetwork _client;
  final Map<String, AiProvider> _providers;
  final Map<String, AiModelRoute> _routes;

  /// Active default model alias or `'provider:model'`, mutable at runtime.
  String? defaultModel;

  final List<AiTool> _defaultTools;
  int _defaultMaxToolRounds;
  AiGuardrail? _guardrail;
  AiSemanticCache? _semanticCache;
  Duration _rateLimitCooldown;
  Map<String, DateTime> _cooldownUntil = {};
  Map<String, Duration> _observedLatency = {};

  /// Cumulative token and USD usage tracker for this AI client.
  final AiUsageTracker usage;

  StreamController<AiCallLogRecord> _telemetry =
      StreamController<AiCallLogRecord>.broadcast();

  /// Broadcast stream of redacted AI call telemetry (used by `OmniInspector`).
  Stream<AiCallLogRecord> get telemetry => _telemetry.stream;

  /// Registered provider adapters keyed by id.
  Map<String, AiProvider> get providers => Map.unmodifiable(_providers);

  /// Configured model aliases / fallback routes.
  Map<String, AiModelRoute> get routes => Map.unmodifiable(_routes);

  /// Active privacy/safety guardrail, if any.
  AiGuardrail? get guardrail => _guardrail;

  /// Active semantic prompt cache, if any.
  AiSemanticCache? get semanticCache => _semanticCache;

  /// Registers or replaces an [AiProvider] dynamically at runtime.
  void registerProvider(String id, AiProvider provider) {
    _providers[id] = provider;
  }

  /// Registers or replaces a logical route alias (e.g. `'smart'`, `'fast'`).
  void setRoute(String alias, AiModelRoute route) {
    _routes[alias] = route;
  }

  /// Replaces the active [AiConfig] (providers, routes, pricing, budget,
  /// guardrail & semantic cache) dynamically at runtime.
  void configure(AiConfig config) {
    _providers
      ..clear()
      ..addAll(config.providers);
    _routes
      ..clear()
      ..addAll(config.routes);
    if (config.defaultModel != null) {
      defaultModel = config.defaultModel;
    }
    if (config.defaultTools.isNotEmpty) {
      _defaultTools
        ..clear()
        ..addAll(config.defaultTools);
    }
    _defaultMaxToolRounds = config.maxToolRounds;
    _guardrail = config.guardrail;
    _semanticCache = config.semanticCache;
    _rateLimitCooldown = config.rateLimitCooldown;
    usage.pricing = Map.of(config.pricing);
    usage.maxSessionBudgetUsd = config.maxSessionBudgetUsd;
  }

  /// Clears active rate-limit cooldown state across all route targets.
  void clearCooldowns() => _cooldownUntil.clear();

  /// Returns a view of this [OmniAi] with [tools] automatically attached to all
  /// calls (`ask`, `chat`, `stream`).
  OmniAi withTools(List<AiTool> tools, {int? maxToolRounds}) => OmniAi._scoped(
    client: _client,
    providers: _providers,
    routes: _routes,
    defaultModel: defaultModel,
    defaultTools: List.of([..._defaultTools, ...tools]),
    defaultMaxToolRounds: maxToolRounds ?? _defaultMaxToolRounds,
    guardrail: _guardrail,
    semanticCache: _semanticCache,
    rateLimitCooldown: _rateLimitCooldown,
    cooldownUntil: _cooldownUntil,
    observedLatency: _observedLatency,
    usage: usage,
    telemetryController: _telemetry,
  );

  /// Sends a single text [prompt] and returns the generated string answer
  /// (running any configured [AiTool] calls automatically).
  Future<String> ask(
    String prompt, {
    String? model,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    int? maxToolRounds,
    OmniCancelToken? cancelToken,
  }) async {
    final messages = [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        AiMessage.system(systemPrompt),
      AiMessage.user(prompt),
    ];
    final res = await chat(
      messages,
      model: model,
      options: options,
      maxToolRounds: maxToolRounds,
      cancelToken: cancelToken,
    );
    return res.text;
  }

  /// Performs a full multi-turn AI chat request with guardrail inspection,
  /// optional semantic cache lookup, smart/hedged failover routing, and
  /// multi-round tool execution.
  Future<AiResponse> chat(
    List<AiMessage> messages, {
    String? model,
    AiRequestOptions options = const AiRequestOptions(),
    int? maxToolRounds,
    OmniCancelToken? cancelToken,
  }) async {
    final effectiveTools = options.tools.isNotEmpty
        ? options.tools
        : _defaultTools;
    final effectiveOptions = options.tools.isNotEmpty
        ? options
        : options.copyWith(tools: effectiveTools);
    final toolMap = {for (final t in effectiveTools) t.name: t};
    final roundsLimit = maxToolRounds ?? _defaultMaxToolRounds;

    var placeholders = const <String, String>{};
    var history = [...messages];
    final guard = _guardrail;
    if (guard != null) {
      final inspected = guard.inspectMessages(history);
      history = inspected.messages;
      placeholders = inspected.placeholders;
    }

    final cache = _semanticCache;
    final canUseCache =
        cache != null &&
        effectiveOptions.useSemanticCache &&
        effectiveTools.isEmpty &&
        !effectiveOptions.jsonMode &&
        effectiveOptions.responseSchema == null &&
        (effectiveOptions.temperature ?? 0.0) <= 0.3 &&
        history.every((m) => m.role != AiRole.tool && m.toolCalls.isEmpty);
    final cachePromptKey = _cacheKeyPrompt(history);
    final resolvedModelKey = model ?? defaultModel ?? '';

    if (canUseCache && cachePromptKey != null) {
      final hit = await cache.lookup(
        modelKey: resolvedModelKey,
        prompt: cachePromptKey,
      );
      if (hit != null) {
        final restoredText = guard != null
            ? guard.restoreText(hit.text, placeholders)
            : hit.text;
        _emitLog(
          providerId: 'semantic_cache',
          model: hit.model,
          usage: AiUsage.zero,
          latency: Duration.zero,
          messages: history,
          responseText: restoredText,
          usedFallback: false,
        );
        return AiResponse(
          text: restoredText,
          model: hit.model,
          providerId: 'semantic_cache',
        );
      }
    }

    var aggregatedUsage = AiUsage.zero;
    final totalSw = Stopwatch()..start();

    for (var round = 0; ; round++) {
      final response = await _generateWithFallback(
        model: model,
        messages: history,
        options: effectiveOptions,
        cancelToken: cancelToken,
      );
      aggregatedUsage += response.usage;

      if (!response.hasToolCalls || toolMap.isEmpty || round >= roundsLimit) {
        final finalText = guard != null
            ? guard.restoreText(response.text, placeholders)
            : response.text;
        final finalRes = AiResponse(
          text: finalText,
          thinking: response.thinking,
          toolCalls: response.toolCalls,
          usage: aggregatedUsage,
          model: response.model,
          providerId: response.providerId,
          finishReason: response.finishReason,
          latency: totalSw.elapsed,
          raw: response.raw,
        );
        if (canUseCache &&
            cachePromptKey != null &&
            round == 0 &&
            finalRes.text.isNotEmpty) {
          await cache.put(
            modelKey: resolvedModelKey,
            prompt: cachePromptKey,
            response: AiResponse(
              text: response.text,
              model: response.model,
              providerId: response.providerId,
            ),
          );
        }
        return finalRes;
      }

      history.add(response.toMessage());
      await _executeToolsIntoHistory(response.toolCalls, toolMap, history);
    }
  }

  /// Streams incremental response tokens for a single [prompt], optionally
  /// running multi-round [AiTool] execution when [autoExecuteTools] is `true`.
  Stream<AiStreamEvent> stream(
    String prompt, {
    String? model,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    bool autoExecuteTools = true,
    int? maxToolRounds,
    OmniCancelToken? cancelToken,
  }) => streamChat(
    [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        AiMessage.system(systemPrompt),
      AiMessage.user(prompt),
    ],
    model: model,
    options: options,
    autoExecuteTools: autoExecuteTools,
    maxToolRounds: maxToolRounds,
    cancelToken: cancelToken,
  );

  /// Streams incremental response tokens for [messages], automatically failing
  /// over before the first emitted chunk and optionally executing multi-round
  /// tool calls seamlessly when [autoExecuteTools] is `true`.
  Stream<AiStreamEvent> streamChat(
    List<AiMessage> messages, {
    String? model,
    AiRequestOptions options = const AiRequestOptions(),
    bool autoExecuteTools = true,
    int? maxToolRounds,
    OmniCancelToken? cancelToken,
  }) async* {
    final effectiveTools = options.tools.isNotEmpty
        ? options.tools
        : _defaultTools;
    final baseOptions = options.tools.isNotEmpty
        ? options
        : options.copyWith(tools: effectiveTools);
    final toolMap = {for (final t in effectiveTools) t.name: t};
    final roundsLimit = maxToolRounds ?? _defaultMaxToolRounds;

    var history = [...messages];
    var placeholders = const <String, String>{};
    final guard = _guardrail;
    if (guard != null) {
      final inspected = guard.inspectMessages(history);
      history = inspected.messages;
      placeholders = inspected.placeholders;
    }

    var totalUsage = AiUsage.zero;
    final totalSw = Stopwatch()..start();

    for (var round = 0; ; round++) {
      AiResponse? roundRes;
      await for (final ev in _streamRoundWithFailover(
        messages: history,
        model: model,
        options: baseOptions,
        cancelToken: cancelToken,
      )) {
        if (ev is AiCompleted) {
          roundRes = ev.response;
          totalUsage += roundRes.usage;
        } else {
          yield ev;
        }
      }
      if (roundRes == null) return;

      final canLoop =
          autoExecuteTools &&
          roundRes.hasToolCalls &&
          toolMap.isNotEmpty &&
          round < roundsLimit;
      if (!canLoop) {
        final finalText = guard != null
            ? guard.restoreText(roundRes.text, placeholders)
            : roundRes.text;
        yield AiCompleted(
          AiResponse(
            text: finalText,
            thinking: roundRes.thinking,
            toolCalls: roundRes.toolCalls,
            usage: totalUsage,
            model: roundRes.model,
            providerId: roundRes.providerId,
            finishReason: roundRes.finishReason,
            latency: totalSw.elapsed,
            raw: roundRes.raw,
          ),
        );
        return;
      }

      history.add(roundRes.toMessage());
      await _executeToolsIntoHistory(roundRes.toolCalls, toolMap, history);
    }
  }

  Stream<AiStreamEvent> _streamRoundWithFailover({
    required List<AiMessage> messages,
    required String? model,
    required AiRequestOptions options,
    required OmniCancelToken? cancelToken,
  }) async* {
    usage.ensureWithinBudget();
    final (targets, _) = _orderedTargets(model);
    Object? lastError;

    for (var i = 0; i < targets.length; i++) {
      final (target, provider) = targets[i];
      final targetOptions = _mergeTargetOptions(target.options, options);
      var emittedAnyChunk = false;
      final sw = Stopwatch()..start();

      try {
        await for (final ev in provider.stream(
          _client,
          model: target.model,
          messages: messages,
          options: targetOptions,
          cancelToken: cancelToken,
        )) {
          if (ev is AiTextDelta ||
              ev is AiThinkingDelta ||
              ev is AiToolCallDelta) {
            emittedAnyChunk = true;
            yield ev;
          } else if (ev is AiCompleted) {
            _observedLatency[_targetKey(target)] = sw.elapsed;
            final pricedUsage = usage.record(
              ev.response.model,
              ev.response.usage,
            );
            final completedRes = AiResponse(
              text: ev.response.text,
              thinking: ev.response.thinking,
              toolCalls: ev.response.toolCalls,
              usage: pricedUsage,
              model: ev.response.model,
              providerId: ev.response.providerId,
              finishReason: ev.response.finishReason,
              latency: ev.response.latency,
              raw: ev.response.raw,
            );
            _emitLog(
              providerId: provider.id,
              model: completedRes.model,
              usage: pricedUsage,
              latency: sw.elapsed,
              messages: messages,
              responseText: completedRes.text,
              usedFallback: i > 0,
            );
            yield AiCompleted(completedRes);
            return;
          } else if (ev is AiStreamError) {
            throw ev.error;
          }
        }
        return;
      } catch (e) {
        lastError = e;
        _recordFailureCooldown(target, e);
        _emitLog(
          providerId: provider.id,
          model: target.model,
          usage: AiUsage.zero,
          latency: sw.elapsed,
          messages: messages,
          error: '$e',
          usedFallback: i > 0,
        );
        final isCancelled =
            (cancelToken?.isCancelled ?? false) ||
            (e is OmniNetworkException && e.isCancelled);
        if (emittedAnyChunk || isCancelled || !_canFailover(e)) {
          rethrow;
        }
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }

  /// Requests structured JSON conforming to optional [schema] and decodes it
  /// directly into type [T] via [decoder]. When [autoRepair] is `true`, performs
  /// one self-healing repair turn if initial JSON output is malformed.
  Future<T> generateObject<T>(
    String prompt, {
    required T Function(Map<String, dynamic> json) decoder,
    Map<String, Object?>? schema,
    String? model,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    bool autoRepair = true,
    OmniCancelToken? cancelToken,
  }) async {
    final effOptions = options.copyWith(
      jsonMode: true,
      responseSchema: schema,
      useSemanticCache: false,
    );
    final rawText = await ask(
      prompt,
      model: model,
      systemPrompt: systemPrompt,
      options: effOptions,
      cancelToken: cancelToken,
    );

    try {
      return _decodeStructured<T>(rawText, decoder);
    } on DecodeFailure catch (firstErr) {
      if (!autoRepair) rethrow;
      final repairedText = await ask(
        'Your previous response could not be parsed cleanly (${firstErr.message}). '
        'Return ONLY a valid raw JSON object matching the schema with no markdown '
        'or commentary.\n\nInvalid output:\n$rawText',
        model: model,
        systemPrompt: systemPrompt,
        options: effOptions,
        cancelToken: cancelToken,
      );
      return _decodeStructured<T>(repairedText, decoder);
    }
  }

  /// Streams best-effort progressive structured objects [AiStreamingObject] as
  /// JSON tokens arrive, ending with the validated (or auto-repaired) [T].
  Stream<AiStreamingObject<T>> streamObject<T>(
    String prompt, {
    required T Function(Map<String, dynamic> json) decoder,
    Map<String, Object?>? schema,
    String? model,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    bool autoRepair = true,
    OmniCancelToken? cancelToken,
  }) async* {
    final effOptions = options.copyWith(
      jsonMode: true,
      responseSchema: schema,
      useSemanticCache: false,
    );
    final rawBuf = StringBuffer();
    AiUsage finalUsage = AiUsage.zero;

    await for (final ev in stream(
      prompt,
      model: model,
      systemPrompt: systemPrompt,
      options: effOptions,
      cancelToken: cancelToken,
    )) {
      if (ev is AiTextDelta) {
        rawBuf.write(ev.text);
        final rawText = rawBuf.toString();
        final partialMap = _tryParsePartialJsonObject(rawText);
        if (partialMap != null) {
          T? decoded;
          try {
            decoded = decoder(partialMap);
          } catch (_) {}
          yield AiStreamingObject<T>(
            partialJson: partialMap,
            value: decoded,
            isComplete: false,
            rawText: rawText,
          );
        }
      } else if (ev is AiCompleted) {
        finalUsage = ev.response.usage;
        if (rawBuf.isEmpty && ev.response.text.isNotEmpty) {
          rawBuf.write(ev.response.text);
        }
      }
    }

    final finalRaw = rawBuf.toString();
    try {
      final val = _decodeStructured<T>(finalRaw, decoder);
      final map = Map<String, dynamic>.from(
        jsonDecode(_stripJsonCodeFence(finalRaw))! as Map,
      );
      yield AiStreamingObject<T>(
        partialJson: map,
        value: val,
        isComplete: true,
        usage: finalUsage,
        rawText: finalRaw,
      );
    } on DecodeFailure catch (firstErr) {
      if (!autoRepair) rethrow;
      final repairedText = await ask(
        'Your previous JSON output could not be parsed cleanly '
        '(${firstErr.message}). Return ONLY a valid raw JSON object.\n\n'
        'Invalid output:\n$finalRaw',
        model: model,
        systemPrompt: systemPrompt,
        options: effOptions,
        cancelToken: cancelToken,
      );
      final val = _decodeStructured<T>(repairedText, decoder);
      final map = Map<String, dynamic>.from(
        jsonDecode(_stripJsonCodeFence(repairedText))! as Map,
      );
      yield AiStreamingObject<T>(
        partialJson: map,
        value: val,
        isComplete: true,
        usage: finalUsage,
        rawText: repairedText,
      );
    }
  }

  /// Generates a dense embedding vector for [text].
  Future<List<double>> embed(
    String text, {
    required String model,
    OmniCancelToken? cancelToken,
  }) async {
    final (targets, _) = _orderedTargets(model);
    final (target, provider) = targets.first;
    return provider.embed(
      _client,
      model: target.model,
      text: text,
      cancelToken: cancelToken,
    );
  }

  /// Generates dense embeddings for [texts], using [AiBatchEmbedProvider]
  /// when available on the target provider.
  Future<List<List<double>>> embedBatch(
    List<String> texts, {
    required String model,
    OmniCancelToken? cancelToken,
  }) async {
    if (texts.isEmpty) return const [];
    final (targets, _) = _orderedTargets(model);
    final (target, provider) = targets.first;
    if (provider is AiBatchEmbedProvider) {
      return provider.embedBatch(
        _client,
        model: target.model,
        texts: texts,
        cancelToken: cancelToken,
      );
    }
    return Future.wait([
      for (final t in texts)
        provider.embed(
          _client,
          model: target.model,
          text: t,
          cancelToken: cancelToken,
        ),
    ]);
  }

  /// Returns a reusable [TextEmbedder] bound to [model].
  TextEmbedder embedder(String model) =>
      (text) => embed(text, model: model);

  /// Returns a reusable [BatchTextEmbedder] bound to [model].
  BatchTextEmbedder batchEmbedder(String model) =>
      (texts) => embedBatch(texts, model: model);

  /// Splits [text] with [TextSplitter], batch-embeds every chunk via
  /// [embedModel], and indexes them into [store] with optional [metadata].
  Future<List<VectorDocument>> indexText({
    required AiVectorStore store,
    required String documentId,
    required String text,
    required String embedModel,
    Map<String, Object?> metadata = const {},
    int chunkSize = 800,
    int overlap = 120,
    OmniCancelToken? cancelToken,
  }) async {
    final chunks = TextSplitter.split(
      text,
      chunkSize: chunkSize,
      overlap: overlap,
    );
    if (chunks.isEmpty) return const [];
    final vectors = await embedBatch(
      chunks,
      model: embedModel,
      cancelToken: cancelToken,
    );
    final docs = <VectorDocument>[
      for (var i = 0; i < chunks.length; i++)
        VectorDocument(
          id: '$documentId#chunk_$i',
          text: chunks[i],
          embedding: vectors[i],
          metadata: {...metadata, 'documentId': documentId, 'chunkIndex': i},
        ),
    ];
    await store.upsertAll(docs);
    return docs;
  }

  /// Answers [question] grounded by top retrieved [VectorSearchHit] documents
  /// (RAG helper).
  Future<String> askWithContext({
    required String question,
    required List<VectorSearchHit> context,
    String? model,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) {
    final buf = StringBuffer();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buf.writeln(systemPrompt);
      buf.writeln();
    }
    buf.writeln('Use the following retrieved context to answer accurately:');
    for (var i = 0; i < context.length; i++) {
      final hit = context[i];
      buf.writeln(
        '[Source ${i + 1} (${hit.document.id})]: ${hit.document.text}',
      );
    }
    return ask(
      question,
      model: model,
      systemPrompt: buf.toString(),
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Transcribes spoken audio bytes into text via an [AiMediaProvider]
  /// (OpenAI Whisper, Gemini audio, Mock, or custom).
  Future<AiTranscriptionResult> transcribeAudio(
    Uint8List audioBytes, {
    required String mimeType,
    String? model,
    String? language,
    String? prompt,
    OmniCancelToken? cancelToken,
  }) => _runMedia(
    model: model,
    actionName: 'audio transcription',
    call: (provider, target) => provider.transcribeAudio(
      _client,
      audioBytes: audioBytes,
      mimeType: mimeType,
      model: target.model,
      language: language,
      prompt: prompt,
      cancelToken: cancelToken,
    ),
  );

  /// Synthesizes text into spoken audio bytes via an [AiMediaProvider]
  /// (OpenAI TTS, Mock, or custom).
  Future<AiSpeechResult> generateSpeech(
    String text, {
    String? model,
    String voice = 'alloy',
    String format = 'mp3',
    OmniCancelToken? cancelToken,
  }) => _runMedia(
    model: model,
    actionName: 'speech synthesis',
    call: (provider, target) => provider.generateSpeech(
      _client,
      text: text,
      model: target.model,
      voice: voice,
      format: format,
      cancelToken: cancelToken,
    ),
  );

  /// Generates one or more images from [prompt] via an [AiMediaProvider]
  /// (OpenAI Images, Gemini Imagen, Mock, or custom).
  Future<List<AiGeneratedImage>> generateImage(
    String prompt, {
    String? model,
    String size = '1024x1024',
    int n = 1,
    OmniCancelToken? cancelToken,
  }) => _runMedia(
    model: model,
    actionName: 'image generation',
    call: (provider, target) => provider.generateImage(
      _client,
      prompt: prompt,
      model: target.model,
      size: size,
      n: n,
      cancelToken: cancelToken,
    ),
  );

  /// Sends the same [prompt] in parallel to multiple [models] (e.g. comparing
  /// speed/quality across GPT, Gemini, Claude & local Llama).
  Future<Map<String, AiResponse>> compare(
    String prompt, {
    required List<String> models,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async {
    final messages = [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        AiMessage.system(systemPrompt),
      AiMessage.user(prompt),
    ];
    final entries = await Future.wait([
      for (final m in models)
        chat(
          messages,
          model: m,
          options: options,
          cancelToken: cancelToken,
        ).then((r) => MapEntry(m, r)),
    ]);
    return {for (final e in entries) e.key: e.value};
  }

  /// Opens a bidirectional WebSocket AI Realtime session (`OpenAI Realtime` or
  /// `Gemini Live`).
  Future<AiRealtimeSession> openRealtime({
    String? model,
    String? systemPrompt,
    Map<String, Object?> extra = const {},
  }) {
    final (resolved, _) = _orderedTargets(model);
    for (final (target, provider) in resolved) {
      if (provider.supportsRealtime) {
        return provider.openRealtime(
          _client,
          model: target.model,
          systemPrompt: systemPrompt,
          extra: extra,
        );
      }
    }
    throw UnsupportedError(
      'None of the target providers for "${model ?? defaultModel}" support '
      'bidirectional WebSocket realtime sessions.',
    );
  }

  /// Closes internal telemetry resources.
  Future<void> close() async {
    await usage.close();
    if (!_telemetry.isClosed) await _telemetry.close();
  }

  Future<R> _runMedia<R>({
    required String? model,
    required String actionName,
    required Future<R> Function(AiMediaProvider provider, AiTarget target) call,
  }) async {
    final (targets, _) = _orderedTargets(model);
    Object? lastError;
    for (final (target, provider) in targets) {
      if (provider is! AiMediaProvider) continue;
      try {
        return await call(provider, target);
      } catch (e) {
        lastError = e;
        _recordFailureCooldown(target, e);
        if (!_canFailover(e)) rethrow;
      }
    }
    if (lastError != null) throw lastError;
    throw UnsupportedError(
      'None of the target providers for "${model ?? defaultModel}" support $actionName.',
    );
  }

  Future<AiResponse> _generateWithFallback({
    required String? model,
    required List<AiMessage> messages,
    required AiRequestOptions options,
    required OmniCancelToken? cancelToken,
  }) async {
    usage.ensureWithinBudget();
    final (targets, route) = _orderedTargets(model);

    if (route != null &&
        route.strategy == AiRoutingStrategy.hedged &&
        targets.length > 1) {
      return _generateHedged(
        targets: targets,
        hedgeDelay: route.hedgeDelay,
        messages: messages,
        options: options,
        cancelToken: cancelToken,
      );
    }

    Object? lastError;
    for (var i = 0; i < targets.length; i++) {
      final (target, provider) = targets[i];
      try {
        return await _attemptSingleTarget(
          target: target,
          provider: provider,
          messages: messages,
          options: options,
          usedFallback: i > 0,
          cancelToken: cancelToken,
        );
      } catch (e) {
        lastError = e;
        final isCancelled =
            (cancelToken?.isCancelled ?? false) ||
            (e is OmniNetworkException && e.isCancelled);
        if (isCancelled || !_canFailover(e)) {
          rethrow;
        }
      }
    }
    throw lastError ?? StateError('No AI targets available');
  }

  Future<AiResponse> _generateHedged({
    required List<(AiTarget, AiProvider)> targets,
    required Duration hedgeDelay,
    required List<AiMessage> messages,
    required AiRequestOptions options,
    required OmniCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const CancelledFailure();
    }
    final completer = Completer<AiResponse>();
    var settled = false;
    var activeCount = 1;
    var nextIndex = 1;
    Object? lastError;
    Timer? hedgeTimer;
    final childTokens = <OmniCancelToken>[];
    void Function()? detachParent;

    void cancelChildren() {
      for (final c in childTokens) {
        c.cancel();
      }
    }

    void settleError(Object error) {
      if (settled) return;
      settled = true;
      hedgeTimer?.cancel();
      detachParent?.call();
      cancelChildren();
      completer.completeError(error);
    }

    detachParent = cancelToken?.attach(
      () => settleError(const CancelledFailure()),
    );

    void startAttempt(int index) {
      final (target, provider) = targets[index];
      final attemptToken = OmniCancelToken();
      childTokens.add(attemptToken);
      if (cancelToken?.isCancelled ?? false) {
        attemptToken.cancel();
      }
      _attemptSingleTarget(
        target: target,
        provider: provider,
        messages: messages,
        options: options,
        usedFallback: index > 0,
        cancelToken: attemptToken,
      ).then(
        (res) {
          if (settled) return;
          settled = true;
          hedgeTimer?.cancel();
          detachParent?.call();
          for (final c in childTokens) {
            if (!identical(c, attemptToken)) c.cancel();
          }
          completer.complete(res);
        },
        onError: (Object err) {
          if (settled) return;
          lastError = err;
          activeCount--;
          final isCancelled =
              (cancelToken?.isCancelled ?? false) ||
              (err is OmniNetworkException && err.isCancelled);
          if (isCancelled) {
            settleError(const CancelledFailure());
            return;
          }
          if (nextIndex < targets.length && _canFailover(err)) {
            if (index == 0) hedgeTimer?.cancel();
            final candidate = nextIndex++;
            activeCount++;
            startAttempt(candidate);
            return;
          }
          if (activeCount <= 0) {
            settleError(lastError!);
          }
        },
      );
    }

    hedgeTimer = Timer(hedgeDelay, () {
      if (settled || nextIndex != 1 || nextIndex >= targets.length) return;
      final candidate = nextIndex++;
      activeCount++;
      startAttempt(candidate);
    });
    startAttempt(0);

    return completer.future;
  }

  Future<AiResponse> _attemptSingleTarget({
    required AiTarget target,
    required AiProvider provider,
    required List<AiMessage> messages,
    required AiRequestOptions options,
    required bool usedFallback,
    required OmniCancelToken? cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final res = await provider.generate(
        _client,
        model: target.model,
        messages: messages,
        options: _mergeTargetOptions(target.options, options),
        cancelToken: cancelToken,
      );
      _observedLatency[_targetKey(target)] = sw.elapsed;
      final pricedUsage = usage.record(res.model, res.usage);
      final finalRes = AiResponse(
        text: res.text,
        thinking: res.thinking,
        toolCalls: res.toolCalls,
        usage: pricedUsage,
        model: res.model,
        providerId: res.providerId,
        finishReason: res.finishReason,
        latency: res.latency == Duration.zero ? sw.elapsed : res.latency,
        raw: res.raw,
      );
      _emitLog(
        providerId: provider.id,
        model: finalRes.model,
        usage: pricedUsage,
        latency: finalRes.latency,
        messages: messages,
        responseText: finalRes.text,
        usedFallback: usedFallback,
      );
      return finalRes;
    } catch (e) {
      _recordFailureCooldown(target, e);
      _emitLog(
        providerId: provider.id,
        model: target.model,
        usage: AiUsage.zero,
        latency: sw.elapsed,
        messages: messages,
        error: '$e',
        usedFallback: usedFallback,
      );
      rethrow;
    }
  }

  static Future<void> _executeToolsIntoHistory(
    List<AiToolCallPart> calls,
    Map<String, AiTool> toolMap,
    List<AiMessage> history,
  ) async {
    for (final call in calls) {
      final tool = toolMap[call.name];
      if (tool == null) {
        history.add(
          AiMessage.toolResult(
            callId: call.id,
            name: call.name,
            result: 'Unknown tool "${call.name}"',
            isError: true,
          ),
        );
        continue;
      }
      try {
        final output = await tool.execute(call.arguments);
        history.add(
          AiMessage.toolResult(
            callId: call.id,
            name: call.name,
            result: output,
          ),
        );
      } catch (e) {
        history.add(
          AiMessage.toolResult(
            callId: call.id,
            name: call.name,
            result: '$e',
            isError: true,
          ),
        );
      }
    }
  }

  (List<(AiTarget, AiProvider)>, AiModelRoute?) _orderedTargets(
    String? requested,
  ) {
    final key = requested ?? defaultModel;
    if (key == null || key.isEmpty) {
      throw const RequestFailure(
        'No AI model specified and no AiConfig.defaultModel configured',
      );
    }

    final route = _routes[key];
    final List<(AiTarget, AiProvider)> resolved;
    if (route != null) {
      resolved = [
        for (final t in route.targets)
          (
            t,
            _providers[t.provider] ??
                (throw RequestFailure(
                  'AI provider "${t.provider}" in route "$key" is not registered',
                )),
          ),
      ];
    } else {
      final colon = key.indexOf(':');
      if (colon > 0) {
        final pId = key.substring(0, colon);
        final modelName = key.substring(colon + 1);
        final provider = _providers[pId];
        if (provider != null) {
          resolved = [(AiTarget(pId, model: modelName), provider)];
        } else {
          resolved = const [];
        }
      } else if (_providers.length == 1) {
        final entry = _providers.entries.first;
        resolved = [(AiTarget(entry.key, model: key), entry.value)];
      } else {
        resolved = const [];
      }
    }

    if (resolved.isEmpty) {
      throw RequestFailure(
        'Unknown AI model/route "$key"; pass a configured route alias or '
        '"provider:model" (available providers: ${_providers.keys.join(', ')})',
      );
    }

    final now = DateTime.now();
    _cooldownUntil.removeWhere((_, until) => !until.isAfter(now));
    final ready = <(AiTarget, AiProvider)>[];
    final cooled = <(AiTarget, AiProvider)>[];
    for (final pair in resolved) {
      if (_cooldownUntil.containsKey(_targetKey(pair.$1))) {
        cooled.add(pair);
      } else {
        ready.add(pair);
      }
    }

    if (route != null && ready.length > 1) {
      switch (route.strategy) {
        case AiRoutingStrategy.lowestLatency:
          ready.sort((a, b) {
            final la = _observedLatency[_targetKey(a.$1)] ?? Duration.zero;
            final lb = _observedLatency[_targetKey(b.$1)] ?? Duration.zero;
            return la.compareTo(lb);
          });
        case AiRoutingStrategy.lowestCost:
          ready.sort(
            (a, b) => _estimatedCostWeight(
              a.$1,
            ).compareTo(_estimatedCostWeight(b.$1)),
          );
        case AiRoutingStrategy.ordered || AiRoutingStrategy.hedged:
          break;
      }
    }

    return ([...ready, ...cooled], route);
  }

  double _estimatedCostWeight(AiTarget target) {
    final c =
        usage.pricing[target.model] ??
        usage.pricing[_targetKey(target)] ??
        const AiModelCost(inputPerMillionUsd: 999, outputPerMillionUsd: 999);
    return c.inputPerMillionUsd + c.outputPerMillionUsd;
  }

  static String _targetKey(AiTarget target) =>
      '${target.provider}:${target.model}';

  void _recordFailureCooldown(AiTarget target, Object error) {
    if (error is HttpFailure && error.statusCode == 429) {
      final retryHeader = error.response.headers['retry-after'];
      Duration? duration;
      if (retryHeader != null) {
        final secs = int.tryParse(retryHeader.trim());
        if (secs != null && secs > 0) {
          duration = Duration(seconds: secs);
        } else {
          final dt = parseHttpDate(retryHeader);
          if (dt != null) {
            final diff = dt.difference(DateTime.now().toUtc());
            if (diff > Duration.zero) duration = diff;
          }
        }
      }
      _cooldownUntil[_targetKey(target)] = DateTime.now().add(
        duration ?? _rateLimitCooldown,
      );
    }
  }

  static AiRequestOptions _mergeTargetOptions(
    AiRequestOptions? targetOpts,
    AiRequestOptions callOpts,
  ) {
    if (targetOpts == null) return callOpts;
    return AiRequestOptions(
      temperature: callOpts.temperature ?? targetOpts.temperature,
      maxTokens: callOpts.maxTokens ?? targetOpts.maxTokens,
      topP: callOpts.topP ?? targetOpts.topP,
      stopSequences: callOpts.stopSequences.isNotEmpty
          ? callOpts.stopSequences
          : targetOpts.stopSequences,
      responseSchema: callOpts.responseSchema ?? targetOpts.responseSchema,
      jsonMode: callOpts.jsonMode || targetOpts.jsonMode,
      tools: callOpts.tools.isNotEmpty ? callOpts.tools : targetOpts.tools,
      promptCaching: callOpts.promptCaching || targetOpts.promptCaching,
      useSemanticCache:
          callOpts.useSemanticCache && targetOpts.useSemanticCache,
      extra: {...targetOpts.extra, ...callOpts.extra},
    );
  }

  static bool _canFailover(Object error) {
    if (error is HttpFailure) {
      final code = error.statusCode;
      return code == 408 || code == 429 || code >= 500;
    }
    if (error is TimeoutFailure ||
        error is ConnectionFailure ||
        error is CircuitOpenFailure) {
      return true;
    }
    return false;
  }

  void _emitLog({
    required String providerId,
    required String model,
    required AiUsage usage,
    required Duration latency,
    required List<AiMessage> messages,
    String? responseText,
    String? error,
    required bool usedFallback,
  }) {
    if (_telemetry.isClosed) return;
    final redactor = _client.redactor;
    final lastPrompt = messages.isEmpty
        ? ''
        : redactor.text(messages.last.text);
    final safeResponse = responseText == null
        ? null
        : redactor.text(responseText);
    final safeError = error == null ? null : redactor.text(error);
    String clip(String s) => s.length <= 120 ? s : '${s.substring(0, 117)}...';
    _telemetry.add(
      AiCallLogRecord(
        providerId: providerId,
        model: model,
        usage: usage,
        latency: latency,
        timestamp: DateTime.now(),
        promptPreview: lastPrompt.isEmpty ? null : clip(lastPrompt),
        responsePreview: safeResponse == null || safeResponse.isEmpty
            ? null
            : clip(safeResponse),
        error: safeError,
        usedFallback: usedFallback,
      ),
    );
  }

  static String? _cacheKeyPrompt(List<AiMessage> history) {
    if (history.isEmpty) return null;
    if (history.any((m) => m.parts.any((p) => p is! AiTextPart))) {
      return null;
    }
    return [for (final m in history) '${m.role.name}:${m.text}'].join('\n');
  }

  static T _decodeStructured<T>(
    String rawText,
    T Function(Map<String, dynamic> json) decoder,
  ) {
    final clean = _stripJsonCodeFence(rawText);
    try {
      final decoded = jsonDecode(clean);
      if (decoded is! Map) {
        throw const DecodeFailure(
          'Expected JSON object from structured AI call',
        );
      }
      return decoder(Map<String, dynamic>.from(decoded));
    } on FormatException catch (e) {
      throw DecodeFailure('Invalid AI JSON output: $e', cause: e);
    } on TypeError catch (e) {
      throw DecodeFailure('Structured AI type mismatch: $e', cause: e);
    }
  }

  static String _stripJsonCodeFence(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    final firstNewline = trimmed.indexOf('\n');
    if (firstNewline < 0) return trimmed;
    var body = trimmed.substring(firstNewline + 1).trim();
    if (body.endsWith('```')) {
      body = body.substring(0, body.length - 3).trim();
    }
    return body;
  }

  static Map<String, dynamic>? _tryParsePartialJsonObject(String raw) {
    var clean = _stripJsonCodeFence(raw).trim();
    final braceStart = clean.indexOf('{');
    if (braceStart < 0) return null;
    clean = clean.substring(braceStart);

    final direct = _decodeMapOrNull(clean);
    if (direct != null) return direct;

    // Best-effort close unclosed string, trailing comma, and open brackets/braces.
    final stack = <String>[];
    var inString = false;
    var escaped = false;
    for (var i = 0; i < clean.length; i++) {
      final ch = clean[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        stack.add('}');
      } else if (ch == '[') {
        stack.add(']');
      } else if ((ch == '}' || ch == ']') && stack.isNotEmpty) {
        stack.removeLast();
      }
    }

    final repaired = StringBuffer(clean);
    if (inString) {
      if (escaped) repaired.write(' ');
      repaired.write('"');
    }
    var candidate = repaired.toString().trimRight();
    if (candidate.endsWith(',')) {
      candidate = candidate.substring(0, candidate.length - 1);
    } else if (candidate.endsWith(':')) {
      candidate = '${candidate}null';
    }
    candidate = '$candidate${stack.reversed.join()}';
    return _decodeMapOrNull(candidate);
  }

  static Map<String, dynamic>? _decodeMapOrNull(String candidate) {
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }
}
