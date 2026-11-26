// 0.2.5: edge swipe-back for every animated page type, OmniRoute.open.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

final log = <String>[];

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get screenName => label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

class Home extends OmniStatelessWidget with OmniLifecycle {
  const Home({super.key});
  @override
  String get screenName => 'home';
  @override
  void onScreenVisible(BuildContext c) => log.add('home:visible');
  @override
  void onScreenHidden(BuildContext c) => log.add('home:hidden');
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home')));
}

class Locked extends OmniStatelessWidget {
  const Locked({super.key});
  @override
  String get screenName => 'locked';
  @override
  Widget build(BuildContext context) => const PopScope(
    canPop: false,
    child: Scaffold(body: Center(child: Text('locked'))),
  );
}

class EdgeButton extends OmniStatelessWidget {
  const EdgeButton({super.key});
  @override
  String get screenName => 'edge';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned(
          left: 0,
          top: 280,
          width: 60,
          height: 40,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => log.add('tapped'),
          ),
        ),
      ],
    ),
  );
}

Widget app({
  OmniSwipeBack swipeBack = OmniSwipeBack.zoom,
  OmniPageType? transition,
  TextDirection dir = TextDirection.ltr,
}) => OmniApp(
  swipeBack: swipeBack,
  transition: transition ?? OmniPages.fade,
  routes: [
    OmniPage('/', (_) => const Home()),
    OmniPage('/a', (_) => const S('a')),
    OmniPage('/b', (_) => const S('b')),
    OmniPage('/c', (_) => const S('c')),
    OmniPage('/locked', (_) => const Locked()),
    OmniPage('/edge', (_) => const EdgeButton()),
    OmniPage(
      '/off',
      (_) => const S('off'),
      transition: OmniPages.transition(
        OmniTransition.fade,
        swipeBack: OmniSwipeBack.none,
      ),
    ),
  ],
  builder: (_, r) => MaterialApp.router(
    routerConfig: r,
    builder: (_, child) => Directionality(textDirection: dir, child: child!),
  ),
);

Future<void> open(WidgetTester t, String location) async {
  await t.pumpWidget(app());
  await t.pumpAndSettle();
  OmniRoute.push(location);
  await t.pumpAndSettle();
}

/// A slow drag (well under the fling velocity).
Future<void> slowDrag(WidgetTester t, Offset from, double dx) async {
  await t.timedDragFrom(from, Offset(dx, 0), const Duration(seconds: 2));
  await t.pumpAndSettle();
}

