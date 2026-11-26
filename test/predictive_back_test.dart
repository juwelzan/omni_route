// Android predictive back (system back gesture) driving the swipe styles.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

late OmniNavigationShell shell;

Widget app({
  bool predictive = true,
  OmniSwipeBack swipeBack = OmniSwipeBack.none,
  OmniPageType transition = OmniPages.material,
  void Function(OmniNavigation)? onNavigate,
}) => OmniApp(
  predictiveBack: predictive,
  swipeBack: swipeBack,
  transition: transition,
  onNavigate: onNavigate,
  routes: [
    OmniPage('/', (_) => const Home()),
    OmniPage('/a', (_) => const S('a')),
    OmniPage('/b', (_) => const S('b')),
    OmniPage('/locked', (_) => const Locked()),
    OmniPage(
      '/off',
      (_) => const S('off'),
      transition: OmniPages.transition(
        OmniTransition.fade,
        swipeBack: OmniSwipeBack.none,
      ),
    ),
    OmniStatefulShell(
      builder: (_, _, s) => shell = s,
      branches: [
        OmniBranch(
          routes: [
            OmniPage(
              '/t/one',
              (_) => const S('one'),
              routes: [OmniPage('d', (_) => const S('one-detail'))],
            ),
          ],
        ),
        OmniBranch(
          routes: [
            OmniPage(
              '/t/two',
              (_) => const S('two'),
              routes: [OmniPage('d', (_) => const S('two-detail'))],
            ),
          ],
        ),
      ],
    ),
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

/// Sends a predictive-back message like the Android embedder does.
Future<void> backGesture(
  WidgetTester t,
  String method, {
  double progress = 0,
  bool left = true,
  bool button = false,
}) async {
  final args = method == 'commitBackGesture' || method == 'cancelBackGesture'
      ? null
      : <String, Object?>{
          'touchOffset': button ? null : <double>[left ? 5 : 795, 300],
          'progress': progress,
          'swipeEdge': left ? 0 : 1,
        };
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.backGesture.name,
    SystemChannels.backGesture.codec.encodeMethodCall(MethodCall(method, args)),
    (_) {},
  );
  await t.pump();
}

/// Scale and x-offset of the swipe transform around [label]'s page.
/// (entry(0, 0), not getMaxScaleOnAxis: z stays 1, so that is always 1.)
(double, double) swipeTransform(WidgetTester t, String label) {
  var scale = 1.0, dx = 0.0;
  for (final e
      in find
          .ancestor(of: find.text(label), matching: find.byType(Transform))
          .evaluate()) {
    final m = (e.widget as Transform).transform;
    if (m.entry(0, 0) != 1 || m.entry(0, 3) != 0) {
      scale = m.entry(0, 0);
      dx = m.entry(0, 3);
    }
  }
  return (scale, dx);
}

Future<void> openA(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  await t.pumpAndSettle();
  OmniRoute.push('/a');
  await t.pumpAndSettle();
}

void main() {
  setUp(log.clear);

  testWidgets('progress zooms the page out; commit pops via go_router', (
    t,
  ) async {
    final navs = <String>[];
    await openA(t, app(onNavigate: (n) => navs.add(n.to.location)));
    log.clear();
    await backGesture(t, 'startBackGesture', progress: 0.1);
    await backGesture(t, 'updateBackGestureProgress', progress: 0.5);
    final (scale, dx) = swipeTransform(t, 'a');
    expect(scale, closeTo(0.91, 0.001), reason: '1 → 0.82 at p = 0.5');
    expect(
      dx,
      closeTo(0.5 * 800 * 0.45, 0.01),
      reason: 'left edge: moves right',
    );
    expect(find.text('home'), findsOneWidget, reason: 'page below visible');

    await backGesture(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(OmniRoute.current.location, '/');
    expect(OmniRoute.stack.map((e) => e.location), ['/']);
    expect(navs.last, '/');
    expect(log, ['home:visible']);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    expect(nav.userGestureInProgress, isFalse);
  });

  testWidgets('cancel springs back', (t) async {
    await openA(t, app());
    await backGesture(t, 'startBackGesture', progress: 0.3);
    await backGesture(t, 'updateBackGestureProgress', progress: 0.6);
    await backGesture(t, 'cancelBackGesture');
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/a');
    expect(swipeTransform(t, 'a'), (1.0, 0.0));
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    expect(nav.userGestureInProgress, isFalse);
  });

  testWidgets('right edge moves the page left', (t) async {
    await openA(t, app());
    await backGesture(t, 'startBackGesture', progress: 0.5, left: false);
    final (_, dx) = swipeTransform(t, 'a');
    expect(dx, lessThan(0));
    await backGesture(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/');
  });

  testWidgets('a back button press is not taken and pops normally', (t) async {
    await openA(t, app());
    await backGesture(t, 'startBackGesture', button: true);
    expect(swipeTransform(t, 'a'), (1.0, 0.0));
    await backGesture(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/');
  });

  testWidgets('first page: not taken, nothing pops', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await backGesture(t, 'startBackGesture', progress: 0.5);
    expect(swipeTransform(t, 'home'), (1.0, 0.0));
    await backGesture(t, 'cancelBackGesture');
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('PopScope(canPop: false): not taken, page stays', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    OmniRoute.push('/locked');
    await t.pumpAndSettle();
    await backGesture(t, 'startBackGesture', progress: 0.5);
    expect(swipeTransform(t, 'locked'), (1.0, 0.0));
    await backGesture(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);
  });

  testWidgets('predictiveBack off: plain pop, no zoom', (t) async {
    await openA(t, app(predictive: false, transition: OmniPages.fade));
    await backGesture(t, 'startBackGesture', progress: 0.5);
    expect(swipeTransform(t, 'a'), (1.0, 0.0));
    await backGesture(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/');
  });

  testWidgets('page-level swipeBack: none: plain pop, no zoom', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    OmniRoute.push('/off');
    await t.pumpAndSettle();
    await backGesture(t, 'startBackGesture', progress: 0.5);
    expect(swipeTransform(t, 'off'), (1.0, 0.0));
    await backGesture(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/');
  });

  testWidgets('follows the app swipe style (zoomCenter: no slide)', (t) async {
    await openA(t, app(swipeBack: OmniSwipeBack.zoomCenter));
    await backGesture(t, 'startBackGesture', progress: 0.5);
    final (scale, dx) = swipeTransform(t, 'a');
    expect(scale, closeTo(0.875, 0.001));
    expect(dx, 0);
    await backGesture(t, 'cancelBackGesture');
    await t.pumpAndSettle();
  });

  testWidgets('material pages use swipeZoom on Android only', (t) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      await openA(t, app());
      await backGesture(t, 'startBackGesture', progress: 0.5);
      final (scale, _) = swipeTransform(t, 'a');
      expect(
        scale < 1,
        platform == TargetPlatform.android,
        reason: '$platform',
      );
      await backGesture(t, 'cancelBackGesture');
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('in a shell, only the visible top page takes the gesture', (
    t,
  ) async {
    await t.pumpWidget(app());
    OmniRoute.go('/t/two/d');
    await t.pumpAndSettle();
    shell.goBranch(0);
    await t.pumpAndSettle();
    OmniRoute.go('/t/one/d');
    await t.pumpAndSettle();
    await backGesture(t, 'startBackGesture', progress: 0.5);
    expect(swipeTransform(t, 'one-detail').$1, lessThan(1));
    await backGesture(t, 'commitBackGesture');
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/t/one');
    shell.goBranch(1);
    await t.pumpAndSettle();
    expect(find.text('two-detail'), findsOneWidget, reason: 'other tab kept');
  });

  testWidgets('OmniPages.swipeZoom: zoom even with the app default off', (
    t,
  ) async {
    await openA(t, app(transition: OmniPages.swipeZoom));
    await backGesture(t, 'startBackGesture', progress: 0.5);
    expect(swipeTransform(t, 'a').$1, closeTo(0.91, 0.001));
    await backGesture(t, 'commitBackGesture');
    await t.pumpAndSettle();
    // In-app edge swipe too (zoom is set on the page type).
    OmniRoute.push('/a');
    await t.pumpAndSettle();
    await t.timedDragFrom(
      const Offset(5, 300),
      const Offset(500, 0),
      const Duration(seconds: 1),
    );
    await t.pumpAndSettle();
    expect(OmniRoute.current.location, '/');
  });
}
