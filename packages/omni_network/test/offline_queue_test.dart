import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

OmniRawResponse status(int code) => OmniRawResponse(statusCode: code);

void main() {
  late MockTransport mock;
  late OmniNetwork api;
  late OfflineQueue queue;
  late List<QueueEvent> events;
  var online = false;

  setUp(() {
    online = false;
    mock = MockTransport(
      (_) => online ? status(201) : throw const ConnectionFailure('offline'),
    );
    api = OmniNetwork(baseUrl: 'https://h.io', transport: mock);
    queue = OfflineQueue(client: api, maxAttempts: 3);
    events = [];
    queue.events.listen(events.add);
  });
  tearDown(() async {
    await queue.close();
    await api.close();
  });

  Future<List<String>> paths() async => [
    for (final q in await queue.pending) q.path,
  ];

  group('nothing is queued implicitly', () {
    test('plain requests failing offline are not queued', () async {
      await expectLater(
        api.sendRaw(const OmniRequest.post('/notes', body: {'t': 'a'})),
        throwsA(isA<ConnectionFailure>()),
      );
      expect(await queue.pending, isEmpty);
    });

    test('GET/HEAD and multipart are refused', () async {
      for (final r in [
        const OmniRequest.get('/a'),
        const OmniRequest.head('/a'),
        OmniRequest.post('/f', body: MultipartBody()),
      ]) {
        await expectLater(queue.enqueue(r), throwsArgumentError);
      }
      expect(await queue.pending, isEmpty);
    });

    test('PUT/PATCH/DELETE need allowDestructive', () async {
      for (final m in [HttpMethod.put, HttpMethod.patch, HttpMethod.delete]) {
        final r = OmniRequest(m, '/notes/1');
        await expectLater(queue.enqueue(r), throwsArgumentError);
        await expectLater(queue.sendOrQueue(r), throwsArgumentError);
        await queue.enqueue(r, allowDestructive: true);
      }
      expect(mock.requests, isEmpty); // refused before sending
      expect(await queue.pending, hasLength(3));
    });

    test('non-JSON body refused', () async {
      await expectLater(
        queue.enqueue(OmniRequest.post('/a', body: {'x': Object()})),
        throwsArgumentError,
      );
    });
  });

  group('sendOrQueue', () {
    test('online: sent, not queued, carries an Idempotency-Key', () async {
      online = true;
      final r = await queue.sendOrQueue(const OmniRequest.post('/notes'));
      expect((r as SentNow).response.statusCode, 201);
      expect(mock.requests.single.headers['idempotency-key'], hasLength(32));
      expect(await queue.pending, isEmpty);
    });

    test('server error is returned, not queued', () async {
      mock.handler = (_) => status(503);
      final r = await queue.sendOrQueue(const OmniRequest.post('/notes'));
      expect((r as SentNow).response.statusCode, 503);
      expect(await queue.pending, isEmpty);
    });

    test('offline: queued with the same key that was attempted', () async {
      final r = await queue.sendOrQueue(
        const OmniRequest.post('/notes', body: {'t': 'a'}),
        tag: 'note:new',
      );
      final item = (r as Queued).item;
      await Future<void>.delayed(Duration.zero);
      expect(item.tag, 'note:new');
      expect(
        item.idempotencyKey,
        mock.requests.single.headers['idempotency-key'],
      );
      expect(events.single.kind, QueueEventKind.enqueued);
      expect(events.single.error, isA<ConnectionFailure>());
    });

    test('existing Idempotency-Key is kept', () async {
      final item = await queue.enqueue(
        const OmniRequest.post('/pay', headers: {'Idempotency-Key': 'mine'}),
      );
      expect(item.idempotencyKey, 'mine');
    });
  });

  test('credentials are never stored; replay gets a fresh token', () async {
    var token = 'OLD';
    final authed = OmniNetwork(
      baseUrl: 'https://h.io',
      transport: mock,
      auth: BearerAuth(token: () => token, refresh: () => null),
    );
    addTearDown(authed.close);
    final q = OfflineQueue(client: authed);
    addTearDown(q.close);
    await q.sendOrQueue(
      const OmniRequest.post(
        '/a',
        headers: {
          'Authorization': 'Bearer EXPLICIT',
          'Cookie': 's=1',
          'X-Keep': '1',
        },
      ),
    );
    final stored = (await q.pending).single;
    expect(
      stored.headers.keys.map((k) => k.toLowerCase()),
      unorderedEquals(['x-keep', 'idempotency-key']),
    );
    expect(jsonEncode(stored.toJson()), isNot(contains('EXPLICIT')));
    online = true;
    token = 'NEW';
    await q.flush();
    expect(mock.requests.last.headers['authorization'], 'Bearer NEW');
  });

  group('credential headers', () {
    const secrets = {
      'X-API-Key': 'secret-api-key',
      'x-auth-token': 'secret-auth',
      'X-CSRF-Token': 'secret-csrf',
      'X-XSRF-TOKEN': 'secret-xsrf',
      'Proxy-Authorization': 'Basic secret-proxy',
      'X-Access-Token': 'secret-access',
      'X-Amz-Security-Token': 'secret-amz',
      'X-Session-Id': 'secret-session', // Redactor rule: "session"
      'X-Client-Secret': 'secret-client', // Redactor rule: "secret"
      'X-Request-Signature': 'secret-sig', // Redactor rule: "signature"
    };
    const safe = {
      'X-Keep': '1',
      'Accept': 'application/json',
      'Content-Language': 'bn',
      'X-Request-Id': 'r-1',
    };

    void expectNoSecrets(Object json) {
      final text = jsonEncode(json);
      for (final v in secrets.values) {
        expect(text, isNot(contains(v)), reason: v);
      }
    }

    test('known and token-like headers are dropped, any case', () async {
      final item = await queue.enqueue(
        const OmniRequest.post(
          '/a',
          headers: {...secrets, ...safe, 'Idempotency-Key': 'idem-1'},
        ),
      );
      expect(item.headers, {...safe, 'Idempotency-Key': 'idem-1'});
      expectNoSecrets(item.toJson());
    });

    test('sendOrQueue drops them before queuing', () async {
      final r = await queue.sendOrQueue(
        const OmniRequest.post('/a', headers: {...secrets, ...safe}),
      );
      final item = (r as Queued).item;
      expect(item.headers.keys.toSet(), {...safe.keys, 'Idempotency-Key'});
      expectNoSecrets((await queue.pending).single.toJson());
    });

    test('sensitiveHeaders adds names, case-insensitively', () async {
      final q = OfflineQueue(
        client: api,
        sensitiveHeaders: const {'x-device-id', 'X-TENANT'},
      );
      addTearDown(q.close);
      final item = await q.enqueue(
        const OmniRequest.post(
          '/a',
          headers: {'X-Device-ID': 'd', 'x-tenant': 't', 'X-Keep': '1'},
        ),
      );
      expect(item.headers.keys.toSet(), {'X-Keep', 'Idempotency-Key'});
    });

    test('toJson never writes them, even for a hand-built item', () {
      final item = QueuedRequest(
        id: '1',
        method: HttpMethod.post,
        path: '/a',
        createdAt: DateTime.utc(2026),
        headers: {...secrets, 'Authorization': 'Bearer secret-bearer'},
      );
      final json = item.toJson();
      expectNoSecrets(json);
      expect(jsonEncode(json), isNot(contains('secret-bearer')));
    });

    test('fromJson drops them from records of older versions', () {
      final back = QueuedRequest.fromJson({
        'id': '1',
        'method': 'post',
        'path': '/a',
        'query': <String, Object?>{},
        'headers': {...secrets, 'Cookie': 's=1', 'Idempotency-Key': 'k'},
        'body': null,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'attempts': 0,
        'tag': null,
      });
      expect(back.headers, {'Idempotency-Key': 'k'});
    });

    test('a stale stored credential never overrides the current one', () async {
      final store = MemoryQueueStore()
        ..add(
          QueuedRequest(
            id: 'legacy',
            method: HttpMethod.post,
            path: '/a',
            createdAt: DateTime.utc(2026),
            headers: const {
              'X-API-Key': 'STALE',
              'X-Device-Id': 'STALE-DEVICE',
              'Idempotency-Key': 'k',
              'X-Keep': '1',
            },
          ),
        );
      final client = OmniNetwork(
        baseUrl: 'https://h.io',
        transport: mock,
        headers: const {'X-API-Key': 'CURRENT'},
      );
      addTearDown(client.close);
      final q = OfflineQueue(
        client: client,
        store: store,
        sensitiveHeaders: const {'x-device-id'},
      );
      addTearDown(q.close);
      online = true;
      await q.flush();
      final sent = mock.requests.last.headers.map(
        (k, v) => MapEntry(k.toLowerCase(), v),
      );
      expect(sent['x-api-key'], 'CURRENT');
      expect(sent.containsKey('x-device-id'), isFalse);
      expect(sent['idempotency-key'], 'k');
      expect(sent['x-keep'], '1');
      expect(store.all(), isEmpty);
    });

    test('FileQueueStore never writes them to disk', () async {
      final dir = await Directory.systemTemp.createTemp('omni_queue_');
      addTearDown(() => dir.delete(recursive: true));
      final store = FileQueueStore(directory: dir.path);
      final q = OfflineQueue(client: api, store: store);
      addTearDown(q.close);
      await q.enqueue(
        const OmniRequest.post(
          '/a',
          headers: {...secrets, 'Authorization': 'Bearer secret-bearer'},
        ),
      );
      // A hand-built item added straight to the store is scrubbed too.
      await store.add(
        QueuedRequest(
          id: 'raw',
          method: HttpMethod.post,
          path: '/b',
          createdAt: DateTime.utc(2026),
          headers: secrets,
        ),
      );
      final onDisk = await File('${dir.path}/queue.json').readAsString();
      for (final v in [...secrets.values, 'secret-bearer']) {
        expect(onDisk, isNot(contains(v)), reason: v);
      }
      expect(await store.all(), hasLength(2));
    });
  });

  group('flush', () {
    test('replays oldest first and empties the queue', () async {
      for (final p in ['/1', '/2', '/3']) {
        await queue.enqueue(OmniRequest.post(p));
      }
      online = true;
      await queue.flush();
      expect(mock.requests.map((r) => r.uri.path), ['/1', '/2', '/3']);
      expect(await queue.pending, isEmpty);
      expect(events.where((e) => e.kind == QueueEventKind.sent), hasLength(3));
    });

    test('stops at the first temporary failure, keeping order', () async {
      for (final p in ['/1', '/2', '/3']) {
        await queue.enqueue(OmniRequest.post(p));
      }
      mock.handler = (r) => r.uri.path == '/2' ? status(503) : status(201);
      await queue.flush();
      expect(await paths(), ['/2', '/3']);
      expect((await queue.pending).first.attempts, 1);
      expect(mock.requests.map((r) => r.uri.path), ['/1', '/2']);
    });

    test('4xx rejected and removed; others continue', () async {
      await queue.enqueue(const OmniRequest.post('/bad'));
      await queue.enqueue(const OmniRequest.post('/ok'));
      mock.handler = (r) => r.uri.path == '/bad' ? status(422) : status(201);
      await queue.flush();
      expect(await queue.pending, isEmpty);
      expect(
        events.map((e) => e.kind),
        containsAllInOrder([QueueEventKind.rejected, QueueEventKind.sent]),
      );
    });

    test('dead-letters after maxAttempts, then continues', () async {
      await queue.enqueue(const OmniRequest.post('/flaky'));
      await queue.enqueue(const OmniRequest.post('/ok'));
      mock.handler = (r) => r.uri.path == '/flaky'
          ? throw const ConnectionFailure('x')
          : status(201);
      await queue.flush();
      await queue.flush();
      expect(await paths(), ['/flaky', '/ok']);
      await queue.flush(); // third failure => dead-letter, /ok sent
      await Future<void>.delayed(Duration.zero);
      expect(await queue.pending, isEmpty);
      final dead = events.firstWhere(
        (e) => e.kind == QueueEventKind.deadLettered,
      );
      expect(dead.item.attempts, 3);
    });

    test('the same idempotency key is sent on every replay', () async {
      await queue.enqueue(const OmniRequest.post('/a'));
      mock.handler = (_) => status(503);
      await queue.flush();
      mock.handler = (_) => status(201);
      await queue.flush();
      final keys = mock.requests
          .map((r) => r.headers['idempotency-key'])
          .toSet();
      expect(keys, hasLength(1));
    });

    test('concurrent flush calls share one run', () async {
      await queue.enqueue(const OmniRequest.post('/a'));
      online = true;
      final a = queue.flush();
      final b = queue.flush();
      expect(identical(a, b), isTrue);
      await a;
      expect(mock.requests, hasLength(1));
    });

    test('replays are not auto-retried by the client policy', () async {
      final retrying = OmniNetwork(
        baseUrl: 'https://h.io',
        transport: mock,
        retry: const RetryPolicy(
          baseDelay: Duration(milliseconds: 1),
          retryWithIdempotencyKey: true,
        ),
      );
      addTearDown(retrying.close);
      final q = OfflineQueue(client: retrying);
      addTearDown(q.close);
      await q.enqueue(const OmniRequest.post('/a'));
      mock.handler = (_) => status(503);
      await q.flush();
      expect(mock.requests, hasLength(1));
    });
  });

  test('enqueue with an existing id is ignored (dedupe)', () async {
    final a = await queue.enqueue(const OmniRequest.post('/a'), id: 'draft-1');
    final b = await queue.enqueue(const OmniRequest.post('/b'), id: 'draft-1');
    expect(b.path, a.path);
    expect(await queue.pending, hasLength(1));
    await queue.discard('draft-1');
    expect(await queue.pending, isEmpty);
  });

  test('attach flushes when connectivity returns', () async {
    await queue.enqueue(const OmniRequest.post('/a'));
    final net = StreamController<bool>();
    queue.attach(net.stream);
    net.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(mock.requests, isEmpty);
    online = true;
    net.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(await queue.pending, isEmpty);
    await queue.close();
    expect(net.hasListener, isFalse);
    await net.close();
    expect(queue.flush, throwsStateError);
  });

  test('toJson/fromJson round-trip (JSON, text, bytes)', () async {
    for (final body in <Object?>[
      {
        'a': [1, 2],
      },
      'plain',
      Uint8List.fromList([0, 255, 7]),
      [5, 6], // List<int> is sent as bytes by the client; kept as bytes.
      null,
    ]) {
      final item = await queue.enqueue(
        OmniRequest.post('/x', body: body, query: {'q': 'v'}),
        tag: 't',
      );
      final back = QueuedRequest.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, Object?>,
      );
      expect(back.body, item.body);
      expect(
        (back.id, back.method, back.path, back.tag),
        (item.id, item.method, item.path, item.tag),
      );
      expect(back.query, {'q': 'v'});
      expect(back.headers, item.headers);
      expect(back.createdAt, item.createdAt.toUtc());
    }
  });
}
