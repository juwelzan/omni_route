import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'omni_responsive_config.dart';

/// Granular dependency aspects used by [OmniResponsiveScope] so widgets only
/// rebuild when the exact slice they consume changes.
enum _OmniResponsiveAspect {
  device,
  windowSize,
  orientation,
  compactHeight,
  tokens,
  metrics,
}

/// Immutable responsive viewport snapshot exposed by [OmniResponsiveScope].
@immutable
class OmniResponsiveData {
  /// Creates a responsive snapshot from [size] and [config].
  factory OmniResponsiveData.fromSize(
    Size size, {
    OmniResponsiveConfig config = const OmniResponsiveConfig(),
    Orientation? orientation,
  }) {
    final resolvedOrientation = orientation ??
        (size.width > size.height
            ? Orientation.landscape
            : Orientation.portrait);
    final device = config.deviceFor(size);
    final smallPhone = config.isSmallPhoneSize(size);
    final windowSize = config.windowSizeFor(size);
    final tokens = config.tokens.forTier(device, isSmallPhone: smallPhone);
    return OmniResponsiveData._(
      size: size,
      device: device,
      windowSize: windowSize,
      orientation: resolvedOrientation,
      isSmallPhone: smallPhone,
      tokens: tokens,
      config: config,
    );
  }

  const OmniResponsiveData._({
    required this.size,
    required this.device,
    required this.windowSize,
    required this.orientation,
    required this.isSmallPhone,
    required this.tokens,
    required this.config,
  });

  /// Current viewport logical dimensions.
  final Size size;

  /// Discrete semantic device tier (`mobile`, `tablet`, `desktop`, `largeDesktop`).
  final OmniDeviceType device;

  /// Material 3 width window size class (`compact` .. `extraLarge`).
  final OmniWindowSize windowSize;

  /// Viewport orientation derived solely from size/orientation (never from
  /// soft-keyboard insets).
  final Orientation orientation;

  /// True when width falls below `config.smallPhoneMaxWidth` inside mobile tier.
  final bool isSmallPhone;

  /// Cached constant design tokens for [device].
  final OmniResponsiveTokens tokens;

  /// Active configuration used to compute this snapshot.
  final OmniResponsiveConfig config;

  /// Viewport logical width.
  double get width => size.width;

  /// Viewport logical height.
  double get height => size.height;

  /// Smaller viewport dimension.
  double get shortestSide => size.shortestSide;

  /// True when vertical height is tight (`< 480dp`), such as on landscape phones
  /// or compact horizontal split panes.
  bool get isCompactHeight => size.height < 480;

  /// True when [device] is [OmniDeviceType.mobile].
  bool get isMobile => device == OmniDeviceType.mobile;

  /// True when [device] is [OmniDeviceType.tablet].
  bool get isTablet => device == OmniDeviceType.tablet;

  /// True when [device] is [OmniDeviceType.desktop].
  bool get isDesktop => device == OmniDeviceType.desktop;

  /// True when [device] is [OmniDeviceType.largeDesktop].
  bool get isLargeDesktop => device == OmniDeviceType.largeDesktop;

  /// True for [OmniDeviceType.tablet], [OmniDeviceType.desktop], or
  /// [OmniDeviceType.largeDesktop].
  bool get isTabletOrLarger => device != OmniDeviceType.mobile;

  /// True for [OmniDeviceType.desktop] or [OmniDeviceType.largeDesktop].
  bool get isDesktopOrLarger =>
      device == OmniDeviceType.desktop || device == OmniDeviceType.largeDesktop;

  /// True when [orientation] is portrait.
  bool get isPortrait => orientation == Orientation.portrait;

  /// True when [orientation] is landscape.
  bool get isLandscape => orientation == Orientation.landscape;

