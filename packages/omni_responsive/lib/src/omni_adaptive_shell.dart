import 'package:flutter/material.dart';

import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';
import 'widgets/bottom_navigation/omni_bottom_navigation.dart';

/// Destination descriptor used by `OmniStatefulShell.adaptive(...)` to drive
/// bottom `NavigationBar` on mobile and `NavigationRail` on tablet/desktop
/// automatically while preserving tab stack state.
@immutable
class OmniAdaptiveDestination {
  /// Creates a navigation destination shared across mobile, tablet, and desktop.
  const OmniAdaptiveDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.tooltip,
    this.badgeCount,
    this.badgeText,
    this.showDotBadge = false,
    this.semanticLabel,
  });

  /// Default icon displayed when tab is inactive.
  final Widget icon;

  /// Optional icon displayed when tab is selected.
  final Widget? selectedIcon;

  /// Short label shown under the icon or beside it in extended desktop rail.
  final String label;

  /// Optional accessibility tooltip on hover/long-press.
  final String? tooltip;

  /// Number badge (`99+` above 99; hidden at 0 or `null`).
  final int? badgeCount;

  /// Text badge (wins over [badgeCount]).
  final String? badgeText;

  /// Small dot badge when there is no number or text.
  final bool showDotBadge;

  /// Screen-reader name (default: [label]) for the Omni bar
  /// (`bottomBarStyle`) and the rail. Material's `NavigationBar` reads
  /// [label].
  final String? semanticLabel;

  String? get _badgeLabel {
    if (badgeText != null && badgeText!.isNotEmpty) return badgeText;
    final count = badgeCount;
    if (count == null || count <= 0) return null;
    return count > 99 ? '99+' : '$count';
  }

  /// [icon] with this destination's badge, for Material's bar and rail.
  Widget _badged(Widget icon) {
    final label = _badgeLabel;
    if (label != null) return Badge(label: Text(label), child: icon);
    if (showDotBadge) return Badge(child: icon);
    return icon;
  }

  /// Rail icon: badge plus the tooltip the rail itself does not show.
  Widget _railIcon(Widget icon) {
    final badged = _badged(icon);
    final tip = tooltip;
    return tip == null || tip.isEmpty
        ? badged
        : Tooltip(message: tip, child: badged);
  }

  OmniBottomNavigationItem _toItem() => OmniBottomNavigationItem(
    icon: icon,
    selectedIcon: selectedIcon,
    label: label,
    tooltip: tooltip,
    badgeCount: badgeCount,
    badgeText: badgeText,
    showDotBadge: showDotBadge,
    semanticLabel: semanticLabel,
  );
}

/// Internal scaffold wired by `OmniStatefulShell.adaptive(...)`.
///
/// Subscribes ONLY to `_OmniResponsiveAspect.device` so resizing within a
/// tier or toggling the soft keyboard produces **zero** shell rebuilds, and
/// passes the exact same `navigationShell` `IndexedStack` across layout tiers
/// so active tab scroll & navigator state stay intact.
class OmniAdaptiveShellScaffold extends StatelessWidget {
  /// Creates an adaptive navigation shell wrapper around [navigationChild].
  const OmniAdaptiveShellScaffold({
    super.key,
    required this.currentIndex,
    required this.onSelectIndex,
    required this.destinations,
    required this.navigationChild,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.railLeading,
    this.railTrailing,
    this.extendedDesktopRail = true,
    this.bottomBarStyle,
    this.bottomBarTheme,
    this.extendBottomBar = true,
  });

  /// Currently selected branch index.
  final int currentIndex;

  /// Callback invoked when user taps a destination.
  final void Function(int index) onSelectIndex;

  /// Destinations mapped 1:1 to shell branches.
  final List<OmniAdaptiveDestination> destinations;

  /// Preserved stateful child (`OmniNavigationShell`) keeping per-tab stacks.
  final Widget navigationChild;

  /// Optional scaffold `AppBar`.
  final PreferredSizeWidget? appBar;

  /// Optional scaffold `FloatingActionButton`.
  final Widget? floatingActionButton;

  /// Optional scaffold background color.
  final Color? backgroundColor;

  /// Optional header widget at the top of the `NavigationRail`.
  final Widget? railLeading;

  /// Optional footer widget at the bottom of the `NavigationRail`.
  final Widget? railTrailing;

  /// Expand `NavigationRail` labels alongside icons on desktop/largeDesktop.
  final bool extendedDesktopRail;

  /// Optional [OmniBottomNavigationStyle] applied on mobile viewports instead
  /// of Material's default `NavigationBar`.
  final OmniBottomNavigationStyle? bottomBarStyle;

  /// Optional theme overrides paired with [bottomBarStyle].
  final OmniBottomNavigationStyleData? bottomBarTheme;

  /// Whether mobile `Scaffold.extendBody` is enabled when [bottomBarStyle] is
  /// active (default `true` for floating/glass/notched styles).
  final bool extendBottomBar;

  @override
  Widget build(BuildContext context) {
    final device = OmniResponsiveScope.deviceOf(context);
    if (device == OmniDeviceType.mobile) {
      final useCustomBar = bottomBarStyle != null || bottomBarTheme != null;
      return Scaffold(
        appBar: appBar,
        backgroundColor: backgroundColor,
        floatingActionButton: floatingActionButton,
        extendBody: useCustomBar && extendBottomBar,
        body: navigationChild,
        bottomNavigationBar: useCustomBar
            ? OmniBottomNavigationBar(
                style: bottomBarStyle,
                theme: bottomBarTheme,
                currentIndex: currentIndex,
                onTap: onSelectIndex,
                items: [for (final d in destinations) d._toItem()],
              )
            : NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: onSelectIndex,
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(
                      icon: d._badged(d.icon),
                      selectedIcon: d.selectedIcon == null
                          ? null
                          : d._badged(d.selectedIcon!),
                      label: d.label,
                      tooltip: d.tooltip,
                    ),
                ],
              ),
      );
    }

    final extended =
        extendedDesktopRail &&
        (device == OmniDeviceType.desktop ||
            device == OmniDeviceType.largeDesktop);

    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    extended: extended,
                    selectedIndex: currentIndex,
                    onDestinationSelected: onSelectIndex,
                    leading: railLeading,
                    trailing: railTrailing,
                    labelType: extended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: d._railIcon(d.icon),
                          selectedIcon: d._railIcon(d.selectedIcon ?? d.icon),
                          label: Text(d.label, semanticsLabel: d.semanticLabel),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationChild),
        ],
      ),
    );
  }
}
