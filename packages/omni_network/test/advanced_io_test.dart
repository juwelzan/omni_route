@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('omni_adv_io_');
  });

  tearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  group('FileQueueStore', () {
    test('persists FIFO requests atomically across store restarts', () async {
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((_) => throw const ConnectionFailure('offline')),
      );
      addTearDown(api.close);

      final store1 = FileQueueStore(directory: dir.path);
      final q1 = OfflineQueue(client: api, store: store1);
      final req1 = await q1.enqueue(
        const OmniRequest.post('/a', body: {'n': 1}),
      );
      await q1.enqueue(
        const OmniRequest.put('/b', body: {'n': 2}),
        allowDestructive: true,
      );
      await store1.add(req1); // duplicate ignored
      await q1.close();

      // New instance reads saved queue.json from disk.
      final store2 = FileQueueStore(directory: dir.path);
      final restored = await store2.all();
      expect(restored.map((e) => e.path), ['/a', '/b']);

      // Simulate one failed replay attempt via OfflineQueue using persisted store2.
      final q2 = OfflineQueue(client: api, store: store2);
      await q2.flush();
      expect((await store2.all()).first.attempts, 1);
      await q2.close();

      await store2.remove(req1.id);
      expect((await FileQueueStore(directory: dir.path).all()).map((e) => e.path), [
        '/b',
      ]);
    });
  });

  group('Gzip request compression (compress: true)', () {
    test('sends Content-Encoding: gzip and valid gzip payload over wire', () async {
      String? seenEncoding;
      List<int> seenRaw = const [];

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        seenEncoding = req.headers.value('content-encoding');
        seenRaw = (await req.toList()).expand((c) => c).toList();
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}');
        await req.response.close();
      });

      final api = OmniNetwork(
        baseUrl: 'http://127.0.0.1:${server.port}',
      );
      addTearDown(api.close);

      final res = await api.post<Map<String, dynamic>>(
        '/events',
        compress: true,
        body: {'events': List.filled(20, 'payload-item')},
      );

      expect(res['ok'], isTrue);
      expect(seenEncoding, 'gzip');
      final decodedJson = jsonDecode(utf8.decode(gzip.decode(seenRaw)))
          as Map<String, Object?>;
      expect((decodedJson['events']! as List).length, 20);
    });
  });

  group('Resumable download If-Range + expectedSha256', () {
    test('restarts full download when ETag changes and validates SHA-256', () async {
      final serverBytes = Uint8List.fromList(List.generate(256, (i) => i % 251));
      final serverDigest = sha256.convert(serverBytes).toString();
      final seenIfRanges = <String?>[];
      var serverEtag = '"v2"';

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        await req.drain<void>();
        final ifRange = req.headers.value('if-range');
        final range = req.headers.value('range');
        seenIfRanges.add(ifRange);
        req.response.headers.set('etag', serverEtag);
        if (range != null && ifRange == serverEtag) {
          final start = int.parse(range.substring(6, range.length - 1));
          req.response.statusCode = 206;
          req.response.headers.contentLength = serverBytes.length - start;
          req.response.add(serverBytes.sublist(start));
        } else {
          req.response.statusCode = 200;
          req.response.headers.contentLength = serverBytes.length;
          req.response.add(serverBytes);
        }
        await req.response.close();
      });

      final dest = '${dir.path}/asset.bin';
      final part = File('$dest.part');
      final meta = File('$dest.part.meta');
      await part.writeAsBytes(List.filled(64, 0));
      await meta.writeAsString('"v1"'); // stale validator triggers 200 restart!

      final api = OmniNetwork(baseUrl: 'http://127.0.0.1:${server.port}');
      addTearDown(api.close);

      await api.downloadToFile(
        '/asset.bin',
        dest,
        resume: true,
        expectedSha256: serverDigest,
      );

      expect(seenIfRanges, ['"v1"']);
      expect(await File(dest).readAsBytes(), serverBytes);
      expect(await part.exists(), isFalse);
      expect(await meta.exists(), isFalse);

      // Resuming with matching ETag sends 206 partial and completes SHA-256.
      await File(dest).delete();
      await part.writeAsBytes(serverBytes.sublist(0, 100));
      await meta.writeAsString('"v2"');

      await api.downloadToFile(
        '/asset.bin',
        dest,
        resume: true,
        expectedSha256: serverDigest,
      );
      expect(seenIfRanges, ['"v1"', '"v2"']);
      expect(await File(dest).readAsBytes(), serverBytes);

      // Wrong SHA-256 fails cleanly.
      await File(dest).delete();
      await expectLater(
        api.downloadToFile(
          '/asset.bin',
          dest,
          resume: false,
          expectedSha256: 'f' * 64,
        ),
        throwsA(isA<DecodeFailure>()),
      );
    });
  });

  group('Custom DNS lookup & live DoH HTTP query', () {
    test('dnsLookup routes unresolvable hostname to loopback HttpServer', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        await req.drain<void>();
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"host":"${req.headers.host}"}');
        await req.response.close();
      });

      final lookedUp = <String>[];
      final api = OmniNetwork(
        baseUrl: 'http://fake.omni.invalid:${server.port}',
        dnsLookup: (host) async {
          lookedUp.add(host);
          return ['127.0.0.1'];
        },
      );
      addTearDown(api.close);

      final res = await api.get<Map<String, dynamic>>('/ping');
      expect(lookedUp, ['fake.omni.invalid']);
      expect(res['host'], startsWith('fake.omni.invalid'));
    });

    test('DnsOverHttpsResolver queries live HTTP JSON endpoint', () async {
      final dohServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => dohServer.close(force: true));
      dohServer.listen((req) async {
        await req.drain<void>();
        expect(req.uri.queryParameters['name'], 'service.internal');
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'Answer': [
                {'type': 1, 'TTL': 30, 'data': '127.0.0.1'},
              ],
            }),
          );
        await req.response.close();
      });

      final resolver = DnsOverHttpsResolver(
        endpoint: Uri.parse('http://127.0.0.1:${dohServer.port}/dns-query'),
      );
      expect(await resolver.resolve('service.internal'), ['127.0.0.1']);
    });
  });
}
