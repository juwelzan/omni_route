import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../endpoint/endpoint.dart';

/// Role of a participant in an AI conversation.
enum AiRole {
  /// System-level developer / persona instructions.
  system,

  /// Human / user prompt or multimodal input.
  user,

  /// AI model reply (including optional tool invocations).
  assistant,

  /// Output returned back to the model after executing an [AiTool].
  tool,
}

/// One typed piece of content inside an [AiMessage] (text, image, audio,
/// document, tool call, or tool result).
@immutable
sealed class AiPart {
  const AiPart();

  /// Plain text segment.
  const factory AiPart.text(String text) = AiTextPart;

  /// Raw image bytes (`image/jpeg`, `image/png`, `image/webp`, etc.).
  const factory AiPart.imageBytes(Uint8List bytes, {String mimeType}) =
      AiImageBytesPart;

  /// Remote HTTPS or `data:` image URL.
  const factory AiPart.imageUrl(String url, {String? detail}) = AiImageUrlPart;

  /// Raw audio bytes (`audio/wav`, `audio/mp3`, etc.).
  const factory AiPart.audioBytes(Uint8List bytes, {String mimeType}) =
      AiAudioBytesPart;

  /// Arbitrary document/file bytes (PDF, CSV, plain text, etc.).
  const factory AiPart.document(
    Uint8List bytes, {
    required String mimeType,
    String? name,
  }) = AiDocumentPart;

  /// Model-requested tool/function invocation.
  const factory AiPart.toolCall({
    required String id,
    required String name,
    required Map<String, Object?> arguments,
  }) = AiToolCallPart;

  /// Result returned after executing a tool call.
  const factory AiPart.toolResult({
    required String callId,
    required String name,
    required Object? result,
    bool isError,
  }) = AiToolResultPart;

  /// Serializes this part to JSON.
  Map<String, Object?> toJson();

  /// Restores a part written by [toJson].
  static AiPart fromJson(Map<String, Object?> json) {
    final kind = json['kind'] as String?;
    return switch (kind) {
      'text' => AiTextPart(json['text'] as String? ?? ''),
      'imageBytes' => AiImageBytesPart(
        base64Decode(json['data']! as String),
        mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      ),
      'imageUrl' => AiImageUrlPart(
        json['url']! as String,
        detail: json['detail'] as String?,
      ),
      'audioBytes' => AiAudioBytesPart(
        base64Decode(json['data']! as String),
        mimeType: json['mimeType'] as String? ?? 'audio/wav',
      ),
      'document' => AiDocumentPart(
        base64Decode(json['data']! as String),
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        name: json['name'] as String?,
      ),
      'toolCall' => AiToolCallPart(
        id: json['id']! as String,
        name: json['name']! as String,
        arguments: Map<String, Object?>.from(
          json['arguments'] as Map? ?? const {},
        ),
      ),
      'toolResult' => AiToolResultPart(
        callId: json['callId']! as String,
        name: json['name']! as String,
        result: json['result'],
        isError: json['isError'] as bool? ?? false,
      ),
      _ => AiTextPart(json['text']?.toString() ?? ''),
    };
  }
}

/// Text content segment inside an [AiMessage].
final class AiTextPart extends AiPart {
  /// Creates a text part.
  const AiTextPart(this.text);

  /// UTF-8 text.
  final String text;

  @override
  Map<String, Object?> toJson() => {'kind': 'text', 'text': text};
}

/// In-memory image segment inside an [AiMessage].
final class AiImageBytesPart extends AiPart {
  /// Creates an image-bytes part.
  const AiImageBytesPart(this.bytes, {this.mimeType = 'image/jpeg'});

  /// Raw encoded image bytes.
  final Uint8List bytes;

  /// MIME type (e.g. `image/png`).
  final String mimeType;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'imageBytes',
    'mimeType': mimeType,
    'data': base64Encode(bytes),
  };
}

/// Image URL segment inside an [AiMessage].
final class AiImageUrlPart extends AiPart {
  /// Creates an image-URL part.
  const AiImageUrlPart(this.url, {this.detail});

  /// Target image URL or `data:` URI.
  final String url;

