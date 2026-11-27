import 'dart:async';

import 'package:meta/meta.dart';

import '../ai/ai_models.dart';
import '../ai/omni_ai.dart';
import '../core/cancel_token.dart';
import '../core/omni_network_exception.dart';
import 'chat_models.dart';
import 'chat_store.dart';

/// Context-window trimming & automatic summarization rule for [OmniAiThread].
@immutable
final class SlidingWindowContext {
  /// Creates a sliding-window context policy.
  const SlidingWindowContext({
    this.maxMessages = 24,
    this.summarizeOlderWithModel,
  }) : assert(maxMessages >= 2);

  /// Maximum recent turns kept verbatim before older turns are trimmed or
  /// summarized.
  final int maxMessages;

  /// Optional model alias/id used to compress overflow turns into a concise
  /// running summary instead of dropping them silently.
  final String? summarizeOlderWithModel;
}

/// Immutable snapshot of an [OmniAiThread] exposed to UI widgets and streams.
@immutable
final class AiThreadState {
  /// Creates a thread state snapshot.
  const AiThreadState({
    required this.threadId,
    required this.model,
    this.messages = const [],
    this.isStreaming = false,
    this.streamingText = '',
    this.streamingThinking = '',
    this.activeToolName,
    this.lastError,
    this.lastUsage,
  });

  /// Unique conversation thread id.
  final String threadId;

  /// Active model alias or `'provider:model'`.
  final String model;

  /// Chronological message history (user + assistant turns).
  final List<ChatMessage> messages;

  /// Whether a response is currently generating/streaming.
  final bool isStreaming;

  /// Partial assistant response text accumulated during current turn.
  final String streamingText;

  /// Partial reasoning trace accumulated during current turn.
  final String streamingThinking;

  /// Name of the [AiTool] currently executing, if any.
  final String? activeToolName;

  /// Error from the latest turn, if any.
  final Object? lastError;

  /// Usage statistics from the latest completed response.
  final AiUsage? lastUsage;
}

/// Stateful multi-turn AI conversation thread supporting streaming tokens,
/// reasoning traces, automatic tool calling, cancellation (`stopGenerating`),
/// context window management, model switching, and [ChatStore] persistence.
final class OmniAiThread {
  /// Creates a conversation thread backed by [ai].
  OmniAiThread({
    required this.id,
    required this.ai,
    String? model,
    this.systemPrompt,
    this.tools = const [],
    this.options = const AiRequestOptions(),
    this.contextPolicy = const SlidingWindowContext(),
    this.maxToolRounds = 5,
    ChatStore? store,
  }) : _model = model ?? ai.defaultModel ?? '',
       _store = store ?? MemoryChatStore(),
       _state = AiThreadState(
         threadId: id,
         model: model ?? ai.defaultModel ?? '',
       );

  /// Thread identifier used as persistence key.
  final String id;

  /// AI router / engine used for completions & streams.
  final OmniAi ai;

  /// Optional system instructions prepended to every LLM call.
  final String? systemPrompt;

  /// Tools available specifically inside this thread.
  final List<AiTool> tools;

  /// Default generation options for this thread.
  final AiRequestOptions options;

  /// Context truncation / summarization policy.
  final SlidingWindowContext contextPolicy;

  /// Max consecutive tool execution rounds per user turn.
  final int maxToolRounds;

  final ChatStore _store;
  final List<ChatMessage> _uiMessages = [];
  final List<AiMessage> _llmHistory = [];
  final StreamController<AiThreadState> _controller =
      StreamController<AiThreadState>.broadcast();

  String _model;
  String? _summary;
  AiThreadState _state;
  OmniCancelToken? _activeCancel;
  bool _restored = false;
  bool _closed = false;
  int _seq = 0;

  /// Active model alias or `'provider:model'`.
  String get model => _model;

  /// Latest thread state snapshot.
  AiThreadState get state => _state;

  /// Broadcast stream of [AiThreadState] updates (token deltas, tool
  /// execution, completion, errors).
  Stream<AiThreadState> get stream => _controller.stream;

