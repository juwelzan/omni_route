// Audit v2 finding E: state restoration.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

int blocsCreated = 0;

class DetailBloc extends Bloc<int, int> {
  DetailBloc() : super(0) {
    blocsCreated++;
  }
}

class Home extends OmniStatelessWidget {
  const Home({super.key});
  @override
  String get screenName => 'Home';
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

class Detail extends OmniStatefulWidget {
  const Detail({super.key, required this.id});
  final int id;
  @override
  String get screenName => 'Detail';
  @override
  List<Provide> get provide => const [Provide<DetailBloc>(lazy: false)];
  @override
  State<Detail> createState() => _DetailState();
}

class _DetailState extends OmniState<Detail> with RestorationMixin {
  final taps = RestorableInt(0);
  @override
  String get restorationId => 'detail';
  @override
  void restoreState(RestorationBucket? old, bool initial) =>
      registerForRestoration(taps, 'taps');
  @override
  void dispose() {
    taps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => setState(() => taps.value++),
      child: Text('detail ${widget.id} taps ${taps.value}'),
    ),
  );
}

class Tab extends OmniStatelessWidget {
  const Tab(this.label, {super.key});
  final String label;
  @override
  String get screenName => label;
  @override
  Widget build(BuildContext context) => Text(label);
}

late OmniNavigationShell shell;

Widget app({required bool restorable}) => OmniApp(
  restorationScopeId: restorable ? 'router' : null,
  blocs: [OmniBloc<DetailBloc>((_) => DetailBloc())],
  routes: [
    OmniPage('/', (_) => const Home()),
    OmniPage('/students/:id', (p) => Detail(id: p.pathInt('id'))),
    OmniStatefulShell(
      restorationScopeId: restorable ? 'shell' : null,
      builder: (_, _, s) => shell = s,
      branches: [
        OmniBranch(
          restorationScopeId: restorable ? 'a' : null,
          routes: [OmniPage('/a', (_) => const Tab('tab a'))],
        ),
        OmniBranch(
          restorationScopeId: restorable ? 'b' : null,
          routes: [OmniPage('/b', (_) => const Tab('tab b'))],
        ),
      ],
    ),
  ],
  builder: (_, r) => MaterialApp.router(
    restorationScopeId: restorable ? 'app' : null,
    routerConfig: r,
  ),
);

void main() {
  testWidgets('route stack and Restorable state survive a restart', (t) async {
    await t.pumpWidget(app(restorable: true));
    await t.pumpAndSettle();
    OmniRoute.push('/students/7');
    await t.pumpAndSettle();
    await t.tap(find.text('detail 7 taps 0'));
    await t.pump();
    await t.tap(find.text('detail 7 taps 1'));
    await t.pump();
    blocsCreated = 0;

    await t.restartAndRestore();

    expect(find.text('detail 7 taps 2'), findsOneWidget);
    expect(OmniRoute.location.path, '/students/7');
    expect(blocsCreated, 1, reason: 'Blocs are recreated, not restored');

    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(
      find.text('home'),
      findsOneWidget,
      reason: 'page below was restored too',
    );
  });

  testWidgets('selected shell tab is restored', (t) async {
    await t.pumpWidget(app(restorable: true));
    OmniRoute.go('/a');
    await t.pumpAndSettle();
    shell.goBranch(1);
    await t.pumpAndSettle();
    await t.restartAndRestore();
    expect(find.text('tab b'), findsOneWidget);
    expect(OmniRoute.location.path, '/b');
  });

  testWidgets('pages carry stable restoration ids from go_router page keys', (
    t,
  ) async {
    await t.pumpWidget(app(restorable: false));
    OmniRoute.push('/students/7');
    await t.pumpAndSettle();
    final pages = t.widget<Navigator>(find.byType(Navigator).first).pages;
    for (final p in pages) {
      expect(p.restorationId, isNotNull);
      expect(p.restorationId, (p.key! as ValueKey<String>).value);
    }
    expect(pages.map((p) => p.restorationId).toSet().length, pages.length);
  });
}
