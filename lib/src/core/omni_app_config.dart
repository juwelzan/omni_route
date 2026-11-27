import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../routing/omni_page.dart';
import '../routing/omni_route_state.dart';
import 'omni_app_features.dart';
import 'omni_onboarding_store.dart';

/// Builds a custom Onboarding screen receiving [flow] to navigate between
/// steps (`nextOnboarding`, `previousOnboarding`) or finish/skip cleanly.
typedef OmniOnboardingBuilder =
    Widget Function(BuildContext context, OmniFlowController flow);

/// Wraps a multi-screen Onboarding pager (`OmniOnboarding.screens`) with a
/// shared custom overlay (e.g. step dots, Skip button, or Next bar).
typedef OmniOnboardingOverlayBuilder =
    Widget Function(
      BuildContext context,
      OmniFlowController flow,
      Widget child,
    );

/// Decides a destination route dynamically after a flow event (e.g. login,
/// logout, or unauthenticated access).
typedef OmniFlowRedirect =
    FutureOr<String?> Function(BuildContext context, OmniRouteState state);

/// Controls when Onboarding appears and how its state is automatically stored in
/// the built-in local database across app kills & cold restarts.
enum OmniOnboardingMode {
  /// Default. Shown on first install/launch; once the user reaches the Login
  /// screen (`auth.loginRoute`/`auth.signupRoute`) OR completes/skips
  /// onboarding, it is saved in local storage and will never re-appear even if
  /// the app is cleared from background and reopened.
  onceUntilLoginScreen,

  /// Shown on every cold app launch until the user successfully completes Login
  /// (`auth.isAuthenticated == true`). Once logged in once, saved automatically
  /// in local storage so future cold restarts skip onboarding (even if cleared
  /// from background).
  untilLoggedIn,

  /// Shown on first install and saved in local storage only when Onboarding
  /// finishes/skips explicitly via `completeOnboarding` / `skipOnboarding`.
  onceAfterComplete,

  /// Shown on every launch (ignores local persistence).
  always,

  /// Completely disables Onboarding even when screens/routes are provided.
  disabled,
}

/// Configuration for the app's Splash Screen & one-time async startup work.
///
/// Pass any custom [screen] widget (`const SplashScreen()`) or [builder], plus
/// optional [onInit], [minDuration], [timeout], [manualFinish], and [onError].
@immutable
class OmniSplash {
  /// Creates Splash configuration for `OmniConfig(splash: ...)`.
  const OmniSplash({
    this.screen,
    this.builder,
    this.onInit,
    this.minDuration,
    this.timeout,
    this.manualFinish = false,
    this.onError,
  });

  /// Direct custom Splash widget (e.g. `const MySplashScreen()`).
  final Widget? screen;

  /// Context-aware builder for your custom Splash screen (takes priority over
  /// [screen] if both are provided).
  final WidgetBuilder? builder;

  /// Async initialization work run while Splash is visible (can read global
  /// repositories and Blocs from `context`).
  final Future<void> Function(BuildContext context)? onInit;

  /// Minimum time to keep Splash visible so fast startups don't flicker.
  final Duration? minDuration;

  /// Optional maximum duration for [onInit] before triggering [onError].
  final Duration? timeout;

  /// When `true`, Splash stays visible until `context.flow?.finishSplash()` is
  /// called (and any [onInit] / [minDuration] finish).
  final bool manualFinish;

  /// Custom error & retry UI shown if startup throws or times out.
  final OmniInitErrorBuilder? onError;

  /// Whether any splash widget, async init, minimum wait, or manual hold is set.
  bool get hasWork =>
      screen != null ||
      builder != null ||
      onInit != null ||
      minDuration != null ||
      manualFinish;

  /// Returns a copy with selected fields replaced.
  OmniSplash copyWith({
    Widget? screen,
    WidgetBuilder? builder,
    Future<void> Function(BuildContext context)? onInit,
    Duration? minDuration,
    Duration? timeout,
    bool? manualFinish,
    OmniInitErrorBuilder? onError,
  }) => OmniSplash(
    screen: screen ?? this.screen,
    builder: builder ?? this.builder,
    onInit: onInit ?? this.onInit,
    minDuration: minDuration ?? this.minDuration,
    timeout: timeout ?? this.timeout,
    manualFinish: manualFinish ?? this.manualFinish,
    onError: onError ?? this.onError,
  );
}

