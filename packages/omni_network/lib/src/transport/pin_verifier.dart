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
  /// Parses [pins] eagerly, throwing [ArgumentError] on empty or invalid lists.
  CertificatePinMatcher(List<String> pins)
    : _pins = List.unmodifiable([for (final p in pins) _parsePin(p)]) {
    if (_pins.isEmpty) {
      throw ArgumentError.value(
        pins,
        'pinnedSha256',
        'At least one SHA-256 pin is required',
      );
    }
  }

  final List<Uint8List> _pins;

  /// Whether no pins are configured.
  bool get isEmpty => _pins.isEmpty;

  /// Returns `true` when [certDer] matches at least one configured SHA-256 pin,
  /// matches [host] when supplied (against SAN / CN per RFC 6125), and is
  /// within [startValidity]..[endValidity] (when supplied).
  bool matchesDer(
    Uint8List certDer, {
    String? host,
    DateTime? startValidity,
    DateTime? endValidity,
    DateTime? now,
  }) {
    if (_pins.isEmpty) return false;
    final checkTime = now ?? DateTime.now();
    if (startValidity != null && checkTime.isBefore(startValidity)) {
      return false;
    }
    if (endValidity != null && !checkTime.isBefore(endValidity)) {
      return false;
    }
    if (host != null && !matchesCertificateHost(certDer, host)) {
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

({int tag, int contentStart, int next})? _readTlv(Uint8List data, int offset) {
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

/// Verifies that the X.509 DER certificate [certDer] matches [host] via its
/// `SubjectAltName` (`dNSName` / `iPAddress`) extension or `Subject` `CN`
/// fallback when SAN is absent.
bool matchesCertificateHost(Uint8List certDer, String host) {
  var normalizedHost = host.trim().toLowerCase();
  if (normalizedHost.isEmpty) return false;
  if (normalizedHost.startsWith('[') &&
      normalizedHost.endsWith(']') &&
      normalizedHost.length > 2) {
    normalizedHost = normalizedHost.substring(1, normalizedHost.length - 1);
  }
  while (normalizedHost.endsWith('.')) {
    normalizedHost = normalizedHost.substring(0, normalizedHost.length - 1);
  }
  if (normalizedHost.isEmpty) return false;

  final names = _extractCertificateNames(certDer);
  if (names == null) return false;

  final ipBytes = _tryParseIpBytes(normalizedHost);
  final hasSan = names.dnsNames.isNotEmpty || names.ipAddresses.isNotEmpty;

  if (ipBytes != null) {
    if (hasSan) {
      return names.ipAddresses.any((ip) => _bytesEqual(ip, ipBytes));
    }
    for (final cn in names.commonNames) {
      final cnIp = _tryParseIpBytes(cn.trim());
      if (cnIp != null && _bytesEqual(cnIp, ipBytes)) return true;
    }
    return false;
  }

  if (hasSan) {
    return names.dnsNames.any(
      (pattern) => _matchDnsPattern(pattern, normalizedHost),
    );
  }
  return names.commonNames.any((cn) => _matchDnsPattern(cn, normalizedHost));
}

List<int>? _tryParseIpBytes(String host) {
  try {
    return Uri.parseIPv4Address(host);
  } on FormatException {
    // Try IPv6 below.
  }
  try {
    return Uri.parseIPv6Address(host);
  } on FormatException {
    return null;
  }
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _matchDnsPattern(String rawPattern, String host) {
  var pattern = rawPattern.trim().toLowerCase();
  while (pattern.endsWith('.')) {
    pattern = pattern.substring(0, pattern.length - 1);
  }
  if (pattern.isEmpty) return false;
  if (!pattern.contains('*')) {
    return pattern == host;
  }
  final pLabels = pattern.split('.');
  final hLabels = host.split('.');
  // RFC 6125: wildcard allowed only as the complete leftmost label of >= 3 labels.
  if (pLabels.length < 3 || pLabels.length != hLabels.length) return false;
  if (pLabels.first != '*' || hLabels.first.isEmpty) return false;
  for (var i = 1; i < pLabels.length; i++) {
    if (pLabels[i].contains('*') || pLabels[i] != hLabels[i]) return false;
  }
  return true;
}

({
  List<String> dnsNames,
  List<Uint8List> ipAddresses,
  List<String> commonNames,
})?
_extractCertificateNames(Uint8List certDer) {
  final outer = _readTlv(certDer, 0);
  if (outer == null || outer.tag != 0x30) return null;
  final tbs = _readTlv(certDer, outer.contentStart);
  if (tbs == null || tbs.tag != 0x30 || tbs.next > outer.next) return null;

  var pos = tbs.contentStart;
  final first = _readTlv(certDer, pos);
  if (first == null || first.next > tbs.next) return null;
  if (first.tag == 0xA0) {
    pos = first.next;
  }

  // Skip serialNumber, signature, issuer, validity (4 elements).
  for (var i = 0; i < 4; i++) {
    final el = _readTlv(certDer, pos);
    if (el == null || el.next > tbs.next) return null;
    pos = el.next;
  }

  final subject = _readTlv(certDer, pos);
  if (subject == null || subject.next > tbs.next) return null;
  pos = subject.next;

  // Skip subjectPublicKeyInfo.
  final spki = _readTlv(certDer, pos);
  if (spki == null || spki.next > tbs.next) return null;
  pos = spki.next;

  final dnsNames = <String>[];
  final ipAddresses = <Uint8List>[];

  while (pos < tbs.next) {
    final extWrapper = _readTlv(certDer, pos);
    if (extWrapper == null || extWrapper.next > tbs.next) break;
    pos = extWrapper.next;
    if (extWrapper.tag != 0xA3) continue;

    final extSeq = _readTlv(certDer, extWrapper.contentStart);
    if (extSeq == null || extSeq.tag != 0x30 || extSeq.next > extWrapper.next) {
      continue;
    }

    var ePos = extSeq.contentStart;
    while (ePos < extSeq.next) {
      final ext = _readTlv(certDer, ePos);
      if (ext == null || ext.next > extSeq.next) break;
      ePos = ext.next;
      if (ext.tag != 0x30) continue;

      final oid = _readTlv(certDer, ext.contentStart);
      if (oid == null || oid.tag != 0x06 || oid.next > ext.next) continue;
      // OID 2.5.29.17 (id-ce-subjectAltName) = 55 1D 11
      final oidLen = oid.next - oid.contentStart;
      if (oidLen != 3 ||
          certDer[oid.contentStart] != 0x55 ||
          certDer[oid.contentStart + 1] != 0x1D ||
          certDer[oid.contentStart + 2] != 0x11) {
        continue;
      }

      var vPos = oid.next;
      var val = _readTlv(certDer, vPos);
      if (val != null && val.tag == 0x01 && val.next <= ext.next) {
        val = _readTlv(certDer, val.next);
      }
      if (val == null || val.tag != 0x04 || val.next > ext.next) continue;

      final genNames = _readTlv(certDer, val.contentStart);
      if (genNames == null ||
          genNames.tag != 0x30 ||
          genNames.next > val.next) {
        continue;
      }
      var gPos = genNames.contentStart;
      while (gPos < genNames.next) {
        final gn = _readTlv(certDer, gPos);
        if (gn == null || gn.next > genNames.next) break;
        gPos = gn.next;
        if (gn.tag == 0x82) {
          dnsNames.add(
            utf8.decode(
              Uint8List.sublistView(certDer, gn.contentStart, gn.next),
              allowMalformed: true,
            ),
          );
        } else if (gn.tag == 0x87) {
          final len = gn.next - gn.contentStart;
          if (len == 4 || len == 16) {
            ipAddresses.add(
              Uint8List.fromList(
                Uint8List.sublistView(certDer, gn.contentStart, gn.next),
              ),
            );
          }
        }
      }
    }
  }

  final commonNames = <String>[];
  if (subject.tag == 0x30) {
    var rdnPos = subject.contentStart;
    while (rdnPos < subject.next) {
      final rdnSet = _readTlv(certDer, rdnPos);
      if (rdnSet == null || rdnSet.next > subject.next) break;
      rdnPos = rdnSet.next;
      if (rdnSet.tag != 0x31) continue;
      var attrPos = rdnSet.contentStart;
      while (attrPos < rdnSet.next) {
        final attr = _readTlv(certDer, attrPos);
        if (attr == null || attr.next > rdnSet.next) break;
        attrPos = attr.next;
        if (attr.tag != 0x30) continue;
        final attrOid = _readTlv(certDer, attr.contentStart);
        if (attrOid == null ||
            attrOid.tag != 0x06 ||
            attrOid.next > attr.next) {
          continue;
        }
        // OID 2.5.4.3 (commonName) = 55 04 03
        if (attrOid.next - attrOid.contentStart == 3 &&
            certDer[attrOid.contentStart] == 0x55 &&
            certDer[attrOid.contentStart + 1] == 0x04 &&
            certDer[attrOid.contentStart + 2] == 0x03) {
          final str = _readTlv(certDer, attrOid.next);
          if (str != null && str.next <= attr.next) {
            final decoded = _decodeAsn1String(certDer, str);
            if (decoded != null) commonNames.add(decoded);
          }
        }
      }
    }
  }

  return (
    dnsNames: dnsNames,
    ipAddresses: ipAddresses,
    commonNames: commonNames,
  );
}

String? _decodeAsn1String(
  Uint8List data,
  ({int tag, int contentStart, int next}) tlv,
) {
  final view = Uint8List.sublistView(data, tlv.contentStart, tlv.next);
  switch (tlv.tag) {
    case 0x0C: // UTF8String
    case 0x13: // PrintableString
    case 0x16: // IA5String
    case 0x1A: // VisibleString
      return utf8.decode(view, allowMalformed: true);
    case 0x14: // T61String
      return latin1.decode(view);
    case 0x1E: // BMPString (UTF-16BE)
      if (view.length.isOdd) return null;
      final units = <int>[
        for (var i = 0; i < view.length; i += 2) (view[i] << 8) | view[i + 1],
      ];
      return String.fromCharCodes(units);
    default:
      return null;
  }
}
