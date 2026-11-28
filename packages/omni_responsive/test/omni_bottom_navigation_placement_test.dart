import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _items = [
  OmniBottomNavigationItem(icon: Icon(Icons.home_outlined), label: 'A'),
  OmniBottomNavigationItem(icon: Icon(Icons.person_outline), label: 'B'),
];
const _shot = Key('shot');

Widget _app(OmniBottomNavigationBar bar) => RepaintBoundary(
  key: _shot,
  child: MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: const SizedBox.expand(),
      bottomNavigationBar: bar,
    ),
  ),
);

Rect _card(WidgetTester t) => t.getRect(
  find
      .descendant(
        of: find.byType(OmniBottomNavigationBar),
        matching: find.byType(Container),
      )
      .first,
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

void main() {
  testWidgets('docked: true makes a floating style edge to edge', (t) async {
    await t.pumpWidget(
      _app(
        const OmniBottomNavigationBar(
          style: OmniBottomNavigationStyle.glass,
          items: _items,
        ),
      ),
    );
    await t.pumpAndSettle();
    final floating = _card(t);
    expect(floating.left, greaterThan(0));

    await t.pumpWidget(
      _app(
        const OmniBottomNavigationBar(
          style: OmniBottomNavigationStyle.glass,
          docked: true,
          items: _items,
        ),
      ),
    );
    await t.pumpAndSettle();
    final docked = _card(t);
    expect(docked.left, 0);
    expect(docked.width, 800);
    expect(docked.bottom, 600);
  });

  testWidgets('docked: false floats a docked style as a card', (t) async {
    await t.pumpWidget(
      _app(
        const OmniBottomNavigationBar(
          style: OmniBottomNavigationStyle.materialPill,
          docked: false,
          items: _items,
        ),
      ),
    );
    await t.pumpAndSettle();
    final card = _card(t);
    expect(card.left, greaterThan(0));
    expect(card.bottom, lessThan(600));
  });

  testWidgets('docked from the theme extension; explicit margin loses', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [OmniBottomNavigationStyleData(docked: true)],
        ),
        home: const Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            style: OmniBottomNavigationStyle.floating,
            margin: EdgeInsets.all(20),
            items: _items,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(_card(t).left, 0);
  });

  testWidgets('topIndicator underline: accent at the bottom edge', (t) async {
    const accent = Color(0xFF00FF00);
    Future<void> pump({required bool atBottom}) async {
      await t.pumpWidget(
        _app(
          OmniBottomNavigationBar(
            style: OmniBottomNavigationStyle.topIndicator,
            currentIndex: 0,
            onTap: (_) {},
            glowColor: accent,
            backgroundColor: const Color(0xFF000000),
            borderWidth: 0,
            indicatorAtBottom: atBottom,
            showSpotlight: false,
            items: const [
              OmniBottomNavigationItem(
                icon: Icon(Icons.home_outlined),
                label: 'A',
                activeColor: accent,
              ),
              OmniBottomNavigationItem(
                icon: Icon(Icons.person_outline),
                label: 'B',
              ),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    await pump(atBottom: false);
    final bar = t.getRect(find.byType(OmniBottomNavigationBar));
    // Beside tab 0's icon and label, inside the 38 px accent.
    final x = bar.width / 4 + 15;
    // The accent is a few pixels inside the padded row.
    Future<bool> greenNear(double y) async {
      for (var dy = -3; dy <= 3; dy++) {
        if (await _pixel(t, Offset(x, y + dy)) == accent) return true;
      }
      return false;
    }

    expect(await greenNear(bar.top + 3), isTrue);
    await pump(atBottom: true);
    final bottomBar = t.getRect(find.byType(OmniBottomNavigationBar));
    var found = false;
    for (var y = bottomBar.bottom - 1; y > bottomBar.bottom - 30; y--) {
      if (await _pixel(t, Offset(x, y)) == accent) {
        found = true;
        break;
      }
    }
    expect(found, isTrue, reason: 'underline near the bottom edge');
    expect(await greenNear(bottomBar.top + 3), isFalse);
  });
}
