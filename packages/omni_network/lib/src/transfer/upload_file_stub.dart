import 'multipart.dart';

/// Non-IO stub for [UploadFile.fromFile].
Future<UploadFile> uploadFileFromPath(
  String field,
  String path, {
  String? filename,
  String? contentType,
}) {
  throw UnsupportedError(
    'UploadFile.fromFile is not supported on this platform; '
    'use UploadFile.fromBytes or UploadFile.fromStream',
  );
}
