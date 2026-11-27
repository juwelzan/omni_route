@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:omni_network/advanced.dart';
import 'package:test/test.dart';

CacheEntry _entry(String url, {int bodyLength = 10}) => CacheEntry(
  url: url,
  statusCode: 200,
  headers: const {'etag': '"v1"'},
  body: Uint8List.fromList(List<int>.generate(bodyLength, (i) => i % 256)),
  storedAt: DateTime.utc(2026),
  expiresAt: DateTime.utc(2027),
  vary: const {'accept': 'json'},
);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('omni_file_cache_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  List<String> files() => [
    for (final f in dir.listSync()) f.uri.pathSegments.last,
  ];

  test('round-trips an entry byte for byte', () async {
    final store = FileCacheStore(directory: dir.path);
    final original = _entry('https://a.test/x', bodyLength: 300000);
    await store.set('k', original);
    final read = await store.get('k');
    expect(read, isNotNull);
    expect(read!.url, original.url);
    expect(read.statusCode, 200);
    expect(read.etag, '"v1"');
    expect(read.vary, {'accept': 'json'});
    expect(read.body, original.body);
    expect(read.expiresAt, original.expiresAt);
  });

  test('a miss returns null without creating files', () async {
    final store = FileCacheStore(directory: dir.path);
    expect(await store.get('missing'), isNull);
    expect(files(), isEmpty);
  });

  test('survives a restart (index rebuilt from disk)', () async {
    await FileCacheStore(directory: dir.path).set('k', _entry('u'));
    final reopened = FileCacheStore(directory: dir.path);
    expect((await reopened.get('k'))?.url, 'u');
  });

  test('removeUrl deletes every key stored for that url only', () async {
    final store = FileCacheStore(directory: dir.path);
    await store.set('k1', _entry('https://a.test/list'));
    await store.set('k2', _entry('https://a.test/list'));
    await store.set('k3', _entry('https://a.test/other'));
    await store.removeUrl('https://a.test/list');
    expect(await store.get('k1'), isNull);
    expect(await store.get('k2'), isNull);
    expect(await store.get('k3'), isNotNull);
    expect(files(), hasLength(1));
  });

  test('evicts least recently used past maxEntries', () async {
    final store = FileCacheStore(directory: dir.path, maxEntries: 2);
    await store.set('a', _entry('a'));
    await store.set('b', _entry('b'));
    await store.get('a'); // a is now most recently used
    await store.set('c', _entry('c'));
    expect(await store.get('b'), isNull);
    expect(await store.get('a'), isNotNull);
    expect(await store.get('c'), isNotNull);
    expect(files(), hasLength(2));
  });

  test('evicts past maxBytes and skips oversized entries', () async {
    final store = FileCacheStore(directory: dir.path, maxBytes: 2000);
    await store.set('big', _entry('big', bodyLength: 5000));
    expect(await store.get('big'), isNull);
    await store.set('a', _entry('a', bodyLength: 800));
    await store.set('b', _entry('b', bodyLength: 800));
    await store.set('c', _entry('c', bodyLength: 800));
    expect(await store.get('a'), isNull);
    expect(await store.get('c'), isNotNull);
  });

  test('corrupted, temp and legacy files are removed', () async {
    File('${dir.path}/junk.omc').writeAsStringSync('not a cache file');
    File('${dir.path}/x.omc.tmp.1_2').writeAsStringSync('half');
    File('${dir.path}/legacy.json').writeAsStringSync('{}');
    final store = FileCacheStore(directory: dir.path);
    expect(await store.get('anything'), isNull);
    expect(files(), isEmpty);
  });

  test('a file corrupted after indexing is dropped on read', () async {
    final store = FileCacheStore(directory: dir.path);
    await store.set('k', _entry('u'));
    final file = dir.listSync().single as File;
    file.writeAsBytesSync([1, 2, 3]);
    expect(await store.get('k'), isNull);
    expect(files(), isEmpty);
  });

  test('concurrent writes keep index and disk consistent', () async {
    final store = FileCacheStore(directory: dir.path, maxEntries: 5);
    await Future.wait([
      for (var i = 0; i < 20; i++) store.set('k$i', _entry('u$i')),
    ]);
    expect(files().where((f) => f.endsWith('.omc')), hasLength(5));
    await store.clear();
    expect(files(), isEmpty);
  });
}
