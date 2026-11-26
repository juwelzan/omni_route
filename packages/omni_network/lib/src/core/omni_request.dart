import 'package:meta/meta.dart';

import '../cache/omni_cache.dart' show CachePolicy;
import '../resilience/retry_policy.dart';
import 'cancel_token.dart';

/// HTTP methods supported by [OmniRequest].
enum HttpMethod {
  /// GET
  get('GET'),

  /// POST
  post('POST'),

  /// PUT
  put('PUT'),

  /// PATCH
  patch('PATCH'),

  /// DELETE
  delete('DELETE'),

  /// HEAD
  head('HEAD');

  const HttpMethod(this.verb);

  /// Wire name, e.g. `GET`.
  final String verb;
}

/// An immutable description of one HTTP request.
///
/// [path] is resolved against the client's base URL unless it is absolute.
/// [body] may be `null`, a `String`, a `List<int>` (raw bytes), or a JSON
/// value (`Map`/`List`/`num`/`bool`) which is encoded as JSON.
@immutable
final class OmniRequest {
  /// Creates a request.
  const OmniRequest(
    this.method,
    this.path, {
    this.query = const {},
    this.headers = const {},
    this.body,
    this.compress = false,
    this.timeout,
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
    this.skipAuth = false,
    this.cancelToken,
    this.retry,
    this.cachePolicy,
  });