  /// Optional provider detail hint (`'low'`, `'high'`, `'auto'`).
  final String? detail;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'imageUrl',
    'url': url,
    'detail': ?detail,
  };
}

/// Audio bytes segment inside an [AiMessage].
final class AiAudioBytesPart extends AiPart {
  /// Creates an audio part.
  const AiAudioBytesPart(this.bytes, {this.mimeType = 'audio/wav'});

  /// Raw audio bytes.
  final Uint8List bytes;

  /// Audio MIME type.
  final String mimeType;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'audioBytes',
    'mimeType': mimeType,
    'data': base64Encode(bytes),
  };
}

/// Binary/document segment inside an [AiMessage].
final class AiDocumentPart extends AiPart {
  /// Creates a document part.
  const AiDocumentPart(this.bytes, {required this.mimeType, this.name});

  /// Document bytes.
  final Uint8List bytes;

  /// Document MIME type (e.g. `application/pdf`).
  final String mimeType;

  /// Optional filename.
  final String? name;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'document',
    'mimeType': mimeType,
    'data': base64Encode(bytes),
    'name': ?name,
  };
}

/// Model-generated tool/function call request.
final class AiToolCallPart extends AiPart {
  /// Creates a tool call part.
  const AiToolCallPart({
    required this.id,
    required this.name,
    required this.arguments,
  });

  /// Provider-assigned call identifier used when returning [AiToolResultPart].
  final String id;

  /// Tool name matching [AiTool.name].
  final String name;

  /// Decoded JSON arguments passed to the tool.
  final Map<String, Object?> arguments;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'toolCall',
    'id': id,
    'name': name,
    'arguments': arguments,
  };
}

/// Execution output sent back to the model for [callId].
final class AiToolResultPart extends AiPart {
  /// Creates a tool result part.
  const AiToolResultPart({
    required this.callId,
    required this.name,
    required this.result,
    this.isError = false,
  });

  /// Matching [AiToolCallPart.id].
  final String callId;

  /// Tool name.
  final String name;

  /// JSON-encodable result or string description.
  final Object? result;

  /// Whether executing the tool threw or failed.
  final bool isError;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'toolResult',
    'callId': callId,
    'name': name,
    'result': result,
    'isError': isError,
  };
}

/// One turn in an AI prompt/conversation.
@immutable
final class AiMessage {
  /// Creates a message with explicit [role] and [parts].
  const AiMessage({
    required this.role,
    required this.parts,
    this.name,
    this.metadata = const {},
  });

  /// Creates a system instruction message.
  factory AiMessage.system(String text) =>
      AiMessage(role: AiRole.system, parts: [AiTextPart(text)]);

  /// Creates a plain-text user message.
  factory AiMessage.user(String text, {String? name}) =>
      AiMessage(role: AiRole.user, parts: [AiTextPart(text)], name: name);

  /// Creates a multimodal user message.
  factory AiMessage.userParts(List<AiPart> parts, {String? name}) =>
      AiMessage(role: AiRole.user, parts: parts, name: name);

  /// Creates an assistant text (and optional tool-call) message.
  factory AiMessage.assistant(
    String text, {
    List<AiToolCallPart> toolCalls = const [],
  }) => AiMessage(
    role: AiRole.assistant,
    parts: [if (text.isNotEmpty) AiTextPart(text), ...toolCalls],
  );

  /// Creates a tool-response turn for [callId].
  factory AiMessage.toolResult({
    required String callId,
    required String name,
    required Object? result,
    bool isError = false,
  }) => AiMessage(
    role: AiRole.tool,
    parts: [
      AiToolResultPart(
        callId: callId,
        name: name,
        result: result,
        isError: isError,
      ),
    ],
  );

  /// Participant role.
  final AiRole role;

  /// Ordered content segments.
  final List<AiPart> parts;

  /// Optional participant name.
  final String? name;

  /// Optional app metadata.
  final Map<String, Object?> metadata;

  /// Combined text of all [AiTextPart] entries in [parts].
  String get text => parts.whereType<AiTextPart>().map((p) => p.text).join();

