import 'dart:async';

import '../cache/omni_cache.dart' show ResponseSource;
import '../core/omni_network_exception.dart';
import '../core/omni_response.dart';
import '../transport/transport.dart';
import 'network_log.dart';
import 'redactor.dart';

/// Zone key carrying a note for the next logged request. Internal.
final Object logNoteKey = Object();

/// Runs [body] so requests it logs carry [note]. Internal.
Future<T> withLogNote<T>(String note, Future<T> Function() body) {
  final outer = Zone.current[logNoteKey] as String?;
  return runZoned(
    body,
    zoneValues: {logNoteKey: outer == null ? note : '$outer · $note'},
  );
}

/// Formats redacted records and hands them to a [LogSink]. Internal.
final class NetworkLogger {
  /// Creates a logger.
  NetworkLogger(
    this.sink,
    this.redactor, {
    this.logBodies = true,
    this.logRequestBody = true,
    this.logResponseBody = true,
  });

  /// Destination.
  final LogSink sink;

  /// Redaction rules.
  final Redactor redactor;

  /// Whether bodies are enabled overall.
  bool logBodies;

  /// Whether outgoing request bodies are included (when [logBodies] is true).
  bool logRequestBody;

  /// Whether incoming response bodies are included (when [logBodies] is true).
  bool logResponseBody;

  static const _tag = '[OmniNetwork';

  /// Logs an outgoing request.
  void request(int id, TransportRequest r) {
    final url = redactor.uri(r.uri);
    final headers = redactor.headers(r.headers);
    final body = !(logBodies && logRequestBody)
        ? null
        : r.bodyStream != null
        ? '<${r.contentLength ?? '?'} bytes, '
              '${r.headers['content-type'] ?? 'unknown type'}, not shown>'
        : redactor.body(
            r.body,
            r.headers['content-type'],
            maxChars: null, // whole body: logs never cut a response
            maxBytes: null,
          );
    final note = Zone.current[logNoteKey] as String?;
    _emit(
      NetworkLogRecord(
        kind: NetworkLogKind.request,
        requestId: id,
        method: r.method.verb,
        url: url,
        headers: headers,
        body: body,
        note: note,
        message: [
          '$_tag #$id] --> ${r.method.verb} $url',
          if (headers.isNotEmpty) '  headers: $headers',
          if (body != null) '  body: $body',
        ].join('\n'),
      ),
    );
  }

  /// Logs a received response.
  void response(int id, TransportRequest r, OmniRawResponse res) {
    final url = redactor.uri(r.uri);
    final headers = redactor.headers(res.headers);
    final body = (logBodies && logResponseBody)
        ? redactor.body(
            res.bodyBytes,
            res.headers['content-type'],
            maxChars: null,
            maxBytes: null,
          )
        : null;
    final ms = res.duration.inMilliseconds;
    _emit(
      NetworkLogRecord(
        kind: NetworkLogKind.response,
        requestId: id,
        method: r.method.verb,
        url: url,
        headers: headers,
        body: body,
        statusCode: res.statusCode,
        duration: res.duration,
        source: res.source,
        bytes: res.bodyBytes.length,
        message: [
          '$_tag #$id] <-- ${res.statusCode} ${r.method.verb} $url '
              '($ms ms, ${res.bodyBytes.length} B'
              '${res.source == ResponseSource.network ? '' : ', ${res.source.name}'})',
          if (headers.isNotEmpty) '  headers: $headers',
          if (body != null) '  body: $body',
        ].join('\n'),
      ),
    );
  }

  /// Logs a failure without a response.
  void error(
    int id,
    TransportRequest? r,
    String method,
    OmniNetworkException e,
    Duration elapsed,
  ) {
    final url = r == null ? (e.uri?.toString() ?? '') : redactor.uri(r.uri);
    // OmniNetworkException.toString never contains bodies, headers or query.
    final text = '${e.runtimeType}: ${e.message}';
    _emit(
      NetworkLogRecord(
        kind: NetworkLogKind.error,
        requestId: id,
        method: method,
        url: url,
        duration: elapsed,
        error: text,
        message:
            '$_tag #$id] xx $method $url ($text, '
            '${elapsed.inMilliseconds} ms)',
      ),
    );
  }

  void _emit(NetworkLogRecord record) {
    try {
      sink.log(record);
    } catch (_) {
      // A broken sink must never break a request.
    }
  }
}
