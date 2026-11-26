import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

final created = <String, int>{};
final closed = <String, int>{};

class TagBloc extends Bloc<int, int> {
  TagBloc(this.tag) : super(0) {
    created[tag] = (created[tag] ?? 0) + 1;
  }
  final String tag;
  @override
  Future<void> close() {
    closed[tag] = (closed[tag] ?? 0) + 1;
    return super.close();
  }
}

class AuthBloc extends TagBloc {
  AuthBloc() : super('auth');
}

class ListBloc extends TagBloc {
  ListBloc() : super('list');
}

class DetailBloc extends TagBloc {
  DetailBloc(this.id) : super('detail');
  final int id;
}

class HomeScreen extends OmniStatelessWidget {
  const HomeScreen({super.key});
  @override
  String get routePath => '/';
  @override
  Widget build(BuildContext context) {
    context.read<AuthBloc>();
    return const Text('home');
  }
}

class ListScreen extends OmniStatelessWidget {
  const ListScreen({super.key});
  @override
  String get routePath => '/students';
  @override
  List<Provide> get provide => const [Provide<ListBloc>(lazy: false)];
  @override
  Widget build(BuildContext context) => const Text('list');
}

class DetailScreen extends OmniStatefulWidget {
  const DetailScreen({super.key, required this.id, this.tab});
  final int id;
  final String? tab;
  @override
  String get routePath => '/students/:id';
  @override
  List<Provide> get provide => [
    Provide<DetailBloc>.create((_) => DetailBloc(id), lazy: false),
  ];
  @override
  State<DetailScreen> createState() => _DetailState();
}

class _DetailState extends OmniState<DetailScreen> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'detail ${widget.id} ${widget.tab} ${context.read<DetailBloc>().id}',
      ),
      Text('loc ${routeState.uri}'),
      TextButton(
        onPressed: () => OmniRoute.pop(widget.id * 2),
        child: const Text('done'),
      ),
    ],
  );
}

Widget buildApp({OmniErrorBuilder? notFound}) => OmniApp(
  blocs: [
    OmniBloc<AuthBloc>((_) => AuthBloc(), global: true),
    OmniBloc<ListBloc>((_) => ListBloc()),
  ],
  notFound: notFound,
  routes: [
    OmniPage('/', (_) => const HomeScreen()),
    OmniPage(
      '/students',
      (_) => const ListScreen(),
      name: 'students',
      routes: [
        OmniPage(
          ':id',
          (p) => DetailScreen(id: p.pathInt('id'), tab: p.query('tab')),
        ),
      ],
    ),
    OmniPage('/raw', (_) => const Text('raw')),
  ],
  builder: (_, router) => MaterialApp.router(routerConfig: router),
);

