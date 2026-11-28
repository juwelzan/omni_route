import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route_example/bottom_nav_demo.dart';

void main() {
  testWidgets('OmniPage demo: fixed bar, mode switch, page without bar', (
    t,
  ) async {
    addTearDown(() => omniPageBarMode.value = OmniPageBarTransition.slide);
    await t.pumpWidget(
      ValueListenableBuilder<OmniPageBarTransition>(
        valueListenable: omniPageBarMode,
        builder: (context, mode, _) => OmniApp.material(
          bottomBarTransition: mode,
          transition: OmniPages.fadeSlide,
          initialRoute: '/omni-page-nav/feed',
          routes: [
            OmniPage.screen(const BottomNavDemoScreen()),
            OmniPage.screen(
              const OmniPageNavFeedScreen(),
              bottomNavigationBar: omniPageDemoSharedBar,
            ),
            OmniPage.screen(
              const OmniPageNavExploreScreen(),
              bottomNavigationBar: omniPageDemoSharedBar,
            ),
            OmniPage.screen(const OmniPageNavDetailsScreen()),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    final bars = find.byType(OmniBottomNavigationBar);
    final rest = t.getRect(bars);

    // Default: one bar, fixed, while the page changes.
    await t.tap(find.byIcon(Icons.auto_awesome_outlined));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(bars, findsOneWidget);
    expect(t.getRect(bars), rest);
    await t.pumpAndSettle();
    expect(find.text('OmniPage Direct Explore'), findsWidgets);

    // A page without a bar: the bar slides away, and comes back.
    await t.tap(find.text('Open a page without a bar'));
    await t.pumpAndSettle();
    expect(find.text('Details (no bar)'), findsOneWidget);
    expect(bars, findsNothing);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(t.getRect(bars), rest);

    // "With page": each page carries its own bar.
    await t.tap(find.text('With page'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.dynamic_feed_outlined));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(bars, findsNWidgets(2));
    await t.pumpAndSettle();
  });
}
