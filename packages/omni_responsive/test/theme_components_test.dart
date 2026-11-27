import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

ThemeData _resolve(OmniTheme theme, {Brightness b = Brightness.light}) =>
    theme.resolve(
      device: OmniDeviceType.mobile,
      tokens: OmniResponsiveTokens.mobile,
      brightness: b,
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('new component colors reach their Material themes', () {
    const fab = Color(0xFFE11D48), menu = Color(0xFFFFF7ED);
    const drawer = Color(0xFFF0FDF4), tab = Color(0xFF7C3AED);
    const cursor = Color(0xFF0891B2), progress = Color(0xFF16A34A);
    const dialog = Color(0xFFFEFCE8), sheet = Color(0xFFEFF6FF);
    final t = _resolve(
      const OmniTheme(
        fabColor: fab,
        menuColor: menu,
        drawerColor: drawer,
        tabSelectedColor: tab,
        cursorColor: cursor,
        progressColor: progress,
        dialogColor: dialog,
        bottomSheetColor: sheet,
      ),
    );
    expect(t.floatingActionButtonTheme.backgroundColor, fab);
    expect(
      t.floatingActionButtonTheme.foregroundColor,
      Colors.white,
      reason: 'readable text on the custom FAB color',
    );
    expect(t.popupMenuTheme.color, menu);
    expect(t.menuTheme.style!.backgroundColor!.resolve({}), menu);
    expect(t.dropdownMenuTheme.menuStyle!.backgroundColor!.resolve({}), menu);
    expect(t.drawerTheme.backgroundColor, drawer);
    expect(t.navigationDrawerTheme.backgroundColor, drawer);
    expect(t.tabBarTheme.labelColor, tab);
    expect(t.tabBarTheme.indicatorColor, tab);
    expect(t.textSelectionTheme.cursorColor, cursor);
    expect(t.textSelectionTheme.selectionHandleColor, cursor);
    expect(t.progressIndicatorTheme.color, progress);
    expect(t.sliderTheme.activeTrackColor, progress);
    expect(t.dialogTheme.backgroundColor, dialog);
    expect(t.datePickerTheme.backgroundColor, dialog);
    expect(t.bottomSheetTheme.backgroundColor, sheet);
  });

  test('defaults of the new colors follow the existing ones', () {
    const card = Color(0xFFFAF5EF), border = Color(0xFFD6C7B0);
    final c = const OmniTheme(
      cardColor: card,
      borderColor: border,
      buttonColor: Color(0xFF0F766E),
    ).resolveColors(Brightness.light);
    expect(c.dialogColor, card);
    expect(c.menuColor, card);
    expect(c.drawerColor, card);
    expect(c.bottomSheetColor, card);
    expect(c.inputBorderColor, border);
    expect(c.outlineButtonBorderColor, border);
    expect(c.fabColor, c.buttonColor);
    expect(c.fabTextColor, c.buttonTextColor);
    expect(c.cursorColor, c.focusedBorderColor);
    expect(c.tabSelectedColor, c.primaryColor);
    expect(c.tabUnselectedColor, c.secondaryTextColor);
  });

  test('custom surfaces drive the Material 3 surface levels', () {
    const card = Color(0xFFFFFBF5), section = Color(0xFFF5EBDD);
    final scheme = _resolve(
      const OmniTheme(cardColor: card, secondaryBackgroundColor: section),
    ).colorScheme;
    expect(scheme.surfaceContainerLowest, card);
    expect(scheme.surfaceContainerHigh, section);
    expect(scheme.surface, card);
  });

  test('switch thumb and checkbox tick stay readable on a light accent', () {
    const yellow = Color(0xFFFDE047);
    final t = _resolve(const OmniTheme(switchActiveColor: yellow));
    final thumb = t.switchTheme.thumbColor!.resolve({WidgetState.selected})!;
    expect(_contrast(thumb, yellow), greaterThanOrEqualTo(4.5));
    final tick = t.checkboxTheme.checkColor!.resolve({WidgetState.selected})!;
    expect(_contrast(tick, yellow), greaterThanOrEqualTo(4.5));
    expect(
      t.switchTheme.trackOutlineColor!.resolve({WidgetState.selected}),
      Colors.transparent,
    );
    expect(
      t.checkboxTheme.side!.color,
      isNot(yellow),
      reason: 'unchecked box keeps the neutral border',
    );
  });

  test('floating label is highlighted only while focused or invalid', () {
    final t = _resolve(const OmniTheme());
    final c = t.extension<OmniColors>()!;
    final style = t.inputDecorationTheme.floatingLabelStyle!;
    Color? colorFor(Set<WidgetState> s) =>
        WidgetStateProperty.resolveAs<TextStyle?>(style, s)!.color;
    expect(colorFor({}), c.secondaryTextColor);
    expect(colorFor({WidgetState.focused}), c.focusedBorderColor);
    expect(colorFor({WidgetState.error}), c.errorColor);
  });

  test('button shape: pill, square and a radius of its own', () {
    OutlinedBorder? filledShape(OmniTheme theme) =>
        _resolve(theme).filledButtonTheme.style!.shape!.resolve({});

    expect(
      filledShape(const OmniTheme(buttonShape: OmniButtonShape.pill)),
      isA<StadiumBorder>(),
    );
    expect(
      filledShape(const OmniTheme(buttonShape: OmniButtonShape.square)),
      const RoundedRectangleBorder(),
    );
    expect(
      filledShape(const OmniTheme(style: OmniThemeStyle.pill)),
      isA<StadiumBorder>(),
      reason: 'the pill style brings pill buttons',
    );

    final t = _resolve(const OmniTheme(borderRadius: 8, buttonRadius: 20));
    final shape =
        t.elevatedButtonTheme.style!.shape!.resolve({})!
            as RoundedRectangleBorder;
    expect(shape.borderRadius, const BorderRadius.all(Radius.circular(20)));
    final field = t.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
    expect(
      field.borderRadius,
      const BorderRadius.all(Radius.circular(8)),
      reason: 'fields keep the theme radius',
    );
    expect(
      t.floatingActionButtonTheme.shape,
      shape,
      reason: 'FAB and segmented buttons share the button shape',
    );
  });

  test('snackbar action is readable in both modes', () {
    for (final b in Brightness.values) {
      final t = _resolve(OmniTheme.sunset, b: b);
      final bg = t.snackBarTheme.backgroundColor!;
      expect(
        _contrast(t.snackBarTheme.actionTextColor!, bg),
        greaterThanOrEqualTo(3),
        reason: b.name,
      );
    }
  });

  test('new colors survive JSON, copyWith, lerp and palettes', () {
    const theme = OmniTheme(
      id: 'brand',
      fabColor: Color(0xFF123456),
      navIndicatorColor: Color(0x33123456),
      buttonShape: OmniButtonShape.pill,
      buttonRadius: 14,
    );
    final back = OmniTheme.fromJson(theme.toJson());
    expect(back, theme);

    final a = OmniColors.lightDefault;
    final b = a.copyWith(scrollbarColor: const Color(0xFF000000));
    expect(b == a, isFalse);
    expect(a.lerp(b, 1).scrollbarColor, const Color(0xFF000000));

    final darkMenu = const OmniTheme(
      dark: OmniColorPalette(menuColor: Color(0xFF101010)),
    ).resolveColors(Brightness.dark).menuColor;
    expect(darkMenu, const Color(0xFF101010));
  });

  testWidgets('real widgets paint with the theme', (t) async {
    const fab = Color(0xFFE11D48);
    await t.pumpWidget(
      MaterialApp(
        theme: _resolve(
          const OmniTheme(fabColor: fab, buttonShape: OmniButtonShape.pill),
        ),
        home: Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Icons.add),
          ),
          body: FilledButton(onPressed: () {}, child: const Text('Go')),
        ),
      ),
    );
    final fabMaterial = t.widget<Material>(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byType(Material),
      ),
    );
    expect(fabMaterial.color, fab);
    final buttonMaterial = t.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    expect(buttonMaterial.shape, isA<StadiumBorder>());
  });
}
