import 'dart:async';

import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../paging/omni_pager.dart';
import '../paging/pagination_strategy.dart';
import '../transfer/multipart.dart';
import 'ai_thread.dart';
import 'chat_models.dart';
import 'chat_protocol.dart';
import 'chat_store.dart';
import 'omni_chat_client.dart';

/// Live state & controls for one realtime chat room (`OmniChatClient.room`).
///
/// Combines instant optimistic delivery + `ChatStore` caching, WebSocket
/// messaging, typing indicators, read receipts, emoji reactions, edit/delete,
/// file upload with progress, cursor/page history pagination, and optional
/// `@ai` hybrid assistant integration.
final class OmniChatRoom {
  /// Internal constructor; obtain instances from [OmniChatClient.room].
  OmniChatRoom.internal({
    required this.roomId,
    required this.chatClient,
    required this.networkClient,
    required this.store,
    required this.protocol,
    this.historyEndpoint,
    this.pageStrategy = const PagePagination(pageSize: 30),
    this.historyItemsKey = 'items',
    this.uploadPath = '/files/upload',
  }) {
    final endpoint = historyEndpoint;
    if (endpoint != null) {
      _pager = networkClient.paginate<ChatMessage>(
        endpoint,
        decoder: ChatMessage.fromJson,
        itemsKey: historyItemsKey,
        strategy: pageStrategy,
        query: {'roomId': roomId},
      );
    }
  }

  /// Unique room identifier.
  final String roomId;

  /// Parent chat coordinator.
  final OmniChatClient chatClient;

  /// Underlying HTTP/WS client.
  final OmniNetwork networkClient;

  /// Local cache/persistence store.
  final ChatStore store;

  /// Wire encoder/decoder.
  final ChatProtocolAdapter protocol;

  /// Optional HTTP pagination endpoint for loading older history.
  final String? historyEndpoint;

  /// Pagination strategy used by [loadOlderMessages].
  final PaginationStrategy pageStrategy;

  /// Optional envelope key wrapping history message lists.
  final String? historyItemsKey;

  /// HTTP upload endpoint used by [sendFile].
  final String uploadPath;

  final List<ChatMessage> _messages = [];
  final Map<String, TypingIndicator> _typing = {};
  final Map<String, Timer> _typingExpiry = {};
  final Map<String, PresenceStatus> _presence = {};

  final _messagesController = StreamController<List<ChatMessage>>.broadcast();
  final _typingController =
      StreamController<Map<String, TypingIndicator>>.broadcast();
  final _presenceController =
      StreamController<Map<String, PresenceStatus>>.broadcast();

  OmniPager<ChatMessage>? _pager;
  Timer? _myTypingTimer;
  bool _restored = false;
  bool _closed = false;
  bool _isLoadingHistory = false;
  int _unreadCount = 0;
  int _seq = 0;
  StreamSubscription<List<ChatMessage>>? _aiSub;

  /// Current chronological message list (unmodifiable snapshot).
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Broadcast stream emitting updated message lists on every change.
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;

  /// Active typing indicators keyed by user id.
  Map<String, TypingIndicator> get typingUsers => Map.unmodifiable(_typing);

  /// Broadcast stream of typing state changes.
  Stream<Map<String, TypingIndicator>> get typingStream =>
      _typingController.stream;

  /// Latest user presence map.
  Map<String, PresenceStatus> get presence => Map.unmodifiable(_presence);

  /// Broadcast stream of presence updates.
  Stream<Map<String, PresenceStatus>> get presenceStream =>
      _presenceController.stream;

  /// Unread message count incremented on incoming non-self messages until
  /// [markAsRead] runs.
  int get unreadCount => _unreadCount;

  /// Whether [loadOlderMessages] is currently running.
  bool get isLoadingHistory => _isLoadingHistory;

