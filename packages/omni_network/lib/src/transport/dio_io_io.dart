import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';

import '../core/omni_network_exception.dart';
import 'dns_resolver.dart';
import 'pin_verifier.dart';

/// Normalizes a user-supplied [proxy] string into an [HttpClient.findProxy]
/// rule and optional proxy [Uri] (null only for `'DIRECT'`).
({String rule, Uri? uri}) parseProxyConfig(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(raw, 'proxy', 'Proxy cannot be empty');
  }
  if (trimmed.toUpperCase() == 'DIRECT') {
    return (rule: 'DIRECT', uri: null);
  }

  var authority = trimmed;
  if (authority.length > 6 &&
      authority.substring(0, 6).toUpperCase() == 'PROXY ') {
    authority = authority.substring(6).trim();
  }
  if (!authority.contains('://')) {
    authority = 'http://$authority';
  }
  final uri = Uri.tryParse(authority);
  if (uri == null ||
      uri.host.isEmpty ||
      !uri.hasPort ||
      uri.port <= 0 ||
      uri.port > 65535) {
    throw ArgumentError.value(
      raw,
      'proxy',
      'Invalid proxy; expected "host:port" (e.g. "192.168.0.105:8888")',
    );
  }
  final hostPart = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  return (rule: 'PROXY $hostPart:${uri.port}', uri: uri);
}

/// Builds an [HttpClient] factory configured with proxy, SHA-256 certificate
/// pinning, mTLS client certificates, custom DNS / DoH, and timeouts.
Object? Function()? buildConfiguredHttpClientFactory({
  String? proxy,
  List<String> pinnedSha256 = const [],
  bool allowBadProxyCertificate = true,
  List<int>? clientCertificateBytes,
  List<int>? clientPrivateKeyBytes,
  String? clientCertificatePassword,
  String? dnsOverHttps,
  DnsLookup? dnsLookup,
  int? maxConnectionsPerHost,
  Duration? idleConnectionTimeout,
  Object? Function(Object client)? onHttpClientCreate,
}) {
  final proxyConfig = proxy == null ? null : parseProxyConfig(proxy);
  final matcher = pinnedSha256.isEmpty
      ? null
      : CertificatePinMatcher(pinnedSha256);
  final hasMtls =
      clientCertificateBytes != null || clientPrivateKeyBytes != null;
  final resolvedDns =
      dnsLookup ??
      (dnsOverHttps != null
          ? DnsOverHttpsResolver(endpoint: Uri.parse(dnsOverHttps)).resolve
          : null);

  if (proxyConfig == null &&
      matcher == null &&
      !hasMtls &&
      resolvedDns == null &&
      maxConnectionsPerHost == null &&
      idleConnectionTimeout == null &&
      onHttpClientCreate == null) {
    return null;
  }

  return () => _createConfiguredHttpClient(
    proxyConfig: proxyConfig,
    matcher: matcher,
    allowBadProxyCertificate: allowBadProxyCertificate,
    clientCertificateBytes: clientCertificateBytes,
    clientPrivateKeyBytes: clientPrivateKeyBytes,
    clientCertificatePassword: clientCertificatePassword,
    resolvedDns: resolvedDns,
    maxConnectionsPerHost: maxConnectionsPerHost,
    idleConnectionTimeout: idleConnectionTimeout,
    onHttpClientCreate: onHttpClientCreate,
  );
}

SecurityContext? _createSecurityContext({
  required CertificatePinMatcher? matcher,
  required List<int>? clientCertificateBytes,
  required List<int>? clientPrivateKeyBytes,
  required String? clientCertificatePassword,
}) {
  final hasMtls =
      clientCertificateBytes != null || clientPrivateKeyBytes != null;
  if (matcher == null && !hasMtls) return null;
  // When pinning is active, disable OS/user trusted roots so every TLS
  // certificate must pass SHA-256 verification.
  final ctx = SecurityContext(withTrustedRoots: matcher == null);
  if (clientCertificateBytes != null) {
    ctx.useCertificateChainBytes(
      clientCertificateBytes,
      password: clientCertificatePassword,
    );
  }
  if (clientPrivateKeyBytes != null) {
    ctx.usePrivateKeyBytes(
      clientPrivateKeyBytes,
      password: clientCertificatePassword,
    );
  }
  return ctx;
}

