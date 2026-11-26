import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:meta/meta.dart';

import '../cache/omni_cache.dart' show ResponseSource;
import '../core/http_status.dart';
import 'ansi_stub.dart' if (dart.library.io) 'ansi_io.dart';
import 'network_log.dart';

/// How `enableLogging: true` prints calls. All fields have defaults.
@immutable
final class LogOptions {
  /// Creates options.
  const LogOptions({
    this.headers = false,
    this.requestBody = true,
    this.responseBody = true,
    this.maxLines,
    this.colors,
    this.width = 60,
    this.maxLineLength = 160,
  });

  /// Print request and response headers (redacted), one per line.
  final bool headers;

  /// Print the request body (redacted, JSON pretty-printed).
  final bool requestBody;

  /// Print the response body (redacted, JSON pretty-printed).
  final bool responseBody;

  /// Body lines shown before `… N more lines`; `null` (the default) prints
  /// every line.
  final int? maxLines;

  /// ANSI colours; `null` = automatic: on in Android logs (`flutter run`
  /// and IDEs show them) and in terminals that support them, off on iOS,
  /// whose log turns colour codes into `\^[` text.
  final bool? colors;

  /// Width of the frame lines.
  final int width;

  /// Longest printed line in characters. Longer lines (a long HTML or
  /// base64 value, a long URL) are wrapped onto the next lines, marked
  /// `↪`, so nothing is cut: Android and iOS drop the end of a log line
  /// longer than about 1000 bytes.
  final int maxLineLength;

  /// Copy with selected fields replaced.
  LogOptions copyWith({
    bool? headers,
    bool? requestBody,
    bool? responseBody,
    int? maxLines,
    bool? colors,
    int? width,
    int? maxLineLength,
  }) => LogOptions(
    headers: headers ?? this.headers,
    requestBody: requestBody ?? this.requestBody,
    responseBody: responseBody ?? this.responseBody,
    maxLines: maxLines ?? this.maxLines,
    colors: colors ?? this.colors,
    width: width ?? this.width,
    maxLineLength: maxLineLength ?? this.maxLineLength,
  );
}

/// Prints each call as one block: method and URL, then status, time, size
/// and the whole pretty-printed body. Request and response are printed
/// together in one log event, so concurrent calls never interleave. Data
/// arrives already redacted.
///
/// By default it logs through the `logger` package: a framed block with
/// the date and time, and a level emoji per line — 💡 success, ⚠️ 4xx,
/// ⛔ 5xx or failure. With colours on, successful calls are green with
/// syntax-coloured JSON, and failed ones are red:
///
/// ```text
/// ┌────────────────────────────────────────────────────────────
/// │ 2026-11-17 10:42:07.311
/// ├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
/// │ 💡 GET  https://api.example.com/users/10
/// │ 💡 ✔ 200 OK · 84 ms · 312 B
/// │ 💡 {
/// │ 💡   "id": 10,
/// │ 💡   "name": "Rahim"
/// │ 💡 }
/// └────────────────────────────────────────────────────────────
/// ```
///
/// Pass [logger] to use your own `Logger` (format, file, crash reporter).
/// Passing [printer] instead prints the classic self-framed text block with
/// `printer` (kept for compatibility).
///
/// This is the default sink for `enableLogging: true`.
final class PrettyLogSink implements LogSink {
  /// Creates the sink.
  PrettyLogSink({
    LogOptions options = const LogOptions(),
    void Function(String)? printer,
    Logger? logger,
  }) : _options = options,
       _printer = printer,
       _colors = options.colors ?? terminalSupportsColors(),
       _customLogger = printer == null && logger != null,
       _logger = printer != null ? null : logger;

  /// Formatting options.
  LogOptions get options => _options;
  LogOptions _options;

  final void Function(String)? _printer;
  bool _colors;
  final bool _customLogger;
  Logger? _logger;

  /// Updates formatting options at runtime (used by `OmniNetwork` when toggling
  /// `logResponse` or `logColors` dynamically without dropping pending pairs).
  @internal
  void updateOptions(LogOptions next) {
    final nextColors = next.colors ?? terminalSupportsColors();
    final rebuildLogger =
        !_customLogger &&
        _printer == null &&
        (_colors != nextColors || _options.width != next.width);
    _options = next;
    _colors = nextColors;
    if (rebuildLogger) {
      _logger = null;
    }
  }

  // Created on first use, so a sink given a printer never builds one.
  Logger get _out => _logger ??= _defaultLogger();

