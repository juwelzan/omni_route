import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show Dio;
import 'package:meta/meta.dart';

import '../auth/bearer_auth.dart';
import '../auth/omni_auth.dart';
import '../cache/omni_cache.dart';
import '../curl/curl.dart';
import '../endpoint/endpoint.dart';
import '../log/network_log.dart';
import '../log/network_logger.dart';
import '../log/pretty_log.dart';
import '../log/redactor.dart';
import '../paging/omni_pager.dart';
import '../paging/pagination_strategy.dart';
import '../resilience/circuit_breaker.dart';
import '../state/request_controller.dart';
import '../resilience/retry_policy.dart';
import '../transfer/download_target.dart';
import '../transfer/stream_target.dart';
import '../transfer/file_target_stub.dart'
    if (dart.library.io) '../transfer/file_target_io.dart';
import '../transfer/multipart.dart';
import '../transport/dio_transport.dart';
import '../transport/transport.dart';
import 'cancel_signal.dart';
import 'cancel_token.dart';
import 'decoding.dart';
import 'interceptor.dart';
import 'omni_network_exception.dart';
import 'omni_request.dart';
import 'omni_response.dart';
import 'response_adapter.dart';

part 'omni_network_advanced.dart';

/// An HTTP client. Independent of Flutter, routing and state management.
///
/// ```dart
/// final api = OmniNetwork(baseUrl: 'https://api.example.com/v1');
/// final user = await api.get<User>('/users/10', decoder: User.fromJson);
/// await api.close();
/// ```
final class OmniNetwork {
  /// Creates a client.
  ///
  /// * [baseUrl]: joined with relative request paths (`/users` and `users`
  ///   both resolve under it, including its path, e.g. `/v1/users`).
  /// * [headers]: default headers, overridden per request.
  /// * [timeout]: overall deadline per request (connect + send + receive).
  /// * [connectTimeout], [sendTimeout], [receiveTimeout]: stage-specific
  ///   transport timeouts enforced per phase on `DioTransport`.
  /// * [proxy]: HTTP proxy (`'192.168.0.105:8888'` or `'PROXY host:port'`),
  ///   ignored in release builds unless [allowProxyInRelease] is `true`.
  /// * [pinnedSha256]: SHA-256 certificate/SPKI pins (`'sha256/<base64>'`,
  ///   raw base64, or hex) enforced on every TLS handshake.
  /// * [enableHttp2]: enables HTTP/2 multiplexing with TLS ALPN fallback to
  ///   HTTP/1.1 on IO platforms.
  /// * [maxConnectionsPerHost], [idleConnectionTimeout]: connection pool
  ///   tuning on IO platforms.
  /// * [decoders]: global model decoder registry (`{User: User.fromJson}`) so
  ///   typed calls (`get<User>`, `getList<User>`, etc.) can omit `decoder:`.
  /// * [transport]: defaults to a [DioTransport] owned by this client. A
  ///   transport you pass in is **not** closed by [close]; you own it.
  /// * [responseAdapter]: applied to every JSON body before decoding,
  ///   e.g. [EnvelopeResponseAdapter]; overridable per call.
  /// * [enableLogging]: the master terminal/logger switch (`true`/`false`,
  ///   default `false`; also mutable at runtime via `api.enableLogging`).
  ///   When on, each call prints the full response cleanly via `logger` with
  ///   ANSI colours — see [PrettyLogSink], [logResponse], [logColors], and
  ///   [logOptions].
  /// * [logResponse]: controls whether full response bodies are printed in
  ///   terminal/logs (defaults to [logOptions.responseBody] and [logBodies];
  ///   mutable at runtime via `api.logResponse`). Set to `false` to hide
  ///   response bodies while keeping request/status lines.
  /// * [logColors]: shortcut to force ANSI terminal colours `true`/`false`
  ///   (`null` auto-detects from terminal/IDE). Also mutable at runtime via
  ///   `api.logColors`.
  /// * [maxConcurrentRequests]: optional limit on parallel in-flight transport
  ///   calls; queued callers still respect `timeout` and `cancelToken`.
  /// * [interceptors]: see [OmniInterceptor].
  /// * [auth]: token management, usually an [OmniAuth] (login/logout,
  ///   refresh on 401 or before expiry, storage). Without [auth] and
  ///   [token] the client still has a plain [OmniAuth], so
  ///   `api.auth.login(...)` works out of the box (no refresh).
  /// * [token]: shortcut for an existing token: returns the current access
  ///   token (or `null`). No refresh; a 401 is an `HttpFailure`.
  ///   Pass either [token] or [auth].
  /// * [retry]: default [RetryPolicy] (none when `null`); overridable per
  ///   request via `OmniRequest(retry:)`.
  /// * [circuitBreaker]: fail fast for hosts that keep failing.
  /// * [cache]: response cache for GET requests, see [OmniCache].
  /// * [deduplicate]: identical concurrent GETs (same URL and headers) share
  ///   one network call; each caller keeps its own timeout and cancel.
  factory OmniNetwork({
    String? baseUrl,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    String? proxy,
    bool allowProxyInRelease = false,
    bool allowBadProxyCertificate = true,
    List<String> pinnedSha256 = const [],
    bool enableHttp2 = false,
    int? maxConnectionsPerHost,
    Duration? idleConnectionTimeout,
    int? maxConcurrentRequests,
    Map<Type, JsonDecoder<Object?>> decoders = const {},
    Transport? transport,
    ResponseAdapter responseAdapter = const PlainResponseAdapter(),
    bool enableLogging = false,
    bool? logResponse,
    bool? logColors,
    LogSink? logSink,
    LogOptions logOptions = const LogOptions(),
    bool logInRelease = false,
    Redactor redactor = const Redactor(),
    bool logBodies = true,
    List<OmniInterceptor> interceptors = const [],
    AuthProvider? auth,
    FutureOr<String?> Function()? token,
    RetryPolicy? retry,
    CircuitBreaker? circuitBreaker,
    OmniCache? cache,
    bool deduplicate = true,
    bool followRedirects = true,
    int maxRedirects = 5,
  }) {
    if (transport != null &&
        (proxy != null ||
            pinnedSha256.isNotEmpty ||
            enableHttp2 ||
            maxConnectionsPerHost != null ||
            idleConnectionTimeout != null)) {
      throw ArgumentError(
        'Cannot combine a custom transport: with proxy:, pinnedSha256:, '
        'enableHttp2:, maxConnectionsPerHost:, or idleConnectionTimeout:. '
        'Configure those on DioTransport.configured(...) directly.',
      );
    }

    final effectiveProxy =
        proxy != null && (allowProxyInRelease || !isReleaseBuild)
        ? proxy
        : null;

    final usesConfiguredDio =
        effectiveProxy != null ||
        pinnedSha256.isNotEmpty ||
        enableHttp2 ||
        connectTimeout != null ||
        sendTimeout != null ||
        receiveTimeout != null ||
        maxConnectionsPerHost != null ||
        idleConnectionTimeout != null;

    final resolvedTransport =
        transport ??
        (usesConfiguredDio
            ? DioTransport.configured(
                proxy: effectiveProxy,
                pinnedSha256: pinnedSha256,
                allowBadProxyCertificate: allowBadProxyCertificate,
                connectTimeout: connectTimeout,
                sendTimeout: sendTimeout,
                receiveTimeout: receiveTimeout,
                maxConnectionsPerHost: maxConnectionsPerHost,
                idleConnectionTimeout: idleConnectionTimeout,
                enableHttp2: enableHttp2,
              )
            : DioTransport());

    return OmniNetwork._(
      baseUrl: baseUrl,
      headers: headers,
      timeout: timeout,
      connectTimeout: connectTimeout,
      sendTimeout: sendTimeout,
      receiveTimeout: receiveTimeout,
      maxConcurrentRequests: maxConcurrentRequests,
      decoders: decoders,
      transport: resolvedTransport,
      ownsTransport: transport == null,
      responseAdapter: responseAdapter,
      enableLogging: enableLogging,
      logResponse: logResponse,
      logColors: logColors,
      logSink: logSink,
      logOptions: logOptions,
      logInRelease: logInRelease,
      redactor: redactor,
      logBodies: logBodies,
      interceptors: interceptors,
      auth: auth,
      token: token,
      retry: retry,
      circuitBreaker: circuitBreaker,
      cache: cache,
      deduplicate: deduplicate,
      followRedirects: followRedirects,
      maxRedirects: maxRedirects,
    );
  }

