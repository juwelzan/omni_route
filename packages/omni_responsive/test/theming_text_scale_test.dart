// Theme performance (cache, precache, startup), new theming features and the
// text size system, through OmniResponsiveApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Probe extends StatefulWidget {
  const Probe({super.key});
  static int inits = 0;
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  @override
  void initState() {
    super.initState();
    Probe.inits++;
  }

  @override
  Widget build(BuildContext context) => const Text('probe');
}

late BuildContext ctx;

Widget app({
  List<OmniTheme> themes = const [],
  OmniLocalization? l10n,
  OmniTextScaling textScaling = const OmniTextScaling(),
  double? maxTextScale,
  Widget body = const Probe(),
}) => OmniResponsiveApp(
  themes: themes,
  localization: l10n,
  textScaling: textScaling,
  maxTextScale: maxTextScale,
  builder: (context, ui) => MaterialApp(
    theme: ui.theme,
    darkTheme: ui.darkTheme,
    themeMode: ui.themeMode,
    themeAnimationDuration: ui.themeAnimationDuration,
    locale: ui.locale,
    localizationsDelegates: ui.localizationsDelegates,
    supportedLocales: ui.supportedLocales,
    builder: ui.builder,
    home: Scaffold(
      body: Builder(
        builder: (c) {
          ctx = c;
          return body;
        },
      ),
    ),
  ),
);

