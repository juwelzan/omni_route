part of 'omni_bottom_sheet.dart';

/// A resizable sheet that lives on the page, over [body] — like the sheets
/// in Maps or Music. The page stays usable behind it.
///
/// ```dart
/// Scaffold(
///   body: OmniScalableSheet(
///     body: const MapView(),
///     detents: const [
///       OmniSheetDetent.height(140), // peek
///       OmniSheetDetent.medium,
///       OmniSheetDetent.large,
///     ],
///     initialDetent: 1,              // opens at medium
///     builder: (context) => ListView(children: [...]),
///   ),
/// )
/// ```
///
/// - Opens at [initialDetent] (animated when [animateOnOpen]) and rests
///   only on [detents]; it can't be dragged below the smallest or above the
///   largest (it stretches and springs back).
/// - Works in every [OmniSheetStyle] — `floating` keeps its margins.
/// - Scroll views inside drag the sheet, like the modal sheet.
/// - [dimFromDetent] dims the page as the sheet grows past that detent; a
///   tap on the dimmed page collapses it again.
/// - The back button collapses an expanded sheet first ([collapseOnBack]).
/// - Drive it with an [OmniScalableSheetController], or with
///   `OmniSheet.of(context)` from inside.
class OmniScalableSheet extends StatefulWidget {
  /// Creates the sheet over [body].
  const OmniScalableSheet({
    super.key,
    required this.body,
    required this.builder,
    this.header,
    this.title,
    this.trailing,
    this.showCloseButton,
    this.scrolling = const OmniSheetScrolling(),
    this.controller,
    this.style = OmniSheetStyle.adaptive,
    this.detents = const [
      OmniSheetDetent.fraction(0.25),
      OmniSheetDetent.medium,
      OmniSheetDetent.large,
    ],
    this.initialDetent = 0,
    this.animateOnOpen = true,
    this.isDismissible = false,
    this.enableDrag = true,
    this.showHandle,
    this.dimFromDetent,
    this.dimColor,
    this.collapseOnBack = true,
    this.backgroundColor,
    this.handleColor,
    this.cornerRadius,
    this.margin,
    this.maxWidth,
    this.shadow,
    this.motion,
    this.useSafeArea = true,
    this.semanticLabel,
    this.onDetentChanged,
    this.onDismissed,
  }) : assert(detents.length > 0, 'A sheet needs at least one detent.'),
       assert(initialDetent >= 0 && initialDetent < detents.length),
       assert(
         dimFromDetent == null ||
             (dimFromDetent >= 0 && dimFromDetent < detents.length),
       ),
       assert(cornerRadius == null || cornerRadius >= 0),
       assert(maxWidth == null || maxWidth > 0);

  /// The page behind the sheet.
  final Widget body;

  /// The sheet's content.
  final WidgetBuilder builder;

  /// A pinned header above the content: dragging it always moves the sheet,
  /// and a separator appears under it while the content is scrolled.
  final WidgetBuilder? header;

  /// Optional centered iOS navigation title shown beside the close button.
  final String? title;

  /// Optional trailing action balanced symmetrically across from the close button.
  final WidgetBuilder? trailing;

  /// Shows the circular iOS close button inside the sheet header.
  final bool? showCloseButton;

  /// How scroll views inside behave.
  final OmniSheetScrolling scrolling;

  /// Optional outside control (snap, expand, collapse, show, hide).
  final OmniScalableSheetController? controller;

  /// Look and motion preset.
  final OmniSheetStyle style;

  /// Sizes the sheet rests on, any order. The smallest is its minimum and
  /// the largest its maximum.
  final List<OmniSheetDetent> detents;

  /// Index into [detents] (in the given order) the sheet opens at.
  final int initialDetent;

  /// Slides up into place when first shown (otherwise appears in place).
  final bool animateOnOpen;

  /// Whether dragging below the smallest detent hides the sheet (bring it
  /// back with [OmniScalableSheetController.show]). Off by default: the
  /// sheet always stays on the page.
  final bool isDismissible;

