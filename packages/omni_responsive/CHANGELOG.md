## 0.1.0

- First release as its own package (previously part of `omni_route`):
  responsive breakpoints and tokens, adaptive widgets, master–detail and
  foldable split views, `OmniTheme` with animated transitions, form fields
  and validators, status/navigation bar and screen-mode control, and
  localization (`OmniText`, 40+ languages, RTL, persistence).
- New `OmniResponsiveApp` to host all of it around any `MaterialApp`
  without `omni_route`.
- The 7,300-line fields file is split into `lib/src/fields/`: one file per
  field plus shared theme, validators, texts and core. Public API unchanged.
- `OmniOtpField`: the resend countdown ticks without rebuilding the boxes
  (only its own text rebuilds), and shows `mm:ss` correctly for durations
  of a minute or more (was `00:120`). The OTP `build` is split into small
  methods.
- `OmniResponsiveAppData.supportedLocales` is never empty.
- `OmniResponsiveConfig` presets check breakpoint order like the default
  constructor, and every constructor checks `smallPhoneMaxWidth <=
  mobileMaxWidth`.
- `OmniColors` has 20 more colors (75 in all), settable everywhere colors are
  (`OmniTheme`, `OmniColorPalette`, `fromSeed`, `copyWith`, JSON):
  `tertiaryColor`, `dialogColor`, `bottomSheetColor`, `drawerColor`,
  `menuColor`, `fabColor`, `fabTextColor`, `outlineButtonColor`,
  `outlineButtonBorderColor`, `inputBorderColor`, `cursorColor`,
  `textSelectionColor`, `progressColor`, `progressTrackColor`,
  `tabSelectedColor`, `tabUnselectedColor`, `switchThumbColor`,
  `focusColor`, `scrollbarColor`, `navIndicatorColor`. Each defaults to the
  color that was used before.
- `OmniTheme.buttonShape` (`OmniButtonShape.rounded` / `pill` / `square`) and
  `buttonRadius` shape every button, FAB and segmented button independently
  of cards and fields. `OmniThemeStyle.pill` uses pill buttons.
- The theme now styles FAB, segmented buttons, popup / dropdown / anchor
  menus, drawers, tab bars, progress indicators, sliders, text selection,
  scrollbars, badges, date and time pickers, search bars, bottom app bars and
  expansion tiles, and maps the theme's surfaces onto the Material 3 surface
  levels instead of seed tones.
- Fixes: a text field's floated label is no longer accent-colored while
  unfocused; field icons follow focus / error / disabled; underlined fields
  have no left inset; switch thumbs and checkbox ticks stay readable on a
  light `switchActiveColor`, without a grey ring around a switched-on track;
  the snackbar action keeps 3:1 contrast in both modes.
- New `showOmniBottomSheet` / `OmniSheetRoute`: a modal bottom sheet in
  `material`, `cupertino`, `floating` or `adaptive` style, with iOS-style
  spring motion (`OmniSheetMotion`), detents (`OmniSheetDetent.medium`,
  `.large`, `.fraction`, `.height`, `.content`), velocity-based snapping,
  rubber-band stretch, drag hand-off from scroll views inside, `PopScope`-
  aware dismissal, keyboard avoidance, reduce-motion fade, and
  `OmniSheet.of(context)` (`snapTo`, `close`, `detent`). Works in
  `MaterialApp` and `CupertinoApp`; opening, closing and dragging only
  repaint. See `doc/bottom_sheet.bn.md`.
- New `OmniScalableSheet`: a resizable sheet on the page (Maps-style) in
  every `OmniSheetStyle`, opening at `initialDetent` and resting only on its
  detents (smallest = minimum, largest = maximum, rubber-band past both),
  with optional page dimming (`dimFromDetent`), back-button collapse, hide /
  show, and `OmniScalableSheetController` (`snapTo`, `expand`, `collapse`,
  `detent`, `isShown`, per-frame `height`). It shares the modal sheet's
  engine.
- Bottom sheets: releasing a non-dismissible sheet dragged below its
  smallest detent now rests on the smallest one.

**Text size**
- New app-wide text size: `OmniTextSize` (small / medium / large / extra
  large), `context.setTextSize(...)`, `OmniTextScale.setSize(...)`, a custom
  factor, and the ready-made `OmniTextSizePicker` (localized). Saved
  automatically; configure with `OmniResponsiveApp(textScaling: ...)`. The
  final scale is OS accessibility × screen tier × user size × language
  (`OmniLocalization.languageTextScale`), then `minTextScale`/`maxTextScale`.
- `OmniThemePanel`, `OmniThemeSettingsTile` and `showOmniThemeSheet` show a
  text size section (`showTextSize: false` hides it) and their labels now
  default to the current language (English, Bengali, Arabic, Hindi).

**Startup**
- `OmniPreferences.preload()` before `runApp` restores the saved theme,
  language and text size synchronously, so the first frame is already
  right. Without it the host holds the first frame (at most 120 ms) until
  they are read. Previously every launch showed a frame or two of the
  default theme and language.

**Theme performance**
- Palettes are cached per theme; built themes are cached per screen tier
  (resizing back to a tier rebuilds nothing).
- A theme switch builds only the brightness on screen; the other one is
  built in later frames, one per frame. `OmniThemePicker` precaches its
  themes the same way, so a tap does no theme work.
  `OmniThemeController.precache(ids)` does it on demand.
- Passing a new but equal `themes:` list no longer throws away every built
  theme.

**Theming features**
- `OmniTheme.fromSeed(color, variant: DynamicSchemeVariant.vibrant)`,
  `schemeVariant` and `contrastLevel` on every theme; the OS high-contrast
  setting switches to high-contrast palettes automatically.
- `OmniThemeController.addTheme` / `removeTheme`: user-made themes at
  runtime, shown in pickers and restored on launch.
- `OmniTheme.toJson` / `OmniTheme.fromJson` (colors as ARGB int or `#hex`).
- `OmniThemeOverride` gives part of the app another theme (cached).
- Debug builds warn when a theme's text or button colors are hard to read.
- Button text on generated palettes is picked by real contrast; several
  presets had button labels below 3:1 (e.g. Sunset dark 2.8:1).

**Fixes**
- Switching between a language with a `localeFonts` entry and one without
  remounted the whole app (all screen state lost); the locale font also
  never reached Material screens. Both fixed.
- Text scaling, the per-language font and the system-bar theme sync keep a
  fixed widget tree shape; crossing a breakpoint, changing text size or
  status-bar style no longer reparents the app.
- `OmniResponsiveApp` and omni_route's `OmniApp` now share one host
  (`OmniUiHost`), so their behaviour can't drift apart.
- `OmniThemeScope.maybeThemesOf(...).mode` is the brightness on screen
  (`light`/`dark`); `system` is resolved by the host.

