## Unreleased

- **Auth providers & JWT helper**: Added `Tokens.fromJwt` and
  `Tokens.jwtExpiration` (plus `BearerAuth.current` loading restored storage
  tokens before checking `isExpiring`), along with built-in `ApiKeyAuth`
  (header or query), `BasicAuth`, and `HmacSignerAuth`.
- **Dio transport enhancements**: One-line client configuration for `proxy`
  (with `allowProxyInRelease` / `allowBadProxyCertificate`), `pinnedSha256`
  (leaf and X.509 SPKI SHA-256 verification), stage timeouts
  (`connectTimeout`, `sendTimeout`, `receiveTimeout` with `TimeoutStage`),
  classified `ConnectionFailure.reason` (`ConnectionReason`), wire-level
  `ProgressReportingTransport`, `enableHttp2`, `OmniNetwork.fromDio`,
  mTLS (`clientCertificateBytes`, `clientPrivateKeyBytes`,
  `clientCertificatePassword`), `dnsOverHttps` (`DnsOverHttpsResolver`),
  and custom `dnsLookup`.
- **DX, persistence & GraphQL**: Added runtime header helpers (`setHeader`,
  `removeHeader`, `clearHeaders`), `OmniInterceptor.inline`, global `decoders`,
  `postForm` / `postFormResponse`, `UploadFile.fromFile`, `FileCacheStore` +
  `clearCache` / `invalidateCache`, `FileQueueStore` for persistent disk
  queues, `maxConcurrentRequests`, `compress: true` gzip request bodies (IO),
  `Endpoint` `:param` support & call overrides, `OmniNetwork.graphql` /
  `graphqlResponse`, `If-Range` `.part.meta` validator persistence +
  `expectedSha256` download verification, and `OmniPager.changes`.
- **Observability & testing**: Added runtime `enableLogging`, `logResponse`,
  and `logColors` setters, `logStream`, `MultiLogSink`, `OmniNetwork.metrics` /
  `resetMetrics()`, `slowRequestThreshold` / `onSlowRequest`, and
  `RecordingTransport` / `RecordedExchange` in `testing.dart`.
- **Whole-body logging fixes**: Logs print whole responses without truncation
  (`maxLines: null`), wrap long lines cleanly after `↪`, use green/red syntax
  colours automatically on Android/colour terminals, treat empty `gzip` inputs
  safely, accept both `sha256/` and `sha256:` prefixes, and avoid microtask
  close races via `unawaited(_logController.close())`.

## 0.1.1

- `enableLogging: true` now logs through the `logger` package (new
  dependency `logger: ^2.8.0`), in the same format as OmniRoute's logs: a
  framed block per call with time and time since start, and a level emoji
  per line — 💡 success, ⚠️ 4xx, ⛔ 5xx or no response. Content is
  unchanged (method, URL, notes, status, time, size, pretty JSON) and still
  redacted.
- New `PrettyLogSink(logger:)` to send the blocks to your own `Logger`.
  `PrettyLogSink(printer:)` keeps the classic self-framed text block.
- Long JSON responses are indented even when the log cut them off (bodies
  over 16,000 characters used to print as one huge line); the cut is shown
  on its own line (`… truncated (N chars in total)`).
- New `LogOptions(maxLineLength:)` (default 120): longer body lines, such as
  long HTML or base64 values, end in `…` (never inside an emoji). Also keeps
  lines under the iOS console's per-line limit.
- Fix: cancelling `downloadToFile` now waits until the `.part` file is
  closed before throwing `CancelledFailure`, so a `resume: true` right
  after starts from the real length.

## 0.1.0

First tagged release (`omni_network-v0.1.0`); no API changes from 0.1.0-dev.

- Part of the `omni_route` repository's pub workspace
  (`resolution: workspace`); one `flutter pub get` at the root resolves it.
- Added `repository`, `homepage` and `issue_tracker` to `pubspec.yaml`.
- Releases are tagged `omni_network-vX.Y.Z`.
- `environment` stays `sdk: ^3.12.0`: the code uses private named
  parameters, which need Dart 3.12.
- Dev dependency `test` relaxed to `^1.25.0` so it resolves together with
  the Flutter SDK's pinned `test_api`.

## 0.1.0-dev

- Step 1: `OmniNetwork` client with `send(OmniRequest)`; GET/POST/PUT/PATCH/
  DELETE/HEAD; base URL + path + query resolution; default and per-request
  headers; overall timeout; `close()` cancels in-flight requests.
