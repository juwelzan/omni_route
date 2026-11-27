# omni_responsive

Responsive layout, adaptive widgets, themes with animated transitions, form
fields, system UI control and localization for Flutter.

It's built into `omni_route`'s `OmniApp`. Use this package directly when your
app routes with something else (go_router, auto_route, plain `Navigator`).

## Install

```yaml
dependencies:
  omni_responsive:
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_responsive
      ref: omni_responsive-v0.1.0
```

Its only dependency besides Flutter is `shared_preferences` (to remember the
chosen theme and language). If you already depend on `omni_route`, don't add
this package too: `omni_route` includes and re-exports it.

## Use

Wrap your app widget in `OmniResponsiveApp` and pass its data through:

```dart
import 'package:omni_responsive/omni_responsive.dart';

void main() => runApp(
  OmniResponsiveApp(
    themes: OmniTheme.presets,
    localization: const OmniLocalization(
      supportedLanguages: [OmniLanguage.en, OmniLanguage.bn],
    ),
    builder: (context, ui) => MaterialApp(        // or MaterialApp.router(...)
      theme: ui.theme,
      darkTheme: ui.darkTheme,
      themeMode: ui.themeMode,
      themeAnimationDuration: ui.themeAnimationDuration,
      themeAnimationCurve: ui.themeAnimationCurve,
      locale: ui.locale,
      localizationsDelegates: ui.localizationsDelegates,
      supportedLocales: ui.supportedLocales,
      builder: ui.builder,
      home: const HomePage(),
    ),
  ),
);
```

Then, anywhere below it:

```dart
context.isMobile;                         // breakpoints
context.responsive.tokens.gridColumns;    // spacing / grid tokens
context.setTheme('ocean');                // animated theme switch
context.themeController.setMode(ThemeMode.dark);
context.l10n(en: 'Hello', bn: 'হ্যালো');  // localized text
OmniText.setLanguage(OmniLanguage.bn);
```

Widgets: `OmniResponsiveLayout`, `OmniResponsiveGrid`,
`OmniResponsiveSliverGrid`, `OmniMasterDetail`, `OmniFoldableSplit`,
`OmniAdaptiveShellScaffold`, `OmniTextField` / `OmniEmailField` /
`OmniPasswordField` / `OmniPhoneField` / `OmniNumberField` / `OmniOtpField`,
`OmniThemePicker`, `OmniLanguagePicker`, `OmniSystemUi`, and more.

Full guides (Bengali): [responsive](../../doc/responsive.bn.md) ·
[theming](../../doc/theming.bn.md).
