import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:omni_network_flutter/omni_network_flutter.dart';

OmniRawResponse _json(Object body, [int status = 200]) => OmniRawResponse(
  statusCode: status,
  headers: const {'content-type': 'application/json'},
  bodyBytes: utf8.encode(jsonEncode(body)),
);

void main() {
  group('OmniRequestBuilder', () {
    testWidgets('auto-loads idle controller and renders error retry -> success', (
      tester,
    ) async {
      var fail = true;
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((_) {
          if (fail) return _json({'err': true}, 500);
          return _json({'name': 'Omni'});
        }),
      );
      addTearDown(api.close);

      final controller = api.watch<Map<String, dynamic>>(
        '/hello',
        autoLoad: false,
      );
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: OmniRequestBuilder<Map<String, dynamic>>(
            controller: controller,
            builder: (_, data, refreshing) =>
                Text('${data['name']}${refreshing ? '...' : ''}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Omni'), findsOneWidget);
    });

    testWidgets('renders emptyBuilder on RequestEmpty', (tester) async {
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((_) => _json(const <Object>[])),
      );
      addTearDown(api.close);

      final controller = api.watchList<String>(
        '/list',
        decoder: (j) => j['v'] as String,
      );
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: OmniRequestBuilder<List<String>>(
            controller: controller,
            emptyBuilder: (_) => const Text('Nothing here'),
            builder: (_, data, _) => Text('Count: ${data.length}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing here'), findsOneWidget);
    });
  });

  group('OmniPagedListView', () {
    testWidgets('loads page 1 automatically and page 2 when scrolling', (
      tester,
    ) async {
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((req) {
          final page = int.parse(req.uri.queryParameters['page'] ?? '1');
          if (page == 1) {
            return _json([
              for (var i = 0; i < 15; i++) {'id': 'item-$i'},
            ]);
          }
          if (page == 2) {
            return _json([
              for (var i = 15; i < 20; i++) {'id': 'item-$i'},
            ]);
          }
          return _json(const <Object>[]);
        }),
      );
      addTearDown(api.close);

      final pager = api.paginate<String>(
        '/feed',
        decoder: (j) => j['id'] as String,
        strategy: const PagePagination(pageSize: 15),
      );
      addTearDown(pager.close);

      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmniPagedListView<String>(
              pager: pager,
              scrollController: scrollController,
              itemBuilder: (_, item, _) => SizedBox(height: 80, child: Text(item)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(pager.items, hasLength(15));
      expect(find.text('item-0'), findsOneWidget);

      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(pager.pageCount, 2);
      expect(pager.items, hasLength(20));
    });

    testWidgets('renders emptyBuilder when page 1 returns empty list', (
      tester,
    ) async {
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: MockTransport((_) => _json(const <Object>[])),
      );
      addTearDown(api.close);

      final pager = api.paginate<String>(
        '/empty',
        decoder: (j) => j['id'] as String,
        strategy: const PagePagination(pageSize: 10),
      );
      addTearDown(pager.close);

      await tester.pumpWidget(
        MaterialApp(
          home: OmniPagedListView<String>(
            pager: pager,
            emptyBuilder: (_) => const Text('Empty Feed'),
            itemBuilder: (_, item, _) => Text(item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Empty Feed'), findsOneWidget);
    });
  });

  group('OmniInspector HAR & Markdown export', () {
    test('toHarJson and toMarkdownReport export redacted logs', () async {
      final inspector = OmniInspector();
      addTearDown(inspector.dispose);

      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        enableLogging: true,
        logInRelease: true,
        logSink: inspector.sink('api'),
        transport: MockTransport(
          (_) => _json({'hello': 'world'}, 201),
        ),
      );
      addTearDown(api.close);

      await api.post<Object?>(
        '/items',
        query: {'api_key': 'secret', 'page': '2'},
        body: {'password': 'pw', 'name': 'book'},
      );
      await Future<void>.delayed(Duration.zero);

      final har = jsonDecode(inspector.toHarJson()) as Map<String, Object?>;
      final log = har['log']! as Map<String, Object?>;
      expect(log['version'], '1.2');
      final entries = log['entries']! as List<Object?>;
      expect(entries, hasLength(1));

      final entry = entries.single! as Map<String, Object?>;
      final request = entry['request']! as Map<String, Object?>;
      final response = entry['response']! as Map<String, Object?>;
      expect(request['method'], 'POST');
      expect(request['url'], contains('api_key=***'));
      expect(response['status'], 201);

      final md = inspector.toMarkdownReport();
      expect(md, contains('# OmniNetwork Inspector Report'));
      expect(md, contains('[api] POST'));
      expect(md, contains('```bash'));
    });

    testWidgets('Copy HAR icon copies valid HAR JSON to clipboard', (
      tester,
    ) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final inspector = OmniInspector();
      addTearDown(inspector.dispose);

      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        enableLogging: true,
        logInRelease: true,
        logSink: inspector,
        transport: MockTransport((_) => _json({'ok': true})),
      );
      addTearDown(api.close);

      await tester.runAsync(() => api.get<Object?>('/ping'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OmniInspectorView(inspector: inspector)),
        ),
      );
      await tester.tap(find.byTooltip('Copy HAR'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(copiedText, isNotNull);
      final parsed = jsonDecode(copiedText!) as Map<String, Object?>;
      expect((parsed['log']! as Map<String, Object?>)['version'], '1.2');
    });
  });
}
