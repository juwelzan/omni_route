import 'dart:async';

import 'package:meta/meta.dart';

import '../core/omni_network.dart';
import '../core/omni_request.dart';
import '../paging/pagination_strategy.dart';
import '../queue/queued_request.dart';
import '../realtime/web_socket.dart';
import '../realtime/ws_protocol.dart';
import 'chat_models.dart';
import 'chat_protocol.dart';
import 'chat_room.dart';
import 'chat_store.dart';

/// Configuration for `OmniChatClient`.
@immutable
final class ChatConfig {
  /// Creates realtime chat defaults.
  const ChatConfig({
    this.wsPath = '/chat/ws',
    this.currentUserId = 'me',
    this.currentUserName,
    this.protocol = const DefaultChatProtocol(),
    this.webAuthMode,
    this.fallbackHttpSendPath,
    this.uploadPath = '/files/upload',
  });

  /// Default WebSocket endpoint path or URL.
  final String wsPath;

  /// Authenticated local user id used on optimistic outgoing messages.
  final String currentUserId;

  /// Optional display name for local outgoing messages & typing events.
  final String? currentUserName;

  /// Wire encoder/decoder.
  final ChatProtocolAdapter protocol;

  /// Optional browser WebSocket auth mode override.
  final WsWebAuthMode? webAuthMode;

  /// Optional HTTP POST fallback endpoint when WebSocket is disconnected.
  final String? fallbackHttpSendPath;

  /// Default file upload endpoint for media/document attachments.
  final String uploadPath;
}

/// Unified realtime chat coordinator managing a shared [OmniWebSocket],
/// offline message persistence (`QueueStore` / `ChatStore`), typing & presence
/// multiplexing, and per-room controllers ([room]).
final class OmniChatClient {
  /// Creates a chat coordinator backed by `OmniNetwork` [networkClient].
  OmniChatClient({
    required OmniNetwork networkClient,
    ChatConfig config = const ChatConfig(),
    ChatStore? store,
    QueueStore? offlineQueueStore,
    WebSocketConnector? connector,
  }) : _network = networkClient,
       currentUserId = config.currentUserId,
       currentUserName = config.currentUserName,
       protocol = config.protocol,
       store = store ?? MemoryChatStore(),
       _offlineStore = offlineQueueStore,
       _wsPath = config.wsPath,
       _webAuthMode = config.webAuthMode,
       _fallbackHttpSendPath = config.fallbackHttpSendPath,
       _uploadPath = config.uploadPath,
       _connector = connector; // ignore: prefer_initializing_formals

  final OmniNetwork _network;

  /// Current local participant id.
  final String currentUserId;

  /// Current local participant display name.
  final String? currentUserName;

  /// Wire protocol adapter.
  final ChatProtocolAdapter protocol;

  /// Chat message persistence store.
  final ChatStore store;

  final QueueStore? _offlineStore;
  final String _wsPath;
  final WsWebAuthMode? _webAuthMode;
  final String? _fallbackHttpSendPath;
  final String _uploadPath;
  final WebSocketConnector? _connector;

  final Map<String, OmniChatRoom> _rooms = {};
  final List<Object> _pendingFrames = [];
  OmniWebSocket? _socket;
  StreamSubscription<Object>? _msgSub;
  bool _closed = false;

  /// Active underlying WebSocket if connected/connecting.
  OmniWebSocket? get socket => _socket;

  /// Opens or returns an active [OmniChatRoom] for [roomId] and automatically
  /// subscribes over WebSocket.
  OmniChatRoom room(
    String roomId, {
    String? historyEndpoint,
    PaginationStrategy pageStrategy = const PagePagination(pageSize: 30),
    String? historyItemsKey = 'items',
    String? uploadPath,
  }) {
    final existing = _rooms[roomId];
    if (existing != null) return existing;
    _ensureConnected();
    final created = OmniChatRoom.internal(
      roomId: roomId,
      chatClient: this,
      networkClient: _network,
      store: store,
      protocol: protocol,
      historyEndpoint: historyEndpoint,
      pageStrategy: pageStrategy,
      historyItemsKey: historyItemsKey,
      uploadPath: uploadPath ?? _uploadPath,
    );
    _rooms[roomId] = created;
    unawaited(created.restore());
    if (_socket?.state == WebSocketState.open) {
      _socket!.send(protocol.encodeJoin(roomId));
    }
    return created;
  }

