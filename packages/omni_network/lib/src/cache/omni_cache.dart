import 'dart:async';
import 'dart:typed_data';

import '../core/http_date.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_request.dart';
import '../core/omni_response.dart';
import '../log/redactor.dart';
import '../transport/transport.dart';
import 'cache_store.dart';

/// How a GET request uses the cache.
enum CachePolicy {
  /// HTTP semantics (RFC 9111): fresh entries are served; stale ones with
  /// an `ETag`/`Last-Modified` are revalidated (`304` → cached body).
  standard,

  /// Serve any cached entry, fresh or stale; network only when missing.
  cacheFirst,

  /// Serve any cached entry at once and refresh it in the background when
  /// stale; network when missing.
  staleWhileRevalidate,

  /// Always ask the network (conditionally when possible); on a connection
  /// error or timeout fall back to a cached entry, even a stale one.
  networkFirst,

  /// Always ask the network (conditionally) and store the result.
  refresh,

  /// Neither read nor write the cache.
  noCache,
}

/// Where an [OmniRawResponse] came from.
enum ResponseSource {
  /// Sent over the network.
  network,

  /// Served from the cache without contacting the server.
  cache,

  /// Server answered `304 Not Modified`; the cached body was used.
  revalidated,
}

/// Response cache for GET requests. Pass to `OmniNetwork(cache:)`.
///
/// Stored: `200` GET responses without `Cache-Control: no-store` and
/// without `Vary: *`, up to [maxEntryBytes]. Freshness comes from
/// `max-age` (minus `Age`) or `Expires`; `no-cache` or no freshness info
/// means "revalidate before use" under [CachePolicy.standard].
///
/// **Authenticated responses** (request had an `Authorization` header) are
/// not cached unless [cacheAuthenticated] is `true`. Then entries are
/// partitioned by [authScope] (e.g. the user id) — or, if that is `null`, by
/// the exact token, which is allowed with [MemoryCacheStore] only.
/// Call [clear] on logout.
///
/// A successful POST/PUT/PATCH/DELETE invalidates cached entries of the
/// same URL.
final class OmniCache {
  /// Creates a cache.
  OmniCache({
    CacheStore? store,
    this.policy = CachePolicy.standard,
    this.cacheAuthenticated = false,
    this.authScope,
    this.maxEntryBytes = 2 * 1024 * 1024,
    DateTime Function()? now,
  }) : store = store ?? MemoryCacheStore(),
       _now = now ?? DateTime.now {
    if (cacheAuthenticated &&
        authScope == null &&
        this.store is! MemoryCacheStore) {
      // Without a scope, entries would be keyed by the token itself; that
      // must never be written to persistent storage.
      throw ArgumentError(
        'cacheAuthenticated with a persistent CacheStore needs authScope '
        '(e.g. the user id)',
      );
    }
  }

  /// Where entries live.
  final CacheStore store;

  /// Default policy; overridable per request with `OmniRequest(cachePolicy:)`.
  final CachePolicy policy;

  /// Whether responses to requests with `Authorization` may be cached.
  final bool cacheAuthenticated;

  /// Partition key for authenticated entries (e.g. current user id).
  final String? Function()? authScope;

  /// Larger bodies are not stored.
  final int maxEntryBytes;

  final DateTime Function() _now;

  /// Removes every entry (e.g. on logout).
  Future<void> clear() async => store.clear();

  /// Removes entries for [url] (absolute URL including query).
  Future<void> invalidate(String url) async => store.removeUrl(url);

  static Map<String, String> _directives(String? header) {
    final out = <String, String>{};
    if (header == null) return out;
    for (final part in header.split(',')) {
      final kv = part.trim().split('=');
      if (kv.first.isEmpty) continue;
      out[kv.first.toLowerCase()] = kv.length > 1
          ? kv.sublist(1).join('=').replaceAll('"', '')
          : '';
    }
    return out;
  }