/// Configuration for any number of developer-designed Onboarding screens, with
/// automatic built-in local storage persistence.
///
/// Choose whichever screen style fits best:
/// - **Multiple widgets:** `screens: const [Step1(), Step2(), Step3()]`
/// - **Multiple builders:** `screenBuilders: [(_, flow) => Step1(flow), ...]`
/// - **Single custom view:** `builder: (context, flow) => MyOnboarding(flow)`
/// - **Named routes:** `route: '/onboarding'` or `routes: ['/ob-1', '/ob-2']`
///
/// Control persistence effortlessly with [mode], [enabled], and [persist]:
/// - [OmniOnboardingMode.onceUntilLoginScreen] *(default)*: auto-saved once
///   the user reaches the Login screen (or finishes onboarding)—clearing the app
///   from background will not re-open onboarding.
/// - [OmniOnboardingMode.untilLoggedIn]: keeps showing onboarding on restarts
///   until Login succeeds (`isAuthenticated == true`), then auto-saves in DB.
/// - Set `enabled: false` or `mode: OmniOnboardingMode.disabled` to turn off
///   onboarding completely, or `persist: false` to disable local DB saving.
@immutable
class OmniOnboarding {
  /// Creates an Onboarding configuration for `OmniConfig(onboarding: ...)`.
  const OmniOnboarding({
    this.screens = const [],
    this.screenBuilders = const [],
    this.builder,
    this.route,
    this.routes = const [],
    this.enabled = true,
    this.mode = OmniOnboardingMode.onceUntilLoginScreen,
    this.persist = true,
    this.storageKey = 'default',
    this.storage,
    this.shouldShow,
    this.alwaysShow = false,
    this.swipeable = true,
    this.overlayBuilder,
    this.onStepChanged,
    this.onDone,
    this.onSkip,
    this.afterDone,
  });

  /// Ordered list of your custom Onboarding screen widgets.
  final List<Widget> screens;

  /// Ordered list of context+flow builders for custom Onboarding screens.
  final List<OmniOnboardingBuilder> screenBuilders;

  /// Single custom Onboarding screen builder when you manage paging yourself.
  final OmniOnboardingBuilder? builder;

  /// Single route path for route-based Onboarding (automatically allowed
  /// before login).
  final String? route;

  /// Ordered list of route paths for multi-route Onboarding (automatically
  /// allowed before login).
  final List<String> routes;

  /// Master switch to turn Onboarding on (`true`) or off (`false`) anytime.
  final bool enabled;

  /// Persistence policy controlling when Onboarding stops re-showing after
  /// clearing/reopening the app.
  final OmniOnboardingMode mode;

  /// Whether to save state automatically in the built-in local database
  /// (`false` disables persistence so [always] / session-only behavior applies).
  final bool persist;

  /// Logical key separating persisted onboarding versions (e.g. `'v1'`, `'v2'`).
  final String storageKey;

  /// Optional custom storage backend overriding OmniRoute's automatic
  /// `SharedPreferences` local database.
  final OmniLocalStore? storage;

  /// Extra optional condition checked before entering Onboarding.
  final FutureOr<bool> Function(BuildContext context)? shouldShow;

  /// Shorthand alias for `mode: OmniOnboardingMode.always`.
  final bool alwaysShow;

  /// Enables horizontal swipe between pages when [screens] or
  /// [screenBuilders] has more than 1 screen.
  final bool swipeable;

  /// Optional shared overlay around your Onboarding pages (for custom progress
  /// dots, Next/Skip buttons, etc.).
  final OmniOnboardingOverlayBuilder? overlayBuilder;

  /// Called whenever the active onboarding step index changes.
  final ValueChanged<int>? onStepChanged;

  /// Runs when Onboarding completes (or skips), e.g. analytics hooks.
  final FutureOr<void> Function(BuildContext context)? onDone;

  /// Runs right before [onDone] when the user skips Onboarding.
  final FutureOr<void> Function(BuildContext context)? onSkip;

  /// Optional destination route after Onboarding finishes (`null` delegates to
  /// auth/home routing).
  final FutureOr<String?> Function(BuildContext context)? afterDone;

  /// Effective mode accounting for [enabled] and [alwaysShow].
  OmniOnboardingMode get effectiveMode {
    if (!enabled || mode == OmniOnboardingMode.disabled) {
      return OmniOnboardingMode.disabled;
    }
    if (alwaysShow) return OmniOnboardingMode.always;
    return mode;
  }

  /// Whether automatic local database persistence applies for this config.
  bool get usesPersistence =>
      persist &&
      effectiveMode != OmniOnboardingMode.disabled &&
      effectiveMode != OmniOnboardingMode.always;

