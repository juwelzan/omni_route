import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/omni_router.dart';

/// How a page can be closed by an edge swipe; see `OmniPages.transition`,
/// `OmniPages.custom` and `OmniApp(swipeBack:)`.
///
/// In the descriptions, `p` is the swipe progress (0 = untouched, 1 =
/// closed).
enum OmniSwipeBack {
  /// No swipe gesture (default).
  none,

  /// iOS-like: the page follows the finger 1:1 with a light edge shadow;
  /// the page below shifts in from -30% (parallax).
  slide,

  /// Scales to 0.82, moves with the finger at 45%, rounds its corners and
  /// fades out after p = 0.75. The page below is not changed.
  zoom,

  /// Shrinks in place to 0.75 around the center and fades out from
  /// p = 0.5: the page "falls back" into the screen.
  zoomCenter,

  /// Shrinks to 0.7 toward the edge it is swiped to, moving at 25%: the page
  /// is pushed off that side.
  zoomToEdge,

  /// Shrinks to 0.8 around the finger and moves with it at 60%, like
  /// holding a card.
  zoomFollow,

  /// Card stack: like [zoom] (0.85) with a soft shadow, and the page below
  /// lights up from a dim overlay as it is revealed.
  zoomCard,

  /// Both pages zoom: the top as [zoom], the page below grows 0.94 → 1.0
  /// over a background color (no black edges).
  zoomParallax,

  /// Like [zoom] plus a small 3D turn away, like a door
  /// ([OmniSwipeBackStyle.maxTilt]).
  zoomTilt,
}

/// A screen edge a swipe-back may start from.
enum OmniSwipeEdge {
  /// The left screen edge (closes by moving right).
  left,

  /// The right screen edge (closes by moving left).
  right,
}

/// Tuning for the swipe-back gesture and its visuals. Visual values left
/// null use the per-mode defaults described on [OmniSwipeBack].
@immutable
class OmniSwipeBackStyle {
  /// All values have defaults tuned for phones.
  const OmniSwipeBackStyle({
    this.minScale,
    this.maxRadius,
    this.slideFactor,
    this.fadeStart,
    this.maxTilt = 0.25,
    this.shadow,
    this.dimBelow,
    this.backgroundColor,
    this.edgeWidth = 28,
    this.edges = const {OmniSwipeEdge.left, OmniSwipeEdge.right},
    this.closeThreshold = 0.5,
    this.flickVelocity = 1.0,
    this.settleCurve = Curves.easeOutBack,
    this.closeCurve = Curves.easeOutCubic,
    this.settleDuration = const Duration(milliseconds: 300),
  }) : assert(minScale == null || (minScale > 0 && minScale <= 1)),
       assert(fadeStart == null || (fadeStart >= 0 && fadeStart < 1)),
       assert(closeThreshold > 0 && closeThreshold < 1);

  /// Less zoom, no tilt, no shadow or dimming.
  const OmniSwipeBackStyle.subtle({
    this.edgeWidth = 28,
    this.edges = const {OmniSwipeEdge.left, OmniSwipeEdge.right},
    this.closeThreshold = 0.5,
    this.flickVelocity = 1.0,
    this.backgroundColor,
  }) : minScale = 0.92,
       maxRadius = 20,
       slideFactor = 0.35,
       fadeStart = 0.8,
       maxTilt = 0,
       shadow = false,
       dimBelow = false,
       settleCurve = Curves.easeOutBack,
       closeCurve = Curves.easeOutCubic,
       settleDuration = const Duration(milliseconds: 300);

  /// More zoom, a stronger tilt, shadow and dimming.
  const OmniSwipeBackStyle.dramatic({
    this.edgeWidth = 28,
    this.edges = const {OmniSwipeEdge.left, OmniSwipeEdge.right},
    this.closeThreshold = 0.5,
    this.flickVelocity = 1.0,
    this.backgroundColor,
  }) : minScale = 0.68,
       maxRadius = 36,
       slideFactor = 0.5,
       fadeStart = 0.7,
       maxTilt = 0.35,
       shadow = true,
       dimBelow = true,
       settleCurve = Curves.easeOutBack,
       closeCurve = Curves.easeOutCubic,
       settleDuration = const Duration(milliseconds: 320);

  /// Page scale at a full drag (per-mode default when null).
  final double? minScale;