  /// Restores locally cached messages from [store].
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final cached = await store.loadMessages(roomId);
    if (cached.isNotEmpty) {
      final decoded = [for (final m in cached) await _decryptMessage(m)];
      _mergeMessages(decoded);
    }
  }

  /// Searches room history (restoring local cache if needed) by text [query],
  /// optional [senderId], [isAi] flag, or [hasAttachments].
  Future<List<ChatMessage>> search(
    String query, {
    String? senderId,
    bool? isAi,
    bool? hasAttachments,
  }) async {
    await restore();
    final q = query.trim().toLowerCase();
    return [
      for (final m in _messages)
        if (!m.isDeleted &&
            (senderId == null || m.senderId == senderId) &&
            (isAi == null || m.isAi == isAi) &&
            (hasAttachments == null ||
                hasAttachments ==
                    m.parts.any((p) => p is ChatMediaPart || p is ChatFilePart)) &&
            (q.isEmpty ||
                m.text.toLowerCase().contains(q) ||
                (m.senderName?.toLowerCase().contains(q) ?? false) ||
                m.parts.any(
                  (p) => switch (p) {
                    ChatFilePart(:final name) => name.toLowerCase().contains(q),
                    ChatMediaPart(:final name?) => name.toLowerCase().contains(q),
                    _ => false,
                  },
                )))
          m,
    ];
  }

  /// Returns the parent message (if cached locally) followed by all replies
  /// referencing [parentMessageId] in chronological order.
  List<ChatMessage> threadMessages(String parentMessageId) => [
    for (final m in _messages)
      if (m.id == parentMessageId || m.replyToId == parentMessageId) m,
  ];

  /// Sends a plain-text message optimistically.
  Future<ChatMessage> sendText(String text, {String? replyToId}) =>
      sendParts([ChatPart.text(text)], replyToId: replyToId);

  /// Sends rich multimodal [parts] optimistically and queues when offline.
  Future<ChatMessage> sendParts(
    List<ChatPart> parts, {
    String? replyToId,
  }) async {
    if (_closed) throw const ClosedFailure();
    await restore();
    final localId =
        'loc_${chatClient.currentUserId}_${++_seq}_${DateTime.now().microsecondsSinceEpoch}';
    final msg = ChatMessage(
      id: localId,
      localId: localId,
      roomId: roomId,
      senderId: chatClient.currentUserId,
      senderName: chatClient.currentUserName,
      parts: parts,
      createdAt: DateTime.now().toUtc(),
      replyToId: replyToId,
      status: MessageDeliveryStatus.sending,
    );
    _upsert(msg);
    await _saveToStore(msg);
    await _dispatchSend(msg);
    return msg;
  }

  /// Uploads [file] via `OmniNetwork.upload` (with optional [onProgress]), then
  /// sends the resulting URL as a media or file chat message.
  Future<ChatMessage> sendFile(
    UploadFile file, {
    String? caption,
    ProgressCallback? onProgress,
    String? replyToId,
    String? overrideUploadPath,
  }) async {
    final res = await networkClient.upload<Map<String, dynamic>>(
      overrideUploadPath ?? uploadPath,
      files: [file],
      fields: {'roomId': roomId},
      onProgress: onProgress,
    );
    final url = res['url'] as String? ?? '';
    final mime = file.contentType;
    final isMedia =
        mime.startsWith('image/') ||
        mime.startsWith('audio/') ||
        mime.startsWith('video/');
    return sendParts([
      if (isMedia)
        ChatMediaPart(
          url: url,
          mimeType: mime,
          name: file.filename,
          sizeBytes: file.length,
        )
      else
        ChatFilePart(
          url: url,
          name: file.filename,
          mimeType: mime,
          sizeBytes: file.length,
        ),
      if (caption != null && caption.isNotEmpty) ChatTextPart(caption),
    ], replyToId: replyToId);
  }

  Future<void> _dispatchSend(ChatMessage msg) async {
    final wireMsg = await _encryptMessage(msg);
    final sent = await chatClient.transmitFrame(
      protocol.encodeSend(wireMsg),
      enqueueFallback: wireMsg,
    );
    if (!sent && msg.localId != null) {
      // Keep status `sending` when buffered/offline queued; caller gets instant UI.
      return;
    }
  }

  /// Retries sending a previously failed local message.
  Future<void> retryFailed(String localOrId) async {
    final idx = _messages.indexWhere(
      (m) => m.id == localOrId || m.localId == localOrId,
    );
    if (idx < 0) return;
    final updated = _messages[idx].copyWith(
      status: MessageDeliveryStatus.sending,
    );
    _messages[idx] = updated;
    await store.saveMessage(updated);
    _emitMessages();
    await _dispatchSend(updated);
  }

  /// Broadcasts typing state and automatically stops after 3 seconds if
  /// [isTyping] is `true`.
  void setTyping(bool isTyping) {
    if (_closed) return;
    _myTypingTimer?.cancel();
    unawaited(
      chatClient.transmitFrame(
        protocol.encodeTyping(
          roomId,
          chatClient.currentUserId,
          chatClient.currentUserName,
          isTyping,
        ),
      ),
    );
    if (isTyping) {
      _myTypingTimer = Timer(const Duration(seconds: 3), () => setTyping(false));
    }
  }

  /// Marks messages up to [messageId] as read and notifies the server.
  Future<void> markAsRead(String messageId) async {
    _unreadCount = 0;
    _emitMessages();
    await chatClient.transmitFrame(
      protocol.encodeReadReceipt(roomId, messageId, chatClient.currentUserId),
    );
  }

  /// Toggles an emoji reaction locally (optimistically) and notifies the server.
  Future<void> toggleReaction(String messageId, String emoji) async {
    var targetId = messageId;
    final idx = _messages.indexWhere(
      (m) => m.id == messageId || m.localId == messageId,
    );
    if (idx >= 0) {
      final m = _messages[idx];
      targetId = m.id;
      final next = {
        for (final e in m.reactions.entries) e.key: [...e.value],
      };
      final users = next.putIfAbsent(emoji, () => []);
      if (users.contains(chatClient.currentUserId)) {
        users.remove(chatClient.currentUserId);
        if (users.isEmpty) next.remove(emoji);
      } else {
        users.add(chatClient.currentUserId);
      }
      final updated = m.copyWith(reactions: next);
      _messages[idx] = updated;
      await store.saveMessage(updated);
      _emitMessages();
    }
    await chatClient.transmitFrame(
      protocol.encodeReaction(roomId, targetId, emoji, chatClient.currentUserId),
    );
  }

  /// Edits a sent message's text optimistically and notifies the server.
  Future<void> editMessage(String messageId, String newText) async {
    var targetId = messageId;
    final idx = _messages.indexWhere(
      (m) => m.id == messageId || m.localId == messageId,
    );
    if (idx >= 0) {
      targetId = _messages[idx].id;
      final updated = _messages[idx].copyWith(
        parts: [ChatTextPart(newText)],
        editedAt: DateTime.now().toUtc(),
      );
      _messages[idx] = updated;
      await _saveToStore(updated);
      _emitMessages();
    }
    final cipher = chatClient.cipher;
    final wireText = cipher == null ? newText : await cipher.encrypt(newText);
    await chatClient.transmitFrame(
      protocol.encodeEdit(roomId, targetId, wireText),
    );
  }

  /// Soft-deletes a message locally and notifies the server.
  Future<void> deleteMessage(String messageId) async {
    var targetId = messageId;
    final idx = _messages.indexWhere(
      (m) => m.id == messageId || m.localId == messageId,
    );
    if (idx >= 0) {
      targetId = _messages[idx].id;
      final updated = _messages[idx].copyWith(isDeleted: true, parts: const []);
      _messages[idx] = updated;
      await store.saveMessage(updated);
      _emitMessages();
    }
    await chatClient.transmitFrame(protocol.encodeDelete(roomId, targetId));
  }

  /// Loads the next older page of messages from [historyEndpoint] (using
  /// [OmniPager]), caches in [store], and merges without duplicates.
  Future<List<ChatMessage>> loadOlderMessages() async {
    final pager = _pager;
    if (pager == null || _isLoadingHistory || !pager.hasMore) {
      return const [];
    }
    _isLoadingHistory = true;
    _emitMessages();
    try {
      final page = await pager.next();
      if (page.isNotEmpty) {
        _mergeMessages(page);
        await store.saveMessages(roomId, page);
      }
      return page;
    } finally {
      _isLoadingHistory = false;
      _emitMessages();
    }
  }

  /// Connects an [OmniAiThread] into this room: whenever a human participant
  /// sends a message starting with [triggerPrefix] (e.g. `'@ai'`), the AI
  /// answers and posts the response back into this room.
  void attachAiAssistant(
    OmniAiThread thread, {
    String triggerPrefix = '@ai',
  }) {
    _aiSub?.cancel();
    final handledIds = <String>{};
    _aiSub = messagesStream.listen((list) {
      if (list.isEmpty) return;
      final latest = list.last;
      if (latest.isAi || handledIds.contains(latest.id)) return;
      final trimmed = latest.text.trim();
      if (!trimmed.toLowerCase().startsWith(triggerPrefix.toLowerCase())) {
        return;
      }
      handledIds.add(latest.id);
      final query = trimmed.substring(triggerPrefix.length).trim();
      if (query.isEmpty) return;
      unawaited(() async {
        try {
          final reply = await thread.sendAndWait(query);
          final botMsg = ChatMessage.text(
            id: 'bot_${++_seq}_${DateTime.now().microsecondsSinceEpoch}',
            roomId: roomId,
            senderId: 'assistant',
            senderName: reply.senderName ?? thread.model,
            isAi: true,
            text: reply.text,
            replyToId: latest.id,
            thinking: reply.thinking,
            model: reply.model,
            usage: reply.usage,
          );
          _upsert(botMsg);
          await store.saveMessage(botMsg);
          await chatClient.transmitFrame(protocol.encodeSend(botMsg));
        } catch (_) {}
      }());
    });
  }

  /// Processes an inbound decoded [ChatInboundEvent] targeting this room.
  void handleInboundEvent(ChatInboundEvent event) {
    if (_closed) return;
    switch (event) {
      case ChatMessageReceived(:final message):
        if (chatClient.cipher != null && message.metadata['_e2ee'] == true) {
          unawaited(_acceptEncryptedInbound(message));
          return;
        }
        _upsert(message);
        if (message.senderId != chatClient.currentUserId && !message.isAi) {
          _unreadCount++;
        }
        _persist(message);
      case ChatMessageAcked(:final localId, :final serverId, :final status, :final createdAt):
        final idx = _messages.indexWhere(
          (m) => m.localId == localId || m.id == localId,
        );
        if (idx >= 0) {
          final existing = _messages[idx];
          final confirmed = ChatMessage(
            id: serverId,
            localId: localId,
            roomId: existing.roomId,
            senderId: existing.senderId,
            senderName: existing.senderName,
            isAi: existing.isAi,
            parts: existing.parts,
            createdAt: createdAt ?? existing.createdAt,
            replyToId: existing.replyToId,
            reactions: existing.reactions,
            status: status,
            editedAt: existing.editedAt,
            isDeleted: existing.isDeleted,
            thinking: existing.thinking,
            model: existing.model,
            usage: existing.usage,
            metadata: existing.metadata,
          );
          _messages[idx] = confirmed;
          _persist(confirmed);
          _emitMessages();
        }
      case ChatDeliveryUpdated(:final messageId, :final status):
        final idx = _messages.indexWhere(
          (m) => m.id == messageId || m.localId == messageId,
        );
        if (idx >= 0) {
          final updated = _messages[idx].copyWith(status: status);
          _messages[idx] = updated;
          _persist(updated);
          _emitMessages();
        }
      case ChatMessageEdited(:final messageId, :final parts, :final editedAt):
        final idx = _messages.indexWhere(
          (m) => m.id == messageId || m.localId == messageId,
        );
        if (idx >= 0) {
          final updated = _messages[idx].copyWith(
            parts: parts,
            editedAt: editedAt,
          );
          _messages[idx] = updated;
          _persist(updated);
          _emitMessages();
        }
      case ChatMessageDeleted(:final messageId):
        final idx = _messages.indexWhere(
          (m) => m.id == messageId || m.localId == messageId,
        );
        if (idx >= 0) {
          final updated = _messages[idx].copyWith(
            isDeleted: true,
            parts: const [],
          );
          _messages[idx] = updated;
          _persist(updated);
          _emitMessages();
        }
      case ChatReactionToggled(:final messageId, :final emoji, :final userId, :final added):
        final idx = _messages.indexWhere(
          (m) => m.id == messageId || m.localId == messageId,
        );
        if (idx >= 0) {
          final next = {
            for (final e in _messages[idx].reactions.entries) e.key: [...e.value],
          };
          final list = next.putIfAbsent(emoji, () => []);
          if (added) {
            if (!list.contains(userId)) list.add(userId);
          } else {
            list.remove(userId);
            if (list.isEmpty) next.remove(emoji);
          }
          final updated = _messages[idx].copyWith(reactions: next);
          _messages[idx] = updated;
          _persist(updated);
          _emitMessages();
        }
      case ChatTypingEvent(:final indicator):
        if (indicator.userId == chatClient.currentUserId) return;
        _typingExpiry[indicator.userId]?.cancel();
        if (indicator.isTyping) {
          _typing[indicator.userId] = indicator;
          _typingExpiry[indicator.userId] = Timer(
            const Duration(seconds: 4),
            () {
              _typing.remove(indicator.userId);
              if (!_typingController.isClosed) {
                _typingController.add(Map.unmodifiable(_typing));
              }
            },
          );
        } else {
          _typing.remove(indicator.userId);
        }
        if (!_typingController.isClosed) {
          _typingController.add(Map.unmodifiable(_typing));
        }
      case ChatPresenceEvent(:final presence):
        _presence[presence.userId] = presence;
        if (!_presenceController.isClosed) {
          _presenceController.add(Map.unmodifiable(_presence));
        }
    }
  }

  /// Clears stored messages and releases room resources.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _myTypingTimer?.cancel();
    for (final t in _typingExpiry.values) {
      t.cancel();
    }
    _typingExpiry.clear();
    await _aiSub?.cancel();
    await _pager?.close();
    unawaited(chatClient.transmitFrame(protocol.encodeLeave(roomId)));
    if (!_messagesController.isClosed) await _messagesController.close();
    if (!_typingController.isClosed) await _typingController.close();
    if (!_presenceController.isClosed) await _presenceController.close();
    chatClient.unregisterRoom(roomId);
  }

  void _upsert(ChatMessage message) {
    final idx = _messages.indexWhere(
      (m) =>
          m.id == message.id ||
          (message.localId != null &&
              (m.localId == message.localId || m.id == message.localId)),
    );
    if (idx >= 0) {
      _messages[idx] = message;
    } else {
      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    _emitMessages();
  }

  void _mergeMessages(List<ChatMessage> incoming) {
    for (final m in incoming) {
      final idx = _messages.indexWhere(
        (e) =>
            e.id == m.id ||
            (m.localId != null && (e.localId == m.localId || e.id == m.localId)),
      );
      if (idx >= 0) {
        _messages[idx] = m;
      } else {
        _messages.add(m);
      }
    }
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _emitMessages();
  }

  Future<ChatMessage> _encryptMessage(ChatMessage m) async {
    final cipher = chatClient.cipher;
    if (cipher == null || m.parts.every((p) => p is! ChatTextPart)) return m;
    final nextParts = <ChatPart>[
      for (final p in m.parts)
        if (p is ChatTextPart) ChatTextPart(await cipher.encrypt(p.text)) else p,
    ];
    return m.copyWith(
      parts: nextParts,
      metadata: {...m.metadata, '_e2ee': true},
    );
  }

  Future<ChatMessage> _decryptMessage(ChatMessage m) async {
    final cipher = chatClient.cipher;
    if (cipher == null || m.metadata['_e2ee'] != true) return m;
    final nextParts = <ChatPart>[
      for (final p in m.parts)
        if (p is ChatTextPart) ChatTextPart(await cipher.decrypt(p.text)) else p,
    ];
    final nextMeta = Map<String, Object?>.of(m.metadata)..remove('_e2ee');
    return m.copyWith(parts: nextParts, metadata: nextMeta);
  }

  Future<void> _acceptEncryptedInbound(ChatMessage message) async {
    final decrypted = await _decryptMessage(message);
    if (_closed) return;
    _upsert(decrypted);
    if (decrypted.senderId != chatClient.currentUserId && !decrypted.isAi) {
      _unreadCount++;
    }
    await _saveToStore(decrypted);
  }

  Future<void> _saveToStore(ChatMessage message) async {
    final toSave = chatClient.encryptLocalStore
        ? await _encryptMessage(message)
        : message;
    await store.saveMessage(toSave);
  }

  void _persist(ChatMessage message) {
    if (!chatClient.encryptLocalStore || chatClient.cipher == null) {
      final res = store.saveMessage(message);
      if (res is Future<void>) unawaited(res);
      return;
    }
    unawaited(_saveToStore(message));
  }

  void _emitMessages() {
    if (!_messagesController.isClosed) {
      _messagesController.add(List.unmodifiable(_messages));
    }
  }
}
