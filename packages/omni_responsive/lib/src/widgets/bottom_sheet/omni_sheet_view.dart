part of 'omni_bottom_sheet.dart';

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
