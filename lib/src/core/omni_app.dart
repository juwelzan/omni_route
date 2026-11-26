import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/omni_bloc.dart';
import '../bloc/omni_bloc_scope.dart';
import '../guards/omni_guard.dart';
import '../routing/omni_page.dart';
import '../routing/omni_route_registry.dart';
import '../routing/omni_route_state.dart';
import '../routing/omni_swipe_back.dart';
import '../screens/omni_lifecycle.dart';
import 'omni_app_features.dart';
import 'omni_desktop_back.dart';
import 'omni_log.dart';
import 'omni_route.dart';
import 'omni_route_entry.dart';
import 'omni_router.dart';

/// Builds your app widget (`MaterialApp.router`, `CupertinoApp.router`, etc.)
/// around the [OmniRouter] created by [OmniApp].
typedef OmniAppBuilder =
    Widget Function(BuildContext context, OmniRouter router);

/// Root of an OmniRoute application.
///
/// Compiles [routes] once into a fast Segment Trie, provides global Blocs,
/// subscribes guard refresh streams, configures platform features (swipe back,
/// predictive back, desktop back, titles, state restoration, startup gating),
/// and hands the native [OmniRouter] to [builder]:
///
/// ```dart
/// OmniApp(
///   initialRoute: '/dashboard',
///   transition: OmniPages.fadeSlide,
///   blocs: [OmniBloc<AuthBloc>((_) => AuthBloc(), global: true)],
///   routes: [OmniPage<DashboardScreen>('/dashboard', (_) => const DashboardScreen())],
///   builder: (context, router) => MaterialApp.router(routerConfig: router),
/// )
/// ```
class OmniApp extends StatefulWidget {
  /// Creates the root of an OmniRoute application.
  const OmniApp({
    super.key,
    required this.routes,
    required this.builder,
    this.blocs = const [],
    this.initialRoute = '/',
    this.transition = OmniPages.material,
    this.guards = const [],
    this.refreshListenable,
    this.notFound,
    this.navigatorKey,
    this.observers,
    this.setTitles = true,
    this.titleColor,
    this.swipeBack = OmniSwipeBack.none,
    this.swipeBackStyle = const OmniSwipeBackStyle(),
    this.predictiveBack = false,
    this.desktopBack = true,
    this.escapeGoesBack = false,
    this.restorationScopeId,
    this.onNavigate,
    this.logNavigation = false,
    this.lifecycle,
    this.onInit,
    this.splash,
    this.dismissKeyboardOnTap = false,
    this.doubleBackToExit,
    this.onExitWarning,
    this.orientations,
    this.minTextScale,
    this.maxTextScale,
    this.blocObserver,
    this.onError,
  });

  /// Declarative routes (`OmniPage`, `OmniRouteGroup`, `OmniShell`,
  /// `OmniStatefulShell`).
  final List<OmniRouteBase> routes;

  /// Builds your app widget (`MaterialApp.router`) with the router.
  final OmniAppBuilder builder;

  /// Bloc factories; entries with `global: true` stay alive for the app.
  final List<OmniBloc> blocs;

  /// Location shown on startup when no platform deep link is active.
  final String initialRoute;

  /// Default page transition used for every [OmniPage] unless overridden per
  /// route, per group, or per navigation call (`animated: false` / `transition:`).
  final OmniPageType transition;

  /// App-wide guards evaluated in order on every navigation.
  final List<OmniGuard> guards;

  /// External listenable whose notifications re-evaluate guards.
  final Listenable? refreshListenable;

  /// Builder for unknown URLs, bad parameters, or guard redirect loops.
  final OmniErrorBuilder? notFound;

  /// Key of the root [Navigator].
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Observers attached to the root [Navigator].
  final List<NavigatorObserver>? observers;

  /// Update browser tab / OS recent-apps title from the visible page title.
  final bool setTitles;

  /// App-switcher colour set alongside the active page title.
  final Color? titleColor;

  /// Default edge swipe-back style for animated [OmniPages].
  final OmniSwipeBack swipeBack;

  /// Default tuning parameters for [swipeBack].
  final OmniSwipeBackStyle swipeBackStyle;

  /// Track Android predictive back gestures across routes.
  final bool predictiveBack;

  /// Enable Alt+Left / Cmd+[ / mouse-back keyboard shortcuts on desktop.
  final bool desktopBack;

  /// Allow Escape to navigate back on desktop (after closing dialogs).
  final bool escapeGoesBack;

  /// State restoration bucket ID for route stack & branch persistence.
  final String? restorationScopeId;

