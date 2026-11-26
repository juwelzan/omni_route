@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Names an app sees with `import 'package:omni_network/omni_network.dart'`.
const simple = [
  'OmniNetwork',
  'OmniRequest',
  'HttpMethod',
  'OmniResponse',
  'OmniRawResponse',
  'Endpoint',
  'OmniNetworkException',
  'HttpFailure',
  'DecodeFailure',
  'TimeoutFailure',
  'TimeoutStage',
  'ConnectionFailure',
  'ConnectionReason',
  'CancelledFailure',
  'ClosedFailure',
  'AuthFailure',
  'CircuitOpenFailure',
  'RequestFailure',
  'Result',
  'Ok',
  'Err',
  'OmniAuth',
  'LogOptions',
  'Tokens',
  'AuthState',
  'OmniInterceptor',
  'OmniCancelToken',
  'RetryPolicy',
  'OmniCache',
  'CachePolicy',
  'ResponseSource',
  'UploadFile',
  'OmniPager',
  'PagePagination',
  'OffsetPagination',
  'CursorPagination',
  'RequestController',
  'RequestState',
  'RequestIdle',
  'RequestLoading',
  'RequestSuccess',
  'RequestEmpty',
  'RequestError',
];

/// Low-level names that must NOT leak into the simple import.
const advancedOnly = [
  'BearerAuth',
  'PrettyLogSink',
  'AuthProvider',
  'TokenStorage',
  'MemoryTokenStorage',
  'Transport',
  'TransportRequest',
  'StreamedResponse',
  'CancelSignal',
  'DioTransport',
  'CacheStore',
  'CacheEntry',
  'MemoryCacheStore',
  'ResponseAdapter',
  'EnvelopeResponseAdapter',
  'LogSink',
  'PrintLogSink',
  'NetworkLogRecord',
  'Redactor',
  'CircuitBreaker',
  'OfflineQueue',
  'QueueStore',
  'QueuedRequest',
  'MultipartBody',
  'OmniStreamResponse',
  'EndpointRegistry',
  'PaginationStrategy',
  'PageContext',
  'LinkHeaderPagination',
  'JsonDecoder',
  'ProgressCallback',
  'CurlImport',
];

const testingOnly = [
  'OmniMock',
  'MockResponse',
  'MockRequest',
  'MockTransport',
];

/// Analyzes a file that mentions [names] as types under [imports] and
/// returns the names reported as undefined.
Future<Set<String>> undefined(List<String> imports, List<String> names) async {
  final file = File('test/_surface_${pid}_${names.length}.dart');
  await file.writeAsString(
    [
      for (final i in imports) "import 'package:omni_network/$i';",
      'void main() {',
      for (final (i, n) in names.indexed)
        '  // ignore: unused_local_variable\n  $n? v$i;',
      '}',
    ].join('\n'),
  );
  try {
    final r = await Process.run('dart', [
      'analyze',
      '--format=machine',
      file.path,
    ]);
    final out = '${r.stdout}${r.stderr}';
    return {
      for (final n in names)
        if (out.contains("Undefined class '$n'")) n,
    };
  } finally {
    await file.delete();
  }
}

/// Analyzes calls of the low-level methods under [import]; returns the
/// method names reported as undefined.
Future<Set<String>> undefinedMethods(String import) async {
  const methods = [
    'sendRaw',
    'send',
    'sendList',
    'openStream',
    'toCurl',
    'resolve',
  ];
  final file = File('test/_surface_m_$pid.dart');
  await file.writeAsString(
    [
      "import 'package:omni_network/$import';",
      'void f(OmniNetwork api, OmniRequest r) {',
      for (final m in methods) '  api.$m(r);',
      '}',
    ].join('\n'),
  );
  try {
    final r = await Process.run('dart', [
      'analyze',
      '--format=machine',
      file.path,
    ]);
    final out = '${r.stdout}${r.stderr}';
    return {
      for (final m in methods)
        if (out.contains("The method '$m' isn't defined")) m,
    };
  } finally {
    await file.delete();
  }
}

void main() {
  test('low-level methods only appear with advanced.dart', () async {
    expect(await undefinedMethods('omni_network.dart'), {
      'sendRaw',
      'send',
      'sendList',
      'openStream',
      'toCurl',
      'resolve',
    });
    expect(await undefinedMethods('advanced.dart'), isEmpty);
  });

  test('simple import exposes the app names', () async {
    expect(await undefined(['omni_network.dart'], simple), isEmpty);
  });

  test('simple import hides low-level and testing names', () async {
    expect(
      await undefined(['omni_network.dart'], [...advancedOnly, ...testingOnly]),
      {...advancedOnly, ...testingOnly},
    );
  });

  test('advanced.dart includes everything in the simple import', () async {
    expect(
      await undefined(['advanced.dart'], [...simple, ...advancedOnly]),
      isEmpty,
    );
  });

  test('testing.dart provides the mocks', () async {
    expect(await undefined(['testing.dart'], testingOnly), isEmpty);
  });
}
