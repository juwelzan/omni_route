import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Matches TLS server certificates against pinned SHA-256 digests.
///
/// Accepts pins in any of these formats:
/// * `sha256/<base64>` (HPKP / OkHttp style)
/// * Raw Base64 (`<base64>`)
/// * Hexadecimal (`AB:CD:12:...` or 64 raw hex characters)
///
/// Matches against **either** the full leaf X.509 DER certificate or its
/// extracted `SubjectPublicKeyInfo` (SPKI) bytes, so both certificate hashes
/// and public-key hashes work out of the box.
final class CertificatePinMatcher {
  /// Parses [pins] eagerly, throwing [ArgumentError] on invalid entries.
  CertificatePinMatcher(List<String> pins)
    : _pins = List.unmodifiable([for (final p in pins) _parsePin(p)]);

  final List<Uint8List> _pins;

  /// Whether at least one pin is configured.
  bool get isEmpty => _pins.isEmpty;

  /// Returns `true` when [certDer] matches at least one configured SHA-256 pin
  /// and is within [startValidity]..[endValidity] (when supplied).
  bool matchesDer(
    Uint8List certDer, {
    DateTime? startValidity,
    DateTime? endValidity,
    DateTime? now,
  }) {
    if (_pins.isEmpty) return true;
    final checkTime = now ?? DateTime.now();
    if (startValidity != null && checkTime.isBefore(startValidity)) {
      return false;
    }
    if (endValidity != null && !checkTime.isBefore(endValidity)) {
      return false;
    }

    final certHash = Uint8List.fromList(sha256.convert(certDer).bytes);
    if (_matchesDigest(certHash)) return true;

    final spki = extractSpkiFromX509Der(certDer);
    if (spki != null) {
      final spkiHash = Uint8List.fromList(sha256.convert(spki).bytes);
      if (_matchesDigest(spkiHash)) return true;
    }
    return false;
  }

  bool _matchesDigest(Uint8List digest) {
    for (final pin in _pins) {
      if (_constantTimeEquals(pin, digest)) return true;
    }
    return false;
  }

  /// Returns `true` when raw SHA-256 digest [bytes] match any configured pin.
  bool matchesDigestBytes(List<int> bytes) =>
      _matchesDigest(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _parsePin(String raw) {
    var normalized = raw.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(raw, 'pinnedSha256', 'Pin cannot be empty');
    }
    if (normalized.length >= 7 &&
        (normalized.substring(0, 7).toLowerCase() == 'sha256/' ||
            normalized.substring(0, 7).toLowerCase() == 'sha256:')) {
      normalized = normalized.substring(7).trim();
    }

    final hexCandidate = normalized.replaceAll(':', '').replaceAll(' ', '');
    if (hexCandidate.length == 64 && _hexPattern.hasMatch(hexCandidate)) {
      final out = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        out[i] = int.parse(hexCandidate.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return out;
    }

    try {
      final decoded = base64Decode(base64.normalize(normalized));
      if (decoded.length == 32) {
        return Uint8List.fromList(decoded);
      }
    } on FormatException {
      // Fall through to error below.
    }

    throw ArgumentError.value(
      raw,
      'pinnedSha256',
      'Invalid SHA-256 pin; expected "sha256/<base64>", base64, or 64 hex chars',
    );
  }

  static final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]{64}$');
}

/// Extracts the X.509 `SubjectPublicKeyInfo` ASN.1 DER element from [certDer],
/// or returns `null` if [certDer] is not a recognized X.509 structure.
Uint8List? extractSpkiFromX509Der(Uint8List certDer) {
  final outer = _readTlv(certDer, 0);
  if (outer == null || outer.tag != 0x30) return null;

  final tbs = _readTlv(certDer, outer.contentStart);
  if (tbs == null || tbs.tag != 0x30 || tbs.next > outer.next) return null;

  var pos = tbs.contentStart;
  final first = _readTlv(certDer, pos);
  if (first == null || first.next > tbs.next) return null;

  // Optional [0] EXPLICIT version in X.509 v2/v3.
  if (first.tag == 0xA0) {
    pos = first.next;
  }

  // Skip serialNumber, signature, issuer, validity, subject (5 elements).
  for (var i = 0; i < 5; i++) {
    final el = _readTlv(certDer, pos);
    if (el == null || el.next > tbs.next) return null;
    pos = el.next;
  }

  final spki = _readTlv(certDer, pos);
  if (spki == null || spki.tag != 0x30 || spki.next > tbs.next) return null;
  return Uint8List.sublistView(certDer, pos, spki.next);
}

({int tag, int contentStart, int next})? _readTlv(
  Uint8List data,
  int offset,
) {
  if (offset < 0 || offset + 2 > data.length) return null;
  final tag = data[offset];
  // Low-tag-number check: all standard X.509 structural tags fit in 1 octet.
  if ((tag & 0x1F) == 0x1F) return null;

  final lenByte = data[offset + 1];
  int length;
  int contentStart;
  if (lenByte < 0x80) {
    length = lenByte;
    contentStart = offset + 2;
  } else {
    final numBytes = lenByte & 0x7F;
    if (numBytes == 0 || numBytes > 4 || offset + 2 + numBytes > data.length) {
      return null;
    }
    length = 0;
    for (var i = 0; i < numBytes; i++) {
      length = (length << 8) | data[offset + 2 + i];
    }
    contentStart = offset + 2 + numBytes;
  }

  final next = contentStart + length;
  if (length < 0 || next > data.length) return null;
  return (tag: tag, contentStart: contentStart, next: next);
}
