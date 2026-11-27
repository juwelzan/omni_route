import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

final created = <String, int>{};
final closed = <String, int>{};

abstract class CountedBloc extends Bloc<int, int> {
  CountedBloc(this.tag) : super(0) {
    created[tag] = (created[tag] ?? 0) + 1;
    on<int>((e, emit) => emit(state + e));
  }
  final String tag;
  @override
  Future<void> close() {
    closed[tag] = (closed[tag] ?? 0) + 1;
    return super.close();
  }
}

class AuthBloc extends CountedBloc {
  AuthBloc() : super('auth');
}

class StudentBloc extends CountedBloc {
  StudentBloc() : super('student');
}

class AttendanceBloc extends CountedBloc {
  AttendanceBloc() : super('attendance');
}

class Repo {
  const Repo(this.id);
  final int id;
}

class RepoBloc extends CountedBloc {
  RepoBloc(this.repo) : super('repo');
  final Repo repo;
}

class StudentScreen extends OmniStatelessWidget {
  const StudentScreen({super.key, this.label = ''});
  final String label;
  @override
  String get routePath => '/students';
  @override
  List<Provide> get provide => const [
    Provide<StudentBloc>(lazy: false),
    Provide<AttendanceBloc>(lazy: false),
  ];
  @override
  Widget build(BuildContext context) {
    final s = context.read<StudentBloc>();
    context.read<AttendanceBloc>();
    context.read<AuthBloc>(); // global is visible
    return Text('students$label ${s.state}');
  }
}

class StatefulStudent extends OmniStatefulWidget {
  const StatefulStudent({super.key});
  @override
  String get routePath => '/stateful-student';
  @override
  List<Provide> get provide => const [Provide<StudentBloc>()];
  @override
  State<StatefulStudent> createState() => _S();
}

class _S extends OmniState<StatefulStudent> {
  late final StudentBloc bloc;
  @override
  void initState() {
    super.initState();
    bloc = context.read<StudentBloc>();
  }

  @override
  Widget build(BuildContext context) => Text('stateful ${bloc.state}');
}

final registry = OmniBlocRegistry([
  OmniBloc<AuthBloc>((_) => AuthBloc(), global: true),
  OmniBloc<StudentBloc>((_) => StudentBloc()),
  OmniBloc<AttendanceBloc>((_) => AttendanceBloc()),
  OmniBloc<RepoBloc>((ctx) => RepoBloc(ctx.read<Repo>())),
]);

/// Simulates what OmniRoute's page builder will do in Phase 4.
Widget page(OmniScreen s) => OmniBlocScope(provide: s.provide, child: s);

Widget app(Widget home, {GlobalKey<NavigatorState>? nav}) =>
    OmniGlobalBlocScope(
      registry: registry,
      child: MaterialApp(navigatorKey: nav, home: home),
    );

void main() {
  setUp(() {
    created.clear();
    closed.clear();
  });

  testWidgets('global + multiple screen blocs; rebuild does not recreate', (
    t,
  ) async {
    await t.pumpWidget(app(page(const StudentScreen(label: 'a'))));
    await t.pumpWidget(app(page(const StudentScreen(label: 'b'))));
    expect(find.text('studentsb 0'), findsOneWidget);
    expect(created, {'auth': 1, 'student': 1, 'attendance': 1});
    expect(closed, isEmpty);
  });

  testWidgets('stateful screen reads its bloc in initState', (t) async {
    await t.pumpWidget(app(page(const StatefulStudent())));
    expect(find.text('stateful 0'), findsOneWidget);
  });

  testWidgets('push keeps, pop closes; global survives; 100 cycles balance', (
    t,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(const Text('home'), nav: nav));
    for (var i = 0; i < 100; i++) {
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => page(const StudentScreen())),
      );
      await t.pumpAndSettle();
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('top')),
      );
      await t.pumpAndSettle();
      expect(
        closed['student'],
        i == 0 ? null : i,
        reason: 'covered screen kept',
      );
      nav.currentState!
        ..pop()
        ..pop();
      await t.pumpAndSettle();
    }
    expect(created['student'], 100);
    expect(closed['student'], 100);
    expect(closed['attendance'], 100);
    expect(created['auth'], 1);
    expect(closed['auth'], isNull);
    await t.pumpWidget(const SizedBox());
    expect(closed['auth'], 1, reason: 'global closed with app');
  });

  testWidgets('value bloc is never closed by OmniRoute', (t) async {
    final external = StudentBloc();
    await t.pumpWidget(
      app(
        OmniBlocScope(
          provide: [Provide.value(external)],
          child: const SizedBox(),
        ),
      ),
    );
    await t.pumpWidget(app(const SizedBox()));
    expect(closed['student'], isNull);
    expect(external.isClosed, isFalse);
    await t.runAsync(external.close);
    expect(closed['student'], 1);
  });

  testWidgets('factory gets dependencies from context; Provide.create', (
    t,
  ) async {
    late RepoBloc r;
    await t.pumpWidget(
      app(
        RepositoryProvider<Repo>.value(
          value: const Repo(7),
          child: OmniBlocScope(
            provide: [
              const Provide<RepoBloc>(),
              Provide<AttendanceBloc>.create((_) => AttendanceBloc()),
            ],
            child: Builder(
              builder: (c) {
                r = c.read<RepoBloc>();
                c.read<AttendanceBloc>();
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(r.repo.id, 7);
    expect(created['attendance'], 1);
  });

  testWidgets('missing factory', (t) async {
    await t.pumpWidget(
      OmniBlocScope(
        provide: const [Provide<StudentBloc>()],
        child: Builder(
          builder: (c) {
            c.read<StudentBloc>();
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      t.takeException(),
      isA<OmniRouteException>().having(
        (e) => e.code,
        'code',
        OmniErrorCode.missingBlocFactory,
      ),
    );
  });

  testWidgets('duplicate in provide list', (t) async {
    await t.pumpWidget(
      app(
        const OmniBlocScope(
          provide: [Provide<StudentBloc>(), Provide<StudentBloc>()],
          child: SizedBox(),
        ),
      ),
    );
    expect(
      t.takeException(),
      isA<OmniRouteException>().having(
        (e) => e.code,
        'code',
        OmniErrorCode.duplicateBlocRegistration,
      ),
    );
  });

  testWidgets('screen re-providing a global bloc is rejected', (t) async {
    await t.pumpWidget(
      app(
        OmniBlocScope(
          provide: const [Provide<AuthBloc>()],
          child: Builder(
            builder: (c) {
              c.read<AuthBloc>();
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(
      t.takeException(),
      isA<OmniRouteException>().having(
        (e) => e.code,
        'code',
        OmniErrorCode.unsupportedConfiguration,
      ),
    );
  });

  test('duplicate registration', () {
    expect(
      () => OmniBlocRegistry([
        OmniBloc<AuthBloc>((_) => AuthBloc()),
        OmniBloc<AuthBloc>((_) => AuthBloc()),
      ]),
      throwsA(isA<OmniRouteException>()),
    );
  });
}
