import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _items = [
  OmniBottomNavigationItem(icon: Icon(Icons.home_outlined), label: 'Home'),
  OmniBottomNavigationItem(icon: Icon(Icons.photo_outlined), label: 'Photos'),
];

class _Harness extends StatefulWidget {
  const _Harness({
    this.actionCount = 2,
    this.width = 400,
    this.dir = TextDirection.ltr,
    this.controller,
  });

  final int actionCount;
  final double width;
  final TextDirection dir;
  final OmniBottomNavigationController? controller;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool active = false;
  final log = <String>[];

  void setActive(bool value) => setState(() => active = value);

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: widget.dir,
    child: Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => setState(() => active = true),
          child: const Text('select'),
        ),
      ),
      bottomNavigationBar: OmniContextualActionBar(
        active: active,
        title: '3 selected',
        onClose: () => setState(() => active = false),
        actions: [
          for (var i = 0; i < widget.actionCount; i++)
            OmniContextualAction(
              icon: Icon(i == 0 ? Icons.share_outlined : Icons.delete_outline),
              label: i == 0 ? 'Share' : 'Action $i',
              destructive: i == 1,
              onPressed: () => log.add(i == 0 ? 'share' : 'action $i'),
            ),
        ],
        child: OmniBottomNavigationBar(
          style: OmniBottomNavigationStyle.materialPill,
          controller: widget.controller,
          labelMode: OmniBottomNavLabelMode.alwaysShow,
          items: _items,
        ),
      ),
    ),
  );
}

Future<_HarnessState> _pump(
  WidgetTester t, {
  int actionCount = 2,
  double width = 400,
  TextDirection dir = TextDirection.ltr,
  OmniBottomNavigationController? controller,
  bool reduceMotion = false,
}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        disableAnimations: reduceMotion,
      ),
      child: MaterialApp(
        home: _Harness(
          actionCount: actionCount,
          width: width,
          dir: dir,
          controller: controller,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return t.state<_HarnessState>(find.byType(_Harness));
}

void main() {
  testWidgets('selection swaps the nav bar for actions and back', (t) async {
    final h = await _pump(t);
    expect(find.text('3 selected'), findsNothing);

    await t.tap(find.text('select'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    expect(t.hasRunningAnimations, isTrue); // animates in
    await t.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);

    await t.tap(find.byTooltip('Share'));
    expect(h.log, ['share']);

    // The nav bar underneath can't be tapped while selecting.
    await t.tap(find.text('Photos'), warnIfMissed: false);
    await t.pump();

    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.text('3 selected'), findsNothing);
    expect(h.active, isFalse);
  });

  testWidgets('the nav bar keeps its state and controller sync', (t) async {
    final controller = OmniBottomNavigationController();
    addTearDown(controller.dispose);
    final h = await _pump(t, controller: controller);
    final barState = t.state(find.byType(OmniBottomNavigationBar));
    h.setActive(true);
    await t.pumpAndSettle();
    controller.select(1); // changed from elsewhere during selection
    await t.pumpAndSettle();
    h.setActive(false);
    await t.pumpAndSettle();
    expect(t.state(find.byType(OmniBottomNavigationBar)), same(barState));
    expect(controller.index, 1);
  });

  testWidgets('system back leaves selection mode first', (t) async {
    final h = await _pump(t);
    h.setActive(true);
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await t.pumpAndSettle();
    expect(h.active, isFalse);
    expect(find.text('select'), findsOneWidget); // page still there
  });

  testWidgets('actions that do not fit go to the overflow menu', (t) async {
    final h = await _pump(t, actionCount: 8, width: 360);
    h.setActive(true);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    await t.tap(find.byIcon(Icons.more_vert_rounded));
    await t.pumpAndSettle();
    await t.tap(find.text('Action 7'));
    await t.pumpAndSettle();
    expect(h.log, ['action 7']);
  });

  testWidgets('RTL mirrors the order', (t) async {
    final h = await _pump(t, dir: TextDirection.rtl);
    h.setActive(true);
    await t.pumpAndSettle();
    expect(
      t.getCenter(find.byTooltip('Close')).dx,
      greaterThan(t.getCenter(find.byTooltip('Share')).dx),
    );
  });

  testWidgets('semantics: nav bar hidden, actions named', (t) async {
    final handle = t.ensureSemantics();
    final h = await _pump(t);
    expect(find.semantics.byLabel(RegExp('Photos')), findsAny);
    h.setActive(true);
    await t.pumpAndSettle();
    expect(find.semantics.byLabel(RegExp('Photos')), findsNothing);
    expect(find.semantics.byLabel(RegExp('3 selected')), findsAny);
    expect(find.byTooltip('Action 1'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('reduced motion swaps instantly', (t) async {
    final h = await _pump(t, reduceMotion: true);
    h.setActive(true);
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('disposes cleanly mid-animation', (t) async {
    final h = await _pump(t);
    h.setActive(true);
    await t.pump(const Duration(milliseconds: 60));
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
}
