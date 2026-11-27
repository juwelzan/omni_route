import 'dart:convert';

import 'package:meta/meta.dart';

import 'chat_models.dart';

/// Normalized inbound event parsed from any backend WebSocket chat payload.
@immutable
sealed class ChatInboundEvent {
  const ChatInboundEvent();
}

/// Server delivered a new message (from another user or broadcast echo).
final class ChatMessageReceived extends ChatInboundEvent {
  /// Creates a message-received event.
  const ChatMessageReceived(this.message);

  /// Incoming chat message.
  final ChatMessage message;
}

/// Server acknowledged an outgoing optimistic message (mapping `localId` to
/// canonical server [serverId]).
final class ChatMessageAcked extends ChatInboundEvent {
  /// Creates an ack event.
  const ChatMessageAcked({
    required this.roomId,
    required this.localId,
    required this.serverId,
    this.status = MessageDeliveryStatus.sent,
    this.createdAt,
  });

  /// Target room.
  final String roomId;

  /// Client-generated optimistic id.
  final String localId;

  /// Server-assigned id.
  final String serverId;

  /// Confirmed status.
  final MessageDeliveryStatus status;

  /// Optional server timestamp.
  final DateTime? createdAt;
}

/// Delivery / read receipt update for one or more messages in [roomId].
final class ChatDeliveryUpdated extends ChatInboundEvent {
  /// Creates a delivery receipt event.
  const ChatDeliveryUpdated({
    required this.roomId,
    required this.messageId,
    required this.status,
  });

  /// Room id.
  final String roomId;

  /// Message id updated.
  final String messageId;

  /// New delivery status (`delivered` or `read`).
  final MessageDeliveryStatus status;
}

/// Message content edited on the server.
final class ChatMessageEdited extends ChatInboundEvent {
  /// Creates a message-edited event.
  const ChatMessageEdited({
    required this.roomId,
    required this.messageId,
    required this.parts,
    required this.editedAt,
  });

  /// Room id.
  final String roomId;

  /// Target message id.
  final String messageId;

  /// Updated parts.
  final List<ChatPart> parts;

  /// Edit timestamp.
  final DateTime editedAt;
}

/// Message soft-deleted on the server.
final class ChatMessageDeleted extends ChatInboundEvent {
  /// Creates a message-deleted event.
  const ChatMessageDeleted({required this.roomId, required this.messageId});

  /// Room id.
  final String roomId;

  /// Deleted message id.
  final String messageId;
}

/// Emoji reaction toggled on a message.
final class ChatReactionToggled extends ChatInboundEvent {
  /// Creates a reaction event.
  const ChatReactionToggled({
    required this.roomId,
    required this.messageId,
    required this.emoji,
    required this.userId,
    required this.added,
  });

  /// Room id.
  final String roomId;

  /// Target message id.
  final String messageId;

  /// Emoji string.
  final String emoji;

  /// Reacting participant id.
  final String userId;

  /// Whether the reaction was added (`true`) or removed (`false`).
  final bool added;
}

/// Typing status notification.
final class ChatTypingEvent extends ChatInboundEvent {
  /// Creates a typing event.
  const ChatTypingEvent(this.indicator);

  /// Typing state.
  final TypingIndicator indicator;
}

/// User presence update notification.
final class ChatPresenceEvent extends ChatInboundEvent {
  /// Creates a presence event.
  const ChatPresenceEvent(this.presence);

  /// Presence update.
  final PresenceStatus presence;
}

/// Translates between `OmniChatClient` domain events and your backend's
/// WebSocket JSON wire format.
abstract interface class ChatProtocolAdapter {
  /// Encodes joining a chat [roomId].
  Object encodeJoin(String roomId);

  /// Encodes leaving a chat [roomId].
  Object encodeLeave(String roomId);

  /// Encodes sending [message].
  Object encodeSend(ChatMessage message);

  /// Encodes typing status change.
  Object encodeTyping(
    String roomId,
    String userId,
    String? userName,
    bool isTyping,
  );

  /// Encodes marking messages up to [messageId] as read.
  Object encodeReadReceipt(String roomId, String messageId, String userId);

  /// Encodes toggling an emoji reaction.
  Object encodeReaction(
    String roomId,
    String messageId,
    String emoji,
    String userId,
  );

  /// Encodes editing a message.
  Object encodeEdit(String roomId, String messageId, String newText);

  /// Encodes deleting a message.
  Object encodeDelete(String roomId, String messageId);

  /// Decodes an incoming raw WebSocket frame, or `null` if unrelated.
  ChatInboundEvent? decode(Object rawMessage);
}

