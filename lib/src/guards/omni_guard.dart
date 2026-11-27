import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/omni_route.dart';
import '../routing/omni_route_state.dart';

/// Redirect callback executed before navigating to a matched route.
///
/// Return a destination location (e.g. `'/login'`) to redirect, or `null`
/// to allow the navigation.
typedef OmniGuardRedirect =
    FutureOr<String?> Function(BuildContext context, OmniRouteState state);

/// Redirect guard evaluated by the OmniRoute engine before opening a page.
///
/// Return a location to redirect, or `null` to allow. Keep guards fast: read
/// Bloc state (e.g. `context.read<AuthBloc>().state`) instead of performing
/// network requests.
///
/// ```dart
/// class AuthGuard extends OmniGuard {
///   @override
///   Stream<Object?> refresh(BuildContext c) => c.read<AuthBloc>().stream;
///
///   @override
///   String? redirect(BuildContext c, OmniRouteState s) {
///     final ok = c.read<AuthBloc>().state is Authenticated;
///     if (!ok && s.matchedLocation != '/login') return '/login';
///     if (ok && s.matchedLocation == '/login') return '/';
///     return null;
///   }
/// }
/// ```
abstract class OmniGuard {
  /// Constant constructor for subclasses.
  const OmniGuard();

  /// Creates an inline guard from [redirect] and an optional [refresh] stream.
  const factory OmniGuard.fn(
    OmniGuardRedirect redirect, {
    Stream<Object?>? Function(BuildContext)? refresh,
  }) = _FnGuard;

  /// Returns a destination location to redirect to, or `null` to allow.
  FutureOr<String?> redirect(BuildContext context, OmniRouteState state);

  /// Stream whose emissions re-evaluate redirects (e.g. an auth Bloc stream).
  /// Subscribed once below global Blocs and cancelled cleanly when disposed.
  Stream<Object?>? refresh(BuildContext context) => null;
}

class _FnGuard extends OmniGuard {
  const _FnGuard(this._redirect, {this._refresh});

  final OmniGuardRedirect _redirect;
  final Stream<Object?>? Function(BuildContext)? _refresh;

  @override
  FutureOr<String?> redirect(BuildContext context, OmniRouteState state) =>
      _redirect(context, state);

  @override
  Stream<Object?>? refresh(BuildContext context) => _refresh?.call(context);
}

/// Evaluates [guards] in order; the first non-null redirect wins.
///
/// Stays completely synchronous whenever every guard returns synchronously,
/// avoiding extra frame delays. Redirects back to the current location are
/// ignored.
@internal
FutureOr<String?> evaluateGuards(
  BuildContext context,
  OmniRouteState state,
  List<OmniGuard> guards,
) {
  if (guards.isEmpty) return null;
  return _runGuards(context, state, guards, 0);
}

FutureOr<String?> _runGuards(
  BuildContext context,
  OmniRouteState state,
  List<OmniGuard> guards,
  int index,
) {
  for (; index < guards.length; index++) {
    final result = guards[index].redirect(context, state);
    if (result is Future<String?>) {
      final next = index + 1;
      return result.then((to) {
        if (!context.mounted) return null;
        return _acceptRedirect(to, state) ??
            _runGuards(context, state, guards, next);
      });
    }
    final accepted = _acceptRedirect(result, state);
    if (accepted != null) return accepted;
  }
  return null;
}

String? _acceptRedirect(String? to, OmniRouteState state) {
  if (to == null) return null;
  if (_sameLocation(to, state.uri)) {
    assert(() {
      OmniRoute.logger.w(
        'OmniRoute · guard\n'
        'redirected to "$to", the page being opened; ignored.',
      );
      return true;
    }());
    return null;
  }
  return to;
}

bool _sameLocation(String to, Uri current) {
  final target = Uri.parse(to);
  return target.path == current.path &&
      (target.query.isEmpty || target.query == current.query);
}

/// Listens to guard refresh streams and triggers router re-evaluation.
@internal
class GuardRefresh extends StatefulWidget {
  const GuardRefresh({
    super.key,
    required this.guards,
    required this.notifier,
    required this.child,
  });

  final List<OmniGuard> guards;
  final GuardNotifier notifier;
  final Widget child;

  @override
  State<GuardRefresh> createState() => _GuardRefreshState();
}

class _GuardRefreshState extends State<GuardRefresh> {
  List<StreamSubscription<Object?>>? _subs;

  void _subscribe() {
    _cancel();
    _subs = [
      for (final g in widget.guards)
        if (g.refresh(context) case final s?)
          s.listen((_) => widget.notifier.ping()),
    ];
  }

  void _cancel() {
    for (final s in _subs ?? const <StreamSubscription<Object?>>[]) {
      s.cancel();
    }
    _subs = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subs == null) _subscribe();
  }

  @override
  void didUpdateWidget(GuardRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.guards, oldWidget.guards)) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Simple [ChangeNotifier] poked when any guard refresh stream emits.
@internal
class GuardNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Strips trailing slashes (`/students/` → `/students`), keeping queries intact.
@internal
class NormalizeUrlGuard extends OmniGuard {
  const NormalizeUrlGuard();

  @override
  String? redirect(BuildContext context, OmniRouteState state) {
    final uri = state.uri;
    if (uri.path.length <= 1 || !uri.path.endsWith('/')) return null;
    var path = uri.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: path).toString();
  }
}
