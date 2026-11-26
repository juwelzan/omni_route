import 'dart:async';

import '../ai/ai_models.dart';
import 'chat_models.dart';

export 'file_chat_store_stub.dart'
    if (dart.library.io) 'file_chat_store_io.dart';

/// Persistence contract for realtime chat rooms and AI assistant threads.
abstract interface class ChatStore {
  /// Loads all saved [ChatMessage] entries for [roomId] in chronological order.
  FutureOr<List<ChatMessage>> loadMessages(String roomId);

  /// Inserts or updates a single [message].
  FutureOr<void> saveMessage(ChatMessage message);

  /// Replaces/merges all saved messages for [roomId].
  FutureOr<void> saveMessages(String roomId, List<ChatMessage> messages);

  /// Marks or removes a message by [id] inside [roomId].
  FutureOr<void> deleteMessage(String roomId, String id);

  /// Clears all messages for [roomId].
  FutureOr<void> clearRoom(String roomId);

  /// Loads raw [AiMessage] conversation context for [threadId].
  FutureOr<List<AiMessage>> loadAiMessages(String threadId);

  /// Persists raw [AiMessage] context for [threadId].
  FutureOr<void> saveAiMessages(String threadId, List<AiMessage> messages);

  /// Clears saved AI context for [threadId].
  FutureOr<void> clearAiThread(String threadId);
}

/// Pure-Dart in-memory [ChatStore] used by default across Web, Mobile, and
/// Desktop.
final class MemoryChatStore implements ChatStore {
  final Map<String, List<ChatMessage>> _rooms = {};
  final Map<String, List<AiMessage>> _aiThreads = {};

  @override
  List<ChatMessage> loadMessages(String roomId) =>
      List.unmodifiable(_rooms[roomId] ?? const []);

  @override
  void saveMessage(ChatMessage message) {
    final list = _rooms.putIfAbsent(message.roomId, () => []);
    final idx = list.indexWhere(
      (m) =>
          m.id == message.id ||
          (message.localId != null &&
              (m.localId == message.localId || m.id == message.localId)),
    );
    if (idx >= 0) {
      list[idx] = message;
    } else {
      list.add(message);
    }
  }

  @override
  void saveMessages(String roomId, List<ChatMessage> messages) {
    for (final m in messages) {
      saveMessage(m);
    }
  }

  @override
  void deleteMessage(String roomId, String id) {
    _rooms[roomId]?.removeWhere((m) => m.id == id || m.localId == id);
  }

  @override
  void clearRoom(String roomId) => _rooms.remove(roomId);

  @override
  List<AiMessage> loadAiMessages(String threadId) =>
      List.unmodifiable(_aiThreads[threadId] ?? const []);

  @override
  void saveAiMessages(String threadId, List<AiMessage> messages) {
    _aiThreads[threadId] = List.of(messages);
  }

  @override
  void clearAiThread(String threadId) => _aiThreads.remove(threadId);
}
