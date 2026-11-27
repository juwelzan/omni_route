import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

OmniRawResponse json(int code, Object body) => OmniRawResponse(
  statusCode: code,
  headers: {'content-type': 'application/json'},
  bodyBytes: utf8.encode(jsonEncode(body)),
);

Uint8List payload(int n) =>
    Uint8List.fromList(List.generate(n, (i) => i % 251));

void main() {
  late MockTransport mock;
  late OmniNetwork api;

  setUp(() {
    mock = MockTransport((_) => json(200, {'ok': true}));
    api = OmniNetwork(
      baseUrl: 'https://h.io',
      transport: mock,
      timeout: const Duration(milliseconds: 80),
    );
  });
  tearDown(() => api.close());

  group('OmniCancelToken', () {
    test('cancels an in-flight request', () async {
      mock.handler = (_) => Completer<OmniRawResponse>().future;
      final token = OmniCancelToken();
      final f = api.get<dynamic>('/slow', cancelToken: token);
      await Future<void>.delayed(Duration.zero);
      expect(token.attachedRequests, 1);
      token.cancel();
      await expectLater(f, throwsA(isA<CancelledFailure>()));
      expect(api.pendingRequests, 0);
      expect(mock.inFlight, 0);
    });

    test('already-cancelled token fails at once, nothing sent', () async {
      final token = OmniCancelToken()..cancel();
      await expectLater(
        api.get<dynamic>('/a', cancelToken: token),
        throwsA(isA<CancelledFailure>()),
      );
      expect(mock.requests, isEmpty);
    });

    test('one token cancels many; no listeners left afterwards', () async {
      mock.handler = (_) => Completer<OmniRawResponse>().future;
      final token = OmniCancelToken();
      final fs = [
        for (var i = 0; i < 5; i++)
          api.get<dynamic>('/r$i', cancelToken: token).asResult(),
      ];
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      final rs = await Future.wait(fs);
      expect(
        rs.map((r) => (r as Err).error),
        everyElement(isA<CancelledFailure>()),
      );
      expect(token.attachedRequests, 0);
    });

    test('finished requests detach from a long-lived token', () async {
      final token = OmniCancelToken();
      for (var i = 0; i < 50; i++) {
        await api.get<dynamic>('/a', cancelToken: token);
      }
      expect(token.attachedRequests, 0);
    });
  });

  group('MultipartBody', () {
    test('exact encoding and length', () async {
      final body = MultipartBody(
        boundary: 'B',
        fields: {'title': 'Hi', 'na"me\r\n': 'x'},
        files: [
          UploadFile.fromBytes(
            'file',
            utf8.encode('DATA'),
            filename: 'a.txt',
            contentType: 'text/plain',
          ),
        ],
      );
      final bytes = (await body.open().toList()).expand((c) => c).toList();
      expect(
        utf8.decode(bytes),
        '--B\r\ncontent-disposition: form-data; name="title"\r\n\r\nHi\r\n'
        '--B\r\ncontent-disposition: form-data; name="na%22me%0D%0A"\r\n\r\nx\r\n'
        '--B\r\ncontent-disposition: form-data; name="file"; '
        'filename="a.txt"\r\ncontent-type: text/plain\r\n\r\nDATA\r\n'
        '--B--\r\n',
      );
      expect(body.length, bytes.length);
      expect(body.contentType, 'multipart/form-data; boundary=B');
    });

    test('rejects CRLF injection in boundary and contentType', () {
      expect(
        () => MultipartBody(boundary: 'bad\r\nX-Injected: 1'),
        throwsArgumentError,
      );
      expect(
        () => UploadFile.fromBytes(
          'file',
          const [1, 2],
          filename: 'a.txt',
          contentType: 'text/plain\r\nX-Injected: evil',
        ),
        throwsArgumentError,
      );
      expect(
        () => UploadFile.fromStream(
          'file',
          () => const Stream.empty(),
          length: 0,
          filename: 'a.txt',
          contentType: 'text/plain\nX-Injected: evil',
        ),
        throwsArgumentError,
      );
    });

    test('random boundaries differ', () {
      expect(MultipartBody().boundary, isNot(MultipartBody().boundary));
    });
  });

  group('upload', () {
    test('sends multipart with progress and decodes the response', () async {
      mock.handler = (_) => json(201, {'id': 7});
      final progress = <(int, int?)>[];
      final result = await api.upload<Map<String, dynamic>>(
        '/files',
        fields: {'album': 'x'},
        files: [
          UploadFile.fromStream(
            'file',
            () => Stream.fromIterable([payload(3000), payload(2000)]),
            length: 5000,
            filename: 'p.bin',
          ),
        ],
        onProgress: (s, t) => progress.add((s, t)),
      );
      expect(result, {'id': 7});
      final r = mock.requests.single;
      expect(r.method, HttpMethod.post);
      expect(r.headers['content-type'], startsWith('multipart/form-data'));
      final total = progress.last.$2!;
      expect(progress.last.$1, total);
      expect(r.body!.length, total);
      final sent = progress.map((p) => p.$1).toList();
      expect(sent, orderedEquals([...sent]..sort()));
    });

    test('wrong declared length fails with RequestFailure', () async {
      await expectLater(
        api.upload<dynamic>(
          '/f',
          files: [
            UploadFile.fromStream(
              'f',
              () => Stream.value([1, 2]),
              length: 5,
              filename: 'x',
            ),
          ],
        ),
        throwsA(isA<RequestFailure>()),
      );
    });

    test(
      'body stream is reopened when replayed after a token refresh',
      () async {
        var opens = 0;
        var valid = 'T1';
        mock.handler = (r) => r.headers['authorization'] == 'Bearer $valid'
            ? json(200, {'ok': true})
            : json(401, {});
        var stored = 'OLD';
        final authed = OmniNetwork(
          baseUrl: 'https://h.io',
          transport: mock,
          auth: BearerAuth(token: () => stored, refresh: () => stored = valid),
        );
        addTearDown(authed.close);
        await authed.upload<dynamic>(
          '/f',
          files: [
            UploadFile.fromStream(
              'f',
              () {
                opens++;
                return Stream.value(payload(10));
              },
              length: 10,
              filename: 'x',
            ),
          ],
        );
        expect(opens, 2);
        expect(mock.requests.map((r) => r.body!.length).toSet(), hasLength(1));
      },
    );

    test('logs summarise multipart bodies', () async {
      final out = StringBuffer();
      final logged = OmniNetwork(
        baseUrl: 'https://h.io',
        transport: mock,
        enableLogging: true,
        logSink: _Sink(out),
      );
      addTearDown(logged.close);
      await logged.upload<dynamic>(
        '/f',
        files: [
          UploadFile.fromBytes('f', utf8.encode('PW-SECRET'), filename: 'x'),
        ],
      );
      expect('$out', contains('multipart/form-data'));
      expect('$out', contains('not shown'));
      expect('$out', isNot(contains('PW-SECRET')));
    });
  });

  group('downloadBytes', () {
    setUp(() {
      mock.chunkSize = 1000;
      mock.handler = (_) => OmniRawResponse(
        statusCode: 200,
        headers: {'content-length': '5500'},
        bodyBytes: payload(5500),
      );
    });

    test('returns bytes with monotonic progress and total', () async {
      final progress = <(int, int?)>[];
      final bytes = await api.downloadBytes(
        '/big',
        onProgress: (r, t) => progress.add((r, t)),
      );
      expect(bytes, payload(5500));
      expect(progress.map((p) => p.$1), [1000, 2000, 3000, 4000, 5000, 5500]);
      expect(progress.every((p) => p.$2 == 5500), isTrue);
    });

    test('non-2xx throws HttpFailure with the error body', () async {
      mock.handler = (_) => json(404, {'error': 'gone'});
      await expectLater(
        api.downloadBytes('/x'),
        throwsA(
          isA<HttpFailure>().having((e) => e.response.json, 'body', {
            'error': 'gone',
          }),
        ),
      );
    });

    test('no overall deadline by default: slow but steady succeeds', () async {
      // Client timeout is 80 ms; the whole download takes ~6 x 30 ms.
      mock.chunkDelay = const Duration(milliseconds: 30);
      final bytes = await api.downloadBytes('/big');
      expect(bytes.length, 5500);
    });

    test('idle timeout when no data arrives', () async {
      mock.chunkDelay = const Duration(milliseconds: 200);
      await expectLater(
        api.downloadBytes(
          '/big',
          idleTimeout: const Duration(milliseconds: 40),
        ),
        throwsA(
          isA<TimeoutFailure>().having(
            (e) => e.timeout,
            'timeout',
            const Duration(milliseconds: 40),
          ),
        ),
      );
      expect(api.pendingRequests, 0);
    });

    test('explicit overall timeout applies', () async {
      mock.chunkDelay = const Duration(milliseconds: 30);
      await expectLater(
        api.downloadBytes('/big', timeout: const Duration(milliseconds: 70)),
        throwsA(isA<TimeoutFailure>()),
      );
    });

    test('cancel mid-download stops the stream', () async {
      mock.chunkDelay = const Duration(milliseconds: 10);
      final token = OmniCancelToken();
      final progress = <int>[];
      await expectLater(
        api.downloadBytes(
          '/big',
          cancelToken: token,
          onProgress: (r, _) {
            progress.add(r);
            if (r >= 2000) token.cancel();
          },
        ),
        throwsA(isA<CancelledFailure>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(progress.last, 2000);
      expect(mock.inFlight, 0);
    });

    test('close during download => ClosedFailure', () async {
      mock.chunkDelay = const Duration(milliseconds: 10);
      final f = api.downloadBytes('/big');
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await api.close();
      await expectLater(f, throwsA(isA<ClosedFailure>()));
    });
  });
}

final class _Sink implements LogSink {
  _Sink(this.out);
  final StringBuffer out;
  @override
  void log(NetworkLogRecord r) => out.writeln(r.message);
}
