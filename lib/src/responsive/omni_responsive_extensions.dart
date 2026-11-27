import 'package:flutter/widgets.dart';

import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';

/// Zero-overhead responsive shortcuts exposed on any [BuildContext].
///
/// Every getter subscribes strictly to its matching [InheritedModel] aspect so
/// widgets checking [isMobile], [tokens], or [responsiveValue] never rebuild on
/// intra-breakpoint resizes or soft-keyboard transitions.
extension OmniResponsiveContext on BuildContext {
  /// Structural responsive snapshot (subscribes to `device`, `windowSize`,
  /// `orientation`, and `tokens` — not continuous pixel width).
  OmniResponsiveData get responsive => OmniResponsiveScope.of(this);

  /// Non-listening O(1) lookup safe inside button callbacks (`onPressed`),
  /// event handlers, or lifecycle hooks without registering rebuild subscriptions.
  OmniResponsiveData get responsiveRead => OmniResponsiveScope.read(this);

  /// Discrete device tier (`mobile`, `tablet`, `desktop`, `largeDesktop`).
  OmniDeviceType get deviceType => OmniResponsiveScope.deviceOf(this);

  /// Material 3 width class (`compact`, `medium`, `expanded`, `large`, `extraLarge`).
  OmniWindowSize get windowSize => OmniResponsiveScope.windowSizeOf(this);

  /// Viewport orientation derived solely from dimensions.
  Orientation get screenOrientation => OmniResponsiveScope.orientationOf(this);

  /// Cached pre-allocated design tokens for the current device tier.
  OmniResponsiveTokens get tokens => OmniResponsiveScope.tokensOf(this);

  /// Viewport logical [Size]. Prefer [deviceType], [windowSize], or [tokens]
  /// when continuous per-pixel rebuilds are unnecessary.
  Size get screenSize => OmniResponsiveScope.sizeOf(this);

  /// Viewport logical width (subscribes to continuous size updates).
  double get screenWidth => OmniResponsiveScope.sizeOf(this).width;

  /// Viewport logical height (subscribes to continuous size updates).
  double get screenHeight => OmniResponsiveScope.sizeOf(this).height;

  /// True when the active viewport is in the `mobile` tier (`< 600dp`).
  bool get isMobile =>
      OmniResponsiveScope.deviceOf(this) == OmniDeviceType.mobile;

  /// True when the active viewport is a compact handset (`< 360dp`).
  bool get isSmallPhone => OmniResponsiveScope.isSmallPhoneOf(this);

  /// True when the active viewport is in the `tablet` tier (`600..1023dp`).
  bool get isTablet =>
      OmniResponsiveScope.deviceOf(this) == OmniDeviceType.tablet;

  /// True when the active viewport is in the `desktop` tier (`1024..1439dp`).
  bool get isDesktop =>
      OmniResponsiveScope.deviceOf(this) == OmniDeviceType.desktop;

  /// True when the active viewport is in the `largeDesktop` tier (`>= 1440dp`).
  bool get isLargeDesktop =>
      OmniResponsiveScope.deviceOf(this) == OmniDeviceType.largeDesktop;

  /// True for `tablet`, `desktop`, and `largeDesktop`.
  bool get isTabletOrLarger =>
      OmniResponsiveScope.deviceOf(this) != OmniDeviceType.mobile;

  /// True for `desktop` and `largeDesktop`.
  bool get isDesktopOrLarger {
    final d = OmniResponsiveScope.deviceOf(this);
    return d == OmniDeviceType.desktop || d == OmniDeviceType.largeDesktop;
  }

  /// True when [screenOrientation] is [Orientation.portrait].
  bool get isPortrait =>
      OmniResponsiveScope.orientationOf(this) == Orientation.portrait;

  /// True when [screenOrientation] is [Orientation.landscape].
  bool get isLandscape =>
      OmniResponsiveScope.orientationOf(this) == Orientation.landscape;

  /// True when viewport height is tight (`< 480dp`), e.g. on landscape phones
  /// or compact split windows.
  bool get isCompactHeight => OmniResponsiveScope.isCompactHeightOf(this);

  /// Picks a value per device tier (subscribes ONLY to `device` aspect) with
  /// downward fallback `largeDesktop -> desktop -> tablet -> mobile`.
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) => switch (OmniResponsiveScope.deviceOf(this)) {
    OmniDeviceType.mobile => mobile,
    OmniDeviceType.tablet => tablet ?? mobile,
    OmniDeviceType.desktop => desktop ?? tablet ?? mobile,
    OmniDeviceType.largeDesktop => largeDesktop ?? desktop ?? tablet ?? mobile,
  };

  /// Resolves grid column count per device tier (subscribes cleanly to tier
  /// changes and respects custom `tokens.gridColumns`).
  int responsiveColumns({
    int? mobile,
    int? tablet,
    int? desktop,
    int? largeDesktop,
  }) {
    final defaultCols = OmniResponsiveScope.tokensOf(this).gridColumns;
    return switch (OmniResponsiveScope.deviceOf(this)) {
      OmniDeviceType.mobile => mobile ?? defaultCols,
      OmniDeviceType.tablet => tablet ?? mobile ?? defaultCols,
      OmniDeviceType.desktop => desktop ?? tablet ?? mobile ?? defaultCols,
      OmniDeviceType.largeDesktop =>
        largeDesktop ?? desktop ?? tablet ?? mobile ?? defaultCols,
    };
  }

  /// Multiplies [value] by the tier's coarse [OmniResponsiveTokens.scaleFactor]
  /// (`0` rebuilds inside a breakpoint).
  double responsiveSize(double value) =>
      OmniResponsiveScope.tokensOf(this).scaled(value);
}
