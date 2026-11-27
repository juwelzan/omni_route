import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'omni_localization.dart';
import 'omni_responsive_config.dart';
import 'omni_status_bar.dart';
import 'omni_system_navigation_bar.dart';
import 'omni_system_ui.dart';
import 'omni_text_scale.dart';
import 'omni_theme.dart';
import 'omni_theme_transition.dart';
import 'omni_ui_host.dart';

/// Everything an app widget needs from [OmniResponsiveApp]: pass these
/// straight to `MaterialApp`, `MaterialApp.router`, `CupertinoApp`, …
@immutable
class OmniResponsiveAppData {
  /// Created by [OmniResponsiveApp]; not meant to be built by hand.
  const OmniResponsiveAppData({
    required this.theme,
    required this.darkTheme,
    required this.themeMode,
    required this.themeAnimationDuration,
    required this.themeAnimationCurve,
    required this.locale,
    required this.localizationsDelegates,
    required this.supportedLocales,
    required this.builder,
  });

  /// Light theme of the active [OmniTheme] (`null` without themes).
  final ThemeData? theme;

  /// Dark theme of the active [OmniTheme] (`null` without themes).
  final ThemeData? darkTheme;

  /// Current light/dark/system choice (`null` without themes).
  final ThemeMode? themeMode;

  /// Pass to `MaterialApp.themeAnimationDuration` (zero while a snapshot
  /// transition such as a circular reveal is running).
  final Duration themeAnimationDuration;

  /// Pass to `MaterialApp.themeAnimationCurve`.
  final Curve themeAnimationCurve;

  /// The language chosen with `OmniText` / [OmniLocaleController].
  final Locale? locale;

  /// Fallback delegates so every [OmniLanguage] renders without extra setup.
  final List<LocalizationsDelegate<dynamic>> localizationsDelegates;

  /// The configured languages plus the active one; never empty.
  final List<Locale> supportedLocales;

  /// Pass to `MaterialApp.builder`: applies responsive text scaling and the
  /// system bar style below the app's `Theme`. Wraps your own builder when
  /// one was given to [OmniResponsiveApp.appBuilder].
  final TransitionBuilder builder;
}

/// Builds the app widget from the resolved [OmniResponsiveAppData].
typedef OmniResponsiveAppBuilder =
    Widget Function(BuildContext context, OmniResponsiveAppData data);

/// Hosts the whole `omni_responsive` stack — responsive breakpoints and
/// tokens, themes with animated transitions, localization, and system UI
/// (status bar, navigation bar, screen mode, orientation) — around any app
/// widget, without `omni_route`.
///
/// ```dart
/// OmniResponsiveApp(
///   themes: OmniTheme.presets,
///   builder: (context, ui) => MaterialApp(
///     theme: ui.theme,
///     darkTheme: ui.darkTheme,
///     themeMode: ui.themeMode,
///     themeAnimationDuration: ui.themeAnimationDuration,
///     themeAnimationCurve: ui.themeAnimationCurve,
///     locale: ui.locale,
///     localizationsDelegates: ui.localizationsDelegates,
///     supportedLocales: ui.supportedLocales,
///     builder: ui.builder,
///     home: const HomePage(),
///   ),
/// )
/// ```
///
/// `OmniApp` from `omni_route` already includes all of this; use this
/// widget only when routing is handled by something else.
class OmniResponsiveApp extends StatefulWidget {
  /// Creates the host. [builder] receives the resolved theme and locale.
  const OmniResponsiveApp({
    super.key,
    required this.builder,
    this.responsive = const OmniResponsiveConfig(),
    this.minTextScale,
    this.maxTextScale,
    this.omniTheme,
    this.themes = const [],
    this.themeAnimation,
    this.localization,
    this.localeController,
    this.textScaling = const OmniTextScaling(),
    this.textScaleController,
    this.statusBar,
    this.systemNavigationBar,
    this.screenMode,
    this.orientation,
    this.orientations,
    this.appBuilder,
  });

  /// Builds the app widget (usually a `MaterialApp`).
  final OmniResponsiveAppBuilder builder;

  /// Breakpoints, tokens and text-scaling rules.
  final OmniResponsiveConfig responsive;

