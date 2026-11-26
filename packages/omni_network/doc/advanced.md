# OmniNetwork — full guide

The [README](../README.md) covers the everyday path. This guide has every
option, with the import each API needs:

| Import | What it gives you |
|---|---|
| `package:omni_network/omni_network.dart` | The default: client, verbs, GraphQL, metrics, errors, `OmniAuth`, `ApiKeyAuth`, `BasicAuth`, `HmacSignerAuth`, retry, cache, pagination, request state |
| `package:omni_network/advanced.dart` | Everything above, plus `OmniNetworkAdvanced`, transports, `FileCacheStore`, `FileQueueStore`, `OfflineQueue`, `CircuitBreaker`, `PrettyLogSink`, `MultiLogSink`, `Redactor`, `DnsOverHttpsResolver`, streaming, cURL, `EndpointRegistry`, adapters and `BearerAuth` |
| `package:omni_network/testing.dart` | `OmniMock`, `MockResponse`, `MockTransport`, `RecordingTransport`, `RecordedExchange` |

## Client configuration & Dio transport power

```dart
final api = OmniNetwork(
  baseUrl: 'https://api.example.com/v1',
  // Stage-level timeouts (in addition to overall `timeout`):
  connectTimeout: const Duration(seconds: 10),
  sendTimeout: const Duration(seconds: 20),
  receiveTimeout: const Duration(seconds: 20),
  // Single-line proxy, SSL pinning, HTTP/2 & mTLS (IO platforms):
  proxy: '192.168.0.105:8888',         // blocked in release unless allowProxyInRelease: true
  pinnedSha256: ['sha256/...'],        // leaf cert or X.509 SPKI SHA-256 (64 hex or base64)
  enableHttp2: true,
  clientCertificateBytes: certPem,
  clientPrivateKeyBytes: keyPem,
  clientCertificatePassword: 'secret', // optional
  // Custom DNS or DNS-over-HTTPS (RFC 8484):
  dnsOverHttps: DnsOverHttpsResolver.cloudflareEndpoint,
  dnsLookup: (host) async => ['127.0.0.1'], // optional custom resolver
  // Concurrency cap, slow-request hook & global decoders:
  maxConcurrentRequests: 8,
  slowRequestThreshold: const Duration(seconds: 2),
  onSlowRequest: (uri, elapsed) => telemetry.warnSlow(uri, elapsed),
  decoders: {User: User.fromJson},
);
```

Wrap an existing configured `Dio` instance incrementally without rewriting
interceptors first:

```dart
final api = OmniNetwork.fromDio(dio, closeDio: false, enableLogging: true);
```

Update default headers on an active client at any time:

```dart
api.setHeader('Accept-Language', 'bn');
api.removeHeader('X-Legacy');
api.clearHeaders();
```

## Requests, typed responses, GraphQL & forms

```dart
final user  = await api.get<User>('/users/10', decoder: User.fromJson);
// Uses global `decoders[User]` when decoder: is omitted:
final user2 = await api.get<User>('/users/10');
final users = await api.getList<User>('/users', decoder: User.fromJson,
    query: {'page': 2, 'tag': ['a', 'b']});          // ?page=2&tag=a&tag=b
final made  = await api.post<User>('/users', body: {'name': 'Ana'},
    decoder: User.fromJson);
await api.post<void>('/batch', body: payload, compress: true); // gzip request body (IO)
await api.postForm<void>('/oauth/token', fields: {'grant_type': 'client_credentials'});
await api.delete<void>('/users/10');

// Without a decoder: String gives the text, int/Map/List are cast from
// JSON, and void or a nullable type accepts an empty body.
final count = await api.get<int>('/users/count');

// Every verb takes the same per-call options.
final me = await api.get<User>('/me',
    decoder: User.fromJson,
    query: {'expand': 'roles'},
    headers: {'X-Trace': traceId},
    timeout: const Duration(seconds: 5),
    cancelToken: token,
    retry: RetryPolicy.none,          // or a policy just for this call
    cache: CachePolicy.networkFirst,  // GET only, needs `cache:` on the client
    auth: false);                     // no token (login, public endpoints)

// The full response (status, headers, duration, source):
final res = await api.getResponse<User>('/users/10', decoder: User.fromJson);
print('${res.statusCode} ${res.headers['etag']} ${res.duration} ${res.source}');
// Also: postResponse, putResponse, patchResponse, deleteResponse, postFormResponse.
```

