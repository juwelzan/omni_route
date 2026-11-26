import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:omni_network/advanced.dart'
    hide SseConnection, SseEvent, SseParser, SseState;
import 'package:omni_network/testing.dart';
import 'package:omni_network_ws/omni_network_ws.dart';
import 'package:test/test.dart';

Future<List<SseEvent>> parse(
  List<String> chunks, {
  List<Duration>? retries,
}) async {
  final p = SseParser(onRetry: retries?.add);
  final out = <SseEvent>[];
  p.events.listen(out.add);
  chunks.forEach(p.add);
  await p.close();
  return out;
}

void main() {
  group('SseParser (WHATWG rules)', () {
    test('data lines, event types, comments, ids', () async {
      final e = await parse([
        ': comment\n',
        'data: first\ndata:second\n\n',
        'event: update\nid: 7\ndata: {"a":1}\n\n',
        'data: no-id-change\n\n',
      ]);
      expect(e.map((x) => (x.event, x.data, x.id)).toList(), [
        ('message', 'first\nsecond', null),
        ('update', '{"a":1}', '7'),
        ('message', 'no-id-change', '7'),
      ]);
      expect(e[1].json, {'a': 1});
    });

    test('CRLF, CR, BOM and chunks split anywhere', () async {
      final text = '﻿data: a\r\n\r\ndata: b\r\rdata: c\n\n';
      for (var size = 1; size <= 5; size++) {
        final chunks = [
          for (var i = 0; i < text.length; i += size)
            text.substring(i, i + size > text.length ? text.length : i + size),
        ];
        expect((await parse(chunks)).map((e) => e.data), [
          'a',
          'b',
          'c',
        ], reason: 'size $size');
      }
    });

    test('retry, empty data, no-data blocks, incomplete tail', () async {
      final retries = <Duration>[];
      final e = await parse([
        'retry: 1500\nretry: x\n\n',
        'event: ping\n\n',
        'data\n\n',
        'id: a\u0000b\ndata: x\n\n',
        'data: never dispatched',
      ], retries: retries);
      expect(retries, [const Duration(milliseconds: 1500)]);
      expect(e.map((x) => (x.event, x.data, x.id)).toList(), [
        ('message', '', null),
        ('message', 'x', null),
      ]);
    });
  });

  test(
    'oversized events are dropped with an error; parsing continues',
    () async {
      final p = SseParser(maxEventBytes: 100);
      final events = <String>[];
      final errors = <Object>[];
      p.events.listen((e) => events.add(e.data), onError: errors.add);
      p.add('data: ${'x' * 60}\n');
      p.add('data: ${'y' * 60}\n\n'); // 121 chars > 100
      p.add('data: ${'z' * 500}'); // unterminated line > 100
      p.add('\n\ndata: ok\n\n');
      await p.close();
      expect(events, ['ok']);
      expect(errors, hasLength(2));
      expect(errors.first, isA<FormatException>());
    },
  );

  group('SseConnection via OmniMock', () {
    late OmniMock mock;
    late OmniNetwork api;
    var connections = 0;
    final lastIds = <String?>[];

    setUp(() {
      connections = 0;
      lastIds.clear();
      mock = OmniMock();
      api = OmniNetwork(baseUrl: 'https://h.io', transport: mock);
    });
    tearDown(() => api.close());

    MockResponse events(String body) =>
        MockResponse.bytes(utf8.encode(body), contentType: 'text/event-stream');

    test(
      'reconnects after the stream ends and resumes with Last-Event-ID',
      () async {
        mock.get('/events', (r) {
          connections++;
          lastIds.add(r.headers['last-event-id']);
          return connections == 1
              ? events('retry: 10\nid: 1\ndata: a\n\nid: 2\ndata: b\n\n')
              : events('id: 3\ndata: c\n\n');
        });
        final sse = SseConnection(api, '/events');
        final got = <String>[];
        final sub = sse.events.listen((e) => got.add(e.data));
        while (got.length < 3) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await sse.close();
        await sub.cancel();
        expect(got.take(3), ['a', 'b', 'c']);
        expect(lastIds.take(2), [null, '2']);
        expect(mock.calls.first.request.headers['accept'], 'text/event-stream');
        expect(sse.state, SseState.closed);
      },
    );

    test('204 stops; 4xx stops with an error; 503 retries', () async {
      mock.get('/done', (_) => const MockResponse.status(204));
      final a = SseConnection(api, '/done');
      expect(await a.states.last, SseState.closed);

      mock.get('/gone', (_) => const MockResponse.status(404));
      final b = SseConnection(api, '/gone');
      await expectLater(b.events, emitsError(isA<HttpFailure>()));

      var n = 0;
      mock.get(
        '/flaky',
        (_) =>
            ++n < 3 ? const MockResponse.status(503) : events('data: ok\n\n'),
      );
      final c = SseConnection(
        api,
        '/flaky',
        retry: const Duration(milliseconds: 5),
      );
      expect((await c.events.first).data, 'ok');
      expect(n, 3);
      await c.close();
    });

    test('maxReconnects gives up with an error', () async {
      mock.get('/down', (_) => const MockResponse.offline());
      final s = SseConnection(
        api,
        '/down',
        retry: const Duration(milliseconds: 2),
        maxReconnects: 2,
      );
      await expectLater(s.events, emitsError(isA<StateError>()));
      expect(mock.calls, hasLength(3));
    });

    test('auth header is added by the client', () async {
      final authed = OmniNetwork(
        baseUrl: 'https://h.io',
        transport: mock,
        auth: BearerAuth(token: () => 'T', refresh: () => null),
      );
      addTearDown(authed.close);
      mock.get('/events', (_) => events('data: x\n\n'));
      final s = SseConnection(authed, '/events');
      await s.events.first;
      await s.close();
      expect(mock.calls.first.request.headers['authorization'], 'Bearer T');
    });

    test('close while waiting to reconnect stops at once', () async {
      mock.get('/e', (_) => events('data: x\n\n'));
      final s = SseConnection(api, '/e', retry: const Duration(seconds: 30));
      await s.events.first;
      while (s.state != SseState.waiting) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final w = Stopwatch()..start();
      await s.close();
      expect(w.elapsed, lessThan(const Duration(seconds: 1)));
      expect(s.state, SseState.closed);
    });
  });

  test(
    'real streaming over Dio: events arrive before the response ends',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      server.listen((req) async {
        req.response.headers.contentType = ContentType('text', 'event-stream');
        req.response.bufferOutput = false;
        req.response.write('data: one\n\n');
        await req.response.flush();
        await release.future;
        req.response.write('data: two\n\n');
        await req.response.close();
      });
      final api = OmniNetwork(baseUrl: 'http://127.0.0.1:${server.port}');
      final s = SseConnection(api, '/');
      final first = await s.events.first.timeout(const Duration(seconds: 5));
      expect(first.data, 'one');
      release.complete();
      await s.close();
      await api.close();
      await server.close(force: true);
    },
  );
}
