import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

String _makeJwt(Map<String, Object?> payload) {
  String b64(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.sig';
}

OmniRawResponse _jsonResponse(
  Object? body, {
  int status = 200,
  Map<String, String> headers = const {},
  Uri? uri,
}) => OmniRawResponse(
  statusCode: status,
  headers: {'content-type': 'application/json', ...headers},
  bodyBytes: body == null ? Uint8List(0) : utf8.encode(jsonEncode(body)),
  requestUri: uri,
);

void main() {
  group('Tokens.fromJwt', () {
    test('extracts UTC exp claim and ignores malformed or missing exp', () {
      final expSec =
          DateTime.utc(2030, 5, 1, 12, 0).millisecondsSinceEpoch ~/ 1000;
      final jwt = _makeJwt({'sub': 'u1', 'exp': expSec});
      final tokens = Tokens.fromJwt(jwt, refresh: 'r1');
      expect(tokens.access, jwt);
      expect(tokens.refresh, 'r1');
      expect(tokens.expiresAt, DateTime.utc(2030, 5, 1, 12, 0));

      expect(Tokens.jwtExpiration(_makeJwt({'sub': 'u1'})), isNull);
      expect(Tokens.jwtExpiration('not-a-jwt'), isNull);
      expect(Tokens.jwtExpiration('a.!!!.c'), isNull);
    });

    test(
      'triggers proactive OmniAuth refresh when JWT is nearly expired',
      () async {
        var now = DateTime.utc(2026, 1, 1, 12, 0, 0);
        final soonExp =
            now.add(const Duration(seconds: 10)).millisecondsSinceEpoch ~/ 1000;
        final laterExp =
            now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;

        final storage = MemoryTokenStorage(
          Tokens.fromJwt(_makeJwt({'exp': soonExp}), refresh: 'r1'),
        );
        var refreshCalls = 0;
        final seenAuth = <String?>[];
        final mock = MockTransport((req) {
          seenAuth.add(req.headers['authorization']);
          return _jsonResponse({'ok': true});
        });

        final api = OmniNetwork(
          baseUrl: 'https://api.test',
          transport: mock,
          auth: OmniAuth(
            storage: storage,
            refreshBefore: const Duration(seconds: 30),
            now: () => now,
            refresh: (tokens, client) async {
              refreshCalls++;
              expect(tokens.refresh, 'r1');
              return Tokens.fromJwt(_makeJwt({'exp': laterExp}), refresh: 'r2');
            },
          ),
        );
        addTearDown(api.close);

        await api.get<Map<String, dynamic>>('/profile');
        expect(refreshCalls, 1);
        expect(seenAuth, hasLength(1));
        expect(seenAuth.single, startsWith('Bearer '));
        expect(storage.read()?.refresh, 'r2');
      },
    );
  });

  group('Auth providers (ApiKeyAuth, BasicAuth, HmacSignerAuth)', () {
    test('ApiKeyAuth attaches static or dynamic header key', () async {
      var key = 'secret-1';
      final headersSeen = <String?>[];
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((req) {
          headersSeen.add(req.headers['x-api-key']);
          return _jsonResponse({'ok': true});
        }),
        auth: ApiKeyAuth.provider(() async => key),
      );
      addTearDown(api.close);

      await api.get<Object?>('/one');
      key = 'secret-2';
      await api.get<Object?>('/two');

      expect(headersSeen, ['secret-1', 'secret-2']);
    });

    test('ApiKeyAuth inQuery mode attaches query param once', () async {
      final uris = <Uri>[];
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((req) {
          uris.add(req.uri);
          return _jsonResponse({'ok': true});
        }),
        auth: ApiKeyAuth('k123', inQuery: true, queryParam: 'key'),
      );
      addTearDown(api.close);

      await api.get<Object?>('/items');
      await api.get<Object?>('/items', query: {'key': 'override'});

      expect(uris[0].queryParameters['key'], 'k123');
      expect(uris[1].queryParameters['key'], 'override');
    });

    test(
      'BasicAuth encodes username:password in Authorization header',
      () async {
        String? header;
        final api = OmniNetwork(
          baseUrl: 'https://api.test',
          transport: MockTransport((req) {
            header = req.headers['authorization'];
            return _jsonResponse({'ok': true});
          }),
          auth: BasicAuth(username: 'alice', password: 'pw'),
        );
        addTearDown(api.close);

        await api.get<Object?>('/me');
        expect(header, 'Basic ${base64Encode(utf8.encode('alice:pw'))}');
      },
    );

    test('HmacSignerAuth signs canonical request string', () async {
      final fixed = DateTime.utc(2026, 2, 1, 0, 0, 5);
      final headersSeen = <Map<String, String>>[];
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((req) {
          headersSeen.add(req.headers);
          return _jsonResponse({'ok': true});
        }),
        auth: HmacSignerAuth(
          secret: 'my-secret',
          prefix: 'sha256=',
          now: () => fixed,
        ),
      );
      addTearDown(api.close);

      await api.post<Object?>('/orders', body: {'amount': 42});

      final ts = (fixed.millisecondsSinceEpoch ~/ 1000).toString();
      final canonical = '$ts\nPOST\n/orders\n{"amount":42}';
      final expectedHex = Hmac(
        sha256,
        utf8.encode('my-secret'),
      ).convert(utf8.encode(canonical)).toString();

      expect(headersSeen.single['x-timestamp'], ts);
      expect(headersSeen.single['x-signature'], 'sha256=$expectedHex');
    });
  });

  group('GraphQL client', () {
    test('sends query, variables, operationName and unwraps dataKey', () async {
      Map<String, Object?>? sentBody;
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((req) {
          sentBody = jsonDecode(utf8.decode(req.body!)) as Map<String, Object?>;
          return _jsonResponse({
            'data': {
              'user': {'name': 'Ada'},
            },
            'errors': <Object>[],
          });
        }),
      );
      addTearDown(api.close);

      final name = await api.graphql<String>(
        '/graphql',
        query: r'query GetUser($id: ID!) { user(id: $id) { name } }',
        variables: const {'id': '7'},
        operationName: 'GetUser',
        dataKey: 'user',
        decoder: (j) => j['name'] as String,
      );

      expect(name, 'Ada');
      expect(sentBody, {
        'query': r'query GetUser($id: ID!) { user(id: $id) { name } }',
        'variables': {'id': '7'},
        'operationName': 'GetUser',
      });
    });

    test('throws DecodeFailure on non-empty errors or missing data', () async {
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport(
          (_) => _jsonResponse({
            'data': null,
            'errors': [
              {'message': 'Unauthorized field'},
            ],
          }),
        ),
      );
      addTearDown(api.close);

      await expectLater(
        api.graphql<Object?>('/graphql', query: '{ secret }'),
        throwsA(
          isA<DecodeFailure>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized field'),
          ),
        ),
      );
    });
  });

  group('Metrics, slow request callback, logStream & MultiLogSink', () {
    test(
      'tracks requests, cache hits, revalidations and resets cleanly',
      () async {
        var call = 0;
        final api = OmniNetwork(
          baseUrl: 'https://api.test',
          cache: OmniCache(),
          transport: MockTransport((req) {
            call++;
            if (req.uri.path == '/fail') {
              return _jsonResponse({'err': true}, status: 500);
            }
            if (call == 1) {
              return _jsonResponse(
                {'v': 1},
                headers: {'etag': '"v1"', 'cache-control': 'max-age=60'},
              );
            }
            if (req.headers['if-none-match'] == '"v1"') {
              return OmniRawResponse(statusCode: 304);
            }
            return _jsonResponse({'v': 2});
          }),
        );
        addTearDown(api.close);

        // 1. Network fetch (caches with ETag).
        await api.get<Object?>('/item');
        // 2. Cache hit (cacheFirst / maxAge still valid).
        await api.get<Object?>('/item', cache: CachePolicy.cacheFirst);
        // 3. Revalidation (304 Not Modified via CachePolicy.refresh).
        await api.get<Object?>('/item', cache: CachePolicy.refresh);
        // 4. Failure (HTTP 500).
        await expectLater(
          api.get<Object?>('/fail'),
          throwsA(isA<HttpFailure>()),
        );

        final m = api.metrics;
        expect(m.totalRequests, 4);
        expect(m.successCount, 3);
        expect(m.failureCount, 1);
        expect(m.cacheHits, 1);
        expect(m.revalidatedCount, 1);
        expect(m.activeRequests, 0);
        expect(m.cacheHitRate, closeTo(0.5, 0.001));
        expect(m.lastLatency, isNotNull);

        api.resetMetrics();
        final reset = api.metrics;
        expect(reset.totalRequests, 0);
        expect(reset.successCount, 0);
        expect(reset.failureCount, 0);
        expect(reset.cacheHits, 0);
      },
    );

    test('onSlowRequest fires when elapsed >= slowRequestThreshold', () async {
      final slowCalls = <(Uri, Duration)>[];
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        slowRequestThreshold: const Duration(milliseconds: 15),
        onSlowRequest: (uri, elapsed) {
          slowCalls.add((uri, elapsed));
          throw StateError('ignored callback failure');
        },
        transport: MockTransport((req) async {
          if (req.uri.path == '/slow') {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          return _jsonResponse({'ok': true});
        }),
      );
      addTearDown(api.close);

      await api.get<Object?>('/fast');
      await api.get<Object?>('/slow');

      expect(slowCalls, hasLength(1));
      expect(slowCalls.single.$1.path, '/slow');
      expect(
        slowCalls.single.$2,
        greaterThanOrEqualTo(const Duration(milliseconds: 15)),
      );
    });

    test(
      'logStream and MultiLogSink isolate exceptions and deliver records',
      () async {
        final sinkA = <NetworkLogRecord>[];
        final sinkB = <NetworkLogRecord>[];
        final streamRecords = <NetworkLogRecord>[];

        final multi = MultiLogSink([
          _FnSink((r) {
            sinkA.add(r);
            throw StateError('boom');
          }),
          _FnSink(sinkB.add),
        ]);

        final api = OmniNetwork(
          baseUrl: 'https://api.test',
          enableLogging: true,
          logInRelease: true,
          logSink: multi,
          transport: MockTransport((_) => _jsonResponse({'ok': true})),
        );
        final sub = api.logStream.listen(streamRecords.add);

        await api.get<Object?>('/ping');
        await Future<void>.delayed(Duration.zero);
        await api.close();
        await sub.cancel();

        expect(sinkA.length, 2); // request + response
        expect(sinkB.length, 2);
        expect(streamRecords.length, 2);
      },
    );
  });

  group('OmniPager.changes stream', () {
    test('emits on next, refresh and reset', () async {
      var page = 0;
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((_) {
          page++;
          return _jsonResponse(
            page == 1
                ? [
                    {'id': 1},
                  ]
                : <Object>[],
          );
        }),
      );
      addTearDown(api.close);

      final pager = api.paginate<int>(
        '/items',
        decoder: (j) => j['id'] as int,
        strategy: const PagePagination(pageSize: 1),
      );
      addTearDown(pager.close);

      var notifications = 0;
      final sub = pager.changes.listen((_) => notifications++);

      await pager.next();
      await pager.refresh();
      pager.reset();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(notifications, greaterThanOrEqualTo(3));
    });
  });

  group('RecordingTransport', () {
    test('records redacted fixtures and replays offline from JSON', () async {
      final inner = MockTransport((req) {
        return _jsonResponse(
          {
            'items': [1, 2],
          },
          headers: {'set-cookie': 'session=secret', 'x-ok': 'yes'},
        );
      });
      final recorder = RecordingTransport(inner);
      final api = OmniNetwork(baseUrl: 'https://api.test', transport: recorder);
      addTearDown(api.close);

      await api.get<Object?>('/feed', query: {'api_key': 'secret', 'p': '1'});

      expect(recorder.exchanges, hasLength(1));
      final recorded = recorder.exchanges.single;
      expect(recorded.url, contains('api_key=***'));
      expect(recorded.headers['set-cookie'], '***');
      expect(recorded.headers['x-ok'], 'yes');

      final exported =
          jsonDecode(jsonEncode(recorder.toJson())) as List<Object?>;
      final replayApi = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: RecordingTransport.replayJson(exported),
      );
      addTearDown(replayApi.close);

      final replayed = await replayApi.get<Map<String, dynamic>>(
        '/feed',
        query: {'p': '9'},
      );
      expect(replayed['items'], [1, 2]);
    });
  });

  group('DnsOverHttpsResolver & BytesTarget SHA-256', () {
    test('caches resolved A/AAAA IPs by TTL and honors clearCache', () async {
      var now = DateTime.utc(2026, 1, 1, 0, 0, 0);
      var fetches = 0;
      final doh = DnsOverHttpsResolver(
        now: () => now,
        fetchJson: (_) async {
          fetches++;
          return {
            'Answer': [
              {'type': 1, 'TTL': 10, 'data': '93.184.216.34'},
              {'type': 5, 'TTL': 10, 'data': 'cname.ignored.'},
            ],
          };
        },
      );

      expect(await doh.resolve('Example.COM'), ['93.184.216.34']);
      expect(await doh.resolve('example.com'), ['93.184.216.34']);
      expect(fetches, 1);

      now = now.add(const Duration(seconds: 15));
      expect(await doh.resolve('example.com'), ['93.184.216.34']);
      expect(fetches, 2);

      doh.clearCache();
      expect(await doh.resolve('example.com'), ['93.184.216.34']);
      expect(fetches, 3);
    });

    test(
      'downloadBytes verifies expectedSha256 and throws on mismatch',
      () async {
        final payload = utf8.encode('verified-binary-content');
        final digestHex = sha256.convert(payload).toString();
        final api = OmniNetwork(
          baseUrl: 'https://api.test',
          transport: MockTransport(
            (_) => OmniRawResponse(
              statusCode: 200,
              bodyBytes: Uint8List.fromList(payload),
            ),
          ),
        );
        addTearDown(api.close);

        final ok = await api.downloadBytes(
          '/file.bin',
          expectedSha256: 'sha256:${digestHex.toUpperCase()}',
        );
        expect(ok, payload);

        await expectLater(
          api.downloadBytes('/file.bin', expectedSha256: '0' * 64),
          throwsA(isA<DecodeFailure>()),
        );
      },
    );
  });
}

final class _FnSink implements LogSink {
  _FnSink(this.fn);
  final void Function(NetworkLogRecord) fn;
  @override
  void log(NetworkLogRecord record) => fn(record);
}
