import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class _TestCubit extends Cubit<int> {
  _TestCubit(super.initialState);

  static int closedCount = 0;

  void increment() => emit(state + 1);

  @override
  Future<void> close() {
    closedCount++;
    return super.close();
  }
}

class _PlainWidget extends StatelessWidget {
  const _PlainWidget(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<_TestCubit>();
    return Scaffold(
      body: Column(
        children: [
          Text('$label:${cubit.state}'),
          TextButton(onPressed: cubit.increment, child: const Text('inc')),
        ],
      ),
    );
  }
}

class _ContextScreen extends OmniStatelessWidget {
  const _ContextScreen();

  @override
  String get routePath => '/ctx';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('param:${context.params.path('id')}'),
        TextButton(
          onPressed: () => context.push('/b', animated: false),
          child: const Text('push-instant'),
        ),
        TextButton(
          onPressed: () => context.to<_TargetScreen>(path: {'code': 99}),
          child: const Text('to-target'),
        ),
      ],
    ),
  );
}

class _TargetScreen extends OmniStatelessWidget {
  const _TargetScreen(this.code);
  final int code;

  @override
  String get routePath => '/target';

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('target:${context.routeState.location}:$code'));
}

void main() {
  setUp(() => _TestCubit.closedCount = 0);

  testWidgets('animated: false and OmniPages.none open instantaneously', (
    t,
  ) async {
    await t.pumpWidget(
      OmniApp(
        transition: OmniPages.fade,
        routes: [
          OmniPage('/', (_) => const Scaffold(body: Text('home'))),
          OmniPage('/next', (_) => const Scaffold(body: Text('next'))),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();

    OmniRoute.push('/next', animated: false);
    final frames = await t.pumpAndSettle();
    expect(frames, lessThanOrEqualTo(2));
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('per-call transition override works cleanly', (t) async {
    await t.pumpWidget(
      OmniApp(
        transition: OmniPages.none,
        routes: [
          OmniPage('/', (_) => const Scaffold(body: Text('home'))),
          OmniPage('/up', (_) => const Scaffold(body: Text('up'))),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();

    OmniRoute.push('/up', transition: OmniPages.slideUp);
    await t.pump();
    final page = t.widget<Navigator>(find.byType(Navigator).first).pages.last;
    expect(page, isA<OmniSwipeBackPage<void>>());
    await t.pumpAndSettle();
    expect(find.text('up'), findsOneWidget);
  });

  testWidgets('plain Widget works in OmniPage with inline provide', (t) async {
    await t.pumpWidget(
      OmniApp(
        transition: OmniPages.none,
        routes: [
          OmniPage('/', (_) => const Scaffold(body: Text('root'))),
          OmniPage<_PlainWidget>(
            '/plain',
            (_) => const _PlainWidget('plain'),
            provide: [Provide<_TestCubit>.create((_) => _TestCubit(10))],
          ),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();

    OmniRoute.pushTo<_PlainWidget, void>();
    await t.pumpAndSettle();
    expect(find.text('plain:10'), findsOneWidget);

    await t.tap(find.text('inc'));
    await t.pump();
    expect(find.text('plain:11'), findsOneWidget);

    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(_TestCubit.closedCount, 1);
  });

  testWidgets('OmniPage onExit confirms or blocks pop', (t) async {
    var allow = false;
    await t.pumpWidget(
      OmniApp(
        transition: OmniPages.none,
        routes: [
          OmniPage('/', (_) => const Scaffold(body: Text('home'))),
          OmniPage(
            '/edit',
            (_) => const Scaffold(body: Text('edit')),
            onExit: (_) async => allow,
          ),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();

    OmniRoute.push('/edit');
    await t.pumpAndSettle();
    expect(find.text('edit'), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('edit'), findsOneWidget, reason: 'blocked when false');

    allow = true;
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('BuildContext extensions and currentListenable react cleanly', (
    t,
  ) async {
    final seen = <String>[];
    await t.pumpWidget(
      OmniApp(
        transition: OmniPages.none,
        routes: [
          OmniPage('/a/:id', (_) => const _ContextScreen()),
          OmniPage('/b', (_) => const Scaffold(body: Text('page-b'))),
          OmniPage<_TargetScreen>(
            '/target/:code',
            (p) => _TargetScreen(p.pathInt('code')),
          ),
        ],
        initialRoute: '/a/42',
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    final listenable = OmniRoute.currentListenable;
    void listener() => seen.add(listenable.value.location);
    listenable.addListener(listener);
    addTearDown(() => listenable.removeListener(listener));

    await t.pumpAndSettle();
    expect(find.text('param:42'), findsOneWidget);

    await t.tap(find.text('push-instant'));
    await t.pumpAndSettle();
    expect(find.text('page-b'), findsOneWidget);
    expect(seen, contains('/b'));

    OmniRoute.pop();
    await t.pumpAndSettle();
    await t.tap(find.text('to-target'));
    await t.pumpAndSettle();
    expect(find.text('target:/target/99:99'), findsOneWidget);
  });

  testWidgets('Segment Trie static wins over :param and backtracks cleanly', (
    t,
  ) async {
    await t.pumpWidget(
      OmniApp(
        transition: OmniPages.none,
        routes: [
          OmniPage(
            '/users/:id',
            (p) => Scaffold(body: Text('user:${p.path('id')}')),
            routes: [
              OmniPage(
                'edit',
                (p) => Scaffold(body: Text('edit:${p.path('id')}')),
              ),
            ],
          ),
          OmniPage(
            '/users/new',
            (_) => const Scaffold(body: Text('user:STATIC_NEW')),
          ),
        ],
        initialRoute: '/users/new',
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('user:STATIC_NEW'), findsOneWidget);

    OmniRoute.go('/users/new/edit');
    await t.pumpAndSettle();
    expect(find.text('edit:new'), findsOneWidget);
  });

  testWidgets('custom animation transitionsBuilder renders without error', (
    t,
  ) async {
    await t.pumpWidget(
      OmniApp(
        routes: [
          OmniPage('/', (_) => const Scaffold(body: Text('start'))),
          OmniPage(
            '/rot',
            (_) => const Scaffold(body: Text('rotated')),
            transition: OmniPages.custom(
              (c, anim, sec, child) =>
                  ScaleTransition(scale: anim, child: child),
              duration: const Duration(milliseconds: 100),
            ),
          ),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();

    OmniRoute.push('/rot');
    await t.pumpAndSettle();
    expect(find.text('rotated'), findsOneWidget);
  });
}
