import 'dart:convert';

import 'package:meta/meta.dart';

/// Masks secrets in headers, query parameters and bodies before logging.
///
/// Redaction cannot be turned off; it can only be extended with
/// [extraHeaders] and [extraKeys].
///
/// Key matching is case-insensitive and ignores `-`/`_`: a key is secret
/// when it **contains** one of the long fragments (`token`, `password`,
/// `secret`, `apikey`, …) or **equals** one of the short keys (`otp`, `pin`,
/// `cvv`, …) so that e.g. `shipping` is not masked because of `pin`.
@immutable
final class Redactor {
  /// Creates a redactor with the built-in rules plus the extras.
  const Redactor({this.extraHeaders = const {}, this.extraKeys = const {}});

  /// Additional header names to mask (case-insensitive).
  final Set<String> extraHeaders;

  /// Additional query/body keys to mask (treated as "contains" fragments).
  final Set<String> extraKeys;

  /// Replacement for masked values.
  static const mask = '***';

  /// Default [body] size limit: larger bodies are summarised by size.
  static const maxRedactedBytes = 64 * 1024;

  static const _headers = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'x-csrf-token',
    'x-xsrf-token',
  };

  static const _fragments = {
    'token',
    'password',
    'passwd',
    'passphrase',
    'secret',
    'apikey',
    'authorization',
    'cookie',
    'session',
    'privatekey',
    'credential',
    'signature',
    'cardnumber',
  };

  static const _exact = {
    'otp',
    'pin',
    'cvv',
    'cvc',
    'ssn',
    'auth',
    'key',
    'sig',
  };

  static String _norm(String k) =>
      k.toLowerCase().replaceAll('-', '').replaceAll('_', '');

  /// Whether a query/body [key] holds a secret.
  bool isSecretKey(String key) {
    final k = _norm(key);
    if (_exact.contains(k)) return true;
    for (final f in _fragments) {
      if (k.contains(f)) return true;
    }
    for (final f in extraKeys) {
      if (k.contains(_norm(f))) return true;
    }
    return false;
  }

  /// Whether header [name] holds a secret (also applies key rules).
  bool isSecretHeader(String name) {
    final n = name.toLowerCase();
    return _headers.contains(n) ||
        extraHeaders.any((h) => h.toLowerCase() == n) ||
        isSecretKey(n);
  }

  /// Copy of [headers] with secret values masked.
  Map<String, String> headers(Map<String, String> headers) => {
    for (final e in headers.entries)
      e.key: isSecretHeader(e.key) ? mask : e.value,
  };

  /// [uri] with user info removed and secret query values masked.
  String uri(Uri uri) {
    final base = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
    if (!uri.hasQuery || uri.query.isEmpty) return base;
    final parts = [
      for (final e in uri.queryParametersAll.entries)
        for (final v in e.value)
          '${Uri.encodeQueryComponent(e.key)}='
              '${isSecretKey(e.key) ? mask : Uri.encodeQueryComponent(v)}',
    ];
    return '$base?${parts.join('&')}';
  }

  /// JSON value with secret keys masked, recursively.
  Object? json(Object? value) => switch (value) {
    Map() => {
      for (final e in value.entries)
        e.key: isSecretKey('${e.key}') ? mask : json(e.value),
    },
    List() => [for (final v in value) json(v)],
    _ => value,
  };

  /// `application/x-www-form-urlencoded` text with secret values masked.
  String form(String body) => body
      .split('&')
      .map((pair) {
        final i = pair.indexOf('=');
        if (i < 0) return pair;
        final key = Uri.decodeQueryComponent(pair.substring(0, i));
        return isSecretKey(key) ? '${pair.substring(0, i)}=$mask' : pair;
      })
      .join('&');

  /// Redacted, printable form of a body, or `null` for no body.
  ///
  /// JSON and form bodies are redacted; other `text/*` bodies are shown;
  /// anything else (binary, multipart, unknown) is summarised by size only.
  /// Output is truncated to [maxChars] characters, and bodies over
  /// [maxBytes] are summarised by size without being parsed; `null` means
  /// no limit (what `enableLogging` uses, so whole responses are printed).
  String? body(
    List<int>? bytes,
    String? contentType, {
    int? maxChars = 2000,
    int? maxBytes = maxRedactedBytes,
  }) {
    if (bytes == null || bytes.isEmpty) return null;
    final type = (contentType ?? '').toLowerCase();
    // Redacting means parsing; callers can refuse that for huge bodies.
    if (maxBytes != null && bytes.length > maxBytes) {
      final label = type.isEmpty ? 'unknown type' : type;
      return '<${bytes.length} bytes, $label, too large to show>';
    }
    String text;
    if (type.contains('json')) {
      final raw = utf8.decode(bytes, allowMalformed: true);
      try {
        text = jsonEncode(json(jsonDecode(raw)));
      } on FormatException {
        return '<${bytes.length} bytes, invalid JSON, not shown>';
      }
    } else if (type.contains('x-www-form-urlencoded')) {
      text = form(utf8.decode(bytes, allowMalformed: true));
    } else if (_isTextualType(type)) {
      text = this.text(utf8.decode(bytes, allowMalformed: true));
    } else {
      final label = type.isEmpty ? 'unknown type' : type;
      return '<${bytes.length} bytes, $label, not shown>';
    }
    if (maxChars != null && text.length > maxChars) {
      text =
          '${text.substring(0, maxChars)}… (${text.length} chars, truncated)';
    }
    return text;
  }

  /// Redacts URIs (query secrets / userInfo), `Bearer`/`Basic` tokens, and
  /// `key=value` / `key: value` secrets embedded in arbitrary text.
  String text(String input) {
    if (input.isEmpty) return input;
    var out = input.replaceAllMapped(_uriInTextPattern, (m) {
      var raw = m.group(0)!;
      var suffix = '';
      while (raw.isNotEmpty &&
          _trailingUriPunct.contains(raw[raw.length - 1])) {
        suffix = raw[raw.length - 1] + suffix;
        raw = raw.substring(0, raw.length - 1);
      }
      final parsed = Uri.tryParse(raw);
      if (parsed == null || parsed.host.isEmpty) return m.group(0)!;
      return '${uri(parsed)}$suffix';
    });

    out = out.replaceAllMapped(_bearerPattern, (m) => '${m.group(1)} $mask');

    out = out.replaceAllMapped(_kvSecretPattern, (m) {
      final prefix = m.group(1)!;
      final key = m.group(2)!;
      final sep = m.group(3)!;
      if (!isSecretKey(key)) return m.group(0)!;
      if (m.group(4) != null) return '$prefix$key$sep"$mask"';
      if (m.group(5) != null) return "$prefix$key$sep'$mask'";
      return '$prefix$key$sep$mask';
    });
    return out;
  }

  static final RegExp _uriInTextPattern = RegExp(
    r'''(?:https?|wss?)://[^\s'"<>]+''',
    caseSensitive: false,
  );
  static const _trailingUriPunct = {'.', ',', ';', ')', ']', '}'};
  static final RegExp _bearerPattern = RegExp(
    r'\b(Bearer|Basic)\s+[A-Za-z0-9\-._~+/]{6,}={0,2}',
    caseSensitive: false,
  );
  static final RegExp _kvSecretPattern = RegExp(
    r'''(^|[\s?&,{(\[])([A-Za-z0-9_.-]+)(\s*[:=]\s*)(?:"([^"\r\n]*)"|'([^'\r\n]*)'|([^\s&,;)}\]]+))''',
  );

  static bool _isTextualType(String type) =>
      type.startsWith('text/') ||
      type.contains('xml') ||
      type.contains('yaml') ||
      type.contains('yml') ||
      type.contains('graphql') ||
      type.contains('javascript') ||
      type.contains('ecmascript') ||
      type.contains('csv') ||
      type.contains('sql');
}
