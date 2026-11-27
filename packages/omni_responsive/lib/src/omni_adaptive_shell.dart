import 'package:flutter/material.dart';

import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';

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
  });

  /// Default icon displayed when tab is inactive.
  final Widget icon;

  /// Optional icon displayed when tab is selected.
  final Widget? selectedIcon;

  /// Short label shown under the icon or beside it in extended desktop rail.
  final String label;

  /// Optional accessibility tooltip on hover/long-press.
  final String? tooltip;
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

  @override
  Widget build(BuildContext context) {
    final device = OmniResponsiveScope.deviceOf(context);
    if (device == OmniDeviceType.mobile) {
      return Scaffold(
        appBar: appBar,
        backgroundColor: backgroundColor,
        floatingActionButton: floatingActionButton,
        body: navigationChild,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onSelectIndex,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: d.label,
                tooltip: d.tooltip,
              ),
          ],
        ),
      );
    }

    final extended = extendedDesktopRail &&
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
                          icon: d.icon,
                          selectedIcon: d.selectedIcon ?? d.icon,
                          label: Text(d.label),
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
