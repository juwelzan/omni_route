// Named constructor parameters stay public names; the fields are private.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../omni_colors.dart';

/// Look and feel of an Omni bottom sheet.
enum OmniSheetStyle {
  /// [cupertino] on iOS and macOS, [material] everywhere else (default).
  adaptive,

  /// Material 3: 28dp top corners, drag handle, quick critically-damped
  /// motion, no stretch past the top.
  material,

  /// iOS: grabber, spring motion, rubber-band stretch past the top, the
  /// status bar area left visible above the largest detent.
  cupertino,

  /// A rounded card floating above the bottom edge, with margins and a
  /// shadow, using the iOS motion.
  floating;

  /// The concrete style for [platform] ([adaptive] resolved).
  OmniSheetStyle resolve(TargetPlatform platform) => switch (this) {
    adaptive => switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => cupertino,
      _ => material,
    },
    _ => this,
  };
}

/// A resting height of a sheet: it snaps to the nearest one when released.
@immutable
class OmniSheetDetent {
  /// A share of the available height (`0 < fraction <= 1`).
  const OmniSheetDetent.fraction(double this.fraction)
    : assert(fraction > 0 && fraction <= 1),
      height = null;

  /// A fixed height in logical pixels (capped by the available height).
  const OmniSheetDetent.height(double this.height)
    : assert(height > 0),
      fraction = null;

  const OmniSheetDetent._content() : fraction = null, height = null;

  /// As tall as the content (capped by the available height). Use it on its
  /// own, not together with other detents.
  static const OmniSheetDetent content = OmniSheetDetent._content();

  /// Half of the available height.
  static const OmniSheetDetent medium = OmniSheetDetent.fraction(0.5);

  /// All of the available height.
  static const OmniSheetDetent large = OmniSheetDetent.fraction(1);

  /// The share of the available height, or `null`.
  final double? fraction;

  /// The fixed height, or `null`.
  final double? height;

  bool get _isContent => fraction == null && height == null;

  double _resolve(double available) =>
      height != null ? math.min(height!, available) : available * fraction!;

  @override
  bool operator ==(Object other) =>
      other is OmniSheetDetent &&
      other.fraction == fraction &&
      other.height == height;

  @override
  int get hashCode => Object.hash(fraction, height);
}

/// How a sheet moves: a spring described the way iOS and SwiftUI do, by
/// [response] (seconds for one oscillation) and [dampingRatio] (`1` = no
/// bounce).
@immutable
class OmniSheetMotion {
  /// Creates a motion.
  const OmniSheetMotion({
    this.response = 0.42,
    this.dampingRatio = 1.0,
    this.rubberBand = true,
    this.dismissVelocity = 900,
  }) : assert(response > 0),
       assert(dampingRatio > 0);

  /// iOS sheet presentation: smooth, no bounce, stretches past the top.
  static const OmniSheetMotion ios = OmniSheetMotion(response: 0.45);

  /// Material 3: quicker, no bounce, stops hard at the top.
  static const OmniSheetMotion material = OmniSheetMotion(
    response: 0.34,
    rubberBand: false,
  );

  /// Fast and crisp.
  static const OmniSheetMotion snappy = OmniSheetMotion(response: 0.28);

  /// A soft overshoot when settling on a detent.
  static const OmniSheetMotion bouncy = OmniSheetMotion(
    response: 0.5,
    dampingRatio: 0.78,
  );

  /// Seconds for one oscillation; smaller is faster.
  final double response;

  /// `1` settles without overshoot, below `1` bounces.
  final double dampingRatio;

  /// Stretches with resistance when pulled past the largest detent (or below
  /// the smallest one when the sheet can't be dismissed).
  final bool rubberBand;

  /// A downward fling faster than this (logical px/s) dismisses the sheet.
  final double dismissVelocity;

