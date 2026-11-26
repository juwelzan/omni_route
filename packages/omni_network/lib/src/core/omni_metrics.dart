import 'package:meta/meta.dart';

/// Immutable snapshot of runtime telemetry collected by an `OmniNetwork` client.
@immutable
final class OmniNetworkMetrics {
  /// Creates a metrics snapshot.
  const OmniNetworkMetrics({
    required this.totalRequests,
    required this.successCount,
    required this.failureCount,
    required this.cacheHits,
    required this.revalidatedCount,
    required this.activeRequests,
    required this.averageLatency,
    this.lastLatency,
  });

  /// Total completed HTTP/transport calls (network + cache + failures).
  final int totalRequests;

  /// Requests that completed with a 2xx response.
  final int successCount;

  /// Requests that failed with an exception or non-2xx HTTP status.
  final int failureCount;

  /// Requests served directly from `OmniCache`.
  final int cacheHits;

  /// Requests served via conditional `304 Not Modified` revalidation.
  final int revalidatedCount;

  /// Requests currently executing.
  final int activeRequests;

  /// Average wall-clock latency across completed requests.
  final Duration averageLatency;

  /// Latency of the most recent completed request, if any.
  final Duration? lastLatency;

  /// Ratio of cache hits + revalidations to [totalRequests] (`0.0`..`1.0`).
  double get cacheHitRate => totalRequests == 0
      ? 0.0
      : (cacheHits + revalidatedCount) / totalRequests;

  @override
  String toString() =>
      'OmniNetworkMetrics(total: $totalRequests, ok: $successCount, '
      'fail: $failureCount, cacheHits: $cacheHits, avg: ${averageLatency.inMilliseconds}ms)';
}
