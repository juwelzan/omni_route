part of 'omni_bottom_navigation.dart';

/// Custom builder for completely bespoke tab rendering inside
/// [OmniBottomNavigationBar].
typedef OmniBottomNavigationItemBuilder =
    Widget Function(
      BuildContext context,
      OmniBottomNavigationItem item,
      bool selected,
      double selectionProgress,
    );

/// A highly customizable, multi-mode bottom navigation bar inspired by CollectUI
/// mobile navigation patterns.
///
/// Works seamlessly in **both**:
/// - `Scaffold(bottomNavigationBar: OmniBottomNavigationBar(...))` or
///   `Scaffold(extendBody: true, bottomNavigationBar: ...)`
/// - Directly inside `omni_route`'s `OmniPage(bottomNavigationBar: ...)` /
///   `OmniPage.screen(...)` / `OmniStatefulShell`.
class OmniBottomNavigationBar extends StatefulWidget {
  /// Creates a customizable bottom navigation bar.
  const OmniBottomNavigationBar({
    super.key,
    required this.items,
    this.currentIndex,
    this.onTap,
    this.onReselect,
    this.style,
    this.labelMode,
    this.theme,
    this.centerAction,
    this.controller,
    this.scrollController,
    this.hideOnScroll = false,
    this.hideOnKeyboard = true,
    this.respectSafeArea = true,
    this.backgroundColor,
    this.backgroundGradient,
    this.activeColor,
    this.inactiveColor,
    this.indicatorColor,
    this.indicatorGradient,
    this.activeContentColor,
    this.borderColor,
    this.borderWidth,
    this.glowColor,
    this.badgeColor,
    this.badgeTextColor,
    this.height,
    this.margin,
    this.padding,
    this.borderRadius,
    this.indicatorRadius,
    this.maxWidth,
    this.iconSize,
    this.selectedIconSize,
    this.blurSigma,
    this.backgroundOpacity,
    this.enableBlur,
    this.boxShadow,
    this.elevation,
    this.labelStyle,
    this.selectedLabelStyle,
    this.animationDuration,
    this.animationCurve,
    this.indicatorCurve,
    this.enableHaptics,
    this.enableScaleAnimation,
    this.itemBuilder,
  });

  /// Tab destinations displayed in the bar (recommended: 2 to 5 items).
  final List<OmniBottomNavigationItem> items;

  /// Active tab index. When `null`, uses [controller] or auto-matches the
  /// active `OmniRouter` route against [OmniBottomNavigationItem.routePath].
  final int? currentIndex;

  /// Called when a tab is tapped. When `null` and the tapped item specifies
  /// [OmniBottomNavigationItem.routePath] inside an `OmniApp`, navigates there
  /// automatically.
  final ValueChanged<int>? onTap;

  /// Optional callback invoked when tapping the already active tab.
  final ValueChanged<int>? onReselect;

  /// Visual CollectUI / Material / iOS layout mode (defaults to
  /// [OmniBottomNavigationStyle.floating]).
  final OmniBottomNavigationStyle? style;

  /// Label display policy across tabs.
  final OmniBottomNavLabelMode? labelMode;

  /// Optional reusable style configuration bundle.
  final OmniBottomNavigationStyleData? theme;

  /// Optional prominent circular CTA button (ideal with
  /// [OmniBottomNavigationStyle.centerFabNotch] and
  /// [OmniBottomNavigationStyle.splitIsland], and seamlessly embedded in other
  /// styles as well).
  final OmniBottomNavigationAction? centerAction;

  /// Optional programmatic controller for active index and show/hide visibility.
  final OmniBottomNavigationController? controller;

  /// Optional scrollable controller paired with [hideOnScroll].
  final ScrollController? scrollController;

  /// Hides the bar with a smooth downward slide when scrolling down and
  /// reveals it on scrolling up (requires [scrollController]).
  final bool hideOnScroll;

  /// Hides the bar smoothly when the on-screen keyboard opens.
  final bool hideOnKeyboard;

  /// Applies bottom safe-area inset for the system gesture/home bar.
  final bool respectSafeArea;

  /// Bar surface color override.
  final Color? backgroundColor;

  /// Bar background gradient override.
  final Gradient? backgroundGradient;

  /// Selected icon & label color override.
  final Color? activeColor;

  /// Unselected icon & label color override.
  final Color? inactiveColor;

  /// Indicator pill / wave orb / bubble / dot fill color override.
  final Color? indicatorColor;

  /// Gradient applied to active pills, bubbles, spotlights, or wave orbs.
  final Gradient? indicatorGradient;

  /// Foreground color used inside solid contrasting indicators.
  final Color? activeContentColor;

  /// Card/dock border color override.
  final Color? borderColor;

  /// Card/dock border width override.
  final double? borderWidth;

  /// Glow / spotlight color override.
  final Color? glowColor;

  /// Default badge background fill override.
  final Color? badgeColor;

  /// Default badge text color override.
  final Color? badgeTextColor;

  /// Base bar content height override.
  final double? height;

  /// Outer margin around floating styles.
  final EdgeInsetsGeometry? margin;

  /// Inner content padding around tab slots.
  final EdgeInsetsGeometry? padding;

  /// Outer corner radius override.
  final double? borderRadius;

  /// Active pill / island corner radius override.
  final double? indicatorRadius;

  /// Maximum width on large tablets & desktops.
  final double? maxWidth;

  /// Default icon size.
  final double? iconSize;

  /// Selected icon size.
  final double? selectedIconSize;

  /// Frosted glass backdrop blur sigma.
  final double? blurSigma;

  /// Background opacity multiplier (`0.0..1.0`).
  final double? backgroundOpacity;

  /// Enables `BackdropFilter` blur for any style.
  final bool? enableBlur;

  /// Custom ambient drop shadows.
  final List<BoxShadow>? boxShadow;

  /// Shadow blur elevation hint.
  final double? elevation;

  /// Unselected label text style.
  final TextStyle? labelStyle;

  /// Selected label text style.
  final TextStyle? selectedLabelStyle;

  /// Transition animation duration.
  final Duration? animationDuration;

  /// General crossfade & slide curve.
  final Curve? animationCurve;

  /// Spring/bounce curve for moving pill/wave/dot indicators.
  final Curve? indicatorCurve;

  /// Plays light selection haptics on tap when `true`.
  final bool? enableHaptics;

  /// Scales tabs slightly on press-down & bounces on release when `true`.
  final bool? enableScaleAnimation;