  /// Whether the sheet (and scroll views in it) can be dragged.
  final bool enableDrag;

  /// Shows the drag handle / grabber (default: when [enableDrag]).
  final bool? showHandle;

  /// Index into [detents] (in the given order) from which the page dims (fully
  /// at the largest detent). `null` never dims.
  final int? dimFromDetent;

  /// Color of the dimming (default: the theme's overlay color).
  final Color? dimColor;

  /// The back button collapses the sheet to its smallest detent before it
  /// leaves the page.
  final bool collapseOnBack;

  /// Sheet color (default: theme).
  final Color? backgroundColor;

  /// Handle color (default: theme).
  final Color? handleColor;

  /// Corner radius (default per style).
  final double? cornerRadius;

  /// Space around a [OmniSheetStyle.floating] sheet.
  final EdgeInsets? margin;

  /// Widest the sheet gets on tablets and desktops; it is centered.
  final double? maxWidth;

  /// Shadow (default: floating only).
  final List<BoxShadow>? shadow;

  /// Spring and drag behaviour (default per style).
  final OmniSheetMotion? motion;

  /// Keeps the sheet out of system bars and notches.
  final bool useSafeArea;

  /// Screen reader name of the sheet.
  final String? semanticLabel;

  /// Called when the sheet comes to rest on (or heads to) a detent, with its
  /// index in [detents].
  final ValueChanged<int>? onDetentChanged;

  /// Called after a drag hid the sheet ([isDismissible] only).
  final VoidCallback? onDismissed;

  @override
  State<OmniScalableSheet> createState() => _OmniScalableSheetState();
}

/// Drives an [OmniScalableSheet] from outside its content.
class OmniScalableSheetController {
  final ValueNotifier<int> _detent = ValueNotifier(0);
  final ValueNotifier<bool> _shown = ValueNotifier(true);
  final _SheetHeight _height = _SheetHeight();
  _OmniScalableSheetState? _state;

  /// Whether a sheet is using this controller.
  bool get isAttached => _state != null;

  /// The detent the sheet rests on (or moves to), in [OmniScalableSheet.detents]
  /// order.
  ValueListenable<int> get detent => _detent;

  /// Whether the sheet is on screen.
  ValueListenable<bool> get isShown => _shown;

  /// Visible height of the sheet in logical pixels, every frame — for
  /// widgets that ride above it (a floating button, map padding). Listen
  /// with an `AnimatedBuilder`; nothing rebuilds unless you listen.
  ValueListenable<double> get height => _height;

  /// Animates to the detent at [index] (in [OmniScalableSheet.detents] order).
  Future<void> snapTo(int index) =>
      _state?._view?.snapTo(index) ?? Future<void>.value();

  /// Animates to the largest detent.
  Future<void> expand() =>
      _state?._view?._expand() ?? Future<void>.value();

  /// Animates to the smallest detent.
  Future<void> collapse() =>
      _state?._view?._collapse() ?? Future<void>.value();

  /// Brings a hidden sheet back.
  Future<void> show() => _state?._setShown(true) ?? Future<void>.value();

  /// Slides the sheet away (it can always be hidden from code).
  Future<void> hide() => _state?._setShown(false) ?? Future<void>.value();

  /// Releases the listenables. Call it when you created the controller.
  void dispose() {
    _detent.dispose();
    _shown.dispose();
    _height.dispose();
  }
}

/// The sheet's visible height, refreshed on every frame of a drag or
/// animation (paint-time value, no rebuilds).
class _SheetHeight extends ChangeNotifier implements ValueListenable<double> {
  double _value = 0;

  @override
  double get value => _value;

  void _update(double v) {
    if (v == _value) return;
    _value = v;
    notifyListeners();
  }
}