  /// Normalized list of declared onboarding route paths, if using routes.
  List<String> get effectiveRoutes {
    if (routes.isNotEmpty) return routes;
    if (route != null) return [route!];
    return const [];
  }

  /// Total number of onboarding screens/routes configured.
  int get screenCount {
    if (screens.isNotEmpty) return screens.length;
    if (screenBuilders.isNotEmpty) return screenBuilders.length;
    if (builder != null) return 1;
    return effectiveRoutes.length;
  }

  /// Whether widget-based onboarding (`screens`, `screenBuilders`, or `builder`)
  /// is configured and enabled.
  bool get hasWidgetMode =>
      effectiveMode != OmniOnboardingMode.disabled &&
      (screens.isNotEmpty || screenBuilders.isNotEmpty || builder != null);

  /// Whether any onboarding screen or route is active.
  bool get hasContent =>
      effectiveMode != OmniOnboardingMode.disabled &&
      (hasWidgetMode || effectiveRoutes.isNotEmpty);

  /// Returns a copy with selected fields replaced.
  OmniOnboarding copyWith({
    List<Widget>? screens,
    List<OmniOnboardingBuilder>? screenBuilders,
    OmniOnboardingBuilder? builder,
    String? route,
    List<String>? routes,
    bool? enabled,
    OmniOnboardingMode? mode,
    bool? persist,
    String? storageKey,
    OmniLocalStore? storage,
    FutureOr<bool> Function(BuildContext context)? shouldShow,
    bool? alwaysShow,
    bool? swipeable,
    OmniOnboardingOverlayBuilder? overlayBuilder,
    ValueChanged<int>? onStepChanged,
    FutureOr<void> Function(BuildContext context)? onDone,
    FutureOr<void> Function(BuildContext context)? onSkip,
    FutureOr<String?> Function(BuildContext context)? afterDone,
  }) => OmniOnboarding(
    screens: screens ?? this.screens,
    screenBuilders: screenBuilders ?? this.screenBuilders,
    builder: builder ?? this.builder,
    route: route ?? this.route,
    routes: routes ?? this.routes,
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    persist: persist ?? this.persist,
    storageKey: storageKey ?? this.storageKey,
    storage: storage ?? this.storage,
    shouldShow: shouldShow ?? this.shouldShow,
    alwaysShow: alwaysShow ?? this.alwaysShow,
    swipeable: swipeable ?? this.swipeable,
    overlayBuilder: overlayBuilder ?? this.overlayBuilder,
    onStepChanged: onStepChanged ?? this.onStepChanged,
    onDone: onDone ?? this.onDone,
    onSkip: onSkip ?? this.onSkip,
    afterDone: afterDone ?? this.afterDone,
  );
}

/// Configuration for Auth gating, Login, Sign Up, and Home routing.
///
/// Pass your [loginScreen] / [signupScreen] directly (or [loginBuilder] /
/// [signupBuilder] if they need URL parameters), plus [isAuthenticated] and
/// optional reactive [refreshStream] / [refreshListenable].
@immutable
class OmniAuthConfig {
  /// Creates Auth & Login/Signup flow configuration for `OmniConfig(auth: ...)`.
  const OmniAuthConfig({
    this.isAuthenticated,
    this.refreshStream,
    this.refreshListenable,
    this.loginRoute = '/login',
    this.loginScreen,
    this.loginBuilder,
    this.signupRoute = '/signup',
    this.signupScreen,
    this.signupBuilder,
    this.homeRoute = '/',
    this.afterLogin,
    this.afterLogout,
    this.onUnauthenticated,
    this.blockAuthWhenLoggedIn = true,
    this.preserveRedirectQuery = true,
  });

  /// Returns `true` when the user is signed in.
  final bool Function(BuildContext context)? isAuthenticated;

  /// Auth state stream (e.g. `(c) => c.read<AuthBloc>().stream`) that triggers
  /// instant Login <-> Home transitions cleanly.
  final Stream<Object?> Function(BuildContext context)? refreshStream;

  /// Optional [Listenable] (e.g. `ChangeNotifier`) triggering auth re-checks.
  final Listenable? refreshListenable;

  /// Route path of the Login screen.
  final String loginRoute;

  /// Direct custom Login screen widget (registered automatically at [loginRoute]
  /// if not already declared in `routes`).
  final Widget? loginScreen;

