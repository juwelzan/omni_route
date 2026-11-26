import 'dart:io';

import 'package:crypto/crypto.dart';

import '../core/omni_network_exception.dart';
import '../transport/pin_verifier.dart';
import 'download_target.dart';

/// Whether files can be written on this platform. Internal.
const bool fileDownloadSupported = true;

/// Writes to `<path>.part`, renamed to [path] on success. Internal.
final class FileTarget extends DownloadTarget {
  /// Creates a target for [path]; [resume] keeps an existing `.part` file.
  FileTarget(this.path, {required this.resume, String? expectedSha256})
    : _matcher = expectedSha256 == null
          ? null
          : CertificatePinMatcher([expectedSha256]);

  /// Final file path.
  final String path;

  /// Whether to continue a previous partial download.
  final bool resume;

  final CertificatePinMatcher? _matcher;

  File get _part => File('$path.part');
  File get _meta => File('$path.part.meta');
  IOSink? _sink;

  @override
  Future<int> existingLength() async =>
      resume && await _part.exists() ? await _part.length() : 0;

  @override
  Future<String?> existingValidator() async {
    if (!resume || !await _meta.exists()) return null;
    final v = (await _meta.readAsString()).trim();
    return v.isEmpty ? null : v;
  }

  @override
  Future<void> saveValidator(String? validator) async {
    if (validator == null || validator.isEmpty) {
      if (await _meta.exists()) {
        await _meta.delete().catchError((_) => _meta);
      }
      return;
    }
    await _meta.parent.create(recursive: true);
    await _meta.writeAsString(validator, flush: true);
  }

  @override
  Future<void> begin({required bool append}) async {
    await _part.parent.create(recursive: true);
    _sink = _part.openWrite(mode: append ? FileMode.append : FileMode.write);
  }

  @override
  Future<void> add(List<int> chunk) async => _sink!.add(chunk);

  @override
  Future<void> commit() async {
    await _sink?.close();
    _sink = null;
    final matcher = _matcher;
    if (matcher != null) {
      final digest = await sha256.bind(_part.openRead()).first;
      if (!matcher.matchesDigestBytes(digest.bytes)) {
        await _part.delete().catchError((_) => _part);
        await _meta.delete().catchError((_) => _meta);
        throw const DecodeFailure(
          'Downloaded file failed SHA-256 checksum verification',
        );
      }
    }
    if (await _meta.exists()) {
      await _meta.delete().catchError((_) => _meta);
    }
    await _part.rename(path);
  }

  @override
  Future<void> abort() async {
    // Keep the .part and .part.meta files so a later `resume: true` can continue safely.
    await _sink?.close();
    _sink = null;
  }
}
