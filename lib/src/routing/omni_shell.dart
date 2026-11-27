import 'package:flutter/material.dart';

import '../bloc/omni_bloc.dart';
import '../guards/omni_guard.dart';
import '../responsive/omni_adaptive_shell.dart';
import 'omni_route_state.dart';

/// Builds a shared shell layout around child routes.
typedef OmniShellBuilder =
    Widget Function(BuildContext context, OmniRouteState state, Widget child);

/// Builds a persistent tabbed shell layout around an [OmniNavigationShell].
typedef OmniStatefulShellBuilder =
    Widget Function(
      BuildContext context,
      OmniRouteState state,
      OmniNavigationShell navigationShell,
    );

/// A shared layout around child [routes] with optional Blocs that live as
/// long as the shell stays on the navigation stack.
class OmniShell extends OmniRouteBase {
  /// Creates a layout shell wrapping [routes].
  const OmniShell({
    required this.builder,
    required this.routes,
    this.provide = const [],
    this.navigatorKey,
    this.parentNavigatorKey,
    this.observers = const [],
    this.guards = const [],
  });

  /// Builds the chrome (app bar, drawer, rail, etc.) around [child].
  final OmniShellBuilder builder;

  /// Child routes rendered inside this shell's navigator.
  final List<OmniRouteBase> routes;

  /// Blocs scoped to the lifetime of this shell.
  final List<OmniBlocEntry> provide;

  /// Optional key for the shell's inner navigator.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Optional outer navigator key when nested inside another shell/root.
  final GlobalKey<NavigatorState>? parentNavigatorKey;

  /// Navigator observers attached to the shell's inner navigator.
  final List<NavigatorObserver> observers;

  /// Guards applied to every route inside this shell.
  final List<OmniGuard> guards;

  @override
  List<OmniRouteBase> get childRoutes => routes;
}

/// One independent navigation stack inside an [OmniStatefulShell] (such as a
/// bottom-navigation tab).
class OmniBranch {
  /// Creates a tab branch holding [routes].
  const OmniBranch({
    required this.routes,
    this.initialLocation,
    this.provide = const [],
    this.navigatorKey,
    this.observers = const [],
    this.restorationScopeId,
  });

  /// Routes inside this tab branch.
  final List<OmniRouteBase> routes;

  /// Initial location when first displaying this tab. Defaults to the first
  /// [OmniPage] inside [routes].
  final String? initialLocation;

  /// Blocs scoped to this branch while the stateful shell is mounted.
  final List<OmniBlocEntry> provide;

  /// Optional navigator key for this branch's stack.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Observers attached to this branch's navigator.
  final List<NavigatorObserver> observers;

  /// Restoration scope ID for this branch's navigator.
  final String? restorationScopeId;
}

/// Persistent indexed-stack shell: each [OmniBranch] keeps its own
/// navigation stack, widget state and Blocs while switching tabs.
///
/// ```dart
/// OmniStatefulShell(
///   builder: (context, state, shell) => Scaffold(
///     body: shell,
///     bottomNavigationBar: NavigationBar(
///       selectedIndex: shell.currentIndex,
///       onDestinationSelected: shell.goBranch,
///       destinations: [...],
///     ),
///   ),
///   branches: [
///     OmniBranch(routes: [OmniPage('/home', (_) => const HomeScreen())]),
///     OmniBranch(routes: [OmniPage('/profile', (_) => const ProfileScreen())]),
///   ],
/// )
/// ```
class OmniStatefulShell extends OmniRouteBase {
  /// Creates a stateful tabbed shell from [branches].
  const OmniStatefulShell({
    required this.builder,
    required this.branches,
    this.provide = const [],
    this.parentNavigatorKey,
    this.restorationScopeId,
    this.guards = const [],
  });

