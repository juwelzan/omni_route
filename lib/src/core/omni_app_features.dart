import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../guards/omni_guard.dart';
import 'package:omni_responsive/integration.dart';
import 'package:omni_responsive/omni_responsive.dart';
import '../routing/omni_page.dart';
import '../routing/omni_route_state.dart';
import '../routing/omni_trie.dart';
import '../screens/omni_lifecycle.dart';
import 'omni_app_config.dart';
import 'omni_onboarding_store.dart';
import 'omni_router.dart';

/// Runs app-wide [OmniLifecycle] hooks (`OmniApp(lifecycle:)`). The context
/// passed to hooks is below the global Blocs.
@internal
class OmniAppLifecycleScope extends StatefulWidget {
  /// Observes the app for [lifecycle].
  const OmniAppLifecycleScope({
    super.key,
    required this.lifecycle,
    required this.child,
  });

  /// The hooks object.
  final OmniLifecycle lifecycle;

  /// The app below.
  final Widget child;

  @override
  State<OmniAppLifecycleScope> createState() => _OmniAppLifecycleScopeState();
}

class _OmniAppLifecycleScopeState extends State<OmniAppLifecycleScope> {
  late final OmniLifecycleHub _hub = OmniLifecycleHub(
    context as Element,
    () => widget.lifecycle,
  );

  @override
  void initState() {
    super.initState();
    _hub; // start observing
  }

