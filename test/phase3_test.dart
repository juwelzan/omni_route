// 0.3.0: navigation helpers, OmniLifecycle misuse report, Cubits, dialog
// and bottom-sheet routes.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class Item extends OmniStatelessWidget {
  const Item({super.key, required this.id});
  final int id;
  @override
  String get screenName => 'item';
  @override
  Widget build(BuildContext context) => Text('item $id');
}

late OmniNavigationShell shell;

Widget app({
  List<OmniBloc> blocs = const [],
  List<OmniRouteBase> extra = const [],
}) => OmniApp(
  blocs: blocs,
  routes: [
    OmniPage('/', (_) => const S('home')),
    OmniPage('/a', (_) => const S('a')),
    OmniPage('/b', (_) => const S('b')),
    OmniPage('/c', (_) => const S('c')),
    OmniPage('/items/:id', (p) => Item(id: p.pathInt('id'))),
    OmniStatefulShell(
      builder: (_, _, s) => shell = s,
      branches: [
        OmniBranch(
          routes: [
            OmniPage(
              '/t/list',
              (_) => const S('list'),
              routes: [
                OmniPage(
                  'd',
                  (_) => const S('detail'),
                  routes: [OmniPage('e', (_) => const S('edit'))],
                ),
              ],
            ),
          ],
        ),
        OmniBranch(
          routes: [OmniPage('/t/other', (_) => const S('other'))],
        ),
      ],
    ),
    ...extra,
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

List<String> locations() => [for (final e in OmniRoute.stack) e.location];

// ── Cubits ────────────────────────────────────────────────────────────
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  static int closed = 0;
  void inc() => emit(state + 1);
  @override
  Future<void> close() {
    closed++;
    return super.close();
  }
}

class Counter extends OmniStatelessWidget {
  const Counter({super.key, this.own = const [Provide<CounterCubit>()]});
  final List<Provide> own;
  @override
  String get screenName => 'counter';
  @override
  List<Provide> get provide => own;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => context.read<CounterCubit>().inc(),
    child: Text('count ${context.watch<CounterCubit>().state}'),
  );
}

// ── Lifecycle on the wrong class ──────────────────────────────────────
class Wrong extends OmniStatefulWidget with OmniLifecycle {
  const Wrong({super.key});
  @override
  String get screenName => 'wrong';
  @override
  State<Wrong> createState() => _WrongState();
}

class _WrongState extends OmniState<Wrong> {
  @override
  Widget build(BuildContext context) => const Text('wrong');
}

// ── Dialog ────────────────────────────────────────────────────────────
class Confirm extends OmniStatelessWidget {
  const Confirm({super.key});
  @override
  String get screenName => 'confirm';
  @override
  Widget build(BuildContext context) => AlertDialog(
    content: const Text('Sure?'),
    actions: [
      TextButton(
        onPressed: () => OmniRoute.pop(true),
        child: const Text('Yes'),
      ),
    ],
  );
}

class Sheet extends OmniStatelessWidget {
  const Sheet({super.key});
  @override
  String get screenName => 'sheet';
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => OmniRoute.pop('picked'),
    child: const Text('Pick'),
  );
}

