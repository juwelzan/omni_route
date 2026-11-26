import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

final created = <String, int>{};
final closed = <String, int>{};

class TagBloc extends Bloc<int, int> {
  TagBloc(this.tag) : super(0) {
    created[tag] = (created[tag] ?? 0) + 1;
    on<int>((e, emit) => emit(e));
  }
  final String tag;
  @override
  Future<void> close() {
    closed[tag] = (closed[tag] ?? 0) + 1;
    return super.close();
  }
}

/// state 1 = logged in, 2 = admin.
class AuthBloc extends TagBloc {
  AuthBloc() : super('auth');
}

class ShellBloc extends TagBloc {
  ShellBloc() : super('shell');
}

class TabBloc extends TagBloc {
  TabBloc() : super('tab');
}

class S extends OmniStatelessWidget {
  const S(this.label, {super.key, this.blocs = const []});
  final String label;
  final List<Provide> blocs;
  @override
  String get screenName => label;
  @override
  List<Provide> get provide => blocs;
  @override
  Widget build(BuildContext context) => Text(label);
}

class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => n++), child: Text('count $n'));
}

class TabScreen extends OmniStatelessWidget {
  const TabScreen({super.key});
  @override
  String get screenName => 'Tab';
  @override
  List<Provide> get provide => const [Provide<TabBloc>(lazy: false)];
  @override
  Widget build(BuildContext context) => const Counter();
}

class AuthGuard extends OmniGuard {
  const AuthGuard();
  @override
  Stream<Object?> refresh(BuildContext c) => c.read<AuthBloc>().stream;
  @override
  String? redirect(BuildContext c, OmniRouteState s) {
    final loggedIn = c.read<AuthBloc>().state >= 1;
    final atLogin = s.matchedLocation == '/login';
    if (!loggedIn && !atLogin) {
      return '/login?from=${Uri.encodeComponent(s.uri.toString())}';
    }
    if (loggedIn && atLogin) return s.uri.queryParameters['from'] ?? '/';
    return null;
  }
}

final adminOnly = OmniGuard.fn((c, s) async {
  await Future<void>.delayed(Duration.zero); // async guard
  return c.read<AuthBloc>().state == 2 ? null : '/denied';
});

late BuildContext rootContext;

Widget buildApp({
  List<OmniGuard> guards = const [AuthGuard()],
  String initial = '/',
}) => OmniApp(
  initialRoute: initial,
  guards: guards,
  blocs: [
    OmniBloc<AuthBloc>((_) => AuthBloc(), global: true, lazy: false),
    OmniBloc<ShellBloc>((_) => ShellBloc()),
    OmniBloc<TabBloc>((_) => TabBloc()),
  ],
  routes: [
    OmniPage('/login', (_) => const S('login')),
    OmniPage('/denied', (_) => const S('denied')),
    OmniPage('/admin', (_) => const S('admin'), guards: [adminOnly]),
    OmniPage(
      '/loop',
      (_) => const S('loop'),
      guards: [OmniGuard.fn((_, _) => '/loop2')],
    ),
    OmniPage(
      '/loop2',
      (_) => const S('loop2'),
      guards: [OmniGuard.fn((_, _) => '/loop')],
    ),
    OmniPage(
      '/self',
      (_) => const S('self'),
      guards: [OmniGuard.fn((_, _) => '/self')],
    ),
    OmniShell(
      provide: const [Provide<ShellBloc>(lazy: false)],
      builder: (c, s, child) => Column(
        children: [
          const Text('shell'),
          Expanded(child: child),
        ],
      ),
      routes: [
        OmniPage('/', (_) => const S('home')),
        OmniPage(
          '/students/:id',
          (p) => S('student ${p.path('id')} ${p.query('tab')}'),
        ),
      ],
    ),
    OmniStatefulShell(
      builder: (c, s, shell) {
        rootContext = c;
        return Scaffold(
          body: shell,
          bottomNavigationBar: Row(
            children: [
              TextButton(
                onPressed: () => shell.goBranch(0),
                child: const Text('tab A'),
              ),
              TextButton(
                onPressed: () => shell.goBranch(1),
                child: const Text('tab B'),
              ),
            ],
          ),
        );
      },
      branches: [
        OmniBranch(routes: [OmniPage('/a', (_) => const TabScreen())]),
        OmniBranch(routes: [OmniPage('/b', (_) => const S('page b'))]),
      ],
    ),
  ],
  builder: (_, router) => MaterialApp.router(routerConfig: router),
);