  /// Invoked when the active top route changes.
  final void Function(OmniNavigation navigation)? onNavigate;

  /// Logs navigations in debug builds via [OmniRoute.logger].
  final bool logNavigation;

  /// App-wide foreground/background/memory lifecycle callbacks.
  final OmniLifecycle? lifecycle;

  /// One-time startup async task executed while displaying [splash].
  final Future<void> Function(BuildContext context)? onInit;

  /// Widget shown while [onInit] completes.
  final WidgetBuilder? splash;

  /// Automatically unfocus text fields when tapping outside them.
  final bool dismissKeyboardOnTap;

  /// Require two back presses within this duration to exit on Android root.
  final Duration? doubleBackToExit;

  /// Triggered on the first back press when [doubleBackToExit] is active.
  final void Function(BuildContext context)? onExitWarning;

  /// Allowed device orientations while this app is mounted.
  final List<DeviceOrientation>? orientations;

  /// Minimum system accessibility text scale factor.
  final double? minTextScale;

  /// Maximum system accessibility text scale factor.
  final double? maxTextScale;

  /// App-wide `Bloc.observer` restored automatically when unmounted.
  final BlocObserver? blocObserver;

  /// Global uncaught Flutter & platform error handler restored on dispose.
  final void Function(Object error, StackTrace stack)? onError;

  @override
  State<OmniApp> createState() => _OmniAppState();
}

class _OmniAppState extends State<OmniApp> {
  late final OmniBlocRegistry _blocs;
  late final GlobalKey<NavigatorState> _navKey;
  List<OmniGuard> _refreshGuards = const [];
  OmniRouter? _router;
  Object? _configError;
  final GuardNotifier _guardRefresh = GuardNotifier();

  OmniRouteEntry? _last;
  Uri? _lastUri;
  LocalKey? _lastPageKey;

