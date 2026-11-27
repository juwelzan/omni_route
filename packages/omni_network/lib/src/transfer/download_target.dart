import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/omni_network_exception.dart';
import '../transport/pin_verifier.dart';

/// Where a download's body goes. Internal.
abstract class DownloadTarget {
  /// Bytes already present (for `Range` resume); 0 when not resuming.
  Future<int> existingLength();

  /// Cached `ETag` or `Last-Modified` validator for `If-Range` resume.
  Future<String?> existingValidator() async => null;

  /// Persists the `ETag` or `Last-Modified` validator for partial resume.
  Future<void> saveValidator(String? validator) async {}

  /// Called once headers arrive with a 2xx status. [append] is true for a
  /// `206 Partial Content` reply to a resume request.
  Future<void> begin({required bool append});

  /// Writes one chunk.
  Future<void> add(List<int> chunk);

  /// Finishes successfully (and validates integrity when expected).
  Future<void> commit();

  /// Abandons the download (error, cancel, timeout).
  Future<void> abort();
}

/// Collects the body in memory. Internal.
final class BytesTarget extends DownloadTarget {
  /// Creates a memory download target with optional [expectedSha256] check.
  BytesTarget({String? expectedSha256})
    : _matcher = expectedSha256 == null
          ? null
          : CertificatePinMatcher([expectedSha256]);

  final BytesBuilder _b = BytesBuilder(copy: false);
  final CertificatePinMatcher? _matcher;

  /// The collected bytes (after [commit]).
  Uint8List bytes = Uint8List(0);

  @override
  Future<int> existingLength() async => 0;

  @override
  Future<void> begin({required bool append}) async {}

  @override
  Future<void> add(List<int> chunk) async => _b.add(chunk);

  @override
  Future<void> commit() async {
    final result = _b.takeBytes();
    final matcher = _matcher;
    if (matcher != null &&
        !matcher.matchesDigestBytes(sha256.convert(result).bytes)) {
      throw const DecodeFailure(
        'Downloaded payload failed SHA-256 checksum verification',
      );
    }
    bytes = result;
  }

  @override
  Future<void> abort() async => _b.clear();
}
