import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class _NavTestScreen extends OmniStatelessWidget {
  const _NavTestScreen();

  @override
  String get routePath => '/screen-hook';

  @override
  Widget buildBottomNavigationBar(BuildContext context) =>
      OmniBottomNavigationBar(
        style: OmniBottomNavigationStyle.glowingDot,
        currentIndex: 1,
        onTap: (_) {},
        items: const [
          OmniBottomNavigationItem(icon: Icon(Icons.home_outlined), label: 'A'),
          OmniBottomNavigationItem(
            icon: Icon(Icons.star_outline),
            label: 'ScreenHook',
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => const Center(child: Text('Hook Body'));
}

void main() {
  testWidgets(
    'OmniPage embeds const OmniBottomNavigationBar and syncs routePath automatically',
    (t) async {
      const sharedNav = OmniBottomNavigationBar(
        style: OmniBottomNavigationStyle.floatingBubble,
        items: [
          OmniBottomNavigationItem(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Feed',
            routePath: '/feed',
          ),
          OmniBottomNavigationItem(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
            routePath: '/explore',
          ),
          OmniBottomNavigationItem(
            icon: Icon(Icons.bookmark_outline_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved',
            routePath: '/saved',
          ),
        ],
      );

      await t.pumpWidget(
        OmniApp.material(
          initialRoute: '/feed',
          routes: [
            OmniPage(
              '/feed',
              (_) => Builder(
                builder: (ctx) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
                  child: const Center(child: Text('Feed Page Body')),
                ),
              ),
              bottomNavigationBar: sharedNav,
            ),
            OmniPage(
              '/explore',
              (_) => const Center(child: Text('Explore Page Body')),
              bottomNavigationBar: sharedNav,
            ),
            OmniPage(
              '/saved',
              (_) => const Center(child: Text('Saved Page Body')),
              bottomNavigationBar: sharedNav,
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      // Initially at /feed -> Feed tab selected and bottom inset propagated.
      expect(find.text('Feed Page Body'), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Explore'), findsNothing);

      final builderElement = t.element(find.text('Feed Page Body'));
      expect(MediaQuery.paddingOf(builderElement).bottom, greaterThan(50));

      // Tap Explore icon without explicit onTap -> OmniRouteNavigationBridge navigates to /explore!
      await t.tap(find.byIcon(Icons.explore_outlined));
      await t.pumpAndSettle();

      expect(OmniRoute.routePath, '/explore');
      expect(find.text('Explore Page Body'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Feed'), findsNothing);

      // Tap Saved -> navigates to /saved & highlights Saved automatically!
      await t.tap(find.byIcon(Icons.bookmark_outline_rounded));
      await t.pumpAndSettle();

      expect(OmniRoute.routePath, '/saved');
      expect(find.text('Saved Page Body'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'OmniPage supports extendBottomNavigationBar: false and OmniScreen hook',
    (t) async {
      await t.pumpWidget(
        OmniApp.material(
          initialRoute: '/docked',
          routes: [
            OmniPage(
              '/docked',
              (_) => Builder(
                builder: (ctx) => Container(
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Text(
                    'bottom=${MediaQuery.paddingOf(ctx).bottom.toInt()}',
                  ),
                ),
              ),
              extendBottomNavigationBar: false,
              bottomNavigationBar: const OmniBottomNavigationBar(
                style: OmniBottomNavigationStyle.materialPill,
                items: [
                  OmniBottomNavigationItem(
                    icon: Icon(Icons.home_outlined),
                    label: 'One',
                    routePath: '/docked',
                  ),
                  OmniBottomNavigationItem(
                    icon: Icon(Icons.layers_outlined),
                    label: 'Screen',
                    routePath: '/screen-hook',
                  ),
                ],
              ),
            ),
            OmniPage.screen(const _NavTestScreen()),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('bottom=0'), findsOneWidget);

      await t.tap(find.byIcon(Icons.layers_outlined));
      await t.pumpAndSettle();

      expect(find.text('Hook Body'), findsOneWidget);
      expect(find.text('ScreenHook'), findsOneWidget);
    },
  );

  testWidgets('OmniStatefulShell.adaptive supports custom bottomBarStyle', (
    t,
  ) async {
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });

    await t.pumpWidget(
      OmniApp.material(
        initialRoute: '/tab-a',
        routes: [
          OmniStatefulShell.adaptive(
            bottomBarStyle: OmniBottomNavigationStyle.slidingPill,
            destinations: const [
              OmniAdaptiveDestination(
                icon: Icon(Icons.looks_one_outlined),
                label: 'Alpha',
              ),
              OmniAdaptiveDestination(
                icon: Icon(Icons.looks_two_outlined),
                label: 'Beta',
              ),
            ],
            branches: [
              OmniBranch(
                routes: [
                  OmniPage('/tab-a', (_) => const Center(child: Text('View A'))),
                ],
              ),
              OmniBranch(
                routes: [
                  OmniPage('/tab-b', (_) => const Center(child: Text('View B'))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    await t.pumpAndSettle();

    expect(find.byType(OmniBottomNavigationBar), findsOneWidget);
    expect(find.text('View A'), findsOneWidget);

    await t.tap(find.text('Beta'));
    await t.pumpAndSettle();
    expect(find.text('View B'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
}