  @override
  void initState() {
    super.initState();
    _installGlobals();
    try {
      _blocs = OmniBlocRegistry(widget.blocs);
      _navKey =
          widget.navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'OmniRoot');
      final registry = OmniRouteRegistry(
        widget.routes,
        rootNavigatorKey: _navKey,
      );
      _refreshGuards = {...widget.guards, ...registry.routeGuards}.toList();

      final platformDefault = PlatformDispatcher.instance.defaultRouteName;
      final start = (platformDefault.isNotEmpty && platformDefault != '/')
          ? platformDefault
          : widget.initialRoute;

      final router = _router = OmniRouter(
        routeRegistry: registry,
        navigatorKey: _navKey,
        guards: widget.guards,
        observers: widget.observers ?? const [],
        onRouteError: widget.notFound ?? defaultOmniErrorBuilder,
        initialRoute: start,
        restorationScopeId: widget.restorationScopeId,
        refresh: widget.refreshListenable == null
            ? _guardRefresh
            : Listenable.merge([_guardRefresh, widget.refreshListenable]),
        onReady: () {
          if (mounted &&
              (widget.onNavigate != null || widget.logNavigation)) {
            _navigated();
          }
        },
      );
      OmniRoute.attach(router, registry);
      if (widget.onNavigate != null || widget.logNavigation) {
        router.routerDelegate.addListener(_navigated);
      }
    } catch (e, stack) {
      _configError = e;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'omni_route',
          context: ErrorDescription('while configuring OmniApp'),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(OmniApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final router = _router;
    if (router == null) return;

    if (!identical(widget.routes, oldWidget.routes) ||
        !identical(widget.guards, oldWidget.guards) ||
        !identical(widget.observers, oldWidget.observers) ||
        !identical(widget.notFound, oldWidget.notFound) ||
        !identical(widget.refreshListenable, oldWidget.refreshListenable)) {
      try {
        final registry = OmniRouteRegistry(
          widget.routes,
          rootNavigatorKey: _navKey,
        );
        OmniRoute.updateRegistry(router, registry);
        router.updateConfig(
          registry: registry,
          guards: widget.guards,
          observers: widget.observers ?? const [],
          errorBuilder: widget.notFound ?? defaultOmniErrorBuilder,
          refreshListenable: widget.refreshListenable == null
              ? _guardRefresh
              : Listenable.merge([_guardRefresh, widget.refreshListenable]),
        );
      } catch (e, stack) {
        _configError = e;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stack,
            library: 'omni_route',
            context: ErrorDescription('while updating OmniApp routes'),
          ),
        );
      }
    }
  }

  void _navigated() {
    final router = _router!;
    final state = router.state;
    if (state.uri == _lastUri && state.pageKey == _lastPageKey) return;
    final to = router.currentEntry;
    final event = OmniNavigation(from: _last, to: to, uri: state.uri);
    _last = to;
    _lastUri = state.uri;
    _lastPageKey = state.pageKey;
    if (widget.logNavigation && kDebugMode) {
      OmniRoute.logger.i(navigationMessage(event));
    }
    widget.onNavigate?.call(event);
  }

  FlutterExceptionHandler? _prevFlutterOnError;
  FlutterExceptionHandler? _ourFlutterOnError;
  bool Function(Object, StackTrace)? _prevPlatformOnError;
  bool Function(Object, StackTrace)? _ourPlatformOnError;
  BlocObserver? _prevBlocObserver;

  void _installGlobals() {
    final onError = widget.onError;
    if (onError != null) {
      _prevFlutterOnError = FlutterError.onError;
      FlutterError.onError = _ourFlutterOnError = (details) {
        onError(details.exception, details.stack ?? StackTrace.empty);
        _prevFlutterOnError?.call(details);
      };
      final dispatcher = PlatformDispatcher.instance;
      _prevPlatformOnError = dispatcher.onError;
      dispatcher.onError = _ourPlatformOnError = (error, stack) {
        onError(error, stack);
        return _prevPlatformOnError?.call(error, stack) ?? false;
      };
    }
    final observer = widget.blocObserver;
    if (observer != null) {
      _prevBlocObserver = Bloc.observer;
      Bloc.observer = observer;
    }
    final orientations = widget.orientations;
    if (orientations != null) {
      SystemChrome.setPreferredOrientations(orientations);
    }
  }

  void _restoreGlobals() {
    if (_ourFlutterOnError != null &&
        identical(FlutterError.onError, _ourFlutterOnError)) {
      FlutterError.onError = _prevFlutterOnError;
    }
    final dispatcher = PlatformDispatcher.instance;
    if (_ourPlatformOnError != null &&
        identical(dispatcher.onError, _ourPlatformOnError)) {
      dispatcher.onError = _prevPlatformOnError;
    }
    final prevObserver = _prevBlocObserver;
    if (prevObserver != null && identical(Bloc.observer, widget.blocObserver)) {
      Bloc.observer = prevObserver;
    }
    if (widget.orientations != null) {
      SystemChrome.setPreferredOrientations(const []);
    }
  }

  @override
  void dispose() {
    _restoreGlobals();
    final router = _router;
    if (router != null) {
      router.routerDelegate.removeListener(_navigated);
      OmniRoute.detach(router);
      router.dispose();
    }
    _guardRefresh.dispose();
    super.dispose();
  }

  Widget _wrapApp(Widget app) {
    var child = app;
    if (widget.minTextScale != null || widget.maxTextScale != null) {
      final inner = child;
      child = Builder(
        builder: (context) => MediaQuery.withClampedTextScaling(
          minScaleFactor: widget.minTextScale ?? 0,
          maxScaleFactor: widget.maxTextScale ?? double.infinity,
          child: inner,
        ),
      );
    }
    if (widget.dismissKeyboardOnTap) {
      child = OmniKeyboardDismiss(child: child);
    }
    final onInit = widget.onInit;
    if (onInit != null) {
      child = OmniInitGate(onInit: onInit, splash: widget.splash, child: child);
    }
    final lifecycle = widget.lifecycle;
    if (lifecycle != null) {
      child = OmniAppLifecycleScope(lifecycle: lifecycle, child: child);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null || _configError != null) {
      return ErrorWidget(_configError ?? 'OmniApp configuration failed');
    }
    return OmniPageConfig(
      transition: widget.transition,
      titles: widget.setTitles,
      titleColor: widget.titleColor,
      errorBuilder: widget.notFound ?? defaultOmniErrorBuilder,
      exitWindow: widget.doubleBackToExit,
      onExitWarning: widget.onExitWarning,
      child: OmniSwipeBackDefaults(
        mode: widget.swipeBack,
        style: widget.swipeBackStyle,
        predictiveBack: widget.predictiveBack,
        child: OmniGlobalBlocScope(
          registry: _blocs,
          child: GuardRefresh(
            guards: _refreshGuards,
            notifier: _guardRefresh,
            child: _wrapApp(
              Builder(
                builder: (c) => widget.desktopBack
                    ? OmniDesktopBack(
                        router: router,
                        escape: widget.escapeGoesBack,
                        child: widget.builder(c, router),
                      )
                    : widget.builder(c, router),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