  /// Parameterized builder for your Login screen (`(p) => LoginScreen(...)`).
  /// Takes priority over [loginScreen] when both are set.
  final OmniScreenBuilder<Widget>? loginBuilder;

  /// Route path of the Sign Up screen (`null` if your app has no signup page).
  final String? signupRoute;

  /// Direct custom Sign Up screen widget (registered automatically at
  /// [signupRoute] if not already declared in `routes`).
  final Widget? signupScreen;

  /// Parameterized builder for your Sign Up screen (`(p) => SignupScreen(...)`).
  final OmniScreenBuilder<Widget>? signupBuilder;

  /// Primary authenticated destination route.
  final String homeRoute;

  /// Custom redirect destination after logging in (`null` returns to `?from=`
  /// when [preserveRedirectQuery] is `true`, otherwise [homeRoute]).
  final OmniFlowRedirect? afterLogin;

  /// Custom destination resolver invoked by `context.flow?.logout()` (`null`
  /// navigates cleanly to [loginRoute]).
  final FutureOr<String?> Function(BuildContext context)? afterLogout;

  /// Custom redirect resolver when a logged-out user visits a protected route
  /// (`null` redirects to `loginRoute` with optional `?from=...`).
  final OmniFlowRedirect? onUnauthenticated;

  /// Redirects logged-in users away from [loginRoute]/[signupRoute] to
  /// [homeRoute] and prevents returning via Web browser Back.
  final bool blockAuthWhenLoggedIn;

  /// Preserves `?from=<targetUri>` when redirecting unauthenticated users so
  /// they return to their deep link after logging in.
  final bool preserveRedirectQuery;

  /// Returns a copy with selected fields replaced.
  OmniAuthConfig copyWith({
    bool Function(BuildContext context)? isAuthenticated,
    Stream<Object?> Function(BuildContext context)? refreshStream,
    Listenable? refreshListenable,
    String? loginRoute,
    Widget? loginScreen,
    OmniScreenBuilder<Widget>? loginBuilder,
    String? signupRoute,
    Widget? signupScreen,
    OmniScreenBuilder<Widget>? signupBuilder,
    String? homeRoute,
    OmniFlowRedirect? afterLogin,
    FutureOr<String?> Function(BuildContext context)? afterLogout,
    OmniFlowRedirect? onUnauthenticated,
    bool? blockAuthWhenLoggedIn,
    bool? preserveRedirectQuery,
  }) => OmniAuthConfig(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    refreshStream: refreshStream ?? this.refreshStream,
    refreshListenable: refreshListenable ?? this.refreshListenable,
    loginRoute: loginRoute ?? this.loginRoute,
    loginScreen: loginScreen ?? this.loginScreen,
    loginBuilder: loginBuilder ?? this.loginBuilder,
    signupRoute: signupRoute ?? this.signupRoute,
    signupScreen: signupScreen ?? this.signupScreen,
    signupBuilder: signupBuilder ?? this.signupBuilder,
    homeRoute: homeRoute ?? this.homeRoute,
    afterLogin: afterLogin ?? this.afterLogin,
    afterLogout: afterLogout ?? this.afterLogout,
    onUnauthenticated: onUnauthenticated ?? this.onUnauthenticated,
    blockAuthWhenLoggedIn: blockAuthWhenLoggedIn ?? this.blockAuthWhenLoggedIn,
    preserveRedirectQuery: preserveRedirectQuery ?? this.preserveRedirectQuery,
  );
}

/// Outcome status returned by [OmniAppGate.check].
enum OmniGateStatus {
  /// App is healthy and allowed to proceed normally.
  ready,

  /// App is temporarily paused for backend maintenance.
  maintenance,

  /// User must update (or optionally dismiss when `canDismiss` is `true`).
  updateRequired,
}

/// Decision returned by [OmniAppGate.check] during startup or `context.flow?.refresh()`.
@immutable
class OmniGateDecision {
  /// Creates an app gate decision.
  const OmniGateDecision({
    required this.status,
    this.title,
    this.message,
    this.minVersion,
    this.currentVersion,
    this.storeUrl,
    this.canDismiss = false,
  });

  /// Normal healthy startup shortcut.
  static const ready = OmniGateDecision(status: OmniGateStatus.ready);

  /// Gate outcome (`ready`, `maintenance`, or `updateRequired`).
  final OmniGateStatus status;

  /// Optional heading rendered in default maintenance / update views.
  final String? title;

  /// Optional description rendered in default maintenance / update views.
  final String? message;

