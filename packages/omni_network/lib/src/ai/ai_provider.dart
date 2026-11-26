import 'dart:async';
import 'dart:typed_data';

import '../core/cancel_token.dart';
import '../core/omni_network.dart';
import '../realtime/web_socket.dart';
import 'ai_models.dart';

/// Live bidirectional WebSocket session with a real-time AI model (such as
/// OpenAI Realtime or Gemini Live).
final class AiRealtimeSession {
  /// Creates a session wrapping [socket].
  AiRealtimeSession({
    required this.socket,
    required Stream<AiRealtimeEvent> events,
    required void Function(String text) sendTextImpl,
    required void Function(Uint8List audio, String mimeType) sendAudioImpl,
    Future<void> Function()? closeImpl,
  }) : _events = events, // ignore: prefer_initializing_formals
       _sendText = sendTextImpl,
       _sendAudio = sendAudioImpl,
       _closeImpl = closeImpl; // ignore: prefer_initializing_formals

  /// Underlying reconnecting WebSocket managed by `OmniNetwork`.
  final OmniWebSocket socket;

  final Stream<AiRealtimeEvent> _events;
  final void Function(String text) _sendText;
  final void Function(Uint8List audio, String mimeType) _sendAudio;
  final Future<void> Function()? _closeImpl;

  /// Broadcast stream of normalized AI realtime events (`AiRealtimeTextDelta`,
  /// `AiRealtimeAudioDelta`, `AiRealtimeJsonEvent`).
  Stream<AiRealtimeEvent> get events => _events;

  /// Socket connection state stream.
  Stream<WebSocketState> get states => socket.states;

  /// Sends a text prompt/turn over the open WebSocket and requests a reply.
  void sendText(String text) => _sendText(text);

  /// Streams raw PCM/audio frame bytes into the live model session.
  void sendAudio(Uint8List audioBytes, {String mimeType = 'audio/pcm'}) =>
      _sendAudio(audioBytes, mimeType);

  /// Sends an arbitrary raw JSON frame to the backend.
  void sendJson(Map<String, Object?> payload) => socket.sendJson(payload);

  /// Closes the live AI session and underlying WebSocket.
  Future<void> close() async {
    await _closeImpl?.call();
    await socket.close();
  }
}

/// Pluggable backend adapter implemented by every AI provider in `OmniAi`.
abstract interface class AiProvider {
  /// Provider identifier (e.g. `'openai'`, `'gemini'`, `'claude'`, `'ollama'`).
  String get id;

  /// Whether [stream] produces true incremental deltas natively.
  bool get supportsStreaming;

  /// Whether [openRealtime] supports bidirectional WebSocket streaming.
  bool get supportsRealtime;

  /// Generates a single complete turn (supports multimodal parts & tool calls).
  Future<AiResponse> generate(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  });

  /// Streams incremental deltas ending with [AiCompleted].
  Stream<AiStreamEvent> stream(
    OmniNetwork client, {
    required String model,
    required List<AiMessage> messages,
    AiRequestOptions options = const AiRequestOptions(),
    OmniCancelToken? cancelToken,
  });

  /// Computes a dense vector embedding for [text].
  Future<List<double>> embed(
    OmniNetwork client, {
    required String model,
    required String text,
    OmniCancelToken? cancelToken,
  });

  /// Opens a bidirectional WebSocket session (optional per provider).
  Future<AiRealtimeSession> openRealtime(
    OmniNetwork client, {
    required String model,
    String? systemPrompt,
    Map<String, Object?> extra = const {},
  });
}
