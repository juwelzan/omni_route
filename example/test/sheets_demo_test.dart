import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route_example/sheets_demo.dart';

void main() {
  Future<void> pumpDemo(WidgetTester t) async {
    await t.pumpWidget(
      OmniApp(
        routes: [OmniPage.screen(const SheetsDemoScreen())],
        initialRoute: '/settings/sheets',
        builder: (_, router) => MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('bottom sheet demo: pick, detents, form guard, locked', (
    t,
  ) async {
    await pumpDemo(t);

    // Sized to content, returns the picked city.
    await t.tap(find.text('Pick a city'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sylhet'));
    await t.pumpAndSettle();
    expect(find.text('Last picked: Sylhet'), findsOneWidget);

    // Detents: Expand / Collapse move between medium and large.
    await t.tap(find.text('iOS'));
    await t.pumpAndSettle();
    await t.tap(find.text('Long list with detents'));
    await t.pumpAndSettle();
    final mediumTop = t.getTopLeft(find.text('Students')).dy;
    await t.tap(find.text('Expand'));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('Students')).dy, lessThan(mediumTop));
    expect(find.text('Collapse'), findsOneWidget);
    await t.tapAt(const Offset(400, 5)); // barrier above the large sheet
    await t.pumpAndSettle();
    expect(find.text('Students'), findsNothing);

    // Form: with text typed, dragging down asks before closing.
    await t.tap(find.text('Form with keyboard'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Buy milk');
    await t.pumpAndSettle();
    await t.timedDrag(
      find.text('New note'),
      const Offset(0, 250),
      const Duration(milliseconds: 700),
    );
    await t.pumpAndSettle();
    expect(find.text('Discard note?'), findsOneWidget);
    await t.tap(find.text('Discard'));
    await t.pumpAndSettle();
    expect(find.text('New note'), findsNothing);

    // Not dismissible: a barrier tap keeps it, its button closes it.
    await t.ensureVisible(find.text('Not dismissible'));
    await t.pumpAndSettle();
    await t.tap(find.text('Not dismissible'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(400, 20));
    await t.pumpAndSettle();
    expect(find.text('Terms updated'), findsOneWidget);
    await t.tap(find.text('Accept'));
    await t.pumpAndSettle();
    expect(find.text('Terms updated'), findsNothing);

    // Custom look opens and closes from the barrier.
    await t.ensureVisible(find.text('Custom look'));
    await t.pumpAndSettle();
    await t.tap(find.text('Custom look'));
    await t.pumpAndSettle();
    expect(find.text('Premium unlocked'), findsOneWidget);
    await t.tapAt(const Offset(400, 20));
    await t.pumpAndSettle();
    expect(find.text('Premium unlocked'), findsNothing);
  });

  testWidgets('scalable sheet demo: opens at medium, expands, styles', (
    t,
  ) async {
    await t.pumpWidget(
      OmniApp(
        routes: [OmniPage.screen(const ScalableSheetDemoScreen())],
        initialRoute: '/settings/sheets/scalable',
        builder: (_, router) => MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    final mediumTop = t.getTopLeft(find.text('Places nearby')).dy;
    expect(find.text('Expand'), findsOneWidget);

    // The FAB rides above the sheet and expands it.
    final fabAtMedium = t.getCenter(find.byTooltip('Show places')).dy;
    await t.tap(find.byTooltip('Show places'));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('Places nearby')).dy, lessThan(mediumTop));
    expect(find.text('Collapse'), findsOneWidget);

    await t.tap(find.text('Collapse'));
    await t.pumpAndSettle();
    expect(
      t.getCenter(find.byTooltip('Show places')).dy,
      greaterThan(fabAtMedium),
      reason: 'the button follows the sheet down to the peek size',
    );

    // Switching style re-creates the sheet at its initial (medium) size.
    await t.tap(find.byTooltip('Style'));
    await t.pumpAndSettle();
    await t.tap(find.text('floating'));
    await t.pumpAndSettle();
    expect(find.text('Places nearby'), findsOneWidget);
    expect(find.text('Expand'), findsOneWidget);
  });
}
