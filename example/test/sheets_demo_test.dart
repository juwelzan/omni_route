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
    await t.tap(find.text('Not dismissible'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(400, 20));
    await t.pumpAndSettle();
    expect(find.text('Terms updated'), findsOneWidget);
    await t.tap(find.text('Accept'));
    await t.pumpAndSettle();
    expect(find.text('Terms updated'), findsNothing);

    // Custom look opens and closes from the barrier.
    await t.tap(find.text('Custom look'));
    await t.pumpAndSettle();
    expect(find.text('Premium unlocked'), findsOneWidget);
    await t.tapAt(const Offset(400, 20));
    await t.pumpAndSettle();
    expect(find.text('Premium unlocked'), findsNothing);
  });
}
