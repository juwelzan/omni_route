import 'dart:async';
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

/// Category of a unified log card displayed in the Talker-style timeline.
enum InspectorLogKind {
  /// Outgoing HTTP request.
  httpRequest,

  /// Successful (1xx–3xx) HTTP response.
  httpResponse,

  /// Client-side (4xx) HTTP warning response.
  httpWarning,

  /// Server-side (5xx) HTTP error or connection failure.
  httpError,

  /// Navigation transition recorded by `OmniRoute`.
  route,

  /// Bloc or Cubit creation lifecycle event.
  blocCreate,

  /// Bloc incoming event.
  blocEvent,

  /// Bloc/Cubit state transition.
  blocTransition,

  /// Realtime WebSocket event or error.
  ws,

  /// Multi-model AI call or error telemetry.
  ai,

  /// General informational log message.
  info,

  /// General warning log message.
  warning,

  /// General error log message.
  error,
}

/// One separate color-coded log item in [OmniInspector.logs] supporting 1-click
/// copy of either the full log block or the pure API JSON response.
@immutable
final class InspectorLogEntry {
  /// Creates an inspector log timeline entry.
  const InspectorLogEntry({
    required this.id,
    required this.kind,
    required this.tag,
    required this.title,
    required this.timestamp,
    this.subtitle = '',
    this.duration,
    this.copyText = '',
    this.copyBody,
    this.httpEntry,
  });

  /// Unique sequential ID within the inspector.
  final int id;

  /// Log category used for accent coloring and grouping.
  final InspectorLogKind kind;

  /// Display tag badge (e.g. `http-response`, `route`, `bloc-transition`).
  final String tag;

  /// Primary single-line summary title.
  final String title;

  /// Secondary contextual summary text.
  final String subtitle;

  /// Capture wall-clock timestamp.
  final DateTime timestamp;

  /// Optional round-trip or elapsed duration.
  final Duration? duration;

  /// Complete preformatted text copied by 1-click card copy actions.
  final String copyText;

  /// Pure pretty-printed JSON payload when available for response-only copy.
  final String? copyBody;

  /// Associated paired HTTP exchange, if applicable.
  final InspectorEntry? httpEntry;
}