  /// The [SpringDescription] of this motion.
  SpringDescription get spring {
    final omega = 2 * math.pi / response;
    return SpringDescription(
      mass: 1,
      stiffness: omega * omega,
      damping: 2 * dampingRatio * omega,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OmniSheetMotion &&
      other.response == response &&
      other.dampingRatio == dampingRatio &&
      other.rubberBand == rubberBand &&
      other.dismissVelocity == dismissVelocity;

  @override
  int get hashCode =>
      Object.hash(response, dampingRatio, rubberBand, dismissVelocity);
}

/// Controls the sheet a widget is in; get it with [OmniSheet.of].
abstract interface class OmniSheetController {
  /// Index of the detent the sheet rests on (or is moving to).
  ValueListenable<int> get detent;

  /// How many detents the sheet has.
  int get detentCount;

  /// The resolved style ([OmniSheetStyle.adaptive] is never returned).
  OmniSheetStyle get style;

  /// The controller that lets a scroll view inside drag the sheet. Scroll
  /// views pick it up on their own on iOS and Android
  /// (`PrimaryScrollController`); pass it explicitly on desktop.
  ScrollController get scrollController;

  /// Animates to the detent at [index].
  Future<void> snapTo(int index);

  /// Closes the sheet, completing `showOmniBottomSheet` with [result].
  void close([Object? result]);
}

/// Access to the sheet around a widget.
abstract final class OmniSheet {
  /// The sheet around [context]; throws outside one.
  static OmniSheetController of(BuildContext context) =>
      maybeOf(context) ??
      (throw FlutterError(
        'OmniSheet.of() called with a context that is not inside an Omni '
        'bottom sheet.',
      ));

  /// The sheet around [context], or `null`.
  static OmniSheetController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_OmniSheetScope>()?.controller;
}

/// Shows a modal bottom sheet in one of the [OmniSheetStyle]s.
///
/// ```dart
/// final picked = await showOmniBottomSheet<String>(
///   context: context,
///   detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
///   builder: (context) => ListView(children: [...]),
/// );
/// ```
///
/// - Drag it, fling it or drag a scroll view inside it: the sheet follows
///   the finger, snaps to the nearest [detents] and dismisses when pulled
///   down far or fast enough.
/// - A `PopScope` inside the sheet can block dismissal; the sheet then
///   springs back.
/// - Colors come from the Omni theme (`bottomSheetColor`, `overlayColor`),
///   the Material theme, or the Cupertino system colors in a `CupertinoApp`.
/// - Opening, closing and dragging only repaint: the content is built once.
///
/// [isDismissible] covers both the barrier tap and dragging down;
/// [enableDrag] turns all dragging off. Everything else (colors, corner
/// radius, margin, width, shadow, handle, [motion]) is optional and
/// defaults per [style].
Future<T?> showOmniBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  OmniSheetStyle style = OmniSheetStyle.adaptive,
  List<OmniSheetDetent> detents = const [OmniSheetDetent.content],
  int initialDetent = 0,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showHandle,
  Color? backgroundColor,
  Color? handleColor,
  Color? barrierColor,
  double? cornerRadius,
  EdgeInsets? margin,
  double? maxWidth,
  List<BoxShadow>? shadow,
  OmniSheetMotion? motion,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  String? semanticLabel,
  RouteSettings? settings,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final resolved = style.resolve(_platformOf(context));
  return navigator.push(
    OmniSheetRoute<T>(
      builder: builder,
      style: resolved,
      detents: detents,
      initialDetent: initialDetent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showHandle: showHandle,
      backgroundColor: backgroundColor,
      handleColor: handleColor,
      barrierColor: barrierColor ?? _defaultBarrierColor(context, resolved),
      cornerRadius: cornerRadius,
      margin: margin,
      maxWidth: maxWidth,
      shadow: shadow,
      motion: motion,
      useSafeArea: useSafeArea,
      semanticLabel: semanticLabel,
      barrierLabel: _localizations(context)?.modalBarrierDismissLabel,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      settings: settings,
    ),
  );
}

/// The route behind [showOmniBottomSheet]; push it yourself to use a
/// specific navigator or route settings.
class OmniSheetRoute<T> extends PopupRoute<T> {
  /// Creates the route. See [showOmniBottomSheet] for the parameters.
  OmniSheetRoute({
    required this.builder,
    this.style = OmniSheetStyle.adaptive,
    this.detents = const [OmniSheetDetent.content],
    this.initialDetent = 0,
    this.isDismissible = true,
    this.enableDrag = true,
    this.showHandle,
    this.backgroundColor,
    this.handleColor,
    Color? barrierColor,
    this.cornerRadius,
    this.margin,
    this.maxWidth,
    this.shadow,
    this.motion,
    this.useSafeArea = true,
    this.semanticLabel,
    String? barrierLabel,
    this.capturedThemes,
    super.settings,
  }) : assert(detents.isNotEmpty, 'A sheet needs at least one detent.'),
       assert(
         detents.length == 1 || !detents.any((d) => d._isContent),
         'OmniSheetDetent.content can only be used on its own.',
       ),
       assert(initialDetent >= 0 && initialDetent < detents.length),
       _barrierColor = barrierColor,
       _barrierLabel = barrierLabel;