  /// Largest corner radius in logical pixels (per-mode default when null).
  final double? maxRadius;

  /// How far the page moves, as a fraction of the drag distance (per-mode
  /// default when null).
  final double? slideFactor;

  /// Progress after which the page fades out (per-mode default when null).
  final double? fadeStart;

  /// [OmniSwipeBack.zoomTilt]: largest turn in radians. Keep it small so
  /// text never mirrors.
  final double maxTilt;

  /// Shadow around the moving page (default on for `slide` and `zoomCard`).
  final bool? shadow;

  /// Dim the page below until it is revealed (default on for `zoomCard`).
  final bool? dimBelow;

  /// Painted behind a zooming page below (`zoomParallax`); defaults to the
  /// theme's `scaffoldBackgroundColor`.
  final Color? backgroundColor;

  /// Width of the edge strip a swipe starts in (the safe-area inset is used
  /// when larger).
  final double edgeWidth;

  /// Edges a swipe may start from.
  final Set<OmniSwipeEdge> edges;

  /// Release past this fraction of the screen width closes the page.
  final double closeThreshold;

  /// A flick faster than this (screen widths per second) toward closing
  /// closes the page even under [closeThreshold].
  final double flickVelocity;

  /// Curve used to spring back when the page is not closed.
  final Curve settleCurve;

  /// Curve used to finish closing.
  final Curve closeCurve;

  /// Time to settle from a full drag; shorter for smaller distances.
  final Duration settleDuration;
}

/// A custom-transition [Page] backing `OmniPages.transition`/`custom`; adds
/// an optional swipe-back layer on top of [transitionsBuilder].
class OmniSwipeBackPage<T> extends Page<T> {
  /// Creates a transition page with optional edge swipe-back behaviour
  /// (`null` swipe settings inherit the [OmniApp] defaults).
  const OmniSwipeBackPage({
    required this.child,
    required this.transitionsBuilder,
    this.transitionDuration = const Duration(milliseconds: 250),
    this.reverseTransitionDuration = const Duration(milliseconds: 200),
    this.maintainState = true,
    this.fullscreenDialog = false,
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.barrierLabel,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    this.swipeBack,
    this.swipeBackStyle,
  });

  /// Screen widget displayed inside this page.
  final Widget child;

  /// Forward open transition duration.
  final Duration transitionDuration;

  /// Reverse pop transition duration.
  final Duration reverseTransitionDuration;

  /// Whether the route preserves state when inactive.
  final bool maintainState;

  /// Whether this page acts as a full-screen modal dialog.
  final bool fullscreenDialog;

  /// Whether this route obscures routes underneath it.
  final bool opaque;

  /// Whether tapping the barrier dismisses this route.
  final bool barrierDismissible;

  /// Color of the modal barrier when [opaque] is `false`.
  final Color? barrierColor;

  /// Semantic label for the barrier.
  final String? barrierLabel;

  /// Builds the transition widget around [child].
  final RouteTransitionsBuilder transitionsBuilder;

  /// Swipe style for this page; null uses the app default.
  final OmniSwipeBack? swipeBack;

  /// Swipe tuning for this page; null uses the app default.
  final OmniSwipeBackStyle? swipeBackStyle;

  @override
  Route<T> createRoute(BuildContext context) => _OmniSwipeBackRoute<T>(this);
}

/// App-wide swipe-back defaults (provided by `OmniApp`).
@internal
class OmniSwipeBackDefaults extends InheritedWidget {
  /// Provides [mode] and [style] to the pages below.
  const OmniSwipeBackDefaults({
    super.key,
    required this.mode,
    required this.style,
    this.predictiveBack = false,
    required super.child,
  });

  /// Default swipe style.
  final OmniSwipeBack mode;

  /// Default tuning.
  final OmniSwipeBackStyle style;

  /// Follow Android's system back gesture (predictive back).
  final bool predictiveBack;

  /// The nearest defaults, or "off".
  static (OmniSwipeBack, OmniSwipeBackStyle, bool) of(BuildContext context) {
    final d = context
        .dependOnInheritedWidgetOfExactType<OmniSwipeBackDefaults>();
    return (
      d?.mode ?? OmniSwipeBack.none,
      d?.style ?? const OmniSwipeBackStyle(),
      d?.predictiveBack ?? false,
    );
  }

