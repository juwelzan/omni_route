import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route_example/bottom_nav_demo.dart';

void main() {
  testWidgets(
    'BottomNavDemoScreen switches CollectUI styles and opens OmniPage routes',
    (t) async {
      await t.pumpWidget(
        OmniApp.material(
          initialRoute: '/bottom-nav-demo',
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
            OmniPage.screen(
              const OmniPageNavSavedScreen(),
              bottomNavigationBar: omniPageDemoSharedBar,
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Mode: Floating Pill'), findsOneWidget);

      await t.tap(find.text('Bubble Expand'));
      await t.pumpAndSettle();
      expect(find.text('Mode: Bubble Expand'), findsOneWidget);

      await t.tap(find.text('Curved Wave Notch'));
      await t.pumpAndSettle();
      expect(find.text('Mode: Curved Wave Notch'), findsOneWidget);

      await t.tap(find.text('Try Direct OmniPage Bottom Bar'));
      await t.pumpAndSettle();
      expect(OmniRoute.routePath, '/omni-page-nav/feed');
      expect(find.text('OmniPage Direct Feed'), findsWidgets);

      await t.tap(find.byIcon(Icons.auto_awesome_outlined));
      await t.pumpAndSettle();
      expect(OmniRoute.routePath, '/omni-page-nav/explore');
      expect(find.text('OmniPage Direct Explore'), findsWidgets);
    },
  );
}