  /// Ensures the shared WebSocket connection is open cleanly and flushes any
  /// queued offline frames once reconnected.
  OmniWebSocket connect() => _ensureConnected();

  OmniWebSocket _ensureConnected() {
    final current = _socket;
    if (current != null && current.state != WebSocketState.closed) {
      return current;
    }
    final ws = _socket = _network.ws(
      _wsPath,
      bufferWhileDisconnected: true,
      webAuthMode: _webAuthMode,
      connector: _connector,
      onOpen: (s) {
        for (final roomId in _rooms.keys) {
          s.send(protocol.encodeJoin(roomId));
        }
        while (_pendingFrames.isNotEmpty) {
          s.send(_pendingFrames.removeAt(0));
        }
        unawaited(_flushOfflineQueue());
      },
    );
    _msgSub?.cancel();
    _msgSub = ws.messages.listen(_onRawMessage, onError: (_) {});
    return ws;
  }

  void _onRawMessage(Object raw) {
    final event = protocol.decode(raw);
    if (event == null) return;
    switch (event) {
      case ChatMessageReceived(:final message):
        _rooms[message.roomId]?.handleInboundEvent(event);
      case ChatMessageAcked(:final roomId):
        _rooms[roomId]?.handleInboundEvent(event);
      case ChatDeliveryUpdated(:final roomId):
        _rooms[roomId]?.handleInboundEvent(event);
      case ChatMessageEdited(:final roomId):
        _rooms[roomId]?.handleInboundEvent(event);
      case ChatMessageDeleted(:final roomId):
        _rooms[roomId]?.handleInboundEvent(event);
      case ChatReactionToggled(:final roomId):
        _rooms[roomId]?.handleInboundEvent(event);
      case ChatTypingEvent(:final indicator):
        _rooms[indicator.roomId]?.handleInboundEvent(event);
      case ChatPresenceEvent():
        for (final room in _rooms.values) {
          room.handleInboundEvent(event);
        }
    }
  }

  /// Sends a wire frame over WebSocket (or buffers/persists offline when
  /// disconnected). Returns `true` if immediately handed to open WebSocket.
  Future<bool> transmitFrame(
    Object frame, {
    ChatMessage? enqueueFallback,
  }) async {
    if (_closed) return false;
    final s = _ensureConnected();
    if (s.state == WebSocketState.open) {
      s.send(frame);
      return true;
    }
    final fallbackPath = _fallbackHttpSendPath;
    if (enqueueFallback != null && fallbackPath != null) {
      try {
        await _network.post<Object?>(
          fallbackPath,
          body: enqueueFallback.toJson(),
        );
        return true;
      } catch (_) {
        // Fall through to offline buffer/store.
      }
    }
    if (enqueueFallback != null && _offlineStore != null) {
      final key = enqueueFallback.localId ?? enqueueFallback.id;
      final item = QueuedRequest(
        id: key,
        method: HttpMethod.post,
        path: fallbackPath ?? '/chat/send',
        headers: {'idempotency-key': key},
        body: enqueueFallback.toJson(),
        createdAt: DateTime.now().toUtc(),
      );
      await _offlineStore.add(item);
      return false;
    }
    try {
      s.send(frame); // Will use bufferWhileDisconnected cleanly when connecting.
    } catch (_) {
      _pendingFrames.add(frame);
    }
    return false;
  }

  Future<void> _flushOfflineQueue() async {
    final store = _offlineStore;
    if (store == null || _socket?.state != WebSocketState.open) return;
    final items = await store.all();
    for (final item in items) {
      try {
        if (item.body is Map) {
          final msg = ChatMessage.fromJson(Map<String, Object?>.from(item.body! as Map));
          _socket!.send(protocol.encodeSend(msg));
        }
        await store.remove(item.id);
      } catch (_) {
        break;
      }
    }
  }

  /// Called when an [OmniChatRoom] closes individually.
  void unregisterRoom(String roomId) {
    _rooms.remove(roomId);
  }

  /// Closes all open rooms, subscriptions, and shared WebSocket.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final r in _rooms.values.toList()) {
      await r.close();
    }
    _rooms.clear();
    await _msgSub?.cancel();
    await _socket?.close();
  }
}
