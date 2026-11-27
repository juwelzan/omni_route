import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../bloc/omni_bloc.dart';
import '../core/omni_route.dart';
import '../routing/omni_page.dart';
import '../routing/omni_path.dart';
import '../routing/omni_trie.dart';
import 'omni_screen_host.dart';

/// Immutable description of a screen, identified across the router by
/// [routePath] and runtime [type].
@immutable
class OmniScreenMetadata {
  /// Creates screen metadata.
  const OmniScreenMetadata({
    required this.type,
    required this.routePath,
    required this.title,
    required this.debugName,
  });

  /// The screen's Dart type: its stable runtime identity.
  final Type type;

  /// Canonical route path for this screen (see [OmniScreen.routePath]).
  final String routePath;

  /// Browser tab / app-switcher title (see [OmniScreen.title]).
  final String title;

  /// Runtime class name, for logs only.
  final String debugName;

  @override
  bool operator ==(Object other) =>
      other is OmniScreenMetadata &&
      other.type == type &&
      other.routePath == routePath &&
      other.title == title;

  @override
  int get hashCode => Object.hash(type, routePath, title);

  @override
  String toString() => 'OmniScreenMetadata($debugName, "$routePath")';
}

/// Shared API of [OmniStatelessWidget] and [OmniStatefulWidget].
///
/// Every screen declares its canonical [routePath] (e.g. `'/dashboard'`,
/// `'/students/:id'`, or relative child `'profile'`), which identifies the
/// page across routes, `OmniRoute.current`/`stack`, `RouteSettings.name`,
/// navigation logs, and built-in navigation shortcuts.
mixin OmniScreen on Widget {
  /// Canonical route path for this screen (e.g. `'/students'`,
  /// `'/students/:id'`). Used everywhere to recognize and identify this page.
  String get routePath;

  /// Browser tab / app-switcher title. Defaults to a formatted label derived
  /// from [routePath] (e.g. `'/students'` -> `'Students'`, `'/'` -> `'Home'`).
  String get title => defaultTitleFromRoutePath(routePath);

  /// Page-scoped Blocs created when entering this screen and closed when
  /// leaving it.
  ///
  /// Accepts `OmniBloc((_) => MyBloc())` (automatically registered on first page
  /// entry without pre-registering in `OmniApp(blocs: ...)`), `Provide<B>()`,
  /// `Provide.create(...)`, `Provide.eager(...)`, or `Provide.value(...)`.
  List<Provide> get provide => const [];

  /// Runtime class name, for debugging/logging only. Not stable under
  /// obfuscation.
  String get debugName => runtimeType.toString();

  /// This screen's metadata.
  OmniScreenMetadata get metadata => OmniScreenMetadata(
    type: runtimeType,
    routePath: routePath,
    title: title,
    debugName: debugName,
  );

  /// Resolves [routePath] by substituting `:param` placeholders from [path] and
  /// appending non-null [query] parameters.
  String resolvePath({
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
  }) => OmniRouteTrie.formatLocation(routePath, params: path, query: query);

  /// Navigates via `go` to this screen's [routePath].
  void go(
    BuildContext context, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
    bool replaceHistory = false,
  }) => context.go(
    resolvePath(path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
    replaceHistory: replaceHistory,
  );

  /// Navigates via `push` to this screen's [routePath].
  Future<R?> push<R extends Object?>(
    BuildContext context, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => context.push<R>(
    resolvePath(path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Smart duplicate-free `open` targeting this screen's [routePath].
  Future<R?> open<R extends Object?>(
    BuildContext context, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    int maxDepth = 10,
    bool animated = true,
    OmniPageType? transition,
  }) => context.open<R>(
    resolvePath(path: path, query: query),
    extra: extra,
    maxDepth: maxDepth,
    animated: animated,
    transition: transition,
  );

  /// Replaces the current top page with this screen's [routePath].
  void replace(
    BuildContext context, {
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? extra,
    bool animated = true,
    OmniPageType? transition,
  }) => context.replace(
    resolvePath(path: path, query: query),
    extra: extra,
    animated: animated,
    transition: transition,
  );

  /// Wraps this screen in [OmniScreenHost] when embedded directly outside an
  /// [OmniPage] route (useful for stateful screens with page Blocs).
  Widget hosted({Key? key}) => OmniScreenHost(key: key, screen: this);
}

/// Throws if [screen]'s `routePath` is empty or invalid.
@internal
void validateScreen(OmniScreen screen) {
  validateScreenRoutePath(screen.routePath);
}