  /// Creates an adaptive navigation shell that automatically switches between a
  /// bottom `NavigationBar` on phones, a compact `NavigationRail` on tablets,
  /// and an extended `NavigationRail` on desktops while preserving every tab's
  /// navigation stack and scroll state.
  factory OmniStatefulShell.adaptive({
    required List<OmniAdaptiveDestination> destinations,
    required List<OmniBranch> branches,
    PreferredSizeWidget? Function(
      BuildContext context,
      OmniRouteState state,
      OmniNavigationShell shell,
    )?
    appBarBuilder,
    PreferredSizeWidget? appBar,
    Widget? Function(
      BuildContext context,
      OmniRouteState state,
      OmniNavigationShell shell,
    )?
    floatingActionButtonBuilder,
    Widget? floatingActionButton,
    Color? backgroundColor,
    Widget? railLeading,
    Widget? railTrailing,
    bool extendedDesktopRail = true,
    bool resetTabOnReselect = true,
    List<OmniBlocEntry> provide = const [],
    GlobalKey<NavigatorState>? parentNavigatorKey,
    String? restorationScopeId,
    List<OmniGuard> guards = const [],
  }) {
    assert(
      destinations.length == branches.length,
      'OmniStatefulShell.adaptive requires destinations.length (${destinations.length}) '
      'to match branches.length (${branches.length}).',
    );
    return OmniStatefulShell(
      branches: branches,
      provide: provide,
      parentNavigatorKey: parentNavigatorKey,
      restorationScopeId: restorationScopeId,
      guards: guards,
      builder: (context, state, shell) => OmniAdaptiveShellScaffold(
        currentIndex: shell.currentIndex,
        onSelectIndex: (index) => shell.goBranch(
          index,
          initialLocation: resetTabOnReselect && index == shell.currentIndex,
        ),
        destinations: destinations,
        appBar: appBarBuilder?.call(context, state, shell) ?? appBar,
        floatingActionButton:
            floatingActionButtonBuilder?.call(context, state, shell) ??
            floatingActionButton,
        backgroundColor: backgroundColor,
        railLeading: railLeading,
        railTrailing: railTrailing,
        extendedDesktopRail: extendedDesktopRail,
        navigationChild: shell,
      ),
    );
  }

  /// Builds the shell UI around [OmniNavigationShell].
  final OmniStatefulShellBuilder builder;

  /// Independent tab branches managed as an indexed stack.
  final List<OmniBranch> branches;

  /// Blocs shared across the whole stateful shell.
  final List<OmniBlocEntry> provide;

  /// Optional outer navigator key.
  final GlobalKey<NavigatorState>? parentNavigatorKey;

  /// Restoration scope ID for the shell state (active tab and branch stacks).
  final String? restorationScopeId;

  /// Guards applied to all routes inside [branches].
  final List<OmniGuard> guards;

  @override
  List<OmniRouteBase> get childRoutes => [
    for (final b in branches) ...b.routes,
  ];
}

/// Widget and controller passed to [OmniStatefulShell.builder].
///
/// Renders the persistent `IndexedStack` of tab navigators and exposes
/// [currentIndex] and [goBranch] to switch tabs cleanly.
class OmniNavigationShell extends StatelessWidget {
  /// Creates a navigation shell widget wrapper.
  const OmniNavigationShell({
    super.key,
    required this.currentIndex,
    required this.onGoBranch,
    required this.branchChildren,
  });

  /// Currently active branch index (`0 .. branchCount - 1`).
  final int currentIndex;

  /// Callback invoked by [goBranch].
  final void Function(int index, {bool initialLocation}) onGoBranch;

  /// Pre-built per-branch subtree widgets displayed in an [IndexedStack].
  final List<Widget> branchChildren;

  /// Number of branches inside this shell.
  int get branchCount => branchChildren.length;

  /// Switches to tab [index]. When [initialLocation] is `true`, resets that
  /// branch back to its initial root page in one frame.
  void goBranch(int index, {bool initialLocation = false}) =>
      onGoBranch(index, initialLocation: initialLocation);

  @override
  Widget build(BuildContext context) =>
      IndexedStack(index: currentIndex, children: branchChildren);
}
