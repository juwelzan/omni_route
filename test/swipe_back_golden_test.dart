// 0.2.6: one golden per swipe-back mode, held at p = 0.5.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class Colored extends OmniStatelessWidget {
  const Colored(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  String get screenName => label;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: color,
    body: Column(
      children: [
        Container(height: 80, color: Colors.black26),
        for (var i = 0; i < 6; i++)
          Container(
            margin: const EdgeInsets.all(12),
            height: 40,
            color: Colors.white70,
          ),
      ],
    ),
  );
}

Widget app(OmniSwipeBack mode, {OmniSwipeBackStyle? style}) => OmniApp(
  swipeBack: mode,
  swipeBackStyle: style ?? const OmniSwipeBackStyle(),
  transition: OmniPages.fade,
  routes: [
    OmniPage('/', (_) => const Colored('below', Colors.teal)),
    OmniPage('/top', (_) => const Colored('top', Colors.deepOrange)),
  ],
  builder: (_, r) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(scaffoldBackgroundColor: Colors.grey.shade300),
    routerConfig: r,
  ),
);

/// Opens /top and holds a left-edge drag at exactly half the width.
Future<TestGesture> holdHalf(WidgetTester t, OmniSwipeBack mode) async {
  await t.pumpWidget(app(mode));
  await t.pumpAndSettle();
  OmniRoute.push('/top');
  await t.pumpAndSettle();
  final g = await t.startGesture(const Offset(4, 300));
  await g.moveBy(const Offset(400, 0)); // 800 px wide: p = 0.5
  await t.pump();
  return g;
}

void main() {
  for (final mode in OmniSwipeBack.values.skip(1)) {
    testWidgets('golden: ${mode.name} at p = 0.5', (t) async {
      final g = await holdHalf(t, mode);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/swipe_${mode.name}.png'),
      );
      await g.moveBy(const Offset(-400, 0));
      await g.up();
      await t.pumpAndSettle();
      expect(OmniRoute.current.location, '/top');
    });
  }

  testWidgets('an idle page has no swipe wrappers', (t) async {
    await t.pumpWidget(app(OmniSwipeBack.zoomTilt));
    await t.pumpAndSettle();
    OmniRoute.push('/top');
    await t.pumpAndSettle();
    final top = find.byType(Colored).last;
    int count(Type type) =>
        find.ancestor(of: top, matching: find.byType(type)).evaluate().length;
    final before = (count(Transform), count(Opacity), count(ClipRRect));
    final g = await t.startGesture(const Offset(4, 300));
    await g.moveBy(const Offset(400, 0));
    await t.pump();
    expect(count(Transform), greaterThan(before.$1), reason: 'while swiping');
    await g.moveBy(const Offset(-400, 0));
    await g.up();
    await t.pumpAndSettle();
    expect((count(Transform), count(Opacity), count(ClipRRect)), before);
  });

  testWidgets('swipe wrappers keep the page state', (t) async {
    await t.pumpWidget(app(OmniSwipeBack.zoom));
    await t.pumpAndSettle();
    OmniRoute.push('/top');
    await t.pumpAndSettle();
    final element = t.element(find.byType(Colored).last);
    final g = await t.startGesture(const Offset(4, 300));
    await g.moveBy(const Offset(200, 0));
    await t.pump();
    expect(t.element(find.byType(Colored).last), same(element));
    await g.moveBy(const Offset(-200, 0));
    await g.up();
    await t.pumpAndSettle();
    expect(t.element(find.byType(Colored).last), same(element));
  });

  testWidgets('zoomParallax and slide change the page below', (t) async {
    for (final mode in [OmniSwipeBack.zoomParallax, OmniSwipeBack.slide]) {
      final g = await holdHalf(t, mode);
      final below = t.getRect(find.byType(Colored).first);
      expect(
        below,
        isNot(const Rect.fromLTWH(0, 0, 800, 600)),
        reason: '$mode',
      );
      await g.up();
      await t.pumpAndSettle();
      expect(OmniRoute.current.location, '/top', reason: 'p = 0.5 is not past');
    }
  });

  testWidgets('zoom leaves the page below unchanged', (t) async {
    final g = await holdHalf(t, OmniSwipeBack.zoom);
    expect(
      t.getRect(find.byType(Colored).first),
      const Rect.fromLTWH(0, 0, 800, 600),
    );
    await g.moveBy(const Offset(-400, 0));
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('presets build', (t) async {
    for (final style in const [
      OmniSwipeBackStyle.subtle(),
      OmniSwipeBackStyle.dramatic(),
    ]) {
      await t.pumpWidget(app(OmniSwipeBack.zoomCard, style: style));
      await t.pumpAndSettle();
      OmniRoute.push('/top');
      await t.pumpAndSettle();
      await t.timedDragFrom(
        const Offset(4, 300),
        const Offset(600, 0),
        const Duration(seconds: 1),
      );
      await t.pumpAndSettle();
      expect(OmniRoute.current.location, '/');
    }
  });
}
