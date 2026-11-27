import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:omni_network_flutter/omni_network_flutter.dart';

void main() {
  late OmniMock mock;

  setUp(() {
    mock = OmniMock()
      ..get(
        '/users',
        (_) => MockResponse.json([
          {'id': 1},
        ]),
      )
      ..get('/missing', (_) => const MockResponse.status(404))
      ..get('/down', (_) => const MockResponse.offline())
      ..post(
        '/login',
        (_) => MockResponse.json({'access_token': 'TOKEN-SECRET'}),
      );
  });

  OmniNetwork client(OmniInspector inspector, [String label = 'api']) =>
      OmniNetwork(
        baseUrl: 'https://api.test',
        headers: {'Authorization': 'Bearer HEADER-SECRET'},
        transport: mock,
        enableLogging: inspector.enabled,
        logSink: inspector.sink(label),
      );

  Future<void> traffic(WidgetTester tester, OmniNetwork api) =>
      tester.runAsync(() async {
        await api.get<dynamic>('/users');
        await api.sendRaw(const OmniRequest.get('/missing'));
        await api.sendRaw(const OmniRequest.get('/down')).asResult();
        await api.sendRaw(
          const OmniRequest.post(
            '/login',
            body: {'user': 'ana', 'password': 'PW-SECRET'},
          ),
        );
      });

  group('OmniInspector collector', () {
    testWidgets('pairs requests with responses and errors', (tester) async {
      final inspector = OmniInspector(enabled: true);
      addTearDown(inspector.dispose);
      final api = client(inspector);
      await traffic(tester, api);
      await tester.runAsync(api.close);
      final e = inspector.entries; // newest first
      expect(e.map((x) => (x.method, x.status)), [
        ('POST', InspectorStatus.success),
        ('GET', InspectorStatus.failed),
        ('GET', InspectorStatus.clientError),
        ('GET', InspectorStatus.success),
      ]);
      expect(e[1].error, startsWith('ConnectionFailure'));
      expect(e.last.source, ResponseSource.network);
      expect(e.last.duration, isNotNull);
    });

    testWidgets('secrets never reach the inspector', (tester) async {
      final inspector = OmniInspector(enabled: true);
      addTearDown(inspector.dispose);
      final api = client(inspector);
      await traffic(tester, api);
      await tester.runAsync(api.close);
      final dump = [
        for (final x in inspector.entries)
          '${x.url}${x.requestHeaders}${x.requestBody}${x.responseHeaders}${x.responseBody}${x.toCurl()}',
      ].join();
      for (final s in ['HEADER-SECRET', 'PW-SECRET', 'TOKEN-SECRET']) {
        expect(dump, isNot(contains(s)));
      }
      expect(dump, contains('"user":"ana"'));
    });

    testWidgets('disabled: records nothing but still forwards', (tester) async {
      final forwarded = <NetworkLogRecord>[];
      final inspector = OmniInspector(
        enabled: false,
        forwardTo: _ListSink(forwarded),
      );
      addTearDown(inspector.dispose);
      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        transport: mock,
        enableLogging: true,
        logSink: inspector,
      );
      await tester.runAsync(() => api.get<dynamic>('/users'));
      await tester.runAsync(api.close);
      expect(inspector.entries, isEmpty);
      expect(forwarded, hasLength(2));
    });

    testWidgets('bounded; labels keep clients apart; clear', (tester) async {
      final inspector = OmniInspector(enabled: true, maxEntries: 3);
      addTearDown(inspector.dispose);
      final a = client(inspector, 'a');
      final b = client(inspector, 'b');
      await tester.runAsync(() async {
        // Same request ids (#1, #2) in both clients.
        await a.get<dynamic>('/users');
        await b.sendRaw(const OmniRequest.get('/missing'));
        await a.sendRaw(const OmniRequest.get('/missing'));
        await b.get<dynamic>('/users');
      });
      await tester.runAsync(() => Future.wait([a.close(), b.close()]));
      expect(inspector.entries.map((e) => (e.label, e.statusCode)), [
        ('b', 200),
        ('a', 404),
        ('b', 404),
      ]);
      var notified = 0;
      inspector.addListener(() => notified++);
      inspector.clear();
      expect(inspector.entries, isEmpty);
      expect(notified, 1);
    });
  });

  group('UI', () {
    testWidgets('list, filter, detail, copy cURL, back', (tester) async {
      final inspector = OmniInspector(enabled: true);
      addTearDown(inspector.dispose);
      final api = client(inspector);
      await traffic(tester, api);
      await tester.runAsync(api.close);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
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

      await tester.pumpWidget(
        MaterialApp(home: OmniInspectorView(inspector: inspector)),
      );
      expect(find.text('Network (4)'), findsOneWidget);
      expect(find.text('404'), findsOneWidget);
      expect(find.text('ERR'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'login');
      await tester.pump();
      expect(find.byType(ListTile), findsOneWidget);

      await tester.tap(find.byType(ListTile));
      await tester.pump();
      expect(find.text('POST 200'), findsOneWidget);
      expect(find.textContaining('authorization: ***'), findsOneWidget);
      expect(find.textContaining('HEADER-SECRET'), findsNothing);

      await tester.tap(find.byTooltip('Copy as cURL'));
      await tester.pump();
      expect(clipboard, startsWith("curl -X POST 'https://api.test/login'"));
      expect(clipboard, contains('***'));
      expect(clipboard, isNot(contains('PW-SECRET')));

      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.byType(ListTile), findsOneWidget); // filter kept

      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();
      expect(find.text('No requests'), findsOneWidget);
    });

    testWidgets('list updates live as requests arrive', (tester) async {
      final inspector = OmniInspector(enabled: true);
      addTearDown(inspector.dispose);
      await tester.pumpWidget(
        MaterialApp(home: OmniInspectorView(inspector: inspector)),
      );
      expect(find.text('No requests'), findsOneWidget);
      final api = client(inspector);
      await tester.runAsync(() => api.get<dynamic>('/users'));
      await tester.runAsync(api.close);
      await tester.pump();
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets(
      'launcher from MaterialApp.builder opens and closes the panel',
      (tester) async {
        final inspector = OmniInspector(enabled: true);
        addTearDown(inspector.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                OmniInspectorLauncher(inspector: inspector, child: child!),
            home: const Scaffold(body: Text('app')),
          ),
        );
        expect(find.text('app'), findsOneWidget);
        await tester.tap(find.byTooltip('Open network inspector'));
        await tester.pump();
        expect(find.text('Network (0)'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'x'); // needs an Overlay
        await tester.pump();
        await tester.tap(find.byTooltip('Close inspector'));
        await tester.pump();
        expect(find.text('Network (0)'), findsNothing);
        expect(find.byTooltip('Open network inspector'), findsOneWidget);
        // Unmount: OverlayEntry and controllers disposed (leak tracking on).
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('app below the launcher still receives taps and rebuilds', (
      tester,
    ) async {
      final inspector = OmniInspector(enabled: true);
      addTearDown(inspector.dispose);
      var taps = 0;
      Widget app(String label) => MaterialApp(
        builder: (context, child) =>
            OmniInspectorLauncher(inspector: inspector, child: child!),
        home: Scaffold(
          body: Center(
            child: TextButton(onPressed: () => taps++, child: Text(label)),
          ),
        ),
      );
      await tester.pumpWidget(app('one'));
      await tester.tap(find.text('one'));
      expect(taps, 1);
      await tester.pumpWidget(app('two'));
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('disabled launcher renders only the app', (tester) async {
      final inspector = OmniInspector(enabled: false);
      addTearDown(inspector.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              OmniInspectorLauncher(inspector: inspector, child: child!),
          home: const Text('app'),
        ),
      );
      expect(find.byTooltip('Open network inspector'), findsNothing);
    });

    testWidgets(
      'Talker-style Logs tab shows color-coded cards & 1-click copy per item',
      (tester) async {
        String? copied;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final inspector = OmniInspector(enabled: true);
        addTearDown(inspector.dispose);
        final api = client(inspector);
        await tester.runAsync(() => api.get<dynamic>('/users'));
        await tester.runAsync(api.close);

        inspector
          ..logRoute('/dashboard -> /api', subtitle: 'uri: /api?id=1')
          ..logBloc(
            'bloc-create',
            'AuthBloc created',
            kind: InspectorLogKind.blocCreate,
          )
          ..logWarning('Cache nearly full', subtitle: '85%');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OmniInspectorView(
                inspector: inspector,
                initialTab: InspectorTab.logs,
              ),
            ),
          ),
        );

        // 1 http-request + 1 http-response + 1 route + 1 bloc-create + 1 warning
        expect(find.text('All Logs (5)'), findsOneWidget);
        expect(find.text('1 http-response'), findsOneWidget);
        expect(find.text('1 route'), findsOneWidget);
        expect(find.text('1 bloc-create'), findsOneWidget);

        // 1-click copy on the http-response card copies pretty JSON directly.
        await tester.tap(find.byTooltip('Copy http-response'));
        await tester.pump();
        expect(copied, contains('"id": 1'));

        // Category chip filters down to matching cards.
        await tester.tap(find.text('1 route'));
        await tester.pump();
        expect(find.textContaining('/dashboard -> /api'), findsOneWidget);
        expect(find.textContaining('AuthBloc created'), findsNothing);

        // Copy all logs exports the complete timeline in one tap.
        await tester.tap(find.byTooltip('Copy all logs'));
        await tester.pump();
        expect(copied, contains('http-response'));
        expect(copied, contains('bloc-create'));
        expect(copied, contains('/dashboard -> /api'));

        // HTTP Detail also exposes 1-click Copy Full Response.
        await tester.tap(find.text('HTTP (1)'));
        await tester.pump();
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        await tester.tap(find.text('Copy Full Response'));
        await tester.pump();
        expect(copied, contains('"id": 1'));
      },
    );

    testWidgets(
      'defensively redacts WS URLs, AI errors, and route logs in entries and Markdown report',
      (tester) async {
        final inspector = OmniInspector(enabled: true);
        addTearDown(inspector.dispose);

        inspector
          ..recordWsLog(
            WsLogRecord(
              uri: 'wss://api.test/live?token=WS-SECRET&v=1',
              direction: 'err',
              summary: 'failed connecting wss://api.test/live?key=API-KEY-SECRET',
              timestamp: DateTime(2026, 1, 1),
            ),
          )
          ..recordAiCall(
            AiCallLogRecord(
              providerId: 'gemini',
              model: 'flash',
              usage: const AiUsage(),
              latency: const Duration(milliseconds: 10),
              timestamp: DateTime(2026, 1, 1),
              promptPreview: 'Bearer PROMPT-SECRET',
              error: 'https://generativelanguage.googleapis.com?key=GEMINI-SECRET',
            ),
          )
          ..logRoute('/auth?token=ROUTE-SECRET -> /home');

        final md = inspector.toMarkdownReport();
        final allText = [
          md,
          for (final l in inspector.logs) '${l.title} ${l.subtitle} ${l.copyText}',
        ].join('\n');

        for (final secret in [
          'WS-SECRET',
          'API-KEY-SECRET',
          'PROMPT-SECRET',
          'GEMINI-SECRET',
          'ROUTE-SECRET',
        ]) {
          expect(allText, isNot(contains(secret)));
        }
        expect(md, contains('token=***'));
      },
    );
  });
}

final class _ListSink implements LogSink {
  _ListSink(this.out);
  final List<NetworkLogRecord> out;
  @override
  void log(NetworkLogRecord r) => out.add(r);
}
