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
    publicIndex: _config.initialDetent,
  );
  late final ValueNotifier<int> _detent = ValueNotifier(_metrics.publicIndex);
  late final _SheetScrollController _scroll = _SheetScrollController(this);
  final ValueNotifier<bool> _scrolled = ValueNotifier(false);
  int _dragStartSortedIndex = 0;
  Widget? _header;
  WidgetBuilder? _headerBuilder;
  Widget? _trailing;
  WidgetBuilder? _trailingBuilder;

  // Content built once; the sheet's own rebuilds (keyboard, rotation) reuse
  // it, so dragging and animating never rebuild what the developer wrote.
  Widget? _content;
  WidgetBuilder? _contentBuilder;
  bool _cupertinoApp = false;

  // Finger position in sheet terms (px of visible sheet), unclamped.
  double _raw = 0;
  bool _dragging = false;
  bool _disposed = false;
  bool _retargetQueued = false;
  int? _pendingRetargetSortedIndex;
  bool _scrollRefreshQueued = false;
  late List<OmniSheetDetent> _lastDetents;

  _SheetHost get _host => widget.host;
  _SheetConfig get _config => _host.config;
  AnimationController get _presence => _host.presence;
  OmniSheetMotion get _motion => _host.effectiveMotion;
  bool get _contentSized => _config.detents.first._isContent;
  double get _available => _metrics.available;
  bool get _canDragSheet => _config.enableDrag && !_disposed && !_host.isClosing;

  @override
  void initState() {
    super.initState();
    _lastDetents = List<OmniSheetDetent>.of(_config.detents);
    _metrics.onRetargetNeeded = _scheduleRetarget;
    _host.attachView(this);
    // Publish the initial detent once attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      _detent.value = _metrics.publicIndex;
      _host.didChangeDetent(_metrics.publicIndex);
    });
  }

  void _scheduleRetarget(int sortedIndex) {
    _pendingRetargetSortedIndex = sortedIndex;
    if (_retargetQueued) return;
    _retargetQueued = true;
    scheduleMicrotask(() {
      _retargetQueued = false;
      final next = _pendingRetargetSortedIndex;
      _pendingRetargetSortedIndex = null;
      if (next == null || !mounted || _disposed || _dragging || _metrics.settled) {
        return;
      }
      if (_heights.isEmpty) return;
      final clamped = next.clamp(0, _heights.length - 1);
      final pub = _metrics.publicIndex.clamp(0, _config.detents.length - 1);
      _snapSorted(
        clamped,
        publicIndex: pub,
        velocity: _extent.velocity,
      );
    });
  }

  void _scheduleRefreshScrolled() {
    if (_scrollRefreshQueued || _disposed) return;
    _scrollRefreshQueued = true;
    scheduleMicrotask(() {
      _scrollRefreshQueued = false;
      if (!mounted || _disposed) return;
      _refreshScrolledFromPositions();
    });
  }

  void _refreshScrolledFromPositions() {
    if (!_scroll.hasClients) {
      if (_scrolled.value) _scrolled.value = false;
      return;
    }
    var anyScrolled = false;
    for (final p in _scroll.positions) {
      if (p.pixels > p.minScrollExtent + 0.5) {
        anyScrolled = true;
        break;
      }
    }
    if (_scrolled.value != anyScrolled) {
      _scrolled.value = anyScrolled;
    }
  }

  @override
  void didUpdateWidget(_OmniSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDetents = _lastDetents;
    final newDetents = _config.detents;
    if (!identical(oldWidget.host, widget.host)) {
      oldWidget.host.attachView(null);
      widget.host.attachView(this);
    }
    if (!listEquals(oldDetents, newDetents)) {
      _lastDetents = List<OmniSheetDetent>.of(newDetents);
      final prevIdx = _metrics.publicIndex.clamp(0, oldDetents.length - 1);
      final prevDetent = oldDetents[prevIdx];
      int nextPublic;
      if (prevIdx < newDetents.length && newDetents[prevIdx] == prevDetent) {
        nextPublic = prevIdx;
      } else {
        final found = newDetents.indexOf(prevDetent);
        nextPublic = found >= 0
            ? found
            : prevIdx.clamp(0, newDetents.length - 1);
      }
      _metrics.publicIndex = nextPublic;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = _metrics.publicIndex;
        if (_detent.value != current) {
          _detent.value = current;
          _host.didChangeDetent(current);
        }
      });
    }
    if (!widget.host.config.enableDrag && _dragging) {
      _dragging = false;
      _metrics.dragging = false;
      _dragEnd(0);
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
    _disposed = true;
    _dragging = false;
    _metrics.dragging = false;
    _metrics.onRetargetNeeded = null;
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
  Future<void> snapTo(int index) {
    RangeError.checkValidIndex(index, _config.detents, 'index');
    if (_heights.isEmpty || _metrics.publicToSorted.length != _config.detents.length) {
      _metrics.publicIndex = index;
      if (_detent.value != index) {
        _detent.value = index;
        _host.didChangeDetent(index);
      }
      return Future<void>.value();
    }
    return _snapSorted(
      _metrics.publicToSorted[index],
      publicIndex: index,
      velocity: 0,
    );
  }

  Future<void> _expand() {
    if (_heights.isEmpty) {
      _metrics.publicIndex = _config.detents.length - 1;
      return Future<void>.value();
    }
    final sorted = _heights.length - 1;
    return _snapSorted(
      sorted,
      publicIndex: _metrics.sortedToPublic[sorted],
      velocity: 0,
    );
  }

  Future<void> _collapse() {
    if (_heights.isEmpty) {
      _metrics.publicIndex = 0;
      return Future<void>.value();
    }
    return _snapSorted(
      0,
      publicIndex: _metrics.sortedToPublic[0],
      velocity: 0,
    );
  }

  @override
  void close([Object? result]) => _host.close(result);

  // ── Gestures ──────────────────────────────────────────────────────────────

  List<double> get _heights => _metrics.heights;

  void _dragStart() {
    if (_heights.isEmpty || !_canDragSheet) return;
    _dragging = true;
    _metrics.dragging = true;
    _dragStartSortedIndex = _metrics.sortedIndex;
    if (_config.scrolling.dismissKeyboardOnDrag) _closeKeyboard();
    _metrics.settled = false;
    _extent.stop();
    _presence.stop();
    final presence = _presence.value;
    final min = _heights.first, max = _heights.last;
    if (presence < 1) {
      final visible = _extent.value * presence;
      if (min <= 0) {
        _raw = 0;
      } else if (visible >= min) {
        _presence.value = 1.0;
        _extent.value = visible;
        _raw = visible;
      } else {
        _extent.value = min;
        _presence.value = (visible / min).clamp(0.001, 1.0);
        _raw = _config.isDismissible
            ? visible
            : min - _rubberInverse(min - visible, min);
      }
    } else if (_extent.value > max) {
      _raw = max + _rubberInverse(_extent.value - max, _available);
    } else {
      _raw = _extent.value;
    }
  }

  /// [delta] > 0 is the finger moving down.
  void _dragUpdate(double delta) {
    if (!_canDragSheet) return;
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
      if (min <= 0) {
        presence = 1.0;
      } else {
        presence = _config.isDismissible
            ? (_raw / min).clamp(0.001, 1.0)
            : 1 - _rubber(min - _raw, min) / min;
      }
    }
    if (_extent.value != extent) _extent.value = extent;
    if (_presence.value != presence) _presence.value = presence;
  }

  /// Cancels any active drag gesture immediately (for route pop / disposal).
  void _cancelDrag() {
    _dragging = false;
    _metrics.dragging = false;
  }

  /// Ends any active drag gesture gracefully by snapping back to a detent.
  void _cancelDragAndSnap() {
    if (_dragging) _dragEnd(0);
  }

  /// Completes a scroll-driven upward expansion cleanly so subsequent
  /// downward dragging scrolls the inner list first before moving the sheet.
  void _finishHandoffToScroll() {
    if (!_dragging) return;
    _dragging = false;
    _metrics.dragging = false;
    if (_heights.isEmpty) return;
    final sorted = _raw >= _heights.last - 0.5 ? _heights.length - 1 : 0;
    final target = _heights[sorted];
    final pub = sorted == _metrics.sortedIndex
        ? _metrics.publicIndex
        : _metrics.sortedToPublic[sorted];
    if (sorted != _dragStartSortedIndex && _config.scrolling.hapticFeedback) {
      HapticFeedback.selectionClick();
    }
    _metrics
      ..sortedIndex = sorted
      ..publicIndex = pub
      ..lastSyncedTarget = target
      ..settled = true;
    if (_detent.value != pub) {
      _detent.value = pub;
      _host.didChangeDetent(pub);
    }
    _extent.value = target;
    _presence.value = 1.0;
    _raw = target;
  }

  /// [velocity] > 0 is a downward fling (px/s).
  void _dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    _metrics.dragging = false;
    if (_disposed || !mounted || _heights.isEmpty) return;
    final min = _heights.first;
    final projected = _raw - velocity * 0.25;
    final dismissible = _config.isDismissible;

    if (_presence.value < 1) {
      if (dismissible &&
          (velocity > _motion.dismissVelocity || projected < min / 2)) {
        _dismiss(velocity);
      } else {
        // Pulled below the smallest detent: rest on the smallest.
        _host.settlePresence(min > 0 ? -velocity / min : 0.0);
        final publicForMin = _metrics.sortedIndex == 0
            ? _metrics.publicIndex
            : _metrics.sortedToPublic[0];
        _snapSorted(0, publicIndex: publicForMin, velocity: 0);
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
        ((_dragStartSortedIndex == 0 && velocity > _motion.dismissVelocity) ||
            (_raw <= min + 40 && velocity > _motion.dismissVelocity * 1.6) ||
            (projected < min / 2 && _raw <= min + 80))) {
      _dismiss(velocity);
      return;
    }
    if (target != _dragStartSortedIndex && _config.scrolling.hapticFeedback) {
      HapticFeedback.selectionClick();
    }
    final targetPublic = target == _metrics.sortedIndex
        ? _metrics.publicIndex
        : _metrics.sortedToPublic[target];
    _snapSorted(target, publicIndex: targetPublic, velocity: -velocity);
  }

  Future<void> _dismiss(double velocity) async {
    final base = math.max(_extent.value, 1.0);
    final gone = await _host.dismiss(-velocity / base);
    // Refused (a PopScope, or the host keeps it): spring back.
    if (!gone && mounted && !_disposed) {
      _host.settlePresence(0);
      _snapSorted(
        _metrics.sortedIndex,
        publicIndex: _metrics.publicIndex,
        velocity: 0,
      );
    }
  }

  TickerFuture _snapSorted(
    int sortedIndex, {
    required int publicIndex,
    required double velocity,
  }) {
    if (_disposed || !mounted || _heights.isEmpty) {
      return TickerFuture.complete();
    }
    final i = sortedIndex.clamp(0, _heights.length - 1);
    final pub = publicIndex.clamp(0, _config.detents.length - 1);
    _metrics.sortedIndex = i;
    _metrics.publicIndex = pub;
    if (_detent.value != pub) {
      _detent.value = pub;
      _host.didChangeDetent(pub);
    }
    if (i == 0 && _heights.length > 1 && _config.scrolling.resetOnCollapse) {
      _scrollToTop();
    }
    _metrics.settled = false;
    final target = _heights[i];
    _metrics.lastSyncedTarget = target;
    var effectiveVelocity = velocity;
    if (!_motion.rubberBand) {
      if (i == _heights.length - 1 &&
          _extent.value >= target - 0.5 &&
          effectiveVelocity > 0) {
        effectiveVelocity = 0;
      } else if (i == 0 &&
          !_config.isDismissible &&
          _extent.value <= target + 0.5 &&
          effectiveVelocity < 0) {
        effectiveVelocity = 0;
      }
    }
    if (_host.reduceMotion ||
        ((_extent.value - target).abs() < 0.05 && effectiveVelocity == 0)) {
      _extent.value = target;
      _metrics.settled = true;
      return TickerFuture.complete();
    }
    return _extent.animateWith(
      _settlingSpring(
        _motion.spring,
        _extent.value,
        target,
        effectiveVelocity,
        tolerance: const Tolerance(distance: 0.4, velocity: 4),
        minValue: _motion.rubberBand ? null : _heights.first,
        maxValue: _motion.rubberBand ? null : _heights.last,
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
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
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
    if (_heights.length > 1) {
      final nextSorted = (_metrics.sortedIndex + 1) % _heights.length;
      _snapSorted(
        nextSorted,
        publicIndex: _metrics.sortedToPublic[nextSorted],
        velocity: 0,
      );
    } else if (_config.isDismissible) {
      unawaited(_dismiss(180));
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
    final safeBottom = safe ? math.max(0.0, padding.bottom - keyboard) : 0.0;
    final safeLeft = safe ? padding.left : 0.0;
    final safeRight = safe ? padding.right : 0.0;
    final leftInset = margin.left + safeLeft;
    final rightInset = margin.right + safeRight;
    final bottomGap = floating
        ? keyboard + math.max(margin.bottom, safeBottom + margin.bottom * 0.5)
        : keyboard;
    final look = _SheetLook.resolve(context, style, route, _cupertinoApp);
    final radius = Radius.circular(
      route.cornerRadius ??
          switch (style) {
            OmniSheetStyle.material => 28,
            OmniSheetStyle.cupertino => 14,
            OmniSheetStyle.floating => 36,
            OmniSheetStyle.adaptive => 28,
          },
    );
    final shape = RoundedRectangleBorder(
      side: floating && route.backgroundColor == null
          ? BorderSide(color: look.rimBorder, width: 1.0)
          : BorderSide.none,
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
        removeLeft: leftInset > 0,
        removeRight: rightInset > 0,
        child: Padding(
          padding: EdgeInsets.only(bottom: floating ? 0 : safeBottom),
          child: PrimaryScrollController(
            controller: _scroll,
            automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
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
    final trailing = route.trailing;
    if (!identical(_trailingBuilder, trailing)) {
      _trailingBuilder = trailing;
      _trailing = trailing == null ? null : Builder(builder: trailing);
    }

    final showHandle = route.showHandle ?? route.enableDrag;
    final hasTitle = route.title != null && route.title!.isNotEmpty;
    final showClose =
        route.showCloseButton ??
        (floating && route.isDismissible);
    final hasIosChrome =
        showClose || hasTitle || _trailing != null;
    final frostedChrome =
        floating || style == OmniSheetStyle.cupertino;

    Widget buildReactiveHandle({bool compact = false}) =>
        ValueListenableBuilder<int>(
          valueListenable: _detent,
          builder: (context, _, _) => _SheetHandle(
            style: style,
            color: look.handle,
            hint: _handleHint(context),
            onTap: _onHandleTap,
            interactive: _canActivateHandle,
            compact: compact,
          ),
        );

    Widget? pinnedTop;
    if (hasIosChrome) {
      final chromeBar = ValueListenableBuilder<int>(
        valueListenable: _detent,
        builder: (context, _, _) => _IosFloatingChrome(
          style: style,
          look: look,
          showHandle: showHandle,
          handleHint: _handleHint(context),
          handleInteractive: _canActivateHandle,
          onHandleTap: _onHandleTap,
          showCloseButton: showClose,
          onClosePressed: () => unawaited(_dismiss(180)),
          title: route.title,
          trailing: _trailing,
        ),
      );
      pinnedTop = _SheetHeader(
        scrolled: _scrolled,
        dividerColor: look.divider,
        backgroundColor: look.background,
        frosted: frostedChrome,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [chromeBar, ?_header],
        ),
      );
    } else if (_header case final customHeader?) {
      pinnedTop = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle) buildReactiveHandle(),
          _SheetHeader(
            scrolled: _scrolled,
            dividerColor: look.divider,
            backgroundColor: look.background,
            frosted: frostedChrome,
            child: customHeader,
          ),
        ],
      );
    } else if (showHandle) {
      pinnedTop = buildReactiveHandle();
    }

    Widget sheet = Material(
      color: look.background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: _contentSized ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?pinnedTop,
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
                  color: Color(0x26000000),
                  blurRadius: 32,
                  spreadRadius: -2,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: Color(0x0E000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
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
    if (_host.isModal) {
      if (route.isDismissible) {
        sheet = CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                unawaited(_dismiss(180)),
          },
          child: sheet,
        );
      }
      sheet = FocusScope(
        autofocus: true,
        child: FocusTraversalGroup(child: sheet),
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
          leftInset: leftInset,
          rightInset: rightInset,
          fill: floating ? null : look.background,
          fadeOnly: fadeOnly,
          clipToBounds: !_host.isModal,
          child: RepaintBoundary(child: sheet),
        ),
      ),
    );
  }

  bool get _canActivateHandle {
    final distinctCount = _heights.isNotEmpty ? _heights.length : detentCount;
    return distinctCount > 1 ||
        _config.isDismissible ||
        _config.scrolling.handleTapScrollsToTop;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (_scroll.hasClients) {
      _refreshScrolledFromPositions();
    } else if (n.depth == 0) {
      _scrolled.value = n.metrics.extentBefore > 0.5;
    }
    return false;
  }

  String _handleHint(BuildContext context) {
    final l = _localizations(context);
    final distinctCount = _heights.isNotEmpty ? _heights.length : detentCount;
    if (distinctCount > 1) {
      return _metrics.sortedIndex < distinctCount - 1
          ? (l?.collapsedIconTapHint ?? 'Expand')
          : (l?.expandedIconTapHint ?? 'Collapse');
    }
    return l?.modalBarrierDismissLabel ?? 'Dismiss';
  }
}
