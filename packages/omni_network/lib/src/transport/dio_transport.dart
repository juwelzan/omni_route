import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/cancel_signal.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_response.dart';
import 'dio_io_stub.dart' if (dart.library.io) 'dio_io_io.dart';
import 'transport.dart';

/// Default [Transport] backed by `package:dio`.
///
/// Dio is an implementation detail: no Dio type appears in OmniNetwork's
/// simple request/response API. Status codes are never turned into errors here,
/// and overall deadlines are enforced by `OmniNetwork`, while optional
/// stage-specific timeouts ([Options.connectTimeout], [Options.sendTimeout],
/// [Options.receiveTimeout]), wire-level send progress, HTTP/2, proxy routing,
/// and SHA-256 certificate pinning are handled cleanly at the transport layer.
final class DioTransport implements ProgressReportingTransport {
  /// Creates a transport. Pass [dio] to customise the client or interceptors.
  DioTransport({Dio? dio}) : _dio = dio ?? Dio();

  /// Creates a configured [DioTransport] with built-in proxy, SSL certificate
  /// pinning ([pinnedSha256]), stage-specific timeouts, HTTP/2 multiplexing, or
  /// a custom [httpClientAdapter] (e.g. native Cronet/`NSURLSession` adapter).
  ///
  /// When [dio] is supplied, its base options and interceptors are preserved
  /// and only explicitly provided timeout/adapter overrides are applied.
  factory DioTransport.configured({
    Dio? dio,
    String? proxy,
    List<String> pinnedSha256 = const [],
    bool allowBadProxyCertificate = true,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    int? maxConnectionsPerHost,
    Duration? idleConnectionTimeout,
    bool enableHttp2 = false,
    HttpClientAdapter? httpClientAdapter,
    Object? Function(Object client)? onHttpClientCreate,
  }) {
    final hasAdapterConfig =
        proxy != null ||
        pinnedSha256.isNotEmpty ||
        maxConnectionsPerHost != null ||
        idleConnectionTimeout != null ||
        enableHttp2 ||
        onHttpClientCreate != null;

    final resolvedAdapter =
        httpClientAdapter ??
        (hasAdapterConfig
            ? buildConfiguredAdapter(
                proxy: proxy,
                pinnedSha256: pinnedSha256,
                allowBadProxyCertificate: allowBadProxyCertificate,
                maxConnectionsPerHost: maxConnectionsPerHost,
                idleConnectionTimeout: idleConnectionTimeout,
                enableHttp2: enableHttp2,
                onHttpClientCreate: onHttpClientCreate,
              )
            : null);

    final client = dio ?? Dio();
    if (connectTimeout != null) {
      client.options.connectTimeout = connectTimeout;
    }
    if (sendTimeout != null) {
      client.options.sendTimeout = sendTimeout;
    }
    if (receiveTimeout != null) {
      client.options.receiveTimeout = receiveTimeout;
    }
    if (resolvedAdapter != null) {
      client.httpClientAdapter = resolvedAdapter;
    }
    return DioTransport(dio: client);
  }

  final Dio _dio;
  final Set<CancelToken> _active = {};

  @override
  Future<OmniRawResponse> send(
    TransportRequest request,
    CancelSignal cancel,
  ) async {
    final r = await _request<List<int>>(request, cancel, ResponseType.bytes);
    final data = r.data;
    return OmniRawResponse(
      statusCode: r.statusCode ?? 0,
      headers: _headers(r.headers),
      bodyBytes: data == null
          ? null
          : data is Uint8List
          ? data
          : Uint8List.fromList(data),
    );
  }

  @override
  Future<StreamedResponse> sendStreamed(
    TransportRequest request,
    CancelSignal cancel,
  ) async {
    final r = await _request<ResponseBody>(
      request,
      cancel,
      ResponseType.stream,
    );
    final body = r.data;
    return StreamedResponse(
      statusCode: r.statusCode ?? 0,
      headers: _headers(r.headers),
      body: body == null
          ? const Stream<List<int>>.empty()
          : body.stream.handleError((Object e) {
              throw ConnectionFailure(
                'Connection lost while reading the body',
                uri: safeUri(request.uri),
                cause: e,
                reason: ConnectionReason.connectionReset,
              );
            }),
    );
  }

  static Map<String, String> _headers(Headers h) => {
    for (final e in h.map.entries) e.key: e.value.join(', '),
  };

  Future<Response<T>> _request<T>(
    TransportRequest request,
    CancelSignal cancel,
    ResponseType type,
  ) async {
    final token = CancelToken();
    _active.add(token);
    final sub = cancel.whenCancelled.then((_) => token.cancel());
    if (cancel.isCancelled) token.cancel();
    final open = request.bodyStream;
    final headers = {
      ...request.headers,
      if (open != null && request.contentLength != null)
        'content-length': '${request.contentLength}',
    };
    final onProgress = request.onSendProgress;
    try {
      return await _dio.requestUri<T>(
        request.uri,
        data: open != null ? open() : request.body,
        cancelToken: token,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) =>
                  onProgress(sent, total <= 0 ? request.contentLength : total),
        options: Options(
          method: request.method.verb,
          headers: headers,
          responseType: type,
          connectTimeout: request.connectTimeout,
          sendTimeout: request.sendTimeout,
          receiveTimeout: request.receiveTimeout,
          validateStatus: (_) => true,
          // OmniNetwork follows redirects itself (credential-safe).
          followRedirects: false,
          maxRedirects: 0,
          // Dio would otherwise pick a content type; ours is in headers.
          contentType: request.headers['content-type'],
        ),
      );
    } on DioException catch (e) {
      final uri = safeUri(request.uri);
      switch (e.type) {
        case DioExceptionType.cancel:
          throw CancelledFailure(uri: uri);
        case DioExceptionType.connectionTimeout:
          throw TimeoutFailure(
            request.connectTimeout ??
                _dio.options.connectTimeout ??
                Duration.zero,
            uri: uri,
            stage: TimeoutStage.connect,
          );
        case DioExceptionType.sendTimeout:
          throw TimeoutFailure(
            request.sendTimeout ?? _dio.options.sendTimeout ?? Duration.zero,
            uri: uri,
            stage: TimeoutStage.send,
          );
        case DioExceptionType.receiveTimeout:
          throw TimeoutFailure(
            request.receiveTimeout ??
                _dio.options.receiveTimeout ??
                Duration.zero,
            uri: uri,
            stage: TimeoutStage.receive,
          );
        case DioExceptionType.transformTimeout:
          throw TimeoutFailure(
            _dio.options.transformTimeout ?? Duration.zero,
            uri: uri,
            stage: TimeoutStage.overall,
          );
        case DioExceptionType.badCertificate:
          throw ConnectionFailure(
            'TLS certificate verification failed',
            uri: uri,
            cause: e.error ?? e.type,
            reason: ConnectionReason.sslMismatch,
          );
        case DioExceptionType.badResponse:
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          final reason = classifyDioError(e);
          throw ConnectionFailure(
            'Network error (${e.type.name}: ${reason.name})',
            uri: uri,
            cause: e.error ?? e.type,
            reason: reason,
          );
      }
    } finally {
      _active.remove(token);
      sub.ignore();
    }
  }

  @override
  Future<void> close({bool force = false}) async {
    if (force) {
      for (final t in _active.toList()) {
        t.cancel();
      }
    }
    _dio.close(force: force);
  }
}