  /// Resolves a value per device tier with graceful downward fallback:
  /// `largeDesktop -> desktop -> tablet -> mobile`.
  T value<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) => switch (device) {
    OmniDeviceType.mobile => mobile,
    OmniDeviceType.tablet => tablet ?? mobile,
    OmniDeviceType.desktop => desktop ?? tablet ?? mobile,
    OmniDeviceType.largeDesktop => largeDesktop ?? desktop ?? tablet ?? mobile,
  };

  /// Resolves a grid column count for the current tier, falling back cleanly
  /// to [tokens.gridColumns] (including any custom [OmniResponsiveConfig] tokens).
  int columns({
    int? mobile,
    int? tablet,
    int? desktop,
    int? largeDesktop,
  }) => switch (device) {
    OmniDeviceType.mobile => mobile ?? tokens.gridColumns,
    OmniDeviceType.tablet => tablet ?? mobile ?? tokens.gridColumns,
    OmniDeviceType.desktop =>
      desktop ?? tablet ?? mobile ?? tokens.gridColumns,
    OmniDeviceType.largeDesktop =>
      largeDesktop ?? desktop ?? tablet ?? mobile ?? tokens.gridColumns,
  };

  /// Scales [base] using the coarse tier [OmniResponsiveTokens.scaleFactor].
  double scaled(double base) => tokens.scaled(base);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniResponsiveData &&
          size == other.size &&
          device == other.device &&
          windowSize == other.windowSize &&
          orientation == other.orientation &&
          isSmallPhone == other.isSmallPhone &&
          tokens == other.tokens &&
          config == other.config;

  @override
  int get hashCode => Object.hash(
    size,
    device,
    windowSize,
    orientation,
    isSmallPhone,
    tokens,
    config,
  );
}

/// Zero-overhead responsive coordinator built on Flutter's `InheritedModel`.
///
/// Key properties that preserve native 60/120fps performance:
/// 1. Reads only viewport size & orientation (`MediaQuery.maybeSizeOf` or
///    cached `FlutterView` dimensions in `didChangeMetrics`), completely
///    ignoring soft-keyboard `viewInsets`.
/// 2. Splits notifications by aspect (`device`, `windowSize`, `orientation`,
///    `compactHeight`, `tokens`, `metrics`) so intra-breakpoint resizes trigger
///    **zero** rebuilds on layout, token, or visibility dependents.
class OmniResponsiveScope extends StatefulWidget {
  /// Installs responsive aspect inheritance around [child].
  const OmniResponsiveScope({
    super.key,
    required this.child,
    this.config = const OmniResponsiveConfig(),
    this.minTextScale,
    this.maxTextScale,
  });

  /// Creates a local container-query scope measured from parent `BoxConstraints`
  /// via [LayoutBuilder] (ideal for Master-Detail split panes or drawers where
  /// a subtree's width is narrower than the overall window).
  ///
  /// When [config] is omitted, inherits the nearest ancestor
  /// [OmniResponsiveConfig] automatically so custom breakpoints and tokens apply
  /// inside sub-panes too.
  static Widget constrained({
    Key? key,
    required Widget child,
    OmniResponsiveConfig? config,
  }) => LayoutBuilder(
    key: key,
    builder: (context, constraints) {
      final resolvedConfig =
          config ?? maybeConfigOf(context) ?? const OmniResponsiveConfig();
      late final fallback =
          MediaQuery.maybeSizeOf(context) ?? const Size(390, 844);
      final w = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : fallback.width;
      final h = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : fallback.height;
      return _OmniResponsiveModel(
        data: OmniResponsiveData.fromSize(Size(w, h), config: resolvedConfig),
        child: child,
      );
    },
  );

  /// Reads the nearest ancestor [OmniResponsiveConfig] without subscribing to
  /// metrics jitter (`null` if no [OmniResponsiveScope] exists).
  static OmniResponsiveConfig? maybeConfigOf(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<_OmniResponsiveModel>()
          ?.data
          .config;

  /// Breakpoint & token configuration.
  final OmniResponsiveConfig config;

  /// Optional min text scale factor inherited by [OmniResponsiveTextScaleHost].
  final double? minTextScale;

  /// Optional max text scale factor inherited by [OmniResponsiveTextScaleHost].
  final double? maxTextScale;

  /// Descendant widget tree.
  final Widget child;

  /// Subscribes [context] to structural tier changes (`device`, `windowSize`,
  /// `orientation`, `compactHeight`, `tokens`) while ignoring pixel jitter
  /// inside a tier.
  static OmniResponsiveData of(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.device,
    );
    if (model != null) {
      InheritedModel.inheritFrom<_OmniResponsiveModel>(
        context,
        aspect: _OmniResponsiveAspect.windowSize,
      );
      InheritedModel.inheritFrom<_OmniResponsiveModel>(
        context,
        aspect: _OmniResponsiveAspect.orientation,
      );
      InheritedModel.inheritFrom<_OmniResponsiveModel>(
        context,
        aspect: _OmniResponsiveAspect.compactHeight,
      );
      InheritedModel.inheritFrom<_OmniResponsiveModel>(
        context,
        aspect: _OmniResponsiveAspect.tokens,
      );
      return model.data;
    }
    return _fallbackFromMediaQuery(context);
  }

