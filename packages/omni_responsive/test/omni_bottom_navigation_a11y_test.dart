import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _items = [
  OmniBottomNavigationItem(icon: Icon(Icons.home_outlined), label: 'A'),
  OmniBottomNavigationItem(icon: Icon(Icons.explore_outlined), label: 'B'),
  OmniBottomNavigationItem(icon: Icon(Icons.person_outline), label: 'C'),
];

Widget _scrollPage({
  required ScrollController scroll,
  OmniBottomNavigationController? controller,
  OmniBottomNavigationStyle style = OmniBottomNavigationStyle.floating,
}) => Scaffold(
  body: ListView(
    controller: scroll,
    children: [
      for (var i = 0; i < 60; i++) SizedBox(height: 60, child: Text('row $i')),
    ],
  ),
  bottomNavigationBar: OmniBottomNavigationBar(
    style: style,
    controller: controller,
    scrollController: scroll,
    hideOnScroll: true,
    items: _items,
  ),
);

Offset _barSlide(WidgetTester t) => t
    .widget<AnimatedSlide>(
      find.descendant(
        of: find.byType(OmniBottomNavigationBar),
        matching: find.byType(AnimatedSlide),
      ),
    )
    .offset;

void main() {
  testWidgets('screen reader on: scrolling never hides the bar', (t) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: MaterialApp(home: _scrollPage(scroll: scroll)),
      ),
    );
    await t.drag(find.byType(ListView), const Offset(0, -600));
    await t.pumpAndSettle();
    expect(scroll.offset, greaterThan(100));
    expect(_barSlide(t), Offset.zero);
  });

  testWidgets('screen reader off: scrolling down still hides it', (t) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await t.pumpWidget(MaterialApp(home: _scrollPage(scroll: scroll)));
    await t.drag(find.byType(ListView), const Offset(0, -600));
    await t.pumpAndSettle();
    expect(_barSlide(t), isNot(Offset.zero));
  });

  testWidgets('screen reader on: controller.hide() still hides', (t) async {
    final scroll = ScrollController();
    final controller = OmniBottomNavigationController();
    addTearDown(scroll.dispose);
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: MaterialApp(
          home: _scrollPage(scroll: scroll, controller: controller),
        ),
      ),
    );
    controller.hide();
    await t.pumpAndSettle();
    expect(_barSlide(t), isNot(Offset.zero));
  });

  testWidgets(
    'reduced motion: hide, press scale and bubble width are instant',
    (t) async {
      final scroll = ScrollController();
      final controller = OmniBottomNavigationController();
      addTearDown(scroll.dispose);
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: _scrollPage(
              scroll: scroll,
              controller: controller,
              style: OmniBottomNavigationStyle.floatingBubble,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      final slide = t.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.duration, Duration.zero);
      for (final c in t.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(OmniBottomNavigationBar),
          matching: find.byType(AnimatedContainer),
        ),
      )) {
        expect(c.duration, Duration.zero);
      }
      for (final s in t.widgetList<AnimatedScale>(
        find.descendant(
          of: find.byType(OmniBottomNavigationBar),
          matching: find.byType(AnimatedScale),
        ),
      )) {
        expect(s.duration, Duration.zero);
      }

      // One frame is enough to finish a tab change.
      final before = t.getSize(find.text('A')).width;
      controller.select(2);
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      expect(find.text('C'), findsOneWidget);
      expect(before, greaterThan(0));
    },
  );
}
