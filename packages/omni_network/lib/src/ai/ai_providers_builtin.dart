import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/cancel_token.dart';
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../transfer/multipart.dart' show UploadFile;
import 'ai_models.dart';
import 'ai_provider.dart';
import 'ai_stream_helpers.dart';

/// Shared OpenAI wire-format adapter powering [OpenAiProvider] as well as
/// OpenAI-compatible backends (Groq, OpenRouter, DeepSeek, Together, Azure
/// OpenAI, vLLM, LM Studio, or an app backend proxy).
base class OpenAiCompatibleProvider
    implements AiProvider, AiBatchEmbedProvider, AiMediaProvider {
  /// Creates an OpenAI-compatible provider adapter.
  OpenAiCompatibleProvider({
    this.id = 'openai_compatible',
    required this.baseUrl,
    this.apiKey,
    this.headers = const {},
    this.chatPath = '/chat/completions',
    this.embeddingsPath = '/embeddings',
    this.realtimeUrl,
    this.useClientAuth = false,
  });

  @override
  final String id;

  /// API base URL (for example `'https://api.openai.com/v1'` or
  /// `'https://api.groq.com/openai/v1'`).
  final String baseUrl;

  /// Dynamic or static API key (`Bearer <key>`), or `null` when using
  /// [useClientAuth] / unauthenticated local servers.
  final FutureOr<String?> Function()? apiKey;

  /// Extra headers sent with every request (e.g. `OpenAI-Organization`).
  final Map<String, String> headers;

  /// Relative path under [baseUrl] for chat completions.
  final String chatPath;

  /// Relative path under [baseUrl] for embeddings.
  final String embeddingsPath;

  /// Optional WebSocket URL for Realtime API sessions.
  final String? realtimeUrl;

  /// When `true`, lets `OmniNetwork` apply its own `auth` (ideal when routing
  /// AI calls through your own authenticated backend proxy).
  final bool useClientAuth;

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsRealtime => realtimeUrl != null;

  String _endpoint(String path) {
    final trimmedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$trimmedBase$cleanPath';
  }

  Future<Map<String, String>> _buildHeaders() async {
    final key = await apiKey?.call();
    return {
      ...headers,
      if (key != null && key.isNotEmpty) 'authorization': 'Bearer $key',
    };
  }

  Map<String, Object?> _buildBody({
    required String model,
    required List<AiMessage> messages,
    required AiRequestOptions options,
    required bool stream,
  }) {
    final formattedMessages = <Map<String, Object?>>[
      for (final msg in messages) _encodeOpenAiMessage(msg),
    ];

    final body = <String, Object?>{
      'model': model,
      'messages': formattedMessages,
      if (stream) 'stream': true,
      if (stream) 'stream_options': const {'include_usage': true},
      if (options.temperature != null) 'temperature': options.temperature,
      if (options.maxTokens != null) 'max_tokens': options.maxTokens,
      if (options.topP != null) 'top_p': options.topP,
      if (options.stopSequences.isNotEmpty) 'stop': options.stopSequences,
      if (options.tools.isNotEmpty)
        'tools': [
          for (final t in options.tools)
            {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameters,
              },
            },
        ],
      if (options.responseSchema != null)
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'response',
            'strict': true,
            'schema': options.responseSchema,
          },
        }
      else if (options.jsonMode)
        'response_format': const {'type': 'json_object'},
      ...options.extra,
    };
    return body;
  }

  @override
  Future<AiResponse> generate(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    final json = await postAiJson(
      client,
      _endpoint(chatPath),
      body: _buildBody(
        model: model,
        messages: messages,
        options: options,
        stream: false,
      ),
      headers: await _buildHeaders(),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    return _decodeOpenAiResponse(json, model: model, latency: sw.elapsed);
  }

  @override
  Stream<AiStreamEvent> stream(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async* {
    final sw = Stopwatch()..start();
    final textBuf = StringBuffer();
    final thinkingBuf = StringBuffer();
    final toolAccum = <int, _ToolAccum>{};
    var usage = AiUsage.zero;
    var finishReason = AiFinishReason.stop;

    await for (final ev in postAiSse(
      client,
      _endpoint(chatPath),
      body: _buildBody(
        model: model,
        messages: messages,
        options: options,
        stream: true,
      ),
      headers: await _buildHeaders(),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    )) {
      final raw = ev.data.trim();
      if (raw.isEmpty || raw == '[DONE]') continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      throwIfAiErrorEnvelope(decoded);
      if (decoded['usage'] is Map) {
        usage = _decodeOpenAiUsage(
          Map<String, Object?>.from(decoded['usage']! as Map),
        );
      }
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;
      final first = choices.first;
      if (first is! Map) continue;
      if (first['finish_reason'] case final String fr) {
        finishReason = _mapFinishReason(fr);
      }
      final delta = first['delta'];
      if (delta is! Map) continue;
      final reasoning = delta['reasoning_content'];
      if (reasoning is String && reasoning.isNotEmpty) {
        thinkingBuf.write(reasoning);
        yield AiThinkingDelta(reasoning);
      }
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        textBuf.write(content);
        yield AiTextDelta(content);
      }
      final toolCalls = delta['tool_calls'];
      if (toolCalls is List) {
        for (final item in toolCalls) {
          if (item is! Map) continue;
          final idx = item['index'] as int? ?? 0;
          final acc = toolAccum.putIfAbsent(idx, _ToolAccum.new);
          if (item['id'] case final String id) acc.id = id;
          final fn = item['function'];
          String? nameChunk;
          String? argChunk;
          if (fn is Map) {
            if (fn['name'] case final String n) {
              acc.name = n;
              nameChunk = n;
            }
            if (fn['arguments'] case final String a) {
              acc.args.write(a);
              argChunk = a;
            }
          }
          yield AiToolCallDelta(
            index: idx,
            id: acc.id,
            name: nameChunk,
            argumentsChunk: argChunk,
          );
        }
      }
    }

    final finalTools = _finalizeToolCalls(toolAccum);
    if (finalTools.isNotEmpty && finishReason == AiFinishReason.stop) {
      finishReason = AiFinishReason.toolCalls;
    }
    yield AiCompleted(
      AiResponse(
        text: textBuf.toString(),
        thinking: thinkingBuf.isEmpty ? null : thinkingBuf.toString(),
        toolCalls: finalTools,
        usage: usage,
        model: model,
        providerId: id,
        finishReason: finishReason,
        latency: sw.elapsed,
      ),
    );
  }

  @override
  Future<List<double>> embed(
    OmniNetwork client, {
    required String model,
    required String text,
    OmniCancelToken? cancelToken,
  }) async {
    final json = await postAiJson(
      client,
      _endpoint(embeddingsPath),
      body: {'model': model, 'input': text},
      headers: await _buildHeaders(),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    final data = json['data'];
    if (data is! List || data.isEmpty) {
      throw const DecodeFailure('Embedding response missing "data"');
    }
    final first = data.first as Map;
    final vec = first['embedding']! as List;
    return [for (final n in vec) (n as num).toDouble()];
  }

  @override
  Future<List<List<double>>> embedBatch(
    OmniNetwork client, {
    required String model,
    required List<String> texts,
    OmniCancelToken? cancelToken,
  }) async {
    if (texts.isEmpty) return const [];
    final json = await postAiJson(
      client,
      _endpoint(embeddingsPath),
      body: {'model': model, 'input': texts},
      headers: await _buildHeaders(),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    final data = json['data'];
    if (data is! List) {
      throw const DecodeFailure('Batch embedding response missing "data"');
    }
    return [
      for (final item in data)
        [
          for (final n in ((item as Map)['embedding']! as List))
            (n as num).toDouble(),
        ],
    ];
  }

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
    final json = await postAiMultipart(
      client,
      _endpoint('/audio/transcriptions'),
      fields: {'model': model, 'language': ?language, 'prompt': ?prompt},
      files: [
        UploadFile.fromBytes(
          'file',
          audioBytes,
          filename: 'audio.${_extFromMime(mimeType)}',
          contentType: mimeType,
        ),
      ],
      headers: await _buildHeaders(),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    return AiTranscriptionResult(
      text: json['text'] as String? ?? '',
      language: json['language'] as String? ?? language,
      durationSeconds: (json['duration'] as num?)?.toDouble(),
      model: model,
      providerId: id,
      raw: json,
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
    final raw = await postAiBytes(
      client,
      _endpoint('/audio/speech'),
      body: {
        'model': model,
        'input': text,
        'voice': voice,
        'response_format': format,
      },
      headers: await _buildHeaders(),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    return AiSpeechResult(
      bytes: raw.bodyBytes,
      mimeType: raw.headers['content-type'] ?? _mimeFromAudioFormat(format),
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
    final json = await postAiJson(
      client,
      _endpoint('/images/generations'),
      body: {'model': model, 'prompt': prompt, 'size': size, 'n': n},
      headers: await _buildHeaders(),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    final data = json['data'] as List? ?? const [];
    return [
      for (final entry in data)
        if (entry is Map)
          AiGeneratedImage(
            bytes: entry['b64_json'] is String
                ? base64Decode(entry['b64_json']! as String)
                : null,
            url: entry['url'] as String?,
            revisedPrompt: entry['revised_prompt'] as String?,
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
  }) async {
    final rt = realtimeUrl;
    if (rt == null) {
      throw UnsupportedError('$id does not configure a realtimeUrl');
    }
    final key = await apiKey?.call();
    final socket = client.ws(
      rt,
      query: {'model': model},
      headers: {
        ...headers,
        if (key != null && key.isNotEmpty) 'authorization': 'Bearer $key',
        'openai-beta': 'realtime=v1',
      },
      auth: useClientAuth,
      onOpen: (s) {
        if (systemPrompt != null || extra.isNotEmpty) {
          s.sendJson({
            'type': 'session.update',
            'session': {'instructions': ?systemPrompt, ...extra},
          });
        }
      },
    );

    final events = socket.jsonMessages.map<AiRealtimeEvent>((raw) {
      if (raw is! Map) return AiRealtimeJsonEvent({'raw': raw});
      final map = Map<String, Object?>.from(raw);
      final type = map['type'] as String?;
      if (type == 'response.text.delta' ||
          type == 'response.audio_transcript.delta') {
        final delta = map['delta'] as String? ?? '';
        return AiRealtimeTextDelta(delta);
      }
      if (type == 'response.audio.delta') {
        final b64 = map['delta'] as String? ?? '';
        return AiRealtimeAudioDelta(base64Decode(b64));
      }
      return AiRealtimeJsonEvent(map);
    });

    return AiRealtimeSession(
      socket: socket,
      events: events,
      sendTextImpl: (text) {
        socket.sendJson({
          'type': 'conversation.item.create',
          'item': {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': text},
            ],
          },
        });
        socket.sendJson({'type': 'response.create'});
      },
      sendAudioImpl: (bytes, _) {
        socket.sendJson({
          'type': 'input_audio_buffer.append',
          'audio': base64Encode(bytes),
        });
      },
    );
  }

  AiResponse _decodeOpenAiResponse(
    Map<String, Object?> json, {
    required String model,
    required Duration latency,
  }) {
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const DecodeFailure('OpenAI response contains no choices');
    }
    final first = Map<String, Object?>.from(choices.first! as Map);
    final msg = Map<String, Object?>.from(first['message']! as Map);
    final finishReason = _mapFinishReason(first['finish_reason'] as String?);
    final content = msg['content'];
    final text = content is String ? content : '';
    final reasoning = msg['reasoning_content'] as String?;
    final rawTools = msg['tool_calls'] as List? ?? const [];
    final toolCalls = [
      for (final rawCall in rawTools)
        if (rawCall is Map) _parseOpenAiToolCall(rawCall),
    ];
    final usage = json['usage'] is Map
        ? _decodeOpenAiUsage(Map<String, Object?>.from(json['usage']! as Map))
        : AiUsage.zero;
    return AiResponse(
      text: text,
      thinking: reasoning,
      toolCalls: toolCalls,
      usage: usage,
      model: json['model'] as String? ?? model,
      providerId: id,
      finishReason: finishReason,
      latency: latency,
      raw: json,
    );
  }
}

/// Official OpenAI Chat, Vision, Embeddings, Tool Calling & Realtime WebSocket
/// adapter.
final class OpenAiProvider extends OpenAiCompatibleProvider {
  /// Creates an OpenAI adapter.
  OpenAiProvider({
    super.id = 'openai',
    super.baseUrl = 'https://api.openai.com/v1',
    super.apiKey,
    String? organization,
    Map<String, String> headers = const {},
    super.realtimeUrl = 'wss://api.openai.com/v1/realtime',
    super.useClientAuth = false,
  }) : super(headers: {...headers, 'openai-organization': ?organization});
}

/// Google Gemini (`generateContent`, `streamGenerateContent?alt=sse`,
/// Embeddings, Multimodal, Audio Transcription, Imagen & Live WebSocket) adapter.
final class GeminiProvider
    implements AiProvider, AiBatchEmbedProvider, AiMediaProvider {
  /// Creates a Gemini adapter.
  GeminiProvider({
    this.id = 'gemini',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    this.apiKey,
    this.apiKeyInQuery = false,
    this.headers = const {},
    this.realtimeUrl =
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
    this.useClientAuth = false,
  });

  @override
  final String id;

  /// Gemini API base URL.
  final String baseUrl;

  /// API key provider (`x-goog-api-key` header by default).
  final FutureOr<String?> Function()? apiKey;

  /// Sends key as `?key=` query parameter instead of `x-goog-api-key` header.
  final bool apiKeyInQuery;

  /// Extra headers.
  final Map<String, String> headers;

  /// WebSocket URL for Gemini Multimodal Live API.
  final String realtimeUrl;

  /// Uses `OmniNetwork`'s auth provider instead of [apiKey] (e.g. proxy mode).
  final bool useClientAuth;

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsRealtime => true;

  Future<(String url, Map<String, String> headers)> _target(String path) async {
    final trimmed = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    var url = '$trimmed$path';
    final key = await apiKey?.call();
    final h = <String, String>{...headers};
    if (key != null && key.isNotEmpty) {
      if (apiKeyInQuery) {
        final sep = url.contains('?') ? '&' : '?';
        url = '$url${sep}key=${Uri.encodeQueryComponent(key)}';
      } else {
        h['x-goog-api-key'] = key;
      }
    }
    return (url, h);
  }

  Map<String, Object?> _buildBody({
    required List<AiMessage> messages,
    required AiRequestOptions options,
  }) {
    final systemParts = <Map<String, Object?>>[];
    final contents = <Map<String, Object?>>[];
    for (final msg in messages) {
      if (msg.role == AiRole.system) {
        if (msg.text.isNotEmpty) {
          systemParts.add({'text': msg.text});
        }
        continue;
      }
      final role = switch (msg.role) {
        AiRole.assistant => 'model',
        AiRole.tool || AiRole.user || AiRole.system => 'user',
      };
      final parts = <Map<String, Object?>>[];
      for (final p in msg.parts) {
        switch (p) {
          case AiTextPart(:final text):
            parts.add({'text': text});
          case AiImageBytesPart(:final bytes, :final mimeType):
            parts.add({
              'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
            });
          case AiAudioBytesPart(:final bytes, :final mimeType):
            parts.add({
              'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
            });
          case AiDocumentPart(:final bytes, :final mimeType):
            parts.add({
              'inlineData': {'mimeType': mimeType, 'data': base64Encode(bytes)},
            });
          case AiImageUrlPart(:final url):
            parts.add({
              'fileData': {'mimeType': _guessImageMime(url), 'fileUri': url},
            });
          case AiToolCallPart(:final name, :final arguments):
            parts.add({
              'functionCall': {'name': name, 'args': arguments},
            });
          case AiToolResultPart(:final name, :final result):
            parts.add({
              'functionResponse': {
                'name': name,
                'response': result is Map
                    ? Map<String, Object?>.from(result)
                    : {'result': result},
              },
            });
        }
      }
      contents.add({'role': role, 'parts': parts});
    }

    final genConfig = <String, Object?>{
      if (options.temperature != null) 'temperature': options.temperature,
      if (options.maxTokens != null) 'maxOutputTokens': options.maxTokens,
      if (options.topP != null) 'topP': options.topP,
      if (options.stopSequences.isNotEmpty)
        'stopSequences': options.stopSequences,
      if (options.responseSchema != null || options.jsonMode)
        'responseMimeType': 'application/json',
      if (options.responseSchema != null)
        'responseSchema': options.responseSchema,
    };

    return {
      if (systemParts.isNotEmpty) 'systemInstruction': {'parts': systemParts},
      'contents': contents,
      if (options.tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [
              for (final t in options.tools)
                {
                  'name': t.name,
                  'description': t.description,
                  'parameters': t.parameters,
                },
            ],
          },
        ],
      if (genConfig.isNotEmpty) 'generationConfig': genConfig,
      ...options.extra,
    };
  }

  @override
  Future<AiResponse> generate(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    final (url, reqHeaders) = await _target('/models/$model:generateContent');
    final json = await postAiJson(
      client,
      url,
      body: _buildBody(messages: messages, options: options),
      headers: reqHeaders,
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    return _decodeGeminiResponse(json, model: model, latency: sw.elapsed);
  }

  @override
  Stream<AiStreamEvent> stream(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async* {
    final sw = Stopwatch()..start();
    final (url, reqHeaders) = await _target(
      '/models/$model:streamGenerateContent?alt=sse',
    );
    final textBuf = StringBuffer();
    final thinkingBuf = StringBuffer();
    final tools = <AiToolCallPart>[];
    var usage = AiUsage.zero;
    var finishReason = AiFinishReason.stop;

    await for (final ev in postAiSse(
      client,
      url,
      body: _buildBody(messages: messages, options: options),
      headers: reqHeaders,
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    )) {
      final raw = ev.data.trim();
      if (raw.isEmpty) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final map = Map<String, Object?>.from(decoded);
      throwIfAiErrorEnvelope(map);
      if (map['usageMetadata'] is Map) {
        usage = _decodeGeminiUsage(
          Map<String, Object?>.from(map['usageMetadata']! as Map),
        );
      }
      final candidates = map['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) continue;
      final first = Map<String, Object?>.from(candidates.first! as Map);
      if (first['finishReason'] case final String fr) {
        finishReason = _mapFinishReason(fr);
      }
      final content = first['content'];
      if (content is! Map) continue;
      final parts = content['parts'] as List? ?? const [];
      for (final p in parts) {
        if (p is! Map) continue;
        final thought = p['thought'] as bool? ?? false;
        if (p['text'] case final String t when t.isNotEmpty) {
          if (thought) {
            thinkingBuf.write(t);
            yield AiThinkingDelta(t);
          } else {
            textBuf.write(t);
            yield AiTextDelta(t);
          }
        }
        if (p['functionCall'] is Map) {
          final fc = Map<String, Object?>.from(p['functionCall']! as Map);
          final callId = 'gemini_call_${tools.length}';
          final name = fc['name'] as String? ?? '';
          final args = Map<String, Object?>.from(
            fc['args'] as Map? ?? const {},
          );
          tools.add(AiToolCallPart(id: callId, name: name, arguments: args));
          yield AiToolCallDelta(
            index: tools.length - 1,
            id: callId,
            name: name,
            argumentsChunk: jsonEncode(args),
          );
        }
      }
    }

    if (tools.isNotEmpty && finishReason == AiFinishReason.stop) {
      finishReason = AiFinishReason.toolCalls;
    }
    yield AiCompleted(
      AiResponse(
        text: textBuf.toString(),
        thinking: thinkingBuf.isEmpty ? null : thinkingBuf.toString(),
        toolCalls: tools,
        usage: usage,
        model: model,
        providerId: id,
        finishReason: finishReason,
        latency: sw.elapsed,
      ),
    );
  }

  @override
  Future<List<double>> embed(
    OmniNetwork client, {
    required String model,
    required String text,
    OmniCancelToken? cancelToken,
  }) async {
    final (url, reqHeaders) = await _target('/models/$model:embedContent');
    final json = await postAiJson(
      client,
      url,
      body: {
        'model': 'models/$model',
        'content': {
          'parts': [
            {'text': text},
          ],
        },
      },
      headers: reqHeaders,
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    final emb = json['embedding'] as Map?;
    final values = emb?['values'] as List?;
    if (values == null) {
      throw const DecodeFailure('Gemini embedding response missing values');
    }
    return [for (final n in values) (n as num).toDouble()];
  }

  @override
  Future<List<List<double>>> embedBatch(
    OmniNetwork client, {
    required String model,
    required List<String> texts,
    OmniCancelToken? cancelToken,
  }) async {
    if (texts.isEmpty) return const [];
    final (url, reqHeaders) = await _target(
      '/models/$model:batchEmbedContents',
    );
    final json = await postAiJson(
      client,
      url,
      body: {
        'requests': [
          for (final t in texts)
            {
              'model': 'models/$model',
              'content': {
                'parts': [
                  {'text': t},
                ],
              },
            },
        ],
      },
      headers: reqHeaders,
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    final embeddings = json['embeddings'] as List?;
    if (embeddings == null) {
      throw const DecodeFailure(
        'Gemini batchEmbedContents response missing "embeddings"',
      );
    }
    return [
      for (final item in embeddings)
        [
          for (final n in ((item as Map)['values']! as List))
            (n as num).toDouble(),
        ],
    ];
  }

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
    final instruction =
        prompt ??
        'Transcribe the provided audio verbatim'
            '${language == null ? '' : ' in $language'}. Return only the transcript text.';
    final res = await generate(
      client,
      model: model,
      messages: [
        AiMessage.userParts([
          AiPart.audioBytes(audioBytes, mimeType: mimeType),
          AiPart.text(instruction),
        ]),
      ],
      cancelToken: cancelToken,
    );
    return AiTranscriptionResult(
      text: res.text.trim(),
      language: language,
      model: res.model,
      providerId: id,
      raw: res.raw,
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
  }) => throw UnsupportedError(
    'GeminiProvider does not expose a standalone audio/speech TTS endpoint; '
    'use OpenAiProvider or openRealtime for live Gemini audio output.',
  );

  @override
  Future<List<AiGeneratedImage>> generateImage(
    OmniNetwork client, {
    required String prompt,
    required String model,
    String size = '1024x1024',
    int n = 1,
    OmniCancelToken? cancelToken,
  }) async {
    final (url, reqHeaders) = await _target('/models/$model:predict');
    final json = await postAiJson(
      client,
      url,
      body: {
        'instances': [
          {'prompt': prompt},
        ],
        'parameters': {'sampleCount': n},
      },
      headers: reqHeaders,
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    final predictions = json['predictions'] as List? ?? const [];
    return [
      for (final p in predictions)
        if (p is Map)
          AiGeneratedImage(
            bytes: p['bytesBase64Encoded'] is String
                ? base64Decode(p['bytesBase64Encoded']! as String)
                : null,
            mimeType: p['mimeType'] as String? ?? 'image/png',
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
  }) async {
    final key = await apiKey?.call();
    final socket = client.ws(
      realtimeUrl,
      query: {if (key != null && key.isNotEmpty) 'key': key},
      headers: headers,
      auth: useClientAuth,
      onOpen: (s) {
        s.sendJson({
          'setup': {
            'model': 'models/$model',
            if (systemPrompt != null)
              'systemInstruction': {
                'parts': [
                  {'text': systemPrompt},
                ],
              },
            ...extra,
          },
        });
      },
    );

    final events = socket.jsonMessages.expand<AiRealtimeEvent>((raw) {
      if (raw is! Map) return const [];
      final map = Map<String, Object?>.from(raw);
      final serverContent = map['serverContent'];
      if (serverContent is Map) {
        final modelTurn = serverContent['modelTurn'];
        if (modelTurn is Map && modelTurn['parts'] is List) {
          final out = <AiRealtimeEvent>[];
          for (final part in modelTurn['parts']! as List) {
            if (part is! Map) continue;
            if (part['text'] case final String t) {
              out.add(AiRealtimeTextDelta(t));
            } else if (part['inlineData'] case final Map inline) {
              final data = inline['data'] as String?;
              if (data != null) {
                out.add(
                  AiRealtimeAudioDelta(
                    base64Decode(data),
                    mimeType: inline['mimeType'] as String? ?? 'audio/pcm',
                  ),
                );
              }
            }
          }
          if (out.isNotEmpty) return out;
        }
      }
      return [AiRealtimeJsonEvent(map)];
    });

    return AiRealtimeSession(
      socket: socket,
      events: events,
      sendTextImpl: (text) {
        socket.sendJson({
          'clientContent': {
            'turns': [
              {
                'role': 'user',
                'parts': [
                  {'text': text},
                ],
              },
            ],
            'turnComplete': true,
          },
        });
      },
      sendAudioImpl: (bytes, mimeType) {
        socket.sendJson({
          'realtimeInput': {
            'mediaChunks': [
              {'mimeType': mimeType, 'data': base64Encode(bytes)},
            ],
          },
        });
      },
    );
  }

  AiResponse _decodeGeminiResponse(
    Map<String, Object?> json, {
    required String model,
    required Duration latency,
  }) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const DecodeFailure('Gemini response contains no candidates');
    }
    final first = Map<String, Object?>.from(candidates.first! as Map);
    final content = Map<String, Object?>.from(first['content']! as Map);
    final parts = content['parts'] as List? ?? const [];
    final textBuf = StringBuffer();
    final thinkingBuf = StringBuffer();
    final tools = <AiToolCallPart>[];

    for (final p in parts) {
      if (p is! Map) continue;
      final thought = p['thought'] as bool? ?? false;
      if (p['text'] case final String t) {
        if (thought) {
          thinkingBuf.write(t);
        } else {
          textBuf.write(t);
        }
      } else if (p['functionCall'] case final Map fc) {
        tools.add(
          AiToolCallPart(
            id: 'gemini_call_${tools.length}',
            name: fc['name'] as String? ?? '',
            arguments: Map<String, Object?>.from(
              fc['args'] as Map? ?? const {},
            ),
          ),
        );
      }
    }
    final usage = json['usageMetadata'] is Map
        ? _decodeGeminiUsage(
            Map<String, Object?>.from(json['usageMetadata']! as Map),
          )
        : AiUsage.zero;
    var finishReason = _mapFinishReason(first['finishReason'] as String?);
    if (tools.isNotEmpty && finishReason == AiFinishReason.stop) {
      finishReason = AiFinishReason.toolCalls;
    }
    return AiResponse(
      text: textBuf.toString(),
      thinking: thinkingBuf.isEmpty ? null : thinkingBuf.toString(),
      toolCalls: tools,
      usage: usage,
      model: model,
      providerId: id,
      finishReason: finishReason,
      latency: latency,
      raw: json,
    );
  }
}

/// Anthropic Claude Messages API (`/v1/messages`, SSE Streaming, Thinking,
/// Vision & Tool Use) adapter.
final class AnthropicProvider implements AiProvider {
  /// Creates an Anthropic Claude adapter.
  AnthropicProvider({
    this.id = 'claude',
    this.baseUrl = 'https://api.anthropic.com/v1',
    this.apiKey,
    this.anthropicVersion = '2023-06-01',
    this.headers = const {},
    this.useClientAuth = false,
  });

  @override
  final String id;

  /// Base URL (`https://api.anthropic.com/v1` by default).
  final String baseUrl;

  /// Anthropic API key provider (`x-api-key`).
  final FutureOr<String?> Function()? apiKey;

  /// `anthropic-version` header value.
  final String anthropicVersion;

  /// Extra headers.
  final Map<String, String> headers;

  /// Uses `OmniNetwork` auth header when routing through an app proxy.
  final bool useClientAuth;

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsRealtime => false;

  String _endpoint(String path) =>
      '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}$path';

  Future<Map<String, String>> _buildHeaders({
    bool promptCaching = false,
  }) async {
    final key = await apiKey?.call();
    return {
      'anthropic-version': anthropicVersion,
      if (promptCaching) 'anthropic-beta': 'prompt-caching-2024-07-31',
      ...headers,
      if (key != null && key.isNotEmpty) 'x-api-key': key,
    };
  }

  Map<String, Object?> _buildBody({
    required String model,
    required List<AiMessage> messages,
    required AiRequestOptions options,
    required bool stream,
  }) {
    final systemTexts = <String>[];
    final outMessages = <Map<String, Object?>>[];

    for (final msg in messages) {
      if (msg.role == AiRole.system) {
        if (msg.text.isNotEmpty) systemTexts.add(msg.text);
        continue;
      }
      final role = msg.role == AiRole.assistant ? 'assistant' : 'user';
      final blocks = <Map<String, Object?>>[];
      for (final p in msg.parts) {
        switch (p) {
          case AiTextPart(:final text):
            blocks.add({'type': 'text', 'text': text});
          case AiImageBytesPart(:final bytes, :final mimeType):
            blocks.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mimeType,
                'data': base64Encode(bytes),
              },
            });
          case AiDocumentPart(:final bytes, :final mimeType):
            blocks.add({
              'type': 'document',
              'source': {
                'type': 'base64',
                'media_type': mimeType,
                'data': base64Encode(bytes),
              },
            });
          case AiImageUrlPart(:final url):
            blocks.add({'type': 'text', 'text': url});
          case AiAudioBytesPart():
            blocks.add(const {
              'type': 'text',
              'text': '[audio attachment omitted]',
            });
          case AiToolCallPart(:final id, :final name, :final arguments):
            blocks.add({
              'type': 'tool_use',
              'id': id,
              'name': name,
              'input': arguments,
            });
          case AiToolResultPart(:final callId, :final result, :final isError):
            blocks.add({
              'type': 'tool_result',
              'tool_use_id': callId,
              'content': result is String ? result : jsonEncode(result),
              if (isError) 'is_error': true,
            });
        }
      }
      outMessages.add({'role': role, 'content': blocks});
    }

    return {
      'model': model,
      'max_tokens': options.maxTokens ?? 4096,
      if (systemTexts.isNotEmpty)
        'system': options.promptCaching
            ? [
                {
                  'type': 'text',
                  'text': systemTexts.join('\n\n'),
                  'cache_control': const {'type': 'ephemeral'},
                },
              ]
            : systemTexts.join('\n\n'),
      'messages': outMessages,
      if (stream) 'stream': true,
      if (options.temperature != null) 'temperature': options.temperature,
      if (options.topP != null) 'top_p': options.topP,
      if (options.stopSequences.isNotEmpty)
        'stop_sequences': options.stopSequences,
      if (options.tools.isNotEmpty)
        'tools': [
          for (final t in options.tools)
            {
              'name': t.name,
              'description': t.description,
              'input_schema': t.parameters,
            },
        ],
      ...options.extra,
    };
  }

  @override
  Future<AiResponse> generate(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    final json = await postAiJson(
      client,
      _endpoint('/messages'),
      body: _buildBody(
        model: model,
        messages: messages,
        options: options,
        stream: false,
      ),
      headers: await _buildHeaders(promptCaching: options.promptCaching),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    );
    final blocks = json['content'] as List? ?? const [];
    final textBuf = StringBuffer();
    final thinkingBuf = StringBuffer();
    final tools = <AiToolCallPart>[];
    for (final b in blocks) {
      if (b is! Map) continue;
      final type = b['type'];
      if (type == 'text') {
        textBuf.write(b['text'] ?? '');
      } else if (type == 'thinking') {
        thinkingBuf.write(b['thinking'] ?? '');
      } else if (type == 'tool_use') {
        tools.add(
          AiToolCallPart(
            id: b['id'] as String? ?? 'claude_tool_${tools.length}',
            name: b['name'] as String? ?? '',
            arguments: Map<String, Object?>.from(
              b['input'] as Map? ?? const {},
            ),
          ),
        );
      }
    }
    final rawUsage = json['usage'] as Map?;
    final inputTokens =
        (rawUsage?['input_tokens'] as int? ?? 0) +
        (rawUsage?['cache_read_input_tokens'] as int? ?? 0) +
        (rawUsage?['cache_creation_input_tokens'] as int? ?? 0);
    final outputTokens = rawUsage?['output_tokens'] as int? ?? 0;
    return AiResponse(
      text: textBuf.toString(),
      thinking: thinkingBuf.isEmpty ? null : thinkingBuf.toString(),
      toolCalls: tools,
      usage: AiUsage(inputTokens: inputTokens, outputTokens: outputTokens),
      model: json['model'] as String? ?? model,
      providerId: id,
      finishReason: _mapFinishReason(json['stop_reason'] as String?),
      latency: sw.elapsed,
      raw: json,
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
    final sw = Stopwatch()..start();
    final textBuf = StringBuffer();
    final thinkingBuf = StringBuffer();
    final toolAccum = <int, _ToolAccum>{};
    var inputTokens = 0;
    var outputTokens = 0;
    var finishReason = AiFinishReason.stop;

    await for (final ev in postAiSse(
      client,
      _endpoint('/messages'),
      body: _buildBody(
        model: model,
        messages: messages,
        options: options,
        stream: true,
      ),
      headers: await _buildHeaders(promptCaching: options.promptCaching),
      skipAuth: !useClientAuth,
      cancelToken: cancelToken,
    )) {
      final raw = ev.data.trim();
      if (raw.isEmpty) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      throwIfAiErrorEnvelope(decoded);
      final type = decoded['type'] as String?;
      if (type == 'message_start' && decoded['message'] is Map) {
        final msg = decoded['message']! as Map;
        if (msg['usage'] is Map) {
          inputTokens = (msg['usage']! as Map)['input_tokens'] as int? ?? 0;
        }
      } else if (type == 'content_block_start') {
        final idx = decoded['index'] as int? ?? 0;
        final block = decoded['content_block'];
        if (block is Map && block['type'] == 'tool_use') {
          final acc = toolAccum.putIfAbsent(idx, _ToolAccum.new)
            ..id = block['id'] as String? ?? 'claude_tool_$idx'
            ..name = block['name'] as String? ?? '';
          yield AiToolCallDelta(index: idx, id: acc.id, name: acc.name);
        }
      } else if (type == 'content_block_delta') {
        final idx = decoded['index'] as int? ?? 0;
        final delta = decoded['delta'];
        if (delta is! Map) continue;
        final dtype = delta['type'];
        if (dtype == 'text_delta') {
          final t = delta['text'] as String? ?? '';
          if (t.isNotEmpty) {
            textBuf.write(t);
            yield AiTextDelta(t);
          }
        } else if (dtype == 'thinking_delta') {
          final t = delta['thinking'] as String? ?? '';
          if (t.isNotEmpty) {
            thinkingBuf.write(t);
            yield AiThinkingDelta(t);
          }
        } else if (dtype == 'input_json_delta') {
          final part = delta['partial_json'] as String? ?? '';
          if (part.isNotEmpty) {
            final acc = toolAccum.putIfAbsent(idx, _ToolAccum.new);
            acc.args.write(part);
            yield AiToolCallDelta(index: idx, argumentsChunk: part);
          }
        }
      } else if (type == 'message_delta') {
        if (decoded['delta'] case final Map d) {
          if (d['stop_reason'] case final String sr) {
            finishReason = _mapFinishReason(sr);
          }
        }
        if (decoded['usage'] case final Map u) {
          outputTokens = u['output_tokens'] as int? ?? outputTokens;
        }
      }
    }

    final finalTools = _finalizeToolCalls(toolAccum);
    if (finalTools.isNotEmpty && finishReason == AiFinishReason.stop) {
      finishReason = AiFinishReason.toolCalls;
    }
    yield AiCompleted(
      AiResponse(
        text: textBuf.toString(),
        thinking: thinkingBuf.isEmpty ? null : thinkingBuf.toString(),
        toolCalls: finalTools,
        usage: AiUsage(inputTokens: inputTokens, outputTokens: outputTokens),
        model: model,
        providerId: id,
        finishReason: finishReason,
        latency: sw.elapsed,
      ),
    );
  }

  @override
  Future<List<double>> embed(
    OmniNetwork client, {
    required String model,
    required String text,
    OmniCancelToken? cancelToken,
  }) => throw UnsupportedError(
    'AnthropicProvider does not provide a native embeddings endpoint; '
    'configure OpenAI, Gemini, or Ollama for embeddings.',
  );

  @override
  Future<AiRealtimeSession> openRealtime(
    OmniNetwork client, {
    required String model,
    String? systemPrompt,
    Map<String, Object?> extra = const {},
  }) => throw UnsupportedError(
    'AnthropicProvider uses SSE streaming and does not expose a WebSocket '
    'realtime endpoint.',
  );
}

/// Ollama local LLM (`/api/chat`, NDJSON streaming & `/api/embed`) adapter.
final class OllamaProvider implements AiProvider, AiBatchEmbedProvider {
  /// Creates an Ollama adapter targeting [baseUrl] (default local daemon).
  OllamaProvider({
    this.id = 'ollama',
    this.baseUrl = 'http://localhost:11434',
    this.headers = const {},
  });

  @override
  final String id;

  /// Ollama daemon base URL.
  final String baseUrl;

  /// Optional extra headers.
  final Map<String, String> headers;

  @override
  bool get supportsStreaming => true;

  @override
  bool get supportsRealtime => false;

  String _endpoint(String path) =>
      '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}$path';

  Map<String, Object?> _buildBody({
    required String model,
    required List<AiMessage> messages,
    required AiRequestOptions options,
    required bool stream,
  }) {
    final encoded = <Map<String, Object?>>[];
    for (final m in messages) {
      final images = <String>[
        for (final p in m.parts)
          if (p is AiImageBytesPart) base64Encode(p.bytes),
      ];
      encoded.add({
        'role': switch (m.role) {
          AiRole.system => 'system',
          AiRole.user => 'user',
          AiRole.assistant => 'assistant',
          AiRole.tool => 'tool',
        },
        'content': m.text,
        if (images.isNotEmpty) 'images': images,
      });
    }
    return {
      'model': model,
      'messages': encoded,
      'stream': stream,
      if (options.responseSchema != null)
        'format': options.responseSchema
      else if (options.jsonMode)
        'format': 'json',
      if (options.tools.isNotEmpty)
        'tools': [
          for (final t in options.tools)
            {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameters,
              },
            },
        ],
      if (options.temperature != null ||
          options.maxTokens != null ||
          options.topP != null ||
          options.stopSequences.isNotEmpty)
        'options': {
          if (options.temperature != null) 'temperature': options.temperature,
          if (options.maxTokens != null) 'num_predict': options.maxTokens,
          if (options.topP != null) 'top_p': options.topP,
          if (options.stopSequences.isNotEmpty) 'stop': options.stopSequences,
        },
      ...options.extra,
    };
  }

  @override
  Future<AiResponse> generate(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async {
    final sw = Stopwatch()..start();
    final json = await postAiJson(
      client,
      _endpoint('/api/chat'),
      body: _buildBody(
        model: model,
        messages: messages,
        options: options,
        stream: false,
      ),
      headers: headers,
      cancelToken: cancelToken,
    );
    final msg = Map<String, Object?>.from(json['message'] as Map? ?? const {});
    final rawTools = msg['tool_calls'] as List? ?? const [];
    final tools = [
      for (var i = 0; i < rawTools.length; i++)
        if (rawTools[i] is Map) _parseOllamaToolCall(i, rawTools[i]! as Map),
    ];
    return AiResponse(
      text: msg['content'] as String? ?? '',
      thinking: msg['thinking'] as String?,
      toolCalls: tools,
      usage: AiUsage(
        inputTokens: json['prompt_eval_count'] as int? ?? 0,
        outputTokens: json['eval_count'] as int? ?? 0,
      ),
      model: json['model'] as String? ?? model,
      providerId: id,
      finishReason: tools.isNotEmpty
          ? AiFinishReason.toolCalls
          : AiFinishReason.stop,
      latency: sw.elapsed,
      raw: json,
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
    final sw = Stopwatch()..start();
    final textBuf = StringBuffer();
    final thinkingBuf = StringBuffer();
    final tools = <AiToolCallPart>[];
    var inputTokens = 0;
    var outputTokens = 0;

    await for (final chunk in postAiNdjson(
      client,
      _endpoint('/api/chat'),
      body: _buildBody(
        model: model,
        messages: messages,
        options: options,
        stream: true,
      ),
      headers: headers,
      cancelToken: cancelToken,
    )) {
      if (chunk['message'] case final Map m) {
        if (m['thinking'] case final String t when t.isNotEmpty) {
          thinkingBuf.write(t);
          yield AiThinkingDelta(t);
        }
        if (m['content'] case final String c when c.isNotEmpty) {
          textBuf.write(c);
          yield AiTextDelta(c);
        }
        if (m['tool_calls'] case final List tcs) {
          for (final raw in tcs) {
            if (raw is Map) {
              tools.add(_parseOllamaToolCall(tools.length, raw));
            }
          }
        }
      }
      if (chunk['done'] == true) {
        inputTokens = chunk['prompt_eval_count'] as int? ?? 0;
        outputTokens = chunk['eval_count'] as int? ?? 0;
      }
    }

    yield AiCompleted(
      AiResponse(
        text: textBuf.toString(),
        thinking: thinkingBuf.isEmpty ? null : thinkingBuf.toString(),
        toolCalls: tools,
        usage: AiUsage(inputTokens: inputTokens, outputTokens: outputTokens),
        model: model,
        providerId: id,
        finishReason: tools.isNotEmpty
            ? AiFinishReason.toolCalls
            : AiFinishReason.stop,
        latency: sw.elapsed,
      ),
    );
  }

  @override
  Future<List<double>> embed(
    OmniNetwork client, {
    required String model,
    required String text,
    OmniCancelToken? cancelToken,
  }) async {
    final json = await postAiJson(
      client,
      _endpoint('/api/embed'),
      body: {'model': model, 'input': text},
      headers: headers,
      cancelToken: cancelToken,
    );
    final embeddings = json['embeddings'] as List?;
    if (embeddings == null || embeddings.isEmpty) {
      throw const DecodeFailure('Ollama embed response missing "embeddings"');
    }
    return [for (final n in embeddings.first! as List) (n as num).toDouble()];
  }

  @override
  Future<List<List<double>>> embedBatch(
    OmniNetwork client, {
    required String model,
    required List<String> texts,
    OmniCancelToken? cancelToken,
  }) async {
    if (texts.isEmpty) return const [];
    final json = await postAiJson(
      client,
      _endpoint('/api/embed'),
      body: {'model': model, 'input': texts},
      headers: headers,
      cancelToken: cancelToken,
    );
    final embeddings = json['embeddings'] as List?;
    if (embeddings == null) {
      throw const DecodeFailure(
        'Ollama batch embed response missing "embeddings"',
      );
    }
    return [
      for (final row in embeddings)
        [for (final n in (row as List)) (n as num).toDouble()],
    ];
  }

  @override
  Future<AiRealtimeSession> openRealtime(
    OmniNetwork client, {
    required String model,
    String? systemPrompt,
    Map<String, Object?> extra = const {},
  }) => throw UnsupportedError(
    'OllamaProvider does not support bidirectional WebSocket realtime sessions.',
  );
}

/// Callback-based adapter for integrating any custom app backend or proprietary
/// LLM HTTP/SSE gateway into `OmniAi`.
final class CustomAiProvider
    implements AiProvider, AiBatchEmbedProvider, AiMediaProvider {
  /// Creates a custom AI adapter from handler callbacks.
  const CustomAiProvider({
    required this.id,
    required Future<AiResponse> Function(
      OmniNetwork client,
      String model,
      List<AiMessage> messages,
      AiRequestOptions options,
      OmniCancelToken? cancelToken,
    )
    onGenerate,
    Stream<AiStreamEvent> Function(
      OmniNetwork client,
      String model,
      List<AiMessage> messages,
      AiRequestOptions options,
      OmniCancelToken? cancelToken,
    )?
    onStream,
    Future<List<double>> Function(
      OmniNetwork client,
      String model,
      String text,
      OmniCancelToken? cancelToken,
    )?
    onEmbed,
    Future<List<List<double>>> Function(
      OmniNetwork client,
      String model,
      List<String> texts,
      OmniCancelToken? cancelToken,
    )?
    onEmbedBatch,
    Future<AiTranscriptionResult> Function(
      OmniNetwork client,
      Uint8List audioBytes,
      String mimeType,
      String model,
      String? language,
      String? prompt,
      OmniCancelToken? cancelToken,
    )?
    onTranscribe,
    Future<AiSpeechResult> Function(
      OmniNetwork client,
      String text,
      String model,
      String voice,
      String format,
      OmniCancelToken? cancelToken,
    )?
    onSpeak,
    Future<List<AiGeneratedImage>> Function(
      OmniNetwork client,
      String prompt,
      String model,
      String size,
      int n,
      OmniCancelToken? cancelToken,
    )?
    onGenerateImage,
  }) : _onGenerate = onGenerate, // ignore: prefer_initializing_formals
       _onStream = onStream, // ignore: prefer_initializing_formals
       _onEmbed = onEmbed, // ignore: prefer_initializing_formals
       _onEmbedBatch = onEmbedBatch, // ignore: prefer_initializing_formals
       _onTranscribe = onTranscribe, // ignore: prefer_initializing_formals
       _onSpeak = onSpeak, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _onGenerateImage = onGenerateImage;

  @override
  final String id;

  final Future<AiResponse> Function(
    OmniNetwork client,
    String model,
    List<AiMessage> messages,
    AiRequestOptions options,
    OmniCancelToken? cancelToken,
  )
  _onGenerate;

  final Stream<AiStreamEvent> Function(
    OmniNetwork client,
    String model,
    List<AiMessage> messages,
    AiRequestOptions options,
    OmniCancelToken? cancelToken,
  )?
  _onStream;

  final Future<List<double>> Function(
    OmniNetwork client,
    String model,
    String text,
    OmniCancelToken? cancelToken,
  )?
  _onEmbed;

  final Future<List<List<double>>> Function(
    OmniNetwork client,
    String model,
    List<String> texts,
    OmniCancelToken? cancelToken,
  )?
  _onEmbedBatch;

  final Future<AiTranscriptionResult> Function(
    OmniNetwork client,
    Uint8List audioBytes,
    String mimeType,
    String model,
    String? language,
    String? prompt,
    OmniCancelToken? cancelToken,
  )?
  _onTranscribe;

  final Future<AiSpeechResult> Function(
    OmniNetwork client,
    String text,
    String model,
    String voice,
    String format,
    OmniCancelToken? cancelToken,
  )?
  _onSpeak;

  final Future<List<AiGeneratedImage>> Function(
    OmniNetwork client,
    String prompt,
    String model,
    String size,
    int n,
    OmniCancelToken? cancelToken,
  )?
  _onGenerateImage;

  @override
  bool get supportsStreaming => _onStream != null;

  @override
  bool get supportsRealtime => false;

  @override
  Future<AiResponse> generate(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) => _onGenerate(client, model, messages, options, cancelToken);

  @override
  Stream<AiStreamEvent> stream(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  }) async* {
    final s = _onStream;
    if (s != null) {
      yield* s(client, model, messages, options, cancelToken);
      return;
    }
    final res = await generate(
      client,
      model: model,
      messages: messages,
      options: options,
      cancelToken: cancelToken,
    );
    if (res.text.isNotEmpty) yield AiTextDelta(res.text);
    yield AiCompleted(res);
  }

  @override
  Future<List<double>> embed(
    OmniNetwork client, {
    required String model,
    required String text,
    OmniCancelToken? cancelToken,
  }) {
    final e = _onEmbed;
    if (e == null) {
      throw UnsupportedError('CustomAiProvider "$id" has no embed handler');
    }
    return e(client, model, text, cancelToken);
  }

  @override
  Future<List<List<double>>> embedBatch(
    OmniNetwork client, {
    required String model,
    required List<String> texts,
    OmniCancelToken? cancelToken,
  }) async {
    final batchFn = _onEmbedBatch;
    if (batchFn != null) return batchFn(client, model, texts, cancelToken);
    return [
      for (final t in texts)
        await embed(client, model: model, text: t, cancelToken: cancelToken),
    ];
  }

  @override
  Future<AiTranscriptionResult> transcribeAudio(
    OmniNetwork client, {
    required Uint8List audioBytes,
    required String mimeType,
    required String model,
    String? language,
    String? prompt,
    OmniCancelToken? cancelToken,
  }) {
    final fn = _onTranscribe;
    if (fn == null) {
      throw UnsupportedError(
        'CustomAiProvider "$id" has no transcribe handler',
      );
    }
    return fn(
      client,
      audioBytes,
      mimeType,
      model,
      language,
      prompt,
      cancelToken,
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
  }) {
    final fn = _onSpeak;
    if (fn == null) {
      throw UnsupportedError('CustomAiProvider "$id" has no speech handler');
    }
    return fn(client, text, model, voice, format, cancelToken);
  }

  @override
  Future<List<AiGeneratedImage>> generateImage(
    OmniNetwork client, {
    required String prompt,
    required String model,
    String size = '1024x1024',
    int n = 1,
    OmniCancelToken? cancelToken,
  }) {
    final fn = _onGenerateImage;
    if (fn == null) {
      throw UnsupportedError(
        'CustomAiProvider "$id" has no image generator handler',
      );
    }
    return fn(client, prompt, model, size, n, cancelToken);
  }

  @override
  Future<AiRealtimeSession> openRealtime(
    OmniNetwork client, {
    required String model,
    String? systemPrompt,
    Map<String, Object?> extra = const {},
  }) =>
      throw UnsupportedError('CustomAiProvider "$id" has no realtime handler');
}

Map<String, Object?> _encodeOpenAiMessage(AiMessage msg) {
  if (msg.role == AiRole.tool) {
    final toolPart = msg.parts.whereType<AiToolResultPart>().firstOrNull;
    return {
      'role': 'tool',
      if (toolPart != null) 'tool_call_id': toolPart.callId,
      'content': toolPart == null
          ? msg.text
          : (toolPart.result is String
                ? toolPart.result
                : jsonEncode(toolPart.result)),
    };
  }
  final calls = msg.toolCalls;
  if (msg.role == AiRole.assistant && calls.isNotEmpty) {
    return {
      'role': 'assistant',
      if (msg.text.isNotEmpty) 'content': msg.text,
      'tool_calls': [
        for (final c in calls)
          {
            'id': c.id,
            'type': 'function',
            'function': {'name': c.name, 'arguments': jsonEncode(c.arguments)},
          },
      ],
    };
  }
  final hasBinary = msg.parts.any(
    (p) =>
        p is AiImageBytesPart ||
        p is AiImageUrlPart ||
        p is AiAudioBytesPart ||
        p is AiDocumentPart,
  );
  if (!hasBinary) {
    return {
      'role': msg.role.name,
      if (msg.name != null) 'name': msg.name,
      'content': msg.text,
    };
  }
  final contentList = <Map<String, Object?>>[];
  for (final p in msg.parts) {
    switch (p) {
      case AiTextPart(:final text):
        contentList.add({'type': 'text', 'text': text});
      case AiImageBytesPart(:final bytes, :final mimeType):
        contentList.add({
          'type': 'image_url',
          'image_url': {'url': 'data:$mimeType;base64,${base64Encode(bytes)}'},
        });
      case AiImageUrlPart(:final url, :final detail):
        contentList.add({
          'type': 'image_url',
          'image_url': {'url': url, 'detail': ?detail},
        });
      case AiAudioBytesPart(:final bytes, :final mimeType):
        contentList.add({
          'type': 'input_audio',
          'input_audio': {
            'data': base64Encode(bytes),
            'format': mimeType.split('/').last,
          },
        });
      case AiDocumentPart(:final bytes, :final name, :final mimeType):
        if (mimeType.startsWith('text/') || mimeType == 'application/json') {
          contentList.add({
            'type': 'text',
            'text':
                'Document (${name ?? mimeType}):\n'
                '${utf8.decode(bytes, allowMalformed: true)}',
          });
        } else {
          contentList.add({
            'type': 'file',
            'file': {
              'filename': name ?? 'document.${_extFromMime(mimeType)}',
              'file_data': 'data:$mimeType;base64,${base64Encode(bytes)}',
            },
          });
        }
      case AiToolCallPart() || AiToolResultPart():
        break;
    }
  }
  return {'role': msg.role.name, 'content': contentList};
}

String _extFromMime(String mimeType) {
  final slash = mimeType.lastIndexOf('/');
  if (slash < 0 || slash == mimeType.length - 1) return 'bin';
  final raw = mimeType.substring(slash + 1).toLowerCase();
  return raw == 'mpeg' ? 'mp3' : raw.split(';').first;
}

String _mimeFromAudioFormat(String format) => switch (format.toLowerCase()) {
  'wav' => 'audio/wav',
  'opus' => 'audio/opus',
  'aac' => 'audio/aac',
  'flac' => 'audio/flac',
  _ => 'audio/mpeg',
};

String _guessImageMime(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

AiUsage _decodeOpenAiUsage(Map<String, Object?> usage) {
  final details = usage['completion_tokens_details'] as Map?;
  return AiUsage(
    inputTokens: usage['prompt_tokens'] as int? ?? 0,
    outputTokens: usage['completion_tokens'] as int? ?? 0,
    reasoningTokens: details?['reasoning_tokens'] as int? ?? 0,
    totalTokens: usage['total_tokens'] as int?,
  );
}

AiUsage _decodeGeminiUsage(Map<String, Object?> usage) => AiUsage(
  inputTokens: usage['promptTokenCount'] as int? ?? 0,
  outputTokens: usage['candidatesTokenCount'] as int? ?? 0,
  reasoningTokens: usage['thoughtsTokenCount'] as int? ?? 0,
  totalTokens: usage['totalTokenCount'] as int?,
);

AiFinishReason _mapFinishReason(String? reason) => switch (reason
    ?.toLowerCase()) {
  null || 'stop' || 'end_turn' => AiFinishReason.stop,
  'length' || 'max_tokens' => AiFinishReason.length,
  'tool_calls' || 'tool_use' => AiFinishReason.toolCalls,
  'content_filter' || 'safety' || 'recitation' => AiFinishReason.contentFilter,
  _ => AiFinishReason.other,
};

AiToolCallPart _parseOpenAiToolCall(Map<Object?, Object?> rawCall) {
  final fn = rawCall['function'] as Map? ?? const {};
  final rawArgs = fn['arguments'];
  return AiToolCallPart(
    id: rawCall['id'] as String? ?? '',
    name: fn['name'] as String? ?? '',
    arguments: _safeJsonMap(rawArgs),
  );
}

AiToolCallPart _parseOllamaToolCall(int idx, Map<Object?, Object?> rawCall) {
  final fn = rawCall['function'] as Map? ?? const {};
  final args = fn['arguments'];
  return AiToolCallPart(
    id: 'ollama_call_$idx',
    name: fn['name'] as String? ?? '',
    arguments: args is Map
        ? Map<String, Object?>.from(args)
        : _safeJsonMap(args),
  );
}

Map<String, Object?> _safeJsonMap(Object? raw) {
  if (raw is Map) return Map<String, Object?>.from(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {}
  }
  return const {};
}

final class _ToolAccum {
  String id = '';
  String name = '';
  final StringBuffer args = StringBuffer();
}

List<AiToolCallPart> _finalizeToolCalls(Map<int, _ToolAccum> map) {
  if (map.isEmpty) return const [];
  final keys = map.keys.toList()..sort();
  return [
    for (final k in keys)
      () {
        final acc = map[k]!;
        return AiToolCallPart(
          id: acc.id.isEmpty ? 'call_$k' : acc.id,
          name: acc.name,
          arguments: _safeJsonMap(acc.args.toString()),
        );
      }(),
  ];
}
