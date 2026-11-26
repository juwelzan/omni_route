import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../bloc/omni_bloc.dart';
import '../bloc/omni_bloc_scope.dart';
import '../errors/omni_route_exception.dart';
import '../guards/omni_guard.dart';
import '../routing/omni_page.dart';
import '../routing/omni_route_registry.dart';
import '../routing/omni_route_state.dart';
import '../routing/omni_shell.dart';
import 'omni_route_entry.dart';

enum _NavKind { go, push, replace }

const int _maxRedirects = 5;
const Object _defaultGroupScopeKey = Object();

/// Native Flutter router engine powering [OmniApp] and [OmniRoute].
///
/// Matches routes via a compiled Segment Trie with zero `RegExp` runtime
/// work, runs synchronous guards without extra frame delays, executes `open` /
/// `popUntil` / `popToRoot` stack operations in a single atomic frame, and
/// scopes `OmniRouteGroup` Blocs natively without nested `Navigator` overhead.
class OmniRouter extends ChangeNotifier implements RouterConfig<Uri> {
  /// Creates an engine instance; managed by [OmniApp].
  @internal
  OmniRouter({
    required OmniRouteRegistry routeRegistry,
    required this.navigatorKey,
    required List<OmniGuard> guards,
    required List<NavigatorObserver> observers,
    required OmniErrorBuilder onRouteError,
    required String initialRoute,
    this.restorationScopeId,
    Listenable? refresh,
    VoidCallback? onReady,
  }) : _registry = routeRegistry,
       _appGuards = guards,
       _userObservers = observers,
       _errorBuilder = onRouteError,
       _refreshListenable = refresh,
       _onInitialReady = onReady {
    _delegate = _OmniRouterDelegate(this);
    _parser = const _OmniRouteInformationParser();
    final startUri = _normalizeParse(initialRoute);
    _infoProvider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: startUri),
    );
    _backButtonDispatcher = RootBackButtonDispatcher();
    _refreshListenable?.addListener(this.refresh);
    _seedInitialStack(startUri);
    _syncCurrentNotifiers(emitChanges: false);
  }

  OmniRouteRegistry _registry;

  /// Root [Navigator] key for this router.
  final GlobalKey<NavigatorState> navigatorKey;

  List<OmniGuard> _appGuards;
  List<NavigatorObserver> _userObservers;
  OmniErrorBuilder _errorBuilder;

  /// Restoration bucket identifier passed from [OmniApp.restorationScopeId].
  final String? restorationScopeId;

  Listenable? _refreshListenable;
  final VoidCallback? _onInitialReady;

  late final _OmniRouterDelegate _delegate;
  late final _OmniRouteInformationParser _parser;
  late final PlatformRouteInformationProvider _infoProvider;
  late final RootBackButtonDispatcher _backButtonDispatcher;

  final _GroupScopeManager _groupManager = _GroupScopeManager();
  final List<_StackFrame> _rootStack = [];
  final ValueNotifier<OmniRouteEntry> _currentEntryNotifier = ValueNotifier(
    const OmniRouteEntry(location: '/'),
  );
  final Map<LocalKey, Future<Object?>> _pendingPopFutures = {};

  BuildContext? _hostContext;
  bool _initialGuardsDone = false;
  bool _resolvingInitial = false;
  bool _initialReadyNotified = false;
  bool _disposed = false;
  int _nextKeyId = 1;
  int _navSeq = 0;

  @override
  RouterDelegate<Uri> get routerDelegate => _delegate;

  @override
  RouteInformationParser<Uri> get routeInformationParser => _parser;

  @override
  RouteInformationProvider get routeInformationProvider => _infoProvider;

  @override
  BackButtonDispatcher get backButtonDispatcher => _backButtonDispatcher;

  /// Reactive listenable tracking the top [OmniRouteEntry].
  ValueListenable<OmniRouteEntry> get currentListenable =>
      _currentEntryNotifier;

  /// Current top route state (URI, decoded params, extra, metadata, key).
  OmniRouteState get state => _topPageFrame().toState();

  /// Current location URI, including pushed pages and active tab stacks.
  Uri get location => state.uri;

  /// Top entry descriptor for analytics/logging.
  OmniRouteEntry get currentEntry => _topPageFrame().toEntry();

  /// Flattened active page entries from bottom to top.
  List<OmniRouteEntry> get stackEntries {
    final out = <OmniRouteEntry>[];
    void visit(List<_StackFrame> frames) {
      for (final f in frames) {
        switch (f) {
          case _PageFrame():
            out.add(f.toEntry());
          case _ShellFrame():
            visit(f.children);
          case _StatefulShellFrame():
            visit(f.branches[f.currentIndex]);
        }
      }
    }

    visit(_rootStack);
    return List.unmodifiable(out);
  }

  /// Finds the nearest [OmniRouter] above [context].
  static OmniRouter of(BuildContext context) =>
      maybeOf(context) ??
      (throw const OmniRouteException(
        OmniErrorCode.notInitialized,
        'No OmniRouter found in context.',
        hint: 'Call from inside an OmniApp widget tree.',
      ));

  /// Finds the nearest [OmniRouter] above [context], or `null` if none exists.
  static OmniRouter? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_OmniRouterScope>()?.router;

  /// Subscribes to changes in whether any navigator inside [context]'s router
  /// can pop, used by [OmniExitGuard].
  @internal
  static bool canPopOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_OmniRouterScope>()
          ?.canPopValue ??
      false;

  /// Navigates cleanly by replacing the stack declaratively with [location].
  void go(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) {
    _navigate(
      location,
      kind: _NavKind.go,
      extra: extra,
      animated: animated ? null : false,
      transition: transition,
    );
  }

  /// Pushes [location] on top of the active stack and resolves with pop data.
  Future<T?> push<T extends Object?>(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) {
    final completer = Completer<Object?>();
    _navigate(
      location,
      kind: _NavKind.push,
      extra: extra,
      animated: animated ? null : false,
      transition: transition,
      completer: completer,
    );
    return completer.future.then((v) => v as T?);
  }

  /// Replaces the top page in the active navigator with [location].
  void replace(
    String location, {
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) {
    _navigate(
      location,
      kind: _NavKind.replace,
      extra: extra,
      animated: animated ? null : false,
      transition: transition,
    );
  }

  /// Navigates to [location] without creating duplicate stack entries.
  Future<T?> open<T extends Object?>(
    String location, {
    Object? extra,
    int maxDepth = 10,
    bool animated = true,
    OmniPageType? transition,
  }) {
    final target = _normalizeParse(location);
    if (this.location == target) return SynchronousFuture<T?>(null);

    final active = _deepestActiveStack();
    final idx = active.lastIndexWhere(
      (f) => f is _PageFrame && f.matchedLocation == target.path,
    );
    if (idx >= 0) {
      if (idx < active.length - 1) {
        _removeSliceFrom(active, idx + 1);
      }
      final top = active.last as _PageFrame;
      if (top.uri != target || !identical(top.extra, extra)) {
        _commit();
        replace(
          location,
          extra: extra,
          animated: animated,
          transition: transition,
        );
      } else {
        _commit();
      }
      return SynchronousFuture<T?>(null);
    }

    if (stackEntries.length >= maxDepth) {
      go(location, extra: extra, animated: animated, transition: transition);
      return SynchronousFuture<T?>(null);
    }

    return push<T>(
      location,
      extra: extra,
      animated: animated,
      transition: transition,
    );
  }

  /// Pops pages synchronously from the deepest active stack until [location]
  /// (`Uri.path`) is on top. Ignores `PopScope`.
  Future<bool> popUntil(String location) {
    final targetPath = _normalizeParse(location).path;
    final active = _deepestActiveStack();
    final idx = active.lastIndexWhere(
      (f) => f is _PageFrame && f.matchedLocation == targetPath,
    );
    if (idx < 0) return SynchronousFuture<bool>(false);
    if (idx < active.length - 1) {
      _removeSliceFrom(active, idx + 1);
      _commit();
    }
    return SynchronousFuture<bool>(true);
  }

  /// Pops every poppable page on the active stack back to its root page.
  Future<void> popToRoot() {
    final active = _deepestActiveStack();
    if (active.length > 1) {
      _removeSliceFrom(active, 1);
      _commit();
    }
    return SynchronousFuture<void>(null);
  }

  /// Whether at least one poppable page exists on the active or root stack.
  bool canPop() => _findPopTargetStack() != null;

  /// Pops the top page, completing any `push` future with [result].
  void pop<T extends Object?>([T? result]) {
    final stack = _findPopTargetStack();
    if (stack == null) {
      throw const OmniRouteException(
        OmniErrorCode.unsupportedConfiguration,
        'There is nothing to pop.',
      );
    }
    final removed = stack.removeLast();
    _completeRemovedFrame(removed, result);
    _commit();
  }

  /// Pops if possible and returns whether a page was popped.
  bool maybePop<T extends Object?>([T? result]) {
    if (!canPop()) return false;
    pop<T>(result);
    return true;
  }

  /// Re-evaluates all guards against the current top URI immediately.
  void refresh() {
    final ctx = _hostContext;
    if (ctx == null || !ctx.mounted) return;
    _runRefresh(ctx);
  }

  /// Updates routes/config seamlessly during Hot Reload without recreating
  /// the router or dropping navigation history.
  @internal
  void updateConfig({
    required OmniRouteRegistry registry,
    required List<OmniGuard> guards,
    required List<NavigatorObserver> observers,
    required OmniErrorBuilder errorBuilder,
    Listenable? refreshListenable,
  }) {
    _registry = registry;
    _appGuards = guards;
    _userObservers = observers;
    _errorBuilder = errorBuilder;
    if (!identical(_refreshListenable, refreshListenable)) {
      _refreshListenable?.removeListener(refresh);
      _refreshListenable = refreshListenable;
      _refreshListenable?.addListener(refresh);
    }
    _remapStack(_rootStack);
    _commit(notify: true);
  }

  /// Removes a specific page bypassing its [PopScope] after `OmniPage.onExit`
  /// approves closing it.
  @internal
  void forcePopPage(ValueKey<String> pageKey, [Object? result]) {
    final removed = _removePageByKey(_rootStack, pageKey);
    if (removed != null) {
      _completeRemovedFrame(removed, result);
      _commit();
    }
  }

  void _seedInitialStack(Uri uri) {
    final normalized = _normalizeUri(uri);
    final match = _registry.matchUri(normalized);
    _applyDeclarativeMatch(
      uri: normalized,
      match: match,
      extra: null,
      error: match == null
          ? FlutterError('No route matches ${normalized.path}.')
          : null,
    );
  }

  void _attachHost(BuildContext context) {
    _hostContext = context;
  }

  void _runInitialGuardsIfNeeded() {
    if (_initialGuardsDone) return;
    _initialGuardsDone = true;
    final ctx = _hostContext;
    if (ctx == null || !ctx.mounted) {
      _scheduleInitialReady();
      return;
    }
    final top = _topPageFrame();
    if (_appGuards.isEmpty && (top.compiled?.guards.isEmpty ?? true)) {
      _scheduleInitialReady();
      return;
    }

    var completedSynchronously = false;
    var stillInBuild = true;
    _resolvingInitial = true;
    final seq = ++_navSeq;

    _resolveGuardsSyncOrAsync(
      ctx,
      top.uri,
      extra: top.extra,
      seq: seq,
      onResolved: (res) {
        _resolvingInitial = false;
        completedSynchronously = stillInBuild;
        if (_disposed || _navSeq != seq) return;
        if (res.redirected || res.error != null || res.uri != top.uri) {
          _applyDeclarativeMatch(
            uri: res.uri,
            match: res.match,
            extra: top.extra,
            error: res.error,
          );
          _syncCurrentNotifiers(emitChanges: true);
          if (!stillInBuild) {
            _initialReadyNotified = true;
            _commit();
            return;
          }
        }
        if (stillInBuild) {
          _scheduleInitialReady();
        } else {
          _initialReadyNotified = true;
          _commit();
        }
      },
    );

    stillInBuild = false;
    if (completedSynchronously) {
      _resolvingInitial = false;
    }
  }

  void _scheduleInitialReady() {
    if (_initialReadyNotified) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _resolvingInitial || _initialReadyNotified) return;
      _initialReadyNotified = true;
      _onInitialReady?.call();
    });
  }

  void _runRefresh(BuildContext context) {
    final top = _topPageFrame();
    final seq = ++_navSeq;
    _resolveGuardsSyncOrAsync(
      context,
      top.uri,
      extra: top.extra,
      seq: seq,
      onResolved: (res) {
        if (_disposed || _navSeq != seq) return;
        if (res.redirected || res.error != null) {
          _applyDeclarativeMatch(
            uri: res.uri,
            match: res.match,
            extra: top.extra,
            error: res.error,
          );
          _commit();
        }
      },
    );
  }

  void _navigate(
    String rawLocation, {
    required _NavKind kind,
    Object? extra,
    OmniPageType? transition,
    bool? animated,
    Completer<Object?>? completer,
  }) {
    final seq = ++_navSeq;
    Uri parsed;
    try {
      parsed = _normalizeParse(rawLocation);
    } on FormatException catch (e) {
      _applyErrorNavigation(
        Uri(path: '/'),
        e,
        kind: kind,
        transition: transition,
        animated: animated,
        completer: completer,
      );
      _commit();
      return;
    }

    final ctx = _hostContext;
    if (ctx == null || !ctx.mounted) {
      final normalized = _normalizeUri(parsed);
      final match = _registry.matchUri(normalized);
      _applyResolved(
        uri: normalized,
        match: match,
        error: match == null
            ? FlutterError('No route matches ${normalized.path}.')
            : null,
        redirected: false,
        kind: kind,
        extra: extra,
        transition: transition,
        animated: animated,
        completer: completer,
      );
      _commit();
      return;
    }

    _resolveGuardsSyncOrAsync(
      ctx,
      parsed,
      extra: extra,
      seq: seq,
      onResolved: (res) {
        if (_disposed || _navSeq != seq) {
          if (completer != null && !completer.isCompleted) {
            completer.complete(null);
          }
          return;
        }
        _applyResolved(
          uri: res.uri,
          match: res.match,
          error: res.error,
          redirected: res.redirected,
          kind: kind,
          extra: extra,
          transition: transition,
          animated: animated,
          completer: completer,
        );
        _commit();
      },
    );
  }

  void _resolveGuardsSyncOrAsync(
    BuildContext context,
    Uri initialUri, {
    required Object? extra,
    required int seq,
    required void Function(
      ({Uri uri, CompiledMatch? match, Object? error, bool redirected}) result,
    )
    onResolved,
  }) {
    void step(Uri uri, int hops, bool redirected) {
      while (true) {
        final normalized = _normalizeUri(uri);
        final match = _registry.matchUri(normalized);
        final route = match?.route;
        final guards = <OmniGuard>[..._appGuards, ...?route?.guards];
        final candidateState = OmniRouteState(
          uri: normalized,
          matchedLocation: normalized.path.isEmpty ? '/' : normalized.path,
          pageKey: const ValueKey('__guard__'),
          path: route?.fullPath,
          name: route?.page.name,
          pathParameters: match?.pathParameters ?? const {},
          extra: extra,
          metadata: route?.page.metadata,
        );

        final guardRes = evaluateGuards(context, candidateState, guards);
        if (guardRes is Future<String?>) {
          guardRes.then((to) {
            if (_disposed || _navSeq != seq) return;
            if (to == null) {
              onResolved((
                uri: normalized,
                match: match,
                error: match == null
                    ? FlutterError('No route matches ${normalized.path}.')
                    : null,
                redirected: redirected || normalized != initialUri,
              ));
              return;
            }
            final nextHops = hops + 1;
            if (nextHops > _maxRedirects) {
              onResolved((
                uri: normalized,
                match: null,
                error: OmniRouteException(
                  OmniErrorCode.redirectLoop,
                  'Exceeded $_maxRedirects redirects — redirect loop at "$to".',
                ),
                redirected: true,
              ));
              return;
            }
            step(_normalizeParse(to), nextHops, true);
          });
          return;
        }

        if (guardRes == null) {
          onResolved((
            uri: normalized,
            match: match,
            error: match == null
                ? FlutterError('No route matches ${normalized.path}.')
                : null,
            redirected: redirected || normalized != initialUri,
          ));
          return;
        }

        hops++;
        if (hops > _maxRedirects) {
          onResolved((
            uri: normalized,
            match: null,
            error: OmniRouteException(
              OmniErrorCode.redirectLoop,
              'Exceeded $_maxRedirects redirects — redirect loop at "$guardRes".',
            ),
            redirected: true,
          ));
          return;
        }
        uri = _normalizeParse(guardRes);
        redirected = true;
      }
    }

    step(initialUri, 0, false);
  }

  void _applyResolved({
    required Uri uri,
    required CompiledMatch? match,
    required Object? error,
    required bool redirected,
    required _NavKind kind,
    required Object? extra,
    required OmniPageType? transition,
    required bool? animated,
    required Completer<Object?>? completer,
  }) {
    if (error != null || match == null) {
      _applyErrorNavigation(
        uri,
        error ?? FlutterError('No route matches ${uri.path}.'),
        kind: redirected ? _NavKind.go : kind,
        transition: transition,
        animated: animated,
        completer: completer,
      );
      return;
    }

    if (kind == _NavKind.go) {
      _applyDeclarativeMatch(
        uri: uri,
        match: match,
        extra: extra,
        transition: transition,
        animated: animated,
      );
      return;
    }

    if (kind == _NavKind.replace) {
      final active = _deepestActiveStack();
      final frame = _makePageFrame(
        uri: uri,
        compiled: match.route,
        pathParameters: match.pathParameters,
        extra: extra,
        transition: transition,
        animated: animated,
      );
      if (active.isEmpty) {
        active.add(frame);
      } else {
        _completeRemovedFrame(active.last, null);
        active[active.length - 1] = frame;
      }
      return;
    }

    // Push navigation:
    final frame = _makePageFrame(
      uri: uri,
      compiled: match.route,
      pathParameters: match.pathParameters,
      extra: extra,
      transition: transition,
      animated: animated,
      completer: completer,
    );
    _pushFrame(frame, match);
  }

  void _applyErrorNavigation(
    Uri uri,
    Object error, {
    required _NavKind kind,
    OmniPageType? transition,
    bool? animated,
    Completer<Object?>? completer,
  }) {
    final errFrame = _PageFrame(
      key: _allocKey(),
      uri: uri,
      matchedLocation: uri.path.isEmpty ? '/' : uri.path,
      compiled: null,
      pathParameters: const {},
      error: error,
      transitionOverride: transition,
      animatedOverride: animated,
      completer: completer,
    );
    if (kind == _NavKind.go) {
      _clearFrames(_rootStack);
      _rootStack.add(errFrame);
    } else if (kind == _NavKind.replace) {
      final active = _deepestActiveStack();
      if (active.isEmpty) {
        active.add(errFrame);
      } else {
        _completeRemovedFrame(active.last, null);
        active[active.length - 1] = errFrame;
      }
    } else {
      _deepestActiveStack().add(errFrame);
    }
  }

  void _applyDeclarativeMatch({
    required Uri uri,
    required CompiledMatch? match,
    Object? extra,
    Object? error,
    OmniPageType? transition,
    bool? animated,
  }) {
    if (match == null || error != null) {
      _applyErrorNavigation(
        uri,
        error ?? FlutterError('No route matches ${uri.path}.'),
        kind: _NavKind.go,
        transition: transition,
        animated: animated,
      );
      return;
    }

    final route = match.route;
    final shellChain = route.shellChain;

    // Build page chain within target navigator using deterministic route-pattern
    // keys so repeated `go('/item/1')` -> `go('/item/2')` on the same route
    // update in-place without stacking zombie animated routes.
    List<_StackFrame> buildPageChain(
      List<_StackFrame> previousFrames,
      List<CompiledRoute> chain, {
      bool isLeafStack = true,
    }) {
      final out = <_StackFrame>[];
      final usedKeys = <String>{};
      for (var i = 0; i < chain.length; i++) {
        final node = chain[i];
        final isLast = i == chain.length - 1;
        final nodePath = _fillAncestorPath(node.fullPath, match.pathParameters);
        final nodeUri = isLast && isLeafStack ? uri : Uri(path: nodePath);
        final nodeMatched = nodeUri.path.isEmpty ? '/' : nodeUri.path;

        _PageFrame? reused;
        if (i < previousFrames.length) {
          final existing = previousFrames[i];
          if (existing is _PageFrame &&
              existing.compiled?.fullPath == node.fullPath &&
              existing.matchedLocation == nodeMatched &&
              existing.uri == nodeUri) {
            reused = existing;
          }
        }

        final baseKey = 'd_${node.fullPath}';
        final stableKeyStr = usedKeys.add(baseKey) ? baseKey : '${baseKey}_$i';
        usedKeys.add(stableKeyStr);

        out.add(
          reused ??
              _makePageFrame(
                keyOverride: ValueKey<String>(stableKeyStr),
                uri: nodeUri,
                compiled: node,
                pathParameters: _filterParamsFor(node, match.pathParameters),
                extra: isLast ? extra : null,
                transition: isLast ? transition : null,
                animated: isLast ? animated : null,
              ),
        );
      }
      return out;
    }

    if (shellChain.isEmpty) {
      // Root Navigator target. What if `outerShellAncestors` exist because
      // `parentNavigatorKey` popped out of a shell? Build underlying shell
      // layer cleanly if needed, otherwise straight root pages!
      if (route.outerShellAncestors.isNotEmpty &&
          route.fullEnclosingShells.isNotEmpty) {
        final existingOuter = _rootStack.isNotEmpty ? _rootStack.first : null;
        final rebuiltShell = _buildShellTree(
          route.fullEnclosingShells,
          0,
          existingOuter,
          (prevChildren) => buildPageChain(
            prevChildren,
            route.outerShellAncestors,
            isLeafStack: false,
          ),
        );
        final tail = buildPageChain(
          _rootStack.length > 1 ? _rootStack.sublist(1) : const [],
          route.sameNavigatorAncestors,
        );
        _rootStack
          ..clear()
          ..add(rebuiltShell)
          ..addAll(tail);
        return;
      }

      final nextRoot = buildPageChain(_rootStack, route.sameNavigatorAncestors);
      _completeRemovedNotIn(_rootStack, nextRoot);
      _rootStack
        ..clear()
        ..addAll(nextRoot);
      return;
    }

    // Target lives inside `shellChain`. Preserve matching shell containers
    // already on `_rootStack` so sibling branch stacks & Blocs remain alive.
    final prevShellFrame = _rootStack.isNotEmpty ? _rootStack.first : null;
    final shellFrame = _buildShellTree(
      shellChain,
      0,
      prevShellFrame,
      (prevChildren) =>
          buildPageChain(prevChildren, route.sameNavigatorAncestors),
    );
    _rootStack
      ..clear()
      ..add(shellFrame);
  }

  _StackFrame _buildShellTree(
    List<CompiledShellRef> chain,
    int depth,
    _StackFrame? existingFrame,
    List<_StackFrame> Function(List<_StackFrame> previous) buildLeaf,
  ) {
    final ref = chain[depth];
    final atLeaf = depth == chain.length - 1;

    switch (ref) {
      case CompiledShell():
        final reusable =
            existingFrame is _ShellFrame && existingFrame.shell.id == ref.id
            ? existingFrame
            : null;
        final prevChildren = reusable?.children ?? const <_StackFrame>[];
        final nextChildren = atLeaf
            ? buildLeaf(prevChildren)
            : <_StackFrame>[
                _buildShellTree(
                  chain,
                  depth + 1,
                  prevChildren.isNotEmpty ? prevChildren.first : null,
                  buildLeaf,
                ),
              ];
        return _ShellFrame(
          shell: ref,
          key: reusable?.key ?? ValueKey<String>('__omni_shell_${ref.id}'),
          children: nextChildren,
        );

      case CompiledBranchRef():
        final ss = ref.statefulShell;
        final idx = ref.branchIndex;
        final reusable =
            existingFrame is _StatefulShellFrame &&
                existingFrame.statefulShell.id == ss.id
            ? existingFrame
            : null;
        final branches = reusable != null
            ? reusable.branches
            : [for (final b in ss.branches) _seedBranchStack(b)];
        final prevBranchStack = branches[idx];
        branches[idx] = atLeaf
            ? buildLeaf(prevBranchStack)
            : [
                _buildShellTree(
                  chain,
                  depth + 1,
                  prevBranchStack.isNotEmpty ? prevBranchStack.first : null,
                  buildLeaf,
                ),
              ];
        return _StatefulShellFrame(
          statefulShell: ss,
          key: reusable?.key ?? ValueKey<String>('__omni_sshell_${ss.id}'),
          currentIndex: idx,
          branches: branches,
        );
    }
  }

  List<_StackFrame> _seedBranchStack(CompiledBranch branch) {
    final uri = _normalizeParse(branch.defaultLocation);
    final match = _registry.matchUri(uri);
    if (match == null) {
      return [
        _PageFrame(
          key: _allocKey(),
          uri: uri,
          matchedLocation: uri.path.isEmpty ? '/' : uri.path,
          compiled: null,
          pathParameters: const {},
          error: OmniRouteException(
            OmniErrorCode.missingRoute,
            'Branch initial route ${uri.path} not found.',
          ),
        ),
      ];
    }
    final leafPages = <_StackFrame>[
      for (var i = 0; i < match.route.sameNavigatorAncestors.length; i++)
        _makePageFrame(
          uri: i == match.route.sameNavigatorAncestors.length - 1
              ? uri
              : Uri(
                  path: _fillAncestorPath(
                    match.route.sameNavigatorAncestors[i].fullPath,
                    match.pathParameters,
                  ),
                ),
          compiled: match.route.sameNavigatorAncestors[i],
          pathParameters: _filterParamsFor(
            match.route.sameNavigatorAncestors[i],
            match.pathParameters,
          ),
        ),
    ];
    final chain = match.route.shellChain;
    final branchPos = chain.indexWhere(
      (ref) =>
          ref is CompiledBranchRef &&
          ref.statefulShell.id == branch.parent.id &&
          ref.branchIndex == branch.branchIndex,
    );
    if (branchPos >= 0 && branchPos + 1 < chain.length) {
      return [
        _buildShellTree(chain, branchPos + 1, null, (_) => leafPages),
      ];
    }
    return leafPages;
  }

  void _pushFrame(_PageFrame frame, CompiledMatch match) {
    final targetNav = match.route.targetNavIdentity;
    if (targetNav == null) {
      _rootStack.add(frame);
      return;
    }

    // Try pushing inside the currently deepest matching shell/branch stack.
    final targetStack = _findStackForNavigator(_rootStack, targetNav);
    if (targetStack != null) {
      targetStack.add(frame);
      return;
    }

    // Fallback: push directly on root so Back cleanly pops back where user came from.
    _rootStack.add(frame);
  }

  List<_StackFrame>? _findStackForNavigator(
    List<_StackFrame> frames,
    Object navIdentity,
  ) {
    if (frames.isEmpty) return null;
    final last = frames.last;
    switch (last) {
      case _PageFrame():
        return null;
      case _ShellFrame():
        if (last.shell.navigatorKey == navIdentity) return last.children;
        return _findStackForNavigator(last.children, navIdentity);
      case _StatefulShellFrame():
        final activeBranch = last.statefulShell.branches[last.currentIndex];
        if (activeBranch.navigatorKey == navIdentity) {
          return last.branches[last.currentIndex];
        }
        return _findStackForNavigator(
          last.branches[last.currentIndex],
          navIdentity,
        );
    }
  }

  List<_StackFrame> _deepestActiveStack() {
    List<_StackFrame> current = _rootStack;
    while (current.isNotEmpty) {
      final last = current.last;
      switch (last) {
        case _PageFrame():
          return current;
        case _ShellFrame():
          if (last.children.isEmpty) return current;
          current = last.children;
        case _StatefulShellFrame():
          final active = last.branches[last.currentIndex];
          if (active.isEmpty) return current;
          current = active;
      }
    }
    return current;
  }

  List<_StackFrame>? _findPopTargetStack() {
    List<_StackFrame>? deepestPoppable;
    void visit(List<_StackFrame> frames) {
      if (frames.length > 1) {
        deepestPoppable = frames;
      }
      if (frames.isEmpty) return;
      final last = frames.last;
      switch (last) {
        case _PageFrame():
          return;
        case _ShellFrame():
          visit(last.children);
        case _StatefulShellFrame():
          visit(last.branches[last.currentIndex]);
      }
    }

    visit(_rootStack);
    return deepestPoppable;
  }

  _PageFrame _topPageFrame() {
    _StackFrame? cur = _rootStack.isEmpty ? null : _rootStack.last;
    while (cur != null) {
      switch (cur) {
        case _PageFrame():
          return cur;
        case _ShellFrame():
          cur = cur.children.isEmpty ? null : cur.children.last;
        case _StatefulShellFrame():
          final b = cur.branches[cur.currentIndex];
          cur = b.isEmpty ? null : b.last;
      }
    }
    return _PageFrame(
      key: const ValueKey('__empty__'),
      uri: Uri(path: '/'),
      matchedLocation: '/',
      compiled: null,
      pathParameters: const {},
    );
  }

  _StackFrame? _removePageByKey(
    List<_StackFrame> frames,
    ValueKey<String> key,
  ) {
    for (var i = frames.length - 1; i >= 0; i--) {
      final f = frames[i];
      switch (f) {
        case _PageFrame():
          if (f.key == key) {
            return frames.removeAt(i);
          }
        case _ShellFrame():
          final hit = _removePageByKey(f.children, key);
          if (hit != null) return hit;
        case _StatefulShellFrame():
          for (final b in f.branches) {
            final hit = _removePageByKey(b, key);
            if (hit != null) return hit;
          }
      }
    }
    return null;
  }

  void _remapStack(List<_StackFrame> frames) {
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      switch (f) {
        case _PageFrame():
          final match = _registry.matchUri(f.uri);
          frames[i] = _PageFrame(
            key: f.key,
            uri: f.uri,
            matchedLocation: f.matchedLocation,
            compiled: match?.route,
            pathParameters: match?.pathParameters ?? f.pathParameters,
            extra: f.extra,
            error: match == null ? f.error : null,
            transitionOverride: f.transitionOverride,
            animatedOverride: f.animatedOverride,
            completer: f.completer,
          );
        case _ShellFrame():
          _remapStack(f.children);
        case _StatefulShellFrame():
          for (final b in f.branches) {
            _remapStack(b);
          }
      }
    }
  }

  void _onNavigatorDidPop(Route<dynamic> route, Route<dynamic>? previous) {
    final settings = route.settings;
    if (settings is Page<Object?> && settings.key != null) {
      _pendingPopFutures[settings.key!] = route.popped;
    }
  }

  void _handlePageRemoved(Page<Object?> page) {
    final key = page.key;
    if (key is! ValueKey<String>) return;
    final popFuture = _pendingPopFutures.remove(key);
    final removed = _removePageByKey(_rootStack, key);
    if (removed is _PageFrame) {
      final completer = removed.completer;
      if (completer != null && !completer.isCompleted) {
        if (popFuture != null) {
          popFuture.then(
            (val) {
              if (!completer.isCompleted) completer.complete(val);
            },
            onError: (_, _) {
              if (!completer.isCompleted) completer.complete(null);
            },
          );
        } else {
          completer.complete(null);
        }
      }
      _commit();
    } else {
      _pruneUnusedGroups();
    }
  }

  void _goBranch(
    _StatefulShellFrame shellFrame,
    int index, {
    bool initialLocation = false,
  }) {
    if (index < 0 || index >= shellFrame.branches.length) return;
    final changed = shellFrame.currentIndex != index;
    shellFrame.currentIndex = index;
    if (initialLocation) {
      final branch = shellFrame.statefulShell.branches[index];
      final old = shellFrame.branches[index];
      _clearFrames(old);
      shellFrame.branches[index] = _seedBranchStack(branch);
    }
    if (changed || initialLocation) {
      _commit();
    }
  }

  Set<_GroupScopeKey> _activeGroupScopeKeys() {
    final keys = <_GroupScopeKey>{};
    void visit(List<_StackFrame> frames) {
      for (final f in frames) {
        switch (f) {
          case _PageFrame():
            final compiled = f.compiled;
            if (compiled != null && compiled.groups.isNotEmpty) {
              final st = f.toState();
              for (final g in compiled.groups) {
                final scopeVal = g.group.scopeKey != null
                    ? g.group.scopeKey!(st)
                    : _defaultGroupScopeKey;
                keys.add(_GroupScopeKey(g.id, scopeVal));
              }
            }
          case _ShellFrame():
            visit(f.children);
          case _StatefulShellFrame():
            for (final b in f.branches) {
              visit(b);
            }
        }
      }
    }

    visit(_rootStack);
    return keys;
  }

  void _pruneUnusedGroups() {
    _groupManager.pruneUnused(_activeGroupScopeKeys());
  }

  void _removeSliceFrom(List<_StackFrame> stack, int start) {
    for (var i = start; i < stack.length; i++) {
      _completeRemovedFrame(stack[i], null);
    }
    stack.removeRange(start, stack.length);
  }

  void _clearFrames(List<_StackFrame> stack) {
    for (final f in stack) {
      _completeRemovedFrame(f, null);
    }
    stack.clear();
  }

  void _completeRemovedNotIn(
    List<_StackFrame> previous,
    List<_StackFrame> next,
  ) {
    final keptKeys = {
      for (final f in next)
        if (f is _PageFrame) f.key,
    };
    for (final f in previous) {
      if (f is _PageFrame && !keptKeys.contains(f.key)) {
        _completeRemovedFrame(f, null);
      } else if (f is! _PageFrame) {
        _completeRemovedFrame(f, null);
      }
    }
  }

  void _completeRemovedFrame(_StackFrame frame, Object? result) {
    switch (frame) {
      case _PageFrame():
        final c = frame.completer;
        if (c != null && !c.isCompleted) c.complete(result);
      case _ShellFrame():
        for (final c in frame.children) {
          _completeRemovedFrame(c, null);
        }
      case _StatefulShellFrame():
        for (final b in frame.branches) {
          for (final c in b) {
            _completeRemovedFrame(c, null);
          }
        }
    }
  }

  void _commit({bool notify = true}) {
    _pruneUnusedGroups();
    _syncCurrentNotifiers(emitChanges: true);
    if (notify) notifyListeners();
  }

  void _syncCurrentNotifiers({required bool emitChanges}) {
    final entry = currentEntry;
    if (_currentEntryNotifier.value != entry) {
      _currentEntryNotifier.value = entry;
    }
  }

  ValueKey<String> _allocKey() => ValueKey<String>('p_${_nextKeyId++}');

  _PageFrame _makePageFrame({
    ValueKey<String>? keyOverride,
    required Uri uri,
    required CompiledRoute compiled,
    required Map<String, String> pathParameters,
    Object? extra,
    OmniPageType? transition,
    bool? animated,
    Completer<Object?>? completer,
  }) => _PageFrame(
    key: keyOverride ?? _allocKey(),
    uri: uri,
    matchedLocation: uri.path.isEmpty ? '/' : uri.path,
    compiled: compiled,
    pathParameters: pathParameters,
    extra: extra,
    transitionOverride: transition,
    animatedOverride: animated,
    completer: completer,
  );

  // ── Navigator & Widget Building ────────────────────────────────────────

  Widget _buildRoot(BuildContext context) {
    if (_resolvingInitial) {
      return const SizedBox.shrink();
    }
    final pages = _buildNavigatorPages(
      context,
      _rootStack,
      navigatorKey: navigatorKey,
    );
    return _OmniRouterScope(
      router: this,
      canPopValue: canPop(),
      child: _buildNavigator(
        key: navigatorKey,
        pages: pages,
        restorationScopeId: restorationScopeId,
        observers: _userObservers,
      ),
    );
  }

  Widget _buildNavigator({
    required GlobalKey<NavigatorState> key,
    required List<Page<Object?>> pages,
    required List<NavigatorObserver> observers,
    String? restorationScopeId,
  }) => Navigator(
    key: key,
    restorationScopeId: restorationScopeId,
    pages: pages,
    observers: [...observers, _OmniPopObserver(_onNavigatorDidPop)],
    onDidRemovePage: _handlePageRemoved,
  );

  List<Page<Object?>> _buildNavigatorPages(
    BuildContext context,
    List<_StackFrame> frames, {
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    final out = <Page<Object?>>[];
    for (final f in frames) {
      switch (f) {
        case _PageFrame():
          out.add(_buildSinglePage(context, f));
        case _ShellFrame():
          out.add(_buildShellPage(context, f));
        case _StatefulShellFrame():
          out.add(_buildStatefulShellPage(context, f));
      }
    }
    return out;
  }

  Page<Object?> _buildSinglePage(BuildContext context, _PageFrame frame) {
    final compiled = frame.compiled;
    final st = frame.toState();
    if (compiled == null) {
      final config = OmniPageConfig.of(context);
      final widget = OmniRouteStateScope(
        state: st,
        child: _errorBuilder(context, st, frame.error),
      );
      final type = frame.animatedOverride == false
          ? OmniPages.none
          : (frame.transitionOverride ?? config.transition);
      return type(frame.key, 'error', widget);
    }

    return compiled.page.buildPage(
      context,
      st,
      fullRoutePath: compiled.fullPath,
      groupTransition: compiled.groupTransition,
      navTransition: frame.transitionOverride,
      animated: frame.animatedOverride,
      wrapGroups: compiled.groups.isEmpty
          ? null
          : (ctx, state, innerChild) =>
                _wrapGroups(compiled.groups, state, innerChild),
    );
  }

  Widget _wrapGroups(
    List<CompiledGroup> groups,
    OmniRouteState state,
    Widget child,
  ) {
    var current = child;
    for (var i = groups.length - 1; i >= 0; i--) {
      final g = groups[i];
      final scopeVal = g.group.scopeKey != null
          ? g.group.scopeKey!(state)
          : _defaultGroupScopeKey;
      final scopeKey = _GroupScopeKey(g.id, scopeVal);
      current = _GroupScopeHost(
        manager: _groupManager,
        scopeKey: scopeKey,
        provide: g.group.provide,
        hasActiveStackRef: () => _activeGroupScopeKeys().contains(scopeKey),
        child: current,
      );
    }
    return current;
  }

  Page<Object?> _buildShellPage(BuildContext context, _ShellFrame frame) {
    final compiled = frame.shell;
    final shell = compiled.shell;
    final st = _topPageFrameIn(frame.children)?.toState() ?? state;

    final innerNav = _ScopedHeroHost(
      child: _buildNavigator(
        key: compiled.navigatorKey,
        pages: _buildNavigatorPages(
          context,
          frame.children,
          navigatorKey: compiled.navigatorKey,
        ),
        observers: shell.observers,
      ),
    );

    final built = shell.provide.isEmpty
        ? shell.builder(context, st, innerNav)
        : OmniBlocScope(
            provide: shell.provide,
            child: Builder(
              builder: (innerCtx) => shell.builder(innerCtx, st, innerNav),
            ),
          );

    return OmniPages.none(frame.key, 'shell_${compiled.id}', built);
  }

  Page<Object?> _buildStatefulShellPage(
    BuildContext context,
    _StatefulShellFrame frame,
  ) {
    final compiled = frame.statefulShell;
    final shell = compiled.shell;
    final st =
        _topPageFrameIn(frame.branches[frame.currentIndex])?.toState() ?? state;

    final branchWidgets = <Widget>[
      for (var i = 0; i < compiled.branches.length; i++)
        _buildBranchWidget(
          context,
          compiled.branches[i],
          frame.branches[i],
          active: i == frame.currentIndex,
        ),
    ];

    final navShell = OmniNavigationShell(
      currentIndex: frame.currentIndex,
      onGoBranch: (idx, {bool initialLocation = false}) =>
          _goBranch(frame, idx, initialLocation: initialLocation),
      branchChildren: branchWidgets,
    );

    Widget built;
    if (shell.provide.isNotEmpty) {
      built = OmniBlocScope(
        provide: shell.provide,
        child: Builder(
          builder: (innerCtx) => shell.builder(innerCtx, st, navShell),
        ),
      );
    } else {
      built = shell.builder(context, st, navShell);
    }
    if (shell.restorationScopeId != null) {
      built = RestorationScope(
        restorationId: shell.restorationScopeId,
        child: built,
      );
    }

    return OmniPages.none(frame.key, 'stateful_shell_${compiled.id}', built);
  }

  Widget _buildBranchWidget(
    BuildContext context,
    CompiledBranch branch,
    List<_StackFrame> stack, {
    required bool active,
  }) {
    Widget child = _ScopedHeroHost(
      child: _buildNavigator(
        key: branch.navigatorKey,
        pages: _buildNavigatorPages(
          context,
          stack,
          navigatorKey: branch.navigatorKey,
        ),
        restorationScopeId: branch.branch.restorationScopeId,
        observers: branch.branch.observers,
      ),
    );
    if (branch.branch.provide.isNotEmpty) {
      child = OmniBlocScope(provide: branch.branch.provide, child: child);
    }
    return TickerMode(enabled: active, child: child);
  }

  _PageFrame? _topPageFrameIn(List<_StackFrame> frames) {
    if (frames.isEmpty) return null;
    final last = frames.last;
    return switch (last) {
      _PageFrame() => last,
      _ShellFrame() => _topPageFrameIn(last.children),
      _StatefulShellFrame() => _topPageFrameIn(
        last.branches[last.currentIndex],
      ),
    };
  }

  // ── Restoration JSON Serialization ─────────────────────────────────────

  String _serializeStack() {
    Object? encodeFrame(_StackFrame f) => switch (f) {
      _PageFrame() => {'t': 'p', 'k': f.key.value, 'u': f.uri.toString()},
      _ShellFrame() => {
        't': 's',
        'k': f.key.value,
        'id': f.shell.id,
        'c': [for (final c in f.children) encodeFrame(c)],
      },
      _StatefulShellFrame() => {
        't': 'ss',
        'k': f.key.value,
        'id': f.statefulShell.id,
        'i': f.currentIndex,
        'b': [
          for (final br in f.branches) [for (final c in br) encodeFrame(c)],
        ],
      },
    };

    return jsonEncode({
      'n': _nextKeyId,
      'r': [for (final f in _rootStack) encodeFrame(f)],
    });
  }

  void _restoreFromJson(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, Object?>;
      final savedN = data['n'];
      if (savedN is int && savedN > _nextKeyId) _nextKeyId = savedN;

      _StackFrame? decodeFrame(Object? item) {
        if (item is! Map<String, Object?>) return null;
        final t = item['t'];
        final keyStr = item['k'] as String? ?? 'p_${_nextKeyId++}';
        final key = ValueKey<String>(keyStr);
        if (t == 'p') {
          final uriStr = item['u'] as String? ?? '/';
          final uri = _normalizeUri(_normalizeParse(uriStr));
          final match = _registry.matchUri(uri);
          return _PageFrame(
            key: key,
            uri: uri,
            matchedLocation: uri.path.isEmpty ? '/' : uri.path,
            compiled: match?.route,
            pathParameters: match?.pathParameters ?? const {},
            error: match == null
                ? OmniRouteException(
                    OmniErrorCode.missingRoute,
                    'No route matches ${uri.path}.',
                  )
                : null,
          );
        } else if (t == 's') {
          final id = item['id'] as int?;
          final compiledShell = _findCompiledShellById(id);
          if (compiledShell == null) return null;
          final rawChildren = item['c'] as List<Object?>? ?? const [];
          final children = <_StackFrame>[
            for (final c in rawChildren) ?decodeFrame(c),
          ];
          if (children.isEmpty) return null;
          return _ShellFrame(
            shell: compiledShell,
            key: key,
            children: children,
          );
        } else if (t == 'ss') {
          final id = item['id'] as int?;
          final compiledSS = _findCompiledStatefulShellById(id);
          if (compiledSS == null) return null;
          final rawBranches = item['b'] as List<Object?>? ?? const [];
          final decodedBranches = <List<_StackFrame>>[];
          for (var i = 0; i < compiledSS.branches.length; i++) {
            final list = i < rawBranches.length
                ? (rawBranches[i] as List<Object?>? ?? const [])
                : const [];
            final parsed = <_StackFrame>[for (final c in list) ?decodeFrame(c)];
            decodedBranches.add(
              parsed.isEmpty
                  ? _seedBranchStack(compiledSS.branches[i])
                  : parsed,
            );
          }
          final idx = (item['i'] as int? ?? 0).clamp(
            0,
            compiledSS.branches.length - 1,
          );
          return _StatefulShellFrame(
            statefulShell: compiledSS,
            key: key,
            currentIndex: idx,
            branches: decodedBranches,
          );
        }
        return null;
      }

      final rawRoot = data['r'] as List<Object?>? ?? const [];
      final restoredRoot = <_StackFrame>[
        for (final f in rawRoot) ?decodeFrame(f),
      ];
      if (restoredRoot.isNotEmpty) {
        _rootStack
          ..clear()
          ..addAll(restoredRoot);
        _initialGuardsDone = true;
        _syncCurrentNotifiers(emitChanges: false);
      }
    } catch (_) {
      // Malformed restoration blob falls back gracefully to initialRoute.
    }
  }

  CompiledShell? _findCompiledShellById(int? id) {
    if (id == null) return null;
    for (final path in _registry.paths) {
      final m = _registry.matchUri(Uri(path: path));
      if (m == null) continue;
      for (final ref in m.route.fullEnclosingShells) {
        if (ref is CompiledShell && ref.id == id) return ref;
      }
    }
    return null;
  }

  CompiledStatefulShell? _findCompiledStatefulShellById(int? id) {
    if (id == null) return null;
    for (final path in _registry.paths) {
      final m = _registry.matchUri(Uri(path: path));
      if (m == null) continue;
      for (final ref in m.route.fullEnclosingShells) {
        if (ref is CompiledBranchRef && ref.statefulShell.id == id) {
          return ref.statefulShell;
        }
      }
    }
    return null;
  }

  static Uri _normalizeParse(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return Uri(path: '/');
    final u = Uri.parse(trimmed);
    if (u.path.isEmpty) return u.replace(path: '/');
    return u;
  }

  static Uri _normalizeUri(Uri uri) {
    var path = uri.path;
    if (path.isEmpty) path = '/';
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path == uri.path &&
        !(uri.hasQuery && uri.query.isEmpty) &&
        !uri.toString().endsWith('?')) {
      return uri;
    }
    return Uri(
      path: path,
      queryParameters: uri.queryParametersAll.isEmpty
          ? null
          : uri.queryParametersAll,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );
  }

  static String _fillAncestorPath(String pattern, Map<String, String> params) {
    if (!pattern.contains(':')) return pattern;
    return OmniRouteRegistry.location(
      pattern,
      params: {
        for (final seg in pattern.split('/'))
          if (seg.startsWith(':'))
            seg.substring(1): params[seg.substring(1)] ?? '',
      },
    );
  }

  static Map<String, String> _filterParamsFor(
    CompiledRoute route,
    Map<String, String> all,
  ) {
    if (all.isEmpty) return const {};
    return Map<String, String>.unmodifiable(all);
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshListenable?.removeListener(refresh);
    _clearFrames(_rootStack);
    _groupManager.disposeAll();
    _currentEntryNotifier.dispose();
    _delegate.dispose();
    _infoProvider.dispose();
    super.dispose();
  }
}

