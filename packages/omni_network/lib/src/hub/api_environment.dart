import 'dart:async';
import 'dart:collection' show Queue;

import 'package:meta/meta.dart';

import '../ai/ai_models.dart';
import '../auth/bearer_auth.dart';
import '../cache/omni_cache.dart';
import '../core/decoding.dart';
import '../core/interceptor.dart';
import '../core/omni_request.dart';
import '../core/response_adapter.dart';
import '../resilience/circuit_breaker.dart';
import '../resilience/retry_policy.dart';
import '../transport/dns_resolver.dart';

/// Environment profile (`dev`, `staging`, `prod`) applied across all services
/// registered in an `OmniApiHub`.
@immutable
final class OmniEnvironment {
  /// Creates an environment profile.
  const OmniEnvironment({
    required this.name,
    this.variables = const {},
    this.headers = const {},
    this.enableLogging,
    this.proxy,
    this.pinnedSha256 = const [],
    this.enableHttp2,
    this.timeout,
  });

  /// Profile name (`'dev'`, `'staging'`, `'prod'`).
  final String name;

  /// Variable map referenced by [ServiceConfig.baseUrlVar] and
  /// [ServiceConfig.wsUrlVar] (e.g. `{'coreUrl': 'https://api.example.com'}`).
  final Map<String, String> variables;

  /// Environment-wide default headers merged into all services.
  final Map<String, String> headers;

  /// Optional override for `OmniNetwork.enableLogging`.
  final bool? enableLogging;

  /// Optional debugging proxy for this environment.
  final String? proxy;

  /// Default SHA-256 certificate pins applied when a service omits its own.
  final List<String> pinnedSha256;

  /// Optional HTTP/2 toggle override.
  final bool? enableHttp2;

  /// Optional overall timeout override.
  final Duration? timeout;

  /// Restores an environment profile from JSON (e.g. remote config).
  factory OmniEnvironment.fromJson(String name, Map<String, Object?> json) =>
      OmniEnvironment(
        name: name,
        variables: Map<String, String>.from(
          json['variables'] as Map? ?? const {},
        ),
        headers: Map<String, String>.from(json['headers'] as Map? ?? const {}),
        enableLogging: json['enableLogging'] as bool?,
        proxy: json['proxy'] as String?,
        pinnedSha256: [
          for (final p in json['pinnedSha256'] as List? ?? const []) '$p',
        ],
        enableHttp2: json['enableHttp2'] as bool?,
        timeout: json['timeoutMs'] is int
            ? Duration(milliseconds: json['timeoutMs']! as int)
            : null,
      );
}

/// Sliding-window rate limit applied per service via [RateLimiterInterceptor].
@immutable
final class RateLimit {
  /// Limits requests to at most [maxRequests] within any [per] window.
  const RateLimit({required this.maxRequests, required this.per})
    : assert(maxRequests >= 1);

  /// Maximum allowed requests per [per] window.
  final int maxRequests;

  /// Sliding time window duration.
  final Duration per;
}

/// [OmniInterceptor] enforcing a [RateLimit] using a non-dropping async queue
/// (works identically on Mobile, Desktop, and Web).
final class RateLimiterInterceptor extends OmniInterceptor {
  /// Creates a rate-limiting interceptor.
  RateLimiterInterceptor(this.limit, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Sliding-window limit.
  final RateLimit limit;
  final DateTime Function() _now;
  final Queue<DateTime> _timestamps = Queue<DateTime>();
  Future<void> _chain = Future<void>.value();

  @override
  Future<OmniRequest> onRequest(OmniRequest request) {
    final next = _chain.then((_) async {
      while (true) {
        final now = _now();
        while (_timestamps.isNotEmpty &&
            now.difference(_timestamps.first) >= limit.per) {
          _timestamps.removeFirst();
        }
        if (_timestamps.length < limit.maxRequests) {
          _timestamps.addLast(now);
          return request;
        }
        final wait = limit.per - now.difference(_timestamps.first);
        await Future<void>.delayed(
          wait > Duration.zero ? wait : const Duration(milliseconds: 1),
        );
      }
    });
    _chain = next.then((_) {}, onError: (_) {});
    return next;
  }
}

/// Complete client recipe for one backend API inside `OmniApiHub` (REST,
/// GraphQL, WebSocket, SSE, Payments, Auth, Third-Party APIs).
@immutable
final class ServiceConfig {
  /// Creates a service configuration with fixed [baseUrl] or variable lookup
  /// [baseUrlVar].
  const ServiceConfig({
    this.baseUrl,
    this.baseUrlVar,
    this.wsUrl,
    this.wsUrlVar,
    this.headers = const {},
    this.timeout,
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.auth,
    this.token,
    this.retry,
    this.cache,
    this.circuitBreaker,
    this.decoders = const {},
    this.pinnedSha256 = const [],
    this.allowBadProxyCertificate = true,
    this.clientCertificateBytes,
    this.clientPrivateKeyBytes,
    this.clientCertificatePassword,
    this.dnsOverHttps,
    this.dnsLookup,
    this.enableHttp2,
    this.maxConcurrentRequests,
    this.slowRequestThreshold,
    this.onSlowRequest,
    this.rateLimit,
    this.interceptors = const [],
    this.responseAdapter = const PlainResponseAdapter(),
  });

