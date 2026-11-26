// 0.2.1: regression tests for route-guard refresh and repeated-location
// navigation events, plus the new additive helpers.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get screenName => label;
  @override
  Widget build(BuildContext context) => Text(label);
}

enum Sort { newest, oldest }

Widget app({
  List<OmniRouteBase> extra = const [],
  void Function(OmniNavigation)? onNavigate,
}) => OmniApp(
  onNavigate: onNavigate,
  routes: [
    OmniPage('/', (_) => const S('home'), name: 'home'),
    OmniPage('/i/:id', (p) => S('item ${p.path('id')}'), name: 'item'),
    OmniPage(
      '/q',
      (p) => S(
        'q ${p.queryBool('on')} ${p.queryDouble('lat')} ${p.queryEnum('sort', Sort.values)}',
      ),
    ),
    ...extra,
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

void main() {
  group('fix: per-route guard refresh', () {
    testWidgets('route guard re-runs when its refresh stream emits', (t) async {
      final changes = StreamController<void>.broadcast();
      var allowed = true;
      final guard = OmniGuard.fn(
        (c, s) => allowed ? null : '/',
        refresh: (_) => changes.stream,
      );
      await t.pumpWidget(
        app(
          extra: [
            OmniPage('/admin', (_) => const S('admin'), guards: [guard]),
            OmniPage('/admin2', (_) => const S('admin2'), guards: [guard]),
          ],
        ),
      );
      OmniRoute.go('/admin');
      await t.pumpAndSettle();
      expect(find.text('admin'), findsOneWidget);

      allowed = false;
      changes.add(null);
      await t.pumpAndSettle();
      expect(
        find.text('home'),
        findsOneWidget,
        reason: 'access revoked → redirected',
      );
      expect(changes.hasListener, isTrue);

      await t.pumpWidget(const SizedBox());
      expect(changes.hasListener, isFalse, reason: 'cancelled on dispose');
      await changes.close();
    });
  });

  group('fix: onNavigate for repeated locations', () {
    testWidgets('same location pushed twice and popped back is reported', (
      t,
    ) async {
      final events = <String>[];
      await t.pumpWidget(app(onNavigate: (n) => events.add(n.uri.toString())));
      await t.pumpAndSettle();
      OmniRoute.push('/i/1');
      await t.pumpAndSettle();
      OmniRoute.push('/i/1');
      await t.pumpAndSettle();
      OmniRoute.pop();
      await t.pumpAndSettle();
      OmniRoute.go('/i/1'); // same page, same URI: still no event
      await t.pumpAndSettle();
      expect(events, ['/', '/i/1', '/i/1', '/i/1', '/i/1']);
    });

    testWidgets('query change on the same page is reported once', (t) async {
      final events = <String>[];
      await t.pumpWidget(app(onNavigate: (n) => events.add(n.uri.toString())));
      OmniRoute.go('/q?on=1');
      await t.pumpAndSettle();
      OmniRoute.go('/q?on=0');
      await t.pumpAndSettle();
      OmniRoute.go('/q?on=0');
      await t.pumpAndSettle();
      expect(events, ['/', '/q?on=1', '/q?on=0']);
    });
  });

  group('new: OmniParams', () {
    testWidgets('queryBool, queryDouble, queryEnum', (t) async {
      await t.pumpWidget(app());
      OmniRoute.go('/q?on=TRUE&lat=23.81&sort=oldest');
      await t.pumpAndSettle();
      expect(find.text('q true 23.81 Sort.oldest'), findsOneWidget);
      OmniRoute.go('/q');
      await t.pumpAndSettle();
      expect(find.text('q null null null'), findsOneWidget);
    });

    for (final bad in ['on=maybe', 'lat=north', 'sort=random']) {
      testWidgets('invalid $bad shows the error page', (t) async {
        await t.pumpWidget(app());
        OmniRoute.go('/q?$bad');
        await t.pumpAndSettle();
        expect(find.text('Page not found'), findsOneWidget);
      });
    }
  });

  group('new: OmniRoute helpers', () {
    testWidgets('maybePop is safe on the first page', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(OmniRoute.maybePop(), isFalse);
      OmniRoute.push('/i/2');
      await t.pumpAndSettle();
      expect(OmniRoute.maybePop(), isTrue);
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('replaceTo replaces the top page by screen type', (t) async {
      await t.pumpWidget(
        app(extra: [OmniPage('/u/:id', (p) => Unique(p.path('id')))]),
      );
      await t.pumpAndSettle();
      OmniRoute.push('/q');
      await t.pumpAndSettle();
      OmniRoute.replaceTo<Unique>(path: {'id': '9'});
      await t.pumpAndSettle();
      expect(find.text('unique 9'), findsOneWidget);
      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('missingRoute explains the List<OmniPage> inference trap', (
      t,
    ) async {
      final List<OmniPage> typed = [
        OmniPage('/u/:id', (p) => Unique(p.path('id'))),
      ];
      await t.pumpWidget(app(extra: typed));
      expect(
        () => OmniRoute.locationOf<Unique>(path: {'id': '1'}),
        throwsA(
          isA<OmniRouteException>().having(
            (e) => e.hint,
            'hint',
            contains('List<OmniRouteBase>'),
          ),
        ),
      );
    });

    testWidgets('replaceNamed replaces the top page', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      OmniRoute.push('/q');
      await t.pumpAndSettle();
      OmniRoute.replaceNamed('item', path: {'id': '5'});
      await t.pumpAndSettle();
      expect(find.text('item 5'), findsOneWidget);
      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(
        find.text('home'),
        findsOneWidget,
        reason: '/q was replaced, not kept',
      );
    });

    testWidgets('refresh re-runs guards without a refresh stream', (t) async {
      var open = true;
      await t.pumpWidget(
        app(
          extra: [
            OmniPage(
              '/gate',
              (_) => const S('gate'),
              guards: [OmniGuard.fn((c, s) => open ? null : '/')],
            ),
          ],
        ),
      );
      OmniRoute.go('/gate');
      await t.pumpAndSettle();
      open = false;
      OmniRoute.refresh();
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}

class Unique extends OmniStatelessWidget {
  const Unique(this.id, {super.key});
  final String id;
  @override
  String get screenName => 'unique';
  @override
  Widget build(BuildContext context) => Text('unique $id');
}
