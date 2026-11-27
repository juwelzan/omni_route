import 'package:flutter/widgets.dart';

/// Semantic device tier resolved from discrete layout breakpoints.
///
/// Matches native Android WindowSize / iOS TraitCollection size classes so UI
/// layouts adapt at clean tier boundaries rather than rebuilding on every pixel.
enum OmniDeviceType {
  /// Handset / compact viewport (`width < mobileMaxWidth`, default `< 600dp`).
  mobile,

  /// Tablet / foldable unfolded viewport (`600dp <= width < 1024dp`).
  tablet,

  /// Desktop / landscape laptop viewport (`1024dp <= width < 1440dp`).
  desktop,

  /// Large desktop / ultrawide monitor (`width >= 1440dp`).
  largeDesktop,
}

/// Material 3 width window size classification.
enum OmniWindowSize {
  /// Width `< 600dp`.
  compact,

  /// Width `600dp .. 839dp`.
  medium,

  /// Width `840dp .. 1199dp`.
  expanded,

  /// Width `1200dp .. 1599dp`.
  large,

  /// Width `>= 1600dp`.
  extraLarge,
}

/// Pre-computed, immutable design tokens for a single [OmniDeviceType] tier.
///
/// Using constant token objects per tier mirrors Android `values/dimens.xml`
/// qualifiers: widgets read cached `EdgeInsets`, `BorderRadius`, and
/// `const SizedBox` spacers directly with zero per-frame heap allocation.
@immutable
class OmniResponsiveTokens {
  /// Creates a responsive token set for a device tier.
  const OmniResponsiveTokens({
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.space2xl,
    required this.pagePadding,
    required this.horizontalPadding,
    required this.cardPadding,
    required this.sectionPadding,
    required this.gapXs,
    required this.gapSm,
    required this.gapMd,
    required this.gapLg,
    required this.gapXl,
    required this.gapWidthSm,
    required this.gapWidthMd,
    required this.gapWidthLg,
    required this.cardRadius,
    required this.buttonRadius,
    required this.dialogRadius,
    required this.cardBorderRadius,
    required this.buttonBorderRadius,
    required this.dialogBorderRadius,
    required this.maxContentWidth,
    required this.gridColumns,
    required this.gridSpacing,
    required this.minTapTarget,
    this.iconSize = 22,
    required this.textScale,
    required this.scaleFactor,
    required this.displaySize,
    required this.headlineSize,
    required this.titleSize,
    required this.bodySize,
    required this.labelSize,
  });

  /// Extra-small spacing (`4dp`–`8dp`).
  final double spaceXs;

  /// Small spacing (`8dp`–`12dp`).
  final double spaceSm;

  /// Standard spacing (`12dp`–`24dp`).
  final double spaceMd;

  /// Large spacing (`20dp`–`36dp`).
  final double spaceLg;

  /// Extra-large spacing (`28dp`–`48dp`).
  final double spaceXl;

  /// Double-extra-large section spacing (`40dp`–`64dp`).
  final double space2xl;

  /// Default page content padding.
  final EdgeInsets pagePadding;

  /// Horizontal page gutter padding.
  final EdgeInsets horizontalPadding;

  /// Default card inner padding.
  final EdgeInsets cardPadding;

  /// Section block vertical/horizontal padding.
  final EdgeInsets sectionPadding;

  /// Pre-allocated vertical `SizedBox` for extra-small gaps.
  final Widget gapXs;

  /// Pre-allocated vertical `SizedBox` for small gaps.
  final Widget gapSm;

  /// Pre-allocated vertical `SizedBox` for medium gaps.
  final Widget gapMd;

  /// Pre-allocated vertical `SizedBox` for large gaps.
  final Widget gapLg;

  /// Pre-allocated vertical `SizedBox` for extra-large gaps.
  final Widget gapXl;

  /// Pre-allocated horizontal `SizedBox` for small gaps.
  final Widget gapWidthSm;

  /// Pre-allocated horizontal `SizedBox` for medium gaps.
  final Widget gapWidthMd;

  /// Pre-allocated horizontal `SizedBox` for large gaps.
  final Widget gapWidthLg;

