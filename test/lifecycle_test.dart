import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

final log = <String>[];

/// Stateless screen with hooks.
class Feed extends OmniStatelessWidget with OmniLifecycle {
  const Feed({super.key});
  @override
  String get screenName => 'feed';
  @override
  Widget build(BuildContext context) => const Text('feed');

  @override
  void onAppLifecycleChanged(BuildContext c, AppLifecycleState s) =>
      log.add('feed:app:${s.name}');
  @override
  void onAppResumed(BuildContext c) => log.add('feed:resumed');
  @override
  void onAppPaused(BuildContext c) => log.add('feed:paused');
  @override
  void onScreenVisible(BuildContext c) => log.add('feed:visible');
  @override
  void onScreenHidden(BuildContext c) => log.add('feed:hidden');
  @override
  void onMemoryPressure(BuildContext c) => log.add('feed:memory');
  @override
  void onMetricsChanged(BuildContext c) => log.add('feed:metrics');
  @override
  void onBrightnessChanged(BuildContext c, Brightness b) =>
      log.add('feed:${b.name}');
  @override
  void onLocalesChanged(BuildContext c, List<Locale>? l) =>
      log.add('feed:locale:${l?.first}');
  @override
  void onTextScaleChanged(BuildContext c) => log.add('feed:textscale');
}

/// Stateful screen with hooks on its State.
class Player extends OmniStatefulWidget {
  const Player({super.key});
  @override
  String get screenName => 'player';
  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends OmniState<Player> with OmniLifecycle {
  bool playing = true;
  @override
  void onScreenHidden(BuildContext c) {
    setState(() => playing = false); // setState is safe in hooks
    log.add('player:hidden');
  }

  @override
  void onScreenVisible(BuildContext c) => log.add('player:visible');
  @override
  void onAppPaused(BuildContext c) => log.add('player:paused');
  @override
  Widget build(BuildContext context) => Text('player $playing');
}

/// A screen without the mixin: unaffected.
class Plain extends OmniStatelessWidget {
  const Plain(this.label, {super.key});
  final String label;
  @override
  String get screenName => label;
  @override
  Widget build(BuildContext context) => Text(label);
}

late OmniNavigationShell shell;

Widget app({String initial = '/'}) => OmniApp(
  initialRoute: initial,
  routes: [
    OmniPage('/', (_) => const Feed()),
    OmniPage('/player', (_) => const Player()),
    OmniPage('/other', (_) => const Plain('other')),
    OmniStatefulShell(
      builder: (_, _, s) => shell = s,
      branches: [
        OmniBranch(routes: [OmniPage('/t/feed', (_) => const Feed())]),
        OmniBranch(
          routes: [OmniPage('/t/plain', (_) => const Plain('plain'))],
        ),
      ],
    ),
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

void main() {
  setUp(log.clear);

  testWidgets('app lifecycle hooks (stateless)', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    log.clear();
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    expect(log, [
      'feed:app:inactive',
      'feed:app:hidden',
      'feed:app:paused',
      'feed:paused',
      'feed:app:hidden',
      'feed:app:inactive',
      'feed:app:resumed',
      'feed:resumed',
    ]);
  });

  testWidgets('system change hooks', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    log.clear();
    t.binding.handleMemoryPressure();
    t.view.physicalSize = const Size(1000, 600);
    addTearDown(t.view.resetPhysicalSize);
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    t.platformDispatcher.localesTestValue = const [Locale('bn', 'BD')];
    addTearDown(t.platformDispatcher.clearLocalesTestValue);
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pump();
    expect(
      log,
      containsAll([
        'feed:memory',
        'feed:metrics',
        'feed:dark',
        'feed:locale:bn_BD',
        'feed:textscale',
      ]),
    );
  });

  testWidgets('visibility follows push and pop (both screen types)', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(log, ['feed:visible']);

    OmniRoute.push('/player');
    await t.pumpAndSettle();
    expect(log, ['feed:visible', 'feed:hidden', 'player:visible']);

    OmniRoute.push('/other');
    await t.pumpAndSettle();
    expect(log.last, 'player:hidden');
    expect(
      find.text('player false', skipOffstage: false),
      findsOneWidget,
      reason: 'setState in a hook works',
    );

    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(log.last, 'player:visible');
    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(log.last, 'feed:visible');
    expect(
      log.where((e) => e == 'player:hidden').length,
      2,
      reason: 'covered by /other, then popped: every visible gets a hidden',
    );
  });

  testWidgets('visibility follows stateful shell tabs', (t) async {
    await t.pumpWidget(app(initial: '/t/feed'));
    await t.pumpAndSettle();
    log.clear();
    shell.goBranch(1);
    await t.pumpAndSettle();
    expect(log, ['feed:hidden']);
    shell.goBranch(0);
    await t.pumpAndSettle();
    expect(log, ['feed:hidden', 'feed:visible']);
  });

  testWidgets('app hooks reach covered screens; none after dispose', (t) async {
    await t.pumpWidget(app());
    OmniRoute.push('/player');
    await t.pumpAndSettle();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(
      log,
      containsAll(['feed:paused', 'player:paused']),
      reason: 'app hooks reach covered screens too',
    );

    // Frames only run while resumed; resume before removing the app.
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(const SizedBox());
    expect(find.byType(Feed, skipOffstage: false), findsNothing);
    log.clear();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    t.binding.handleMemoryPressure();
    expect(log, isEmpty);
  });

  testWidgets('a visible screen that is removed reports hidden', (t) async {
    for (final initial in ['/', '/player']) {
      log.clear();
      await t.pumpWidget(app(initial: initial));
      await t.pumpAndSettle();
      // The whole subtree goes away in one frame (no rebuild first).
      await t.pumpWidget(const SizedBox());
      final name = initial == '/' ? 'feed' : 'player';
      expect(log, ['$name:visible', '$name:hidden'], reason: initial);
    }
  });

  testWidgets('hidden is reported once when go removes the page', (t) async {
    await t.pumpWidget(
      OmniApp(
        transition: OmniPages.none,
        routes: [
          OmniPage('/', (_) => const Feed()),
          OmniPage('/other', (_) => const Plain('other')),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.go('/other');
    await t.pumpAndSettle();
    expect(log, ['feed:visible', 'feed:hidden']);
  });

  testWidgets('stateless screen outside a route gets hooks too', (t) async {
    await t.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: Feed()),
    );
    await t.pump();
    expect(log, ['feed:visible']);
    t.binding.handleMemoryPressure();
    expect(log.last, 'feed:memory');
  });
}
