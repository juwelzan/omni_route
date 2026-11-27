import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key, this.customTitle});
  final String label;
  final String? customTitle;
  @override
  String get routePath {
    final slug = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? '/s' : '/$slug';
  }

  @override
  String get title => customTitle ?? label;
  @override
  Widget build(BuildContext context) => Text(label);
}

Widget buildApp({bool titles = true}) => OmniApp(
  setTitles: titles,
  routes: [
    OmniPage('/', (_) => const S('Home')),
    OmniPage(
      '/students',
      (_) => const S('Students'),
      routes: [
        OmniPage(
          ':id',
          (p) => S('Student', customTitle: 'Student ${p.path('id')}'),
        ),
      ],
    ),
    OmniPage('/profile/:name', (p) => S('profile ${p.path('name')}')),
  ],
  builder: (_, router) => MaterialApp.router(routerConfig: router),
);

void main() {
  final titles = <String>[];
  setUp(() {
    titles.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
            titles.add((call.arguments as Map)['label'] as String);
          }
          return null;
        });
  });

  testWidgets('title follows push and pop', (t) async {
    await t.pumpWidget(buildApp());
    await t.pumpAndSettle();
    expect(titles.last, 'Home');
    OmniRoute.push('/students/101');
    await t.pumpAndSettle();
    expect(titles.last, 'Student 101');
    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(titles.last, 'Home', reason: 'revealed page sets title again');
  });

  testWidgets('setTitles: false leaves title alone', (t) async {
    await t.pumpWidget(buildApp(titles: false));
    await t.pumpAndSettle();
    expect(titles.where((x) => x == 'Home'), isEmpty);
  });

  testWidgets('trailing slash normalized, query kept, encoding round-trips', (
    t,
  ) async {
    await t.pumpWidget(buildApp());
    OmniRoute.go('/students/7/?tab=a');
    await t.pumpAndSettle();
    expect(OmniRoute.location.toString(), '/students/7?tab=a');
    OmniRoute.go('/students//');
    await t.pumpAndSettle();
    expect(OmniRoute.location.path, '/students');
    OmniRoute.go('/profile/${Uri.encodeComponent('জুয়েল rahman')}');
    await t.pumpAndSettle();
    expect(find.text('profile জুয়েল rahman'), findsOneWidget);
  });

  testWidgets('title follows stateful shell tab switches', (t) async {
    late OmniNavigationShell nav;
    await t.pumpWidget(
      OmniApp(
        initialRoute: '/a',
        routes: [
          OmniStatefulShell(
            builder: (_, _, shell) => nav = shell,
            branches: [
              OmniBranch(routes: [OmniPage('/a', (_) => const S('Tab A'))]),
              OmniBranch(routes: [OmniPage('/b', (_) => const S('Tab B'))]),
            ],
          ),
        ],
        builder: (_, router) => MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    expect(titles.last, 'Tab A');
    nav.goBranch(1);
    await t.pumpAndSettle();
    expect(titles.last, 'Tab B');
    OmniRoute.go('/a');
    await t.pumpAndSettle();
    expect(titles.last, 'Tab A');
  });

  testWidgets('title tracking never resets screen state on push/pop', (
    t,
  ) async {
    await t.pumpWidget(
      OmniApp(
        routes: [
          OmniPage('/', (_) => const CounterScreen()),
          OmniPage('/next', (_) => const S('Next')),
        ],
        builder: (_, router) => MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('count 0'));
    await t.pump();
    OmniRoute.push('/next');
    await t.pumpAndSettle();
    OmniRoute.pop();
    await t.pumpAndSettle();
    expect(find.text('count 1'), findsOneWidget);
    expect(titles.last, 'Counter');
  });

  registerWebHistoryGroup();
}

class CounterScreen extends OmniStatefulWidget {
  const CounterScreen({super.key});
  @override
  String get routePath => '/counter';
  @override
  State<CounterScreen> createState() => _CounterState();
}

class _CounterState extends OmniState<CounterScreen> {
  int n = 0;
  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => n++), child: Text('count $n'));
}

