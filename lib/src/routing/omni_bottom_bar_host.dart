import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import 'omni_route_state.dart';

/// Signature for building an [OmniPage]-level bottom navigation bar from the
/// active [BuildContext] and matched [OmniRouteState].
typedef OmniBottomNavigationBarBuilder =
    Widget Function(BuildContext context, OmniRouteState state);

enum _PageBarSlot { body, bottomBar }

class _BottomNavBodyConstraints extends BoxConstraints {
  const _BottomNavBodyConstraints({
    required super.maxWidth,
    required super.maxHeight,
    required this.bottomBarHeight,
  });

  final double bottomBarHeight;

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is _BottomNavBodyConstraints &&
      other.bottomBarHeight == bottomBarHeight;

  @override
  int get hashCode => Object.hash(super.hashCode, bottomBarHeight);

  @override
  String toString() =>
      '${super.toString()} (bottomBarHeight: $bottomBarHeight)';
}

class _PageBottomBarLayoutDelegate extends MultiChildLayoutDelegate {
  _PageBottomBarLayoutDelegate({
    required this.extendBody,
    required this.keyboardInset,
    required this.hideOnKeyboard,
  });

  final bool extendBody;
  final double keyboardInset;
  final bool hideOnKeyboard;

  @override
  void performLayout(Size size) {
    final fullWidth = BoxConstraints.loose(size).tighten(width: size.width);
    var barHeight = 0.0;
    final keyboardOpen = hideOnKeyboard && keyboardInset > 0;

    if (hasChild(_PageBarSlot.bottomBar)) {
      final barSize = layoutChild(_PageBarSlot.bottomBar, fullWidth);
      if (!keyboardOpen) {
        barHeight = barSize.height;
      }
      final barTop = math.max(0.0, size.height - barSize.height);
      positionChild(_PageBarSlot.bottomBar, Offset(0, barTop));
    }

    if (hasChild(_PageBarSlot.body)) {
      final bodyHeight = extendBody
          ? size.height
          : math.max(0.0, size.height - barHeight);
      final propagatedBottom = extendBody ? barHeight : 0.0;

      layoutChild(
        _PageBarSlot.body,
        _BottomNavBodyConstraints(
          maxWidth: size.width,
          maxHeight: bodyHeight,
          bottomBarHeight: propagatedBottom,
        ),
      );
      positionChild(_PageBarSlot.body, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(covariant _PageBottomBarLayoutDelegate old) =>
      old.extendBody != extendBody ||
      old.keyboardInset != keyboardInset ||
      old.hideOnKeyboard != hideOnKeyboard;
}

/// Hosts an [OmniPage]-level [bottomNavigationBar] cleanly above [child] without
/// introducing a second nested `Scaffold` (preserving `ScaffoldMessenger`,
/// `Drawer`, and inner `AppBar` behavior while still propagating accurate
/// `MediaQuery.padding.bottom` to lists, safe areas, and FABs).
class OmniPageBottomBarHost extends StatelessWidget {
  /// Wraps [child] with [bottomNavigationBar].
  const OmniPageBottomBarHost({
    super.key,
    required this.bottomNavigationBar,
    required this.child,
    this.extendBody = true,
    this.hideOnKeyboard = true,
  });

  /// Navigation bar placed at the bottom of the page.
  final Widget bottomNavigationBar;

  /// Screen widget below the bar.
  final Widget child;

  /// When `true` (default), [child] spans full height underneath translucent /
  /// floating / curved bars and receives `MediaQuery.padding.bottom` matching
  /// the bar's height. When `false`, [child] is docked strictly above the bar.
  final bool extendBody;

  /// Collapses bottom padding impact when the software keyboard opens.
  final bool hideOnKeyboard;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;

    return CustomMultiChildLayout(
      delegate: _PageBottomBarLayoutDelegate(
        extendBody: extendBody,
        keyboardInset: keyboardInset,
        hideOnKeyboard: hideOnKeyboard,
      ),
      children: [
        LayoutId(
          id: _PageBarSlot.body,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final navConstraints = constraints as _BottomNavBodyConstraints;
              final baseMedia = MediaQuery.of(ctx);
              final adjustedBottom = extendBody
                  ? math.max(
                      baseMedia.padding.bottom,
                      navConstraints.bottomBarHeight,
                    )
                  : 0.0;
              return MediaQuery(
                data: baseMedia.copyWith(
                  padding: baseMedia.padding.copyWith(bottom: adjustedBottom),
                ),
                child: child,
              );
            },
          ),
        ),
        LayoutId(id: _PageBarSlot.bottomBar, child: bottomNavigationBar),
      ],
    );
  }
}

