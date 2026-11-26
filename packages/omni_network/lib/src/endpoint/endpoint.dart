import 'package:meta/meta.dart';

import '../cache/omni_cache.dart' show CachePolicy;
import '../core/cancel_token.dart';
import '../core/decoding.dart';
import '../core/omni_request.dart';
import '../core/omni_response.dart';
import '../core/response_adapter.dart';
import '../resilience/retry_policy.dart';

/// A typed API operation: method, path template and response type.
///
/// ```dart
/// abstract final class UserApi {
///   static final byId = Endpoint.get<User>('/users/{id}',
///       decoder: User.fromJson, name: 'getUser');
///   static final list = Endpoint.getList<User>('/users',
///       decoder: User.fromJson);
///   static final create = Endpoint.post<User>('/users',
///       decoder: User.fromJson);
/// }
///
/// final user = await api.call(UserApi.byId, path: {'id': 10});
/// ```
///
/// Path parameters use `{name}` or `:name` segments; values are URL-encoded,
/// and a missing or unknown parameter is an [ArgumentError].
@immutable
final class Endpoint<T> {
  const Endpoint._(
    this.method,
    this.path,
    this._decode,
    this._decodeAsync, {
    this.name,
    this.description,
    this.query = const {},
    this.headers = const {},
    this.cachePolicy,
    this.retry,
    this.tags = const {},
  });

  /// HTTP method.
  final HttpMethod method;

  /// Path template, e.g. `/users/{id}` or `/users/:id`.
  final String path;

  /// Unique name (for registries, mocks and generated code).
  final String? name;

  /// Human description.
  final String? description;

  /// Default query parameters.
  final Map<String, Object?> query;

  /// Default headers.
  final Map<String, String> headers;

  /// Default cache policy.
  final CachePolicy? cachePolicy;

  /// Default retry policy.
  final RetryPolicy? retry;

  /// Free-form labels (e.g. `users`, `admin`).
  final Set<String> tags;

  final T Function(
    OmniRawResponse raw,
    ResponseAdapter adapter,
    JsonDecoder<E>? Function<E>()? lookup,
  )
  _decode;

  final Future<T> Function(
    OmniRawResponse raw,
    ResponseAdapter adapter,
    JsonDecoder<E>? Function<E>()? lookup,
  )
  _decodeAsync;

  static Endpoint<T> _single<T>(
    HttpMethod m,
    String path,
    JsonDecoder<T>? decoder,
    String? name,
    String? description,
    Map<String, Object?> query,
    Map<String, String> headers,
    CachePolicy? cachePolicy,
    RetryPolicy? retry,
    Set<String> tags,
  ) => Endpoint._(
    m,
    path,
    (raw, adapter, lookup) =>
        decodeBody<T>(raw, decoder ?? lookup?.call<T>(), adapter),
    (raw, adapter, lookup) =>
        decodeBodyAsync<T>(raw, decoder ?? lookup?.call<T>(), adapter),
    name: name,
    description: description,
    query: query,
    headers: headers,
    cachePolicy: cachePolicy,
    retry: retry,
    tags: tags,
  );

  /// GET returning `T`.
  static Endpoint<T> get<T>(
    String path, {
    JsonDecoder<T>? decoder,
    String? name,
    String? description,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    CachePolicy? cachePolicy,
    RetryPolicy? retry,
    Set<String> tags = const {},
  }) => _single(
    HttpMethod.get,
    path,
    decoder,
    name,
    description,
    query,
    headers,
    cachePolicy,
    retry,
    tags,
  );

  /// GET returning a JSON array decoded into `List<T>`.
  ///
  /// When [decoder] is omitted, `OmniNetwork.call` falls back to its global
  /// `decoders` registry for `T`.
  static Endpoint<List<T>> getList<T>(
    String path, {
    JsonDecoder<T>? decoder,
    String? name,
    String? description,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    CachePolicy? cachePolicy,
    RetryPolicy? retry,
    Set<String> tags = const {},
  }) => Endpoint._(
    HttpMethod.get,
    path,
    (raw, adapter, lookup) {
      final resolved = decoder ?? lookup?.call<T>();
      if (resolved == null) {
        return decodeList<T>(
          raw,
          (_) => throw ArgumentError('No decoder registered for $T'),
          adapter,
        );
      }
      return decodeList<T>(raw, resolved, adapter);
    },
    (raw, adapter, lookup) {
      final resolved = decoder ?? lookup?.call<T>();
      if (resolved == null) {
        return decodeListAsync<T>(
          raw,
          (_) => throw ArgumentError('No decoder registered for $T'),
          adapter,
        );
      }
      return decodeListAsync<T>(raw, resolved, adapter);
    },
    name: name,
    description: description,
    query: query,
    headers: headers,
    cachePolicy: cachePolicy,
    retry: retry,
    tags: tags,
  );

  /// POST returning `T`.
  static Endpoint<T> post<T>(
    String path, {
    JsonDecoder<T>? decoder,
    String? name,
    String? description,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    RetryPolicy? retry,
    Set<String> tags = const {},
  }) => _single(
    HttpMethod.post,
    path,
    decoder,
    name,
    description,
    query,
    headers,
    null,
    retry,
    tags,
  );

  /// PUT returning `T`.
  static Endpoint<T> put<T>(
    String path, {
    JsonDecoder<T>? decoder,
    String? name,
    String? description,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    RetryPolicy? retry,
    Set<String> tags = const {},
  }) => _single(
    HttpMethod.put,
    path,
    decoder,
    name,
    description,
    query,
    headers,
    null,
    retry,
    tags,
  );

