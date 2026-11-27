import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';

/// Signature for [OmniResponsiveBuilder.builder].
typedef OmniResponsiveWidgetBuilder =
    Widget Function(
      BuildContext context,
      OmniDeviceType device,
      OmniResponsiveTokens tokens,
    );

/// Builds different UI with [device] and pre-cached [tokens], rebuilding ONLY
/// when crossing a breakpoint threshold (`0` intra-breakpoint or keyboard
/// rebuilds).
class OmniResponsiveBuilder extends StatelessWidget {
  /// Creates a tier-scoped responsive builder.
  const OmniResponsiveBuilder({super.key, required this.builder});

  /// Called when active [OmniDeviceType] or [OmniResponsiveTokens] changes.
  final OmniResponsiveWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final device = OmniResponsiveScope.deviceOf(context);
    final tokens = OmniResponsiveScope.tokensOf(context);
    return builder(context, device, tokens);
  }
}

/// Switches lazily between device-specific widget subtrees while keeping all
/// branches clean and rebuilding ONLY when crossing [OmniDeviceType] bounds.
class OmniResponsiveLayout extends StatelessWidget {
  /// Creates a responsive slot layout.
  ///
  /// Uses downward fallback `largeDesktop -> desktop -> tablet -> mobile`.
  const OmniResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  /// Layout rendered on phones (and fallback for larger tiers if omitted).
  final Widget mobile;

  /// Optional layout rendered on tablets.
  final Widget? tablet;

  /// Optional layout rendered on desktops.
  final Widget? desktop;

  /// Optional layout rendered on large desktop monitors.
  final Widget? largeDesktop;

  @override
  Widget build(BuildContext context) {
    return switch (OmniResponsiveScope.deviceOf(context)) {
      OmniDeviceType.mobile => mobile,
      OmniDeviceType.tablet => tablet ?? mobile,
      OmniDeviceType.desktop => desktop ?? tablet ?? mobile,
      OmniDeviceType.largeDesktop =>
        largeDesktop ?? desktop ?? tablet ?? mobile,
    };
  }
}

/// Shows or hides [child] per [OmniDeviceType] with zero per-pixel rebuilds.
class OmniResponsiveVisibility extends StatelessWidget {
  /// Creates a responsive visibility toggle widget.
  const OmniResponsiveVisibility({
    super.key,
    required this.child,
    this.mobile = true,
    this.tablet = true,
    this.desktop = true,
    this.largeDesktop = true,
    this.replacement = const SizedBox.shrink(),
  });

