import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/omni_bloc.dart';
import '../core/omni_route.dart';
import '../errors/omni_route_exception.dart';
import '../routing/omni_page.dart';
import '../routing/omni_params.dart';
import '../routing/omni_route_state.dart';

import 'omni_lifecycle.dart';
import 'omni_screen.dart';
import 'omni_screen_host.dart';

/// A [StatefulWidget] screen with canonical [routePath] identity and page-entry
/// Bloc hosting. Pair with [OmniState].
///
/// ```dart
/// class DashboardScreen extends OmniStatefulWidget {
///   const DashboardScreen({super.key});
///
///   @override
///   String get routePath => '/dashboard';
///
///   @override
///   State<DashboardScreen> createState() => _DashboardState();
/// }
/// ```
abstract class OmniStatefulWidget extends StatefulWidget with OmniScreen {
  /// Creates a stateful screen.
  const OmniStatefulWidget({super.key});

  @override
  State<OmniStatefulWidget> createState();

  @override
  StatefulElement createElement() => _OmniStatefulElement(this);
}

class _OmniStatefulElement extends StatefulElement {
  _OmniStatefulElement(OmniStatefulWidget super.widget);

  // Widget types already reported for OmniLifecycle-on-the-widget, so the
  // mistake is reported once per type, not on every rebuild or page.
  static final Set<Type> _reportedLifecycleOnWidget = {};

  // Only States that mix in OmniLifecycle get a hub (no cost otherwise).
  OmniLifecycleHub? _lifecycle;

  @override
  void unmount() {
    _lifecycle?.dispose();
    _lifecycle = null;
    super.unmount();
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    // Reported (not thrown) before initState runs, so the cause is shown
    // first and the element still mounts and disposes normally.
    final screen = widget as OmniStatefulWidget;
    if (!isHosted(parent, screen)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: notHostedError(screen),
          library: 'omni_route',
        ),
      );
    }
    if (kDebugMode &&
        screen is OmniLifecycle &&
        state is! OmniLifecycle &&
        _reportedLifecycleOnWidget.add(screen.runtimeType)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: OmniRouteException(
            OmniErrorCode.lifecycleOnWidget,
            '${screen.runtimeType} mixes in OmniLifecycle, but hooks on a '
            'stateful screen run on its State, so they would never be called.',
            hint:
                'Mix OmniLifecycle into your OmniState instead: '
                'class _${screen.runtimeType}State extends '
                'OmniState<${screen.runtimeType}> with OmniLifecycle.',
          ),
          library: 'omni_route',
        ),
      );
    }
    if (state is OmniLifecycle) {
      _lifecycle = OmniLifecycleHub(
        this,
        () => state is OmniLifecycle ? state as OmniLifecycle : null,
      );
    }
    super.mount(parent, newSlot);
    if (state case final OmniState omniState) {
      omniState._scheduleReady();
    }
  }

  @override
  Widget build() {
    validateScreen(widget as OmniScreen);
    final built = super.build();
    return _lifecycle?.wrap(built) ?? built;
  }
}

/// Enhanced [State] for an [OmniStatefulWidget].
///
/// Preserves standard Flutter lifecycles (`initState`, `didChangeDependencies`,
/// `didUpdateWidget`, `dispose`) while providing:
/// - Canonical screen accessors: [routePath], [screenTitle], [metadata]
/// - `initState`-safe & reactive route state: [routeState], [maybeRouteState],
///   [params], [maybeParams]
/// - Post-frame [onReady] & param/query-only [onRouteChanged] callbacks
/// - Async-safe [safeSetState] & concise Bloc/navigation shortcuts (`bloc`,
///   `watchBloc`, `go`, `push`, `open`, `replace`, `pop`, `to`, `pushTo`, ...)
abstract class OmniState<T extends OmniStatefulWidget> extends State<T> {
  bool _depsReady = false;
  OmniRouteState? _lastRouteState;

