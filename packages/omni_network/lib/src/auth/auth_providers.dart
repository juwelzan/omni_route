import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/omni_network.dart';
import 'bearer_auth.dart';

/// Attaches a static or dynamic API key via a request header or query parameter.
final class ApiKeyAuth implements AuthProvider {
  /// Creates an API-key auth provider from a fixed [key].
  ApiKeyAuth(
    String key, {
    String headerName = 'X-API-Key',
    bool inQuery = false,
    String queryParam = 'api_key',
  }) : this.provider(
         () => key,
         headerName: headerName,
         inQuery: inQuery,
         queryParam: queryParam,
       );

  /// Creates an API-key auth provider resolved dynamically per request.
  const ApiKeyAuth.provider(
    this.apiKey, {
    this.headerName = 'X-API-Key',
    this.inQuery = false,
    this.queryParam = 'api_key',
  });

  /// Supplies the API key (or `null` when absent).
  final FutureOr<String?> Function() apiKey;

  /// Header name used when [inQuery] is `false`.
  final String headerName;

  /// When `true`, sends the key as query parameter [queryParam] instead of a
  /// request header.
  final bool inQuery;

  /// Query parameter name used when [inQuery] is `true`.
  final String queryParam;

  @override
  BearerAuth bearerFor(OmniNetwork client) {
    if (!inQuery) {
      return BearerAuth(token: apiKey, scheme: '', headerName: headerName);
    }
    return BearerAuth.custom(
      token: apiKey,
      headerName: headerName,
      hasCredential: (request) => request.query.containsKey(queryParam),
      attach: (request, token) => token == null || token.isEmpty
          ? request
          : request.copyWith(query: {...request.query, queryParam: token}),
    );
  }
}

/// Attaches HTTP Basic authentication (`Authorization: Basic <base64>`).
final class BasicAuth implements AuthProvider {
  /// Creates Basic auth from [username] and [password].
  BasicAuth({
    required this.username,
    required this.password,
    this.headerName = 'Authorization',
  }) : _encoded = base64Encode(utf8.encode('$username:$password'));

  /// Username.
  final String username;

  /// Password.
  final String password;

  /// Header name (defaults to `Authorization`).
  final String headerName;

  final String _encoded;

  @override
  BearerAuth bearerFor(OmniNetwork client) =>
      BearerAuth(token: () => _encoded, scheme: 'Basic', headerName: headerName);
}

/// Signs every outgoing request using HMAC-SHA256 (`timestamp\nMETHOD\npath\nbody`).
final class HmacSignerAuth implements AuthProvider {
  /// Creates an HMAC-SHA256 request signer.
  HmacSignerAuth({
    required this.secret,
    this.headerName = 'X-Signature',
    this.timestampHeader = 'X-Timestamp',
    this.prefix = '',
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Shared signing secret.
  final String secret;

  /// Header carrying the hex HMAC-SHA256 signature.
  final String headerName;

  /// Header carrying the Unix epoch timestamp in seconds.
  final String timestampHeader;

  /// Optional signature prefix (e.g. `'sha256='`).
  final String prefix;

  final DateTime Function() _now;

  @override
  BearerAuth bearerFor(OmniNetwork client) => BearerAuth.custom(
    headerName: headerName,
    attach: (request, _) {
      final ts = (_now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
      final bodyStr = switch (request.body) {
        null => '',
        String s => s,
        List<int> bytes => base64Encode(bytes),
        Map() || List() || num() || bool() => jsonEncode(request.body),
        _ => '${request.body}',
      };
      final canonical = '$ts\n${request.method.verb}\n${request.path}\n$bodyStr';
      final mac = Hmac(sha256, utf8.encode(secret));
      final digest = mac.convert(utf8.encode(canonical)).toString();
      return request.copyWith(
        headers: {
          ...request.headers,
          timestampHeader: ts,
          headerName: '$prefix$digest',
        },
      );
    },
  );
}
