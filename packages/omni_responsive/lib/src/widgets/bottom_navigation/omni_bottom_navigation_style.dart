part of 'omni_bottom_navigation.dart';

/// Visual layout and interaction mode for [OmniBottomNavigationBar],
/// inspired by modern mobile CollectUI / Dribbble bottom navigation patterns.
enum OmniBottomNavigationStyle {
  /// Screen-detached rounded floating card pill with layered ambient shadow,
  /// crisp rim border, spring icon bounce, and subtle active highlight.
  floating,

  /// Expanding horizontal bubble pill: inactive tabs stay compact as icons,
  /// while the selected tab smoothly expands into a colored pill showing both
  /// icon and label side by side.
  floatingBubble,

  /// Fluid morphing slider pill: a contrasting capsule slides across tabs with
  /// velocity-driven squash-and-stretch and inverted foreground tinting.
  slidingPill,

  /// Smooth cubic Bézier inward wave notch that travels cleanly along the bar
  /// while the selected icon rises into a floating circular orb above the dip.
  curvedNotch,

  /// Central symmetric concave Bézier cradle carved neatly around an elevated
  /// circular [OmniBottomNavigationAction] (`centerAction`) button.
  centerFabNotch,

  /// Modern dual floating island: main navigation pill on the left separated by
  /// a clean gap from a detached circular action orb on the right.
  splitIsland,

  /// Floating iOS liquid / frosted glass dock using real `BackdropFilter`
  /// blur, translucent surface tint, and top-lit specular refraction border.
  glass,

  /// Minimalist dock where a crisp glowing orb indicator (`BoxShadow` bloom)
  /// glides smoothly underneath the lifted active icon.
  glowingDot,

  /// Dashboard-inspired bar with a sliding rounded top accent bar and soft
  /// trapezoidal spotlight gradient cone illuminating the active tab.
  topIndicator,

  /// Modular CollectUI islands: each navigation item lives inside its own
  /// soft circular/squircle pill that lifts and illuminates when selected.
  floatingCircles,

  /// Material 3 expressive docked bar with center-expanding tonal stadium
  /// indicator and outlined-to-filled icon crossfade.
  materialPill,

  /// Native iOS translucent hairline tab bar with crisp SF proportions and
  /// light tactile tap scale.
  cupertino;

  /// Whether this style detaches from the bottom screen edge by default.
  bool get isFloatingByDefault => switch (this) {
    OmniBottomNavigationStyle.floating ||
    OmniBottomNavigationStyle.floatingBubble ||
    OmniBottomNavigationStyle.slidingPill ||
    OmniBottomNavigationStyle.splitIsland ||
    OmniBottomNavigationStyle.glass ||
    OmniBottomNavigationStyle.glowingDot ||
    OmniBottomNavigationStyle.floatingCircles => true,
    OmniBottomNavigationStyle.curvedNotch ||
    OmniBottomNavigationStyle.centerFabNotch ||
    OmniBottomNavigationStyle.topIndicator ||
    OmniBottomNavigationStyle.materialPill ||
    OmniBottomNavigationStyle.cupertino => false,
  };

  /// Human-readable preset title for theme/style switchers.
  String get label => switch (this) {
    OmniBottomNavigationStyle.floating => 'Floating Pill',
    OmniBottomNavigationStyle.floatingBubble => 'Bubble Expand',
    OmniBottomNavigationStyle.slidingPill => 'Sliding Morph Pill',
    OmniBottomNavigationStyle.curvedNotch => 'Curved Wave Notch',
    OmniBottomNavigationStyle.centerFabNotch => 'Center FAB Cradle',
    OmniBottomNavigationStyle.splitIsland => 'Split Island',
    OmniBottomNavigationStyle.glass => 'Liquid Glass',
    OmniBottomNavigationStyle.glowingDot => 'Glowing Dot',
    OmniBottomNavigationStyle.topIndicator => 'Top Spotlight',
    OmniBottomNavigationStyle.floatingCircles => 'Floating Islands',
    OmniBottomNavigationStyle.materialPill => 'Material 3 Pill',
    OmniBottomNavigationStyle.cupertino => 'Cupertino Bar',
  };
}

/// Controls when item text labels are displayed in [OmniBottomNavigationBar].
enum OmniBottomNavLabelMode {
  /// Automatically uses the authentic label convention of the chosen
  /// [OmniBottomNavigationStyle].
  styleDefault,

  /// Always shows concise labels for all tabs.
  alwaysShow,

  /// Shows the label only for the currently selected tab.
  selectedOnly,

  /// Hides all labels for an ultra-minimal icon-only bar.
  never,
}