  /// Shows [child] ONLY on mobile phones (`< 600dp`).
  const OmniResponsiveVisibility.mobileOnly({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : mobile = true,
       tablet = false,
       desktop = false,
       largeDesktop = false;

  /// Shows [child] ONLY on tablets (`600..1023dp`).
  const OmniResponsiveVisibility.tabletOnly({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : mobile = false,
       tablet = true,
       desktop = false,
       largeDesktop = false;

  /// Shows [child] on tablets, desktops, and large monitors (`>= 600dp`).
  const OmniResponsiveVisibility.tabletUp({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : mobile = false,
       tablet = true,
       desktop = true,
       largeDesktop = true;

  /// Shows [child] ONLY on desktop and large monitors (`>= 1024dp`).
  const OmniResponsiveVisibility.desktopUp({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : mobile = false,
       tablet = false,
       desktop = true,
       largeDesktop = true;

  /// Hides [child] on phones while keeping it visible on tablets & desktops.
  const OmniResponsiveVisibility.hideOnMobile({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : mobile = false,
       tablet = true,
       desktop = true,
       largeDesktop = true;

  /// Shows [child] on mobile & tablet, hiding it on desktop & large monitors.
  const OmniResponsiveVisibility.hideOnDesktop({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
  }) : mobile = true,
       tablet = true,
       desktop = false,
       largeDesktop = false;

  /// Subtree shown when visible for the current tier.
  final Widget child;

  /// Show on [OmniDeviceType.mobile].
  final bool mobile;

  /// Show on [OmniDeviceType.tablet].
  final bool tablet;

  /// Show on [OmniDeviceType.desktop].
  final bool desktop;

  /// Show on [OmniDeviceType.largeDesktop].
  final bool largeDesktop;

  /// Placeholder rendered when hidden (defaults to `const SizedBox.shrink()`).
  final Widget replacement;

  @override
  Widget build(BuildContext context) {
    final visible = switch (OmniResponsiveScope.deviceOf(context)) {
      OmniDeviceType.mobile => mobile,
      OmniDeviceType.tablet => tablet,
      OmniDeviceType.desktop => desktop,
      OmniDeviceType.largeDesktop => largeDesktop,
    };
    return visible ? child : replacement;
  }
}

/// Centers content inside `tokens.maxContentWidth` and `tokens.horizontalPadding`
/// using Flutter's native single-pass `ConstrainedBox` + `Padding`.
class OmniResponsiveContainer extends StatelessWidget {
  /// Creates a max-width constrained responsive content container.
  const OmniResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
    this.fillWidth = true,
  });

  /// Body widget constrained to readable line/grid measure.
  final Widget child;

  /// Optional explicit max width overriding `context.tokens.maxContentWidth`.
  final double? maxWidth;

  /// Optional explicit padding overriding `context.tokens.horizontalPadding`.
  final EdgeInsetsGeometry? padding;

  /// Container alignment inside wider desktop/ultrawide screens.
  final AlignmentGeometry alignment;

  /// Stretches [child] to fill `min(parentWidth, maxWidth)` (so left-aligned
  /// columns align neatly inside the container instead of shrink-wrapping). Set
  /// to `false` to shrink-wrap around intrinsic child width.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = OmniResponsiveScope.tokensOf(context);
    final effectiveWidth = maxWidth ?? tokens.maxContentWidth;
    final effectivePadding = padding ?? tokens.horizontalPadding;

    Widget content = child;
    if (effectivePadding != EdgeInsets.zero) {
      content = Padding(padding: effectivePadding, child: content);
    }
    if (!effectiveWidth.isFinite) {
      return content;
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveWidth),
        child: fillWidth
            ? SizedBox(width: effectiveWidth, child: content)
            : content,
      ),
    );
  }
}

/// Switches between vertical `Column` on mobile and horizontal `Row` on
/// larger screens (`rowFrom` threshold defaults to [OmniDeviceType.tablet]).
class OmniResponsiveRowColumn extends StatelessWidget {
  /// Creates a breakpoint-adaptive `Row` / `Column`.
  const OmniResponsiveRowColumn({
    super.key,
    required this.children,
    this.rowFrom = OmniDeviceType.tablet,
    this.gap,
    this.expandInRow = false,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
    this.columnMainAxisAlignment = MainAxisAlignment.start,
    this.columnCrossAxisAlignment = CrossAxisAlignment.stretch,
    this.rowMainAxisSize = MainAxisSize.max,
    this.columnMainAxisSize = MainAxisSize.min,
  });

  /// Child widgets arranged horizontally or vertically.
  final List<Widget> children;

  /// Minimum [OmniDeviceType] index at which horizontal [Row] mode activates.
  final OmniDeviceType rowFrom;

  /// Optional spacing inserted between adjacent children via Flutter's native
  /// `Flex.spacing` (zero extra `SizedBox` widgets).
  final double? gap;

  /// When true, wraps each child in `Expanded` ONLY during horizontal [Row]
  /// layout (leaving vertical [Column] unwrapped so scrolling parents never hit
  /// unbounded height flex errors).
  final bool expandInRow;

  /// `MainAxisAlignment` when laid out as a [Row].
  final MainAxisAlignment rowMainAxisAlignment;

  /// `CrossAxisAlignment` when laid out as a [Row].
  final CrossAxisAlignment rowCrossAxisAlignment;

  /// `MainAxisAlignment` when laid out as a [Column].
  final MainAxisAlignment columnMainAxisAlignment;

  /// `CrossAxisAlignment` when laid out as a [Column].
  final CrossAxisAlignment columnCrossAxisAlignment;

  /// `MainAxisSize` when laid out as a [Row].
  final MainAxisSize rowMainAxisSize;

  /// `MainAxisSize` when laid out as a [Column].
  final MainAxisSize columnMainAxisSize;

  @override
  Widget build(BuildContext context) {
    final device = OmniResponsiveScope.deviceOf(context);
    final useRow = device.index >= rowFrom.index;
    final spacing = gap ?? OmniResponsiveScope.tokensOf(context).spaceMd;

    if (useRow) {
      return Row(
        mainAxisAlignment: rowMainAxisAlignment,
        crossAxisAlignment: rowCrossAxisAlignment,
        mainAxisSize: rowMainAxisSize,
        spacing: spacing,
        children: expandInRow
            ? [for (final c in children) Expanded(child: c)]
            : children,
      );
    }
    return Column(
      mainAxisAlignment: columnMainAxisAlignment,
      crossAxisAlignment: columnCrossAxisAlignment,
      mainAxisSize: columnMainAxisSize,
      spacing: spacing,
      children: children,
    );
  }
}

/// Resolves the appropriate [SliverGridDelegate] for responsive grids using
/// either C++ [SliverGridDelegateWithMaxCrossAxisExtent] (when [maxItemWidth]
/// is supplied) or discrete [OmniDeviceType] column counts.
SliverGridDelegate resolveOmniGridDelegate(
  BuildContext context, {
  required OmniResponsiveTokens tokens,
  double? maxItemWidth,
  int? mobileColumns,
  int? tabletColumns,
  int? desktopColumns,
  int? largeDesktopColumns,
  double? spacing,
  double? runSpacing,
  double childAspectRatio = 1.0,
  double? mainAxisExtent,
}) {
  final gap = spacing ?? tokens.gridSpacing;
  final rowGap = runSpacing ?? gap;
  if (maxItemWidth case final maxExtent?) {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxExtent,
      crossAxisSpacing: gap,
      mainAxisSpacing: rowGap,
      childAspectRatio: childAspectRatio,
      mainAxisExtent: mainAxisExtent,
    );
  }
  final cols = switch (OmniResponsiveScope.deviceOf(context)) {
    OmniDeviceType.mobile => mobileColumns ?? tokens.gridColumns,
    OmniDeviceType.tablet =>
      tabletColumns ?? mobileColumns ?? tokens.gridColumns,
    OmniDeviceType.desktop =>
      desktopColumns ?? tabletColumns ?? mobileColumns ?? tokens.gridColumns,
    OmniDeviceType.largeDesktop =>
      largeDesktopColumns ??
          desktopColumns ??
          tabletColumns ??
          mobileColumns ??
          tokens.gridColumns,
  };
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,
    crossAxisSpacing: gap,
    mainAxisSpacing: rowGap,
    childAspectRatio: childAspectRatio,
    mainAxisExtent: mainAxisExtent,
  );
}

enum _OmniGapKind { xs, sm, md, lg, xl, hSm, hMd, hLg }

/// Zero-allocation `const` responsive spacer returning pre-cached
/// `context.tokens.gap*` `SizedBox` instances directly inside `Column`, `Row`,
/// and `ListView`.
class OmniGap extends StatelessWidget {
  /// Extra-small vertical gap (`tokens.gapXs`).
  const OmniGap.xs({super.key}) : _kind = _OmniGapKind.xs;

  /// Small vertical gap (`tokens.gapSm`).
  const OmniGap.sm({super.key}) : _kind = _OmniGapKind.sm;

  /// Medium vertical gap (`tokens.gapMd`, most common between cards/fields).
  const OmniGap.md({super.key}) : _kind = _OmniGapKind.md;

  /// Large vertical gap (`tokens.gapLg`).
  const OmniGap.lg({super.key}) : _kind = _OmniGapKind.lg;

  /// Extra-large vertical gap (`tokens.gapXl`).
  const OmniGap.xl({super.key}) : _kind = _OmniGapKind.xl;

  /// Small horizontal gap for `Row` children (`tokens.gapWidthSm`).
  const OmniGap.horizontalSm({super.key}) : _kind = _OmniGapKind.hSm;

  /// Medium horizontal gap for `Row` children (`tokens.gapWidthMd`).
  const OmniGap.horizontalMd({super.key}) : _kind = _OmniGapKind.hMd;

  /// Large horizontal gap for `Row` children (`tokens.gapWidthLg`).
  const OmniGap.horizontalLg({super.key}) : _kind = _OmniGapKind.hLg;

  final _OmniGapKind _kind;

  @override
  Widget build(BuildContext context) {
    final t = OmniResponsiveScope.tokensOf(context);
    return switch (_kind) {
      _OmniGapKind.xs => t.gapXs,
      _OmniGapKind.sm => t.gapSm,
      _OmniGapKind.md => t.gapMd,
      _OmniGapKind.lg => t.gapLg,
      _OmniGapKind.xl => t.gapXl,
      _OmniGapKind.hSm => t.gapWidthSm,
      _OmniGapKind.hMd => t.gapWidthMd,
      _OmniGapKind.hLg => t.gapWidthLg,
    };
  }
}

enum _OmniPaddingKind { page, horizontal, card, section }

/// `const`-friendly responsive padding wrapper applying `context.tokens`
/// padding cleanly without `Builder` or manual `EdgeInsets` calls.
class OmniResponsivePadding extends StatelessWidget {
  /// Applies standard page padding (`tokens.pagePadding`).
  const OmniResponsivePadding({super.key, required this.child})
    : _kind = _OmniPaddingKind.page;

  /// Applies horizontal gutter padding (`tokens.horizontalPadding`).
  const OmniResponsivePadding.horizontal({super.key, required this.child})
    : _kind = _OmniPaddingKind.horizontal;

  /// Applies inner card padding (`tokens.cardPadding`).
  const OmniResponsivePadding.card({super.key, required this.child})
    : _kind = _OmniPaddingKind.card;

  /// Applies vertical+horizontal section padding (`tokens.sectionPadding`).
  const OmniResponsivePadding.section({super.key, required this.child})
    : _kind = _OmniPaddingKind.section;

  /// Descendant subtree to pad.
  final Widget child;

  final _OmniPaddingKind _kind;

  @override
  Widget build(BuildContext context) {
    final t = OmniResponsiveScope.tokensOf(context);
    final padding = switch (_kind) {
      _OmniPaddingKind.page => t.pagePadding,
      _OmniPaddingKind.horizontal => t.horizontalPadding,
      _OmniPaddingKind.card => t.cardPadding,
      _OmniPaddingKind.section => t.sectionPadding,
    };
    return Padding(padding: padding, child: child);
  }
}

/// Natural intrinsic-height responsive multi-column layout.
///
/// Unlike [GridView] (which enforces fixed aspect ratio rectangles that can clip
/// or overflow when text wraps), each item keeps its natural intrinsic height
/// while aligning into equal-width responsive columns (`mobileColumns`,
/// `tabletColumns`, `desktopColumns`, `largeDesktopColumns`), making it ideal
/// inside any `Column`, `ListView`, or form with **zero** overflow bugs.
class OmniResponsiveColumns extends StatelessWidget {
  /// Creates an overflow-free intrinsic-height responsive grid.
  const OmniResponsiveColumns({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.largeDesktopColumns = 4,
    this.spacing,
    this.runSpacing,
    this.rowCrossAxisAlignment = CrossAxisAlignment.start,
  }) : assert(mobileColumns > 0),
       assert(tabletColumns > 0),
       assert(desktopColumns > 0),
       assert(largeDesktopColumns > 0);

  /// Items arranged into equal-width responsive columns.
  final List<Widget> children;

  /// Column count on phones (defaults to `1`).
  final int mobileColumns;

  /// Column count on tablets (defaults to `2`).
  final int tabletColumns;

  /// Column count on desktops (defaults to `3`).
  final int desktopColumns;

  /// Column count on large monitors (defaults to `4`).
  final int largeDesktopColumns;

  /// Horizontal gap between columns (defaults to `tokens.gridSpacing`).
  final double? spacing;

  /// Vertical gap between rows (defaults to [spacing] / `tokens.gridSpacing`).
  final double? runSpacing;

  /// Vertical alignment of items within the same row.
  final CrossAxisAlignment rowCrossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final device = OmniResponsiveScope.deviceOf(context);
    final tokens = OmniResponsiveScope.tokensOf(context);
    final colGap = spacing ?? tokens.gridSpacing;
    final rowGap = runSpacing ?? colGap;
    final cols = switch (device) {
      OmniDeviceType.mobile => mobileColumns,
      OmniDeviceType.tablet => tabletColumns,
      OmniDeviceType.desktop => desktopColumns,
      OmniDeviceType.largeDesktop => largeDesktopColumns,
    };

    if (cols == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: rowGap,
        children: children,
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final rowChildren = <Widget>[];
      for (var c = 0; c < cols; c++) {
        final idx = i + c;
        rowChildren.add(
          Expanded(
            child: idx < children.length
                ? children[idx]
                : const SizedBox.shrink(),
          ),
        );
      }
      rows.add(
        Row(
          crossAxisAlignment: rowCrossAxisAlignment,
          spacing: colGap,
          children: rowChildren,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: rowGap,
      children: rows,
    );
  }
}

/// High-performance responsive grid backed directly by Flutter's native
/// `SliverGridDelegateWithMaxCrossAxisExtent` or breakpoint column counts.
///
/// When [maxItemWidth] is provided, column reflow runs completely inside C++
/// `RenderSliverGrid` layout at 120fps with **zero** Dart widget rebuilds on
/// resize. Otherwise, columns switch only at [OmniDeviceType] breakpoints.
class OmniResponsiveGrid extends StatelessWidget {
  /// Creates an eager responsive grid from [children].
  const OmniResponsiveGrid({
    super.key,
    required List<Widget> this.children,
    this.maxItemWidth,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.largeDesktopColumns,
    this.spacing,
    this.runSpacing,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
    this.padding,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.primary,
    this.clipBehavior = Clip.hardEdge,
    this.dragStartBehavior = DragStartBehavior.start,
  }) : itemCount = null,
       itemBuilder = null;

  /// Creates a lazily-built responsive grid for long or paginated item lists.
  const OmniResponsiveGrid.builder({
    super.key,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.maxItemWidth,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.largeDesktopColumns,
    this.spacing,
    this.runSpacing,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.primary,
    this.clipBehavior = Clip.hardEdge,
    this.dragStartBehavior = DragStartBehavior.start,
  }) : children = null;

  /// Fixed child list for the default constructor.
  final List<Widget>? children;

  /// Lazy item count for [OmniResponsiveGrid.builder].
  final int? itemCount;

  /// Lazy item builder for [OmniResponsiveGrid.builder].
  final IndexedWidgetBuilder? itemBuilder;

  /// If non-null, delegates reflow cleanly to `SliverGridDelegateWithMaxCrossAxisExtent`
  /// with zero Dart rebuilds during window resize.
  final double? maxItemWidth;

  /// Column count override on phones.
  final int? mobileColumns;

  /// Column count override on tablets.
  final int? tabletColumns;

  /// Column count override on desktops.
  final int? desktopColumns;

  /// Column count override on large desktop monitors.
  final int? largeDesktopColumns;

  /// Cross-axis spacing between tiles (defaults to `tokens.gridSpacing`).
  final double? spacing;

  /// Main-axis run spacing between rows (defaults to [spacing]).
  final double? runSpacing;

  /// Ratio of cross-axis to main-axis extent for each tile (ignored if
  /// [mainAxisExtent] is specified).
  final double childAspectRatio;

  /// Optional fixed vertical tile height in logical pixels across all columns.
  final double? mainAxisExtent;

  /// Optional outer padding around the grid.
  final EdgeInsetsGeometry? padding;

  /// Whether the grid sizes to its content (`true` for embedded grids).
  final bool shrinkWrap;

  /// Scroll physics (defaults to non-scrollable when [shrinkWrap] is used via
  /// default constructor).
  final ScrollPhysics? physics;

  /// Passed through to [GridView].
  final bool? primary;

  /// Passed through to [GridView].
  final Clip clipBehavior;

  /// Passed through to [GridView].
  final DragStartBehavior dragStartBehavior;

  @override
  Widget build(BuildContext context) {
    final tokens = OmniResponsiveScope.tokensOf(context);
    final delegate = resolveOmniGridDelegate(
      context,
      tokens: tokens,
      maxItemWidth: maxItemWidth,
      mobileColumns: mobileColumns,
      tabletColumns: tabletColumns,
      desktopColumns: desktopColumns,
      largeDesktopColumns: largeDesktopColumns,
      spacing: spacing,
      runSpacing: runSpacing,
      childAspectRatio: childAspectRatio,
      mainAxisExtent: mainAxisExtent,
    );

    if (itemBuilder case final builder?) {
      return GridView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        primary: primary,
        clipBehavior: clipBehavior,
        dragStartBehavior: dragStartBehavior,
        gridDelegate: delegate,
        itemCount: itemCount,
        itemBuilder: builder,
      );
    }

    return GridView(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      primary: primary,
      clipBehavior: clipBehavior,
      dragStartBehavior: dragStartBehavior,
      gridDelegate: delegate,
      children: children!,
    );
  }
}