  /// Tool calls requested inside this message.
  List<AiToolCallPart> get toolCalls =>
      parts.whereType<AiToolCallPart>().toList(growable: false);

  /// Converts to JSON for persistence.
  Map<String, Object?> toJson() => {
    'role': role.name,
    'parts': [for (final p in parts) p.toJson()],
    'name': ?name,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  /// Restores a message written by [toJson].
  factory AiMessage.fromJson(Map<String, Object?> json) => AiMessage(
    role: AiRole.values.byName(json['role'] as String? ?? 'user'),
    parts: [
      for (final raw in json['parts'] as List? ?? const [])
        if (raw is Map) AiPart.fromJson(Map<String, Object?>.from(raw)),
    ],
    name: json['name'] as String?,
    metadata: Map<String, Object?>.from(json['metadata'] as Map? ?? const {}),
  );
}

/// Token consumption and estimated USD cost for an AI call.
@immutable
final class AiUsage {
  /// Creates a usage summary.
  const AiUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.reasoningTokens = 0,
    int? totalTokens,
    this.estimatedCostUsd = 0.0,
  }) : totalTokens = totalTokens ?? (inputTokens + outputTokens);

  /// Zero usage constant.
  static const AiUsage zero = AiUsage();

  /// Prompt / input tokens.
  final int inputTokens;

  /// Completion / output tokens.
  final int outputTokens;

  /// Extended thinking / reasoning tokens, when reported by the provider.
  final int reasoningTokens;

  /// Total tokens charged (`input + output` or provider total).
  final int totalTokens;

  /// Estimated USD cost computed from model pricing rates.
  final double estimatedCostUsd;

  /// Combines two usage counters.
  AiUsage operator +(AiUsage other) => AiUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    reasoningTokens: reasoningTokens + other.reasoningTokens,
    totalTokens: totalTokens + other.totalTokens,
    estimatedCostUsd: estimatedCostUsd + other.estimatedCostUsd,
  );
}

/// Why an AI generation finished.
enum AiFinishReason {
  /// Completed naturally (`stop`, `end_turn`, `STOP`).
  stop,

  /// Reached [AiRequestOptions.maxTokens] output limit.
  length,

  /// Stopped to wait for client [AiToolCallPart] execution.
  toolCalls,

  /// Blocked or truncated by safety/content filter.
  contentFilter,

  /// Cancelled by the caller.
  cancelled,

  /// Any other provider-specific finish reason.
  other,
}

/// Complete response from an AI provider call.
@immutable
final class AiResponse {
  /// Creates an AI response.
  const AiResponse({
    required this.text,
    required this.model,
    required this.providerId,
    this.thinking,
    this.toolCalls = const [],
    this.usage = AiUsage.zero,
    this.finishReason = AiFinishReason.stop,
    this.latency = Duration.zero,
    this.raw,
  });

  /// Generated response text.
  final String text;

  /// Reasoning/thinking trace, if the model exposed one.
  final String? thinking;

  /// Tool calls requested by the model (non-empty when tools need to run).
  final List<AiToolCallPart> toolCalls;

  /// Token & USD usage statistics.
  final AiUsage usage;

  /// Concrete model ID that generated this response.
  final String model;

  /// Provider key (`openai`, `gemini`, `claude`, `local`, etc.).
  final String providerId;

  /// Completion reason.
  final AiFinishReason finishReason;

  /// End-to-end call duration.
  final Duration latency;

  /// Optional raw decoded provider JSON payload.
  final Map<String, Object?>? raw;

  /// Whether the model requested one or more tools before finishing.
  bool get hasToolCalls => toolCalls.isNotEmpty;

  /// Converts this response into an [AiMessage] ready to append to thread
  /// history.
  AiMessage toMessage() => AiMessage.assistant(text, toolCalls: toolCalls);
}

/// Incremental streaming event emitted by `OmniAi.stream(...)`.
@immutable
sealed class AiStreamEvent {
  const AiStreamEvent();
}

/// Reasoning / chain-of-thought delta chunk.
final class AiThinkingDelta extends AiStreamEvent {
  /// Creates a thinking delta.
  const AiThinkingDelta(this.text);

  /// Incremental reasoning text.
  final String text;
}

