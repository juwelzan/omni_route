import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key, this.customTitle});
  final String label;
  final String? customTitle;
  @override
  String get screenName => label;
  @override
  String get title => customTitle ?? screenName;
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
}

class CounterScreen extends OmniStatefulWidget {
  const CounterScreen({super.key});
  @override
  String get screenName => 'Counter';
  @override
  State<CounterScreen> createState() => _CounterState();
}

class _CounterState extends OmniState<CounterScreen> {
  int n = 0;
  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => n++), child: Text('count $n'));
}
