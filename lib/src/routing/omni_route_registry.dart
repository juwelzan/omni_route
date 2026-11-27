import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../errors/omni_route_exception.dart';
import '../guards/omni_guard.dart';
import 'omni_page.dart';
import 'omni_path.dart';
import 'omni_route_group.dart';
import 'omni_route_state.dart';
import 'omni_shell.dart';
import 'omni_trie.dart';

/// Compiled descriptor for an [OmniRouteGroup] in the route tree.
@internal
class CompiledGroup {
  const CompiledGroup({required this.id, required this.group});

  final int id;
  final OmniRouteGroup group;
}

/// Shared interface for compiled navigator shells ([CompiledShell] or
/// [CompiledBranchRef]).
@internal
sealed class CompiledShellRef {
  const CompiledShellRef();

  int get shellId;
  GlobalKey<NavigatorState> get navigatorKey;
}

/// Compiled descriptor for an [OmniShell].
@internal
class CompiledShell extends CompiledShellRef {
  const CompiledShell({
    required this.id,
    required this.shell,
    required this.navigatorKey,
    this.parentNavigatorKey,
  });

  final int id;
  final OmniShell shell;

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  final GlobalKey<NavigatorState>? parentNavigatorKey;

  @override
  int get shellId => id;
}

/// Compiled descriptor for one tab branch of an [OmniStatefulShell].
@internal
class CompiledBranch {
  CompiledBranch({
    required this.parent,
    required this.branchIndex,
    required this.branch,
    required this.navigatorKey,
  });

  final CompiledStatefulShell parent;
  final int branchIndex;
  final OmniBranch branch;
  final GlobalKey<NavigatorState> navigatorKey;

  /// First matched page path in this branch (or explicit `initialLocation`).
  late final String defaultLocation;
}

/// Reference to a specific branch inside a [CompiledStatefulShell].
@internal
class CompiledBranchRef extends CompiledShellRef {
  const CompiledBranchRef({
    required this.statefulShell,
    required this.branchIndex,
  });

  final CompiledStatefulShell statefulShell;
  final int branchIndex;

  @override
  int get shellId => statefulShell.id;

  @override
  GlobalKey<NavigatorState> get navigatorKey =>
      statefulShell.branches[branchIndex].navigatorKey;

  CompiledBranch get compiledBranch => statefulShell.branches[branchIndex];
}

/// Compiled descriptor for an [OmniStatefulShell].
@internal
class CompiledStatefulShell {
  CompiledStatefulShell({
    required this.id,
    required this.shell,
    required this.branches,
  });

  final int id;
  final OmniStatefulShell shell;
  final List<CompiledBranch> branches;
}

/// Fully compiled metadata for a reachable [OmniPage].
@internal
class CompiledRoute {
  CompiledRoute({
    required this.page,
    required this.fullPath,
    required this.groups,
    required this.shellChain,
    required this.fullEnclosingShells,
    required this.outerShellAncestors,
    required this.guards,
  });

  final OmniPage page;
  final String fullPath;
  final List<CompiledGroup> groups;
  final List<CompiledShellRef> shellChain;
  final List<CompiledShellRef> fullEnclosingShells;
  late final List<CompiledRoute> sameNavigatorAncestors;
  final List<CompiledRoute> outerShellAncestors;
  final List<OmniGuard> guards;

  OmniPageType? get groupTransition {
    for (var i = groups.length - 1; i >= 0; i--) {
      final t = groups[i].group.transition;
      if (t != null) return t;
    }
    return null;
  }

  Object? get targetNavIdentity =>
      shellChain.isEmpty ? null : shellChain.last.navigatorKey;
}

/// Result of matching a [Uri] against the compiled route trie.
@internal
class CompiledMatch {
  const CompiledMatch(this.route, this.pathParameters);

  final CompiledRoute route;
  final Map<String, String> pathParameters;
}

