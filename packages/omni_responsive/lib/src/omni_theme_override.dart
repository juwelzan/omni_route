import 'package:flutter/material.dart';

import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';
import 'omni_theme.dart';

/// Gives one part of the app a different [OmniTheme] — a premium section, a
/// brand card, a theme preview — while the rest keeps the app theme.
///
/// ```dart
/// OmniThemeOverride(
///   theme: OmniTheme.emerald,
///   child: PremiumSection(),
/// )
/// ```
///
/// Everything below (`Theme.of`, `context.ui`, Omni fields and buttons) uses
/// [theme]. It follows the app's light/dark mode unless [brightness] is set,
/// and the screen tier and high-contrast setting like the app theme does.
/// Built themes are cached per theme, so overrides inside lists cost
/// nothing after the first build.
class OmniThemeOverride extends StatelessWidget {
  /// Applies [theme] to [child].
  const OmniThemeOverride({
    super.key,
    required this.theme,
    this.brightness,
    required this.child,
  });

  /// The theme for this subtree.
  final OmniTheme theme;

  /// Force light or dark; `null` follows the surrounding theme.
  final Brightness? brightness;

  /// The subtree.
  final Widget child;

  static final Expando<Map<_OverrideKey, ThemeData>> _cache = Expando(
    'omniThemeOverride',
  );

  /// Most environments one theme is built for (tiers × brightness × contrast).
  static const int _maxPerTheme = 16;

  @override
  Widget build(BuildContext context) {
    final key = _OverrideKey(
      device: OmniResponsiveScope.deviceOf(context),
      tokens: OmniResponsiveScope.tokensOf(context),
      brightness: brightness ?? Theme.of(context).brightness,
      highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
    );
    final perTheme = _cache[theme] ??= <_OverrideKey, ThemeData>{};
    var data = perTheme[key];
    if (data == null) {
      if (perTheme.length >= _maxPerTheme) perTheme.clear();
      data = perTheme[key] = theme.resolve(
        device: key.device,
        tokens: key.tokens,
        brightness: key.brightness,
        highContrast: key.highContrast,
      );
    }
    return Theme(data: data, child: child);
  }
}

@immutable
class _OverrideKey {
  const _OverrideKey({
    required this.device,
    required this.tokens,
    required this.brightness,
    required this.highContrast,
  });

  final OmniDeviceType device;
  final OmniResponsiveTokens tokens;
  final Brightness brightness;
  final bool highContrast;

  @override
  bool operator ==(Object other) =>
      other is _OverrideKey &&
      other.device == device &&
      identical(other.tokens, tokens) &&
      other.brightness == brightness &&
      other.highContrast == highContrast;

  @override
  int get hashCode =>
      Object.hash(device, identityHashCode(tokens), brightness, highContrast);
}