  /// Creates an [OmniNetwork] client backed by an existing [Dio] instance.
  ///
  /// Preserves [dio]'s existing base URL, headers, timeouts, interceptors, and
  /// `httpClientAdapter`, while layering OmniNetwork's caching, token refresh,
  /// retries, circuit breaking, and structured logging on top.
  ///
  /// By default [close] does **not** close the supplied [dio] instance so
  /// incremental migration can share [dio] safely; pass `closeDio: true` to
  /// transfer ownership.
  factory OmniNetwork.fromDio(
    Dio dio, {
    String? baseUrl,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    int? maxConcurrentRequests,
    Map<Type, JsonDecoder<Object?>> decoders = const {},
    ResponseAdapter responseAdapter = const PlainResponseAdapter(),
    bool enableLogging = false,
    bool? logResponse,
    bool? logColors,
    LogSink? logSink,
    LogOptions logOptions = const LogOptions(),
    bool logInRelease = false,
    Redactor redactor = const Redactor(),
    bool logBodies = true,
    List<OmniInterceptor> interceptors = const [],
    AuthProvider? auth,
    FutureOr<String?> Function()? token,
    RetryPolicy? retry,
    CircuitBreaker? circuitBreaker,
    OmniCache? cache,
    bool deduplicate = true,
    bool followRedirects = true,
    int maxRedirects = 5,
    bool closeDio = false,
  }) {
    final dioBase = dio.options.baseUrl;
    final resolvedBaseUrl =
        baseUrl ?? (dioBase.isEmpty ? null : dioBase);
    final mergedHeaders = <String, String>{
      for (final e in dio.options.headers.entries)
        if (e.value != null) e.key: '${e.value}',
      ...headers,
    };
    return OmniNetwork._(
      baseUrl: resolvedBaseUrl,
      headers: mergedHeaders,
      timeout: timeout,
      connectTimeout: connectTimeout ?? dio.options.connectTimeout,
      sendTimeout: sendTimeout ?? dio.options.sendTimeout,
      receiveTimeout: receiveTimeout ?? dio.options.receiveTimeout,
      maxConcurrentRequests: maxConcurrentRequests,
      decoders: decoders,
      transport: DioTransport(dio: dio),
      ownsTransport: closeDio,
      responseAdapter: responseAdapter,
      enableLogging: enableLogging,
      logResponse: logResponse,
      logColors: logColors,
      logSink: logSink,
      logOptions: logOptions,
      logInRelease: logInRelease,
      redactor: redactor,
      logBodies: logBodies,
      interceptors: interceptors,
      auth: auth,
      token: token,
      retry: retry,
      circuitBreaker: circuitBreaker,
      cache: cache,
      deduplicate: deduplicate,
      followRedirects: followRedirects,
      maxRedirects: maxRedirects,
    );
  }

  OmniNetwork._({
    String? baseUrl,
    Map<String, String> headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.maxConcurrentRequests,
    Map<Type, JsonDecoder<Object?>> decoders = const {},
    required this._transport,
    required this._ownsTransport,
    this.responseAdapter = const PlainResponseAdapter(),
    this._enableLogging = false,
    bool? logResponse,
    bool? logColors,
    LogSink? logSink,
    LogOptions logOptions = const LogOptions(),
    this._logInRelease = false,
    this.redactor = const Redactor(),
    this._logBodies = true,
    List<OmniInterceptor> interceptors = const [],
    AuthProvider? auth,
    FutureOr<String?> Function()? token,
    this.retry,
    this.circuitBreaker,
    this.cache,
    this.deduplicate = true,
    this.followRedirects = true,
    this.maxRedirects = 5,
  }) : assert(
         auth == null || token == null,
         'Pass either token: or auth:, not both',
       ),
       assert(
         maxConcurrentRequests == null || maxConcurrentRequests >= 1,
         'maxConcurrentRequests must be at least 1',
       ),
       _provider =
           auth ?? (token == null ? OmniAuth() : BearerAuth(token: token)),
       interceptors = List.unmodifiable(interceptors),
       _logResponse = logResponse ?? logOptions.responseBody,
       _logColors = logColors ?? logOptions.colors,
       _baseLogOptions = logOptions,
       _customLogSink = logSink,
       baseUri = baseUrl == null ? null : _parseBase(baseUrl),
       _headers = _lower(headers),
       _decoders = Map.unmodifiable(decoders) {
    _syncLogger();
    // Bind the auth provider now so misuse (one OmniAuth for two clients)
    // fails at construction, not on the first request.
    _bearer;
  }

  /// Parsed base URL (always ending in `/`), or `null`.
  final Uri? baseUri;

  final Map<String, String> _headers;

  /// Default headers (lower-case names). Unmodifiable view; update at runtime
  /// with [setHeader], [removeHeader], and [clearHeaders].
  Map<String, String> get headers => Map.unmodifiable(_headers);

  /// Sets or replaces a default header sent with subsequent requests.
  void setHeader(String name, String value) {
    _headers[name.toLowerCase()] = value;
  }

  /// Removes a default header by [name] (case-insensitive).
  void removeHeader(String name) {
    _headers.remove(name.toLowerCase());
  }

  /// Removes all default headers from this client.
  void clearHeaders() {
    _headers.clear();
  }

  /// Clears all entries stored in [cache] (no-op if no cache is configured).
  Future<void> clearCache() async => await cache?.clear();

  /// Invalidates cached GET entries for [pathOrUrl] (resolved against
  /// [baseUri] when relative) plus optional [query].
  Future<void> invalidateCache(
    String pathOrUrl, {
    Map<String, Object?> query = const {},
  }) async {
    final target = cache;
    if (target == null) return;
    final uri = _resolveUri(OmniRequest.get(pathOrUrl, query: query));
    await target.invalidate(uri.toString());
  }

  /// Default overall request timeout.
  final Duration timeout;

  /// Default TCP/TLS connection timeout (when supported by the transport).
  final Duration? connectTimeout;