/// Describes one tab destination inside an [OmniBottomNavigationBar].
@immutable
class OmniBottomNavigationItem {
  /// Creates a navigation item with an [icon] and concise [label].
  const OmniBottomNavigationItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.tooltip,
    this.routePath,
    this.matchPrefix = false,
    this.badgeText,
    this.badgeCount,
    this.showDotBadge = false,
    this.activeColor,
    this.indicatorColor,
    this.badgeColor,
    this.badgeTextColor,
    this.semanticLabel,
  });

  /// Default icon displayed when unselected.
  final Widget icon;

  /// Optional icon displayed when selected (falls back to [icon]).
  final Widget? selectedIcon;

  /// Short tab label.
  final String label;

  /// Optional hover/long-press tooltip.
  final String? tooltip;

  /// Optional route path (e.g. `'/home'`) used to automatically highlight the
  /// matching tab and navigate when `currentIndex` / `onTap` are omitted inside
  /// `OmniApp` / `OmniPage`.
  final String? routePath;

  /// When `true`, nested sub-routes sharing [routePath] as a segment prefix
  /// still mark this tab selected (e.g. `'/students'` matches `'/students/12'`).
  final bool matchPrefix;

  /// Custom badge text rendered on the icon corner (takes precedence over
  /// [badgeCount]).
  final String? badgeText;

  /// Numeric unread badge count (`0` or negative hides the badge; `> 99` shows
  /// `'99+'`).
  final int? badgeCount;

  /// Renders a clean minimal notification dot when `true` and no text/count
  /// badge is active.
  final bool showDotBadge;

  /// Optional per-item accent color used when this tab is selected.
  final Color? activeColor;

  /// Optional per-item indicator pill / spotlight / wave background color.
  final Color? indicatorColor;

  /// Optional per-item badge fill color override.
  final Color? badgeColor;

  /// Optional per-item badge text color override.
  final Color? badgeTextColor;

  /// Screen-reader label override (defaults to [label]).
  final String? semanticLabel;

  /// Formatted badge text or `null` when no text badge should display.
  String? get resolvedBadgeLabel {
    if (badgeText != null && badgeText!.isNotEmpty) return badgeText;
    final count = badgeCount;
    if (count == null || count <= 0) return null;
    return count > 99 ? '99+' : '$count';
  }
}

/// Optional center or detached circular action CTA integrated into
/// [OmniBottomNavigationBar] (e.g. scan, add `+`, compose, pay).
@immutable
class OmniBottomNavigationAction {
  /// Creates an integrated circular/squircle action button.
  const OmniBottomNavigationAction({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.gradient,
    this.size = 56,
    this.elevation = 10,
    this.shape,
    this.showGlow = true,
  });

  /// Primary icon shown inside the button.
  final Widget icon;

  /// Callback invoked when tapped.
  final VoidCallback onPressed;

  /// Hover/long-press tooltip.
  final String? tooltip;

  /// Accessibility label for screen readers.
  final String? semanticLabel;

  /// Solid background fill when [gradient] is `null`.
  final Color? backgroundColor;

  /// Foreground icon tint (defaults to high-contrast white/onPrimary).
  final Color? foregroundColor;

  /// Optional gradient fill for CollectUI-style glowing primary buttons.
  final Gradient? gradient;

  /// Diameter of the button (default `56`).
  final double size;

  /// Shadow elevation blur radius control.
  final double elevation;

  /// Custom button shape (defaults to circular).
  final ShapeBorder? shape;

  /// Whether to render a colored ambient glow beneath the action orb.
  final bool showGlow;
}

/// Programmatic controller to switch active tabs or toggle scroll visibility
/// of an [OmniBottomNavigationBar].
class OmniBottomNavigationController extends ChangeNotifier {
  /// Creates a controller starting at [initialIndex] and visibility [visible].
  OmniBottomNavigationController({int initialIndex = 0, bool visible = true})
    : _index = initialIndex < 0 ? 0 : initialIndex,
      _isVisible = visible;

  int _index;
  int? _itemCount;
  bool _isVisible;
  bool _disposed = false;

  /// Currently selected tab index.
  int get index => _index;

  /// Whether the navigation bar is currently revealed.
  bool get isVisible => _isVisible;

  void _syncItemCount(int itemCount) {
    _itemCount = itemCount;
    if (_disposed) return;
    final nextIndex = itemCount == 0 ? 0 : _index.clamp(0, itemCount - 1);
    if (nextIndex != _index) {
      _index = nextIndex;
      notifyListeners();
    }
  }

  /// Switches programmatically to tab [index] and reveals the bar if hidden.
  void select(int index) {
    if (_disposed) return;
    final nextIndex = switch (_itemCount) {
      null => index < 0 ? 0 : index,
      0 => 0,
      final count => index.clamp(0, count - 1),
    };
    if (_index == nextIndex && _isVisible) return;
    _index = nextIndex;
    _isVisible = true;
    notifyListeners();
  }