  /// Whether predictive back is on, read without subscribing.
  static bool predictiveBackOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<OmniSwipeBackDefaults>()
          ?.predictiveBack ??
      false;

  @override
  bool updateShouldNotify(OmniSwipeBackDefaults old) =>
      old.mode != mode ||
      old.style != style ||
      old.predictiveBack != predictiveBack;
}

/// Resolved visual values for one swipe.
class _Look {
  _Look(this.mode, OmniSwipeBackStyle s)
    : minScale = s.minScale ?? _scale[mode]!,
      maxRadius = s.maxRadius ?? (mode == OmniSwipeBack.zoomCenter ? 32 : 28),
      slideFactor = s.slideFactor ?? _slide[mode]!,
      fadeStart =
          s.fadeStart ?? (mode == OmniSwipeBack.zoomCenter ? 0.5 : 0.75),
      maxTilt = mode == OmniSwipeBack.zoomTilt ? s.maxTilt : 0,
      shadow =
          s.shadow ??
          (mode == OmniSwipeBack.slide || mode == OmniSwipeBack.zoomCard),
      dimBelow = s.dimBelow ?? mode == OmniSwipeBack.zoomCard,
      backgroundColor = s.backgroundColor;

  static const _scale = {
    OmniSwipeBack.slide: 1.0,
    OmniSwipeBack.zoom: 0.82,
    OmniSwipeBack.zoomCenter: 0.75,
    OmniSwipeBack.zoomToEdge: 0.7,
    OmniSwipeBack.zoomFollow: 0.8,
    OmniSwipeBack.zoomCard: 0.85,
    OmniSwipeBack.zoomParallax: 0.82,
    OmniSwipeBack.zoomTilt: 0.82,
  };
  static const _slide = {
    OmniSwipeBack.slide: 1.0,
    OmniSwipeBack.zoom: 0.45,
    OmniSwipeBack.zoomCenter: 0.0,
    OmniSwipeBack.zoomToEdge: 0.25,
    OmniSwipeBack.zoomFollow: 0.6,
    OmniSwipeBack.zoomCard: 0.45,
    OmniSwipeBack.zoomParallax: 0.45,
    OmniSwipeBack.zoomTilt: 0.45,
  };

  final OmniSwipeBack mode;
  final double minScale, maxRadius, slideFactor, fadeStart, maxTilt;
  final bool shadow, dimBelow;
  final Color? backgroundColor;
}

/// The swipe in progress on a navigator, so the page below can react.
class _ActiveSwipe {
  _ActiveSwipe(this.look, this.side);
  final _Look look;
  final double side;
}

final Expando<_ActiveSwipe> _activeSwipes = Expando('OmniSwipeBack');

class _OmniSwipeBackRoute<T> extends PageRoute<T> {
  _OmniSwipeBackRoute(OmniSwipeBackPage<T> page) : super(settings: page);

  OmniSwipeBackPage<T> get _page => settings as OmniSwipeBackPage<T>;