HttpClient _createConfiguredHttpClient({
  required ({String rule, Uri? uri})? proxyConfig,
  required CertificatePinMatcher? matcher,
  required bool allowBadProxyCertificate,
  required List<int>? clientCertificateBytes,
  required List<int>? clientPrivateKeyBytes,
  required String? clientCertificatePassword,
  required DnsLookup? resolvedDns,
  required int? maxConnectionsPerHost,
  required Duration? idleConnectionTimeout,
  required Object? Function(Object client)? onHttpClientCreate,
}) {
  final securityContext = _createSecurityContext(
    matcher: matcher,
    clientCertificateBytes: clientCertificateBytes,
    clientPrivateKeyBytes: clientPrivateKeyBytes,
    clientCertificatePassword: clientCertificatePassword,
  );
  final client = securityContext != null
      ? HttpClient(context: securityContext)
      : HttpClient();

  client.idleTimeout = idleConnectionTimeout ?? const Duration(seconds: 3);
  if (maxConnectionsPerHost != null) {
    client.maxConnectionsPerHost = maxConnectionsPerHost;
  }

  if (proxyConfig != null) {
    final rule = proxyConfig.rule;
    client.findProxy = (_) => rule;
  }

  bool Function(X509Certificate cert, String host, int port)? badCert;
  if (matcher != null) {
    badCert = (cert, _, _) => matcher.matchesDer(
      cert.der,
      startValidity: cert.startValidity,
      endValidity: cert.endValidity,
    );
  } else if (proxyConfig != null && allowBadProxyCertificate) {
    badCert = (_, _, _) => true;
  }
  if (badCert != null) {
    client.badCertificateCallback = badCert;
  }

  if (resolvedDns != null) {
    client.connectionFactory = (Uri url, String? proxyHost, int? proxyPort) {
      if (proxyHost != null) {
        return Socket.startConnect(proxyHost, proxyPort ?? 80);
      }
      final port = url.hasPort ? url.port : (url.scheme == 'https' ? 443 : 80);
      ConnectionTask<Socket>? tcpTask;
      var cancelled = false;
      Future<Socket> connect() async {
        Object connectHost = url.host;
        if (InternetAddress.tryParse(url.host) == null) {
          final ips = await resolvedDns(url.host);
          if (cancelled) {
            throw const SocketException('Connection attempt cancelled');
          }
          if (ips.isNotEmpty) {
            connectHost = InternetAddress.tryParse(ips.first) ?? ips.first;
          }
        }
        tcpTask = await Socket.startConnect(connectHost, port);
        if (cancelled) {
          tcpTask!.cancel();
          throw const SocketException('Connection attempt cancelled');
        }
        final socket = await tcpTask!.socket;
        if (url.scheme != 'https') return socket;
        final badCertCallback = badCert;
        return SecureSocket.secure(
          socket,
          host: url.host,
          context: securityContext,
          onBadCertificate: badCertCallback == null
              ? null
              : (cert) => badCertCallback(cert, url.host, port),
        );
      }

      return Future.value(
        ConnectionTask.fromSocket(connect(), () {
          cancelled = true;
          tcpTask?.cancel();
        }),
      );
    };
  }

  final custom = onHttpClientCreate?.call(client);
  return custom is HttpClient ? custom : client;
}