// ── Persistent page bars ─────────────────────────────────────────────────────

/// How an [OmniPage]'s `bottomNavigationBar` behaves while pages change.
enum OmniPageBarTransition {
  /// The bar stays fixed while the page under it changes; only its own
  /// animation runs (indicator, notch). To or from a page without a bar it
  /// slides down / up in step with the page transition. Default.
  slide,

  /// Like [slide], but to or from a page without a bar it fades.
  fade,

  /// The bar is part of the page and moves with the page transition.
  withPage,
}

/// Keeps one bar per navigator fixed while its pages change.
///
/// Every page bar in this navigator is the same element, moved (GlobalKey)
/// between the page that shows it and this host: while a page transition
/// runs, the host draws the bar above the navigator — fixed in place — and
/// the pages keep a same-sized empty slot; afterwards the new page takes it
/// back. One element means one state, so the indicator animates from the
/// old tab to the new one. Dialogs and sheets pushed on the navigator still
/// cover the bar, because outside transitions it lives inside the page.
@internal
class OmniPageBarHost extends StatefulWidget {
  /// Wraps the navigator built by [builder]; pass the given observer to it.
  const OmniPageBarHost({super.key, required this.builder});

  /// Builds the navigator with the host's observer added.
  final Widget Function(BuildContext context, NavigatorObserver observer)
  builder;

  @override
  State<OmniPageBarHost> createState() => _OmniPageBarHostState();
}

/// Token for "the host draws the bar right now".
const Object _hostOwns = Object();

class _BarClaim {
  _BarClaim(this.route, this.bar, this.transition);

  final Route<dynamic> route;
  Widget bar;
  OmniPageBarTransition transition;
}

class _Session {
  _Session({
    required this.incoming,
    required this.outgoing,
    required this.route,
    required this.animation,
    required this.pop,
    required this.gesture,
  });

  /// The route whose transition this is.
  final Route<dynamic> route;

  /// Page becoming current.
  final Route<dynamic>? incoming;

  /// Page leaving.
  final Route<dynamic>? outgoing;

  /// The moving route's animation.
  final Animation<double> animation;
  final bool pop;

  /// A back swipe that may still be cancelled.
  final bool gesture;

  /// 0 → 1 as [incoming] arrives.
  double get progress => pop ? 1 - animation.value : animation.value;
}

class _OmniPageBarHostState extends State<OmniPageBarHost> {
  final GlobalKey _barKey = GlobalKey(debugLabel: 'OmniPageBar');
  late final _BarObserver _observer = _BarObserver(this);
  final Map<Route<dynamic>, _BarClaim> _claims = {};

  /// The route whose page draws the bar, [_hostOwns], or `null` (the
  /// current page draws it until the host settles).
  final ValueNotifier<Object?> owner = ValueNotifier<Object?>(null);

  /// Last laid-out bar height, for the empty slots.
  final ValueNotifier<double> barHeight = ValueNotifier<double>(0);

  _Session? _session;
  Route<dynamic>? _topPage;

  @override
  void dispose() {
    _session?.animation.removeStatusListener(_onSessionStatus);
    owner.dispose();
    barHeight.dispose();
    super.dispose();
  }

  static bool _isPage(Route<dynamic>? route) =>
      route is PageRoute && route.opaque;