### GraphQL

```dart
final viewer = await api.graphql<User>(
  '/graphql',
  query: r'query Viewer($withEmail: Boolean!) { viewer { id name } }',
  variables: const {'withEmail': true},
  operationName: 'Viewer',
  dataKey: 'viewer',
  decoder: User.fromJson,
);
// Or full response: api.graphqlResponse<User>(...)
```

`graphql` automatically unwraps `data` (and optional `dataKey`), treats `errors: []`
as valid, and throws `DecodeFailure` with server error messages if `errors` is
non-empty or `"data"`/`dataKey` is missing.

JSON envelopes such as `{"data": ..., "meta": ...}` for REST calls are unwrapped
with `responseAdapter: const EnvelopeResponseAdapter(dataKey: 'data')` (or per-call
`adapter:`).

## Errors

Every failure is a subtype of the sealed `OmniNetworkException`:
`HttpFailure` (non-2xx; the full `response` is kept), `DecodeFailure`,
`TimeoutFailure` (includes `stage`: `overall`, `idle`, `connect`, `send`, `receive`),
`ConnectionFailure` (includes `reason`: `noInternet`, `dnsFailed`, `sslMismatch`,
`connectionRefused`, `connectionReset`, `unknown`), `CancelledFailure`, `ClosedFailure`,
`AuthFailure`, `CircuitOpenFailure` and `RequestFailure`. Error messages
never contain bodies, headers, query strings or URL user info.

Quick checks on any failure:

```dart
try {
  await api.get<User>('/me', decoder: User.fromJson);
} on OmniNetworkException catch (e) {
  if (e.isOffline) showOfflineBanner();          // connection error or timeout
  else if (e.isUnauthorized) goToLogin();        // 401 or refresh failed
  else if (e.statusCode == 404) showNotFound();  // null when no response
  else showError(e.message);                     // safe: no secrets
}
```

`isTimeout` and `isCancelled` are also available. Or skip try/catch:

```dart
switch (await api.get<User>('/me', decoder: User.fromJson).asResult()) {
  case Ok(:final value): show(value);
  case Err(:final error): showError(error);
}
```

## Logging, metrics and redaction

One `true`/`false` switch prints every call in the terminal while you
develop, and can be toggled dynamically at runtime:

```dart
final api = OmniNetwork(baseUrl: url, enableLogging: true);

// Toggle live at runtime (e.g. from a developer settings switch):
api.enableLogging = true;
api.logResponse = true;    // false skips large response bodies while keeping request lines
api.logColors = null;      // true, false, or null (auto-detect)

// Stream every redacted record anywhere in your app:
final sub = api.logStream.listen((record) => analytics.breadcrumb(record.method));

// Runtime telemetry snapshot:
final m = api.metrics;
print('${m.totalRequests} reqs, hit rate: ${m.cacheHitRate}, avg: ${m.averageLatency}');
api.resetMetrics();
```