void main() {
  group('navigation helpers', () {
    testWidgets('popUntil and popToRoot', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      for (final l in ['/a', '/b', '/c']) {
        OmniRoute.push(l);
      }
      await t.pumpAndSettle();
      expect(await OmniRoute.popUntil('/missing'), isFalse);
      expect(locations(), ['/', '/a', '/b', '/c'], reason: 'nothing popped');
      final found = OmniRoute.popUntil('/a');
      await t.pumpAndSettle();
      expect(await found, isTrue);
      expect(locations(), ['/', '/a']);
      OmniRoute.push('/b');
      await t.pumpAndSettle();
      OmniRoute.popToRoot();
      await t.pumpAndSettle();
      expect(locations(), ['/']);
      expect(find.text('home'), findsOneWidget);
      OmniRoute.popToRoot(); // safe on the first page
    });

    testWidgets('popToRoot ignores PopScope, like Navigator.popUntil', (
      t,
    ) async {
      await t.pumpWidget(
        app(extra: [OmniPage('/locked', (_) => const Locked())]),
      );
      await t.pumpAndSettle();
      OmniRoute.push('/locked');
      OmniRoute.push('/a');
      await t.pumpAndSettle();
      OmniRoute.popToRoot();
      await t.pumpAndSettle();
      expect(locations(), ['/']);
    });

    testWidgets('openTo builds the location; no duplicates', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      OmniRoute.openTo<Item>(path: {'id': '7'});
      await t.pumpAndSettle();
      OmniRoute.openTo<Item>(path: {'id': '7'});
      await t.pumpAndSettle();
      expect(locations(), ['/', '/items/7']);
      expect(find.text('item 7'), findsOneWidget);
    });

    testWidgets('open and popUntil inside a stateful shell', (t) async {
      await t.pumpWidget(app());
      OmniRoute.go('/t/list');
      await t.pumpAndSettle();
      OmniRoute.open('/t/list/d');
      await t.pumpAndSettle();
      OmniRoute.open('/t/list/d/e');
      await t.pumpAndSettle();
      expect(locations(), ['/t/list', '/t/list/d', '/t/list/d/e']);
      OmniRoute.open('/t/list/d/e'); // already on top
      await t.pumpAndSettle();
      expect(locations(), ['/t/list', '/t/list/d', '/t/list/d/e']);
      OmniRoute.open('/t/list'); // pops back inside the tab
      await t.pumpAndSettle();
      expect(locations(), ['/t/list']);
      expect(find.text('list'), findsOneWidget);
      // Declarative sub-route below a pushed page.
      OmniRoute.go('/t/list/d');
      await t.pumpAndSettle();
      OmniRoute.open('/t/list/d/e');
      await t.pumpAndSettle();
      expect(locations(), ['/t/list', '/t/list/d', '/t/list/d/e']);
      OmniRoute.popUntil('/t/list');
      await t.pumpAndSettle();
      expect(locations(), ['/t/list']);
      expect(t.takeException(), isNull);
      OmniRoute.open('/t/list/d');
      await t.pumpAndSettle();
      OmniRoute.popToRoot();
      await t.pumpAndSettle();
      expect(locations(), ['/t/list'], reason: 'root of the current tab');
    });
  });

  testWidgets('OmniLifecycle on the stateful widget is reported once', (
    t,
  ) async {
    await t.pumpWidget(app(extra: [OmniPage('/w', (_) => const Wrong())]));
    await t.pumpAndSettle();
    OmniRoute.push('/w');
    await t.pumpAndSettle();
    final e = t.takeException();
    expect(
      e,
      isA<OmniRouteException>()
          .having((e) => e.code, 'code', OmniErrorCode.lifecycleOnWidget)
          .having((e) => e.hint, 'hint', contains('OmniState')),
    );
    expect(find.text('wrong'), findsOneWidget, reason: 'still shown');
    OmniRoute.pop();
    await t.pumpAndSettle();
    OmniRoute.push('/w');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'reported once');
  });

  group('Cubits', () {
    setUp(() => CounterCubit.closed = 0);

    testWidgets('global Cubit', (t) async {
      await t.pumpWidget(
        app(
          blocs: [OmniBloc<CounterCubit>((_) => CounterCubit(), global: true)],
          extra: [OmniPage('/n', (_) => const Counter(own: []))],
        ),
      );
      OmniRoute.go('/n');
      await t.pumpAndSettle();
      await t.tap(find.text('count 0'));
      await t.pump();
      expect(find.text('count 1'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      expect(CounterCubit.closed, 1);
    });

    testWidgets('screen-scoped Cubit is closed on pop', (t) async {
      await t.pumpWidget(
        app(
          blocs: [OmniBloc<CounterCubit>((_) => CounterCubit())],
          extra: [OmniPage('/n', (_) => const Counter())],
        ),
      );
      await t.pumpAndSettle();
      OmniRoute.push('/n');
      await t.pumpAndSettle();
      await t.tap(find.text('count 0'));
      await t.pump();
      expect(find.text('count 1'), findsOneWidget);
      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(CounterCubit.closed, 1);
    });

    testWidgets('Provide.value Cubit is never closed by OmniRoute', (t) async {
      final cubit = CounterCubit();
      addTearDown(cubit.close);
      await t.pumpWidget(
        app(
          extra: [
            OmniPage(
              '/n',
              (_) => Counter(own: [Provide<CounterCubit>.value(cubit)]),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      OmniRoute.push('/n');
      await t.pumpAndSettle();
      await t.tap(find.text('count 0'));
      await t.pump();
      expect(cubit.state, 1);
      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(CounterCubit.closed, 0);
    });
  });

  group('dialog and bottom sheet routes', () {
    Widget withModals() => app(
      extra: [
        OmniPage(
          '/confirm',
          (_) => const Confirm(),
          transition: OmniPages.dialog(),
        ),
        OmniPage(
          '/sheet',
          (_) => const Sheet(),
          transition: OmniPages.bottomSheet(showDragHandle: true),
        ),
      ],
    );

    testWidgets('dialog returns the popped value; page below stays', (t) async {
      await t.pumpWidget(withModals());
      await t.pumpAndSettle();
      final result = OmniRoute.push<bool>('/confirm');
      await t.pumpAndSettle();
      expect(find.text('Sure?'), findsOneWidget);
      expect(find.text('home'), findsOneWidget, reason: 'visible behind');
      await t.tap(find.text('Yes'));
      await t.pumpAndSettle();
      expect(await result, isTrue);
      expect(OmniRoute.current.location, '/');
    });

    testWidgets('barrier tap closes the dialog with null', (t) async {
      await t.pumpWidget(withModals());
      await t.pumpAndSettle();
      final result = OmniRoute.push<bool>('/confirm');
      await t.pumpAndSettle();
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(await result, isNull);
      expect(locations(), ['/']);
    });

    testWidgets('bottom sheet returns a value and has a drag handle', (
      t,
    ) async {
      await t.pumpWidget(withModals());
      await t.pumpAndSettle();
      final result = OmniRoute.push<String>('/sheet');
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('home'), findsOneWidget);
      await t.tap(find.text('Pick'));
      await t.pumpAndSettle();
      expect(await result, 'picked');
      expect(OmniRoute.current.location, '/');
    });
  });
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
