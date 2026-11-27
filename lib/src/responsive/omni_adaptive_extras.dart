import 'package:flutter/material.dart';

import '../core/omni_route.dart';
import '../routing/omni_route_state.dart';
import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';

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
    final gap = spacing ?? tokens.gridSpacing;
    final rowGap = runSpacing ?? gap;

    final SliverGridDelegate delegate;
    if (maxItemWidth case final maxExtent?) {
      delegate = SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        crossAxisSpacing: gap,
        mainAxisSpacing: rowGap,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: mainAxisExtent,
      );
    } else {
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
      delegate = SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: gap,
        mainAxisSpacing: rowGap,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: mainAxisExtent,
      );
    }

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

/// Passive predictive route-prefetch trigger with zero gesture arena
/// overhead (`MouseRegion` on desktop/web hover + `Listener.onPointerDown` on
/// touch devices).
///
/// Triggers `OmniRoute.prefetch(location, context: context)` right before a
/// user completes tapping or clicking a link, eliminating perceptible loading
/// latency on target pages declaring `OmniPage(onPrefetch: ...)`.
class OmniPrefetch extends StatelessWidget {
  /// Wraps [child] to prefetch [location] cleanly ahead of navigation.
  const OmniPrefetch({
    super.key,
    required this.location,
    required this.child,
    this.enabled = true,
    this.ttl = const Duration(seconds: 30),
  });

  /// Target URI/path to prefetch (e.g. `'/products/42'`).
  final String location;

  /// Interactive child widget (e.g. `Card`, `ListTile`, or `InkWell`).
  final Widget child;

  /// Disables prefetching when `false` with zero extra wrappers.
  final bool enabled;

  /// Deduplication cache window so repeated hovers do not hammer backends.
  final Duration ttl;

  void _trigger(BuildContext context) {
    OmniRoute.prefetch(location, context: context, ttl: ttl);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return MouseRegion(
      opaque: false,
      onEnter: (_) => _trigger(context),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _trigger(context),
        child: child,
      ),
    );
  }
}

/// Adaptive URL breadcrumb navigation bar for tablet & desktop viewports.
///
/// Hidden automatically on [OmniDeviceType.mobile] (returns `const
/// SizedBox.shrink()`) unless [showOnMobile] is `true`. Tapping any ancestor
/// segment navigates directly back up the path hierarchy.
class OmniBreadcrumbBar extends StatelessWidget {
  /// Creates an interactive path breadcrumb bar.
  const OmniBreadcrumbBar({
    super.key,
    this.rootLabel = 'Home',
    this.rootPath = '/',
    this.labelFormatter,
    this.showOnMobile = false,
    this.separator = const Icon(Icons.chevron_right, size: 16),
    this.padding,
    this.onTapSegment,
  });

  /// Label displayed for the root `'/'` segment.
  final String rootLabel;

  /// Target location navigated when tapping [rootLabel].
  final String rootPath;

  /// Optional custom display label formatter given each raw URL segment.
  final String Function(String segment)? labelFormatter;

  /// Whether to render on compact phone screens (default `false`).
  final bool showOnMobile;

  /// Widget rendered between adjacent path segments.
  final Widget separator;

  /// Outer padding override (defaults to `tokens.horizontalPadding`).
  final EdgeInsetsGeometry? padding;

  /// Optional custom tap override; defaults to `context.go(targetPath)`.
  final void Function(BuildContext context, String targetPath)? onTapSegment;

  String _format(String seg) {
    if (labelFormatter != null) return labelFormatter!(seg);
    final clean = seg.replaceAll('-', ' ').replaceAll('_', ' ');
    if (clean.isEmpty) return seg;
    return clean[0].toUpperCase() + clean.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (!showOnMobile && OmniResponsiveScope.deviceOf(context) == OmniDeviceType.mobile) {
      return const SizedBox.shrink();
    }

    final state = OmniRouteState.maybeOf(context);
    final segments = state?.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    final theme = Theme.of(context);
    final effectivePadding =
        padding ?? OmniResponsiveScope.tokensOf(context).horizontalPadding;

    void navigate(String path) {
      if (onTapSegment != null) {
        onTapSegment!(context, path);
      } else {
        context.go(path);
      }
    }

    return Padding(
      padding: effectivePadding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BreadcrumbItem(
              label: rootLabel,
              isLast: segments.isEmpty,
              theme: theme,
              onTap: segments.isEmpty ? null : () => navigate(rootPath),
            ),
            for (var i = 0; i < segments.length; i++) ...[
              separator,
              _BreadcrumbItem(
                label: _format(segments[i]),
                isLast: i == segments.length - 1,
                theme: theme,
                onTap: i == segments.length - 1
                    ? null
                    : () => navigate('/${segments.sublist(0, i + 1).join('/')}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  const _BreadcrumbItem({
    required this.label,
    required this.isLast,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool isLast;
  final ThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = isLast
        ? theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label, style: style),
      );
    }
    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label, style: style),
      ),
    );
  }
}
