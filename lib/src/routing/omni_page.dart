import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bloc/omni_bloc.dart';
import '../bloc/omni_bloc_scope.dart';
import '../core/omni_app_features.dart';
import '../core/omni_router.dart';
import '../errors/omni_route_exception.dart';
import '../guards/omni_guard.dart';
import 'package:omni_responsive/omni_responsive.dart';
import '../screens/omni_screen.dart';
import '../screens/omni_screen_host.dart';
import 'omni_bottom_bar_host.dart';
import 'omni_params.dart';
import 'omni_route_state.dart';
import 'omni_swipe_back.dart';
import 'omni_title.dart';

/// Builds a page widget (`OmniScreen` or any plain `Widget`) from the active
/// route's parameters.
typedef OmniScreenBuilder<S extends Widget> = S Function(OmniParams p);

/// Builds the error widget shown when a route is missing or parameters fail.
typedef OmniErrorBuilder =
    Widget Function(BuildContext context, OmniRouteState state, Object? error);

/// Creates the [Page] that wraps a screen and controls its transition.
typedef OmniPageType =
    Page<void> Function(LocalKey key, String? name, Widget child);

/// Builds a custom page transition widget; matches Flutter's
/// `PageRouteBuilder.transitionsBuilder`.
typedef OmniTransitionBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    );

/// Asynchronous or synchronous confirmation callback before leaving an
/// [OmniPage]. Return `true` to allow popping or `false` to cancel.
typedef OmniPageExit = FutureOr<bool> Function(BuildContext context);

/// Built-in animated page transitions; see [OmniPages.transition].
enum OmniTransition {
  /// Cross-fade.
  fade,

  /// Slide in from the end edge (RTL-aware), while the page below shifts.
  slide,

  /// Slide up from the bottom.
  slideUp,

  /// Zoom in from 92% with a fade.
  scale,

  /// Zoom in from 96% with a subtle fade.
  fadeScale,

  /// Fade in while sliding upward subtly.
  fadeSlide,
}

