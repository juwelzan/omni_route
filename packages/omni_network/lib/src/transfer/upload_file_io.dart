import 'dart:io';

import 'multipart.dart';

/// Reads file length and streams bytes from [path] for multipart upload.
Future<UploadFile> uploadFileFromPath(
  String field,
  String path, {
  String? filename,
  String? contentType,
}) async {
  final file = File(path);
  final length = await file.length();
  final resolvedName = filename ?? _basename(path);
  final resolvedType = contentType ?? _inferMimeType(resolvedName);
  return UploadFile.fromStream(
    field,
    file.openRead,
    length: length,
    filename: resolvedName,
    contentType: resolvedType,
  );
}

String _basename(String path) {
  final parts = path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty);
  return parts.isEmpty ? 'file' : parts.last;
}

String _inferMimeType(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) {
    return 'application/octet-stream';
  }
  return switch (filename.substring(dot + 1).toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'svg' => 'image/svg+xml',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    'json' => 'application/json',
    'txt' || 'log' => 'text/plain',
    'csv' => 'text/csv',
    'html' || 'htm' => 'text/html',
    'xml' => 'application/xml',
    'zip' => 'application/zip',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'aac' => 'audio/aac',
    'm4a' => 'audio/mp4',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _ => 'application/octet-stream',
  };
}
