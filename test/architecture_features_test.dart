import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _VideoScreen extends OmniStatelessWidget {
  const _VideoScreen();

  @override
  String get routePath => '/video';

  @override
  OmniScreenMode get screenMode => OmniScreenMode.fullscreenLean;

  @override
  OmniOrientation get orientation => OmniOrientation.landscape;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('video:full=${context.isFullscreen}'),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('close-video'),
          ),
        ],
      ),
    );
  }
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
      'OmniThemeStyle, context.ui, 53 colors, 16 presets & Settings 1-click Color Palette + Mode sheet',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        expect(OmniTheme.presets.length, 16);
        expect(OmniTheme.presets.map((p) => p.id).toSet().length, 16);
        expect(OmniThemeStyle.values.length, 12);
        expect(OmniTheme.findPreset('violet')?.name, 'Violet');
        expect(OmniTheme.findPreset('teal')?.name, 'Teal');
        expect(OmniTheme.findPreset('amber')?.name, 'Amber');
        expect(OmniTheme.findPreset('indigo')?.name, 'Indigo');
        expect(OmniTheme.findPreset('crimson')?.name, 'Crimson');
        expect(OmniTheme.findPreset('cyberpunk')?.name, 'Neon Cyber');
        expect(OmniTheme.findPreset('forest')?.name, 'Forest');
        expect(OmniTheme.findPreset('coffee')?.name, 'Espresso');
        expect(OmniTheme.findPreset('nordic')?.name, 'Nordic Ice');
        expect(OmniTheme.findPreset('gold')?.name, 'Royal Gold');
        expect(OmniTheme.findPreset('monochrome')?.name, 'Monochrome');

        // Verify monochrome light/dark palettes produce crisp AMOLED contrast & pure light/dark buttons:
        final monoLight = OmniTheme.monochrome.resolveColors(Brightness.light);
        final monoDark = OmniTheme.monochrome.resolveColors(Brightness.dark);
        expect(monoLight.buttonColor, const Color(0xFF18181B));
        expect(monoLight.buttonTextColor, const Color(0xFFFFFFFF));
        expect(monoDark.surfaceColor, const Color(0xFF000000));
        expect(monoDark.buttonColor, const Color(0xFFFAFAFA));
        expect(monoDark.buttonTextColor, const Color(0xFF09090B));

        // Verify new OmniThemeStyle border/elevation presets:
        expect(OmniThemeStyle.pill.borderRadius, 24.0);
        expect(OmniThemeStyle.sharp.borderRadius, 4.0);
        expect(OmniThemeStyle.floating.cardElevation, 6.0);
        expect(OmniThemeStyle.floating.cardBorderWidth, 0.0);
        expect(OmniThemeStyle.brutal.borderWidth, 2.2);
        expect(OmniThemeStyle.flat.cardBorderWidth, 0.0);
        expect(OmniThemeStyle.flat.cardElevation, 0.0);
        expect(OmniThemeStyle.glassy.borderWidth, 0.7);
        expect(OmniThemeStyle.glassy.borderRadius, 18.0);

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
        await t.ensureVisible(find.text('Violet'));
        await t.tap(find.text('Violet'));
        await t.pumpAndSettle();
        // Tap Dark mode segment:
        await t.ensureVisible(find.text('Dark'));
        await t.tap(find.text('Dark'));
        await t.pumpAndSettle();
        // Tap Elevated style chip:
        await t.ensureVisible(find.text('Elevated'));
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
                (_) => Scaffold(
                  body: Builder(
                    builder: (c) => Text(
                      'restored:${c.activeThemeId}:${c.themeMode.name}:${c.activeThemeStyle.name}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('restored:violet:dark:elevated'), findsOneWidget);

        // Verify borderless styles (.flat & .floating) emit no Card/cardDecoration borders:
        final flatCtx = t.element(find.byType(Scaffold));
        flatCtx.setThemeStyle(OmniThemeStyle.flat);
        await t.pumpAndSettle();
        expect(flatCtx.activeThemeStyle, OmniThemeStyle.flat);
        expect(flatCtx.ui.styles.cardDecoration.border, isNull);
        expect(Theme.of(flatCtx).cardTheme.elevation, 0.0);

        flatCtx.setThemeStyle(OmniThemeStyle.floating);
        await t.pumpAndSettle();
        expect(flatCtx.ui.styles.cardDecoration.border, isNull);
        expect(Theme.of(flatCtx).cardTheme.elevation, 6.0);
      },
    );
  });

  group('System UI, Gesture Bar Edge-to-Edge, Fullscreen & Orientation Modes', () {
    test('OmniColors includes statusBarColor & systemNavigationBarColor (55 semantic colors)', () {
      final light = OmniColors.fromSeed(
        primaryColor: Colors.blue,
        brightness: Brightness.light,
      );
      expect(light.statusBarColor, Colors.transparent);
      expect(light.systemNavigationBarColor, Colors.transparent);

      final custom = light.copyWith(
        statusBarColor: const Color(0xFF112233),
        systemNavigationBarColor: const Color(0xFF445566),
      );
      expect(custom.statusBarColor, const Color(0xFF112233));
      expect(custom.systemNavigationBarColor, const Color(0xFF445566));
      expect(custom == light, isFalse);

      final lerped = light.lerp(custom, 0.5);
      expect(
        lerped.systemNavigationBarColor,
        Color.lerp(Colors.transparent, const Color(0xFF445566), 0.5),
      );
    });

    testWidgets(
      'OmniTheme defaults to edgeToEdge with transparent gesture bar & contrastEnforced=false across screens and dark/light modes',
      (t) async {
        final modeCalls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (c) async {
              if (c.method == 'SystemChrome.setEnabledSystemUIMode') {
                modeCalls.add('${c.arguments}');
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              seedColor: Color(0xFF2563EB),
              mode: ThemeMode.light,
              persistMode: false,
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text('mode:${context.screenMode.name}'),
                        ElevatedButton(
                          onPressed: () => context.setThemeMode(ThemeMode.dark),
                          child: const Text('go-dark'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('mode:edgeToEdge'), findsOneWidget);
        expect(modeCalls.last, contains('SystemUiMode.edgeToEdge'));

        AnnotatedRegion<SystemUiOverlayStyle> rootRegion() =>
            t.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find
                  .byWidgetPredicate(
                    (w) => w is AnnotatedRegion<SystemUiOverlayStyle>,
                  )
                  .first,
            );

        var overlay = rootRegion().value;
        expect(overlay.statusBarColor, Colors.transparent);
        expect(overlay.systemNavigationBarColor, Colors.transparent);
        expect(overlay.systemNavigationBarContrastEnforced, isFalse);
        expect(overlay.systemStatusBarContrastEnforced, isFalse);
        expect(overlay.statusBarIconBrightness, Brightness.dark);
        expect(overlay.systemNavigationBarIconBrightness, Brightness.dark);

        // Switch theme to Dark mode -> icons automatically become Brightness.light.
        await t.tap(find.text('go-dark'));
        await t.pumpAndSettle();

        overlay = rootRegion().value;
        expect(overlay.statusBarIconBrightness, Brightness.light);
        expect(overlay.systemNavigationBarIconBrightness, Brightness.light);
        expect(overlay.systemNavigationBarContrastEnforced, isFalse);

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Separate OmniStatusBarStyle & OmniSystemNavigationBarStyle apply across AppBar, non-AppBar, runtime, Dark/Light, and plain custom-theme screens with zero per-screen code',
      (t) async {
        final overlayCalls = <Map<dynamic, dynamic>>[];
        final modeCalls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (c) async {
              if (c.method == 'SystemChrome.setSystemUIOverlayStyle') {
                overlayCalls.add(
                  Map<dynamic, dynamic>.from(c.arguments as Map),
                );
              } else if (c.method == 'SystemChrome.setEnabledSystemUIMode') {
                modeCalls.add('mode:${c.arguments}');
              } else if (c.method == 'SystemChrome.setEnabledSystemUIOverlays') {
                modeCalls.add('overlays:${c.arguments}');
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              seedColor: Color(0xFF2563EB),
              mode: ThemeMode.light,
              persistMode: false,
              screenMode: OmniScreenMode.normal,
              statusBar: OmniStatusBarStyle.solid(
                color: Color(0xFF0F172A),
                darkColor: Color(0xFF020617),
              ),
              systemNavigationBar: OmniSystemNavigationBarStyle.solid(
                color: Color(0xFF1E293B),
                darkColor: Color(0xFF090D16),
                dividerColor: Color(0xFF334155),
                darkDividerColor: Color(0xFF1E293B),
              ),
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Screen A (AppBar)')),
                    body: Column(
                      children: [
                        Text(
                          'bars:${context.colors.statusBarColor.toARGB32()}:${context.colors.systemNavigationBarColor.toARGB32()}',
                        ),
                        ElevatedButton(
                          onPressed: () => context.push<void>('/no-appbar'),
                          child: const Text('open-plain'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              context.push<void>('/custom-appbar-page'),
                          child: const Text('open-override'),
                        ),
                        ElevatedButton(
                          onPressed: () => context.setThemeMode(ThemeMode.dark),
                          child: const Text('toggle-dark'),
                        ),
                        ElevatedButton(
                          onPressed: () => context.setStatusBar(
                            const OmniStatusBarStyle.solid(
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                          child: const Text('runtime-status'),
                        ),
                        ElevatedButton(
                          onPressed: () => context.setSystemNavigationBar(
                            const OmniSystemNavigationBarStyle.solid(
                              color: Color(0xFF059669),
                            ),
                          ),
                          child: const Text('runtime-nav'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OmniPage(
                '/no-appbar',
                (_) => Builder(
                  builder: (context) => Scaffold(
                    // Notice: NO SystemChrome / AnnotatedRegion inside this screen!
                    body: Column(
                      children: [
                        Text(
                          'noappbar:${context.statusBar.resolveColor(Theme.of(context).brightness)?.toARGB32()}:${context.systemNavigationBar.resolveColor(Theme.of(context).brightness)?.toARGB32()}',
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('pop-plain'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OmniPage(
                '/custom-appbar-page',
                (_) => Builder(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Per-Route AppBar')),
                    body: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('pop-override'),
                    ),
                  ),
                ),
                statusBar: const OmniStatusBarStyle.solid(
                  color: Color(0xFFBE123C),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        // 1. Light mode global colors automatically applied on Screen A + SystemChrome + AppBarTheme:
        expect(
          find.text(
            'bars:${const Color(0xFF0F172A).toARGB32()}:${const Color(0xFF1E293B).toARGB32()}',
          ),
          findsOneWidget,
        );
        final firstOverlay = overlayCalls.last;
        expect(firstOverlay['statusBarColor'], const Color(0xFF0F172A).toARGB32());
        expect(
          firstOverlay['systemNavigationBarColor'],
          const Color(0xFF1E293B).toARGB32(),
        );
        expect(
          firstOverlay['systemNavigationBarDividerColor'],
          const Color(0xFF334155).toARGB32(),
        );
        expect(firstOverlay['systemNavigationBarContrastEnforced'], isFalse);

        final homeCtx = t.element(find.byType(Scaffold));
        expect(
          Theme.of(homeCtx).appBarTheme.systemOverlayStyle?.statusBarColor,
          const Color(0xFF0F172A),
        );

        // 2. Push plain screen WITHOUT AppBar & WITHOUT any per-screen chrome code -> still receives both!
        await t.tap(find.text('open-plain'));
        await t.pumpAndSettle();
        expect(
          find.text(
            'noappbar:${const Color(0xFF0F172A).toARGB32()}:${const Color(0xFF1E293B).toARGB32()}',
          ),
          findsOneWidget,
        );
        await t.tap(find.text('pop-plain'));
        await t.pumpAndSettle();

        // 3. Push OmniPage overriding ONLY statusBar on an AppBar screen -> AppBar gets 0xFFBE123C, nav bar stays 0xFF1E293B, and pop restores 0xFF0F172A!
        await t.tap(find.text('open-override'));
        await t.pumpAndSettle();
        final overrideScaffoldCtx = t.element(find.byType(Scaffold).last);
        expect(
          Theme.of(overrideScaffoldCtx)
              .appBarTheme
              .systemOverlayStyle
              ?.statusBarColor,
          const Color(0xFFBE123C),
        );
        expect(
          Theme.of(overrideScaffoldCtx)
              .appBarTheme
              .systemOverlayStyle
              ?.systemNavigationBarColor,
          const Color(0xFF1E293B),
        );
        expect(
          overlayCalls.last['statusBarColor'],
          const Color(0xFFBE123C).toARGB32(),
        );

        await t.tap(find.text('pop-override'));
        await t.pumpAndSettle();
        expect(
          overlayCalls.last['statusBarColor'],
          const Color(0xFF0F172A).toARGB32(),
        );

        // 4. Switch to Dark mode -> darkColor from both separate classes applies automatically!
        await t.tap(find.text('toggle-dark'));
        await t.pumpAndSettle();
        expect(
          overlayCalls.last['statusBarColor'],
          const Color(0xFF020617).toARGB32(),
        );
        expect(
          overlayCalls.last['systemNavigationBarColor'],
          const Color(0xFF090D16).toARGB32(),
        );
        expect(
          overlayCalls.last['systemNavigationBarDividerColor'],
          const Color(0xFF1E293B).toARGB32(),
        );

        // 5. Runtime updates via separate context.setStatusBar & context.setSystemNavigationBar sync AppBarTheme + SystemChrome!
        await t.tap(find.text('runtime-status'));
        await t.pumpAndSettle();
        expect(
          overlayCalls.last['statusBarColor'],
          const Color(0xFF7C3AED).toARGB32(),
        );
        await t.tap(find.text('runtime-nav'));
        await t.pumpAndSettle();
        expect(
          overlayCalls.last['systemNavigationBarColor'],
          const Color(0xFF059669).toARGB32(),
        );

        // 6. Plain OmniApp.material WITHOUT omniTheme also injects global bar styles into AppBar screens automatically!
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          OmniApp.material(
            theme: ThemeData.light(),
            statusBar: const OmniStatusBarStyle.solid(color: Color(0xFFEA580C)),
            systemNavigationBar: const OmniSystemNavigationBarStyle.solid(
              color: Color(0xFF0D9488),
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Plain App')),
                    body: Text(
                      'plain-appbar:${Theme.of(context).appBarTheme.systemOverlayStyle?.statusBarColor?.toARGB32()}:${Theme.of(context).appBarTheme.systemOverlayStyle?.systemNavigationBarColor?.toARGB32()}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text(
            'plain-appbar:${const Color(0xFFEA580C).toARGB32()}:${const Color(0xFF0D9488).toARGB32()}',
          ),
          findsOneWidget,
        );
        expect(
          overlayCalls.last['statusBarColor'],
          const Color(0xFFEA580C).toARGB32(),
        );
        expect(
          overlayCalls.last['systemNavigationBarColor'],
          const Color(0xFF0D9488).toARGB32(),
        );

        // Avoid unused variable warning on modeCalls.
        expect(modeCalls, isNotEmpty);

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'OmniFullscreenButton, context fullscreen helpers, and statusBarOnly/navigationBarOnly modes trigger SystemChrome',
      (t) async {
        final modeCalls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (c) async {
              if (c.method == 'SystemChrome.setEnabledSystemUIMode') {
                modeCalls.add('mode:${c.arguments}');
              } else if (c.method == 'SystemChrome.setEnabledSystemUIOverlays') {
                modeCalls.add('overlays:${c.arguments}');
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              seedColor: Colors.teal,
              persistMode: false,
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      actions: const [OmniFullscreenButton()],
                    ),
                    body: Column(
                      children: [
                        Text('full=${context.isFullscreen}'),
                        ElevatedButton(
                          onPressed: () => context.setScreenMode(
                            OmniScreenMode.statusBarOnly,
                          ),
                          child: const Text('status-only'),
                        ),
                        ElevatedButton(
                          onPressed: () => context.setScreenMode(
                            OmniScreenMode.navigationBarOnly,
                          ),
                          child: const Text('nav-only'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('full=false'), findsOneWidget);
        expect(modeCalls.last, 'mode:SystemUiMode.edgeToEdge');

        await t.tap(find.byType(OmniFullscreenButton));
        await t.pumpAndSettle();
        expect(find.text('full=true'), findsOneWidget);
        expect(modeCalls.last, 'mode:SystemUiMode.immersiveSticky');

        await t.tap(find.byType(OmniFullscreenButton));
        await t.pumpAndSettle();
        expect(find.text('full=false'), findsOneWidget);
        expect(modeCalls.last, 'mode:SystemUiMode.edgeToEdge');

        await t.tap(find.text('status-only'));
        await t.pumpAndSettle();
        expect(modeCalls.last, 'overlays:[SystemUiOverlay.top]');

        await t.tap(find.text('nav-only'));
        await t.pumpAndSettle();
        expect(modeCalls.last, 'overlays:[SystemUiOverlay.bottom]');

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'OmniOrientation.portraitOnMobile adapts from portrait on phone to 4-way auto-rotate on tablet',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.reset);

        final orientCalls = <List<dynamic>>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (c) async {
              if (c.method == 'SystemChrome.setPreferredOrientations') {
                orientCalls.add(List<dynamic>.from(c.arguments as List));
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await t.pumpWidget(
          OmniApp.material(
            orientation: OmniOrientation.portraitOnMobile,
            routes: [
              OmniPage('/', (_) => const Scaffold(body: Text('adaptive'))),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(orientCalls.last, ['DeviceOrientation.portraitUp']);

        // Expand window to tablet width (>= 600dp) -> automatically unlocks all 4 orientations!
        t.view.physicalSize = const Size(900, 800);
        await t.pumpAndSettle();

        expect(orientCalls.last, [
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.portraitDown',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ]);

        // Unmount -> cleanly resets preferred orientations to [].
        await t.pumpWidget(const SizedBox());
        expect(orientCalls.last, isEmpty);
      },
    );

    testWidgets(
      'Per-page OmniPage & OmniScreen overrides switch to fullscreen/landscape on push and restore Home on pop',
      (t) async {
        final modeCalls = <String>[];
        final orientCalls = <List<dynamic>>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (c) async {
              if (c.method == 'SystemChrome.setEnabledSystemUIMode') {
                modeCalls.add('${c.arguments}');
              } else if (c.method == 'SystemChrome.setPreferredOrientations') {
                orientCalls.add(List<dynamic>.from(c.arguments as List));
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              seedColor: Colors.indigo,
              persistMode: false,
            ),
            orientation: OmniOrientation.portrait,
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text('home:full=${context.isFullscreen}'),
                        ElevatedButton(
                          onPressed: () => context.push<void>('/player'),
                          child: const Text('open-player'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              context.pushTo<_VideoScreen, void>(),
                          child: const Text('open-video-screen'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OmniPage(
                '/player',
                (_) => Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text('player:full=${context.isFullscreen}'),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('pop-player'),
                        ),
                      ],
                    ),
                  ),
                ),
                screenMode: OmniScreenMode.fullscreen,
                orientation: OmniOrientation.landscape,
              ),
              OmniPage.screen(const _VideoScreen()),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('home:full=false'), findsOneWidget);
        expect(modeCalls.last, 'SystemUiMode.edgeToEdge');
        expect(orientCalls.last, ['DeviceOrientation.portraitUp']);

        // 1. Push OmniPage fullscreen + landscape route:
        await t.tap(find.text('open-player'));
        await t.pumpAndSettle();

        expect(find.text('player:full=true'), findsOneWidget);
        expect(modeCalls.last, 'SystemUiMode.immersiveSticky');
        expect(orientCalls.last, [
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ]);

        // 2. Pop back to Home -> restores edgeToEdge & portraitUp automatically!
        await t.tap(find.text('pop-player'));
        await t.pumpAndSettle();

        expect(find.text('home:full=false'), findsOneWidget);
        expect(modeCalls.last, 'SystemUiMode.edgeToEdge');
        expect(orientCalls.last, ['DeviceOrientation.portraitUp']);

        // 3. Push OmniStatelessWidget overriding `screenMode` & `orientation` getters:
        await t.tap(find.text('open-video-screen'));
        await t.pumpAndSettle();

        expect(find.text('video:full=true'), findsOneWidget);
        expect(modeCalls.last, 'SystemUiMode.leanBack');
        expect(orientCalls.last, [
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ]);

        // 4. Pop back -> restores again!
        await t.tap(find.text('close-video'));
        await t.pumpAndSettle();
        expect(modeCalls.last, 'SystemUiMode.edgeToEdge');
        expect(orientCalls.last, ['DeviceOrientation.portraitUp']);

        await t.pumpWidget(const SizedBox());
      },
    );
  });

  group('Dual Light & Dark Color Palette System', () {
    test(
      'OmniColorPalette & OmniColors.light/dark allow adding arbitrary Light and Dark colors without requiring all 55 fields',
      () {
        const lightPalette = OmniColorPalette(
          primaryColor: Color(0xFF1D4ED8),
          surfaceColor: Color(0xFFFFFBEB),
          cardColor: Color(0xFFFFFFFF),
          buttonColor: Color(0xFF2563EB),
          textColor: Color(0xFF0F172A),
          errorBackgroundColor: Color(0xFFFEE2E2),
          statusBarColor: Color(0xFFF8FAFC),
        );
        const darkPalette = OmniColorPalette(
          primaryColor: Color(0xFF60A5FA),
          secondaryColor: Color(0xFF38BDF8),
          surfaceColor: Color(0xFF090D16),
          cardColor: Color(0xFF111827),
          buttonColor: Color(0xFFF59E0B),
          buttonTextColor: Color(0xFF111827),
          textColor: Color(0xFFF9FAFB),
          errorBackgroundColor: Color(0xFF450A0A),
          systemNavigationBarColor: Color(0xFF0B1120),
        );

        expect(lightPalette == lightPalette.copyWith(), isTrue);
        expect(lightPalette == darkPalette, isFalse);

        final resolvedLight = OmniColors.light(
          primaryColor: const Color(0xFF059669),
          cardColor: const Color(0xFFECFDF5),
        );
        final resolvedDark = OmniColors.dark(
          primaryColor: const Color(0xFF34D399),
          cardColor: const Color(0xFF064E3B),
        );
        expect(resolvedLight.primaryColor, const Color(0xFF059669));
        expect(resolvedLight.cardColor, const Color(0xFFECFDF5));
        expect(resolvedDark.primaryColor, const Color(0xFF34D399));
        expect(resolvedDark.cardColor, const Color(0xFF064E3B));

        final theme = const OmniTheme(
          id: 'dual',
          name: 'Dual Brand',
          light: lightPalette,
          dark: darkPalette,
        );
        final lightColors = theme.resolveColors(Brightness.light);
        final darkColors = theme.resolveColors(Brightness.dark);

        expect(lightColors.primaryColor, const Color(0xFF1D4ED8));
        expect(lightColors.surfaceColor, const Color(0xFFFFFBEB));
        expect(lightColors.errorBackgroundColor, const Color(0xFFFEE2E2));
        expect(lightColors.statusBarColor, const Color(0xFFF8FAFC));

        expect(darkColors.primaryColor, const Color(0xFF60A5FA));
        expect(darkColors.secondaryColor, const Color(0xFF38BDF8));
        expect(darkColors.surfaceColor, const Color(0xFF090D16));
        expect(darkColors.cardColor, const Color(0xFF111827));
        expect(darkColors.buttonColor, const Color(0xFFF59E0B));
        expect(darkColors.buttonTextColor, const Color(0xFF111827));
        expect(darkColors.textColor, const Color(0xFFF9FAFB));
        expect(darkColors.errorBackgroundColor, const Color(0xFF450A0A));
        expect(darkColors.systemNavigationBarColor, const Color(0xFF0B1120));

        expect(theme.swatchColorFor(Brightness.light), const Color(0xFF1D4ED8));
        expect(theme.swatchColorFor(Brightness.dark), const Color(0xFF60A5FA));
      },
    );

    testWidgets(
      'Switching Light <-> Dark mode updates Light & Dark palette colors and Settings picker swatches live',
      (t) async {
        const customDual = OmniTheme(
          id: 'midnight_gold',
          name: 'Midnight Gold',
          light: OmniColorPalette(
            primaryColor: Color(0xFFB45309),
            secondaryColor: Color(0xFFD97706),
            surfaceColor: Color(0xFFFFFBEB),
            cardColor: Color(0xFFFFFFFF),
            appBarColor: Color(0xFFFEF3C7),
            textColor: Color(0xFF451A03),
          ),
          dark: OmniColorPalette(
            primaryColor: Color(0xFFFBBF24),
            secondaryColor: Color(0xFF38BDF8),
            surfaceColor: Color(0xFF090D16),
            cardColor: Color(0xFF111827),
            appBarColor: Color(0xFF1E293B),
            textColor: Color(0xFFFEF9C3),
          ),
          mode: ThemeMode.light,
          persistMode: false,
        );

        await t.pumpWidget(
          OmniApp.material(
            themes: [customDual, ...OmniTheme.presets],
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (context) {
                    final c = context.colors;
                    return Scaffold(
                      appBar: AppBar(title: const Text('Dual Palette')),
                      body: ListView(
                        children: [
                          Text(
                            'colors:${c.primaryColor.toARGB32()}:${c.surfaceColor.toARGB32()}:${c.appBarColor.toARGB32()}:${c.textColor.toARGB32()}',
                          ),
                          const OmniThemePanel(),
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

        expect(
          find.text(
            'colors:${const Color(0xFFB45309).toARGB32()}:${const Color(0xFFFFFBEB).toARGB32()}:${const Color(0xFFFEF3C7).toARGB32()}:${const Color(0xFF451A03).toARGB32()}',
          ),
          findsOneWidget,
        );

        // Toggle Dark mode via OmniThemeModeSwitch inside Settings panel:
        await t.tap(find.text('Dark'));
        await t.pumpAndSettle();

        expect(
          find.text(
            'colors:${const Color(0xFFFBBF24).toARGB32()}:${const Color(0xFF090D16).toARGB32()}:${const Color(0xFF1E293B).toARGB32()}:${const Color(0xFFFEF9C3).toARGB32()}',
          ),
          findsOneWidget,
        );

        // Also switch to a built-in preset (Ocean) -> distinct high-contrast dark primary!
        await t.tap(find.text('Ocean'));
        await t.pumpAndSettle();
        final ctx = t.element(find.byType(Scaffold));
        expect(
          ctx.colors.primaryColor,
          OmniTheme.ocean.dark!.primaryColor,
        );

        await t.pumpWidget(const SizedBox());
      },
    );
  });

  group('Animated Dark/Light Mode & Color Palette Transitions', () {
    testWidgets(
      'Switching Dark/Light mode and Color Palette triggers visual screen overlay animations and supports all animation modes',
      (t) async {
        SharedPreferences.setMockInitialValues({});

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              id: 'ocean',
              name: 'Ocean',
              seedColor: Color(0xFF2563EB),
              mode: ThemeMode.light,
              animation: OmniThemeAnimation(
                mode: OmniThemeAnimationMode.circularReveal,
                paletteMode: OmniThemeAnimationMode.diagonalSweep,
                duration: Duration(milliseconds: 300),
              ),
            ),
            themes: OmniTheme.presets,
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  appBar: AppBar(
                    title: const Text('Animated Theme'),
                    actions: const [
                      OmniThemeButton(),
                      OmniThemeModeButton(),
                    ],
                  ),
                  body: Column(
                    children: [
                      Builder(
                        builder: (c) => Text(
                          'state:${c.isDarkMode}:${c.activeThemeId}:${c.activeThemeAnimationMode.name}',
                        ),
                      ),
                      const Expanded(
                        child: SingleChildScrollView(
                          child: OmniThemePanel(
                            showStylePicker: true,
                            showAnimationPicker: true,
                          ),
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

        expect(find.text('state:false:ocean:circularReveal'), findsOneWidget);
        final overlayFinder = find.byKey(
          const ValueKey<String>('omni_theme_transition_overlay'),
        );
        expect(overlayFinder, findsNothing);

        // 1. Toggle Light -> Dark via button tap -> overlay runs mid-animation then disposes cleanly:
        await t.tap(find.byType(OmniThemeModeButton));
        await t.pump(); // Tap triggers deferred/immediate capture
        await t.pump(const Duration(milliseconds: 80));
        expect(
          overlayFinder,
          findsOneWidget,
          reason: 'Dark/Light toggle renders screen-over reveal overlay mid-animation',
        );
        await t.pumpAndSettle();
        expect(overlayFinder, findsNothing);
        expect(find.text('state:true:ocean:circularReveal'), findsOneWidget);

        // 2. Switch Color Palette -> ALSO triggers screen animation cleanly!
        await t.tap(find.text('Emerald'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 80));
        expect(
          overlayFinder,
          findsOneWidget,
          reason: 'Palette change animates visually across the screen too',
        );
        await t.pumpAndSettle();
        expect(overlayFinder, findsNothing);
        expect(find.text('state:true:emerald:circularReveal'), findsOneWidget);

        // 3. Verify all 16 animation modes, convenience constructors & pickers:
        expect(OmniThemeAnimationMode.values.length, 16);
        expect(
          const OmniThemeAnimation.verticalSplitShutter().mode,
          OmniThemeAnimationMode.verticalSplitShutter,
        );
        expect(
          const OmniThemeAnimation.blindsWipe().mode,
          OmniThemeAnimationMode.blindsWipe,
        );
        expect(
          const OmniThemeAnimation.clockSweep().mode,
          OmniThemeAnimationMode.clockSweep,
        );
        expect(
          const OmniThemeAnimation.roundedBoxReveal().mode,
          OmniThemeAnimationMode.roundedBoxReveal,
        );
        expect(
          const OmniThemeAnimation.zoomFade().mode,
          OmniThemeAnimationMode.zoomFade,
        );
        expect(
          const OmniThemeAnimation.slideReveal().mode,
          OmniThemeAnimationMode.slideReveal,
        );

        for (final mode in const [
          OmniThemeAnimationMode.circularShrink,
          OmniThemeAnimationMode.horizontalWipe,
          OmniThemeAnimationMode.verticalWipe,
          OmniThemeAnimationMode.splitShutter,
          OmniThemeAnimationMode.verticalSplitShutter,
          OmniThemeAnimationMode.blindsWipe,
          OmniThemeAnimationMode.clockSweep,
          OmniThemeAnimationMode.roundedBoxReveal,
          OmniThemeAnimationMode.diamondReveal,
          OmniThemeAnimationMode.crossfade,
          OmniThemeAnimationMode.zoomFade,
          OmniThemeAnimationMode.slideReveal,
        ]) {
          await t.ensureVisible(find.text(mode.label));
          await t.tap(find.text(mode.label));
          await t.pumpAndSettle();
          expect(
            t.element(find.byType(Scaffold)).activeThemeAnimationMode,
            mode,
          );
          await t.tap(find.byType(OmniThemeModeButton));
          await t.pump();
          await t.pump(const Duration(milliseconds: 60));
          expect(
            overlayFinder,
            findsOneWidget,
            reason: '${mode.name} should animate across screen',
          );
          await t.pumpAndSettle();
          expect(overlayFinder, findsNothing);
        }

        // 4. Pick Color Morph -> uses MaterialApp AnimatedTheme interpolation without overlay:
        await t.ensureVisible(find.text(OmniThemeAnimationMode.colorMorph.label));
        await t.tap(find.text(OmniThemeAnimationMode.colorMorph.label));
        await t.pumpAndSettle();
        final ctxMorph = t.element(find.byType(Scaffold));
        ctxMorph.setTheme('violet', origin: const Offset(100, 200));
        await t.pump();
        expect(overlayFinder, findsNothing);
        expect(
          t.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationDuration,
          const Duration(milliseconds: 300),
        );
        await t.pumpAndSettle();
        expect(ctxMorph.activeThemeId, 'violet');

        // 5. Pick None / Instant -> Duration.zero & no overlay:
        await t.ensureVisible(find.text(OmniThemeAnimationMode.none.label));
        await t.tap(find.text(OmniThemeAnimationMode.none.label));
        await t.pumpAndSettle();
        t.element(find.byType(Scaffold)).setTheme('rose');
        await t.pump();
        expect(overlayFinder, findsNothing);
        expect(
          t.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationDuration,
          Duration.zero,
        );
        await t.pumpAndSettle();

        // 6. Verify persisted animationMode survives cold restart WITHOUT startup wipe overlay:
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('omni_route.theme.default.animationMode'),
          'none',
        );
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              seedColor: Color(0xFF2563EB),
              mode: ThemeMode.light,
            ),
            themes: OmniTheme.presets,
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) => Text('restoredAnim:${c.activeThemeAnimationMode.name}'),
                ),
              ),
            ],
          ),
        );
        await t.pump();
        expect(overlayFinder, findsNothing);
        await t.pumpAndSettle();
        expect(find.text('restoredAnim:none'), findsOneWidget);

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'System brightness change animates screen, unchanged visual state skips flash, and raw MaterialApp themeAnimation works',
      (t) async {
        t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              seedColor: Colors.teal,
              mode: ThemeMode.system,
              persistMode: false,
              animation: OmniThemeAnimation.horizontalWipe(
                duration: Duration(milliseconds: 280),
              ),
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) => Scaffold(
                    body: Text('sysDark:${c.isDarkMode}:mode:${c.themeMode.name}'),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        final overlayFinder = find.byKey(
          const ValueKey<String>('omni_theme_transition_overlay'),
        );
        expect(find.text('sysDark:false:mode:system'), findsOneWidget);

        // OS brightness switches light -> dark while ThemeMode.system is active:
        t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        await t.pump();
        await t.pump(const Duration(milliseconds: 60));
        expect(
          overlayFinder,
          findsOneWidget,
          reason: 'OS brightness change while in ThemeMode.system animates smoothly',
        );
        await t.pumpAndSettle();
        expect(find.text('sysDark:true:mode:system'), findsOneWidget);

        // Switching System (currently dark) -> explicit ThemeMode.dark has zero visual delta -> no fake flash:
        t.element(find.byType(Scaffold)).setThemeMode(ThemeMode.dark);
        await t.pump();
        expect(overlayFinder, findsNothing);
        await t.pumpAndSettle();
        expect(find.text('sysDark:true:mode:dark'), findsOneWidget);

        // Reduced motion accessibility flag skips screen animation cleanly:
        t.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
        t.element(find.byType(Scaffold)).setThemeMode(ThemeMode.light);
        await t.pump();
        expect(overlayFinder, findsNothing);
        await t.pumpAndSettle();
        expect(find.text('sysDark:false:mode:light'), findsOneWidget);

        // Raw MaterialApp without omniTheme also supports OmniApp.material(themeAnimation: ...):
        t.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        var darkModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);
        addTearDown(darkModeNotifier.dispose);

        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          ValueListenableBuilder<ThemeMode>(
            valueListenable: darkModeNotifier,
            builder: (_, mode, _) => OmniApp.material(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: mode,
              themeAnimation: const OmniThemeAnimation.splitShutter(
                duration: Duration(milliseconds: 260),
              ),
              routes: [
                OmniPage(
                  '/',
                  (_) => Builder(
                    builder: (c) => Scaffold(body: Text('raw:${c.isDarkMode}')),
                  ),
                ),
              ],
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('raw:false'), findsOneWidget);

        darkModeNotifier.value = ThemeMode.dark;
        await t.pump();
        await t.pump(const Duration(milliseconds: 60));
        expect(overlayFinder, findsOneWidget);
        await t.pumpAndSettle();
        expect(find.text('raw:true'), findsOneWidget);

        await t.pumpWidget(const SizedBox());
      },
    );
  });
}
