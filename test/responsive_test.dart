import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

void main() {
  group('OmniResponsiveConfig & Scope', () {
    testWidgets('resolves mobile, smallPhone, tablet, desktop, and largeDesktop', (
      t,
    ) async {
      late OmniResponsiveData captured;

      Future<void> pumpAt(Size logicalSize) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = logicalSize;
        addTearDown(t.view.reset);

        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (p) => Builder(
                  builder: (context) {
                    captured = context.responsive;
                    return Scaffold(
                      body: Text('device:${captured.device.name}'),
                    );
                  },
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
      }

      await pumpAt(const Size(320, 640));
      expect(captured.device, OmniDeviceType.mobile);
      expect(captured.isSmallPhone, isTrue);
      expect(captured.windowSize, OmniWindowSize.compact);
      expect(captured.tokens.gridColumns, 2);
      expect(captured.tokens.textScale, 0.94);

      await pumpAt(const Size(390, 844));
      expect(captured.device, OmniDeviceType.mobile);
      expect(captured.isSmallPhone, isFalse);
      expect(captured.windowSize, OmniWindowSize.compact);
      expect(captured.tokens.textScale, 1.0);

      await pumpAt(const Size(768, 1024));
      expect(captured.device, OmniDeviceType.tablet);
      expect(captured.windowSize, OmniWindowSize.medium);
      expect(captured.tokens.gridColumns, 3);
      expect(captured.isTabletOrLarger, isTrue);

      await pumpAt(const Size(900, 900));
      expect(captured.device, OmniDeviceType.tablet);
      expect(captured.windowSize, OmniWindowSize.expanded);

      await pumpAt(const Size(1280, 800));
      expect(captured.device, OmniDeviceType.desktop);
      expect(captured.windowSize, OmniWindowSize.large);
      expect(captured.tokens.gridColumns, 4);
      expect(captured.tokens.textScale, 1.05);

      await pumpAt(const Size(1680, 1050));
      expect(captured.device, OmniDeviceType.largeDesktop);
      expect(captured.windowSize, OmniWindowSize.extraLarge);
      expect(captured.tokens.gridColumns, 5);
      expect(captured.tokens.textScale, 1.08);
    });

    testWidgets(
      'ZERO rebuilds inside same breakpoint and on keyboard open/close',
      (t) async {
        var deviceBuilds = 0;
        var tokenBuilds = 0;
        var windowSizeBuilds = 0;
        var orientationBuilds = 0;
        var layoutBuilds = 0;
        var rawSizeBuilds = 0;

        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(380, 800);
        addTearDown(t.view.reset);

        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  body: Column(
                    children: [
                      Builder(
                        builder: (c) {
                          deviceBuilds++;
                          return Text('m:${c.isMobile}');
                        },
                      ),
                      Builder(
                        builder: (c) {
                          tokenBuilds++;
                          return SizedBox(height: c.tokens.spaceMd);
                        },
                      ),
                      Builder(
                        builder: (c) {
                          windowSizeBuilds++;
                          return Text('w:${c.windowSize.name}');
                        },
                      ),
                      Builder(
                        builder: (c) {
                          orientationBuilds++;
                          return Text('o:${c.isPortrait}');
                        },
                      ),
                      OmniResponsiveLayout(
                        mobile: Builder(
                          builder: (_) {
                            layoutBuilds++;
                            return const Text('mobile-slot');
                          },
                        ),
                        tablet: Builder(
                          builder: (_) {
                            layoutBuilds++;
                            return const Text('tablet-slot');
                          },
                        ),
                      ),
                      Builder(
                        builder: (c) {
                          rawSizeBuilds++;
                          return Text('raw:${c.screenWidth.round()}');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(deviceBuilds, 1);
        expect(tokenBuilds, 1);
        expect(windowSizeBuilds, 1);
        expect(orientationBuilds, 1);
        expect(layoutBuilds, 1);
        expect(rawSizeBuilds, 1);

        // Resize repeatedly inside mobile tier (380 -> 580) without rotating:
        for (final w in <double>[400, 440, 490, 540, 580]) {
          t.view.physicalSize = Size(w, 800);
          await t.pump();
        }

        expect(rawSizeBuilds, 6);
        expect(deviceBuilds, 1, reason: '0 rebuilds within mobile tier');
        expect(tokenBuilds, 1, reason: '0 token rebuilds within mobile tier');
        expect(windowSizeBuilds, 1);
        expect(orientationBuilds, 1);
        expect(layoutBuilds, 1);

        // Simulate keyboard open & close (`viewInsets.bottom` changes only):
        t.view.viewInsets = const FakeViewPadding(bottom: 320);
        await t.pump();
        t.view.viewInsets = FakeViewPadding.zero;
        await t.pump();

        expect(deviceBuilds, 1, reason: '0 rebuilds when keyboard toggles');
        expect(tokenBuilds, 1);
        expect(windowSizeBuilds, 1);
        expect(orientationBuilds, 1);
        expect(layoutBuilds, 1);
        expect(rawSizeBuilds, 6);

        // Now cross mobile -> tablet breakpoint (580 -> 720, still portrait):
        t.view.physicalSize = const Size(720, 900);
        await t.pump();

        expect(deviceBuilds, 2);
        expect(tokenBuilds, 2);
        expect(windowSizeBuilds, 2);
        expect(layoutBuilds, 2);
        expect(orientationBuilds, 1, reason: 'orientation stayed portrait');
        expect(find.text('tablet-slot'), findsOneWidget);
      },
    );

    testWidgets('useShortestSide keeps landscape phone in mobile device tier', (
      t,
    ) async {
      late OmniDeviceType device;
      late bool portrait;

      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = const Size(844, 390);
      addTearDown(t.view.reset);

      await t.pumpWidget(
        OmniApp.material(
          responsive: const OmniResponsiveConfig(useShortestSide: true),
          routes: [
            OmniPage(
              '/',
              (_) => Builder(
                builder: (c) {
                  device = c.deviceType;
                  portrait = c.isPortrait;
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(device, OmniDeviceType.mobile);
      expect(portrait, isFalse);
    });

    testWidgets(
      'adaptTextScaling adjusts const Text on desktop and respects maxTextScale clamp',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(1280, 800);
        addTearDown(t.view.reset);

        late TextScaler observed;
        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) {
                    observed = MediaQuery.textScalerOf(c);
                    return const Text('home');
                  },
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(observed.scale(20), closeTo(21.0, 0.01));

        // Now with accessibility = 3.0 and maxTextScale = 1.5 clamp:
        t.platformDispatcher.textScaleFactorTestValue = 3.0;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        await t.pumpWidget(
          OmniApp.material(
            maxTextScale: 1.5,
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) {
                    observed = MediaQuery.textScalerOf(c);
                    return const Text('home');
                  },
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(observed.scale(10), 15);
      },
    );

    testWidgets('works inside Splash and custom Onboarding stages', (t) async {
      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = const Size(1100, 768);
      addTearDown(t.view.reset);

      await t.pumpWidget(
        OmniApp.material(
          config: OmniConfig(
            onboarding: OmniOnboarding(
              persist: false,
              screens: [
                Builder(
                  builder: (c) => Scaffold(
                    body: Text('ob:${c.isDesktop ? 'desktop' : 'other'}'),
                  ),
                ),
              ],
            ),
          ),
          routes: [OmniPage('/', (_) => const Scaffold(body: Text('home')))],
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('ob:desktop'), findsOneWidget);
    });
  });

  group('Responsive Widgets & Adaptive Navigation/Modals', () {
    testWidgets(
      'OmniResponsiveContainer, Visibility, RowColumn & Grid adapt cleanly',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(420, 900);
        addTearDown(t.view.reset);

        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  body: SingleChildScrollView(
                    child: OmniResponsiveContainer(
                      maxWidth: 900,
                      child: Column(
                        children: [
                          const OmniResponsiveVisibility(
                            mobile: false,
                            desktop: true,
                            child: Text('desktop-sidebar'),
                          ),
                          const OmniResponsiveRowColumn(
                            children: [Text('left'), Text('right')],
                          ),
                          OmniResponsiveGrid(
                            mobileColumns: 2,
                            desktopColumns: 4,
                            children: const [
                              Text('c1'),
                              Text('c2'),
                              Text('c3'),
                              Text('c4'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('desktop-sidebar'), findsNothing);
        expect(find.byType(Column), findsWidgets);
        // Check 2-column vs 4-column grid delegate:
        var grid = t.widget<GridView>(find.byType(GridView));
        var delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, 2);

        // Resize to desktop:
        t.view.physicalSize = const Size(1280, 900);
        await t.pumpAndSettle();

        expect(find.text('desktop-sidebar'), findsOneWidget);
        expect(find.byType(Row), findsWidgets);
        grid = t.widget<GridView>(find.byType(GridView));
        delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, 4);

        final innerBox = t.getSize(
          find
              .descendant(
                of: find.byType(OmniResponsiveContainer),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect(innerBox.width, 900);
      },
    );

    testWidgets(
      'OmniStatefulShell.adaptive switches NavigationBar <-> NavigationRail & preserves tab state',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.reset);

        var tab2Counter = 0;
        await t.pumpWidget(
          OmniApp.material(
            initialRoute: '/feed',
            routes: [
              OmniStatefulShell.adaptive(
                destinations: const [
                  OmniAdaptiveDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Feed',
                  ),
                  OmniAdaptiveDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
                branches: [
                  OmniBranch(
                    routes: [
                      OmniPage(
                        '/feed',
                        (_) => const Center(child: Text('feed-body')),
                      ),
                    ],
                  ),
                  OmniBranch(
                    routes: [
                      OmniPage(
                        '/profile',
                        (_) => StatefulBuilder(
                          builder: (_, setState) => Center(
                            child: ElevatedButton(
                              onPressed: () => setState(() => tab2Counter++),
                              child: Text('count:$tab2Counter'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        // Mobile shows bottom NavigationBar, no NavigationRail:
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);

        // Switch to Profile tab & increment counter:
        await t.tap(find.text('Profile'));
        await t.pumpAndSettle();
        await t.tap(find.text('count:0'));
        await t.pump();
        expect(find.text('count:1'), findsOneWidget);

        // Switch to Tablet -> compact NavigationRail, state preserved!
        t.view.physicalSize = const Size(800, 1000);
        await t.pumpAndSettle();
        expect(find.byType(NavigationBar), findsNothing);
        var rail = t.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isFalse);
        expect(find.text('count:1'), findsOneWidget);

        // Switch to Desktop -> extended NavigationRail, state still preserved!
        t.view.physicalSize = const Size(1280, 900);
        await t.pumpAndSettle();
        rail = t.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, isTrue);
        expect(find.text('count:1'), findsOneWidget);
      },
    );

    testWidgets(
      'OmniPages.adaptiveModal opens BottomSheet on mobile & Dialog on tablet/desktop',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.reset);

        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage('/', (_) => const Scaffold(body: Text('root'))),
              OmniPage(
                '/filter',
                (_) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('filter-sheet-or-dialog'),
                ),
                transition: OmniPages.adaptiveModal(),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        OmniRoute.push('/filter');
        await t.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);

        OmniRoute.pop();
        await t.pumpAndSettle();

        // Resize to Desktop and open again:
        t.view.physicalSize = const Size(1200, 800);
        await t.pumpAndSettle();

        OmniRoute.push('/filter');
        await t.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
      },
    );

    testWidgets(
      'OmniResponsiveGrid.builder maxItemWidth + OmniResponsiveBuilder + disabled config',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(900, 700);
        addTearDown(t.view.reset);

        var builderCalls = 0;
        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  body: Column(
                    children: [
                      OmniResponsiveBuilder(
                        builder: (c, device, tokens) {
                          builderCalls++;
                          return Text(
                            'b:${device.name}:${tokens.gridColumns}',
                          );
                        },
                      ),
                      Expanded(
                        child: OmniResponsiveGrid.builder(
                          maxItemWidth: 220,
                          itemCount: 8,
                          itemBuilder: (_, i) => Card(child: Text('item-$i')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('b:tablet:3'), findsOneWidget);
        expect(builderCalls, 1);

        final grid = t.widget<GridView>(find.byType(GridView));
        expect(
          grid.gridDelegate,
          isA<SliverGridDelegateWithMaxCrossAxisExtent>(),
        );

        // Resize within tablet tier (900 -> 960): OmniResponsiveBuilder keeps 1 build.
        t.view.physicalSize = const Size(960, 700);
        await t.pump();
        expect(builderCalls, 1);

        // Disabled config stops tier text scaling on desktop:
        late TextScaler disabledScaler;
        t.view.physicalSize = const Size(1280, 800);
        await t.pumpWidget(
          OmniApp.material(
            responsive: const OmniResponsiveConfig.disabled(),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) {
                    disabledScaler = MediaQuery.textScalerOf(c);
                    return const Text('disabled');
                  },
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(disabledScaler.scale(20), 20);
      },
    );

    testWidgets(
      'short landscape NavigationRail never overflows, custom token gridColumns respected, split-pane constrained scope & expandInRow work safely',
      (t) async {
        // Short landscape viewport (844x390) with 6 destinations in adaptive shell:
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(844, 390);
        addTearDown(t.view.reset);

        OmniDeviceType? paneDevice;
        OmniDeviceType? readDeviceFromTap;
        int? customCols;

        await t.pumpWidget(
          OmniApp.material(
            initialRoute: '/tab0',
            responsive: OmniResponsiveConfig(
              tokens: OmniResponsiveTokenSet(
                tablet: OmniResponsiveTokens.tablet.copyWith(gridColumns: 6),
              ),
            ),
            routes: [
              OmniStatefulShell.adaptive(
                destinations: const [
                  OmniAdaptiveDestination(icon: Icon(Icons.home), label: 'T0'),
                  OmniAdaptiveDestination(icon: Icon(Icons.star), label: 'T1'),
                  OmniAdaptiveDestination(icon: Icon(Icons.map), label: 'T2'),
                  OmniAdaptiveDestination(icon: Icon(Icons.chat), label: 'T3'),
                  OmniAdaptiveDestination(icon: Icon(Icons.bolt), label: 'T4'),
                  OmniAdaptiveDestination(icon: Icon(Icons.settings), label: 'T5'),
                ],
                branches: [
                  OmniBranch(
                    routes: [
                      OmniPage(
                        '/tab0',
                        (_) => SingleChildScrollView(
                          child: Builder(
                            builder: (c) {
                              customCols = c.responsiveColumns();
                              return Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      readDeviceFromTap =
                                          c.responsiveRead.device;
                                    },
                                    child: Text('short:${c.isCompactHeight}'),
                                  ),
                                  const OmniResponsiveRowColumn(
                                    expandInRow: true,
                                    children: [Text('a'), Text('b')],
                                  ),
                                  SizedBox(
                                    width: 320,
                                    height: 200,
                                    child: OmniResponsiveScope.constrained(
                                      child: Builder(
                                        builder: (paneCtx) {
                                          paneDevice = paneCtx.deviceType;
                                          return const Text('pane');
                                        },
                                      ),
                                    ),
                                  ),
                                  OmniResponsiveGrid(
                                    mainAxisExtent: 90,
                                    children: const [Text('g1'), Text('g2')],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (var i = 1; i < 6; i++)
                    OmniBranch(
                      routes: [OmniPage('/tab$i', (_) => Text('tab-$i'))],
                    ),
                ],
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.text('short:true'), findsOneWidget);
        expect(customCols, 6);
        expect(paneDevice, OmniDeviceType.mobile);

        await t.tap(find.text('short:true'));
        expect(readDeviceFromTap, OmniDeviceType.tablet);
        expect(t.takeException(), isNull);
      },
    );
  });
}