/// Visible response text delta chunk.
final class AiTextDelta extends AiStreamEvent {
  /// Creates a text delta.
  const AiTextDelta(this.text);

  /// Incremental text chunk.
  final String text;
}

/// Partial streamed tool call fragment.
final class AiToolCallDelta extends AiStreamEvent {
  /// Creates a tool call fragment event.
  const AiToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.argumentsChunk,
  });

  /// Index of the tool call in the current response turn.
  final int index;

  /// Tool call id (usually sent on first delta).
  final String? id;

  /// Function name (usually sent on first delta).
  final String? name;

  /// Partial JSON arguments fragment.
  final String? argumentsChunk;
}

/// Final event delivered once generation finishes cleanly.
final class AiCompleted extends AiStreamEvent {
  /// Creates a completion event wrapping the full [response].
  const AiCompleted(this.response);

  /// Aggregated final response with usage & tool calls.
  final AiResponse response;
}

/// Stream error event (used internally when routing/collecting streams).
final class AiStreamError extends AiStreamEvent {
  /// Creates a stream error wrapper.
  const AiStreamError(this.error, [this.stackTrace]);

  /// Error object.
  final Object error;

  /// Stack trace, if captured.
  final StackTrace? stackTrace;
}

/// Declarative callable tool exposed to AI models for function calling.
final class AiTool {
  /// Creates a function-backed tool.
  const AiTool.function({
    required this.name,
    required this.description,
    required this.execute,
    this.parameters = const {'type': 'object', 'properties': <String, Object?>{}},
  });

  /// Wraps an existing `OmniNetwork` [Endpoint] so an AI model can call typed
  /// backend APIs directly during tool loops.
  factory AiTool.fromEndpoint(
    Endpoint<Object?> endpoint, {
    required OmniNetwork client,
    String? name,
    String? description,
    Map<String, Object?>? parameters,
    Object? Function(Object? result)? serialize,
  }) {
    final resolvedName =
        name ?? endpoint.name ?? endpoint.path.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return AiTool.function(
      name: resolvedName,
      description:
          description ??
          endpoint.description ??
          'Calls ${endpoint.method.verb} ${endpoint.path}',
      parameters:
          parameters ??
          const {
            'type': 'object',
            'properties': {
              'path': {'type': 'object'},
              'query': {'type': 'object'},
              'body': {'type': 'object'},
            },
          },
      execute: (args) async {
        final pathArgs = args['path'] is Map
            ? Map<String, Object?>.from(args['path']! as Map)
            : args.map((k, v) => MapEntry(k, v));
        final queryArgs = args['query'] is Map
            ? Map<String, Object?>.from(args['query']! as Map)
            : const <String, Object?>{};
        final bodyArg = args['body'];
        final res = await client.call<Object?>(
          endpoint,
          path: pathArgs,
          query: queryArgs,
          body: bodyArg,
        );
        return serialize == null ? res : serialize(res);
      },
    );
  }

  /// Unique function name sent to the AI model (`[a-zA-Z0-9_-]+`).
  final String name;

  /// Natural language description helping the model decide when to call it.
  final String description;

  /// JSON Schema describing expected arguments.
  final Map<String, Object?> parameters;

  /// Handler invoked when the model emits a matching [AiToolCallPart].
  final FutureOr<Object?> Function(Map<String, Object?> arguments) execute;
}

/// Generation hyper-parameters shared across AI providers.
@immutable
final class AiRequestOptions {
  /// Creates AI generation options.
  const AiRequestOptions({
    this.temperature,
    this.maxTokens,
    this.topP,
    this.stopSequences = const [],
    this.responseSchema,
    this.jsonMode = false,
    this.tools = const [],
    this.extra = const {},
  });

  /// Sampling temperature (`0.0`..`2.0`).
  final double? temperature;

  /// Maximum output tokens to generate.
  final int? maxTokens;

  /// Nucleus sampling threshold.
  final double? topP;

  /// Custom stop sequences.
  final List<String> stopSequences;

  /// Optional JSON Schema enforcing structured JSON output.
  final Map<String, Object?>? responseSchema;

