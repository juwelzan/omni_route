import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:omni_network/advanced.dart';

/// Outcome category of an [InspectorEntry].
enum InspectorStatus {
  /// Sent, no response yet.
  pending,

  /// 1xx–3xx.
  success,

  /// 4xx.
  clientError,

  /// 5xx.
  serverError,

  /// No response (timeout, connection error, cancelled…).
  failed,
}

/// One request as seen by the inspector. All data is already redacted by
/// the client's `Redactor`.
final class InspectorEntry {
  InspectorEntry._(this.id, this.label, NetworkLogRecord request)
    : method = request.method,
      url = request.url,
      requestHeaders = request.headers,
      requestBody = request.body,
      startedAt = DateTime.now();

  /// Unique within the inspector.
  final int id;

  /// Client label (see [OmniInspector.sink]).
  final String label;

  /// HTTP verb.
  final String method;

  /// Redacted URL.
  final String url;

  /// Redacted request headers.
  final Map<String, String> requestHeaders;

  /// Redacted, truncated request body.
  final String? requestBody;

  /// When the request was logged.
  final DateTime startedAt;

  /// Status code, once a response arrived.
  int? statusCode;

  /// Redacted response headers.
  Map<String, String> responseHeaders = const {};

  /// Redacted, truncated response body.
  String? responseBody;

  /// Elapsed time, once finished.
  Duration? duration;

  /// Failure description, when no response arrived.
  String? error;

  /// Where the response came from.
  ResponseSource? source;

  /// Outcome category.
  InspectorStatus get status {
    if (error != null) return InspectorStatus.failed;
    final s = statusCode;
    if (s == null) return InspectorStatus.pending;
    if (s >= 500) return InspectorStatus.serverError;
    if (s >= 400) return InspectorStatus.clientError;
    return InspectorStatus.success;
  }

  /// A redacted `curl` command for this request.
  String toCurl() {
    String q(String s) => "'${s.replaceAll("'", r"'\''")}'";
    return [
      'curl',
      if (method != 'GET') method == 'HEAD' ? '--head' : '-X $method',
      q(url),
      for (final e in requestHeaders.entries) '-H ${q('${e.key}: ${e.value}')}',
      if (requestBody case final b? when !b.startsWith('<'))
        '--data-raw ${q(b)}',
    ].join(' ');
  }
}

/// Collects redacted request/response records for the in-app inspector.
///
/// Plug it into a client as its log sink:
///
/// ```dart
/// final inspector = OmniInspector();
/// final api = OmniNetwork(
///   baseUrl: '...',
///   enableLogging: inspector.enabled,
///   logSink: inspector.sink('api'),
/// );
/// ```
///
/// Disabled in release builds by default ([enabled]); then it records
/// nothing. Keeps at most [maxEntries] (oldest dropped). Records are
/// redacted by the client before they arrive, so secrets never reach the
/// UI. Call [dispose] when done.
final class OmniInspector extends ChangeNotifier implements LogSink {
  /// Creates an inspector.
  OmniInspector({bool? enabled, this.maxEntries = 300, this.forwardTo})
    : enabled = enabled ?? !kReleaseMode;

  /// Whether records are collected.
  final bool enabled;

  /// Maximum entries kept.
  final int maxEntries;

  /// Optional sink that also receives every record (e.g. `PrintLogSink`).
  final LogSink? forwardTo;

  final ListQueue<InspectorEntry> _entries = ListQueue();
  final Map<(String, int), InspectorEntry> _open = {};
  int _nextId = 0;

  /// Entries, newest first.
  List<InspectorEntry> get entries =>
      List.unmodifiable(_entries.toList().reversed);

  /// A sink tagging records with [label] (one per client, since request ids
  /// are per client).
  LogSink sink(String label) => _LabelledSink(this, label);

  @override
  void log(NetworkLogRecord record) => _add('default', record);

  void _add(String label, NetworkLogRecord r) {
    try {
      forwardTo?.log(r);
    } catch (_) {}
    if (!enabled) return;
    final key = (label, r.requestId);
    switch (r.kind) {
      case NetworkLogKind.request:
        final e = InspectorEntry._(_nextId++, label, r);
        _open[key] = e;
        _entries.addLast(e);
        while (_entries.length > maxEntries) {
          final old = _entries.removeFirst();
          _open.removeWhere((_, v) => identical(v, old));
        }
      case NetworkLogKind.response:
        final e = _open.remove(key);
        if (e == null) return;
        e
          ..statusCode = r.statusCode
          ..responseHeaders = r.headers
          ..responseBody = r.body
          ..duration = r.duration
          ..source = r.source;
      case NetworkLogKind.error:
        final e = _open.remove(key);
        if (e == null) return;
        e
          ..error = r.error
          ..duration = r.duration;
    }
    notifyListeners();
  }

