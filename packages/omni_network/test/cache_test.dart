import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late MockTransport mock;
  late OmniCache cache;
  late OmniNetwork api;
  late int version;
  late Map<String, String> headers;

  OmniRawResponse serve(TransportRequest r) {
    final etag = '"v$version"';
    if (r.headers['if-none-match'] == etag) {
      return OmniRawResponse(
        statusCode: 304,
        headers: {'etag': etag, ...headers},
      );
    }
    return OmniRawResponse(
      statusCode: 200,
      headers: {'content-type': 'application/json', 'etag': etag, ...headers},
      bodyBytes: utf8.encode(jsonEncode({'v': version, 'path': r.uri.path})),
    );
  }

  OmniNetwork client({
    CachePolicy policy = CachePolicy.standard,
    bool authed = false,
    String? Function()? scope,
  }) {
    cache = OmniCache(
      policy: policy,
      now: () => now,
      cacheAuthenticated: authed,
      authScope: scope,
    );
    return api = OmniNetwork(
      baseUrl: 'https://h.io',
      transport: mock,
      cache: cache,
    );
  }

  setUp(() {
    now = DateTime(2026, 1, 1);
    version = 1;
    headers = {'cache-control': 'max-age=60'};
    mock = MockTransport(serve);
  });
  tearDown(() => api.close());

  Future<(Object?, ResponseSource)> get(
    String path, {
    CachePolicy? policy,
    Map<String, String> h = const {},
  }) async {
    final r = await api.sendRaw(
      OmniRequest.get(path, cachePolicy: policy, headers: h),
    );
    return (r.json, r.source);
  }

  Future<(String, ResponseSource)> getText(String path) async {
    final (json, source) = await get(path);
    return (jsonEncode(json), source);
  }

  group('standard (HTTP semantics)', () {
    test('fresh entry served without network', () async {
      client();
      expect(await getText('/a'), (
        '{"v":1,"path":"/a"}',
        ResponseSource.network,
      ));
      version = 2;
      expect(await getText('/a'), (
        '{"v":1,"path":"/a"}',
        ResponseSource.cache,
      ));
      expect(mock.requests, hasLength(1));
    });

    test('stale entry revalidated with ETag: 304 keeps body', () async {
      client();
      await get('/a');
      now = now.add(const Duration(seconds: 61));
      final (json, source) = await get('/a');
      expect(source, ResponseSource.revalidated);
      expect(json, {'v': 1, 'path': '/a'});
      expect(mock.requests.last.headers['if-none-match'], '"v1"');
      // 304 refreshed freshness: next call is a pure cache hit.
      expect((await get('/a')).$2, ResponseSource.cache);
      expect(mock.requests, hasLength(2));
    });

    test('changed resource: 200 replaces the entry', () async {
      client();
      await get('/a');
      now = now.add(const Duration(minutes: 2));
      version = 2;
      expect(await getText('/a'), (
        '{"v":2,"path":"/a"}',
        ResponseSource.network,
      ));
      expect((await get('/a')).$1, {'v': 2, 'path': '/a'});
    });

    test('Last-Modified validator', () async {
      headers = {
        'cache-control': 'max-age=0',
        'last-modified': 'Wed, 21 Oct 2015 07:28:00 GMT',
      };
      mock.handler = (r) => r.headers['if-modified-since'] != null
          ? OmniRawResponse(statusCode: 304)
          : serve(r);
      client();
      await get('/a');
      expect((await get('/a')).$2, ResponseSource.revalidated);
      expect(
        mock.requests.last.headers['if-modified-since'],
        'Wed, 21 Oct 2015 07:28:00 GMT',
      );
    });

    test('no freshness info and no validators => always network', () async {
      headers = {};
      mock.handler = (r) =>
          OmniRawResponse(statusCode: 200, bodyBytes: utf8.encode('1'));
      client();
      await get('/a');
      await get('/a');
      expect(mock.requests, hasLength(2));
      expect(mock.requests.last.headers.containsKey('if-none-match'), isFalse);
    });

    test('no-store is not stored; no-cache always revalidates', () async {
      headers = {'cache-control': 'no-store'};
      client();
      await get('/a');
      await get('/a');
      expect(mock.requests.last.headers.containsKey('if-none-match'), isFalse);
      expect(mock.requests, hasLength(2));

      headers = {'cache-control': 'no-cache'};
      await get('/b');
      expect((await get('/b')).$2, ResponseSource.revalidated);
    });

    test('Age is subtracted; Expires relative to Date', () async {
      headers = {'cache-control': 'max-age=60', 'age': '50'};
      client();
      await get('/a');
      now = now.add(const Duration(seconds: 11));
      expect((await get('/a')).$2, ResponseSource.revalidated);

      headers = {
        'date': 'Wed, 21 Oct 2015 07:00:00 GMT',
        'expires': 'Wed, 21 Oct 2015 07:00:30 GMT',
      };
      await get('/e');
      now = now.add(const Duration(seconds: 20));
      expect((await get('/e')).$2, ResponseSource.cache);
      now = now.add(const Duration(seconds: 11));
      expect((await get('/e')).$2, ResponseSource.revalidated);
    });

    test('Vary: matching and * (never stored)', () async {
      headers = {'cache-control': 'max-age=60', 'vary': 'Accept-Language'};
      client();
      await get('/a', h: {'accept-language': 'bn'});
      expect(
        (await get('/a', h: {'accept-language': 'bn'})).$2,
        ResponseSource.cache,
      );
      expect(
        (await get('/a', h: {'accept-language': 'en'})).$2,
        ResponseSource.network,
      );

      headers = {'cache-control': 'max-age=60', 'vary': '*'};
      await get('/star');
      expect((await get('/star')).$2, ResponseSource.network);
    });

    test('query strings are separate entries', () async {
      client();
      await api.sendRaw(const OmniRequest.get('/s', query: {'q': 'a'}));
      final r = await api.sendRaw(
        const OmniRequest.get('/s', query: {'q': 'b'}),
      );
      expect(r.source, ResponseSource.network);
    });

    test('non-200 and oversized bodies are not stored', () async {
      mock.handler = (_) => OmniRawResponse(
        statusCode: 404,
        headers: {'cache-control': 'max-age=60'},
      );
      client();
      await get('/a');
      await get('/a');
      expect(mock.requests, hasLength(2));

      final small = OmniCache(maxEntryBytes: 10, now: () => now);
      final api2 = OmniNetwork(
        baseUrl: 'https://h.io',
        transport: mock,
        cache: small,
      );
      addTearDown(api2.close);
      mock.handler = serve;
      await api2.sendRaw(const OmniRequest.get('/big'));
      final r = await api2.sendRaw(const OmniRequest.get('/big'));
      expect(r.source, ResponseSource.network);
    });

    test('request Cache-Control no-store / no-cache', () async {
      client();
      await get('/a');
      expect(
        (await get('/a', h: {'cache-control': 'no-store'})).$2,
        ResponseSource.network,
      );
      expect(
        (await get('/a', h: {'cache-control': 'no-cache'})).$2,
        ResponseSource.revalidated,
      );
    });
  });

  group('policies', () {
    setUp(() => headers = {'cache-control': 'max-age=10'});

    test('cacheFirst serves stale entries', () async {
      client(policy: CachePolicy.cacheFirst);
      await get('/a');
      now = now.add(const Duration(days: 1));
      expect((await get('/a')).$2, ResponseSource.cache);
      expect(mock.requests, hasLength(1));
    });

    test('staleWhileRevalidate: stale now, fresh next time', () async {
      client(policy: CachePolicy.staleWhileRevalidate);
      await get('/a');
      now = now.add(const Duration(seconds: 11));
      version = 2;
      expect(await getText('/a'), (
        '{"v":1,"path":"/a"}',
        ResponseSource.cache,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(mock.requests, hasLength(2)); // background refresh
      expect((await get('/a')).$1, {'v': 2, 'path': '/a'});
    });

    test('staleWhileRevalidate background errors are swallowed', () async {
      client(policy: CachePolicy.staleWhileRevalidate);
      await get('/a');
      now = now.add(const Duration(seconds: 11));
      mock.handler = (_) => throw const ConnectionFailure('down');
      expect((await get('/a')).$2, ResponseSource.cache);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    test('networkFirst falls back on connection errors only', () async {
      client(policy: CachePolicy.networkFirst);
      await get('/a');
      mock.handler = (_) => throw const ConnectionFailure('offline');
      expect((await get('/a')).$2, ResponseSource.cache);
      mock.handler = (_) => OmniRawResponse(statusCode: 500);
      final r = await api.sendRaw(const OmniRequest.get('/a'));
      expect(r.statusCode, 500);
      mock.handler = (_) => throw const ConnectionFailure('offline');
      await expectLater(
        get('/never-cached'),
        throwsA(isA<ConnectionFailure>()),
      );
    });

    test('refresh always asks the network; noCache bypasses', () async {
      client();
      await get('/a');
      expect(
        (await get('/a', policy: CachePolicy.refresh)).$2,
        ResponseSource.revalidated,
      );
      expect(
        (await get('/a', policy: CachePolicy.noCache)).$2,
        ResponseSource.network,
      );
      expect(mock.requests.last.headers.containsKey('if-none-match'), isFalse);
    });
  });

  group('authenticated responses', () {
    test('not cached by default', () async {
      client();
      final h = {'authorization': 'Bearer A'};
      await get('/me', h: h);
      expect((await get('/me', h: h)).$2, ResponseSource.network);
    });

    test('opt-in partitions by token hash', () async {
      client(authed: true);
      await get('/me', h: {'authorization': 'Bearer A'});
      expect(
        (await get('/me', h: {'authorization': 'Bearer A'})).$2,
        ResponseSource.cache,
      );
      expect(
        (await get('/me', h: {'authorization': 'Bearer B'})).$2,
        ResponseSource.network,
      );
    });

    test('opt-in partitions by authScope', () async {
      var user = 'u1';
      client(authed: true, scope: () => user);
      await get('/me', h: {'authorization': 'Bearer A'});
      user = 'u2';
      expect(
        (await get('/me', h: {'authorization': 'Bearer A'})).$2,
        ResponseSource.network,
      );
      await cache.clear();
      user = 'u1';
      expect(
        (await get('/me', h: {'authorization': 'Bearer A'})).$2,
        ResponseSource.network,
      );
    });

    test(
      'Cookie, X-API-Key, and X-Auth-Token are excluded unless enabled and partitioned',
      () async {
        client();
        await get('/me', h: {'Cookie': 'sid=userA'});
        await get('/me', h: {'Cookie': 'sid=userA'});
        await get('/me', h: {'X-API-Key': 'key-1'});
        await get('/me', h: {'X-Auth-Token': 'tok-1'});
        expect(mock.requests, hasLength(4));

        // With cacheAuthenticated: true and no authScope, distinct Cookies/API keys
        // stay strictly partitioned per credential set.
        client(authed: true);
        expect(
          ((await get('/me', h: {'Cookie': 'sid=userA'})).$1! as Map)['v'],
          1,
        );
        version = 2;
        expect(
          (await get('/me', h: {'Cookie': 'sid=userA'})).$2,
          ResponseSource.cache,
        );
        expect(
          ((await get('/me', h: {'Cookie': 'sid=userB'})).$1! as Map)['v'],
          2,
        );
        expect(
          (await get('/me', h: {'X-API-Key': 'key-1'})).$2,
          ResponseSource.network,
        );
      },
    );
  });

  test('successful unsafe request invalidates the URL', () async {
    client();
    await get('/items');
    mock.handler = (r) => r.method == HttpMethod.post
        ? OmniRawResponse(statusCode: 201)
        : serve(r);
    await api.sendRaw(const OmniRequest.post('/items', body: {'a': 1}));
    expect((await get('/items')).$2, ResponseSource.network);
  });

  test('typed calls and logs work with cache hits', () async {
    final sink = _Sink();
    cache = OmniCache(now: () => now);
    api = OmniNetwork(
      baseUrl: 'https://h.io',
      transport: mock,
      cache: cache,
      enableLogging: true,
      logSink: sink,
    );
    await api.get<Map<String, dynamic>>('/a');
    final m = await api.get<Map<String, dynamic>>('/a');
    expect(m['v'], 1);
    expect(sink.out, contains(', cache)'));
    expect(sink.records.last.source, ResponseSource.cache);
  });

  group('MemoryCacheStore', () {
    CacheEntry entry(String url, int bytes) => CacheEntry(
      url: url,
      statusCode: 200,
      headers: const {},
      body: Uint8ListOf(bytes),
      storedAt: DateTime(2026),
      expiresAt: DateTime(2027),
    );

    test('LRU by count', () {
      final s = MemoryCacheStore(maxEntries: 2);
      s.set('a', entry('a', 1));
      s.set('b', entry('b', 1));
      s.get('a'); // a is now most recent
      s.set('c', entry('c', 1));
      expect(s.get('b'), isNull);
      expect(s.get('a'), isNotNull);
      expect(s.length, 2);
    });

    test('bounded by bytes; oversized entry rejected', () {
      final s = MemoryCacheStore(maxBytes: 100);
      s.set('a', entry('a', 60));
      s.set('b', entry('b', 60));
      expect(s.get('a'), isNull);
      expect(s.bytes, 60);
      s.set('huge', entry('h', 500));
      expect(s.get('huge'), isNull);
      s.clear();
      expect((s.length, s.bytes), (0, 0));
    });
  });

  group('in-flight deduplication', () {
    late Completer<OmniRawResponse> gate;
    setUp(() {
      gate = Completer();
      mock.handler = (_) => gate.future;
      api = OmniNetwork(baseUrl: 'https://h.io', transport: mock);
    });

    test('identical concurrent GETs share one call', () async {
      final fs = [
        for (var i = 0; i < 5; i++) api.sendRaw(const OmniRequest.get('/a')),
      ];
      await Future<void>.delayed(Duration.zero);
      gate.complete(
        OmniRawResponse(statusCode: 200, bodyBytes: utf8.encode('x')),
      );
      final rs = await Future.wait(fs);
      expect(rs.map((r) => r.text), everyElement('x'));
      expect(mock.requests, hasLength(1));
      // After completion a new call goes to the network again.
      mock.handler = (_) => OmniRawResponse(statusCode: 200);
      await api.sendRaw(const OmniRequest.get('/a'));
      expect(mock.requests, hasLength(2));
    });

    test(
      'different headers, POSTs and deduplicate:false are not shared',
      () async {
        api.sendRaw(const OmniRequest.get('/a', headers: {'x': '1'})).ignore();
        api.sendRaw(const OmniRequest.get('/a', headers: {'x': '2'})).ignore();
        api.sendRaw(const OmniRequest.post('/a')).ignore();
        api.sendRaw(const OmniRequest.post('/a')).ignore();
        await Future<void>.delayed(Duration.zero);
        expect(mock.requests, hasLength(4));

        final plain = OmniNetwork(
          baseUrl: 'https://h.io',
          transport: mock,
          deduplicate: false,
        );
        addTearDown(plain.close);
        plain.sendRaw(const OmniRequest.get('/b')).ignore();
        plain.sendRaw(const OmniRequest.get('/b')).ignore();
        await Future<void>.delayed(Duration.zero);
        expect(mock.requests, hasLength(6));
        gate.complete(OmniRawResponse(statusCode: 200));
      },
    );

    test('one caller cancelling does not affect the others', () async {
      final token = OmniCancelToken();
      final a = api.sendRaw(OmniRequest.get('/a', cancelToken: token));
      final b = api.sendRaw(const OmniRequest.get('/a'));
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await expectLater(a, throwsA(isA<CancelledFailure>()));
      gate.complete(OmniRawResponse(statusCode: 200));
      expect((await b).statusCode, 200);
      expect(mock.requests, hasLength(1));
    });

    test('all callers cancelling cancels the shared call', () async {
      final t1 = OmniCancelToken();
      final t2 = OmniCancelToken();
      final a = api.sendRaw(OmniRequest.get('/a', cancelToken: t1));
      final b = api.sendRaw(OmniRequest.get('/a', cancelToken: t2));
      await Future<void>.delayed(Duration.zero);
      expect(mock.inFlight, 1);
      t1.cancel();
      t2.cancel();
      await expectLater(a, throwsA(isA<CancelledFailure>()));
      await expectLater(b, throwsA(isA<CancelledFailure>()));
      await Future<void>.delayed(Duration.zero);
      expect(mock.inFlight, 0);
    });

    test('each caller keeps its own timeout', () async {
      final short = api.sendRaw(
        const OmniRequest.get('/a', timeout: Duration(milliseconds: 20)),
      );
      final long = api.sendRaw(const OmniRequest.get('/a'));
      await expectLater(short, throwsA(isA<TimeoutFailure>()));
      gate.complete(OmniRawResponse(statusCode: 200));
      expect((await long).statusCode, 200);
    });
  });
}

// ignore: non_constant_identifier_names
Uint8List Uint8ListOf(int n) => Uint8List(n);

final class _Sink implements LogSink {
  final b = StringBuffer();
  final records = <NetworkLogRecord>[];
  String get out => '$b';
  @override
  void log(NetworkLogRecord r) {
    records.add(r);
    b.writeln(r.message);
  }
}
