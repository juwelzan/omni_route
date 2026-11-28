// Named constructor parameters stay public names; the fields are private.
// ignore_for_file: prefer_initializing_formals

part of 'omni_bottom_sheet.dart';

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
  WidgetBuilder? header,
  String? title,
  WidgetBuilder? trailing,
  bool? showCloseButton,
  OmniSheetScrolling scrolling = const OmniSheetScrolling(),
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
  _validateSheetConfig(
    detents: detents,
    initialDetent: initialDetent,
    cornerRadius: cornerRadius,
    maxWidth: maxWidth,
    motion: motion,
  );
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final resolved = style.resolve(_platformOf(context));
  return navigator.push(
    OmniSheetRoute<T>(
      builder: builder,
      header: header,
      title: title,
      trailing: trailing,
      showCloseButton: showCloseButton,
      scrolling: scrolling,
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
      barrierLabel: isDismissible
          ? _localizations(context)?.modalBarrierDismissLabel
          : null,
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
    this.header,
    this.title,
    this.trailing,
    this.showCloseButton,
    this.scrolling = const OmniSheetScrolling(),
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
  }) : _barrierColor = barrierColor,
       _barrierLabel = barrierLabel {
    _validateSheetConfig(
      detents: detents,
      initialDetent: initialDetent,
      cornerRadius: cornerRadius,
      maxWidth: maxWidth,
      motion: motion,
    );
  }

  /// Builds the sheet's content.
  final WidgetBuilder builder;

  /// A pinned header above the content: dragging it always moves the sheet,
  /// and a separator appears under it while the content is scrolled.
  final WidgetBuilder? header;

  /// Optional centered iOS navigation title shown beside the close button.
  final String? title;

  /// Optional trailing action balanced symmetrically across from the close button.
  final WidgetBuilder? trailing;

  /// Shows the circular iOS-style close (`×`) button in the top bar
  /// (defaults to `true` when [style] is [OmniSheetStyle.floating] and
  /// [isDismissible] is `true`, or whenever [title] is provided cleanly).
  final bool? showCloseButton;

  /// How scroll views inside behave.
  final OmniSheetScrolling scrolling;

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
  bool _closing = false;
  bool _dismissInFlight = false;

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

  late final _RouteSheetHost<T> _host = _RouteSheetHost<T>(this);

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
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute != null) {
      _host._view?._cancelDragAndSnap();
    }
  }

  @override
  bool didPop(T? result) {
    _closing = true;
    _host._view?._cancelDrag();
    return super.didPop(result);
  }

  @override
  void didComplete(T? result) {
    _closing = true;
    _host._view?._cancelDrag();
    super.didComplete(result);
  }

  @override
  void dispose() {
    _closing = true;
    _host._view = null;
    super.dispose();
  }

  @override
  Color? get barrierColor {
    if (_barrierColor != null) return _barrierColor;
    final nav = navigator;
    return nav != null
        ? _defaultBarrierColor(nav.context, _style)
        : const Color(0x66000000);
  }

  @override
  bool get barrierDismissible => isDismissible;

  @override
  String? get barrierLabel {
    if (!isDismissible) return null;
    if (_barrierLabel != null) return _barrierLabel;
    final nav = navigator;
    return (nav != null
            ? _localizations(nav.context)?.modalBarrierDismissLabel
            : null) ??
        'Dismiss';
  }

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

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final view = _OmniSheetView(host: _host);
    return capturedThemes?.wrap(view) ?? view;
  }
}

/// Connects [OmniSheetRoute] to the shared sheet view.
class _RouteSheetHost<T> implements _SheetHost {
  _RouteSheetHost(this.route);

  final OmniSheetRoute<T> route;
  _OmniSheetViewState? _view;

  @override
  late final _SheetConfig config = _SheetConfig(
    builder: route.builder,
    header: route.header,
    title: route.title,
    trailing: route.trailing,
    showCloseButton: route.showCloseButton,
    scrolling: route.scrolling,
    detents: route.detents,
    initialDetent: route.initialDetent,
    isDismissible: route.isDismissible,
    enableDrag: route.enableDrag,
    showHandle: route.showHandle,
    backgroundColor: route.backgroundColor,
    handleColor: route.handleColor,
    cornerRadius: route.cornerRadius,
    margin: route.margin,
    maxWidth: route.maxWidth,
    shadow: route.shadow,
    useSafeArea: route.useSafeArea,
    semanticLabel: route.semanticLabel,
  );

  @override
  OmniSheetStyle get effectiveStyle => route.effectiveStyle;

  @override
  OmniSheetMotion get effectiveMotion => route.effectiveMotion;

  @override
  AnimationController get presence => route._presence;

  @override
  bool get reduceMotion => route._reduceMotion;

  @override
  bool get isModal => true;

  @override
  bool get isClosing => route._closing || !route.isActive;

  @override
  void settlePresence(double velocity) {
    if (isClosing) return;
    _springPresence(
      presence,
      effectiveMotion,
      1,
      velocity,
      reduceMotion: reduceMotion,
    );
  }

  @override
  Future<bool> dismiss(double velocity) async {
    final nav = route.navigator;
    if (nav == null ||
        !route.isActive ||
        !route.isCurrent ||
        route._closing ||
        route._dismissInFlight) {
      return false;
    }
    _view?._cancelDrag();
    route._dismissInFlight = true;
    route._popVelocity = velocity;
    try {
      await nav.maybePop<T>();
      // Navigator.maybePop returns true even when PopScope vetoes the pop, so
      // check whether the route actually began leaving. Not `isCurrent`: a
      // PopScope that asks "Discard?" pushes a dialog on top, and the sheet
      // must still spring back behind it.
      final gone = !route.isActive || route._closing;
      if (!gone) route._popVelocity = null;
      return gone;
    } finally {
      route._dismissInFlight = false;
    }
  }

  @override
  void close(Object? result) {
    final nav = route.navigator;
    if (nav == null || !route.isActive || route._closing) return;
    route._closing = true;
    route._popVelocity = null;
    _view?._cancelDrag();
    if (route.isCurrent) {
      nav.pop<T>(result as T?);
    } else {
      nav.removeRoute(route, result as T?);
    }
  }

  @override
  void didChangeDetent(int index) {}

  @override
  void attachView(_OmniSheetViewState? view) => _view = view;
}

Color _defaultBarrierColor(BuildContext context, OmniSheetStyle style) {
  final omni = Theme.of(context).extension<OmniColors>();
  if (omni != null) return omni.overlayColor;
  final themed = Theme.of(context).bottomSheetTheme.modalBarrierColor;
  if (themed != null) return themed;
  return switch (style) {
    OmniSheetStyle.material => Colors.black54,
    OmniSheetStyle.floating => const Color(0x47000000),
    _ => const Color(0x66000000),
  };
}

TargetPlatform _platformOf(BuildContext context) => Theme.of(context).platform;

MaterialLocalizations? _localizations(BuildContext context) =>
    Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