/// Validates and compiles the route tree once at startup into an O(depth)
/// Segment Trie, route name table, and screen `Type` index.
@internal
class OmniRouteRegistry {
  OmniRouteRegistry(
    List<OmniRouteBase> routes, {
    required GlobalKey<NavigatorState> rootNavigatorKey,
  }) {
    final allPaths = <String>[];
    final names = <String, CompiledRoute>{};
    final byRoutePath = <String, CompiledRoute>{};
    var nextShellId = 0;
    var nextGroupId = 0;

    void walk(
      List<OmniRouteBase> list, {
      required String parentPath,
      required bool topLevel,
      required List<CompiledGroup> groups,
      required List<CompiledShellRef> shells,
      required List<CompiledRoute> ancestorPages,
      required List<OmniGuard> guards,
      CompiledBranch? activeBranch,
      void Function(String firstPath)? onFirstBranchPage,
    }) {
      for (final node in list) {
        switch (node) {
          case OmniPage():
            var nodePath = node.path;
            if (!topLevel &&
                parentPath == '/' &&
                node.usesScreenPath &&
                nodePath.startsWith('/') &&
                nodePath.length > 1) {
              nodePath = nodePath.substring(1);
            } else if (!topLevel &&
                parentPath != '/' &&
                nodePath.startsWith('$parentPath/')) {
              nodePath = nodePath.substring(parentPath.length + 1);
            }
            if (node.usesScreenPath && nodePath.trim().isEmpty) {
              throw OmniRouteException(
                OmniErrorCode.emptyRoutePath,
                'OmniPage.screen(${node.screenType}) requires an OmniScreen '
                'or an explicit `path:` argument.',
                hint:
                    'Extend OmniStatelessWidget/OmniStatefulWidget with '
                    '`routePath` or pass `path: "/my-route"`.',
              );
            }
            validateRoutePath(nodePath, topLevel: topLevel);
            final fullPath = topLevel || nodePath.startsWith('/')
                ? nodePath
                : (parentPath == '/' ? '/$nodePath' : '$parentPath/$nodePath');
            if (!topLevel && fullPath != nodePath) {
              validateRoutePath(fullPath, topLevel: true);
            }
            allPaths.add(fullPath);
            onFirstBranchPage?.call(fullPath);

            final targetShells = _resolveTargetShells(
              shells,
              node.parentNavigatorKey,
              rootNavigatorKey,
            );
            final targetKey = targetShells.isEmpty
                ? null
                : targetShells.last.navigatorKey;

            final sameNavAncestors = <CompiledRoute>[];
            final outerAncestors = <CompiledRoute>[];
            for (final anc in ancestorPages) {
              if (anc.targetNavIdentity == targetKey) {
                sameNavAncestors.add(anc);
              } else {
                outerAncestors.add(anc);
              }
            }

            final pageGuards = List<OmniGuard>.unmodifiable([
              ...guards,
              ...node.guards,
            ]);
            routeGuards.addAll(node.guards);

            final stored = CompiledRoute(
              page: node,
              fullPath: fullPath,
              groups: List.unmodifiable(groups),
              shellChain: targetShells,
              fullEnclosingShells: List.unmodifiable(shells),
              outerShellAncestors: List.unmodifiable(outerAncestors),
              guards: pageGuards,
            );
            stored.sameNavigatorAncestors = List<CompiledRoute>.unmodifiable([
              ...sameNavAncestors,
              stored,
            ]);

            final name = node.name;
            if (name != null) {
              final existing = names[name];
              if (existing != null) {
                throw OmniRouteException(
                  OmniErrorCode.duplicateRoute,
                  'Route name "$name" is used by both '
                  '${existing.fullPath} and $fullPath.',
                  hint: 'Route names must be unique; rename one of them.',
                );
              }
              names[name] = stored;
            }

            _byType.update(
              node.screenType,
              (_) => null,
              ifAbsent: () => fullPath,
            );
            byRoutePath[fullPath] = stored;
            _trie.insert(fullPath, stored);

            walk(
              node.routes,
              parentPath: fullPath,
              topLevel: false,
              groups: groups,
              shells: shells,
              ancestorPages: [...ancestorPages, stored],
              guards: pageGuards,
              activeBranch: activeBranch,
            );

          case OmniRouteGroup():
            final compiledGroup = CompiledGroup(id: nextGroupId++, group: node);
            routeGuards.addAll(node.guards);
            walk(
              node.routes,
              parentPath: parentPath,
              topLevel: topLevel,
              groups: [...groups, compiledGroup],
              shells: shells,
              ancestorPages: ancestorPages,
              guards: [...guards, ...node.guards],
              activeBranch: activeBranch,
              onFirstBranchPage: onFirstBranchPage,
            );

          case OmniShell():
            final id = nextShellId++;
            final compiledShell = CompiledShell(
              id: id,
              shell: node,
              navigatorKey:
                  node.navigatorKey ??
                  GlobalKey<NavigatorState>(debugLabel: 'OmniShell_$id'),
              parentNavigatorKey: node.parentNavigatorKey,
            );
            routeGuards.addAll(node.guards);
            final targetShells = _resolveTargetShells(
              shells,
              node.parentNavigatorKey,
              rootNavigatorKey,
            );
            walk(
              node.routes,
              parentPath: parentPath,
              topLevel: topLevel,
              groups: groups,
              shells: [...targetShells, compiledShell],
              ancestorPages: ancestorPages,
              guards: [...guards, ...node.guards],
              activeBranch: activeBranch,
              onFirstBranchPage: onFirstBranchPage,
            );

          case OmniStatefulShell():
            if (node.branches.isEmpty) {
              throw const OmniRouteException(
                OmniErrorCode.unsupportedConfiguration,
                'OmniStatefulShell must have at least one OmniBranch.',
              );
            }
            final id = nextShellId++;
            final compiledBranches = <CompiledBranch>[];
            final statefulShell = CompiledStatefulShell(
              id: id,
              shell: node,
              branches: compiledBranches,
            );
            routeGuards.addAll(node.guards);
            final shellGuards = [...guards, ...node.guards];
            final baseShells = _resolveTargetShells(
              shells,
              node.parentNavigatorKey,
              rootNavigatorKey,
            );

            for (var i = 0; i < node.branches.length; i++) {
              final b = node.branches[i];
              final compiledBranch = CompiledBranch(
                parent: statefulShell,
                branchIndex: i,
                branch: b,
                navigatorKey:
                    b.navigatorKey ??
                    GlobalKey<NavigatorState>(
                      debugLabel: 'OmniBranch_${id}_$i',
                    ),
              );
              compiledBranches.add(compiledBranch);
              String? firstPath;
              walk(
                b.routes,
                parentPath: parentPath,
                topLevel: topLevel,
                groups: groups,
                shells: [
                  ...baseShells,
                  CompiledBranchRef(
                    statefulShell: statefulShell,
                    branchIndex: i,
                  ),
                ],
                ancestorPages: ancestorPages,
                guards: shellGuards,
                activeBranch: compiledBranch,
                onFirstBranchPage: (p) => firstPath ??= p,
              );
              final initial = b.initialLocation ?? firstPath;
              if (initial == null) {
                throw const OmniRouteException(
                  OmniErrorCode.missingRoute,
                  'An OmniBranch in OmniStatefulShell has no OmniPage routes.',
                  hint: 'Add at least one OmniPage inside each OmniBranch.',
                );
              }
              compiledBranch.defaultLocation = initial;
            }
        }
      }
    }

    walk(
      routes,
      parentPath: '',
      topLevel: true,
      groups: const [],
      shells: const [],
      ancestorPages: const [],
      guards: const [],
    );

    checkDuplicatePaths(allPaths);
    paths = List.unmodifiable(allPaths);
    _byName = Map.unmodifiable(names);
    _byRoutePath = Map.unmodifiable(byRoutePath);
  }

