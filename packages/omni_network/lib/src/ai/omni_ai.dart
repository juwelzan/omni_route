import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../core/cancel_token.dart';
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import 'ai_models.dart';
import 'ai_provider.dart';
import 'vector_store.dart';

/// Configuration passed to `OmniNetwork(ai: ...)` or `OmniApiHub(ai: ...)`.
@immutable
final class AiConfig {
  /// Creates multi-AI routing and budget configuration.
  const AiConfig({
    this.defaultModel,
    this.providers = const {},
    this.routes = const {},
    this.pricing = const {},
    this.maxSessionBudgetUsd,
    this.defaultTools = const [],
    this.maxToolRounds = 5,
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
/// Ollama, OpenAI-compatible servers, automatic failover routes, SSE/WebSocket
/// streaming, tool calling, structured JSON output, embeddings/RAG & usage caps.
final class OmniAi {
  /// Creates an AI coordinator backed by `OmniNetwork` [client].
  OmniAi({
    required OmniNetwork client,
    AiConfig config = const AiConfig(),
  }) : _client = client, // ignore: prefer_initializing_formals
       _providers = Map.of(config.providers),
       _routes = Map.of(config.routes),
       defaultModel = config.defaultModel,
       _defaultTools = List.unmodifiable(config.defaultTools),
       _defaultMaxToolRounds = config.maxToolRounds,
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
    required this.usage,
    required StreamController<AiCallLogRecord> telemetryController,
  }) : _client = client, // ignore: prefer_initializing_formals
       _providers = providers, // ignore: prefer_initializing_formals
       _routes = routes, // ignore: prefer_initializing_formals
       _defaultTools = defaultTools, // ignore: prefer_initializing_formals
       _defaultMaxToolRounds = defaultMaxToolRounds, // ignore: prefer_initializing_formals
       _telemetry = telemetryController;

  final OmniNetwork _client;
  final Map<String, AiProvider> _providers;
  final Map<String, AiModelRoute> _routes;

  /// Active default model alias or `'provider:model'`, mutable at runtime.
  String? defaultModel;

  final List<AiTool> _defaultTools;
  final int _defaultMaxToolRounds;

  /// Cumulative token and USD usage tracker for this AI client.
  final AiUsageTracker usage;

  StreamController<AiCallLogRecord> _telemetry =
      StreamController<AiCallLogRecord>.broadcast();

  /// Broadcast stream of redacted AI call telemetry (used by `OmniInspector`).
  Stream<AiCallLogRecord> get telemetry => _telemetry.stream;

  /// Registered provider ids.
  Map<String, AiProvider> get providers => Map.unmodifiable(_providers);

  /// Configured model aliases / fallback routes.
  Map<String, AiModelRoute> get routes => Map.unmodifiable(_routes);

  /// Registers or replaces an [AiProvider] dynamically at runtime.
  void registerProvider(String id, AiProvider provider) {
    _providers[id] = provider;
  }

  /// Registers or replaces a logical route alias (e.g. `'smart'`, `'fast'`).
  void setRoute(String alias, AiModelRoute route) {
    _routes[alias] = route;
  }

  /// Replaces the entire [AiConfig] (routes & providers) dynamically at runtime.
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
  }