  // OmniNetwork already decides whether to log (enableLogging / release
  // builds), so this logger prints everything it is given.
  Logger _defaultLogger() => Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 0, // no Dart stack trace for HTTP calls
      errorMethodCount: 0,
      lineLength: options.width,
      colors: _colors,
      levelColors: {
        for (final l in Level.values)
          l: AnsiColor.fg(l.index >= Level.warning.index ? _redFg : _greenFg),
      },
      dateTimeFormat: formatDateTime,
    ),
    level: Level.trace,
  );

  // Insertion-ordered; bounded so a request whose result is never logged
  // (e.g. a programming error thrown mid-call) cannot grow it forever.
  final Map<int, NetworkLogRecord> _open = {};
  static const _maxOpen = 256;

  /// Requests waiting for their result (diagnostics/tests).
  @visibleForTesting
  int get debugOpenRequests => _open.length;

  @override
  void log(NetworkLogRecord record) {
    switch (record.kind) {
      case NetworkLogKind.request:
        _open[record.requestId] = record;
        while (_open.length > _maxOpen) {
          _open.remove(_open.keys.first);
        }
      case NetworkLogKind.response || NetworkLogKind.error:
        final req = _open.remove(record.requestId);
        if (_printer case final printer?) {
          // Trailing newline: a blank line between blocks.
          printer('${format(req, record)}\n');
        } else {
          _out.log(levelOf(record), message(req, record));
        }
    }
  }

  // ── Colours (xterm 256) ──────────────────────────────────────────────

  static const _greenFg = 40;
  static const _redFg = 196;
  static const _green = '38;5;$_greenFg';
  static const _red = '38;5;$_redFg';
  static const _key = '38;5;81'; // JSON keys: cyan
  static const _string = '38;5;186'; // JSON strings: soft yellow
  static const _number = '38;5;141'; // numbers: violet
  static const _literal = '38;5;205'; // true / false / null: pink
  static const _punct = '38;5;250'; // { } [ ] , : light grey
  static const _text = '38;5;252'; // non-JSON text
  static const _dim = '38;5;244'; // labels, header values
  static const _note = '38;5;45'; // retry / token notes
  static const _bold = '1';

  static bool _failed(NetworkLogRecord r) =>
      r.kind != NetworkLogKind.response || (r.statusCode ?? 0) >= 400;

  /// Log level for a result: info for success, warning for 4xx, error for
  /// 5xx and failures (timeouts, no connection, …). Visible for tests.
  @visibleForTesting
  static Level levelOf(NetworkLogRecord result) {
    if (result.kind != NetworkLogKind.response) return Level.error;
    final status = result.statusCode ?? 0;
    return status >= 500
        ? Level.error
        : status >= 400
        ? Level.warning
        : Level.info;
  }

  // ── Formats ──────────────────────────────────────────────────────────

  /// `2026-11-17 10:42:07.311`: the date and local time of the log line.
  /// Visible for tests.
  @visibleForTesting
  static String formatDateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }

  /// How long a call took: `84 ms`, `1.24 s`, `2 min 05 s`. Visible for
  /// tests.
  @visibleForTesting
  static String formatDuration(Duration? d) {
    final ms = d?.inMilliseconds ?? 0;
    if (ms < 1000) return '$ms ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(2)} s';
    final s = (ms ~/ 1000) % 60;
    return '${ms ~/ 60000} min ${s.toString().padLeft(2, '0')} s';
  }

  static String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  // ── Rendering ────────────────────────────────────────────────────────

  /// The block's text for the `logger` output (the logger draws the frame,
  /// time and line colour). Visible for tests.
  @visibleForTesting
  String message(NetworkLogRecord? request, NetworkLogRecord result) {
    final base = _failed(result) ? _red : _green;
    return [
      for (final row in _rows(request, result))
        if (row != null) _paintRow(row, base),
    ].join('\n');
  }

  /// Renders one classic self-framed block. Visible for tests.
  @visibleForTesting
  String format(NetworkLogRecord? request, NetworkLogRecord result) {
    final base = _failed(result) ? _red : _green;
    String paint(String s) => _colors ? '\x1B[${base}m$s\x1B[0m' : s;
    final rule = '─' * options.width;
    final out = <String>[paint('┌$rule')];
    for (final row in _rows(request, result)) {
      out.add(
        row == null ? paint('├$rule') : '${paint('│')} ${_paintRow(row, base)}',
      );
    }
    out.add(paint('└$rule'));
    return out.join('\n');
  }

  // Inside a line already in [base] colour (the logger colours whole
  // lines): each coloured span switches colour, then goes back to [base].
  String _paintRow(List<_Span> row, String base) {
    if (!_colors) return row.map((s) => s.$1).join();
    final b = StringBuffer('\x1B[${base}m');
    for (final (text, color) in row) {
      if (color == null || color == base) {
        b.write(text);
      } else {
        b.write('\x1B[${color}m$text\x1B[0m\x1B[${base}m');
      }
    }
    return (b..write('\x1B[0m')).toString();
  }

  /// The block's rows; `null` marks the divider between request and
  /// response. Every row fits [LogOptions.maxLineLength].
  List<List<_Span>?> _rows(
    NetworkLogRecord? request,
    NetworkLogRecord result,
  ) => [
    for (final row in _entries(request, result))
      if (row == null) null else ..._wrap(row),
  ];

  List<List<_Span>?> _entries(
    NetworkLogRecord? request,
    NetworkLogRecord result,
  ) {
    final failed = _failed(result);
    final base = failed ? _red : _green;
    final out = <List<_Span>?>[];
    final method = (request?.method ?? result.method).padRight(4);
    out.add([
      (method, '$_bold;$base'),
      (' ${request?.url ?? result.url}', null),
    ]);
    if (request?.note case final n?) {
      out.add([
        (
          n
              .replaceAll('retry', '↻ retry')
              .replaceAll('token refreshed', '🔑 token refreshed'),
          _note,
        ),
      ]);
    }
    if (options.headers && request != null && request.headers.isNotEmpty) {
      out.addAll(_headers('⇢ headers', request.headers));
    }
    final reqBody = options.requestBody ? request?.body : null;
    if (reqBody case final b?) {
      out.add([('⇢ body', _dim)]);
      for (final row in _body(b, highlight: !failed)) {
        out.add([('  ', null), ...row]);
      }
    }
    out.add(null);
    final took = formatDuration(result.duration);
    if (result.kind == NetworkLogKind.response) {
      final status = result.statusCode ?? 0;
      final reason = httpReasonPhrase(status);
      out.add([
        (
          [
            '${failed ? '✖' : '✔'} $status${reason == null ? '' : ' $reason'}',
            took,
            if (result.bytes case final n? when n > 0) _size(n),
            if (result.source case final s? when s != ResponseSource.network)
              s.name,
          ].join(' · '),
          '$_bold;$base',
        ),
      ]);
      if (options.headers && result.headers.isNotEmpty) {
        out.addAll(_headers('⇠ headers', result.headers));
      }
      final resBody = options.responseBody ? result.body : null;
      if (resBody case final b?) out.addAll(_body(b, highlight: !failed));
    } else {
      out.add([('✖ ${result.error ?? 'failed'} · $took', '$_bold;$_red')]);
    }
    return out;
  }

  static List<List<_Span>> _headers(String label, Map<String, String> h) => [
    [(label, _dim)],
    for (final e in h.entries)
      [('  ${e.key}', _key), (': ', _punct), (e.value, _dim)],
  ];

  // The redactor used to cut long bodies and append this; still accepted
  // from custom sinks feeding records through.
  static final _truncatedTail = RegExp(r'… \((\d+) chars, truncated\)$');

  // The whole body: JSON pretty-printed (and syntax-coloured when
  // [highlight]), other text line by line.
  List<List<_Span>> _body(String text, {required bool highlight}) {
    var body = text;
    String? tail;
    if (_truncatedTail.firstMatch(body) case final m?) {
      body = body.substring(0, m.start);
      tail = '… truncated (${m.group(1)} chars in total)';
    }
    var json = true;
    List<String> lines;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map || parsed is List) {
        lines = const JsonEncoder.withIndent('  ').convert(parsed).split('\n');
      } else {
        lines = [body];
        json = parsed is! String;
      }
    } on FormatException {
      // Cut-off or not JSON: indent it anyway when it looks like JSON.
      final t = body.trimLeft();
      json = t.startsWith('{') || t.startsWith('[');
      lines = json ? indentJsonText(t) : body.split('\n');
    }
    if (options.maxLines case final max? when lines.length > max) {
      final more = lines.length - max;
      lines = [...lines.take(max), '… $more more line${more == 1 ? '' : 's'}'];
    }
    return [
      for (final l in lines)
        !highlight
            ? [(l, null)]
            : json
            ? jsonSpans(l)
            : [(l, _text)],
      if (tail != null) [(tail, _dim)],
    ];
  }

  /// One line of JSON split into coloured spans: keys, strings, numbers,
  /// `true`/`false`/`null` and punctuation. Works on cut-off JSON too.
  /// Visible for tests.
  @visibleForTesting
  static List<(String text, String? color)> jsonSpans(String line) {
    final out = <_Span>[];
    void add(String text, String? color) {
      if (text.isEmpty) return;
      if (out.isNotEmpty && out.last.$2 == color) {
        out[out.length - 1] = (out.last.$1 + text, color);
      } else {
        out.add((text, color));
      }
    }

    var i = 0;
    while (i < line.length) {
      final c = line[i];
      if (c == '"') {
        var j = i + 1;
        var escaped = false;
        while (j < line.length) {
          final d = line[j];
          j++;
          if (escaped) {
            escaped = false;
          } else if (d == r'\') {
            escaped = true;
          } else if (d == '"') {
            break;
          }
        }
        var k = j;
        while (k < line.length && line[k] == ' ') {
          k++;
        }
        final isKey = k < line.length && line[k] == ':';
        add(line.substring(i, j), isKey ? _key : _string);
        i = j;
      } else if ('{}[],:'.contains(c)) {
        add(c, _punct);
        i++;
      } else if (c == '-' || _isDigit(c)) {
        var j = i + 1;
        while (j < line.length && _numberChars.contains(line[j])) {
          j++;
        }
        add(line.substring(i, j), _number);
        i = j;
      } else if (line.startsWith('true', i) ||
          line.startsWith('null', i) ||
          line.startsWith('false', i)) {
        final n = line.startsWith('false', i) ? 5 : 4;
        add(line.substring(i, i + n), _literal);
        i += n;
      } else {
        add(c, null);
        i++;
      }
    }
    return out;
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39;
  }

  static const _numberChars = '0123456789eE+-.';

  // Android and iOS cut a log line after about 1000 bytes; keep the text
  // well below that, leaving room for colour codes and the prefix.
  static const _maxRowBytes = 640;

  static int _utf8Length(int rune) => rune < 0x80
      ? 1
      : rune < 0x800
      ? 2
      : rune < 0x10000
      ? 3
      : 4;

  /// Wraps a row longer than [LogOptions.maxLineLength] characters (or
  /// too many bytes for a phone's log) onto continuation rows that start
  /// with the row's indent and `↪`. Splits between characters (runes),
  /// never inside one; a span's colour carries onto the next row.
  List<List<_Span>> _wrap(List<_Span> row) {
    final maxChars = options.maxLineLength < 20 ? 20 : options.maxLineLength;
    var chars = 0;
    var bytes = 0;
    for (final (text, _) in row) {
      for (final r in text.runes) {
        chars++;
        bytes += _utf8Length(r);
      }
    }
    if (chars <= maxChars && bytes <= _maxRowBytes) return [row];

    final plain = row.map((s) => s.$1).join();
    final indent =
        ' ' * (plain.length - plain.trimLeft().length).clamp(0, maxChars ~/ 2);
    final rows = <List<_Span>>[];
    var current = <_Span>[];
    chars = 0;
    bytes = 0;
    void newRow() {
      rows.add(current);
      current = [('$indent↪ ', _dim)];
      chars = indent.length + 2;
      bytes = chars + 2; // "↪" is 3 bytes
    }

    for (final (text, color) in row) {
      final piece = StringBuffer();
      for (final r in text.runes) {
        final size = _utf8Length(r);
        if (chars + 1 > maxChars || bytes + size > _maxRowBytes) {
          if (piece.isNotEmpty) current.add((piece.toString(), color));
          piece.clear();
          newRow();
        }
        piece.writeCharCode(r);
        chars++;
        bytes += size;
      }
      if (piece.isNotEmpty) current.add((piece.toString(), color));
    }
    if (current.isNotEmpty) rows.add(current);
    return rows;
  }

  /// Indents JSON text two spaces per level without parsing it, so it also
  /// works on JSON that was cut off. Strings (and their escapes) are kept
  /// as they are. Visible for tests.
  @visibleForTesting
  static List<String> indentJsonText(String text) {
    final lines = <String>[];
    final line = StringBuffer();
    var depth = 0;
    var inString = false;
    var escaped = false;
    void newLine() {
      if (line.isNotEmpty) lines.add(line.toString());
      line
        ..clear()
        ..write('  ' * depth);
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inString) {
        line.write(c);
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      switch (c) {
        case '"':
          inString = true;
          line.write(c);
        case '{' || '[':
          // Empty {} / []: keep on one line.
          var j = i + 1;
          while (j < text.length && text[j].trim().isEmpty) {
            j++;
          }
          final close = c == '{' ? '}' : ']';
          if (j < text.length && text[j] == close) {
            line.write('$c$close');
            i = j;
          } else {
            line.write(c);
            depth++;
            newLine();
          }
        case '}' || ']':
          depth = depth > 0 ? depth - 1 : 0;
          newLine();
          line.write(c);
        case ',':
          line.write(c);
          newLine();
        case ':':
          line.write(': ');
        case ' ' || '\n' || '\r' || '\t':
          break;
        default:
          line.write(c);
      }
    }
    if (line.toString().trim().isNotEmpty) lines.add(line.toString());
    return lines;
  }
}

/// A piece of a log line and its ANSI colour (`null` = the line's colour).
typedef _Span = (String text, String? color);