  /// Default request body upload timeout (when supported by the transport).
  final Duration? sendTimeout;

  /// Default response receive timeout (when supported by the transport).
  final Duration? receiveTimeout;

  /// Maximum concurrent in-flight network requests, or `null` for unlimited.
  final int? maxConcurrentRequests;
  int _activeSlots = 0;
  final Queue<Completer<void>> _slotWaiters = Queue<Completer<void>>();

  final Map<Type, JsonDecoder<Object?>> _decoders;

  /// Returns a registered model decoder for `T`, or `null`. Internal.
  @internal
  JsonDecoder<T>? decoderFor<T>() {
    final registered = _decoders[T];
    if (registered == null) return null;
    return (Map<String, dynamic> json) => registered(json) as T;
  }

  /// Interceptors, in `onRequest` order.
  final List<OmniInterceptor> interceptors;

  final AuthProvider _provider;
  late final BearerAuth _bearer = _provider.bearerFor(this);

  /// The token manager: `api.auth.login(...)`, `logout()`, `isLoggedIn`,
  /// `changes`. Throws [StateError] when the client was created with
  /// `token:` or a custom provider such as `BearerAuth`.
  OmniAuth get auth {
    final p = _provider;
    if (p is OmniAuth) return p;
    throw StateError(
      'This client uses ${p.runtimeType}; api.auth is only available with '
      'OmniAuth (the default)',
    );
  }

  /// Default retry policy, or `null` for no retries.
  final RetryPolicy? retry;

  /// Circuit breaker, or `null`.
  final CircuitBreaker? circuitBreaker;

  int _cancelEpoch = 0;

  /// Response cache, or `null`.
  final OmniCache? cache;

  /// Whether identical concurrent GETs share one network call.
  final bool deduplicate;

  /// Follow 301/302/303/307/308 redirects (safely, see [maxRedirects]).
  ///
  /// Redirects are followed by OmniNetwork itself, not the HTTP library, so
  /// that credentials (`Authorization`, `Cookie`, `Proxy-Authorization`) are
  /// **removed** when a redirect leaves the original origin, and an HTTPS →
  /// HTTP downgrade is never followed (the 3xx response is returned).
  /// 303, and 301/302 after a POST, continue as GET without a body.
  final bool followRedirects;

  /// Maximum redirects per request; the last 3xx is returned after that.
  final int maxRedirects;

  static const _redirects = {301, 302, 303, 307, 308};
  static const _credentialHeaders = {
    'authorization',
    'cookie',
    'proxy-authorization',
  };

  Future<OmniRawResponse> _redirecting(
    TransportRequest resolved,
    OmniRequest request,
    _Transfer? t,
  ) async {
    var current = resolved;
    final origin = resolved.uri;
    for (var hop = 0; ; hop++) {
      final res = await _transmit(current, request, t);
      final location = res.headers['location'];
      if (!followRedirects ||
          !_redirects.contains(res.statusCode) ||
          location == null ||
          hop >= maxRedirects) {
        return res;
      }
      final Uri next;
      try {
        next = current.uri.resolve(location);
      } on FormatException {
        return res;
      }
      if (next.scheme != 'http' && next.scheme != 'https') return res;
      if (current.uri.scheme == 'https' && next.scheme == 'http') return res;
      final sameOrigin =
          next.scheme == origin.scheme &&
          next.host == origin.host &&
          next.port == origin.port;
      final toGet =
          res.statusCode == 303 ||
          ((res.statusCode == 301 || res.statusCode == 302) &&
              current.method == HttpMethod.post);
      final headers = {
        for (final e in current.headers.entries)
          if (sameOrigin || !_credentialHeaders.contains(e.key))
            if (!toGet ||
                (e.key != 'content-type' && e.key != 'content-length'))
              e.key: e.value,
      };
      current = TransportRequest(
        method: toGet && current.method != HttpMethod.head
            ? HttpMethod.get
            : current.method,
        uri: next,
        headers: headers,
        body: toGet ? null : current.body,
        bodyStream: toGet ? null : current.bodyStream,
        contentLength: toGet ? null : current.contentLength,
        onSendProgress: toGet ? null : current.onSendProgress,
        connectTimeout: current.connectTimeout,
        sendTimeout: current.sendTimeout,
        receiveTimeout: current.receiveTimeout,
      );
    }
  }

  final Map<String, _Shared> _inflight = {};

  /// Redaction rules for logs and [toCurl].
  final Redactor redactor;

  final LogOptions _baseLogOptions;
  final bool _logInRelease;
  final bool _logBodies;
  final LogSink? _customLogSink;
  PrettyLogSink? _ownedPrettySink;
  bool _enableLogging;
  bool _logResponse;
  bool? _logColors;

  /// Whether logging is turned on for this client (mutable at runtime).
  ///
  /// Setting this to `true` enables full terminal/logger printing via
  /// [PrettyLogSink] (or the configured `logSink`); setting it to `false`
  /// disables logging immediately. See also [logResponse] and [isLogging].
  bool get enableLogging => _enableLogging;
  set enableLogging(bool value) {
    if (_enableLogging == value) return;
    _enableLogging = value;
    _syncLogger();
  }

  /// Whether full response bodies are printed when logging is enabled
  /// (mutable at runtime).
  ///
  /// Defaults to `true` (unless disabled via `LogOptions(responseBody: false)`
  /// or `logBodies: false`). Set to `true` to print complete 500–1000+ line
  /// responses in the console/terminal, or `false` to omit response bodies.
  bool get logResponse => _logResponse;
  set logResponse(bool value) {
    if (_logResponse == value) return;
    _logResponse = value;
    _syncLogger();
  }

  /// ANSI colour setting for the built-in logger (`null` = auto-detect
  /// terminal/IDE colour support). Mutable at runtime.
  bool? get logColors => _logColors;
  set logColors(bool? value) {
    if (_logColors == value) return;
    _logColors = value;
    _syncLogger();
  }

  /// Whether calls are actually logged right now (`enableLogging`, and not a
  /// release build unless `logInRelease`).
  bool get isLogging => _enableLogging && (_logInRelease || !isReleaseBuild);

  /// Whether this is a release/product build. Tests may override it.
  @visibleForTesting
  static bool isReleaseBuild = const bool.fromEnvironment('dart.vm.product');

  NetworkLogger? _logger;
  int _logSeq = 0;

  LogOptions _resolvedLogOptions() => LogOptions(
    headers: _baseLogOptions.headers,
    requestBody: _baseLogOptions.requestBody,
    responseBody: _logResponse && _logBodies,
    maxLines: _baseLogOptions.maxLines,
    colors: _logColors,
    width: _baseLogOptions.width,
    maxLineLength: _baseLogOptions.maxLineLength,
  );

  void _syncLogger() {
    final options = _resolvedLogOptions();
    _ownedPrettySink?.updateOptions(options);
    final existing = _logger;
    if (existing != null) {
      existing
        ..logBodies = _logBodies
        ..logRequestBody = _baseLogOptions.requestBody
        ..logResponseBody = _logResponse;
    } else if (_enableLogging && (_logInRelease || !isReleaseBuild)) {
      final sink = _customLogSink ?? (_ownedPrettySink ??= PrettyLogSink(options: options));
      _logger = NetworkLogger(
        sink,
        redactor,
        logBodies: _logBodies,
        logRequestBody: _baseLogOptions.requestBody,
        logResponseBody: _logResponse,
      );
    }
  }

