# Migrating from 0.4 to 0.5

The package was split so apps install only what they use.

| Was (0.4) | Now (0.5) | What to do |
|---|---|---|
| `omni_route` exported `omni_network`, `omni_network_flutter` and `flutter_secure_storage` | not exported, not depended on | add `omni_network` (and `omni_network_flutter` for `SecureTokenStorage` / inspector) to `pubspec.yaml`, then `import 'package:omni_network/omni_network.dart';` (and `package:omni_network_flutter/omni_network_flutter.dart`) |
| `package:omni_route/network.dart` | removed | import the `omni_network` packages directly |
| `package:omni_route/advanced.dart` | removed | `import 'package:omni_network/advanced.dart';` |
| `package:omni_route/testing.dart` exported network mocks | exports only `omni_route` | `import 'package:omni_network/testing.dart';` for `OmniMock` / `MockTransport` |
| responsive, theme, fields, localization lived in `omni_route` | moved to the `omni_responsive` package | nothing — `omni_route.dart` re-exports it; to use them **without** `omni_route`, depend on `omni_responsive` and wrap your app in `OmniResponsiveApp` |

Routing, Bloc, theme and responsive APIs are unchanged.

### Behaviour changes to check (0.5)

- **Startup:** the app holds its first frame (at most 120 ms) until saved
  settings are read. Add `await OmniPreferences.preload();` before
  `runApp` to remove the wait entirely.
- **Button text colors:** on generated palettes the label color is now chosen
  by contrast, so some presets show dark text on light buttons (e.g. Gold,
  Amber, Sunset). Set `buttonTextColor` to keep the old look.
- **`OmniThemeScope.maybeThemesOf(context).mode`** returns the brightness on
  screen (`ThemeMode.light` / `ThemeMode.dark`) instead of `system`. Use
  `context.themeMode` for the user's choice.
- **Theme widget labels** (`OmniThemePanel`, `OmniThemeModeSwitch`,
  `OmniThemeSettingsTile`, `showOmniThemeSheet`) default to the current
  language; passed strings still win. These panels also show a text size
  section (`showTextSize: false` to hide).

# Migrating from 0.1 to 0.2

0.2 adds features and fixes bugs. No public API was removed or renamed, and
most apps need no changes. Read the **behaviour changes** below; each one
was a bug fix, but code may have relied on the old behaviour.


## Behaviour changes

| Change | Was (0.1) | Now (0.2) | What to do |
|---|---|---|---|
| `OmniRoute.location` | ignored pages added with `push`; returned the location underneath | returns the page on top | if you worked around this, remove the workaround |
| Duplicate route `name`s | only a go_router debug assert; release builds silently used one of them | `OmniRouteException(duplicateRoute)` at startup in every build mode | rename the duplicate |
| Stateless screen shown outside a route with `provide` | `ProviderNotFoundException` | creates its own Blocs | nothing; remove manual `OmniBlocScope` wrappers if you like (they still work) |
| Stateful screen shown outside a route with `provide` | `ProviderNotFoundException` | the same, preceded by a clear `screenNotHosted` error | wrap it: `OmniScreenHost(screen: MyScreen())` |
| Two `OmniApp`s at once | the second's page type / titles / not-found page applied to both | each app keeps its own | nothing |
| `OmniRoute.*` after the latest of several apps is disposed | `notInitialized` | falls back to the previous app | nothing |
| Built-in page types | no `restorationId` | `restorationId` = go_router page key | nothing (used only if you enable restoration) |

## Enum addition

`OmniErrorCode.screenNotHosted` is new. A `switch` over `OmniErrorCode`
without a `default`/`_` case needs that case added.

## New APIs (optional)

| API | Use |
|---|---|
| `OmniScreenHost(screen:)` | show a stateful screen with Blocs outside a route |
| `OmniRouteGroup(provide:, scopeKey:, routes:)` | Blocs shared by several routes (route scope) |
| `OmniParams.of(context)` | route params in Bloc factories and `initState` |
| `OmniApp(restorationScopeId:)` | state restoration |
| `OmniPage(metadata:)` | per-route data for guards, analytics, titles |
| `OmniRoute.current` / `.stack` / `.state` | inspect navigation |
| `OmniApp(onNavigate:, logNavigation:)` | analytics hook, debug logging |

## Example: sharing a Bloc between detail and edit

0.1 (each page had its own copy):

```dart
OmniPage(':id', (p) => DetailScreen(id: p.pathInt('id')), routes: [
  OmniPage('edit', (p) => EditScreen(id: p.pathInt('id'))),
]),
// DetailScreen and EditScreen each: provide => [Provide<StudentBloc>.create(...)]
```

0.2 (one shared instance):

```dart
OmniRouteGroup(
  scopeKey: (s) => s.pathParameters['id'],
  provide: [
    Provide<StudentBloc>.create((c) => StudentBloc(OmniParams.of(c).pathInt('id'))),
  ],
  routes: [
    OmniPage(':id', (p) => DetailScreen(id: p.pathInt('id')), routes: [
      OmniPage('edit', (_) => const EditScreen()),
    ]),
  ],
),
// Screens drop the provide entry and use context.read<StudentBloc>().
```