- `Transport` interface with `DioTransport` (default) and `MockTransport`.
- `OmniNetworkException` (sealed): timeout, connection, cancelled, closed.
- Step 2: typed calls `get/getList/post/put/patch/delete/head` and
  `send<T>`/`sendList<T>` returning `OmniResponse<T>`; decoders are plain
  functions (`User.fromJson`), no code generation. The raw call is now
  `sendRaw` (returns every status).
- `HttpFailure` (non-2xx, keeps the response, never prints the body) and
  `DecodeFailure` (invalid JSON, wrong shape, decoder threw; body never echoed).
- `ResponseAdapter`: `PlainResponseAdapter` (default) and
  `EnvelopeResponseAdapter(dataKey:, errorKey:)`, per client or per call.
- `Result<T>` (`Ok`/`Err`) via `future.asResult()`; only
  `OmniNetworkException`s are captured.
- Step 3: logging with one switch, `OmniNetwork(enableLogging: true)`
  (default `false`: nothing is formatted, the sink is never called).
  `LogSink` interface (default `PrintLogSink`), structured
  `NetworkLogRecord`s (request/response/error, correlation id, duration).
- `Redactor` (always on, extendable via `extraHeaders`/`extraKeys`): masks
  auth/cookie/API-key headers, secret query values and JSON/form body keys
  (recursively), strips URL user info; binary/multipart/unknown bodies are
  summarised by size; bodies truncated at 2000 chars; `logBodies: false`
  omits them. A throwing sink never breaks a request.
- Step 4: `OmniInterceptor` (onRequest in order; onResponse/onError in
  reverse; transport-independent). `OmniRequest.copyWith/withHeader/header`
  and `skipAuth`.
- `BearerAuth(token:, refresh:, onRefreshFailed:)`: single-flight refresh
  (N concurrent 401s → one refresh, each request replayed once, no loops);
  requests started during a refresh wait for it; requests made inside the
  refresh callback skip auth automatically; refresh failure/throw/timeout →
  callback once and `AuthFailure` for every waiter; later 401s for the same
  stale token fail without refreshing again.
- Step 5: `OmniCancelToken` (`cancelToken:` on every call; shared tokens,
  no listener leaks). `upload<T>` with `MultipartBody`/`UploadFile`
  (bytes or re-openable stream, exact `content-length`, send progress,
  replayable after token refresh). `downloadBytes` and `downloadToFile`
  (IO only; `.part` file renamed on success, `resume:` via `Range`/206,
  restart on 200) with receive progress. Transfers have no overall deadline
  by default but fail after `idleTimeout` without progress.
- `Transport.sendStreamed` + `StreamedResponse` (Dio and Mock implement it).
- Logs summarise streamed/multipart bodies by size only.
- Step 6: `RetryPolicy` (client `retry:` or per request `OmniRequest(retry:)`,
  `RetryPolicy.none`): GET/HEAD only by default; PUT/DELETE opt-in via
  `methods`; POST/PATCH only with an `Idempotency-Key` header **and**
  `retryWithIdempotencyKey: true`. Retries 408/429/5xx-gateway statuses,
  timeouts and connection errors; exponential backoff with cap and 50–100 %
  jitter; honours `Retry-After` (seconds or HTTP date) and does not wait
  beyond `maxRetryAfter`. Backoff waits are cancellable (token, `close`,
  `cancelAll`). Each attempt is logged. Transfers are not auto-retried.
- `CircuitBreaker` per host (`failureThreshold`, `openDuration`,
  `halfOpenTrials`), `CircuitOpenFailure`, `stateOf(host)`.
- `OmniNetwork.cancelAll()` (also requests waiting for a token refresh or a
  retry) and `OmniCancelToken.child()`.
- Fix: `OmniRequest.copyWith`/`withHeader` dropped `cancelToken`, so
  cancelling did nothing for requests passing through `BearerAuth` or a
  header-adding interceptor (Step 5 regression; test added).
- Step 7: `api.paginate<T>()` → `OmniPager<T>` (`next`, `items`,
  `hasMore`, `isLoading`, `refresh`, `reset`, `close`, `lastError`).
  Concurrent `next()` calls share one request; a failed page keeps the state
  so `next()` retries it; `refresh`/`reset` discard stale in-flight pages;
  repeating cursors and `maxPages` stop runaway paging.
- Strategies: `PagePagination` (short page / empty / `totalPagesKey` /
  `hasMoreKey`), `OffsetPagination` (`totalKey`), `CursorPagination`
  (`nextCursorKey` JSON path), `LinkHeaderPagination` (RFC 8288; refuses
  next links to another origin so auth headers never leave the API host).
  `itemsKey` JSON path (`data`, `result.items`) keeps metadata visible.