  /// Default [ResponseAdapter] for typed calls.
  final ResponseAdapter responseAdapter;

  final Transport _transport;
  final bool _ownsTransport;
  final Set<CancelSignal> _pending = {};
  bool _closed = false;
  Future<void>? _closing;

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// Number of requests currently in flight.
  int get pendingRequests => _pending.length;

  /// Sends [request] and decodes a 2xx body into `T`.
  ///
  /// With [decoder], the body must be a JSON object (after [adapter]).
  /// Without it: nullable `T` (incl. `void`) accepts an empty body;
  /// `String` returns the text; `void`/`dynamic`/`Object?` return the parsed
  /// JSON, or the text if it is not JSON; other `T` (e.g. `int`,
  /// `Map<String, dynamic>`) are cast from the parsed JSON.
  ///
  /// Throws [HttpFailure] for non-2xx, [DecodeFailure] for a bad body, and
  /// everything [sendRaw] throws.
  Future<OmniResponse<T>> _send<T>(
    OmniRequest request, {
    JsonDecoder<T>? decoder,
    ResponseAdapter? adapter,
  }) async {
    final raw = await _ok(request);
    return OmniResponse(
      await decodeBodyAsync<T>(
        raw,
        decoder ?? decoderFor<T>(),
        adapter ?? responseAdapter,
      ),
      raw,
    );
  }

  /// Like [send] for a JSON array of objects.
  Future<OmniResponse<List<T>>> _sendList<T>(
    OmniRequest request, {
    JsonDecoder<T>? decoder,
    ResponseAdapter? adapter,
  }) async {
    final raw = await _ok(request);
    final resolved = decoder ?? decoderFor<T>();
    if (resolved == null) {
      throw DecodeFailure(
        'No JsonDecoder<$T> provided or registered in OmniNetwork(decoders:)',
        uri: raw.requestUri,
      );
    }
    return OmniResponse(
      await decodeListAsync<T>(raw, resolved, adapter ?? responseAdapter),
      raw,
    );
  }

  // ------------------------------------------------------------ verbs
  //
  // Every verb takes the same per-call options:
  //   query, headers, timeout, cancelToken — as usual;
  //   retry — RetryPolicy for this call (RetryPolicy.none disables);
  //   cache — CachePolicy for this GET (needs `cache:` on the client);
  //   auth — false sends this call without the client's token (login,
  //          public endpoints);
  //   adapter — response envelope adapter for this call.
  // `xxxResponse` variants return the full [OmniResponse] (status,
  // headers, duration, source) instead of just the data.