AuthBloc auth(WidgetTester t) =>
    t.element(find.byType(Navigator).first).read<AuthBloc>();

void main() {
  setUp(() {
    created.clear();
    closed.clear();
  });

  testWidgets('auth guard: login redirect keeps target, reacts to bloc', (
    t,
  ) async {
    await t.pumpWidget(buildApp(initial: '/students/9?tab=x'));
    await t.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
    expect(OmniRoute.location.queryParameters['from'], '/students/9?tab=x');

    auth(t).add(1); // log in → refresh stream re-runs redirect
    await t.pumpAndSettle();
    expect(find.text('student 9 x'), findsOneWidget);

    auth(t).add(0); // log out
    await t.pumpAndSettle();
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('role guard (async, per route)', (t) async {
    await t.pumpWidget(buildApp());
    await t.pumpAndSettle();
    auth(t).add(1);
    await t.pumpAndSettle();
    OmniRoute.go('/admin');
    await t.pumpAndSettle();
    expect(find.text('denied'), findsOneWidget);
    auth(t).add(2);
    await t.pumpAndSettle();
    OmniRoute.go('/admin');
    await t.pumpAndSettle();
    expect(find.text('admin'), findsOneWidget);
  });

  testWidgets('self redirect ignored; redirect loop shows error page', (
    t,
  ) async {
    await t.pumpWidget(buildApp(guards: const []));
    OmniRoute.go('/self');
    await t.pumpAndSettle();
    expect(find.text('self'), findsOneWidget);
    OmniRoute.go('/loop');
    await t.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('redirect loop'), findsOneWidget);
  });

  testWidgets(
    'shell bloc lives across child routes, closes when shell leaves',
    (t) async {
      await t.pumpWidget(buildApp(guards: const []));
      await t.pumpAndSettle();
      expect(find.text('shell'), findsOneWidget);
      OmniRoute.go('/students/1');
      await t.pumpAndSettle();
      expect(find.text('student 1 null'), findsOneWidget);
      expect(created['shell'], 1);
      OmniRoute.go('/login');
      await t.pumpAndSettle();
      expect(closed['shell'], 1);
    },
  );

  testWidgets('stateful shell keeps tab state and blocs over 50 switches', (
    t,
  ) async {
    await t.pumpWidget(buildApp(guards: const [], initial: '/a'));
    await t.pumpAndSettle();
    await t.tap(find.text('count 0'));
    await t.pump();
    for (var i = 0; i < 50; i++) {
      await t.tap(find.text('tab B'));
      await t.pumpAndSettle();
      expect(find.text('page b'), findsOneWidget);
      await t.tap(find.text('tab A'));
      await t.pumpAndSettle();
    }
    expect(find.text('count 1'), findsOneWidget);
    expect(created['tab'], 1);
    expect(closed['tab'], isNull);
    expect(rootContext.mounted, isTrue);
  });

  testWidgets('deep link from platform opens screen with params', (t) async {
    await t.pumpWidget(buildApp(guards: const []));
    await t.pumpAndSettle();
    final msg = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('pushRouteInformation', {
        'location': '/students/55?tab=grades',
        'state': null,
      }),
    );
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      msg,
      (_) {},
    );
    await t.pumpAndSettle();
    expect(find.text('student 55 grades'), findsOneWidget);
  });
}