  /// Requests JSON-formatted output even without a formal schema.
  final bool jsonMode;

  /// Tools available for function calling in this request.
  final List<AiTool> tools;

  /// Additional provider-specific body fields merged cleanly.
  final Map<String, Object?> extra;

  /// Returns a copy with overridden fields.
  AiRequestOptions copyWith({
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
    Map<String, Object?>? responseSchema,
    bool? jsonMode,
    List<AiTool>? tools,
    Map<String, Object?>? extra,
  }) => AiRequestOptions(
    temperature: temperature ?? this.temperature,
    maxTokens: maxTokens ?? this.maxTokens,
    topP: topP ?? this.topP,
    stopSequences: stopSequences ?? this.stopSequences,
    responseSchema: responseSchema ?? this.responseSchema,
    jsonMode: jsonMode ?? this.jsonMode,
    tools: tools ?? this.tools,
    extra: extra ?? this.extra,
  );
}

/// Concrete provider + model target used inside an [AiModelRoute].
@immutable
final class AiTarget {
  /// Creates a target pointing to [model] on registered provider [provider].
  const AiTarget(this.provider, {required this.model, this.options});

  /// Provider key inside `OmniAi.providers` (e.g. `'openai'`, `'gemini'`,
  /// `'claude'`, `'local'`).
  final String provider;

  /// Model identifier understood by [provider] (e.g. `'gpt-4o'`,
  /// `'gemini-2.5-flash'`, `'claude-3-7-sonnet-latest'`).
  final String model;

  /// Optional default generation options for this target.
  final AiRequestOptions? options;
}

/// Ordered routing rule for a logical model alias (e.g. `'fast'`, `'smart'`),
/// supporting automatic failover across multiple AI models/providers.
@immutable
final class AiModelRoute {
  /// Creates a route trying [targets] in order until one succeeds.
  const AiModelRoute(this.targets);

  /// Single provider/model route without fallback.
  factory AiModelRoute.single(
    String provider, {
    required String model,
    AiRequestOptions? options,
  }) => AiModelRoute([AiTarget(provider, model: model, options: options)]);

  /// Fallback route trying each target in order on transient/provider failures
  /// (rate limits, 5xx, timeouts, network failures).
  factory AiModelRoute.fallback(List<AiTarget> targets) {
    if (targets.isEmpty) {
      throw ArgumentError.value(targets, 'targets', 'Cannot be empty');
    }
    return AiModelRoute(List.unmodifiable(targets));
  }

  /// Ordered list of provider+model candidates.
  final List<AiTarget> targets;
}

/// Per-million-token USD pricing used by [AiUsageTracker] to estimate cost.
@immutable
final class AiModelCost {
  /// Creates pricing rates per 1,000,000 tokens.
  const AiModelCost({
    required this.inputPerMillionUsd,
    required this.outputPerMillionUsd,
  });

  /// USD cost per 1M input tokens.
  final double inputPerMillionUsd;

  /// USD cost per 1M output tokens.
  final double outputPerMillionUsd;

  /// Computes estimated USD cost for the given token counts.
  double estimate(int inputTokens, int outputTokens) =>
      (inputTokens / 1000000.0) * inputPerMillionUsd +
      (outputTokens / 1000000.0) * outputPerMillionUsd;
}

/// Cumulative AI token/cost telemetry & optional session spend cap.
final class AiUsageTracker {
  /// Creates a tracker with optional [maxSessionBudgetUsd] limit and per-model
  /// [pricing] rates.
  AiUsageTracker({
    this.maxSessionBudgetUsd,
    this.pricing = const {},
  });

  /// Optional USD cap per session; throws [RequestFailure] before sending new
  /// requests once reached.
  final double? maxSessionBudgetUsd;

  /// Cost table keyed by model name (`'gpt-4o'`, `'gemini-2.5-flash'`, ...).
  final Map<String, AiModelCost> pricing;

  int _inputTokens = 0;
  int _outputTokens = 0;
  int _reasoningTokens = 0;
  double _totalCostUsd = 0.0;
  int _callCount = 0;
  final Map<String, AiUsage> _byModel = {};
  final StreamController<AiUsage> _changes = StreamController<AiUsage>.broadcast();