  /// Builds the sheet's content.
  final WidgetBuilder builder;

  /// Look and motion preset.
  final OmniSheetStyle style;

  /// Resting heights, any order.
  final List<OmniSheetDetent> detents;

  /// Index into [detents] (in the given order) the sheet opens at.
  final int initialDetent;

  /// Whether a barrier tap or a drag down closes the sheet.
  final bool isDismissible;

  /// Whether the sheet (and scroll views in it) can be dragged.
  final bool enableDrag;

  /// Shows the drag handle / grabber (default: when [enableDrag]).
  final bool? showHandle;

  /// Sheet color (default: theme).
  final Color? backgroundColor;

  /// Handle color (default: theme).
  final Color? handleColor;

  /// Corner radius (default per style).
  final double? cornerRadius;

  /// Space around a [OmniSheetStyle.floating] sheet.
  final EdgeInsets? margin;

  /// Widest the sheet gets on tablets and desktops (default 640, floating
  /// 560); it is centered.
  final double? maxWidth;

  /// Shadow (default: floating only).
  final List<BoxShadow>? shadow;

  /// Spring and drag behaviour (default per style).
  final OmniSheetMotion? motion;

  /// Keeps the sheet and its content out of system bars and notches.
  final bool useSafeArea;

  /// Screen reader name of the sheet.
  final String? semanticLabel;

  /// Themes of the context the sheet was opened from.
  final CapturedThemes? capturedThemes;

  final Color? _barrierColor;
  final String? _barrierLabel;

  late OmniSheetStyle _style;
  double? _popVelocity;

  /// The style in effect ([OmniSheetStyle.adaptive] resolved).
  OmniSheetStyle get effectiveStyle => _style;

  /// The motion in effect.
  OmniSheetMotion get effectiveMotion =>
      motion ??
      (_style == OmniSheetStyle.material
          ? OmniSheetMotion.material
          : OmniSheetMotion.ios);

  /// The 0–1 presence animation; dragging writes to it directly.
  AnimationController get _presence => controller!;

  bool get _reduceMotion {
    final nav = navigator;
    return nav != null &&
        (MediaQuery.maybeDisableAnimationsOf(nav.context) ?? false);
  }

  @override
  void install() {
    _style = style.resolve(_platformOf(navigator!.context));
    super.install();
  }

  @override
  Color? get barrierColor => _barrierColor ?? const Color(0x66000000);

  @override
  bool get barrierDismissible => isDismissible;

  @override
  String? get barrierLabel => _barrierLabel ?? 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Curve get barrierCurve => Curves.linear;

  @override
  Simulation? createSimulation({required bool forward}) {
    if (_reduceMotion) return null; // A short fade instead (see the view).
    final velocity = forward ? 0.0 : (_popVelocity ?? 0.0);
    _popVelocity = null;
    return _settlingSpring(
      effectiveMotion.spring,
      _presence.value,
      forward ? 1 : 0,
      velocity,
      tolerance: const Tolerance(distance: 0.0008, velocity: 0.01),
    );
  }

  /// Springs the presence back to fully shown after a partial drag.
  void _settlePresence(double velocity) {
    if (_reduceMotion) {
      _presence.value = 1;
      return;
    }
    _presence.animateWith(
      _settlingSpring(
        effectiveMotion.spring,
        _presence.value,
        1,
        velocity,
        tolerance: const Tolerance(distance: 0.0008, velocity: 0.01),
      ),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final view = _OmniSheetView<T>(route: this);
    return capturedThemes?.wrap(view) ?? view;
  }
}

// ── View ────────────────────────────────────────────────────────────────────

class _OmniSheetView<T> extends StatefulWidget {
  const _OmniSheetView({required this.route});

  final OmniSheetRoute<T> route;

