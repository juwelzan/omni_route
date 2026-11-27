@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:omni_network/advanced.dart';
import 'package:omni_network/src/transport/dio_io_io.dart'
    show classifyDioError, parseProxyConfig;
import 'package:test/test.dart';

final class _Person {
  _Person(this.id, this.name);
  factory _Person.fromJson(Map<String, dynamic> json) =>
      _Person(json['id'] as int, json['name'] as String);
  final int id;
  final String name;
}

final class _ProgressSpyTransport implements ProgressReportingTransport {
  final List<(int, int?)> reported = [];

  @override
  Future<OmniRawResponse> send(
    TransportRequest request,
    CancelSignal cancel,
  ) async {
    final open = request.bodyStream;
    var totalRead = 0;
    if (open != null) {
      await for (final chunk in open()) {
        totalRead += chunk.length;
      }
    }
    request.onSendProgress?.call(totalRead ~/ 2, totalRead);
    reported.add((totalRead ~/ 2, totalRead));
    request.onSendProgress?.call(totalRead, totalRead);
    reported.add((totalRead, totalRead));
    return OmniRawResponse(
      statusCode: 200,
      headers: {'content-type': 'application/json'},
      bodyBytes: utf8.encode('{"ok":true}'),
    );
  }

  @override
  Future<StreamedResponse> sendStreamed(
    TransportRequest request,
    CancelSignal cancel,
  ) => throw UnimplementedError();

  @override
  Future<void> close({bool force = false}) async {}
}

final class _CountingHttpAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{"adapter":"custom"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SSL Certificate Pinning (pinnedSha256)', () {
    late Directory certDir;
    late String certPath;
    late String keyPath;
    late String leafBase64Pin;
    late String leafHexPin;
    late String spkiBase64Pin;
    late HttpServer httpsServer;

