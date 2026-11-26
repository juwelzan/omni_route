import 'dart:async';

import 'doh_client_stub.dart' if (dart.library.io) 'doh_client_io.dart';

/// Custom DNS host resolution callback returning resolved IP strings (IPv4 or
/// IPv6) for [host]. Return an empty list to fall back to platform DNS.
typedef DnsLookup = Future<List<String>> Function(String host);

/// Resolves hostnames using DNS-over-HTTPS (RFC 8484 JSON API, e.g. Cloudflare
/// or Google Public DNS) with an in-memory TTL cache.
final class DnsOverHttpsResolver {
  /// Creates a DoH resolver targeting [endpoint].
  DnsOverHttpsResolver({
    Uri? endpoint,
    this.defaultTtl = const Duration(minutes: 5),
    this.timeout = const Duration(seconds: 5),
    Future<Map<String, Object?>?> Function(Uri uri)? fetchJson,
    DateTime Function()? now,
  }) : endpoint = endpoint ?? Uri.parse(cloudflareEndpoint),
       _customFetch = fetchJson,
       _now = now ?? DateTime.now;

  /// Cloudflare DNS-over-HTTPS JSON endpoint.
  static const String cloudflareEndpoint =
      'https://cloudflare-dns.com/dns-query';

  /// Google Public DNS-over-HTTPS JSON endpoint.
  static const String googleEndpoint = 'https://dns.google/resolve';

  /// DoH JSON endpoint URI.
  final Uri endpoint;

  /// Cache TTL used when the DNS answer reports a smaller/missing TTL.
  final Duration defaultTtl;

  /// Lookup timeout per query.
  final Duration timeout;

  final Future<Map<String, Object?>?> Function(Uri uri)? _customFetch;
  final DateTime Function() _now;
  final Map<String, ({List<String> ips, DateTime expiresAt})> _cache = {};

  /// Clears cached DNS resolutions.
  void clearCache() => _cache.clear();

  /// Resolves [host] to one or more IP strings (cached until TTL expires).
  Future<List<String>> resolve(String host) async {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final cached = _cache[normalized];
    final current = _now();
    if (cached != null && current.isBefore(cached.expiresAt)) {
      return cached.ips;
    }

    final uri = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'name': normalized,
        'type': 'A',
      },
    );
    final payload = await (_customFetch != null
        ? _customFetch(uri)
        : fetchDohJson(uri, timeout));
    if (payload == null) return const [];

    final answers = payload['Answer'];
    if (answers is! List) return const [];

    final ips = <String>[];
    int? minTtl;
    for (final raw in answers) {
      if (raw is! Map) continue;
      final type = raw['type'];
      final data = raw['data'];
      if ((type == 1 || type == 28) && data is String && data.isNotEmpty) {
        ips.add(data);
        final ttl = raw['TTL'];
        if (ttl is int && ttl > 0) {
          minTtl = minTtl == null || ttl < minTtl ? ttl : minTtl;
        }
      }
    }
    if (ips.isEmpty) return const [];
    final ttlDuration = minTtl == null
        ? defaultTtl
        : Duration(seconds: minTtl);
    _cache[normalized] = (
      ips: List.unmodifiable(ips),
      expiresAt: current.add(ttlDuration),
    );
    return ips;
  }
}
