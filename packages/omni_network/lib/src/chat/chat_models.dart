import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import '../ai/ai_models.dart';

/// Optional encryption transformer applied by `OmniChatClient` to chat text
/// payloads before sending over WebSocket (E2EE) and/or persisting to disk.
abstract interface class ChatCipher {
  /// Encrypts [plaintext] into an encrypted string representation.
  FutureOr<String> encrypt(String plaintext);

  /// Decrypts [ciphertext] back to plain UTF-8 text.
  FutureOr<String> decrypt(String ciphertext);
}

/// Role of a participant in a chat room or AI thread.
enum ChatParticipantKind {
  /// Human user (local or remote).
  user,

  /// AI assistant participant.
  assistant,

  /// System event / announcement.
  system,
}

/// Participant metadata inside a chat room.
@immutable
final class ChatParticipant {
  /// Creates a participant descriptor.
  const ChatParticipant({
    required this.id,
    this.name,
    this.avatarUrl,
    this.kind = ChatParticipantKind.user,
    this.isOnline = false,
    this.lastSeen,
  });

  /// Unique user or bot id.
  final String id;

  /// Display name.
  final String? name;

  /// Optional avatar image URL.
  final String? avatarUrl;

  /// Participant kind.
  final ChatParticipantKind kind;

  /// Latest online status.
  final bool isOnline;

  /// Last seen timestamp when offline.
  final DateTime? lastSeen;

  /// Serializes to JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': ?name,
    'avatarUrl': ?avatarUrl,
    'kind': kind.name,
    'isOnline': isOnline,
    if (lastSeen != null) 'lastSeen': lastSeen!.toUtc().toIso8601String(),
  };

  /// Restores from JSON.
  factory ChatParticipant.fromJson(Map<String, Object?> json) => ChatParticipant(
    id: json['id']! as String,
    name: json['name'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    kind: ChatParticipantKind.values.byName(
      json['kind'] as String? ?? 'user',
    ),
    isOnline: json['isOnline'] as bool? ?? false,
    lastSeen: json['lastSeen'] == null
        ? null
        : DateTime.parse(json['lastSeen']! as String),
  );
}

/// Lifecycle state of an outgoing [ChatMessage].
enum MessageDeliveryStatus {
  /// Queued or uploading/sending optimistically.
  sending,

  /// Accepted by server / relay.
  sent,

  /// Delivered to recipient device(s).
  delivered,

  /// Read by recipient(s).
  read,

  /// Failed permanently or awaiting manual retry.
  failed,
}

/// Typed content segment inside a [ChatMessage].
@immutable
sealed class ChatPart {
  const ChatPart();

  /// Plain text content.
  const factory ChatPart.text(String text) = ChatTextPart;

  /// Image, video, or audio media attachment.
  const factory ChatPart.media({
    required String url,
    required String mimeType,
    String? name,
    int? sizeBytes,
    String? thumbnailUrl,
  }) = ChatMediaPart;

  /// Document / arbitrary file attachment.
  const factory ChatPart.file({
    required String url,
    required String name,
    String? mimeType,
    int? sizeBytes,
  }) = ChatFilePart;

  /// Geographic location pin.
  const factory ChatPart.location({
    required double latitude,
    required double longitude,
    String? label,
  }) = ChatLocationPart;

  /// Custom structured app payload (cards, orders, polls…).
  const factory ChatPart.custom({
    required String type,
    required Map<String, Object?> data,
  }) = ChatCustomPart;

  /// Serializes to JSON.
  Map<String, Object?> toJson();

  /// Restores from JSON.
  static ChatPart fromJson(Map<String, Object?> json) =>
      switch (json['kind'] as String?) {
        'media' => ChatMediaPart(
          url: json['url']! as String,
          mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
          name: json['name'] as String?,
          sizeBytes: json['sizeBytes'] as int?,
          thumbnailUrl: json['thumbnailUrl'] as String?,
        ),
        'file' => ChatFilePart(
          url: json['url']! as String,
          name: json['name'] as String? ?? 'file',
          mimeType: json['mimeType'] as String?,
          sizeBytes: json['sizeBytes'] as int?,
        ),
        'location' => ChatLocationPart(
          latitude: (json['latitude']! as num).toDouble(),
          longitude: (json['longitude']! as num).toDouble(),
          label: json['label'] as String?,
        ),
        'custom' => ChatCustomPart(
          type: json['type']! as String,
          data: Map<String, Object?>.from(json['data'] as Map? ?? const {}),
        ),
        _ => ChatTextPart(json['text'] as String? ?? ''),
      };
}

/// Text message segment.
final class ChatTextPart extends ChatPart {
  /// Creates a text part.
  const ChatTextPart(this.text);

  /// UTF-8 message text.
  final String text;

  @override
  Map<String, Object?> toJson() => {'kind': 'text', 'text': text};
}