// ── Stack Frames ───────────────────────────────────────────────────────────

sealed class _StackFrame {}

class _PageFrame extends _StackFrame {
  _PageFrame({
    required this.key,
    required this.uri,
    required this.matchedLocation,
    required this.compiled,
    required this.pathParameters,
    this.extra,
    this.error,
    this.transitionOverride,
    this.animatedOverride,
    this.completer,
  });

  final ValueKey<String> key;
  final Uri uri;
  final String matchedLocation;
  final CompiledRoute? compiled;
  final Map<String, String> pathParameters;
  final Object? extra;
  final Object? error;
  final OmniPageType? transitionOverride;
  final bool? animatedOverride;
  final Completer<Object?>? completer;

  OmniRouteEntry toEntry() => compiled != null
      ? OmniRouteEntry.fromPage(
          compiled!.page,
          matchedLocation,
          routePath: compiled!.fullPath,
        )
      : errorEntryFor(uri);

  OmniRouteState toState() => OmniRouteState(
    uri: uri,
    matchedLocation: matchedLocation,
    pageKey: key,
    path: compiled?.fullPath,
    name: compiled?.page.name,
    pathParameters: pathParameters,
    extra: extra,
    metadata: compiled?.page.metadata,
    error: error,
  );
}

class _ShellFrame extends _StackFrame {
  _ShellFrame({required this.shell, required this.key, required this.children});

