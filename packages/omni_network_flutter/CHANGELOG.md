## Unreleased

- Added `OmniRequestBuilder<T>` widget for reactive UI binding to
  `RequestController<T>` (auto-load, refreshing state, empty view, error
  retry).
- Added `OmniPagedListView<T>` widget for infinite scrolling and
  pull-to-refresh bound to `OmniPager<T>` via `OmniPager.changes`.
- Added `OmniInspector.toHarJson()` (HAR 1.2 JSON export),
  `OmniInspector.toMarkdownReport()`, and a **"Copy HAR"** toolbar button in
  `OmniInspectorView`.

## 0.1.0

First tagged release (`omni_network_flutter-v0.1.0`); no API changes from 0.1.0-dev.

- Part of the `omni_route` repository's pub workspace
  (`resolution: workspace`); one `flutter pub get` at the root resolves it.
- Added `repository`, `homepage` and `issue_tracker` to `pubspec.yaml`.
- Releases are tagged `omni_network_flutter-vX.Y.Z`.
- `environment` stays `sdk: ^3.12.0`: the code uses private named
  parameters, which need Dart 3.12.
- Dev dependency `test` relaxed to `^1.25.0` so it resolves together with
  the Flutter SDK's pinned `test_api`.

## 0.1.0-dev

- Step 15: `OmniInspector` (a `LogSink` + `ChangeNotifier`; off in release
  builds by default; `sink(label)` per client; bounded `maxEntries`;
  `forwardTo`; only ever sees redacted data), `OmniInspectorView` (list,
  filter, status colours, detail with headers/bodies, copy redacted cURL)
  and `OmniInspectorLauncher` for `MaterialApp.builder` (own `Overlay`,
  floating button, full-screen panel). Widget tests run with leak tracking.
- `SecureTokenStorage` (`flutter_secure_storage` ^11.2.0): `OmniAuth` tokens
  in Keychain/Keystore/Credential Manager/libsecret (WebCrypto on the Web),
  so users stay signed in across restarts. Corrupted entries are cleared;
  platform errors are reported via `onError` without secrets and never
  crash the app.