  /// Shows the navigation bar smoothly.
  void show() {
    if (_disposed || _isVisible) return;
    _isVisible = true;
    notifyListeners();
  }

  /// Slides the navigation bar cleanly out of view.
  void hide() {
    if (_disposed || !_isVisible) return;
    _isVisible = false;
    notifyListeners();
  }

  /// Toggles bar visibility cleanly.
  void toggleVisible() => _isVisible ? hide() : show();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Reusable theme extension and styling bundle for [OmniBottomNavigationBar].
///
/// Can be passed directly via `OmniBottomNavigationBar(theme: ...)` or
/// registered on `ThemeData(extensions: [OmniBottomNavigationStyleData(...)])`.
@immutable
class OmniBottomNavigationStyleData
    extends ThemeExtension<OmniBottomNavigationStyleData> {
  /// Creates a reusable bottom navigation style configuration.
  const OmniBottomNavigationStyleData({
    this.style,
    this.labelMode,
    this.backgroundColor,
    this.darkBackgroundColor,
    this.backgroundGradient,
    this.darkBackgroundGradient,
    this.activeColor,
    this.darkActiveColor,
    this.inactiveColor,
    this.darkInactiveColor,
    this.indicatorColor,
    this.darkIndicatorColor,
    this.indicatorGradient,
    this.activeContentColor,
    this.borderColor,
    this.darkBorderColor,
    this.borderWidth,
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
    this.badgeColor,
    this.badgeTextColor,
    this.glowColor,
    this.animationDuration,
    this.animationCurve,
    this.indicatorCurve,
    this.enableHaptics,
    this.enableScaleAnimation,
    this.notch,
  });

  /// Default style preset.
  final OmniBottomNavigationStyle? style;

  /// Default label display mode.
  final OmniBottomNavLabelMode? labelMode;

  /// Light mode bar surface color.
  final Color? backgroundColor;

  /// Dark mode bar surface color.
  final Color? darkBackgroundColor;

  /// Light mode bar background gradient.
  final Gradient? backgroundGradient;

  /// Dark mode bar background gradient.
  final Gradient? darkBackgroundGradient;

  /// Light mode selected icon & label color.
  final Color? activeColor;

  /// Dark mode selected icon & label color.
  final Color? darkActiveColor;

  /// Light mode unselected icon & label color.
  final Color? inactiveColor;

  /// Dark mode unselected icon & label color.
  final Color? darkInactiveColor;

  /// Light mode active indicator fill color.
  final Color? indicatorColor;

  /// Dark mode active indicator fill color.
  final Color? darkIndicatorColor;

  /// Gradient used for filled pill / wave orb / spotlight indicators.
  final Gradient? indicatorGradient;

  /// Foreground color of icons & text inside solid filled pills/orbs.
  final Color? activeContentColor;

  /// Light mode border color.
  final Color? borderColor;

  /// Dark mode border color.
  final Color? darkBorderColor;

  /// Hairline/card border thickness.
  final double? borderWidth;

  /// Base bar content height.
  final double? height;

  /// Outer floating margin.
  final EdgeInsetsGeometry? margin;

  /// Inner padding around tabs.
  final EdgeInsetsGeometry? padding;

  /// Outer container corner radius.
  final double? borderRadius;

  /// Active indicator corner radius.
  final double? indicatorRadius;

  /// Maximum width clamp for wide tablets & desktops.
  final double? maxWidth;

  /// Base unselected icon size.
  final double? iconSize;

  /// Selected icon size override.
  final double? selectedIconSize;

  /// Backdrop blur sigma for frosted/glass styles.
  final double? blurSigma;

  /// Optional background opacity multiplier (`0.0..1.0`).
  final double? backgroundOpacity;

  /// Forces backdrop blur even on non-glass styles.
  final bool? enableBlur;

  /// Custom drop shadows overriding defaults.
  final List<BoxShadow>? boxShadow;

  /// Shadow blur elevation hint.
  final double? elevation;

  /// Unselected label text style.
  final TextStyle? labelStyle;

  /// Selected label text style.
  final TextStyle? selectedLabelStyle;

  /// Badge background color.
  final Color? badgeColor;

  /// Badge label text color.
  final Color? badgeTextColor;

  /// Custom spotlight / glowing dot color.
  final Color? glowColor;

  /// Transition duration between tabs.
  final Duration? animationDuration;

  /// Curve used for bar visibility & crossfades.
  final Curve? animationCurve;

  /// Spring/bounce curve used for traveling indicators.
  final Curve? indicatorCurve;

  /// Enables light haptic selection ticks on tab changes.
  final bool? enableHaptics;

  /// Enables press-down micro-bounce on tab taps.
  final bool? enableScaleAnimation;

  /// Orb and cut-out of the notched styles.
  final OmniBottomNavigationNotch? notch;

  @override
  OmniBottomNavigationStyleData copyWith({
    OmniBottomNavigationStyle? style,
    OmniBottomNavLabelMode? labelMode,
    Color? backgroundColor,
    Color? darkBackgroundColor,
    Gradient? backgroundGradient,
    Gradient? darkBackgroundGradient,
    Color? activeColor,
    Color? darkActiveColor,
    Color? inactiveColor,
    Color? darkInactiveColor,
    Color? indicatorColor,
    Color? darkIndicatorColor,
    Gradient? indicatorGradient,
    Color? activeContentColor,
    Color? borderColor,
    Color? darkBorderColor,
    double? borderWidth,
    double? height,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double? borderRadius,
    double? indicatorRadius,
    double? maxWidth,
    double? iconSize,
    double? selectedIconSize,
    double? blurSigma,
    double? backgroundOpacity,
    bool? enableBlur,
    List<BoxShadow>? boxShadow,
    double? elevation,
    TextStyle? labelStyle,
    TextStyle? selectedLabelStyle,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? glowColor,
    Duration? animationDuration,
    Curve? animationCurve,
    Curve? indicatorCurve,
    bool? enableHaptics,
    bool? enableScaleAnimation,
    OmniBottomNavigationNotch? notch,
  }) => OmniBottomNavigationStyleData(
    style: style ?? this.style,
    labelMode: labelMode ?? this.labelMode,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    darkBackgroundColor: darkBackgroundColor ?? this.darkBackgroundColor,
    backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    darkBackgroundGradient:
        darkBackgroundGradient ?? this.darkBackgroundGradient,
    activeColor: activeColor ?? this.activeColor,
    darkActiveColor: darkActiveColor ?? this.darkActiveColor,
    inactiveColor: inactiveColor ?? this.inactiveColor,
    darkInactiveColor: darkInactiveColor ?? this.darkInactiveColor,
    indicatorColor: indicatorColor ?? this.indicatorColor,
    darkIndicatorColor: darkIndicatorColor ?? this.darkIndicatorColor,
    indicatorGradient: indicatorGradient ?? this.indicatorGradient,
    activeContentColor: activeContentColor ?? this.activeContentColor,
    borderColor: borderColor ?? this.borderColor,
    darkBorderColor: darkBorderColor ?? this.darkBorderColor,
    borderWidth: borderWidth ?? this.borderWidth,
    height: height ?? this.height,
    margin: margin ?? this.margin,
    padding: padding ?? this.padding,
    borderRadius: borderRadius ?? this.borderRadius,
    indicatorRadius: indicatorRadius ?? this.indicatorRadius,
    maxWidth: maxWidth ?? this.maxWidth,
    iconSize: iconSize ?? this.iconSize,
    selectedIconSize: selectedIconSize ?? this.selectedIconSize,
    blurSigma: blurSigma ?? this.blurSigma,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    enableBlur: enableBlur ?? this.enableBlur,
    boxShadow: boxShadow ?? this.boxShadow,
    elevation: elevation ?? this.elevation,
    labelStyle: labelStyle ?? this.labelStyle,
    selectedLabelStyle: selectedLabelStyle ?? this.selectedLabelStyle,
    badgeColor: badgeColor ?? this.badgeColor,
    badgeTextColor: badgeTextColor ?? this.badgeTextColor,
    glowColor: glowColor ?? this.glowColor,
    animationDuration: animationDuration ?? this.animationDuration,
    animationCurve: animationCurve ?? this.animationCurve,
    indicatorCurve: indicatorCurve ?? this.indicatorCurve,
    enableHaptics: enableHaptics ?? this.enableHaptics,
    enableScaleAnimation: enableScaleAnimation ?? this.enableScaleAnimation,
    notch: notch ?? this.notch,
  );

  @override
  OmniBottomNavigationStyleData lerp(
    covariant OmniBottomNavigationStyleData? other,
    double t,
  ) {
    if (other == null) return this;
    return OmniBottomNavigationStyleData(
      style: t < 0.5 ? style : other.style,
      labelMode: t < 0.5 ? labelMode : other.labelMode,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      darkBackgroundColor: Color.lerp(
        darkBackgroundColor,
        other.darkBackgroundColor,
        t,
      ),
      backgroundGradient: Gradient.lerp(
        backgroundGradient,
        other.backgroundGradient,
        t,
      ),
      darkBackgroundGradient: Gradient.lerp(
        darkBackgroundGradient,
        other.darkBackgroundGradient,
        t,
      ),
      activeColor: Color.lerp(activeColor, other.activeColor, t),
      darkActiveColor: Color.lerp(darkActiveColor, other.darkActiveColor, t),
      inactiveColor: Color.lerp(inactiveColor, other.inactiveColor, t),
      darkInactiveColor: Color.lerp(
        darkInactiveColor,
        other.darkInactiveColor,
        t,
      ),
      indicatorColor: Color.lerp(indicatorColor, other.indicatorColor, t),
      darkIndicatorColor: Color.lerp(
        darkIndicatorColor,
        other.darkIndicatorColor,
        t,
      ),
      indicatorGradient: Gradient.lerp(
        indicatorGradient,
        other.indicatorGradient,
        t,
      ),
      activeContentColor: Color.lerp(
        activeContentColor,
        other.activeContentColor,
        t,
      ),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      darkBorderColor: Color.lerp(darkBorderColor, other.darkBorderColor, t),
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t),
      height: lerpDouble(height, other.height, t),
      margin: EdgeInsetsGeometry.lerp(margin, other.margin, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t),
      indicatorRadius: lerpDouble(indicatorRadius, other.indicatorRadius, t),
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t),
      iconSize: lerpDouble(iconSize, other.iconSize, t),
      selectedIconSize: lerpDouble(selectedIconSize, other.selectedIconSize, t),
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t),
      backgroundOpacity: lerpDouble(
        backgroundOpacity,
        other.backgroundOpacity,
        t,
      ),
      enableBlur: t < 0.5 ? enableBlur : other.enableBlur,
      boxShadow: t < 0.5 ? boxShadow : other.boxShadow,
      elevation: lerpDouble(elevation, other.elevation, t),
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t),
      selectedLabelStyle: TextStyle.lerp(
        selectedLabelStyle,
        other.selectedLabelStyle,
        t,
      ),
      badgeColor: Color.lerp(badgeColor, other.badgeColor, t),
      badgeTextColor: Color.lerp(badgeTextColor, other.badgeTextColor, t),
      glowColor: Color.lerp(glowColor, other.glowColor, t),
      animationDuration: t < 0.5 ? animationDuration : other.animationDuration,
      animationCurve: t < 0.5 ? animationCurve : other.animationCurve,
      indicatorCurve: t < 0.5 ? indicatorCurve : other.indicatorCurve,
      enableHaptics: t < 0.5 ? enableHaptics : other.enableHaptics,
      enableScaleAnimation: t < 0.5
          ? enableScaleAnimation
          : other.enableScaleAnimation,
      notch: OmniBottomNavigationNotch.lerp(notch, other.notch, t),
    );
  }
}

