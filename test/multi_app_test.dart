// Audit v2 finding D: settings must not leak between OmniApps.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get routePath => '/${label.replaceAll(' ', '-').toLowerCase()}';
  @override
  Widget build(BuildContext context) => Text(label);
}

final key1 = GlobalKey<NavigatorState>();
final key2 = GlobalKey<NavigatorState>();

Widget app(String id, GlobalKey<NavigatorState> nav, {required bool second}) =>
    OmniApp(
      navigatorKey: nav,
      transition: second ? OmniPages.none : OmniPages.material,
      notFound: second ? (_, s, _) => Text('custom 404 ${s.uri.path}') : null,
      routes: [
        OmniPage('/', (_) => S('$id home')),
        OmniPage('/x', (_) => S('$id x')),
      ],
      builder: (_, r) => MaterialApp.router(routerConfig: r),
    );

Page<Object?> topPage(GlobalKey<NavigatorState> k) =>
    (k.currentWidget! as Navigator).pages.last;

OmniRouter routerOf(GlobalKey<NavigatorState> k) =>
    OmniRouter.of(k.currentContext!);

void main() {
  testWidgets('two OmniApps keep their own page type, error page and router', (
    t,
  ) async {
    await t.pumpWidget(
      Row(
        textDirection: TextDirection.ltr,
        children: [
          Expanded(child: app('one', key1, second: false)),
          Expanded(child: app('two', key2, second: true)),
        ],
      ),
    );
    await t.pumpAndSettle();

    routerOf(key1).push('/x');
    routerOf(key2).push('/x');
    await t.pumpAndSettle();
    expect(
      topPage(key1),
      isA<MaterialPage<void>>(),
      reason: 'app 1 not overwritten by app 2',
    );
    expect(topPage(key2), isA<OmniNoTransitionPage<void>>());

    routerOf(key1).go('/missing');
    routerOf(key2).go('/missing');
    await t.pumpAndSettle();
    expect(
      find.text('Page not found'),
      findsOneWidget,
      reason: 'app 1 default page',
    );
    expect(
      find.text('custom 404 /missing'),
      findsOneWidget,
      reason: 'app 2 custom page',
    );

    // Static helpers act on the most recently mounted app.
    OmniRoute.go('/');
    await t.pumpAndSettle();
    expect(find.text('two home'), findsOneWidget);
    expect(find.text('one home'), findsNothing);

    // Remove app 2: helpers fall back to app 1.
    await t.pumpWidget(
      Row(
        textDirection: TextDirection.ltr,
        children: [Expanded(child: app('one', key1, second: false))],
      ),
    );
    OmniRoute.go('/');
    await t.pumpAndSettle();
    expect(find.text('one home'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    expect(() => OmniRoute.router, throwsA(isA<OmniRouteException>()));
  });
}