  /// Returns [OmniResponsiveData] without throwing when no [OmniResponsiveScope]
  /// exists in [context], or `null` if neither scope nor `MediaQuery` exists.
  static OmniResponsiveData? maybeOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.device,
    );
    if (model != null) return model.data;
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null) return null;
    return OmniResponsiveData.fromSize(
      size,
      orientation: MediaQuery.maybeOrientationOf(context),
    );
  }

  /// Non-subscribing O(1) lookup safe inside `onPressed`, `initState`,
  /// `didUpdateWidget`, and `Page.createRoute` callbacks without registering an
  /// `InheritedWidget` dependency.
  static OmniResponsiveData read(BuildContext context) {
    final model = context.getInheritedWidgetOfExactType<_OmniResponsiveModel>();
    if (model != null) return model.data;
    final mqData = context.getInheritedWidgetOfExactType<MediaQuery>()?.data;
    if (mqData != null) {
      return OmniResponsiveData.fromSize(
        mqData.size,
        orientation: mqData.orientation,
      );
    }
    final view = context.findAncestorWidgetOfExactType<View>()?.view ??
        WidgetsBinding.instance.platformDispatcher.implicitView;
    final size = (view != null && view.devicePixelRatio > 0 && !view.physicalSize.isEmpty)
        ? view.physicalSize / view.devicePixelRatio
        : const Size(390, 844);
    return OmniResponsiveData.fromSize(size);
  }

  /// Subscribes [context] ONLY to [OmniDeviceType] changes (never rebuilds
  /// within the same breakpoint tier or on keyboard open/close).
  static OmniDeviceType deviceOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.device,
    );
    return (model?.data ?? _fallbackFromMediaQuery(context)).device;
  }

  /// Subscribes [context] ONLY to `isSmallPhone` / `device` tier changes.
  static bool isSmallPhoneOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.device,
    );
    return (model?.data ?? _fallbackFromMediaQuery(context)).isSmallPhone;
  }

  /// Subscribes [context] ONLY to Material 3 [OmniWindowSize] changes.
  static OmniWindowSize windowSizeOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.windowSize,
    );
    return (model?.data ?? _fallbackFromMediaQuery(context)).windowSize;
  }

  /// Subscribes [context] ONLY to viewport [Orientation] changes.
  static Orientation orientationOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.orientation,
    );
    return (model?.data ?? _fallbackFromMediaQuery(context)).orientation;
  }

  /// Subscribes [context] ONLY to whether height is compact (`< 480dp`).
  static bool isCompactHeightOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.compactHeight,
    );
    return (model?.data ?? _fallbackFromMediaQuery(context)).isCompactHeight;
  }

  /// Subscribes [context] ONLY to cached [OmniResponsiveTokens] changes.
  static OmniResponsiveTokens tokensOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.tokens,
    );
    return (model?.data ?? _fallbackFromMediaQuery(context)).tokens;
  }

  /// Explicit opt-in subscription to continuous viewport [Size] updates.
  /// Prefer [deviceOf], [windowSizeOf], or [tokensOf] whenever possible to
  /// avoid rebuilding on every resize pixel.
  static Size sizeOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.metrics,
    );
    if (model != null) return model.data.size;
    return MediaQuery.maybeSizeOf(context) ?? const Size(390, 844);
  }

  /// Reads the nearest config + text-scale clamp bounds without subscribing to
  /// metrics jitter (used internally by [OmniResponsiveTextScaleHost.fromScope]).
  static ({
    OmniResponsiveConfig config,
    double? minTextScale,
    double? maxTextScale,
  })?
  maybeScaleSettingsOf(BuildContext context) {
    final model = InheritedModel.inheritFrom<_OmniResponsiveModel>(
      context,
      aspect: _OmniResponsiveAspect.tokens,
    );
    if (model == null) return null;
    return (
      config: model.data.config,
      minTextScale: model.minTextScale,
      maxTextScale: model.maxTextScale,
    );
  }

  static OmniResponsiveData _fallbackFromMediaQuery(BuildContext context) {
    final size = MediaQuery.maybeSizeOf(context) ?? const Size(390, 844);
    final orientation = MediaQuery.maybeOrientationOf(context);
    return OmniResponsiveData.fromSize(size, orientation: orientation);
  }

  @override
  State<OmniResponsiveScope> createState() => _OmniResponsiveScopeState();
}

