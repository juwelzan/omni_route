import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _items = [
  OmniBottomNavigationItem(icon: Icon(Icons.home), label: 'Home'),
  OmniBottomNavigationItem(icon: Icon(Icons.search), label: 'Search'),
  OmniBottomNavigationItem(icon: Icon(Icons.person), label: 'Profile'),
];

Future<ScrollController> _pump(
  WidgetTester t, {
  ScrollPhysics? physics,
}) async {
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        extendBody: true,
        body: ListView.builder(
          controller: scroll,
          physics: physics,
          itemCount: 60,
          itemBuilder: (_, i) => SizedBox(height: 60, child: Text('Item $i')),
        ),
        bottomNavigationBar: OmniBottomNavigationBar(
          style: OmniBottomNavigationStyle.floating,
          scrollController: scroll,
          hideOnScroll: true,
          currentIndex: 0,
          onTap: (_) {},
          items: _items,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return scroll;
}

bool _hidden(WidgetTester t) => t
    .widget<IgnorePointer>(
      find
          .descendant(
            of: find.byType(OmniBottomNavigationBar),
            matching: find.byType(IgnorePointer),
          )
          .first,
    )
    .ignoring;

/// Moves the list [steps] times by [step] px, one notification per frame.
Future<void> _drift(
  WidgetTester t,
  ScrollController scroll,
  double step,
  int steps,
) async {
  for (var i = 0; i < steps; i++) {
    scroll.jumpTo(scroll.offset + step);
    await t.pump(const Duration(milliseconds: 16));
  }
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a slow scroll down hides the bar', (t) async {
    final scroll = await _pump(t);
    scroll.jumpTo(200);
    await t.pumpAndSettle();
    // Back to visible with a clean slate.
    await _drift(t, scroll, -4, 5);
    expect(_hidden(t), isFalse);

    // 2 px a frame: no single step reaches the old 10 px threshold.
    await _drift(t, scroll, 2, 20);
    expect(_hidden(t), isTrue);
  });

  testWidgets('a slow scroll up shows it again', (t) async {
    final scroll = await _pump(t);
    scroll.jumpTo(600);
    await t.pumpAndSettle();
    await _drift(t, scroll, 2, 20);
    expect(_hidden(t), isTrue);

    await _drift(t, scroll, -2, 10);
    expect(_hidden(t), isFalse);
  });

  testWidgets('jitter in both directions does not flip the bar', (t) async {
    final scroll = await _pump(t);
    scroll.jumpTo(600);
    await t.pumpAndSettle();
    await _drift(t, scroll, -4, 5);
    expect(_hidden(t), isFalse);

    for (var i = 0; i < 20; i++) {
      await _drift(t, scroll, i.isEven ? 12 : -10, 1);
      expect(_hidden(t), isFalse, reason: 'flipped at step $i');
    }
  });

  testWidgets('a scroll under the hide distance keeps the bar', (t) async {
    final scroll = await _pump(t);
    scroll.jumpTo(600);
    await t.pumpAndSettle();
    await _drift(t, scroll, -4, 5);

    await _drift(t, scroll, 2, 10); // 20 px < 24
    expect(_hidden(t), isFalse);
  });

  testWidgets('the overscroll bounce at the end keeps the bar hidden', (
    t,
  ) async {
    final scroll = await _pump(t, physics: const BouncingScrollPhysics());
    final end = scroll.position.maxScrollExtent;
    scroll.jumpTo(end - 200);
    await t.pumpAndSettle();
    await _drift(t, scroll, 10, 20);
    expect(scroll.offset, end);
    expect(_hidden(t), isTrue);

    // Rubber-band past the end, then spring back.
    scroll.jumpTo(end + 60);
    await t.pump();
    await t.pumpAndSettle();
    expect(scroll.offset, end);
    expect(_hidden(t), isTrue);
  });

  testWidgets('reaching the top always shows the bar', (t) async {
    final scroll = await _pump(t);
    scroll.jumpTo(30);
    await t.pumpAndSettle();
    await _drift(t, scroll, 2, 20);
    expect(_hidden(t), isTrue);

    scroll.jumpTo(5);
    await t.pumpAndSettle();
    expect(_hidden(t), isFalse);
  });
}
