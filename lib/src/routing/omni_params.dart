import 'package:flutter/widgets.dart';

import '../errors/omni_route_exception.dart';
import 'omni_route_state.dart';

/// Typed access to the current route's path parameters, query parameters
/// and `extra`. Wraps [OmniRouteState]; values are already URL-decoded.
@immutable
class OmniParams {
  /// Wraps [state].
  const OmniParams(this.state);

  /// Parameters of the route [context] is in. Useful in Bloc factories:
  /// `Provide<X>.create((c) => X(OmniParams.of(c).pathInt('id')))`.
  ///
  /// Reads without subscribing, so it is safe in Bloc `create` callbacks
  /// and `initState`.
  factory OmniParams.of(BuildContext context) =>
      maybeOf(context) ??
      (throw FlutterError(
        'OmniParams.of(context) called outside an OmniPage route.',
      ));

  /// Parameters of the route [context] is in, or `null` outside an [OmniPage].
  ///
  /// Safe in `initState` and Bloc factories.
  static OmniParams? maybeOf(BuildContext context) {
    final s = OmniRouteState.readMaybeOf(context);
    return s == null ? null : OmniParams(s);
  }

  /// The underlying route state.
  final OmniRouteState state;

  /// The full location, including query.
  Uri get uri => state.uri;

  /// Required path parameter, e.g. `id` in `/students/:id`.
  String path(String name) {
    final v = state.pathParameters[name];
    if (v == null) _fail(name, 'missing path parameter');
    return v;
  }

  /// Path parameter parsed as int; an invalid value shows the not-found page.
  int pathInt(String name) => _int(name, path(name));

  /// Path parameter parsed as a strictly positive integer (`>= 1`). Zero,
  /// negative, or non-integer values trigger the route error/not-found page.
  int pathPositiveInt(String name) {
    final n = pathInt(name);
    if (n <= 0) _fail(name, 'expected positive integer, got $n');
    return n;
  }

  /// Required path parameter matched against enum [values].
  T pathEnum<T extends Enum>(String name, List<T> values) {
    final v = path(name);
    for (final e in values) {
      if (e.name == v) return e;
    }
    _fail(name, '"$v" is not one of ${values.map((e) => e.name).join(', ')}');
  }

  /// Optional query parameter (`?class=10`).
  String? query(String name) => state.uri.queryParameters[name];

  /// Required non-empty query parameter; missing or empty → error page.
  String queryRequired(String name) {
    final v = query(name);
    if (v == null || v.isEmpty) _fail(name, 'missing required query parameter');
    return v;
  }

  /// Optional query parameter parsed as int. Present but not an int → error.
  int? queryInt(String name) {
    final v = query(name);
    return v == null ? null : _int(name, v);
  }

  /// Optional query parameter parsed as ISO-8601 [DateTime].
  DateTime? queryDateTime(String name) {
    final v = query(name);
    if (v == null) return null;
    return DateTime.tryParse(v) ?? _fail(name, '"$v" is not an ISO-8601 date');
  }

  /// Query parameter validated against [allowed] set (or returns
  /// [defaultValue] when absent).
  String? queryOneOf(
    String name,
    Iterable<String> allowed, {
    String? defaultValue,
  }) {
    final v = query(name);
    if (v == null) return defaultValue;
    for (final candidate in allowed) {
      if (candidate == v) return v;
    }
    _fail(name, '"$v" is not one of ${allowed.join(', ')}');
  }

  /// Optional query parameter parsed as double (`?lat=23.8`). Present but
  /// not a number → error page.
  double? queryDouble(String name) {
    final v = query(name);
    if (v == null) return null;
    return double.tryParse(v) ?? _fail(name, '"$v" is not a number');
  }

  /// Optional query parameter parsed as bool: `true`/`false`/`1`/`0`
  /// (case-insensitive). Anything else → error page.
  bool? queryBool(String name) {
    final v = query(name)?.toLowerCase();
    return switch (v) {
      null => null,
      'true' || '1' => true,
      'false' || '0' => false,
      _ => _fail(name, '"$v" is not true/false'),
    };
  }

  /// Optional query parameter matched by name against [values]
  /// (`?sort=newest` with `Sort.values`). Unknown name → error page.
  T? queryEnum<T extends Enum>(String name, List<T> values) {
    final v = query(name);
    if (v == null) return null;
    for (final e in values) {
      if (e.name == v) return e;
    }
    _fail(name, '"$v" is not one of ${values.map((e) => e.name).join(', ')}');
  }

  /// All values of a repeated query parameter (`?tag=a&tag=b`).
  List<String> queryAll(String name) =>
      state.uri.queryParametersAll[name] ?? const [];

  /// `extra` passed with `push`/`go`. Lost on web refresh — never rely on it
  /// for data the page needs after reload.
  T? extra<T>() {
    final e = state.extra;
    if (e == null) return null;
    if (e is T) return e as T;
    _fail('extra', 'expected $T, got ${e.runtimeType}');
  }

  int _int(String name, String v) =>
      int.tryParse(v) ?? _fail(name, '"$v" is not an integer');

  Never _fail(String name, String why) => throw OmniRouteException(
    OmniErrorCode.invalidParameter,
    'Route ${state.uri}: parameter "$name": $why.',
  );
}