    setUpAll(() async {
      certDir = await Directory.systemTemp.createTemp('omni_tls_');
      certPath = '${certDir.path}/cert.pem';
      keyPath = '${certDir.path}/key.pem';

      final gen = await Process.run('openssl', [
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-keyout',
        keyPath,
        '-out',
        certPath,
        '-days',
        '2',
        '-nodes',
        '-subj',
        '/CN=localhost',
      ]);
      expect(gen.exitCode, 0, reason: '${gen.stderr}');

      // Compute full leaf certificate DER SHA-256 (base64 and colon-hex).
      final certDerB64 = await Process.run('sh', [
        '-c',
        'openssl x509 -in "$certPath" -outform DER '
            '| openssl dgst -sha256 -binary | openssl base64 -A',
      ]);
      expect(certDerB64.exitCode, 0);
      leafBase64Pin = 'sha256/${(certDerB64.stdout as String).trim()}';

      final certDerHex = await Process.run('sh', [
        '-c',
        'openssl x509 -in "$certPath" -outform DER '
            '| openssl dgst -sha256 -r | cut -d" " -f1',
      ]);
      expect(certDerHex.exitCode, 0);
      final hex = (certDerHex.stdout as String).trim();
      leafHexPin = [
        for (var i = 0; i < hex.length; i += 2)
          hex.substring(i, i + 2).toUpperCase(),
      ].join(':');

      // Compute X.509 SPKI public-key DER SHA-256 (base64).
      final spkiB64 = await Process.run('sh', [
        '-c',
        'openssl x509 -in "$certPath" -pubkey -noout '
            '| openssl pkey -pubin -outform DER '
            '| openssl dgst -sha256 -binary | openssl base64 -A',
      ]);
      expect(spkiB64.exitCode, 0);
      spkiBase64Pin = 'sha256/${(spkiB64.stdout as String).trim()}';

      final context = SecurityContext()
        ..useCertificateChain(certPath)
        ..usePrivateKey(keyPath);
      httpsServer = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      httpsServer.listen((req) async {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"secure":true}');
        await req.response.close();
      });
    });

    tearDownAll(() async {
      await httpsServer.close(force: true);
      await certDir.delete(recursive: true);
    });

    test('accepts matching sha256/<base64> leaf pin', () async {
      final api = OmniNetwork(
        baseUrl: 'https://127.0.0.1:${httpsServer.port}',
        pinnedSha256: [leafBase64Pin],
      );
      addTearDown(api.close);

      final data = await api.get<Map<String, dynamic>>('/ping');
      expect(data['secure'], isTrue);
    });

    test('accepts matching colon-hex leaf pin', () async {
      final api = OmniNetwork(
        baseUrl: 'https://127.0.0.1:${httpsServer.port}',
        pinnedSha256: [leafHexPin],
      );
      addTearDown(api.close);

      final data = await api.get<Map<String, dynamic>>('/ping');
      expect(data['secure'], isTrue);
    });

    test('accepts matching SPKI public-key sha256 pin', () async {
      final api = OmniNetwork(
        baseUrl: 'https://127.0.0.1:${httpsServer.port}',
        pinnedSha256: [spkiBase64Pin],
      );
      addTearDown(api.close);

      final data = await api.get<Map<String, dynamic>>('/ping');
      expect(data['secure'], isTrue);
    });

    test('rejects mismatched SHA-256 pin with ConnectionReason.sslMismatch',
        () async {
      final wrongPin = 'sha256/${base64Encode(List<int>.filled(32, 0xAB))}';
      final api = OmniNetwork(
        baseUrl: 'https://127.0.0.1:${httpsServer.port}',
        pinnedSha256: [wrongPin],
      );
      addTearDown(api.close);

      await expectLater(
        api.get<Map<String, dynamic>>('/ping'),
        throwsA(
          isA<ConnectionFailure>().having(
            (e) => e.reason,
            'reason',
            ConnectionReason.sslMismatch,
          ),
        ),
      );
    });

    test('HTTP/2 adapter also enforces pinnedSha256 (pass and fail)',
        () async {
      final okClient = OmniNetwork(
        baseUrl: 'https://127.0.0.1:${httpsServer.port}',
        enableHttp2: true,
        pinnedSha256: [spkiBase64Pin],
      );
      addTearDown(okClient.close);
      expect((await okClient.get<Map<String, dynamic>>('/ping'))['secure'],
          isTrue);

      final wrongPin = 'sha256/${base64Encode(List<int>.filled(32, 0xCD))}';
      final badClient = OmniNetwork(
        baseUrl: 'https://127.0.0.1:${httpsServer.port}',
        enableHttp2: true,
        pinnedSha256: [wrongPin],
      );
      addTearDown(badClient.close);

      await expectLater(
        badClient.get<Map<String, dynamic>>('/ping'),
        throwsA(
          isA<ConnectionFailure>().having(
            (e) => e.reason,
            'reason',
            ConnectionReason.sslMismatch,
          ),
        ),
      );
    });
  });

  group('Proxy routing and release guard', () {
    test('routes traffic through configured proxy and bypasses in release',
        () async {
      final targetHits = <String>[];
      final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => target.close(force: true));
      target.listen((req) async {
        targetHits.add(req.uri.path);
        req.response
          ..headers.contentType = ContentType.json
          ..write('{"via":"direct"}');
        await req.response.close();
      });

      final proxyHits = <String>[];
      final proxyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => proxyServer.close(force: true));
      proxyServer.listen((req) async {
        proxyHits.add(req.uri.toString());
        req.response
          ..headers.contentType = ContentType.json
          ..write('{"via":"proxy"}');
        await req.response.close();
      });

      final api = OmniNetwork(
        baseUrl: 'http://127.0.0.1:${target.port}',
        proxy: '127.0.0.1:${proxyServer.port}',
      );
      addTearDown(api.close);

      final viaProxy = await api.get<Map<String, dynamic>>('/hello');
      expect(viaProxy['via'], 'proxy');
      expect(proxyHits.single, endsWith('/hello'));
      expect(targetHits, isEmpty);

      // In release mode, proxy is ignored automatically unless opted in.
      final wasRelease = OmniNetwork.isReleaseBuild;
      OmniNetwork.isReleaseBuild = true;
      addTearDown(() => OmniNetwork.isReleaseBuild = wasRelease);

      final releaseClient = OmniNetwork(
        baseUrl: 'http://127.0.0.1:${target.port}',
        proxy: '127.0.0.1:${proxyServer.port}',
      );
      addTearDown(releaseClient.close);

      final viaDirect = await releaseClient.get<Map<String, dynamic>>('/live');
      expect(viaDirect['via'], 'direct');
      expect(targetHits, ['/live']);

      final releaseWithOptIn = OmniNetwork(
        baseUrl: 'http://127.0.0.1:${target.port}',
        proxy: '127.0.0.1:${proxyServer.port}',
        allowProxyInRelease: true,
      );
      addTearDown(releaseWithOptIn.close);

      final viaOptInProxy = await releaseWithOptIn.get<Map<String, dynamic>>(
        '/forced',
      );
      expect(viaOptInProxy['via'], 'proxy');
      expect(proxyHits, hasLength(2));
    });

    test('parseProxyConfig normalizes host:port, PROXY prefix, and URLs', () {
      expect(
        parseProxyConfig('192.168.0.105:8888').rule,
        'PROXY 192.168.0.105:8888',
      );
      expect(
        parseProxyConfig('PROXY 10.0.0.2:3128').rule,
        'PROXY 10.0.0.2:3128',
      );
      expect(
        parseProxyConfig('http://localhost:9000').rule,
        'PROXY localhost:9000',
      );
      expect(parseProxyConfig('DIRECT').rule, 'DIRECT');
      expect(() => parseProxyConfig('invalid-no-port'), throwsArgumentError);
    });
  });

  group('Timeouts, Error Reasons, HTTP/2 & Custom Adapter', () {
    test('receiveTimeout triggers TimeoutFailure with TimeoutStage.receive',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final pending = <HttpRequest>[];
      addTearDown(() async {
        for (final r in pending) {
          await r.response.close().catchError((_) {});
        }
      });
      server.listen((req) {
        pending.add(req);
      });

      final api = OmniNetwork(
        baseUrl: 'http://127.0.0.1:${server.port}',
        timeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(milliseconds: 60),
      );
      addTearDown(api.close);

      await expectLater(
        api.get<void>('/slow'),
        throwsA(
          isA<TimeoutFailure>().having(
            (e) => e.stage,
            'stage',
            TimeoutStage.receive,
          ),
        ),
      );
    });

    test('unreachable loopback reports ConnectionReason.connectionRefused',
        () async {
      final temp = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = temp.port;
      await temp.close(force: true);

      final api = OmniNetwork(baseUrl: 'http://127.0.0.1:$deadPort');
      addTearDown(api.close);

      await expectLater(
        api.get<void>('/down'),
        throwsA(
          isA<ConnectionFailure>().having(
            (e) => e.reason,
            'reason',
            ConnectionReason.connectionRefused,
          ),
        ),
      );
    });

    test('classifyDioError accurately maps SocketException / TLS / badCert',
        () {
      final opts = RequestOptions(path: '/x');

      expect(
        classifyDioError(DioException.badCertificate(requestOptions: opts)),
        ConnectionReason.sslMismatch,
      );
      expect(
        classifyDioError(
          DioException.connectionError(
            requestOptions: opts,
            reason: 'tls',
            error: const HandshakeException('bad cert'),
          ),
        ),
        ConnectionReason.sslMismatch,
      );
      expect(
        classifyDioError(
          DioException.connectionError(
            requestOptions: opts,
            reason: 'dns',
            error: const SocketException('Failed host lookup: api.invalid'),
          ),
        ),
        ConnectionReason.dnsFailed,
      );
      expect(
        classifyDioError(
          DioException.connectionError(
            requestOptions: opts,
            reason: 'offline',
            error: const SocketException(
              'Network is unreachable',
              osError: OSError('Network is unreachable', 51),
            ),
          ),
        ),
        ConnectionReason.noInternet,
      );
      expect(
        classifyDioError(
          DioException.connectionError(
            requestOptions: opts,
            reason: 'reset',
            error: const SocketException(
              'Connection reset by peer',
              osError: OSError('Connection reset by peer', 54),
            ),
          ),
        ),
        ConnectionReason.connectionReset,
      );
    });

    test('enableHttp2 and custom httpClientAdapter work cleanly', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        req.response
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}');
        await req.response.close();
      });

      final h2 = OmniNetwork(
        baseUrl: 'http://127.0.0.1:${server.port}',
        enableHttp2: true,
      );
      addTearDown(h2.close);
      expect((await h2.get<Map<String, dynamic>>('/h2'))['ok'], isTrue);

      final customAdapter = _CountingHttpAdapter();
      final client = OmniNetwork(
        baseUrl: 'https://custom.local',
        transport: DioTransport.configured(httpClientAdapter: customAdapter),
      );
      addTearDown(client.close);
      final res = await client.get<Map<String, dynamic>>('/ping');
      expect(res['adapter'], 'custom');
      expect(customAdapter.calls, 1);
    });
  });

  group('OmniNetwork.fromDio', () {
    test('preserves baseUrl, headers, Dio interceptors, and adds Omni features',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var hits = 0;
      server.listen((req) async {
        hits++;
        req.response
          ..headers.contentType = ContentType.json
          ..headers.set('cache-control', 'max-age=60')
          ..write(
            jsonEncode({
              'id': 7,
              'name': '${req.headers.value('x-legacy')}:${req.headers.value('x-dio-int')}',
            }),
          );
        await req.response.close();
      });

      final oldDio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:${server.port}',
          headers: {'x-legacy': 'yes'},
          connectTimeout: const Duration(seconds: 4),
        ),
      );
      oldDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['x-dio-int'] = 'ran';
            handler.next(options);
          },
        ),
      );

      final api = OmniNetwork.fromDio(
        oldDio,
        cache: OmniCache(),
        decoders: {_Person: _Person.fromJson},
      );

      final p1 = await api.get<_Person>('/me');
      final p2 = await api.get<_Person>('/me'); // served from OmniCache!
      expect((p1.id, p1.name), (7, 'yes:ran'));
      expect((p2.id, p2.name), (7, 'yes:ran'));
      expect(hits, 1);

      // Closing without closeDio: true leaves oldDio working cleanly.
      await api.close();
      final directRes = await oldDio.get<Map<String, dynamic>>('/still-open');
      expect(directRes.statusCode, 200);
      oldDio.close(force: true);
    });
  });

  group('UploadFile.fromFile & Wire Progress', () {
    test('reads filename, length, MIME type and streams uploads cleanly',
        () async {
      final dir = await Directory.systemTemp.createTemp('omni_upload_');
      addTearDown(() => dir.delete(recursive: true));

      final photoPath = '${dir.path}/avatar.jpg';
      final pdfPath = '${dir.path}/invoice.pdf';
      final unknownPath = '${dir.path}/blob.xyz';
      final bytes = Uint8List.fromList(List.generate(32768, (i) => i % 251));
      await File(photoPath).writeAsBytes(bytes);
      await File(pdfPath).writeAsString('%PDF-1.4');
      await File(unknownPath).writeAsBytes([1, 2, 3]);

      final f1 = await UploadFile.fromFile('avatar', photoPath);
      expect(f1.filename, 'avatar.jpg');
      expect(f1.contentType, 'image/jpeg');
      expect(f1.length, bytes.length);

      final f2 = await UploadFile.fromFile('doc', pdfPath);
      expect(f2.contentType, 'application/pdf');

      final f3 = await UploadFile.fromFile(
        'bin',
        unknownPath,
        filename: 'override.bin',
      );
      expect(f3.filename, 'override.bin');
      expect(f3.contentType, 'application/octet-stream');

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      late String bodyText;
      server.listen((req) async {
        final raw = (await req.toList()).expand((c) => c).toList();
        bodyText = utf8.decode(raw, allowMalformed: true);
        req.response
          ..headers.contentType = ContentType.json
          ..write('{"id":42,"name":"Uploaded"}');
        await req.response.close();
      });

      final api = OmniNetwork(
        baseUrl: 'http://127.0.0.1:${server.port}',
        decoders: {_Person: _Person.fromJson},
      );
      addTearDown(api.close);

      final progress = <(int, int?)>[];
      final person = await api.upload<_Person>(
        '/up',
        files: [f1],
        onProgress: (sent, total) => progress.add((sent, total)),
      );
      expect((person.id, person.name), (42, 'Uploaded'));
      expect(progress, isNotEmpty);
      expect(progress.last.$1, progress.last.$2);
      expect(bodyText, contains('filename="avatar.jpg"'));
      expect(bodyText, contains('content-type: image/jpeg'));
    });

    test('ProgressReportingTransport receives wire onSendProgress from core',
        () async {
      final spy = _ProgressSpyTransport();
      final api = OmniNetwork(baseUrl: 'https://example.test', transport: spy);
      addTearDown(api.close);

      final received = <(int, int?)>[];
      await api.upload<Map<String, dynamic>>(
        '/up',
        files: [UploadFile.fromBytes('f', [1, 2, 3, 4], filename: 'a.bin')],
        onProgress: (s, t) => received.add((s, t)),
      );

      expect(spy.reported, isNotEmpty);
      expect(received, spy.reported);
    });
  });

  group('FileCacheStore (Persistent Disk Cache)', () {
    test('persists cached responses across client instances offline and evicts LRU',
        () async {
      final dir = await Directory.systemTemp.createTemp('omni_disk_cache_');
      addTearDown(() => dir.delete(recursive: true));

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      var hits = 0;
      server.listen((req) async {
        hits++;
        req.response
          ..headers.contentType = ContentType.json
          ..headers.set('cache-control', 'max-age=300')
          ..write(jsonEncode({'id': hits, 'name': req.uri.path}));
        await req.response.close();
      });

      final client1 = OmniNetwork(
        baseUrl: 'http://127.0.0.1:$port',
        cache: OmniCache(
          store: FileCacheStore(directory: dir.path, maxEntries: 2),
          policy: CachePolicy.networkFirst,
        ),
        decoders: {_Person: _Person.fromJson},
      );

      final live = await client1.get<_Person>('/profile');
      expect((live.id, live.name), (1, '/profile'));
      expect(hits, 1);
      await client1.close();

      // Shut down the server completely so client2 is offline.
      await server.close(force: true);

      final client2 = OmniNetwork(
        baseUrl: 'http://127.0.0.1:$port',
        cache: OmniCache(
          store: FileCacheStore(directory: dir.path, maxEntries: 2),
          policy: CachePolicy.networkFirst,
        ),
        decoders: {_Person: _Person.fromJson},
      );
      addTearDown(client2.close);

      final cachedOffline = await client2.get<_Person>('/profile');
      expect((cachedOffline.id, cachedOffline.name), (1, '/profile'));

      // Check direct store eviction at maxEntries: 2.
      final store = FileCacheStore(directory: dir.path, maxEntries: 2);
      final now = DateTime.now();
      for (final k in ['k1', 'k2', 'k3']) {
        await store.set(
          k,
          CacheEntry(
            url: 'https://example.test/$k',
            statusCode: 200,
            headers: const {'content-type': 'application/json'},
            body: Uint8List.fromList([1, 2, 3]),
            storedAt: now,
            expiresAt: now.add(const Duration(minutes: 5)),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.omc'))
          .toList();
      expect(files, hasLength(2));

      await store.clear();
      expect(dir.listSync(), isEmpty);
    });
  });
}