  final CompiledShell shell;
  final ValueKey<String> key;
  final List<_StackFrame> children;
}

class _StatefulShellFrame extends _StackFrame {
  _StatefulShellFrame({
    required this.statefulShell,
    required this.key,
    required this.currentIndex,
    required this.branches,
  });

  final CompiledStatefulShell statefulShell;
  final ValueKey<String> key;
  int currentIndex;
  final List<List<_StackFrame>> branches;
}

// ── RouterDelegate & Parser ────────────────────────────────────────────────

class _OmniRouterDelegate extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  _OmniRouterDelegate(this.router) {
    router.addListener(notifyListeners);
  }

  final OmniRouter router;

  @override
  GlobalKey<NavigatorState> get navigatorKey => router.navigatorKey;

  @override
  Uri get currentConfiguration => router.location;

  @override
  Future<bool> popRoute() async {
    // Give the deepest active navigator a chance to run `PopScope` / dismiss
    // barriers / pop its own route before popping outer navigators.
    final navKeys = <GlobalKey<NavigatorState>>[];
    void collect(List<_StackFrame> frames) {
      if (frames.isEmpty) return;
      final last = frames.last;
      switch (last) {
        case _PageFrame():
          return;
        case _ShellFrame():
          navKeys.add(last.shell.navigatorKey);
          collect(last.children);
        case _StatefulShellFrame():
          navKeys.add(
            last.statefulShell.branches[last.currentIndex].navigatorKey,
          );
          collect(last.branches[last.currentIndex]);
      }
    }

    navKeys.add(router.navigatorKey);
    collect(router._rootStack);

    for (var i = navKeys.length - 1; i >= 0; i--) {
      final nav = navKeys[i].currentState;
      if (nav == null) continue;
      if (await nav.maybePop()) return true;
    }
    return false;
  }

  @override
  Future<void> setInitialRoutePath(Uri configuration) {
    if (configuration != router.location &&
        configuration.path.isNotEmpty &&
        !(router._initialGuardsDone)) {
      router._seedInitialStack(configuration);
    }
    return SynchronousFuture<void>(null);
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    if (configuration != router.location) {
      router.go(configuration.toString());
    }
    return SynchronousFuture<void>(null);
  }

  @override
  Widget build(BuildContext context) => _OmniRouterHost(router: router);

  @override
  void dispose() {
    router.removeListener(notifyListeners);
    super.dispose();
  }
}

