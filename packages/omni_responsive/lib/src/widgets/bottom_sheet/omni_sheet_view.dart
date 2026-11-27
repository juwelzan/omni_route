part of 'omni_bottom_sheet.dart';

/// The sheet itself — drag, detents, look — shared by the modal route and
/// the in-page [OmniScalableSheet] through [_SheetHost].
class _OmniSheetView extends StatefulWidget {
  const _OmniSheetView({required this.host});

  final _SheetHost host;

  @override
  State<_OmniSheetView> createState() => _OmniSheetViewState();
}

class _OmniSheetViewState extends State<_OmniSheetView>
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
  final ValueNotifier<bool> _scrolled = ValueNotifier(false);
  int _dragStartIndex = 0;
  Widget? _header;
  WidgetBuilder? _headerBuilder;

  // Content built once; the sheet's own rebuilds (keyboard, rotation) reuse
  // it, so dragging and animating never rebuild what the developer wrote.
  Widget? _content;
  WidgetBuilder? _contentBuilder;
  bool _cupertinoApp = false;

  // Finger position in sheet terms (px of visible sheet), unclamped.
  double _raw = 0;
  bool _dragging = false;

  _SheetHost get _host => widget.host;
  _SheetConfig get _config => _host.config;
  AnimationController get _presence => _host.presence;
  OmniSheetMotion get _motion => _host.effectiveMotion;
  bool get _contentSized => _config.detents.first._isContent;
  double get _available => _metrics.available;

  // The given index (caller's order) is mapped to the smallest-first order
  // at the first layout, once fractions and fixed heights can be compared.
  int _sortedInitialIndex() => _config.detents[_config.initialDetent]._isContent
      ? 0
      : _config.initialDetent;

  @override
  void initState() {
    super.initState();
    _host.attachView(this);
    // Publish the smallest-first index of the initial detent once known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _detent.value = _metrics.index;
      _host.didChangeDetent(_metrics.index);
    });
  }

  @override
  void didUpdateWidget(_OmniSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.host, widget.host)) {
      oldWidget.host.attachView(null);
      widget.host.attachView(this);
    }
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
    _host.attachView(null);
    _extent.dispose();
    _detent.dispose();
    _scrolled.dispose();
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
  ValueListenable<bool> get isScrolled => _scrolled;

  @override
  int get detentCount => _config.detents.length;

  @override
  OmniSheetStyle get style => _host.effectiveStyle;

  @override
  ScrollController get scrollController => _scroll;

  @override
  Future<void> snapTo(int index) => _snap(index, 0);

  @override
  void close([Object? result]) => _host.close(result);

  // ── Gestures ──────────────────────────────────────────────────────────────

  List<double> get _heights => _metrics.heights;

  void _dragStart() {
    if (_heights.isEmpty) return;
    _dragging = true;
    _dragStartIndex = _metrics.index;
    if (_config.scrolling.dismissKeyboardOnDrag) _closeKeyboard();
    _metrics.settled = false;
    _extent.stop();
    _presence.stop();
    final presence = _presence.value;
    final min = _heights.first, max = _heights.last;
    if (presence < 1) {
      _raw = _config.isDismissible
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
      presence = _config.isDismissible
          ? (_raw / min).clamp(0.001, 1.0)
          : 1 - _rubber(min - _raw, min) / min;
    }
    if (_extent.value != extent) _extent.value = extent;
    if (_presence.value != presence) _presence.value = presence;
  }

  /// [velocity] > 0 is a downward fling (px/s).
  void _dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    if (_heights.isEmpty) return;
    final min = _heights.first;
    final projected = _raw - velocity * 0.25;
    final dismissible = _config.isDismissible;

    if (_presence.value < 1) {
      if (dismissible &&
          (velocity > _motion.dismissVelocity || projected < min / 2)) {
        _dismiss(velocity);
      } else {
        // Pulled below the smallest detent: rest on the smallest.
        _host.settlePresence(-velocity / min);
        _snap(0, 0);
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
    if (target != _dragStartIndex && _config.scrolling.hapticFeedback) {
      HapticFeedback.selectionClick();
    }
    _snap(target, -velocity);
  }

  Future<void> _dismiss(double velocity) async {
    final base = math.max(_extent.value, 1.0);
    final gone = await _host.dismiss(-velocity / base);
    // Refused (a PopScope, or the host keeps it): spring back.
    if (!gone && mounted) {
      _host.settlePresence(0);
      _snap(_metrics.index, 0);
    }
  }

  TickerFuture _snap(int index, double velocity) {
    if (_heights.isEmpty) return TickerFuture.complete();
    final i = index.clamp(0, _heights.length - 1);
    _metrics.index = i;
    if (_detent.value != i) {
      _detent.value = i;
      _host.didChangeDetent(i);
    }
    if (i == 0 && _heights.length > 1 && _config.scrolling.resetOnCollapse) {
      _scrollToTop();
    }
    _metrics.settled = false;
    final target = _heights[i];
    if (_host.reduceMotion) {
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

  /// Unfocuses a text field inside this sheet (closing the keyboard). The
  /// keyboard inset can't be read here — a Scaffold removes it from its
  /// body — so the focused field itself is the signal.
  void _closeKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focusContext == null) return;
    final inSheet = identical(
      focusContext.getInheritedWidgetOfExactType<_OmniSheetScope>()?.controller,
      this,
    );
    if (inSheet &&
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null) {
      focus!.unfocus();
    }
  }

  /// Animates scrolled lists inside back to their top; `false` when none
  /// was scrolled.
  bool _scrollToTop() {
    var any = false;
    for (final p in _scroll.positions) {
      if (p.pixels > p.minScrollExtent + 0.5) {
        any = true;
        p.animateTo(
          p.minScrollExtent,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
      }
    }
    return any;
  }

  void _onHandleTap() {
    if (_config.scrolling.handleTapScrollsToTop && _scrollToTop()) return;
    _cycleDetent();
  }

  void _cycleDetent() {
    if (detentCount > 1) {
      _snap((_metrics.index + 1) % _heights.length, 0);
    } else if (_config.isDismissible) {
      close();
    }
  }

  /// Whether a scroll view inside should move the sheet instead of its
  /// content for a drag of [delta] (> 0 = finger down).
  bool _takesScroll(double delta, ScrollPosition position) {
    if (!_config.enableDrag || _heights.isEmpty) return false;
    if (_dragging) {
      // Keep the sheet until it is fully expanded again.
      return delta > 0 ||
          _presence.value < 1 ||
          (_config.scrolling.expandBeforeScroll && _raw < _heights.last);
    }
    if (delta > 0) return position.pixels <= position.minScrollExtent;
    return _presence.value < 1 ||
        (_config.scrolling.expandBeforeScroll &&
            _extent.value < _heights.last - 0.5);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final route = _config;
    final style = _host.effectiveStyle;
    final padding = MediaQuery.paddingOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final fadeOnly = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final safe = route.useSafeArea;
    final floating = style == OmniSheetStyle.floating;
    final margin = floating
        ? (route.margin ?? const EdgeInsets.all(10))
        : EdgeInsets.zero;

    final double topGap = switch (style) {
      OmniSheetStyle.cupertino => (safe ? padding.top : 0.0) + 10,
      OmniSheetStyle.floating => (safe ? padding.top : 0.0) + margin.top,
      _ => safe ? padding.top : 0.0,
    };
    final keyboard = insets.bottom;
    final safeBottom = safe && keyboard == 0 ? padding.bottom : 0.0;
    final bottomGap = floating
        ? keyboard + math.max(margin.bottom, safeBottom + margin.bottom * 0.5)
        : keyboard;
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

    // Built once per builder: drags and animations never rebuild it; a new
    // builder (the in-page sheet's parent rebuilt) does.
    if (!identical(_contentBuilder, route.builder)) {
      _contentBuilder = route.builder;
      _content = Builder(builder: route.builder);
    }
    Widget content = _content!;
    final physics = route.scrolling.resolve(style, _platformOf(context));
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
          child: PrimaryScrollController(
            controller: _scroll,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                physics: physics,
                overscroll: physics is BouncingScrollPhysics ? false : null,
                keyboardDismissBehavior: route.scrolling.dismissKeyboardOnDrag
                    ? ScrollViewKeyboardDismissBehavior.onDrag
                    : null,
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );

    final header = route.header;
    if (!identical(_headerBuilder, header)) {
      _headerBuilder = header;
      _header = header == null ? null : Builder(builder: header);
    }

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
              onTap: _onHandleTap,
            ),
          if (_header case final header?)
            _SheetHeader(
              scrolled: _scrolled,
              dividerColor: look.divider,
              child: header,
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
        scopesRoute: _host.isModal,
        namesRoute: _host.isModal,
        container: true,
        explicitChildNodes: true,
        label:
            route.semanticLabel ??
            _localizations(context)?.bottomSheetLabel ??
            'Sheet',
        child: _SheetLayout(
          presence: _presence,
          extent: _extent,
          metrics: _metrics,
          detents: route.detents,
          topGap: topGap,
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

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      _scrolled.value = n.metrics.extentBefore > 0.5;
    }
    return false;
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
