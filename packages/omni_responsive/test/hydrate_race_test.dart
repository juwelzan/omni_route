import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

void main() {
  test('theme: a change made during hydrate is not overwritten', () async {
    SharedPreferences.setMockInitialValues({
      'omni_route.theme.default.mode': 'light',
      'omni_route.theme.default.themeId': 'ocean',
    });
    final c = OmniThemeController();
    addTearDown(c.dispose);
    final hydrating = c.hydrate();
    c.setMode(ThemeMode.dark, animate: false); // before storage answers
    await hydrating;
    expect(c.mode, ThemeMode.dark, reason: 'user choice wins');
    expect(c.themeId, 'ocean', reason: 'untouched fields still restore');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('omni_route.theme.default.mode'), 'dark');
  });

  test('theme: hydrate restores when nothing changed meanwhile', () async {
    SharedPreferences.setMockInitialValues({
      'omni_route.theme.default.mode': 'light',
    });
    final c = OmniThemeController();
    addTearDown(c.dispose);
    await c.hydrate();
    expect(c.mode, ThemeMode.light);
  });

  test('locale: a change made during hydrate is not overwritten', () async {
    SharedPreferences.setMockInitialValues({
      'omni_route.l10n.default.followSystem': false,
      'omni_route.l10n.default.language': 'en',
      'omni_route.l10n.default.country': 'US',
    });
    final c = OmniLocaleController();
    addTearDown(c.dispose);
    final hydrating = c.hydrate();
    c.setLanguage(OmniLanguage.bn);
    await hydrating;
    expect(c.value.language, OmniLanguage.bn);
  });
}
