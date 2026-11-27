import 'package:flutter/material.dart';
import 'package:omni_responsive/omni_responsive.dart';

import '../core/omni_route.dart';
import 'omni_route_state.dart';

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
    if (!showOnMobile &&
        OmniResponsiveScope.deviceOf(context) == OmniDeviceType.mobile) {
      return const SizedBox.shrink();
    }

    final state = OmniRouteState.maybeOf(context);
    final segments =
        state?.uri.pathSegments
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
                    : () =>
                          navigate('/${segments.sublist(0, i + 1).join('/')}'),
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