/// Media attachment segment (image/audio/video).
final class ChatMediaPart extends ChatPart {
  /// Creates a media part.
  const ChatMediaPart({
    required this.url,
    required this.mimeType,
    this.name,
    this.sizeBytes,
    this.thumbnailUrl,
  });

  /// Hosted media URL.
  final String url;

  /// MIME type.
  final String mimeType;

  /// Optional filename.
  final String? name;

  /// Byte length, if known.
  final int? sizeBytes;

  /// Optional preview thumbnail URL.
  final String? thumbnailUrl;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'media',
    'url': url,
    'mimeType': mimeType,
    'name': ?name,
    'sizeBytes': ?sizeBytes,
    'thumbnailUrl': ?thumbnailUrl,
  };
}

/// Generic file attachment segment.
final class ChatFilePart extends ChatPart {
  /// Creates a file attachment part.
  const ChatFilePart({
    required this.url,
    required this.name,
    this.mimeType,
    this.sizeBytes,
  });

  /// Download URL.
  final String url;

  /// Filename.
  final String name;

  /// Optional MIME type.
  final String? mimeType;

  /// File size in bytes.
  final int? sizeBytes;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'file',
    'url': url,
    'name': name,
    'mimeType': ?mimeType,
    'sizeBytes': ?sizeBytes,
  };
}

/// Location coordinates segment.
final class ChatLocationPart extends ChatPart {
  /// Creates a location part.
  const ChatLocationPart({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Optional place name.
  final String? label;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'location',
    'latitude': latitude,
    'longitude': longitude,
    'label': ?label,
  };
}

/// Arbitrary custom structured card/payload inside a message.
final class ChatCustomPart extends ChatPart {
  /// Creates a custom typed payload part.
  const ChatCustomPart({required this.type, required this.data});

  /// Custom payload type identifier.
  final String type;

  /// Arbitrary JSON map.
  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() => {'kind': 'custom', 'type': type, 'data': data};
}

/// Unified chat message model supporting realtime user rooms and AI threads.
@immutable
final class ChatMessage {
  /// Creates a chat message.
  const ChatMessage({
    required this.id,
    this.localId,
    required this.roomId,
    required this.senderId,
    this.senderName,
    this.isAi = false,
    required this.parts,
    required this.createdAt,
    this.replyToId,
    this.reactions = const {},
    this.status = MessageDeliveryStatus.sent,
    this.editedAt,
    this.isDeleted = false,
    this.thinking,
    this.model,
    this.usage,
    this.metadata = const {},
  });

  /// Convenience factory for a plain-text message.
  factory ChatMessage.text({
    required String id,
    String? localId,
    required String roomId,
    required String senderId,
    String? senderName,
    bool isAi = false,
    required String text,
    DateTime? createdAt,
    String? replyToId,
    MessageDeliveryStatus status = MessageDeliveryStatus.sent,
    String? thinking,
    String? model,
    AiUsage? usage,
  }) => ChatMessage(
    id: id,
    localId: localId,
    roomId: roomId,
    senderId: senderId,
    senderName: senderName,
    isAi: isAi,
    parts: [ChatTextPart(text)],
    createdAt: createdAt ?? DateTime.now().toUtc(),
    replyToId: replyToId,
    status: status,
    thinking: thinking,
    model: model,
    usage: usage,
  );

  /// Server-assigned or stable message id.
  final String id;

  /// Client-generated optimistic id for deduplication & status reconciliation.
  final String? localId;

  /// Room or AI thread id.
  final String roomId;

  /// Author id (or `'assistant'` for AI replies).
  final String senderId;

  /// Optional display name.
  final String? senderName;

  /// Whether this message was generated by an AI model.
  final bool isAi;

  /// Ordered content segments (text, media, files, location, custom cards).
  final List<ChatPart> parts;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Parent message id when replying.
  final String? replyToId;

  /// Reactions map (`emoji` -> list of reacting user ids).
  final Map<String, List<String>> reactions;

  /// Current delivery lifecycle state.
  final MessageDeliveryStatus status;

  /// Timestamp of last edit, if edited.
  final DateTime? editedAt;

  /// Soft-delete flag.
  final bool isDeleted;

  /// Optional AI reasoning trace.
  final String? thinking;

  /// Concrete AI model id when [isAi] is `true`.
  final String? model;

  /// Token/USD usage when generated by an AI model.
  final AiUsage? usage;

  /// Arbitrary extra metadata.
  final Map<String, Object?> metadata;

  /// Combined plain text of all [ChatTextPart] segments.
  String get text => parts.whereType<ChatTextPart>().map((p) => p.text).join();