  /// Numeric corner radius for cards.
  final double cardRadius;

  /// Numeric corner radius for buttons and inputs.
  final double buttonRadius;

  /// Numeric corner radius for dialogs and sheets.
  final double dialogRadius;

  /// Cached [BorderRadius] matching [cardRadius].
  final BorderRadius cardBorderRadius;

  /// Cached [BorderRadius] matching [buttonRadius].
  final BorderRadius buttonBorderRadius;

  /// Cached [BorderRadius] matching [dialogRadius].
  final BorderRadius dialogBorderRadius;

  /// Maximum readable content container width (`double.infinity` on phones).
  final double maxContentWidth;

  /// Default responsive grid column count for this tier.
  final int gridColumns;

  /// Default grid item spacing for this tier.
  final double gridSpacing;

  /// Minimum interactive hit target dimension (48dp touch / 40dp pointer).
  final double minTapTarget;

  /// Recommended standard icon dimension for buttons and navigation items.
  final double iconSize;

  /// Tier-level readability multiplier composed cleanly with OS accessibility
  /// `TextScaler` (desktop gets a subtle readability bump while mobile stays
  /// 1:1 with system accessibility settings).
  final double textScale;

  /// Coarse tier multiplier for custom `context.responsiveSize(value)` calls
  /// without per-pixel rebuilds.
  final double scaleFactor;

  /// Recommended hero/display font size for this tier.
  final double displaySize;

  /// Recommended section headline font size for this tier.
  final double headlineSize;

  /// Recommended card/app-bar title font size for this tier.
  final double titleSize;

  /// Recommended body copy font size for this tier.
  final double bodySize;

  /// Recommended caption/badge label font size for this tier.
  final double labelSize;

  /// Pre-allocated tokens for extra-compact phones (`width < 360dp`).
  static const smallPhone = OmniResponsiveTokens(
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 12,
    spaceLg: 18,
    spaceXl: 24,
    space2xl: 32,
    pagePadding: EdgeInsets.all(12),
    horizontalPadding: EdgeInsets.symmetric(horizontal: 12),
    cardPadding: EdgeInsets.all(12),
    sectionPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    gapXs: SizedBox(height: 4),
    gapSm: SizedBox(height: 8),
    gapMd: SizedBox(height: 12),
    gapLg: SizedBox(height: 18),
    gapXl: SizedBox(height: 24),
    gapWidthSm: SizedBox(width: 8),
    gapWidthMd: SizedBox(width: 12),
    gapWidthLg: SizedBox(width: 18),
    cardRadius: 10,
    buttonRadius: 8,
    dialogRadius: 14,
    cardBorderRadius: BorderRadius.all(Radius.circular(10)),
    buttonBorderRadius: BorderRadius.all(Radius.circular(8)),
    dialogBorderRadius: BorderRadius.all(Radius.circular(14)),
    maxContentWidth: double.infinity,
    gridColumns: 2,
    gridSpacing: 10,
    minTapTarget: 48,
    iconSize: 20,
    textScale: 0.94,
    scaleFactor: 0.92,
    displaySize: 28,
    headlineSize: 20,
    titleSize: 16,
    bodySize: 13.5,
    labelSize: 11.5,
  );

  /// Pre-allocated tokens for standard mobile devices (`360dp .. 599dp`).
  static const mobile = OmniResponsiveTokens(
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 16,
    spaceLg: 24,
    spaceXl: 32,
    space2xl: 44,
    pagePadding: EdgeInsets.all(16),
    horizontalPadding: EdgeInsets.symmetric(horizontal: 16),
    cardPadding: EdgeInsets.all(14),
    sectionPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    gapXs: SizedBox(height: 4),
    gapSm: SizedBox(height: 8),
    gapMd: SizedBox(height: 16),
    gapLg: SizedBox(height: 24),
    gapXl: SizedBox(height: 32),
    gapWidthSm: SizedBox(width: 8),
    gapWidthMd: SizedBox(width: 16),
    gapWidthLg: SizedBox(width: 24),
    cardRadius: 12,
    buttonRadius: 10,
    dialogRadius: 16,
    cardBorderRadius: BorderRadius.all(Radius.circular(12)),
    buttonBorderRadius: BorderRadius.all(Radius.circular(10)),
    dialogBorderRadius: BorderRadius.all(Radius.circular(16)),
    maxContentWidth: double.infinity,
    gridColumns: 2,
    gridSpacing: 12,
    minTapTarget: 48,
    iconSize: 22,
    textScale: 1.0,
    scaleFactor: 1.0,
    displaySize: 32,
    headlineSize: 22,
    titleSize: 17,
    bodySize: 14,
    labelSize: 12,
  );