  /// Creates a service whose URLs resolve dynamically from environment
  /// variables [baseUrlVar] and optional [wsUrlVar].
  const ServiceConfig.fromVar({
    required this.baseUrlVar,
    this.wsUrlVar,
    this.headers = const {},
    this.timeout,
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.auth,
    this.token,
    this.retry,
    this.cache,
    this.circuitBreaker,
    this.decoders = const {},
    this.pinnedSha256 = const [],
    this.allowBadProxyCertificate = true,
    this.clientCertificateBytes,
    this.clientPrivateKeyBytes,
    this.clientCertificatePassword,
    this.dnsOverHttps,
    this.dnsLookup,
    this.enableHttp2,
    this.maxConcurrentRequests,
    this.slowRequestThreshold,
    this.onSlowRequest,
    this.rateLimit,
    this.interceptors = const [],
    this.responseAdapter = const PlainResponseAdapter(),
  }) : baseUrl = null,
       wsUrl = null;

  /// Explicit HTTP base URL.
  final String? baseUrl;

  /// Variable name in `OmniEnvironment.variables` supplying the HTTP base URL.
  final String? baseUrlVar;

  /// Explicit WebSocket base URL.
  final String? wsUrl;

  /// Variable name in `OmniEnvironment.variables` supplying the WS base URL.
  final String? wsUrlVar;

  /// Service-specific default headers.
  final Map<String, String> headers;

  /// Overall timeout.
  final Duration? timeout;

  /// Connection timeout.
  final Duration? connectTimeout;

  /// Body upload timeout.
  final Duration? sendTimeout;

  /// Receive timeout.
  final Duration? receiveTimeout;

  /// Dedicated or shared [AuthProvider].
  final AuthProvider? auth;

  /// Lightweight external token provider when [auth] is not set.
  final FutureOr<String?> Function()? token;

  /// Default retry policy.
  final RetryPolicy? retry;

  /// Dedicated or shared [OmniCache].
  final OmniCache? cache;

  /// Dedicated or shared [CircuitBreaker].
  final CircuitBreaker? circuitBreaker;

  /// Global typed JSON decoders registered on this service client.
  final Map<Type, JsonDecoder<Object?>> decoders;

  /// Service-specific SHA-256 certificate pins.
  final List<String> pinnedSha256;

  /// Proxy bad-certificate handling when `proxy` is enabled.
  final bool allowBadProxyCertificate;

  /// Optional mTLS certificate bytes.
  final List<int>? clientCertificateBytes;

  /// Optional mTLS private key bytes.
  final List<int>? clientPrivateKeyBytes;

  /// Optional mTLS passphrase.
  final String? clientCertificatePassword;

  /// Optional DNS-over-HTTPS endpoint.
  final String? dnsOverHttps;

  /// Optional custom DNS callback.
  final DnsLookup? dnsLookup;

  /// HTTP/2 preference override.
  final bool? enableHttp2;

  /// Max concurrent in-flight calls on this service.
  final int? maxConcurrentRequests;

  /// Slow-request telemetry threshold.
  final Duration? slowRequestThreshold;

  /// Slow-request callback.
  final void Function(Uri uri, Duration elapsed)? onSlowRequest;

  /// Optional sliding-window rate limit enforced per service.
  final RateLimit? rateLimit;

  /// Additional interceptors for this service.
  final List<OmniInterceptor> interceptors;

  /// Response envelope unwrapper.
  final ResponseAdapter responseAdapter;

  /// Resolves concrete `(baseUrl, wsUrl)` given optional [env].
  ({String? baseUrl, String? wsUrl}) resolveUrls(OmniEnvironment? env) => (
    baseUrl:
        (baseUrlVar != null ? env?.variables[baseUrlVar!] : null) ?? baseUrl,
    wsUrl: (wsUrlVar != null ? env?.variables[wsUrlVar!] : null) ?? wsUrl,
  );

