import 'package:flutter/material.dart';

import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';
import 'omni_responsive_widgets.dart';

/// Lazy, sliver-virtualized responsive grid for `CustomScrollView`.
///
/// Unlike `GridView(shrinkWrap: true)` inside a `SingleChildScrollView`, this
/// sliver builds **only the visible items on screen** (`O(visible)` memory)
/// and delegates layout directly to C++ `RenderSliverGrid` at 120fps:
/// - Pass [maxItemWidth] for zero Dart rebuilds across window resizes, or
/// - Omit [maxItemWidth] to step discrete column counts at [OmniDeviceType]
///   breakpoints cleanly.
class OmniResponsiveSliverGrid extends StatelessWidget {
  /// Creates a lazily-built responsive sliver grid from [itemCount] and
  /// [itemBuilder].
  const OmniResponsiveSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxItemWidth,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.largeDesktopColumns,
    this.spacing,
    this.runSpacing,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
  }) : assert(maxItemWidth == null || maxItemWidth > 0);

  /// Total number of virtualized tiles.
  final int? itemCount;

  /// Called lazily for visible tiles only.
  final NullableIndexedWidgetBuilder itemBuilder;

  /// Optional maximum tile width driving `SliverGridDelegateWithMaxCrossAxisExtent`
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

  /// Cross-axis gap between tiles (defaults to `tokens.gridSpacing`).
  final double? spacing;

  /// Main-axis gap between rows (defaults to [spacing]).
  final double? runSpacing;

  /// Tile width/height aspect ratio (ignored when [mainAxisExtent] is set).
  final double childAspectRatio;

  /// Optional fixed tile height in logical pixels.
  final double? mainAxisExtent;

  /// Forwarded to [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  /// Forwarded to [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

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

    return SliverGrid(
      gridDelegate: delegate,
      delegate: SliverChildBuilderDelegate(
        itemBuilder,
        childCount: itemCount,
        addAutomaticKeepAlives: addAutomaticKeepAlives,
        addRepaintBoundaries: addRepaintBoundaries,
      ),
    );
  }
}
