import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/omni_bloc.dart';
import '../bloc/omni_bloc_scope.dart';
import '../guards/omni_guard.dart';
import 'package:omni_responsive/integration.dart';
import 'package:omni_responsive/omni_responsive.dart';
import '../routing/omni_page.dart';
import '../routing/omni_route_registry.dart';
import '../routing/omni_route_state.dart';
import '../routing/omni_swipe_back.dart';
import '../screens/omni_lifecycle.dart';
import 'omni_app_config.dart';
import 'omni_app_features.dart';
import 'omni_breadcrumbs.dart';
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
    this.config,
    this.onInit,
    this.initTimeout,
    this.splash,
    this.onInitError,
    this.dismissKeyboardOnTap = false,
    this.doubleBackToExit,
    this.onExitWarning,
    this.screenMode,
    this.statusBar,
    this.systemNavigationBar,
    this.orientation,
    this.orientations,
    this.minTextScale,
    this.maxTextScale,
    this.blocObserver,
    this.onError,
    this.overlayBuilder,
    this.responsive = const OmniResponsiveConfig(),
    this.omniTheme,
    this.themes = const [],
    this.themeAnimation,
    this.localization,
    this.localeController,
    this.maxBreadcrumbs = 25,
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
    this.config,
    this.onInit,
    this.initTimeout,
    this.splash,
    this.onInitError,
    this.dismissKeyboardOnTap = false,
    this.doubleBackToExit,
    this.onExitWarning,
    this.screenMode,
    this.statusBar,
    this.systemNavigationBar,
    this.orientation,
    this.orientations,
    this.minTextScale,
    this.maxTextScale,
    this.blocObserver,
    this.onError,
    this.overlayBuilder,
    this.responsive = const OmniResponsiveConfig(),
    this.omniTheme,
    this.themes = const [],
    this.themeAnimation,
    this.localization,
    this.localeController,
    this.maxBreadcrumbs = 25,
    String title = '',
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeData? highContrastTheme,
    ThemeData? highContrastDarkTheme,
    ThemeMode? themeMode,
    ThemeMode? Function(BuildContext context)? themeModeBuilder,
    Duration? themeAnimationDuration,
    Curve? themeAnimationCurve,
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
  }) : builder = ((context, router) {
         final resolved = OmniThemeScope.maybeThemesOf(context);
         final animSettings = OmniThemeScope.animationSettingsOf(context);
         final effThemeMode =
             themeModeBuilder?.call(context) ?? themeMode ?? resolved?.mode;
         final l10n = _resolveL10n(
           context,
           locale: locale,
           localizationsDelegates: localizationsDelegates,
           supportedLocales: supportedLocales,
         );

         MaterialApp buildMaterialApp(
           Duration animDuration,
           Curve animCurve,
           ThemeMode? modeOverride,
         ) => MaterialApp.router(
           title: title,
           theme: theme ?? resolved?.light,
           darkTheme: darkTheme ?? resolved?.dark,
           highContrastTheme: highContrastTheme,
           highContrastDarkTheme: highContrastDarkTheme,
           themeMode: modeOverride ?? effThemeMode,
           themeAnimationDuration: animDuration,
           themeAnimationCurve: animCurve,
           color: color,
           locale: l10n.locale,
           localizationsDelegates: l10n.delegates,
           supportedLocales: l10n.supportedLocales,
           debugShowCheckedModeBanner: debugShowCheckedModeBanner,
           scaffoldMessengerKey: scaffoldMessengerKey,
           shortcuts: shortcuts,
           actions: actions,
           scrollBehavior: scrollBehavior,
           routerConfig: router,
           builder: _chainBuilders(
             appBuilder,
             overlayBuilder,
             responsive,
             minTextScale,
             maxTextScale,
             syncMaterialBarTheme: omniTheme == null && themes.isEmpty,
           ),
         );

         if (resolved == null &&
             themeAnimation != null &&
             themeAnimation.mode != OmniThemeAnimationMode.none) {
           final rawBrightness = switch (effThemeMode ?? ThemeMode.system) {
             ThemeMode.light => Brightness.light,
             ThemeMode.dark => Brightness.dark,
             ThemeMode.system => MediaQuery.platformBrightnessOf(context),
           };
           return OmniThemeTransition<
             ({
               Brightness brightness,
               ThemeMode? mode,
               ThemeData? light,
               ThemeData? dark,
             })
           >(
             value: (
               brightness: rawBrightness,
               mode: effThemeMode,
               light: theme,
               dark: darkTheme,
             ),
             animation: themeAnimation,
             shouldAnimate: (prev, next) =>
                 prev.brightness != next.brightness ||
                 prev.light != next.light ||
                 prev.dark != next.dark,
             resolveMode: (prev, next) => themeAnimation.effectiveModeFor(
               brightnessChanged: prev.brightness != next.brightness,
               paletteChanged: prev.light != next.light || prev.dark != next.dark,
               styleChanged: false,
             ),
             resolveDuration: (prev, next) => themeAnimation.effectiveDurationFor(
               brightnessChanged: prev.brightness != next.brightness,
               paletteChanged: prev.light != next.light || prev.dark != next.dark,
             ),
             resolveGlowColor: (next) =>
                 themeAnimation.edgeGlowColor ??
                 (next.brightness == Brightness.dark
                     ? next.dark?.colorScheme.primary
                     : next.light?.colorScheme.primary) ??
                 next.light?.colorScheme.primary,
             builder: (_, displayed, dur, cur) => buildMaterialApp(
               themeAnimationDuration ?? dur,
               themeAnimationCurve ?? cur,
               displayed.mode,
             ),
           );
         }

         return buildMaterialApp(
           themeAnimationDuration ??
               animSettings?.duration ??
               kThemeAnimationDuration,
           themeAnimationCurve ?? animSettings?.curve ?? Curves.linear,
           null,
         );
       }),
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
    this.config,
    this.onInit,
    this.initTimeout,
    this.splash,
    this.onInitError,
    this.dismissKeyboardOnTap = false,
    this.doubleBackToExit,
    this.onExitWarning,
    this.screenMode,
    this.statusBar,
    this.systemNavigationBar,
    this.orientation,
    this.orientations,
    this.minTextScale,
    this.maxTextScale,
    this.blocObserver,
    this.onError,
    this.overlayBuilder,
    this.responsive = const OmniResponsiveConfig(),
    this.localization,
    this.localeController,
    this.maxBreadcrumbs = 25,
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
  }) : builder = ((context, router) {
         final l10n = _resolveL10n(
           context,
           locale: locale,
           localizationsDelegates: localizationsDelegates,
           supportedLocales: supportedLocales,
         );
         return CupertinoApp.router(
           title: title,
           theme: theme,
           color: color,
           locale: l10n.locale,
           localizationsDelegates: l10n.delegates,
           supportedLocales: l10n.supportedLocales,
           debugShowCheckedModeBanner: debugShowCheckedModeBanner,
           shortcuts: shortcuts,
           actions: actions,
           scrollBehavior: scrollBehavior,
           routerConfig: router,
           builder: _chainBuilders(
             appBuilder,
             overlayBuilder,
             responsive,
             minTextScale,
             maxTextScale,
           ),
         );
       }),
       omniTheme = null,
       themes = const [],
       themeAnimation = null,
       _applyRootOverlay = false;

  static ({
    Locale? locale,
    Iterable<LocalizationsDelegate<dynamic>> delegates,
    Iterable<Locale> supportedLocales,
  })
  _resolveL10n(
    BuildContext context, {
    Locale? locale,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    Iterable<Locale> supportedLocales = const <Locale>[Locale('en', 'US')],
  }) {
    final l10nScope = OmniL10nScope.maybeOf(context);
    final l10nState = l10nScope?.notifier?.value;
    final effectiveLocale = locale ?? l10nState?.effectiveLocale;
    final delegates = <LocalizationsDelegate<dynamic>>[
      ...?localizationsDelegates,
      OmniFallbackMaterialLocalizationsDelegate.instance,
      OmniFallbackCupertinoLocalizationsDelegate.instance,
      OmniFallbackWidgetsLocalizationsDelegate.instance,
    ];
    final supported = <Locale>{
      ...supportedLocales,
      if (l10nScope != null)
        for (final lang in l10nScope.config.supportedLanguages) lang.locale,
      ?effectiveLocale,
    };
    return (
      locale: effectiveLocale,
      delegates: delegates,
      supportedLocales: supported,
    );
  }

  static TransitionBuilder? _chainBuilders(
    TransitionBuilder? appBuilder,
    TransitionBuilder? overlayBuilder,
    OmniResponsiveConfig responsive,
    double? minTextScale,
    double? maxTextScale, {
    bool syncMaterialBarTheme = false,
  }) {
    final hasScale =
        (responsive.enabled && responsive.adaptTextScaling) ||
        minTextScale != null ||
        maxTextScale != null;
    if (appBuilder == null &&
        overlayBuilder == null &&
        !hasScale &&
        !syncMaterialBarTheme) {
      return null;
    }
    return (context, child) {
      var current = child;
      if (syncMaterialBarTheme && current != null) {
        final scope =
            context.dependOnInheritedWidgetOfExactType<OmniSystemUiScope>();
        if (scope != null &&
            (scope.effectiveStatusBar != const OmniStatusBarStyle.transparent() ||
                scope.effectiveSystemNavigationBar !=
                    const OmniSystemNavigationBarStyle.transparent() ||
                scope.effectiveScreenMode != OmniScreenMode.edgeToEdge)) {
          final theme = Theme.of(context);
          final overlay = composeOmniSystemUiOverlayStyle(
            brightness: theme.brightness,
            screenMode: scope.effectiveScreenMode,
            statusBar: scope.effectiveStatusBar,
            systemNavigationBar: scope.effectiveSystemNavigationBar,
            fallbackTopBackground:
                theme.appBarTheme.backgroundColor ??
                theme.scaffoldBackgroundColor,
            fallbackBottomBackground: theme.scaffoldBackgroundColor,
          );
          if (theme.appBarTheme.systemOverlayStyle != overlay) {
            current = Theme(
              data: theme.copyWith(
                appBarTheme: theme.appBarTheme.copyWith(
                  systemOverlayStyle: overlay,
                ),
              ),
              child: current,
            );
          }
        }
      }
      if (appBuilder != null) current = appBuilder(context, current);
      if (overlayBuilder != null) current = overlayBuilder(context, current);
      if (hasScale && current != null) {
        current = OmniResponsiveTextScaleHost(
          config: responsive,
          minTextScale: minTextScale,
          maxTextScale: maxTextScale,
          child: current,
        );
      }
      return current!;
    };
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

  /// Centralized flow configuration for Splash, `onInit`, Onboarding, Auth
  /// (`loginScreen`/`signupScreen`/`homeRoute`), and pre-login public routes.
  final OmniConfig? config;

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

  /// App-wide system bars & fullscreen display mode (`edgeToEdge`,
  /// `fullscreen`, `fullscreenLean`, `normal`, `statusBarOnly`,
  /// `navigationBarOnly`). Can be changed at runtime via `context.enterFullscreen()`,
  /// `context.exitFullscreen()`, or per-page via `OmniPage(screenMode: ...)`.
  final OmniScreenMode? screenMode;

  /// App-wide custom style for the TOP system status bar ([OmniStatusBarStyle]).
  /// Applied globally to every screen (with or without `AppBar`).
  final OmniStatusBarStyle? statusBar;

  /// App-wide custom style for the BOTTOM system navigation / gesture swipe bar
  /// ([OmniSystemNavigationBarStyle]); removes Android gesture-bar black scrim across every screen.
  final OmniSystemNavigationBarStyle? systemNavigationBar;

  /// High-level device rotation preset (`auto`, `portrait`, `portraitBoth`,
  /// `landscape`, `landscapeLeft`, `landscapeRight`, `portraitOnMobile`, `system`).
  /// Takes effect globally and can be overridden per route via `OmniPage(orientation: ...)`.
  final OmniOrientation? orientation;

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

  /// Native-equivalent, zero-overhead responsive configuration (active by
  /// default via discrete breakpoint tiers and pre-cached constant tokens).
  final OmniResponsiveConfig responsive;

  /// Optional responsive Material 3 theming & persisted Dark/Light mode config.
  final OmniTheme? omniTheme;

  /// Optional theme catalog enabling 1-click switching across multiple named
  /// themes (`OmniTheme.presets` or custom `OmniTheme(...)` variants).
  final List<OmniTheme> themes;

  /// Optional animated transition configuration when Dark/Light mode or Color
  /// Palette changes (`OmniThemeAnimation.circularReveal`, `.horizontalWipe`,
  /// `.diagonalSweep`, `.colorMorph`, etc.).
  final OmniThemeAnimation? themeAnimation;

  /// Optional localization configuration ([OmniLocalization]); even when omitted,
  /// [OmniText], `context.l10n(...)`, and `OmniText.setLanguage(...)` work
  /// automatically across all screens with zero extra setup.
  final OmniLocalization? localization;

  /// Optional isolated [OmniLocaleController] override.
  final OmniLocaleController? localeController;

  /// Bounded in-memory navigation/error breadcrumb capacity retained for
  /// `OmniRoute.breadcrumbs` and `OmniRoute.exportDiagnostics()` (`0` disables
  /// recording completely with zero heap allocations).
  final int maxBreadcrumbs;

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
  final OmniFlowSession _flowSession = OmniFlowSession();
  final OmniSystemUiController _systemUiController = OmniSystemUiController();
  bool _navListenerAttached = false;

  OmniRouteEntry? _last;
  Uri? _lastUri;
  LocalKey? _lastPageKey;

  ({
    OmniConfig? config,
    OmniRouteRegistry registry,
    List<OmniGuard> guards,
    Listenable refresh,
  })
  _compileConfig() {
    final config = _effectiveConfig();
    final registry = OmniRouteRegistry(
      buildOmniConfigRoutes(widget.routes, config),
      rootNavigatorKey: _navKey,
    );
    final guards = [
      if (config != null && config.hasAuthGuard)
        OmniConfigGuard(config: config, session: _flowSession),
      ...widget.guards,
    ];
    _refreshGuards = {...guards, ...registry.routeGuards}.toList();

    final external = widget.refreshListenable;
    final auth = config?.auth?.refreshListenable;
    final Listenable refresh = (external == null && auth == null)
        ? _guardRefresh
        : Listenable.merge([
            _guardRefresh,
            ?external,
            if (auth != null && !identical(auth, external)) auth,
          ]);

    return (
      config: config,
      registry: registry,
      guards: guards,
      refresh: refresh,
    );
  }

  String _resolveInitialRoute(OmniConfig? config, OmniRouteRegistry registry) {
    final platformDefault = PlatformDispatcher.instance.defaultRouteName;
    if (platformDefault.isNotEmpty && platformDefault != '/') {
      return platformDefault;
    }
    final homeRoute = config?.auth?.homeRoute ?? '/';
    if (widget.initialRoute == '/' &&
        homeRoute != '/' &&
        registry.routeAt('/') == null) {
      return normalizeOmniConfigPath(homeRoute);
    }
    return widget.initialRoute;
  }

  void _initRouter() {
    _blocs ??= OmniBlocRegistry(widget.blocs);
    final compiled = _compileConfig();

    final router = _router = OmniRouter(
      routeRegistry: compiled.registry,
      navigatorKey: _navKey,
      guards: compiled.guards,
      observers: widget.observers ?? const [],
      onRouteError: widget.notFound ?? defaultOmniErrorBuilder,
      initialRoute: _resolveInitialRoute(compiled.config, compiled.registry),
      restorationScopeId: widget.restorationScopeId,
      refresh: compiled.refresh,
      onReady: () {
        if (mounted &&
            (widget.onNavigate != null ||
                widget.logNavigation ||
                widget.maxBreadcrumbs > 0)) {
          _navigated();
        }
      },
    );
    OmniRoute.attach(
      router,
      compiled.registry,
      maxBreadcrumbs: widget.maxBreadcrumbs,
    );
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
    final want =
        widget.onNavigate != null ||
        widget.logNavigation ||
        widget.maxBreadcrumbs > 0;
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
    if (widget.maxBreadcrumbs != oldWidget.maxBreadcrumbs) {
      OmniRoute.configureRuntime(
        router,
        maxBreadcrumbs: widget.maxBreadcrumbs,
      );
    }
    _syncNavListener();

    final blocsChanged = !identical(widget.blocs, oldWidget.blocs);
    final routesOrRouterChanged =
        !identical(widget.routes, oldWidget.routes) ||
        !identical(widget.guards, oldWidget.guards) ||
        !identical(widget.observers, oldWidget.observers) ||
        !identical(widget.notFound, oldWidget.notFound) ||
        !identical(widget.refreshListenable, oldWidget.refreshListenable) ||
        !identical(widget.config, oldWidget.config);

    if (blocsChanged || routesOrRouterChanged || _configError != null) {
      try {
        if (blocsChanged) {
          (_blocs ??= OmniBlocRegistry(const [])).mergeEntries(widget.blocs);
        }
        if (routesOrRouterChanged || _configError != null) {
          final compiled = _compileConfig();
          OmniRoute.updateRegistry(router, compiled.registry);
          router.updateConfig(
            registry: compiled.registry,
            guards: compiled.guards,
            observers: widget.observers ?? const [],
            errorBuilder: widget.notFound ?? defaultOmniErrorBuilder,
            refreshListenable: compiled.refresh,
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
    if (widget.maxBreadcrumbs > 0) {
      final ctx = _navKey.currentContext;
      final device = ctx != null ? OmniResponsiveScope.read(ctx).device : null;
      OmniRoute.recordBreadcrumbFor(
        router,
        OmniBreadcrumb(
          timestamp: event.timestamp ?? DateTime.now(),
          category: 'navigation',
          message: '${event.from?.location ?? 'initial'} -> ${to.location}',
          routePath: to.routePath,
          device: device,
          data: {'kind': router.lastNavigationKind.name},
        ),
      );
    }
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
      if (widget.maxBreadcrumbs > 0 && _router != null) {
        OmniRoute.recordBreadcrumbFor(
          _router!,
          OmniBreadcrumb(
            timestamp: DateTime.now(),
            category: 'error',
            message: details.exceptionAsString(),
            routePath: _router?.state.routePath,
          ),
        );
      }
      widget.onError?.call(details.exception, details.stack ?? StackTrace.empty);
      _prevFlutterOnError?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    _prevPlatformOnError = dispatcher.onError;
    dispatcher.onError = _ourPlatformOnError = (error, stack) {
      if (widget.maxBreadcrumbs > 0 && _router != null) {
        OmniRoute.recordBreadcrumbFor(
          _router!,
          OmniBreadcrumb(
            timestamp: DateTime.now(),
            category: 'error',
            message: error.toString(),
            routePath: _router?.state.routePath,
          ),
        );
      }
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
  }

  void _restoreGlobals() {
    _uninstallErrorHandlers();
    final prevObserver = _prevBlocObserver;
    if (prevObserver != null &&
        identical(Bloc.observer, _installedBlocObserver)) {
      Bloc.observer = prevObserver;
    }
    _installedBlocObserver = null;
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
    _systemUiController.dispose();
    super.dispose();
  }

  Widget _wrapApp(Widget app, OmniRouter router) {
    var child = app;
    if (widget._applyRootOverlay) {
      if (widget.overlayBuilder case final overlay?) {
        final inner = child;
        child = Builder(builder: (context) => overlay(context, inner));
      }
      if ((widget.responsive.enabled && widget.responsive.adaptTextScaling) ||
          widget.minTextScale != null ||
          widget.maxTextScale != null) {
        child = OmniResponsiveTextScaleHost(
          config: widget.responsive,
          minTextScale: widget.minTextScale,
          maxTextScale: widget.maxTextScale,
          child: child,
        );
      }
    }
    if (widget.dismissKeyboardOnTap) {
      child = OmniKeyboardDismiss(child: child);
    }
    final config = _effectiveConfig();
    if (config != null) {
      child = OmniInitGate(
        config: config,
        session: _flowSession,
        router: router,
        child: child,
      );
    }
    final hasThemeHost = widget.omniTheme != null || widget.themes.isNotEmpty;
    final innerChild = child;
    child = ListenableBuilder(
      listenable: _systemUiController,
      child: innerChild,
      builder: (context, builtChild) {
        final effectiveStatusBar =
            _systemUiController.statusBar ?? widget.statusBar;
        final effectiveNavBar =
            _systemUiController.systemNavigationBar ??
            widget.systemNavigationBar;
        final baseMode = _systemUiController.screenMode ?? widget.screenMode;
        final effectiveScreenMode = baseMode != null
            ? resolveEffectiveOmniScreenMode(
                baseMode,
                statusBar: effectiveStatusBar,
                systemNavigationBar: effectiveNavBar,
              )
            : (effectiveStatusBar != null || effectiveNavBar != null
                ? resolveEffectiveOmniScreenMode(
                    OmniScreenMode.edgeToEdge,
                    statusBar: effectiveStatusBar,
                    systemNavigationBar: effectiveNavBar,
                  )
                : null);
        final hasRuntimeOrient =
            _systemUiController.orientations != null ||
            _systemUiController.orientation != null;
        final effectiveOrientation = hasRuntimeOrient
            ? _systemUiController.orientation
            : widget.orientation;
        final effectiveOrientations = hasRuntimeOrient
            ? _systemUiController.orientations
            : (widget.orientation != null ? null : widget.orientations);

        var current = builtChild!;
        if (hasThemeHost) {
          current = OmniResponsiveThemeHost(
            omniTheme: widget.omniTheme,
            themes: widget.themes,
            themeAnimation: widget.themeAnimation,
            appScreenMode: effectiveScreenMode,
            appStatusBar: effectiveStatusBar,
            appSystemNavigationBar: effectiveNavBar,
            child: current,
          );
        }
        current = OmniSystemUi(
          screenMode: hasThemeHost ? null : effectiveScreenMode,
          statusBar: hasThemeHost ? null : effectiveStatusBar,
          systemNavigationBar: hasThemeHost ? null : effectiveNavBar,
          brightness: !hasThemeHost &&
                  (effectiveStatusBar != null ||
                      effectiveNavBar != null ||
                      effectiveScreenMode != null)
              ? MediaQuery.platformBrightnessOf(context)
              : null,
          orientation: effectiveOrientation,
          orientations: effectiveOrientations,
          child: current,
        );
        return OmniSystemUiScope(
          controller: _systemUiController,
          effectiveScreenMode:
              effectiveScreenMode ??
              (widget.omniTheme ?? widget.themes.firstOrNull)?.screenMode ??
              OmniScreenMode.edgeToEdge,
          effectiveOrientation: effectiveOrientation,
          effectiveStatusBar:
              effectiveStatusBar ??
              (widget.omniTheme ?? widget.themes.firstOrNull)?.statusBar ??
              const OmniStatusBarStyle.transparent(),
          effectiveSystemNavigationBar:
              effectiveNavBar ??
              (widget.omniTheme ?? widget.themes.firstOrNull)
                  ?.systemNavigationBar ??
              const OmniSystemNavigationBarStyle.transparent(),
          child: current,
        );
      },
    );
    final lifecycle = widget.lifecycle;
    if (lifecycle != null) {
      child = OmniAppLifecycleScope(lifecycle: lifecycle, child: child);
    }
    child = OmniLocalizationHost(
      config: widget.localization ?? const OmniLocalization(),
      controller: widget.localeController,
      child: child,
    );
    return OmniResponsiveScope(
      config: widget.responsive,
      minTextScale: widget.minTextScale,
      maxTextScale: widget.maxTextScale,
      child: child,
    );
  }

  OmniConfig? _effectiveConfig() {
    final base = widget.config;
    final hasSplashDirect =
        widget.onInit != null ||
        widget.initTimeout != null ||
        widget.splash != null ||
        widget.onInitError != null;
    if (base == null && !hasSplashDirect && widget.resolveInitialRoute == null) {
      return null;
    }
    final nextSplash = hasSplashDirect
        ? (base?.splash ?? const OmniSplash()).copyWith(
            builder: widget.splash,
            onInit: widget.onInit,
            timeout: widget.initTimeout,
            onError: widget.onInitError,
          )
        : base?.splash;
    return (base ?? const OmniConfig()).copyWith(
      splash: nextSplash,
      resolveInitialRoute: widget.resolveInitialRoute,
    );
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
