import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

enum _SortOrder { newest, oldest, rating }

class _StaticThemeLeaf extends StatelessWidget {
  const _StaticThemeLeaf();

  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    builds++;
    return const Text('static-leaf');
  }
}

class _OrderBloc extends Cubit<int> {
  _OrderBloc() : super(1);
}

void main() {
  group('OmniMasterDetail & OmniFoldableSplit', () {
    testWidgets(
      'mobile renders master-only (zero detail alloc) & wide pane avoids master list rebuilds',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.reset);

        var masterBuilds = 0;
        var detailBuilds = 0;
        String? mobileOpened;

        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  body: OmniMasterDetail<String>(
                    masterBuilder: (ctx, selection, onSelect) {
                      masterBuilds++;
                      return ListView(
                        children: [
                          for (final item in const ['alpha', 'beta', 'gamma'])
                            ListTile(
                              title: Text('row:$item'),
                              onTap: () => onSelect(item),
                            ),
                        ],
                      );
                    },
                    detailBuilder: (ctx, item) {
                      detailBuilds++;
                      return Text('detail:$item');
                    },
                    emptyDetailBuilder: (_) => const Text('pick-one'),
                    onOpenMobile: (_, item) => mobileOpened = item,
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(masterBuilds, 1);
        expect(detailBuilds, 0, reason: 'detail skipped completely on mobile');
        await t.tap(find.text('row:beta'));
        await t.pump();
        expect(mobileOpened, 'beta');

        // Resize to desktop -> shows split panes & empty placeholder or selected item:
        t.view.physicalSize = const Size(1280, 800);
        await t.pumpAndSettle();
        expect(find.text('detail:beta'), findsOneWidget);
        final buildsAfterResize = masterBuilds;
        final detailBeforeTap = detailBuilds;

        // Selecting another item in wide layout rebuilds detail ONLY, zero master rebuilds:
        await t.tap(find.text('row:gamma'));
        await t.pump();
        expect(find.text('detail:gamma'), findsOneWidget);
        expect(masterBuilds, buildsAfterResize);
        expect(detailBuilds, detailBeforeTap + 1);
      },
    );

    testWidgets('OmniFoldableSplit places secondary pane strictly right of hinge', (
      t,
    ) async {
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(824, 900),
            displayFeatures: [
              ui.DisplayFeature(
                bounds: Rect.fromLTWH(400, 0, 24, 900),
                type: ui.DisplayFeatureType.hinge,
                state: ui.DisplayFeatureState.postureHalfOpened,
              ),
            ],
          ),
          child: OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => const Scaffold(
                  body: OmniFoldableSplit(
                    primary: Center(child: Text('left-pane')),
                    secondary: Center(child: Text('right-pane')),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();

      final leftRect = t.getRect(find.text('left-pane'));
      final rightRect = t.getRect(find.text('right-pane'));
      expect(leftRect.right, lessThanOrEqualTo(400));
      expect(rightRect.left, greaterThanOrEqualTo(424));
    });
  });

  group('OmniTheme memoization', () {
    testWidgets(
      'same breakpoint reuses identical ThemeData instance; switches cleanly on desktop',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.reset);

        final captured = <ThemeData>[];
        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(seedColor: Colors.teal),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) {
                    captured.add(Theme.of(c));
                    return const Scaffold(body: Text('themed'));
                  },
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(captured.single.materialTapTargetSize, MaterialTapTargetSize.padded);

        // Resize within mobile tier -> ThemeData instance MUST stay identical:
        t.view.physicalSize = const Size(480, 844);
        await t.pump();
        expect(captured.length, 1);

        // Cross to desktop tier -> compact density + updated typography:
        t.view.physicalSize = const Size(1280, 800);
        await t.pumpAndSettle();
        expect(captured.last.visualDensity, VisualDensity.compact);
        expect(
          captured.last.materialTapTargetSize,
          MaterialTapTargetSize.shrinkWrap,
        );
        expect(
          captured.last.textTheme.headlineMedium?.fontSize,
          OmniResponsiveTokens.desktop.headlineSize,
        );
      },
    );
  });

  group('Deep-link Validation, Prefetch, Slivers & Breadcrumbs', () {
    testWidgets(
      'OmniPage.validateParams rejects invalid params BEFORE creating page Blocs',
      (t) async {
        var blocCreated = 0;
        await t.pumpWidget(
          OmniApp.material(
            initialRoute: '/orders/0?sort=newest',
            routes: [
              OmniPage(
                '/orders/:id',
                (p) {
                  final id = p.pathPositiveInt('id');
                  final sort = p.pathEnum('sort', _SortOrder.values);
                  return Text('order:$id:${sort.name}');
                },
                validateParams: (p) {
                  p.pathPositiveInt('id');
                  p.queryEnum('sort', _SortOrder.values);
                  return null;
                },
                blocs: [
                  OmniBloc<_OrderBloc>((_) {
                    blocCreated++;
                    return _OrderBloc();
                  }),
                ],
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(blocCreated, 0);
        expect(find.textContaining('Page not found'), findsOneWidget);

        // Strict query validators check:
        final state = OmniRouteState(
          uri: Uri(
            path: '/check',
            query: 'req=yes&when=2026-11-27&mode=fast&sort=rating',
          ),
          matchedLocation: '/check',
          pageKey: const ValueKey('check'),
          pathParameters: const {'order': 'oldest'},
        );
        final p = state.params;
        expect(p.queryRequired('req'), 'yes');
        expect(p.queryDateTime('when')?.year, 2026);
        expect(p.queryOneOf('mode', const ['fast', 'accurate']), 'fast');
        expect(p.pathEnum('order', _SortOrder.values), _SortOrder.oldest);
      },
    );

    testWidgets(
      'OmniPrefetch deduplicates hover bursts & skips invalid parameter URLs',
      (t) async {
        final prefetched = <String>[];
        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => const Scaffold(
                  body: Column(
                    children: [
                      OmniPrefetch(
                        location: '/product/42',
                        child: SizedBox(
                          width: 120,
                          height: 48,
                          child: Text('valid-card'),
                        ),
                      ),
                      OmniPrefetch(
                        location: '/product/-1',
                        child: SizedBox(
                          width: 120,
                          height: 48,
                          child: Text('invalid-card'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              OmniPage(
                '/product/:id',
                (p) => Text('p:${p.pathPositiveInt('id')}'),
                validateParams: (p) {
                  p.pathPositiveInt('id');
                  return null;
                },
                onPrefetch: (_, p) => prefetched.add(p.path('id')),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        // Simulate desktop hover enter twice & touch down:
        final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(t.getCenter(find.text('valid-card')));
        await t.pump();
        await gesture.moveTo(t.getCenter(find.text('valid-card')));
        await t.pump();

        // Also touch down on invalid target -> must NOT prefetch:
        await t.press(find.text('invalid-card'));
        await t.pump();

        expect(prefetched, ['42']);
      },
    );

    testWidgets(
      'OmniBreadcrumbBar, lazy OmniResponsiveSliverGrid & bounded breadcrumbs',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(1200, 700);
        addTearDown(t.view.reset);

        var builtItems = 0;
        await t.pumpWidget(
          OmniApp.material(
            maxBreadcrumbs: 5,
            initialRoute: '/shop/electronics',
            routes: [
              OmniPage('/', (_) => const Scaffold(body: Text('root-home'))),
              OmniPage(
                '/shop',
                (_) => const Scaffold(body: Text('shop-cat')),
                routes: [
                  OmniPage(
                    'electronics',
                    (_) => Scaffold(
                      body: CustomScrollView(
                        slivers: [
                          const SliverToBoxAdapter(child: OmniBreadcrumbBar()),
                          OmniResponsiveSliverGrid(
                            itemCount: 1000,
                            maxItemWidth: 250,
                            mainAxisExtent: 120,
                            itemBuilder: (_, i) {
                              builtItems++;
                              return Card(child: Text('tile-$i'));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Shop'), findsOneWidget);
        expect(find.text('Electronics'), findsOneWidget);
        // Only visible viewport slivers should build (far fewer than 1000):
        expect(builtItems, lessThan(50));

        // Tapping 'Shop' breadcrumb navigates cleanly to /shop:
        await t.tap(find.text('Shop'));
        await t.pumpAndSettle();
        expect(find.text('shop-cat'), findsOneWidget);

        // Push/go repeatedly -> breadcrumbs remain strictly bounded <= 5:
        for (var i = 0; i < 12; i++) {
          OmniRoute.go(i.isEven ? '/' : '/shop');
          await t.pump();
        }
        OmniRoute.recordBreadcrumb('custom checkpoint', data: {'step': 99});
        expect(OmniRoute.breadcrumbs.length, 5);
        final report = OmniRoute.exportDiagnostics();
        expect(report, contains('OmniRoute Diagnostics'));
        expect(report, contains('custom checkpoint'));

        // Mobile hides breadcrumb bar:
        OmniRoute.go('/shop/electronics');
        await t.pumpAndSettle();
        t.view.physicalSize = const Size(390, 844);
        await t.pumpAndSettle();
        expect(find.text('Electronics'), findsNothing);
      },
    );
  });

  group('OmniAppGate (Maintenance & Force Update)', () {
    testWidgets(
      'maintenance blocks startup & dismissible update allows continuing',
      (t) async {
        var maintenance = true;
        await t.pumpWidget(
          OmniApp.material(
            config: OmniConfig(
              gate: OmniAppGate(
                check: (_) => maintenance
                    ? const OmniGateDecision(
                        status: OmniGateStatus.maintenance,
                        title: 'Scheduled Upgrade',
                        message: 'Back in 5 minutes',
                      )
                    : const OmniGateDecision(
                        status: OmniGateStatus.updateRequired,
                        title: 'New Version Available',
                        minVersion: '2.0.0',
                        canDismiss: true,
                      ),
              ),
            ),
            routes: [OmniPage('/', (_) => const Scaffold(body: Text('home')))],
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Scheduled Upgrade'), findsOneWidget);
        expect(find.text('home'), findsNothing);

        // Retry after maintenance flips to dismissible update:
        maintenance = false;
        await t.tap(find.text('Retry'));
        await t.pumpAndSettle();
        expect(find.text('New Version Available'), findsOneWidget);

        await t.tap(find.text('Later'));
        await t.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
      },
    );
  });

  group('OmniTheme Mode Switching, Presets & Persistence', () {
    testWidgets(
      'OmniThemeModeButton, OmniThemeModeSwitch, context.toggleTheme & persistence work effortlessly',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        _StaticThemeLeaf.builds = 0;

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme.pill(
              seedColor: Colors.deepPurple,
              mode: ThemeMode.light,
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Theme App'),
                    actions: const [OmniThemeModeButton()],
                  ),
                  body: Column(
                    children: [
                      const _StaticThemeLeaf(),
                      Builder(
                        builder: (c) => Text('dark:${c.isDarkMode}'),
                      ),
                      const OmniThemeModeSwitch(
                        systemLabel: 'Auto',
                        lightLabel: 'Day',
                        darkLabel: 'Night',
                      ),
                      Builder(
                        builder: (c) => ElevatedButton(
                          onPressed: () => c.toggleTheme(),
                          child: const Text('manual-toggle'),
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

        expect(_StaticThemeLeaf.builds, 1);
        expect(find.text('dark:false'), findsOneWidget);

        // 1-tap AppBar button switches to Dark mode cleanly:
        await t.tap(find.byType(OmniThemeModeButton));
        await t.pumpAndSettle();
        expect(find.text('dark:true'), findsOneWidget);
        expect(
          _StaticThemeLeaf.builds,
          1,
          reason: 'unrelated static child widgets never rebuild on theme toggle',
        );

        // Verify saved to SharedPreferences:
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('omni_route.theme.default.mode'), 'dark');

        // Segmented switch selects Day -> back to Light:
        await t.tap(find.text('Day'));
        await t.pumpAndSettle();
        expect(find.text('dark:false'), findsOneWidget);
        expect(prefs.getString('omni_route.theme.default.mode'), 'light');

        // Manual toggle puts it back to Dark:
        await t.tap(find.text('manual-toggle'));
        await t.pumpAndSettle();
        expect(find.text('dark:true'), findsOneWidget);

        // Cold-restart a fresh OmniApp -> restores persisted Dark mode automatically:
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme.compact(
              seedColor: Colors.teal,
              mode: ThemeMode.light,
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) => Text('restoredDark:${c.isDarkMode}'),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('restoredDark:true'), findsOneWidget);
      },
    );

    testWidgets('OmniTheme shares mode inside Onboarding stage views', (t) async {
      SharedPreferences.setMockInitialValues({});

      await t.pumpWidget(
        OmniApp.material(
          omniTheme: const OmniTheme(
            seedColor: Colors.orange,
            mode: ThemeMode.dark,
            persistMode: false,
          ),
          config: OmniConfig(
            onboarding: OmniOnboarding(
              persist: false,
              screens: [
                Builder(
                  builder: (c) => Scaffold(
                    body: TextButton(
                      onPressed: () => c.toggleTheme(),
                      child: Text('obDark:${c.isDarkMode}'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          routes: [OmniPage('/', (_) => const Scaffold(body: Text('home')))],
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('obDark:true'), findsOneWidget);
      await t.tap(find.text('obDark:true'));
      await t.pumpAndSettle();
      expect(find.text('obDark:false'), findsOneWidget);
    });

    testWidgets(
      'OmniColors semantic fields + 1-click multi-theme switching (OmniThemeButton & OmniThemePanel) + persistence & caching',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        late ThemeData customLightTheme;
        late ThemeData customLightThemeReturned;
        late OmniColors capturedColors;

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              id: 'custom',
              name: 'Custom Brand',
              seedColor: Color(0xFF1D4ED8),
              mode: ThemeMode.light,
              surfaceColor: Color(0xFFF3F6FA),
              cardColor: Color(0xFFFFFFFF),
              buttonColor: Color(0xFF0284C7),
              borderColor: Color(0xFF94A3B8),
              errorColor: Color(0xFFB91C1C),
              warningColor: Color(0xFFD97706),
              successColor: Color(0xFF047857),
            ),
            themes: OmniTheme.presets,
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Multi-Theme'),
                    actions: const [
                      OmniThemeButton(),
                      OmniThemeModeButton(),
                    ],
                  ),
                  body: Builder(
                    builder: (c) {
                      final light = OmniThemeScope.maybeThemesOf(c)!.light;
                      if (c.activeThemeId == 'custom') {
                        customLightThemeReturned = light;
                      }
                      capturedColors = c.colors;
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            Text('active:${c.activeThemeId}'),
                            const OmniThemePanel(
                              modeTitle: 'Mode',
                              themeTitle: 'Themes',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        customLightTheme = customLightThemeReturned;
        expect(find.text('active:custom'), findsOneWidget);
        expect(capturedColors.surfaceColor, const Color(0xFFF3F6FA));
        expect(capturedColors.buttonColor, const Color(0xFF0284C7));
        expect(capturedColors.borderColor, const Color(0xFF94A3B8));
        expect(capturedColors.errorColor, const Color(0xFFB91C1C));
        expect(capturedColors.warningColor, const Color(0xFFD97706));
        expect(capturedColors.successColor, const Color(0xFF047857));
        expect(
          Theme.of(t.element(find.text('active:custom'))).scaffoldBackgroundColor,
          const Color(0xFFF3F6FA),
        );

        // 1-click OmniThemeButton switches immediately to Ocean:
        await t.tap(find.byType(OmniThemeButton));
        await t.pumpAndSettle();
        expect(find.text('active:ocean'), findsOneWidget);
        expect(
          capturedColors.primaryColor,
          OmniTheme.ocean.seedColor,
        );

        // 1-click Emerald chip inside OmniThemePanel:
        await t.tap(find.text('Emerald'));
        await t.pumpAndSettle();
        expect(find.text('active:emerald'), findsOneWidget);
        expect(
          capturedColors.primaryColor,
          OmniTheme.emerald.seedColor,
        );

        // Verify persisted themeId + return to custom reuses cached ThemeData:
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('omni_route.theme.default.themeId'), 'emerald');

        await t.tap(find.text('Custom Brand'));
        await t.pumpAndSettle();
        expect(find.text('active:custom'), findsOneWidget);
        expect(
          identical(customLightThemeReturned, customLightTheme),
          isTrue,
          reason: 'revisiting cached theme returns memoized ThemeData instance',
        );

        // Select Sunset then cold-restart -> automatically restores Sunset!
        await t.tap(find.text('Sunset'));
        await t.pumpAndSettle();
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          OmniApp.material(
            themes: OmniTheme.presets,
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) => Text('restored:${c.activeThemeId}'),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('restored:sunset'), findsOneWidget);
      },
    );

    testWidgets(
      'OmniColors (44+ pure names), OmniTextStyles, OmniStyles & OmniInputVariant resolve cleanly with zero resize allocation',
      (t) async {
        const customTheme = OmniTheme(
          id: 'custom_tokens',
          name: 'Custom Tokens',
          seedColor: Colors.indigo,
          headingWeight: FontWeight.w800,
          inputVariant: OmniInputVariant.outlined,
          borderWidth: 1.25,
          focusedBorderWidth: 2.25,
          cardBorderWidth: 1.5,
          secondaryButtonColor: Color(0xFF334155),
          secondaryButtonTextColor: Color(0xFFF8FAFC),
          dangerButtonColor: Color(0xFFB91C1C),
          dangerButtonTextColor: Color(0xFFFFFFFF),
          linkColor: Color(0xFF0284C7),
          navBarColor: Color(0xFFF1F5F9),
          navSelectedColor: Color(0xFF1D4ED8),
          navUnselectedColor: Color(0xFF64748B),
          chipColor: Color(0xFFE2E8F0),
          chipTextColor: Color(0xFF0F172A),
          badgeColor: Color(0xFFDC2626),
          badgeTextColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFFDBEAFE),
          hoverColor: Color(0x141D4ED8),
          shimmerBaseColor: Color(0xFFE5E7EB),
          shimmerHighlightColor: Color(0xFFF9FAFB),
          overlayColor: Color(0x800F172A),
          shadowColor: Color(0x330F172A),
        );

        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.reset);

        late OmniColors lightColors;
        late OmniTextStyles lightTextStyles;
        late OmniStyles lightStyles;
        late InputDecorationThemeData lightInputTheme;
        late ShapeBorder? cardShape;
        double? headlineFontSize;
        double? expectedHeadlineSize;
        OmniStyles? scopeStyles1;

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: customTheme,
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) {
                    lightColors = c.colors;
                    lightTextStyles = c.textStyles;
                    lightStyles = c.styles;
                    lightInputTheme = Theme.of(c).inputDecorationTheme;
                    cardShape = Theme.of(c).cardTheme.shape;
                    headlineFontSize =
                        Theme.of(c).textTheme.headlineMedium?.fontSize;
                    expectedHeadlineSize = c.tokens.headlineSize;
                    scopeStyles1 = OmniThemeScope.maybeThemesOf(
                      c,
                    )?.light.extension<OmniStyles>();

                    return Scaffold(
                      body: Column(
                        children: [
                          Container(
                            decoration: lightStyles.cardDecoration,
                            child: Text('Heading', style: lightTextStyles.heading),
                          ),
                          Container(
                            decoration: lightStyles.warningBoxDecoration,
                            child: Text('Warn', style: lightTextStyles.warning),
                          ),
                          TextField(
                            decoration: lightStyles.inputDecoration(
                              label: 'Email',
                              hint: 'you@example.com',
                            ),
                          ),
                          TextField(
                            decoration: lightStyles.searchDecoration(
                              hint: 'Search',
                              onClear: () {},
                            ),
                          ),
                          FilledButton(
                            style: lightStyles.dangerButton,
                            onPressed: () {},
                            child: const Text('Delete'),
                          ),
                          FilledButton(
                            style: lightStyles.secondaryButton,
                            onPressed: () {},
                            child: const Text('Later'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        // 1. All new pure colors resolved cleanly:
        expect(lightColors.secondaryButtonColor, const Color(0xFF334155));
        expect(lightColors.secondaryButtonTextColor, const Color(0xFFF8FAFC));
        expect(lightColors.dangerButtonColor, const Color(0xFFB91C1C));
        expect(lightColors.dangerButtonTextColor, const Color(0xFFFFFFFF));
        expect(lightColors.linkColor, const Color(0xFF0284C7));
        expect(lightColors.navBarColor, const Color(0xFFF1F5F9));
        expect(lightColors.navSelectedColor, const Color(0xFF1D4ED8));
        expect(lightColors.navUnselectedColor, const Color(0xFF64748B));
        expect(lightColors.chipColor, const Color(0xFFE2E8F0));
        expect(lightColors.chipTextColor, const Color(0xFF0F172A));
        expect(lightColors.badgeColor, const Color(0xFFDC2626));
        expect(lightColors.badgeTextColor, const Color(0xFFFFFFFF));
        expect(lightColors.selectedItemColor, const Color(0xFFDBEAFE));
        expect(lightColors.hoverColor, const Color(0x141D4ED8));
        expect(lightColors.shimmerBaseColor, const Color(0xFFE5E7EB));
        expect(lightColors.shimmerHighlightColor, const Color(0xFFF9FAFB));
        expect(lightColors.overlayColor, const Color(0x800F172A));
        expect(lightColors.shadowColor, const Color(0x330F172A));

        // 2. OmniTextStyles hierarchy & semantic colors:
        expect(lightTextStyles.heading.fontWeight, FontWeight.w800);
        expect(lightTextStyles.display.fontWeight, FontWeight.w800);
        expect(headlineFontSize, expectedHeadlineSize);
        expect(lightTextStyles.link.color, lightColors.linkColor);
        expect(lightTextStyles.error.color, lightColors.errorColor);
        expect(lightTextStyles.warning.color, lightColors.warningColor);
        expect(lightTextStyles.success.color, lightColors.successColor);
        expect(lightTextStyles.bodyMuted.color, lightColors.secondaryTextColor);
        expect(lightTextStyles.hint.color, lightColors.hintTextColor);
        expect(lightTextStyles.code.fontFamily, 'monospace');

        // 3. OmniInputVariant.outlined + border widths + cardBorderWidth:
        expect(lightInputTheme.filled, isFalse);
        expect(lightInputTheme.enabledBorder, isA<OutlineInputBorder>());
        expect(
          (lightInputTheme.enabledBorder! as OutlineInputBorder)
              .borderSide
              .width,
          1.25,
        );
        expect(
          (lightInputTheme.focusedBorder! as OutlineInputBorder)
              .borderSide
              .width,
          2.25,
        );
        expect(cardShape, isA<RoundedRectangleBorder>());
        expect((cardShape! as RoundedRectangleBorder).side.width, 1.5);
        expect(
          (lightStyles.cardDecoration.border! as Border).top.color,
          lightColors.borderColor,
        );
        expect(
          lightStyles.errorBoxDecoration.color,
          lightColors.errorBackgroundColor,
        );
        expect(
          lightStyles.successBoxDecoration.color,
          lightColors.successBackgroundColor,
        );
        expect(
          lightStyles.infoBoxDecoration.color,
          lightColors.infoBackgroundColor,
        );

        // 4. Resizing within same mobile tier reuses exact memoized OmniStyles:
        t.view.physicalSize = const Size(420, 844);
        await t.pumpAndSettle();
        final ctx = t.element(find.byType(Scaffold));
        final scopeStyles2 = OmniThemeScope.maybeThemesOf(
          ctx,
        )?.light.extension<OmniStyles>();
        expect(identical(scopeStyles1, scopeStyles2), isTrue);

        // 5. Underlined input variant + cardBorderWidth = 0 + Dark mode defaults:
        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              seedColor: Colors.teal,
              mode: ThemeMode.dark,
              inputVariant: OmniInputVariant.underlined,
              cardBorderWidth: 0,
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) {
                    final darkTheme = Theme.of(c);
                    final dc = c.colors;
                    final dts = c.textStyles;
                    return Text(
                      'underlined:${darkTheme.inputDecorationTheme.enabledBorder is UnderlineInputBorder}:'
                      'filled:${darkTheme.inputDecorationTheme.filled}:'
                      'cardNone:${(darkTheme.cardTheme.shape! as RoundedRectangleBorder).side == BorderSide.none}:'
                      'shimmerOk:${dc.shimmerBaseColor != dc.shimmerHighlightColor}:'
                      'badgeOk:${dc.badgeColor != dc.badgeTextColor}:'
                      'darkText:${dts.body.color == dc.textColor}',
                    );
                  },
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text(
            'underlined:true:filled:false:cardNone:true:shimmerOk:true:badgeOk:true:darkText:true',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'OmniThemeStyle, context.ui, 53 colors, 8 presets & Settings 1-click Color Palette + Mode sheet',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        expect(OmniTheme.presets.length, 8);
        expect(OmniTheme.findPreset('violet')?.name, 'Violet');
        expect(OmniTheme.findPreset('teal')?.name, 'Teal');
        expect(OmniTheme.findPreset('amber')?.name, 'Amber');

        const themed = OmniTheme(
          id: 'brand',
          name: 'Brand',
          seedColor: Colors.indigo,
          style: OmniThemeStyle.outlined,
          secondaryBackgroundColor: Color(0xFFEAF0F6),
          disabledBorderColor: Color(0xFF94A3B8),
          rippleColor: Color(0x1F4F46E5),
          snackbarColor: Color(0xFF111827),
          snackbarTextColor: Color(0xFFF9FAFB),
          switchActiveColor: Color(0xFF059669),
          switchInactiveColor: Color(0xFF6B7280),
          tooltipColor: Color(0xFF1F2937),
          tooltipTextColor: Color(0xFFFFFFFF),
        );

        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.reset);

        late OmniUiTheme capturedUi;
        late ThemeData capturedThemeData;

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: themed,
            themes: OmniTheme.presets,
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) {
                    capturedUi = c.ui;
                    capturedThemeData = Theme.of(c);
                    return Scaffold(
                      appBar: AppBar(title: const Text('Settings Demo')),
                      body: ListView(
                        padding: capturedUi.tokens.pagePadding,
                        children: [
                          const OmniThemeSettingsTile(),
                          Container(
                            decoration: capturedUi.styles.subtleBoxDecoration,
                            child: Text('Subtle', style: capturedUi.text.body),
                          ),
                          Container(
                            decoration: capturedUi.styles.disabledBoxDecoration,
                            child: Text(
                              'Disabled',
                              style: capturedUi.text.bodyMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        // 1. All 9 new pure semantic colors & ThemeData wiring:
        expect(capturedUi.colors.secondaryBackgroundColor, const Color(0xFFEAF0F6));
        expect(capturedUi.colors.disabledBorderColor, const Color(0xFF94A3B8));
        expect(capturedUi.colors.rippleColor, const Color(0x1F4F46E5));
        expect(capturedUi.colors.snackbarColor, const Color(0xFF111827));
        expect(capturedUi.colors.snackbarTextColor, const Color(0xFFF9FAFB));
        expect(capturedUi.colors.switchActiveColor, const Color(0xFF059669));
        expect(capturedUi.colors.switchInactiveColor, const Color(0xFF6B7280));
        expect(capturedUi.colors.tooltipColor, const Color(0xFF1F2937));
        expect(capturedUi.colors.tooltipTextColor, const Color(0xFFFFFFFF));

        expect(capturedThemeData.splashColor, const Color(0x1F4F46E5));
        expect(
          capturedThemeData.snackBarTheme.backgroundColor,
          const Color(0xFF111827),
        );
        expect(capturedThemeData.tooltipTheme.textStyle?.color, Colors.white);
        expect(
          capturedThemeData.inputDecorationTheme.filled,
          isFalse,
          reason: 'OmniThemeStyle.outlined uses outlined non-filled input',
        );
        expect(
          (capturedUi.styles.subtleBoxDecoration.color),
          const Color(0xFFEAF0F6),
        );
        expect(
          (capturedUi.styles.disabledBoxDecoration.border! as Border).top.color,
          const Color(0xFF94A3B8),
        );
        expect(capturedUi.isMobile, isTrue);
        expect(capturedUi.isDark, isFalse);

        // 2. Open Settings Theme & Color Palette bottom sheet -> 1-click Palette + Mode + Style!
        expect(find.text('Brand · System · Outlined'), findsOneWidget);
        await t.tap(find.byType(OmniThemeSettingsTile));
        await t.pumpAndSettle();

        // Tap Violet palette card:
        await t.tap(find.text('Violet'));
        await t.pumpAndSettle();
        // Tap Dark mode segment:
        await t.tap(find.text('Dark'));
        await t.pumpAndSettle();
        // Tap Elevated style chip:
        await t.tap(find.text('Elevated'));
        await t.pumpAndSettle();

        // Close sheet:
        await t.tap(find.byTooltip('Close'));
        await t.pumpAndSettle();

        expect(find.text('Violet · Dark · Elevated'), findsOneWidget);
        final ctx = t.element(find.byType(Scaffold));
        expect(ctx.activeThemeId, 'violet');
        expect(ctx.activeThemeStyle, OmniThemeStyle.elevated);
        expect(Theme.of(ctx).cardTheme.elevation, 2.0);
        expect(ctx.isDarkMode, isTrue);

        // Verify persistence across cold restart!
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          OmniApp.material(
            themes: OmniTheme.presets,
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) => Text(
                    'restored:${c.activeThemeId}:${c.themeMode.name}:${c.activeThemeStyle.name}',
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('restored:violet:dark:elevated'), findsOneWidget);
      },
    );
  });
}
