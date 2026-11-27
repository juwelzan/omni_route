// omni_responsive on its own: no omni_route, no OmniApp — a plain
// MaterialApp hosted by OmniResponsiveApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app({
  required WidgetBuilder home,
  List<OmniTheme> themes = const [],
  OmniLocalization? localization,
}) => OmniResponsiveApp(
  themes: themes,
  localization: localization,
  builder: (context, ui) => MaterialApp(
    theme: ui.theme,
    darkTheme: ui.darkTheme,
    themeMode: ui.themeMode,
    themeAnimationDuration: ui.themeAnimationDuration,
    themeAnimationCurve: ui.themeAnimationCurve,
    locale: ui.locale,
    localizationsDelegates: ui.localizationsDelegates,
    supportedLocales: ui.supportedLocales,
    builder: ui.builder,
    home: Builder(builder: home),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('breakpoints resolve from the window size', (t) async {
    late OmniResponsiveData data;
    Future<void> at(Size size) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = size;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          home: (context) {
            data = context.responsive;
            return const Scaffold();
          },
        ),
      );
      await t.pumpAndSettle();
    }

    await at(const Size(390, 844));
    expect(data.device, OmniDeviceType.mobile);
    await at(const Size(768, 1024));
    expect(data.device, OmniDeviceType.tablet);
    await at(const Size(1280, 800));
    expect(data.device, OmniDeviceType.desktop);
    await at(const Size(1680, 1050));
    expect(data.device, OmniDeviceType.largeDesktop);
  });

  testWidgets('responsive widgets switch layout per device', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _app(
        home: (_) => const Scaffold(
          body: OmniResponsiveLayout(
            mobile: Text('phone'),
            desktop: Text('desk'),
          ),
        ),
      ),
    );
    expect(find.text('phone'), findsOneWidget);
    t.view.physicalSize = const Size(1400, 900);
    await t.pumpAndSettle();
    expect(find.text('desk'), findsOneWidget);
  });

  testWidgets('themes reach MaterialApp and switch at runtime', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      _app(
        themes: OmniTheme.presets,
        home: (context) {
          ctx = context;
          return const Scaffold();
        },
      ),
    );
    await t.pumpAndSettle();
    final first = OmniTheme.presets.first.id;
    expect(ctx.activeThemeId, first);
    final before = Theme.of(ctx).colorScheme.primary;

    final other = OmniTheme.presets.firstWhere((p) => p.id != first).id;
    ctx.setTheme(other, animate: false);
    await t.pumpAndSettle();
    expect(ctx.activeThemeId, other);
    expect(Theme.of(ctx).colorScheme.primary, isNot(before));

    ctx.themeController.setMode(ThemeMode.dark, animate: false);
    await t.pumpAndSettle();
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });

  testWidgets('animated theme switch completes and frees its snapshot', (
    t,
  ) async {
    late BuildContext ctx;
    await t.pumpWidget(
      _app(
        themes: OmniTheme.presets,
        home: (context) {
          ctx = context;
          return const Scaffold(body: Center(child: Text('x')));
        },
      ),
    );
    await t.pumpAndSettle();
    ctx.themeController.setMode(ThemeMode.dark);
    await t.pumpAndSettle();
    expect(Theme.of(ctx).brightness, Brightness.dark);
    // The leak tracker (flutter_test_config.dart) fails the test if the
    // transition's snapshot image or controller were not disposed.
  });

  testWidgets('language changes rebuild localized text', (t) async {
    addTearDown(() => OmniText.setLanguage(OmniLanguage.en, persist: false));
    await t.pumpWidget(
      _app(
        localization: const OmniLocalization(
          supportedLanguages: [OmniLanguage.en, OmniLanguage.bn],
        ),
        home: (context) => Scaffold(
          body: Text(context.l10n(en: 'Hello', bn: 'হ্যালো')),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
    OmniText.setLanguage(OmniLanguage.bn, persist: false);
    await t.pumpAndSettle();
    expect(find.text('হ্যালো'), findsOneWidget);
  });

  testWidgets('text field clear button follows the text', (t) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _app(
        home: (_) => Scaffold(
          body: OmniTextField(
            label: 'Name',
            controller: controller,
            showClearButton: true,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    await t.enterText(find.byType(TextField), 'abc');
    await t.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    // Moving the cursor alone must not change anything visible.
    controller.selection = const TextSelection.collapsed(offset: 1);
    await t.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await t.tap(find.byIcon(Icons.close_rounded));
    await t.pump();
    expect(controller.text, isEmpty);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('number field rejects invalid input', (t) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _app(
        home: (_) => Scaffold(
          body: OmniNumberField(
            controller: controller,
            allowDecimal: true,
            decimalRange: 2,
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), '12.5');
    expect(controller.text, '12.5');
    await t.enterText(find.byType(TextField), '12.555');
    expect(controller.text, '12.5', reason: 'max 2 decimals');
    await t.enterText(find.byType(TextField), '-3');
    expect(controller.text, '12.5', reason: 'negatives not allowed');
  });

  test('validators', () {
    expect(OmniValidators.email('a@b.co'), isNull);
    expect(OmniValidators.email('nope'), isNotNull);
  });

  testWidgets('system UI scope is available below the host', (t) async {
    OmniSystemUiScope? scope;
    await t.pumpWidget(
      _app(
        home: (context) {
          scope = context
              .dependOnInheritedWidgetOfExactType<OmniSystemUiScope>();
          return const Scaffold();
        },
      ),
    );
    expect(scope, isNotNull);
    expect(scope!.effectiveScreenMode, OmniScreenMode.edgeToEdge);
  });

  testWidgets('OTP resend countdown shows mm:ss and ticks on its own', (
    t,
  ) async {
    var resent = 0;
    await t.pumpWidget(
      _app(
        home: (_) => Scaffold(
          body: OmniOtpField(
            length: 4,
            resendDuration: const Duration(seconds: 125),
            onResend: () => resent++,
          ),
        ),
      ),
    );
    expect(find.text('Resend code in 02:05'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Resend code in 02:04'), findsOneWidget);
    await t.pump(const Duration(seconds: 124));
    expect(find.textContaining('Resend code in'), findsNothing);
    await t.tap(find.byIcon(Icons.refresh_rounded));
    await t.pump();
    expect(resent, 1);
    expect(find.text('Resend code in 02:05'), findsOneWidget);
    // Unmount mid-countdown: the timer and notifier must be released.
    await t.pumpWidget(const SizedBox());
  });
}
