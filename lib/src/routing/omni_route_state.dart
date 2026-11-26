import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'omni_params.dart';

/// Base class for all route nodes in an [OmniApp] (`OmniPage`,
/// `OmniRouteGroup`, `OmniShell`, `OmniStatefulShell`).
abstract class OmniRouteBase {
  /// Constant constructor for route nodes.
  const OmniRouteBase();

  /// Child routes nested under this route node.
  List<OmniRouteBase> get childRoutes;
}

/// Snapshot of the matched route for a page: location, parsed parameters,
/// extra object, metadata, and unique page key.
@immutable
class OmniRouteState {
  /// Creates a route state snapshot.
  const OmniRouteState({
    required this.uri,
    required this.matchedLocation,
    required this.pageKey,
    this.path,
    this.name,
    this.pathParameters = const {},
    this.extra,
    this.metadata,
    this.error,
  });

  /// Full URI including path, query parameters and fragment.
  final Uri uri;

  /// Full location string, e.g. `/students/7?tab=info`.
  String get location => uri.toString();

  /// Matched path without query or fragment, e.g. `/students/7`.
  final String matchedLocation;

  /// Route pattern as declared, e.g. `:id` or `/students/:id`.
  final String? path;

  /// Optional route name (`OmniPage(..., name: ...)`).
  final String? name;

  /// Decoded path parameters keyed by parameter name.
  final Map<String, String> pathParameters;

  /// Decoded single query parameters.
  Map<String, String> get queryParameters => uri.queryParameters;

  /// Decoded multi-value query parameters.
  Map<String, List<String>> get queryParametersAll => uri.queryParametersAll;

  /// Typed parameter helper for this route state.
  OmniParams get params => OmniParams(this);

  /// Arbitrary extra object passed to navigation methods.
  final Object? extra;

  /// Route metadata (`OmniPage(metadata: ...)`).
  final Map<String, dynamic>? metadata;

  /// Stable key for the [Page] representing this route instance.
  final ValueKey<String> pageKey;

  /// Error attached when a route is missing or a redirect fails.
  final Object? error;

  /// Finds the [OmniRouteState] of the route built above [context].
  static OmniRouteState of(BuildContext context) =>
      maybeOf(context) ??
      (throw FlutterError(
        'OmniRouteState.of(context) called with a context that has no '
        'OmniPage above it.',
      ));

  /// Finds the [OmniRouteState] above [context], or `null` if outside a route.
  static OmniRouteState? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OmniRouteStateScope>()
      ?.state;

  /// Returns a copy of this state with updated fields.
  OmniRouteState copyWith({
    Uri? uri,
    String? matchedLocation,
    String? path,
    String? name,
    Map<String, String>? pathParameters,
    Object? extra,
    Map<String, dynamic>? metadata,
    ValueKey<String>? pageKey,
    Object? error,
  }) => OmniRouteState(
    uri: uri ?? this.uri,
    matchedLocation: matchedLocation ?? this.matchedLocation,
    path: path ?? this.path,
    name: name ?? this.name,
    pathParameters: pathParameters ?? this.pathParameters,
    extra: extra ?? this.extra,
    metadata: metadata ?? this.metadata,
    pageKey: pageKey ?? this.pageKey,
    error: error ?? this.error,
  );

  @override
  bool operator ==(Object other) =>
      other is OmniRouteState &&
      other.uri == uri &&
      other.matchedLocation == matchedLocation &&
      other.path == path &&
      other.name == name &&
      mapEquals(other.pathParameters, pathParameters) &&
      other.extra == extra &&
      other.pageKey == pageKey &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(uri, matchedLocation, path, name, pageKey, extra, error);

  @override
  String toString() => 'OmniRouteState($location)';
}

/// Makes a route's [OmniRouteState] readable anywhere below the page.
class OmniRouteStateScope extends InheritedWidget {
  /// Exposes [state] to descendants.
  const OmniRouteStateScope({
    super.key,
    required this.state,
    required super.child,
  });

  /// The route state for the current page.
  final OmniRouteState state;

  @override
  bool updateShouldNotify(OmniRouteStateScope old) => state != old.state;
}