  static List<CompiledShellRef> _resolveTargetShells(
    List<CompiledShellRef> enclosing,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    GlobalKey<NavigatorState> rootNavigatorKey,
  ) {
    if (parentNavigatorKey == null) return List.unmodifiable(enclosing);
    if (parentNavigatorKey == rootNavigatorKey) return const [];
    for (var i = enclosing.length - 1; i >= 0; i--) {
      if (enclosing[i].navigatorKey == parentNavigatorKey) {
        return List.unmodifiable(enclosing.sublist(0, i + 1));
      }
    }
    return const [];
  }

  final OmniRouteTrie<CompiledRoute> _trie = OmniRouteTrie<CompiledRoute>();
  final Map<Type, String?> _byType = {};
  late final Map<String, CompiledRoute> _byName;
  late final Map<String, CompiledRoute> _byRoutePath;

  /// All registered full route paths in declaration order.
  late final List<String> paths;

  /// Guards declared across routes, groups and shells, in tree order.
  final List<OmniGuard> routeGuards = [];

  /// Looks up a compiled route by its canonical [routePath] pattern.
  CompiledRoute? routeAt(String routePath) => _byRoutePath[routePath];

  /// Matches [uri] against the Segment Trie in O(segments) time.
  CompiledMatch? matchUri(Uri uri) {
    final hit = _trie.matchUri(uri);
    if (hit == null) return null;
    return CompiledMatch(hit.value, hit.pathParameters);
  }

  /// Looks up a named route compiled in this tree.
  CompiledRoute routeNamed(String name) =>
      _byName[name] ??
      (throw OmniRouteException(
        OmniErrorCode.missingRoute,
        'No route named "$name".',
        hint: 'Add name: "$name" to the target OmniPage.',
      ));

  /// Resolves the full URL path registered for screen type [screen].
  String pathFor(Type screen) {
    if (!_byType.containsKey(screen)) {
      throw OmniRouteException(
        OmniErrorCode.missingRoute,
        'No OmniPage builds $screen.',
        hint:
            'Add OmniPage(..., (_) => $screen(...)) or OmniPage.screen(const $screen()). '
            'If your routes are in a List<OmniPage>, Dart infers '
            'OmniPage<Widget> and loses the screen type: use List<OmniRouteBase> '
            'or write OmniPage<$screen>(...).',
      );
    }
    return _byType[screen] ??
        (throw OmniRouteException(
          OmniErrorCode.unsupportedConfiguration,
          '$screen is used by several routes; navigation by type is ambiguous.',
          hint: 'Navigate by path, or give the route a `name` and use goNamed.',
        ));
  }

  /// Fills `:params` in [path] and appends non-null [query] parameters.
  static String location(
    String path, {
    Map<String, Object?> params = const {},
    Map<String, Object?> query = const {},
  }) => OmniRouteTrie.formatLocation(path, params: params, query: query);
}
