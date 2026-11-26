import 'package:dio/dio.dart';

import '../core/omni_network_exception.dart';

/// Web/non-IO stub: browser handles TLS, HTTP/2/HTTP/3, and proxies natively.
HttpClientAdapter? buildConfiguredAdapter({
  String? proxy,
  List<String> pinnedSha256 = const [],
  bool allowBadProxyCertificate = true,
  int? maxConnectionsPerHost,
  Duration? idleConnectionTimeout,
  bool enableHttp2 = false,
  Object? Function(Object client)? onHttpClientCreate,
}) {
  return null;
}

/// Classifies a [DioException] on non-IO platforms.
ConnectionReason classifyDioError(DioException error) {
  if (error.type == DioExceptionType.badCertificate) {
    return ConnectionReason.sslMismatch;
  }
  final msg = '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();
  if (msg.contains('ssl') ||
      msg.contains('certificate') ||
      msg.contains('tls')) {
    return ConnectionReason.sslMismatch;
  }
  if (msg.contains('failed host lookup') || msg.contains('dns')) {
    return ConnectionReason.dnsFailed;
  }
  if (msg.contains('refused')) {
    return ConnectionReason.connectionRefused;
  }
  if (msg.contains('reset') || msg.contains('aborted')) {
    return ConnectionReason.connectionReset;
  }
  if (msg.contains('offline') ||
      msg.contains('network') ||
      error.type == DioExceptionType.connectionError) {
    return ConnectionReason.noInternet;
  }
  return ConnectionReason.unknown;
}