/// Predefined page transition factories plus helpers for custom transitions,
/// dialogs, modal sheets, and zero-delay instant navigation.
abstract final class OmniPages {
  /// Platform-adaptive transition: instant [none] on web (zero transition lag),
  /// [cupertino] on iOS/macOS, and [material] on other platforms.
  static Page<void> adaptive(LocalKey key, String? name, Widget child) {
    if (kIsWeb) return none(key, name, child);
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => cupertino(key, name, child),
      _ => material(key, name, child),
    };
  }

  /// Uses Material's platform-native page transition (iOS swipe-back on
  /// Apple platforms, Material zoom/fade on Android/desktop).
  static Page<void> material(LocalKey key, String? name, Widget child) =>
      MaterialPage<void>(
        key: key,
        name: name,
        restorationId: _restorationId(key),
        child: child,
      );

  /// Cupertino horizontal slide with edge swipe-back on every platform.
  static Page<void> cupertino(LocalKey key, String? name, Widget child) =>
      CupertinoPage<void>(
        key: key,
        name: name,
        title: name,
        restorationId: _restorationId(key),
        child: child,
      );

  /// Instant transition with zero animation frames or tickers. Ideal when you
  /// want pages to appear immediately with no opening delay.
  static Page<void> none(LocalKey key, String? name, Widget child) =>
      OmniNoTransitionPage<void>(
        key: key,
        name: name,
        restorationId: _restorationId(key),
        child: child,
      );

  /// Default forward open duration for built-in animated transitions.
  static const defaultDuration = Duration(milliseconds: 250);

  /// Default reverse close duration for built-in animated transitions.
  static const defaultReverseDuration = Duration(milliseconds: 200);

  /// Smooth GPU-composited cross-fade.
  static Page<void> fade(LocalKey key, String? name, Widget child) =>
      _fade(key, name, child);
  static final OmniPageType _fade = transition(OmniTransition.fade);

  /// RTL-aware slide from the end edge with parallax on the route below.
  static Page<void> slide(LocalKey key, String? name, Widget child) =>
      _slide(key, name, child);
  static final OmniPageType _slide = transition(OmniTransition.slide);

  /// Slide up from the bottom edge (great for forms and full-screen modals).
  static Page<void> slideUp(LocalKey key, String? name, Widget child) =>
      _slideUp(key, name, child);
  static final OmniPageType _slideUp = transition(OmniTransition.slideUp);

  /// Scale in from 92% combined with a fade.
  static Page<void> scale(LocalKey key, String? name, Widget child) =>
      _scale(key, name, child);
  static final OmniPageType _scale = transition(OmniTransition.scale);

  /// Subtle zoom in from 96% with a fade.
  static Page<void> fadeScale(LocalKey key, String? name, Widget child) =>
      _fadeScale(key, name, child);
  static final OmniPageType _fadeScale = transition(OmniTransition.fadeScale);

  /// Fade in paired with a subtle upward shift.
  static Page<void> fadeSlide(LocalKey key, String? name, Widget child) =>
      _fadeSlide(key, name, child);
  static final OmniPageType _fadeSlide = transition(OmniTransition.fadeSlide);

  /// Soft zoom-in (0.94 -> 1.0) paired with zoom edge swipe-back and
  /// Android predictive-back progress.
  static Page<void> swipeZoom(LocalKey key, String? name, Widget child) =>
      _swipeZoom(key, name, child);
  static final OmniPageType _swipeZoom = custom(
    _softZoom,
    swipeBack: OmniSwipeBack.zoom,
  );

  // Used internally when `predictiveBack: true` upgrades material/cupertino/
  // adaptive pages on Android so they track the system gesture.
  static final OmniPageType _androidPredictive = custom(_softZoom);

  static Widget _softZoom(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: curved.drive(Tween(begin: 0.94, end: 1.0)),
        child: child,
      ),
    );
  }

  /// Configures any built-in [kind] with custom [duration], [reverseDuration],
  /// [curve], and edge [swipeBack] behaviour.
  static OmniPageType transition(
    OmniTransition kind, {
    Duration duration = defaultDuration,
    Duration reverseDuration = defaultReverseDuration,
    Curve curve = Curves.easeOutCubic,
    OmniSwipeBack? swipeBack,
    OmniSwipeBackStyle? swipeBackStyle,
  }) => custom(
    _builderFor(kind, CurveTween(curve: curve)),
    duration: duration,
    reverseDuration: reverseDuration,
    swipeBack: swipeBack,
    swipeBackStyle: swipeBackStyle,
  );

  /// Creates a completely custom page transition from [builder].
  static OmniPageType custom(
    OmniTransitionBuilder builder, {
    Duration duration = defaultDuration,
    Duration? reverseDuration,
    bool opaque = true,
    Color? barrierColor,
    bool barrierDismissible = false,
    bool fullscreenDialog = false,
    OmniSwipeBack? swipeBack,
    OmniSwipeBackStyle? swipeBackStyle,
  }) =>
      (key, name, child) => OmniSwipeBackPage<void>(
        key: key,
        name: name,
        restorationId: _restorationId(key),
        transitionDuration: duration,
        reverseTransitionDuration: reverseDuration ?? duration,
        opaque: opaque,
        barrierColor: barrierColor,
        barrierDismissible: barrierDismissible,
        fullscreenDialog: fullscreenDialog,
        transitionsBuilder: builder,
        swipeBack: swipeBack,
        swipeBackStyle: swipeBackStyle,
        child: child,
      );

  /// Displays the screen inside a Material [DialogRoute].
  static OmniPageType dialog({
    Color? barrierColor = Colors.black54,
    bool barrierDismissible = true,
  }) =>
      (key, name, child) => _OmniDialogPage(
        key: key,
        name: name,
        child: child,
        barrierColor: barrierColor,
        barrierDismissible: barrierDismissible,
      );

  /// Displays the screen inside a Material [ModalBottomSheetRoute].
  static OmniPageType bottomSheet({
    bool? showDragHandle,
    bool isScrollControlled = false,
  }) =>
      (key, name, child) => _OmniSheetPage(
        key: key,
        name: name,
        child: child,
        showDragHandle: showDragHandle,
        isScrollControlled: isScrollControlled,
      );

  /// Displays the screen as a modal bottom sheet on mobile viewports and a
  /// constrained centered modal dialog on tablet and desktop viewports.
  static OmniPageType adaptiveModal({
    Color? barrierColor = Colors.black54,
    bool barrierDismissible = true,
    bool? showDragHandle,
    bool isScrollControlled = true,
    double maxDialogWidth = 560,
  }) =>
      (key, name, child) => _OmniAdaptiveModalPage(
        key: key,
        name: name,
        child: child,
        barrierColor: barrierColor,
        barrierDismissible: barrierDismissible,
        showDragHandle: showDragHandle,
        isScrollControlled: isScrollControlled,
        maxDialogWidth: maxDialogWidth,
      );

  static OmniTransitionBuilder _builderFor(OmniTransition kind, CurveTween c) =>
      switch (kind) {
        OmniTransition.fade => (context, a, s, child) => FadeTransition(
          opacity: a.drive(c),
          child: child,
        ),
        OmniTransition.slide => (context, a, s, child) {
          final dir = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
          return SlideTransition(
            position: s
                .drive(c)
                .drive(Tween(begin: Offset.zero, end: Offset(-0.25 * dir, 0))),
            child: SlideTransition(
              position: a
                  .drive(c)
                  .drive(Tween(begin: Offset(1.0 * dir, 0), end: Offset.zero)),
              child: child,
            ),
          );
        },
        OmniTransition.slideUp => (context, a, s, child) => SlideTransition(
          position: a
              .drive(c)
              .drive(Tween(begin: const Offset(0, 1), end: Offset.zero)),
          child: child,
        ),
        OmniTransition.scale => (context, a, s, child) => FadeTransition(
          opacity: a.drive(c),
          child: ScaleTransition(
            scale: a.drive(c).drive(Tween(begin: 0.92, end: 1.0)),
            child: child,
          ),
        ),
        OmniTransition.fadeScale => (context, a, s, child) => FadeTransition(
          opacity: a.drive(c),
          child: ScaleTransition(
            scale: a.drive(c).drive(Tween(begin: 0.96, end: 1.0)),
            child: child,
          ),
        ),
        OmniTransition.fadeSlide => (context, a, s, child) => FadeTransition(
          opacity: a.drive(c),
          child: SlideTransition(
            position: a
                .drive(c)
                .drive(Tween(begin: const Offset(0, 0.04), end: Offset.zero)),
            child: child,
          ),
        ),
      };

  static String? _restorationId(LocalKey key) =>
      key is ValueKey<String> ? key.value : null;
}

