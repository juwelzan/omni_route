import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../cache/omni_cache.dart' show CachePolicy;
import '../core/cancel_token.dart';
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_request.dart';
import '../core/omni_response.dart';
import '../realtime/sse.dart';
import '../resilience/retry_policy.dart';
import '../transfer/multipart.dart';

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

/// Shared helper that POSTs an AI JSON payload expecting raw binary bytes back
/// (e.g. OpenAI TTS `/audio/speech`).
Future<OmniRawResponse> postAiBytes(
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
  return raw;
}

/// Shared helper that POSTs a `multipart/form-data` request to an AI endpoint
/// (e.g. OpenAI `/audio/transcriptions`) and returns the decoded JSON object.
Future<Map<String, Object?>> postAiMultipart(
  OmniNetwork client,
  String pathOrUrl, {
  Map<String, String> fields = const {},
  required List<UploadFile> files,
  Map<String, String> headers = const {},
  bool skipAuth = true,
  OmniCancelToken? cancelToken,
}) async {
  final raw = await client.sendRaw(
    OmniRequest.post(
      pathOrUrl,
      body: MultipartBody(fields: fields, files: files),
      headers: headers,
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
      'Expected JSON object from AI multipart endpoint',
      uri: raw.requestUri,
    );
  }
  return Map<String, Object?>.from(decoded);
}

/// Throws a structured [HttpFailure] (when `status` is numeric 4xx/5xx) or
/// [RequestFailure] if a streaming SSE/NDJSON payload encodes a provider-side
/// error object mid-stream.
void throwIfAiErrorEnvelope(Map<Object?, Object?> decoded) {
  final err = decoded['error'];
  if (err == null) return;
  final msg = err is Map
      ? (err['message']?.toString() ?? jsonEncode(err))
      : '$err';
  final code = err is Map ? err['status'] ?? err['code'] : null;
  if (code is int && code >= 400) {
    throw HttpFailure(
      OmniRawResponse(
        statusCode: code,
        bodyBytes: Uint8List.fromList(utf8.encode(msg)),
      ),
    );
  }
  throw RequestFailure('AI stream error: $msg');
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
        throwIfAiErrorEnvelope(decoded);
        yield Map<String, Object?>.from(decoded);
      }
    }
  } finally {
    streamRes.cancel();
  }
}