/// Builds a configured [HttpClientAdapter] for `dart:io` platforms.
HttpClientAdapter? buildConfiguredAdapter({
  String? proxy,
  List<String> pinnedSha256 = const [],
  bool allowBadProxyCertificate = true,
  List<int>? clientCertificateBytes,
  List<int>? clientPrivateKeyBytes,
  String? clientCertificatePassword,
  String? dnsOverHttps,
  DnsLookup? dnsLookup,
  int? maxConnectionsPerHost,
  Duration? idleConnectionTimeout,
  bool enableHttp2 = false,
  Object? Function(Object client)? onHttpClientCreate,
}) {
  final proxyConfig = proxy == null ? null : parseProxyConfig(proxy);
  final matcher = pinnedSha256.isEmpty
      ? null
      : CertificatePinMatcher(pinnedSha256);
  final resolvedDns =
      dnsLookup ??
      (dnsOverHttps != null
          ? DnsOverHttpsResolver(endpoint: Uri.parse(dnsOverHttps)).resolve
          : null);

  HttpClient createClient() => _createConfiguredHttpClient(
    proxyConfig: proxyConfig,
    matcher: matcher,
    allowBadProxyCertificate: allowBadProxyCertificate,
    clientCertificateBytes: clientCertificateBytes,
    clientPrivateKeyBytes: clientPrivateKeyBytes,
    clientCertificatePassword: clientCertificatePassword,
    resolvedDns: resolvedDns,
    maxConnectionsPerHost: maxConnectionsPerHost,
    idleConnectionTimeout: idleConnectionTimeout,
    onHttpClientCreate: onHttpClientCreate,
  );

  final ioAdapter = IOHttpClientAdapter(createHttpClient: createClient);

  if (!enableHttp2) {
    return ioAdapter;
  }

  final h2Adapter = Http2Adapter(
    ConnectionManager(
      idleTimeout: idleConnectionTimeout ?? const Duration(seconds: 15),
      supportedProtocols: const ['h2', 'http/1.1'],
      onClientCreate: (_, settings) {
        if (proxyConfig?.uri != null) {
          settings.proxy = proxyConfig!.uri;
        }
        final ctx = _createSecurityContext(
          matcher: matcher,
          clientCertificateBytes: clientCertificateBytes,
          clientPrivateKeyBytes: clientPrivateKeyBytes,
          clientCertificatePassword: clientCertificatePassword,
        );
        if (ctx != null) {
          settings.context = ctx;
        }
        if (matcher != null) {
          settings.onBadCertificate = (cert) => matcher.matchesDer(
            cert.der,
            startValidity: cert.startValidity,
            endValidity: cert.endValidity,
          );
        } else if (proxyConfig != null && allowBadProxyCertificate) {
          settings.onBadCertificate = (_) => true;
        }
      },
    ),
    fallbackAdapter: ioAdapter,
  );
  return _SchemeRoutingHttpAdapter(h2Adapter, ioAdapter);
}

final class _SchemeRoutingHttpAdapter implements HttpClientAdapter {
  _SchemeRoutingHttpAdapter(this._httpsAdapter, this._httpFallback);

  final Http2Adapter _httpsAdapter;
  final IOHttpClientAdapter _httpFallback;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.uri.scheme != 'https') {
      return _httpFallback.fetch(options, requestStream, cancelFuture);
    }
    return _httpsAdapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _httpsAdapter.close(force: force);
    _httpFallback.close(force: force);
  }
}

/// Classifies a [DioException] using underlying `dart:io` error types and OS
/// error codes when available.
ConnectionReason classifyDioError(DioException error) {
  if (error.type == DioExceptionType.badCertificate) {
    return ConnectionReason.sslMismatch;
  }
  final cause = error.error;
  if (cause is HandshakeException || cause is TlsException) {
    return ConnectionReason.sslMismatch;
  }
  if (cause is SocketException) {
    final code = cause.osError?.errorCode;
    final msg = '${cause.message} ${cause.osError?.message ?? ''}'
        .toLowerCase();
    if (msg.contains('failed host lookup') ||
        msg.contains('no address associated') ||
        msg.contains('nodename nor servname') ||
        msg.contains('name or service not known') ||
        code == 8 ||
        code == -2 ||
        code == -3 ||
        code == 11001) {
      return ConnectionReason.dnsFailed;
    }
    if (msg.contains('connection refused') ||
        code == 61 ||
        code == 111 ||
        code == 10061) {
      return ConnectionReason.connectionRefused;
    }
    if (msg.contains('network is unreachable') ||
        msg.contains('no route to host') ||
        msg.contains('network is down') ||
        msg.contains('software caused connection abort') ||
        code == 50 ||
        code == 51 ||
        code == 53 ||
        code == 64 ||
        code == 65 ||
        code == 100 ||
        code == 101 ||
        code == 102 ||
        code == 103) {
      return ConnectionReason.noInternet;
    }
    if (msg.contains('connection reset') ||
        msg.contains('broken pipe') ||
        code == 32 ||
        code == 54 ||
        code == 104 ||
        code == 10054) {
      return ConnectionReason.connectionReset;
    }
  }
  if (cause is HttpException) {
    final msg = cause.message.toLowerCase();
    if (msg.contains('connection closed') || msg.contains('reset')) {
      return ConnectionReason.connectionReset;
    }
  }
  final text = '${error.message ?? ''} ${cause ?? ''}'.toLowerCase();
  if (text.contains('certificate') ||
      text.contains('handshake') ||
      text.contains('tls') ||
      text.contains('ssl')) {
    return ConnectionReason.sslMismatch;
  }
  if (text.contains('connection refused')) {
    return ConnectionReason.connectionRefused;
  }
  if (text.contains('failed host lookup')) {
    return ConnectionReason.dnsFailed;
  }
  if (text.contains('connection reset')) {
    return ConnectionReason.connectionReset;
  }
  return ConnectionReason.unknown;
}