/// Low-level InheritedWidget bridge allowing `omni_route`'s `OmniApp` to
/// expose the current route path and `go` callback to [OmniBottomNavigationBar]
/// without creating a package circular dependency.
class OmniRouteNavigationBridge extends InheritedWidget {
  /// Exposes [currentLocation] and [onNavigate] to nested navigation bars.
  const OmniRouteNavigationBridge({
    super.key,
    required this.currentLocation,
    required this.onNavigate,
    required super.child,
  });

  /// Current active route path (e.g. `'/students/101'`).
  final String? currentLocation;

  /// Callback used when tapping an item with [OmniBottomNavigationItem.routePath].
  final void Function(String path)? onNavigate;

  /// Subscribes to location updates from the nearest bridge above [context].
  static OmniRouteNavigationBridge? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniRouteNavigationBridge>();

  /// Reads the nearest bridge above [context] without subscribing.
  static OmniRouteNavigationBridge? readMaybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OmniRouteNavigationBridge>();

  @override
  bool updateShouldNotify(OmniRouteNavigationBridge oldWidget) =>
      oldWidget.currentLocation != currentLocation ||
      oldWidget.onNavigate != onNavigate;
}

class _ResolvedNavLook {
  const _ResolvedNavLook({
    required this.style,
    required this.labelMode,
    required this.isDark,
    required this.backgroundColor,
    required this.backgroundGradient,
    required this.activeColor,
    required this.inactiveColor,
    required this.indicatorColor,
    required this.indicatorGradient,
    required this.activeContentColor,
    required this.borderColor,
    required this.borderWidth,
    required this.glowColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.height,
    required this.margin,
    required this.padding,
    required this.borderRadius,
    required this.indicatorRadius,
    required this.maxWidth,
    required this.iconSize,
    required this.selectedIconSize,
    required this.blurSigma,
    required this.useBlur,
    required this.shadows,
    required this.labelStyle,
    required this.selectedLabelStyle,
    required this.duration,
    required this.curve,
    required this.indicatorCurve,
    required this.enableHaptics,
    required this.enableScaleAnimation,
    required this.notch,
  });

