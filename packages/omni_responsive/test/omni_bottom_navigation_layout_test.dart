import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _items = [
  OmniBottomNavigationItem(icon: Icon(Icons.home_outlined), label: 'Home'),
  OmniBottomNavigationItem(
    icon: Icon(Icons.explore_outlined),
    label: 'Explore',
  ),
  OmniBottomNavigationItem(icon: Icon(Icons.person_outline), label: 'Profile'),
];

// Styles whose items honour itemLayout.
const _styles = [
  OmniBottomNavigationStyle.floating,
  OmniBottomNavigationStyle.slidingPill,
  OmniBottomNavigationStyle.glass,
  OmniBottomNavigationStyle.glowingDot,
  OmniBottomNavigationStyle.topIndicator,
  OmniBottomNavigationStyle.materialPill,
  OmniBottomNavigationStyle.cupertino,
  OmniBottomNavigationStyle.floatingCircles,
  OmniBottomNavigationStyle.centerFabNotch,
];

Future<void> _pump(
  WidgetTester t, {
  required OmniBottomNavigationStyle style,
  OmniBottomNavItemLayout? layout,
  TextDirection dir = TextDirection.ltr,
  double width = 800,
  double textScale = 1,
  OmniBottomNavigationStyleData? themeData,
}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [?themeData]),
      home: Directionality(
        textDirection: dir,
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            bottomNavigationBar: OmniBottomNavigationBar(
              style: style,
              itemLayout: layout,
              labelMode: OmniBottomNavLabelMode.alwaysShow,
              currentIndex: 0,
              onTap: (_) {},
              centerAction: style == OmniBottomNavigationStyle.centerFabNotch
                  ? OmniBottomNavigationAction(
                      icon: const Icon(Icons.add),
                      onPressed: () {},
                    )
                  : null,
              items: _items,
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

bool _sideBySide(WidgetTester t, String label, IconData icon) {
  final i = t.getRect(find.byIcon(icon));
  final l = t.getRect(find.text(label));
  return (i.center.dy - l.center.dy).abs() < 4;
}

void main() {
  testWidgets('default stays stacked (label under the icon)', (t) async {
    await _pump(t, style: OmniBottomNavigationStyle.materialPill);
    expect(_sideBySide(t, 'Explore', Icons.explore_outlined), isFalse);
    expect(
      t.getRect(find.text('Explore')).top,
      greaterThan(t.getRect(find.byIcon(Icons.explore_outlined)).bottom - 1),
    );
  });

  for (final style in _styles) {
    testWidgets('inline puts icon and label in one row: ${style.name}', (
      t,
    ) async {
      await _pump(t, style: style, layout: OmniBottomNavItemLayout.inline);
      expect(t.takeException(), isNull);
      expect(_sideBySide(t, 'Explore', Icons.explore_outlined), isTrue);
      expect(
        t.getRect(find.text('Explore')).left,
        greaterThan(t.getRect(find.byIcon(Icons.explore_outlined)).right - 1),
      );
    });
  }

  testWidgets('RTL: label sits left of the icon', (t) async {
    await _pump(
      t,
      style: OmniBottomNavigationStyle.materialPill,
      layout: OmniBottomNavItemLayout.inline,
      dir: TextDirection.rtl,
    );
    expect(
      t.getRect(find.text('Explore')).right,
      lessThan(t.getRect(find.byIcon(Icons.explore_outlined)).left + 1),
    );
  });

  testWidgets('narrow screen and large text: no overflow', (t) async {
    for (final style in _styles) {
      await _pump(
        t,
        style: style,
        layout: OmniBottomNavItemLayout.inline,
        width: 320,
        textScale: 1.6,
      );
      expect(t.takeException(), isNull, reason: style.name);
    }
  });

  testWidgets('adaptive: stacked below 600, inline from 600', (t) async {
    await _pump(
      t,
      style: OmniBottomNavigationStyle.materialPill,
      layout: OmniBottomNavItemLayout.adaptive,
      width: 400,
    );
    expect(_sideBySide(t, 'Explore', Icons.explore_outlined), isFalse);
    await _pump(
      t,
      style: OmniBottomNavigationStyle.materialPill,
      layout: OmniBottomNavItemLayout.adaptive,
      width: 700,
    );
    expect(_sideBySide(t, 'Explore', Icons.explore_outlined), isTrue);
  });

  testWidgets('itemLayout comes from the theme extension too', (t) async {
    await _pump(
      t,
      style: OmniBottomNavigationStyle.cupertino,
      themeData: const OmniBottomNavigationStyleData(
        itemLayout: OmniBottomNavItemLayout.inline,
      ),
    );
    expect(_sideBySide(t, 'Explore', Icons.explore_outlined), isTrue);
  });

  testWidgets('semantics: each tab is a selectable button with its label', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await _pump(
      t,
      style: OmniBottomNavigationStyle.materialPill,
      layout: OmniBottomNavItemLayout.inline,
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Home').first),
      matchesSemantics(
        label: 'Home',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
