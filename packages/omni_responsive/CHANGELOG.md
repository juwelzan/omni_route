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

