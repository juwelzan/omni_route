# omni_network

Simple, typed and safe HTTP for Dart and Flutter. It works on Android, iOS,
macOS, Windows, Linux and the Web, and needs no code generation.

```dart
final api = OmniNetwork(baseUrl: 'https://api.example.com', enableLogging: true);
final user = await api.get<User>('/users/10', decoder: User.fromJson);
```

> Status: `0.1.1`, not on pub.dev yet. Depend on it from GitHub by tag.

- [Start here](#start-here)
- [Login and tokens](#login-and-tokens)
- [Terminal logs](#terminal-logs)
- [Common tasks](#common-tasks)
- [Safe by default](#safe-by-default)
- [Full guide](doc/advanced.md)
- [সম্পূর্ণ গাইড — বাংলা](doc/guide.bn.md)

---

## Start here

### 1. Install

```yaml
dependencies:
  omni_network:
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_network
      ref: omni_network-v0.1.1
```

```dart
import 'package:omni_network/omni_network.dart';
```

### 2. Create one client for your app

```dart
final api = OmniNetwork(
  baseUrl: 'https://api.example.com/v1',
  enableLogging: true,   // prints every call while you develop; off in release
  // Register decoders once so get<User>() doesn't need decoder: every time:
  decoders: {User: User.fromJson},
);
```

Need low-level transport power (proxy, SSL pinning, HTTP/2, mTLS, custom DNS /
DoH, stage timeouts, concurrency limit)? Pass them in one line on
`OmniNetwork(...)`, or migrate incrementally with `OmniNetwork.fromDio(dio)`:

```dart
final api = OmniNetwork(
  baseUrl: 'https://api.example.com/v1',
  proxy: '192.168.0.105:8888',        // dev debugging proxy (off in release by default)
  pinnedSha256: ['sha256/...'],       // leaf or SPKI SHA-256 pinning
  enableHttp2: true,                  // HTTP/2 on mobile/desktop
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 20),
  maxConcurrentRequests: 6,
);
```

Update shared headers on a running client anytime with `api.setHeader(...)`,
`api.removeHeader(...)`, and `api.clearHeaders()`.

### 3. Get data

A decoder is any function that turns a JSON map into your class, usually
your model's `fromJson` (or registered once in `decoders:`):

```dart
class User {
  User({required this.id, required this.name});
  factory User.fromJson(Map<String, dynamic> json) =>
      User(id: json['id'] as int, name: json['name'] as String);
  final int id;
  final String name;
}

final user  = await api.get<User>('/users/10', decoder: User.fromJson);
final users = await api.getList<User>('/users', decoder: User.fromJson);
final page  = await api.getList<User>('/users', decoder: User.fromJson,
    query: {'page': 2});   // → /users?page=2

// GraphQL query / mutation:
final me = await api.graphql<User>(
  '/graphql',
  query: r'query Me { viewer { id name } }',
  dataKey: 'viewer',
  decoder: User.fromJson,
);
```

### 4. Send data

```dart
final created = await api.post<User>('/users',
    body: {'name': 'Ana'}, decoder: User.fromJson);   // Map/List → JSON
await api.post<void>('/events', body: largeList, compress: true); // gzip body (IO)
await api.postForm<void>('/token', fields: {'grant_type': 'refresh_token'});
await api.put<void>('/users/10', body: {'name': 'Ana B.'});
await api.patch<void>('/users/10', body: {'name': 'Ana C.'});
await api.delete<void>('/users/10');
```

### 5. Handle errors

Every failure is an `OmniNetworkException`, with simple checks:

```dart
try {
  final user = await api.get<User>('/users/10', decoder: User.fromJson);
} on OmniNetworkException catch (e) {
  if (e.isOffline) {
    showMessage('No internet connection');
  } else if (e.isUnauthorized) {
    goToLogin();
  } else if (e.statusCode == 404) {
    showMessage('Not found');
  } else {
    showMessage(e.message);   // safe to show: never contains tokens
  }
}
```

Or without `try`/`catch`:

```dart
final result = await api.get<User>('/users/10', decoder: User.fromJson).asResult();
switch (result) {
  case Ok(:final value): showUser(value);
  case Err(:final error): showMessage(error.message);
}
```

That's all you need for most apps. Close the client when the app shuts down:
`await api.close();`.

---

## Login and tokens

Every client has a token manager, `api.auth`. After your login call, give
it the tokens once. From then on every request carries them:

```dart
final res = await api.post<Map<String, dynamic>>('/auth/login',
    body: {'email': email, 'password': password},
    auth: false);                            // this call needs no token

await api.auth.login(Tokens(
  access: res['access_token'],
  refresh: res['refresh_token'],
  expiresIn: Duration(seconds: res['expires_in']),
));
// Or extract `exp` directly from a JWT access token:
await api.auth.login(Tokens.fromJwt(jwtAccess, refresh: refreshToken));

api.auth.isLoggedIn;      // true
await api.auth.logout();  // forget the tokens
```

To refresh expired tokens automatically, tell `OmniAuth` how:

```dart
final api = OmniNetwork(
  baseUrl: 'https://api.example.com/v1',
  auth: OmniAuth(
    refresh: (tokens, api) async {
      final r = await api.post<Map<String, dynamic>>('/auth/refresh',
          body: {'refresh_token': tokens.refresh});
      return Tokens(access: r['access_token'], refresh: r['refresh_token'],
          expiresIn: Duration(seconds: r['expires_in']));
    },
    onLogout: () => goToLogin(),   // refresh failed, or logout() was called
  ),
);
```

What `OmniAuth` takes care of:

- **Refresh before expiry.** The token is refreshed shortly before it
  expires (works even on cold start from `storage`), and again if the server
  answers 401.
- **One refresh at a time.** If many calls need a refresh together, it runs
  once and the calls are replayed.
- **Failed refresh.** If refreshing fails, the user is signed out once:
  the tokens are cleared and `onLogout` runs.
- **Router updates.** `api.auth.changes` is a stream of
  `signedIn`/`signedOut`, so your router can follow it.

**Keep users signed in after the app restarts** (Flutter):
`OmniAuth(storage: SecureTokenStorage(), ...)` from
[`omni_network_flutter`](../omni_network_flutter). It uses the Keychain or
Keystore.

**Other built-in auth strategies:**

- `token: () => myToken` — simple external token callback.
- `ApiKeyAuth(key, headerName: 'X-API-Key')` (or `inQuery: true`, or dynamic
  `ApiKeyAuth.provider(...)`).
- `BasicAuth(username: u, password: p)`.
- `HmacSignerAuth(secret: s)` — signs requests with HMAC-SHA256.

---

## Terminal logs

`enableLogging: true` logs each call as one clear block through the
[`logger`](https://pub.dev/packages/logger) package (same look as
OmniRoute's logs). Secrets are always hidden:

```
┌───────────────────────────────────────────────────────────
│ 2026-11-17 15:35:30.519
├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
│ 💡 GET  https://api.example.com/v1/users/10
│ 💡 ✔ 200 OK · 3 ms · 43 B
│ 💡 {
│ 💡   "id": 10,
│ 💡   "name": "Rahim",
│ 💡   "access_token": "***"
│ 💡 }
└───────────────────────────────────────────────────────────
┌───────────────────────────────────────────────────────────
│ 2026-11-17 15:35:30.526
├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
│ ⚠️ POST https://api.example.com/v1/orders
│ ⚠️ ⇢ body
│ ⚠️   {
│ ⚠️     "qty": 0
│ ⚠️   }
│ ⚠️ ✖ 422 Unprocessable Entity · 0 ms · 15 B
│ ⚠️ {
│ ⚠️   "error": "qty"
│ ⚠️ }
└───────────────────────────────────────────────────────────
```

- **Levels.** 💡 success, ⚠️ a 4xx error, ⛔ a 5xx error or no response.
- **Colours.** Successful calls are green with coloured JSON (keys, strings,
  numbers); errors are red. On by default in Android logs and colour
  terminals. iOS logs can't show colours, so they stay plain there.
- **Whole responses.** Every line of every body is printed (500–1000+ lines),
  never cut off. Lines longer than 160 characters continue on the next line
  after `↪`, because Android and iOS drop the end of a very long log line.
- **Toggle on/off anytime.** Control at init or dynamically at runtime via
  `api.enableLogging = true/false`, `api.logResponse = true/false` (hide/show
  response bodies), and `api.logColors = true/false/null`.
- **Stream & multi-sink.** Listen to `api.logStream` directly, or fan out logs
  to terminal + inspector simultaneously with `MultiLogSink([PrettyLogSink(), inspector])`
  (from `advanced.dart`).
- **Notes.** Retries (`↻ retry 2/3`), token refreshes (`🔑 token refreshed`) and
  cache hits are marked.
- **Off in release builds.** Logging is turned off automatically in release
  builds unless `logInRelease: true`.

---

## Common tasks

Every call (`get`, `getList`, `post`, `put`, `patch`, `delete`) takes the
same optional settings:

```dart
await api.get<User>('/me',
    decoder: User.fromJson,
    query: {'expand': 'roles'},          // ?expand=roles
    headers: {'X-Trace': id},
    timeout: const Duration(seconds: 5),
    auth: false,                         // send without the token
    retry: RetryPolicy.none,             // no retry for this call
    cache: CachePolicy.networkFirst,     // needs `cache: OmniCache()` on the client
    cancelToken: token);                 // cancel later with token.cancel()
```

| I want to… | Use |
|---|---|
| status code / headers too | `api.getResponse<User>(...)` (also `postResponse`, …) |
| GraphQL query / mutation | `api.graphql<T>(path, query: ..., variables: ..., dataKey: ...)` |
| form-urlencoded POST | `api.postForm<T>(path, fields: {...})` |
| gzip request body (IO) | `api.post(path, body: data, compress: true)` |
| retry failed GETs | `OmniNetwork(retry: const RetryPolicy())` |
| cache responses (RAM / disk) | `OmniNetwork(cache: OmniCache(store: FileCacheStore(...)))`, `api.clearCache()` |
| upload a file | `api.upload('/avatar', files: [await UploadFile.fromFile('file', path)], onProgress: …)` |
| download with resume & SHA-256 | `api.downloadBytes(..., expectedSha256: ...)` or `api.downloadToFile(url, path, resume: true, expectedSha256: ...)` |
| load page by page | `api.paginate<User>('/users', decoder: User.fromJson, strategy: const PagePagination())` (listens via `pager.changes`) |
| show loading / data / error in UI | `api.watch<User>(...)` + `OmniRequestBuilder` / `OmniPagedListView` in [`omni_network_flutter`](../omni_network_flutter) |
| quick inline interceptor | `OmniInterceptor.inline(onRequest: ..., onResponse: ..., onError: ...)` |
| telemetry & slow requests | `api.metrics`, `api.resetMetrics()`, `slowRequestThreshold:` + `onSlowRequest:` |
| proxy / SSL pin / DoH / mTLS | `OmniNetwork(proxy: ..., pinnedSha256: [...], dnsOverHttps: ..., clientCertificateBytes: ...)` |
| migrate from Dio | `OmniNetwork.fromDio(dio)` |
| cancel requests | `OmniCancelToken`, `api.cancelAll()` |
| record / mock without server | `OmniMock` & `RecordingTransport` from `package:omni_network/testing.dart` |
| typed endpoints from OpenAPI | [`omni_network_openapi`](../omni_network_openapi) |
| WebSocket / Server-Sent Events | [`omni_network_ws`](../omni_network_ws) |
| in-app inspector & HAR export | [`omni_network_flutter`](../omni_network_flutter) (`OmniInspector`) |

Details and every option are in the **[full guide](doc/advanced.md)**. It
also covers `FileQueueStore` for offline persistence, custom DNS, interceptors,
circuit breaker, cURL, custom transports and stores.

---

## Safe by default

- **Tokens and passwords never leak.** They are hidden in logs, never put in
  error messages, and never stored by the offline queue.
- **Redirects.** Credentials are dropped when a redirect leaves your
  server, and HTTPS → HTTP redirects are refused.
- **Retry.** Off unless you turn it on. Even then only GET/HEAD are
  retried, never a payment POST by accident.
- **Cache.** Off unless you turn it on. Even then, logged-in responses are
  not cached unless you allow it.
- **No frozen UI.** Large JSON is decoded off the main isolate on mobile and
  desktop.
- **Logs.** Off in release builds.

## Platforms

| Feature | Android | iOS | macOS | Windows | Linux | Web |
|---|---|---|---|---|---|---|
| Core HTTP, auth, GraphQL, cache, metrics | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅² |
| `downloadToFile` / `FileCacheStore` / `FileQueueStore` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `proxy` / `pinnedSha256` / mTLS / DoH / `compress` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌³ |

1. macOS apps need the `com.apple.security.network.client` entitlement.
2. On the Web, your server must allow CORS.
3. Browsers handle TLS, DNS, proxy and `Content-Encoding` natively on the Web; use `downloadBytes` on Web.

## Example

`dart run example/main.dart` runs a tour against a fake server, with no
internet needed.
