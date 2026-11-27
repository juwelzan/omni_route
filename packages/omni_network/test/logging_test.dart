import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

final class ListSink implements LogSink {
  final records = <NetworkLogRecord>[];
  @override
  void log(NetworkLogRecord record) => records.add(record);
  String get all => records.map((r) => r.message).join('\n');
}

final class ThrowingSink implements LogSink {
  @override
  void log(NetworkLogRecord record) => throw StateError('sink broke');
}

/// Values that must never appear in any log output.
const secrets = [
  'BEARER-SECRET',
  'COOKIE-SECRET',
  'Q-SECRET',
  'PW-SECRET',
  'NESTED-SECRET',
  'SET-COOKIE-SECRET',
  'FORM-SECRET',
  'USERINFO-SECRET',
  'APIKEY-SECRET',
];

void main() {
  late MockTransport mock;
  late ListSink sink;

  OmniNetwork client({
    bool enable = true,
    bool bodies = true,
    LogSink? s,
    Redactor redactor = const Redactor(),
  }) => OmniNetwork(
    baseUrl: 'https://user:USERINFO-SECRET@api.example.com',
    headers: {'Authorization': 'Bearer BEARER-SECRET'},
    transport: mock,
    enableLogging: enable,
    logSink: s ?? sink,
    logBodies: bodies,
    redactor: redactor,
    timeout: const Duration(milliseconds: 50),
  );

  setUp(() {
    sink = ListSink();
    mock = MockTransport(
      (_) => OmniRawResponse(
        statusCode: 200,
        headers: {
          'Content-Type': 'application/json',
          'Set-Cookie': 'sid=SET-COOKIE-SECRET',
        },
        bodyBytes: utf8.encode(
          jsonEncode({
            'access_token': 'BEARER-SECRET',
            'user': {'name': 'Ana', 'refreshToken': 'NESTED-SECRET'},
          }),
        ),
      ),
    );
  });

  test('disabled by default: sink never called', () async {
    final api = OmniNetwork(
      baseUrl: 'https://h.io',
      transport: mock,
      logSink: sink,
    );
    addTearDown(api.close);
    expect(api.enableLogging, isFalse);
    await api.sendRaw(const OmniRequest.get('/a'));
    await api.get<dynamic>('/a');
    expect(sink.records, isEmpty);
  });

  test(
    'enableLogging: false with custom sink logs nothing, even errors',
    () async {
      final api = client(enable: false);
      addTearDown(api.close);
      mock.handler = (_) => throw const ConnectionFailure('down');
      await expectLater(
        api.sendRaw(const OmniRequest.get('/a')),
        throwsA(isA<ConnectionFailure>()),
      );
      expect(sink.records, isEmpty);
    },
  );

  test('request + response logged with correlation id', () async {
    final api = client();
    addTearDown(api.close);
    await api.sendRaw(const OmniRequest.get('/users', query: {'page': 2}));
    await api.sendRaw(const OmniRequest.get('/users'));
    expect(sink.records.map((r) => (r.kind, r.requestId)), [
      (NetworkLogKind.request, 1),
      (NetworkLogKind.response, 1),
      (NetworkLogKind.request, 2),
      (NetworkLogKind.response, 2),
    ]);
    final res = sink.records[1];
    expect(res.statusCode, 200);
    expect(res.method, 'GET');
    expect(res.url, 'https://api.example.com/users?page=2');
    expect(res.duration, isNotNull);
    expect(sink.records.first.message, startsWith('[OmniNetwork #1] --> GET'));
  });

  test('no secret appears anywhere in the output', () async {
    final api = client();
    addTearDown(api.close);
    await api.sendRaw(
      OmniRequest.post(
        '/login',
        query: {'access_token': 'Q-SECRET', 'q': 'visible'},
        headers: {'Cookie': 'a=COOKIE-SECRET', 'X-Api-Key': 'APIKEY-SECRET'},
        body: {
          'username': 'ana',
          'password': 'PW-SECRET',
          'profile': {'session_id': 'NESTED-SECRET'},
          'list': [
            {'client_secret': 'NESTED-SECRET'},
          ],
        },
      ),
    );
    await api.sendRaw(
      const OmniRequest.post(
        '/form',
        body: 'user=ana&password=FORM-SECRET',
        headers: {'content-type': 'application/x-www-form-urlencoded'},
      ),
    );
    final out =
        sink.all +
        sink.records.map((r) => '${r.headers}${r.body}${r.url}').join();
    for (final s in secrets) {
      expect(out, isNot(contains(s)), reason: '$s leaked');
    }
    // Non-secret data stays readable.
    expect(out, contains('visible'));
    expect(out, contains('"username":"ana"'));
    expect(out, contains('user=ana'));
    expect(out, contains('access_token=***'));
    expect(out, contains('authorization: ***'));
  });

  test('errors are logged without secrets', () async {
    final api = client();
    addTearDown(api.close);
    mock.handler = (_) => Completer<OmniRawResponse>().future;
    await expectLater(
      api.sendRaw(const OmniRequest.get('/slow', query: {'token': 'Q-SECRET'})),
      throwsA(isA<TimeoutFailure>()),
    );
    final err = sink.records.last;
    expect(err.kind, NetworkLogKind.error);
    expect(err.error, startsWith('TimeoutFailure'));
    expect(err.url, 'https://api.example.com/slow?token=***');
    for (final s in secrets) {
      expect(sink.all, isNot(contains(s)));
    }
  });

  test('RequestFailure before sending is logged as error', () async {
    final api = client();
    addTearDown(api.close);
    await expectLater(
      api.sendRaw(OmniRequest.post('/a', body: Object())),
      throwsA(isA<RequestFailure>()),
    );
    expect(sink.records.single.kind, NetworkLogKind.error);
  });

  test(
    'binary, unknown and multipart bodies are summarised, not shown',
    () async {
      final api = client();
      addTearDown(api.close);
      await api.sendRaw(
        OmniRequest.post(
          '/up',
          body: Uint8List.fromList(utf8.encode('PW-SECRET')),
        ),
      );
      await api.sendRaw(
        OmniRequest.post(
          '/up',
          body: utf8.encode('PW-SECRET'),
          headers: {'content-type': 'multipart/form-data; boundary=x'},
        ),
      );
      expect(
        sink.all,
        contains('<9 bytes, application/octet-stream, not shown>'),
      );
      expect(sink.all, contains('multipart/form-data'));
      expect(sink.all, isNot(contains('PW-SECRET')));
    },
  );

  test('long bodies logged whole; logBodies: false omits bodies', () async {
    final api = client();
    addTearDown(api.close);
    await api.sendRaw(OmniRequest.post('/t', body: 'x' * 20000));
    expect(sink.records.first.body, 'x' * 20000);

    final quiet = client(bodies: false);
    addTearDown(quiet.close);
    sink.records.clear();
    await quiet.sendRaw(const OmniRequest.post('/t', body: {'a': 1}));
    expect(sink.records.every((r) => r.body == null), isTrue);
  });

  test('invalid JSON with json content type is not echoed', () async {
    final api = client();
    addTearDown(api.close);
    mock.handler = (_) => OmniRawResponse(
      statusCode: 200,
      headers: {'content-type': 'application/json'},
      bodyBytes: utf8.encode('{password: PW-SECRET'),
    );
    await api.sendRaw(const OmniRequest.get('/x'));
    expect(sink.all, contains('invalid JSON, not shown'));
    expect(sink.all, isNot(contains('PW-SECRET')));
  });

  test('a throwing sink never breaks requests', () async {
    final api = client(s: ThrowingSink());
    addTearDown(api.close);
    final res = await api.sendRaw(const OmniRequest.get('/a'));
    expect(res.statusCode, 200);
  });

  test('extra headers/keys extend redaction', () async {
    final api = client(
      redactor: const Redactor(
        extraHeaders: {'X-Tenant'},
        extraKeys: {'national_id'},
      ),
    );
    addTearDown(api.close);
    await api.sendRaw(
      const OmniRequest.post(
        '/a',
        headers: {'X-Tenant': 'T-1'},
        body: {'nationalId': 'N-1'},
      ),
    );
    expect(sink.all, isNot(contains('T-1')));
    expect(sink.all, isNot(contains('N-1')));
  });

  group('Redactor rules', () {
    const r = Redactor();
    test('key matching', () {
      for (final k in [
        'password',
        'Access-Token',
        'refresh_token',
        'apiKey',
        'client_secret',
        'otp',
        'PIN',
        'sessionId',
        'x_signature',
      ]) {
        expect(r.isSecretKey(k), isTrue, reason: k);
      }
      for (final k in [
        'shipping',
        'opinion',
        'name',
        'keyboard_layout_x',
        'page',
        'monkey',
      ]) {
        expect(r.isSecretKey(k), isFalse, reason: k);
      }
    });
    test('uri strips user info and masks query', () {
      expect(
        r.uri(Uri.parse('https://u:p@h.io:8443/a?token=1&b=2&b=3')),
        'https://h.io:8443/a?token=***&b=2&b=3',
      );
    });

    test('text and textual bodies mask tokens, query secrets, and passwords', () {
      final errText = r.text(
        'WebSocketException connecting wss://u:p@h.io/ws?token=WS-SECRET&key=KEY-SECRET with Bearer TOP-SECRET password=MY-PASS',
      );
      expect(errText, isNot(contains('WS-SECRET')));
      expect(errText, isNot(contains('KEY-SECRET')));
      expect(errText, isNot(contains('TOP-SECRET')));
      expect(errText, isNot(contains('MY-PASS')));
      expect(errText, contains('token=***'));
      expect(errText, contains('key=***'));
      expect(errText, contains('Bearer ***'));

      final txtBody = r.body(
        utf8.encode('Authorization: Bearer BODY-TOK\npassword: SECRET-PW'),
        'text/plain',
      );
      expect(txtBody, isNot(contains('BODY-TOK')));
      expect(txtBody, isNot(contains('SECRET-PW')));
    });

    test('ws realtimeLogs mask query tokens and error URLs', () async {
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        wsBaseUrl: 'wss://api.test',
        enableLogging: true,
        wsConnector: (uri, _, _) => throw StateError('fail $uri'),
      );
      addTearDown(api.close);

      final logs = <WsLogRecord>[];
      final sub = api.realtimeLogs.listen(logs.add);
      addTearDown(sub.cancel);

      final ws = api.ws(
        '/live',
        query: {'token': 'WS-QUERY-SECRET', 'api_key': 'KEY-42'},
        maxReconnects: 0,
        minDelay: const Duration(milliseconds: 1),
      );
      await expectLater(ws.messages, emitsError(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);

      final combined = logs.map((e) => '${e.uri} ${e.summary}').join('\n');
      expect(combined, isNot(contains('WS-QUERY-SECRET')));
      expect(combined, isNot(contains('KEY-42')));
      expect(combined, contains('token=***'));
    });
  });
}
