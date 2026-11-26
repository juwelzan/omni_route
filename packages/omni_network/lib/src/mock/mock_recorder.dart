import 'dart:convert';
import 'dart:typed_data';

import '../core/cancel_signal.dart';
import '../core/omni_request.dart';
import '../core/omni_response.dart';
import '../log/redactor.dart';
import '../transport/mock_transport.dart';
import '../transport/transport.dart';

/// A captured HTTP exchange recorded by [RecordingTransport].
final class RecordedExchange {
  /// Creates a recorded exchange.
  const RecordedExchange({
    required this.method,
    required this.url,
    required this.statusCode,
    this.headers = const {},
    this.bodyBytes,
  });

  /// HTTP method verb.
  final HttpMethod method;

  /// Redacted request URI string.
  final String url;

  /// Recorded HTTP status code.
  final int statusCode;

  /// Recorded response headers (redacted when `redact: true`).
  final Map<String, String> headers;

  /// Recorded raw response body bytes.
  final Uint8List? bodyBytes;

  /// Converts to a JSON map for fixture serialization.
  Map<String, Object?> toJson() => {
    'method': method.name,
    'url': url,
    'statusCode': statusCode,
    'headers': headers,
    if (bodyBytes != null) 'bodyBase64': base64Encode(bodyBytes!),
  };

  /// Restores an exchange written by [toJson].
  factory RecordedExchange.fromJson(Map<String, Object?> json) =>
      RecordedExchange(
        method: HttpMethod.values.byName(json['method']! as String),
        url: json['url']! as String,
        statusCode: json['statusCode']! as int,
        headers: Map<String, String>.from(json['headers'] as Map? ?? const {}),
        bodyBytes: json['bodyBase64'] == null
            ? null
            : base64Decode(json['bodyBase64']! as String),
      );
}

/// Wraps another [Transport] to record real HTTP exchanges into offline replay
/// fixtures ([toMockTransport], [toJson]) with secrets automatically redacted.
final class RecordingTransport implements Transport {
  /// Creates a recording transport wrapping [inner].
  RecordingTransport(
    this.inner, {
    this.redact = true,
    this.redactor = const Redactor(),
  });

  /// Underlying transport actually performing network/mock I/O.
  final Transport inner;

  /// Whether to redact secret query parameters and response headers.
  final bool redact;

  /// Redaction rules applied when [redact] is `true`.
  final Redactor redactor;

  /// All exchanges recorded so far, in order.
  final List<RecordedExchange> exchanges = [];

  @override
  Future<OmniRawResponse> send(
    TransportRequest request,
    CancelSignal cancel,
  ) async {
    final res = await inner.send(request, cancel);
    exchanges.add(
      RecordedExchange(
        method: request.method,
        url: redact ? redactor.uri(request.uri) : request.uri.toString(),
        statusCode: res.statusCode,
        headers: redact ? redactor.headers(res.headers) : res.headers,
        bodyBytes: res.bodyBytes.isEmpty
            ? null
            : Uint8List.fromList(res.bodyBytes),
      ),
    );
    return res;
  }

  @override
  Future<StreamedResponse> sendStreamed(
    TransportRequest request,
    CancelSignal cancel,
  ) => inner.sendStreamed(request, cancel);

  /// Exports recorded exchanges as a JSON-compatible list.
  List<Map<String, Object?>> toJson() => [
    for (final e in exchanges) e.toJson(),
  ];

  /// Imports exchanges previously saved via [toJson] and builds an offline
  /// replay [MockTransport] (matching by method and URL path).
  static MockTransport replayJson(List<Object?> json) {
    final list = [
      for (final item in json)
        RecordedExchange.fromJson(Map<String, Object?>.from(item! as Map)),
    ];
    return _replay(list);
  }

  /// Creates an offline [MockTransport] replaying recorded [exchanges] in order
  /// per `METHOD path`.
  MockTransport toMockTransport() => _replay(exchanges);

  static MockTransport _replay(List<RecordedExchange> list) {
    final buckets = <String, List<RecordedExchange>>{};
    for (final ex in list) {
      final path = Uri.tryParse(ex.url)?.path ?? ex.url;
      (buckets['${ex.method.verb} $path'] ??= []).add(ex);
    }
    return MockTransport((r) {
      final key = '${r.method.verb} ${r.uri.path}';
      final queue = buckets[key];
      if (queue == null || queue.isEmpty) {
        return OmniRawResponse(statusCode: 404);
      }
      final hit = queue.length > 1 ? queue.removeAt(0) : queue.first;
      return OmniRawResponse(
        statusCode: hit.statusCode,
        headers: hit.headers,
        bodyBytes: hit.bodyBytes,
      );
    });
  }

  @override
  Future<void> close({bool force = false}) => inner.close(force: force);
}
