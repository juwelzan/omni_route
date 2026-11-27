# OmniRoute Example App

Fast, lightweight Flutter showcase demonstrating `OmniRoute` (`OmniApp.material`, `OmniRouter`, `flutter_bloc`, route guards, responsive UI, and animated Dark/Light + Color Palette theming) with zero slow background network calls on startup.

> **বাংলা ইউজার গাইড:** [`../doc/theming.bn.md`](../doc/theming.bn.md) · [`../doc/responsive.bn.md`](../doc/responsive.bn.md) · [`../README.md`](../README.md)

## What It Demonstrates

1. **Zero-Boilerplate `OmniApp.material` Architecture** ([`lib/main.dart`](lib/main.dart))
   - `AuthGuard` redirecting unauthenticated users to `/login` and returning cleanly to `/dashboard`.
   - Lazy page-entry `Provide` registration (`StudentBloc`, `StudentDetailBloc`, `AttendanceBloc`) — registered on entry, closed automatically on exit.
   - `OmniStatefulShell` (Dashboard, Students, Settings), `OmniRouteGroup` (shared scope across student detail + edit), classic named routes (`OmniRoute.pushNamed`), dialog routes (`OmniPages.dialog`), and `onExit` confirmation prompts.
   - `OmniState` (`safeSetState`), `OmniLifecycle` (`onScreenVisible`), and `.hosted()` widgets (`WelcomeBadge`).

2. **Animated Dark/Light Mode, Color Palettes & System Bars**
   - `OmniTheme` with `OmniTheme.presets` (16 dual-mode color palettes), smooth zero-stutter screen transitions (`OmniThemeTransition`), 16 selectable animation modes (`OmniThemeAnimationPicker`), 12 design styles (`OmniThemeStylePicker`), edge-to-edge `OmniStatusBarStyle` / `OmniSystemNavigationBarStyle`, and `OmniOrientation.portraitOnMobile`.

3. **Predefined Form Fields & Shared `OmniFieldTheme`**
   - One shared `OmniFieldTheme` with per-identity `identityStyles` on `OmniTheme` powering `OmniEmailField.gmail`, `OmniPasswordField` (show/hide + strength + confirm), `OmniNameField`, `OmniPhoneField` (country picker + BD/E.164 verify), `OmniOtpField` (6-box paste + verify), `OmniNumberField` (integer/currency), `OmniSearchField`, `OmniMultilineField`, `OmniUrlField`, and `OmniTextField` across `/login`, `/students`, `/students/:id/edit`, and `/settings/profile`.

## Running

```bash
cd example

# Run the app:
flutter run

# Run UI & flow widget tests:
flutter test
```