  @override
  bool get barrierDismissible => _page.barrierDismissible;
  @override
  Color? get barrierColor => _page.barrierColor;
  @override
  String? get barrierLabel => _page.barrierLabel;
  @override
  Duration get transitionDuration => _page.transitionDuration;
  @override
  Duration get reverseTransitionDuration => _page.reverseTransitionDuration;
  @override
  bool get maintainState => _page.maintainState;
  @override
  bool get fullscreenDialog => _page.fullscreenDialog;
  @override
  bool get opaque => _page.opaque;

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
  ) {
    final (appMode, appStyle, predictive) = OmniSwipeBackDefaults.of(context);
    final mode = _page.swipeBack ?? appMode;
    // Android's system back gesture uses this page's style (zoom when the
    // in-app swipe is off). An explicit `swipeBack: none` on the page turns
    // both off.
    final predictiveMode = predictive && _page.swipeBack != OmniSwipeBack.none
        ? (mode == OmniSwipeBack.none ? OmniSwipeBack.zoom : mode)
        : null;
    // Swipe-back off everywhere: exactly the plain transition.
    if (mode == OmniSwipeBack.none &&
        appMode == OmniSwipeBack.none &&
        predictiveMode == null) {
      return _page.transitionsBuilder(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return _SwipeBackLayer(
      route: this,
      mode: mode,
      predictiveMode: predictiveMode,
      style: _page.swipeBackStyle ?? appStyle,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }

  /// Same rules as Flutter's Cupertino back gesture.
  bool get swipeEnabled {
    final nav = navigator;
    return nav != null &&
        isActive &&
        isCurrent &&
        !isFirst &&
        !willHandlePopInternally &&
        popDisposition == RoutePopDisposition.pop &&
        !fullscreenDialog &&
        animation!.status == AnimationStatus.completed &&
        secondaryAnimation!.status == AnimationStatus.dismissed &&
        !nav.userGestureInProgress;
  }

  AnimationController get swipeController => controller!;

  /// Pops through OmniRouter when it owns this page, so its state, the
  /// OmniRoute stack, logs and lifecycle hooks stay correct.
  void swipePop(BuildContext context) {
    final router = OmniRouter.maybeOf(context);
    if (router != null && router.state.pageKey == _page.key) {
      router.pop<Object?>();
    } else {
      navigator?.pop();
    }
  }
}

class _SwipeBackLayer extends StatefulWidget {
  const _SwipeBackLayer({
    required this.route,
    required this.mode,
    required this.predictiveMode,
    required this.style,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final _OmniSwipeBackRoute<dynamic> route;

  /// In-app edge swipe style (none = no edge strips).
  final OmniSwipeBack mode;

  /// Style for Android's system back gesture, or null to ignore it.
  final OmniSwipeBack? predictiveMode;
  final OmniSwipeBackStyle style;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_SwipeBackLayer> createState() => _SwipeBackLayerState();
}

class _SwipeBackLayerState extends State<_SwipeBackLayer>
    with WidgetsBindingObserver {
  late final HorizontalDragGestureRecognizer _drag =
      HorizontalDragGestureRecognizer(debugOwner: this)
        // The page follows the finger from where it touched down.
        ..dragStartBehavior = DragStartBehavior.down
        ..onStart = _onStart
        ..onUpdate = _onUpdate
        ..onEnd = _onEnd
        ..onCancel = _onCancel;

  // Keeps the page's state when the swipe wrappers are added or removed, so
  // an idle page has no extra widgets.
  final GlobalKey _pageKey = GlobalKey();

  /// This page is being swiped (from drag start until it settles).
  _ActiveSwipe? _swipe;
  NavigatorState? _navigator;
  double _side = 1;
  double _width = 1;
  Alignment _focal = Alignment.center;

  @override
  void initState() {
    super.initState();
    if (widget.predictiveMode != null) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didUpdateWidget(_SwipeBackLayer old) {
    super.didUpdateWidget(old);
    final was = old.predictiveMode != null;
    final now = widget.predictiveMode != null;
    if (was && !now) WidgetsBinding.instance.removeObserver(this);
    if (!was && now) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drag.dispose();
    _finishGesture(rebuild: false);
    super.dispose();
  }

  // ── Android predictive back ─────────────────────────────────────────
  // The binding hands the gesture to every observer that accepts it, so
  // only the page on top of everything (OmniRouter's top page, in a visible
  // tab) accepts. A button press (`isButtonEvent`) is left to the normal
  // `handlePopRoute`, which pops as usual.

  bool _isTopPage() {
    if (!widget.route.swipeEnabled || !TickerMode.valuesOf(context).enabled) {
      return false;
    }
    final router = OmniRouter.maybeOf(context);
    return router == null || router.state.pageKey == widget.route._page.key;
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final mode = widget.predictiveMode;
    if (mode == null || backEvent.isButtonEvent || _navigator != null) {
      return false;
    }
    if (!_isTopPage()) return false;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    _side = backEvent.swipeEdge == SwipeEdge.left ? 1.0 : -1.0;
    _width = box.size.width;
    final touch = backEvent.touchOffset;
    if (touch != null) _setFocal(box, touch);
    _begin(mode);
    widget.route.swipeController.value = 1 - backEvent.progress;
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (_navigator == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final touch = backEvent.touchOffset;
    if (box != null && box.hasSize && touch != null) _setFocal(box, touch);
    widget.route.swipeController.value = (1 - backEvent.progress).clamp(
      0.0,
      1.0,
    );
  }

  @override
  void handleCommitBackGesture() {
    if (_navigator != null) _close();
  }

  @override
  void handleCancelBackGesture() {
    if (_navigator != null) _settle();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (widget.mode == OmniSwipeBack.none || !widget.route.swipeEnabled) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final x = box.globalToLocal(e.position).dx;
    final padding = MediaQuery.paddingOf(context);
    final s = widget.style;
    final OmniSwipeEdge edge;
    if (s.edges.contains(OmniSwipeEdge.left) &&
        x <= math.max(s.edgeWidth, padding.left)) {
      edge = OmniSwipeEdge.left;
    } else if (s.edges.contains(OmniSwipeEdge.right) &&
        x >= box.size.width - math.max(s.edgeWidth, padding.right)) {
      edge = OmniSwipeEdge.right;
    } else {
      return;
    }
    // Closing always moves inward from the starting edge, in LTR and RTL.
    _side = edge == OmniSwipeEdge.left ? 1.0 : -1.0;
    _width = box.size.width;
    _setFocal(box, e.position);
    _drag.addPointer(e);
  }

  void _setFocal(RenderBox box, Offset global) {
    final local = box.globalToLocal(global);
    _focal = Alignment(
      (local.dx / box.size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / box.size.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  void _onStart(DragStartDetails _) {
    if (!widget.route.swipeEnabled) return;
    _begin(widget.mode);
  }

  /// Starts a swipe (edge drag or system back gesture) in [style].
  void _begin(OmniSwipeBack style) {
    final nav = widget.route.navigator!..didStartUserGesture();
    _navigator = nav;
    final mode = MediaQuery.disableAnimationsOf(context)
        ? OmniSwipeBack.slide
        : style;
    final swipe = _ActiveSwipe(_Look(mode, widget.style), _side);
    _activeSwipes[nav] = swipe;
    setState(() => _swipe = swipe);
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_navigator == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) _setFocal(box, d.globalPosition);
    final c = widget.route.swipeController;
    final progress = (1 - c.value + _side * d.primaryDelta! / _width).clamp(
      0.0,
      1.0,
    );
    c.value = 1 - progress;
  }

  void _onEnd(DragEndDetails d) {
    if (_navigator == null) return;
    final s = widget.style;
    final c = widget.route.swipeController;
    final progress = 1 - c.value;
    final velocity = _side * d.velocity.pixelsPerSecond.dx / _width;
    final close =
        progress > 0 &&
        (velocity >= s.flickVelocity ||
            (progress > s.closeThreshold && velocity > -s.flickVelocity));
    if (close) {
      _close();
    } else {
      _settle();
    }
  }

  /// Closes the page from where the gesture left it (shared by the edge
  /// swipe and the system back gesture).
  void _close() {
    final s = widget.style;
    final c = widget.route.swipeController;
    final ms = math.max(
      80,
      (s.settleDuration.inMilliseconds * c.value).round(),
    );
    widget.route.swipePop(context);
    // pop() starts the normal reverse animation; continue from where the
    // finger left instead.
    c
        .animateBack(
          0,
          duration: Duration(milliseconds: ms),
          curve: s.closeCurve,
        )
        .whenCompleteOrCancel(_finishGesture);
  }

  void _onCancel() {
    if (_navigator == null) return;
    _settle();
  }

  /// Springs the page back open.
  void _settle() {
    final s = widget.style;
    final c = widget.route.swipeController;
    final ms = math.max(
      80,
      (s.settleDuration.inMilliseconds * (1 - c.value)).round(),
    );
    c
        .animateTo(
          1,
          duration: Duration(milliseconds: ms),
          curve: s.settleCurve,
        )
        .whenCompleteOrCancel(_finishGesture);
  }

  void _finishGesture({bool rebuild = true}) {
    final nav = _navigator;
    if (nav == null) return;
    _navigator = null;
    if (identical(_activeSwipes[nav], _swipe)) _activeSwipes[nav] = null;
    nav.didStopUserGesture();
    if (rebuild && mounted) {
      setState(() => _swipe = null);
    } else {
      _swipe = null;
    }
  }

  /// The swipe on the page directly above this one, if any.
  _ActiveSwipe? _swipeAbove() {
    if (_swipe != null) return null;
    final nav = widget.route.navigator;
    if (nav == null || !nav.userGestureInProgress) return null;
    if (widget.secondaryAnimation.isDismissed) return null;
    return _activeSwipes[nav];
  }

  @override
  Widget build(BuildContext context) {
    final nav = widget.route.navigator;
    if (nav == null) return _build(context);
    // Rebuild when a swipe starts or ends on the page above.
    return ValueListenableBuilder<bool>(
      valueListenable: nav.userGestureInProgressNotifier,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final page = widget.route._page;
    final above = _swipeAbove();
    final swipe = _swipe;
    final transitioned = KeyedSubtree(
      key: _pageKey,
      child: page.transitionsBuilder(
        context,
        // While swiping, the page's own transition is held still and the
        // swipe visuals take over.
        swipe != null ? kAlwaysCompleteAnimation : widget.animation,
        above != null ? kAlwaysDismissedAnimation : widget.secondaryAnimation,
        widget.child,
      ),
    );

    Widget body;
    if (swipe != null) {
      body = AnimatedBuilder(
        animation: widget.animation,
        child: RepaintBoundary(child: transitioned),
        builder: (context, child) =>
            _top(swipe, 1 - widget.animation.value, child!),
      );
    } else if (above != null && _belowChanges(above.look)) {
      body = AnimatedBuilder(
        animation: widget.secondaryAnimation,
        child: RepaintBoundary(child: transitioned),
        builder: (context, child) =>
            _below(above, 1 - widget.secondaryAnimation.value, child!),
      );
    } else {
      body = transitioned;
    }
    if (widget.mode == OmniSwipeBack.none) return body;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: body,
    );
  }

  static bool _belowChanges(_Look l) =>
      l.mode == OmniSwipeBack.slide || l.mode == OmniSwipeBack.zoomParallax;

  /// The page being swiped, at progress [p].
  Widget _top(_ActiveSwipe s, double p, Widget child) {
    final l = s.look;
    final side = s.side;
    final scale = lerpDouble(1, l.minScale, p)!;
    final dx = side * p * _width * l.slideFactor;
    final radius = l.mode == OmniSwipeBack.slide
        ? 0.0
        : math.min(p * 120, l.maxRadius);
    final opacity = p <= l.fadeStart
        ? 1.0
        : (1 - (p - l.fadeStart) / (1 - l.fadeStart)).clamp(0.0, 1.0);
    final alignment = switch (l.mode) {
      OmniSwipeBack.zoomToEdge =>
        side > 0 ? Alignment.centerRight : Alignment.centerLeft,
      OmniSwipeBack.zoomFollow => _focal,
      _ => Alignment.center,
    };
    final transform = Matrix4.translationValues(dx, 0, 0);
    if (l.maxTilt > 0) {
      transform
        ..setEntry(3, 2, 0.0012)
        ..rotateY(side * p * l.maxTilt);
    }
    if (scale != 1) transform.scaleByDouble(scale, scale, 1, 1);

    // The tree shape stays fixed for the whole swipe: adding or removing a
    // wrapper mid-gesture would reparent the page's GlobalKey subtree (a
    // deactivate/activate + relayout), which shows up as a dropped frame.
    // Opacity at 1.0 and ClipRRect with Clip.none paint without a layer.
    Widget page = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: radius > 0 ? Clip.antiAlias : Clip.none,
      child: child,
    );
    final slide = l.mode == OmniSwipeBack.slide;
    page = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: l.shadow && p > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: slide ? 0.18 * (1 - p) : 0.35 * p,
                  ),
                  blurRadius: slide ? 16 : 30,
                ),
              ]
            : null,
      ),
      child: page,
    );
    page = Transform(transform: transform, alignment: alignment, child: page);
    page = Opacity(opacity: opacity, child: page);
    if (l.dimBelow) {
      // Behind the moving page and over the page below.
      page = Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.25 * (1 - p)),
            ),
          ),
          page,
        ],
      );
    }
    return page;
  }

  /// The page below a swipe, at progress [p] of the swipe above.
  Widget _below(_ActiveSwipe s, double p, Widget child) {
    final l = s.look;
    if (l.mode == OmniSwipeBack.slide) {
      final box = context.findRenderObject() as RenderBox?;
      final width = box != null && box.hasSize
          ? box.size.width
          : MediaQuery.sizeOf(context).width;
      return Transform.translate(
        offset: Offset(-s.side * 0.3 * (1 - p) * width, 0),
        child: child,
      );
    }
    // zoomParallax: grow 0.94 → 1 over a background, never black edges.
    final bg = l.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    return ColoredBox(
      color: bg,
      child: Transform.scale(scale: lerpDouble(0.94, 1, p)!, child: child),
    );
  }
}
