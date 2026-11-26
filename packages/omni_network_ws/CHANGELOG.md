## Unreleased

- Consolidated WebSocket & SSE implementations into `omni_network`
  (`OmniWebSocket`, `SseConnection`, `SseParser`, `parseSseByteStream`,
  `WsWebAuthMode`); `omni_network_ws` now re-exports them cleanly for backward
  compatibility.

## 0.1.0

First tagged release (`omni_network_ws-v0.1.0`); no API changes from 0.1.0-dev.

- Part of the `omni_route` repository's pub workspace
  (`resolution: workspace`); one `flutter pub get` at the root resolves it.
- Added `repository`, `homepage` and `issue_tracker` to `pubspec.yaml`.
- Releases are tagged `omni_network_ws-vX.Y.Z`.
- `environment` stays `sdk: ^3.12.0`: the code uses private named
  parameters, which need Dart 3.12.
- Dev dependency `test` relaxed to `^1.25.0` so it resolves together with
  the Flutter SDK's pinned `test_api`.

## 0.1.0-dev

- Step 14: `SseParser` (WHATWG event-stream rules) and `SseConnection`
  (reconnect with `retry:`/backoff, `Last-Event-ID`, stops on 204/4xx,
  `maxReconnects`, runs through `OmniNetwork.openStream` so auth,
  interceptors and logging apply). `OmniWebSocket` (reconnect with
  backoff and jitter except after a normal 1000 close or `close()`,
  per-connect `headers` callback (IO only; browsers forbid handshake
  headers), `onOpen`, `states`, `jsonMessages`, `send` throws while
  disconnected unless `bufferWhileDisconnected` (bounded, ordered)).
- Hardening: `SseParser(maxEventBytes:)` (default 1 MB) drops oversized
  events with a `FormatException` instead of growing memory without bound;
  `SseConnection` forwards parser errors to `events`.
