import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omni_network/omni_network.dart';

import 'model_picker.dart';

/// Full-featured streaming AI assistant chat view backed by [OmniAiThread].
///
/// Renders user & AI messages, expandable reasoning traces (`thinking`),
/// active tool execution indicators, token/USD usage badges, live streaming
/// deltas, model switching via [OmniModelPicker], stop-generation, and
/// regenerate controls.
class OmniAiChatView extends StatefulWidget {
  /// Creates an AI chat view bound to [thread].
  const OmniAiChatView({
    super.key,
    required this.thread,
    this.hintText = 'Ask AI anything…',
    this.showModelPicker = true,
    this.showThinking = true,
    this.showUsage = true,
    this.showRegenerate = true,
    this.emptyBuilder,
    this.headerTrailing,
    this.messageBuilder,
    this.onError,
  });

  /// Conversation thread controller managing AI turns & persistence.
  final OmniAiThread thread;

  /// Composer placeholder text.
  final String hintText;

  /// Shows the top model selector bar via [OmniModelPicker].
  final bool showModelPicker;

  /// Displays model thinking/reasoning traces when present.
  final bool showThinking;

  /// Displays per-turn token and USD cost badges when available.
  final bool showUsage;

  /// Displays a regenerate-last-answer action when idle with history.
  final bool showRegenerate;

  /// Custom empty-state widget rendered before the first message.
  final WidgetBuilder? emptyBuilder;

  /// Optional extra widget placed on the right of the header bar.
  final Widget? headerTrailing;

  /// Optional custom renderer overriding default message bubbles.
  final Widget Function(BuildContext context, ChatMessage message)?
  messageBuilder;

  /// Optional callback invoked if sending or regenerating throws.
  final void Function(Object error)? onError;

  @override
  State<OmniAiChatView> createState() => _OmniAiChatViewState();
}

class _OmniAiChatViewState extends State<OmniAiChatView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  StreamSubscription<AiThreadState>? _sendSub;

  @override
  void initState() {
    super.initState();
    unawaited(widget.thread.restore());
  }

  @override
  void didUpdateWidget(covariant OmniAiChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread != widget.thread) {
      unawaited(_sendSub?.cancel());
      _sendSub = null;
      unawaited(widget.thread.restore());
    }
  }

  @override
  void dispose() {
    unawaited(_sendSub?.cancel());
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

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    unawaited(_sendSub?.cancel());
    _sendSub = widget.thread
        .send(text)
        .listen(
          (_) => _scrollToBottom(),
          onError: (Object error) => widget.onError?.call(error),
          onDone: () => _sendSub = null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<AiThreadState>(
      initialData: widget.thread.state,
      stream: widget.thread.stream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.thread.state;
        final itemCount = state.messages.length + (state.isStreaming ? 1 : 0);

        return Column(
          children: [
            _buildHeader(context, state, scheme),
            Expanded(
              child: itemCount == 0
                  ? widget.emptyBuilder?.call(context) ??
                        Center(
                          child: Text(
                            'Start a conversation with AI',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index < state.messages.length) {
                          final msg = state.messages[index];
                          if (widget.messageBuilder != null) {
                            return widget.messageBuilder!(context, msg);
                          }
                          return _AiMessageBubble(
                            message: msg,
                            showThinking: widget.showThinking,
                            showUsage: widget.showUsage,
                          );
                        }
                        return _StreamingAiBubble(
                          model: state.model,
                          thinking: state.streamingThinking,
                          text: state.streamingText,
                          activeToolName: state.activeToolName,
                          showThinking: widget.showThinking,
                        );
                      },
                    ),
            ),
            if (state.lastError != null)
              Container(
                width: double.infinity,
                color: scheme.errorContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '${state.lastError}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            _buildComposer(context, state, scheme),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AiThreadState state,
    ColorScheme scheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (widget.showModelPicker)
            Flexible(
              child: OmniModelPicker(
                ai: widget.thread.ai,
                selectedModel: state.model,
                onSelected: widget.thread.switchModel,
                compact: true,
              ),
            )
          else
            Expanded(
              child: Text(
                state.model,
                style: Theme.of(context).textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (state.activeToolName != null) ...[
            const SizedBox(width: 8),
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('Tool: ${state.activeToolName}'),
            ),
          ],
          const Spacer(),
          if (widget.showRegenerate &&
              !state.isStreaming &&
              state.messages.isNotEmpty)
            IconButton(
              tooltip: 'Regenerate last answer',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () {
                unawaited(
                  widget.thread
                      .regenerateLast()
                      .then((_) {})
                      .catchError((Object e) {
                        widget.onError?.call(e);
                      }),
                );
              },
            ),
          IconButton(
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: state.messages.isEmpty ? null : widget.thread.clear,
          ),
          ?widget.headerTrailing,
        ],
      ),
    );
  }

  Widget _buildComposer(
    BuildContext context,
    AiThreadState state,
    ColorScheme scheme,
  ) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (state.isStreaming)
              IconButton.filledTonal(
                tooltip: 'Stop generating',
                onPressed: widget.thread.stopGenerating,
                icon: const Icon(Icons.stop),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty;
                  return IconButton.filled(
                    tooltip: 'Send prompt',
                    onPressed: canSend ? _submit : null,
                    icon: const Icon(Icons.send),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AiMessageBubble extends StatelessWidget {
  const _AiMessageBubble({
    required this.message,
    required this.showThinking,
    required this.showUsage,
  });

  final ChatMessage message;
  final bool showThinking;
  final bool showUsage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAi = message.isAi;
    final bg = isAi ? scheme.surfaceContainerHigh : scheme.primaryContainer;
    final fg = isAi ? scheme.onSurface : scheme.onPrimaryContainer;

    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showThinking &&
                message.thinking != null &&
                message.thinking!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  dense: true,
                  title: Text(
                    'Reasoning',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  children: [
                    SelectableText(
                      message.thinking!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            SelectableText(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg),
            ),
            if (isAi && (message.model != null || (showUsage && message.usage != null)))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (message.model != null)
                      Text(
                        message.model!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (showUsage &&
                        message.usage != null &&
                        message.usage!.totalTokens > 0)
                      Text(
                        '${message.usage!.totalTokens} tok'
                        '${message.usage!.estimatedCostUsd > 0 ? ' · \$${message.usage!.estimatedCostUsd.toStringAsFixed(4)}' : ''}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreamingAiBubble extends StatelessWidget {
  const _StreamingAiBubble({
    required this.model,
    required this.thinking,
    required this.text,
    required this.activeToolName,
    required this.showThinking,
  });

  final String model;
  final String thinking;
  final String text;
  final String? activeToolName;
  final bool showThinking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  activeToolName != null
                      ? '$model · running $activeToolName…'
                      : '$model · generating…',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (showThinking && thinking.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                thinking,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (text.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(text),
            ],
          ],
        ),
      ),
    );
  }
}
