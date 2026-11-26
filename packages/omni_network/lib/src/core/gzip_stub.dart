import 'dart:typed_data';

/// Gzip compression is skipped on Web (browsers restrict `Content-Encoding`
/// headers on XHR/Fetch).
Uint8List? tryGzipCompress(Uint8List bytes) => null;
