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
export 'src/auth/omni_auth.dart' show OmniAuth, AuthState;
export 'src/auth/tokens.dart' show Tokens;
export 'src/core/interceptor.dart' show OmniInterceptor;
export 'src/core/cancel_token.dart' show OmniCancelToken;
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