/// Default JSON WebSocket protocol (`{ "event": "...", "data": { ... } }`)
/// matching `DefaultWsProtocol`.
final class DefaultChatProtocol implements ChatProtocolAdapter {
  /// Creates the default chat wire protocol.
  const DefaultChatProtocol({this.eventKey = 'event', this.dataKey = 'data'});

  /// Field holding the event name (default `'event'`).
  final String eventKey;

  /// Field holding the payload object (default `'data'`).
  final String dataKey;

  String _wire(String event, Map<String, Object?> data) =>
      jsonEncode({eventKey: event, dataKey: data});

  @override
  Object encodeJoin(String roomId) => _wire('chat.join', {'roomId': roomId});

  @override
  Object encodeLeave(String roomId) => _wire('chat.leave', {'roomId': roomId});

  @override
  Object encodeSend(ChatMessage message) =>
      _wire('chat.send', message.toJson());

  @override
  Object encodeTyping(
    String roomId,
    String userId,
    String? userName,
    bool isTyping,
  ) => _wire('chat.typing', {
    'roomId': roomId,
    'userId': userId,
    'userName': ?userName,
    'isTyping': isTyping,
  });

  @override
  Object encodeReadReceipt(String roomId, String messageId, String userId) =>
      _wire('chat.read', {
        'roomId': roomId,
        'messageId': messageId,
        'userId': userId,
      });

  @override
  Object encodeReaction(
    String roomId,
    String messageId,
    String emoji,
    String userId,
  ) => _wire('chat.reaction', {
    'roomId': roomId,
    'messageId': messageId,
    'emoji': emoji,
    'userId': userId,
  });

  @override
  Object encodeEdit(String roomId, String messageId, String newText) => _wire(
    'chat.edit',
    {'roomId': roomId, 'messageId': messageId, 'text': newText},
  );

  @override
  Object encodeDelete(String roomId, String messageId) =>
      _wire('chat.delete', {'roomId': roomId, 'messageId': messageId});

  @override
  ChatInboundEvent? decode(Object rawMessage) {
    if (rawMessage is! String) return null;
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) return null;
      final event = decoded[eventKey] as String?;
      final rawData = decoded[dataKey];
      if (event == null || rawData is! Map) return null;
      final data = Map<String, Object?>.from(rawData);
      return switch (event) {
        'chat.message' => ChatMessageReceived(ChatMessage.fromJson(data)),
        'chat.ack' => ChatMessageAcked(
          roomId: data['roomId']! as String,
          localId: data['localId']! as String,
          serverId: data['serverId']! as String,
          status: MessageDeliveryStatus.values.byName(
            data['status'] as String? ?? 'sent',
          ),
          createdAt: data['createdAt'] == null
              ? null
              : DateTime.parse(data['createdAt']! as String),
        ),
        'chat.receipt' ||
        'chat.read' ||
        'chat.delivered' => ChatDeliveryUpdated(
          roomId: data['roomId']! as String,
          messageId: data['messageId']! as String,
          status: MessageDeliveryStatus.values.byName(
            data['status'] as String? ??
                (event == 'chat.read' ? 'read' : 'delivered'),
          ),
        ),
        'chat.edit' => ChatMessageEdited(
          roomId: data['roomId']! as String,
          messageId: data['messageId']! as String,
          parts: data['parts'] is List
              ? [
                  for (final p in data['parts']! as List)
                    if (p is Map)
                      ChatPart.fromJson(Map<String, Object?>.from(p)),
                ]
              : [ChatTextPart(data['text'] as String? ?? '')],
          editedAt: data['editedAt'] == null
              ? DateTime.now().toUtc()
              : DateTime.parse(data['editedAt']! as String),
        ),
        'chat.delete' => ChatMessageDeleted(
          roomId: data['roomId']! as String,
          messageId: data['messageId']! as String,
        ),
        'chat.reaction' => ChatReactionToggled(
          roomId: data['roomId']! as String,
          messageId: data['messageId']! as String,
          emoji: data['emoji']! as String,
          userId: data['userId']! as String,
          added: data['added'] as bool? ?? true,
        ),
        'chat.typing' => ChatTypingEvent(
          TypingIndicator(
            roomId: data['roomId']! as String,
            userId: data['userId']! as String,
            userName: data['userName'] as String?,
            isTyping: data['isTyping'] as bool? ?? true,
            updatedAt: DateTime.now().toUtc(),
          ),
        ),
        'chat.presence' => ChatPresenceEvent(
          PresenceStatus(
            userId: data['userId']! as String,
            isOnline: data['isOnline'] as bool? ?? false,
            lastSeen: data['lastSeen'] == null
                ? null
                : DateTime.parse(data['lastSeen']! as String),
          ),
        ),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}
