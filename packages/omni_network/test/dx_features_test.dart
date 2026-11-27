import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:omni_network/advanced.dart';
import 'package:omni_network/src/transport/pin_verifier.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

final class _User {
  const _User(this.id, this.name);
  factory _User.fromJson(Map<String, dynamic> j) =>
      _User(j['id'] as int, j['name'] as String);
  final int id;
  final String name;
}

final class _Unregistered {
  const _Unregistered();
}

void main() {
  group('Global Decoders Registry', () {
    late OmniMock mock;
    late OmniNetwork api;

    setUp(() {
      mock = OmniMock()
        ..get('/me', (_) => MockResponse.json({'id': 1, 'name': 'Ana'}))
        ..get('/users', (r) {
          final page = int.parse(r.query['page'] ?? '1');
          return MockResponse.json(
            page == 1
                ? [
                    {'id': 1, 'name': 'Ana'},
                    {'id': 2, 'name': 'Bo'},
                  ]
                : const [],
          );
        })
        ..post('/users', (_) => MockResponse.json({'id': 2, 'name': 'Post'}))
        ..put('/users/2', (_) => MockResponse.json({'id': 2, 'name': 'Put'}))
        ..patch(
          '/users/2',
          (_) => MockResponse.json({'id': 2, 'name': 'Patch'}),
        )
        ..delete(
          '/users/2',
          (_) => MockResponse.json({'id': 2, 'name': 'Delete'}),
        )
        ..post('/form', (r) => MockResponse.json({'id': 3, 'name': r.text}))
        ..get(
          '/bad-list',
          (_) => MockResponse.json([
            {'x': 1},
          ]),
        );

      api = OmniNetwork(
        baseUrl: 'https://h.io',
        transport: mock,
        decoders: {_User: _User.fromJson},
      );
    });

    tearDown(() => api.close());

    test(
      'decodes get, getList, post, put, patch, delete without decoder param',
      () async {
        final me = await api.get<_User>('/me');
        expect((me.id, me.name), (1, 'Ana'));

        final list = await api.getList<_User>('/users');
        expect(list.map((u) => u.name), ['Ana', 'Bo']);

        final created = await api.post<_User>('/users', body: {'name': 'Post'});
        expect(created.name, 'Post');

        final updated = await api.put<_User>('/users/2', body: {'name': 'Put'});
        expect(updated.name, 'Put');

        final patched = await api.patch<_User>(
          '/users/2',
          body: {'name': 'Patch'},
        );
        expect(patched.name, 'Patch');

        final deleted = await api.delete<_User>('/users/2');
        expect(deleted.name, 'Delete');
      },
    );

    test('explicit per-call decoder overrides registered decoder', () async {
      final custom = await api.get<_User>(
        '/me',
        decoder: (j) => _User(j['id'] as int, '${j['name']}!'),
      );
      expect(custom.name, 'Ana!');
    });

    test(
      'watch, watchList, paginate, and sendList use global decoders',
      () async {
        final ctrl = api.watch<_User>('/me');
        addTearDown(ctrl.close);
        await ctrl.stream.firstWhere((s) => s is RequestSuccess<_User>);
        expect((ctrl.state as RequestSuccess<_User>).data.name, 'Ana');

        final listCtrl = api.watchList<_User>('/users');
        addTearDown(listCtrl.close);
        await listCtrl.stream.firstWhere(
          (s) => s is RequestSuccess<List<_User>>,
        );
        expect((listCtrl.state as RequestSuccess<List<_User>>).data.length, 2);

        final pager = api.paginate<_User>(
          '/users',
          strategy: const PagePagination(pageSize: 2),
        );
        addTearDown(pager.close);
        final page1 = await pager.next();
        expect(page1.map((u) => u.name), ['Ana', 'Bo']);

        final rawList = await api.sendList<_User>(
          const OmniRequest.get('/users'),
        );
        expect(rawList.data.first.name, 'Ana');
      },
    );

    test('unregistered list type fails cleanly with DecodeFailure', () async {
      await expectLater(
        api.getList<_Unregistered>('/bad-list'),
        throwsA(isA<DecodeFailure>()),
      );
    });
  });

  group('postForm', () {
    test(
      'encodes URL-encoded form body, preserves overrides and decodes',
      () async {
        final mock = MockTransport(
          (r) => OmniRawResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            bodyBytes: utf8.encode(
              jsonEncode({'id': 9, 'name': utf8.decode(r.body!)}),
            ),
          ),
        );
        final api = OmniNetwork(
          baseUrl: 'https://h.io',
          transport: mock,
          decoders: {_User: _User.fromJson},
        );
        addTearDown(api.close);

        final user = await api.postForm<_User>(
          '/oauth/token',
          fields: {
            'grant_type': 'refresh_token',
            'note': 'hello world!',
            'ignored': null,
            'tags': ['a', 'b'],
          },
        );
        final sent = mock.requests.single;
        expect(sent.method, HttpMethod.post);
        expect(
          sent.headers['content-type'],
          'application/x-www-form-urlencoded',
        );
        expect(
          user.name,
          'grant_type=refresh_token&note=hello+world%21&tags=a&tags=b',
        );

        final full = await api.postFormResponse<_User>(
          '/oauth/token',
          fields: {'k': 'v'},
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          },
        );
        expect(full.statusCode, 200);
        expect(
          mock.requests.last.headers['content-type'],
          'application/x-www-form-urlencoded; charset=utf-8',
        );
      },
    );
  });

  group('Endpoint DX & :id routing enhancements', () {
    test('supports :id and mixed {id} templates plus Registry match', () async {
      final colon = Endpoint.get<_User>('/users/:id/posts/:postId');
      expect(colon.pathParams, ['id', 'postId']);
      expect(
        colon.expand({'id': 42, 'postId': 'a/b'}),
        '/users/42/posts/a%2Fb',
      );

      final mixed = Endpoint.get<String>('/orgs/{org}/members/:memberId');
      expect(mixed.pathParams, ['org', 'memberId']);
      expect(mixed.expand({'org': 'o', 'memberId': 7}), '/orgs/o/members/7');

      final action = Endpoint.post<void>(
        '/v1/items:batchGet',
        query: {'dryRun': true},
      );
      expect(action.pathParams, isEmpty);
      expect(action.expand({}), '/v1/items:batchGet');

      final reg = EndpointRegistry([colon, action]);
      expect(reg.match(HttpMethod.get, '/users/10/posts/99'), same(colon));
      expect(reg.match(HttpMethod.post, '/v1/items:batchGet'), same(action));
    });

    test(
      'post/put/patch/delete endpoints preserve default query & call overrides',
      () async {
        var hits = 0;
        final mock = MockTransport((r) {
          hits++;
          if (hits == 1 && r.method == HttpMethod.post) {
            return OmniRawResponse(statusCode: 503);
          }
          return OmniRawResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            bodyBytes: utf8.encode(
              jsonEncode({
                'wrapped': {
                  'id': 1,
                  'name':
                      '${r.method.verb}:${r.uri.query}:${r.headers['authorization'] ?? 'none'}',
                },
              }),
            ),
          );
        });

        final api = OmniNetwork(
          baseUrl: 'https://h.io',
          transport: mock,
          token: () => 'SECRET',
          decoders: {_User: _User.fromJson},
        );
        addTearDown(api.close);

        final create = Endpoint.post<_User>('/users', query: {'v': 2});
        final update = Endpoint.put<_User>('/users/:id', query: {'v': 2});
        final patch = Endpoint.patch<_User>('/users/:id', query: {'v': 2});
        final del = Endpoint.delete<_User>('/users/:id', query: {'hard': true});

        final created = await api.call(
          create,
          query: {'extra': 1},
          retry: const RetryPolicy(
            maxAttempts: 2,
            methods: {HttpMethod.post},
            baseDelay: Duration(milliseconds: 1),
            jitter: false,
          ),
          auth: false,
          adapter: const EnvelopeResponseAdapter(dataKey: 'wrapped'),
        );
        expect((created.id, created.name), (1, 'POST:v=2&extra=1:none'));
        expect(hits, 2);

        final updated = await api.call(
          update,
          path: {'id': 5},
          adapter: const EnvelopeResponseAdapter(dataKey: 'wrapped'),
        );
        expect(updated.name, contains('PUT:v=2:Bearer SECRET'));

        final patched = await api.call(
          patch,
          path: {'id': 5},
          adapter: const EnvelopeResponseAdapter(dataKey: 'wrapped'),
        );
        expect(patched.name, contains('PATCH:v=2'));

        final deleted = await api.call(
          del,
          path: {'id': 5},
          adapter: const EnvelopeResponseAdapter(dataKey: 'wrapped'),
        );
        expect(deleted.name, contains('DELETE:hard=true'));

        // Endpoint.getList without inline decoder falls back to global registry.
        final listEndpoint = Endpoint.getList<_User>('/list');
        final mock2 = MockTransport(
          (_) => OmniRawResponse(
            statusCode: 200,
            headers: {'content-type': 'application/json'},
            bodyBytes: utf8.encode('[{"id":1,"name":"Reg"}]'),
          ),
        );
        final api2 = OmniNetwork(
          baseUrl: 'https://h.io',
          transport: mock2,
          decoders: {_User: _User.fromJson},
        );
        addTearDown(api2.close);
        final list = await api2.call(listEndpoint);
        expect(list.single.name, 'Reg');
      },
    );
  });

  group('CertificatePinMatcher parsing & validity', () {
    test('validates pin formats and checks cert validity dates', () {
      final sampleDer = Uint8List.fromList([1, 2, 3, 4, 5]);
      final digest = sha256.convert(sampleDer).bytes;
      final b64 = base64Encode(digest);

      final matcher = CertificatePinMatcher(['sha256/$b64']);
      final now = DateTime(2026, 1, 15);

      expect(
        matcher.matchesDer(
          sampleDer,
          startValidity: DateTime(2026, 1, 1),
          endValidity: DateTime(2026, 2, 1),
          now: now,
        ),
        isTrue,
      );
      expect(
        matcher.matchesDer(
          sampleDer,
          startValidity: DateTime(2025, 1, 1),
          endValidity: DateTime(2026, 1, 1),
          now: now,
        ),
        isFalse,
      );
      expect(() => CertificatePinMatcher(['']), throwsArgumentError);
      expect(
        () => CertificatePinMatcher(['not-a-valid-pin']),
        throwsArgumentError,
      );
    });
  });
}