  @override
  State<_OmniSheetView<T>> createState() => _OmniSheetViewState<T>();
}

class _OmniSheetViewState<T> extends State<_OmniSheetView<T>>
    with SingleTickerProviderStateMixin
    implements OmniSheetController {
  late final AnimationController _extent = AnimationController.unbounded(
    vsync: this,
  )..addStatusListener(_onExtentStatus);
  late final _SheetMetrics _metrics = _SheetMetrics(
    index: _sortedInitialIndex(),
  );
  late final ValueNotifier<int> _detent = ValueNotifier(_metrics.index);
  late final _SheetScrollController _scroll = _SheetScrollController(this);

  // Content built once; the sheet's own rebuilds (keyboard, rotation) reuse
  // it, so dragging and animating never rebuild what the developer wrote.
  Widget? _content;
  bool _cupertinoApp = false;

  // Finger position in sheet terms (px of visible sheet), unclamped.
  double _raw = 0;
  bool _dragging = false;

  OmniSheetRoute<T> get _route => widget.route;
  OmniSheetMotion get _motion => _route.effectiveMotion;
  bool get _contentSized => _route.detents.first._isContent;

  int _sortedInitialIndex() {
    final initial = _route.detents[_route.initialDetent];
    if (initial._isContent) return 0;
    // Heights are sorted ascending; fractions sort before or among fixed
    // heights depending on the screen, so match after the first layout.
    return _route.initialDetent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cupertinoApp =
        Theme.of(context).extension<OmniColors>() == null &&
        context.findAncestorWidgetOfExactType<CupertinoApp>() != null;
  }

  @override
  void dispose() {
    _extent.dispose();
    _detent.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onExtentStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_dragging) {
      _metrics.settled = true;
    }
  }

  // ── OmniSheetController ───────────────────────────────────────────────────

  @override
  ValueListenable<int> get detent => _detent;

  @override
  int get detentCount => _route.detents.length;

  @override
  OmniSheetStyle get style => _route.effectiveStyle;

  @override
  ScrollController get scrollController => _scroll;

  @override
  Future<void> snapTo(int index) => _snap(index, 0);

  @override
  void close([Object? result]) {
    final nav = _route.navigator;
    if (nav == null || !_route.isActive) return;
    if (_route.isCurrent) {
      nav.pop<T>(result as T?);
    } else {
      nav.removeRoute(_route, result as T?);
    }
  }

  // ── Gestures ──────────────────────────────────────────────────────────────

  List<double> get _heights => _metrics.heights;

  void _dragStart() {
    if (_heights.isEmpty) return;
    _dragging = true;
    _metrics.settled = false;
    _extent.stop();
    _route._presence.stop();
    final presence = _route._presence.value;
    final min = _heights.first, max = _heights.last;
    if (presence < 1) {
      _raw = _route.isDismissible
          ? presence * min
          : min - _rubberInverse((1 - presence) * min, min);
    } else if (_extent.value > max) {
      _raw = max + _rubberInverse(_extent.value - max, _available);
    } else {
      _raw = _extent.value;
    }
  }

  /// [delta] > 0 is the finger moving down.
  void _dragUpdate(double delta) {
    if (!_dragging) _dragStart();
    if (_heights.isEmpty) return;
    _raw -= delta;
    final min = _heights.first, max = _heights.last;
    double extent;
    var presence = 1.0;
    if (_raw >= max) {
      extent = _motion.rubberBand ? max + _rubber(_raw - max, _available) : max;
      if (!_motion.rubberBand) _raw = max;
    } else if (_raw >= min) {
      extent = _raw;
    } else {
      extent = min;
      presence = _route.isDismissible
          ? (_raw / min).clamp(0.001, 1.0)
          : 1 - _rubber(min - _raw, min) / min;
    }
    if (_extent.value != extent) _extent.value = extent;
    if (_route._presence.value != presence) _route._presence.value = presence;
  }

  /// [velocity] > 0 is a downward fling (px/s).
  void _dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    if (_heights.isEmpty) return;
    final min = _heights.first;
    final projected = _raw - velocity * 0.25;
    final dismissible = _route.isDismissible;

    if (_route._presence.value < 1) {
      if (dismissible &&
          (velocity > _motion.dismissVelocity || projected < min / 2)) {
        _dismiss(velocity);
      } else {
        _route._settlePresence(-velocity / min);
        _snap(_metrics.index, 0);
      }
      return;
    }

    var target = 0;
    var best = double.infinity;
    for (var i = 0; i < _heights.length; i++) {
      final d = (_heights[i] - projected).abs();
      if (d < best) {
        best = d;
        target = i;
      }
    }
    if (dismissible &&
        target == 0 &&
        (velocity > _motion.dismissVelocity * 1.6 || projected < min / 2)) {
      _dismiss(velocity);
      return;
    }
    _snap(target, -velocity);
  }

  Future<void> _dismiss(double velocity) async {
    final base = math.max(_extent.value, 1.0);
    _route._popVelocity = -velocity / base;
    await _route.navigator?.maybePop<T>();
    // Blocked by a PopScope (or a guard): spring back.
    if (mounted && _route.isActive && _route.isCurrent) {
      _route._popVelocity = null;
      _route._settlePresence(0);
      _snap(_metrics.index, 0);
    }
  }

