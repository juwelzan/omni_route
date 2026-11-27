## 0.5.0 — Unreleased

**Breaking: packages split** — see [doc/migration.md](doc/migration.md).

- `omni_route` no longer depends on or re-exports `omni_network`,
  `omni_network_flutter`, `omni_network_ws`, `dio`, `web_socket_channel` or
  `flutter_secure_storage`. Add them only when you use them;
  `flutter_secure_storage` was the one native plugin every app paid for.
- `package:omni_route/network.dart` and `advanced.dart` are removed;
  `testing.dart` no longer exports network mocks.
- Responsive layout, themes, theme transitions, fields, system UI and
  localization moved to the new `omni_responsive` package. `omni_route`
  depends on it and re-exports it, so existing imports keep working.
- New `OmniResponsiveApp` (in `omni_responsive`): the same theme / locale /
  system-UI / text-scaling stack as `OmniApp`, around any `MaterialApp`, for
  apps that route with something else.

- Text fields rebuild only when what they show changes (clear button,
  suggestions, strength meter), not on every cursor move or IME update.
  Validator and formatter regexes are compiled once.
- Swipe-back keeps a fixed widget tree during the gesture, so crossing the
  fade/radius/shadow thresholds no longer reparents the page mid-swipe.
- A theme or language chosen while saved preferences are still loading at
  startup is no longer overwritten by the older saved value.
- Theme transition snapshots behave the same in debug and release builds.
- State restoration looks shells up by id from a one-time index.
- Recovered errors (storage unavailable, malformed restoration data) are
  logged to DevTools in debug builds instead of being swallowed silently.
- The router host follows a replaced `OmniRouter` instead of keeping the
  old one's listener.
- Push, pop and app rebuilds (theme, locale) no longer re-run the screen
  builder of every page in the stack: a page whose route is unchanged is
  handed back to the Navigator as is. Before, a builder route such as
  `(p) => DetailScreen(id: p.pathInt('id'))` rebuilt every screen below on
  each navigation. A query or parameter change still rebuilds its page; hot
  reload refreshes all pages.
- Dialog, bottom-sheet and adaptive-modal pages show the updated screen when
  their page changes (for example a new query), instead of the first one.
- `OmniPage.onExit` is asked once when back is pressed again while it is
  still deciding, so the confirm dialog no longer opens twice and the page
  is not popped twice.
- A screen's `routePath` is validated once per path instead of on every
  build.
- `OmniColors` has 20 more colors (75 in all), settable everywhere colors are
  (`OmniTheme`, `OmniColorPalette`, `fromSeed`, `copyWith`, JSON):
  `tertiaryColor`, `dialogColor`, `bottomSheetColor`, `drawerColor`,
  `menuColor`, `fabColor`, `fabTextColor`, `outlineButtonColor`,
  `outlineButtonBorderColor`, `inputBorderColor`, `cursorColor`,
  `textSelectionColor`, `progressColor`, `progressTrackColor`,
  `tabSelectedColor`, `tabUnselectedColor`, `switchThumbColor`,
  `focusColor`, `scrollbarColor`, `navIndicatorColor`. Each defaults to the
  color that was used before.
- `OmniTheme.buttonShape` (`OmniButtonShape.rounded` / `pill` / `square`) and
  `buttonRadius` shape every button, FAB and segmented button independently
  of cards and fields. `OmniThemeStyle.pill` uses pill buttons.
- The theme now styles FAB, segmented buttons, popup / dropdown / anchor
  menus, drawers, tab bars, progress indicators, sliders, text selection,
  scrollbars, badges, date and time pickers, search bars, bottom app bars and
  expansion tiles, and maps the theme's surfaces onto the Material 3 surface
  levels instead of seed tones.
- Fixes: a text field's floated label is no longer accent-colored while
  unfocused; field icons follow focus / error / disabled; underlined fields
  have no left inset; switch thumbs and checkbox ticks stay readable on a
  light `switchActiveColor`, without a grey ring around a switched-on track;
  the snackbar action keeps 3:1 contrast in both modes.
- Install docs use one repository tag (`ref: v0.5.0`) for every package;
  WebSocket/SSE are documented as part of `omni_network` (no extra package).
- The whole repository is `dart format`-clean again, so CI's format step
  passes.
- `OmniApp` is built on `omni_responsive`'s `OmniUiHost` (about 120 lines of
  duplicated composition removed) and gains `textScaling:` /
  `textScaleController:` for the new app-wide text size. Theme, language
  and text size are restored before the first frame (see
  `OmniPreferences.preload`). Details in omni_responsive's CHANGELOG.

