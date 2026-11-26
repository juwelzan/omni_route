import 'package:meta/meta.dart';

import '../errors/omni_route_exception.dart';

/// Result of matching a path against [OmniRouteTrie].
@internal
class OmniTrieMatch<T> {
  const OmniTrieMatch(this.value, this.pathParameters);

  /// The matched route value.
  final T value;

  /// Decoded dynamic path parameters captured during traversal.
  final Map<String, String> pathParameters;
}

class _TrieNode<T> {
  final Map<String, _TrieNode<T>> staticChildren = {};
  _TrieNode<T>? paramChild;
  String? paramName;
  _TrieNode<T>? wildcardChild;
  String? wildcardName;
  T? value;
}

/// Segment-based Trie for fast O(segments) route matching without `RegExp`.
///
/// Precedence at every segment depth:
/// 1. Exact static segment match
/// 2. Dynamic `:param` segment
/// 3. Wildcard `*` / `*name` rest-of-path segment
@internal
class OmniRouteTrie<T> {
  final _TrieNode<T> _root = _TrieNode<T>();

  /// Inserts [fullPath] mapped to [value].
  void insert(String fullPath, T value) {
    final segments = _splitPattern(fullPath);
    var node = _root;
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.startsWith('*')) {
        final name = seg.length > 1 ? seg.substring(1) : 'rest';
        node.wildcardName ??= name;
        node = node.wildcardChild ??= _TrieNode<T>();
        break;
      } else if (seg.startsWith(':')) {
        final name = seg.substring(1);
        final child = node.paramChild;
        if (child != null && node.paramName != name) {
          throw OmniRouteException(
            OmniErrorCode.duplicateRoute,
            'Conflicting parameter names ":${node.paramName}" and ":$name" '
            'at "$fullPath".',
            hint: 'Use the same parameter name for routes sharing a prefix.',
          );
        }
        node.paramName = name;
        node = node.paramChild ??= _TrieNode<T>();
      } else {
        node = node.staticChildren.putIfAbsent(seg, _TrieNode<T>.new);
      }
    }
    node.value = value;
  }

  /// Matches [uri] against compiled routes, returning `null` if none match.
  OmniTrieMatch<T>? matchUri(Uri uri) {
    final segments = _decodedSegments(uri);
    final params = <String, String>{};
    final matched = _search(_root, segments, 0, params);
    if (matched == null) return null;
    return OmniTrieMatch<T>(
      matched,
      params.isEmpty ? const {} : Map.unmodifiable(params),
    );
  }

  T? _search(
    _TrieNode<T> node,
    List<String> segments,
    int index,
    Map<String, String> params,
  ) {
    if (index == segments.length) {
      if (node.value != null) return node.value;
      final wild = node.wildcardChild;
      if (wild?.value != null) {
        params[node.wildcardName!] = '';
        return wild!.value;
      }
      return null;
    }

    final seg = segments[index];

    // 1. Exact static segment (O(1) map lookup).
    final staticChild = node.staticChildren[seg];
    if (staticChild != null) {
      final hit = _search(staticChild, segments, index + 1, params);
      if (hit != null) return hit;
    }

    // 2. Dynamic `:param` segment.
    final paramChild = node.paramChild;
    if (paramChild != null) {
      final paramName = node.paramName!;
      final prev = params[paramName];
      params[paramName] = seg;
      final hit = _search(paramChild, segments, index + 1, params);
      if (hit != null) return hit;
      if (prev == null) {
        params.remove(paramName);
      } else {
        params[paramName] = prev;
      }
    }

    // 3. Catch-all `*` segment.
    final wildChild = node.wildcardChild;
    if (wildChild?.value != null) {
      params[node.wildcardName!] = segments.sublist(index).join('/');
      return wildChild!.value;
    }

    return null;
  }

  /// Builds a normalized location URI string from a route [pattern],
  /// substituting `:param` placeholders from [params] and attaching
  /// non-null entries from [query].
  static String formatLocation(
    String pattern, {
    Map<String, Object?> params = const {},
    Map<String, Object?> query = const {},
  }) {
    final segments = _splitPattern(pattern);
    final used = <String>{};
    final buffer = StringBuffer();

    if (segments.isEmpty) {
      buffer.write('/');
    } else {
      for (final seg in segments) {
        buffer.write('/');
        if (seg.startsWith(':')) {
          final key = seg.substring(1);
          final raw = params[key];
          final value = raw?.toString();
          if (value == null || value.isEmpty) {
            throw OmniRouteException(
              OmniErrorCode.invalidParameter,
              'Missing path parameter "$key" for $pattern.',
            );
          }
          used.add(key);
          buffer.write(Uri.encodeComponent(value));
        } else if (seg.startsWith('*')) {
          final key = seg.length > 1 ? seg.substring(1) : 'rest';
          final raw = params[key];
          if (raw != null) {
            used.add(key);
            final parts = raw
                .toString()
                .split('/')
                .where((s) => s.isNotEmpty)
                .map(Uri.encodeComponent);
            buffer.write(parts.join('/'));
          }
        } else {
          buffer.write(seg);
        }
      }
    }

    for (final k in params.keys) {
      if (!used.contains(k)) {
        throw OmniRouteException(
          OmniErrorCode.invalidParameter,
          'Unknown path parameter(s) {$k} for $pattern.',
        );
      }
    }

    final cleanPath = buffer.toString();
    if (query.isEmpty) return cleanPath;

    final queryMap = <String, dynamic>{};
    query.forEach((key, val) {
      if (val == null) return;
      if (val is Iterable) {
        queryMap[key] = [for (final item in val) item.toString()];
      } else {
        queryMap[key] = val.toString();
      }
    });
    if (queryMap.isEmpty) return cleanPath;
    return Uri(path: cleanPath, queryParameters: queryMap).toString();
  }

  static List<String> _splitPattern(String pattern) {
    if (pattern == '/' || pattern.isEmpty) return const [];
    final trimmed = pattern.endsWith('/') && pattern.length > 1
        ? pattern.substring(0, pattern.length - 1)
        : pattern;
    return [
      for (final s in trimmed.split('/'))
        if (s.isNotEmpty) s,
    ];
  }

  static List<String> _decodedSegments(Uri uri) {
    final segs = uri.pathSegments;
    if (segs.isEmpty) return const [];
    // Drop trailing empty segment produced when path ends with '/'.
    if (segs.last.isEmpty) {
      return [
        for (var i = 0; i < segs.length; i++)
          if (segs[i].isNotEmpty) segs[i],
      ];
    }
    return segs;
  }
}