  final OmniBottomNavigationStyle style;
  final OmniBottomNavLabelMode labelMode;
  final bool isDark;
  final Color backgroundColor;
  final Gradient? backgroundGradient;
  final Color activeColor;
  final Color inactiveColor;
  final Color indicatorColor;
  final Gradient? indicatorGradient;
  final Color activeContentColor;
  final Color borderColor;
  final double borderWidth;
  final Color glowColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final double height;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double indicatorRadius;
  final double maxWidth;
  final double iconSize;
  final double selectedIconSize;
  final double blurSigma;
  final bool useBlur;
  final List<BoxShadow> shadows;
  final TextStyle labelStyle;
  final TextStyle selectedLabelStyle;
  final Duration duration;
  final Curve curve;
  final Curve indicatorCurve;
  final bool enableHaptics;
  final bool enableScaleAnimation;
  final OmniBottomNavigationNotch notch;

  static _ResolvedNavLook resolve(
    BuildContext context,
    OmniBottomNavigationBar widget,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final omni = theme.extension<OmniColors>();
    final ext = theme.extension<OmniBottomNavigationStyleData>();
    final inline = widget.theme;

    T? pick<T>(T? a, T? b, T? c) => a ?? b ?? c;

    final style =
        widget.style ??
        inline?.style ??
        ext?.style ??
        OmniBottomNavigationStyle.floating;
    final labelMode =
        widget.labelMode ??
        inline?.labelMode ??
        ext?.labelMode ??
        OmniBottomNavLabelMode.styleDefault;

    final basePrimary = omni?.primaryColor ?? theme.colorScheme.primary;
    final activeColor =
        pick(
          widget.activeColor,
          isDark ? inline?.darkActiveColor : inline?.activeColor,
          isDark ? ext?.darkActiveColor : ext?.activeColor,
        ) ??
        pick(null, inline?.activeColor, ext?.activeColor) ??
        omni?.navSelectedColor ??
        basePrimary;

    final inactiveColor =
        pick(
          widget.inactiveColor,
          isDark ? inline?.darkInactiveColor : inline?.inactiveColor,
          isDark ? ext?.darkInactiveColor : ext?.inactiveColor,
        ) ??
        pick(null, inline?.inactiveColor, ext?.inactiveColor) ??
        omni?.navUnselectedColor ??
        theme.colorScheme.onSurfaceVariant;

    final baseCard =
        omni?.navBarColor ??
        theme.navigationBarTheme.backgroundColor ??
        (isDark ? const Color(0xFF161B26) : Colors.white);

    Color defaultBg = switch (style) {
      OmniBottomNavigationStyle.glass =>
        isDark ? const Color(0xAA161B26) : const Color(0xB8FFFFFF),
      OmniBottomNavigationStyle.cupertino =>
        isDark ? const Color(0xD9161618) : const Color(0xE6F9F9FB),
      OmniBottomNavigationStyle.glowingDot =>
        isDark ? const Color(0xFF141821) : const Color(0xFFFFFFFF),
      OmniBottomNavigationStyle.floatingCircles => Colors.transparent,
      _ => baseCard,
    };

    var bg =
        pick(
          widget.backgroundColor,
          isDark ? inline?.darkBackgroundColor : inline?.backgroundColor,
          isDark ? ext?.darkBackgroundColor : ext?.backgroundColor,
        ) ??
        pick(null, inline?.backgroundColor, ext?.backgroundColor) ??
        defaultBg;

    final opacity = pick(
      widget.backgroundOpacity,
      inline?.backgroundOpacity,
      ext?.backgroundOpacity,
    );
    if (opacity != null) {
      bg = bg.withValues(alpha: opacity.clamp(0.0, 1.0));
    }

    final bgGradient =
        pick(
          widget.backgroundGradient,
          isDark ? inline?.darkBackgroundGradient : inline?.backgroundGradient,
          isDark ? ext?.darkBackgroundGradient : ext?.backgroundGradient,
        ) ??
        pick(null, inline?.backgroundGradient, ext?.backgroundGradient);

    final defaultIndicator = switch (style) {
      OmniBottomNavigationStyle.slidingPill ||
      OmniBottomNavigationStyle.curvedNotch ||
      OmniBottomNavigationStyle.floatingCircles => activeColor,
      _ =>
        omni?.navIndicatorColor ??
            activeColor.withValues(alpha: isDark ? 0.22 : 0.13),
    };

    final indicatorColor =
        pick(
          widget.indicatorColor,
          isDark ? inline?.darkIndicatorColor : inline?.indicatorColor,
          isDark ? ext?.darkIndicatorColor : ext?.indicatorColor,
        ) ??
        pick(null, inline?.indicatorColor, ext?.indicatorColor) ??
        defaultIndicator;

    final indicatorGradient = pick(
      widget.indicatorGradient,
      inline?.indicatorGradient,
      ext?.indicatorGradient,
    );

    final indicatorLum =
        ThemeData.estimateBrightnessForColor(indicatorColor) == Brightness.dark;
    final activeContentColor =
        pick(
          widget.activeContentColor,
          inline?.activeContentColor,
          ext?.activeContentColor,
        ) ??
        (indicatorLum ? Colors.white : const Color(0xFF0F172A));

    final borderColor =
        pick(
          widget.borderColor,
          isDark ? inline?.darkBorderColor : inline?.borderColor,
          isDark ? ext?.darkBorderColor : ext?.borderColor,
        ) ??
        pick(null, inline?.borderColor, ext?.borderColor) ??
        (style == OmniBottomNavigationStyle.glass
            ? (isDark ? const Color(0x38FFFFFF) : const Color(0xAAFFFFFF))
            : (isDark ? const Color(0x1EFFFFFF) : const Color(0x14000000)));

    final borderWidth =
        pick(widget.borderWidth, inline?.borderWidth, ext?.borderWidth) ??
        switch (style) {
          OmniBottomNavigationStyle.glass => 1.1,
          OmniBottomNavigationStyle.floating ||
          OmniBottomNavigationStyle.floatingBubble ||
          OmniBottomNavigationStyle.slidingPill ||
          OmniBottomNavigationStyle.splitIsland ||
          OmniBottomNavigationStyle.glowingDot ||
          OmniBottomNavigationStyle.floatingCircles => 0.9,
          OmniBottomNavigationStyle.materialPill ||
          OmniBottomNavigationStyle.cupertino ||
          OmniBottomNavigationStyle.topIndicator => 0.6,
          OmniBottomNavigationStyle.curvedNotch ||
          OmniBottomNavigationStyle.centerFabNotch => 0.7,
        };

    final borderRadius =
        pick(widget.borderRadius, inline?.borderRadius, ext?.borderRadius) ??
        switch (style) {
          OmniBottomNavigationStyle.floating ||
          OmniBottomNavigationStyle.floatingBubble ||
          OmniBottomNavigationStyle.slidingPill ||
          OmniBottomNavigationStyle.glass ||
          OmniBottomNavigationStyle.splitIsland => 30.0,
          OmniBottomNavigationStyle.glowingDot ||
          OmniBottomNavigationStyle.floatingCircles => 26.0,
          OmniBottomNavigationStyle.curvedNotch ||
          OmniBottomNavigationStyle.centerFabNotch ||
          OmniBottomNavigationStyle.topIndicator ||
          OmniBottomNavigationStyle.materialPill ||
          OmniBottomNavigationStyle.cupertino => 0.0,
        };

    final indicatorRadius =
        pick(
          widget.indicatorRadius,
          inline?.indicatorRadius,
          ext?.indicatorRadius,
        ) ??
        switch (style) {
          OmniBottomNavigationStyle.floatingCircles => 20.0,
          _ => 24.0,
        };

    final height =
        pick(widget.height, inline?.height, ext?.height) ??
        switch (style) {
          OmniBottomNavigationStyle.floating ||
          OmniBottomNavigationStyle.floatingBubble ||
          OmniBottomNavigationStyle.slidingPill ||
          OmniBottomNavigationStyle.glass ||
          OmniBottomNavigationStyle.splitIsland ||
          OmniBottomNavigationStyle.glowingDot ||
          OmniBottomNavigationStyle.floatingCircles => 66.0,
          OmniBottomNavigationStyle.curvedNotch ||
          OmniBottomNavigationStyle.centerFabNotch => 64.0,
          OmniBottomNavigationStyle.cupertino => 58.0,
          OmniBottomNavigationStyle.materialPill ||
          OmniBottomNavigationStyle.topIndicator => 68.0,
        };

    final margin =
        pick(widget.margin, inline?.margin, ext?.margin) ??
        (style.isFloatingByDefault
            ? const EdgeInsets.fromLTRB(16, 4, 16, 10)
            : EdgeInsets.zero);

    final padding =
        pick(widget.padding, inline?.padding, ext?.padding) ??
        switch (style) {
          OmniBottomNavigationStyle.floatingBubble ||
          OmniBottomNavigationStyle.slidingPill ||
          OmniBottomNavigationStyle.glass ||
          OmniBottomNavigationStyle.floating ||
          OmniBottomNavigationStyle.splitIsland => const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          OmniBottomNavigationStyle.floatingCircles =>
            const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          _ => const EdgeInsets.symmetric(horizontal: 8),
        };

    final elevation = pick(widget.elevation, inline?.elevation, ext?.elevation);
    final blurSigma =
        pick(widget.blurSigma, inline?.blurSigma, ext?.blurSigma) ?? 18.0;
    final useBlur =
        (pick(widget.enableBlur, inline?.enableBlur, ext?.enableBlur) ??
            false) ||
        style == OmniBottomNavigationStyle.glass ||
        style == OmniBottomNavigationStyle.cupertino;

    final defaultShadows =
        style.isFloatingByDefault &&
            style != OmniBottomNavigationStyle.floatingCircles
        ? [
            BoxShadow(
              color: isDark ? const Color(0x52000000) : const Color(0x1C0F172A),
              blurRadius: elevation ?? 26,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: isDark ? const Color(0x28000000) : const Color(0x0D0F172A),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
        : (style == OmniBottomNavigationStyle.curvedNotch ||
                  style == OmniBottomNavigationStyle.centerFabNotch
              ? [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x40000000)
                        : const Color(0x180F172A),
                    blurRadius: elevation ?? 18,
                    offset: const Offset(0, -4),
                  ),
                ]
              : const <BoxShadow>[]);

    final shadows =
        pick(widget.boxShadow, inline?.boxShadow, ext?.boxShadow) ??
        defaultShadows;

    final baseLabelStyle =
        pick(widget.labelStyle, inline?.labelStyle, ext?.labelStyle) ??
        (theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(
          fontSize: style == OmniBottomNavigationStyle.cupertino ? 10.5 : 11.5,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
          height: 1.1,
        );

    final selectedLabelStyle =
        pick(
          widget.selectedLabelStyle,
          inline?.selectedLabelStyle,
          ext?.selectedLabelStyle,
        ) ??
        baseLabelStyle.copyWith(fontWeight: FontWeight.w700);

    final textScaler = MediaQuery.textScalerOf(context);
    double labelLineHeight(TextStyle style) {
      final fontSize = style.fontSize ?? 11.5;
      return fontSize * (style.height ?? 1.0);
    }

    double scaledLabelLineHeight(TextStyle style) {
      final fontSize = style.fontSize ?? 11.5;
      return textScaler.scale(fontSize) * (style.height ?? 1.0);
    }

    final baseLabelHeight = math
        .max(
          labelLineHeight(baseLabelStyle),
          labelLineHeight(selectedLabelStyle),
        )
        .toDouble();
    final scaledLabelHeight = math
        .max(
          scaledLabelLineHeight(baseLabelStyle),
          scaledLabelLineHeight(selectedLabelStyle),
        )
        .toDouble();
    final scaledHeight = scaledLabelHeight > baseLabelHeight
        ? height + scaledLabelHeight - baseLabelHeight + 8
        : height;

    final iconSize =
        pick(widget.iconSize, inline?.iconSize, ext?.iconSize) ?? 23.0;
    final selectedIconSize =
        pick(
          widget.selectedIconSize,
          inline?.selectedIconSize,
          ext?.selectedIconSize,
        ) ??
        (iconSize + 1.5);

    return _ResolvedNavLook(
      style: style,
      labelMode: labelMode,
      isDark: isDark,
      backgroundColor: bg,
      backgroundGradient: bgGradient,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      indicatorColor: indicatorColor,
      indicatorGradient: indicatorGradient,
      activeContentColor: activeContentColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      glowColor:
          pick(widget.glowColor, inline?.glowColor, ext?.glowColor) ??
          activeColor,
      badgeColor:
          pick(widget.badgeColor, inline?.badgeColor, ext?.badgeColor) ??
          omni?.errorColor ??
          theme.colorScheme.error,
      badgeTextColor:
          pick(
            widget.badgeTextColor,
            inline?.badgeTextColor,
            ext?.badgeTextColor,
          ) ??
          Colors.white,
      height: scaledHeight,
      margin: margin,
      padding: padding,
      borderRadius: borderRadius,
      indicatorRadius: indicatorRadius,
      maxWidth: pick(widget.maxWidth, inline?.maxWidth, ext?.maxWidth) ?? 560.0,
      iconSize: iconSize,
      selectedIconSize: selectedIconSize,
      blurSigma: blurSigma,
      useBlur: useBlur,
      shadows: shadows,
      labelStyle: baseLabelStyle,
      selectedLabelStyle: selectedLabelStyle,
      duration:
          pick(
            widget.animationDuration,
            inline?.animationDuration,
            ext?.animationDuration,
          ) ??
          const Duration(milliseconds: 340),
      curve:
          pick(
            widget.animationCurve,
            inline?.animationCurve,
            ext?.animationCurve,
          ) ??
          Curves.easeOutCubic,
      indicatorCurve:
          pick(
            widget.indicatorCurve,
            inline?.indicatorCurve,
            ext?.indicatorCurve,
          ) ??
          Curves.easeOutBack,
      enableHaptics:
          pick(
            widget.enableHaptics,
            inline?.enableHaptics,
            ext?.enableHaptics,
          ) ??
          true,
      enableScaleAnimation:
          pick(
            widget.enableScaleAnimation,
            inline?.enableScaleAnimation,
            ext?.enableScaleAnimation,
          ) ??
          true,
      notch:
          pick(widget.notch, inline?.notch, ext?.notch) ??
          OmniBottomNavigationNotch.standard,
    );
  }
}