  /// Total input tokens recorded across all calls.
  int get totalInputTokens => _inputTokens;

  /// Total output tokens recorded across all calls.
  int get totalOutputTokens => _outputTokens;

  /// Total reasoning tokens recorded across all calls.
  int get totalReasoningTokens => _reasoningTokens;

  /// Total tokens (`input + output`).
  int get totalTokens => _inputTokens + _outputTokens;

  /// Estimated USD cost spent in this session.
  double get totalCostUsd => _totalCostUsd;

  /// Number of recorded AI calls.
  int get callCount => _callCount;

  /// Aggregated usage broken down by concrete model name.
  Map<String, AiUsage> get byModel => Map.unmodifiable(_byModel);

  /// Emits updated cumulative usage after each call.
  Stream<AiUsage> get changes => _changes.stream;

  /// Cumulative [AiUsage] snapshot.
  AiUsage get snapshot => AiUsage(
    inputTokens: _inputTokens,
    outputTokens: _outputTokens,
    reasoningTokens: _reasoningTokens,
    totalTokens: totalTokens,
    estimatedCostUsd: _totalCostUsd,
  );

  /// Ensures [maxSessionBudgetUsd] has not already been exceeded.
  void ensureWithinBudget([Uri? uri]) {
    final limit = maxSessionBudgetUsd;
    if (limit != null && _totalCostUsd >= limit) {
      throw RequestFailure(
        'AI session budget exceeded (\$${_totalCostUsd.toStringAsFixed(4)} / '
        '\$${limit.toStringAsFixed(4)})',
        uri: uri,
      );
    }
  }

  /// Computes cost for [model] and records [usage].
  AiUsage record(String model, AiUsage usage) {
    final rate = pricing[model];
    final cost = usage.estimatedCostUsd > 0 || rate == null
        ? usage.estimatedCostUsd
        : rate.estimate(usage.inputTokens, usage.outputTokens);
    final priced = AiUsage(
      inputTokens: usage.inputTokens,
      outputTokens: usage.outputTokens,
      reasoningTokens: usage.reasoningTokens,
      totalTokens: usage.totalTokens,
      estimatedCostUsd: cost,
    );
    _inputTokens += priced.inputTokens;
    _outputTokens += priced.outputTokens;
    _reasoningTokens += priced.reasoningTokens;
    _totalCostUsd += priced.estimatedCostUsd;
    _callCount++;
    final prev = _byModel[model] ?? AiUsage.zero;
    _byModel[model] = prev + priced;
    if (!_changes.isClosed) _changes.add(snapshot);
    return priced;
  }

  /// Resets cumulative statistics back to zero.
  void reset() {
    _inputTokens = 0;
    _outputTokens = 0;
    _reasoningTokens = 0;
    _totalCostUsd = 0.0;
    _callCount = 0;
    _byModel.clear();
  }

  /// Closes internal change stream.
  Future<void> close() => _changes.close();
}

/// Events emitted by an active WebSocket-backed AI Realtime session.
@immutable
sealed class AiRealtimeEvent {
  const AiRealtimeEvent();
}

/// Incremental text delta received from a live WebSocket AI session.
final class AiRealtimeTextDelta extends AiRealtimeEvent {
  /// Creates a realtime text delta.
  const AiRealtimeTextDelta(this.text);

  /// UTF-8 text chunk.
  final String text;
}

/// Incremental PCM/audio chunk received from a live WebSocket AI session.
final class AiRealtimeAudioDelta extends AiRealtimeEvent {
  /// Creates a realtime audio delta.
  const AiRealtimeAudioDelta(this.bytes, {this.mimeType = 'audio/pcm'});

  /// Raw audio frame bytes.
  final Uint8List bytes;

  /// Audio MIME type.
  final String mimeType;
}

/// Structured JSON payload emitted by a live WebSocket AI session.
final class AiRealtimeJsonEvent extends AiRealtimeEvent {
  /// Creates a realtime JSON event.
  const AiRealtimeJsonEvent(this.payload);

  /// Raw decoded JSON event object.
  final Map<String, Object?> payload;
}
