import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import '../routing/omni_page.dart';

/// One page in the navigation stack, for debugging, analytics and tools.
@immutable
class OmniRouteEntry {
  /// Creates an entry.
  const OmniRouteEntry({
    required this.location,
    this.routePath,
    this.name,
    this.path,
    this.screen,
    this.metadata = const {},
  });

  /// Creates an entry for an [OmniPage] matched at [location].
  factory OmniRouteEntry.fromPage(
    OmniPage page,
    String location, {
    String? routePath,
  }) => OmniRouteEntry(
    location: location,
    routePath: routePath ?? (page.path.isNotEmpty ? page.path : null),
    name: page.name,
    path: page.path,
    screen: page.screenType,
    metadata: page.metadata ?? const {},
  );

  /// Where the page is, e.g. `/students/7` (no query).
  final String location;

  /// Full canonical route pattern recognizing this page, e.g. `/students/:id`.
  final String? routePath;

  /// The route's `name` alias, if it has one.
  final String? name;

  /// The route pattern segment as declared, e.g. `:id`.
  final String? path;

  /// The screen type shown by the route (`OmniPage<S>`).
  final Type? screen;

  /// The route's metadata (`OmniPage(metadata: ...)`).
  final Map<String, dynamic> metadata;

  @override
  bool operator ==(Object other) =>
      other is OmniRouteEntry &&
      other.location == location &&
      other.routePath == routePath &&
      other.name == name &&
      other.path == path &&
      other.screen == screen;

  @override
  int get hashCode => Object.hash(location, routePath, name, path, screen);

  @override
  String toString() =>
      '$location${screen == null ? '' : ' ($screen)'}${routePath == null ? '' : ' [$routePath]'}${name == null ? '' : ' #$name'}';
}

/// A completed navigation event passed to `OmniApp(onNavigate:)`.
@immutable
class OmniNavigation {
  /// Creates a navigation event.
  const OmniNavigation({
    required this.from,
    required this.to,
    required this.uri,
  });

  /// The top page before navigation, or `null` for the initial location.
  final OmniRouteEntry? from;

  /// The top page now.
  final OmniRouteEntry to;

  /// The full new location, including query and fragment.
  final Uri uri;

  @override
  String toString() => '${from ?? '(start)'} → $to';
}

/// Internal sentinel entry representing an unmatched or error route.
@internal
OmniRouteEntry errorEntryFor(Uri uri) =>
    OmniRouteEntry(location: uri.path.isEmpty ? '/' : uri.path);
