import 'dart:async';
import 'dart:convert';

import '../cache/omni_cache.dart' show CachePolicy;
import '../core/cancel_token.dart';
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_request.dart';
import '../realtime/sse.dart';
import '../resilience/retry_policy.dart';

/// Shared helper that POSTs an AI JSON payload via [client.sendRaw] and throws
/// [HttpFailure] on non-2xx responses.
Future<Map<String, Object?>> postAiJson(
  OmniNetwork client,
  String pathOrUrl, {
  required Object body,
  Map<String, String> headers = const {},
  bool skipAuth = true,
  OmniCancelToken? cancelToken,
}) async {
  final raw = await client.sendRaw(
    OmniRequest.post(
      pathOrUrl,
      body: body,
      headers: {'content-type': 'application/json', ...headers},
      skipAuth: skipAuth,
      cancelToken: cancelToken,
      retry: RetryPolicy.none,
      cachePolicy: CachePolicy.noCache,
    ),
  );
  if (!raw.isSuccess) {
    throw HttpFailure(raw);
  }
  final decoded = raw.json;
  if (decoded is! Map) {
    throw DecodeFailure(
      'Expected JSON object from AI provider',
      uri: raw.requestUri,
    );
  }
  return Map<String, Object?>.from(decoded);
}

/// Shared helper that opens a streaming POST SSE response through
/// [OmniNetwork] (`openStream`) and emits parsed [SseEvent] items.
Stream<SseEvent> postAiSse(
  OmniNetwork client,
  String pathOrUrl, {
  required Object body,
  Map<String, String> headers = const {},
  bool skipAuth = true,
  OmniCancelToken? cancelToken,
}) async* {
  final streamRes = await client.openStream(
    OmniRequest.post(
      pathOrUrl,
      body: body,
      headers: {
        'content-type': 'application/json',
        'accept': 'text/event-stream',
        ...headers,
      },
      skipAuth: skipAuth,
      cancelToken: cancelToken,
      retry: RetryPolicy.none,
      cachePolicy: CachePolicy.noCache,
    ),
  );
  try {
    yield* parseSseByteStream(streamRes.body);
  } finally {
    streamRes.cancel();
  }
}

/// Shared helper for newline-delimited JSON streams (e.g. Ollama `/api/chat`).
Stream<Map<String, Object?>> postAiNdjson(
  OmniNetwork client,
  String pathOrUrl, {
  required Object body,
  Map<String, String> headers = const {},
  bool skipAuth = true,
  OmniCancelToken? cancelToken,
}) async* {
  final streamRes = await client.openStream(
    OmniRequest.post(
      pathOrUrl,
      body: body,
      headers: {'content-type': 'application/json', ...headers},
      skipAuth: skipAuth,
      cancelToken: cancelToken,
      retry: RetryPolicy.none,
      cachePolicy: CachePolicy.noCache,
    ),
  );
  try {
    await for (final line
        in streamRes.body
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        yield Map<String, Object?>.from(decoded);
      }
    }
  } finally {
    streamRes.cancel();
  }
}