  /// Lower bound for the composed text scale.
  final double? minTextScale;

  /// Upper bound for the composed text scale.
  final double? maxTextScale;

  /// Initial theme (or the only one).
  final OmniTheme? omniTheme;

  /// Themes the user can switch between at runtime.
  final List<OmniTheme> themes;

  /// How theme and mode changes animate.
  final OmniThemeAnimation? themeAnimation;

  /// Languages and persistence; `OmniText` works without it too.
  final OmniLocalization? localization;

  /// Optional isolated locale controller.
  final OmniLocaleController? localeController;

  /// The user's text size (small / medium / large …) and whether it is
  /// saved. Change it with `context.setTextSize(...)` or
  /// [OmniTextSizePicker].
  final OmniTextScaling textScaling;

  /// Optional isolated text size controller.
  final OmniTextScaleController? textScaleController;

  /// App-wide status bar style.
  final OmniStatusBarStyle? statusBar;

  /// App-wide system navigation bar style.
  final OmniSystemNavigationBarStyle? systemNavigationBar;

  /// Edge-to-edge, immersive, …
  final OmniScreenMode? screenMode;

  /// Locks the app to one orientation.
  final OmniOrientation? orientation;

  /// Allowed orientations (ignored when [orientation] is set).
  final List<DeviceOrientation>? orientations;

  /// Your own `MaterialApp.builder`, run inside [OmniResponsiveAppData.builder].
  final TransitionBuilder? appBuilder;

  @override
  State<OmniResponsiveApp> createState() => _OmniResponsiveAppState();
}

class _OmniResponsiveAppState extends State<OmniResponsiveApp> {
  bool get _hasThemeHost =>
      widget.omniTheme != null || widget.themes.isNotEmpty;

  @override
  Widget build(BuildContext context) => OmniUiHost(
    responsive: widget.responsive,
    minTextScale: widget.minTextScale,
    maxTextScale: widget.maxTextScale,
    omniTheme: widget.omniTheme,
    themes: widget.themes,
    themeAnimation: widget.themeAnimation,
    localization: widget.localization,
    localeController: widget.localeController,
    textScaling: widget.textScaling,
    textScaleController: widget.textScaleController,
    statusBar: widget.statusBar,
    systemNavigationBar: widget.systemNavigationBar,
    screenMode: widget.screenMode,
    orientation: widget.orientation,
    orientations: widget.orientations,
    child: Builder(builder: _buildApp),
  );

  Widget _buildApp(BuildContext context) {
    final themes = OmniThemeScope.maybeThemesOf(context);
    final anim = OmniThemeScope.animationSettingsOf(context);
    final l10nScope = OmniL10nScope.maybeOf(context);
    final locale = l10nScope?.notifier?.value.effectiveLocale;
    final supported = <Locale>{
      if (l10nScope != null)
        for (final lang in l10nScope.config.supportedLanguages) lang.locale,
      ?locale,
    };
    final data = OmniResponsiveAppData(
      theme: themes?.light,
      darkTheme: themes?.dark,
      themeMode: themes?.mode,
      themeAnimationDuration: anim?.duration ?? kThemeAnimationDuration,
      themeAnimationCurve: anim?.curve ?? Curves.linear,
      locale: locale,
      localizationsDelegates: const [
        OmniFallbackMaterialLocalizationsDelegate.instance,
        OmniFallbackCupertinoLocalizationsDelegate.instance,
        OmniFallbackWidgetsLocalizationsDelegate.instance,
      ],
      // MaterialApp asserts on an empty list.
      supportedLocales: supported.isEmpty
          ? const [Locale('en', 'US')]
          : List.unmodifiable(supported),
      builder: _appBuilder,
    );
    return widget.builder(context, data);
  }

  Widget _appBuilder(BuildContext context, Widget? child) =>
      OmniUiHost.buildAppContent(
        context,
        child,
        responsive: widget.responsive,
        minTextScale: widget.minTextScale,
        maxTextScale: widget.maxTextScale,
        syncBarTheme: !_hasThemeHost,
        appBuilder: widget.appBuilder,
      );
}