  /// Pre-allocated tokens for tablets (`600dp .. 1023dp`).
  static const tablet = OmniResponsiveTokens(
    spaceXs: 6,
    spaceSm: 10,
    spaceMd: 20,
    spaceLg: 28,
    spaceXl: 40,
    space2xl: 52,
    pagePadding: EdgeInsets.all(24),
    horizontalPadding: EdgeInsets.symmetric(horizontal: 24),
    cardPadding: EdgeInsets.all(18),
    sectionPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
    gapXs: SizedBox(height: 6),
    gapSm: SizedBox(height: 10),
    gapMd: SizedBox(height: 20),
    gapLg: SizedBox(height: 28),
    gapXl: SizedBox(height: 40),
    gapWidthSm: SizedBox(width: 10),
    gapWidthMd: SizedBox(width: 20),
    gapWidthLg: SizedBox(width: 28),
    cardRadius: 14,
    buttonRadius: 12,
    dialogRadius: 20,
    cardBorderRadius: BorderRadius.all(Radius.circular(14)),
    buttonBorderRadius: BorderRadius.all(Radius.circular(12)),
    dialogBorderRadius: BorderRadius.all(Radius.circular(20)),
    maxContentWidth: 780,
    gridColumns: 3,
    gridSpacing: 16,
    minTapTarget: 44,
    iconSize: 24,
    textScale: 1.0,
    scaleFactor: 1.08,
    displaySize: 36,
    headlineSize: 24,
    titleSize: 18,
    bodySize: 15,
    labelSize: 13,
  );

  /// Pre-allocated tokens for desktops & laptops (`1024dp .. 1439dp`).
  static const desktop = OmniResponsiveTokens(
    spaceXs: 6,
    spaceSm: 12,
    spaceMd: 24,
    spaceLg: 32,
    spaceXl: 44,
    space2xl: 60,
    pagePadding: EdgeInsets.all(28),
    horizontalPadding: EdgeInsets.symmetric(horizontal: 32),
    cardPadding: EdgeInsets.all(20),
    sectionPadding: EdgeInsets.symmetric(vertical: 24, horizontal: 32),
    gapXs: SizedBox(height: 6),
    gapSm: SizedBox(height: 12),
    gapMd: SizedBox(height: 24),
    gapLg: SizedBox(height: 32),
    gapXl: SizedBox(height: 44),
    gapWidthSm: SizedBox(width: 12),
    gapWidthMd: SizedBox(width: 24),
    gapWidthLg: SizedBox(width: 32),
    cardRadius: 16,
    buttonRadius: 12,
    dialogRadius: 22,
    cardBorderRadius: BorderRadius.all(Radius.circular(16)),
    buttonBorderRadius: BorderRadius.all(Radius.circular(12)),
    dialogBorderRadius: BorderRadius.all(Radius.circular(22)),
    maxContentWidth: 1140,
    gridColumns: 4,
    gridSpacing: 20,
    minTapTarget: 40,
    iconSize: 24,
    textScale: 1.05,
    scaleFactor: 1.14,
    displaySize: 40,
    headlineSize: 26,
    titleSize: 19,
    bodySize: 15.5,
    labelSize: 13,
  );

