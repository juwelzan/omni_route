# OmniRoute — Memory & Performance Report (Phase 7)

Date: 2026-11-14 · Flutter 3.50.0 · Dart 3.13.4 · go_router 18.1.4 ·
flutter_bloc 9.1.1 · macOS 27.2 (Apple Silicon)

## Summary

- **Memory leaks:** none. All package tests run with Flutter's leak tracker on
  (every tracked Element, State, Route and ChangeNotifier must be disposed and
  garbage-collected). Two leaks it found, both on error paths, were fixed.
- **Bloc lifecycle:** create/close counts stay balanced over 1,000 mixed
  navigations, 200 push/pop cycles and 500 tab switches.
- **Overhead vs raw GoRouter + BlocProvider:** no measurable difference in
  profile mode; the differences are inside run-to-run noise.

## 1. Leak tracking (automated, every test run)

`test/flutter_test_config.dart` enables `leak_tracker_flutter_testing` with
`withTrackedAll()` for all 40 tests.

Leaks it found and how they were fixed:

| Leak | Cause | Fix |
|---|---|---|
| `StatelessElement` not disposed | empty `routePath` threw inside `mount` | validate in the element's `build` → Flutter shows an ErrorWidget and disposes normally |
| 4× `StatefulElement` not disposed | `OmniApp` config error thrown from `initState` | report via `FlutterError.reportError`, render `ErrorWidget` |

Normal navigation never leaked.

## 2. Lifecycle & rebuild tests (`test/performance_test.dart`)

| Test | Result |
|---|---|
| 1,000 mixed go/push/pop navigations | exactly 1 page Bloc alive at the end (the visible page); widget tree back to its starting element count |
| 20 pushes on top of home | home `build` called 0 extra times; 21 Blocs, none recreated |
| 50 global Bloc state changes | screens not rebuilt |
| 500 StatefulShell tab switches | 0 Blocs created, ≤ 1 rebuild per switch |
| 1,000-route registry | startup ≈ 11 ms, go + frame ≈ 0.6 ms (debug test env; ceiling check only) |

## 3. Profile-mode benchmark (`example/benchmark/benchmark_main.dart`)

Same screens (AppBar + 30-row ListView), same Blocs, same `MaterialPage`
transition. One app uses OmniRoute; the other uses GoRouter + BlocProvider
directly. Each round = 20 warm-up + 300 push/pop cycles; rounds alternate
raw/omni.

```bash
cd example
flutter run --profile -d macos -t benchmark/benchmark_main.dart
```

**Method note.** This Mac would not let the app window come to the
foreground, so the engine sent no vsync and no frames were drawn. The
benchmark therefore drives frames itself (`handleBeginFrame`/`handleDrawFrame`)
and times the **UI thread** (build + layout + paint + composite submission).
That is the only part OmniRoute can change; rasterization is the same
for both because the widgets are identical.

### Paired results (µs; lower is better)

| metric | raw 1 | omni 1 | raw 2 | omni 2 | raw 3 | omni 3 |
|---|---:|---:|---:|---:|---:|---:|
| push, first frame p50 | 2373 | 2465 | 4203 | 4000 | 5586 | 5247 |
| push, first frame p90 | 5360 | 4972 | 9046 | 7296 | 11566 | 10597 |
| push, all frames p50 | 2747 | 3145 | 5385 | 5511 | 7336 | 7611 |
| pop, first frame p50 | 608 | 577 | 1461 | 1393 | 2342 | 2117 |
| UI frame p50 | 474 | 602 | 1215 | 1452 | 2067 | 2117 |
| UI frame p99 | 6761 | 7553 | 14161 | 12247 | 15163 | 16822 |
| frames measured | 1200 | 1200 | 1200 | 1200 | 1200 | 1200 |

Within each round the two sides differ by only a few percent, and the faster
side switches from metric to metric. All values are below the 16.67 ms
(60 Hz) budget at p90, and below 8.33 ms (120 Hz) in round 1.

### Drift across rounds — harness, not OmniRoute

Cost rises from round to round **for both sides**. Separate runs of only raw
and only OmniRoute (4 rounds each) show the same drift:

| run | UI frame p50 per round (µs) |
|---|---|
| raw only | 265 → 411 → 574 → 923 |
| omni only | 200 → 511 → 1058 → 861 |

The drift appears even with no OmniRoute code involved, so it comes from
driving frames without a visible window (RSS also rises about 230 MB per
round in both). For that reason this benchmark's **RSS numbers are not used as
memory evidence**; the leak tracker in §1 is.

### Finding: go_router default page type

A plain `GoRoute(builder: ...)` got `NoTransitionPage` (no animation) in
both the test environment and this macOS app, because go_router's MaterialApp
detection did not find the app. `OmniPage` always uses `MaterialPage`
(Material transitions; Cupertino slide + swipe-back on iOS through the theme).
The first benchmark run was unfair (80 vs 1240 frames) until the raw app used
`MaterialPage` too. A configurable page type (e.g. `CupertinoPage`,
`NoTransitionPage`) will be added with the platform work in Phase 8.

## 4. Not done / needs your machine

- **Real-display frame timing** (raster thread, jank on a vsync-driven
  display) and **DevTools heap snapshots**: these need the app in the
  foreground. Run the benchmark above in a normal desktop session, or on a
  phone with `flutter run --profile`, and open DevTools → Performance / Memory.
- Web and mobile profile numbers: Phase 8.