void main() {
  setUp(log.clear);

  testWidgets('left-edge drag past 50% pops', (t) async {
    await open(t, '/a');
    await slowDrag(t, const Offset(5, 300), 500);
    expect(find.text('a'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('drag under 50% springs back and does not pop', (t) async {
    await open(t, '/a');
    final gesture = await t.startGesture(const Offset(5, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(25, 0));
      await t.pump(const Duration(milliseconds: 50));
    }
    // Mid-drag: the zoomed page is smaller than the screen.
    final mid = t.getRect(find.byType(Scaffold).last);
    expect(mid.width, lessThan(800), reason: 'zoomed out');
    expect(mid.center.dx, greaterThan(400), reason: 'follows the finger');
    await t.pump(const Duration(milliseconds: 200)); // stop: no velocity
    await gesture.up();
    await t.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
    expect(OmniRoute.current.location, '/a');
    expect(t.getCenter(find.text('a')), const Offset(400, 300));
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('right-edge drag pops; a drag from the middle does nothing', (
    t,
  ) async {
    await open(t, '/a');
    await slowDrag(t, const Offset(400, 300), 380);
    expect(find.text('a'), findsOneWidget, reason: 'middle start ignored');
    await slowDrag(t, const Offset(795, 300), -500);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });

  testWidgets('a drag the wrong way does nothing', (t) async {
    await open(t, '/a');
    await slowDrag(t, const Offset(795, 300), 4);
    await slowDrag(t, const Offset(5, 300), -4);
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('a fast flick under 50% still pops', (t) async {
    await open(t, '/a');
    await t.flingFrom(const Offset(5, 300), const Offset(200, 0), 2000);
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });

  testWidgets('no gesture on the first page', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await slowDrag(t, const Offset(5, 300), 500);
    expect(find.text('home'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('no gesture under PopScope(canPop: false)', (t) async {
    await open(t, '/locked');
    await slowDrag(t, const Offset(5, 300), 500);
    expect(find.text('locked'), findsOneWidget);
  });

  testWidgets('no gesture with swipeBack: none (app or page)', (t) async {
    await t.pumpWidget(app(swipeBack: OmniSwipeBack.none));
    await t.pumpAndSettle();
    OmniRoute.push('/a');
    await t.pumpAndSettle();
    await slowDrag(t, const Offset(5, 300), 500);
    expect(find.text('a'), findsOneWidget);

    await t.pumpWidget(app());
    OmniRoute.go('/');
    await t.pumpAndSettle();
    OmniRoute.push('/off');
    await t.pumpAndSettle();
    await slowDrag(t, const Offset(5, 300), 500);
    expect(find.text('off'), findsOneWidget, reason: 'page-level none wins');
  });

  testWidgets('per-page opt-in works without an app default', (t) async {
    await t.pumpWidget(
      app(
        swipeBack: OmniSwipeBack.none,
        transition: OmniPages.custom(
          (_, a, _, child) => FadeTransition(opacity: a, child: child),
          swipeBack: OmniSwipeBack.slide,
        ),
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/a');
    await t.pumpAndSettle();
    await slowDrag(t, const Offset(5, 300), 500);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a tap inside the edge strip still hits the page', (t) async {
    await open(t, '/edge');
    await t.tapAt(const Offset(10, 300));
    await t.pumpAndSettle();
    expect(log, contains('tapped'));
    expect(OmniRoute.current.location, '/edge');
  });

  testWidgets('after a swipe pop: stack, current, onScreenVisible', (t) async {
    await open(t, '/a');
    OmniRoute.push('/b');
    await t.pumpAndSettle();
    await slowDrag(t, const Offset(5, 300), 500);
    expect(OmniRoute.current.location, '/a');
    expect(OmniRoute.stack.map((e) => e.location), ['/', '/a']);

    log.clear();
    await slowDrag(t, const Offset(5, 300), 500);
    expect(OmniRoute.current.location, '/');
    expect(OmniRoute.stack.map((e) => e.location), ['/']);
    expect(log, ['home:visible']);
  });

  testWidgets('RTL: both edges close, moving inward', (t) async {
    await t.pumpWidget(app(dir: TextDirection.rtl));
    await t.pumpAndSettle();
    OmniRoute.push('/a');
    OmniRoute.push('/b');
    await t.pumpAndSettle();
    await slowDrag(t, const Offset(795, 300), -500);
    expect(OmniRoute.current.location, '/a');
    await slowDrag(t, const Offset(5, 300), 500);
    expect(OmniRoute.current.location, '/');
  });

  testWidgets('reduced motion keeps the gesture (plain slide)', (t) async {
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          disableAnimations: true,
        ),
        child: app(),
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/a');
    await t.pumpAndSettle();
    final g = await t.startGesture(const Offset(5, 300));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(200, 0));
    await t.pump();
    // Plain slide: same size, moved by the drag.
    expect(t.getSize(find.byType(Scaffold).last), const Size(800, 600));
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('right edge: under 50% springs back, a flick pops', (t) async {
    await open(t, '/a');
    final g = await t.startGesture(const Offset(795, 300));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-25, 0));
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pump(const Duration(milliseconds: 200));
    await g.up();
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/a');

    await t.flingFrom(const Offset(795, 300), const Offset(-200, 0), 2000);
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/');
  });

  testWidgets('a cancelled gesture stops the user gesture', (t) async {
    await open(t, '/a');
    final nav = t.state<NavigatorState>(find.byType(Navigator).last);
    final g = await t.startGesture(const Offset(5, 300));
    await g.moveBy(const Offset(200, 0));
    await t.pump();
    expect(nav.userGestureInProgress, isTrue);
    await g.cancel();
    await t.pumpAndSettle();
    expect(nav.userGestureInProgress, isFalse);
    expect(OmniRoute.current.location, '/a');
    // A new swipe works afterwards.
    await slowDrag(t, const Offset(5, 300), 500);
    expect(OmniRoute.current.location, '/');
  });

  testWidgets('onNavigate reports a swipe pop', (t) async {
    final navs = <String>[];
    await t.pumpWidget(
      OmniApp(
        swipeBack: OmniSwipeBack.zoomCard,
        transition: OmniPages.fade,
        onNavigate: (n) => navs.add('${n.from?.location}->${n.to.location}'),
        routes: [
          OmniPage('/', (_) => const Home()),
          OmniPage('/a', (_) => const S('a')),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/a');
    await t.pumpAndSettle();
    await slowDrag(t, const Offset(5, 300), 500);
    expect(navs.last, '/a->/');
  });

  for (final mode in OmniSwipeBack.values) {
    testWidgets('system back still pops with ${mode.name}', (t) async {
      await t.pumpWidget(app(swipeBack: mode));
      await t.pumpAndSettle();
      OmniRoute.push('/a');
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(OmniRoute.current.location, '/');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  group('OmniRoute.open', () {
    testWidgets('no duplicates; pops back to an existing page', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      OmniRoute.open('/a');
      await t.pumpAndSettle();
      OmniRoute.open('/a');
      await t.pumpAndSettle();
      expect(OmniRoute.stack.map((e) => e.location), ['/', '/a']);

      OmniRoute.open('/b');
      OmniRoute.open('/c');
      await t.pumpAndSettle();
      expect(OmniRoute.stack.map((e) => e.location), ['/', '/a', '/b', '/c']);

      OmniRoute.open('/a');
      await t.pumpAndSettle();
      expect(OmniRoute.stack.map((e) => e.location), ['/', '/a']);
      expect(find.text('a'), findsOneWidget);
      OmniRoute.open('/');
      await t.pumpAndSettle();
      expect(OmniRoute.stack.map((e) => e.location), ['/']);
    });

    testWidgets('honours maxDepth', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      OmniRoute.open('/a', maxDepth: 3);
      OmniRoute.open('/b', maxDepth: 3);
      await t.pumpAndSettle();
      expect(OmniRoute.stack.length, 3);
      OmniRoute.open('/c', maxDepth: 3);
      await t.pumpAndSettle();
      expect(OmniRoute.stack.map((e) => e.location), ['/c']);
    });
  });
}