  /// Optional required version string for update prompts.
  final String? minVersion;

  /// Optional currently installed version string for display.
  final String? currentVersion;

  /// Optional app-store link or metadata passed to custom builders.
  final String? storeUrl;

  /// Whether user can dismiss an update gate temporarily and continue into
  /// the app. Always ignored for [OmniGateStatus.maintenance].
  final bool canDismiss;
}

/// Optional Maintenance & Force-Update startup gate checked inside `OmniConfig`
/// after `splash.onInit` finishes (zero cost when omitted).
@immutable
class OmniAppGate {
  /// Creates a maintenance / force-update gate configuration.
  const OmniAppGate({
    required this.check,
    this.maintenanceBuilder,
    this.updateBuilder,
  });

  /// Checks whether the app can proceed, is under maintenance, or requires an
  /// update. Can safely read `OmniRepo` clients via `context`.
  final FutureOr<OmniGateDecision?> Function(BuildContext context) check;

  /// Custom widget shown when `status == OmniGateStatus.maintenance`. Receives
  /// [retry] callback to re-run the check.
  final Widget Function(
    BuildContext context,
    OmniGateDecision decision,
    VoidCallback retry,
  )?
  maintenanceBuilder;

  /// Custom widget shown when `status == OmniGateStatus.updateRequired`.
  /// Receives [continueAnyway] (non-null only when `decision.canDismiss` is
  /// `true`) and [retry].
  final Widget Function(
    BuildContext context,
    OmniGateDecision decision,
    VoidCallback? continueAnyway,
    VoidCallback retry,
  )?
  updateBuilder;
}

/// Centralized, user-friendly configuration for **Splash**, **Onboarding**,
/// **Auth (Login / Sign Up / Home)**, **Public pre-login screens**, and
/// optional **Maintenance / Force-Update Gate** inside [OmniApp],
/// [OmniApp.material], and [OmniApp.cupertino].
@immutable
class OmniConfig {
  /// Creates an entry-flow & auth configuration passed via `OmniApp(config:)`.
  const OmniConfig({
    this.splash,
    this.onboarding,
    this.auth,
    this.gate,
    this.publicScreens = const {},
    this.publicPages = const [],
    this.publicRoutes = const [],
    this.resolveInitialRoute,
  });

  /// Splash screen widget/builder, startup `onInit`, timing, and error UI.
  final OmniSplash? splash;

  /// One or many developer-supplied Onboarding screens with built-in local DB
  /// persistence controls.
  final OmniOnboarding? onboarding;

  /// Login, Sign Up, Home, and authentication guard configuration.
  final OmniAuthConfig? auth;

  /// Optional Maintenance & Force-Update gate evaluated cleanly on startup.
  final OmniAppGate? gate;

  /// Map of `routePath -> Widget` screens automatically registered AND
  /// accessible without logging in (e.g. `{'/about': const AboutScreen()}`).
  final Map<String, Widget> publicScreens;

  /// Declarative public [OmniPage] / [OmniRouteBase] screens (ideal for dynamic
  /// parameters like `'/article/:id'` or `OmniPage.screen(...)`), automatically
  /// registered and accessible before login.
  final List<OmniRouteBase> publicPages;

  /// Route patterns (`'/terms'`, `'/article/:id'`, `'/docs/*'`) declared in
  /// `OmniApp(routes:)` that remain accessible before login.
  final List<String> publicRoutes;

  /// Optional async callback choosing the initial route after Splash/Onboarding.
  final OmniInitialRouteResolver? resolveInitialRoute;

  /// Whether any Splash, Onboarding, App Gate, or dynamic initial route gate is
  /// active.
  bool get hasStartupGate =>
      (splash?.hasWork ?? false) ||
      (onboarding?.hasContent ?? false) ||
      gate != null ||
      resolveInitialRoute != null;

  /// Whether Auth protection or route-based Onboarding gating is active.
  bool get hasAuthGuard =>
      auth?.isAuthenticated != null ||
      ((onboarding?.hasContent ?? false) &&
          (onboarding?.effectiveRoutes.isNotEmpty ?? false));

