import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:typed_data';

import '../ai/ai_models.dart';
import '../ai/ai_provider.dart';
import '../core/cancel_token.dart';
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';

/// Programmable mock reply returned by [MockAiProvider].
final class MockAiReply {
  /// Creates a canned AI response.
  const MockAiReply({
    required this.text,
    this.thinking,
    this.toolCalls = const [],
    this.usage = const AiUsage(inputTokens: 10, outputTokens: 12),
    this.finishReason = AiFinishReason.stop,
  });

  /// Output text.
  final String text;

  /// Optional reasoning/thinking text.
  final String? thinking;

  /// Optional tool calls requested before a final answer.
  final List<AiToolCallPart> toolCalls;

  /// Simulated token usage.
  final AiUsage usage;

  /// Finish reason.
  final AiFinishReason finishReason;
}

/// Offline programmable [AiProvider] for testing `OmniAi`, fallback routing,
/// tool-calling loops, streaming chunks, and embeddings without real keys or
/// network traffic.
final class MockAiProvider
    implements AiProvider, AiBatchEmbedProvider, AiMediaProvider {
  /// Creates a mock AI provider.
  MockAiProvider({
    this.id = 'mock_ai',
    FutureOr<MockAiReply> Function(
      String model,
      List<AiMessage> messages,
      AiRequestOptions options,
    )?
    handler,
    this.streamChunkSize = 4,
    this.chunkDelay = Duration.zero,
    List<double> Function(String text)? embedder,
    FutureOr<String> Function(Uint8List audio, String mimeType, String model)?
    transcriber,
    FutureOr<Uint8List> Function(String text, String voice, String model)?
    speaker,
    FutureOr<List<AiGeneratedImage>> Function(String prompt, String model)?
    imageGenerator,
  }) : _handler = handler, // ignore: prefer_initializing_formals
       _embedder = embedder, // ignore: prefer_initializing_formals
       _transcriber = transcriber, // ignore: prefer_initializing_formals
       _speaker = speaker, // ignore: prefer_initializing_formals
       _imageGenerator = imageGenerator; // ignore: prefer_initializing_formals

  @override
  final String id;

  /// Number of characters yielded per `AiTextDelta` chunk when streaming.
  final int streamChunkSize;

  /// Optional artificial delay between streamed chunks.
  final Duration chunkDelay;

  final FutureOr<MockAiReply> Function(
    String model,
    List<AiMessage> messages,
    AiRequestOptions options,
  )?
  _handler;
  final List<double> Function(String text)? _embedder;
  final FutureOr<String> Function(
    Uint8List audio,
    String mimeType,
    String model,
  )?
  _transcriber;
  final FutureOr<Uint8List> Function(String text, String voice, String model)?
  _speaker;
  final FutureOr<List<AiGeneratedImage>> Function(String prompt, String model)?
  _imageGenerator;
  final Queue<FutureOr<MockAiReply> Function()> _queue = Queue();

  /// History of all prompts recorded by this mock.
  final List<(String model, List<AiMessage> messages)> calls = [];

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsRealtime => false;

  /// Enqueues canned responses or thrown errors for consecutive calls.
  void enqueue(FutureOr<MockAiReply> Function() reply) => _queue.addLast(reply);

  /// Enqueues a thrown failure on the next call (ideal for fallback tests).
  void failNext(Object error) => enqueue(() => throw error);

  @override
  Future<AiResponse> generate(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async {
    calls.add((model, List.unmodifiable(messages)));
    final sw = Stopwatch()..start();
    final reply = _queue.isNotEmpty
        ? await _queue.removeFirst()()
        : (_handler != null
              ? await _handler(model, messages, options)
              : MockAiReply(text: 'Mock reply: ${messages.last.text}'));
    return AiResponse(
      text: reply.text,
      thinking: reply.thinking,
      toolCalls: reply.toolCalls,
      usage: reply.usage,
      model: model,
      providerId: id,
      finishReason: reply.toolCalls.isNotEmpty
          ? AiFinishReason.toolCalls
          : reply.finishReason,
      latency: sw.elapsed,
    );
  }

  @override
  Stream<AiStreamEvent> stream(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async* {
    final res = await generate(
      client,
      model: model,
      messages: messages,
      options: options,
      cancelToken: cancelToken,
    );
    if (res.thinking != null && res.thinking!.isNotEmpty) {
      yield AiThinkingDelta(res.thinking!);
    }
    final step = streamChunkSize < 1 ? res.text.length : streamChunkSize;
    for (var i = 0; i < res.text.length; i += step) {
      if (cancelToken?.isCancelled ?? false) {
        throw const CancelledFailure();
      }
      final end = (i + step) > res.text.length ? res.text.length : (i + step);
      yield AiTextDelta(res.text.substring(i, end));
      if (chunkDelay > Duration.zero) {
        await Future<void>.delayed(chunkDelay);
      }
      if (cancelToken?.isCancelled ?? false) {
        throw const CancelledFailure();
      }
    }
    for (var i = 0; i < res.toolCalls.length; i++) {
      final t = res.toolCalls[i];
      yield AiToolCallDelta(index: i, id: t.id, name: t.name);
    }
    yield AiCompleted(res);
  }

  @override
  Future<List<double>> embed(
    OmniNetwork client, {
    required String model,
    required String text,
    OmniCancelToken? cancelToken,
  }) async {
    if (_embedder != null) return _embedder(text);
    // Simple deterministic normalized bag-of-characters vector for offline tests.
    final v = List<double>.filled(4, 0.0);
    for (final code in text.codeUnits) {
      v[code % 4] += 1.0;
    }
    final len = text.isEmpty ? 1.0 : text.length.toDouble();
    return [for (final x in v) x / len];
  }

  @override
  Future<List<List<double>>> embedBatch(
    OmniNetwork client, {
    required String model,
    required List<String> texts,
    OmniCancelToken? cancelToken,
  }) async => [
    for (final t in texts)
      await embed(client, model: model, text: t, cancelToken: cancelToken),
  ];

  @override
  Future<AiTranscriptionResult> transcribeAudio(
    OmniNetwork client, {
    required Uint8List audioBytes,
    required String mimeType,
    required String model,
    String? language,
    String? prompt,
    OmniCancelToken? cancelToken,
  }) async {
    final txt = _transcriber != null
        ? await _transcriber(audioBytes, mimeType, model)
        : 'Mock transcript (${audioBytes.length} bytes)';
    return AiTranscriptionResult(
      text: txt,
      language: language,
      model: model,
      providerId: id,
    );
  }

  @override
  Future<AiSpeechResult> generateSpeech(
    OmniNetwork client, {
    required String text,
    required String model,
    String voice = 'alloy',
    String format = 'mp3',
    OmniCancelToken? cancelToken,
  }) async {
    final bytes = _speaker != null
        ? await _speaker(text, voice, model)
        : Uint8List.fromList(text.codeUnits);
    return AiSpeechResult(
      bytes: bytes,
      mimeType: 'audio/$format',
      model: model,
      providerId: id,
    );
  }

  @override
  Future<List<AiGeneratedImage>> generateImage(
    OmniNetwork client, {
    required String prompt,
    required String model,
    String size = '1024x1024',
    int n = 1,
    OmniCancelToken? cancelToken,
  }) async {
    if (_imageGenerator != null) {
      return _imageGenerator(prompt, model);
    }
    return [
      for (var i = 0; i < n; i++)
        AiGeneratedImage(
          url: 'https://mock.image/$i/${Uri.encodeComponent(prompt)}.png',
          revisedPrompt: prompt,
          model: model,
          providerId: id,
        ),
    ];
  }

  @override
  Future<AiRealtimeSession> openRealtime(
    OmniNetwork client, {
    required String model,
    String? systemPrompt,
    Map<String, Object?> extra = const {},
  }) =>
      throw UnsupportedError('MockAiProvider does not implement openRealtime');
}