/// A [Page] with zero transition animations (`Duration.zero`) used by
/// [OmniPages.none] and instant `animated: false` navigations.
class OmniNoTransitionPage<T> extends Page<T> {
  /// Creates an instant no-transition page wrapping [child].
  const OmniNoTransitionPage({
    required this.child,
    super.key,
    super.name,
    super.restorationId,
  });

  /// Screen widget displayed inside this page.
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _OmniNoTransitionRoute<T>(this);
}

class _OmniNoTransitionRoute<T> extends PageRoute<T> {
  _OmniNoTransitionRoute(OmniNoTransitionPage<T> page) : super(settings: page);

  OmniNoTransitionPage<T> get _page => settings as OmniNoTransitionPage<T>;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class _OmniDialogPage extends Page<void> {
  const _OmniDialogPage({
    super.key,
    super.name,
    required this.child,
    required this.barrierColor,
    required this.barrierDismissible,
  });

  final Widget child;
  final Color? barrierColor;
  final bool barrierDismissible;

  @override
  Route<void> createRoute(BuildContext context) {
    late final DialogRoute<void> route;
    return route = DialogRoute<void>(
      context: context,
      settings: this,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      builder: (_) => _currentChild(route, child),
    );
  }
}

/// The child of the page [route] shows now. Navigator swaps a route's
/// settings when its page is updated (new query, new screen), so route
/// builders read the child from there, not from the page that created them.
Widget _currentChild(Route<void> route, Widget fallback) =>
    switch (route.settings) {
      _OmniDialogPage(:final child) => child,
      _OmniSheetPage(:final child) => child,
      _OmniAdaptiveModalPage(:final child) => child,
      _ => fallback,
    };

class _OmniSheetPage extends Page<void> {
  const _OmniSheetPage({
    super.key,
    super.name,
    required this.child,
    required this.showDragHandle,
    required this.isScrollControlled,
  });

  final Widget child;
  final bool? showDragHandle;
  final bool isScrollControlled;

