import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:logger/logger.dart';

import '../errors/omni_route_exception.dart';
import '../routing/omni_page.dart';
import '../routing/omni_params.dart';
import '../routing/omni_route_registry.dart';
import '../routing/omni_route_state.dart';
import 'omni_log.dart';
import 'omni_route_entry.dart';
import 'omni_router.dart';

/// Global navigation facade and router inspection API for the active [OmniApp].
///
/// All calls operate instantaneously on the native [OmniRouter] engine with
/// zero lazy frame waits. Every navigation helper supports `animated: false`
/// for immediate instant jumps or `transition:` to override a page transition
/// per call.
///
/// With multiple [OmniApp] instances mounted concurrently, static helpers
/// target the most recently mounted app; inside widget trees, [OmniRouteContext]
/// (`context.go`, `context.to<S>`, `context.params`, ...) always targets the
/// nearest ancestor [OmniApp].
abstract final class OmniRoute {
  static final List<(OmniRouter, OmniRouteRegistry)> _apps = [];

  static OmniRouter? get _router => _apps.isEmpty ? null : _apps.last.$1;
  static OmniRouteRegistry? get _registry =>
      _apps.isEmpty ? null : _apps.last.$2;

  /// Use clean path URLs on the web (`/students/101` instead of `/#/students/101`).
  /// Call once in `main()` before `runApp`. No-op on other platforms.
  static void usePathUrls() => usePathUrlStrategy();

  /// Logger receiving `OmniApp(logNavigation: true)` and guard warnings.
  static Logger logger = defaultOmniLogger();

  /// The active [OmniRouter] driving the mounted [OmniApp].
  static OmniRouter get router =>
      _router ??
      (throw const OmniRouteException(
        OmniErrorCode.notInitialized,
        'No OmniApp is mounted.',
        hint: 'Navigate after OmniApp is built, or use context.go(...).',
      ));

  /// Registers [r] and [reg] for static helpers. Called by [OmniApp].
  @internal
  static void attach(OmniRouter r, OmniRouteRegistry reg) => _apps.add((r, reg));

  /// Updates [reg] during Hot Reload without altering active ordering.
  @internal
  static void updateRegistry(OmniRouter r, OmniRouteRegistry reg) {
    final i = _apps.indexWhere((e) => identical(e.$1, r));
    if (i >= 0) _apps[i] = (r, reg);
  }

  /// Detaches [r]; the previously mounted app (if any) becomes active.
  @internal
  static void detach(OmniRouter r) =>
      _apps.removeWhere((app) => identical(app.$1, r));

  /// Looks up the [OmniRouteRegistry] associated with [router].
  @internal
  static OmniRouteRegistry registryOf(OmniRouter router) {
    for (var i = _apps.length - 1; i >= 0; i--) {
      if (identical(_apps[i].$1, router)) return _apps[i].$2;
    }
    return _registry!;
  }

  /// Current location URI including query and pushed pages.
  static Uri get location => router.location;

  /// Full [OmniRouteState] for the page currently on top.
  static OmniRouteState get state => router.state;

  /// Top navigation entry in the active stack.
  static OmniRouteEntry get current => router.currentEntry;

  /// Reactive listenable emitting the active top [OmniRouteEntry].
  static ValueListenable<OmniRouteEntry> get currentListenable =>
      router.currentListenable;

  /// Active navigation stack from bottom to top, across active shells/tabs.
  static List<OmniRouteEntry> get stack => router.stackEntries;