class _TestAuthCubit extends Cubit<bool> {
  _TestAuthCubit() : super(false);
  void logIn() => emit(true);
  void logOut() => emit(false);
}

class _TestAuthGuard extends OmniGuard {
  const _TestAuthGuard();

  @override
  Stream<Object?>? refresh(BuildContext context) =>
      context.read<_TestAuthCubit>().stream;

  @override
  String? redirect(BuildContext context, OmniRouteState state) {
    final loggedIn = context.read<_TestAuthCubit>().state;
    final atLogin = state.uri.path == '/login';
    if (!loggedIn && !atLogin) {
      return Uri(
        path: '/login',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    if (loggedIn && atLogin) {
      return state.params.query('from') ?? '/dashboard';
    }
    return null;
  }
}

void mainWebHistoryTests() {}

Future<void> _pushPlatformRoute(WidgetTester t, String location) async {
  final msg = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', <String, dynamic>{
      'location': location,
      'state': null,
    }),
  );
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    msg,
    (_) {},
  );
}

// Registered from main() below:
void registerWebHistoryGroup() {
  group('web browser history & back prevention', () {
    late List<({String uri, bool replace})> navUpdates;

    setUp(() {
      navUpdates = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
            if (call.method == 'routeInformationUpdated') {
              final args = call.arguments as Map;
              navUpdates.add((
                uri: args['uri'] as String,
                replace: args['replace'] as bool,
              ));
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.navigation, null),
      );
    });

    testWidgets(
      'replace() from /login to /home replaces web history & blocks back',
      (t) async {
        await t.pumpWidget(
          OmniApp.material(
            initialRoute: '/login',
            routes: [
              OmniPage('/login', (_) => const S('Login')),
              OmniPage('/home', (_) => const S('Home')),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(navUpdates.last.uri, '/login');
        expect(navUpdates.last.replace, isTrue);

        navUpdates.clear();
        OmniRoute.replace('/home');
        await t.pumpAndSettle();

        expect(find.text('Home'), findsOneWidget);
        expect(OmniRoute.canPop(), isFalse);
        expect(navUpdates, [(uri: '/home', replace: true)]);
        expect(await OmniRoute.router.routerDelegate.popRoute(), isFalse);
      },
    );

    testWidgets(
      'go(replaceHistory: true) and OmniRoute.neglect replace history',
      (t) async {
        await t.pumpWidget(
          OmniApp.material(
            initialRoute: '/login',
            routes: [
              OmniPage('/login', (_) => const S('Login')),
              OmniPage('/otp', (_) => const S('OTP')),
              OmniPage('/home', (_) => const S('Home')),
              OmniPage('/other', (_) => const S('Other')),
            ],
          ),
        );
        await t.pumpAndSettle();

        OmniRoute.push('/otp');
        await t.pumpAndSettle();
        expect(navUpdates.last, (uri: '/otp', replace: false));

        navUpdates.clear();
        OmniRoute.go('/home', replaceHistory: true);
        await t.pumpAndSettle();
        expect(OmniRoute.canPop(), isFalse);
        expect(find.text('Home'), findsOneWidget);
        expect(navUpdates.last, (uri: '/home', replace: true));

        navUpdates.clear();
        OmniRoute.neglect(() => OmniRoute.go('/other'));
        await t.pumpAndSettle();
        expect(find.text('Other'), findsOneWidget);
        expect(navUpdates.last, (uri: '/other', replace: true));
      },
    );

    testWidgets('push creates history entry; pop and AppBar back replace it', (
      t,
    ) async {
      await t.pumpWidget(
        OmniApp.material(
          routes: [
            OmniPage('/', (_) => const S('Home')),
            OmniPage(
              '/detail',
              (p) => Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('back arrow'),
                ),
              ),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      navUpdates.clear();
      OmniRoute.push('/detail');
      await t.pumpAndSettle();
      expect(navUpdates.last, (uri: '/detail', replace: false));

      navUpdates.clear();
      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(navUpdates.last, (uri: '/', replace: true));

      // Push again and trigger Navigator.pop directly (like AppBar back button)
      OmniRoute.push('/detail');
      await t.pumpAndSettle();
      navUpdates.clear();
      await t.tap(find.text('back arrow'));
      await t.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(navUpdates.last, (uri: '/', replace: true));
    });

    testWidgets(
      'AuthGuard login/logout refresh replaces history and blocks browser back',
      (t) async {
        late BuildContext rootCtx;

        await t.pumpWidget(
          OmniApp.material(
            initialRoute: '/dashboard',
            guards: const [_TestAuthGuard()],
            blocs: [OmniBloc((_) => _TestAuthCubit(), global: true)],
            routes: [
              OmniPage(
                '/login',
                (_) => Builder(
                  builder: (ctx) {
                    rootCtx = ctx;
                    return const S('Login');
                  },
                ),
              ),
              OmniStatefulShell(
                builder: (_, _, shell) => Column(
                  children: [
                    const Text('ShellChrome'),
                    Expanded(child: shell),
                  ],
                ),
                branches: [
                  OmniBranch(
                    routes: [
                      OmniPage('/dashboard', (_) => const S('Dashboard')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Login'), findsOneWidget);
        expect(navUpdates.last.replace, isTrue);

        // Log in -> Guard redirects /login -> /dashboard with replace: true
        navUpdates.clear();
        rootCtx.read<_TestAuthCubit>().logIn();
        OmniRoute.refresh();
        await t.pumpAndSettle();

        expect(find.text('ShellChrome'), findsOneWidget);
        expect(find.text('Dashboard'), findsOneWidget);
        expect(OmniRoute.canPop(), isFalse);
        expect(navUpdates.last, (uri: '/dashboard', replace: true));

        // Simulate browser Back into /login while authenticated
        navUpdates.clear();
        await _pushPlatformRoute(t, '/login');
        await t.pumpAndSettle();
        expect(find.text('Dashboard'), findsOneWidget);
        expect(navUpdates.last, (uri: '/dashboard', replace: true));

        // Log out -> redirects back to /login replacing history
        navUpdates.clear();
        t.element(find.text('Dashboard')).read<_TestAuthCubit>().logOut();
        OmniRoute.refresh();
        await t.pumpAndSettle();
        expect(find.text('Login'), findsOneWidget);
        expect(navUpdates.last.uri, '/login?from=%2Fdashboard');
        expect(navUpdates.last.replace, isTrue);

        // Simulate browser Back trying /dashboard after logout -> blocked cleanly
        navUpdates.clear();
        await _pushPlatformRoute(t, '/dashboard');
        await t.pumpAndSettle();
        expect(find.text('Login'), findsOneWidget);
        expect(navUpdates.last, (
          uri: '/login?from=%2Fdashboard',
          replace: true,
        ));
      },
    );

    testWidgets('cross-shell replace() keeps OmniStatefulShell intact', (
      t,
    ) async {
      await t.pumpWidget(
        OmniApp.material(
          initialRoute: '/login',
          routes: [
            OmniPage('/login', (_) => const S('Login')),
            OmniStatefulShell(
              builder: (_, _, shell) => Column(
                children: [
                  const Text('ShellBar'),
                  Expanded(child: shell),
                ],
              ),
              branches: [
                OmniBranch(
                  routes: [OmniPage('/dashboard', (_) => const S('Dashboard'))],
                ),
              ],
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);

      OmniRoute.replace('/dashboard');
      await t.pumpAndSettle();
      expect(find.text('ShellBar'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(OmniRoute.canPop(), isFalse);

      OmniRoute.replace('/login');
      await t.pumpAndSettle();
      expect(find.text('ShellBar'), findsNothing);
      expect(find.text('Login'), findsOneWidget);
      expect(OmniRoute.canPop(), isFalse);
    });
  });
}
