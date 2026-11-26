# omni_network_ws

Server-Sent Events and WebSocket adapters for
[`omni_network`](../omni_network). Pure Dart.

> All WebSocket & SSE implementations now live directly inside
> [`omni_network`](../omni_network) (`api.ws(...)`, `api.sse(...)`,
> `OmniWebSocket`, `SseConnection`, `SseParser`, `WsWebAuthMode`), sharing client
> auth, `proxy`, `pinnedSha256`, mTLS, custom DNS, and logging. `omni_network_ws`
> re-exports the same types for backward compatibility.

## Server-Sent Events

```dart
final sse = SseConnection(api, '/events');   // api is an OmniNetwork
sse.events.listen((e) => print('${e.event}: ${e.data}'));
sse.states.listen(print);                    // connecting/open/waiting/closed
await sse.close();
```

- **Same pipeline as normal requests.** The stream goes through
  `OmniNetwork.openStream`, so `BearerAuth` (including refresh),
  interceptors and logging all apply.
- **Reconnects.** It reconnects when the stream ends or the connection
  drops. The delay starts from the server's `retry:` value and grows with
  backoff. It sends `Last-Event-ID` so the server can resume.
- **Stops** on `204`, on a 4xx other than 408/429 (the error is reported on
  `events`), or after `maxReconnects` failed attempts.
- **Parser.** `SseParser` follows the WHATWG event-stream rules and can be
  used on its own.

## WebSocket

```dart
final ws = OmniWebSocket(
  Uri.parse('wss://api.example.com/live'),
  headers: () async => {'authorization': 'Bearer ${await tokens.access()}'},
  onOpen: (s) => s.sendJson({'subscribe': 'prices'}),
);
ws.jsonMessages.listen(print);
await ws.close();
```

- **Reconnects** after errors and abnormal closes, with backoff and jitter.
  It does not reconnect after a normal close (`1000`) from the server or
  after `close()`.
- **Headers per connect.** `headers` runs on every connect, so a refreshed
  token is used. Handshake headers work on IO platforms only; browsers do
  not allow them (`OmniWebSocket.supportsHandshakeHeaders`).
- **No silent queuing.** `send` throws while disconnected. Opt in with
  `bufferWhileDisconnected: true`; messages are then kept in order up to
  `maxBuffered`.

## Development

Run the tests with `dart run test/<file>_test.dart`; see the note in
`omni_network`. The tests use a fake backend and loopback servers, never
the internet.
