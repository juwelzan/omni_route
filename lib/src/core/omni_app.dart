import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Compiles [routes] once into a fast Segment Trie, provides global
/// [repositories] and [blocs], subscribes guard refresh streams, configures
/// platform features (swipe back, predictive back, desktop back, titles, state
/// restoration, startup gating), and hands the native [OmniRouter] to [builder]
/// (or use the zero-boilerplate [OmniApp.material] / [OmniApp.cupertino]
/// constructors):
///
/// ```dart
/// OmniApp.material(
///   title: 'My App',
///   initialRoute: '/dashboard',
///   transition: OmniPages.fadeSlide,
///   repositories: [OmniRepo((_) => AuthRepository())],
///   blocs: [OmniBloc((c) => AuthBloc(c.read<AuthRepository>()), global: true)],
///   routes: [OmniPage.screen(const DashboardScreen())],
/// )
/// ```
class OmniApp extends StatefulWidget {
  /// Creates the root of an OmniRoute application with a custom [builder].
  const OmniApp({
    super.key,
    required this.routes,
    required this.builder,
    this.blocs = const [],
    this.repositories = const [],
    this.initialRoute = '/',
    this.resolveInitialRoute,
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
    this.initTimeout,
    this.splash,
    this.onInitError,
    this.dismissKeyboardOnTap = false,
    this.doubleBackToExit,
    this.onExitWarning,
    this.orientations,
    this.minTextScale,
    this.maxTextScale,
    this.blocObserver,
    this.onError,
    this.overlayBuilder,
  }) : _applyRootOverlay = true;

  /// Creates an [OmniApp] pre-configured with `MaterialApp.router`, removing
  /// repetitive `builder: (context, router) => MaterialApp.router(...)` setup.
  OmniApp.material({
    super.key,
    required this.routes,
    this.blocs = const [],
    this.repositories = const [],
    this.initialRoute = '/',
    this.resolveInitialRoute,
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
    this.initTimeout,
    this.splash,
    this.onInitError,
    this.dismissKeyboardOnTap = false,
    this.doubleBackToExit,
    this.onExitWarning,
    this.orientations,
    this.minTextScale,
    this.maxTextScale,
    this.blocObserver,
    this.onError,
    this.overlayBuilder,
    String title = '',
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeData? highContrastTheme,
    ThemeData? highContrastDarkTheme,
    ThemeMode? themeMode,
    ThemeMode? Function(BuildContext context)? themeModeBuilder,
    Color? color,
    Locale? locale,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    Iterable<Locale> supportedLocales = const <Locale>[Locale('en', 'US')],
    bool debugShowCheckedModeBanner = true,
    GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey,
    Map<ShortcutActivator, Intent>? shortcuts,
    Map<Type, Action<Intent>>? actions,
    ScrollBehavior? scrollBehavior,
    TransitionBuilder? appBuilder,
  }) : builder = ((context, router) => MaterialApp.router(
         title: title,
         theme: theme,
         darkTheme: darkTheme,
         highContrastTheme: highContrastTheme,
         highContrastDarkTheme: highContrastDarkTheme,
         themeMode: themeModeBuilder?.call(context) ?? themeMode,
         color: color,
         locale: locale,
         localizationsDelegates: localizationsDelegates,
         supportedLocales: supportedLocales,
         debugShowCheckedModeBanner: debugShowCheckedModeBanner,
         scaffoldMessengerKey: scaffoldMessengerKey,
         shortcuts: shortcuts,
         actions: actions,
         scrollBehavior: scrollBehavior,
         routerConfig: router,
         builder: _chainBuilders(appBuilder, overlayBuilder),
       )),
       _applyRootOverlay = false;

  /// Creates an [OmniApp] pre-configured with `CupertinoApp.router`.
  OmniApp.cupertino({
    super.key,
    required this.routes,
    this.blocs = const [],
    this.repositories = const [],
    this.initialRoute = '/',
    this.resolveInitialRoute,
    this.transition = OmniPages.cupertino,
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
    this.initTimeout,
    this.splash,
    this.onInitError,
    this.dismissKeyboardOnTap = false,
    this.doubleBackToExit,
    this.onExitWarning,
    this.orientations,
    this.minTextScale,
    this.maxTextScale,
    this.blocObserver,
    this.onError,
    this.overlayBuilder,
    String title = '',
    CupertinoThemeData? theme,
    Color? color,
    Locale? locale,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    Iterable<Locale> supportedLocales = const <Locale>[Locale('en', 'US')],
    bool debugShowCheckedModeBanner = true,
    Map<ShortcutActivator, Intent>? shortcuts,
    Map<Type, Action<Intent>>? actions,
    ScrollBehavior? scrollBehavior,
    TransitionBuilder? appBuilder,
  }) : builder = ((_, router) => CupertinoApp.router(
         title: title,
         theme: theme,
         color: color,
         locale: locale,
         localizationsDelegates: localizationsDelegates,
         supportedLocales: supportedLocales,
         debugShowCheckedModeBanner: debugShowCheckedModeBanner,
         shortcuts: shortcuts,
         actions: actions,
         scrollBehavior: scrollBehavior,
         routerConfig: router,
         builder: _chainBuilders(appBuilder, overlayBuilder),
       )),
       _applyRootOverlay = false;

