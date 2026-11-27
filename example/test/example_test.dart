import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route_example/api_lab_screens.dart';
import 'package:omni_route_example/demo_backend.dart';
import 'package:omni_route_example/main.dart';

void main() {
  testWidgets(
    'Full ExampleApp flow: guards, page-entry Bloc, Normal vs Modified public APIs, '
    'Multi-Website Hub, WS Echo RPC, AI Chat, WS Chat, OmniShell, OmniStatefulShell, dialogs & sheets',
    (tester) async {
      // useLiveNetwork: false uses the local public-API mirror inside Flutter's
      // hermetic test binding (production ExampleApp & bin/demo.dart hit real URLs).
      await tester.pumpWidget(const ExampleApp(useLiveNetwork: false));
      await tester.pumpAndSettle();

      // 1. AuthGuard redirects unauthenticated startup -> /login.
      expect(OmniRoute.routePath, '/login');
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // 2. Dashboard: OmniStatefulWidget + OmniLifecycle + .hosted() OmniStatelessWidget.
      expect(OmniRoute.routePath, '/dashboard');
      expect(find.textContaining('Hosted OmniStatelessWidget'), findsOneWidget);

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

      await tester.tap(find.text('Back to list'));
      await tester.pumpAndSettle();
      expect(find.text('Discard edits?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Rahim Updated'), findsOneWidget);

      // Re-tap active Students tab -> resets Branch 1 to /students (lazy StudentBloc).
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();
      expect(find.text('Student #101'), findsOneWidget);

      // 3. Switch to API & AI tab (OmniStatefulShell branch wrapping OmniShell).
      await tester.tap(find.text('API & AI'));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/api');
      expect(find.text('OmniShell: /api'), findsOneWidget);

      final apiScroll = find
          .descendant(
            of: find.byType(ApiCompareScreen),
            matching: find.byType(Scrollable),
          )
          .first;

      // onReady ran Normal & Modified API immediately in the top cards.
      expect(find.textContaining('[NORMAL API RESULT'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('[MODIFIED API RESULT'),
        150,
        scrollable: apiScroll,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('[MODIFIED API RESULT'), findsOneWidget);

      Future<void> tapInApiLab(Finder target) async {
        await tester.scrollUntilVisible(target, 150, scrollable: apiScroll);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      // Run POST /posts (201 Created), verify 1-click Copy Full JSON, Warning & Error triggers, then Print 100 Posts JSON.
      await tapInApiLab(find.text('POST /posts (201)'));
      expect(find.textContaining('[POST 201 CREATED]'), findsOneWidget);
      await tapInApiLab(find.text('Copy Full JSON'));
      expect(find.textContaining('Copied Modified API JSON'), findsOneWidget);

      await tapInApiLab(find.text('404 Warning'));
      expect(find.textContaining('[404 WARNING'), findsOneWidget);

      await tapInApiLab(find.text('500 Error'));
      expect(find.textContaining('[500 SERVER ERROR'), findsOneWidget);

      await tapInApiLab(find.text('Print 100 Posts JSON'));
      expect(find.textContaining('totalPosts=100'), findsOneWidget);
      expect(find.textContaining('no truncation'), findsOneWidget);

      // Runtime toggle `logResponse = false` -> re-run keeps status only.
      await tapInApiLab(find.text('logResponse'));
      await tapInApiLab(find.text('Call Modified API'));
      expect(find.textContaining('logResponse=false'), findsOneWidget);

      // Scroll to Card 3: verify onReady Multi-Website Hub output, then switch env.
      await tapInApiLab(find.text('Call 3 Public Websites'));
      expect(find.textContaining('[MULTI-WEBSITE PUBLIC HUB'), findsOneWidget);
      await tapInApiLab(find.text('sandbox'));
      expect(find.text('env: sandbox'), findsOneWidget);
      expect(find.textContaining('Switched OmniApiHub env'), findsOneWidget);

      // WebSocket Echo + Correlated RPC.
      await tapInApiLab(find.text('Run Live WS Echo + RPC'));
      expect(find.textContaining('RPC echo_rpc(18+24) = 42'), findsOneWidget);

      // Separate Logs & Talker Inspector (Card 5).
      await tapInApiLab(find.text('All Logs'));
      expect(find.textContaining('All Logs ('), findsOneWidget);
      expect(find.textContaining('http-response'), findsWidgets);
      await tester.tap(find.byTooltip('Close inspector'));
      await tester.pumpAndSettle();

      // Classic Named Route (`/classic-student/:id`).
      await tapInApiLab(find.text('Classic Named Route'));
      expect(find.textContaining('Classic Style:'), findsOneWidget);
      await tester.tap(find.text('Pop Classic Route'));
      await tester.pumpAndSettle();

      // BottomSheet route (`OmniPages.bottomSheet`).
      await tapInApiLab(find.text('BottomSheet Route (/api-sheet)'));
      expect(find.textContaining('Current routePath: /api-sheet'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Nested OmniShell sub-route 1: AI Chat (`/api/ai-chat`).
      await tapInApiLab(find.text('AI Chat (/api/ai-chat)'));
      expect(OmniRoute.routePath, '/api/ai-chat');
      await tester.enterText(find.byType(TextField), 'Test public APIs');
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

      // Settings -> System/Light/Dark mode & 1-click Color Palette -> Nested `/settings/profile`.
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.tap(find.text('Emerald'));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(SettingsScreen)).colors.primaryColor,
        OmniTheme.emerald.seedColor,
      );
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      final settingsScroll = find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final profileTile = find.text('Profile');
      await tester.scrollUntilVisible(
        profileTile,
        150,
        scrollable: settingsScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(profileTile);
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/settings/profile');

      // Dashboard -> Dialog route logout -> AuthGuard redirects to /login.
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/confirm-logout');

      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/login');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test(
    'Offline mirror ApiComparisonCoordinator verifies all public endpoints',
    () async {
      final coordinator = ApiComparisonCoordinator(
        useLiveNetwork: false,
        enableColors: false,
      );
      addTearDown(coordinator.dispose);

      final user = await coordinator.callNormalApi(id: 1);
      final modified = await coordinator.callModifiedApi(id: 2);
      final created = await coordinator.callCreatePostDemo();
      final posts = await coordinator.callLargePayloadApi();
      final largePayloadLines =
          coordinator.lastModifiedTerminalBlock.split('\n').length;
      final multi = await coordinator.callMultiWebsitePublicApis();
      final wsSum = await coordinator.callWebSocketDemo(a: 18, b: 24);
      final aiReply = await coordinator.callAiStreamingDemo('Hello');

      expect(user.name, 'Leanne Graham');
      expect(modified.valueOrNull?.name, 'Ervin Howell');
      expect(created.id, 101);
      expect(posts.length, 100);
      expect(largePayloadLines, greaterThan(500));
      expect(
        coordinator.lastModifiedTerminalBlock,
        contains('💡 http-response · 200 OK'),
      );
      expect(
        coordinator.lastModifiedTerminalBlock,
        contains('📦 Body: JSON Object'),
      );
      expect(coordinator.lastModifiedTerminalBlock, contains('\x1B[38;5;40m'));

      await coordinator.callWarningDemo();
      expect(
        coordinator.lastModifiedTerminalBlock,
        contains('⚠️ http-warning · 404 Not Found'),
      );
      expect(coordinator.lastModifiedTerminalBlock, contains('\x1B[38;5;214m'));

      await coordinator.callErrorDemo();
      expect(
        coordinator.lastModifiedTerminalBlock,
        contains('⛔ http-error · 500'),
      );
      expect(
        coordinator.lastModifiedTerminalBlock,
        contains('\x1B[1;38;5;15;48;5;196m'),
      );
      expect(multi, contains('dummyjson.com'));
      expect(multi, contains('open-meteo.com'));
      expect(multi, contains('pokeapi.co'));
      expect(wsSum, 42);
      expect(aiReply, contains('[OpenAI/gpt-4o-mini]'));
    },
  );
}