  /// Whether widgets are being built right now. Observer callbacks arrive
  /// mid-build inside frames, and also outside any frame: `runApp` and hot
  /// restart build the first tree with the scheduler idle, and the
  /// navigator reports its first push then. `debugBuilding` covers that
  /// case; it is only tracked in debug, the only mode that asserts on a
  /// mid-build `setState` (in release the host simply rebuilds).
  static bool get _midBuild =>
      SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks ||
      (WidgetsBinding.instance.buildOwner?.debugBuilding ?? false);

  /// Acts now, or after the frame when widgets are building (asking for a
  /// frame if none is coming). Gestures — a back swipe — act at once, so
  /// the bar never lags a frame behind the finger.
  void _defer(VoidCallback action) {
    if (!_midBuild) {
      action();
      return;
    }
    final scheduler = SchedulerBinding.instance;
    scheduler.addPostFrameCallback((_) {
      if (mounted) action();
    });
    scheduler.ensureVisualUpdate();
  }

  /// A hero flight parks the arriving route offstage for a frame, which
  /// swaps its animation for an always-complete one; that is not the end of
  /// the transition.
  static bool _offstage(Route<dynamic> route) =>
      route is ModalRoute && route.offstage;

  void _begin({
    required Route<dynamic> route,
    required Route<dynamic>? incoming,
    required Route<dynamic>? outgoing,
    bool pop = false,
    bool gesture = false,
  }) {
    final animation = route is ModalRoute ? route.animation : null;
    _defer(() {
      _endSession(settle: false);
      final claim = _claims[incoming] ?? _claims[outgoing];
      final animating =
          animation != null &&
          (gesture ||
              _offstage(route) ||
              animation.status == AnimationStatus.forward ||
              animation.status == AnimationStatus.reverse);
      if (claim == null ||
          claim.transition == OmniPageBarTransition.withPage ||
          !animating) {
        _settle();
        return;
      }
      _session = _Session(
        route: route,
        incoming: incoming,
        outgoing: outgoing,
        animation: animation,
        pop: pop,
        gesture: gesture,
      );
      animation.addStatusListener(_onSessionStatus);
      owner.value = _hostOwns;
      setState(() {});
    });
  }

  void _onSessionStatus(AnimationStatus status) {
    final session = _session;
    if (session == null || _offstage(session.route)) return;
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _endSession(settle: true);
    }
  }

  void _endSession({required bool settle}) {
    final session = _session;
    if (session == null) return;
    session.animation.removeStatusListener(_onSessionStatus);
    _session = null;
    if (settle) _settle();
  }

  /// Hands the bar back to the top page.
  void _settle() {
    if (!mounted) return;
    final top = _topPage;
    final claim = top == null ? null : _claims[top];
    owner.value = claim != null && top!.isActive ? top : null;
    setState(() {});
  }

  void _register(_BarClaim claim) => _claims[claim.route] = claim;

  void _unregister(_BarClaim claim) {
    if (!identical(_claims[claim.route], claim)) return;
    _claims.remove(claim.route);
    if (owner.value == claim.route) _defer(_settle);
  }

  void _reportHeight(double height) {
    if (height == barHeight.value) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) barHeight.value = height;
    });
  }

  Widget _keyed(Widget bar) => KeyedSubtree(
    key: _barKey,
    child: _BarSizeReporter(onHeight: _reportHeight, child: bar),
  );

  Widget? _buildOverlay() {
    final session = _session;
    if (session == null) return null;
    final to = _claims[session.incoming];
    final from = _claims[session.outgoing];
    if (to == null && from == null) return null;
    final mode = (to ?? from)!.transition;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: session.animation,
          builder: (context, _) {
            // Both pages have a bar: it stays put and shows the page that
            // is arriving (a back swipe keeps the current one until it
            // commits).
            if (to != null && from != null) {
              return _keyed(session.gesture ? from.bar : to.bar);
            }
            final p = Curves.easeOutCubic.transform(
              session.progress.clamp(0.0, 1.0),
            );
            final shown = to ?? from!;
            final visible = to != null ? p : 1 - p; // 1 = fully on screen
            final child = _keyed(shown.bar);
            return mode == OmniPageBarTransition.fade
                ? Opacity(opacity: visible, child: child)
                : FractionalTranslation(
                    translation: Offset(0, 1 - visible),
                    child: child,
                  );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _buildOverlay();
    return _PageBarHostScope(
      host: this,
      child: Stack(
        fit: StackFit.expand,
        children: [widget.builder(context, _observer), ?overlay],
      ),
    );
  }
}