  @override
  Route<void> createRoute(BuildContext context) {
    late final ModalBottomSheetRoute<void> route;
    return route = ModalBottomSheetRoute<void>(
      settings: this,
      showDragHandle: showDragHandle,
      isScrollControlled: isScrollControlled,
      builder: (_) => _currentChild(route, child),
    );
  }
}

class _OmniAdaptiveModalPage extends Page<void> {
  const _OmniAdaptiveModalPage({
    super.key,
    super.name,
    required this.child,
    required this.barrierColor,
    required this.barrierDismissible,
    required this.showDragHandle,
    required this.isScrollControlled,
    required this.maxDialogWidth,
  });

  final Widget child;
  final Color? barrierColor;
  final bool barrierDismissible;
  final bool? showDragHandle;
  final bool isScrollControlled;
  final double maxDialogWidth;

  @override
  Route<void> createRoute(BuildContext context) {
    final snapshot = OmniResponsiveScope.read(context);
    if (snapshot.device == OmniDeviceType.mobile) {
      late final ModalBottomSheetRoute<void> sheet;
      return sheet = ModalBottomSheetRoute<void>(
        settings: this,
        showDragHandle: showDragHandle,
        isScrollControlled: isScrollControlled,
        useSafeArea: true,
        builder: (_) => _currentChild(sheet, child),
      );
    }
    late final DialogRoute<void> dialog;
    return dialog = DialogRoute<void>(
      context: context,
      settings: this,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      builder: (_) {
        final content = _currentChild(dialog, child);
        final constrained = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxDialogWidth),
          child: content,
        );
        if (content is Dialog) return constrained;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: snapshot.tokens.dialogBorderRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: constrained,
        );
      },
    );
  }
}

/// Declares a route inside an [OmniApp] mapping [path] to any [Widget] (either
/// an [OmniScreen] with automatic lifecycle/Bloc hosting or a plain [Widget]).
///
/// ```dart
/// OmniPage.screen(
///   const StudentsScreen(), // uses StudentsScreen.routePath automatically
///   routes: [
///     OmniPage<StudentDetailScreen>(
///       ':id',
///       (p) => StudentDetailScreen(id: p.pathInt('id')),
///       transition: OmniPages.slide,
///     ),
///   ],
/// )
/// ```
class OmniPage<S extends Widget> extends OmniRouteBase {
  /// Creates a route at [path] displaying the widget built by [screenBuilder].
  const OmniPage(
    String this._path,
    OmniScreenBuilder<S> this._screenBuilder, {
    this.name,
    this.title,
    this.transition,
    this.guards = const [],
    this.provide = const [],
    this.blocs = const [],
    this.onExit,
    this.validateParams,
    this.onPrefetch,
    this.routes = const [],
    this.metadata,
    this.parentNavigatorKey,
    this.screenMode,
    this.statusBar,
    this.systemNavigationBar,
    this.orientation,
    this.orientations,
    this.bottomNavigationBar,
    this.bottomNavigationBarBuilder,
    this.extendBottomNavigationBar = true,
    this.hideBottomBarOnKeyboard = true,
  }) : _screen = null;

  /// Creates a route directly from a widget [screen], automatically using
  /// `screen.routePath` when [screen] is an [OmniScreen] (or [path] if
  /// supplied). Eliminates duplicate path strings and builder boilerplate.
  const OmniPage.screen(
    S this._screen, {
    String? path,
    this.name,
    this.title,
    this.transition,
    this.guards = const [],
    this.provide = const [],
    this.blocs = const [],
    this.onExit,
    this.validateParams,
    this.onPrefetch,
    this.routes = const [],
    this.metadata,
    this.parentNavigatorKey,
    this.screenMode,
    this.statusBar,
    this.systemNavigationBar,
    this.orientation,
    this.orientations,
    this.bottomNavigationBar,
    this.bottomNavigationBarBuilder,
    this.extendBottomNavigationBar = true,
    this.hideBottomBarOnKeyboard = true,
  }) : // Named `path` cannot be a private initializing formal alongside computed `get path`.
       // ignore: prefer_initializing_formals
       _path = path,
       _screenBuilder = null;

  /// Screen mode for this route (fullscreen, edge-to-edge, …); overrides the
  /// screen's own `screenMode`. The previous mode comes back on pop.
  final OmniScreenMode? screenMode;

  /// Status bar style for this route; overrides the screen's `statusBar`.
  final OmniStatusBarStyle? statusBar;

  /// System navigation bar style for this route; overrides the screen's
  /// `systemNavigationBar`.
  final OmniSystemNavigationBarStyle? systemNavigationBar;