  TickerFuture _snap(int index, double velocity) {
    if (_heights.isEmpty) return TickerFuture.complete();
    final i = index.clamp(0, _heights.length - 1);
    _metrics.index = i;
    _detent.value = i;
    _metrics.settled = false;
    final target = _heights[i];
    if (_route._reduceMotion) {
      _extent.value = target;
      _metrics.settled = true;
      return TickerFuture.complete();
    }
    return _extent.animateWith(
      _settlingSpring(
        _motion.spring,
        _extent.value,
        target,
        velocity,
        tolerance: const Tolerance(distance: 0.4, velocity: 4),
      ),
    );
  }

  void _cycleDetent() {
    if (detentCount > 1) {
      _snap((_metrics.index + 1) % _heights.length, 0);
    } else if (_route.isDismissible) {
      close();
    }
  }

  /// Whether a scroll view inside should move the sheet instead of its
  /// content for a drag of [delta] (> 0 = finger down).
  bool _takesScroll(double delta, ScrollPosition position) {
    if (!_route.enableDrag || _heights.isEmpty) return false;
    if (_dragging) {
      // Keep the sheet until it is fully expanded again.
      return delta > 0 || _route._presence.value < 1 || _raw < _heights.last;
    }
    if (delta > 0) return position.pixels <= position.minScrollExtent;
    return _route._presence.value < 1 || _extent.value < _heights.last - 0.5;
  }

  // ── Layout values ─────────────────────────────────────────────────────────

  double _available = 0;

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final style = route.effectiveStyle;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final fadeOnly = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final safe = route.useSafeArea;
    final floating = style == OmniSheetStyle.floating;
    final margin = floating
        ? (route.margin ?? const EdgeInsets.all(10))
        : EdgeInsets.zero;

    final topGap = switch (style) {
      OmniSheetStyle.cupertino => (safe ? padding.top : 0) + 10,
      OmniSheetStyle.floating => (safe ? padding.top : 0) + margin.top,
      _ => safe ? padding.top : 0,
    };
    final keyboard = insets.bottom;
    final safeBottom = safe && keyboard == 0 ? padding.bottom : 0.0;
    final bottomGap = floating
        ? keyboard + math.max(margin.bottom, safeBottom + margin.bottom * 0.5)
        : keyboard;
    _available = math.max(0, size.height - topGap - bottomGap);

    final look = _SheetLook.resolve(context, style, route, _cupertinoApp);
    final radius = Radius.circular(
      route.cornerRadius ??
          switch (style) {
            OmniSheetStyle.material => 28,
            OmniSheetStyle.cupertino => 14,
            _ => 28,
          },
    );
    final shape = RoundedRectangleBorder(
      borderRadius: floating
          ? BorderRadius.all(radius)
          : BorderRadius.vertical(top: radius),
    );

    Widget content = _content ??= Builder(builder: route.builder);
    if (look.cupertinoText) {
      content = DefaultTextStyle.merge(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: content,
      );
    }
    content = MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: floating ? 0 : safeBottom),
          child: PrimaryScrollController(controller: _scroll, child: content),
        ),
      ),
    );

    final showHandle = route.showHandle ?? route.enableDrag;
    Widget sheet = Material(
      color: look.background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: _contentSized ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            _SheetHandle(
              style: style,
              color: look.handle,
              hint: _handleHint(context),
              onTap: _cycleDetent,
            ),
          if (_contentSized)
            Flexible(child: content)
          else
            Expanded(child: content),
        ],
      ),
    );
    if (style == OmniSheetStyle.cupertino || floating) {
      sheet = CupertinoUserInterfaceLevel(
        data: CupertinoUserInterfaceLevelData.elevated,
        child: sheet,
      );
    }
    final shadow =
        route.shadow ??
        (floating
            ? const [
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ]
            : null);
    if (shadow != null && shadow.isNotEmpty) {
      sheet = DecoratedBox(
        decoration: ShapeDecoration(shape: shape, shadows: shadow),
        child: sheet,
      );
    }
    if (route.enableDrag) {
      sheet = GestureDetector(
        excludeFromSemantics: true,
        onVerticalDragStart: (_) => _dragStart(),
        onVerticalDragUpdate: (d) => _dragUpdate(d.primaryDelta ?? 0),
        onVerticalDragEnd: (d) => _dragEnd(d.velocity.pixelsPerSecond.dy),
        onVerticalDragCancel: () => _dragEnd(0),
        child: sheet,
      );
    }

    return _OmniSheetScope(
      controller: this,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label:
            route.semanticLabel ??
            _localizations(context)?.bottomSheetLabel ??
            'Sheet',
        child: _SheetLayout(
          presence: route._presence,
          extent: _extent,
          metrics: _metrics,
          detents: route.detents,
          available: _available,
          bottomGap: bottomGap,
          maxWidth: route.maxWidth ?? (floating ? 560 : 640),
          horizontalMargin: math.max(margin.left, margin.right),
          fill: floating ? null : look.background,
          fadeOnly: fadeOnly,
          child: RepaintBoundary(child: sheet),
        ),
      ),
    );
  }

  String _handleHint(BuildContext context) {
    final l = _localizations(context);
    if (detentCount > 1) {
      return _metrics.index < detentCount - 1
          ? (l?.collapsedIconTapHint ?? 'Expand')
          : (l?.expandedIconTapHint ?? 'Collapse');
    }
    return l?.modalBarrierDismissLabel ?? 'Dismiss';
  }
}