  /// Pre-allocated tokens for large monitors (`>= 1440dp`).
  static const largeDesktop = OmniResponsiveTokens(
    spaceXs: 8,
    spaceSm: 14,
    spaceMd: 28,
    spaceLg: 40,
    spaceXl: 52,
    space2xl: 68,
    pagePadding: EdgeInsets.all(32),
    horizontalPadding: EdgeInsets.symmetric(horizontal: 40),
    cardPadding: EdgeInsets.all(24),
    sectionPadding: EdgeInsets.symmetric(vertical: 28, horizontal: 40),
    gapXs: SizedBox(height: 8),
    gapSm: SizedBox(height: 14),
    gapMd: SizedBox(height: 28),
    gapLg: SizedBox(height: 40),
    gapXl: SizedBox(height: 52),
    gapWidthSm: SizedBox(width: 14),
    gapWidthMd: SizedBox(width: 28),
    gapWidthLg: SizedBox(width: 40),
    cardRadius: 16,
    buttonRadius: 12,
    dialogRadius: 24,
    cardBorderRadius: BorderRadius.all(Radius.circular(16)),
    buttonBorderRadius: BorderRadius.all(Radius.circular(12)),
    dialogBorderRadius: BorderRadius.all(Radius.circular(24)),
    maxContentWidth: 1320,
    gridColumns: 5,
    gridSpacing: 24,
    minTapTarget: 40,
    iconSize: 26,
    textScale: 1.08,
    scaleFactor: 1.2,
    displaySize: 44,
    headlineSize: 28,
    titleSize: 20,
    bodySize: 16,
    labelSize: 13.5,
  );

  /// Scales [value] using this tier's coarse [scaleFactor] without triggering
  /// continuous per-pixel rebuilds.
  double scaled(double value) => value * scaleFactor;

