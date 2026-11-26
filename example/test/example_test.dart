import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route_example/api_lab_screens.dart';
import 'package:omni_route_example/demo_backend.dart';
import 'package:omni_route_example/main.dart';

void main() {
  testWidgets(
    'Full ExampleApp flow: guards, page-entry Bloc, Normal vs Modified API, '
    'WS RPC, AI Chat, WS Chat, OmniShell, OmniStatefulShell, dialogs & sheets',
    (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      // 1. AuthGuard redirects unauthenticated startup -> /login.
      expect(OmniRoute.routePath, '/login');
      expect(find.text('Log in'), findsOneWidget);

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // 2. Dashboard: OmniStatefulWidget + OmniLifecycle + .hosted() OmniStatelessWidget.
      expect(OmniRoute.routePath, '/dashboard');
      expect(find.textContaining('Hosted OmniStatelessWidget'), findsOneWidget);
      expect(find.textContaining('OmniLifecycle onShow count:'), findsOneWidget);

      // Jump directly to /students/101 (OmniRouteGroup + StudentDetailBloc).
      await tester.tap(find.text('Open student 101'));
      await tester.pumpAndSettle();
      expect(find.text('Route: /students/101'), findsOneWidget);

      // AttendanceBloc (page-scoped on StudentDetailScreen).
      await tester.tap(find.text('Mark present'));
      await tester.pumpAndSettle();
      expect(find.text('Present: true'), findsOneWidget);

      // Edit screen with slideUp transition + onExit confirmation guard.
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Rahim Updated');
      await tester.pumpAndSettle();

      // Dirty pop triggers onExit dialog; Stay keeps edits, Save resets dirty & pops.
      await tester.tap(find.text('Back to list'));
      await tester.pumpAndSettle();
      expect(find.text('Discard edits?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Rahim Updated'), findsOneWidget);

      // Re-tap active Students tab -> resets Branch 1 to /students (registers
      // lazy page-entry StudentBloc on first entry!).
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();
      expect(find.text('Student #101'), findsOneWidget);
      expect(find.text('Student #102'), findsOneWidget);
      expect(find.text('Student #103'), findsOneWidget);

      // 3. Switch to API & AI tab (OmniStatefulShell branch wrapping OmniShell).
      await tester.tap(find.text('API & AI'));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/api');
      expect(find.text('OmniShell: /api'), findsOneWidget);

      // onReady ran both Normal & Modified API automatically.
      expect(find.textContaining('[NORMAL API RESULT]'), findsOneWidget);
      expect(find.textContaining('[MODIFIED API RESULT]'), findsOneWidget);

      final apiScroll = find
          .descendant(
            of: find.byType(ApiCompareScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> tapInApiLab(Finder target) async {
        await tester.scrollUntilVisible(target, 150, scrollable: apiScroll);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      // Run 500-line full response test & print count.
      await tapInApiLab(find.text('Print 500-Line JSON'));
      expect(find.textContaining('totalRows=100'), findsOneWidget);
      expect(find.textContaining('no truncation'), findsOneWidget);

      // Switch OmniApiHub dev -> prod environment.
      await tapInApiLab(find.text('prod'));
      expect(find.text('env: prod'), findsOneWidget);
      expect(
        find.textContaining('https://prod.api.omni.local'),
        findsOneWidget,
      );

      // Runtime logger toggle (`logResponse = false` -> re-run keeps status only).
      await tapInApiLab(find.text('logResponse'));
      await tapInApiLab(find.text('Call Modified API'));
      expect(find.textContaining('logResponse=false'), findsOneWidget);

      // WebSocket Event + Correlated RPC.
      await tapInApiLab(find.text('Run WS Event + RPC'));
      expect(find.textContaining('RPC sum(15+27) = 42'), findsOneWidget);

      // Classic Named Route (`/classic-student/:id` + pre-registered Bloc).
      await tapInApiLab(find.text('Classic Named Route'));
      expect(find.textContaining('Classic Style:'), findsOneWidget);
      await tester.tap(find.text('Pop Classic Route'));
      await tester.pumpAndSettle();

      // BottomSheet route (`OmniPages.bottomSheet`).
      await tapInApiLab(find.text('BottomSheet Route (/api-sheet)'));
      expect(find.textContaining('Current routePath: /api-sheet'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Nested OmniShell sub-route 1: Multi-Model AI Chat (`/api/ai-chat`).
      await tapInApiLab(find.text('AI Chat (/api/ai-chat)'));
      expect(OmniRoute.routePath, '/api/ai-chat');
      await tester.enterText(
        find.byType(TextField),
        'Test OmniRoute routing',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.textContaining('[OpenAI/gpt-4o-mini]'), findsOneWidget);

      // Nested OmniShell sub-route 2: Realtime WS Chat (`/api/chat`).
      await tester.tap(find.text('WS Chat'));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/api/chat');
      await tester.enterText(find.byType(TextField), 'Hello @ai');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('Hello @ai'), findsOneWidget);

      // Switch to Settings tab -> Dark mode -> Nested `/settings/profile`.
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/settings/profile');

      // Jump back to Dashboard via tab and trigger Dialog route logout.
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/confirm-logout');

      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/login');

      // Cleanly unmount so ApiLabCubit.close() closes WS & streams.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test('Pure-Dart ApiComparisonCoordinator verifies Normal vs Modified API', () async {
    final coordinator = ApiComparisonCoordinator(enableColors: false);
    addTearDown(coordinator.dispose);

    final normal = await coordinator.callNormalApi(id: 101);
    final modified = await coordinator.callModifiedApi(id: 103);
    final report = await coordinator.callLargePayloadApi();
    final wsTotal = await coordinator.callWebSocketDemo(a: 10, b: 15);
    final aiReply = await coordinator.callAiStreamingDemo('Hello');

    expect(normal.id, 101);
    expect(modified.valueOrNull?.id, 103);
    expect(report['totalRows'], 100);
    expect(coordinator.lastModifiedTerminalBlock.split('\n').length, greaterThan(500));
    expect(wsTotal, 25);
    expect(aiReply, contains('[OpenAI/gpt-4o-mini]'));
  });
}
