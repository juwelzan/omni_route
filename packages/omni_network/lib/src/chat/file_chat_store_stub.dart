import '../ai/ai_models.dart';
import 'chat_models.dart';
import 'chat_store.dart';

/// Web fallback for `FileChatStore`: uses [MemoryChatStore] where direct
/// filesystem I/O is unavailable.
final class FileChatStore implements ChatStore {
  /// Creates an in-memory fallback chat store on Web.
  FileChatStore({required this.directory});

  /// Ignored on Web.
  final String directory;

  final MemoryChatStore _inner = MemoryChatStore();

  @override
  Future<List<ChatMessage>> loadMessages(String roomId) async =>
      _inner.loadMessages(roomId);

  @override
  Future<void> saveMessage(ChatMessage message) async {
    _inner.saveMessage(message);
  }

  @override
  Future<void> saveMessages(String roomId, List<ChatMessage> messages) async {
    _inner.saveMessages(roomId, messages);
  }

  @override
  Future<void> deleteMessage(String roomId, String id) async {
    _inner.deleteMessage(roomId, id);
  }

  @override
  Future<void> clearRoom(String roomId) async {
    _inner.clearRoom(roomId);
  }

  @override
  Future<List<AiMessage>> loadAiMessages(String threadId) async =>
      _inner.loadAiMessages(threadId);

  @override
  Future<void> saveAiMessages(String threadId, List<AiMessage> messages) async {
    _inner.saveAiMessages(threadId, messages);
  }

  @override
  Future<void> clearAiThread(String threadId) async {
    _inner.clearAiThread(threadId);
  }
}
