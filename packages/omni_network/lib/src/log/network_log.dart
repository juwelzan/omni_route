import 'package:meta/meta.dart';

import '../cache/omni_cache.dart' show ResponseSource;

/// What a [NetworkLogRecord] describes.
enum NetworkLogKind {
  /// A request is about to be sent.
  request,

  /// A response arrived (any status).
  response,

  /// The request failed without a response.
  error,
}

/// One log entry. Every field is already redacted: safe to print or ship.
@immutable
final class NetworkLogRecord {
  /// Creates a record.
  const NetworkLogRecord({
    required this.kind,
    required this.requestId,
    required this.method,
    required this.url,
    required this.message,
    this.headers = const {},
    this.body,
    this.statusCode,
    this.duration,
    this.error,
    this.source,
    this.note,
    this.bytes,
  });

  /// Kind of event.
  final NetworkLogKind kind;

  /// Correlates request, response and error of one call (per client).
  final int requestId;

  /// HTTP verb.
  final String method;

  /// Redacted URL (no user info; secret query values masked).
  final String url;

  /// Redacted headers.
  final Map<String, String> headers;

  /// Redacted body (whole, unless a custom sink cut it), or `null`.
  final String? body;

  /// Status code ([NetworkLogKind.response] only).
  final int? statusCode;

  /// Elapsed time (response/error only).
  final Duration? duration;

  /// Failure type and message ([NetworkLogKind.error] only).
  final String? error;

  /// Where the response came from ([NetworkLogKind.response] only).
  final ResponseSource? source;

  /// Context for a request, e.g. `retry 2/3` or `token refreshed`.
  final String? note;

  /// Response body size in bytes ([NetworkLogKind.response] only).
  final int? bytes;

  /// Human-readable, multi-line rendering.
  final String message;

  @override
  String toString() => message;
}

/// Receives log records when `enableLogging` is on.
///
/// Implement this to forward to `package:logger`, `dart:developer`, a file,
/// or a crash reporter.
abstract interface class LogSink {
  /// Handles one record. Exceptions thrown here are ignored.
  void log(NetworkLogRecord record);
}

/// Default sink: prints [NetworkLogRecord.message].
final class PrintLogSink implements LogSink {
  /// Creates the print sink.
  const PrintLogSink();

  @override
  void log(NetworkLogRecord record) => print(record.message);
}

/// Forwards every log record to multiple [sinks] (e.g. terminal `PrettyLogSink`
/// and in-app `OmniInspector` simultaneously). Exceptions in individual sinks
/// are isolated so the remaining sinks still receive every record.
final class MultiLogSink implements LogSink {
  /// Creates a fan-out sink forwarding to [sinks].
  const MultiLogSink(this.sinks);

  /// Target sinks invoked in order.
  final List<LogSink> sinks;

  @override
  void log(NetworkLogRecord record) {
    for (final sink in sinks) {
      try {
        sink.log(record);
      } catch (_) {
        // Keep other sinks unaffected.
      }
    }
  }
}
