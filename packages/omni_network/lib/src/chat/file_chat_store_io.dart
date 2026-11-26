import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../ai/ai_models.dart';
import 'chat_models.dart';
import 'chat_store.dart';

/// Persistent JSON-backed [ChatStore] for IO platforms so chat rooms and AI
/// assistant threads survive app restarts.
final class FileChatStore implements ChatStore {
  /// Creates a disk-backed chat store rooted at [directory].
  FileChatStore({required this.directory});

  /// Directory where hashed room/thread files are persisted.
  final String directory;

  File _roomFile(String roomId) {
    final hash = sha256.convert(utf8.encode('room:$roomId')).toString();
    return File('$directory${Platform.pathSeparator}chat_$hash.json');
  }

  File _aiFile(String threadId) {
    final hash = sha256.convert(utf8.encode('ai:$threadId')).toString();
    return File('$directory${Platform.pathSeparator}ai_$hash.json');
  }

  Future<void> _atomicWrite(File target, Object payload) async {
    await Directory(directory).create(recursive: true);
    final temp = File('${target.path}.tmp.${pid}_${identityHashCode(payload)}');
    await temp.writeAsString(jsonEncode(payload), flush: true);
    await temp.rename(target.path);
  }

  @override
  Future<List<ChatMessage>> loadMessages(String roomId) async {
    final file = _roomFile(roomId);
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      return ChatMessage.listFromJson(decoded);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    final list = [...await loadMessages(message.roomId)];
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
    await _atomicWrite(_roomFile(message.roomId), [
      for (final m in list) m.toJson(),
    ]);
  }

  @override
  Future<void> saveMessages(String roomId, List<ChatMessage> messages) async {
    final existing = [...await loadMessages(roomId)];
    for (final message in messages) {
      final idx = existing.indexWhere(
        (m) =>
            m.id == message.id ||
            (message.localId != null &&
                (m.localId == message.localId || m.id == message.localId)),
      );
      if (idx >= 0) {
        existing[idx] = message;
      } else {
        existing.add(message);
      }
    }
    await _atomicWrite(_roomFile(roomId), [for (final m in existing) m.toJson()]);
  }

  @override
  Future<void> deleteMessage(String roomId, String id) async {
    final list = [...await loadMessages(roomId)];
    final before = list.length;
    list.removeWhere((m) => m.id == id || m.localId == id);
    if (list.length != before) {
      await _atomicWrite(_roomFile(roomId), [for (final m in list) m.toJson()]);
    }
  }

  @override
  Future<void> clearRoom(String roomId) async {
    final file = _roomFile(roomId);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<AiMessage>> loadAiMessages(String threadId) async {
    final file = _aiFile(threadId);
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map) AiMessage.fromJson(Map<String, Object?>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveAiMessages(String threadId, List<AiMessage> messages) =>
      _atomicWrite(_aiFile(threadId), [for (final m in messages) m.toJson()]);

  @override
  Future<void> clearAiThread(String threadId) async {
    final file = _aiFile(threadId);
    if (await file.exists()) await file.delete();
  }
}
