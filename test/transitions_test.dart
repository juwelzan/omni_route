// 0.2.4: page transition builders and built-in animations.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get screenName => label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

Widget app(
  OmniPageType type, {
  TextDirection dir = TextDirection.ltr,
  List<OmniRouteBase> extra = const [],
}) => OmniApp(
  transition: type,
  routes: [
    OmniPage('/', (_) => const S('home')),
    OmniPage('/next', (_) => const S('next')),
    ...extra,
  ],
  builder: (_, r) => MaterialApp.router(
    routerConfig: r,
    builder: (_, child) => Directionality(textDirection: dir, child: child!),
  ),
);

Page<Object?> top(WidgetTester t) =>
    t.widget<Navigator>(find.byType(Navigator).first).pages.last;

double opacityOf(WidgetTester t, String text) {
  var o = 1.0;
  for (final f in t.widgetList<FadeTransition>(
    find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)),
  )) {
    o *= f.opacity.value;
  }
  return o;
}

void main() {
  final builtIns = <String, OmniPageType>{
    'fade': OmniPages.fade,
    'slide': OmniPages.slide,
    'slideUp': OmniPages.slideUp,
    'scale': OmniPages.scale,
    'fadeScale': OmniPages.fadeScale,
    'fadeSlide': OmniPages.fadeSlide,
  };

  for (final MapEntry(key: name, value: type) in builtIns.entries) {
    testWidgets('$name: fast, animates, completes, pops back', (t) async {
      await t.pumpWidget(app(type));
      await t.pumpAndSettle();
      OmniRoute.push('/next');
      await t.pump();
      final page = top(t) as OmniSwipeBackPage<void>;
      expect(page.transitionDuration, const Duration(milliseconds: 250));
      expect(page.reverseTransitionDuration, const Duration(milliseconds: 200));
      expect(page.restorationId, isNotNull, reason: 'restoration still works');

      await t.pump(const Duration(milliseconds: 100)); // mid-animation
      final rect = t.getRect(find.text('next'));
      final moving =
          opacityOf(t, 'next') < 1 ||
          rect.center != t.getCenter(find.byType(Navigator).first);
      expect(moving, isTrue, reason: 'something is animating at 100ms');

      // 100ms already passed; 160ms more = 260ms after the push.
      await t.pump(const Duration(milliseconds: 160));
      expect(
        t.binding.hasScheduledFrame,
        isFalse,
        reason: 'animation finished within ~250ms',
      );
      expect(opacityOf(t, 'next'), 1);
      expect(
        t.getCenter(find.text('next')),
        t.getCenter(find.byType(Navigator).first),
      );

      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.text('next'), findsNothing);
    });
  }

  testWidgets('slide enters from the right in LTR and from the left in RTL', (
    t,
  ) async {
    for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
      await t.pumpWidget(app(OmniPages.slide, dir: dir));
      await t.pumpAndSettle();
      OmniRoute.push('/next');
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final x = t.getCenter(find.text('next')).dx;
      final mid = t.getCenter(find.byType(Navigator).first).dx;
      expect(
        dir == TextDirection.ltr ? x > mid : x < mid,
        isTrue,
        reason: '$dir',
      );
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('slide shifts the page below (parallax)', (t) async {
    await t.pumpWidget(app(OmniPages.slide));
    await t.pumpAndSettle();
    final before = t.getCenter(find.text('home')).dx;
    OmniRoute.push('/next');
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    expect(
      t.getCenter(find.text('home', skipOffstage: false)).dx,
      lessThan(before),
    );
  });

  testWidgets('transition() takes duration and curve', (t) async {
    await t.pumpWidget(
      app(
        OmniPages.transition(
          OmniTransition.fade,
          duration: const Duration(milliseconds: 120),
          reverseDuration: const Duration(milliseconds: 80),
          curve: Curves.linear,
        ),
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/next');
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(
      opacityOf(t, 'next'),
      closeTo(0.5, 0.05),
      reason: 'linear at half time',
    );
    final page = top(t) as OmniSwipeBackPage<void>;
    expect(page.transitionDuration.inMilliseconds, 120);
    expect(page.reverseTransitionDuration.inMilliseconds, 80);
  });

  testWidgets('custom builder is used; dialog-style page keeps the one below', (
    t,
  ) async {
    var calls = 0;
    await t.pumpWidget(
      app(
        OmniPages.material,
        extra: [
          OmniPage(
            '/dialog',
            (_) => const S('dialog'),
            transition: OmniPages.custom(
              (context, a, s, child) {
                calls++;
                return RotationTransition(
                  turns: a.drive(Tween(begin: 0.9, end: 1.0)),
                  child: child,
                );
              },
              opaque: false,
              barrierColor: Colors.black54,
            ),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/dialog');
    await t.pumpAndSettle();
    expect(calls, greaterThan(0));
    expect(find.byType(RotationTransition), findsWidgets);
    expect(
      find.text('home'),
      findsOneWidget,
      reason: 'not opaque: page below stays',
    );
    expect(find.text('dialog'), findsOneWidget);
  });

  testWidgets('per-route transition overrides the app default', (t) async {
    await t.pumpWidget(
      app(
        OmniPages.material,
        extra: [
          OmniPage('/up', (_) => const S('up'), transition: OmniPages.slideUp),
        ],
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/next');
    await t.pumpAndSettle();
    expect(top(t), isA<MaterialPage<void>>());
    OmniRoute.push('/up');
    await t.pump();
    expect(top(t), isA<OmniSwipeBackPage<void>>());
  });

  testWidgets('screen state survives the transition', (t) async {
    await t.pumpWidget(
      app(OmniPages.fadeSlide, extra: [OmniPage('/c', (_) => const Counter())]),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/c');
    await t.pumpAndSettle();
    await t.tap(find.text('count 0'));
    await t.pump();
    OmniRoute.push('/next');
    await t.pumpAndSettle();
    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(find.text('count 1'), findsOneWidget);
  });
}

class Counter extends OmniStatefulWidget {
  const Counter({super.key});
  @override
  String get screenName => 'counter';
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends OmniState<Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => setState(() => n++),
      child: Text('count $n'),
    ),
  );
}
