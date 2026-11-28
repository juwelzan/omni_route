import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _items = [
  OmniBottomNavigationItem(icon: Icon(Icons.home_outlined), label: 'A'),
  OmniBottomNavigationItem(icon: Icon(Icons.person_outline), label: 'B'),
];

Widget _app({
  required OmniBottomNavigationStyle style,
  bool? sync = true,
  Color background = const Color(0xFF101828),
  OmniBottomNavigationController? controller,
  OmniBottomNavigationStyleData? themeData,
}) => MaterialApp(
  theme: ThemeData(extensions: [?themeData]),
  home: AnnotatedRegion<SystemUiOverlayStyle>(
    // The page's own style (what OmniSystemUi would set).
    value: const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFFFF0000),
    ),
    child: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: OmniBottomNavigationBar(
        style: style,
        controller: controller,
        syncSystemNavigationBar: sync,
        backgroundColor: background,
        items: _items,
      ),
    ),
  ),
);

Color? get _navColor => SystemChrome.latestStyle?.systemNavigationBarColor;

void main() {
  testWidgets('docked bar colours the system bar with contrasting icons', (
    t,
  ) async {
    await t.pumpWidget(_app(style: OmniBottomNavigationStyle.materialPill));
    await t.pumpAndSettle();
    expect(_navColor, const Color(0xFF101828));
    expect(
      SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
      Brightness.light,
    );

    await t.pumpWidget(
      _app(
        style: OmniBottomNavigationStyle.materialPill,
        background: const Color(0xFFF8FAFC),
      ),
    );
    await t.pumpAndSettle();
    expect(
      SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
  });

  testWidgets('floating bar keeps the system bar transparent', (t) async {
    await t.pumpWidget(_app(style: OmniBottomNavigationStyle.floating));
    await t.pumpAndSettle();
    expect(_navColor, const Color(0x00000000));
  });

  testWidgets('off by default: the page style applies', (t) async {
    await t.pumpWidget(
      _app(style: OmniBottomNavigationStyle.materialPill, sync: null),
    );
    await t.pumpAndSettle();
    expect(_navColor, const Color(0xFFFF0000));
  });

  testWidgets('hidden bar hands the system bar back to the page', (t) async {
    final controller = OmniBottomNavigationController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _app(
        style: OmniBottomNavigationStyle.materialPill,
        controller: controller,
      ),
    );
    await t.pumpAndSettle();
    expect(_navColor, const Color(0xFF101828));
    controller.hide();
    await t.pumpAndSettle();
    expect(_navColor, const Color(0xFFFF0000));
    controller.show();
    await t.pumpAndSettle();
    expect(_navColor, const Color(0xFF101828));
  });

  testWidgets('theme extension can turn it on', (t) async {
    await t.pumpWidget(
      _app(
        style: OmniBottomNavigationStyle.cupertino,
        sync: null,
        themeData: const OmniBottomNavigationStyleData(
          syncSystemNavigationBar: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(_navColor, const Color(0xFF101828));
  });
}
