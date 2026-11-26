/// OmniNetwork: simple, typed, safe-by-default HTTP networking.
///
/// This import has what apps need. For custom transports, stores,
/// strategies, logging sinks, cURL and other low-level APIs import
/// `package:omni_network/advanced.dart`; for tests import
/// `package:omni_network/testing.dart`.
///
/// Pure Dart: no Flutter, router or state-management dependency.
library;

// Client, requests and responses.
export 'src/core/omni_metrics.dart' show OmniNetworkMetrics, EndpointMetrics;
export 'src/core/omni_network.dart' show OmniNetwork;
export 'src/core/omni_request.dart' show OmniRequest, HttpMethod;
export 'src/core/omni_response.dart' show OmniResponse, OmniRawResponse;
export 'src/endpoint/endpoint.dart' show Endpoint;

// Errors.
export 'src/core/omni_network_exception.dart'
    show
        OmniNetworkException,
        HttpFailure,
        DecodeFailure,
        TimeoutFailure,
        TimeoutStage,
        ConnectionFailure,
        ConnectionReason,
        CancelledFailure,
        ClosedFailure,
        AuthFailure,
        CircuitOpenFailure,
        RequestFailure;
export 'src/core/result.dart' show Result, Ok, Err, OmniResultFuture;

// Features.
export 'src/auth/auth_providers.dart'
    show ApiKeyAuth, BasicAuth, HmacSignerAuth;
export 'src/auth/omni_auth.dart' show OmniAuth, AuthState;
export 'src/auth/tokens.dart' show Tokens;
export 'src/core/interceptor.dart' show OmniInterceptor;
export 'src/core/cancel_token.dart' show OmniCancelToken;
export 'src/realtime/sse.dart' show SseConnection, SseEvent, SseState;
export 'src/realtime/web_socket.dart' show OmniWebSocket, WebSocketState;
export 'src/realtime/ws_protocol.dart' show WsWebAuthMode;
export 'src/hub/api_environment.dart'
    show
        OmniEnvironment,
        ServiceConfig,
        ServiceHealth,
        RateLimit,
        GraphqlEndpoint,
        WsEndpoint,
        SseEndpoint,
        AiEndpoint;
export 'src/hub/api_hub.dart' show OmniApiHub;
export 'src/ai/ai_guardrail.dart' show AiGuardrail, AiGuardrailAction;
export 'src/ai/ai_models.dart'
    show
        AiRole,
        AiPart,
        AiTextPart,
        AiImageBytesPart,
        AiImageUrlPart,
        AiAudioBytesPart,
        AiDocumentPart,
        AiToolCallPart,
        AiToolResultPart,
        AiMessage,
        AiUsage,
        AiFinishReason,
        AiResponse,
        AiStreamEvent,
        AiThinkingDelta,
        AiTextDelta,
        AiToolCallDelta,
        AiCompleted,
        AiStreamError,
        AiTool,
        AiRequestOptions,
        AiTarget,
        AiRoutingStrategy,
        AiModelRoute,
        AiModelCost,
        AiStreamingObject,
        AiTranscriptionResult,
        AiSpeechResult,
        AiGeneratedImage,
        AiRealtimeEvent,
        AiRealtimeTextDelta,
        AiRealtimeAudioDelta,
        AiRealtimeJsonEvent;
export 'src/ai/ai_provider.dart' show AiRealtimeSession;
export 'src/ai/ai_semantic_cache.dart' show AiSemanticCache;
export 'src/ai/vector_store.dart' show TextSplitter;
export 'src/ai/ai_providers_builtin.dart'
    show
        OpenAiProvider,
        OpenAiCompatibleProvider,
        GeminiProvider,
        AnthropicProvider,
        OllamaProvider,
        CustomAiProvider;
export 'src/ai/omni_ai.dart' show OmniAi, AiConfig;
export 'src/chat/ai_thread.dart'
    show OmniAiThread, AiThreadState, SlidingWindowContext;
export 'src/chat/chat_models.dart'
    show
        ChatCipher,
        ChatParticipantKind,
        ChatParticipant,
        MessageDeliveryStatus,
        ChatPart,
        ChatTextPart,
        ChatMediaPart,
        ChatFilePart,
        ChatLocationPart,
        ChatCustomPart,
        ChatMessage,
        TypingIndicator,
        PresenceStatus;
export 'src/chat/chat_room.dart' show OmniChatRoom;
export 'src/chat/omni_chat_client.dart' show OmniChatClient, ChatConfig;
export 'src/resilience/retry_policy.dart' show RetryPolicy;
export 'src/cache/omni_cache.dart' show OmniCache, CachePolicy, ResponseSource;
export 'src/transfer/multipart.dart' show UploadFile;
export 'src/paging/omni_pager.dart' show OmniPager;
export 'src/paging/pagination_strategy.dart'
    show PagePagination, OffsetPagination, CursorPagination;
export 'src/state/request_controller.dart' show RequestController;
export 'src/state/request_state.dart'
    show
        RequestState,
        RequestIdle,
        RequestLoading,
        RequestSuccess,
        RequestEmpty,
        RequestError;
export 'src/log/pretty_log.dart' show LogOptions;