  /// Returns a copy with selectively updated remote/override settings.
  ServiceConfig copyWith({
    String? baseUrl,
    String? wsUrl,
    Map<String, String>? headers,
    Duration? timeout,
    List<String>? pinnedSha256,
  }) => ServiceConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    baseUrlVar: baseUrlVar,
    wsUrl: wsUrl ?? this.wsUrl,
    wsUrlVar: wsUrlVar,
    headers: headers ?? this.headers,
    timeout: timeout ?? this.timeout,
    connectTimeout: connectTimeout,
    sendTimeout: sendTimeout,
    receiveTimeout: receiveTimeout,
    auth: auth,
    token: token,
    retry: retry,
    cache: cache,
    circuitBreaker: circuitBreaker,
    decoders: decoders,
    pinnedSha256: pinnedSha256 ?? this.pinnedSha256,
    allowBadProxyCertificate: allowBadProxyCertificate,
    clientCertificateBytes: clientCertificateBytes,
    clientPrivateKeyBytes: clientPrivateKeyBytes,
    clientCertificatePassword: clientCertificatePassword,
    dnsOverHttps: dnsOverHttps,
    dnsLookup: dnsLookup,
    enableHttp2: enableHttp2,
    maxConcurrentRequests: maxConcurrentRequests,
    slowRequestThreshold: slowRequestThreshold,
    onSlowRequest: onSlowRequest,
    rateLimit: rateLimit,
    interceptors: interceptors,
    responseAdapter: responseAdapter,
  );
}

/// Declarative GraphQL query/mutation specification reusable across
/// `OmniNetwork` and `OmniApiHub`.
@immutable
final class GraphqlEndpoint<T> {
  /// Creates a GraphQL endpoint spec.
  const GraphqlEndpoint({
    this.path = '/graphql',
    required this.query,
    this.operationName,
    this.dataKey,
    this.decoder,
    this.defaultVariables = const {},
    this.headers = const {},
  });

  /// GraphQL HTTP path.
  final String path;

  /// GraphQL query or mutation document.
  final String query;

  /// Optional operation name.
  final String? operationName;

  /// Optional key under `data` to extract before calling [decoder].
  final String? dataKey;

  /// Model decoder (`fromJson`).
  final JsonDecoder<T>? decoder;

  /// Default variables merged with call-site variables.
  final Map<String, Object?> defaultVariables;

  /// Extra headers.
  final Map<String, String> headers;
}

/// Declarative WebSocket channel subscription specification.
@immutable
final class WsEndpoint<T> {
  /// Creates a typed WebSocket endpoint spec.
  const WsEndpoint({
    required this.path,
    this.event,
    this.decoder,
    this.query = const {},
  });

  /// Relative or full WS path.
  final String path;

  /// Optional default event name to subscribe to via `socket.on(event)`.
  final String? event;

  /// Typed event decoder.
  final T Function(Map<String, dynamic> json)? decoder;

  /// Default query parameters.
  final Map<String, Object?> query;
}

/// Declarative Server-Sent Events stream specification.
@immutable
final class SseEndpoint<T> {
  /// Creates an SSE stream endpoint spec.
  const SseEndpoint({
    required this.path,
    this.decoder,
    this.query = const {},
  });

  /// Relative or full SSE path.
  final String path;

  /// Optional JSON payload decoder.
  final JsonDecoder<T>? decoder;

  /// Default query parameters.
  final Map<String, Object?> query;
}

/// Declarative AI task specification wrapping a reusable prompt template and
/// structured output decoder.
@immutable
final class AiEndpoint<T> {
  /// Creates a typed AI endpoint definition.
  const AiEndpoint({
    this.model,
    this.systemPrompt,
    required this.buildPrompt,
    this.decoder,
    this.schema,
    this.options = const AiRequestOptions(),
  });

  /// Logical model alias (`'fast'`, `'smart'`) or `'provider:model'`.
  final String? model;

  /// System instructions.
  final String? systemPrompt;

  /// Function turning input args into the prompt string.
  final String Function(Map<String, Object?> input) buildPrompt;

  /// Optional JSON decoder when structured output [T] is desired.
  final JsonDecoder<T>? decoder;

  /// Optional JSON Schema enforcing structured output.
  final Map<String, Object?>? schema;

  /// Generation options.
  final AiRequestOptions options;
}

/// Result of probing a service's health endpoint via `OmniApiHub.healthCheckAll`.
@immutable
final class ServiceHealth {
  /// Creates a service health snapshot.
  const ServiceHealth({
    required this.serviceName,
    required this.isHealthy,
    this.statusCode,
    required this.latency,
    this.error,
  });

  /// Registered service key in `OmniApiHub`.
  final String serviceName;

  /// Whether the service answered with a 2xx HTTP status.
  final bool isHealthy;

  /// HTTP status code if a response arrived.
  final int? statusCode;

  /// Round-trip check latency.
  final Duration latency;

  /// Failure description if unhealthy/unreachable.
  final String? error;
}
