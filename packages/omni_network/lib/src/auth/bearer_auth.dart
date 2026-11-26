import 'dart:async';

import 'package:meta/meta.dart';

import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_request.dart';
import '../core/omni_response.dart';

/// Zone key marking code that runs inside a refresh callback. Internal.
final Object authSkipZoneKey = Object();

/// Whether the current zone is inside a refresh callback. Internal.
bool get insideRefresh => Zone.current[authSkipZoneKey] == true;

/// Something that can authenticate an `OmniNetwork` client: `OmniAuth`
/// (recommended) or [BearerAuth] (advanced).
abstract interface class AuthProvider {
  /// The token/refresh machinery used by [client]. Internal.
  BearerAuth bearerFor(OmniNetwork client);
}

/// Adds a token to requests and refreshes it once when it expires.
///
/// ```dart
/// final api = OmniNetwork(
///   baseUrl: 'https://api.example.com',
///   auth: BearerAuth(
///     token: () => store.accessToken,
///     refresh: () async {
///       final r = await api.post<Map<String, dynamic>>('/auth/refresh',
///           body: {'refresh_token': store.refreshToken});
///       await store.save(r);
///       return r['access_token'] as String;
///     },
///     onRefreshFailed: session.logout,
///   ),
/// );
/// ```
///
/// Guarantees:
/// * **single flight**: however many requests get a 401 at once, [refresh]
///   runs once; all of them wait for it and are replayed once with the new
///   token. A request already replayed is never refreshed again (no loops).
/// * requests started while a refresh runs wait for it instead of sending a
///   stale token;
/// * requests made inside [refresh] skip auth automatically (no deadlock);
/// * when [refresh] returns `null`/empty, throws or exceeds
///   [refreshTimeout], [onRefreshFailed] runs **once** and every waiting
///   request fails with [AuthFailure]. Later 401s for the same stale token
///   fail immediately without another refresh.
///
/// A request that already carries the auth header, or uses
/// `OmniRequest(skipAuth: true)`, is sent untouched.
final class BearerAuth implements AuthProvider {
  /// Creates bearer-token auth.
  BearerAuth({
    required this.token,
    this.refresh,
    this.onRefreshFailed,
    bool Function(OmniRawResponse response)? isExpired,
    this.scheme = 'Bearer',
    this.headerName = 'Authorization',
    this.refreshTimeout = const Duration(seconds: 30),
    this.isExpiring,
  }) : isExpired = isExpired ?? _is401,
       _customAttach = null,
       _customHasCredential = null;

  /// Internal custom signer constructor used by `ApiKeyAuth` and
  /// `HmacSignerAuth`.
  @internal
  BearerAuth.custom({
    FutureOr<String?> Function()? token,
    required OmniRequest Function(OmniRequest request, String? token) attach,
    bool Function(OmniRequest request)? hasCredential,
    this.headerName = 'Authorization',
  }) : token = token ?? _emptyToken,
       refresh = null,
       onRefreshFailed = null,
       isExpired = _is401,
       scheme = '',
       refreshTimeout = const Duration(seconds: 30),
       isExpiring = null,
       _customAttach = attach,
       _customHasCredential = hasCredential;

  static String? _emptyToken() => null;

  final OmniRequest Function(OmniRequest request, String? token)? _customAttach;
  final bool Function(OmniRequest request)? _customHasCredential;

  /// When it returns `true` before a request, the token is refreshed first
  /// (single flight), e.g. because it expires within seconds.
  final bool Function()? isExpiring;

  /// Reads the current access token (`null` = not signed in).
  final FutureOr<String?> Function() token;

  /// Obtains and stores a new access token; returns it, or `null` on failure.
  ///
  /// When `null`, the token is only attached: a 401 is returned as is
  /// (as `HttpFailure` from typed calls) and nothing is refreshed.
  final FutureOr<String?> Function()? refresh;

  /// Called once per failed refresh, e.g. to log out.
  final FutureOr<void> Function()? onRefreshFailed;

  /// Whether a response means "token expired"; default: status 401.
  final bool Function(OmniRawResponse response) isExpired;

  /// Header value prefix; empty sends the bare token.
  final String scheme;

  /// Header carrying the token.
  final String headerName;

  /// Upper bound for one [refresh] call.
  final Duration refreshTimeout;

  Future<(String?, Object?)>? _inFlight;
  String? _failedFor;
  bool _failedForSet = false;
  int _refreshCount = 0;

  /// How many times [refresh] has been called (diagnostics/tests).
  int get refreshCount => _refreshCount;

  /// Whether a refresh is currently running.
  bool get isRefreshing => _inFlight != null;

  static bool _is401(OmniRawResponse r) => r.statusCode == 401;

  @override
  BearerAuth bearerFor(OmniNetwork client) => this;

  /// Whether [request] already carries an explicit credential. Internal.
  bool hasCredential(OmniRequest request) =>
      _customHasCredential?.call(request) ?? request.header(headerName) != null;

  /// [request] with the token header added. Internal.
  OmniRequest attach(OmniRequest request, String? token) {
    final custom = _customAttach;
    if (custom != null) return custom(request, token);
    return token == null || token.isEmpty
        ? request
        : request.withHeader(
            headerName,
            scheme.isEmpty ? token : '$scheme $token',
          );
  }

  /// The token to use now, waiting for a running refresh first. Internal.
  Future<String?> current() async {
    final running = _inFlight;
    final checkExpiring = isExpiring;
    if (running != null) {
      await running;
    } else if (refresh != null && checkExpiring != null) {
      final used = await token();
      if (checkExpiring()) {
        await (_inFlight ??= _run(used));
      } else {
        return used;
      }
    }
    return token();
  }

  /// Recovers from an expired-token [response] to a request sent with
  /// [used]. Returns the token to replay with or throws [AuthFailure].
  /// Internal.
  Future<String> recover(String? used, OmniRawResponse response) async {
    if (_inFlight == null) {
      if (_failedForSet && _failedFor == used) {
        throw AuthFailure(
          'Token refresh already failed for this session',
          uri: response.requestUri,
          response: response,
        );
      }
      // A refresh may have completed while this request was on the wire.
      final now = await token();
      if (now != null && now.isNotEmpty && now != used) return now;
    }
    final (fresh, error) = await (_inFlight ??= _run(used));
    if (fresh == null) {
      throw AuthFailure(
        'Token refresh failed',
        uri: response.requestUri,
        response: response,
        cause: error,
      );
    }
    return fresh;
  }

  Future<(String?, Object?)> _run(String? used) async {
    _refreshCount++;
    try {
      final fresh = await runZoned(
        () => Future.sync(refresh!),
        zoneValues: {authSkipZoneKey: true},
      ).timeout(refreshTimeout);
      if (fresh != null && fresh.isNotEmpty) {
        _failedForSet = false;
        return (fresh, null);
      }
      await _fail(used);
      return (null, null);
    } catch (e) {
      await _fail(used);
      return (null, e is TimeoutException ? 'refresh timed out' : e);
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _fail(String? used) async {
    _failedFor = used;
    _failedForSet = true;
    try {
      await onRefreshFailed?.call();
    } catch (_) {
      // The callback's own failure must not mask the auth failure.
    }
  }
}