  /// Removes all entries.
  void clear() {
    _entries.clear();
    _open.clear();
    notifyListeners();
  }

  /// Exports recorded exchanges as a HAR 1.2 JSON string (chronological order,
  /// already redacted by `OmniNetwork`'s `Redactor`).
  String toHarJson({bool pretty = true}) {
    String? headerValue(Map<String, String> headers, String lowerName) {
      for (final e in headers.entries) {
        if (e.key.toLowerCase() == lowerName) return e.value;
      }
      return null;
    }

    final harEntries = [
      for (final e in _entries)
        () {
          final uri = Uri.tryParse(e.url);
          final queryString = uri == null
              ? const <Map<String, String>>[]
              : [
                  for (final q in uri.queryParametersAll.entries)
                    for (final v in q.value) {'name': q.key, 'value': v},
                ];
          final elapsedMs = e.duration?.inMilliseconds ?? 0;
          final reqMime =
              headerValue(e.requestHeaders, 'content-type') ?? 'text/plain';
          final resMime =
              headerValue(e.responseHeaders, 'content-type') ??
              'application/octet-stream';
          return {
            'startedDateTime': e.startedAt.toUtc().toIso8601String(),
            'time': elapsedMs,
            'request': {
              'method': e.method,
              'url': e.url,
              'httpVersion': 'HTTP/1.1',
              'headers': [
                for (final h in e.requestHeaders.entries)
                  {'name': h.key, 'value': h.value},
              ],
              'queryString': queryString,
              if (e.requestBody case final reqBody?)
                'postData': {'mimeType': reqMime, 'text': reqBody},
              'headersSize': -1,
              'bodySize': e.requestBody?.length ?? 0,
            },
            'response': {
              'status': e.statusCode ?? 0,
              'statusText': e.error ?? '',
              'httpVersion': 'HTTP/1.1',
              'headers': [
                for (final h in e.responseHeaders.entries)
                  {'name': h.key, 'value': h.value},
              ],
              'content': {
                'size': e.responseBody?.length ?? 0,
                'mimeType': resMime,
                'text': ?e.responseBody,
              },
              'headersSize': -1,
              'bodySize': e.responseBody?.length ?? 0,
            },
            'cache': const <String, Object?>{},
            'timings': {'send': 0, 'wait': elapsedMs, 'receive': 0},
            '_label': e.label,
            if (e.source case final s?) '_source': s.name,
            '_error': ?e.error,
          };
        }(),
    ];

    final root = {
      'log': {
        'version': '1.2',
        'creator': const {'name': 'OmniInspector', 'version': '1.0'},
        'entries': harEntries,
      },
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(root)
        : jsonEncode(root);
  }

  /// Renders recorded requests as a redacted Markdown bug-report summary.
  String toMarkdownReport() {
    final buf = StringBuffer('# OmniNetwork Inspector Report\n\n');
    final all = entries;
    final errors = all
        .where(
          (e) =>
              e.status == InspectorStatus.failed ||
              e.status == InspectorStatus.clientError ||
              e.status == InspectorStatus.serverError,
        )
        .length;
    buf
      ..writeln('- Recorded requests: ${all.length}')
      ..writeln('- Failed / 4xx-5xx: $errors\n');
    for (final e in all) {
      final status = e.statusCode?.toString() ?? e.status.name;
      final ms = e.duration == null ? '-' : '${e.duration!.inMilliseconds} ms';
      buf
        ..writeln('## [${e.label}] ${e.method} ${e.url}')
        ..writeln('- Status: `$status` · Duration: `$ms`')
        ..writeln('- Timestamp: `${e.startedAt.toUtc().toIso8601String()}`');
      if (e.error != null) buf.writeln('- Error: `${e.error}`');
      if (e.source != null) buf.writeln('- Source: `${e.source!.name}`');
      buf
        ..writeln('\n```bash')
        ..writeln(e.toCurl())
        ..writeln('```\n');
    }
    return buf.toString();
  }
}

final class _LabelledSink implements LogSink {
  _LabelledSink(this.inspector, this.label);
  final OmniInspector inspector;
  final String label;
  @override
  void log(NetworkLogRecord record) => inspector._add(label, record);
}