class _OmniResponsiveScopeState extends State<OmniResponsiveScope>
    with WidgetsBindingObserver {
  Size? _viewSize;
  ui.FlutterView? _cachedView;
  bool _hasAncestorMediaQuery = false;

  Size? _lastSize;
  Orientation? _lastOrientation;
  OmniResponsiveConfig? _lastConfig;
  OmniResponsiveData? _lastData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedView = context.findAncestorWidgetOfExactType<View>()?.view;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Size _readViewLogicalSize() {
    final view = _cachedView ??
        WidgetsBinding.instance.platformDispatcher.implicitView ??
        _firstView();
    if (view == null || view.devicePixelRatio <= 0 || view.physicalSize.isEmpty) {
      return const Size(390, 844);
    }
    return view.physicalSize / view.devicePixelRatio;
  }

  static ui.FlutterView? _firstView() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? null : views.first;
  }

  @override
  void didChangeMetrics() {
    // When an ancestor MediaQuery exists, `MediaQuery.maybeSizeOf` handles
    // size changes cleanly inside `build` without calling `dependOn...` here.
    // Otherwise check cached FlutterView logical size directly: keyboard open
    // (`viewInsets` only) keeps `physicalSize` identical -> zero `setState`.
    if (!mounted || _hasAncestorMediaQuery) return;
    final nextSize = _readViewLogicalSize();
    if (nextSize != _viewSize) {
      setState(() => _viewSize = nextSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mqSize = MediaQuery.maybeSizeOf(context);
    _hasAncestorMediaQuery = mqSize != null;
    final size = mqSize ?? (_viewSize ??= _readViewLogicalSize());
    final mqOrientation = mqSize != null
        ? MediaQuery.maybeOrientationOf(context)
        : null;
    final data = (_lastData != null &&
            _lastSize == size &&
            _lastOrientation == mqOrientation &&
            _lastConfig == widget.config)
        ? _lastData!
        : (_lastData = OmniResponsiveData.fromSize(
            _lastSize = size,
            config: _lastConfig = widget.config,
            orientation: _lastOrientation = mqOrientation,
          ));
    return _OmniResponsiveModel(
      data: data,
      minTextScale: widget.minTextScale,
      maxTextScale: widget.maxTextScale,
      child: widget.child,
    );
  }
}

class _OmniResponsiveModel extends InheritedModel<_OmniResponsiveAspect> {
  const _OmniResponsiveModel({
    required this.data,
    required super.child,
    this.minTextScale,
    this.maxTextScale,
  });

  final OmniResponsiveData data;
  final double? minTextScale;
  final double? maxTextScale;

  @override
  bool updateShouldNotify(covariant _OmniResponsiveModel oldWidget) =>
      oldWidget.data != data ||
      oldWidget.minTextScale != minTextScale ||
      oldWidget.maxTextScale != maxTextScale;

  @override
  bool updateShouldNotifyDependent(
    covariant _OmniResponsiveModel oldWidget,
    Set<_OmniResponsiveAspect> dependencies,
  ) {
    final prev = oldWidget.data;
    if (dependencies.contains(_OmniResponsiveAspect.device) &&
        (prev.device != data.device || prev.isSmallPhone != data.isSmallPhone)) {
      return true;
    }
    if (dependencies.contains(_OmniResponsiveAspect.windowSize) &&
        prev.windowSize != data.windowSize) {
      return true;
    }
    if (dependencies.contains(_OmniResponsiveAspect.orientation) &&
        prev.orientation != data.orientation) {
      return true;
    }
    if (dependencies.contains(_OmniResponsiveAspect.compactHeight) &&
        prev.isCompactHeight != data.isCompactHeight) {
      return true;
    }
    if (dependencies.contains(_OmniResponsiveAspect.tokens) &&
        (prev.tokens != data.tokens ||
            oldWidget.minTextScale != minTextScale ||
            oldWidget.maxTextScale != maxTextScale)) {
      return true;
    }
    if (dependencies.contains(_OmniResponsiveAspect.metrics) &&
        prev.size != data.size) {
      return true;
    }
    return false;
  }
}

/// Applies responsive tier text scaling & optional min/max clamps cleanly ONCE
/// per tier change without rebuilding when only viewport pixels jitter.
class OmniResponsiveTextScaleHost extends StatelessWidget {
  /// Wraps [child] with composed tier + accessibility `TextScaler` clamps.
  const OmniResponsiveTextScaleHost({
    super.key,
    required this.child,
    required this.config,
    this.minTextScale,
    this.maxTextScale,
  });

  /// Wraps [child] reading settings automatically from the nearest
  /// [OmniResponsiveScope] (used inside Splash/Onboarding stage fallback apps).
  static Widget fromScope(BuildContext context, {required Widget child}) {
    final settings = OmniResponsiveScope.maybeScaleSettingsOf(context);
    if (settings == null) return child;
    return OmniResponsiveTextScaleHost(
      config: settings.config,
      minTextScale: settings.minTextScale,
      maxTextScale: settings.maxTextScale,
      child: child,
    );
  }

  /// Responsive configuration supplying tier `textScale`.
  final OmniResponsiveConfig config;

  /// Optional lower clamp matching `OmniApp.minTextScale`.
  final double? minTextScale;

  /// Optional upper clamp matching `OmniApp.maxTextScale`.
  final double? maxTextScale;

  /// Descendant subtree (typically inside `MaterialApp`/`CupertinoApp`).
  final Widget child;

  double _resolveTierScale(BuildContext context) =>
      (config.enabled && config.adaptTextScaling)
          ? OmniResponsiveScope.tokensOf(context).textScale
          : 1.0;

  Widget _applyWithFullMediaQuery(
    BuildContext context,
    MediaQueryData mq,
    double tierScale,
  ) {
    final nextScaler = OmniResponsiveConfig.composeTextScaler(
      mq.textScaler,
      tierScale,
      minScale: minTextScale,
      maxScale: maxTextScale,
    );
    if (nextScaler == mq.textScaler) return child;

    return MediaQuery(
      data: mq.copyWith(textScaler: nextScaler),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tierScale = _resolveTierScale(context);
    if (tierScale == 1.0 && minTextScale == null && maxTextScale == null) {
      return child;
    }

    // Subscribe ONLY to textScaler first so keyboard viewInsets animations do
    // NOT rebuild the app root when the composed scaler matches OS textScaler!
    final currentScaler = MediaQuery.maybeTextScalerOf(context);
    if (currentScaler != null) {
      final preview = OmniResponsiveConfig.composeTextScaler(
        currentScaler,
        tierScale,
        minScale: minTextScale,
        maxScale: maxTextScale,
      );
      if (preview == currentScaler) return child;

      final mq = MediaQuery.of(context);
      return _applyWithFullMediaQuery(context, mq, tierScale);
    }

    // Fallback when wrapped outside MaterialApp (e.g. custom OmniApp(builder:)
    // under runApp where no ancestor MediaQuery exists yet).
    final view = View.maybeOf(context);
    if (view == null) return child;
    return MediaQuery.fromView(
      view: view,
      child: Builder(
        builder: (innerCtx) => _applyWithFullMediaQuery(
          innerCtx,
          MediaQuery.of(innerCtx),
          tierScale,
        ),
      ),
    );
  }
}