  /// Returns a copy with updated fields.
  ChatMessage copyWith({
    String? id,
    String? localId,
    List<ChatPart>? parts,
    MessageDeliveryStatus? status,
    Map<String, List<String>>? reactions,
    DateTime? editedAt,
    bool? isDeleted,
    String? thinking,
    String? model,
    AiUsage? usage,
    Map<String, Object?>? metadata,
  }) => ChatMessage(
    id: id ?? this.id,
    localId: localId ?? this.localId,
    roomId: roomId,
    senderId: senderId,
    senderName: senderName,
    isAi: isAi,
    parts: parts ?? this.parts,
    createdAt: createdAt,
    replyToId: replyToId,
    reactions: reactions ?? this.reactions,
    status: status ?? this.status,
    editedAt: editedAt ?? this.editedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    thinking: thinking ?? this.thinking,
    model: model ?? this.model,
    usage: usage ?? this.usage,
    metadata: metadata ?? this.metadata,
  );

  /// Serializes to JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'localId': ?localId,
    'roomId': roomId,
    'senderId': senderId,
    'senderName': ?senderName,
    'isAi': isAi,
    'parts': [for (final p in parts) p.toJson()],
    'createdAt': createdAt.toUtc().toIso8601String(),
    'replyToId': ?replyToId,
    if (reactions.isNotEmpty) 'reactions': reactions,
    'status': status.name,
    if (editedAt != null) 'editedAt': editedAt!.toUtc().toIso8601String(),
    if (isDeleted) 'isDeleted': true,
    'thinking': ?thinking,
    'model': ?model,
    if (usage != null)
      'usage': {
        'inputTokens': usage!.inputTokens,
        'outputTokens': usage!.outputTokens,
        'reasoningTokens': usage!.reasoningTokens,
        'totalTokens': usage!.totalTokens,
        'estimatedCostUsd': usage!.estimatedCostUsd,
      },
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  /// Restores a message written by [toJson].
  factory ChatMessage.fromJson(Map<String, Object?> json) {
    final rawReactions = json['reactions'] as Map?;
    final parsedReactions = <String, List<String>>{
      if (rawReactions != null)
        for (final e in rawReactions.entries)
          e.key.toString(): [
            for (final u in e.value as List? ?? const []) '$u',
          ],
    };
    final rawUsage = json['usage'] as Map?;
    final parsedUsage = rawUsage == null
        ? null
        : AiUsage(
            inputTokens: rawUsage['inputTokens'] as int? ?? 0,
            outputTokens: rawUsage['outputTokens'] as int? ?? 0,
            reasoningTokens: rawUsage['reasoningTokens'] as int? ?? 0,
            totalTokens: rawUsage['totalTokens'] as int?,
            estimatedCostUsd:
                (rawUsage['estimatedCostUsd'] as num?)?.toDouble() ?? 0.0,
          );
    final rawParts = json['parts'] as List?;
    final parts = rawParts != null
        ? [
            for (final p in rawParts)
              if (p is Map) ChatPart.fromJson(Map<String, Object?>.from(p)),
          ]
        : <ChatPart>[
            if (json['text'] is String) ChatTextPart(json['text']! as String),
          ];
    return ChatMessage(
      id: json['id']! as String,
      localId: json['localId'] as String?,
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? 'unknown',
      senderName: json['senderName'] as String?,
      isAi: json['isAi'] as bool? ?? false,
      parts: parts,
      createdAt: json['createdAt'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(json['createdAt']! as String),
      replyToId: json['replyToId'] as String?,
      reactions: parsedReactions,
      status: MessageDeliveryStatus.values.byName(
        json['status'] as String? ?? 'sent',
      ),
      editedAt: json['editedAt'] == null
          ? null
          : DateTime.parse(json['editedAt']! as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      thinking: json['thinking'] as String?,
      model: json['model'] as String?,
      usage: parsedUsage,
      metadata: Map<String, Object?>.from(
        json['metadata'] as Map? ?? const {},
      ),
    );
  }

  /// Helper decoding a `List` of JSON messages safely.
  static List<ChatMessage> listFromJson(Object? decoded) {
    if (decoded is! List) return const [];
    return [
      for (final raw in decoded)
        if (raw is Map) ChatMessage.fromJson(Map<String, Object?>.from(raw)),
    ];
  }

  @override
  String toString() =>
      'ChatMessage($id, from: $senderId, status: ${status.name}, text: ${jsonEncode(text)})';
}

/// Active typing indicator status for a participant in a room.
@immutable
final class TypingIndicator {
  /// Creates a typing status.
  const TypingIndicator({
    required this.roomId,
    required this.userId,
    this.userName,
    required this.isTyping,
    required this.updatedAt,
  });

  /// Room id.
  final String roomId;

  /// Participant id.
  final String userId;

  /// Optional participant name.
  final String? userName;

  /// Whether currently typing.
  final bool isTyping;

  /// Timestamp used to auto-expire stale indicators.
  final DateTime updatedAt;
}

/// User presence state (`online`, `offline`, `lastSeen`).
@immutable
final class PresenceStatus {
  /// Creates a presence status.
  const PresenceStatus({
    required this.userId,
    required this.isOnline,
    this.lastSeen,
  });

  /// Participant id.
  final String userId;

  /// Whether currently online.
  final bool isOnline;

  /// Last seen timestamp when offline.
  final DateTime? lastSeen;
}
