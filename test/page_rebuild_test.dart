import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

int _listBuilds = 0, _detailBuilds = 0, _formBuilds = 0, _formUpdates = 0;

class _ListScreen extends OmniStatelessWidget {
  // Not const on purpose: builder routes create a new instance per build.
  // ignore: prefer_const_constructors_in_immutables
  _ListScreen();
  @override
  String get routePath => '/';
  @override
  Widget build(BuildContext context) {
    _listBuilds++;
    return const Text('list');
  }
}

class _DetailScreen extends OmniStatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _DetailScreen(this.id);
  final int id;
  @override
  String get routePath => '/item/:id';
  @override
  Widget build(BuildContext context) {
    _detailBuilds++;
    return Text('item $id');
  }
}

class _FormScreen extends OmniStatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _FormScreen();
  @override
  String get routePath => '/form';
  @override
  State<_FormScreen> createState() => _FormState();
}

class _FormState extends OmniState<_FormScreen> {
  @override
  void didUpdateWidget(_FormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _formUpdates++;
  }

  @override
  Widget build(BuildContext context) {
    _formBuilds++;
    return const Text('form');
  }
}

Widget _app({List<OmniRouteBase> extra = const []}) => OmniApp(
  transition: OmniPages.none,
  routes: [
    OmniPage('/', (_) => _ListScreen()),
    OmniPage('/item/:id', (p) => _DetailScreen(p.pathInt('id'))),
    OmniPage('/form', (_) => _FormScreen()),
    ...extra,
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

void main() {
  setUp(() => _listBuilds = _detailBuilds = _formBuilds = _formUpdates = 0);

  testWidgets('push and pop do not rebuild the pages below', (t) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(_listBuilds, 1);

    OmniRoute.push('/item/1');
    await t.pumpAndSettle();
    OmniRoute.push('/form');
    await t.pumpAndSettle();
    OmniRoute.push('/item/2');
    await t.pumpAndSettle();
    OmniRoute.pop();
    await t.pumpAndSettle();
    OmniRoute.pop();
    await t.pumpAndSettle();

    expect(_listBuilds, 1, reason: 'the root page never rebuilt');
    expect(_detailBuilds, 2, reason: 'each detail page built once');
    expect(_formBuilds, 1);
    expect(_formUpdates, 0);
    expect(find.text('item 1'), findsOneWidget);
  });

  testWidgets('a query change still rebuilds the page it belongs to', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    OmniRoute.go('/item/7?tab=1');
    await t.pumpAndSettle();
    final before = _detailBuilds;
    OmniRoute.go('/item/7?tab=2');
    await t.pumpAndSettle();
    expect(_detailBuilds, before + 1);
    expect(OmniRoute.location.queryParameters['tab'], '2');
  });

  testWidgets('dialog page shows the updated page content', (t) async {
    await t.pumpWidget(
      _app(
        extra: [
          OmniPage(
            '/confirm',
            (p) => Text('confirm ${p.query('step')}'),
            transition: OmniPages.dialog(),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.go('/confirm?step=1');
    await t.pumpAndSettle();
    expect(find.text('confirm 1'), findsOneWidget);

    OmniRoute.go('/confirm?step=2');
    await t.pumpAndSettle();
    expect(find.text('confirm 2'), findsOneWidget);
    expect(find.text('confirm 1'), findsNothing);
  });

  testWidgets('onExit runs once for a quick double back press', (t) async {
    var asks = 0;
    late Completer<bool> answer;
    await t.pumpWidget(
      _app(
        extra: [
          OmniPage(
            '/edit',
            (_) => const Text('edit'),
            onExit: (_) {
              asks++;
              return (answer = Completer<bool>()).future;
            },
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/item/1');
    await t.pumpAndSettle();
    OmniRoute.push('/edit');
    await t.pumpAndSettle();

    await t.binding.handlePopRoute();
    await t.binding.handlePopRoute();
    await t.pump();
    expect(asks, 1);

    answer.complete(true);
    await t.pumpAndSettle();
    expect(find.text('item 1'), findsOneWidget, reason: 'popped exactly once');

    // Asking again works after the first decision finished.
    OmniRoute.push('/edit');
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pump();
    expect(asks, 2);
    answer.complete(false);
    await t.pumpAndSettle();
    expect(find.text('edit'), findsOneWidget);
  });

  testWidgets('theme change does not re-run screen builders', (t) async {
    final dark = ValueNotifier(false);
    addTearDown(dark.dispose);
    await t.pumpWidget(
      OmniApp(
        transition: OmniPages.none,
        routes: [
          OmniPage('/', (_) => _ListScreen()),
          OmniPage('/item/:id', (p) => _DetailScreen(p.pathInt('id'))),
        ],
        builder: (_, r) => ValueListenableBuilder(
          valueListenable: dark,
          builder: (_, isDark, _) => MaterialApp.router(
            theme: isDark ? ThemeData.dark() : ThemeData.light(),
            routerConfig: r,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    OmniRoute.push('/item/1');
    await t.pumpAndSettle();
    final list = _listBuilds, detail = _detailBuilds;

    dark.value = true;
    await t.pumpAndSettle();
    expect(_listBuilds, list);
    expect(_detailBuilds, detail);
  });
}