  static TransitionBuilder? _chainBuilders(
    TransitionBuilder? appBuilder,
    TransitionBuilder? overlayBuilder,
  ) {
    if (appBuilder == null && overlayBuilder == null) return null;
    if (appBuilder == null) return overlayBuilder;
    if (overlayBuilder == null) return appBuilder;
    return (context, child) =>
        overlayBuilder(context, appBuilder(context, child));
  }

  /// Validates [routes] upfront (duplicate `routePath`, duplicate names,
  /// malformed patterns) and returns every compiled `routePath`.
  static List<String> validateRoutes(
    List<OmniRouteBase> routes, {
    GlobalKey<NavigatorState>? rootNavigatorKey,
  }) => OmniRouteRegistry(
    routes,
    rootNavigatorKey:
        rootNavigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'Validate'),
  ).paths;

  /// Declarative routes (`OmniPage`, `OmniRouteGroup`, `OmniShell`,
  /// `OmniStatefulShell`).
  final List<OmniRouteBase> routes;

  /// Builds your app widget (`MaterialApp.router`) with the router.
  final OmniAppBuilder builder;

  /// App-wide Bloc factories; entries with `global: true` stay alive for the
  /// whole app. Page-scoped Blocs should instead be declared directly on their
  /// screen (`provide`) or `OmniPage(blocs: [...])` so their `BlocProvider`s
  /// register when first entering that page.
  final List<OmniBlocEntry> blocs;

  /// App-wide repositories and services (`OmniRepo`) mounted above [blocs]
  /// so both global Blocs and routes can read `context.read<T>()`.
  final List<OmniRepoEntry> repositories;

  /// Location shown on startup when no platform deep link is active.
  final String initialRoute;

  /// Optional async resolver run after [onInit] completes to choose the actual
  /// startup location (e.g. `'/onboarding'` vs `'/dashboard'`).
  final OmniInitialRouteResolver? resolveInitialRoute;

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

  /// Optional timeout applied to [onInit].
  final Duration? initTimeout;

  /// Widget shown while [onInit] or [resolveInitialRoute] completes.
  final WidgetBuilder? splash;

  /// Custom error & retry view rendered when [onInit] throws or times out.
  final OmniInitErrorBuilder? onInitError;

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

  /// Optional global overlay/wrapper surrounding the app (inside Theme /
  /// Directionality when using [OmniApp.material] or [OmniApp.cupertino], or
  /// wrapping [builder] in the default constructor).
  final TransitionBuilder? overlayBuilder;

  final bool _applyRootOverlay;

  @override
  State<OmniApp> createState() => _OmniAppState();
}

class _OmniAppState extends State<OmniApp> {
  OmniBlocRegistry? _blocs;
  late GlobalKey<NavigatorState> _navKey;
  List<OmniGuard> _refreshGuards = const [];
  OmniRouter? _router;
  Object? _configError;
  final GuardNotifier _guardRefresh = GuardNotifier();
  bool _navListenerAttached = false;

  OmniRouteEntry? _last;
  Uri? _lastUri;
  LocalKey? _lastPageKey;

