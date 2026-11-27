// Route scope (audit v2 finding C).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

final created = <int>[];
final closed = <int>[];

class StudentBloc extends Bloc<int, int> {
  StudentBloc(this.id) : super(0) {
    created.add(id);
    on<int>((e, emit) => emit(e));
  }
  final int id;
  @override
  Future<void> close() {
    closed.add(id);
    return super.close();
  }
}

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get routePath => '/${label.toLowerCase()}';
  @override
  List<Provide> get provide => const [];
  @override
  Widget build(BuildContext context) {
    final b = context.watch<StudentBloc>();
    return Scaffold(body: Text('$label ${b.id}:${b.state}'));
  }
}

class Plain extends OmniStatelessWidget {
  const Plain(this.label, {super.key});
  final String label;
  @override
  String get routePath => '/${label.toLowerCase()}';
  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}

late StudentBloc Function() current;

Widget app({bool keyed = true}) => OmniApp(
  initialRoute: '/students',
  routes: [
    OmniPage(
      '/students',
      (_) => const Plain('list'),
      routes: [
        OmniRouteGroup(
          scopeKey: keyed ? (s) => s.pathParameters['id'] : null,
          provide: [
            Provide<StudentBloc>.create(
              (c) => StudentBloc(OmniParams.of(c).pathInt('id')),
              lazy: false,
            ),
          ],
          routes: [
            OmniPage(
              ':id',
              (_) => const S('detail'),
              routes: [OmniPage('edit', (_) => const S('edit'))],
            ),
          ],
        ),
      ],
    ),
    OmniPage('/help', (_) => const Plain('help')),
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

StudentBloc bloc(WidgetTester t, String text) =>
    t.element(find.textContaining(text)).read<StudentBloc>();

void main() {
  setUp(() {
    created.clear();
    closed.clear();
  });

  testWidgets('shared across group routes; closed when the group is left', (
    t,
  ) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(created, isEmpty, reason: 'not created before entering the group');

    OmniRoute.go('/students/7');
    await t.pumpAndSettle();
    bloc(t, 'detail').add(5);
    await t.pump();

    OmniRoute.push('/students/7/edit');
    await t.pumpAndSettle();
    expect(
      find.text('edit 7:5'),
      findsOneWidget,
      reason: 'same instance in child route',
    );

    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(find.text('detail 7:5'), findsOneWidget);

    OmniRoute.go('/students/7/edit');
    await t.pumpAndSettle();
    expect(
      find.text('edit 7:5'),
      findsOneWidget,
      reason: 'go within the group keeps it',
    );
    expect(created, [7]);
    expect(closed, isEmpty);

    OmniRoute.go('/students');
    await t.pumpAndSettle();
    expect(closed, [7], reason: 'left the group');
  });

  testWidgets('pushing a route outside the group keeps the group alive', (
    t,
  ) async {
    await t.pumpWidget(app());
    OmniRoute.go('/students/3');
    await t.pumpAndSettle();
    final first = bloc(t, 'detail');
    OmniRoute.push('/help');
    await t.pumpAndSettle();
    expect(find.text('help'), findsOneWidget);
    expect(closed, isEmpty);
    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(bloc(t, 'detail'), same(first));
  });

  testWidgets('scopeKey: new id closes old Blocs and creates new ones', (
    t,
  ) async {
    await t.pumpWidget(app());
    OmniRoute.go('/students/1');
    await t.pumpAndSettle();
    OmniRoute.go('/students/2/edit');
    await t.pumpAndSettle();
    expect(find.text('edit 2:0'), findsOneWidget);
    expect(created, [1, 2]);
    expect(closed, [1]);
  });

  testWidgets('back navigation inside the group (system back)', (t) async {
    await t.pumpWidget(app());
    OmniRoute.go('/students/4/edit');
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('detail 4:0'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(closed, [4]);
  });

  testWidgets('100 enter/leave cycles stay balanced', (t) async {
    await t.pumpWidget(app());
    for (var i = 0; i < 100; i++) {
      OmniRoute.go('/students/$i/edit');
      await t.pumpAndSettle();
      OmniRoute.go('/help');
      await t.pumpAndSettle();
    }
    expect(created.length, 100);
    expect(closed.length, 100);
  });

  testWidgets('group page uses the app page type (transition)', (t) async {
    await t.pumpWidget(app());
    OmniRoute.push('/students/1');
    await t.pumpAndSettle();
    final root = t.widget<Navigator>(find.byType(Navigator).first);
    expect(root.pages.last, isA<MaterialPage<void>>());
    expect(OmniRouter.of(t.element(find.text('detail 1:0'))), isNotNull);
  });

  testWidgets('OmniParams.of works in a page Bloc factory and in initState', (
    t,
  ) async {
    await t.pumpWidget(
      OmniApp(
        initialRoute: '/p/9?tab=x',
        routes: [OmniPage('/p/:id', (_) => const ParamScreen())],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('9 x 9'), findsOneWidget);
  });
}

class ParamScreen extends OmniStatefulWidget {
  const ParamScreen({super.key});
  @override
  String get routePath => '/param/:id';
  @override
  List<Provide> get provide => [
    Provide<StudentBloc>.create(
      (c) => StudentBloc(OmniParams.of(c).pathInt('id')),
    ),
  ];
  @override
  State<ParamScreen> createState() => _ParamState();
}

class _ParamState extends OmniState<ParamScreen> {
  late final OmniParams p;
  @override
  void initState() {
    super.initState();
    p = OmniParams.of(context);
  }

  @override
  Widget build(BuildContext context) => Text(
    '${p.path('id')} ${p.query('tab')} ${context.read<StudentBloc>().id}',
  );
}
