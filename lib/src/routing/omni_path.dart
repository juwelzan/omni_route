import 'package:meta/meta.dart';

import '../errors/omni_route_exception.dart';

final RegExp _param = RegExp(r'^:[a-zA-Z_]\w*$');
final RegExp _static = RegExp(r'^[a-z0-9._~-]+$');

/// Validates a route path before it reaches go_router.
///
/// Top-level paths start with `/`; child paths must not. Static segments are
/// lowercase URL-safe; parameters are `:name`. No `#`, `?`, empty segments,
/// trailing slash, or repeated parameter names.
@internal
void validateRoutePath(String path, {required bool topLevel}) {
  Never fail(String why, [String? hint]) => throw OmniRouteException(
    OmniErrorCode.invalidRoutePath,
    'Invalid route path "$path": $why.',
    hint: hint,
  );

  if (path.trim().isEmpty) {
    throw const OmniRouteException(
      OmniErrorCode.emptyRoutePath,
      'Route path is empty.',
    );
  }
  if (path.contains('#')) {
    fail('"#" is not allowed', 'OmniRoute uses path URLs.');
  }
  if (path.contains('?')) {
    fail('query strings belong in navigation calls, not route paths');
  }
  if (topLevel && !path.startsWith('/')) {
    fail('top-level paths must start with "/"');
  }
  if (!topLevel && path.startsWith('/')) {
    fail('child paths must be relative', 'Use "${path.substring(1)}".');
  }
  if (path == '/') return;
  if (path.endsWith('/')) fail('trailing "/" is not allowed');

  final segments = (topLevel ? path.substring(1) : path).split('/');
  final params = <String>{};
  for (final s in segments) {
    if (s.isEmpty) fail('empty segment ("//")');
    if (s.startsWith(':')) {
      if (!_param.hasMatch(s)) fail('bad parameter "$s"', 'Use ":name".');
      if (!params.add(s)) fail('parameter "$s" is repeated');
    } else if (!_static.hasMatch(s)) {
      fail(
        'segment "$s" must be lowercase and URL-safe',
        'Use "${s.toLowerCase()}".',
      );
    }
  }
}

/// Validates a screen's declared `routePath`.
///
/// Accepts either top-level/full paths (`/students`, `/students/:id`, `/`) or
/// relative child paths (`:id`, `edit`). Rejects empty paths, uppercase
/// segments, spaces, trailing slashes, `?`, `#`, empty segments, or duplicate
/// parameter names.
@internal
void validateScreenRoutePath(String path) {
  if (path.trim().isEmpty) {
    throw const OmniRouteException(
      OmniErrorCode.emptyRoutePath,
      'Screen routePath is empty.',
      hint: "Override `String get routePath => '/my-screen';`.",
    );
  }
  validateRoutePath(path, topLevel: path.startsWith('/'));
}

/// Derives a readable default window/app-bar title from [routePath].
///
/// Examples: `'/'` -> `'Home'`, `'/students'` -> `'Students'`,
/// `'/confirm-logout'` -> `'Confirm Logout'`, `'/students/:id'` -> `'Students'`.
@internal
String defaultTitleFromRoutePath(String routePath) {
  final trimmed = routePath.trim();
  if (trimmed.isEmpty || trimmed == '/') return 'Home';
  final rawSegments = (trimmed.startsWith('/') ? trimmed.substring(1) : trimmed)
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  String? chosen;
  for (var i = rawSegments.length - 1; i >= 0; i--) {
    final seg = rawSegments[i];
    if (!seg.startsWith(':') && !seg.startsWith('*')) {
      chosen = seg;
      break;
    }
  }
  chosen ??= rawSegments.isNotEmpty ? rawSegments.last : 'Home';
  if (chosen.startsWith(':') || chosen.startsWith('*')) {
    chosen = chosen.substring(1);
  }
  final words = chosen
      .split(RegExp(r'[-_.]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}');
  final result = words.join(' ');
  return result.isEmpty ? 'Home' : result;
}

/// Throws on the first full path that appears twice in [fullPaths].
@internal
void checkDuplicatePaths(Iterable<String> fullPaths) {
  final seen = <String>{};
  for (final p in fullPaths) {
    // `/a/:id` and `/a/:slug` match the same URLs.
    final shape = p.replaceAll(RegExp(r':\w+'), ':');
    if (!seen.add(shape)) {
      throw OmniRouteException(
        OmniErrorCode.duplicateRoute,
        'Route "$p" is registered more than once.',
      );
    }
  }
}