class _OmniSheetScope extends InheritedWidget {
  const _OmniSheetScope({required this.controller, required super.child});

  final OmniSheetController controller;

  @override
  bool updateShouldNotify(_OmniSheetScope old) => false;
}

// ── Look ────────────────────────────────────────────────────────────────────

class _SheetLook {
  const _SheetLook(this.background, this.handle, this.cupertinoText);

  final Color background;
  final Color handle;
  final bool cupertinoText;

  static _SheetLook resolve(
    BuildContext context,
    OmniSheetStyle style,
    OmniSheetRoute<dynamic> route,
    bool cupertinoApp,
  ) {
    final omni = Theme.of(context).extension<OmniColors>();
    Color background, handle;
    if (omni != null) {
      background = omni.bottomSheetColor;
      handle = style == OmniSheetStyle.material
          ? omni.borderColor
          : omni.hintTextColor.withValues(alpha: 0.55);
    } else if (cupertinoApp) {
      background = CupertinoDynamicColor.resolve(
        CupertinoColors.systemBackground,
        context,
      );
      handle = CupertinoDynamicColor.resolve(
        CupertinoColors.systemGrey3,
        context,
      );
    } else {
      final theme = Theme.of(context);
      background =
          theme.bottomSheetTheme.modalBackgroundColor ??
          theme.colorScheme.surfaceContainerLow;
      handle =
          theme.bottomSheetTheme.dragHandleColor ??
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    }
    return _SheetLook(
      route.backgroundColor ?? background,
      route.handleColor ?? handle,
      cupertinoApp,
    );
  }
}

Color _defaultBarrierColor(BuildContext context, OmniSheetStyle style) {
  final omni = Theme.of(context).extension<OmniColors>();
  if (omni != null) return omni.overlayColor;
  final themed = Theme.of(context).bottomSheetTheme.modalBarrierColor;
  if (themed != null) return themed;
  return style == OmniSheetStyle.material
      ? Colors.black54
      : const Color(0x66000000);
}

TargetPlatform _platformOf(BuildContext context) => Theme.of(context).platform;

