import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route/src/routing/omni_bottom_bar_host.dart'
    show OmniPageBarHost, OmniPageBarSlot;

const _bar = OmniBottomNavigationBar(
  style: OmniBottomNavigationStyle.floatingBubble,
  items: [
    OmniBottomNavigationItem(
      icon: Icon(Icons.home_outlined),
      label: 'Feed',
      routePath: '/feed',
    ),
    OmniBottomNavigationItem(
      icon: Icon(Icons.explore_outlined),
      label: 'Explore',
      routePath: '/explore',
    ),
  ],
);

Widget _app({
  OmniPageBarTransition? transition = OmniPageBarTransition.slide,
  OmniPageBarTransition appTransition = OmniPageBarTransition.slide,
  OmniPageType? pageTransition,
  String? restorationScopeId,
}) => OmniApp.material(
  initialRoute: '/feed',
  restorationScopeId: restorationScopeId,
  bottomBarTransition: appTransition,
  transition: pageTransition ?? OmniPages.fadeSlide,
  routes: [
    OmniPage(
      '/feed',
      (_) => const Center(child: Text('F')),
      bottomNavigationBar: _bar,
      bottomNavigationBarTransition: transition,
      routes: [
        OmniPage('detail', (_) => const Center(child: Text('D'))),
        OmniPage(
          'more',
          (_) => const ColoredBox(
            color: Colors.white,
            child: Center(child: Text('M')),
          ),
          bottomNavigationBar: _bar,
          bottomNavigationBarTransition: transition,
        ),
      ],
    ),
    OmniPage(
      '/explore',
      (_) => const Center(child: Text('E')),
      bottomNavigationBar: _bar,
      bottomNavigationBarTransition: transition,
    ),
  ],
);

Finder get _bars => find.byType(OmniBottomNavigationBar);

void main() {
  testWidgets('observer events during a build never setState the host', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    final element = t.element(find.text('F'));
    final route = ModalRoute.of(element)!;
    // What runApp / hot restart do: widgets build with the scheduler idle
    // while the navigator reports a push.
    t.binding.buildOwner!.buildScope(element, () {
      for (final o in nav.widget.observers) {
        o.didPush(route, null);
      }
    });
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(_bars, findsOneWidget);
  });

  testWidgets('first attach outside a frame (app start, hot restart)', (
    t,
  ) async {
    // runApp / hot restart build the first tree outside any frame (the
    // scheduler is idle) and the navigator reports its first push during
    // that build. The host must not setState then.
    Widget host() => MaterialApp(
      home: OmniPageBarHost(
        builder: (context, observer) => Navigator(
          observers: [observer],
          pages: const [
            MaterialPage<void>(
              child: Scaffold(
                body: Text('F'),
                bottomNavigationBar: OmniPageBarSlot(bar: _bar),
              ),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      t.binding.attachRootWidget(t.binding.wrapWithDefaultView(host()));
      expect(t.takeException(), isNull);
      await t.pump();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_bars, findsOneWidget);
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('switching pages keeps one fixed bar; its state survives', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    final state = t.state(_bars);
    final rest = t.getRect(_bars);

    await t.tap(find.byIcon(Icons.explore_outlined));
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 25));
      // Both pages are on screen, the bar is one and does not move.
      expect(_bars, findsOneWidget);
      expect(t.getRect(_bars), rest);
      expect(t.state(_bars), same(state));
    }
    await t.pumpAndSettle();
    expect(find.text('E'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget); // selected tab label
    expect(t.state(_bars), same(state));
    expect(t.getRect(_bars), rest);

    // And back.
    await t.tap(find.byIcon(Icons.home_outlined));
    await t.pumpAndSettle();
    expect(find.text('Feed'), findsOneWidget);
    expect(t.state(_bars), same(state));
  });

  testWidgets('a page without a bar: the bar slides down, then back up', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    final rest = t.getRect(_bars);

    OmniRoute.go('/feed/detail');
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    expect(t.getRect(_bars).top, greaterThan(rest.top + 4));
    await t.pumpAndSettle();
    expect(find.text('D'), findsOneWidget);

    OmniRoute.pop();
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    expect(t.getRect(_bars).top, greaterThan(rest.top + 1));
    await t.pumpAndSettle();
    expect(t.getRect(_bars), rest);
  });

  testWidgets('fade mode fades the bar out for a page without one', (t) async {
    await t.pumpWidget(_app(transition: OmniPageBarTransition.fade));
    await t.pumpAndSettle();
    final rest = t.getRect(_bars);
    OmniRoute.go('/feed/detail');
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    expect(t.getRect(_bars), rest); // stays in place
    final opacity = t.widget<Opacity>(
      find.ancestor(of: _bars, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, inExclusiveRange(0.0, 1.0));
    await t.pumpAndSettle();
  });

  testWidgets('a dialog covers the bar', (t) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    final ctx = t.element(find.text('F'));
    showDialog<void>(
      context: ctx,
      builder: (_) => const AlertDialog(content: Text('Hi')),
    );
    await t.pumpAndSettle();
    // The barrier is on top: tapping the bar's tab does not navigate.
    await t.tap(find.byIcon(Icons.explore_outlined), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('E'), findsNothing);
    expect(_bars, findsOneWidget);
  });

  testWidgets('iOS back swipe: bar stays put, cancel or commit', (t) async {
    await t.pumpWidget(_app(pageTransition: OmniPages.cupertino));
    await t.pumpAndSettle();
    final state = t.state(_bars);
    final rest = t.getRect(_bars);
    OmniRoute.go('/feed/more');
    await t.pumpAndSettle();
    expect(find.text('M'), findsOneWidget);
    expect(t.getRect(_bars), rest);

    // A short swipe is cancelled.
    final g = await t.startGesture(const Offset(5, 300));
    await g.moveBy(const Offset(120, 0));
    await t.pump();
    expect(t.getRect(_bars), rest);
    await g.up();
    await t.pumpAndSettle();
    expect(find.text('M'), findsOneWidget);
    expect(t.getRect(_bars), rest);

    // A long one goes back.
    final g2 = await t.startGesture(const Offset(5, 300));
    for (var i = 0; i < 10; i++) {
      await g2.moveBy(const Offset(60, 0));
      await t.pump(const Duration(milliseconds: 16));
      expect(t.getRect(_bars), rest);
    }
    await g2.up();
    await t.pumpAndSettle();
    expect(find.text('M'), findsNothing);
    expect(find.text('F'), findsOneWidget);
    expect(t.getRect(_bars), rest);
    expect(t.state(_bars), same(state));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('OmniApp.bottomBarTransition is the default for pages', (
    t,
  ) async {
    await t.pumpWidget(
      _app(transition: null, appTransition: OmniPageBarTransition.withPage),
    );
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.explore_outlined));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(_bars, findsNWidgets(2));
    await t.pumpAndSettle();
  });

  testWidgets('withPage: each page brings its own bar along', (t) async {
    await t.pumpWidget(_app(transition: OmniPageBarTransition.withPage));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.explore_outlined));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(_bars, findsNWidgets(2));
    await t.pumpAndSettle();
    expect(_bars, findsOneWidget);
  });
}
