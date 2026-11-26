import 'dart:io';
import 'dart:typed_data';

/// Compresses [bytes] using gzip on IO platforms.
Uint8List? tryGzipCompress(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  final compressed = gzip.encode(bytes);
  return compressed is Uint8List ? compressed : Uint8List.fromList(compressed);
}