  @override
  void dispose() {
    _hub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Error builder rendered by [OmniInitGate] when startup (`onInit`) fails and
/// `onError` is provided; invoking [retry] restarts startup initialization.
typedef OmniInitErrorBuilder =
    Widget Function(
      BuildContext context,
      Object error,
      StackTrace stack,
      VoidCallback retry,
    );

/// Asynchronous callback executed after startup completes to pick a starting
/// route (e.g. `'/onboarding'` vs `'/dashboard'`).
typedef OmniInitialRouteResolver = FutureOr<String?> Function(BuildContext context);

/// Mutable per-[OmniApp] session state shared between [OmniInitGate] and
/// [OmniConfigGuard].
@internal
class OmniFlowSession {
  /// Whether onboarding was finished or skipped during this app session.
  bool onboardingCompleted = false;

  /// Whether route-based onboarding (`OmniOnboarding.route` / `routes`) is
  /// currently active and guarding protected navigation.
  bool onboardingPending = false;

  /// Active route-based onboarding step index.
  int onboardingRouteStep = 0;

  /// Last storage key marked persisted in this session (avoids redundant writes).
  String? persistedMarkedKey;
}

/// Normalizes a route path pattern (`trim`, leading `/`, no trailing `/`).
@internal
String normalizeOmniConfigPath(String raw) {
  var p = raw.trim();
  if (p.isEmpty) return '/';
  if (!p.startsWith('/')) p = '/$p';
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

/// Collects every full route pattern inside [nodes] following `OmniRouteRegistry`
/// relative/absolute joining rules.
@internal
void collectOmniConfigRoutePaths(
  List<OmniRouteBase> nodes,
  Set<String> out, {
  String parentPath = '',
  bool topLevel = true,
}) {
  for (final node in nodes) {
    if (node is OmniPage) {
      var nodePath = node.path;
      if (!topLevel &&
          parentPath != '/' &&
          nodePath.startsWith('$parentPath/')) {
        nodePath = nodePath.substring(parentPath.length + 1);
      }
      final trimmed = nodePath.trim();
      if (trimmed.isNotEmpty) {
        final fullPath = topLevel || trimmed.startsWith('/')
            ? normalizeOmniConfigPath(trimmed)
            : normalizeOmniConfigPath(
                parentPath == '/' ? '/$trimmed' : '$parentPath/$trimmed',
              );
        out.add(fullPath);
        collectOmniConfigRoutePaths(
          node.routes,
          out,
          parentPath: fullPath,
          topLevel: false,
        );
      }
    } else {
      collectOmniConfigRoutePaths(
        node.childRoutes,
        out,
        parentPath: parentPath,
        topLevel: topLevel,
      );
    }
  }
}

/// Combines developer [routes] with optional `publicScreens`, `publicPages`,
/// and [OmniAuthConfig] `login` / `signup` screens declared on [config].
@internal
List<OmniRouteBase> buildOmniConfigRoutes(
  List<OmniRouteBase> routes,
  OmniConfig? config,
) {
  if (config == null) return routes;
  final auth = config.auth;
  final hasLogin =
      auth != null && (auth.loginBuilder != null || auth.loginScreen != null);
  final hasSignup =
      auth != null &&
      auth.signupRoute != null &&
      (auth.signupBuilder != null || auth.signupScreen != null);
  final hasExtras =
      config.publicScreens.isNotEmpty ||
      config.publicPages.isNotEmpty ||
      hasLogin ||
      hasSignup;
  if (!hasExtras) return routes;

  final declared = <String>{};
  collectOmniConfigRoutePaths(routes, declared);

  final out = <OmniRouteBase>[...routes];

  for (final entry in config.publicScreens.entries) {
    final loc = normalizeOmniConfigPath(entry.key);
    if (!declared.contains(loc)) {
      final widget = entry.value;
      out.add(OmniPage<Widget>(loc, (_) => widget));
      declared.add(loc);
    }
  }

  for (final page in config.publicPages) {
    final pagePaths = <String>{};
    collectOmniConfigRoutePaths([page], pagePaths);
    if (pagePaths.isEmpty || !pagePaths.every(declared.contains)) {
      out.add(page);
      declared.addAll(pagePaths);
    }
  }

  if (hasLogin) {
    final loginLoc = normalizeOmniConfigPath(auth.loginRoute);
    if (!declared.contains(loginLoc)) {
      final builder = auth.loginBuilder ?? (_) => auth.loginScreen!;
      out.add(OmniPage<Widget>(loginLoc, builder));
      declared.add(loginLoc);
    }
  }

  if (hasSignup) {
    final signupLoc = normalizeOmniConfigPath(auth.signupRoute!);
    if (!declared.contains(signupLoc)) {
      final builder = auth.signupBuilder ?? (_) => auth.signupScreen!;
      out.add(OmniPage<Widget>(signupLoc, builder));
      declared.add(signupLoc);
    }
  }

  return out;
}

/// Guard implementing [OmniConfig] rules for route-based onboarding, [OmniAuthConfig]
/// login/signup/home protection, automatic onboarding persistence triggers, and
/// pre-login public screens/routes.
@internal
class OmniConfigGuard extends OmniGuard {
  /// Builds the guard from [config] and shared [session].
  OmniConfigGuard({required this.config, required this.session})
    : _publicTrie = _buildPublicTrie(config);

  /// Active flow configuration.
  final OmniConfig config;

  /// Shared onboarding/startup session flags.
  final OmniFlowSession session;

  final OmniRouteTrie<bool> _publicTrie;

  static OmniRouteTrie<bool> _buildPublicTrie(OmniConfig config) {
    final trie = OmniRouteTrie<bool>();
    for (final raw in config.publicRoutes) {
      trie.insert(normalizeOmniConfigPath(raw), true);
    }
    for (final raw in config.publicScreens.keys) {
      trie.insert(normalizeOmniConfigPath(raw), true);
    }
    if (config.publicPages.isNotEmpty) {
      final pagePaths = <String>{};
      collectOmniConfigRoutePaths(config.publicPages, pagePaths);
      for (final p in pagePaths) {
        trie.insert(p, true);
      }
    }
    return trie;
  }

  void _markOnboardingPersisted(OmniOnboarding ob) {
    if (!ob.usesPersistence) return;
    if (session.persistedMarkedKey == ob.storageKey) return;
    session.persistedMarkedKey = ob.storageKey;
    session.onboardingCompleted = true;
    unawaited(
      OmniOnboardingStore.markDone(ob.storageKey, customStore: ob.storage),
    );
  }

  @override
  Stream<Object?>? refresh(BuildContext context) =>
      config.auth?.refreshStream?.call(context);

  @override
  FutureOr<String?> redirect(BuildContext context, OmniRouteState state) {
    final loc = normalizeOmniConfigPath(state.matchedLocation);
    final ob = config.onboarding;
    final obEnabled = ob != null && ob.hasContent;
    final obRoutes = [
      if (obEnabled)
        for (final r in ob.effectiveRoutes) normalizeOmniConfigPath(r),
    ];

    if (obRoutes.isNotEmpty) {
      final idx = obRoutes.indexOf(loc);
      if (session.onboardingPending && idx < 0) {
        final targetIdx = session.onboardingRouteStep.clamp(
          0,
          obRoutes.length - 1,
        );
        return obRoutes[targetIdx];
      }
      if (idx >= 0) {
        session.onboardingRouteStep = idx;
        return null;
      }
    }

    final auth = config.auth;
    if (auth == null) return null;

    final loginLoc = normalizeOmniConfigPath(auth.loginRoute);
    final signupRaw = auth.signupRoute;
    final signupLoc = signupRaw == null
        ? null
        : normalizeOmniConfigPath(signupRaw);
    final isAuthRoute = loc == loginLoc || (signupLoc != null && loc == signupLoc);

    // Entering Login/Signup marks onboarding done in local storage under
    // onceUntilLoginScreen mode—even if the user leaves before signing in.
    if (isAuthRoute &&
        ob != null &&
        ob.usesPersistence &&
        ob.effectiveMode == OmniOnboardingMode.onceUntilLoginScreen) {
      _markOnboardingPersisted(ob);
    }

    final authCheck = auth.isAuthenticated;
    if (authCheck == null) return null;

    final authed = authCheck(context);
    final homeLoc = normalizeOmniConfigPath(auth.homeRoute);
    final isPublic = _publicTrie.matchUri(state.uri) != null;

    if (authed &&
        ob != null &&
        ob.usesPersistence &&
        (ob.effectiveMode == OmniOnboardingMode.untilLoggedIn ||
            ob.effectiveMode == OmniOnboardingMode.onceUntilLoginScreen)) {
      _markOnboardingPersisted(ob);
    }

    if (!authed) {
      if (isAuthRoute || isPublic) return null;
      final custom = auth.onUnauthenticated;
      if (custom != null) {
        final res = custom(context, state);
        if (res is Future<String?>) {
          return res.then(
            (v) => v ?? _defaultLoginRedirect(auth, state, loginLoc, homeLoc),
          );
        }
        return res ?? _defaultLoginRedirect(auth, state, loginLoc, homeLoc);
      }
      return _defaultLoginRedirect(auth, state, loginLoc, homeLoc);
    }

    if (auth.blockAuthWhenLoggedIn && isAuthRoute) {
      final custom = auth.afterLogin;
      if (custom != null) {
        final res = custom(context, state);
        if (res is Future<String?>) {
          return res.then(
            (v) =>
                v ??
                _defaultPostLoginTarget(
                  auth,
                  state,
                  homeLoc,
                  loginLoc,
                  signupLoc,
                  obRoutes,
                ),
          );
        }
        return res ??
            _defaultPostLoginTarget(
              auth,
              state,
              homeLoc,
              loginLoc,
              signupLoc,
              obRoutes,
            );
      }
      return _defaultPostLoginTarget(
        auth,
        state,
        homeLoc,
        loginLoc,
        signupLoc,
        obRoutes,
      );
    }

    return null;
  }

  String _defaultLoginRedirect(
    OmniAuthConfig auth,
    OmniRouteState state,
    String loginLoc,
    String homeLoc,
  ) {
    if (!auth.preserveRedirectQuery) return loginLoc;
    final requested = state.uri.toString();
    final pathOnly = normalizeOmniConfigPath(state.matchedLocation);
    if (requested == '/' ||
        (pathOnly == homeLoc && state.uri.queryParameters.isEmpty)) {
      return loginLoc;
    }
    return Uri(path: loginLoc, queryParameters: {'from': requested}).toString();
  }

  String _defaultPostLoginTarget(
    OmniAuthConfig auth,
    OmniRouteState state,
    String homeLoc,
    String loginLoc,
    String? signupLoc,
    List<String> obRoutes,
  ) {
    if (auth.preserveRedirectQuery) {
      final from = state.queryParameters['from'];
      if (from != null && from.startsWith('/') && !from.startsWith('//')) {
        final parsed = Uri.tryParse(from);
        if (parsed != null) {
          final targetPath = normalizeOmniConfigPath(parsed.path);
          if (targetPath != loginLoc &&
              targetPath != signupLoc &&
              !obRoutes.contains(targetPath)) {
            return from;
          }
        }
      }
    }
    return homeLoc;
  }
}

enum _StartupPhase {
  splash,
  maintenance,
  updateRequired,
  onboarding,
  app,
  error,
}

/// Runs [OmniConfig] startup, Splash, multi-screen or single Onboarding,
/// automatic local DB persistence, and runtime [OmniFlowController] actions
/// via [OmniFlowScope] (`context.flow`).
@internal
class OmniInitGate extends StatefulWidget {
  /// Creates the startup & flow gate wrapping [child].
  const OmniInitGate({
    super.key,
    required this.child,
    required this.config,
    required this.session,
    this.router,
  });

  /// Effective flow & startup configuration.
  final OmniConfig config;

  /// Shared onboarding/startup session state.
  final OmniFlowSession session;

  /// Router controlled by [OmniFlowController] actions.
  final OmniRouter? router;

  /// Main router application widget shown once Splash/Onboarding allow entry.
  final Widget child;

  @override
  State<OmniInitGate> createState() => _OmniInitGateState();
}

class _OmniInitGateState extends State<OmniInitGate>
    implements OmniFlowController {
  _StartupPhase _phase = _StartupPhase.app;
  Object? _error;
  StackTrace? _stack;
  OmniGateDecision? _gateDecision;
  bool _gateDismissed = false;
  int _runEpoch = 0;
  bool _manualSplashDone = false;
  Completer<void>? _manualSplashCompleter;
  final Set<Timer> _timers = {};
  final ValueNotifier<int> _stepNotifier = ValueNotifier<int>(0);
  PageController? _pageController;
  final Set<PageController> _pendingControllers = {};
  int? _programmaticTarget;

  bool get _hasAsyncSplashStage {
    final sp = widget.config.splash;
    return (sp?.hasWork ?? false) ||
        widget.config.gate != null ||
        widget.config.resolveInitialRoute != null;
  }

  List<String> get _normalizedObRoutes => [
    for (final r in widget.config.onboarding?.effectiveRoutes ?? const <String>[])
      normalizeOmniConfigPath(r),
  ];

  int get _widgetOnboardingCount {
    final ob = widget.config.onboarding;
    if (ob == null || !ob.hasWidgetMode) return 0;
    if (ob.screens.isNotEmpty) return ob.screens.length;
    if (ob.screenBuilders.isNotEmpty) return ob.screenBuilders.length;
    if (ob.builder != null) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    widget.router?.currentListenable.addListener(_syncRouteStep);

    final cfg = widget.config;
    if (!cfg.hasStartupGate) {
      _phase = _StartupPhase.app;
      return;
    }

    final ob = cfg.onboarding;
    if (!_hasAsyncSplashStage &&
        ob != null &&
        ob.hasContent &&
        !ob.usesPersistence) {
      final mode = ob.effectiveMode;
      final decision = mode == OmniOnboardingMode.always
          ? true
          : ob.shouldShow == null
          ? !widget.session.onboardingCompleted
          : ob.shouldShow!(context);
      if (decision is bool) {
        if (!decision) {
          _phase = _StartupPhase.app;
          return;
        }
        if (ob.hasWidgetMode) {
          _enterWidgetOnboarding(setStateNow: false);
          return;
        }
        final routes = _normalizedObRoutes;
        if (routes.isNotEmpty) {
          widget.session.onboardingPending = true;
          widget.session.onboardingRouteStep = 0;
          _stepNotifier.value = 0;
          widget.router?.go(routes.first, animated: false, replaceHistory: true);
          _phase = _StartupPhase.app;
          return;
        }
      }
      _phase = _StartupPhase.splash;
      _run(pendingDecision: decision is Future<bool> ? decision : null);
      return;
    }

    _phase = _StartupPhase.splash;
    _run();
  }

  @override
  void didUpdateWidget(OmniInitGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.router, widget.router)) {
      oldWidget.router?.currentListenable.removeListener(_syncRouteStep);
      widget.router?.currentListenable.addListener(_syncRouteStep);
    }
    if (!oldWidget.config.hasStartupGate && widget.config.hasStartupGate) {
      restartStartup();
    } else if (oldWidget.config.hasStartupGate &&
        !widget.config.hasStartupGate &&
        _phase != _StartupPhase.app) {
      _runEpoch++;
      _cancelTimers();
      _retirePageController();
      widget.session.onboardingPending = false;
      setState(() {
        _error = null;
        _stack = null;
        _phase = _StartupPhase.app;
      });
    }
  }

  @override
  void dispose() {
    _runEpoch++;
    widget.router?.currentListenable.removeListener(_syncRouteStep);
    _cancelTimers();
    _completeManualSplash();
    _pageController?.dispose();
    _pageController = null;
    for (final c in _pendingControllers) {
      c.dispose();
    }
    _pendingControllers.clear();
    _stepNotifier.dispose();
    super.dispose();
  }

  void _syncRouteStep() {
    if (!mounted) return;
    final ob = widget.config.onboarding;
    if (ob == null || !ob.hasContent || ob.hasWidgetMode) return;
    final routes = _normalizedObRoutes;
    if (routes.isEmpty) return;
    final loc = normalizeOmniConfigPath(
      widget.router?.currentListenable.value.location.split('?').first ?? '/',
    );
    final idx = routes.indexOf(loc);
    if (idx >= 0 && _stepNotifier.value != idx) {
      widget.session.onboardingRouteStep = idx;
      _stepNotifier.value = idx;
    }
  }

  void _retirePageController() {
    final prev = _pageController;
    _pageController = null;
    if (prev == null) return;
    _pendingControllers.add(prev);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingControllers.remove(prev)) {
        prev.dispose();
      }
    });
  }

  void _enterWidgetOnboarding({bool setStateNow = true}) {
    _retirePageController();
    _stepNotifier.value = 0;
    widget.session.onboardingPending = false;
    final count = _widgetOnboardingCount;
    if (count > 1) {
      _pageController = PageController();
    }
    if (setStateNow) {
      setState(() {
        _error = null;
        _stack = null;
        _phase = _StartupPhase.onboarding;
      });
    } else {
      _phase = _StartupPhase.onboarding;
    }
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _completeManualSplash() {
    final c = _manualSplashCompleter;
    _manualSplashCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  Future<void> _delay(Duration duration) {
    final completer = Completer<void>();
    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      if (!completer.isCompleted) completer.complete();
    });
    _timers.add(timer);
    return completer.future;
  }

  Future<void> _awaitWithOptionalTimeout(
    Future<void> future,
    Duration? timeout,
  ) {
    if (timeout == null) return future;
    final completer = Completer<void>();
    late final Timer timer;
    timer = Timer(timeout, () {
      _timers.remove(timer);
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('OmniSplash.onInit timed out after $timeout', timeout),
          StackTrace.current,
        );
      }
    });
    _timers.add(timer);
    future.then(
      (_) {
        if (timer.isActive) {
          timer.cancel();
          _timers.remove(timer);
        }
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (timer.isActive) {
          timer.cancel();
          _timers.remove(timer);
        }
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    return completer.future;
  }

  Future<void> _markPersisted(OmniOnboarding ob) async {
    if (!ob.usesPersistence) return;
    if (widget.session.persistedMarkedKey == ob.storageKey) return;
    widget.session.persistedMarkedKey = ob.storageKey;
    widget.session.onboardingCompleted = true;
    await OmniOnboardingStore.markDone(
      ob.storageKey,
      customStore: ob.storage,
    );
  }

  Future<bool> _shouldEnterOnboarding({Future<bool>? pendingDecision}) async {
    final ob = widget.config.onboarding;
    if (ob == null || !ob.hasContent) return false;
    final mode = ob.effectiveMode;
    if (mode == OmniOnboardingMode.disabled) return false;
    if (mode == OmniOnboardingMode.always) return true;

    if (ob.persist) {
      final persistedDone = await OmniOnboardingStore.isDone(
        ob.storageKey,
        customStore: ob.storage,
      );
      if (!mounted) return false;
      if (persistedDone) {
        widget.session.persistedMarkedKey = ob.storageKey;
        widget.session.onboardingCompleted = true;
        return false;
      }
      if (mode == OmniOnboardingMode.untilLoggedIn) {
        final authFn = widget.config.auth?.isAuthenticated;
        if (authFn != null && authFn(context)) {
          await _markPersisted(ob);
          if (!mounted) return false;
          return false;
        }
      }
    }

    if (pendingDecision != null) return pendingDecision;
    if (ob.shouldShow != null) {
      return Future<bool>.sync(() => ob.shouldShow!(context));
    }
    return !widget.session.onboardingCompleted;
  }

  Future<void> _applyPostStartupRoute({String? preferredRoute}) async {
    final router = widget.router;
    if (router == null) return;

    var dest = preferredRoute;
    if (dest == null || dest.isEmpty) {
      final resolver = widget.config.resolveInitialRoute;
      if (resolver != null) {
        dest = await Future<String?>.sync(() => resolver(context));
        if (!mounted) return;
      }
    }

    if (dest != null && dest.isNotEmpty) {
      router.go(dest, animated: false, replaceHistory: true);
      return;
    }

    final obRoutes = _normalizedObRoutes;
    if (obRoutes.isNotEmpty) {
      final currentLoc = normalizeOmniConfigPath(router.state.matchedLocation);
      if (obRoutes.contains(currentLoc)) {
        final homeLoc = normalizeOmniConfigPath(
          widget.config.auth?.homeRoute ?? '/',
        );
        router.go(homeLoc, animated: false, replaceHistory: true);
      }
    }
  }

  void _handleFailure(Object e, StackTrace s, String where) {
    if (widget.config.splash?.onError != null) {
      setState(() {
        _error = e;
        _stack = s;
        _phase = _StartupPhase.error;
      });
    } else {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: 'omni_route',
          context: ErrorDescription(where),
        ),
      );
      setState(() => _phase = _StartupPhase.app);
    }
  }

  Future<void> _run({Future<bool>? pendingDecision}) async {
    final epoch = ++_runEpoch;
    _cancelTimers();
    _retirePageController();
    final sp = widget.config.splash;
    _manualSplashDone = false;
    _completeManualSplash();
    if (sp?.manualFinish ?? false) {
      _manualSplashCompleter = Completer<void>();
    }

    final minDelay = sp?.minDuration;
    final minFuture = (minDelay != null && minDelay > Duration.zero)
        ? _delay(minDelay)
        : null;

    if (mounted && (_phase != _StartupPhase.splash || _error != null)) {
      setState(() {
        _error = null;
        _stack = null;
        _phase = _StartupPhase.splash;
      });
    }

    try {
      if (sp?.onInit != null) {
        final fut = Future<void>.sync(() => sp!.onInit!(context));
        await _awaitWithOptionalTimeout(fut, sp?.timeout);
      }
      if (!mounted || epoch != _runEpoch) return;

      if (minFuture != null) {
        await minFuture;
        if (!mounted || epoch != _runEpoch) return;
      }

      if ((sp?.manualFinish ?? false) && !_manualSplashDone) {
        await (_manualSplashCompleter ??= Completer<void>()).future;
        if (!mounted || epoch != _runEpoch) return;
      }

      if (widget.config.gate case final gate? when !_gateDismissed) {
        final decision = await Future<OmniGateDecision?>.sync(
          () => gate.check(context),
        );
        if (!mounted || epoch != _runEpoch) return;
        if (decision != null && decision.status != OmniGateStatus.ready) {
          setState(() {
            _gateDecision = decision;
            _phase = decision.status == OmniGateStatus.maintenance
                ? _StartupPhase.maintenance
                : _StartupPhase.updateRequired;
          });
          return;
        }
      }

      await _proceedAfterGate(epoch: epoch, pendingDecision: pendingDecision);
    } catch (e, s) {
      if (!mounted || epoch != _runEpoch) return;
      _handleFailure(e, s, 'in OmniApp startup');
    }
  }

  Future<void> _proceedAfterGate({
    required int epoch,
    Future<bool>? pendingDecision,
  }) async {
    if (await _shouldEnterOnboarding(pendingDecision: pendingDecision)) {
      if (!mounted || epoch != _runEpoch) return;
      final ob = widget.config.onboarding!;
      if (ob.hasWidgetMode) {
        _enterWidgetOnboarding();
        return;
      }
      final obRoutes = _normalizedObRoutes;
      if (obRoutes.isNotEmpty) {
        widget.session.onboardingPending = true;
        widget.session.onboardingRouteStep = 0;
        _stepNotifier.value = 0;
        widget.router?.go(obRoutes.first, animated: false, replaceHistory: true);
        setState(() => _phase = _StartupPhase.app);
        return;
      }
    }
    if (!mounted || epoch != _runEpoch) return;

    await _applyPostStartupRoute();
    if (!mounted || epoch != _runEpoch) return;
    setState(() => _phase = _StartupPhase.app);
  }

  void _dismissUpdateGate() {
    if (!mounted) return;
    _gateDismissed = true;
    final epoch = ++_runEpoch;
    _proceedAfterGate(epoch: epoch).catchError((Object e, StackTrace s) {
      if (mounted && epoch == _runEpoch) {
        _handleFailure(e, s, 'after update prompt');
      }
    });
  }

  Future<void> _finishOnboarding({
    required bool skipped,
    String? redirectTo,
  }) async {
    final epoch = _runEpoch;
    final ob = widget.config.onboarding;
    if (!mounted) return;
    try {
      if (skipped && ob?.onSkip != null) {
        await Future<void>.sync(() => ob!.onSkip!(context));
        if (!mounted || epoch != _runEpoch) return;
      }
      if (ob?.onDone != null) {
        await Future<void>.sync(() => ob!.onDone!(context));
        if (!mounted || epoch != _runEpoch) return;
      }
      widget.session.onboardingCompleted = true;
      widget.session.onboardingPending = false;
      _retirePageController();

      if (ob != null && ob.usesPersistence) {
        final mode = ob.effectiveMode;
        final hasAuthCheck = widget.config.auth?.isAuthenticated != null;
        final authedNow = hasAuthCheck && widget.config.auth!.isAuthenticated!(context);
        final shouldPersistNow = switch (mode) {
          OmniOnboardingMode.onceUntilLoginScreen ||
          OmniOnboardingMode.onceAfterComplete => true,
          OmniOnboardingMode.untilLoggedIn => !hasAuthCheck || authedNow,
          OmniOnboardingMode.always || OmniOnboardingMode.disabled => false,
        };
        if (shouldPersistNow) {
          await _markPersisted(ob);
          if (!mounted || epoch != _runEpoch) return;
        }
      }

      var dest = redirectTo;
      if ((dest == null || dest.isEmpty) && ob?.afterDone != null) {
        dest = await Future<String?>.sync(() => ob!.afterDone!(context));
        if (!mounted || epoch != _runEpoch) return;
      }

      await _applyPostStartupRoute(preferredRoute: dest);
      if (!mounted || epoch != _runEpoch) return;
      if (_phase != _StartupPhase.app) {
        setState(() => _phase = _StartupPhase.app);
      }
    } catch (e, s) {
      if (!mounted || epoch != _runEpoch) return;
      _handleFailure(e, s, 'in OmniApp onboarding');
    }
  }

  void _leaveOverlayIfNeeded() {
    if (_phase != _StartupPhase.app) {
      _retirePageController();
      setState(() => _phase = _StartupPhase.app);
    }
  }

  @override
  int get onboardingStep => _stepNotifier.value;

  @override
  int get onboardingCount => widget.config.onboarding?.screenCount ?? 0;

  @override
  bool get isFirstOnboardingStep => onboardingStep <= 0;

  @override
  bool get isLastOnboardingStep {
    final count = onboardingCount;
    return count <= 1 || onboardingStep >= count - 1;
  }

  @override
  ValueListenable<int> get onboardingStepListenable => _stepNotifier;

  @override
  Future<void> nextOnboarding({String? redirectTo}) async {
    final count = onboardingCount;
    if (count == 0 || onboardingStep >= count - 1) {
      await completeOnboarding(redirectTo: redirectTo);
      return;
    }
    goToOnboardingStep(onboardingStep + 1);
  }

  @override
  void previousOnboarding() {
    if (onboardingStep > 0) {
      goToOnboardingStep(onboardingStep - 1);
    }
  }

  @override
  void goToOnboardingStep(int index) {
    final count = onboardingCount;
    if (!mounted || count <= 0) return;
    final target = index.clamp(0, count - 1);
    final ob = widget.config.onboarding;
    if (ob == null || !ob.hasContent) return;

    if (ob.hasWidgetMode) {
      if (_stepNotifier.value == target) return;
      _programmaticTarget = target;
      _stepNotifier.value = target;
      ob.onStepChanged?.call(target);
      final pc = _pageController;
      if (pc != null && pc.hasClients) {
        pc
            .animateToPage(
              target,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() {
              if (_programmaticTarget == target) _programmaticTarget = null;
            });
      } else {
        _programmaticTarget = null;
      }
      return;
    }

    final routes = _normalizedObRoutes;
    if (routes.isNotEmpty) {
      widget.session.onboardingRouteStep = target;
      _stepNotifier.value = target;
      ob.onStepChanged?.call(target);
      widget.router?.go(routes[target], replaceHistory: true);
    }
  }

  @override
  void finishSplash() {
    _manualSplashDone = true;
    _completeManualSplash();
  }

  @override
  Future<void> completeOnboarding({String? redirectTo}) =>
      _finishOnboarding(skipped: false, redirectTo: redirectTo);

  @override
  Future<void> skipOnboarding({String? redirectTo}) =>
      _finishOnboarding(skipped: true, redirectTo: redirectTo);

  @override
  void replayOnboarding() {
    if (!mounted) return;
    final ob = widget.config.onboarding;
    if (ob == null || !ob.hasContent) return;
    if (ob.hasWidgetMode) {
      _runEpoch++;
      _cancelTimers();
      _enterWidgetOnboarding();
      return;
    }
    final routes = _normalizedObRoutes;
    if (routes.isNotEmpty) {
      widget.session.onboardingPending = true;
      widget.session.onboardingRouteStep = 0;
      _stepNotifier.value = 0;
      widget.router?.go(routes.first, replaceHistory: true);
      _leaveOverlayIfNeeded();
    }
  }

  @override
  Future<void> resetOnboarding({bool replay = false}) async {
    final ob = widget.config.onboarding;
    widget.session.onboardingCompleted = false;
    widget.session.onboardingPending = false;
    widget.session.onboardingRouteStep = 0;
    widget.session.persistedMarkedKey = null;
    _stepNotifier.value = 0;
    if (ob != null) {
      await OmniOnboardingStore.clearDone(
        ob.storageKey,
        customStore: ob.storage,
      );
      if (!mounted) return;
      if (replay) {
        replayOnboarding();
      }
    }
  }

  @override
  void restartStartup() {
    if (!mounted) return;
    widget.session.onboardingCompleted = false;
    widget.session.onboardingPending = false;
    widget.session.onboardingRouteStep = 0;
    widget.session.persistedMarkedKey = null;
    _gateDecision = null;
    _gateDismissed = false;
    _stepNotifier.value = 0;
    _run();
  }

  @override
  void goToLogin({String? from}) {
    final ob = widget.config.onboarding;
    if (ob != null &&
        ob.usesPersistence &&
        ob.effectiveMode == OmniOnboardingMode.onceUntilLoginScreen) {
      unawaited(_markPersisted(ob));
    }
    widget.session.onboardingCompleted = true;
    widget.session.onboardingPending = false;
    final loginLoc = normalizeOmniConfigPath(
      widget.config.auth?.loginRoute ?? '/login',
    );
    final target = (from != null && from.isNotEmpty)
        ? Uri(path: loginLoc, queryParameters: {'from': from}).toString()
        : loginLoc;
    widget.router?.go(target, replaceHistory: true);
    _leaveOverlayIfNeeded();
  }

  @override
  void goToSignup() {
    final router = widget.router;
    if (router == null) return;
    final ob = widget.config.onboarding;
    if (ob != null &&
        ob.usesPersistence &&
        ob.effectiveMode == OmniOnboardingMode.onceUntilLoginScreen) {
      unawaited(_markPersisted(ob));
    }
    widget.session.onboardingCompleted = true;
    widget.session.onboardingPending = false;
    final auth = widget.config.auth;
    final rawSignup = auth?.signupRoute ?? auth?.loginRoute ?? '/signup';
    final signupLoc = normalizeOmniConfigPath(rawSignup);
    final currentFrom = router.state.queryParameters['from'];
    final target = (currentFrom != null && currentFrom.isNotEmpty)
        ? Uri(path: signupLoc, queryParameters: {'from': currentFrom}).toString()
        : signupLoc;
    router.go(target, replaceHistory: true);
    _leaveOverlayIfNeeded();
  }

  @override
  void goToHome() {
    final ob = widget.config.onboarding;
    final authed = widget.config.auth?.isAuthenticated?.call(context) ?? false;
    if (authed &&
        ob != null &&
        ob.usesPersistence &&
        (ob.effectiveMode == OmniOnboardingMode.untilLoggedIn ||
            ob.effectiveMode == OmniOnboardingMode.onceUntilLoginScreen)) {
      unawaited(_markPersisted(ob));
    }
    widget.session.onboardingPending = false;
    widget.router?.go(
      normalizeOmniConfigPath(widget.config.auth?.homeRoute ?? '/'),
      replaceHistory: true,
    );
    _leaveOverlayIfNeeded();
  }

  @override
  void goToPublic(String path) {
    widget.session.onboardingPending = false;
    widget.router?.go(normalizeOmniConfigPath(path), replaceHistory: true);
    _leaveOverlayIfNeeded();
  }

  @override
  Future<T?> pushPublic<T extends Object?>(String path, {Object? extra}) {
    if (_phase != _StartupPhase.app) {
      goToPublic(path);
      return SynchronousFuture<T?>(null);
    }
    final router = widget.router;
    if (router == null) return SynchronousFuture<T?>(null);
    return router.push<T>(normalizeOmniConfigPath(path), extra: extra);
  }

  @override
  Future<void> logout([
    FutureOr<void> Function(BuildContext context)? onLogout,
  ]) async {
    if (!mounted) return;
    if (onLogout != null) {
      await Future<void>.sync(() => onLogout(context));
      if (!mounted) return;
    }
    final auth = widget.config.auth;
    String? dest;
    if (auth?.afterLogout != null) {
      dest = await Future<String?>.sync(() => auth!.afterLogout!(context));
      if (!mounted) return;
    }
    final target = (dest != null && dest.isNotEmpty)
        ? dest
        : normalizeOmniConfigPath(auth?.loginRoute ?? '/login');
    widget.router?.go(target, replaceHistory: true);
    _leaveOverlayIfNeeded();
  }

  @override
  void refresh() {
    final ob = widget.config.onboarding;
    final authed = widget.config.auth?.isAuthenticated?.call(context) ?? false;
    if (authed &&
        ob != null &&
        ob.usesPersistence &&
        (ob.effectiveMode == OmniOnboardingMode.untilLoggedIn ||
            ob.effectiveMode == OmniOnboardingMode.onceUntilLoginScreen)) {
      unawaited(_markPersisted(ob));
    }
    widget.router?.refresh();
  }

  Widget _wrapStageView(BuildContext context, Widget built) {
    final hasApp = context.findAncestorWidgetOfExactType<WidgetsApp>() != null;
    if (hasApp) return built;
    final themed = OmniThemeScope.maybeThemesOf(context);
    final anim = OmniThemeScope.animationSettingsOf(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themed?.light,
      darkTheme: themed?.dark,
      themeMode: themed?.mode,
      themeAnimationDuration: anim?.duration ?? kThemeAnimationDuration,
      themeAnimationCurve: anim?.curve ?? Curves.linear,
      builder: (stageContext, child) => child == null
          ? const SizedBox.shrink()
          : OmniResponsiveTextScaleHost.fromScope(stageContext, child: child),
      home: built,
    );
  }

  Widget _buildSplashView(BuildContext flowContext) {
    final sp = widget.config.splash;
    if (sp?.builder != null) return sp!.builder!(flowContext);
    if (sp?.screen != null) return sp!.screen!;
    return const SizedBox.shrink();
  }

  Widget _buildWidgetOnboardingView(BuildContext flowContext) {
    final ob = widget.config.onboarding!;
    if (ob.builder != null) {
      return ob.builder!(flowContext, this);
    }

    final count = _widgetOnboardingCount;
    Widget pageAt(BuildContext ctx, int index) {
      if (ob.screens.isNotEmpty) return ob.screens[index];
      return ob.screenBuilders[index](ctx, this);
    }

    Widget content;
    if (count == 1) {
      content = pageAt(flowContext, 0);
    } else {
      final pc = _pageController ??= PageController();
      content = PageView.builder(
        controller: pc,
        physics: ob.swipeable ? null : const NeverScrollableScrollPhysics(),
        itemCount: count,
        onPageChanged: (index) {
          final target = _programmaticTarget;
          if (target != null) {
            if (index != target) return;
            _programmaticTarget = null;
          }
          if (_stepNotifier.value != index) {
            _stepNotifier.value = index;
            ob.onStepChanged?.call(index);
          }
        },
        itemBuilder: pageAt,
      );
    }

    if (ob.overlayBuilder != null) {
      content = ValueListenableBuilder<int>(
        valueListenable: _stepNotifier,
        builder: (ctx, _, child) => ob.overlayBuilder!(ctx, this, child!),
        child: content,
      );
    }
    return content;
  }

  Widget _defaultGateView(
    BuildContext context,
    OmniGateDecision decision,
    VoidCallback? continueAnyway,
    VoidCallback retry,
  ) {
    final isMaintenance = decision.status == OmniGateStatus.maintenance;
    final title =
        decision.title ??
        (isMaintenance ? 'Under Maintenance' : 'Update Available');
    final message =
        decision.message ??
        (isMaintenance
            ? 'We are performing scheduled maintenance. Please check back soon.'
            : 'Please update to the latest version'
                  '${decision.minVersion != null ? ' (${decision.minVersion})' : ''}.');

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: retry,
                      child: const Text('Retry'),
                    ),
                    if (continueAnyway != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: continueAnyway,
                        child: const Text('Later'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OmniFlowScope(
      controller: this,
      child: Builder(
        builder: (flowContext) => switch (_phase) {
          _StartupPhase.error when widget.config.splash?.onError != null =>
            KeyedSubtree(
              key: const ValueKey('_omni_startup_error'),
              child: _wrapStageView(
                flowContext,
                widget.config.splash!.onError!(
                  flowContext,
                  _error!,
                  _stack ?? StackTrace.empty,
                  restartStartup,
                ),
              ),
            ),
          _StartupPhase.maintenance when _gateDecision != null => KeyedSubtree(
            key: const ValueKey('_omni_startup_maintenance'),
            child: _wrapStageView(
              flowContext,
              widget.config.gate?.maintenanceBuilder?.call(
                    flowContext,
                    _gateDecision!,
                    restartStartup,
                  ) ??
                  _defaultGateView(
                    flowContext,
                    _gateDecision!,
                    null,
                    restartStartup,
                  ),
            ),
          ),
          _StartupPhase.updateRequired when _gateDecision != null =>
            KeyedSubtree(
              key: const ValueKey('_omni_startup_update'),
              child: _wrapStageView(
                flowContext,
                widget.config.gate?.updateBuilder?.call(
                      flowContext,
                      _gateDecision!,
                      _gateDecision!.canDismiss ? _dismissUpdateGate : null,
                      restartStartup,
                    ) ??
                    _defaultGateView(
                      flowContext,
                      _gateDecision!,
                      _gateDecision!.canDismiss ? _dismissUpdateGate : null,
                      restartStartup,
                    ),
              ),
            ),
          _StartupPhase.onboarding
              when widget.config.onboarding?.hasWidgetMode ?? false =>
            KeyedSubtree(
              key: const ValueKey('_omni_startup_onboarding'),
              child: _wrapStageView(
                flowContext,
                _buildWidgetOnboardingView(flowContext),
              ),
            ),
          _StartupPhase.app => KeyedSubtree(
            key: const ValueKey('_omni_startup_app'),
            child: widget.child,
          ),
          _ => KeyedSubtree(
            key: const ValueKey('_omni_startup_splash'),
            child: _wrapStageView(flowContext, _buildSplashView(flowContext)),
          ),
        },
      ),
    );
  }
}

