import 'dart:async';
import 'dart:convert';

import 'package:omni_network/omni_network.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

String _stripAnsi(String s) => s.replaceAll(RegExp('\x1B\\[[0-9;]*m'), '');

void main() {
  group('Full response logging & live OmniNetwork toggles', () {
    test(
      'prints full 1000+ line response with terminal colors and toggles ON/OFF cleanly',
      () async {
        final bigPayload = {
          'total': 250,
          'active': true,
          'items': [
            for (var i = 0; i < 250; i++)
              {
                'id': i,
                'code': 'ITEM_$i',
                'ok': i.isEven,
                'note': 'Line payload entry number $i',
              },
          ],
        };
        // Pretty JSON has 250 * 6 + 6 = 1506 lines!
        expect(
          const JsonEncoder.withIndent('  ').convert(bigPayload).split('\n').length,
          greaterThan(1000),
        );

        final mock = MockTransport(
          (_) => OmniRawResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            bodyBytes: utf8.encode(jsonEncode(bigPayload)),
          ),
        );

        final api = OmniNetwork(
          baseUrl: 'https://api.example.com',
          transport: mock,
          enableLogging: false,
          logColors: true,
        );
        addTearDown(api.close);

        Future<List<String>> capturePrint(Future<void> Function() run) async {
          final lines = <String>[];
          await runZoned(
            run,
            zoneSpecification: ZoneSpecification(
              print: (_, _, _, line) => lines.add(line),
            ),
          );
          return lines;
        }

        // 1. Starts OFF -> nothing printed at all.
        expect(api.enableLogging, isFalse);
        expect(api.isLogging, isFalse);
        final offLines = await capturePrint(() => api.get<dynamic>('/big'));
        expect(offLines, isEmpty);

        // 2. Flip enableLogging = true -> full 1500+ line response printed with colors!
        api.enableLogging = true;
        expect(api.isLogging, isTrue);
        expect(api.logResponse, isTrue);

        final coloredLines = await capturePrint(
          () => api.get<dynamic>('/big'),
        );
        final coloredDump = coloredLines.join('\n');
        final plainDump = _stripAnsi(coloredDump);

        expect(coloredLines.length, greaterThan(1000));
        expect(plainDump, contains('GET  https://api.example.com/big'));
        expect(plainDump, contains('✔ 200 OK'));
        expect(plainDump, contains('"code": "ITEM_0"'));
        expect(plainDump, contains('"code": "ITEM_249"'));
        expect(plainDump, isNot(contains('more lines')));
        expect(plainDump, isNot(contains('truncated')));

        // Terminal ANSI 256-colors present on status, keys, strings, numbers, bools.
        expect(coloredDump, contains('\x1B[38;5;40m')); // green success
        expect(coloredDump, contains('\x1B[38;5;81m"items"')); // cyan key
        expect(coloredDump, contains('\x1B[38;5;186m"ITEM_249"')); // yellow string
        expect(coloredDump, contains('\x1B[38;5;141m249')); // violet number
        expect(coloredDump, contains('\x1B[38;5;205mtrue')); // pink bool

        // 3. Turn off only response body printing via api.logResponse = false.
        api.logResponse = false;
        final noResBodyLines = await capturePrint(
          () => api.get<dynamic>('/big'),
        );
        final noResBodyPlain = _stripAnsi(noResBodyLines.join('\n'));
        expect(noResBodyPlain, contains('✔ 200 OK'));
        expect(noResBodyPlain, isNot(contains('ITEM_249')));

        // 4. Turn response body back ON and toggle colors OFF at runtime.
        api
          ..logResponse = true
          ..logColors = false;
        final uncoloredLines = await capturePrint(
          () => api.get<dynamic>('/big'),
        );
        final uncoloredDump = uncoloredLines.join('\n');
        expect(uncoloredLines.length, greaterThan(1000));
        expect(uncoloredDump, contains('"code": "ITEM_249"'));
        expect(uncoloredDump, isNot(contains('\x1B[')));

        // 5. Flip enableLogging = false again -> nothing printed.
        api.enableLogging = false;
        final stoppedLines = await capturePrint(() => api.get<dynamic>('/big'));
        expect(stoppedLines, isEmpty);
      },
    );

    test('logs XML and GraphQL text bodies cleanly', () async {
      final mock = MockTransport(
        (_) => OmniRawResponse(
          statusCode: 200,
          headers: {'content-type': 'application/xml'},
          bodyBytes: utf8.encode('<root><item>1</item></root>'),
        ),
      );
      final lines = <String>[];
      final api = OmniNetwork(
        baseUrl: 'https://api.example.com',
        transport: mock,
        enableLogging: true,
        logColors: false,
      );
      addTearDown(api.close);

      await runZoned(
        () => api.get<String>('/xml'),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      expect(lines.join('\n'), contains('<root><item>1</item></root>'));
    });
  });

  group('Dynamic headers, InlineInterceptor, Cache helpers & Concurrency', () {
    test('setHeader, removeHeader, and clearHeaders update runtime headers',
        () async {
      final mock = MockTransport(
        (r) => OmniRawResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          bodyBytes: utf8.encode(jsonEncode(r.headers)),
        ),
      );
      final api = OmniNetwork(
        baseUrl: 'https://h.io',
        headers: {'X-App': '1.0'},
        transport: mock,
      );
      addTearDown(api.close);

      var seen = await api.get<Map<String, dynamic>>('/echo');
      expect(seen['x-app'], '1.0');

      api.setHeader('Accept-Language', 'bn');
      expect(api.headers['accept-language'], 'bn');
      seen = await api.get<Map<String, dynamic>>('/echo');
      expect(seen['accept-language'], 'bn');
      expect(seen['x-app'], '1.0');

      api.removeHeader('X-App');
      seen = await api.get<Map<String, dynamic>>('/echo');
      expect(seen.containsKey('x-app'), isFalse);
      expect(seen['accept-language'], 'bn');

      api.clearHeaders();
      expect(api.headers, isEmpty);
      seen = await api.get<Map<String, dynamic>>('/echo');
      expect(seen.containsKey('accept-language'), isFalse);
    });

    test('OmniInterceptor.inline handles onRequest, onResponse, and onError',
        () async {
      var hits = 0;
      var errors = 0;
      final mock = MockTransport((r) {
        if (r.uri.path == '/fail') {
          return throw const ConnectionFailure('down');
        }
        return OmniRawResponse(
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          bodyBytes: utf8.encode(
            jsonEncode({'tag': r.headers['x-inline']}),
          ),
        );
      });

      final api = OmniNetwork(
        baseUrl: 'https://h.io',
        transport: mock,
        interceptors: [
          OmniInterceptor.inline(
            onRequest: (r) => r.withHeader('X-Inline', 'ok'),
            onResponse: (_, res) {
              hits++;
              return res;
            },
            onError: (_, _) => errors++,
          ),
        ],
      );
      addTearDown(api.close);

      final ok = await api.get<Map<String, dynamic>>('/ok');
      expect(ok['tag'], 'ok');
      expect(hits, 1);

      await expectLater(
        api.get<void>('/fail'),
        throwsA(isA<ConnectionFailure>()),
      );
      expect(errors, 1);
    });

    test('clearCache and invalidateCache resolve relative paths cleanly',
        () async {
      var calls = 0;
      final mock = MockTransport(
        (r) => OmniRawResponse(
          statusCode: 200,
          headers: {'cache-control': 'max-age=60'},
          bodyBytes: utf8.encode('${r.uri.path}:${++calls}'),
        ),
      );
      final api = OmniNetwork(
        baseUrl: 'https://h.io/v1',
        transport: mock,
        cache: OmniCache(),
      );
      addTearDown(api.close);

      expect(await api.get<String>('/a', query: {'p': 1}), '/v1/a:1');
      expect(await api.get<String>('/a', query: {'p': 1}), '/v1/a:1');
      expect(await api.get<String>('/b'), '/v1/b:2');

      await api.invalidateCache('/a', query: {'p': 1});
      expect(await api.get<String>('/a', query: {'p': 1}), '/v1/a:3');
      expect(await api.get<String>('/b'), '/v1/b:2'); // still cached!

      await api.clearCache();
      expect(await api.get<String>('/b'), '/v1/b:4');
    });

    test('maxConcurrentRequests throttles bursts and cancels queued requests',
        () async {
      var active = 0;
      var peak = 0;
      final gates = <Completer<void>>[];

      final mock = MockTransport((r) async {
        active++;
        if (active > peak) peak = active;
        final c = Completer<void>();
        gates.add(c);
        await c.future;
        active--;
        return OmniRawResponse(
          statusCode: 200,
          bodyBytes: utf8.encode(r.uri.path),
        );
      });

      final api = OmniNetwork(
        baseUrl: 'https://h.io',
        transport: mock,
        maxConcurrentRequests: 2,
      );
      addTearDown(api.close);

      final token = OmniCancelToken();
      final f1 = api.get<String>('/1');
      final f2 = api.get<String>('/2');
      final f3 = api.get<String>('/3', cancelToken: token);
      final f4 = api.get<String>('/4');

      await Future<void>.delayed(Duration.zero);
      expect(active, 2);
      expect(peak, 2);

      // Cancel f3 while queued before f1/f2 finish.
      token.cancel();
      await expectLater(f3, throwsA(isA<CancelledFailure>()));

      // Finish first two slots -> f4 runs without deadlock.
      gates[0].complete();
      gates[1].complete();
      await Future<void>.delayed(Duration.zero);
      expect(gates, hasLength(3));
      gates[2].complete();

      expect(await Future.wait([f1, f2, f4]), ['/1', '/2', '/4']);
      expect(peak, 2);
    });
  });
}