MaterialLocalizations? _localizations(BuildContext context) =>
    Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({
    required this.style,
    required this.color,
    required this.hint,
    required this.onTap,
  });

  final OmniSheetStyle style;
  final Color color;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final material = style == OmniSheetStyle.material;
    final width = material ? 32.0 : 36.0;
    final thickness = material ? 4.0 : 5.0;
    return Semantics(
      button: true,
      label: hint,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: material ? 36 : 20,
          child: Align(
            alignment: material ? Alignment.center : const Alignment(0, -0.4),
            child: Container(
              width: width,
              height: thickness,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(thickness),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scroll hand-off ─────────────────────────────────────────────────────────

class _SheetScrollController extends ScrollController {
  _SheetScrollController(this.sheet);

  final _OmniSheetViewState<dynamic> sheet;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SheetScrollPosition(
    sheet: sheet,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    debugLabel: debugLabel,
  );
}

class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition({
    required this.sheet,
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });

  final _OmniSheetViewState<dynamic> sheet;
  bool _driving = false;

  @override
  void applyUserOffset(double delta) {
    if (sheet._takesScroll(delta, this)) {
      if (!_driving) {
        _driving = true;
        sheet._dragStart();
      }
      sheet._dragUpdate(delta);
      return;
    }
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (_driving) {
      _driving = false;
      final expanded =
          sheet._route._presence.value >= 1 &&
          sheet._raw >= sheet._heights.last;
      if (expanded) {
        // The sheet is fully up: the content keeps its fling.
        sheet._dragEnd(0);
        super.goBallistic(velocity);
      } else {
        sheet._dragEnd(-velocity);
        super.goBallistic(0);
      }
      return;
    }
    super.goBallistic(velocity);
  }

  @override
  void dispose() {
    if (_driving) sheet._dragEnd(0);
    super.dispose();
  }
}

// ── Layout: paint-only movement ─────────────────────────────────────────────

class _SheetMetrics {
  _SheetMetrics({required this.index});

  int index;
  List<double> heights = const [];
  bool ready = false;
  bool settled = true;
}

class _SheetLayout extends SingleChildRenderObjectWidget {
  const _SheetLayout({
    required this.presence,
    required this.extent,
    required this.metrics,
    required this.detents,
    required this.available,
    required this.bottomGap,
    required this.maxWidth,
    required this.horizontalMargin,
    required this.fill,
    required this.fadeOnly,
    super.child,
  });

  final Animation<double> presence;
  final AnimationController extent;
  final _SheetMetrics metrics;
  final List<OmniSheetDetent> detents;
  final double available;
  final double bottomGap;
  final double maxWidth;
  final double horizontalMargin;
  final Color? fill;
  final bool fadeOnly;

  @override
  _RenderSheet createRenderObject(BuildContext context) => _RenderSheet(
    presence: presence,
    extent: extent,
    metrics: metrics,
    detents: detents,
    available: available,
    bottomGap: bottomGap,
    maxWidth: maxWidth,
    horizontalMargin: horizontalMargin,
    fill: fill,
    fadeOnly: fadeOnly,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderSheet renderObject) {
    renderObject
      ..detents = detents
      ..available = available
      ..bottomGap = bottomGap
      ..maxWidth = maxWidth
      ..horizontalMargin = horizontalMargin
      ..fill = fill
      ..fadeOnly = fadeOnly;
  }
}

/// Lays the sheet out once and moves it in paint, so opening, closing and
/// dragging cost a repaint of one layer — never a rebuild or a relayout of
/// the content. Only moving between detents relayouts (the sheet resizes,
/// like on iOS, so bottom-pinned content stays visible).
class _RenderSheet extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderSheet({
    required Animation<double> presence,
    required AnimationController extent,
    required _SheetMetrics metrics,
    required List<OmniSheetDetent> detents,
    required double available,
    required double bottomGap,
    required double maxWidth,
    required double horizontalMargin,
    required Color? fill,
    required bool fadeOnly,
  }) : _presence = presence,
       _extent = extent,
       _metrics = metrics,
       _detents = detents,
       _available = available,
       _bottomGap = bottomGap,
       _maxWidth = maxWidth,
       _horizontalMargin = horizontalMargin,
       _fill = fill,
       _fadeOnly = fadeOnly;

  final Animation<double> _presence;
  final AnimationController _extent;
  final _SheetMetrics _metrics;
  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

  List<OmniSheetDetent> _detents;
  set detents(List<OmniSheetDetent> v) {
    if (listEquals(v, _detents)) return;
    _detents = v;
    markNeedsLayout();
  }

  double _available;
  set available(double v) {
    if (v == _available) return;
    _available = v;
    markNeedsLayout();
  }

  double _bottomGap;
  set bottomGap(double v) {
    if (v == _bottomGap) return;
    _bottomGap = v;
    markNeedsPaint();
  }

  double _maxWidth;
  set maxWidth(double v) {
    if (v == _maxWidth) return;
    _maxWidth = v;
    markNeedsLayout();
  }

  double _horizontalMargin;
  set horizontalMargin(double v) {
    if (v == _horizontalMargin) return;
    _horizontalMargin = v;
    markNeedsLayout();
  }

  Color? _fill;
  set fill(Color? v) {
    if (v == _fill) return;
    _fill = v;
    markNeedsPaint();
  }

  bool _fadeOnly;
  set fadeOnly(bool v) {
    if (v == _fadeOnly) return;
    _fadeOnly = v;
    markNeedsPaint();
  }

  bool get _contentSized => _detents.first._isContent;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _presence.addListener(markNeedsPaint);
    _extent.addListener(_onExtent);
  }

  @override
  void detach() {
    _presence.removeListener(markNeedsPaint);
    _extent.removeListener(_onExtent);
    super.detach();
  }

  @override
  void dispose() {
    _opacity.layer = null;
    super.dispose();
  }

  void _onExtent() {
    final child = this.child;
    if (!_contentSized &&
        child != null &&
        child.hasSize &&
        _metrics.heights.isNotEmpty &&
        _layoutHeight() != child.size.height) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  double _layoutHeight() =>
      _extent.value.clamp(_metrics.heights.first, _metrics.heights.last);

  void _syncExtent() {
    final heights = _metrics.heights;
    final index = _metrics.index.clamp(0, heights.length - 1);
    _metrics.index = index;
    final target = heights[index];
    if (!_metrics.ready || (_metrics.settled && _extent.value != target)) {
      _metrics.ready = true;
      _extent.value = target;
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) return;
    final width = math.max(
      0.0,
      math.min(size.width - _horizontalMargin * 2, _maxWidth),
    );
    if (_contentSized) {
      child.layout(
        BoxConstraints(minWidth: width, maxWidth: width, maxHeight: _available),
        parentUsesSize: true,
      );
      _metrics.heights = [child.size.height];
      _syncExtent();
    } else {
      final firstLayout = !_metrics.ready;
      final heights = <double>{
        for (final d in _detents) math.max(1.0, d._resolve(_available)),
      }.toList()..sort();
      if (firstLayout) {
        // The initial detent was given in the caller's order.
        final initial = _detents[_metrics.index.clamp(0, _detents.length - 1)]
            ._resolve(_available);
        _metrics.index = heights.indexWhere(
          (h) => (h - math.max(1.0, initial)).abs() < 0.01,
        );
        if (_metrics.index < 0) _metrics.index = 0;
      }
      _metrics.heights = heights;
      _syncExtent();
      child.layout(
        BoxConstraints.tightFor(width: width, height: _layoutHeight()),
        parentUsesSize: true,
      );
    }
  }

  Offset _childOffset() {
    final child = this.child!;
    final visible = _extent.value;
    final presence = _presence.value;
    final x = (size.width - child.size.width) / 2;
    final y = _fadeOnly
        ? size.height - _bottomGap - visible
        : size.height - (visible + _bottomGap) * presence;
    return Offset(x, y);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || _presence.value <= 0) {
      _opacity.layer = null;
      return;
    }
    final childOffset = _childOffset();
    void paintSheet(PaintingContext context, Offset offset) {
      final visible = _extent.value;
      final fill = _fill;
      if (fill != null && visible > child.size.height) {
        // Rubber-band stretch past the top: extend the sheet's color down
        // instead of showing a gap under it.
        final top = offset.dy + childOffset.dy + child.size.height - 1;
        context.canvas.drawRect(
          Rect.fromLTWH(
            offset.dx + childOffset.dx,
            top,
            child.size.width,
            visible - child.size.height + _bottomGap + 1,
          ),
          Paint()..color = fill,
        );
      }
      context.paintChild(child, offset + childOffset);
    }

    final presence = _presence.value;
    if (_fadeOnly && presence < 1) {
      _opacity.layer = context.pushOpacity(
        offset,
        (presence * 255).round(),
        paintSheet,
        oldLayer: _opacity.layer,
      );
    } else {
      _opacity.layer = null;
      paintSheet(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || _presence.value <= 0) return false;
    return result.addWithPaintOffset(
      offset: _childOffset(),
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final o = _childOffset();
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }
}

// iOS rubber-band: resistance grows the further it is pulled.
double _rubber(double offset, double dimension) {
  if (offset <= 0 || dimension <= 0) return 0;
  const c = 0.55;
  return (1 - 1 / (offset * c / dimension + 1)) * dimension;
}

double _rubberInverse(double stretched, double dimension) {
  if (stretched <= 0 || dimension <= 0) return 0;
  const c = 0.55;
  final ratio = (stretched / dimension).clamp(0.0, 0.999);
  return (1 / (1 - ratio) - 1) * dimension / c;
}

/// A spring that lands exactly on its target once it is within tolerance,
/// so a settled sheet sits on whole pixels instead of a hair off.
Simulation _settlingSpring(
  SpringDescription spring,
  double start,
  double end,
  double velocity, {
  required Tolerance tolerance,
}) => _SettlingSimulation(
  SpringSimulation(spring, start, end, velocity, tolerance: tolerance),
  end,
);

class _SettlingSimulation extends Simulation {
  _SettlingSimulation(this._inner, this._end)
    : super(tolerance: _inner.tolerance);

  final SpringSimulation _inner;
  final double _end;

  @override
  double x(double time) => _inner.isDone(time) ? _end : _inner.x(time);

  @override
  double dx(double time) => _inner.isDone(time) ? 0 : _inner.dx(time);

  @override
  bool isDone(double time) => _inner.isDone(time);
}