  /// GET request.
  const OmniRequest.get(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool skipAuth = false,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cachePolicy,
  }) : this(
         HttpMethod.get,
         path,
         query: query,
         headers: headers,
         timeout: timeout,
         connectTimeout: connectTimeout,
         sendTimeout: sendTimeout,
         receiveTimeout: receiveTimeout,
         skipAuth: skipAuth,
         cancelToken: cancelToken,
         retry: retry,
         cachePolicy: cachePolicy,
       );

  /// POST request.
  const OmniRequest.post(
    String path, {
    Object? body,
    bool compress = false,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool skipAuth = false,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cachePolicy,
  }) : this(
         HttpMethod.post,
         path,
         body: body,
         compress: compress,
         query: query,
         headers: headers,
         timeout: timeout,
         connectTimeout: connectTimeout,
         sendTimeout: sendTimeout,
         receiveTimeout: receiveTimeout,
         skipAuth: skipAuth,
         cancelToken: cancelToken,
         retry: retry,
         cachePolicy: cachePolicy,
       );

  /// PUT request.
  const OmniRequest.put(
    String path, {
    Object? body,
    bool compress = false,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool skipAuth = false,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cachePolicy,
  }) : this(
         HttpMethod.put,
         path,
         body: body,
         compress: compress,
         query: query,
         headers: headers,
         timeout: timeout,
         connectTimeout: connectTimeout,
         sendTimeout: sendTimeout,
         receiveTimeout: receiveTimeout,
         skipAuth: skipAuth,
         cancelToken: cancelToken,
         retry: retry,
         cachePolicy: cachePolicy,
       );

  /// PATCH request.
  const OmniRequest.patch(
    String path, {
    Object? body,
    bool compress = false,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool skipAuth = false,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cachePolicy,
  }) : this(
         HttpMethod.patch,
         path,
         body: body,
         compress: compress,
         query: query,
         headers: headers,
         timeout: timeout,
         connectTimeout: connectTimeout,
         sendTimeout: sendTimeout,
         receiveTimeout: receiveTimeout,
         skipAuth: skipAuth,
         cancelToken: cancelToken,
         retry: retry,
         cachePolicy: cachePolicy,
       );

  /// DELETE request.
  const OmniRequest.delete(
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool skipAuth = false,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cachePolicy,
  }) : this(
         HttpMethod.delete,
         path,
         body: body,
         query: query,
         headers: headers,
         timeout: timeout,
         connectTimeout: connectTimeout,
         sendTimeout: sendTimeout,
         receiveTimeout: receiveTimeout,
         skipAuth: skipAuth,
         cancelToken: cancelToken,
         retry: retry,
         cachePolicy: cachePolicy,
       );

  /// HEAD request.
  const OmniRequest.head(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Duration? timeout,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool skipAuth = false,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cachePolicy,
  }) : this(
         HttpMethod.head,
         path,
         query: query,
         headers: headers,
         timeout: timeout,
         connectTimeout: connectTimeout,
         sendTimeout: sendTimeout,
         receiveTimeout: receiveTimeout,
         skipAuth: skipAuth,
         cancelToken: cancelToken,
         retry: retry,
         cachePolicy: cachePolicy,
       );

  /// HTTP method.
  final HttpMethod method;

  /// Relative path (joined to the base URL) or absolute `http(s)` URL.
  final String path;

  /// Query parameters. `null` values are dropped; `Iterable` values become
  /// repeated keys (`?id=1&id=2`); other values use `toString()`.
  final Map<String, Object?> query;

  /// Headers; override the client's default headers (case-insensitive).
  final Map<String, String> headers;

  /// Request body, see class docs.
  final Object? body;

  /// Whether to gzip-compress encoded request bodies on IO platforms (`post`,
  /// `put`, `patch`) and attach `Content-Encoding: gzip`.
  final bool compress;

  /// Overall deadline for this request; overrides the client's timeout.
  final Duration? timeout;

  /// Connection establishment timeout override for this request.
  final Duration? connectTimeout;

  /// Request body send timeout override for this request.
  final Duration? sendTimeout;

  /// Response receive timeout override for this request.
  final Duration? receiveTimeout;

  /// When `true`, the client's auth (e.g. `BearerAuth`) neither adds a
  /// token nor refreshes on 401 for this request. Requests made from inside
  /// a refresh callback skip auth automatically.
  final bool skipAuth;

  /// Cancels this request when cancelled, see [OmniCancelToken].
  final OmniCancelToken? cancelToken;

  /// Retry policy for this request; overrides the client's. Use
  /// [RetryPolicy.none] to disable retries for one call.
  final RetryPolicy? retry;

  /// Cache policy for this GET; overrides the client cache's default.
  final CachePolicy? cachePolicy;

  /// Copy with the given fields replaced.
  OmniRequest copyWith({
    HttpMethod? method,
    String? path,
    Map<String, Object?>? query,
    Map<String, String>? headers,
    Object? body = _unset,
    bool? compress,
    Duration? timeout,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? skipAuth,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cachePolicy,
  }) => OmniRequest(
    method ?? this.method,
    path ?? this.path,
    query: query ?? this.query,
    headers: headers ?? this.headers,
    body: identical(body, _unset) ? this.body : body,
    compress: compress ?? this.compress,
    timeout: timeout ?? this.timeout,
    connectTimeout: connectTimeout ?? this.connectTimeout,
    sendTimeout: sendTimeout ?? this.sendTimeout,
    receiveTimeout: receiveTimeout ?? this.receiveTimeout,
    skipAuth: skipAuth ?? this.skipAuth,
    cancelToken: cancelToken ?? this.cancelToken,
    retry: retry ?? this.retry,
    cachePolicy: cachePolicy ?? this.cachePolicy,
  );

  /// Copy with header [name] set to [value] (replacing any existing header
  /// of that name, case-insensitively).
  OmniRequest withHeader(String name, String value) {
    final lower = name.toLowerCase();
    return copyWith(
      headers: {
        for (final e in headers.entries)
          if (e.key.toLowerCase() != lower) e.key: e.value,
        name: value,
      },
    );
  }

  /// Value of header [name] (case-insensitive), or `null`.
  String? header(String name) {
    final lower = name.toLowerCase();
    for (final e in headers.entries) {
      if (e.key.toLowerCase() == lower) return e.value;
    }
    return null;
  }

  @override
  String toString() => 'OmniRequest(${method.verb} $path)';
}

const Object _unset = Object();
