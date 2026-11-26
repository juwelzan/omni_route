import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omni_network/omni_network.dart';

/// Complete realtime chat room UI backed by [OmniChatRoom].
///
/// Supports optimistic message delivery, typing indicators, delivery/read status
/// icons, reply previews, emoji reaction toggling, failed-message retry, older
/// history pagination, optional attachment uploads, and `@ai` assistant replies.
class OmniChatView extends StatefulWidget {
  /// Creates a realtime chat view bound to [room].
  const OmniChatView({
    super.key,
    required this.room,
    this.hintText = 'Type a message…',
    this.onPickAttachment,
    this.quickReactions = const ['👍', '❤️', '😂'],
    this.showTypingIndicator = true,
    this.showDeliveryStatus = true,
    this.headerBuilder,
    this.emptyBuilder,
    this.messageBuilder,
    this.onError,
  });

  /// Live chat room controller managing WebSocket events, cache, and AI
  /// assistant replies.
  final OmniChatRoom room;

  /// Placeholder hint inside the composer input field.
  final String hintText;

  /// Optional file/media picker callback used by the attachment button.
  final Future<UploadFile?> Function()? onPickAttachment;

  /// Reaction emojis offered in each message's quick action menu.
  final List<String> quickReactions;

  /// Shows incoming typing indicators above the composer bar.
  final bool showTypingIndicator;

  /// Shows delivery/read checkmarks on outgoing messages.
  final bool showDeliveryStatus;

  /// Optional header widget placed above the message list.
  final WidgetBuilder? headerBuilder;

  /// Custom empty-state widget rendered when the room has no messages.
  final WidgetBuilder? emptyBuilder;

  /// Custom message bubble builder overriding the default bubble.
  final Widget Function(BuildContext context, ChatMessage message)?
  messageBuilder;

  /// Optional error callback triggered if attachment upload or send fails.
  final void Function(Object error)? onError;

  @override
  State<OmniChatView> createState() => _OmniChatViewState();
}

