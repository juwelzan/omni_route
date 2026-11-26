// OmniRoute's logs go through the `logger` package with a fixed format.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route/src/core/omni_log.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get routePath => '/${label.toLowerCase()}';
  @override
  Widget build(BuildContext context) => Text(label);
}

class Profile extends S {
  const Profile({super.key}) : super('profile');
}

class Capture extends LogOutput {
  final events = <OutputEvent>[];
  String get text => events.expand((e) => e.lines).join('\n');
  @override
  void output(OutputEvent event) => events.add(event);
}

late Capture out;

Widget app({bool log = true, List<OmniGuard> guards = const []}) => OmniApp(
  logNavigation: log,
  guards: guards,
  routes: [
    OmniPage('/', (_) => const S('home')),
    OmniPage('/profile', (_) => const Profile()),
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

void main() {
  late Logger before;
  setUp(() {
    before = OmniRoute.logger;
    out = Capture();
    OmniRoute.logger = defaultOmniLogger(output: out);
  });
  tearDown(() => OmniRoute.logger = before);

  test('navigation message: aligned from/to rows with the screen', () {
    final msg = navigationMessage(
      OmniNavigation(
        from: const OmniRouteEntry(location: '/settings', screen: String),
        to: const OmniRouteEntry(location: '/settings/profile', screen: int),
        uri: Uri.parse('/settings/profile?tab=2'),
      ),
    );
    expect(msg, '''
OmniRoute · navigation
from  /settings                String
to    /settings/profile        int
uri   /settings/profile?tab=2''');
  });

  test('first navigation says "app start"', () {
    final msg = navigationMessage(
      OmniNavigation(
        from: null,
        to: const OmniRouteEntry(location: '/'),
        uri: Uri.parse('/'),
      ),
    );
    expect(msg.split('\n')[1], 'from  (app start)');
  });

  test('a generic OmniScreen type shows the route name instead', () {
    final msg = navigationMessage(
      OmniNavigation(
        from: const OmniRouteEntry(location: '/blogs/565', screen: String),
        to: const OmniRouteEntry(
          location: '/blogs',
          name: 'blogs',
          screen: OmniScreen,
        ),
        uri: Uri.parse('/blogs'),
      ),
    );
    expect(msg.split('\n')[2], 'to    /blogs      blogs');
    expect(msg, isNot(contains('OmniScreen')));
  });

  test('no colour codes when the console is not a terminal', () {
    final out = Capture();
    defaultOmniLogger(output: out).i('x');
    expect(out.text, isNot(contains('\x1B[')));
  });

  testWidgets('logNavigation prints one framed info block per navigation', (
    t,
  ) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    OmniRoute.push('/profile');
    await t.pumpAndSettle();
    expect(out.events.map((e) => e.level), [Level.info, Level.info]);
    final last = out.events.last.lines.join('\n');
    expect(last, contains('OmniRoute · navigation'));
    expect(last, contains('from  /'));
    expect(last, contains('to    /profile  Profile'));
    expect(last, contains('┌'), reason: 'framed block');
    expect(last, contains('💡'), reason: 'level emoji');
    expect(last, isNot(contains('#0')), reason: 'no stack trace');
  });

  testWidgets('logNavigation off: nothing is logged', (t) async {
    await t.pumpWidget(app(log: false));
    await t.pumpAndSettle();
    OmniRoute.push('/profile');
    await t.pumpAndSettle();
    expect(out.events, isEmpty);
  });

  testWidgets('a guard redirecting to the same page logs a warning', (t) async {
    await t.pumpWidget(
      app(log: false, guards: [OmniGuard.fn((_, s) => s.matchedLocation)]),
    );
    await t.pumpAndSettle();
    expect(out.events.single.level, Level.warning);
    expect(out.text, contains('OmniRoute · guard'));
    expect(out.text, contains('redirected to "/"'));
  });
}