class _OmniScalableSheetState extends State<OmniScalableSheet>
    with SingleTickerProviderStateMixin
    implements _SheetHost {
  late final AnimationController _presence = AnimationController(
    vsync: this,
    value: widget.animateOnOpen ? 0 : 1,
  )..addListener(_relayHeight);
  OmniScalableSheetController? _ownController;
  OmniScalableSheetController get _controller =>
      widget.controller ?? (_ownController ??= OmniScalableSheetController());

  final ValueNotifier<bool> _dimmed = ValueNotifier(false);
  _OmniSheetViewState? _view;
  late OmniSheetStyle _style;
  late _SheetConfig _config = _buildConfig();
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _validateSheetConfig(
      detents: widget.detents,
      initialDetent: widget.initialDetent,
      dimFromDetent: widget.dimFromDetent,
      cornerRadius: widget.cornerRadius,
      maxWidth: widget.maxWidth,
      motion: widget.motion,
    );
    _controller._state = this;
    _controller._detent.value = widget.initialDetent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _style = widget.style.resolve(_platformOf(context));
    if (!_opened) {
      _opened = true;
      if (widget.animateOnOpen) {
        _springPresence(
          _presence,
          effectiveMotion,
          1,
          0,
          reduceMotion: reduceMotion,
        );
      }
    }
  }

  @override
  void didUpdateWidget(OmniScalableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateSheetConfig(
      detents: widget.detents,
      initialDetent: widget.initialDetent,
      dimFromDetent: widget.dimFromDetent,
      cornerRadius: widget.cornerRadius,
      maxWidth: widget.maxWidth,
      motion: widget.motion,
    );
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?._state = null;
      _controller._state = this;
    }
    _style = widget.style.resolve(_platformOf(context));
    _config = _buildConfig();
  }

  @override
  void dispose() {
    _controller._state = null;
    _ownController?.dispose();
    _presence.dispose();
    _dimmed.dispose();
    super.dispose();
  }

  _SheetConfig _buildConfig() => _SheetConfig(
    builder: widget.builder,
    header: widget.header,
    title: widget.title,
    trailing: widget.trailing,
    showCloseButton: widget.showCloseButton,
    scrolling: widget.scrolling,
    detents: widget.detents,
    initialDetent: widget.initialDetent,
    isDismissible: widget.isDismissible,
    enableDrag: widget.enableDrag,
    showHandle: widget.showHandle,
    backgroundColor: widget.backgroundColor,
    handleColor: widget.handleColor,
    cornerRadius: widget.cornerRadius,
    margin: widget.margin,
    maxWidth: widget.maxWidth,
    shadow: widget.shadow,
    useSafeArea: widget.useSafeArea,
    semanticLabel: widget.semanticLabel,
  );

  // ── _SheetHost ────────────────────────────────────────────────────────────

  @override
  _SheetConfig get config => _config;

  @override
  OmniSheetStyle get effectiveStyle => _style;

  @override
  OmniSheetMotion get effectiveMotion =>
      widget.motion ??
      (_style == OmniSheetStyle.material
          ? OmniSheetMotion.material
          : OmniSheetMotion.ios);

  @override
  AnimationController get presence => _presence;

  @override
  bool get reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  bool get isModal => false;

  @override
  void settlePresence(double velocity) => _springPresence(
    _presence,
    effectiveMotion,
    1,
    velocity,
    reduceMotion: reduceMotion,
  );

  @override
  Future<bool> dismiss(double velocity) async {
    if (!widget.isDismissible) return false;
    _controller._shown.value = false;
    await _springPresence(
      _presence,
      effectiveMotion,
      0,
      velocity,
      reduceMotion: reduceMotion,
    ).orCancel.catchError((Object _) {});
    if (mounted && !_controller._shown.value) widget.onDismissed?.call();
    return true;
  }

  @override
  void close(Object? result) => _setShown(false);

  @override
  void didChangeDetent(int index) {
    _controller._detent.value = index;
    widget.onDetentChanged?.call(index);
  }

  @override
  void attachView(_OmniSheetViewState? view) {
    if (identical(view, _view)) return;
    _view?._extent.removeListener(_relayHeight);
    _view = view;
    view?._extent.addListener(_relayHeight);
  }

  // ── Show / hide, dimming ─────────────────────────────────────────────────

  Future<void> _setShown(bool shown) async {
    if (_controller._shown.value == shown &&
        (shown ? 1.0 : 0.0) == _presence.value) {
      return;
    }
    _controller._shown.value = shown;
    await _springPresence(
      _presence,
      effectiveMotion,
      shown ? 1 : 0,
      0,
      reduceMotion: reduceMotion,
    ).orCancel.catchError((Object _) {});
  }

  /// 0–1 dimming of the page for the sheet's current height.
  double _dimAmount() {
    final from = widget.dimFromDetent;
    final view = _view;
    if (from == null || view == null) return 0;
    final metrics = view._metrics;
    final heights = metrics.heights;
    if (from < 0 || from >= metrics.publicToSorted.length) return 0;
    final sortedFrom = metrics.publicToSorted[from];
    if (heights.length <= sortedFrom) return 0;
    final start = heights[sortedFrom], end = heights.last;
    final extent = view._extent.value;
    final t = end > start
        ? ((extent - start) / (end - start)).clamp(0.0, 1.0)
        : (extent >= end ? 1.0 : 0.0);
    return t * _presence.value;
  }

  bool _relayQueued = false;

  void _relayHeight() {
    final view = _view;
    if (view == null) return;
    // The sheet's size is first known (and set) during layout; listeners
    // that rebuild must hear about it after the frame, not inside it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_relayQueued) return;
      _relayQueued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _relayQueued = false;
        if (mounted) _relayHeight();
      });
      return;
    }
    _controller._height._update(view._extent.value * _presence.value);
    if (widget.dimFromDetent != null) _dimmed.value = _dimAmount() > 0.01;
  }

  void _collapseFromBackdrop() {
    final from = widget.dimFromDetent ?? 0;
    _view?.snapTo(from);
  }

  bool _isAtSmallestDetent(int publicDetent) {
    final view = _view;
    if (view == null || view._metrics.heights.isEmpty) {
      return publicDetent == 0;
    }
    final metrics = view._metrics;
    if (publicDetent < 0 || publicDetent >= metrics.publicToSorted.length) {
      return false;
    }
    return metrics.publicToSorted[publicDetent] == 0;
  }

  late final Listenable _popScopeListenable = Listenable.merge([
    _controller._detent,
    _controller._shown,
  ]);

  @override
  Widget build(BuildContext context) {
    final omni = Theme.of(context).extension<OmniColors>();
    final dimColor =
        widget.dimColor ?? omni?.overlayColor ?? const Color(0x66000000);
    Widget stack = Stack(
      fit: StackFit.expand,
      children: [
        widget.body,
        if (widget.dimFromDetent != null)
          ValueListenableBuilder<bool>(
            valueListenable: _dimmed,
            builder: (context, dimmed, child) => IgnorePointer(
              ignoring: !dimmed,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _collapseFromBackdrop,
                child: child,
              ),
            ),
            child: CustomPaint(
              painter: _DimPainter(
                color: dimColor,
                amount: _dimAmount,
                repaint: Listenable.merge([_presence, _controller._height]),
              ),
            ),
          ),
        _OmniSheetView(host: this),
      ],
    );
    if (widget.collapseOnBack) {
      stack = ListenableBuilder(
        listenable: _popScopeListenable,
        builder: (context, child) => PopScope(
          canPop:
              !_controller._shown.value ||
              _isAtSmallestDetent(_controller._detent.value),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _view?._collapse();
          },
          child: child!,
        ),
        child: stack,
      );
    }
    return stack;
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter({
    required this.color,
    required this.amount,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Color color;
  final double Function() amount;

  @override
  void paint(Canvas canvas, Size size) {
    final a = amount();
    if (a <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: color.a * a),
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.color != color;
}
