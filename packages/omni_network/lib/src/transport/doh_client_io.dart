import 'dart:convert';
import 'dart:io';

/// Queries a DNS-over-HTTPS JSON endpoint via `dart:io`.
Future<Map<String, Object?>?> fetchDohJson(Uri uri, Duration timeout) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final req = await client.getUrl(uri).timeout(timeout);
    req.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
    final res = await req.close().timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final body = await utf8.decoder.bind(res).join().timeout(timeout);
    final decoded = jsonDecode(body);
    return decoded is Map<String, Object?>
        ? decoded
        : decoded is Map
        ? Map<String, Object?>.from(decoded)
        : null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