class _OmniRouteInformationParser extends RouteInformationParser<Uri> {
  const _OmniRouteInformationParser();

  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture<Uri>(routeInformation.uri);

  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

// ── Host Widget (Restoration + Host BuildContext + Guards) ─────────────────

class _OmniRouterHost extends StatefulWidget {
  const _OmniRouterHost({required this.router});

  final OmniRouter router;

  @override
  State<_OmniRouterHost> createState() => _OmniRouterHostState();
}

class _OmniRouterHostState extends State<_OmniRouterHost>
    with RestorationMixin {
  final RestorableStringN _savedStack = RestorableStringN(null);
  bool _restored = false;

  @override
  String? get restorationId {
    final id = widget.router.restorationScopeId;
    return id == null ? null : '__omni_host_$id';
  }

  @override
  void initState() {
    super.initState();
    widget.router.addListener(_onRouterChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.router._attachHost(context);
    widget.router._runInitialGuardsIfNeeded();
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_savedStack, '_omni_router_stack');
    if (!_restored) {
      _restored = true;
      final saved = _savedStack.value;
      if (saved != null && saved.isNotEmpty) {
        widget.router._restoreFromJson(saved);
      } else if (restorationId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && restorationId != null && _savedStack.value == null) {
            _savedStack.value = widget.router._serializeStack();
          }
        });
      }
    }
  }

  void _onRouterChanged() {
    if (!mounted) return;
    if (restorationId != null && _restored) {
      _savedStack.value = widget.router._serializeStack();
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.router.removeListener(_onRouterChanged);
    _savedStack.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.router._buildRoot(context);
}

class _OmniRouterScope extends InheritedWidget {
  const _OmniRouterScope({
    required this.router,
    required this.canPopValue,
    required super.child,
  });

  final OmniRouter router;
  final bool canPopValue;

  @override
  bool updateShouldNotify(_OmniRouterScope old) =>
      !identical(old.router, router) || old.canPopValue != canPopValue;
}

class _OmniPopObserver extends NavigatorObserver {
  _OmniPopObserver(this.onPop);

  final void Function(Route<dynamic> route, Route<dynamic>? previousRoute)
  onPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onPop(route, previousRoute);
}

class _ScopedHeroHost extends StatefulWidget {
  const _ScopedHeroHost({required this.child});

  final Widget child;

  @override
  State<_ScopedHeroHost> createState() => _ScopedHeroHostState();
}

class _ScopedHeroHostState extends State<_ScopedHeroHost> {
  final HeroController _controller = HeroController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      HeroControllerScope(controller: _controller, child: widget.child);
}

// ── Flat Group Bloc Scopes (zero nested Navigator overhead) ──────────────

class _GroupScopeKey {
  const _GroupScopeKey(this.groupId, this.scopeValue);

  final int groupId;
  final Object? scopeValue;

  @override
  bool operator ==(Object other) =>
      other is _GroupScopeKey &&
      other.groupId == groupId &&
      other.scopeValue == scopeValue;

  @override
  int get hashCode => Object.hash(groupId, scopeValue);
}

class _GroupScopeBox {
  _GroupScopeBox(this.provide)
    : instances = List<OmniAnyBloc?>.filled(provide.length, null);

  final List<OmniBlocEntry> provide;
  final List<OmniAnyBloc?> instances;
  int mounts = 0;
  bool closed = false;

  OmniAnyBloc getOrCreate(
    int index,
    BuildContext context,
    OmniBlocRegistry registry,
  ) => instances[index] ??= provide[index].instantiate(context, registry);

  void closeOwned() {
    if (closed) return;
    closed = true;
    for (var i = 0; i < provide.length; i++) {
      final instance = instances[i];
      if (provide[i].isOwned && instance != null) {
        instance.close();
      }
      instances[i] = null;
    }
  }
}

class _GroupScopeManager {
  final Map<_GroupScopeKey, _GroupScopeBox> _boxes = {};

  _GroupScopeBox retain(_GroupScopeKey key, List<OmniBlocEntry> provide) {
    final box = _boxes.putIfAbsent(key, () => _GroupScopeBox(provide));
    box.mounts++;
    return box;
  }

  void release(
    _GroupScopeKey key,
    _GroupScopeBox box, {
    required bool hasActiveStackRef,
  }) {
    box.mounts = (box.mounts - 1).clamp(0, 1 << 20);
    if (box.mounts == 0 && !hasActiveStackRef) {
      if (identical(_boxes[key], box)) {
        _boxes.remove(key);
      }
      box.closeOwned();
    }
  }

  void pruneUnused(Set<_GroupScopeKey> activeKeys) {
    final toRemove = <_GroupScopeKey>[];
    _boxes.forEach((k, box) {
      if (box.mounts <= 0 && !activeKeys.contains(k)) {
        toRemove.add(k);
      }
    });
    for (final k in toRemove) {
      _boxes.remove(k)?.closeOwned();
    }
  }

  void disposeAll() {
    for (final box in _boxes.values) {
      box.closeOwned();
    }
    _boxes.clear();
  }
}

class _GroupScopeHost extends StatefulWidget {
  const _GroupScopeHost({
    required this.manager,
    required this.scopeKey,
    required this.provide,
    required this.hasActiveStackRef,
    required this.child,
  });

  final _GroupScopeManager manager;
  final _GroupScopeKey scopeKey;
  final List<OmniBlocEntry> provide;
  final bool Function() hasActiveStackRef;
  final Widget child;

  @override
  State<_GroupScopeHost> createState() => _GroupScopeHostState();
}

class _GroupScopeHostState extends State<_GroupScopeHost> {
  late _GroupScopeBox _box;

  @override
  void initState() {
    super.initState();
    _box = widget.manager.retain(widget.scopeKey, widget.provide);
  }

  @override
  void didUpdateWidget(_GroupScopeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey) {
      final oldBox = _box;
      _box = widget.manager.retain(widget.scopeKey, widget.provide);
      widget.manager.release(
        oldWidget.scopeKey,
        oldBox,
        hasActiveStackRef: oldWidget.hasActiveStackRef(),
      );
    }
  }

  @override
  void dispose() {
    widget.manager.release(
      widget.scopeKey,
      _box,
      hasActiveStackRef: widget.hasActiveStackRef(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.provide.isEmpty) return widget.child;
    final registry = OmniGlobalBlocScope.registryOf(context);
    registry.registerPageBlocs(widget.provide);

    Widget wrapChain(int index) {
      if (index >= widget.provide.length) return widget.child;
      final p = widget.provide[index];
      final existing = _box.instances[index];
      if (existing != null) {
        return p.valueProvider(existing, child: wrapChain(index + 1));
      }
      return Builder(
        builder: (innerCtx) {
          final created = _box.getOrCreate(index, innerCtx, registry);
          return p.valueProvider(created, child: wrapChain(index + 1));
        },
      );
    }

    return wrapChain(0);
  }
}