  void _scheduleReady() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) onReady(context);
    });
  }

  @mustCallSuper
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _depsReady = true;
    final current = OmniRouteState.maybeOf(context);
    if (current != null) {
      final previous = _lastRouteState;
      _lastRouteState = current;
      if (previous != null && previous != current) {
        onRouteChanged(previous, current);
      }
    }
  }

  /// Called once after the first frame when this state is still [mounted].
  @protected
  void onReady(BuildContext context) {}

  /// Called when the current route's [OmniRouteState] changes while this page
  /// stays mounted (for example query parameter updates `?tab=2`), without
  /// firing on unrelated `Theme` or `MediaQuery` changes.
  @protected
  void onRouteChanged(OmniRouteState previous, OmniRouteState current) {}

  /// Canonical [OmniScreen.routePath] of the current widget.
  String get routePath => widget.routePath;

  /// Human-readable [OmniScreen.title] of the current widget.
  String get screenTitle => widget.title;

  /// Metadata of the current widget.
  OmniScreenMetadata get metadata => widget.metadata;

  /// Route state of the page this screen is on (path, query, extra).
  ///
  /// Safe inside `initState` (reads without subscribing) and reactive inside
  /// `build` / `didChangeDependencies`.
  OmniRouteState get routeState =>
      _depsReady ? OmniRouteState.of(context) : OmniRouteState.readOf(context);

  /// Route state of the enclosing [OmniPage], or `null` when embedded outside
  /// a route.
  OmniRouteState? get maybeRouteState => _depsReady
      ? OmniRouteState.maybeOf(context)
      : OmniRouteState.readMaybeOf(context);

  /// Typed route parameters for this page (`initState`-safe).
  OmniParams get params => OmniParams.of(context);

  /// Typed route parameters for this page, or `null` when outside a route.
  OmniParams? get maybeParams => OmniParams.maybeOf(context);

  /// Calls [setState] only if this `State` is still [mounted].
  @protected
  void safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  /// Reads Bloc [B] once without subscribing to rebuilds.
  @protected
  B readBloc<B extends OmniAnyBloc>() =>
      BlocProvider.of<B>(context, listen: false);

  /// Watches Bloc [B], rebuilding whenever its state changes.
  @protected
  B watchBloc<B extends OmniAnyBloc>() =>
      BlocProvider.of<B>(context, listen: true);

  /// Declaratively replace the navigation stack with [location].
  @protected
  void go(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
    bool replaceHistory = false,
  }) => context.go(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
    replaceHistory: replaceHistory,
  );

  /// Push [location] onto the active stack; completes with its pop result.
  @protected
  Future<R?> push<R extends Object?>(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => context.push<R>(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Replace the top page on the active stack with [location].
  @protected
  void replace(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => context.replace(
    location,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Smart duplicate-free open of [location].
  @protected
  Future<R?> open<R extends Object?>(
    String location, {
    Object? extra,
    int maxDepth = 10,
    bool animated = true,
    OmniPageType? transition,
  }) => context.open<R>(
    location,
    extra: extra,
    maxDepth: maxDepth,
    animated: animated,
    transition: transition,
  );

  /// Navigate via `go` to screen type [S].
  @protected
  void to<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
    bool replaceHistory = false,
  }) => context.to<S>(
    path: path,
    query: query,
    extra: extra,
    animated: animated,
    transition: transition,
    replaceHistory: replaceHistory,
  );

  /// Replace the current top page with screen type [S].
  @protected
  void replaceTo<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => context.replaceTo<S>(
    path: path,
    query: query,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Push screen type [S] onto the active stack.
  @protected
  Future<R?> pushTo<S extends Widget, R extends Object?>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => context.pushTo<S, R>(
    path: path,
    query: query,
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Smart duplicate-free `openTo` screen type [S].
  @protected
  Future<Object?> openTo<S extends Widget>({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    int maxDepth = 10,
    bool animated = true,
    OmniPageType? transition,
  }) => context.openTo<S>(
    path: path,
    query: query,
    extra: extra,
    maxDepth: maxDepth,
    animated: animated,
    transition: transition,
  );

  /// Pop the current page with an optional [result].
  @protected
  void pop<R extends Object?>([R? result]) => context.pop<R>(result);

  /// Pop if possible and return `true`; safe on the root page.
  @protected
  bool maybePop<R extends Object?>([R? result]) => context.maybePop<R>(result);

  /// Whether the active or root stack can pop.
  @protected
  bool canPop() => context.canPop();
}