## 0.3.1

No API changes; purely additive. Everything new is off by default.

- New `OmniApp(predictiveBack: true)`: Android's system back gesture
  (predictive back, Android 14+) drives the swipe-back styles — the page
  zooms out with the finger, pops on commit (through go_router, so the
  stack, `onNavigate`, logs and `OmniLifecycle` stay correct) and springs
  back on cancel. Uses the page's `swipeBack` style (`zoom` when the
  in-app swipe is off). Back button presses still pop normally. Needs
  `android:enableOnBackInvokedCallback="true"` in `AndroidManifest.xml`.
- With `predictiveBack` on Android, `material`/`cupertino` pages use the
  new `OmniPages.swipeZoom` so they follow the gesture too (iOS unchanged).
- New `OmniPages.swipeZoom`: soft zoom-in (0.94 → 1) with a fade, plus the
  `zoom` edge swipe.
- OmniRoute's logs (`logNavigation`, guard warnings) now go through the
  `logger` package (new dependency `logger: ^2.8.0`) in one readable format:
  a framed block per event with time, time since start, level emoji and
  aligned `from`/`to` rows with the screen class. Debug builds only.
  Replace `OmniRoute.logger` to change the format or the destination. The
  old one-line `[OmniRoute] ...` text is gone. Colours are used only where
  the console shows them (not in phone/simulator logs, where they appeared
  as `\^[[38;5;12m`). Routes declared without a screen type show their
  name instead of `OmniScreen`.
