import 'package:meta/meta.dart';

/// Per-endpoint telemetry breakdown (`METHOD /path`).
@immutable
final class EndpointMetrics {
  /// Creates endpoint metrics.
  const EndpointMetrics({
    required this.count,
    required this.failures,
    required this.averageLatency,
  });

  /// Total completed calls for this endpoint key.
  final int count;

  /// Calls that failed with a non-2xx HTTP status or exception.
  final int failures;

  /// Mean wall-clock latency for this endpoint.
  final Duration averageLatency;

  /// Failure ratio (`0.0`..`1.0`).
  double get errorRate => count == 0 ? 0.0 : failures / count;
}

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
    this.p50Latency = Duration.zero,
    this.p95Latency = Duration.zero,
    this.p99Latency = Duration.zero,
    this.wsReconnectCount = 0,
    this.byEndpoint = const {},
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

  /// 50th percentile (median) latency over the recent rolling window.
  final Duration p50Latency;

  /// 95th percentile latency over the recent rolling window.
  final Duration p95Latency;

  /// 99th percentile latency over the recent rolling window.
  final Duration p99Latency;

  /// Number of automatic WebSocket reconnects observed by this client.
  final int wsReconnectCount;

  /// Per-endpoint breakdown keyed by `'METHOD /path'`.
  final Map<String, EndpointMetrics> byEndpoint;

  /// Ratio of cache hits + revalidations to [totalRequests] (`0.0`..`1.0`).
  double get cacheHitRate =>
      totalRequests == 0 ? 0.0 : (cacheHits + revalidatedCount) / totalRequests;

  @override
  String toString() =>
      'OmniNetworkMetrics(total: $totalRequests, ok: $successCount, '
      'fail: $failureCount, cacheHits: $cacheHits, avg: ${averageLatency.inMilliseconds}ms, '
      'p95: ${p95Latency.inMilliseconds}ms, wsReconnects: $wsReconnectCount)';
}