Terminal blocks use [`logger`](https://pub.dev/packages/logger) by default:

```
┌───────────────────────────────────────────────────────────
│ 2026-11-17 15:35:30.519
├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
│ 💡 GET  https://api.example.com/v1/users/10
│ 💡 🔑 token refreshed
│ 💡 ✔ 200 OK · 142 ms · 1.2 KB
│ 💡 {
│ 💡   "id": 10,
│ 💡   "name": "Ana",
│ 💡   "access_token": "***"
│ 💡 }
└───────────────────────────────────────────────────────────
```

To fan out logs to both terminal and `OmniInspector` simultaneously, use
`MultiLogSink([PrettyLogSink(), inspector])` (both from `advanced.dart`).

- **Whole bodies.** Nothing is cut (`maxLines: null`): every line (500–1000+ lines)
  is printed. A line longer than `maxLineLength` (160) continues on the next line
  after `↪`. Only binary bodies and unparseable JSON are summarised by size.
- **Levels & colours.** 💡 info (green, syntax-coloured JSON) for 2xx/3xx; ⚠️
  warning (red) for 4xx; ⛔ error (red) for 5xx and failures. Automatic on Android
  & colour terminals, plain on iOS.
- **Secrets.** Always `***`: auth and cookie headers, token, password and
  API-key fields, query values and URL user info (`redactor: Redactor(extraKeys: {...})`).
- **Release builds.** Logging is off in release builds unless `logInRelease: true`.

```dart
OmniNetwork(
  baseUrl: url,
  enableLogging: true,
  logOptions: const LogOptions(
    headers: true,       // default false
    requestBody: true,   // default true
    responseBody: true,  // default true
    maxLines: null,      // default null = every line; a number cuts with "… N more lines"
    maxLineLength: 160,  // longer lines wrap onto the next line after "↪"
    colors: null,        // null = auto (Android and colour terminals: on; iOS: off)
  ),
);
```

## Auth and interceptors

Every client has a built-in token manager, `api.auth`:

```dart
final api = OmniNetwork(
  baseUrl: url,
  auth: OmniAuth(
    refresh: (tokens, api) async {
      final r = await api.post<Map<String, dynamic>>('/auth/refresh',
          body: {'refresh_token': tokens.refresh});
      return Tokens(access: r['access_token'], refresh: r['refresh_token'],
          expiresIn: Duration(seconds: r['expires_in']));
    },
    onLogout: () => router.go('/login'),
  ),
);

// After login (or directly from a JWT `exp` claim):
await api.auth.login(Tokens.fromJwt(jwtAccess, refresh: refreshToken));

api.auth.isLoggedIn;      // true
api.auth.changes;         // Stream<AuthState>, e.g. to redirect in the router
await api.auth.logout();  // clears tokens and cache, calls onLogout
```

Built-in `AuthProvider` alternatives when not using Bearer/OAuth refresh:

```dart
// Header or query API key (static or dynamic async callback):
OmniNetwork(baseUrl: url, auth: ApiKeyAuth('my-key', inQuery: true, queryParam: 'api_key'));
// HTTP Basic Auth:
OmniNetwork(baseUrl: url, auth: BasicAuth(username: 'alice', password: 'pw'));
// HMAC-SHA256 request signing (sends X-Timestamp & X-Signature):
OmniNetwork(baseUrl: url, auth: HmacSignerAuth(secret: 'shared-secret', prefix: 'sha256='));
```

Interceptors support subclasses or concise inline callbacks:

```dart
OmniNetwork(
  baseUrl: url,
  interceptors: [
    OmniInterceptor.inline(
      onRequest: (r) => r.withHeader('X-App', '1.4.0'),
      onError: (r, err) => crashReporter.record(err),
    ),
  ],
);
```

For custom low-level auth engines, `BearerAuth` is in `advanced.dart`.

## Retry and circuit breaker

```dart
OmniNetwork(
  baseUrl: url,
  retry: const RetryPolicy(maxAttempts: 3),   // off by default
  circuitBreaker: CircuitBreaker(failureThreshold: 5),
);
```

- **Methods.** Only `GET` and `HEAD` are retried. Add `PUT`/`DELETE` through
  `methods:`. `POST`/`PATCH` are retried only when the request carries an
  `Idempotency-Key` header and you set `retryWithIdempotencyKey: true`.
- **What is retried.** Status 408, 429 and 5xx gateway errors, timeouts and
  connection errors. The delay grows exponentially with jitter, and honours
  `Retry-After`.
- **Circuit breaker.** A host that keeps failing fails fast with
  `CircuitOpenFailure`.

## Cancellation

```dart
final token = OmniCancelToken();
api.get<User>('/slow', decoder: User.fromJson, cancelToken: token);
token.cancel();                 // fails with CancelledFailure

final screen = appToken.child(); // cancelling the parent cancels children
api.cancelAll();                 // cancels everything, client stays usable
await api.close();               // cancels everything, client closed
```

## Upload and download

```dart
// From memory or streamed directly from disk (IO only):
await api.upload<void>('/avatar',
    fields: {'album': 'me'},
    files: [await UploadFile.fromFile('file', '/tmp/me.png')],
    onProgress: (sent, total) {});

// Download with optional SHA-256 verification:
final bytes = await api.downloadBytes(
  '/report.pdf',
  expectedSha256: 'b26d48a5...',
  onProgress: (got, total) {},
);

// IO platforms only (check OmniNetwork.supportsFileDownload):
await api.downloadToFile(
  '/big.zip',
  '/tmp/big.zip',
  resume: true,
  expectedSha256: 'b26d48a5...',
);
```

- **Resumable downloads.** Writes to `<file>.part` and saves `ETag`/`Last-Modified`
  in `<file>.part.meta`. When `resume: true`, `OmniNetwork` sends `Range` and
  `If-Range`; if the server file changed (`200 OK`), it restarts cleanly from byte 0.
- **Integrity check.** `expectedSha256` validates the final payload before commit
  and throws `DecodeFailure` on mismatch.
- **Timeouts.** Transfers have no overall deadline unless `timeout:` is set,
  relying on `idleTimeout` to detect stalled streams.

## Pagination

```dart
final pager = api.paginate<User>('/users',
    decoder: User.fromJson, strategy: const PagePagination(pageSize: 20));
pager.changes.listen((_) => updateUi());
await pager.next();
if (pager.hasMore) await pager.next();
pager.items;
await pager.refresh();
await pager.close();
```

Four strategies: `PagePagination`, `OffsetPagination`,
`CursorPagination(nextCursorKey: 'meta.next')` and `LinkHeaderPagination` (same-origin).
In Flutter, use `OmniPagedListView<T>` from `omni_network_flutter` to bind an
`OmniPager` directly to an infinite-scroll `RefreshIndicator` list.

## Cache and request de-duplication

```dart
// In-memory by default, or bounded persistent disk storage via FileCacheStore (IO):
OmniNetwork(
  baseUrl: url,
  cache: OmniCache(
    store: FileCacheStore(directory: '/path/to/cache', maxEntries: 200),
  ),
);
api.get<User>('/me', decoder: User.fromJson);
api.get<List<dynamic>>('/feed', cache: CachePolicy.staleWhileRevalidate);

await api.invalidateCache('/feed');
await api.clearCache();
```

- **Standard policy.** Follows RFC 9111: `max-age`, `Age`, `Expires`, `no-store`,
  `no-cache`, `Vary`, and conditional `ETag`/`Last-Modified` (`304`).
- **Other policies.** `cacheFirst`, `staleWhileRevalidate`, `networkFirst`,
  `refresh`, `noCache`.
- **Auth & invalidation.** Authenticated responses require `cacheAuthenticated: true`
  + `authScope:`. Successful mutating verbs invalidate matching URLs.
- **De-duplication.** Identical concurrent GETs share one network call
  (`deduplicate: true`).

## Request state for UIs

```dart
final me = api.watch<User>('/me', decoder: User.fromJson);
me.stream.listen((state) => switch (state) {
  RequestIdle() || RequestLoading(previous: null) => showSpinner(),
  RequestLoading(:final previous?) => showUser(previous, refreshing: true),
  RequestSuccess(:final data) => showUser(data),
  RequestEmpty() => showEmpty(),
  RequestError(:final error) => showError(error),
});
await me.refresh();
await me.close();
```

In Flutter apps, `OmniRequestBuilder<T>` from `omni_network_flutter` wraps
`RequestController` directly with loading, empty, refresh and retry states.

## Offline queue

Needs `advanced.dart`. Use `FileQueueStore` for persistent atomic FIFO disk
storage across restarts (or Web stub no-op):

```dart
final queue = OfflineQueue(
  client: api,
  store: FileQueueStore(directory: '/path/to/queue'),
);
final result = await queue.sendOrQueue(
    const OmniRequest.post('/notes', body: {'text': 'hi'}));
queue.attach(connectivityStream);                 // Stream<bool>, flushes when online
```

- **Explicit & safe.** Only `enqueue`/`sendOrQueue` write to the queue; `PUT`,
  `PATCH`, `DELETE` require `allowDestructive: true`; `Authorization`/`Cookie`
  headers are never written to disk; every item preserves a stable `Idempotency-Key`.

## Endpoints and cURL

```dart
abstract final class UserApi {
  // Supports both {id} and :id path parameters plus default query/headers:
  static final byId = Endpoint.get<User>('/users/:id', decoder: User.fromJson);
}
final u = await api.call(UserApi.byId, path: {'id': 10}, query: {'expand': 'roles'});

// advanced.dart: low-level calls and cURL.
final raw = await api.sendRaw(const OmniRequest.get('/health'));
print(api.toCurl(const OmniRequest.get('/users'))); // secrets redacted
final imported = parseCurl(copiedFromBrowser).request;
```

## Testing, recording and replay

Needs `testing.dart`.

```dart
final mock = OmniMock(basePath: '/v1')
  ..get('/users/{id}', (r) => MockResponse.json({'id': r.pathParams['id']}))
  ..get('/feed', OmniMock.sequence([
      const MockResponse.offline(),
      MockResponse.json([]),
    ]))
  ..scenario('down', (s) => s.any((_) => const MockResponse.status(503)));
final api = OmniNetwork(baseUrl: 'https://api.test/v1', transport: mock);
```

Record real redacted HTTP exchanges and replay them offline:

```dart
final recorder = RecordingTransport(DioTransport());
// ... run requests against api ...
final jsonFixtures = recorder.toJson();

final offlineApi = OmniNetwork(
  baseUrl: 'https://api.test/v1',
  transport: RecordingTransport.replayJson(jsonFixtures),
);
```

## Safe defaults

| Topic | Default |
|---|---|
| Logging | off; redaction always on; toggleable live via `enableLogging` / `logResponse` / `logColors` |
| Proxy | ignored in release unless `allowProxyInRelease: true` |
| Retry | off; when on, GET/HEAD only (POST/PATCH need `Idempotency-Key` + opt-in) |
| Offline queue | explicit only; destructive requests need opt-in |
| Cache | off; authenticated responses not cached |
| Error messages | no bodies, headers, query strings or URL user info |
| Link pagination | same origin only |
| Redirects | followed safely; credentials dropped cross-origin; no HTTPS → HTTP |
| Large JSON (≥ 256 KB) | parsed off the main isolate on IO platforms |

## Platforms

| | Android | iOS | macOS | Windows | Linux | Web |
|---|---|---|---|---|---|---|
| Core HTTP, auth, GraphQL, cache, metrics | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅² |
| Upload/download progress | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `downloadToFile` / resume / `FileCacheStore` / `FileQueueStore` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `proxy` / `pinnedSha256` / mTLS / DoH / `compress` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌³ |

1. macOS apps need the `com.apple.security.network.client` entitlement.
2. On the Web, the server must send CORS headers.
3. On Web, browsers manage DNS, TLS certificates, proxy settings, and `Content-Encoding`.

## Development

```sh
dart analyze
flutter test
```