  /// Returns a copy with overridden fields.
  OmniResponsiveTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? space2xl,
    EdgeInsets? pagePadding,
    EdgeInsets? horizontalPadding,
    EdgeInsets? cardPadding,
    EdgeInsets? sectionPadding,
    double? cardRadius,
    double? buttonRadius,
    double? dialogRadius,
    double? maxContentWidth,
    int? gridColumns,
    double? gridSpacing,
    double? minTapTarget,
    double? iconSize,
    double? textScale,
    double? scaleFactor,
    double? displaySize,
    double? headlineSize,
    double? titleSize,
    double? bodySize,
    double? labelSize,
  }) {
    final nextSpaceXs = spaceXs ?? this.spaceXs;
    final nextSpaceSm = spaceSm ?? this.spaceSm;
    final nextSpaceMd = spaceMd ?? this.spaceMd;
    final nextSpaceLg = spaceLg ?? this.spaceLg;
    final nextSpaceXl = spaceXl ?? this.spaceXl;
    final nextCardRadius = cardRadius ?? this.cardRadius;
    final nextButtonRadius = buttonRadius ?? this.buttonRadius;
    final nextDialogRadius = dialogRadius ?? this.dialogRadius;
    return OmniResponsiveTokens(
      spaceXs: nextSpaceXs,
      spaceSm: nextSpaceSm,
      spaceMd: nextSpaceMd,
      spaceLg: nextSpaceLg,
      spaceXl: nextSpaceXl,
      space2xl: space2xl ?? this.space2xl,
      pagePadding: pagePadding ?? this.pagePadding,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      cardPadding: cardPadding ?? this.cardPadding,
      sectionPadding: sectionPadding ?? this.sectionPadding,
      gapXs: nextSpaceXs == this.spaceXs ? gapXs : SizedBox(height: nextSpaceXs),
      gapSm: nextSpaceSm == this.spaceSm ? gapSm : SizedBox(height: nextSpaceSm),
      gapMd: nextSpaceMd == this.spaceMd ? gapMd : SizedBox(height: nextSpaceMd),
      gapLg: nextSpaceLg == this.spaceLg ? gapLg : SizedBox(height: nextSpaceLg),
      gapXl: nextSpaceXl == this.spaceXl ? gapXl : SizedBox(height: nextSpaceXl),
      gapWidthSm: nextSpaceSm == this.spaceSm
          ? gapWidthSm
          : SizedBox(width: nextSpaceSm),
      gapWidthMd: nextSpaceMd == this.spaceMd
          ? gapWidthMd
          : SizedBox(width: nextSpaceMd),
      gapWidthLg: nextSpaceLg == this.spaceLg
          ? gapWidthLg
          : SizedBox(width: nextSpaceLg),
      cardRadius: nextCardRadius,
      buttonRadius: nextButtonRadius,
      dialogRadius: nextDialogRadius,
      cardBorderRadius: nextCardRadius == this.cardRadius
          ? cardBorderRadius
          : BorderRadius.all(Radius.circular(nextCardRadius)),
      buttonBorderRadius: nextButtonRadius == this.buttonRadius
          ? buttonBorderRadius
          : BorderRadius.all(Radius.circular(nextButtonRadius)),
      dialogBorderRadius: nextDialogRadius == this.dialogRadius
          ? dialogBorderRadius
          : BorderRadius.all(Radius.circular(nextDialogRadius)),
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
      gridColumns: gridColumns ?? this.gridColumns,
      gridSpacing: gridSpacing ?? this.gridSpacing,
      minTapTarget: minTapTarget ?? this.minTapTarget,
      iconSize: iconSize ?? this.iconSize,
      textScale: textScale ?? this.textScale,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      displaySize: displaySize ?? this.displaySize,
      headlineSize: headlineSize ?? this.headlineSize,
      titleSize: titleSize ?? this.titleSize,
      bodySize: bodySize ?? this.bodySize,
      labelSize: labelSize ?? this.labelSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniResponsiveTokens &&
          spaceXs == other.spaceXs &&
          spaceSm == other.spaceSm &&
          spaceMd == other.spaceMd &&
          spaceLg == other.spaceLg &&
          spaceXl == other.spaceXl &&
          space2xl == other.space2xl &&
          pagePadding == other.pagePadding &&
          horizontalPadding == other.horizontalPadding &&
          cardPadding == other.cardPadding &&
          sectionPadding == other.sectionPadding &&
          cardRadius == other.cardRadius &&
          buttonRadius == other.buttonRadius &&
          dialogRadius == other.dialogRadius &&
          maxContentWidth == other.maxContentWidth &&
          gridColumns == other.gridColumns &&
          gridSpacing == other.gridSpacing &&
          minTapTarget == other.minTapTarget &&
          iconSize == other.iconSize &&
          textScale == other.textScale &&
          scaleFactor == other.scaleFactor &&
          displaySize == other.displaySize &&
          headlineSize == other.headlineSize &&
          titleSize == other.titleSize &&
          bodySize == other.bodySize &&
          labelSize == other.labelSize;

  @override
  int get hashCode => Object.hashAll([
    spaceXs,
    spaceSm,
    spaceMd,
    spaceLg,
    spaceXl,
    space2xl,
    pagePadding,
    horizontalPadding,
    cardPadding,
    sectionPadding,
    cardRadius,
    buttonRadius,
    dialogRadius,
    maxContentWidth,
    gridColumns,
    gridSpacing,
    minTapTarget,
    iconSize,
    textScale,
    scaleFactor,
    displaySize,
    headlineSize,
    titleSize,
    bodySize,
    labelSize,
  ]);
}

/// Maps each [OmniDeviceType] tier to a pre-computed [OmniResponsiveTokens] set.
@immutable
class OmniResponsiveTokenSet {
  /// Creates a custom token bundle per device tier.
  const OmniResponsiveTokenSet({
    this.smallPhone = OmniResponsiveTokens.smallPhone,
    this.mobile = OmniResponsiveTokens.mobile,
    this.tablet = OmniResponsiveTokens.tablet,
    this.desktop = OmniResponsiveTokens.desktop,
    this.largeDesktop = OmniResponsiveTokens.largeDesktop,
  });

  /// Tokens for narrow phones (`< smallPhoneMaxWidth`).
  final OmniResponsiveTokens smallPhone;

  /// Tokens for standard phones.
  final OmniResponsiveTokens mobile;

  /// Tokens for tablets.
  final OmniResponsiveTokens tablet;

  /// Tokens for desktops and laptops.
  final OmniResponsiveTokens desktop;

  /// Tokens for large monitors.
  final OmniResponsiveTokens largeDesktop;

  /// Returns the cached token set for [device] in O(1) time.
  OmniResponsiveTokens forTier(
    OmniDeviceType device, {
    bool isSmallPhone = false,
  }) => switch (device) {
    OmniDeviceType.mobile => isSmallPhone ? smallPhone : mobile,
    OmniDeviceType.tablet => tablet,
    OmniDeviceType.desktop => desktop,
    OmniDeviceType.largeDesktop => largeDesktop,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniResponsiveTokenSet &&
          smallPhone == other.smallPhone &&
          mobile == other.mobile &&
          tablet == other.tablet &&
          desktop == other.desktop &&
          largeDesktop == other.largeDesktop;

  @override
  int get hashCode =>
      Object.hash(smallPhone, mobile, tablet, desktop, largeDesktop);
}

/// Configuration for OmniRoute's zero-overhead native-equivalent responsive
/// system on [OmniApp] and [OmniResponsiveScope].
///
/// Enabled by default on every [OmniApp] using discrete breakpoint tiers and
/// pre-cached constant tokens (`0` intra-breakpoint rebuilds, `0` keyboard
/// rebuilds, and `const Text(...)` preservation). Pass
/// `const OmniResponsiveConfig.disabled()` to turn off responsive typography
/// and tier overrides.
@immutable
class OmniResponsiveConfig {
  /// Creates a responsive configuration with Material/HIG standard breakpoints.
  const OmniResponsiveConfig({
    this.enabled = true,
    this.smallPhoneMaxWidth = 360,
    this.mobileMaxWidth = 600,
    this.tabletMaxWidth = 1024,
    this.desktopMaxWidth = 1440,
    this.useShortestSide = false,
    this.adaptTextScaling = true,
    this.tokens = const OmniResponsiveTokenSet(),
  }) : assert(smallPhoneMaxWidth >= 0),
       assert(mobileMaxWidth > 0),
       assert(tabletMaxWidth >= mobileMaxWidth),
       assert(desktopMaxWidth >= tabletMaxWidth);

  /// Disables responsive text scaling (breakpoints fall back to structural
  /// queries when explicitly accessed).
  const OmniResponsiveConfig.disabled({
    this.smallPhoneMaxWidth = 360,
    this.mobileMaxWidth = 600,
    this.tabletMaxWidth = 1024,
    this.desktopMaxWidth = 1440,
    this.useShortestSide = false,
    this.tokens = const OmniResponsiveTokenSet(),
  }) : enabled = false,
       adaptTextScaling = false;

  /// Whether built-in responsive handling & tier text scaling are active.
  final bool enabled;

  /// Upper bound for [OmniResponsiveTokens.smallPhone] inside mobile tier.
  final double smallPhoneMaxWidth;

  /// Upper bound (exclusive) for [OmniDeviceType.mobile]. Defaults to `600`.
  final double mobileMaxWidth;

  /// Upper bound (exclusive) for [OmniDeviceType.tablet]. Defaults to `1024`.
  final double tabletMaxWidth;

  /// Upper bound (exclusive) for [OmniDeviceType.desktop]. Defaults to `1440`.
  final double desktopMaxWidth;

  /// Classify [OmniDeviceType] using `size.shortestSide` instead of `size.width`
  /// when keeping phone UI orientation-stable across landscape rotation.
  final bool useShortestSide;

  /// Automatically compose subtle tier readability scaling onto `MediaQuery`'s
  /// `TextScaler` while respecting OS accessibility and `minTextScale`/
  /// `maxTextScale` bounds.
  final bool adaptTextScaling;

  /// Tier token presets returned via `context.tokens`.
  final OmniResponsiveTokenSet tokens;

  /// Resolves [OmniDeviceType] from viewport [size] using a single comparison.
  OmniDeviceType deviceFor(Size size) {
    final metric = useShortestSide ? size.shortestSide : size.width;
    if (metric < mobileMaxWidth) return OmniDeviceType.mobile;
    if (metric < tabletMaxWidth) return OmniDeviceType.tablet;
    if (metric < desktopMaxWidth) return OmniDeviceType.desktop;
    return OmniDeviceType.largeDesktop;
  }

  /// Resolves whether [size] represents a narrow `< smallPhoneMaxWidth` handset.
  bool isSmallPhoneSize(Size size) {
    final metric = useShortestSide ? size.shortestSide : size.width;
    return metric < smallPhoneMaxWidth;
  }

  /// Resolves Material 3 [OmniWindowSize] purely from viewport width.
  OmniWindowSize windowSizeFor(Size size) {
    final w = size.width;
    if (w < 600) return OmniWindowSize.compact;
    if (w < 840) return OmniWindowSize.medium;
    if (w < 1200) return OmniWindowSize.expanded;
    if (w < 1600) return OmniWindowSize.large;
    return OmniWindowSize.extraLarge;
  }

  /// Returns pre-allocated [OmniResponsiveTokens] for [size].
  OmniResponsiveTokens tokensFor(Size size) =>
      tokens.forTier(deviceFor(size), isSmallPhone: isSmallPhoneSize(size));

  /// Composes [base] OS/App `TextScaler` with the current tier's [textScale]
  /// multiplier and applies optional [minScale] / [maxScale] clamp last.
  static TextScaler composeTextScaler(
    TextScaler base,
    double textScale, {
    double? minScale,
    double? maxScale,
  }) {
    var result = base;
    if (textScale != 1.0 && textScale > 0) {
      if (base == TextScaler.noScaling) {
        result = TextScaler.linear(textScale);
      } else {
        result = _MultipliedTextScaler(base, textScale);
      }
    }
    if (minScale != null || maxScale != null) {
      result = result.clamp(
        minScaleFactor: minScale ?? 0,
        maxScaleFactor: maxScale ?? double.infinity,
      );
    }
    return result;
  }

  /// Returns a modified copy of this configuration.
  OmniResponsiveConfig copyWith({
    bool? enabled,
    double? smallPhoneMaxWidth,
    double? mobileMaxWidth,
    double? tabletMaxWidth,
    double? desktopMaxWidth,
    bool? useShortestSide,
    bool? adaptTextScaling,
    OmniResponsiveTokenSet? tokens,
  }) => OmniResponsiveConfig(
    enabled: enabled ?? this.enabled,
    smallPhoneMaxWidth: smallPhoneMaxWidth ?? this.smallPhoneMaxWidth,
    mobileMaxWidth: mobileMaxWidth ?? this.mobileMaxWidth,
    tabletMaxWidth: tabletMaxWidth ?? this.tabletMaxWidth,
    desktopMaxWidth: desktopMaxWidth ?? this.desktopMaxWidth,
    useShortestSide: useShortestSide ?? this.useShortestSide,
    adaptTextScaling: adaptTextScaling ?? this.adaptTextScaling,
    tokens: tokens ?? this.tokens,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniResponsiveConfig &&
          enabled == other.enabled &&
          smallPhoneMaxWidth == other.smallPhoneMaxWidth &&
          mobileMaxWidth == other.mobileMaxWidth &&
          tabletMaxWidth == other.tabletMaxWidth &&
          desktopMaxWidth == other.desktopMaxWidth &&
          useShortestSide == other.useShortestSide &&
          adaptTextScaling == other.adaptTextScaling &&
          tokens == other.tokens;

  @override
  int get hashCode => Object.hash(
    enabled,
    smallPhoneMaxWidth,
    mobileMaxWidth,
    tabletMaxWidth,
    desktopMaxWidth,
    useShortestSide,
    adaptTextScaling,
    tokens,
  );
}

final class _MultipliedTextScaler extends TextScaler {
  const _MultipliedTextScaler(this.parent, this.multiplier);

  final TextScaler parent;
  final double multiplier;

  @override
  double scale(double fontSize) => parent.scale(fontSize) * multiplier;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => parent.textScaleFactor * multiplier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MultipliedTextScaler &&
          parent == other.parent &&
          multiplier == other.multiplier;

  @override
  int get hashCode => Object.hash(parent, multiplier);
}
