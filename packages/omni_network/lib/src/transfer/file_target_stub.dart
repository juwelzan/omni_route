import 'download_target.dart';

/// Whether files can be written on this platform. Internal.
const bool fileDownloadSupported = false;

/// Unsupported on this platform (e.g. Web). Internal.
final class FileTarget extends DownloadTarget {
  /// Always throws [UnsupportedError].
  FileTarget(String path, {required bool resume, String? expectedSha256}) {
    throw UnsupportedError('downloadToFile is not supported on this platform');
  }

  @override
  Future<int> existingLength() => throw UnimplementedError();
  @override
  Future<void> begin({required bool append}) => throw UnimplementedError();
  @override
  Future<void> add(List<int> chunk) => throw UnimplementedError();
  @override
  Future<void> commit() => throw UnimplementedError();
  @override
  Future<void> abort() => throw UnimplementedError();
}
