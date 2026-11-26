import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

int created = 0, closed = 0;
final builds = <String, int>{};

class PageBloc extends Bloc<int, int> {
  PageBloc() : super(0) {
    created++;
    on<int>((e, emit) => emit(e));
  }
  @override
  Future<void> close() {
    closed++;
    return super.close();
  }
}

class GlobalBloc extends Bloc<int, int> {
  GlobalBloc() : super(0) {
    on<int>((e, emit) => emit(e));
  }
}

class P extends OmniStatelessWidget {
  const P(this.label, {super.key});
  final String label;
  @override
  String get routePath => '/${label.replaceAll(' ', '-').toLowerCase()}';
  @override
  List<Provide> get provide => const [Provide<PageBloc>(lazy: false)];
  @override
  Widget build(BuildContext context) {
    builds[label] = (builds[label] ?? 0) + 1;
    return Text(label);
  }
}

late OmniNavigationShell shell;

Widget app({int extraRoutes = 0}) => OmniApp(
  blocs: [
    OmniBloc<PageBloc>((_) => PageBloc()),
    OmniBloc<GlobalBloc>((_) => GlobalBloc(), global: true, lazy: false),
  ],
  routes: [
    OmniPage('/', (_) => const P('home')),
    OmniPage('/item/:id', (p) => P('item ${p.path('id')}')),
    OmniStatefulShell(
      builder: (_, _, s) => shell = s,
      branches: [
        OmniBranch(routes: [OmniPage('/t0', (_) => const P('t0'))]),
        OmniBranch(routes: [OmniPage('/t1', (_) => const P('t1'))]),
      ],
    ),
    for (var i = 0; i < extraRoutes; i++) OmniPage('/r$i/:id', (p) => P('r$i')),
  ],
  builder: (_, router) => MaterialApp.router(routerConfig: router),
);

void main() {
  setUp(() {
    created = closed = 0;
    builds.clear();
  });

  testWidgets('long session: 1000 mixed navigations, no resource growth', (
    t,
  ) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    final elementsAtStart = _countElements(t);
    for (var i = 0; i < 1000; i++) {
      switch (i % 4) {
        case 0:
          OmniRoute.push('/item/$i');
        case 1:
          OmniRoute.pop();
        case 2:
          OmniRoute.go('/item/$i');
        case 3:
          OmniRoute.go('/');
      }
      await t.pumpAndSettle();
    }
    expect(OmniRoute.location.path, '/');
    expect(
      created - closed,
      1,
      reason: 'only the visible home page bloc is alive',
    );
    expect(
      _countElements(t),
      elementsAtStart,
      reason: 'widget tree returns to same size',
    );
  });

  testWidgets('covered page and app root are not rebuilt by push', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    final homeBuilds = builds['home']!;
    for (var i = 0; i < 20; i++) {
      OmniRoute.push('/item/$i');
      await t.pumpAndSettle();
    }
    expect(
      builds['home'],
      homeBuilds,
      reason: 'home stays untouched under 20 pushes',
    );
    expect(created, 21, reason: 'one bloc per page, never recreated');
  });

  testWidgets('global bloc state change does not rebuild screens', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    final before = builds['home']!;
    final g = t.element(find.text('home')).read<GlobalBloc>();
    for (var i = 1; i <= 50; i++) {
      g.add(i);
      await t.pump();
    }
    expect(builds['home'], before);
  });

  testWidgets('tab switching: 500 switches, no rebuild storms or recreation', (
    t,
  ) async {
    await t.pumpWidget(app());
    OmniRoute.go('/t0');
    await t.pumpAndSettle();
    shell.goBranch(1);
    await t.pumpAndSettle();
    final c = created;
    for (var i = 0; i < 500; i++) {
      shell.goBranch(i.isEven ? 0 : 1);
      await t.pumpAndSettle();
    }
    expect(created, c, reason: 'tab blocs reused');
    expect(closed, 1, reason: 'only home closed when entering shell');
    // Each switch may rebuild the newly shown tab at most once.
    expect(builds['t0']! + builds['t1']!, lessThanOrEqualTo(2 + 500));
  });

  testWidgets('large registry: 1000 routes validate and match quickly', (
    t,
  ) async {
    final sw = Stopwatch()..start();
    await t.pumpWidget(app(extraRoutes: 1000));
    final startup = sw.elapsedMilliseconds;
    sw.reset();
    for (var i = 0; i < 100; i++) {
      OmniRoute.go('/r999/$i');
      await t.pump();
    }
    final nav = sw.elapsedMilliseconds;
    // Loose ceilings for slow CI; real numbers come from the profile benchmark.
    expect(startup, lessThan(2000));
    expect(nav / 100, lessThan(50));
    expect(find.text('r999'), findsOneWidget);
    debugPrint(
      '1000-route startup ${startup}ms, avg go+frame ${nav / 100}ms (debug, test env)',
    );
  });

  testWidgets('push/pop above a lifecycle screen does not rebuild it', (
    t,
  ) async {
    _CountedFeed.builds = 0;
    await t.pumpWidget(
      OmniApp(
        routes: [
          OmniPage('/', (_) => const _CountedFeed()),
          OmniPage('/other', (_) => const _Other()),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();
    expect(_CountedFeed.builds, 1);
    for (var i = 0; i < 5; i++) {
      OmniRoute.push('/other');
      await t.pumpAndSettle();
      OmniRoute.pop();
      await t.pumpAndSettle();
    }
    // Visibility still tracked (hooks ran) without rebuilding the screen.
    expect(_CountedFeed.events, 11);
    expect(_CountedFeed.builds, 1);
  });
}

int _countElements(WidgetTester t) {
  var n = 0;
  void visit(Element e) {
    n++;
    e.visitChildren(visit);
  }

  t.binding.rootElement!.visitChildren(visit);
  return n;
}

class _CountedFeed extends OmniStatelessWidget with OmniLifecycle {
  const _CountedFeed();
  static int builds = 0;
  static int events = 0;
  @override
  String get routePath => '/counted';
  @override
  void onScreenVisible(BuildContext c) => events++;
  @override
  void onScreenHidden(BuildContext c) => events++;
  @override
  Widget build(BuildContext context) {
    builds++;
    return const Text('counted');
  }
}

class _Other extends OmniStatelessWidget {
  const _Other();
  @override
  String get routePath => '/other';
  @override
  Widget build(BuildContext context) => const Text('other');
}