  /// Returns a view of this [OmniAi] with [tools] automatically attached to all
  /// calls (`ask`, `chat`, `stream`).
  OmniAi withTools(
    List<AiTool> tools, {
    int? maxToolRounds,
  }) => OmniAi._scoped(
    client: _client,
    providers: _providers,
    routes: _routes,
    defaultModel: defaultModel,
    defaultTools: List.unmodifiable([..._defaultTools, ...tools]),
    defaultMaxToolRounds: maxToolRounds ?? _defaultMaxToolRounds,
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

  /// Performs a full multi-turn AI chat request with automatic fallback routing
  /// and multi-round tool-calling execution.
  Future<AiResponse> chat(
    List<AiMessage> messages, {
    String? model,
    AiRequestOptions options = const AiRequestOptions(),
    int? maxToolRounds,
    OmniCancelToken? cancelToken,
  }) async {
    final effectiveTools = options.tools.isNotEmpty ? options.tools : _defaultTools;
    final effectiveOptions = options.tools.isNotEmpty
        ? options
        : options.copyWith(tools: effectiveTools);
    final toolMap = {for (final t in effectiveTools) t.name: t};
    final history = [...messages];
    final roundsLimit = maxToolRounds ?? _defaultMaxToolRounds;

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
        return AiResponse(
          text: response.text,
          thinking: response.thinking,
          toolCalls: response.toolCalls,
          usage: aggregatedUsage,
          model: response.model,
          providerId: response.providerId,
          finishReason: response.finishReason,
          latency: totalSw.elapsed,
          raw: response.raw,
        );
      }

      history.add(response.toMessage());
      for (final call in response.toolCalls) {
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
  }

  /// Streams incremental response tokens for a single [prompt].
  Stream<AiStreamEvent> stream(
    String prompt, {
    String? model,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) => streamChat(
    [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        AiMessage.system(systemPrompt),
      AiMessage.user(prompt),
    ],
    model: model,
    options: options,
    cancelToken: cancelToken,
  );

  /// Streams incremental response tokens for a multi-turn [messages] list,
  /// failing over cleanly if the primary target fails before emitting output.
  Stream<AiStreamEvent> streamChat(
    List<AiMessage> messages, {
    String? model,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async* {
    usage.ensureWithinBudget();
    final effectiveTools = options.tools.isNotEmpty ? options.tools : _defaultTools;
    final baseOptions = options.tools.isNotEmpty
        ? options
        : options.copyWith(tools: effectiveTools);
    final resolvedTargets = _resolveRoute(model);
    Object? lastError;

    for (var i = 0; i < resolvedTargets.length; i++) {
      final (target, provider) = resolvedTargets[i];
      final targetOptions = _mergeTargetOptions(target.options, baseOptions);
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
            final pricedUsage = usage.record(ev.response.model, ev.response.usage);
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
  /// directly into type [T] via [decoder].
  Future<T> generateObject<T>(
    String prompt, {
    required T Function(Map<String, dynamic> json) decoder,
    Map<String, Object?>? schema,
    String? model,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async {
    final res = await ask(
      prompt,
      model: model,
      systemPrompt: systemPrompt,
      options: options.copyWith(
        jsonMode: true,
        responseSchema: schema,
      ),
      cancelToken: cancelToken,
    );
    final clean = _stripJsonCodeFence(res);
    try {
      final decoded = jsonDecode(clean);
      if (decoded is! Map) {
        throw const DecodeFailure('Expected JSON object from structured AI call');
      }
      return decoder(Map<String, dynamic>.from(decoded));
    } on FormatException catch (e) {
      throw DecodeFailure('Invalid AI JSON output: $e', cause: e);
    }
  }

  /// Generates a dense embedding vector for [text].
  Future<List<double>> embed(
    String text, {
    required String model,
    OmniCancelToken? cancelToken,
  }) async {
    final targets = _resolveRoute(model);
    final (target, provider) = targets.first;
    return provider.embed(
      _client,
      model: target.model,
      text: text,
      cancelToken: cancelToken,
    );
  }

  /// Returns a reusable [TextEmbedder] bound to [model] (ideal for
  /// `MemoryVectorStore` / `FileVectorStore`).
  TextEmbedder embedder(String model) =>
      (text) => embed(text, model: model);

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
      buf.writeln('[Source ${i + 1} (${hit.document.id})]: ${hit.document.text}');
    }
    return ask(
      question,
      model: model,
      systemPrompt: buf.toString(),
      options: options,
      cancelToken: cancelToken,
    );
  }

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
    final resolved = _resolveRoute(model);
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

  Future<AiResponse> _generateWithFallback({
    required String? model,
    required List<AiMessage> messages,
    required AiRequestOptions options,
    required OmniCancelToken? cancelToken,
  }) async {
    usage.ensureWithinBudget();
    final resolvedTargets = _resolveRoute(model);
    Object? lastError;

    for (var i = 0; i < resolvedTargets.length; i++) {
      final (target, provider) = resolvedTargets[i];
      final sw = Stopwatch()..start();
      try {
        final res = await provider.generate(
          _client,
          model: target.model,
          messages: messages,
          options: _mergeTargetOptions(target.options, options),
          cancelToken: cancelToken,
        );
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
          usedFallback: i > 0,
        );
        return finalRes;
      } catch (e) {
        lastError = e;
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
        if (isCancelled || !_canFailover(e)) {
          rethrow;
        }
      }
    }
    throw lastError ?? StateError('No AI targets available');
  }

  List<(AiTarget, AiProvider)> _resolveRoute(String? requested) {
    final key = requested ?? defaultModel;
    if (key == null || key.isEmpty) {
      throw const RequestFailure(
        'No AI model specified and no AiConfig.defaultModel configured',
      );
    }
    if (_routes[key] case final route?) {
      return [
        for (final t in route.targets)
          (
            t,
            _providers[t.provider] ??
                (throw RequestFailure(
                  'AI provider "${t.provider}" in route "$key" is not registered',
                )),
          ),
      ];
    }
    final colon = key.indexOf(':');
    if (colon > 0) {
      final pId = key.substring(0, colon);
      final modelName = key.substring(colon + 1);
      final provider = _providers[pId];
      if (provider != null) {
        return [(AiTarget(pId, model: modelName), provider)];
      }
    }
    if (_providers.length == 1) {
      final entry = _providers.entries.first;
      return [(AiTarget(entry.key, model: key), entry.value)];
    }
    throw RequestFailure(
      'Unknown AI model/route "$key"; pass a configured route alias or '
      '"provider:model" (available providers: ${_providers.keys.join(', ')})',
    );
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
    final lastPrompt = messages.isEmpty ? '' : messages.last.text;
    String clip(String s) => s.length <= 120 ? s : '${s.substring(0, 117)}...';
    _telemetry.add(
      AiCallLogRecord(
        providerId: providerId,
        model: model,
        usage: usage,
        latency: latency,
        timestamp: DateTime.now(),
        promptPreview: lastPrompt.isEmpty ? null : clip(lastPrompt),
        responsePreview: responseText == null || responseText.isEmpty
            ? null
            : clip(responseText),
        error: error,
        usedFallback: usedFallback,
      ),
    );
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
}
