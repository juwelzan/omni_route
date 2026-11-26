// Audit v2 finding F: metadata, current/stack, navigation hooks, logging.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:omni_route/omni_route.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get routePath => '/${label.toLowerCase()}';
  @override
  Widget build(BuildContext context) => Text(label);
}

class Home extends S {
  const Home({super.key}) : super('home');
}

class Detail extends S {
  const Detail({super.key}) : super('detail');
}

class Admin extends S {
  const Admin({super.key}) : super('admin');
}

bool isAdmin = false;

/// One guard for all routes, driven by route metadata.
final roleGuard = OmniGuard.fn((c, s) {
  final roles = s.metadata?['roles'] as List<String>?;
  if (roles == null || roles.contains('admin') && isAdmin) return null;
  return '/';
});

Widget app(List<OmniNavigation> events, {bool log = false}) => OmniApp(
  guards: [roleGuard],
  onNavigate: events.add,
  logNavigation: log,
  routes: [
    OmniPage('/', (_) => const Home(), name: 'home'),
    OmniPage(
      '/admin',
      (_) => const Admin(),
      metadata: const {
        'roles': ['admin'],
        'title': 'Admin',
      },
    ),
    OmniShell(
      builder: (_, _, child) => child,
      routes: [
        OmniPage(
          '/items/:id',
          (_) => const Detail(),
          name: 'item',
          metadata: const {'section': 'items'},
        ),
      ],
    ),
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

void main() {
  setUp(() => isAdmin = false);

  testWidgets('route metadata drives a guard and is readable', (t) async {
    final events = <OmniNavigation>[];
    await t.pumpWidget(app(events));
    await t.pumpAndSettle();
    OmniRoute.go('/admin');
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget, reason: 'not admin → redirected');
    isAdmin = true;
    OmniRoute.go('/admin');
    await t.pumpAndSettle();
    expect(find.text('admin'), findsOneWidget);
    expect(OmniRoute.current.metadata['title'], 'Admin');
    expect(OmniRoute.current.screen, Admin);
    expect(OmniRoute.state.metadata?['roles'], ['admin']);
  });

  testWidgets('stack lists pages bottom to top, through shells and pushes', (
    t,
  ) async {
    await t.pumpWidget(app([]));
    await t.pumpAndSettle();
    OmniRoute.push('/items/1');
    await t.pumpAndSettle();
    OmniRoute.push('/items/2');
    await t.pumpAndSettle();
    expect(OmniRoute.stack.map((e) => e.location), [
      '/',
      '/items/1',
      '/items/2',
    ]);
    expect(OmniRoute.stack.map((e) => e.screen), [Home, Detail, Detail]);
    expect(OmniRoute.stack.last.metadata['section'], 'items');
    expect(OmniRoute.current.name, 'item');
  });

  testWidgets('onNavigate: initial, go, push, pop, redirect; no duplicates', (
    t,
  ) async {
    final events = <OmniNavigation>[];
    await t.pumpWidget(app(events));
    await t.pumpAndSettle();
    OmniRoute.go('/items/1?tab=a');
    await t.pumpAndSettle();
    OmniRoute.push('/items/2');
    await t.pumpAndSettle();
    OmniRoute.pop();
    await t.pumpAndSettle();
    OmniRoute.go('/admin'); // redirected to /
    await t.pumpAndSettle();
    OmniRoute.go('/'); // same location: no event
    await t.pumpAndSettle();

    expect(events.map((e) => e.uri.toString()), [
      '/',
      '/items/1?tab=a',
      '/items/2',
      '/items/1?tab=a',
      '/',
    ]);
    expect(events.first.from, isNull);
    expect(events[2].from!.location, '/items/1');
    expect(events[2].to.screen, Detail);
    expect(
      events.last.to.screen,
      Home,
      reason: 'reports where the user ended up',
    );
  });

  testWidgets('logNavigation prints in debug; listener removed on dispose', (
    t,
  ) async {
    final printed = <String>[];
    final old = OmniRoute.logger;
    OmniRoute.logger = Logger(
      printer: SimplePrinter(colors: false),
      output: _ListOutput(printed),
    );
    final events = <OmniNavigation>[];
    await t.pumpWidget(app(events, log: true));
    await t.pumpAndSettle();
    OmniRoute.go('/items/3');
    await t.pumpAndSettle();
    OmniRoute.logger = old;
    expect(
      printed.where((m) => m.contains('OmniRoute · navigation')).length,
      2,
    );
    expect(printed.last, contains('/items/3'));
    expect(printed.last, contains('Detail'));

    // Disposing removes the delegate listener (checked by the leak tracker).
    await t.pumpWidget(const SizedBox());
  });
}

class _ListOutput extends LogOutput {
  _ListOutput(this.lines);
  final List<String> lines;
  @override
  void output(OutputEvent event) => lines.add(event.lines.join('\n'));
}
