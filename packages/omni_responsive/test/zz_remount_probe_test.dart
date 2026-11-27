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
  Widget build(BuildContext context) => const SizedBox();
}

Widget app({OmniLocalization? l10n}) => OmniResponsiveApp(
  localization: l10n,
  builder: (context, ui) => MaterialApp(
    locale: ui.locale,
    localizationsDelegates: ui.localizationsDelegates,
    supportedLocales: ui.supportedLocales,
    builder: ui.builder,
    home: const Scaffold(body: Probe()),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Probe.inits = 0;
  });

  testWidgets('resize tablet -> desktop keeps app state', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(900, 800);
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(1200, 800);
    await t.pumpAndSettle();
    expect(Probe.inits, 1);
  });

  testWidgets('language switch with locale font keeps app state', (t) async {
    addTearDown(() => OmniText.setLanguage(OmniLanguage.en, persist: false));
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
    final style = DefaultTextStyle.of(t.element(find.byType(Probe))).style;
    expect(style.fontFamily, 'NotoSansBengali', reason: 'font reaches screens');
  });
}