  void _initRouter() {
    _blocs ??= OmniBlocRegistry(widget.blocs);
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
        if (mounted && (widget.onNavigate != null || widget.logNavigation)) {
          _navigated();
        }
      },
    );
    OmniRoute.attach(router, registry);
    _syncNavListener();
  }

  @override
  void initState() {
    super.initState();
    _navKey =
        widget.navigatorKey ??
        GlobalKey<NavigatorState>(debugLabel: 'OmniRoot');
    _installGlobals();
    try {
      _initRouter();
      _configError = null;
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

  void _syncNavListener() {
    final router = _router;
    if (router == null) return;
    final want = widget.onNavigate != null || widget.logNavigation;
    if (want && !_navListenerAttached) {
      router.routerDelegate.addListener(_navigated);
      _navListenerAttached = true;
    } else if (!want && _navListenerAttached) {
      router.routerDelegate.removeListener(_navigated);
      _navListenerAttached = false;
    }
  }

  @override
  void didUpdateWidget(OmniApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGlobals(oldWidget);

    if (_router == null) {
      try {
        _initRouter();
        _configError = null;
      } catch (e, stack) {
        _configError = e;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stack,
            library: 'omni_route',
            context: ErrorDescription('while re-configuring OmniApp'),
          ),
        );
      }
      return;
    }

    final router = _router!;
    _syncNavListener();

    final blocsChanged = !identical(widget.blocs, oldWidget.blocs);
    final routesOrRouterChanged =
        !identical(widget.routes, oldWidget.routes) ||
        !identical(widget.guards, oldWidget.guards) ||
        !identical(widget.observers, oldWidget.observers) ||
        !identical(widget.notFound, oldWidget.notFound) ||
        !identical(widget.refreshListenable, oldWidget.refreshListenable);

    if (blocsChanged || routesOrRouterChanged || _configError != null) {
      try {
        if (blocsChanged) {
          (_blocs ??= OmniBlocRegistry(const [])).mergeEntries(widget.blocs);
        }
        if (routesOrRouterChanged || _configError != null) {
          final registry = OmniRouteRegistry(
            widget.routes,
            rootNavigatorKey: _navKey,
          );
          _refreshGuards = {...widget.guards, ...registry.routeGuards}.toList();
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
        }
        _configError = null;
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
    final event = OmniNavigation(
      from: _last,
      to: to,
      uri: state.uri,
      kind: router.lastNavigationKind,
      timestamp: DateTime.now(),
    );
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
  BlocObserver? _installedBlocObserver;

  void _installErrorHandlers() {
    if (_ourFlutterOnError != null) return;
    _prevFlutterOnError = FlutterError.onError;
    FlutterError.onError = _ourFlutterOnError = (details) {
      widget.onError?.call(details.exception, details.stack ?? StackTrace.empty);
      _prevFlutterOnError?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    _prevPlatformOnError = dispatcher.onError;
    dispatcher.onError = _ourPlatformOnError = (error, stack) {
      widget.onError?.call(error, stack);
      return _prevPlatformOnError?.call(error, stack) ?? false;
    };
  }

  void _uninstallErrorHandlers() {
    if (_ourFlutterOnError != null &&
        identical(FlutterError.onError, _ourFlutterOnError)) {
      FlutterError.onError = _prevFlutterOnError;
    }
    _ourFlutterOnError = null;
    final dispatcher = PlatformDispatcher.instance;
    if (_ourPlatformOnError != null &&
        identical(dispatcher.onError, _ourPlatformOnError)) {
      dispatcher.onError = _prevPlatformOnError;
    }
    _ourPlatformOnError = null;
  }

  void _installGlobals() {
    if (widget.onError != null) {
      _installErrorHandlers();
    }
    final observer = widget.blocObserver;
    if (observer != null) {
      _prevBlocObserver = Bloc.observer;
      _installedBlocObserver = observer;
      Bloc.observer = observer;
    }
    final orientations = widget.orientations;
    if (orientations != null) {
      SystemChrome.setPreferredOrientations(orientations);
    }
  }

  void _syncGlobals(OmniApp oldWidget) {
    if (widget.onError != null && _ourFlutterOnError == null) {
      _installErrorHandlers();
    } else if (widget.onError == null && _ourFlutterOnError != null) {
      _uninstallErrorHandlers();
    }

    if (!identical(widget.blocObserver, oldWidget.blocObserver)) {
      if (_prevBlocObserver case final prev?
          when _installedBlocObserver != null &&
              identical(Bloc.observer, _installedBlocObserver)) {
        Bloc.observer = prev;
      }
      _installedBlocObserver = null;
      _prevBlocObserver = null;
      final next = widget.blocObserver;
      if (next != null) {
        _prevBlocObserver = Bloc.observer;
        _installedBlocObserver = next;
        Bloc.observer = next;
      }
    }

    if (!listEquals(widget.orientations, oldWidget.orientations)) {
      if (widget.orientations != null) {
        SystemChrome.setPreferredOrientations(widget.orientations!);
      } else if (oldWidget.orientations != null) {
        SystemChrome.setPreferredOrientations(const []);
      }
    }
  }

  void _restoreGlobals() {
    _uninstallErrorHandlers();
    final prevObserver = _prevBlocObserver;
    if (prevObserver != null &&
        identical(Bloc.observer, _installedBlocObserver)) {
      Bloc.observer = prevObserver;
    }
    _installedBlocObserver = null;
    if (widget.orientations != null) {
      SystemChrome.setPreferredOrientations(const []);
    }
  }

  @override
  void dispose() {
    _restoreGlobals();
    final router = _router;
    if (router != null) {
      if (_navListenerAttached) {
        router.routerDelegate.removeListener(_navigated);
        _navListenerAttached = false;
      }
      OmniRoute.detach(router);
      router.dispose();
    }
    _guardRefresh.dispose();
    super.dispose();
  }

  Widget _wrapApp(Widget app, OmniRouter router) {
    var child = app;
    if (widget._applyRootOverlay) {
      if (widget.overlayBuilder case final overlay?) {
        final inner = child;
        child = Builder(builder: (context) => overlay(context, inner));
      }
    }
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
    if (widget.onInit != null || widget.resolveInitialRoute != null) {
      child = OmniInitGate(
        onInit: widget.onInit,
        initTimeout: widget.initTimeout,
        splash: widget.splash,
        onInitError: widget.onInitError,
        resolveInitialRoute: widget.resolveInitialRoute,
        router: router,
        child: child,
      );
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
    final blocs = _blocs;
    if (router == null || blocs == null || _configError != null) {
      return ErrorWidget(_configError ?? 'OmniApp configuration failed');
    }

    Widget tree = GuardRefresh(
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
        router,
      ),
    );

    tree = OmniGlobalBlocScope(registry: blocs, child: tree);
    if (widget.repositories.isNotEmpty) {
      tree = MultiRepositoryProvider(
        providers: [for (final r in widget.repositories) r.toProvider()],
        child: tree,
      );
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
        child: tree,
      ),
    );
  }
}
