import 'dart:async';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

String plain(String s) => s.replaceAll(RegExp('\x1B\\[[0-9;]*m'), '');
String stable(String s) => plain(s).replaceAll(RegExp(r'\d+ ms'), 'N ms');

void main() {
  late OmniMock mock;
  late List<String> out;

  OmniNetwork client({
    LogOptions options = const LogOptions(colors: false),
    bool enable = true,
  }) => OmniNetwork(
    baseUrl: 'https://api.test/v1',
    headers: {
      'Authorization': 'Bearer HEADER-SECRET',
      'Accept': 'application/json',
    },
    transport: mock,
    enableLogging: enable,
    logSink: PrettyLogSink(options: options, printer: out.add),
  );

  setUp(() {
    out = [];
    mock = OmniMock(basePath: '/v1')
      ..get(
        '/users/{id}',
        (_) => MockResponse.json({
          'id': 10,
          'name': 'Ana',
          'access_token': 'BODY-SECRET',
        }),
      )
      ..post('/orders', (_) => MockResponse.json({'error': 'qty'}, status: 422))
      ..get('/down', (_) => const MockResponse.offline())
      ..get('/big', (_) => MockResponse.json([for (var i = 0; i < 50; i++) i]))
      ..get('/bin', (_) => MockResponse.bytes([1, 2, 3]));
  });

  test('GET 200: exact block', () async {
    final api = client();
    addTearDown(api.close);
    await api.get<void>('/users/10');
    expect(stable(out.single), '''
┌────────────────────────────────────────────────────────────
│ GET  https://api.test/v1/users/10
├────────────────────────────────────────────────────────────
│ ✔ 200 OK · N ms · 51 B
│ {
│   "id": 10,
│   "name": "Ana",
│   "access_token": "***"
│ }
└────────────────────────────────────────────────────────────
''');
  });

  test('POST 422 with request body, and a connection failure', () async {
    final api = client();
    addTearDown(api.close);
    await api
        .post<void>('/orders', body: {'item': 7, 'password': 'PW-SECRET'})
        .asResult();
    await api.get<void>('/down').asResult();
    expect(stable(out[0]), '''
┌────────────────────────────────────────────────────────────
│ POST https://api.test/v1/orders
│ ⇢ body
│   {
│     "item": 7,
│     "password": "***"
│   }
├────────────────────────────────────────────────────────────
│ ✖ 422 Unprocessable Entity · N ms · 15 B
│ {
│   "error": "qty"
│ }
└────────────────────────────────────────────────────────────
''');
    expect(stable(out[1]), '''
┌────────────────────────────────────────────────────────────
│ GET  https://api.test/v1/down
├────────────────────────────────────────────────────────────
│ ✖ ConnectionFailure: Mock: offline · N ms
└────────────────────────────────────────────────────────────
''');
  });

  test(
    'colours: green 2xx, red 4xx and failures; plain text identical',
    () async {
      final api = client(options: const LogOptions(colors: true));
      addTearDown(api.close);
      await api.get<void>('/users/1');
      await api.post<void>('/orders').asResult();
      await api.get<void>('/down').asResult();
      expect(out[0], contains('\x1B[1;38;5;40m✔ 200 OK'));
      expect(out[1], contains('\x1B[1;38;5;196m✖ 422'));
      expect(out[2], contains('\x1B[1;38;5;196m✖ ConnectionFailure'));
      // Successful JSON is syntax-coloured: keys and numbers.
      expect(out[0], contains('\x1B[38;5;81m"id"'));
      expect(out[0], contains('\x1B[38;5;141m1'));
      // A failed call stays red: its body is not syntax-coloured.
      expect(out[1], isNot(contains('\x1B[38;5;81m"error"')));
      final noColor = <String>[];
      final api2 = OmniNetwork(
        baseUrl: 'https://api.test/v1',
        transport: mock,
        enableLogging: true,
        logSink: PrettyLogSink(
          options: const LogOptions(colors: false),
          printer: noColor.add,
        ),
      );
      addTearDown(api2.close);
      await api2.get<void>('/users/1');
      expect(stable(out[0]), stable(noColor[0]));
    },
  );

  test('secrets never printed, even with headers on', () async {
    final api = client(options: const LogOptions(colors: false, headers: true));
    addTearDown(api.close);
    await api.get<void>('/users/1', query: {'api_key': 'QUERY-SECRET'});
    await api.post<void>('/orders', body: {'password': 'PW-SECRET'}).asResult();
    final all = out.join();
    for (final s in [
      'HEADER-SECRET',
      'BODY-SECRET',
      'QUERY-SECRET',
      'PW-SECRET',
    ]) {
      expect(all, isNot(contains(s)));
    }
    expect(
      all,
      contains(
        '│ ⇢ headers\n│   authorization: ***\n│   accept: application/json',
      ),
    );
    expect(all, contains('│ ⇠ headers\n│   content-type: application/json'));
    expect(all, contains('api_key=***'));
  });

  test(
    'long bodies cut after maxLines; binary bodies summarised; options',
    () async {
      final api = client(
        options: const LogOptions(
          colors: false,
          maxLines: 5,
          requestBody: false,
        ),
      );
      addTearDown(api.close);
      await api.get<void>('/big');
      await api.get<void>('/bin');
      await api.post<void>('/orders', body: {'x': 1}).asResult();
      final big = plain(out[0]).split('\n');
      expect(
        big.where((l) => l.startsWith('│   ')),
        hasLength(4),
      ); // 5 lines incl. "["
      expect(out[0], contains('… 47 more lines'));
      expect(
        out[1],
        contains('<3 bytes, application/octet-stream, not shown>'),
      );
      expect(out[2], isNot(contains('⇢ body')));
    },
  );

  test('retry and token-refresh notes', () async {
    var n = 0;
    var token = 'OLD';
    mock
      ..get(
        '/flaky',
        (_) => ++n < 2 ? const MockResponse.status(503) : MockResponse.json(1),
      )
      ..get(
        '/me',
        (r) => r.headers['authorization'] == 'Bearer NEW'
            ? MockResponse.json(1)
            : const MockResponse.status(401),
      );
    final api = OmniNetwork(
      baseUrl: 'https://api.test/v1',
      transport: mock,
      enableLogging: true,
      logSink: PrettyLogSink(
        options: const LogOptions(colors: false),
        printer: out.add,
      ),
      retry: const RetryPolicy(
        baseDelay: Duration(milliseconds: 1),
        jitter: false,
      ),
      auth: BearerAuth(token: () => token, refresh: () => token = 'NEW'),
    );
    addTearDown(api.close);
    await api.get<void>('/flaky');
    await api.get<void>('/me');
    expect(out[1], contains('│ ↻ retry 2/3'));
    expect(out[3], contains('│ 🔑 token refreshed'));
    expect(out[0], isNot(contains('retry')));
  });

  test('cache hits are marked', () async {
    mock.get(
      '/c',
      (_) => MockResponse.json(1, headers: {'cache-control': 'max-age=60'}),
    );
    final api = OmniNetwork(
      baseUrl: 'https://api.test/v1',
      transport: mock,
      enableLogging: true,
      cache: OmniCache(),
      logSink: PrettyLogSink(
        options: const LogOptions(colors: false),
        printer: out.add,
      ),
    );
    addTearDown(api.close);
    await api.get<void>('/c');
    await api.get<void>('/c');
    expect(out[1], contains('✔ 200 OK · '));
    expect(out[1], contains(' · cache'));
  });

  test('concurrent calls print whole blocks, never interleaved', () async {
    mock.get(
      '/slow/{n}',
      (r) => MockResponse.json(
        {'n': r.pathParams['n']},
        delay: Duration(milliseconds: 5 * (5 - int.parse(r.pathParams['n']!))),
      ),
    );
    final api = client();
    addTearDown(api.close);
    await Future.wait([for (var i = 0; i < 5; i++) api.get<void>('/slow/$i')]);
    expect(out, hasLength(5));
    for (final block in out) {
      expect('┌'.allMatches(block), hasLength(1));
      expect('└'.allMatches(block), hasLength(1));
      final n = RegExp(r'/slow/(\d)').firstMatch(block)![1];
      expect(block, contains('"n": "$n"'));
    }
  });

  group('switch', () {
    tearDown(() => OmniNetwork.isReleaseBuild = false);

    test('enableLogging: false prints nothing', () async {
      final api = client(enable: false);
      addTearDown(api.close);
      await api.get<void>('/users/1');
      expect(out, isEmpty);
      expect(api.isLogging, isFalse);
    });

    test('release builds never log unless logInRelease', () async {
      OmniNetwork.isReleaseBuild = true;
      final api = client();
      addTearDown(api.close);
      await api.get<void>('/users/1');
      expect(out, isEmpty);
      expect((api.enableLogging, api.isLogging), (true, false));

      final forced = OmniNetwork(
        baseUrl: 'https://api.test/v1',
        transport: mock,
        enableLogging: true,
        logInRelease: true,
        logSink: PrettyLogSink(
          options: const LogOptions(colors: false),
          printer: out.add,
        ),
      );
      addTearDown(forced.close);
      await forced.get<void>('/users/1');
      expect(out, hasLength(1));
    });

    test(
      'enableLogging: true logs through the logger package by default',
      () async {
        final printed = <String>[];
        await runZoned(
          () async {
            final api = OmniNetwork(
              baseUrl: 'https://api.test/v1',
              transport: mock,
              enableLogging: true,
              logOptions: const LogOptions(colors: false),
            );
            await api.get<void>('/users/1');
            await api.close();
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => printed.add(line),
          ),
        );
        // One logger block: frame, time, then one line per row, each with
        // the level emoji. Printed synchronously, so blocks never
        // interleave.
        final block = printed.join('\n');
        expect(printed.first, startsWith('┌'));
        expect(printed.last, startsWith('└'));
        expect(block, contains('💡 GET  https://api.test/v1/users/1'));
        expect(block, contains('💡 ✔ 200 OK'));
        expect(
          block,
          contains(RegExp(r'\d\d:\d\d:\d\d\.\d{3}')),
          reason: 'time',
        );
      },
    );

    test(
      'summary: true prints instant outcome badge, speed & JSON shape',
      () async {
        final summaryOut = <String>[];
        final summaryMock = OmniMock(basePath: '/v1')
          ..get('/users/1', (_) => MockResponse.json({'id': 1, 'name': 'Ana'}))
          ..get('/posts', (_) => MockResponse.json([1, 2, 3]))
          ..get(
            '/missing',
            (_) => MockResponse.json({'error': 'none'}, status: 404),
          )
          ..get(
            '/crash',
            (_) => MockResponse.json({'err': 'down'}, status: 503),
          );
        final api = OmniNetwork(
          baseUrl: 'https://api.test/v1',
          transport: summaryMock,
          enableLogging: true,
          logSink: PrettyLogSink(
            options: const LogOptions(summary: true, colors: true),
            printer: summaryOut.add,
          ),
        );
        addTearDown(api.close);

        await api.get<void>('/users/1');
        await api.get<void>('/posts');
        await api.get<void>('/missing').asResult();
        await api.get<void>('/crash').asResult();

        expect(
          plain(summaryOut[0]),
          contains('🟢 ✔ 200 OK · SUCCESS · ⚡ FAST'),
        );
        expect(
          plain(summaryOut[0]),
          contains('📦 Body: JSON Object (2 keys: id, name)'),
        );
        expect(plain(summaryOut[1]), contains('📋 Body: JSON Array (3 items)'));
        expect(
          plain(summaryOut[2]),
          contains('🟠 ⚠ 404 Not Found · CLIENT WARNING'),
        );
        expect(summaryOut[2], contains('\x1B[38;5;214m'));
        expect(
          plain(summaryOut[3]),
          contains('🔴 ✖ 503 Service Unavailable · SERVER ERROR'),
        );
        expect(summaryOut[3], contains('\x1B[38;5;196m'));
      },
    );

    test(
      'separate: true emits distinct colored request, response & status-matched JSON boxes',
      () async {
        final blocks = <String>[];
        final sepMock = OmniMock(basePath: '/v1')
          ..get('/users/1', (_) => MockResponse.json({'id': 1, 'name': 'Ana'}))
          ..get(
            '/missing',
            (_) => MockResponse.json({'error': 'missing'}, status: 404),
          )
          ..get(
            '/crash',
            (_) => MockResponse.json({'error': 'down'}, status: 503),
          );
        final api = OmniNetwork(
          baseUrl: 'https://api.test/v1',
          transport: sepMock,
          enableLogging: true,
          logSink: PrettyLogSink(
            options: const LogOptions(
              summary: true,
              separate: true,
              colors: true,
            ),
            printer: blocks.add,
          ),
        );
        addTearDown(api.close);

        await api.get<void>('/users/1');
        await api.get<void>('/missing').asResult();
        await api.get<void>('/crash').asResult();

        // Expect 3 blocks per JSON call: request + response header + JSON body.
        expect(blocks, hasLength(9));

        // 1. Separate magenta http-request box.
        expect(blocks[0], contains('\x1B[38;5;171m'));
        expect(plain(blocks[0]), contains('📡 http-request · GET'));
        expect(plain(blocks[0]), contains('https://api.test/v1/users/1'));

        // 2. Separate green 200 OK header box & green-matched JSON body box.
        expect(blocks[1], contains('\x1B[38;5;40m'));
        expect(
          plain(blocks[1]),
          contains('💡 http-response · 200 OK · SUCCESS'),
        );
        expect(plain(blocks[1]), contains('📦 Body: JSON Object'));
        expect(blocks[2], contains('\x1B[38;5;40m┌'));
        expect(plain(blocks[2]), contains('"id": 1'));
        expect(plain(blocks[2]), contains('"name": "Ana"'));
        expect(plain(blocks[2]), isNot(contains('💡')));

        // 3. Separate amber 404 warning box + amber-matched 404 JSON body box.
        expect(blocks[3], contains('\x1B[38;5;171m'));
        expect(blocks[4], contains('\x1B[38;5;214m'));
        expect(plain(blocks[4]), contains('⚠️ http-warning · 404 Not Found'));
        expect(blocks[5], contains('\x1B[38;5;214m┌'));
        expect(plain(blocks[5]), contains('"error": "missing"'));

        // 4. Separate red 503 error box (with white-on-red banner) + red JSON body box.
        expect(blocks[6], contains('\x1B[38;5;171m'));
        expect(blocks[7], contains('\x1B[1;38;5;15;48;5;196m'));
        expect(
          plain(blocks[7]),
          contains('⛔ http-error · 503 Service Unavailable'),
        );
        expect(blocks[8], contains('\x1B[38;5;196m┌'));
        expect(plain(blocks[8]), contains('"error": "down"'));
      },
    );
  });
}