double scaleOf(BuildContext c) => MediaQuery.textScalerOf(c).scale(10) / 10;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OmniText.reset();
    Probe.inits = 0;
  });
  tearDown(() => OmniText.setLanguage(OmniLanguage.en, persist: false));

  group('no remounts', () {
    testWidgets('resize across a breakpoint keeps state', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(900, 800);
      addTearDown(t.view.reset);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(1200, 800); // tier scale 1.0 → 1.05
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(900, 800);
      await t.pumpAndSettle();
      expect(Probe.inits, 1);
    });

    testWidgets('language switch with a locale font keeps state and the font '
        'reaches Material screens', (t) async {
      await t.pumpWidget(
        app(
          l10n: const OmniLocalization(
            supportedLanguages: [OmniLanguage.en, OmniLanguage.bn],
            localeFonts: {'bn': 'NotoSansBengali'},
          ),
        ),
      );
      await t.pumpAndSettle();
      OmniText.setLanguage(OmniLanguage.bn, persist: false);
      await t.pumpAndSettle();
      expect(Probe.inits, 1);
      expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamily, 'NotoSansBengali');
      OmniText.setLanguage(OmniLanguage.en, persist: false);
      await t.pumpAndSettle();
      expect(Probe.inits, 1);
      expect(
        Theme.of(ctx).textTheme.bodyMedium!.fontFamily,
        isNot('NotoSansBengali'),
      );
    });

    testWidgets('text size changes keep state', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      for (final s in OmniTextSize.values) {
        ctx.setTextSize(s);
        await t.pump();
      }
      ctx.setTextSize(OmniTextSize.medium);
      await t.pump();
      expect(Probe.inits, 1);
    });
  });

  group('startup', () {
    testWidgets('after preload, the first frame already has the saved theme, '
        'language and text size', (t) async {
      SharedPreferences.setMockInitialValues({
        'omni_route.theme.default.mode': 'dark',
        'omni_route.l10n.default.followSystem': false,
        'omni_route.l10n.default.language': 'bn',
        'omni_route.l10n.default.country': 'BD',
        'omni_route.textScale.default.factor': 1.15,
      });
      await OmniPreferences.preload();
      await t.pumpWidget(
        app(
          themes: OmniTheme.presets,
          l10n: const OmniLocalization(
            supportedLanguages: [OmniLanguage.en, OmniLanguage.bn],
          ),
          body: Builder(
            builder: (c) => Text(c.l10n(en: 'Hello', bn: 'হ্যালো')),
          ),
        ),
      ); // one frame, no settle
      expect(Theme.of(ctx).brightness, Brightness.dark);
      expect(find.text('হ্যালো'), findsOneWidget);
      expect(OmniTextScale.size, OmniTextSize.large);
      expect(scaleOf(ctx), closeTo(1.15, 1e-6));
    });

    testWidgets('without preload the saved theme is applied once storage '
        'answers', (t) async {
      SharedPreferences.setMockInitialValues({
        'omni_route.theme.default.mode': 'dark',
      });
      await t.pumpWidget(app(themes: OmniTheme.presets));
      await t.pump();
      expect(Theme.of(ctx).brightness, Brightness.dark);
    });
  });

  group('text size', () {
    testWidgets('scales every Text, is saved, and combines with the '
        'language factor and the max clamp', (t) async {
      await t.pumpWidget(
        app(
          l10n: const OmniLocalization(
            supportedLanguages: [OmniLanguage.en, OmniLanguage.bn],
            languageTextScale: {'bn': 1.1},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(scaleOf(ctx), 1.0);

      ctx.setTextSize(OmniTextSize.large);
      await t.pump();
      expect(scaleOf(ctx), closeTo(1.15, 1e-6));
      expect(ctx.textSize, OmniTextSize.large);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('omni_route.textScale.default.factor'), 1.15);

      OmniText.setLanguage(OmniLanguage.bn, persist: false);
      await t.pump();
      expect(scaleOf(ctx), closeTo(1.15 * 1.1, 1e-6));

      OmniTextScale.setFactor(5); // clamped to maxFactor 1.6
      await t.pump();
      expect(OmniTextScale.factor, 1.6);
    });

    testWidgets('maxTextScale still caps the result', (t) async {
      await t.pumpWidget(app(maxTextScale: 1.2));
      await t.pumpAndSettle();
      ctx.setTextSize(OmniTextSize.extraLarge);
      await t.pump();
      expect(scaleOf(ctx), closeTo(1.2, 1e-6));
    });

    testWidgets('OS accessibility scale multiplies with the user size', (
      t,
    ) async {
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      ctx.setTextSize(OmniTextSize.small);
      await t.pump();
      expect(scaleOf(ctx), closeTo(2 * 0.85, 1e-6));
    });

    testWidgets('picker shows localized names and changes the size', (t) async {
      await t.pumpWidget(app(body: const OmniTextSizePicker(showLabels: true)));
      await t.pumpAndSettle();
      expect(find.text('Large'), findsOneWidget);
      await t.tap(find.text('Large'));
      await t.pump();
      expect(OmniTextScale.size, OmniTextSize.large);
      OmniText.setLanguage(OmniLanguage.bn, persist: false);
      await t.pump();
      expect(find.text('বড়'), findsOneWidget);
    });

    test('custom factors have no preset', () {
      expect(OmniTextSize.fromFactor(1.15), OmniTextSize.large);
      expect(OmniTextSize.fromFactor(1.07), isNull);
    });
  });

  group('theme performance', () {
    testWidgets('switching back to a theme and resizing back reuse built '
        'themes', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(400, 800);
      addTearDown(t.view.reset);
      await t.pumpWidget(app(themes: OmniTheme.presets));
      await t.pumpAndSettle();
      final a = OmniTheme.presets[0].id;
      final b = OmniTheme.presets[1].id;
      ctx.setTheme(b, animate: false);
      await t.pumpAndSettle();
      final afterB = OmniTheme.debugResolveCount;
      ctx.setTheme(a, animate: false);
      await t.pumpAndSettle();
      ctx.setTheme(b, animate: false);
      await t.pumpAndSettle();
      expect(OmniTheme.debugResolveCount, afterB, reason: 'cache hits');

      t.view.physicalSize = const Size(1300, 800);
      await t.pumpAndSettle();
      final afterDesktop = OmniTheme.debugResolveCount;
      t.view.physicalSize = const Size(400, 800);
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(1300, 800);
      await t.pumpAndSettle();
      expect(OmniTheme.debugResolveCount, afterDesktop, reason: 'per-tier');
    });

    testWidgets('a switch builds only the brightness on screen; the other '
        'one is built after the frame', (t) async {
      await t.pumpWidget(app(themes: OmniTheme.presets));
      await t.pumpAndSettle();
      final before = OmniTheme.debugResolveCount;
      ctx.setTheme(OmniTheme.presets[2].id, animate: false);
      await t.pump();
      expect(OmniTheme.debugResolveCount - before, 1);
      await t.pumpAndSettle();
      expect(OmniTheme.debugResolveCount - before, 2);
    });

    testWidgets('the theme picker precaches its themes', (t) async {
      await t.pumpWidget(
        app(
          themes: OmniTheme.presets,
          body: const SingleChildScrollView(child: OmniThemePicker()),
        ),
      );
      await t.pumpAndSettle();
      var before = OmniTheme.debugResolveCount;
      for (final th in OmniTheme.presets.skip(1).take(4)) {
        ctx.setTheme(th.id, animate: false);
        await t.pump();
        // The tap frame itself built nothing: the theme was precached.
        expect(OmniTheme.debugResolveCount, before, reason: th.id);
        // Its dark variant is built in later frames, off the tap frame.
        await t.pumpAndSettle();
        expect(OmniTheme.debugResolveCount, before + 1, reason: th.id);
        before = OmniTheme.debugResolveCount;
      }
    });

    testWidgets('high contrast OS setting uses a high-contrast palette', (
      t,
    ) async {
      await t.pumpWidget(app(themes: OmniTheme.presets));
      await t.pumpAndSettle();
      final normal = Theme.of(ctx).colorScheme;
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await t.pumpAndSettle();
      expect(Theme.of(ctx).colorScheme, isNot(normal));
    });
  });

  group('theming features', () {
    test('fromSeed variants give different palettes', () {
      const seed = Color(0xFF0EA5E9);
      final tonal = OmniTheme.fromSeed(seed).resolveColors(Brightness.light);
      final vibrant = OmniTheme.fromSeed(
        seed,
        variant: DynamicSchemeVariant.monochrome,
      ).resolveColors(Brightness.light);
      expect(tonal.secondaryColor, isNot(vibrant.secondaryColor));
    });

    test('resolveColors is cached per theme', () {
      final theme = OmniTheme.fromSeed(const Color(0xFF7C3AED));
      expect(
        identical(
          theme.resolveColors(Brightness.dark),
          theme.resolveColors(Brightness.dark),
        ),
        isTrue,
      );
    });

    test('JSON round trip', () {
      final theme = OmniTheme.fromSeed(
        const Color(0xFF0EA5E9),
        id: 'brand',
        name: 'Brand',
        variant: DynamicSchemeVariant.vibrant,
        style: OmniThemeStyle.values.last,
        borderRadius: 14,
        fontFamily: 'Inter',
      ).copyWith(cardColor: const Color(0xFF101820), contrastLevel: 0.5);
      final back = OmniTheme.fromJson(theme.toJson());
      expect(back, theme);
      expect(() => OmniTheme.fromJson({'seedColor': 1}), throwsFormatException);
      expect(
        OmniTheme.fromJson({'id': 'x', 'seedColor': '#FF0000'}).seedColor,
        const Color(0xFFFF0000),
      );
    });

    test('preset button labels are readable (≥ 3:1)', () {
      double ratio(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final p in OmniTheme.presets) {
        for (final b in Brightness.values) {
          final c = p.resolveColors(b);
          expect(
            ratio(c.buttonTextColor, c.buttonColor),
            greaterThanOrEqualTo(3),
            reason: '${p.id} ${b.name}',
          );
        }
      }
    });

    testWidgets('runtime themes appear, switch and survive a restart', (
      t,
    ) async {
      await t.pumpWidget(app(themes: OmniTheme.presets));
      await t.pumpAndSettle();
      final mine = OmniTheme.fromSeed(const Color(0xFFE11D48), id: 'mine');
      ctx.themeController.addTheme(mine);
      await t.pump();
      expect(ctx.availableThemes.map((e) => e.id), contains('mine'));
      ctx.setTheme('mine', animate: false);
      await t.pumpAndSettle();
      expect(ctx.activeThemeId, 'mine');

      // "Restart": new app instance reading the saved settings.
      await t.pumpWidget(const SizedBox());
      OmniPreferences.debugReset();
      await OmniPreferences.preload();
      await t.pumpWidget(app(themes: OmniTheme.presets));
      expect(ctx.activeThemeId, 'mine');
      expect(
        Theme.of(ctx).colorScheme.primary,
        mine.resolveColors(Theme.of(ctx).brightness).primaryColor,
      );
    });

    testWidgets('OmniThemeOverride themes a subtree and is cached', (t) async {
      late BuildContext inner;
      Widget overridden() => OmniThemeOverride(
        theme: OmniTheme.presets.last,
        child: Builder(
          builder: (c) {
            inner = c;
            return const SizedBox();
          },
        ),
      );
      await t.pumpWidget(
        app(
          themes: [OmniTheme.presets.first],
          body: Column(children: [overridden(), overridden()]),
        ),
      );
      await t.pumpAndSettle();
      expect(
        Theme.of(inner).colorScheme.primary,
        isNot(Theme.of(ctx).colorScheme.primary),
      );
      expect(inner.ui.colors.primaryColor, isNot(ctx.ui.colors.primaryColor));
      final count = OmniTheme.debugResolveCount;
      await t.pumpWidget(
        app(
          themes: [OmniTheme.presets.first],
          body: Column(children: [overridden(), overridden(), overridden()]),
        ),
      );
      expect(OmniTheme.debugResolveCount, count);
    });

    testWidgets('theme panel labels follow the language', (t) async {
      await t.pumpWidget(
        app(
          themes: OmniTheme.presets,
          body: const SingleChildScrollView(child: OmniThemePanel()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      OmniText.setLanguage(OmniLanguage.bn, persist: false);
      await t.pumpAndSettle();
      expect(find.text('লেখার আকার'), findsOneWidget);
      expect(find.text('ডার্ক'), findsOneWidget);
    });
  });
}