  /// Returns a copy with selected fields replaced.
  OmniConfig copyWith({
    OmniSplash? splash,
    OmniOnboarding? onboarding,
    OmniAuthConfig? auth,
    OmniAppGate? gate,
    Map<String, Widget>? publicScreens,
    List<OmniRouteBase>? publicPages,
    List<String>? publicRoutes,
    OmniInitialRouteResolver? resolveInitialRoute,
  }) => OmniConfig(
    splash: splash ?? this.splash,
    onboarding: onboarding ?? this.onboarding,
    auth: auth ?? this.auth,
    gate: gate ?? this.gate,
    publicScreens: publicScreens ?? this.publicScreens,
    publicPages: publicPages ?? this.publicPages,
    publicRoutes: publicRoutes ?? this.publicRoutes,
    resolveInitialRoute: resolveInitialRoute ?? this.resolveInitialRoute,
  );
}

/// Runtime controller for [OmniConfig] flows (`context.flow` and passed to
/// custom [OmniOnboarding] builders).
abstract interface class OmniFlowController {
  /// Completes a manual Splash screen (`OmniSplash(manualFinish: true)`) and
  /// moves to Onboarding or the app.
  void finishSplash();

  /// Restarts the entire startup sequence (Splash -> Onboarding -> App).
  void restartStartup();

  /// Zero-based index of the currently visible Onboarding screen/route.
  int get onboardingStep;

  /// Total count of configured Onboarding screens/routes.
  int get onboardingCount;

  /// Whether the first Onboarding screen is currently active.
  bool get isFirstOnboardingStep;

  /// Whether the last Onboarding screen is currently active.
  bool get isLastOnboardingStep;

  /// Reactive listenable tracking [onboardingStep] changes for custom dots or
  /// progress bars.
  ValueListenable<int> get onboardingStepListenable;

  /// Advances to the next Onboarding screen, or completes Onboarding (using
  /// optional [redirectTo]) when already on the last screen.
  Future<void> nextOnboarding({String? redirectTo});

  /// Returns to the previous Onboarding screen if [onboardingStep] > 0.
  void previousOnboarding();

  /// Jumps directly to Onboarding screen at [index].
  void goToOnboardingStep(int index);

  /// Marks Onboarding completed, runs `onDone`, updates local storage per
  /// [OmniOnboarding.mode], and moves cleanly to [redirectTo], `afterDone`, or
  /// auth/home.
  Future<void> completeOnboarding({String? redirectTo});

  /// Runs `onSkip` + `onDone`, updates local storage per [OmniOnboarding.mode],
  /// and moves cleanly out of Onboarding to [redirectTo], `afterDone`, or
  /// auth/home.
  Future<void> skipOnboarding({String? redirectTo});

  /// Re-opens Onboarding cleanly (e.g. from Settings).
  void replayOnboarding();

  /// Clears saved onboarding progress from the local database so Onboarding will
  /// show again (and opens it immediately when [replay] is `true`).
  Future<void> resetOnboarding({bool replay = false});

  /// Opens `auth.loginRoute` (optional `?from=`), replacing active history.
  void goToLogin({String? from});

  /// Opens `auth.signupRoute` (preserving `?from=` if present), replacing
  /// active history.
  void goToSignup();

  /// Opens `auth.homeRoute` replacing stack & browser Back history.
  void goToHome();

  /// Navigates cleanly to a public route [path] (clearing stack/onboarding if
  /// needed).
  void goToPublic(String path);

  /// Pushes a public screen [path] on top of the current page (e.g. Terms /
  /// Privacy from Login or Signup so Back returns right back to Login).
  Future<T?> pushPublic<T extends Object?>(String path, {Object? extra});

  /// Runs optional [onLogout] cleanup and navigates cleanly to `afterLogout` or
  /// `auth.loginRoute` with history replaced.
  Future<void> logout([
    FutureOr<void> Function(BuildContext context)? onLogout,
  ]);

  /// Immediately re-evaluates guards (e.g. after updating Auth state).
  void refresh();
}

/// Provides [OmniFlowController] (`context.flow`) to Splash, Onboarding, Auth,
/// Public, and main app screens.
class OmniFlowScope extends InheritedWidget {
  /// Exposes [controller] to [child].
  const OmniFlowScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// Active flow controller for this [OmniApp].
  final OmniFlowController controller;

  /// Returns the nearest [OmniFlowController] or throws if not available.
  static OmniFlowController of(BuildContext context) =>
      maybeOf(context) ??
      (throw FlutterError(
        'OmniFlowScope.of(context) called without an enclosing OmniApp.',
      ));

  /// Returns the nearest [OmniFlowController], or `null` when unavailable.
  static OmniFlowController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OmniFlowScope>()?.controller;

  @override
  bool updateShouldNotify(OmniFlowScope oldWidget) =>
      !identical(oldWidget.controller, controller);
}