- The edge swipe and the system gesture share one settle path; only the
  page on top of everything (go_router's top page, in a visible tab) takes
  the system gesture.

## 0.3.0

No breaking API changes; everything new is optional. One deprecation:
`AnyBloc` (see the README's migration section).

- Repository: pub workspace (one `flutter pub get` at the root resolves the
  package and `packages/*`), CI on push/PR, `repository`/`homepage`/
  `issue_tracker` metadata, install from GitHub tags (`ref: v0.3.0`).
- New `OmniRoute.popUntil(location)`, `OmniRoute.popToRoot()` (one pop per
  frame; like `Navigator.popUntil` they ignore `PopScope`) and
  `OmniRoute.openTo<S>()`. `open` no longer pops twice in one frame.
- Cubits are accepted everywhere a Bloc is (`OmniBloc`, `Provide`,
  `Provide.value`, `OmniBlocRegistry`, scopes) via the new
  `OmniAnyBloc = BlocBase<Object?>`. `AnyBloc` is deprecated.
- New page types `OmniPages.dialog(barrierColor:, barrierDismissible:)` and
  `OmniPages.bottomSheet(showDragHandle:, isScrollControlled:)`;
  `await OmniRoute.push<T>(...)` returns the value given to `pop`.
- `OmniLifecycle` mixed into an `OmniStatefulWidget` (instead of its State)
  is reported once in debug builds (`OmniErrorCode.lifecycleOnWidget`).
- `onScreenHidden` now also fires when a visible screen is removed outright
  (e.g. `go` or app teardown), so every visible has exactly one hidden.
- Screens with `OmniLifecycle` no longer rebuild on every push/pop above
  them: visibility is tracked by a tiny child widget.
- New `OmniApp(titleColor:)`; the app-switcher colour now defaults to the
  theme's `colorScheme.primary` (black without a Material theme) instead of
  always black.
- `dismissKeyboardOnTap` uses the text field's own tap-outside detection
  (`TapRegion` intents) instead of a root `GestureDetector`, so it no longer
  joins every tap's gesture arena. Same behaviour: taps outside close the
  keyboard, scrolls and taps on the field (or its toolbar) don't.

## 0.2.6

Swipe-back gets 8 visual styles. Additive except for two renames in
`OmniSwipeBackStyle`, which was only added in 0.2.5.

- New `OmniSwipeBack` styles: `zoomCenter`, `zoomToEdge`, `zoomFollow`,
  `zoomCard`, `zoomParallax`, `zoomTilt` (plus `slide` and `zoom`). `slide`
  now has a light edge shadow and a -30% parallax on the page below.
- New `OmniSwipeBackStyle` options: `fadeStart`, `maxTilt`, `shadow`,
  `dimBelow`, `backgroundColor`; visual values are now nullable and fall back
  to per-style defaults. Presets `OmniSwipeBackStyle.subtle()` and
  `.dramatic()`.
- Renamed `flingVelocity` → `flickVelocity` and `springCurve` →
  `settleCurve`.
- A page that is not being swiped has no extra widgets (only the edge
  listener); its state is kept when the swipe starts and ends. Only
  Transform / Opacity / ClipRRect / box shadow are used, never blur.
- The page follows the finger from touch-down (no slop jump).
- Golden tests for every style; the example app can switch styles live.

## 0.2.5

No API changes; purely additive. Swipe-back is off by default, so existing
apps behave exactly as before.

- New edge swipe-back for every animated page type (`OmniPages.fade`,
  `slide`, ..., `transition(...)`, `custom(...)`), as a separate gesture
  layer: `OmniPages.transition(kind, swipeBack:)`,
  `OmniPages.custom(builder, swipeBack:)`, and the app-wide default
  `OmniApp(swipeBack:, swipeBackStyle:)`.
- Styles `OmniSwipeBack.none` / `slide` / `zoom` (scale to 0.82, rounded
  corners, fade in the last 25%); tuning via `OmniSwipeBackStyle` (min
  scale, corner radius, slide factor, edge width, close threshold, fling
  velocity, edges, curves).
- Same enable rules as Flutter's Cupertino back gesture (respects
  `PopScope`); pops through go_router so `OmniRoute.stack`, logs and
  `OmniLifecycle` hooks stay correct; plain slide under reduced motion.
- New `OmniRoute.open(location, maxDepth:)`: push without duplicates (pops
  back to a page already in the stack, `go` when the stack is too deep).
- New public types `OmniSwipeBack`, `OmniSwipeBackStyle`, `OmniSwipeEdge`,
  `OmniSwipeBackPage` (a `CustomTransitionPage`).

## 0.2.4

No API changes; purely additive.

- New built-in animated page transitions: `OmniPages.fade`, `slide`
  (RTL-aware, with parallax on the page below), `slideUp`, `scale`,
  `fadeScale`, `fadeSlide`. 250 ms open / 200 ms close, `easeOutCubic`,
  opacity/transform only (GPU-composited, no per-frame allocation).
- New `OmniPages.transition(OmniTransition, duration:, reverseDuration:,
  curve:)` to tune a built-in.
- New `OmniPages.custom(builder, ...)` transition builder (Flutter's
  `transitionsBuilder` signature), with `opaque`, `barrierColor`,
  `barrierDismissible`, `fullscreenDialog` for dialog-style pages.
- New public types `OmniTransition`, `OmniTransitionBuilder`.
- Restoration ids are kept for all new page types.

## 0.2.3

No API changes; purely additive. Every new `OmniApp` parameter is optional
and off by default, so existing apps behave exactly as before.

- New `OmniApp(lifecycle:)`: app-wide `OmniLifecycle` hooks (resume, pause,
  memory pressure, ...) whose context can read global Blocs.
- New `OmniApp(onInit:, splash:)`: async startup work before the first
  page; guards see the loaded state. Errors are reported and the app opens.
- New `OmniApp(dismissKeyboardOnTap:)`: close the keyboard on outside taps.
- New `OmniApp(doubleBackToExit:, onExitWarning:)`: Android "press back
  again to exit" on the first page; other pages and platforms unchanged.
- New `OmniApp(orientations:)`: preferred orientations, reset on dispose.
- New `OmniApp(minTextScale:, maxTextScale:)`: clamp the system text scale.
- New `OmniApp(blocObserver:)`: installs `Bloc.observer`, restored on dispose.
- New `OmniApp(onError:)`: receives Flutter and platform errors (previous
  handlers still run; default reporting is kept); restored on dispose.

## 0.2.2

No API changes; purely additive.

- New: `OmniLifecycle` mixin — lifecycle hooks for both screen types without
  `WidgetsBindingObserver` boilerplate. Opt in with `with OmniLifecycle` on
  an `OmniStatelessWidget` or an `OmniState`; registration and cleanup are
  automatic. Hooks: `onAppLifecycleChanged`, `onAppResumed`,
  `onAppInactive`, `onAppHidden`, `onAppPaused`, `onAppDetached`,
  `onScreenVisible`, `onScreenHidden` (push/pop/tab), `onMemoryPressure`,
  `onMetricsChanged`, `onBrightnessChanged`, `onLocalesChanged`,
  `onTextScaleChanged`. Screens without the mixin are unaffected.

## 0.2.1

No API changes; all 0.2.0 code keeps compiling and behaving the same,
except for the two bug fixes below.

- Fix: guards passed to `OmniPage(guards:)` now re-run when their `refresh`
  stream emits (only `OmniApp(guards:)` were listened to). A guard object
  shared by several routes is subscribed once.
- Fix: `onNavigate` now reports a new page at the same location (pushing
  the same URL twice, popping back to it). Re-going to the current page
  still reports nothing.
- New: `OmniParams.queryBool`, `queryDouble`, `queryEnum`.
- New: `OmniRoute.maybePop`, `refresh`, `replaceTo<S>`, `replaceNamed`.
- Better error: `missingRoute` explains the `List<OmniPage>` type-inference
  trap that hides a route's screen type.

## 0.2.0

- Fix: a stateless screen shown outside a route now creates its own
  `provide` Blocs (it failed with `ProviderNotFoundException`).
- New: `OmniScreenHost` for stateful screens shown outside a route; a clear
  `OmniErrorCode.screenNotHosted` error is reported otherwise.
- Fix: duplicate route `name`s are rejected at startup in release builds too
  (previously only a go_router debug assert).
- New: `OmniRouteGroup` — route scope. Blocs shared by a group of routes,
  created on entering the group and closed on leaving it; `scopeKey`
  recreates them when e.g. the `:id` changes. Built on go_router `ShellRoute`.
- New: `OmniParams.of(context)` — read route parameters without subscribing,
  safe in Bloc `create` callbacks and `initState`.
- Example: student detail and edit share Blocs through `OmniRouteGroup`.
- Fix: page type, title setting and not-found page are now per `OmniApp`
  (were package-level variables: a second `OmniApp` overwrote the first's).
- `OmniRoute` helpers with several mounted apps act on the most recent one
  and fall back to the previous one when it is disposed.
- New: `OmniApp(restorationScopeId:)`; built-in page types set a stable
  `restorationId`, so the route stack, pushed pages, shell tabs and
  `Restorable*` widget state survive a restart. Blocs are recreated.
- Fix: `OmniRoute.location` ignored pages added with `push` and returned the
  location underneath them.
- New: `OmniPage(metadata:)` (go_router route metadata; readable in guards
  via `state.metadata`).
- New: `OmniRoute.current`, `OmniRoute.stack` (pages bottom→top through
  shells and pushes), `OmniRoute.state`; `OmniRouteEntry` type.
- New: `OmniApp(onNavigate:)` hook (`OmniNavigation` from/to/uri, no
  duplicate events) and `OmniApp(logNavigation: true)` (debug builds only).
- Docs: architecture, lifecycle & Bloc ownership guide (`doc/architecture.md`),
  migration guide (`doc/migration.md`), README sections for all new APIs.

## 0.1.0

First release.

### Development history

- Phase 2: `OmniStatelessWidget`, `OmniStatefulWidget`, `OmniState`, `OmniScreenMetadata`, `OmniRouteException`, route path validation.
- Phase 3: `OmniBloc` factory registry (global/screen), `Provide` / `Provide.create` / `Provide.value`, `OmniGlobalBlocScope`, `OmniBlocScope`, `provide` on screens.
- Phase 4: `OmniApp` (single GoRouter), `OmniPage` (compiles to GoRoute, wraps screen Bloc scope), `OmniParams`, `OmniRoute` navigation helpers incl. typed `to<S>()`, route validation at startup, not-found/invalid-param error page.
- Phase 5: `OmniShell`, `OmniStatefulShell` (with shell-scoped Blocs), `OmniGuard` (app-wide + per-route, sync/async, Bloc-stream refresh, self-redirect ignored, loops caught by GoRouter), deep-link test.
- Phase 6: `OmniRoute.usePathUrls()`, trailing-slash normalization, browser title from screen `title` (follows pop and tab switches), `OmniApp(setTitles:)`, web hosting docs (`doc/web.md`), example app.
- Phase 7: leak tracking on all tests (2 error-path leaks fixed), long-session/rebuild/tab-switch/large-registry tests, profile benchmark vs raw GoRouter (`example/benchmark`), report in `doc/performance.md`.
- Phase 8: `OmniApp(pageType:)` / `OmniPage(pageType:)` with `OmniPages.material|cupertino|none`, desktop back (Alt+←, Cmd+[, mouse back, optional Escape), per-platform tests, platform guide (`doc/platforms.md`).
- Phase 9: README, complete example + flow test, API docs for all public members, LICENSE (MIT).