void main() {
  setUp(() {
    created.clear();
    closed.clear();
  });

  testWidgets('go / push / pop / replace / result', (t) async {
    await t.pumpWidget(buildApp());
    expect(find.text('home'), findsOneWidget);

    OmniRoute.go('/students');
    await t.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(OmniRoute.location.path, '/students');

    final result = OmniRoute.push<int>('/students/7?tab=info');
    await t.pumpAndSettle();
    expect(find.text('detail 7 info 7'), findsOneWidget);
    expect(find.text('loc /students/7?tab=info'), findsOneWidget);
    expect(
      OmniRoute.location.toString(),
      '/students/7?tab=info',
      reason: 'regression: location must include pushed pages',
    );
    expect(closed['list'], isNull, reason: 'covered page keeps its bloc');

    await t.tap(find.text('done'));
    await t.pumpAndSettle();
    expect(await result, 14);
    expect(closed['detail'], 1);

    OmniRoute.replace('/raw');
    await t.pumpAndSettle();
    expect(find.text('raw'), findsOneWidget);
    expect(closed['list'], 1, reason: 'replaced page closes its bloc');
    expect(closed['auth'], isNull);
  });

  testWidgets('typed navigation and named routes', (t) async {
    await t.pumpWidget(buildApp());
    OmniRoute.to<DetailScreen>(path: {'id': '42'}, query: {'tab': 'a b'});
    await t.pumpAndSettle();
    expect(find.text('detail 42 a b 42'), findsOneWidget);
    expect(
      OmniRoute.locationOf<DetailScreen>(path: {'id': '1'}),
      '/students/1',
    );
    OmniRoute.goNamed('students');
    await t.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(
      () => OmniRoute.locationOf<DetailScreen>(),
      throwsA(isA<OmniRouteException>()),
    );
    expect(
      () => OmniRoute.locationOf<_Unregistered>(),
      throwsA(
        isA<OmniRouteException>().having(
          (e) => e.code,
          'c',
          OmniErrorCode.missingRoute,
        ),
      ),
    );
  });

  testWidgets('unknown url and invalid param show error page', (t) async {
    await t.pumpWidget(
      buildApp(
        notFound: (_, s, e) =>
            Text('404 ${s.uri.path} ${e is OmniRouteException}'),
      ),
    );
    OmniRoute.go('/nope');
    await t.pumpAndSettle();
    expect(find.text('404 /nope false'), findsOneWidget);
    OmniRoute.go('/students/abc');
    await t.pumpAndSettle();
    expect(find.text('404 /students/abc true'), findsOneWidget);
  });

  testWidgets('200 push/pop cycles keep bloc counts balanced', (t) async {
    await t.pumpWidget(buildApp());
    for (var i = 0; i < 200; i++) {
      OmniRoute.push('/students/$i');
      await t.pumpAndSettle();
      OmniRoute.pop();
      await t.pumpAndSettle();
    }
    expect(created['detail'], 200);
    expect(closed['detail'], 200);
    expect(created['auth'], 1);
  });

  testWidgets('dispose detaches router and closes globals', (t) async {
    await t.pumpWidget(buildApp());
    await t.pumpWidget(const SizedBox());
    expect(
      () => OmniRoute.go('/'),
      throwsA(
        isA<OmniRouteException>().having(
          (e) => e.code,
          'c',
          OmniErrorCode.notInitialized,
        ),
      ),
    );
    expect(closed['auth'], 1);
  });

  testWidgets('invalid / duplicate route config fails fast', (t) async {
    await t.pumpWidget(
      OmniApp(
        routes: [OmniPage('/Bad', (_) => const HomeScreen())],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    expect(t.takeException(), isA<OmniRouteException>());
    expect(find.byType(ErrorWidget), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      OmniApp(
        routes: [
          OmniPage('/a', (_) => const HomeScreen()),
          OmniPage('/a', (_) => const SizedBox()),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    expect(
      t.takeException(),
      isA<OmniRouteException>().having(
        (e) => e.code,
        'c',
        OmniErrorCode.duplicateRoute,
      ),
    );
  });

  testWidgets(
    'nested OmniShell inside OmniStatefulShell branch renders on seed & switch',
    (t) async {
      late OmniNavigationShell navShell;
      await t.pumpWidget(
        OmniApp(
          initialRoute: '/tab-a',
          routes: [
            OmniStatefulShell(
              builder: (_, _, s) {
                navShell = s;
                return Scaffold(body: s);
              },
              branches: [
                OmniBranch(
                  routes: [OmniPage('/tab-a', (_) => const Text('Tab A'))],
                ),
                OmniBranch(
                  routes: [
                    OmniShell(
                      builder: (_, state, child) => Column(
                        children: [
                          Text('InnerShell:${state.uri.path}'),
                          Expanded(child: child),
                        ],
                      ),
                      routes: [
                        OmniPage(
                          '/tab-b',
                          (_) => const Text('Tab B Root'),
                          routes: [
                            OmniPage(
                              'sub',
                              (_) => const Text('Tab B Sub'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      // Switch to Branch 1 -> seeded stack MUST wrap `/tab-b` inside InnerShell!
      navShell.goBranch(1);
      await t.pumpAndSettle();
      expect(find.text('InnerShell:/tab-b'), findsOneWidget);
      expect(find.text('Tab B Root'), findsOneWidget);

      // Push sub-route inside InnerShell, then reset via initialLocation: true.
      OmniRoute.push('/tab-b/sub');
      await t.pumpAndSettle();
      expect(find.text('InnerShell:/tab-b/sub'), findsOneWidget);
      expect(find.text('Tab B Sub'), findsOneWidget);

      navShell.goBranch(1, initialLocation: true);
      await t.pumpAndSettle();
      expect(find.text('InnerShell:/tab-b'), findsOneWidget);
      expect(find.text('Tab B Root'), findsOneWidget);
    },
  );
}

class _Unregistered extends OmniStatelessWidget {
  @override
  String get routePath => '/unregistered';
  @override
  Widget build(BuildContext context) => const SizedBox();
}