  /// GETs [path] and decodes the body into `T`.
  ///
  /// ```dart
  /// final user = await api.get<User>('/users/10', decoder: User.fromJson);
  /// ```
  ///
  /// Without [decoder]: `String` returns the text; `int`, `Map`, `List`
  /// are cast from JSON; `void` or a nullable `T` accept an empty body.
  Future<T> get<T>(
    String path, {
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cache,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async => (await getResponse<T>(
    path,
    decoder: decoder,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry,
    cache: cache,
    auth: auth,
    adapter: adapter,
  )).data;

  /// Like [get] but returns the full [OmniResponse].
  Future<OmniResponse<T>> getResponse<T>(
    String path, {
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cache,
    bool auth = true,
    ResponseAdapter? adapter,
  }) => _send<T>(
    _req(
      HttpMethod.get,
      path,
      null,
      query,
      headers,
      timeout,
      cancelToken,
      retry,
      cache,
      auth,
    ),
    decoder: decoder,
    adapter: adapter,
  );

  /// GETs a JSON array at [path] and decodes each item with [decoder] (or
  /// a decoder registered in `OmniNetwork(decoders:)`).
  Future<List<T>> getList<T>(
    String path, {
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cache,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async => (await _sendList<T>(
    _req(
      HttpMethod.get,
      path,
      null,
      query,
      headers,
      timeout,
      cancelToken,
      retry,
      cache,
      auth,
    ),
    decoder: decoder,
    adapter: adapter,
  )).data;

  /// POSTs [fields] encoded as `application/x-www-form-urlencoded` and decodes
  /// the 2xx response into `T`.
  Future<T> postForm<T>(
    String path, {
    Map<String, Object?> fields = const {},
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async => (await postFormResponse<T>(
    path,
    fields: fields,
    decoder: decoder,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry,
    auth: auth,
    adapter: adapter,
  )).data;

  /// Like [postForm] but returns the full [OmniResponse].
  Future<OmniResponse<T>> postFormResponse<T>(
    String path, {
    Map<String, Object?> fields = const {},
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) => _send<T>(
    _req(
      HttpMethod.post,
      path,
      _encodeFormFields(fields),
      query,
      {'content-type': 'application/x-www-form-urlencoded', ...headers},
      timeout,
      cancelToken,
      retry,
      null,
      auth,
    ),
    decoder: decoder,
    adapter: adapter,
  );

  static String _encodeFormFields(Map<String, Object?> fields) {
    final normalized = <String, Object>{};
    for (final e in fields.entries) {
      final v = e.value;
      if (v == null) continue;
      if (v is Iterable) {
        normalized[e.key] = [
          for (final item in v)
            if (item != null) '$item',
        ];
      } else {
        normalized[e.key] = '$v';
      }
    }
    return Uri(queryParameters: normalized).query;
  }

  /// POSTs [body] (JSON value, `String` or bytes) and decodes the response.
  Future<T> post<T>(
    String path, {
    Object? body,
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async => (await postResponse<T>(
    path,
    body: body,
    decoder: decoder,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry,
    auth: auth,
    adapter: adapter,
  )).data;

  /// Like [post] but returns the full [OmniResponse].
  Future<OmniResponse<T>> postResponse<T>(
    String path, {
    Object? body,
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) => _send<T>(
    _req(
      HttpMethod.post,
      path,
      body,
      query,
      headers,
      timeout,
      cancelToken,
      retry,
      null,
      auth,
    ),
    decoder: decoder,
    adapter: adapter,
  );

  /// PUTs [body] and decodes the response.
  Future<T> put<T>(
    String path, {
    Object? body,
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async => (await putResponse<T>(
    path,
    body: body,
    decoder: decoder,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry,
    auth: auth,
    adapter: adapter,
  )).data;

  /// Like [put] but returns the full [OmniResponse].
  Future<OmniResponse<T>> putResponse<T>(
    String path, {
    Object? body,
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) => _send<T>(
    _req(
      HttpMethod.put,
      path,
      body,
      query,
      headers,
      timeout,
      cancelToken,
      retry,
      null,
      auth,
    ),
    decoder: decoder,
    adapter: adapter,
  );

  /// PATCHes [body] and decodes the response.
  Future<T> patch<T>(
    String path, {
    Object? body,
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async => (await patchResponse<T>(
    path,
    body: body,
    decoder: decoder,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry,
    auth: auth,
    adapter: adapter,
  )).data;

  /// Like [patch] but returns the full [OmniResponse].
  Future<OmniResponse<T>> patchResponse<T>(
    String path, {
    Object? body,
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) => _send<T>(
    _req(
      HttpMethod.patch,
      path,
      body,
      query,
      headers,
      timeout,
      cancelToken,
      retry,
      null,
      auth,
    ),
    decoder: decoder,
    adapter: adapter,
  );

  /// DELETEs [path] and decodes the response (often `void`).
  Future<T> delete<T>(
    String path, {
    Object? body,
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async => (await deleteResponse<T>(
    path,
    body: body,
    decoder: decoder,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry,
    auth: auth,
    adapter: adapter,
  )).data;

  /// Like [delete] but returns the full [OmniResponse].
  Future<OmniResponse<T>> deleteResponse<T>(
    String path, {
    Object? body,
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
    ResponseAdapter? adapter,
  }) => _send<T>(
    _req(
      HttpMethod.delete,
      path,
      body,
      query,
      headers,
      timeout,
      cancelToken,
      retry,
      null,
      auth,
    ),
    decoder: decoder,
    adapter: adapter,
  );

  /// HEADs [path]; returns the 2xx response (status and headers only).
  Future<OmniRawResponse> head(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    bool auth = true,
  }) => _ok(
    _req(
      HttpMethod.head,
      path,
      null,
      query,
      headers,
      timeout,
      cancelToken,
      retry,
      null,
      auth,
    ),
  );

  static OmniRequest _req(
    HttpMethod method,
    String path,
    Object? body,
    Map<String, Object?> query,
    Map<String, String> headers,
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cache,
    bool auth,
  ) => OmniRequest(
    method,
    path,
    body: body,
    query: query,
    headers: headers,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry,
    cachePolicy: cache,
    skipAuth: !auth,
  );

  /// Calls [endpoint] and returns its decoded result.
  ///
  /// ```dart
  /// final user = await api.call(UserApi.byId, path: {'id': 10});
  /// ```
  Future<T> call<T>(
    Endpoint<T> endpoint, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cache,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async => (await callResponse(
    endpoint,
    path: path,
    query: query,
    headers: headers,
    body: body,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry,
    cache: cache,
    auth: auth,
    adapter: adapter,
  )).data;

  /// Like [call] but returns the full [OmniResponse].
  Future<OmniResponse<T>> callResponse<T>(
    Endpoint<T> endpoint, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cache,
    bool auth = true,
    ResponseAdapter? adapter,
  }) async {
    final raw = await _ok(
      endpoint.request(
        path: path,
        query: query,
        headers: headers,
        body: body,
        timeout: timeout,
        cancelToken: cancelToken,
        retry: retry,
        cachePolicy: cache,
        skipAuth: !auth,
      ),
    );
    return OmniResponse(
      await endpoint.decodeAsync(
        raw,
        adapter ?? responseAdapter,
        lookupDecoder: decoderFor,
      ),
      raw,
    );
  }

  /// A [RequestController] that GETs [path] decoded into `T` (see [send]).
  /// Starts loading at once unless [autoLoad] is `false`.
  RequestController<T> watch<T>(
    String path, {
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    CachePolicy? cachePolicy,
    bool Function(T value)? isEmpty,
    bool autoLoad = true,
  }) => RequestController<T>(
    (token) async => (await _send<T>(
      OmniRequest.get(
        path,
        query: query,
        headers: headers,
        cancelToken: token,
        cachePolicy: cachePolicy,
      ),
      decoder: decoder,
    )).data,
    isEmpty: isEmpty,
    autoLoad: autoLoad,
  );

  /// Like [watch] for a JSON array; an empty array is [RequestEmpty].
  RequestController<List<T>> watchList<T>(
    String path, {
    JsonDecoder<T>? decoder,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    CachePolicy? cachePolicy,
    bool autoLoad = true,
  }) => RequestController<List<T>>(
    (token) async => (await _sendList<T>(
      OmniRequest.get(
        path,
        query: query,
        headers: headers,
        cancelToken: token,
        cachePolicy: cachePolicy,
      ),
      decoder: decoder,
    )).data,
    autoLoad: autoLoad,
  );

  /// A pager over the list at [path]; see [OmniPager].
  ///
  /// [itemsKey] is the JSON path of the items in the full body (e.g.
  /// `data`), so metadata such as `meta.next_cursor` stays visible to the
  /// [strategy]. Without it, the client's response adapter result must be
  /// the item array.
  OmniPager<T> paginate<T>(
    String path, {
    JsonDecoder<T>? decoder,
    required PaginationStrategy strategy,
    String? itemsKey,
    int? maxPages,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
  }) => OmniPager<T>(
    client: this,
    request: OmniRequest.get(path, query: query, headers: headers),
    strategy: strategy,
    decoder: decoder,
    itemsKey: itemsKey,
    maxPages: maxPages,
  );

  /// Uploads [files] and text [fields] as `multipart/form-data` and decodes
  /// the 2xx response into `T` (see [send]).
  ///
  /// [onProgress] reports bytes handed to the transport. Transfers have no
  /// overall deadline unless [timeout] is given; instead they fail with
  /// [TimeoutFailure] when no progress happens for [idleTimeout] (default:
  /// the client [timeout]). Cancel with [cancelToken].
  Future<T> upload<T>(
    String path, {
    List<UploadFile> files = const [],
    Map<String, String> fields = const {},
    HttpMethod method = HttpMethod.post,
    ProgressCallback? onProgress,
    JsonDecoder<T>? decoder,
    ResponseAdapter? adapter,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? idleTimeout,
    OmniCancelToken? cancelToken,
  }) async {
    final request = OmniRequest(
      method,
      path,
      body: MultipartBody(fields: fields, files: files),
      query: query,
      headers: headers,
      cancelToken: cancelToken,
    );
    final raw = await _pipeline(
      request,
      _Transfer(onSend: onProgress, overall: timeout, idle: idleTimeout),
    );
    if (!raw.isSuccess) throw HttpFailure(raw);
    return decodeBodyAsync<T>(
      raw,
      decoder ?? decoderFor<T>(),
      adapter ?? responseAdapter,
    );
  }

  /// Downloads [path] into memory. See [upload] for timeouts/cancel.
  /// [onProgress] receives bytes received and `content-length` (if sent).
  Future<Uint8List> downloadBytes(
    String path, {
    ProgressCallback? onProgress,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? idleTimeout,
    OmniCancelToken? cancelToken,
  }) async {
    final target = BytesTarget();
    await _downloadTo(
      target,
      OmniRequest.get(
        path,
        query: query,
        headers: headers,
        cancelToken: cancelToken,
      ),
      onProgress,
      timeout,
      idleTimeout,
    );
    return target.bytes;
  }

  /// Opens a long-lived streamed response (e.g. Server-Sent Events) through
  /// the full pipeline (interceptors, auth incl. refresh on 401, logging).
  ///
  /// Completes once a 2xx status and headers arrive; the body then flows
  /// through [OmniStreamResponse.body]. Non-2xx throws [HttpFailure]. There
  /// is no overall or idle timeout unless [timeout]/[idleTimeout] is given.
  /// Cancelling the body subscription (or [OmniStreamResponse.cancel], or
  /// the request's `cancelToken`) aborts the connection. Not retried.
  Future<OmniStreamResponse> _openStream(
    OmniRequest request, {
    Duration? timeout,
    Duration? idleTimeout,
  }) async {
    final own = request.cancelToken?.child() ?? OmniCancelToken();
    final target = StreamTarget(own.cancel);
    final pipeline = _pipeline(
      request.copyWith(cancelToken: own),
      _Transfer(
        target: target,
        overall: timeout,
        idle: idleTimeout,
        noIdle: idleTimeout == null,
      ),
    );
    unawaited(
      pipeline.then(
        (_) {},
        onError: (Object e, StackTrace st) => target.fail(e, st),
      ),
    );
    final first = await Future.any<Object?>([
      target.started.then((_) => null),
      pipeline,
    ]);
    if (first is OmniRawResponse) {
      if (!first.isSuccess) throw HttpFailure(first);
      // 2xx whose body already ended (begin() ran too): fall through.
    }
    final headers = await target.started;
    return OmniStreamResponse(
      statusCode: headers.$1,
      headers: headers.$2,
      body: target.stream,
      cancel: own.cancel,
    );
  }

  /// Whether [downloadToFile] works on this platform (`false` on Web).
  static bool get supportsFileDownload => fileDownloadSupported;

  /// Downloads [path] to [filePath] (IO platforms only; on Web throws
  /// [UnsupportedError], use [downloadBytes]).
  ///
  /// Data is written to `<filePath>.part` and renamed on success. When the
  /// download fails or is cancelled the `.part` file is kept; with
  /// [resume] a later call continues it using an HTTP `Range` request if
  /// the server answers `206`, or starts over if it answers `200`.
  /// Returns the final response (status and headers; empty body).
  Future<OmniRawResponse> downloadToFile(
    String path,
    String filePath, {
    bool resume = false,
    ProgressCallback? onProgress,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? idleTimeout,
    OmniCancelToken? cancelToken,
  }) => _downloadTo(
    FileTarget(filePath, resume: resume),
    OmniRequest.get(
      path,
      query: query,
      headers: headers,
      cancelToken: cancelToken,
    ),
    onProgress,
    timeout,
    idleTimeout,
  );

  Future<OmniRawResponse> _downloadTo(
    DownloadTarget target,
    OmniRequest request,
    ProgressCallback? onProgress,
    Duration? timeout,
    Duration? idleTimeout,
  ) async {
    final from = await target.existingLength();
    final raw = await _pipeline(
      from > 0 ? request.withHeader('Range', 'bytes=$from-') : request,
      _Transfer(
        target: target,
        onReceive: onProgress,
        overall: timeout,
        idle: idleTimeout,
        resumeFrom: from,
      ),
    );
    if (!raw.isSuccess) throw HttpFailure(raw);
    return raw;
  }

  Future<OmniRawResponse> _ok(OmniRequest request) async {
    final raw = await _sendRaw(request);
    if (!raw.isSuccess) throw HttpFailure(raw);
    return raw;
  }

  /// Sends [request] and returns the raw response for **any** status code
  /// (no decoding, no status check).
  ///
  /// Throws an [OmniNetworkException]: [TimeoutFailure], [ConnectionFailure],
  /// [ClosedFailure] or [RequestFailure].
  Future<OmniRawResponse> _sendRaw(OmniRequest request) =>
      _pipeline(request, null);

  Future<OmniRawResponse> _pipeline(OmniRequest request, _Transfer? t) async {
    if (_closed) throw const ClosedFailure();
    if (request.cancelToken?.isCancelled ?? false) {
      throw const CancelledFailure();
    }
    var current = request;
    final epoch = _cancelEpoch;
    try {
      for (final i in interceptors) {
        final r = current;
        current = await _guard(() => i.onRequest(r));
      }
      var response = await _withRetry(current, t, epoch);
      for (final i in interceptors.reversed) {
        final res = response;
        final r = current;
        response = await _guard(() => i.onResponse(r, res));
      }
      return response;
    } on OmniNetworkException catch (e) {
      for (final i in interceptors.reversed) {
        try {
          await i.onError(current, e);
        } catch (_) {
          // Keep the original failure.
        }
      }
      rethrow;
    }
  }

  Future<OmniRawResponse> _withRetry(
    OmniRequest request,
    _Transfer? t,
    int epoch,
  ) async {
    final policy = t == null ? request.retry ?? retry : null;
    if (policy == null || !policy.allows(request)) {
      return _guarded(request, t, epoch);
    }
    for (var attempt = 1; ; attempt++) {
      final last = attempt >= policy.maxAttempts;
      Duration? wait;
      try {
        final res = attempt == 1
            ? await _guarded(request, t, epoch)
            : await withLogNote(
                'retry $attempt/${policy.maxAttempts}',
                () => _guarded(request, t, epoch),
              );
        if (last || !policy.statuses.contains(res.statusCode)) return res;
        wait = policy.delayFor(attempt, res);
        if (wait == null) return res;
      } on OmniNetworkException catch (e) {
        if (last || !policy.retriesError(e)) rethrow;
        wait = policy.backoff(attempt);
      }
      await _sleep(wait, request);
      _checkStillWanted(request, epoch);
    }
  }

  Future<OmniRawResponse> _guarded(
    OmniRequest request,
    _Transfer? t,
    int epoch,
  ) async {
    final breaker = circuitBreaker;
    if (breaker == null) return _authorized(request, t, epoch);
    final uri = _resolveUri(request);
    final host = '${uri.host}:${uri.port}';
    breaker.acquire(host, safeUri(uri));
    try {
      final res = await _authorized(request, t, epoch);
      breaker.record(host, success: res.statusCode < 500);
      return res;
    } on OmniNetworkException catch (e) {
      if (e is TimeoutFailure || e is ConnectionFailure) {
        breaker.record(host, success: false);
      } else {
        breaker.release(host);
      }
      rethrow;
    }
  }

  Future<void> _sleep(Duration delay, OmniRequest request) async {
    final signal = CancelSignal();
    final timer = Timer(delay, signal.cancel);
    final detach = request.cancelToken?.attach(
      () => signal.cancel(_Reason.user),
    );
    _pending.add(signal);
    try {
      final reason = await signal.whenCancelled;
      if (reason == _Reason.closed) throw const ClosedFailure();
      if (reason == _Reason.user) throw const CancelledFailure();
    } finally {
      timer.cancel();
      detach?.call();
      _pending.remove(signal);
    }
  }

  /// Cancels every in-flight request (including ones waiting for a retry
  /// or a token refresh) with [CancelledFailure]; the client stays usable.
  void cancelAll() {
    _cancelEpoch++;
    for (final s in _pending.toList()) {
      s.cancel(_Reason.user);
    }
  }

  Future<OmniRawResponse> _authorized(
    OmniRequest request,
    _Transfer? t,
    int epoch,
  ) async {
    final auth = _bearer;
    if (request.skipAuth ||
        insideRefresh ||
        request.header(auth.headerName) != null) {
      return _sendOnce(request, t);
    }
    final refreshesBefore = auth.refreshCount;
    final used = await auth.current();
    _checkStillWanted(request, epoch);
    final first = auth.refreshCount == refreshesBefore
        ? await _sendOnce(auth.attach(request, used), t)
        : await withLogNote(
            'token refreshed',
            () => _sendOnce(auth.attach(request, used), t),
          );
    if (auth.refresh == null || !auth.isExpired(first)) return first;
    final fresh = await auth.recover(used, first);
    _checkStillWanted(request, epoch);
    return withLogNote(
      'token refreshed',
      () => _sendOnce(auth.attach(request, fresh), t),
    );
  }

  void _checkStillWanted(OmniRequest request, int epoch) {
    if (_closed) throw const ClosedFailure();
    if (epoch != _cancelEpoch) throw const CancelledFailure();
    if (request.cancelToken?.isCancelled ?? false) {
      throw const CancelledFailure();
    }
  }

  static Future<T> _guard<T>(FutureOr<T> Function() run) async {
    try {
      return await run();
    } on OmniNetworkException {
      rethrow;
    } on Exception catch (e) {
      throw RequestFailure('Interceptor threw ${e.runtimeType}', cause: e);
    }
  }

  Future<OmniRawResponse> _sendOnce(OmniRequest request, _Transfer? t) async {
    if (_closed) throw const ClosedFailure();
    _syncLogger();
    final log = isLogging ? _logger : null;
    if (log == null) return _network(_resolve(request), request, t);
    final id = ++_logSeq;
    final watch = Stopwatch()..start();
    TransportRequest? resolved;
    try {
      resolved = _resolve(request);
      log.request(id, resolved);
      final response = await _network(resolved, request, t);
      log.response(id, resolved, response);
      return response;
    } on OmniNetworkException catch (e) {
      log.error(id, resolved, request.method.verb, e, watch.elapsed);
      rethrow;
    }
  }

  Future<OmniRawResponse> _network(
    TransportRequest resolved,
    OmniRequest request,
    _Transfer? t,
  ) async {
    final cache = this.cache;
    if (cache == null || t != null) return _redirecting(resolved, request, t);
    final res = await cache.handle(
      resolved,
      request.cachePolicy,
      (r) => _redirecting(r, request, null),
    );
    return res.requestUri != null
        ? res
        : res.finish(duration: res.duration, requestUri: safeUri(resolved.uri));
  }

  Future<OmniRawResponse> _shared(TransportRequest r, CancelSignal caller) {
    final key = [
      r.uri.toString(),
      for (final e
          in (r.headers.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key))))
        '${e.key}:${e.value}',
    ].join('\n');
    var shared = _inflight[key];
    if (shared == null) {
      final signal = CancelSignal();
      final s = shared = _Shared(
        signal,
        Future.sync(() => _transport.send(r, signal)),
      );
      _inflight[key] = s;
      s.future.whenComplete(() {
        if (identical(_inflight[key], s)) _inflight.remove(key);
      }).ignore();
    }
    final s = shared;
    s.waiters++;
    caller.whenCancelled.then((_) {
      if (--s.waiters == 0) {
        s.signal.cancel();
        if (identical(_inflight[key], s)) _inflight.remove(key);
      }
    });
    return s.future;
  }

  Future<OmniRawResponse> _transmit(
    TransportRequest resolved,
    OmniRequest request,
    _Transfer? t,
  ) async {
    final uri = safeUri(resolved.uri);
    final signal = CancelSignal();
    final limit = t == null ? request.timeout ?? timeout : t.overall;
    final timer = limit == null
        ? null
        : Timer(limit, () => signal.cancel(_Reason.timeout));
    Timer? idle;
    final idleLimit = t?.idle ?? timeout;
    void kick() {
      if (t == null || t.noIdle || signal.isCancelled) return;
      idle?.cancel();
      idle = Timer(idleLimit, () => signal.cancel(_Reason.idle));
    }

    final detach = request.cancelToken?.attach(
      () => signal.cancel(_Reason.user),
    );
    _pending.add(signal);
    var outgoing = resolved;
    final open = resolved.bodyStream;
    if (t != null && open != null) {
      final total = resolved.contentLength;
      if (_transport is ProgressReportingTransport) {
        outgoing = resolved
            .withBodyStream(
              () => open().map((chunk) {
                kick();
                return chunk;
              }),
            )
            .copyWith(
              onSendProgress: (sent, reportedTotal) {
                kick();
                t.onSend?.call(sent, reportedTotal ?? total);
              },
            );
      } else {
        outgoing = resolved.withBodyStream(() {
          var sent = 0;
          return open().map((chunk) {
            sent += chunk.length;
            kick();
            t.onSend?.call(sent, total);
            return chunk;
          });
        });
      }
    }
    final watch = Stopwatch()..start();
    final target = t?.target;
    Future<OmniRawResponse>? work;
    var hasSlot = false;
    try {
      hasSlot = await _acquireSlot(signal);
      kick();
      final response = await Future.any<OmniRawResponse>([
        work = Future.sync(
          () => target == null
              ? (deduplicate &&
                        outgoing.method == HttpMethod.get &&
                        outgoing.body == null &&
                        outgoing.bodyStream == null
                    ? _shared(outgoing, signal)
                    : _transport.send(outgoing, signal))
              : _download(outgoing, signal, t!, target, kick, uri),
        ),
        signal.whenCancelled.then<OmniRawResponse>(
          (_) => throw CancelledFailure(uri: uri),
        ),
      ]);
      return response.finish(duration: watch.elapsed, requestUri: uri);
    } on OmniNetworkException catch (e) {
      if (e is CancelledFailure && signal.isCancelled) {
        // A cancelled download is still closing its `.part` file; wait for
        // that so a resume right after starts from the real length.
        if (target != null && work != null) {
          await work
              .then<void>((_) {}, onError: (Object _) {})
              .timeout(const Duration(seconds: 5), onTimeout: () {});
        }
        final reason = await signal.whenCancelled;
        if (reason == _Reason.timeout) throw TimeoutFailure(limit!, uri: uri);
        if (reason == _Reason.idle) throw TimeoutFailure(idleLimit, uri: uri);
        if (reason == _Reason.closed) throw ClosedFailure(uri: uri);
        throw CancelledFailure(uri: uri);
      }
      rethrow;
    } on Exception catch (e) {
      throw ConnectionFailure('Transport error', uri: uri, cause: e);
    } finally {
      if (hasSlot) _releaseSlot();
      timer?.cancel();
      idle?.cancel();
      detach?.call();
      _pending.remove(signal);
    }
  }

  Future<bool> _acquireSlot(CancelSignal signal) async {
    final limit = maxConcurrentRequests;
    if (limit == null) return false;
    if (signal.isCancelled) throw const CancelledFailure();
    if (_activeSlots < limit) {
      _activeSlots++;
      return true;
    }
    final gate = Completer<void>();
    _slotWaiters.addLast(gate);
    final cancelSub = signal.whenCancelled.then((_) {
      if (!gate.isCompleted) {
        _slotWaiters.remove(gate);
        gate.completeError(const CancelledFailure());
      }
    });
    try {
      await gate.future;
      return true;
    } finally {
      cancelSub.ignore();
    }
  }

  void _releaseSlot() {
    while (_slotWaiters.isNotEmpty) {
      final next = _slotWaiters.removeFirst();
      if (!next.isCompleted) {
        next.complete();
        return;
      }
    }
    if (_activeSlots > 0) _activeSlots--;
  }

  Future<OmniRawResponse> _download(
    TransportRequest request,
    CancelSignal signal,
    _Transfer t,
    DownloadTarget target,
    void Function() kick,
    Uri uri,
  ) async {
    final res = await _transport.sendStreamed(request, signal);
    kick();
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (!ok) {
      // Error bodies are small: buffer them for HttpFailure/auth handling.
      final b = BytesBuilder(copy: false);
      await for (final chunk in res.body) {
        b.add(chunk);
      }
      return OmniRawResponse(
        statusCode: res.statusCode,
        headers: res.headers,
        bodyBytes: b.takeBytes(),
      );
    }
    final append = res.statusCode == 206 && t.resumeFrom > 0;
    var received = append ? t.resumeFrom : 0;
    final length = res.contentLength;
    final total = length == null ? null : length + received;
    if (target is StreamTarget) target.head(res.statusCode, res.headers);
    await target.begin(append: append);
    final done = Completer<void>();
    void fail(Object e) {
      if (done.isCompleted) return;
      done.completeError(
        e is OmniNetworkException
            ? e
            : ConnectionFailure('Download failed', uri: uri, cause: e),
      );
    }

    late final StreamSubscription<List<int>> sub;
    sub = res.body.listen(
      (chunk) async {
        sub.pause();
        try {
          await target.add(chunk);
          received += chunk.length;
          kick();
          t.onReceive?.call(received, total);
        } catch (e) {
          await sub.cancel();
          fail(e);
        } finally {
          sub.resume();
        }
      },
      onError: (Object e) {
        sub.cancel();
        fail(e);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    unawaited(
      signal.whenCancelled.then((_) {
        sub.cancel();
        fail(CancelledFailure(uri: uri));
      }),
    );
    try {
      await done.future;
      await target.commit();
    } catch (_) {
      await target.abort();
      rethrow;
    }
    return OmniRawResponse(statusCode: res.statusCode, headers: res.headers);
  }

  /// Builds the [TransportRequest] for [request] without sending it.
  /// Throws [RequestFailure] for an unresolvable URL or unsupported body.
  TransportRequest _resolve(OmniRequest request) {
    final uri = _resolveUri(request);
    final merged = {..._headers, ..._lower(request.headers)};
    final reqConnectTimeout = request.connectTimeout ?? connectTimeout;
    final reqSendTimeout = request.sendTimeout ?? sendTimeout;
    final reqReceiveTimeout = request.receiveTimeout ?? receiveTimeout;
    final body = request.body;
    if (body is MultipartBody) {
      if (request.method == HttpMethod.get ||
          request.method == HttpMethod.head) {
        throw RequestFailure(
          '${request.method.verb} requests cannot have a body',
          uri: safeUri(uri),
        );
      }
      merged['content-type'] = body.contentType;
      return TransportRequest(
        method: request.method,
        uri: uri,
        headers: merged,
        bodyStream: body.open,
        contentLength: body.length,
        connectTimeout: reqConnectTimeout,
        sendTimeout: reqSendTimeout,
        receiveTimeout: reqReceiveTimeout,
      );
    }
    final encoded = _encodeBody(request, merged, uri);
    return TransportRequest(
      method: request.method,
      uri: uri,
      headers: merged,
      body: encoded,
      connectTimeout: reqConnectTimeout,
      sendTimeout: reqSendTimeout,
      receiveTimeout: reqReceiveTimeout,
    );
  }

  /// Closes the client: in-flight requests fail with [ClosedFailure], new
  /// ones are rejected, and an owned transport is closed. Idempotent.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    final provider = _provider;
    if (provider is OmniAuth) await provider.close();
    for (final s in _pending.toList()) {
      s.cancel(_Reason.closed);
    }
    for (final s in _inflight.values.toList()) {
      s.signal.cancel();
    }
    _inflight.clear();
    if (_ownsTransport) await _transport.close(force: true);
  }

  Uri _resolveUri(OmniRequest request) {
    final Uri parsed;
    try {
      parsed = Uri.parse(request.path);
    } on FormatException catch (e) {
      throw RequestFailure('Invalid path', cause: e);
    }
    final Uri target;
    if (parsed.hasScheme) {
      if (parsed.scheme != 'http' && parsed.scheme != 'https') {
        throw RequestFailure('Unsupported URL scheme "${parsed.scheme}"');
      }
      target = parsed;
    } else {
      final base = baseUri;
      if (base == null) {
        throw const RequestFailure(
          'Relative path used but no baseUrl was configured',
        );
      }
      var rel = request.path;
      while (rel.startsWith('/')) {
        rel = rel.substring(1);
      }
      target = base.resolve(rel);
    }
    if (request.query.isEmpty) return target;
    final all = <String, List<String>>{
      for (final e in target.queryParametersAll.entries) e.key: [...e.value],
    };
    for (final MapEntry(:key, :value) in request.query.entries) {
      if (value == null) continue;
      final values = value is Iterable
          ? [
              for (final v in value)
                if (v != null) '$v',
            ]
          : ['$value'];
      (all[key] ??= []).addAll(values);
    }
    return target.replace(queryParameters: all);
  }

  static Uint8List? _encodeBody(
    OmniRequest request,
    Map<String, String> headers,
    Uri uri,
  ) {
    final body = request.body;
    if (body == null) return null;
    if (request.method == HttpMethod.get || request.method == HttpMethod.head) {
      throw RequestFailure(
        '${request.method.verb} requests cannot have a body',
        uri: safeUri(uri),
      );
    }
    void type(String t) => headers.putIfAbsent('content-type', () => t);
    switch (body) {
      case Uint8List():
        type('application/octet-stream');
        return body;
      case List<int>():
        type('application/octet-stream');
        return Uint8List.fromList(body);
      case String():
        type('text/plain; charset=utf-8');
        return utf8.encode(body);
      case Map() || List() || num() || bool():
        type('application/json; charset=utf-8');
        try {
          return utf8.encode(jsonEncode(body));
        } on JsonUnsupportedObjectError catch (e) {
          throw RequestFailure(
            'Body is not JSON-encodable',
            uri: safeUri(uri),
            cause: e,
          );
        }
      default:
        throw RequestFailure(
          'Unsupported body type ${body.runtimeType}; pass a JSON value, '
          'String or List<int>',
          uri: safeUri(uri),
        );
    }
  }

  static Uri _parseBase(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'must be an absolute http(s) URL',
      );
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'must not contain a query or fragment',
      );
    }
    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }

  static Map<String, String> _lower(Map<String, String> h) => {
    for (final e in h.entries) e.key.toLowerCase(): e.value,
  };
}

final class _Shared {
  _Shared(this.signal, this.future);
  final CancelSignal signal;
  final Future<OmniRawResponse> future;
  int waiters = 0;
}

enum _Reason { timeout, idle, closed, user }

final class _Transfer {
  _Transfer({
    this.onSend,
    this.onReceive,
    this.target,
    this.overall,
    this.idle,
    this.resumeFrom = 0,
    this.noIdle = false,
  });

  final bool noIdle;
  final ProgressCallback? onSend;
  final ProgressCallback? onReceive;
  final DownloadTarget? target;
  final Duration? overall;
  final Duration? idle;
  final int resumeFrom;
}
