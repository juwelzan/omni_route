import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../core/cancel_signal.dart';
import '../core/omni_request.dart';
import '../core/omni_response.dart';
import '../transfer/multipart.dart' show ProgressCallback;

/// A fully resolved request handed to a [Transport].
@immutable
final class TransportRequest {
  /// Creates a resolved request.
  TransportRequest({
    required this.method,
    required this.uri,
    Map<String, String> headers = const {},
    this.body,
    this.bodyStream,
    this.contentLength,
    this.onSendProgress,
    this.connectTimeout,
    this.sendTimeout,
    this.receiveTimeout,
  }) : assert(body == null || bodyStream == null),
       headers = Map.unmodifiable(headers);

  /// HTTP method.
  final HttpMethod method;

  /// Absolute URL including the query string.
  final Uri uri;

  /// Final headers (lower-case names).
  final Map<String, String> headers;

  /// Encoded body, or `null`.
  final Uint8List? body;

  /// Streamed body (uploads): each call opens a fresh stream, so the request
  /// can be replayed (e.g. after a token refresh). Exclusive with [body].
  final Stream<List<int>> Function()? bodyStream;

  /// Byte length of [bodyStream], when known.
  final int? contentLength;

  /// Optional wire-level upload progress callback handled by transports that
  /// implement [ProgressReportingTransport].
  final ProgressCallback? onSendProgress;

  /// Stage-specific connection timeout override, if any.
  final Duration? connectTimeout;

  /// Stage-specific send timeout override, if any.
  final Duration? sendTimeout;

  /// Stage-specific receive timeout override, if any.
  final Duration? receiveTimeout;

  /// Copy with [extra] headers added (lower-case names).
  TransportRequest withHeaders(Map<String, String> extra) => TransportRequest(
    method: method,
    uri: uri,
    headers: {...headers, ...extra},
    body: body,
    bodyStream: bodyStream,
    contentLength: contentLength,
    onSendProgress: onSendProgress,
    connectTimeout: connectTimeout,
    sendTimeout: sendTimeout,
    receiveTimeout: receiveTimeout,
  );

  /// Copy with [bodyStream] replaced (headers, URL and method kept).
  TransportRequest withBodyStream(Stream<List<int>> Function() open) =>
      TransportRequest(
        method: method,
        uri: uri,
        headers: headers,
        bodyStream: open,
        contentLength: contentLength,
        onSendProgress: onSendProgress,
        connectTimeout: connectTimeout,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
      );

  /// Copy with upload progress / timeout metadata updated.
  TransportRequest copyWith({
    ProgressCallback? onSendProgress,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) => TransportRequest(
    method: method,
    uri: uri,
    headers: headers,
    body: body,
    bodyStream: bodyStream,
    contentLength: contentLength,
    onSendProgress: onSendProgress ?? this.onSendProgress,
    connectTimeout: connectTimeout ?? this.connectTimeout,
    sendTimeout: sendTimeout ?? this.sendTimeout,
    receiveTimeout: receiveTimeout ?? this.receiveTimeout,
  );

  @override
  String toString() => 'TransportRequest(${method.verb} ${uri.path})';
}

/// Optional marker for [Transport] implementations that invoke
/// [TransportRequest.onSendProgress] with wire-level upload progress.
abstract interface class ProgressReportingTransport implements Transport {}

/// Sends [TransportRequest]s over some I/O mechanism.
///
/// Implementations must:
/// * return any HTTP status as an [OmniRawResponse] (never throw for 4xx/5xx);
/// * abort and throw `CancelledFailure` when [CancelSignal] fires;
/// * throw `ConnectionFailure` for network-level errors.
abstract interface class Transport {
  /// Sends [request]; see class docs for the error contract.
  Future<OmniRawResponse> send(TransportRequest request, CancelSignal cancel);

  /// Like [send] but returns the body as a stream (downloads). The stream
  /// must stop when [cancel] fires.
  Future<StreamedResponse> sendStreamed(
    TransportRequest request,
    CancelSignal cancel,
  );

  /// Releases resources. With [force], in-flight requests are aborted.
  Future<void> close({bool force = false});
}

/// A response whose body has not been read yet.
final class StreamedResponse {
  /// Creates a streamed response. Header names are stored lower-case.
  StreamedResponse({
    required this.statusCode,
    Map<String, String> headers = const {},
    required this.body,
  }) : headers = {
         for (final e in headers.entries) e.key.toLowerCase(): e.value,
       };

  /// HTTP status code.
  final int statusCode;

  /// Response headers (lower-case names).
  final Map<String, String> headers;

  /// Body bytes; single subscription.
  final Stream<List<int>> body;

  /// `content-length`, when present and valid.
  int? get contentLength => int.tryParse(headers['content-length'] ?? '');
}
