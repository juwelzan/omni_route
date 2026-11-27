// Regression tests for audit v2 findings A (screens outside routes) and
// B (duplicate route names).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
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

class PaneBloc extends TagBloc {
  PaneBloc() : super('pane');
}

class DetailBloc extends TagBloc {
  DetailBloc() : super('detail');
}

class PageBloc extends TagBloc {
  PageBloc() : super('page');
}

class Pane extends OmniStatelessWidget {
  const Pane({super.key, this.label = 'pane'});
  final String label;
  @override
  String get routePath => '/pane';
  @override
  List<Provide> get provide => const [Provide<PaneBloc>()];
  @override
  Widget build(BuildContext context) =>
      Text('$label ${context.watch<PaneBloc>().state}');
}

class Detail extends OmniStatefulWidget {
  const Detail({super.key});
  @override
  String get routePath => '/detail';
  @override
  List<Provide> get provide => const [Provide<DetailBloc>()];
  @override
  State<Detail> createState() => _DetailState();
}

class _DetailState extends OmniState<Detail> {
  late final DetailBloc bloc;
  @override
  void initState() {
    super.initState();
    bloc = context.read<DetailBloc>(); // must work in initState
  }

  @override
  Widget build(BuildContext context) => Text('detail ${bloc.state}');
}

/// A routed screen that embeds another screen with its own Blocs.
class Page extends OmniStatelessWidget {
  const Page({super.key});
  @override
  String get routePath => '/page';
  @override
  List<Provide> get provide => const [Provide<PageBloc>(lazy: false)];
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('page ${context.watch<PageBloc>().state}'),
      const Pane(label: 'inner'),
    ],
  );
}

final registry = OmniBlocRegistry([
  OmniBloc<PaneBloc>((_) => PaneBloc()),
  OmniBloc<DetailBloc>((_) => DetailBloc()),
  OmniBloc<PageBloc>((_) => PageBloc()),
]);

Widget host(Widget child) => OmniGlobalBlocScope(
  registry: registry,
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  setUp(() {
    created.clear();
    closed.clear();
  });

  group('A: screens shown outside a route', () {
    testWidgets(
      'stateless screen provides its own Blocs; created once, closed on removal',
      (t) async {
        await t.pumpWidget(host(const Pane(label: 'a')));
        expect(find.text('a 0'), findsOneWidget);
        await t.pumpWidget(host(const Pane(label: 'b'))); // rebuild
        expect(find.text('b 0'), findsOneWidget);
        expect(created['pane'], 1);
        await t.pumpWidget(host(const SizedBox()));
        expect(closed['pane'], 1);
      },
    );

    testWidgets(
      'stateful screen in OmniScreenHost can read Blocs in initState',
      (t) async {
        await t.pumpWidget(host(const OmniScreenHost(screen: Detail())));
        expect(find.text('detail 0'), findsOneWidget);
        await t.pumpWidget(host(const SizedBox()));
        expect(closed['detail'], 1);
      },
    );

    // The screen's initState throws (ProviderNotFound) by design here, which
    // leaves that element undisposed; leak tracking is off for this test only.
    testWidgets(
      'stateful screen without host reports a clear error first',
      experimentalLeakTesting: LeakTesting.settings.withIgnoredAll(),
      (t) async {
        final errors = <Object>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exception);
        await t.pumpWidget(host(const Detail()));
        FlutterError.onError = old;
        expect(
          errors.first,
          isA<OmniRouteException>()
              .having((e) => e.code, 'code', OmniErrorCode.screenNotHosted)
              .having((e) => e.hint, 'hint', contains('OmniScreenHost')),
        );
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets('screen embedded inside a routed screen gets its own Blocs', (
      t,
    ) async {
      await t.pumpWidget(
        OmniApp(
          blocs: [
            OmniBloc<PaneBloc>((_) => PaneBloc()),
            OmniBloc<PageBloc>((_) => PageBloc()),
          ],
          routes: [OmniPage('/', (_) => const Page())],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('page 0'), findsOneWidget);
      expect(find.text('inner 0'), findsOneWidget);
      expect(created, {
        'page': 1,
        'pane': 1,
      }, reason: 'routed screen not double-wrapped');
    });

    testWidgets('routed stateless screen is not hosted twice', (t) async {
      await t.pumpWidget(
        OmniApp(
          blocs: [OmniBloc<PaneBloc>((_) => PaneBloc())],
          routes: [OmniPage('/', (_) => const Pane())],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(OmniBlocScope), findsOneWidget);
      expect(created['pane'], 1);
    });
  });

  testWidgets('manual OmniBlocScope around a screen still creates Blocs once', (
    t,
  ) async {
    await t.pumpWidget(
      host(OmniBlocScope(provide: const Pane().provide, child: const Pane())),
    );
    expect(find.text('pane 0'), findsOneWidget);
    expect(created['pane'], 1);
  });

  testWidgets('B: duplicate route names are rejected in all build modes', (
    t,
  ) async {
    await t.pumpWidget(
      OmniApp(
        routes: [
          OmniPage('/a', (_) => const Pane(), name: 'x'),
          OmniPage('/b', (_) => const Pane(), name: 'x'),
        ],
        builder: (_, r) => MaterialApp.router(routerConfig: r),
      ),
    );
    expect(
      t.takeException(),
      isA<OmniRouteException>()
          .having((e) => e.code, 'code', OmniErrorCode.duplicateRoute)
          .having((e) => e.message, 'message', contains('/a and /b')),
    );
  });
}