/// Closes the keyboard when the user taps outside a text field.
///
/// Uses the text field's own tap-outside detection (`TapRegion`): every
/// `EditableText` invokes [EditableTextTapOutsideIntent] /
/// [EditableTextTapUpOutsideIntent], and this widget handles them for the
/// whole app. Nothing joins the gesture arena, taps on the field's toolbar
/// and handles count as inside, and a pointer that moved further than a tap
/// (a scroll or drag) leaves the keyboard open.
@internal
class OmniKeyboardDismiss extends StatefulWidget {
  /// Wraps [child].
  const OmniKeyboardDismiss({super.key, required this.child});

  /// The app below.
  final Widget child;

  @override
  State<OmniKeyboardDismiss> createState() => _OmniKeyboardDismissState();
}

class _OmniKeyboardDismissState extends State<OmniKeyboardDismiss> {
  // Where each pointer went down outside a focused field.
  final Map<int, Offset> _downs = {};

  late final Map<Type, Action<Intent>> _actions = {
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
      onInvoke: (i) {
        final e = i.pointerDownEvent;
        _downs[e.pointer] = e.position;
        return null;
      },
    ),
    EditableTextTapUpOutsideIntent:
        CallbackAction<EditableTextTapUpOutsideIntent>(
          onInvoke: (i) {
            final e = i.pointerUpEvent;
            final down = _downs.remove(e.pointer);
            if (down != null &&
                (e.position - down).distance <= computeHitSlop(e.kind, null)) {
              i.focusNode.unfocus();
            }
            return null;
          },
        ),
  };

  @override
  Widget build(BuildContext context) =>
      Actions(actions: _actions, child: widget.child);
}

