import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _page = Color(0xFFFF0000);
const _bar = Color(0xFFFFFFFF);
const _shot = Key('shot');

List<OmniBottomNavigationItem> _items(int n) => [
  for (var i = 0; i < n; i++)
    OmniBottomNavigationItem(icon: const Icon(Icons.circle), label: 'T$i'),
];

Finder get _orb => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).shape == BoxShape.circle,
);

Future<Color> _pixel(WidgetTester t, Offset at) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final image = (await t.runAsync(() => boundary.toImage()))!;
  final data = (await t.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final i = (at.dy.round() * image.width + at.dx.round()) * 4;
  image.dispose();
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

Widget _app({
  required OmniBottomNavigationController controller,
  required OmniBottomNavigationNotch notch,
  int count = 5,
  EdgeInsetsGeometry? margin,
}) => RepaintBoundary(
  key: _shot,
  child: MaterialApp(
    home: Scaffold(
      backgroundColor: _page,
      bottomNavigationBar: OmniBottomNavigationBar(
        style: OmniBottomNavigationStyle.curvedNotch,
        controller: controller,
        backgroundColor: _bar,
        boxShadow: const [],
        borderWidth: 0,
        margin: margin,
        borderRadius: 28,
        notch: notch,
        items: _items(count),
      ),
    ),
  ),
);

void main() {
  testWidgets('the cut stays centred on the orb on the first and last tab', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final controller = OmniBottomNavigationController();
    addTearDown(controller.dispose);
    const notch = OmniBottomNavigationNotch(
      shape: OmniNotchShape.circular,
      orbSize: 50,
      lift: 20,
      gap: 8,
    );
    await t.pumpWidget(
      _app(
        controller: controller,
        notch: notch,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      ),
    );
    await t.pumpAndSettle();

    for (final tab in [0, 4]) {
      controller.select(tab);
      await t.pumpAndSettle();
      final orb = t.getRect(_orb);
      final barTop = orb.top + 20;
      // Inside the gap ring, left and right of the orb, just below the bar's
      // top edge: both sides must be cut out (page colour shows).
      for (final side in [-1, 1]) {
        final probe = Offset(orb.center.dx + side * (25 + 4), barTop + 3);
        expect(
          await _pixel(t, probe),
          _page,
          reason: 'tab $tab, side $side: the cut is off the orb',
        );
      }
      // Well away from the orb the bar is solid.
      final solid = Offset(orb.center.dx + (tab == 0 ? 80 : -80), barTop + 3);
      expect(await _pixel(t, solid), _bar);
    }
  });

  testWidgets('shape none keeps a straight bar under the orb', (t) async {
    final controller = OmniBottomNavigationController(initialIndex: 2);
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _app(
        controller: controller,
        notch: const OmniBottomNavigationNotch(
          shape: OmniNotchShape.none,
          lift: 40,
        ),
      ),
    );
    await t.pumpAndSettle();
    final orb = t.getRect(_orb);
    final barTop = orb.top + 40;
    expect(await _pixel(t, Offset(orb.center.dx - 29, barTop + 3)), _bar);
  });

  testWidgets('orbSize and lift size and place the orb', (t) async {
    final controller = OmniBottomNavigationController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _app(
        controller: controller,
        notch: const OmniBottomNavigationNotch(orbSize: 64, lift: 30),
      ),
    );
    await t.pumpAndSettle();
    final orb = t.getRect(_orb);
    expect(orb.width, 64);
    final bar = t.getRect(find.byType(OmniBottomNavigationBar));
    expect(orb.top - bar.top, closeTo(2, 0.01)); // headroom = lift + 2
  });

  testWidgets('pop shrinks the orb half-way, dip sinks it', (t) async {
    final controller = OmniBottomNavigationController();
    addTearDown(controller.dispose);

    Future<Rect> midTravel(OmniNotchTravel travel) async {
      controller.select(0);
      await t.pumpWidget(
        _app(
          controller: controller,
          notch: OmniBottomNavigationNotch(travel: travel),
        ),
      );
      await t.pumpAndSettle();
      controller.select(3);
      await t.pump();
      // Half of the 340 ms travel.
      await t.pump(const Duration(milliseconds: 170));
      final r = t.getRect(_orb);
      await t.pumpAndSettle();
      return r;
    }

    final pop = await midTravel(OmniNotchTravel.pop);
    expect(pop.width, lessThan(50 * 0.2));

    final dip = await midTravel(OmniNotchTravel.dip);
    final settled = t.getRect(_orb);
    expect(dip.center.dy, greaterThan(settled.center.dy + 5));

    final slide = await midTravel(OmniNotchTravel.slide);
    expect(slide.width, closeTo(settled.width, 0.01));
  });

  testWidgets('notch comes from the theme extension too', (t) async {
    final controller = OmniBottomNavigationController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [
            OmniBottomNavigationStyleData(
              notch: OmniBottomNavigationNotch(orbSize: 40),
            ),
          ],
        ),
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            style: OmniBottomNavigationStyle.curvedNotch,
            controller: controller,
            items: _items(3),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.getRect(_orb).width, 40);
  });

  testWidgets('centre FAB notch honours orbSize, shape and gap', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            style: OmniBottomNavigationStyle.centerFabNotch,
            currentIndex: 0,
            onTap: (_) {},
            notch: const OmniBottomNavigationNotch(
              shape: OmniNotchShape.circular,
              orbSize: 64,
              gap: 10,
            ),
            centerAction: OmniBottomNavigationAction(
              icon: const Icon(Icons.add),
              onPressed: () {},
            ),
            items: _items(4),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final fab = find.ancestor(
      of: find.byIcon(Icons.add),
      matching: find.byType(Container),
    );
    expect(t.getSize(fab.first).width, 64);
  });

  test('copyWith, equality and lerp', () {
    const a = OmniBottomNavigationNotch(orbSize: 40, gap: 4);
    final b = a.copyWith(shape: OmniNotchShape.circular, orbSize: 60);
    expect(b.gap, 4);
    expect(b.shape, OmniNotchShape.circular);
    expect(a, const OmniBottomNavigationNotch(orbSize: 40, gap: 4));
    final mid = OmniBottomNavigationNotch.lerp(a, b, 0.5)!;
    expect(mid.orbSize, 50);
    expect(mid.shape, OmniNotchShape.circular);
  });
}