  /// Replace the current stack declaratively with [location].
  ///
  /// Set [animated] to `false` for instant zero-transition display, or pass
  /// [transition] to override the animation for this navigation only.
  static void go(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => router.go(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Push [location] onto the active stack; completes with the pop result.
  static Future<T?> push<T extends Object?>(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => router.push<T>(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Replace the top page with [location] without changing stack depth.
  static void replace(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => router.replace(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Pop the top page, completing its `push` future with [result].
  static void pop<T extends Object?>([T? result]) => router.pop<T>(result);

  /// Whether there is at least one page to pop on the active or root stack.
  static bool canPop() => router.canPop();

  /// Pop the top page if possible and return `true`; safe on the root page.
  static bool maybePop<T extends Object?>([T? result]) =>
      router.maybePop<T>(result);

  /// Smart duplicate-free navigation in a single synchronous frame:
  /// - Already on top with same query/extra: no-op
  /// - Already in active stack: pops synchronously back to it
  /// - Stack at or above [maxDepth]: replaces stack via [go]
  /// - Otherwise pushes onto the stack.
  static Future<T?> open<T extends Object?>(
    String location, {
    Object? extra,
    int maxDepth = 10,
    bool animated = true,
    OmniPageType? transition,
  }) => router.open<T>(
    location,
    extra: extra,
    maxDepth: maxDepth,
    animated: animated,
    transition: transition,
  );

  /// [open] targeting the route that renders widget/screen [S].
  static Future<Object?> openTo<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    int maxDepth = 10,
    bool animated = true,
    OmniPageType? transition,
  }) => open<Object?>(
    locationOf<S>(path: path, query: query),
    extra: extra,
    maxDepth: maxDepth,
    animated: animated,
    transition: transition,
  );

  /// Synchronously pop pages until [location] (`Uri.path`) is on top.
  /// Returns `false` (and changes nothing) if [location] is absent from stack.
  static Future<bool> popUntil(String location) => router.popUntil(location);

  /// Synchronously pop all pages back to the root of the active stack/tab.
  static Future<void> popToRoot() => router.popToRoot();

  /// Re-run guards and redirects for the current location immediately.
  static void refresh() => router.refresh();

  /// Replace the top page with the route named [name].
  static void replaceNamed(
    String name, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => replace(
    locationNamed(name, path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Navigate declaratively via [go] to the route named [name].
  static void goNamed(
    String name, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => go(
    locationNamed(name, path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Push the route named [name] onto the active stack.
  static Future<T?> pushNamed<T extends Object?>(
    String name, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => push<T>(
    locationNamed(name, path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Resolve the URL string for named route [name].
  static String locationNamed(
    String name, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
  }) {
    final compiled = _registryOfRouter(router).routeNamed(name);
    return OmniRouteRegistry.location(
      compiled.fullPath,
      params: path,
      query: query,
    );
  }

  /// Resolve the URL string for widget/screen [S].
  static String locationOf<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
  }) {
    final r = router;
    return OmniRouteRegistry.location(
      registryOf(r).pathFor(S),
      params: path,
      query: query,
    );
  }

  static OmniRouteRegistry _registryOfRouter(OmniRouter r) => registryOf(r);

  /// Replace the top page with the route building widget/screen [S].
  static void replaceTo<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => replace(
    locationOf<S>(path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Navigate declaratively via [go] to the route building widget/screen [S].
  static void to<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => go(
    locationOf<S>(path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Push the route building widget/screen [S] onto the active stack.
  static Future<T?> pushTo<S extends Widget, T extends Object?>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => push<T>(
    locationOf<S>(path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
  );
}

/// Concise navigation and route-parameter helpers directly on [BuildContext].
///
/// Targets the nearest enclosing [OmniApp] router (falling back to the global
/// [OmniRoute.router] if invoked at the root), making multi-window apps and
/// everyday screen navigation effortless:
///
/// ```dart
/// context.params.pathInt('id');
/// context.to<DetailScreen>(path: {'id': 42});
/// context.push('/settings', animated: false);
/// context.pop();
/// ```
extension OmniRouteContext on BuildContext {
  OmniRouter get _omniRouter => OmniRouter.maybeOf(this) ?? OmniRoute.router;

  /// Typed route parameters for the current page.
  OmniParams get params => OmniParams.of(this);

  /// Current [OmniRouteState] for the page above this context.
  OmniRouteState get routeState => OmniRouteState.of(this);

  /// Replace the stack declaratively with [location].
  void go(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => _omniRouter.go(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Push [location] onto this app's active stack.
  Future<T?> push<T extends Object?>(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => _omniRouter.push<T>(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Replace the top page on this app's active stack.
  void replace(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => _omniRouter.replace(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Smart duplicate-free open onto this app's active stack.
  Future<T?> open<T extends Object?>(
    String location, {
    Object? extra,
    int maxDepth = 10,
    bool animated = true,
    OmniPageType? transition,
  }) => _omniRouter.open<T>(
    location,
    extra: extra,
    maxDepth: maxDepth,
    animated: animated,
    transition: transition,
  );

  /// Pop the top page from this app's active stack.
  void pop<T extends Object?>([T? result]) => _omniRouter.pop<T>(result);

  /// Whether this app's router can pop.
  bool canPop() => _omniRouter.canPop();

  /// [go] to the route rendering [S] in this app.
  void to<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) {
    final r = _omniRouter;
    final loc = OmniRouteRegistry.location(
      OmniRoute.registryOf(r).pathFor(S),
      params: path,
      query: query,
    );
    r.go(loc, extra: extra, animated: animated, transition: transition);
  }

  /// [push] the route rendering [S] in this app.
  Future<T?> pushTo<S extends Widget, T extends Object?>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) {
    final r = _omniRouter;
    final loc = OmniRouteRegistry.location(
      OmniRoute.registryOf(r).pathFor(S),
      params: path,
      query: query,
    );
    return r.push<T>(
      loc,
      extra: extra,
      animated: animated,
      transition: transition,
    );
  }

  /// [replace] the top page with the route rendering [S] in this app.
  void replaceTo<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) {
    final r = _omniRouter;
    final loc = OmniRouteRegistry.location(
      OmniRoute.registryOf(r).pathFor(S),
      params: path,
      query: query,
    );
    r.replace(loc, extra: extra, animated: animated, transition: transition);
  }
}