- Step 8: `OmniCache` for GET (`OmniNetwork(cache:)`, per request
  `OmniRequest(cachePolicy:)`): `standard` (RFC 9111 freshness from
  `max-age`/`Age`/`Expires`+`Date`, `no-store`, `no-cache`, `Vary`,
  conditional `If-None-Match`/`If-Modified-Since`, `304` → cached body),
  `cacheFirst`, `staleWhileRevalidate` (background refresh, errors
  swallowed), `networkFirst` (offline fallback on connection errors and
  timeouts only), `refresh`, `noCache`. Request `Cache-Control` honoured.
  Successful unsafe requests invalidate the URL. Authenticated responses are
  never cached unless `cacheAuthenticated: true`, then partitioned by
  `authScope` (or token hash in memory). `CacheStore` interface +
  `MemoryCacheStore` (LRU, entry and byte limits).
- `OmniRawResponse.source` (`network`/`cache`/`revalidated`), shown in logs.
- In-flight deduplication (`deduplicate: true` by default): identical
  concurrent GETs (same URL and headers) share one network call; each caller
  keeps its own timeout/cancel, and the shared call is cancelled only when
  every caller has left.
- Step 9: `RequestState<T>` (sealed: `RequestIdle`, `RequestLoading`
  with `previous`, `RequestSuccess`, `RequestEmpty`, `RequestError` with
  `previous`/`networkError`) and `RequestController<T>` (`state`, `stream`
  replaying the current state to each listener, `load` sharing a running
  load, `refresh` restarting it, superseded loads never emit, `close`
  cancels the request). `api.watch<T>()` / `api.watchList<T>()`.
  Plain Dart; Flutter/Bloc bindings come in their own packages.
- Step 10: `OfflineQueue` — nothing is queued implicitly; only `enqueue`
  and `sendOrQueue` (queues only on connection error/timeout; any server
  response, even 5xx, is returned). GET/HEAD and multipart refused;
  PUT/PATCH/DELETE need `allowDestructive: true`; every item carries an
  `Idempotency-Key` (generated or kept) that is reused on every replay;
  `Authorization`/`Cookie` are never stored (auth adds a fresh token on
  replay). `flush` replays FIFO one at a time, stops at the first temporary
  failure (order kept), removes 4xx as `rejected`, dead-letters after
  `maxAttempts`; concurrent flushes share one run; replays bypass client
  retries. `events` stream, `discard`, `attach(Stream<bool>)` for
  connectivity, id-based dedupe. `QueueStore` interface + `MemoryQueueStore`;
  `QueuedRequest.toJson/fromJson` for persistent stores.
- Step 11: `Endpoint<T>` (`Endpoint.get/getList/post/put/patch/delete`,
  `{param}` path templates URL-encoded, missing/unknown params rejected,
  default query/headers/cache/retry, name/description/tags) with
  `api.call(endpoint, path:, query:, body:)` / `callResponse`.
  `EndpointRegistry` (by name or `METHOD path`, tags, `match` concrete
  paths, duplicates rejected).
- Fluent `api.request(path, method:)` → `OmniRequestBuilder` (`query`,
  `header`, `json`, `form`, `text`, `bytes`, `timeout`, `cancelToken`,
  `retry`, `cache`, `skipAuth`, `send`/`sendList`/`sendRaw`, `build`).
- `api.toCurl(request, redact: true)`: secrets masked by default, safe shell
  quoting, binary/multipart bodies never inlined. `parseCurl(command)` →
  `CurlImport(request, warnings)` for browser "Copy as cURL" commands
  (quotes, continuations, -X/-H/-d*/--json/-u/-G/-I/--url…; unsupported
  options reported, never silently dropped). Export→import round-trips.
- `OmniNetwork.redactor` is now a public field (used by logs and cURL).
- Step 12: `OmniMock`, a programmable fake backend usable as `transport:`:
  `get/post/put/patch/delete/on/any` routes with `{param}` templates
  (later routes win), `endpoint(Endpoint, …)`, `basePath`, `MockRequest`
  (`pathParams`, `query`, `headers`, `json`, `text`), `MockResponse`
  (`json`, `text`, `bytes`, `status`, `error`, `offline`, `hang`, per
  response `delay`), `OmniMock.sequence([...])`, named `scenario`s with
  `use(name)`, global `latency`, `failNext(n, error)`, seeded
  `failureRate`, `calls`/`callsTo`/`unmatched`/`resetCalls`. Strict by
  default: an unmatched request fails with a `RequestFailure` naming it.
  Downloads and uploads work through it.