  static const _redactor = Redactor();
  static const _credentialHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'x-api-key',
    'x-auth-token',
    'x-csrf-token',
    'x-xsrf-token',
  };

  static bool _isCredentialHeader(String name) {
    final lower = name.toLowerCase();
    return _credentialHeaders.contains(lower) ||
        _redactor.isSecretHeader(lower);
  }

  List<MapEntry<String, String>> _credentialEntries(TransportRequest r) {
    final out = [
      for (final e in r.headers.entries)
        if (_isCredentialHeader(e.key)) MapEntry(e.key.toLowerCase(), e.value),
    ]..sort((a, b) => a.key.compareTo(b.key));
    return out;
  }

  String? _partition(TransportRequest r) {
    final creds = _credentialEntries(r);
    if (creds.isEmpty) return '';
    if (!cacheAuthenticated) return null;
    final scope = authScope?.call();
    if (scope != null) return 'u:$scope';
    // In-memory only (enforced in the constructor): canonical header values,
    // so two users can never share an entry across Authorization/Cookie/API key.
    return 't:${creds.map((e) => '${e.key}=${e.value}').join('\n')}';
  }

  static String _url(TransportRequest r) => r.uri.toString();

  String _key(TransportRequest r, String partition) =>
      '${r.method.verb} ${_url(r)} #$partition';

  /// Runs [request] through the cache using [network] to reach the server.
  /// Internal.
  Future<OmniRawResponse> handle(
    TransportRequest request,
    CachePolicy? requested,
    Future<OmniRawResponse> Function(TransportRequest) network,
  ) async {
    var policy = requested ?? this.policy;
    final reqCc = _directives(request.headers['cache-control']);
    if (reqCc.containsKey('no-store')) policy = CachePolicy.noCache;
    if (request.method != HttpMethod.get) {
      final res = await network(request);
      if (request.method != HttpMethod.head &&
          res.statusCode >= 200 &&
          res.statusCode < 400) {
        await store.removeUrl(_url(request));
      }
      return res;
    }
    final partition = _partition(request);
    if (policy == CachePolicy.noCache || partition == null) {
      return network(request);
    }
    if (reqCc.containsKey('no-cache') && policy == CachePolicy.standard) {
      policy = CachePolicy.refresh;
    }
    final key = _key(request, partition);
    var entry = await store.get(key);
    if (entry != null && !_varyMatches(entry, request)) entry = null;
    final now = _now();

    switch (policy) {
      case CachePolicy.cacheFirst when entry != null:
        return _fromEntry(entry, ResponseSource.cache);
      case CachePolicy.staleWhileRevalidate when entry != null:
        if (!entry.isFresh(now)) {
          unawaited(
            _fetch(key, request, entry, network).then((_) {}, onError: (_) {}),
          );
        }
        return _fromEntry(entry, ResponseSource.cache);
      case CachePolicy.standard when entry != null && entry.isFresh(now):
        return _fromEntry(entry, ResponseSource.cache);
      case CachePolicy.networkFirst:
        try {
          return await _fetch(key, request, entry, network);
        } on OmniNetworkException catch (e) {
          if (entry != null &&
              (e is ConnectionFailure || e is TimeoutFailure)) {
            return _fromEntry(entry, ResponseSource.cache);
          }
          rethrow;
        }
      default:
        return _fetch(key, request, entry, network);
    }
  }

  Future<OmniRawResponse> _fetch(
    String key,
    TransportRequest request,
    CacheEntry? entry,
    Future<OmniRawResponse> Function(TransportRequest) network,
  ) async {
    var outgoing = request;
    final conditional =
        entry != null &&
        entry.hasValidators &&
        !request.headers.containsKey('if-none-match') &&
        !request.headers.containsKey('if-modified-since');
    if (conditional) {
      outgoing = request.withHeaders({
        'if-none-match': ?entry.etag,
        'if-modified-since': ?entry.lastModified,
      });
    }
    final res = await network(outgoing);
    if (res.statusCode == 304 && conditional) {
      final merged = {...entry.headers, ...res.headers}
        ..remove('content-length');
      final updated = _entry(request, 200, merged, entry.body);
      await _save(key, updated, merged);
      return _fromEntry(updated, ResponseSource.revalidated, res.duration);
    }
    if (res.statusCode == 200) {
      await _save(
        key,
        _entry(request, 200, res.headers, res.bodyBytes),
        res.headers,
      );
    }
    return res;
  }

  Future<void> _save(
    String key,
    CacheEntry entry,
    Map<String, String> headers,
  ) async {
    final cc = _directives(headers['cache-control']);
    final hasSetCookie = headers.keys.any(
      (k) => k.toLowerCase() == 'set-cookie',
    );
    final unsharedPrivate =
        cc.containsKey('private') &&
        store is! MemoryCacheStore &&
        authScope == null;
    if (cc.containsKey('no-store') ||
        hasSetCookie ||
        unsharedPrivate ||
        headers['vary']?.trim() == '*' ||
        entry.body.length > maxEntryBytes) {
      await store.remove(key);
      return;
    }
    await store.set(key, entry);
  }

  CacheEntry _entry(
    TransportRequest request,
    int status,
    Map<String, String> headers,
    List<int> body,
  ) {
    final now = _now();
    final cc = _directives(headers['cache-control']);
    var expires = now;
    if (!cc.containsKey('no-cache')) {
      final maxAge = int.tryParse(cc['max-age'] ?? '');
      final age = int.tryParse(headers['age'] ?? '') ?? 0;
      if (maxAge != null) {
        expires = now.add(Duration(seconds: maxAge - age));
      } else if (headers['expires'] case final e?) {
        final at = parseHttpDate(e);
        final date = parseHttpDate(headers['date'] ?? '');
        if (at != null) {
          // Expires is relative to the server's Date when present.
          expires = now.add(at.difference(date ?? now.toUtc()));
        }
      }
    }
    final varyNames = (headers['vary'] ?? '')
        .split(',')
        .map((v) => v.trim().toLowerCase())
        .where((v) => v.isNotEmpty && v != '*');
    return CacheEntry(
      url: _url(request),
      statusCode: status,
      headers: Map.unmodifiable(headers),
      body: body is Uint8List ? body : Uint8List.fromList(body),
      storedAt: now,
      expiresAt: expires,
      vary: {for (final n in varyNames) n: request.headers[n] ?? ''},
    );
  }

  static bool _varyMatches(CacheEntry e, TransportRequest r) =>
      e.vary.entries.every((v) => (r.headers[v.key] ?? '') == v.value);

  OmniRawResponse _fromEntry(
    CacheEntry e,
    ResponseSource source, [
    Duration duration = Duration.zero,
  ]) => OmniRawResponse(
    statusCode: e.statusCode,
    headers: e.headers,
    bodyBytes: e.body,
    duration: duration,
    source: source,
  );
}
