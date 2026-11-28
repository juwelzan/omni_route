import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

Widget _app({OmniBottomNavigationStyle? style}) => OmniApp.material(
  initialRoute: '/inbox',
  routes: [
    OmniStatefulShell.adaptive(
      bottomBarStyle: style,
      destinations: const [
        OmniAdaptiveDestination(
          icon: Icon(Icons.inbox_outlined),
          label: 'Inbox',
          badgeCount: 120,
          tooltip: 'Your inbox',
          semanticLabel: 'Inbox, 120 unread',
        ),
        OmniAdaptiveDestination(
          icon: Icon(Icons.chat_outlined),
          label: 'Chat',
          showDotBadge: true,
        ),
        OmniAdaptiveDestination(
          icon: Icon(Icons.person_outline),
          label: 'Me',
          badgeText: 'NEW',
        ),
      ],
      branches: [
        for (final p in ['/inbox', '/chat', '/me'])
          OmniBranch(routes: [OmniPage(p, (_) => Text('page $p'))]),
      ],
    ),
  ],
);

/// Loads preferences before the app mounts, so OmniApp does not hold the
/// first frame (the test binding never builds semantics for a held frame).
Future<void> _preload(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  await t.runAsync(OmniPreferences.load);
}

void _size(WidgetTester t, Size s) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = s;
}

void main() {
  testWidgets('Material NavigationBar shows number, text and dot badges', (
    t,
  ) async {
    _size(t, const Size(390, 844));
    addTearDown(t.view.reset);
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.byType(Badge), findsNWidgets(3));
  });

  testWidgets('Omni bar (bottomBarStyle) gets badges and semantics', (t) async {
    _size(t, const Size(390, 844));
    addTearDown(t.view.reset);
    await _preload(t);
    final handle = t.ensureSemantics();
    await t.pumpWidget(_app(style: OmniBottomNavigationStyle.materialPill));
    await t.pumpAndSettle();
    expect(find.byType(OmniBottomNavigationBar), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Inbox, 120 unread')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('rail: badges, tooltip and semantics survive tier switches', (
    t,
  ) async {
    _size(t, const Size(390, 844));
    addTearDown(t.view.reset);
    await _preload(t);
    final handle = t.ensureSemantics();
    await t.pumpWidget(_app());
    await t.pumpAndSettle();

    for (final size in [const Size(800, 1000), const Size(1280, 900)]) {
      _size(t, size);
      await t.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.byTooltip('Your inbox'), findsWidgets);
      // The rail reads the label's semanticsLabel.
      expect(
        t.widget<Text>(find.text('Inbox')).semanticsLabel,
        'Inbox, 120 unread',
      );
    }

    _size(t, const Size(390, 844));
    await t.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    handle.dispose();
  });
}