  /// Orientation lock for this route; restored on pop.
  final OmniOrientation? orientation;

  /// Allowed orientations for this route (takes precedence over
  /// [orientation]).
  final List<DeviceOrientation>? orientations;

  /// Optional bottom navigation bar widget embedded directly inside this
  /// [OmniPage] (for example, `OmniBottomNavigationBar(...)`).
  final Widget? bottomNavigationBar;

  /// Builder variant of [bottomNavigationBar] providing [BuildContext] and
  /// matched [OmniRouteState]. Takes precedence over [bottomNavigationBar].
  final OmniBottomNavigationBarBuilder? bottomNavigationBarBuilder;

  /// Whether page content extends behind [bottomNavigationBar] (default `true`,
  /// propagating `MediaQuery.padding.bottom` to scrollables and safe areas so
  /// floating and glass bars look translucent without cutting off content).
  final bool extendBottomNavigationBar;

  /// Whether [bottomNavigationBar] collapses its bottom clearance when the
  /// software keyboard opens (default `true`).
  final bool hideBottomBarOnKeyboard;

  final String? _path;
  final OmniScreenBuilder<S>? _screenBuilder;
  final S? _screen;

  /// Path segment or full path (e.g. `'/'`, `'/students'`, `':id'`).
  /// Defaults to `screen.routePath` for [OmniPage.screen] routes.
  String get path {
    if (_path != null) return _path;
    final screen = _screen;
    if (screen is OmniScreen) return screen.routePath;
    return '';
  }

  /// Canonical route path identifying this page (alias for [path]).
  String get routePath => path;

  /// Builds the screen widget from decoded route parameters.
  OmniScreenBuilder<S> get screenBuilder =>
      _screenBuilder ?? (_) => _screen as S;

  /// Optional unique route alias for `goNamed` / `pushNamed` / `replaceNamed`.
  final String? name;

  /// Optional page title used for browser tabs and OS task switchers.
  /// Defaults to `metadata?['title']` or `OmniScreen.title`.
  final String? title;

  /// Overrides `OmniApp(transition:)` for this route.
  final OmniPageType? transition;

  /// Route-specific guards checked when navigating to this page.
  final List<OmniGuard> guards;

  /// Blocs scoped cleanly to this route page (registered on page entry and
  /// closed on pop). Works with both [OmniScreen] and plain [Widget] screens.
  final List<OmniBlocEntry> provide;

  /// Additional Blocs scoped to this route page (merged with [provide]).
  /// Lets you pass `[OmniBloc((_) => MyBloc())]` directly at page level.
  final List<OmniBlocEntry> blocs;

  /// Combined list of [provide] and [blocs].
  List<OmniBlocEntry> get effectiveProvide {
    if (blocs.isEmpty) return provide;
    if (provide.isEmpty) return blocs;
    return [...provide, ...blocs];
  }

  /// Confirmation callback before popping this page via back button or
  /// `maybePop`.
  final OmniPageExit? onExit;

  /// Optional synchronous parameter & Deep Link validator executed BEFORE any
  /// page-level Bloc or screen widget is constructed. Returning a non-null
  /// message triggers `OmniRouteException(OmniErrorCode.invalidParameter)` so
  /// invalid deep links redirect cleanly to the error page without allocating
  /// Blocs or widget elements.
  final String? Function(OmniParams params)? validateParams;

  /// Optional predictive prefetch callback invoked on desktop link hover or
  /// mobile touch-down via [OmniPrefetch] or `OmniRoute.prefetch(...)`.
  final FutureOr<void> Function(BuildContext context, OmniParams params)?
  onPrefetch;

  /// Nested child routes under this route.
  final List<OmniRouteBase> routes;

  /// Arbitrary metadata attached to this route (accessible via
  /// `OmniRouteState.metadata` and `OmniRouteEntry.metadata`).
  final Map<String, dynamic>? metadata;

  /// Optional target navigator key (e.g. root navigator key from inside a shell).
  final GlobalKey<NavigatorState>? parentNavigatorKey;

  /// Screen type [S] used by `OmniRoute.to<S>()`.
  Type get screenType => S;

  /// Whether this page was constructed via [OmniPage.screen] without an
  /// explicit non-OmniScreen path error context.
  @internal
  bool get usesScreenPath => _path == null && _screen != null;

  @override
  List<OmniRouteBase> get childRoutes => routes;

