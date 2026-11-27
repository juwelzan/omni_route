# omni_network_flutter

Flutter tools for [`omni_network`](../omni_network):

- **Secure token storage.** Users stay signed in after the app restarts.
- **In-app Talker-style Log, HTTP, WebSocket & AI Inspector with 1-click Copy.** Unified color-coded timeline (`http-request`, `http-response`, `http-warning`, `http-error`, `route`, `bloc-create`, `bloc-event`, `bloc-transition`, `ws`, `ai`), syntax-highlighted JSON viewer, per-card 1-click copy, `Copy Full Response`, `Copy as cURL`, `Copy HAR` (1.2), and Markdown reports.
- **Reactive UI widgets.** Bind `RequestController<T>` and `OmniPager<T>` with `OmniRequestBuilder<T>` and `OmniPagedListView<T>`.
- **Realtime Human & AI Chat widgets.** Drop-in Material 3 widgets for WebSocket team rooms (`OmniChatView`), streaming Multi-AI conversations with reasoning traces (`OmniAiChatView`), and runtime model/route switching (`OmniModelPicker`).

## Stay signed in: `SecureTokenStorage`

```dart
final api = OmniNetwork(
  baseUrl: 'https://api.example.com',
  auth: OmniAuth(
    storage: SecureTokenStorage(),   // that's all
    refresh: (tokens, api) async { /* see omni_network README */ },
  ),
);

await api.auth.login(Tokens(access: a, refresh: r)); // saved securely
// Next app start: the user is still signed in.
await api.auth.logout();                              // removed from the store
```

| Platform | Where tokens are kept |
|---|---|
| iOS / macOS | Keychain (macOS: add the Keychain Sharing entitlement) |
| Android | Keystore-encrypted storage |
| Windows / Linux | Credential Manager / libsecret |
| Web | WebCrypto-encrypted `localStorage`. A browser can't fully protect it, so use short-lived access tokens |

Failure handling:

- **Corrupted data** is deleted and treated as signed out, so the app never
  gets stuck.
- **Platform errors** never crash the app. They are reported through
  `onError` (the default prints only the error type, never a token).
- **Several clients.** Use a different `key:` for each client so they keep
  separate tokens.

## Reactive UI widgets

### `OmniRequestBuilder<T>`

Binds directly to `RequestController<T>` (`api.watch(...)`), automatically
loading on init when idle and handling loading, refresh, empty and error-retry
states cleanly:

```dart
final me = api.watch<User>('/me', decoder: User.fromJson);

OmniRequestBuilder<User>(
  controller: me,
  emptyBuilder: (_) => const Text('No profile found'),
  builder: (context, user, isRefreshing) => Column(
    children: [
      if (isRefreshing) const LinearProgressIndicator(),
      Text(user.name),
    ],
  ),
);
```

### `OmniPagedListView<T>`

Infinite-scrolling `RefreshIndicator` list bound to `OmniPager<T>` (`api.paginate(...)`):

```dart
final pager = api.paginate<User>(
  '/users',
  decoder: User.fromJson,
  strategy: const PagePagination(pageSize: 20),
);

OmniPagedListView<User>(
  pager: pager,
  itemBuilder: (context, user, index) => ListTile(title: Text(user.name)),
);
```

Automatically loads page 1, fetches subsequent pages when scrolling within
`loadThreshold` (default 200 px) of the bottom, supports pull-to-refresh, and
shows empty/retry footers when needed.

### Chat & Multi-AI widgets

- **`OmniAiChatView(thread: api.aiThread('assistant'))`** — Streaming Multi-AI chat UI with collapsible thinking/reasoning traces, active tool badge, token/USD usage summary, stop-generation, regenerate, clear, and model switching via `OmniModelPicker`.
- **`OmniChatView(room: api.chat.room('lobby'))`** — Realtime WebSocket room UI with optimistic message delivery, delivery status ticks, reply preview banner, typing indicators, emoji reactions, failed-message retry, file/media attachment picker (`onPickAttachment`), older history pagination, and `@ai` assistant replies.
- **`OmniModelPicker(...)`** — Compact popup selector for switching active `OmniAi` routes or `'provider:model'` identifiers.

## Talker-style Log & Network Inspector (with 1-Click Copy)

```dart
final inspector = OmniInspector();         // disabled in release builds
final api = OmniNetwork(
  baseUrl: 'https://api.example.com',
  wsBaseUrl: 'wss://ws.example.com',
  enableLogging: inspector.enabled,
  logSink: inspector.sink('api'),          // one label per client
);
final detach = inspector.attachClient(api); // captures HTTP, WS frames & AI telemetry

// Optionally push OmniRoute navigation and Bloc logs into the same timeline:
inspector.logRoute('/dashboard -> /profile', subtitle: 'uri: /profile');
inspector.logBloc('bloc-transition', 'ThemeBloc -> dark', kind: InspectorLogKind.blocTransition);

MaterialApp(
  builder: (context, child) => OmniInspectorLauncher(
    inspector: inspector,
    initialTab: InspectorTab.logs,         // or InspectorTab.http
    child: child!,
  ),
  home: const HomePage(),
);
```

`OmniInspectorLauncher` adds a small floating button that opens a full-screen
panel (`OmniInspectorView`) featuring:

- **`All Logs` (`InspectorTab.logs`)**: Talker-style separate color-bordered cards (`http-request`, `http-response`, `http-warning`, `http-error`, `route`, `bloc-create`, `bloc-event`, `bloc-transition`, `ws`, `ai`, `info`, `warning`, `error`), tag count filter chips, and `Search...`.
- **1-Click Copy everywhere**: copy icon right on every card (copies pretty response JSON or the card log), plus **`Copy Full Response`**, **`Copy Full Log`**, **`Copy as cURL`**, **`Copy HAR`** (`inspector.toHarJson()`), and **`Copy all logs`** in the toolbar.
- **Syntax-highlighted Response & Detail Viewer**: colored status banners (`SUCCESS` green, `WARNING` orange, `ERROR` red) and highlighted JSON tokens (keys, strings, numbers, booleans).
- **Redacted & bounded**: receives records after `OmniNetwork`'s `Redactor` runs, keeping at most `maxEntries` entries (up to `2 * maxEntries` timeline cards); pass `forwardTo: PrettyLogSink()` to mirror into terminal logs simultaneously.

## Example

`example/` has an app that uses `RequestController` with a fake backend.
To run it, first add platform folders:

```sh
cd example
flutter create --platforms=android,ios,macos,web .
flutter run
```

`flutter test` in `example/` runs its smoke test.

## Development

`flutter test` runs with leak tracking enabled for every test
(`test/flutter_test_config.dart`), the same setup as `omni_route`.
