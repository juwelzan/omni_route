import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route_example/bottom_nav_demo.dart';

void main() {
  testWidgets('notch panel customizes the curved notch and resets', (t) async {
    await t.pumpWidget(
      OmniApp(
        routes: [OmniPage.screen(const BottomNavDemoScreen())],
        initialRoute: '/bottom-nav-demo',
        builder: (_, router) => MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Notch & orb'), findsNothing);

    await t.tap(find.text('Curved Wave Notch'));
    await t.pumpAndSettle();
    expect(find.text('Notch & orb'), findsOneWidget);

    OmniBottomNavigationNotch notch() => t
        .widget<OmniBottomNavigationBar>(find.byType(OmniBottomNavigationBar))
        .notch!;
    expect(notch(), OmniBottomNavigationNotch.standard);

    await t.ensureVisible(find.text('Circle'));
    // Keep it clear of the floating bar that overlays the list's bottom.
    await t.drag(find.byType(ListView), const Offset(0, 120));
    await t.pumpAndSettle();
    await t.tap(find.text('Circle'));
    await t.pumpAndSettle(); // each tap rebuilds the panel before the next
    await t.tap(find.text('Dip'));
    await t.pumpAndSettle();
    expect(notch().shape, OmniNotchShape.circular);
    expect(notch().travel, OmniNotchTravel.dip);
    // Depth / wave width only apply to the smooth shape.
    expect(find.text('Depth'), findsNothing);

    // Switching tabs with the custom notch runs cleanly.
    await t.tap(find.byIcon(Icons.person_outline_rounded).last);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    await t.tap(find.text('Reset'));
    await t.pumpAndSettle();
    expect(notch(), OmniBottomNavigationNotch.standard);

    // The centre FAB style shares the panel, without the travel options.
    await t.scrollUntilVisible(find.text('Center FAB Cradle'), -150);
    await t.pumpAndSettle();
    await t.tap(find.text('Center FAB Cradle'));
    await t.pumpAndSettle();
    expect(find.text('Notch & orb'), findsOneWidget);
    expect(find.text('Dip'), findsNothing);
  });

  testWidgets('layout, placement and selection mode controls', (t) async {
    await t.pumpWidget(
      OmniApp(
        routes: [OmniPage.screen(const BottomNavDemoScreen())],
        initialRoute: '/bottom-nav-demo',
        builder: (_, router) => MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    OmniBottomNavigationBar bar() =>
        t.widget<OmniBottomNavigationBar>(find.byType(OmniBottomNavigationBar));

    await t.scrollUntilVisible(find.text('Side by side'), 200);
    await t.ensureVisible(find.text('Side by side'));
    await t.drag(find.byType(ListView), const Offset(0, 120));
    await t.pumpAndSettle();
    await t.tap(find.text('Side by side'));
    await t.pumpAndSettle();
    expect(bar().itemLayout, OmniBottomNavItemLayout.inline);
    await t.tap(find.text('Docked'));
    await t.pumpAndSettle();
    expect(bar().docked, isTrue);
    expect(t.takeException(), isNull);

    // Long-press a card: the contextual bar takes the bar's place.
    await t.scrollUntilVisible(find.text('Mobile Pattern Card #2'), 200);
    await t.ensureVisible(find.text('Mobile Pattern Card #2'));
    await t.drag(find.byType(ListView), const Offset(0, 120));
    await t.pumpAndSettle();
    await t.longPress(find.text('Mobile Pattern Card #2'));
    await t.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await t.tap(find.text('Mobile Pattern Card #3'));
    await t.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.text('2 selected'), findsNothing);
  });
}