  /// Builds the [Page] for this route match with state, scope, exit guards, and
  /// resolved transition.
  @internal
  Page<void> buildPage(
    BuildContext context,
    OmniRouteState state, {
    String? fullRoutePath,
    Widget Function(BuildContext context, OmniRouteState state, Widget child)?
    wrapGroups,
    OmniPageType? groupTransition,
    OmniPageType? navTransition,
    bool? animated,
  }) {
    final config = OmniPageConfig.of(context);
    final result = _buildContent(
      context,
      state,
      config,
      fullRoutePath,
      wrapGroups,
    );

    var resolvedType = animated == false
        ? OmniPages.none
        : (navTransition ?? transition ?? groupTransition ?? config.transition);

    if ((resolvedType == OmniPages.material ||
            resolvedType == OmniPages.cupertino ||
            resolvedType == OmniPages.adaptive) &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        OmniSwipeBackDefaults.predictiveBackOf(context)) {
      resolvedType = OmniPages._androidPredictive;
    }

    return resolvedType(state.pageKey, result.routePath, result.child);
  }

  ({Widget child, String? routePath}) _buildContent(
    BuildContext context,
    OmniRouteState state,
    OmniPageConfig config,
    String? fullRoutePath,
    Widget Function(BuildContext context, OmniRouteState state, Widget child)?
    wrapGroups,
  ) {
    Widget content;
    final pageBlocs = effectiveProvide;
    String? resolvedRoutePath =
        fullRoutePath ?? (path.isNotEmpty ? path : null);

    try {
      if (validateParams case final validator?) {
        final problem = validator(OmniParams(state));
        if (problem != null && problem.isNotEmpty) {
          throw OmniRouteException(
            OmniErrorCode.invalidParameter,
            'Route ${state.uri}: $problem',
          );
        }
      }
      // Instantiate screen inside Builder if `provide`/`blocs` has page-level
      // Blocs so screen constructors or initState reading Blocs work
      // immediately, while still resolving synchronous `OmniParams` errors
      // cleanly when possible.
      Widget wrapSystemUi(Widget child, {OmniScreen? omniScreen}) {
        final effectiveMode = screenMode ?? omniScreen?.screenMode;
        final effectiveStatusBar = statusBar ?? omniScreen?.statusBar;
        final effectiveNavBar =
            systemNavigationBar ?? omniScreen?.systemNavigationBar;
        final effectiveOrientation = orientation ?? omniScreen?.orientation;
        final effectiveOrientations = orientations ?? omniScreen?.orientations;
        if (effectiveMode == null &&
            effectiveStatusBar == null &&
            effectiveNavBar == null &&
            effectiveOrientation == null &&
            effectiveOrientations == null) {
          return child;
        }
        return OmniSystemUi(
          screenMode: effectiveMode,
          statusBar: effectiveStatusBar,
          systemNavigationBar: effectiveNavBar,
          orientation: effectiveOrientation,
          orientations: effectiveOrientations,
          child: child,
        );
      }

      Widget wrapBottomBar(
        BuildContext ctx,
        Widget body, {
        OmniScreen? omniScreen,
      }) {
        final bar =
            bottomNavigationBarBuilder?.call(ctx, state) ??
            bottomNavigationBar ??
            omniScreen?.buildBottomNavigationBar(ctx);
        if (bar == null) return body;
        return OmniPageBottomBarHost(
          bottomNavigationBar: bar,
          extendBody: extendBottomNavigationBar,
          hideOnKeyboard: hideBottomBarOnKeyboard,
          child: body,
        );
      }

      Widget buildInner(BuildContext innerContext) {
        final screen = _screen ?? screenBuilder(OmniParams(state));
        if (screen is OmniScreen) {
          resolvedRoutePath ??= screen.routePath;
          final effectiveTitle =
              title ?? (metadata?['title'] as String?) ?? screen.title;
          return wrapSystemUi(
            wrapBottomBar(
              innerContext,
              hostScreen(
                screen,
                wrap: config.titles
                    ? (s) => OmniTitle(
                        title: effectiveTitle,
                        color: config.titleColor,
                        child: s,
                      )
                    : null,
              ),
              omniScreen: screen,
            ),
            omniScreen: screen,
          );
        }
        final effectiveTitle = title ?? (metadata?['title'] as String?);
        final inner = (config.titles && effectiveTitle != null)
            ? OmniTitle(
                title: effectiveTitle,
                color: config.titleColor,
                child: screen,
              )
            : screen;
        return wrapSystemUi(wrapBottomBar(innerContext, inner));
      }

      if (pageBlocs.isEmpty) {
        content = buildInner(context);
      } else {
        // Page-level BlocProviders are mounted & registered on first entry to
        // this page via OmniBlocScope.
        content = OmniBlocScope(
          provide: pageBlocs,
          child: Builder(
            builder: (innerCtx) {
              try {
                return buildInner(innerCtx);
              } on OmniRouteException catch (e) {
                return config.errorBuilder(innerCtx, state, e);
              }
            },
          ),
        );
      }

      if (onExit != null) {
        content = _OmniPageExitScope(
          pageKey: state.pageKey,
          onExit: onExit!,
          child: content,
        );
      }
    } on OmniRouteException catch (e) {
      content = config.errorBuilder(context, state, e);
    }

    if (wrapGroups != null) {
      content = wrapGroups(context, state, content);
    }

    content = OmniRouteStateScope(state: state, child: content);

    final exitWindow = config.exitWindow;
    if (exitWindow != null && OmniExitGuard.supported) {
      content = OmniExitGuard(
        window: exitWindow,
        onWarning: config.onExitWarning,
        child: content,
      );
    }

    return (child: content, routePath: resolvedRoutePath ?? name ?? title);
  }
}

