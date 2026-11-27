import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../core/omni_network_exception.dart';
import 'upload_file_stub.dart' if (dart.library.io) 'upload_file_io.dart';

/// Reports transfer progress; [total] is `null` when unknown.
typedef ProgressCallback = void Function(int transferred, int? total);

/// One file part of a [MultipartBody].
@immutable
final class UploadFile {
  /// Reads a local file at [path] by streaming its bytes cleanly without
  /// loading the entire file into RAM (IO platforms only).
  ///
  /// When omitted, [filename] is extracted from [path] and [contentType] is
  /// inferred from the extension (falling back to `'application/octet-stream'`).
  /// Throws [UnsupportedError] on Web.
  static Future<UploadFile> fromFile(
    String field,
    String path, {
    String? filename,
    String? contentType,
  }) => uploadFileFromPath(
    field,
    path,
    filename: filename,
    contentType: contentType,
  );

  /// A file held in memory.
  UploadFile.fromBytes(
    this.field,
    List<int> bytes, {
    required this.filename,
    String contentType = 'application/octet-stream',
  }) : contentType = _validateHeaderValue(contentType, 'contentType'),
       length = bytes.length,
       _open = (() => Stream.value(bytes));

  /// A file read from a stream, e.g. on IO platforms:
  ///
  /// ```dart
  /// final f = File(path);
  /// UploadFile.fromStream('file', f.openRead, length: f.lengthSync(),
  ///     filename: 'photo.jpg', contentType: 'image/jpeg');
  /// ```
  ///
  /// [open] is called once per attempt, so it must return a fresh stream.
  UploadFile.fromStream(
    this.field,
    Stream<List<int>> Function() open, {
    required this.length,
    required this.filename,
    String contentType = 'application/octet-stream',
  }) : contentType = _validateHeaderValue(contentType, 'contentType'),
       _open = open;

  static String _validateHeaderValue(String value, String name) {
    if (value.isEmpty ||
        value.contains('\r') ||
        value.contains('\n') ||
        value.contains('\x00')) {
      throw ArgumentError.value(
        value,
        name,
        'Header value cannot be empty or contain CR/LF/NUL characters',
      );
    }
    return value;
  }

  /// Form field name.
  final String field;

  /// File name sent to the server.
  final String filename;

  /// MIME type of the part.
  final String contentType;

  /// Byte length (required so the request has a `content-length`).
  final int length;

  final Stream<List<int>> Function() _open;
}

/// A `multipart/form-data` request body; pass it as `OmniRequest.body` or
/// use `OmniNetwork.upload`.
@immutable
final class MultipartBody {
  /// Creates a body with text [fields] and [files].
  MultipartBody({
    this.fields = const {},
    this.files = const [],
    String? boundary,
  }) : boundary = boundary == null
           ? _randomBoundary()
           : UploadFile._validateHeaderValue(boundary, 'boundary');

  /// Text fields.
  final Map<String, String> fields;

  /// File parts.
  final List<UploadFile> files;

  /// Part separator.
  final String boundary;

  /// `content-type` header value.
  String get contentType => 'multipart/form-data; boundary=$boundary';

  static final _rand = Random.secure();
  static const _chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static String _randomBoundary() =>
      'omni-${List.generate(24, (_) => _chars[_rand.nextInt(_chars.length)]).join()}';

  // Per the HTML spec: escape `"`, CR and LF in names.
  static String _escape(String v) =>
      v.replaceAll('\r', '%0D').replaceAll('\n', '%0A').replaceAll('"', '%22');

  List<int> _fieldPart(String name, String value) => utf8.encode(
    '--$boundary\r\n'
    'content-disposition: form-data; name="${_escape(name)}"\r\n\r\n'
    '$value\r\n',
  );

  List<int> _fileHeader(UploadFile f) => utf8.encode(
    '--$boundary\r\n'
    'content-disposition: form-data; name="${_escape(f.field)}"; '
    'filename="${_escape(f.filename)}"\r\n'
    'content-type: ${UploadFile._validateHeaderValue(f.contentType, 'contentType')}\r\n\r\n',
  );

  static final _crlf = Uint8List.fromList([13, 10]);
  List<int> get _end => utf8.encode('--$boundary--\r\n');

  /// Total encoded length in bytes.
  int get length {
    var n = _end.length;
    for (final e in fields.entries) {
      n += _fieldPart(e.key, e.value).length;
    }
    for (final f in files) {
      n += _fileHeader(f).length + f.length + _crlf.length;
    }
    return n;
  }

  /// Opens a fresh stream of the encoded body.
  Stream<List<int>> open() async* {
    for (final e in fields.entries) {
      yield _fieldPart(e.key, e.value);
    }
    for (final f in files) {
      yield _fileHeader(f);
      var sent = 0;
      await for (final chunk in f._open()) {
        sent += chunk.length;
        if (sent > f.length) {
          throw RequestFailure(
            'UploadFile "${f.filename}" produced more than ${f.length} bytes',
          );
        }
        yield chunk;
      }
      if (sent != f.length) {
        throw RequestFailure(
          'UploadFile "${f.filename}" produced $sent of ${f.length} bytes',
        );
      }
      yield _crlf;
    }
    yield _end;
  }
}