String _prettyJsonOrRaw(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return raw;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map || decoded is List) {
      return const JsonEncoder.withIndent('  ').convert(decoded);
    }
  } catch (_) {}
  return raw;
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

  /// Pretty-formatted JSON response body (or raw text) for 1-click copy.
  String formattedResponseBody() =>
      responseBody == null ? '' : _prettyJsonOrRaw(responseBody!);

  /// Pretty-formatted JSON request body (or raw text).
  String formattedRequestBody() =>
      requestBody == null ? '' : _prettyJsonOrRaw(requestBody!);

  /// Full copyable log block containing status, URL, headers, and body.
  String formattedFullLog() {
    final buf = StringBuffer()
      ..writeln('[$method] $url')
      ..writeln(
        'Status: ${statusCode ?? error ?? 'pending'}'
        '${duration != null ? ' · ${duration!.inMilliseconds} ms' : ''}'
        '${source != null ? ' · ${source!.name}' : ''}',
      );
    if (requestHeaders.isNotEmpty) {
      buf.writeln('\n-- Request Headers --');
      requestHeaders.forEach((k, v) => buf.writeln('$k: $v'));
    }
    if (requestBody != null && requestBody!.isNotEmpty) {
      buf
        ..writeln('\n-- Request Body --')
        ..writeln(formattedRequestBody());
    }
    if (responseHeaders.isNotEmpty) {
      buf.writeln('\n-- Response Headers --');
      responseHeaders.forEach((k, v) => buf.writeln('$k: $v'));
    }
    if (responseBody != null && responseBody!.isNotEmpty) {
      buf
        ..writeln('\n-- Response Body --')
        ..writeln(formattedResponseBody());
    }
    if (error != null) {
      buf.writeln('\n-- Error --\n$error');
    }
    return buf.toString().trimRight();
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
  final ListQueue<WsLogRecord> _wsEntries = ListQueue();
  final ListQueue<AiCallLogRecord> _aiEntries = ListQueue();
  final ListQueue<InspectorLogEntry> _logs = ListQueue();
  final List<StreamSubscription<Object?>> _subs = [];
  int _nextId = 0;
  bool _disposed = false;

  /// Entries, newest first.
  List<InspectorEntry> get entries =>
      List.unmodifiable(_entries.toList().reversed);

  /// All unified Talker-style log cards (`http-request`, `http-response`,
  /// `http-error`, `route`, `bloc`, `ws`, `ai`, `info`, `warning`, `error`),
  /// newest first.
  List<InspectorLogEntry> get logs =>
      List.unmodifiable(_logs.toList().reversed);

  /// Recorded WebSocket events, newest first.
  List<WsLogRecord> get wsEntries =>
      List.unmodifiable(_wsEntries.toList().reversed);

  /// Recorded AI generation calls, newest first.
  List<AiCallLogRecord> get aiEntries =>
      List.unmodifiable(_aiEntries.toList().reversed);

  /// Sum of tokens consumed across all recorded AI calls.
  int get totalAiTokens =>
      _aiEntries.fold(0, (sum, e) => sum + e.usage.totalTokens);

  /// Estimated total USD spent across all recorded AI calls.
  double get totalAiCostUsd =>
      _aiEntries.fold(0.0, (sum, e) => sum + e.usage.estimatedCostUsd);

  /// A sink tagging records with [label] (one per client, since request ids
  /// are per client).
  LogSink sink(String label) => _LabelledSink(this, label);

  void _pushLog(InspectorLogEntry entry) {
    _logs.addLast(entry);
    final limit = maxEntries * 2;
    while (_logs.length > limit) {
      _logs.removeFirst();
    }
  }

  /// Appends a custom log entry (e.g. `route`, `bloc-event`, `info`, `warning`).
  void addLog({
    required InspectorLogKind kind,
    required String tag,
    required String title,
    String subtitle = '',
    Duration? duration,
    String? copyText,
    String? copyBody,
    InspectorEntry? httpEntry,
  }) {
    if (!enabled || _disposed) return;
    final resolvedCopy =
        copyText ??
        [
          '[$tag] $title',
          if (subtitle.isNotEmpty) subtitle,
          if (copyBody != null && copyBody.isNotEmpty) copyBody,
        ].join('\n');
    _pushLog(
      InspectorLogEntry(
        id: _nextId++,
        kind: kind,
        tag: tag,
        title: title,
        subtitle: subtitle,
        timestamp: DateTime.now(),
        duration: duration,
        copyText: resolvedCopy,
        copyBody: copyBody,
        httpEntry: httpEntry,
      ),
    );
    notifyListeners();
  }

  /// Records an `OmniRoute` navigation event card (`route | HH:MM:SS`).
  void logRoute(
    String title, {
    String subtitle = '',
    Duration? duration,
    String? copyText,
  }) => addLog(
    kind: InspectorLogKind.route,
    tag: 'route',
    title: title,
    subtitle: subtitle,
    duration: duration,
    copyText: copyText,
  );

  /// Records a Bloc lifecycle/event/transition card (`bloc-event`,
  /// `bloc-transition`, `bloc-create`).
  void logBloc(
    String tag,
    String title, {
    InspectorLogKind kind = InspectorLogKind.blocEvent,
    String subtitle = '',
    String? copyText,
  }) => addLog(
    kind: kind,
    tag: tag,
    title: title,
    subtitle: subtitle,
    copyText: copyText,
  );

  /// Records an informational app log card.
  void logInfo(String title, {String subtitle = '', String? copyText}) =>
      addLog(
        kind: InspectorLogKind.info,
        tag: 'info',
        title: title,
        subtitle: subtitle,
        copyText: copyText,
      );

  /// Records a warning log card.
  void logWarning(String title, {String subtitle = '', String? copyText}) =>
      addLog(
        kind: InspectorLogKind.warning,
        tag: 'warning',
        title: title,
        subtitle: subtitle,
        copyText: copyText,
      );

  /// Records an error log card.
  void logError(String title, {String subtitle = '', String? copyText}) =>
      addLog(
        kind: InspectorLogKind.error,
        tag: 'error',
        title: title,
        subtitle: subtitle,
        copyText: copyText,
      );

  /// Records a single redacted WebSocket log event.
  void recordWsLog(WsLogRecord record) {
    if (!enabled || _disposed) return;
    _wsEntries.addLast(record);
    while (_wsEntries.length > maxEntries) {
      _wsEntries.removeFirst();
    }
    _pushLog(
      InspectorLogEntry(
        id: _nextId++,
        kind: record.direction == 'err'
            ? InspectorLogKind.error
            : InspectorLogKind.ws,
        tag: record.direction == 'err' ? 'ws-error' : 'ws-${record.direction}',
        title: '${record.direction.toUpperCase()} ${record.uri}',
        subtitle: record.summary,
        timestamp: record.timestamp,
        copyText: '[WS ${record.direction}] ${record.uri}\n${record.summary}',
        copyBody: _prettyJsonOrRaw(record.summary),
      ),
    );
    notifyListeners();
  }

  /// Records a single redacted AI call telemetry event.
  void recordAiCall(AiCallLogRecord record) {
    if (!enabled || _disposed) return;
    _aiEntries.addLast(record);
    while (_aiEntries.length > maxEntries) {
      _aiEntries.removeFirst();
    }
    _pushLog(
      InspectorLogEntry(
        id: _nextId++,
        kind: record.error != null ? InspectorLogKind.error : InspectorLogKind.ai,
        tag: record.error != null ? 'ai-error' : 'ai-response',
        title: '${record.providerId}:${record.model} · ${record.usage.totalTokens} tok',
        subtitle: record.error ?? record.responsePreview ?? record.promptPreview ?? '',
        timestamp: DateTime.now(),
        duration: record.latency,
        copyText:
            '[AI ${record.providerId}:${record.model}]\n'
            'Prompt: ${record.promptPreview ?? ''}\n'
            'Response: ${record.responsePreview ?? ''}\n'
            'Error: ${record.error ?? 'none'}',
        copyBody: record.responsePreview,
      ),
    );
    notifyListeners();
  }

  /// Subscribes this inspector to [client]'s realtime WebSocket logs (and
  /// optionally its [OmniAi.telemetry] stream).
  ///
  /// Returned callback detaches the subscriptions; [dispose] also cancels all
  /// active subscriptions automatically.
  VoidCallback attachClient(OmniNetwork client, {bool includeAi = true}) {
    final wsSub = client.realtimeLogs.listen(recordWsLog);
    _subs.add(wsSub);
    StreamSubscription<AiCallLogRecord>? aiSub;
    if (includeAi) {
      aiSub = client.ai.telemetry.listen(recordAiCall);
      _subs.add(aiSub);
    }
    return () {
      _subs.remove(wsSub);
      unawaited(wsSub.cancel());
      if (aiSub != null) {
        _subs.remove(aiSub);
        unawaited(aiSub.cancel());
      }
    };
  }

  /// Subscribes this inspector directly to an [OmniAi] instance's telemetry.
  VoidCallback attachAi(OmniAi ai) {
    final sub = ai.telemetry.listen(recordAiCall);
    _subs.add(sub);
    return () {
      _subs.remove(sub);
      unawaited(sub.cancel());
    };
  }

  @override
  void dispose() {
    _disposed = true;
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    super.dispose();
  }

  @override
  void log(NetworkLogRecord record) => _add('default', record);

  void _add(String label, NetworkLogRecord r) {
    try {
      forwardTo?.log(r);
    } catch (_) {}
    if (!enabled || _disposed) return;
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
        _pushLog(
          InspectorLogEntry(
            id: _nextId++,
            kind: InspectorLogKind.httpRequest,
            tag: 'http-request',
            title: '${r.method} ${r.url}',
            subtitle: r.body != null ? 'Body: ${r.body}' : 'Request dispatched',
            timestamp: e.startedAt,
            copyText: e.formattedFullLog(),
            copyBody: e.requestBody == null ? null : e.formattedRequestBody(),
            httpEntry: e,
          ),
        );
      case NetworkLogKind.response:
        final e = _open.remove(key);
        if (e == null) return;
        e
          ..statusCode = r.statusCode
          ..responseHeaders = r.headers
          ..responseBody = r.body
          ..duration = r.duration
          ..source = r.source;
        final status = r.statusCode ?? 200;
        final kind = status >= 500
            ? InspectorLogKind.httpError
            : status >= 400
            ? InspectorLogKind.httpWarning
            : InspectorLogKind.httpResponse;
        final tag = status >= 500
            ? 'http-error'
            : status >= 400
            ? 'http-warning'
            : 'http-response';
        _pushLog(
          InspectorLogEntry(
            id: _nextId++,
            kind: kind,
            tag: tag,
            title: '${e.method} $status · ${e.url}',
            subtitle:
                '${r.bytes ?? e.responseBody?.length ?? 0} B'
                '${r.source != null && r.source != ResponseSource.network ? ' · ${r.source!.name}' : ''}',
            timestamp: DateTime.now(),
            duration: r.duration,
            copyText: e.formattedFullLog(),
            copyBody: e.formattedResponseBody(),
            httpEntry: e,
          ),
        );
      case NetworkLogKind.error:
        final e = _open.remove(key);
        if (e == null) return;
        e
          ..error = r.error
          ..duration = r.duration;
        _pushLog(
          InspectorLogEntry(
            id: _nextId++,
            kind: InspectorLogKind.httpError,
            tag: 'http-error',
            title: '${e.method} ERROR · ${e.url}',
            subtitle: r.error ?? 'Request failed',
            timestamp: DateTime.now(),
            duration: r.duration,
            copyText: e.formattedFullLog(),
            copyBody: r.error,
            httpEntry: e,
          ),
        );
    }
    notifyListeners();
  }

  /// Removes all HTTP, WebSocket, AI, and unified timeline log entries.
  void clear() {
    if (_disposed) return;
    _entries.clear();
    _open.clear();
    _wsEntries.clear();
    _aiEntries.clear();
    _logs.clear();
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
    if (_wsEntries.isNotEmpty) {
      buf.writeln('## WebSocket Events (${_wsEntries.length})\n');
      for (final ws in wsEntries) {
        buf.writeln(
          '- `${ws.timestamp.toUtc().toIso8601String()}` '
          '[${ws.direction.toUpperCase()}] `${ws.uri}` — ${ws.summary}',
        );
      }
      buf.writeln();
    }
    if (_aiEntries.isNotEmpty) {
      buf
        ..writeln('## AI Calls (${_aiEntries.length})\n')
        ..writeln(
          '- Total tokens: `$totalAiTokens` · '
          'Estimated USD: `\$${totalAiCostUsd.toStringAsFixed(4)}`\n',
        );
      for (final call in aiEntries) {
        final err = call.error == null ? '' : ' · error: `${call.error}`';
        buf.writeln(
          '- `${call.providerId}:${call.model}` · '
          '${call.usage.totalTokens} tok · '
          '${call.latency.inMilliseconds} ms'
          '${call.usedFallback ? ' · fallback' : ''}$err',
        );
      }
      buf.writeln();
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