  /// PATCH returning `T`.
  static Endpoint<T> patch<T>(
    String path, {
    JsonDecoder<T>? decoder,
    String? name,
    String? description,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    RetryPolicy? retry,
    Set<String> tags = const {},
  }) => _single(
    HttpMethod.patch,
    path,
    decoder,
    name,
    description,
    query,
    headers,
    null,
    retry,
    tags,
  );

  /// DELETE returning `T` (often `void`).
  static Endpoint<T> delete<T>(
    String path, {
    JsonDecoder<T>? decoder,
    String? name,
    String? description,
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    RetryPolicy? retry,
    Set<String> tags = const {},
  }) => _single(
    HttpMethod.delete,
    path,
    decoder,
    name,
    description,
    query,
    headers,
    null,
    retry,
    tags,
  );

  static final _param = RegExp(
    r'\{([A-Za-z_][A-Za-z0-9_]*)\}|(?:^|(?<=/)):([A-Za-z_][A-Za-z0-9_]*)',
  );

  /// Names of the `{params}` or `:params` in [path], in order.
  List<String> get pathParams => [
    for (final m in _param.allMatches(path)) (m[1] ?? m[2])!,
  ];

  /// [path] with [params] substituted (URL-encoded).
  String expand(Map<String, Object?> params) {
    final unknown = params.keys.toSet().difference(pathParams.toSet());
    if (unknown.isNotEmpty) {
      throw ArgumentError.value(
        unknown.join(', '),
        'path',
        'unknown path parameter(s) for $path',
      );
    }
    return path.replaceAllMapped(_param, (m) {
      final name = (m[1] ?? m[2])!;
      final v = params[name];
      if (v == null) {
        throw ArgumentError.value(
          name,
          'path',
          'missing path parameter for $path',
        );
      }
      return Uri.encodeComponent('$v');
    });
  }

  /// The request for this endpoint.
  OmniRequest request({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
    OmniCancelToken? cancelToken,
    RetryPolicy? retry,
    CachePolicy? cachePolicy,
    bool skipAuth = false,
  }) => OmniRequest(
    method,
    expand(path),
    query: {...this.query, ...query},
    headers: {...this.headers, ...headers},
    body: body,
    timeout: timeout,
    cancelToken: cancelToken,
    retry: retry ?? this.retry,
    cachePolicy: cachePolicy ?? this.cachePolicy,
    skipAuth: skipAuth,
  );

  /// Decodes a 2xx [raw] response. Internal.
  T decode(
    OmniRawResponse raw,
    ResponseAdapter adapter, {
    JsonDecoder<E>? Function<E>()? lookupDecoder,
  }) => _decode(raw, adapter, lookupDecoder);

  /// Asynchronously decodes a 2xx [raw] response (off-thread for large JSON).
  /// Internal.
  Future<T> decodeAsync(
    OmniRawResponse raw,
    ResponseAdapter adapter, {
    JsonDecoder<E>? Function<E>()? lookupDecoder,
  }) => _decodeAsync(raw, adapter, lookupDecoder);

  @override
  String toString() =>
      'Endpoint(${method.verb} $path${name == null ? '' : ' "$name"'})';
}

/// A named collection of endpoints (for tooling: mocks, inspector, docs).
final class EndpointRegistry {
  /// Creates a registry from [endpoints].
  EndpointRegistry([Iterable<Endpoint<Object?>> endpoints = const []]) {
    endpoints.forEach(register);
  }

  final Map<String, Endpoint<Object?>> _byKey = {};

  /// Adds [endpoint]. Its key is its name, or `METHOD path` when unnamed.
  /// Throws [ArgumentError] on a duplicate key or a duplicate
  /// method + path.
  void register(Endpoint<Object?> endpoint) {
    final key = keyOf(endpoint);
    if (_byKey.containsKey(key)) {
      throw ArgumentError.value(key, 'endpoint', 'already registered');
    }
    final route = '${endpoint.method.verb} ${endpoint.path}';
    for (final e in _byKey.values) {
      if ('${e.method.verb} ${e.path}' == route) {
        throw ArgumentError.value(
          route,
          'endpoint',
          'route already registered',
        );
      }
    }
    _byKey[key] = endpoint;
  }

  /// Key used for [endpoint].
  static String keyOf(Endpoint<Object?> endpoint) =>
      endpoint.name ?? '${endpoint.method.verb} ${endpoint.path}';

  /// All endpoints in registration order.
  List<Endpoint<Object?>> get all => List.unmodifiable(_byKey.values);

  /// Endpoint by key, or `null`.
  Endpoint<Object?>? operator [](String key) => _byKey[key];

  /// Endpoints carrying [tag].
  List<Endpoint<Object?>> tagged(String tag) => [
    for (final e in _byKey.values)
      if (e.tags.contains(tag)) e,
  ];

  /// The endpoint whose method and template match a concrete request
  /// [method] and [path] (e.g. `GET /users/10` → `/users/{id}` or `/users/:id`),
  /// or `null`.
  Endpoint<Object?>? match(HttpMethod method, String path) {
    final clean = path.split('?').first;
    for (final e in _byKey.values) {
      if (e.method != method) continue;
      final pattern = RegExp(
        '^${e.path.split(Endpoint._param).map(RegExp.escape).join('[^/]+')}\$',
      );
      if (pattern.hasMatch(clean)) return e;
    }
    return null;
  }
}