class _OmniPageExitScope extends StatefulWidget {
  const _OmniPageExitScope({
    required this.pageKey,
    required this.onExit,
    required this.child,
  });

  final ValueKey<String> pageKey;
  final OmniPageExit onExit;
  final Widget child;

  @override
  State<_OmniPageExitScope> createState() => _OmniPageExitScopeState();
}

class _OmniPageExitScopeState extends State<_OmniPageExitScope> {
  // A second back press while `onExit` is still deciding (its confirm
  // dialog not up yet, or a slow async check) must not ask or pop twice.
  bool _deciding = false;

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop || _deciding) return;
    _deciding = true;
    final bool allowed;
    try {
      allowed = await widget.onExit(context);
    } finally {
      _deciding = false;
    }
    if (allowed && mounted) {
      OmniRouter.maybeOf(context)?.forcePopPage(widget.pageKey, result);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: _onPopInvoked,
    child: widget.child,
  );
}

/// Per-app page settings exposed cleanly below [OmniApp].
@internal
class OmniPageConfig extends InheritedWidget {
  /// Provides the page settings to [child].
  const OmniPageConfig({
    super.key,
    required this.transition,
    required this.titles,
    this.titleColor,
    required this.errorBuilder,
    this.exitWindow,
    this.onExitWarning,
    required super.child,
  });

  /// Defaults used when no [OmniApp] is mounted.
  static const fallback = OmniPageConfig(
    transition: OmniPages.material,
    titles: true,
    errorBuilder: defaultOmniErrorBuilder,
    child: SizedBox(),
  );

  /// Default page transition.
  final OmniPageType transition;

  /// Whether pages update browser / OS app-switcher titles.
  final bool titles;

  /// App-switcher colour, or `null` for the theme's primary colour.
  final Color? titleColor;

  /// Renders missing route or parameter parsing errors.
  final OmniErrorBuilder errorBuilder;

  /// Double-back exit window on Android root pages, or `null`.
  final Duration? exitWindow;

  /// Callback fired on the first back press when [exitWindow] is set.
  final void Function(BuildContext context)? onExitWarning;

  /// Nearest [OmniPageConfig], without registering a rebuild dependency.
  static OmniPageConfig of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OmniPageConfig>() ?? fallback;

  @override
  bool updateShouldNotify(OmniPageConfig old) =>
      old.transition != transition ||
      old.titles != titles ||
      old.titleColor != titleColor ||
      old.errorBuilder != errorBuilder ||
      old.exitWindow != exitWindow ||
      old.onExitWarning != onExitWarning;
}

/// Default error page shown for unmatched routes, invalid parameters, or
/// guard redirect loops.
Widget defaultOmniErrorBuilder(
  BuildContext context,
  OmniRouteState state,
  Object? error,
) => Scaffold(
  body: Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Page not found', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            kDebugMode ? '${state.uri}\n$error' : state.uri.path,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  ),
);
