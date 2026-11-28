import 'dart:async';

import 'package:meta/meta.dart';

import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import 'bearer_auth.dart';
import 'tokens.dart';

/// Signed in or not.
enum AuthState {
  /// No tokens.
  signedOut,

  /// Tokens present.
  signedIn,
}

/// Built-in token manager: stores tokens, adds them to requests, refreshes
/// them, and signs out when that fails.
///
/// ```dart
/// final api = OmniNetwork(
///   baseUrl: 'https://api.example.com',
///   auth: OmniAuth(
///     refresh: (tokens, api) async {
///       final r = await api.post<Map<String, dynamic>>('/auth/refresh',
///           body: {'refresh_token': tokens.refresh});
///       return Tokens(access: r['access_token'], refresh: r['refresh_token'],
///           expiresIn: Duration(seconds: r['expires_in']));
///     },
///     onLogout: () => router.go('/login'),
///   ),
/// );
///
/// await api.auth.login(Tokens(access: a, refresh: r));
/// await api.auth.logout();
/// ```
///
/// * Every request gets `Authorization: Bearer <access>` (use
///   `auth: false` on a call to skip it).
/// * [refresh] runs on a 401, or before a request when the token expires
///   within [refreshBefore]. Concurrent requests share one refresh. Calls
///   made inside [refresh] skip auth automatically.
/// * When [refresh] returns `null`, throws or times out, the tokens are
///   cleared, [onLogout] runs once and waiting requests fail with
///   `AuthFailure`. Without [refresh], a 401 is just an `HttpFailure`.
/// * [logout] clears the tokens and the client's cache, then runs
///   [onLogout].
/// * Tokens live in [storage] (memory by default) and are restored from it
///   on first use.
final class OmniAuth implements AuthProvider {
  /// Creates a token manager.
  OmniAuth({
    this.refresh,
    this.onLogout,
    TokenStorage? storage,
    this.refreshBefore = const Duration(seconds: 30),
    this.refreshTimeout = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : storage = storage ?? MemoryTokenStorage(),
       _now = now ?? DateTime.now;

  /// Gets new tokens for [current]; return `null` when that is not possible.
  final Future<Tokens?> Function(Tokens current, OmniNetwork api)? refresh;

  /// Runs once whenever the user becomes signed out (logout or failed
  /// refresh).
  final FutureOr<void> Function()? onLogout;

  /// Where tokens are kept.
  final TokenStorage storage;

  /// Refresh this long before `Tokens.expiresAt`.
  final Duration refreshBefore;

  /// Upper bound for one [refresh] call.
  final Duration refreshTimeout;

  final DateTime Function() _now;
  final _changes = StreamController<AuthState>.broadcast(sync: true);
  OmniNetwork? _client;
  BearerAuth? _bearer;
  Tokens? _tokens;
  Future<void>? _loading;
  Future<void> _writeChain = Future<void>.value();
  bool _loaded = false;
  bool _closed = false;
  int _epoch = 0;

  /// Current tokens (after they were loaded from [storage]).
  Tokens? get tokens => _tokens;

  /// Whether tokens are present.
  bool get isLoggedIn => _tokens != null;

  /// Current state.
  AuthState get state => isLoggedIn ? AuthState.signedIn : AuthState.signedOut;

  /// State changes (e.g. for a router's `refreshListenable`).
  Stream<AuthState> get changes => _changes.stream;

  /// Loads tokens from [storage] (done automatically before the first
  /// request). Returns whether the user is signed in.
  Future<bool> restore() async {
    await (_loading ??= _load());
    return isLoggedIn;
  }

  Future<void> _load() async {
    if (_loaded) return;
    final startEpoch = _epoch;
    final t = await storage.read();
    // A login() or logout() during the read wins.
    if (!_loaded && _epoch == startEpoch) {
      _tokens = t;
      _loaded = true;
      if (t != null) _emit();
    }
  }

  /// Saves [tokens] (e.g. from your login response) and signs in.
  Future<void> login(Tokens tokens) async {
    final epoch = ++_epoch;
    _bearer?.resetFailure();
    final was = isLoggedIn;
    await _save(tokens.fixedAt(_now()), epoch: epoch);
    if (!was) _emit();
  }

  /// Clears tokens and the client's cache, then runs [onLogout] (if the
  /// user was signed in).
  Future<void> logout() => _signOut();

  Future<void> _save(Tokens? t, {required int epoch}) {
    _tokens = t;
    _loaded = true;
    return _writeChain = _writeChain
        .catchError((Object _) {})
        .then((_) async {
          if (epoch != _epoch) return;
          await storage.write(t);
        });
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(state);
  }

  Future<void> _signOut() async {
    final epoch = ++_epoch;
    final was = isLoggedIn;
    await _save(null, epoch: epoch);
    await _client?.cache?.clear();
    if (!was) return;
    _emit();
    try {
      await onLogout?.call();
    } catch (_) {
      // The app's callback must not break the request that triggered it.
    }
  }

  bool _expiring() {
    final at = _tokens?.expiresAt;
    return at != null && !_now().add(refreshBefore).isBefore(at);
  }

  @override
  BearerAuth bearerFor(OmniNetwork client) {
    final prev = _client;
    if (prev != null && !identical(prev, client)) {
      if (!prev.isClosed) {
        throw StateError('An OmniAuth can serve only one OmniNetwork client');
      }
      _bearer = null;
      _closed = false;
    }
    _client = client;
    final r = refresh;
    return _bearer ??= BearerAuth(
      token: () async {
        await restore();
        return _tokens?.access;
      },
      refresh: r == null
          ? null
          : () async {
              if (_closed || client.isClosed) throw const ClosedFailure();
              final startEpoch = _epoch;
              final current = _tokens;
              if (current == null) return null;
              final next = await r(current, client);
              if (_closed || client.isClosed) throw const ClosedFailure();
              // Keep newer login/logout state if auth changed mid-refresh.
              if (startEpoch != _epoch) {
                return _tokens?.access;
              }
              if (next == null) return null;
              // Keep the refresh token when the server does not rotate it.
              final saved = Tokens(
                access: next.access,
                refresh: next.refresh ?? current.refresh,
                expiresAt: next.expiresAt,
                expiresIn: next.expiresIn,
              ).fixedAt(_now());
              await _save(saved, epoch: startEpoch);
              return saved.access;
            },
      onRefreshFailed: _signOut,
      refreshTimeout: refreshTimeout,
      isExpiring: _expiring,
    );
  }

  /// Marks [client] detached without closing [changes] (e.g. `ApiHub`
  /// environment switches). Internal.
  @internal
  void detachClient(OmniNetwork client) {
    if (identical(_client, client)) {
      _bearer?.close();
    }
  }

  /// Closes [changes]. Called by `OmniNetwork.close`.
  Future<void> close() async {
    _closed = true;
    _bearer?.close();
    await _writeChain.catchError((Object _) {});
    if (!_changes.isClosed) await _changes.close();
  }
}