- Step 14 (core): `OmniNetwork.openStream(request)` → `OmniStreamResponse`
  (status, headers, body stream, `cancel`) through the full pipeline
  (interceptors, auth refresh, logging); no timeout unless given; used by
  `omni_network_ws` for Server-Sent Events.
- Step 15 (core): `NetworkLogRecord.source` (network/cache/revalidated).
- S1 (simplification): the default import `omni_network.dart` now exposes
  only app-level names (39, down from ~95; 16 of them are error/state
  subtypes for `switch`). Low-level and extension APIs moved to
  `package:omni_network/advanced.dart` (which re-exports the default
  import); `OmniMock`/`MockTransport` moved to
  `package:omni_network/testing.dart`. `safeUri` is no longer exported.
  An analyzer-based test guards the split.
- S2 (simplification): one way to call. `get/getList/post/put/patch/delete/
  head` take every per-call option: `query`, `headers`, `timeout`,
  `cancelToken`, `retry`, `cache` (GET), `auth: false` (no token, no
  refresh), `adapter`. New `getResponse/postResponse/putResponse/
  patchResponse/deleteResponse` return the full `OmniResponse`, which now
  has `source`. **Breaking:** the fluent builder (`api.request(...)`,
  `OmniRequestBuilder`) is removed; `send`, `sendList`, `sendRaw`,
  `openStream`, `resolve` and `toCurl` moved to the `OmniNetworkAdvanced`
  extension (`advanced.dart`).
- S3 (simplification): `OmniNetwork(token: () => …)` shortcut (bearer
  header, no refresh; 401 stays an `HttpFailure`). `BearerAuth.refresh` is
  optional. Every `OmniNetworkException` has `statusCode` (null without a
  response), `isOffline`, `isTimeout`, `isCancelled`, `isUnauthorized`.
- S4 (simplification): `OmniAuth` token manager — `api.auth.login(Tokens)`,
  `logout()` (clears tokens and cache, `onLogout` once), `isLoggedIn`,
  `tokens`, `changes` (`AuthState`), `restore()`. Refresh on 401 and
  shortly before expiry (`refreshBefore`), single flight, keeps the refresh
  token when not rotated, signs out on refresh failure. `TokenStorage`
  (+ `MemoryTokenStorage`, default) in `advanced.dart`; `Tokens` with
  `toJson/fromJson` and a `toString` that never prints secrets. Every client
  has an `OmniAuth` by default, so `api.auth.login(...)` works without
  configuration. **Breaking:** `auth:` takes an `AuthProvider` (`OmniAuth` or
  `BearerAuth`); `BearerAuth` moved to `advanced.dart`. One `OmniAuth` per
  client (checked at construction).
- S5 (simplification): `enableLogging: true` now prints each call as one
  framed block (`PrettyLogSink`, the new default sink): method, URL,
  status with reason, time, size, pretty-printed JSON (cut after
  `maxLines`), `↻ retry n/m` and `🔑 token refreshed` notes, `cache` marker,
  colours when the terminal supports them. One `print` per call, so
  concurrent calls never interleave. `LogOptions` (`headers`,
  `requestBody`, `responseBody`, `maxLines`, `colors`, `width`). Release
  builds never log unless `logInRelease: true`; `api.isLogging`.
  `NetworkLogRecord.note` and `.bytes`. The compact `PrintLogSink` stays in
  `advanced.dart`.
- Hardening (security, memory, performance):
  - **Redirects** are followed by OmniNetwork, not Dio: `Authorization`,
    `Cookie` and `Proxy-Authorization` are removed when a redirect leaves
    the original origin; HTTPS → HTTP downgrades are never followed; 303 (and
    301/302 after POST) continue as GET without a body. `followRedirects`,
    `maxRedirects` (default 5).
  - **Auth cache**: authenticated entries are partitioned by the exact token
    instead of `String.hashCode` (two users with colliding hashes could see
    each other's cached data — regression test added); a persistent
    `CacheStore` with `cacheAuthenticated` now requires `authScope`.
  - **Large bodies**: JSON bodies ≥ 256 KB are parsed on a background isolate
    (IO platforms) so the UI does not freeze; bodies > 64 KB are summarised
    in logs instead of parsed for redaction.
  - **Memory**: `OmniCancelToken.child()` children are held weakly (creating
    a child per request on a long-lived token leaked them); the pretty log
    buffer is bounded; stress test with 2000 mixed calls checks nothing is
    left pending.
  - Friendlier messages: `HttpFailure.message` includes the reason phrase
    (`HTTP 404 Not Found`).