/// "Press back again to exit" on the first page (Android only).
@internal
class OmniExitGuard extends StatefulWidget {
  /// Guards [child].
  const OmniExitGuard({
    super.key,
    required this.window,
    required this.onWarning,
    required this.child,
  });

  /// Second press must come within this time.
  final Duration window;

  /// Called on the first press (show a SnackBar / toast).
  final void Function(BuildContext context)? onWarning;

  /// The page.
  final Widget child;

  /// Whether exit confirmation applies on this platform.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  State<OmniExitGuard> createState() => _OmniExitGuardState();
}

class _OmniExitGuardState extends State<OmniExitGuard> {
  Timer? _armed;

  @override
  void dispose() {
    _armed?.cancel();
    super.dispose();
  }

  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    if (_armed?.isActive ?? false) {
      _armed!.cancel();
      SystemNavigator.pop();
      return;
    }
    _armed = Timer(widget.window, () {});
    widget.onWarning?.call(context);
  }

  @override
  Widget build(BuildContext context) {
    // Same widget shape for every page (only canPop changes), so page state
    // is never reset. Also checks OmniRouter.canPopOf so shells/sub-navigators
    // pushed over another root page don't trigger double-back exit early.
    final isRoot =
        (ModalRoute.of(context)?.isFirst ?? false) &&
        !OmniRouter.canPopOf(context);
    return PopScope(
      canPop: !isRoot,
      onPopInvokedWithResult: _onBack,
      child: widget.child,
    );
  }
}