class _BarObserver extends NavigatorObserver {
  _BarObserver(this.host);

  final _OmniPageBarHostState host;

  bool _isPage(Route<dynamic>? r) => _OmniPageBarHostState._isPage(r);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_isPage(route)) return;
    final outgoing = _isPage(previousRoute) ? previousRoute : host._topPage;
    host._topPage = route;
    host._begin(route: route, incoming: route, outgoing: outgoing);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_isPage(route)) return;
    final incoming = _isPage(previousRoute) ? previousRoute : null;
    host._topPage = incoming;
    host._begin(route: route, incoming: incoming, outgoing: route, pop: true);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (host._topPage == route) {
      host._topPage = _isPage(previousRoute) ? previousRoute : null;
      host._defer(host._settle);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (!_isPage(newRoute)) return;
    host._topPage = newRoute;
    host._begin(route: newRoute!, incoming: newRoute, outgoing: oldRoute);
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    if (!_isPage(route)) return;
    host._begin(
      route: route,
      incoming: _isPage(previousRoute) ? previousRoute : null,
      outgoing: route,
      pop: true,
      gesture: true,
    );
  }
}

class _PageBarHostScope extends InheritedWidget {
  const _PageBarHostScope({required this.host, required super.child});

  final _OmniPageBarHostState host;

  @override
  bool updateShouldNotify(_PageBarHostScope old) => old.host != host;
}

/// Puts a page's bar into its navigator's [OmniPageBarHost] (or, with
/// [OmniPageBarTransition.withPage] or no host, simply shows it).
@internal
class OmniPageBarSlot extends StatefulWidget {
  /// Claims [bar] for the enclosing page.
  const OmniPageBarSlot({
    super.key,
    required this.bar,
    this.transition = OmniPageBarTransition.slide,
  });

  /// The page's bar.
  final Widget bar;

  /// How it behaves while pages change.
  final OmniPageBarTransition transition;

  @override
  State<OmniPageBarSlot> createState() => _OmniPageBarSlotState();
}

class _OmniPageBarSlotState extends State<OmniPageBarSlot> {
  _OmniPageBarHostState? _host;
  _BarClaim? _claim;

  @override
  void dispose() {
    final claim = _claim;
    if (claim != null) _host?._unregister(claim);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = context
        .dependOnInheritedWidgetOfExactType<_PageBarHostScope>()
        ?.host;
    final route = ModalRoute.of(context);
    if (host == null ||
        route == null ||
        widget.transition == OmniPageBarTransition.withPage) {
      final claim = _claim;
      if (claim != null) _host?._unregister(claim);
      _claim = null;
      return widget.bar;
    }
    if (!identical(host, _host) || _claim?.route != route) {
      final old = _claim;
      if (old != null) _host?._unregister(old);
      _claim = null;
    }
    _host = host;
    final claim = _claim ??= _BarClaim(route, widget.bar, widget.transition);
    claim
      ..bar = widget.bar
      ..transition = widget.transition;
    host._register(claim);

    return ValueListenableBuilder<Object?>(
      valueListenable: host.owner,
      builder: (context, owner, _) {
        final owns = owner == route || (owner == null && route.isCurrent);
        if (owns) return host._keyed(widget.bar);
        return ValueListenableBuilder<double>(
          valueListenable: host.barHeight,
          builder: (context, h, _) => SizedBox(height: h),
        );
      },
    );
  }
}

class _BarSizeReporter extends SingleChildRenderObjectWidget {
  const _BarSizeReporter({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  _RenderBarSizeReporter createRenderObject(BuildContext context) =>
      _RenderBarSizeReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBarSizeReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderBarSizeReporter extends RenderProxyBox {
  _RenderBarSizeReporter(this.onHeight);

  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}
