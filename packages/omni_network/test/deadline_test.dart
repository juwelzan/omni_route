import 'dart:async';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

const _fast = RetryPolicy(
  maxAttempts: 5,
  baseDelay: Duration(milliseconds: 1),
  jitter: false,
);

OmniRawResponse _ok() => OmniRawResponse(statusCode: 200);

Future<OmniRawResponse> _hang() => Completer<OmniRawResponse>().future;

/// Runs [body] and returns (error or null, elapsed ms).
Future<(Object?, int)> _timed(Future<Object?> Function() body) async {
  final watch = Stopwatch()..start();
  Object? error;
  try {
    await body();
  } catch (e) {
    error = e;
  }
  return (error, watch.elapsedMilliseconds);
}

void main() {
  late MockTransport mock;
  late OmniNetwork api;
  late MockHandler handler;

  OmniNetwork client({
    Duration timeout = const Duration(milliseconds: 150),
    RetryPolicy? retry,
    int? maxConcurrentRequests,
    AuthProvider? auth,
  }) => OmniNetwork(
    baseUrl: 'https://h.io',
    transport: mock,
    timeout: timeout,
    retry: retry,
    maxConcurrentRequests: maxConcurrentRequests,
    auth: auth,
  );

  setUp(() {
    handler = (_) => _ok();
    mock = MockTransport((r) => handler(r));
    api = client();
  });
  tearDown(() => api.close());

  test('first attempt times out at the deadline and is cancelled', () async {
    handler = (_) => _hang();
    final (e, ms) = await _timed(() => api.sendRaw(const OmniRequest.get('/')));
    expect(e, isA<TimeoutFailure>());
    expect(ms, inInclusiveRange(140, 400));
    expect(mock.inFlight, 0);
  });

  test('retries share one deadline; none starts after it', () async {
    api = client(retry: _fast);
    handler = (_) => _hang();
    final (e, ms) = await _timed(() => api.sendRaw(const OmniRequest.get('/')));
    expect(e, isA<TimeoutFailure>());
    // Before: every attempt got a fresh 150 ms (5 × 150 ms).
    expect(ms, lessThan(400));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(mock.requests, hasLength(1));
  });

  test('a retry attempt only gets the time that is left', () async {
    api = client(timeout: const Duration(milliseconds: 400), retry: _fast);
    var n = 0;
    handler = (_) async {
      if (++n == 1) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        throw const ConnectionFailure('down');
      }
      return _hang();
    };
    final (e, ms) = await _timed(() => api.sendRaw(const OmniRequest.get('/')));
    expect(e, isA<TimeoutFailure>());
    expect((e! as TimeoutFailure).timeout, const Duration(milliseconds: 400));
    // Before: 200 ms + a fresh 400 ms for the retry.
    expect(ms, lessThan(560));
    expect(mock.requests, hasLength(2));
  });

  test('a backoff that would pass the deadline is not waited for', () async {
    api = client(
      retry: const RetryPolicy(
        baseDelay: Duration(milliseconds: 500),
        jitter: false,
      ),
    );
    handler = (_) => throw const ConnectionFailure('down');
    final (e, ms) = await _timed(() => api.sendRaw(const OmniRequest.get('/')));
    // The real cause, at once, instead of sleeping into a timeout.
    expect(e, isA<ConnectionFailure>());
    expect(ms, lessThan(100));
    expect(mock.requests, hasLength(1));
  });

  test('a Retry-After past the deadline returns the response', () async {
    api = client(retry: _fast);
    handler = (_) =>
        OmniRawResponse(statusCode: 503, headers: {'retry-after': '1'});
    final res = await api.sendRaw(const OmniRequest.get('/'));
    expect(res.statusCode, 503);
    expect(mock.requests, hasLength(1));
  });

  test('cancelling during a retry delay stops at once', () async {
    api = client(
      timeout: const Duration(seconds: 10),
      retry: const RetryPolicy(baseDelay: Duration(seconds: 2), jitter: false),
    );
    handler = (_) => throw const ConnectionFailure('down');
    final token = OmniCancelToken();
    Timer(const Duration(milliseconds: 50), token.cancel);
    final (e, ms) = await _timed(
      () => api.sendRaw(OmniRequest.get('/', cancelToken: token)),
    );
    expect(e, isA<CancelledFailure>());
    expect(ms, lessThan(500));
    expect(mock.requests, hasLength(1));
  });

  test('cancelAll during a retry delay stops at once', () async {
    api = client(
      timeout: const Duration(seconds: 10),
      retry: const RetryPolicy(baseDelay: Duration(seconds: 2), jitter: false),
    );
    handler = (_) => throw const ConnectionFailure('down');
    Timer(const Duration(milliseconds: 50), api.cancelAll);
    final (e, ms) = await _timed(() => api.sendRaw(const OmniRequest.get('/')));
    expect(e, isA<CancelledFailure>());
    expect(ms, lessThan(500));
    expect(mock.requests, hasLength(1));
  });

  test('closing the client during a retry delay stops it', () async {
    api = client(
      timeout: const Duration(seconds: 10),
      retry: const RetryPolicy(baseDelay: Duration(seconds: 2), jitter: false),
    );
    handler = (_) => throw const ConnectionFailure('down');
    Timer(const Duration(milliseconds: 50), api.close);
    final (e, ms) = await _timed(() => api.sendRaw(const OmniRequest.get('/')));
    expect(e, isA<ClosedFailure>());
    expect(ms, lessThan(500));
  });

  test('waiting for a concurrency slot counts towards the deadline', () async {
    api = client(maxConcurrentRequests: 1);
    final release = Completer<OmniRawResponse>();
    handler = (_) => release.future;
    final first = api.sendRaw(
      const OmniRequest.get('/a', timeout: Duration(seconds: 10)),
    );
    final (e, ms) = await _timed(
      () => api.sendRaw(const OmniRequest.get('/b')),
    );
    expect(e, isA<TimeoutFailure>());
    expect(ms, inInclusiveRange(140, 400));
    // The timed-out waiter gave its place back.
    release.complete(_ok());
    await first;
    handler = (_) => _ok();
    expect((await api.sendRaw(const OmniRequest.get('/c'))).statusCode, 200);
  });

  test('waiting for a token counts towards the deadline', () async {
    api = client(auth: BearerAuth(token: () => _hang().then((_) => 't')));
    final (e, ms) = await _timed(() => api.sendRaw(const OmniRequest.get('/')));
    expect(e, isA<TimeoutFailure>());
    expect(ms, lessThan(400));
    expect(mock.requests, isEmpty);
  });

  test('a slow but successful retry within the deadline succeeds', () async {
    api = client(timeout: const Duration(milliseconds: 400), retry: _fast);
    var n = 0;
    handler = (_) async {
      if (++n == 1) throw const ConnectionFailure('down');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return _ok();
    };
    final res = await api.sendRaw(const OmniRequest.get('/'));
    expect(res.statusCode, 200);
    expect(mock.requests, hasLength(2));
  });

  test('a finished request leaves nothing running', () async {
    api = client(retry: _fast);
    handler = (_) => _hang();
    await expectLater(
      api.sendRaw(const OmniRequest.get('/')),
      throwsA(isA<TimeoutFailure>()),
    );
    expect(mock.inFlight, 0);
    // Close resolves at once: no pending request or retry is left.
    await api.close().timeout(const Duration(milliseconds: 200));
  });
}