  /// Loads saved history from [ChatStore] if present.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final ui = await _store.loadMessages('ai:$id');
    final llm = await _store.loadAiMessages(id);
    _uiMessages
      ..clear()
      ..addAll(ui);
    _llmHistory
      ..clear()
      ..addAll(llm);
    _emit(messages: List.unmodifiable(_uiMessages));
  }

  /// Switches the active model used on subsequent turns.
  void switchModel(String newModel) {
    _model = newModel;
    _emit(model: _model);
  }

  /// Cancels any currently running generation/stream cleanly.
  void stopGenerating() {
    _activeCancel?.cancel();
  }

  /// Sends a user [prompt] (with optional multimodal [extraParts]) and streams
  /// [AiThreadState] snapshots until completion.
  Stream<AiThreadState> send(
    String prompt, {
    List<AiPart> extraParts = const [],
    AiRequestOptions? optionsOverride,
  }) async* {
    if (_closed) {
      throw const ClosedFailure();
    }
    await restore();
    stopGenerating();

    final cancel = _activeCancel = OmniCancelToken();
    final userChat = ChatMessage.text(
      id: 'ai_u_${++_seq}_${DateTime.now().microsecondsSinceEpoch}',
      roomId: 'ai:$id',
      senderId: 'user',
      text: prompt,
      status: MessageDeliveryStatus.sent,
    );
    _uiMessages.add(userChat);

    final userLlmMsg = extraParts.isEmpty
        ? AiMessage.user(prompt)
        : AiMessage.userParts([AiPart.text(prompt), ...extraParts]);
    _llmHistory.add(userLlmMsg);

    await _trimAndSummarizeContextIfNeeded();
    await _persist();

    _emit(
      messages: List.unmodifiable(_uiMessages),
      isStreaming: true,
      streamingText: '',
      streamingThinking: '',
      activeToolName: null,
      lastError: null,
      clearError: true,
    );
    yield _state;

    final effectiveOpts = optionsOverride ?? options;
    final combinedTools = effectiveOpts.tools.isNotEmpty
        ? effectiveOpts.tools
        : tools;
    final callOpts = combinedTools.isNotEmpty
        ? effectiveOpts.copyWith(tools: combinedTools)
        : effectiveOpts;
    final toolMap = {for (final t in combinedTools) t.name: t};

    final totalText = StringBuffer();
    final totalThinking = StringBuffer();
    var totalUsage = AiUsage.zero;
    var concreteModel = _model;

    try {
      for (var round = 0; ; round++) {
        final roundText = StringBuffer();
        final roundThinking = StringBuffer();
        AiResponse? roundResponse;

        final payload = <AiMessage>[
          if (systemPrompt != null && systemPrompt!.isNotEmpty)
            AiMessage.system(systemPrompt!),
          if (_summary != null && _summary!.isNotEmpty)
            AiMessage.system('Earlier conversation summary:\n$_summary'),
          ..._llmHistory,
        ];

        await for (final ev in ai.streamChat(
          payload,
          model: _model,
          options: callOpts,
          autoExecuteTools: false,
          cancelToken: cancel,
        )) {
          switch (ev) {
            case AiThinkingDelta(:final text):
              roundThinking.write(text);
              totalThinking.write(text);
              _emit(streamingThinking: totalThinking.toString());
              yield _state;
            case AiTextDelta(:final text):
              roundText.write(text);
              totalText.write(text);
              _emit(streamingText: totalText.toString());
              yield _state;
            case AiToolCallDelta():
              break;
            case AiCompleted(:final response):
              roundResponse = response;
              totalUsage += response.usage;
              concreteModel = response.model;
            case AiStreamError(:final error):
              throw error;
          }
        }

        final res = roundResponse;
        if (cancel.isCancelled) {
          throw const CancelledFailure();
        }
        if (res == null) break;

        _llmHistory.add(
          AiMessage.assistant(
            res.text.isEmpty ? roundText.toString() : res.text,
            toolCalls: res.toolCalls,
          ),
        );

        if (!res.hasToolCalls || toolMap.isEmpty || round >= maxToolRounds) {
          break;
        }

        for (final call in res.toolCalls) {
          _emit(activeToolName: call.name);
          yield _state;
          final tool = toolMap[call.name];
          if (tool == null) {
            _llmHistory.add(
              AiMessage.toolResult(
                callId: call.id,
                name: call.name,
                result: 'Unknown tool "${call.name}"',
                isError: true,
              ),
            );
            continue;
          }
          try {
            final output = await tool.execute(call.arguments);
            _llmHistory.add(
              AiMessage.toolResult(
                callId: call.id,
                name: call.name,
                result: output,
              ),
            );
          } catch (e) {
            _llmHistory.add(
              AiMessage.toolResult(
                callId: call.id,
                name: call.name,
                result: '$e',
                isError: true,
              ),
            );
          }
        }
        _emit(activeToolName: null);
        yield _state;
      }

      final assistantMsg = ChatMessage.text(
        id: 'ai_a_${++_seq}_${DateTime.now().microsecondsSinceEpoch}',
        roomId: 'ai:$id',
        senderId: 'assistant',
        senderName: concreteModel,
        isAi: true,
        text: totalText.toString(),
        thinking: totalThinking.isEmpty ? null : totalThinking.toString(),
        model: concreteModel,
        usage: totalUsage,
      );
      _uiMessages.add(assistantMsg);
      await _persist();

      _emit(
        messages: List.unmodifiable(_uiMessages),
        isStreaming: false,
        streamingText: '',
        streamingThinking: '',
        activeToolName: null,
        lastUsage: totalUsage,
      );
      yield _state;
    } catch (e) {
      if (totalText.isNotEmpty) {
        _uiMessages.add(
          ChatMessage.text(
            id: 'ai_a_${++_seq}_${DateTime.now().microsecondsSinceEpoch}',
            roomId: 'ai:$id',
            senderId: 'assistant',
            senderName: concreteModel,
            isAi: true,
            text: totalText.toString(),
            status: cancel.isCancelled
                ? MessageDeliveryStatus.sent
                : MessageDeliveryStatus.failed,
          ),
        );
        await _persist();
      }
      _emit(
        messages: List.unmodifiable(_uiMessages),
        isStreaming: false,
        streamingText: '',
        streamingThinking: '',
        activeToolName: null,
        lastError: e,
      );
      yield _state;
    } finally {
      if (identical(_activeCancel, cancel)) {
        _activeCancel = null;
      }
    }
  }

  /// Convenience method that sends [prompt], awaits completion, and returns the
  /// final assistant [ChatMessage].
  Future<ChatMessage> sendAndWait(
    String prompt, {
    List<AiPart> extraParts = const [],
    AiRequestOptions? optionsOverride,
  }) async {
    AiThreadState? last;
    await for (final s in send(
      prompt,
      extraParts: extraParts,
      optionsOverride: optionsOverride,
    )) {
      last = s;
    }
    if (last?.lastError case final err?) {
      throw err;
    }
    return _uiMessages.last;
  }

  /// Removes the latest assistant response (if any) and regenerates an answer
  /// for the preceding user prompt.
  Future<ChatMessage?> regenerateLast() async {
    await restore();
    if (_uiMessages.isEmpty) return null;
    if (_uiMessages.last.isAi) {
      _uiMessages.removeLast();
    }
    if (_llmHistory.isNotEmpty && _llmHistory.last.role == AiRole.assistant) {
      _llmHistory.removeLast();
    }
    final lastUserIdx = _uiMessages.lastIndexWhere((m) => !m.isAi);
    if (lastUserIdx < 0) return null;
    final lastPrompt = _uiMessages[lastUserIdx].text;
    _uiMessages.removeAt(lastUserIdx);
    if (_llmHistory.isNotEmpty && _llmHistory.last.role == AiRole.user) {
      _llmHistory.removeLast();
    }
    return sendAndWait(lastPrompt);
  }

  /// Clears conversation history both in memory and in [ChatStore].
  Future<void> clear() async {
    stopGenerating();
    _uiMessages.clear();
    _llmHistory.clear();
    _summary = null;
    await _store.clearRoom('ai:$id');
    await _store.clearAiThread(id);
    _emit(
      messages: const [],
      isStreaming: false,
      streamingText: '',
      streamingThinking: '',
      activeToolName: null,
      clearError: true,
    );
  }

  Future<void> _trimAndSummarizeContextIfNeeded() async {
    final limit = contextPolicy.maxMessages;
    if (_llmHistory.length <= limit) return;
    final cut = _llmHistory.length - limit;
    final older = _llmHistory.sublist(0, cut);
    _llmHistory.removeRange(0, cut);

    final summaryModel = contextPolicy.summarizeOlderWithModel;
    if (summaryModel != null && older.isNotEmpty) {
      try {
        final transcript = [
          for (final m in older) '${m.role.name}: ${m.text}',
        ].join('\n');
        _summary = await ai.ask(
          'Summarize the following earlier conversation turns concisely, '
          'preserving key facts, names, and user goals:\n\n$transcript',
          model: summaryModel,
        );
      } catch (_) {
        // Keep sliding window safely even if optional summarization fails.
      }
    }
  }

  Future<void> _persist() async {
    await _store.saveMessages('ai:$id', _uiMessages);
    await _store.saveAiMessages(id, _llmHistory);
  }

  void _emit({
    String? model,
    List<ChatMessage>? messages,
    bool? isStreaming,
    String? streamingText,
    String? streamingThinking,
    Object? activeToolName = _sentinel,
    Object? lastError = _sentinel,
    bool clearError = false,
    AiUsage? lastUsage,
  }) {
    _state = AiThreadState(
      threadId: id,
      model: model ?? _state.model,
      messages: messages ?? _state.messages,
      isStreaming: isStreaming ?? _state.isStreaming,
      streamingText: streamingText ?? _state.streamingText,
      streamingThinking: streamingThinking ?? _state.streamingThinking,
      activeToolName: identical(activeToolName, _sentinel)
          ? _state.activeToolName
          : activeToolName as String?,
      lastError: clearError
          ? null
          : identical(lastError, _sentinel)
          ? _state.lastError
          : lastError,
      lastUsage: lastUsage ?? _state.lastUsage,
    );
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  /// Releases timers, cancels any running generation, and closes streams.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    stopGenerating();
    if (!_controller.isClosed) await _controller.close();
  }
}

const Object _sentinel = Object();