  /// Optional custom per-item builder for full visual freedom.
  final OmniBottomNavigationItemBuilder? itemBuilder;

  @override
  State<OmniBottomNavigationBar> createState() =>
      _OmniBottomNavigationBarState();
}

class _OmniBottomNavigationBarState extends State<OmniBottomNavigationBar>
    with SingleTickerProviderStateMixin {
  /// Last indicator position per item list. Bars built from the same `items`
  /// list (one shared `const` bar on several routes) pick up where the
  /// previous one stopped, so a freshly pushed page slides the indicator from
  /// the old tab instead of jumping or sweeping in from tab 0.
  static final Expando<double> _lastTravelByItems = Expando<double>(
    'OmniBottomNavigationBar.travel',
  );

  late final AnimationController _travelCtrl;

  /// Indicator position (in tab units) where the current travel started.
  double _fromIndex = 0;

  /// Tab the indicator is travelling to.
  double _toIndex = 0;

  /// Resolved selected tab (from [OmniBottomNavigationBar.currentIndex], the
  /// controller, or the route), kept in state so the indicator and the
  /// selected colours always agree within a frame.
  int _activeIndex = 0;
  bool _resolvedOnce = false;
  bool _reduceMotion = false;
  Curve _travelCurve = Curves.easeOutCubic;

  /// Bridge seen in the last dependency pass. Controller notifications use
  /// it instead of looking the tree up, since they can arrive while this
  /// element is deactivated (e.g. a replacement bar syncs the shared
  /// controller in its initState).
  OmniRouteNavigationBridge? _bridge;

  bool _scrollVisible = true;
  final Map<ScrollPosition, double> _lastScrollPixelsByPosition = {};

  @override
  void initState() {
    super.initState();
    _travelCtrl = AnimationController(
      vsync: this,
      duration: widget.animationDuration ?? const Duration(milliseconds: 340),
      value: 1,
    );
    widget.controller?._syncItemCount(widget.items.length);
    widget.controller?.addListener(_onControllerChanged);
    _attachScroll(widget.scrollController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _bridge = OmniRouteNavigationBridge.readMaybeOf(context);
    _syncActiveIndex();
  }

  @override
  void didUpdateWidget(covariant OmniBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller?._syncItemCount(widget.items.length);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
    if (oldWidget.scrollController != widget.scrollController ||
        oldWidget.hideOnScroll != widget.hideOnScroll) {
      _detachScroll(oldWidget.scrollController);
      _attachScroll(widget.scrollController);
    }
    if (oldWidget.items.length != widget.items.length) {
      final maxIdx = math.max(0, widget.items.length - 1).toDouble();
      _fromIndex = _fromIndex.clamp(0.0, maxIdx);
      _toIndex = _toIndex.clamp(0.0, maxIdx);
    }
    _bridge = OmniRouteNavigationBridge.readMaybeOf(context);
    _syncActiveIndex();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _detachScroll(widget.scrollController);
    _travelCtrl.dispose();
    super.dispose();
  }

  /// Re-resolves the selected tab and starts the indicator towards it. Runs
  /// from the lifecycle hooks (never from `build`), so a route change, a
  /// controller change and a new `currentIndex` all retarget in the same frame
  /// they arrive in.
  void _syncActiveIndex() {
    final next = _resolveActiveIndex(_bridge);
    _activeIndex = next;
    if (widget.items.isEmpty) {
      _fromIndex = 0;
      _toIndex = 0;
      return;
    }
    if (!_resolvedOnce) {
      _resolvedOnce = true;
      final last = _lastTravelByItems[widget.items];
      final maxIdx = (widget.items.length - 1).toDouble();
      if (last != null && last != next && !_reduceMotion) {
        _fromIndex = last.clamp(0.0, maxIdx);
        _toIndex = next.toDouble();
        _travelCtrl.forward(from: 0);
      } else {
        _fromIndex = next.toDouble();
        _toIndex = next.toDouble();
        _travelCtrl.value = 1;
      }
      _lastTravelByItems[widget.items] = next.toDouble();
      return;
    }
    _animateToIndex(next);
  }

  /// Where the indicator is drawn at controller value [v]. The curve may
  /// overshoot (the default `easeOutBack` does); the overshoot is softly
  /// limited to a fraction of a tab so the indicator never visits a
  /// neighbouring tab on the way.
  double _travelAt(double v) {
    final from = _fromIndex;
    final to = _toIndex;
    if (from == to || v >= 1) return to;
    if (v <= 0) return from;
    final pos = from + (to - from) * _travelCurve.transform(v);
    final lo = math.min(from, to);
    final hi = math.max(from, to);
    if (pos > hi) return hi + _softLimit(pos - hi);
    if (pos < lo) return lo - _softLimit(lo - pos);
    return pos;
  }

  static const double _maxOvershoot = 0.14;

  static double _softLimit(double excess) =>
      _maxOvershoot * excess / (excess + _maxOvershoot);

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller == null) return;
    // Index and visibility both live on the controller.
    setState(_syncActiveIndex);
  }

  void _attachScroll(ScrollController? controller) {
    if (controller == null || !widget.hideOnScroll) return;
    _lastScrollPixelsByPosition.clear();
    for (final position in controller.positions) {
      _lastScrollPixelsByPosition[position] = position.pixels;
    }
    controller.addListener(_onScroll);
    _scheduleScrollPositionSync(controller);
  }

  void _detachScroll(ScrollController? controller) {
    controller?.removeListener(_onScroll);
    _lastScrollPixelsByPosition.clear();
  }

  void _scheduleScrollPositionSync(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.hideOnScroll ||
          widget.scrollController != controller) {
        return;
      }

      final positions = controller.positions.toSet();
      _lastScrollPixelsByPosition.removeWhere(
        (position, _) => !positions.contains(position),
      );
      for (final position in positions) {
        _lastScrollPixelsByPosition.putIfAbsent(
          position,
          () => position.pixels,
        );
      }
    });
  }

  void _onScroll() {
    final controller = widget.scrollController;
    if (!widget.hideOnScroll ||
        controller == null ||
        !controller.hasClients ||
        !mounted) {
      return;
    }

    var movedDown = false;
    var movedUp = false;
    var atScrollStart = false;

    for (final position in controller.positions) {
      final pixels = position.pixels;
      final lastPixels = _lastScrollPixelsByPosition[position];
      if (lastPixels == null) {
        _lastScrollPixelsByPosition[position] = pixels;
        if (pixels <= position.minScrollExtent + 12) {
          atScrollStart = true;
        }
        continue;
      }
      final delta = pixels - lastPixels;
      _lastScrollPixelsByPosition[position] = pixels;

      if (pixels <= position.minScrollExtent + 12) {
        atScrollStart = true;
      } else if (delta > 10) {
        movedDown = true;
      } else if (delta < -8) {
        movedUp = true;
      }
    }

    if (atScrollStart) {
      if (!_scrollVisible) setState(() => _scrollVisible = true);
    } else if (movedUp && !_scrollVisible) {
      setState(() => _scrollVisible = true);
    } else if (movedDown && _scrollVisible) {
      setState(() => _scrollVisible = false);
    }
  }

  bool get _hasRoutePaths => widget.items.any((e) => e.routePath != null);

  int _resolveActiveIndex(OmniRouteNavigationBridge? bridge) {
    if (widget.items.isEmpty) return 0;
    final raw = widget.currentIndex ?? widget.controller?.index;
    if (raw != null) {
      return raw.clamp(0, widget.items.length - 1);
    }
    final loc = bridge?.currentLocation;
    if (loc != null && _hasRoutePaths) {
      final matched = _matchRouteIndex(loc);
      if (matched != null) return matched;
    }
    return 0;
  }

  int? _matchRouteIndex(String location) {
    final clean = _normalizeRoutePath(location);
    var bestIndex = -1;
    var bestLen = -1;
    for (var i = 0; i < widget.items.length; i++) {
      final route = widget.items[i].routePath;
      if (route == null || route.isEmpty) continue;
      final normalizedRoute = _normalizeRoutePath(route);
      if (clean == normalizedRoute) return i;
      if (widget.items[i].matchPrefix) {
        final prefix = normalizedRoute == '/'
            ? normalizedRoute
            : '$normalizedRoute/';
        if (clean.startsWith(prefix) && normalizedRoute.length > bestLen) {
          bestIndex = i;
          bestLen = normalizedRoute.length;
        }
      }
    }
    return bestIndex >= 0 ? bestIndex : null;
  }

  String _normalizeRoutePath(String path) {
    var normalized = path.split('?').first.split('#').first;
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  void _animateToIndex(int target) {
    if (widget.items.isEmpty) return;
    final clamped = target.clamp(0, widget.items.length - 1).toDouble();
    if (_toIndex == clamped) return;
    _lastTravelByItems[widget.items] = clamped;
    if (_reduceMotion) {
      _fromIndex = clamped;
      _toIndex = clamped;
      _travelCtrl.value = 1;
      return;
    }
    // Start from where the indicator is drawn right now (curve applied), so
    // an interrupted travel continues smoothly instead of jumping back.
    _fromIndex = _travelAt(_travelCtrl.value);
    _toIndex = clamped;
    _travelCtrl.forward(from: 0);
  }

  void _handleItemTap(
    int index,
    int activeIndex,
    _ResolvedNavLook look,
    OmniRouteNavigationBridge? bridge,
  ) {
    if (look.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    if (index == activeIndex) {
      widget.onReselect?.call(index);
    }
    if (widget.controller != null) {
      widget.controller!.select(index);
    }
    if (widget.onTap != null) {
      widget.onTap!(index);
      return;
    }
    final route = widget.items[index].routePath;
    if (route != null) {
      bridge?.onNavigate?.call(route);
    }
  }

  bool _shouldShowLabel(
    OmniBottomNavLabelMode mode,
    OmniBottomNavigationStyle style,
    bool selected,
  ) {
    return switch (mode) {
      OmniBottomNavLabelMode.alwaysShow => true,
      OmniBottomNavLabelMode.selectedOnly => selected,
      OmniBottomNavLabelMode.never => false,
      OmniBottomNavLabelMode.styleDefault => switch (style) {
        OmniBottomNavigationStyle.floatingBubble => selected,
        OmniBottomNavigationStyle.glowingDot => selected,
        _ => true,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final scrollController = widget.scrollController;
    if (widget.hideOnScroll && scrollController != null) {
      _scheduleScrollPositionSync(scrollController);
    }
    // Route-driven bars subscribe so a navigation reaches
    // didChangeDependencies (which retargets the indicator); bars driven by
    // an index or a controller only read the bridge for `onNavigate`.
    final subscribeRoute =
        widget.currentIndex == null &&
        widget.controller == null &&
        _hasRoutePaths;
    final bridge = subscribeRoute
        ? OmniRouteNavigationBridge.maybeOf(context)
        : OmniRouteNavigationBridge.readMaybeOf(context);
    final activeIndex = _activeIndex.clamp(0, widget.items.length - 1);
    final look = _ResolvedNavLook.resolve(context, widget);
    _travelCurve = look.indicatorCurve;
    if (_travelCtrl.duration != look.duration) {
      _travelCtrl.duration = look.duration;
    }

    final keyboardOpen =
        widget.hideOnKeyboard && MediaQuery.viewInsetsOf(context).bottom > 0;
    final visible =
        !keyboardOpen &&
        (widget.controller?.isVisible ?? true) &&
        (!widget.hideOnScroll || _scrollVisible);

    final safeBottom = widget.respectSafeArea
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;

    final rawContent = AnimatedBuilder(
      animation: _travelCtrl,
      builder: (context, _) {
        final travel = _travelAt(_travelCtrl.value);
        return _buildStyledShell(
          context: context,
          look: look,
          activeIndex: activeIndex,
          travelIndex: travel,
          safeBottom: safeBottom,
          bridge: bridge,
        );
      },
    );

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.15),
        duration: look.duration,
        curve: look.curve,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: Duration(
            milliseconds: (look.duration.inMilliseconds * 0.7).round(),
          ),
          // The indicator repaints every frame while it travels; keep that
          // from repainting the page behind the bar.
          child: RepaintBoundary(
            child: Material(type: MaterialType.transparency, child: rawContent),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledShell({
    required BuildContext context,
    required _ResolvedNavLook look,
    required int activeIndex,
    required double travelIndex,
    required double safeBottom,
    required OmniRouteNavigationBridge? bridge,
  }) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final resolvedMargin = look.margin.resolve(Directionality.of(context));

    return switch (look.style) {
      OmniBottomNavigationStyle.curvedNotch => _buildCurvedNotchBar(
        context: context,
        look: look,
        activeIndex: activeIndex,
        travelIndex: travelIndex,
        safeBottom: safeBottom,
        margin: resolvedMargin,
        rtl: rtl,
        bridge: bridge,
      ),
      OmniBottomNavigationStyle.centerFabNotch => _buildCenterFabNotchBar(
        context: context,
        look: look,
        activeIndex: activeIndex,
        safeBottom: safeBottom,
        margin: resolvedMargin,
        rtl: rtl,
        bridge: bridge,
      ),
      OmniBottomNavigationStyle.splitIsland => _buildSplitIslandBar(
        context: context,
        look: look,
        activeIndex: activeIndex,
        travelIndex: travelIndex,
        safeBottom: safeBottom,
        margin: resolvedMargin,
        rtl: rtl,
        bridge: bridge,
      ),
      OmniBottomNavigationStyle.floatingCircles => _buildFloatingCirclesBar(
        context: context,
        look: look,
        activeIndex: activeIndex,
        safeBottom: safeBottom,
        margin: resolvedMargin,
        bridge: bridge,
      ),
      _ => _buildStandardOrFloatingBar(
        context: context,
        look: look,
        activeIndex: activeIndex,
        travelIndex: travelIndex,
        safeBottom: safeBottom,
        margin: resolvedMargin,
        rtl: rtl,
        bridge: bridge,
      ),
    };
  }

  // ── 1. Standard Docked & Floating Card / Pill / Glass / Top / Material / iOS
  Widget _buildStandardOrFloatingBar({
    required BuildContext context,
    required _ResolvedNavLook look,
    required int activeIndex,
    required double travelIndex,
    required double safeBottom,
    required EdgeInsets margin,
    required bool rtl,
    required OmniRouteNavigationBridge? bridge,
  }) {
    final isFloating =
        look.style.isFloatingByDefault || margin != EdgeInsets.zero;
    final resolvedRadius = look.borderRadius > 0
        ? BorderRadius.circular(look.borderRadius)
        : BorderRadius.zero;
    final effectiveAction = widget.centerAction;
    final bottomInset = isFloating ? margin.bottom + safeBottom : 0.0;
    final innerSafeBottom = isFloating ? 0.0 : safeBottom;
    final totalHeight = look.height + innerSafeBottom;

    Widget rowContent = _buildInteractiveSlots(
      context: context,
      look: look,
      activeIndex: activeIndex,
      travelIndex: travelIndex,
      rtl: rtl,
      bridge: bridge,
      centerAction: effectiveAction,
    );

    if (look.style == OmniBottomNavigationStyle.topIndicator) {
      final slotCount = widget.items.length + (effectiveAction != null ? 1 : 0);
      final mappedIndex = _mapTabIndexWithCenterAction(
        travelIndex,
        widget.items.length,
        effectiveAction != null,
      );
      rowContent = Stack(
        children: [
          rowContent,
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final slotW = constraints.maxWidth / slotCount;
                  final normIndex = rtl
                      ? (slotCount - 1 - mappedIndex)
                      : mappedIndex;
                  final cx = slotW * (normIndex + 0.5);
                  return CustomPaint(
                    painter: _SpotlightGlowPainter(
                      centerX: cx,
                      barWidth: math.min(38.0, slotW * 0.56),
                      color:
                          widget.items[activeIndex].activeColor ??
                          look.glowColor,
                      isDark: look.isDark,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    Widget container = Container(
      height: totalHeight,
      padding: EdgeInsets.only(bottom: innerSafeBottom),
      decoration: BoxDecoration(
        color: look.backgroundGradient == null ? look.backgroundColor : null,
        gradient: look.backgroundGradient,
        borderRadius: resolvedRadius,
        border: look.borderWidth > 0
            ? (isFloating
                  ? Border.all(color: look.borderColor, width: look.borderWidth)
                  : Border(
                      top: BorderSide(
                        color: look.borderColor,
                        width: look.borderWidth,
                      ),
                    ))
            : null,
      ),
      child: Padding(padding: look.padding, child: rowContent),
    );

    if (look.useBlur) {
      container = ClipRRect(
        borderRadius: resolvedRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: look.blurSigma,
            sigmaY: look.blurSigma,
          ),
          child: container,
        ),
      );
    } else if (resolvedRadius != BorderRadius.zero) {
      container = ClipRRect(borderRadius: resolvedRadius, child: container);
    }

    if (look.shadows.isNotEmpty) {
      container = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: resolvedRadius,
          boxShadow: look.shadows,
        ),
        child: container,
      );
    }

    if (isFloating) {
      container = Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            margin.left,
            margin.top,
            margin.right,
            bottomInset,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: look.maxWidth),
            child: container,
          ),
        ),
      );
    }

    return container;
  }

  Widget _buildInteractiveSlots({
    required BuildContext context,
    required _ResolvedNavLook look,
    required int activeIndex,
    required double travelIndex,
    required bool rtl,
    required OmniRouteNavigationBridge? bridge,
    required OmniBottomNavigationAction? centerAction,
  }) {
    if (look.style == OmniBottomNavigationStyle.floatingBubble &&
        centerAction == null &&
        widget.itemBuilder == null) {
      return _buildBubbleExpandRow(
        context: context,
        look: look,
        activeIndex: activeIndex,
        bridge: bridge,
      );
    }

    final hasCenter = centerAction != null;
    final slotCount = widget.items.length + (hasCenter ? 1 : 0);
    final leftCount = widget.items.length ~/ 2;

    Widget buildSlotRow() {
      final children = <Widget>[];
      for (var i = 0; i < widget.items.length; i++) {
        if (hasCenter && i == leftCount) {
          children.add(
            Expanded(
              child: Center(
                child: _ActionOrbButton(
                  action: centerAction,
                  defaultColor: look.activeColor,
                  compact: true,
                ),
              ),
            ),
          );
        }
        final item = widget.items[i];
        final selected = i == activeIndex;
        final proximity = (1.0 - (travelIndex - i).abs()).clamp(0.0, 1.0);
        children.add(
          Expanded(
            child: _NavTabTapTarget(
              label: item.semanticLabel ?? item.label,
              tooltip: item.tooltip,
              selected: selected,
              enableScale: look.enableScaleAnimation,
              onTap: () => _handleItemTap(i, activeIndex, look, bridge),
              child: widget.itemBuilder != null
                  ? widget.itemBuilder!(context, item, selected, proximity)
                  : _buildStandardItemContent(
                      look: look,
                      item: item,
                      selected: selected,
                      proximity: proximity,
                      useContrastContent:
                          look.style == OmniBottomNavigationStyle.slidingPill,
                    ),
            ),
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (look.style == OmniBottomNavigationStyle.slidingPill) {
      final mappedTravel = _mapTabIndexWithCenterAction(
        travelIndex,
        widget.items.length,
        hasCenter,
      );
      final stretch =
          math.sin(_travelCtrl.value * math.pi).clamp(0.0, 1.0) * 0.24;
      final activeItem = widget.items[activeIndex];
      final pillColor = activeItem.indicatorColor ?? look.indicatorColor;

      return LayoutBuilder(
        builder: (_, constraints) {
          final slotW = constraints.maxWidth / slotCount;
          final visualIndex = rtl
              ? (slotCount - 1 - mappedTravel)
              : mappedTravel;
          final pillW = math.max(36.0, slotW * (0.88 + stretch));
          final pillLeft = (slotW * (visualIndex + 0.5) - pillW * 0.5)
              .clamp(0.0, math.max(0.0, constraints.maxWidth - pillW))
              .toDouble();
          return Stack(
            children: [
              Positioned(
                left: pillLeft,
                top: 2,
                bottom: 2,
                width: pillW,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: look.indicatorGradient == null ? pillColor : null,
                      gradient: look.indicatorGradient,
                      borderRadius: BorderRadius.circular(look.indicatorRadius),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: buildSlotRow()),
            ],
          );
        },
      );
    }

    return buildSlotRow();
  }

  Widget _buildBubbleExpandRow({
    required BuildContext context,
    required _ResolvedNavLook look,
    required int activeIndex,
    required OmniRouteNavigationBridge? bridge,
  }) {
    final count = widget.items.length;
    return LayoutBuilder(
      builder: (_, constraints) {
        final totalW = constraints.maxWidth;
        final selectedW = math.min(
          164.0,
          math.max(totalW / count + 22.0, totalW * (count <= 3 ? 0.44 : 0.36)),
        );
        final unselectedW = (totalW - selectedW) / math.max(1, count - 1);

        return Row(
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: look.duration,
                curve: look.curve,
                width: i == activeIndex ? selectedW : unselectedW,
                child: _NavTabTapTarget(
                  label: widget.items[i].semanticLabel ?? widget.items[i].label,
                  tooltip: widget.items[i].tooltip,
                  selected: i == activeIndex,
                  enableScale: look.enableScaleAnimation,
                  onTap: () => _handleItemTap(i, activeIndex, look, bridge),
                  child: _buildBubbleItem(
                    look: look,
                    item: widget.items[i],
                    selected: i == activeIndex,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBubbleItem({
    required _ResolvedNavLook look,
    required OmniBottomNavigationItem item,
    required bool selected,
  }) {
    final accent = item.activeColor ?? look.activeColor;
    final bubbleFill =
        item.indicatorColor ??
        (widget.indicatorColor ??
            accent.withValues(alpha: look.isDark ? 0.24 : 0.14));
    final showLabel = _shouldShowLabel(look.labelMode, look.style, selected);

    return Center(
      child: AnimatedContainer(
        duration: look.duration,
        curve: look.curve,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 12 : 8,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected && look.indicatorGradient == null
              ? bubbleFill
              : (selected ? null : Colors.transparent),
          gradient: selected ? look.indicatorGradient : null,
          borderRadius: BorderRadius.circular(look.indicatorRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadgedIcon(
              item: item,
              look: look,
              selected: selected,
              color: selected ? accent : look.inactiveColor,
              size: selected ? look.selectedIconSize : look.iconSize,
            ),
            if (showLabel && selected) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: look.selectedLabelStyle.copyWith(color: accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 2. Curved Wave Notch + Popped Orb ──────────────────────────────────────
  Widget _buildCurvedNotchBar({
    required BuildContext context,
    required _ResolvedNavLook look,
    required int activeIndex,
    required double travelIndex,
    required double safeBottom,
    required EdgeInsets margin,
    required bool rtl,
    required OmniRouteNavigationBridge? bridge,
  }) {
    const topHeadroom = 22.0;
    final isFloating = margin != EdgeInsets.zero;
    final barRadius = isFloating
        ? (look.borderRadius > 0 ? look.borderRadius : 28.0)
        : 0.0;
    final innerSafeBottom = isFloating ? 0.0 : safeBottom;
    final totalHeight = topHeadroom + look.height + innerSafeBottom;
    final count = widget.items.length;

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          margin.left,
          margin.top,
          margin.right,
          isFloating ? margin.bottom + safeBottom : 0.0,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isFloating ? look.maxWidth : double.infinity,
          ),
          child: SizedBox(
            height: totalHeight,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final horizontalPad = look.padding.resolve(
                  Directionality.of(context),
                );
                final usableW = constraints.maxWidth - horizontalPad.horizontal;
                final slotW = usableW / count;
                final visualIndex = rtl
                    ? (count - 1 - travelIndex)
                    : travelIndex;
                final notchCx =
                    horizontalPad.left + slotW * (visualIndex + 0.5);
                final activeItem = widget.items[activeIndex];
                final orbColor =
                    activeItem.indicatorColor ??
                    activeItem.activeColor ??
                    look.activeColor;

                Widget waveBackground = CustomPaint(
                  size: Size(constraints.maxWidth, totalHeight),
                  painter: _CurvedNotchBarPainter(
                    notchCenterX: notchCx,
                    notchRadius: 31,
                    notchDepth: 26,
                    topOffset: topHeadroom,
                    cornerRadius: barRadius,
                    backgroundColor: look.backgroundColor,
                    backgroundGradient: look.backgroundGradient,
                    borderColor: look.borderColor,
                    borderWidth: look.borderWidth,
                    shadows: look.shadows,
                  ),
                );

                if (look.useBlur) {
                  waveBackground = ClipPath(
                    clipper: _CurvedNotchClipper(
                      notchCenterX: notchCx,
                      notchRadius: 31,
                      notchDepth: 26,
                      topOffset: topHeadroom,
                      cornerRadius: barRadius,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: look.blurSigma,
                        sigmaY: look.blurSigma,
                      ),
                      child: waveBackground,
                    ),
                  );
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: waveBackground),
                    Positioned.fill(
                      top: topHeadroom,
                      bottom: innerSafeBottom,
                      left: horizontalPad.left,
                      right: horizontalPad.right,
                      child: Row(
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: _NavTabTapTarget(
                                label:
                                    widget.items[i].semanticLabel ??
                                    widget.items[i].label,
                                tooltip: widget.items[i].tooltip,
                                selected: i == activeIndex,
                                enableScale: look.enableScaleAnimation,
                                onTap: () => _handleItemTap(
                                  i,
                                  activeIndex,
                                  look,
                                  bridge,
                                ),
                                child: widget.itemBuilder != null
                                    ? widget.itemBuilder!(
                                        context,
                                        widget.items[i],
                                        i == activeIndex,
                                        i == activeIndex ? 1.0 : 0.0,
                                      )
                                    : _buildCurvedSlotLabel(
                                        look: look,
                                        item: widget.items[i],
                                        selected: i == activeIndex,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: notchCx - 25,
                      top: 2,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleItemTap(
                          activeIndex,
                          activeIndex,
                          look,
                          bridge,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: look.indicatorGradient == null
                                ? orbColor
                                : null,
                            gradient: look.indicatorGradient,
                            boxShadow: [
                              BoxShadow(
                                color: orbColor.withValues(alpha: 0.38),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: KeyedSubtree(
                                key: ValueKey(activeIndex),
                                child: _buildBadgedIcon(
                                  item: activeItem,
                                  look: look,
                                  selected: true,
                                  color: look.activeContentColor,
                                  size: look.selectedIconSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurvedSlotLabel({
    required _ResolvedNavLook look,
    required OmniBottomNavigationItem item,
    required bool selected,
  }) {
    final accent = item.activeColor ?? look.activeColor;
    final showLabel = _shouldShowLabel(look.labelMode, look.style, selected);
    if (selected) {
      if (!showLabel) return const SizedBox.shrink();
      return Align(
        alignment: const Alignment(0, 0.72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            item.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: look.selectedLabelStyle.copyWith(color: accent),
          ),
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBadgedIcon(
          item: item,
          look: look,
          selected: false,
          color: look.inactiveColor,
          size: look.iconSize,
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: look.labelStyle.copyWith(color: look.inactiveColor),
            ),
          ),
        ],
      ],
    );
  }

  // ── 3. Center Action Cradle Dock ───────────────────────────────────────────
  Widget _buildCenterFabNotchBar({
    required BuildContext context,
    required _ResolvedNavLook look,
    required int activeIndex,
    required double safeBottom,
    required EdgeInsets margin,
    required bool rtl,
    required OmniRouteNavigationBridge? bridge,
  }) {
    final action =
        widget.centerAction ??
        OmniBottomNavigationAction(
          icon: const Icon(Icons.add_rounded, size: 28),
          tooltip: 'Action',
          onPressed: () => widget.onReselect?.call(activeIndex),
        );
    final topHeadroom = math.max(20.0, action.size * 0.44);
    final isFloating = margin != EdgeInsets.zero;
    final barRadius = isFloating
        ? (look.borderRadius > 0 ? look.borderRadius : 28.0)
        : 0.0;
    final innerSafeBottom = isFloating ? 0.0 : safeBottom;
    final totalHeight = topHeadroom + look.height + innerSafeBottom;
    final leftCount = widget.items.length ~/ 2;
    final notchRadius = action.size * 0.62;
    final notchDepth = action.size * 0.52;

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          margin.left,
          margin.top,
          margin.right,
          isFloating ? margin.bottom + safeBottom : 0.0,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isFloating ? look.maxWidth : double.infinity,
          ),
          child: SizedBox(
            height: totalHeight,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final centerX = constraints.maxWidth * 0.5;
                Widget backdrop = CustomPaint(
                  size: Size(constraints.maxWidth, totalHeight),
                  painter: _CurvedNotchBarPainter(
                    notchCenterX: centerX,
                    notchRadius: notchRadius,
                    notchDepth: notchDepth,
                    topOffset: topHeadroom,
                    cornerRadius: barRadius,
                    backgroundColor: look.backgroundColor,
                    backgroundGradient: look.backgroundGradient,
                    borderColor: look.borderColor,
                    borderWidth: look.borderWidth,
                    shadows: look.shadows,
                  ),
                );
                if (look.useBlur) {
                  backdrop = ClipPath(
                    clipper: _CurvedNotchClipper(
                      notchCenterX: centerX,
                      notchRadius: notchRadius,
                      notchDepth: notchDepth,
                      topOffset: topHeadroom,
                      cornerRadius: barRadius,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: look.blurSigma,
                        sigmaY: look.blurSigma,
                      ),
                      child: backdrop,
                    ),
                  );
                }

                final slots = <Widget>[];
                for (var i = 0; i < widget.items.length; i++) {
                  if (i == leftCount) {
                    slots.add(SizedBox(width: notchRadius * 1.95));
                  }
                  final item = widget.items[i];
                  final selected = i == activeIndex;
                  slots.add(
                    Expanded(
                      child: _NavTabTapTarget(
                        label: item.semanticLabel ?? item.label,
                        tooltip: item.tooltip,
                        selected: selected,
                        enableScale: look.enableScaleAnimation,
                        onTap: () =>
                            _handleItemTap(i, activeIndex, look, bridge),
                        child: widget.itemBuilder != null
                            ? widget.itemBuilder!(
                                context,
                                item,
                                selected,
                                selected ? 1.0 : 0.0,
                              )
                            : _buildStandardItemContent(
                                look: look,
                                item: item,
                                selected: selected,
                                proximity: selected ? 1.0 : 0.0,
                                useContrastContent: false,
                              ),
                      ),
                    ),
                  );
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: backdrop),
                    Positioned(
                      left: centerX - action.size * 0.5,
                      top: 0,
                      width: action.size,
                      height: action.size,
                      child: _ActionOrbButton(
                        action: action,
                        defaultColor: look.activeColor,
                      ),
                    ),
                    Positioned.fill(
                      top: topHeadroom,
                      bottom: innerSafeBottom,
                      child: Padding(
                        padding: look.padding,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: slots,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. Split Dual Floating Islands ─────────────────────────────────────────
  Widget _buildSplitIslandBar({
    required BuildContext context,
    required _ResolvedNavLook look,
    required int activeIndex,
    required double travelIndex,
    required double safeBottom,
    required EdgeInsets margin,
    required bool rtl,
    required OmniRouteNavigationBridge? bridge,
  }) {
    final hasAction = widget.centerAction != null;
    final pillCount = hasAction ? widget.items.length : widget.items.length - 1;
    final pillItems = widget.items.take(pillCount).toList(growable: false);
    final pillRadius = BorderRadius.circular(look.borderRadius);
    final bottomInset = margin.bottom + safeBottom;
    final orbSize = math.min(look.height, 60.0);

    Widget buildOrb() {
      if (hasAction) {
        return _ActionOrbButton(
          action: widget.centerAction!,
          defaultColor: look.activeColor,
        );
      }
      final lastIdx = widget.items.length - 1;
      final lastItem = widget.items[lastIdx];
      final selected = activeIndex == lastIdx;
      final accent = lastItem.activeColor ?? look.activeColor;
      return _NavTabTapTarget(
        label: lastItem.semanticLabel ?? lastItem.label,
        tooltip: lastItem.tooltip ?? lastItem.label,
        selected: selected,
        enableScale: look.enableScaleAnimation,
        onTap: () => _handleItemTap(lastIdx, activeIndex, look, bridge),
        child: Container(
          width: orbSize,
          height: orbSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? accent : look.backgroundColor,
            border: look.borderWidth > 0
                ? Border.all(
                    color: selected ? accent : look.borderColor,
                    width: look.borderWidth,
                  )
                : null,
            boxShadow: look.shadows,
          ),
          child: Center(
            child: _buildBadgedIcon(
              item: lastItem,
              look: look,
              selected: selected,
              color: selected ? look.activeContentColor : look.inactiveColor,
              size: selected ? look.selectedIconSize : look.iconSize,
            ),
          ),
        ),
      );
    }

    Widget pillShell = Container(
      height: look.height,
      padding: look.padding,
      decoration: BoxDecoration(
        color: look.backgroundGradient == null ? look.backgroundColor : null,
        gradient: look.backgroundGradient,
        borderRadius: pillRadius,
        border: look.borderWidth > 0
            ? Border.all(color: look.borderColor, width: look.borderWidth)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < pillItems.length; i++)
            Expanded(
              child: _NavTabTapTarget(
                label: pillItems[i].semanticLabel ?? pillItems[i].label,
                tooltip: pillItems[i].tooltip,
                selected: i == activeIndex,
                enableScale: look.enableScaleAnimation,
                onTap: () => _handleItemTap(i, activeIndex, look, bridge),
                child: widget.itemBuilder != null
                    ? widget.itemBuilder!(
                        context,
                        pillItems[i],
                        i == activeIndex,
                        i == activeIndex ? 1.0 : 0.0,
                      )
                    : _buildStandardItemContent(
                        look: look,
                        item: pillItems[i],
                        selected: i == activeIndex,
                        proximity: i == activeIndex ? 1.0 : 0.0,
                        useContrastContent: false,
                      ),
              ),
            ),
        ],
      ),
    );

    if (look.useBlur) {
      pillShell = ClipRRect(
        borderRadius: pillRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: look.blurSigma,
            sigmaY: look.blurSigma,
          ),
          child: pillShell,
        ),
      );
    } else {
      pillShell = ClipRRect(borderRadius: pillRadius, child: pillShell);
    }

    if (look.shadows.isNotEmpty) {
      pillShell = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: pillRadius,
          boxShadow: look.shadows,
        ),
        child: pillShell,
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          margin.left,
          margin.top,
          margin.right,
          bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: look.maxWidth),
          child: Row(
            children: [
              Expanded(child: pillShell),
              const SizedBox(width: 12),
              buildOrb(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5. Modular Detached Floating Islands ───────────────────────────────────
  Widget _buildFloatingCirclesBar({
    required BuildContext context,
    required _ResolvedNavLook look,
    required int activeIndex,
    required double safeBottom,
    required EdgeInsets margin,
    required OmniRouteNavigationBridge? bridge,
  }) {
    final bottomInset = margin.bottom + safeBottom;
    final hasAction = widget.centerAction != null;
    final leftCount = widget.items.length ~/ 2;
    final surfaceCard =
        widget.backgroundColor ??
        (look.isDark ? const Color(0xFF1A202E) : Colors.white);

    final children = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      if (hasAction && i == leftCount) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ActionOrbButton(
              action: widget.centerAction!,
              defaultColor: look.activeColor,
              compact: true,
            ),
          ),
        );
      }
      final item = widget.items[i];
      final selected = i == activeIndex;
      final accent = item.activeColor ?? look.activeColor;
      final showLabel = _shouldShowLabel(look.labelMode, look.style, selected);

      children.add(
        Expanded(
          child: Padding(
            padding: look.padding,
            child: _NavTabTapTarget(
              label: item.semanticLabel ?? item.label,
              tooltip: item.tooltip,
              selected: selected,
              enableScale: look.enableScaleAnimation,
              onTap: () => _handleItemTap(i, activeIndex, look, bridge),
              child: AnimatedContainer(
                duration: look.duration,
                curve: look.curve,
                transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? (look.indicatorGradient == null
                            ? (item.indicatorColor ?? accent)
                            : null)
                      : surfaceCard,
                  gradient: selected ? look.indicatorGradient : null,
                  borderRadius: BorderRadius.circular(look.indicatorRadius),
                  border: Border.all(
                    color: selected ? Colors.transparent : look.borderColor,
                    width: look.borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? accent.withValues(alpha: 0.34)
                          : (look.isDark
                                ? const Color(0x36000000)
                                : const Color(0x140F172A)),
                      blurRadius: selected ? 18 : 10,
                      offset: Offset(0, selected ? 8 : 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBadgedIcon(
                      item: item,
                      look: look,
                      selected: selected,
                      color: selected
                          ? look.activeContentColor
                          : look.inactiveColor,
                      size: selected ? look.selectedIconSize : look.iconSize,
                    ),
                    if (showLabel) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (selected
                                    ? look.selectedLabelStyle
                                    : look.labelStyle)
                                .copyWith(
                                  color: selected
                                      ? look.activeContentColor
                                      : look.inactiveColor,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          margin.left,
          margin.top,
          margin.right,
          bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: look.maxWidth),
          child: SizedBox(
            height: look.height,
            child: Row(children: children),
          ),
        ),
      ),
    );
  }

  // ── Shared Tab Item Renderer ───────────────────────────────────────────────
  Widget _buildStandardItemContent({
    required _ResolvedNavLook look,
    required OmniBottomNavigationItem item,
    required bool selected,
    required double proximity,
    required bool useContrastContent,
  }) {
    final accent = item.activeColor ?? look.activeColor;
    final fg = selected
        ? (useContrastContent ? look.activeContentColor : accent)
        : look.inactiveColor;
    final showLabel = _shouldShowLabel(look.labelMode, look.style, selected);
    final isGlowingDot = look.style == OmniBottomNavigationStyle.glowingDot;
    final isM3 = look.style == OmniBottomNavigationStyle.materialPill;
    final hasTonalPill =
        look.style == OmniBottomNavigationStyle.floating ||
        look.style == OmniBottomNavigationStyle.glass;

    Widget icon = _buildBadgedIcon(
      item: item,
      look: look,
      selected: selected,
      color: fg,
      size: selected ? look.selectedIconSize : look.iconSize,
    );

    if (isM3 || hasTonalPill) {
      final pillColor = item.indicatorColor ?? look.indicatorColor;
      icon = Stack(
        alignment: Alignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.0 : 0.0,
            duration: look.duration,
            curve: look.indicatorCurve,
            child: AnimatedOpacity(
              opacity: selected ? 1.0 : 0.0,
              duration: Duration(
                milliseconds: (look.duration.inMilliseconds * 0.65).round(),
              ),
              child: Container(
                width: isM3 ? 60 : 50,
                height: isM3 ? 28 : 26,
                decoration: BoxDecoration(
                  color: look.indicatorGradient == null ? pillColor : null,
                  gradient: look.indicatorGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: icon,
          ),
        ],
      );
    }

    return Center(
      child: AnimatedContainer(
        duration: look.duration,
        curve: look.curve,
        transform: Matrix4.translationValues(
          0,
          isGlowingDot && selected ? -2.5 : 0,
          0,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            if (showLabel) ...[
              SizedBox(height: isM3 ? 3 : 2.5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: (selected ? look.selectedLabelStyle : look.labelStyle)
                      .copyWith(color: fg),
                ),
              ),
            ],
            if (isGlowingDot) ...[
              const SizedBox(height: 3),
              AnimatedScale(
                scale: selected ? 1.0 : 0.0,
                duration: look.duration,
                curve: look.indicatorCurve,
                child: Container(
                  width: 14,
                  height: 4,
                  decoration: BoxDecoration(
                    color: selected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.65),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadgedIcon({
    required OmniBottomNavigationItem item,
    required _ResolvedNavLook look,
    required bool selected,
    required Color color,
    required double size,
  }) {
    final rawIcon = selected ? (item.selectedIcon ?? item.icon) : item.icon;
    final themed = IconTheme.merge(
      data: IconThemeData(color: color, size: size),
      child: AnimatedScale(
        scale: selected && look.enableScaleAnimation ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: look.indicatorCurve,
        child: rawIcon,
      ),
    );

    final badgeText = item.resolvedBadgeLabel;
    if (badgeText == null && !item.showDotBadge) return themed;

    final badgeBg = item.badgeColor ?? look.badgeColor;
    final badgeFg = item.badgeTextColor ?? look.badgeTextColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        themed,
        if (badgeText != null)
          Positioned(
            right: -9,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: look.backgroundColor.a > 0.3
                      ? look.backgroundColor
                      : Colors.white,
                  width: 1.2,
                ),
              ),
              child: Text(
                badgeText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: badgeFg,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          )
        else
          Positioned(
            right: -3,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ),
      ],
    );
  }

  double _mapTabIndexWithCenterAction(
    double tabIndex,
    int itemCount,
    bool hasCenter,
  ) {
    if (!hasCenter) return tabIndex;
    final leftCount = itemCount ~/ 2;
    if (leftCount == 0) return tabIndex + 1.0;
    // Continuous across the centre slot: between the last left tab and the
    // first right tab the indicator glides over the action instead of
    // teleporting past it.
    final lastLeft = (leftCount - 1).toDouble();
    if (tabIndex <= lastLeft) return tabIndex;
    if (tabIndex >= leftCount) return tabIndex + 1.0;
    return lastLeft + (tabIndex - lastLeft) * 2.0;
  }
}

class _NavTabTapTarget extends StatefulWidget {
  const _NavTabTapTarget({
    required this.label,
    required this.selected,
    required this.enableScale,
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  final String label;
  final String? tooltip;
  final bool selected;
  final bool enableScale;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_NavTabTapTarget> createState() => _NavTabTapTargetState();
}

class _NavTabTapTargetState extends State<_NavTabTapTarget> {
  bool _pressed = false;

  void _setPressed(bool next) {
    if (_pressed != next && mounted) setState(() => _pressed = next);
  }

  @override
  Widget build(BuildContext context) {
    Widget body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: widget.enableScale
            ? AnimatedScale(
                scale: _pressed ? 0.90 : 1.0,
                duration: Duration(milliseconds: _pressed ? 80 : 200),
                curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
                child: widget.child,
              )
            : widget.child,
      ),
    );

    body = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.label,
        onTap: widget.onTap,
        child: body,
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      body = Tooltip(message: widget.tooltip!, child: body);
    }

    return body;
  }
}

class _ActionOrbButton extends StatefulWidget {
  const _ActionOrbButton({
    required this.action,
    required this.defaultColor,
    this.compact = false,
  });

  final OmniBottomNavigationAction action;
  final Color defaultColor;
  final bool compact;

  @override
  State<_ActionOrbButton> createState() => _ActionOrbButtonState();
}

class _ActionOrbButtonState extends State<_ActionOrbButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final diameter = widget.compact ? math.min(a.size, 46.0) : a.size;
    final bg = a.backgroundColor ?? widget.defaultColor;
    final isDarkBg =
        ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
    final fg = a.foregroundColor ?? (isDarkBg ? Colors.white : Colors.black);

    Widget btn = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        a.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: Duration(milliseconds: _pressed ? 85 : 210),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: ShapeDecoration(
            color: a.gradient == null ? bg : null,
            gradient: a.gradient,
            shape: a.shape ?? const CircleBorder(),
            shadows: [
              if (a.showGlow)
                BoxShadow(
                  color: bg.withValues(alpha: _pressed ? 0.24 : 0.42),
                  blurRadius: _pressed ? 8 : a.elevation * 1.8,
                  offset: Offset(0, _pressed ? 2 : 6),
                ),
            ],
          ),
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(color: fg, size: diameter * 0.46),
              child: a.icon,
            ),
          ),
        ),
      ),
    );

    btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: a.semanticLabel ?? a.tooltip ?? 'Primary Action',
        onTap: a.onPressed,
        child: btn,
      ),
    );

    if (a.tooltip != null && a.tooltip!.isNotEmpty) {
      btn = Tooltip(message: a.tooltip!, child: btn);
    }

    return btn;
  }
}
