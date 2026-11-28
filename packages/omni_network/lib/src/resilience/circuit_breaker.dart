import '../core/omni_network_exception.dart';

/// State of one host's circuit.
enum CircuitState {
  /// Requests flow normally.
  closed,

  /// Requests fail fast with [CircuitOpenFailure].
  open,

  /// A limited number of trial requests may probe the host.
  halfOpen,
}

/// Stops calling a failing host for a while (per `host:port`).
///
/// Failures are 5xx responses, [TimeoutFailure] and [ConnectionFailure];
/// 4xx and cancellations do not count. After [failureThreshold]
/// consecutive failures the circuit opens for [openDuration]; then up to
/// [halfOpenTrials] concurrent requests probe it: a success closes it, a
/// failure opens it again.
final class CircuitBreaker {
  /// Creates a breaker. [now] is injectable for tests.
  CircuitBreaker({
    this.failureThreshold = 5,
    this.openDuration = const Duration(seconds: 30),
    this.halfOpenTrials = 1,
    DateTime Function()? now,
  }) : assert(failureThreshold >= 1 && halfOpenTrials >= 1),
       _now = now ?? DateTime.now;

  /// Consecutive failures that open the circuit.
  final int failureThreshold;

  /// How long the circuit stays open before probing.
  final Duration openDuration;

  /// Concurrent probes allowed while half-open.
  final int halfOpenTrials;

  final DateTime Function() _now;
  final Map<String, _Host> _hosts = {};

  /// Current state for [host] (`host:port`).
  CircuitState stateOf(String host) {
    final h = _hosts[host];
    if (h == null) return CircuitState.closed;
    _advance(h);
    return h.state;
  }

  /// Resets every circuit to closed.
  void reset() => _hosts.clear();

  void _advance(_Host h) {
    if (h.state == CircuitState.open &&
        _now().difference(h.openedAt!) >= openDuration) {
      h
        ..state = CircuitState.halfOpen
        ..trials = 0;
    }
  }

  /// Admits a request or throws [CircuitOpenFailure]. Internal.
  void acquire(String host, Uri uri) {
    final h = _hosts.putIfAbsent(host, _Host.new);
    _advance(h);
    switch (h.state) {
      case CircuitState.closed:
        return;
      case CircuitState.open:
        throw CircuitOpenFailure(host, uri: uri);
      case CircuitState.halfOpen:
        if (h.trials >= halfOpenTrials) {
          throw CircuitOpenFailure(host, uri: uri);
        }
        h.trials++;
    }
  }

  /// Records an outcome for an admitted request. Internal.
  void record(String host, {required bool success}) {
    final h = _hosts.putIfAbsent(host, _Host.new);
    if (success) {
      if (h.state == CircuitState.open) return;
      h
        ..state = CircuitState.closed
        ..failures = 0
        ..trials = 0;
      return;
    }
    if (h.state == CircuitState.open) return;
    if (h.state == CircuitState.halfOpen) {
      _open(h);
      return;
    }
    h.failures++;
    if (h.failures >= failureThreshold) _open(h);
  }

  /// Releases an admitted request whose outcome does not count. Internal.
  void release(String host) {
    final h = _hosts[host];
    if (h != null && h.state == CircuitState.halfOpen && h.trials > 0) {
      h.trials--;
    }
  }

  void _open(_Host h) {
    h
      ..state = CircuitState.open
      ..openedAt = _now()
      ..failures = 0
      ..trials = 0;
  }
}

final class _Host {
  CircuitState state = CircuitState.closed;
  int failures = 0;
  int trials = 0;
  DateTime? openedAt;
}
