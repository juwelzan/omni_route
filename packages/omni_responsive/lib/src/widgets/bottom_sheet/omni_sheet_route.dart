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

  @override
  late final _SheetConfig config = _SheetConfig(
    builder: route.builder,
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
  void settlePresence(double velocity) => _springPresence(
    presence,
    effectiveMotion,
    1,
    velocity,
    reduceMotion: reduceMotion,
  );

  @override
  Future<bool> dismiss(double velocity) async {
    route._popVelocity = velocity;
    await route.navigator?.maybePop<T>();
    final gone = !(route.isActive && route.isCurrent);
    if (!gone) route._popVelocity = null;
    return gone;
  }

  @override
  void close(Object? result) {
    final nav = route.navigator;
    if (nav == null || !route.isActive) return;
    if (route.isCurrent) {
      nav.pop<T>(result as T?);
    } else {
      nav.removeRoute(route, result as T?);
    }
  }

  @override
  void didChangeDetent(int index) {}

  @override
  void attachView(_OmniSheetViewState? view) {}
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