class _OmniChatViewState extends State<OmniChatView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ChatMessage? _replyTo;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.room.restore());
  }

  @override
  void didUpdateWidget(covariant OmniChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room) {
      _replyTo = null;
      unawaited(widget.room.restore());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final reply = _replyTo;
    _input.clear();
    if (_replyTo != null) {
      setState(() => _replyTo = null);
    }
    widget.room.setTyping(false);
    try {
      await widget.room.sendText(text, replyToId: reply?.id);
      _scrollToBottom();
    } catch (e) {
      widget.onError?.call(e);
    }
  }

  Future<void> _pickAndSendFile() async {
    final picker = widget.onPickAttachment;
    if (picker == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      final file = await picker();
      if (file == null) return;
      final caption = _input.text.trim();
      if (caption.isNotEmpty) _input.clear();
      await widget.room.sendFile(
        file,
        caption: caption.isEmpty ? null : caption,
        replyToId: _replyTo?.id,
      );
      if (_replyTo != null && mounted) {
        setState(() => _replyTo = null);
      }
      _scrollToBottom();
    } catch (e) {
      widget.onError?.call(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (widget.headerBuilder != null) widget.headerBuilder!(context),
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            initialData: widget.room.messages,
            stream: widget.room.messagesStream,
            builder: (context, snapshot) {
              final messages = snapshot.data ?? widget.room.messages;
              if (messages.isEmpty && !widget.room.isLoadingHistory) {
                return widget.emptyBuilder?.call(context) ??
                    Center(
                      child: Text(
                        'No messages yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
              }
              final hasHeaderLoader = widget.room.historyEndpoint != null;
              final extraTop = hasHeaderLoader ? 1 : 0;
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length + extraTop,
                itemBuilder: (context, index) {
                  if (hasHeaderLoader && index == 0) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: widget.room.isLoadingHistory
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                onPressed: () =>
                                    unawaited(widget.room.loadOlderMessages()),
                                child: const Text('Load older messages'),
                              ),
                      ),
                    );
                  }
                  final msg = messages[index - extraTop];
                  if (widget.messageBuilder != null) {
                    return widget.messageBuilder!(context, msg);
                  }
                  final isMine =
                      msg.senderId == widget.room.chatClient.currentUserId;
                  return _ChatMessageTile(
                    message: msg,
                    isMine: isMine,
                    quickReactions: widget.quickReactions,
                    showDeliveryStatus: widget.showDeliveryStatus,
                    onRetry: msg.status == MessageDeliveryStatus.failed
                        ? () => unawaited(
                            widget.room.retryFailed(msg.localId ?? msg.id),
                          )
                        : null,
                    onReply: () => setState(() => _replyTo = msg),
                    onReact: (emoji) =>
                        unawaited(widget.room.toggleReaction(msg.id, emoji)),
                  );
                },
              );
            },
          ),
        ),
        if (widget.showTypingIndicator)
          StreamBuilder<Map<String, TypingIndicator>>(
            initialData: widget.room.typingUsers,
            stream: widget.room.typingStream,
            builder: (context, snapshot) {
              final active = snapshot.data ?? widget.room.typingUsers;
              if (active.isEmpty) return const SizedBox.shrink();
              final names = active.values
                  .map((t) => t.userName ?? t.userId)
                  .toList(growable: false);
              final label = names.length == 1
                  ? '${names.first} is typing…'
                  : '${names.length} people typing…';
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            },
          ),
        if (_replyTo != null)
          Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.reply, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Replying to ${_replyTo!.senderName ?? _replyTo!.senderId}: ${_replyTo!.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel reply',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _replyTo = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                if (widget.onPickAttachment != null)
                  IconButton(
                    tooltip: 'Attach file',
                    onPressed: _uploading ? null : _pickAndSendFile,
                    icon: _uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file),
                  ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onChanged: (v) =>
                        widget.room.setTyping(v.trim().isNotEmpty),
                    onSubmitted: (_) => unawaited(_sendText()),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _input,
                  builder: (context, value, _) {
                    final canSend = value.text.trim().isNotEmpty;
                    return IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: canSend ? () => unawaited(_sendText()) : null,
                      icon: const Icon(Icons.send),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    required this.message,
    required this.isMine,
    required this.quickReactions,
    required this.showDeliveryStatus,
    required this.onReply,
    required this.onReact,
    this.onRetry,
  });

  final ChatMessage message;
  final bool isMine;
  final List<String> quickReactions;
  final bool showDeliveryStatus;
  final VoidCallback? onRetry;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.isAi
        ? scheme.tertiaryContainer
        : isMine
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final fg = message.isAi
        ? scheme.onTertiaryContainer
        : isMine
        ? scheme.onPrimaryContainer
        : scheme.onSurface;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isAi) ...[
                        Icon(Icons.auto_awesome, size: 13, color: fg),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          message.senderName ?? message.senderId,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: fg,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        tooltip: 'Message actions',
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        onSelected: (value) {
                          if (value == '__reply') {
                            onReply();
                          } else {
                            onReact(value);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: '__reply',
                            child: Text('Reply'),
                          ),
                          for (final emoji in quickReactions)
                            PopupMenuItem(
                              value: emoji,
                              child: Text('React $emoji'),
                            ),
                        ],
                        child: Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  if (message.replyToId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Text(
                        '↩ Reply to ${message.replyToId}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: fg.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (message.isDeleted)
                    Text(
                      'Message deleted',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fg.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    for (final part in message.parts)
                      _partWidget(context, part, fg),
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final entry in message.reactions.entries)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${entry.key} ${entry.value.length}'),
                            onPressed: () => onReact(entry.key),
                          ),
                      ],
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.editedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              'edited',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: fg.withValues(alpha: 0.7)),
                            ),
                          ),
                        if (message.model != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              message.model!,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: fg.withValues(alpha: 0.75)),
                            ),
                          ),
                        if (isMine && showDeliveryStatus)
                          _statusIcon(context, scheme, fg),
                        if (onRetry != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: onRetry,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _partWidget(BuildContext context, ChatPart part, Color fg) =>
      switch (part) {
        ChatTextPart(:final text) => SelectableText(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
        ),
        ChatMediaPart(:final mimeType, :final name, :final url) => Text(
          '[Media $mimeType: ${name ?? url}]',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
        ),
        ChatFilePart(:final name, :final url) => Text(
          '[File: $name ($url)]',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
        ),
        ChatLocationPart(:final latitude, :final longitude, :final label) =>
          Text(
            '[Location: ${label ?? '$latitude, $longitude'}]',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
          ),
        ChatCustomPart(:final type) => Text(
          '[$type]',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
        ),
      };

  Widget _statusIcon(BuildContext context, ColorScheme scheme, Color fg) {
    final (icon, color) = switch (message.status) {
      MessageDeliveryStatus.sending => (
        Icons.access_time,
        fg.withValues(alpha: 0.7),
      ),
      MessageDeliveryStatus.sent => (Icons.check, fg.withValues(alpha: 0.8)),
      MessageDeliveryStatus.delivered => (
        Icons.done_all,
        fg.withValues(alpha: 0.8),
      ),
      MessageDeliveryStatus.read => (Icons.done_all, scheme.primary),
      MessageDeliveryStatus.failed => (Icons.error_outline, scheme.error),
    };
    return Icon(icon, size: 14, color: color);
  }
}
