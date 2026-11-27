# OmniRoute & OmniNetwork Full Example App

Complete Flutter + CLI showcase combining native `OmniRoute` (`OmniRouter` + `flutter_bloc`) with real public REST, WebSocket, and Multi-AI APIs via `omni_network` & `omni_network_flutter`.

> **বাংলা ইউজার গাইড (প্রতিটি প্যারামিটারসহ):** [`../doc/guide.bn.md`](../doc/guide.bn.md) | [`../README.md`](../README.md)

## What It Demonstrates

1. **Upgraded `OmniApp.material` Architecture** ([`lib/main.dart`](lib/main.dart))
   - Zero-boilerplate `OmniApp.material(...)` with `themeModeBuilder`, `appBuilder` (`OmniInspectorLauncher`), and managed `blocObserver`.
   - `AuthGuard` redirecting unauthenticated users and preserving the target URI (`?from=...`).
   - Lazy page-entry `Provide` registration (`StudentBloc`, `StudentDetailBloc`, `AttendanceBloc`) — registered when first entering the route, closed cleanly on exit.
   - `OmniStatefulShell` (4 persistent tabs), `OmniShell` (`/api`, `/api/ai-chat`, `/api/chat`), `OmniRouteGroup` (shared scope across detail + edit), modal `bottomSheet`, and `dialog` routes.
   - `OmniState` features (`onReady`, `onRouteChanged`, `readBloc`, `watchBloc`, `safeSetState`) + `OmniLifecycle` (`onAppResumed`).

2. **Real Public Developer APIs — Normal vs Modified Comparison** ([`lib/demo_backend.dart`](lib/demo_backend.dart), [`lib/api_lab_screens.dart`](lib/api_lab_screens.dart))
   - **`https://jsonplaceholder.typicode.com`** — `GET /users/{id}`, `POST /posts` (201 Created), full `GET /posts` (100 items, unclipped terminal logging), and `GET /users/999` (404 Client Warning).
   - **`https://dummyjson.com`** — `GET /products/{id}` and `GET /http/500` (500 Server Error demo).
   - **`https://api.open-meteo.com`** — Live Dhaka weather (`temperature_2m`, `wind_speed_10m`).
   - **`https://pokeapi.co/api/v2`** — Pokémon stats (`pikachu`).
   - **`wss://ws.postman-echo.com/raw`** — Live public WebSocket event + correlated RPC (`echo_rpc`).
   - **`Multi-Model AI`** — `OpenAiProvider` + `GeminiProvider` route switching and streaming chat (`MockAiProvider` demo out of the box; drop in API keys via `--dart-define`).

3. **Separate Colored Logs & 1-Click Copy**
   - Separate color-coded boxes (`LogOptions(summary: true, separate: true)`):
     - Request (`📡 http-request`, magenta), Success (`2xx`, green), Warning (`4xx`, amber/orange), Error (`5xx`, white-on-red banner + red body box), Navigation (`🧭 route`), and Bloc (`bloc-create`, `bloc-transition`).
   - In-app syntax-highlighted JSON previews + 1-click **`Copy JSON`**, **`Copy Full JSON`**, **`Copy Log`**, **`Copy All`**, and full Talker-style `OmniInspectorView(initialTab: InspectorTab.logs)`.

## Running

```bash
cd example

# Run the Flutter app against real public APIs:
flutter run -d macos    # or -d chrome / Android emulator / iPhone simulator

# Run the interactive live CLI tour in terminal:
dart run bin/demo.dart

# Run full hermetic UI + backend flow widget tests:
flutter test
```
