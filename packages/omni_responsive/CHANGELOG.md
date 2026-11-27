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
