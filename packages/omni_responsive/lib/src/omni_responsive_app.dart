import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'omni_localization.dart';
import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';
import 'omni_status_bar.dart';
import 'omni_system_navigation_bar.dart';
import 'omni_system_ui.dart';
import 'omni_theme.dart';
import 'omni_theme_transition.dart';

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
  final OmniSystemUiController _systemUi = OmniSystemUiController();

  bool get _hasThemeHost =>
      widget.omniTheme != null || widget.themes.isNotEmpty;

  @override
  void dispose() {
    _systemUi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Builder(builder: _buildApp);
    child = ListenableBuilder(
      listenable: _systemUi,
      child: child,
      builder: (context, built) => _systemUiLayer(context, built!),
    );
    child = OmniLocalizationHost(
      config: widget.localization ?? const OmniLocalization(),
      controller: widget.localeController,
      child: child,
    );
    return OmniResponsiveScope(
      config: widget.responsive,
      minTextScale: widget.minTextScale,
      maxTextScale: widget.maxTextScale,
      child: child,
    );
  }

  Widget _systemUiLayer(BuildContext context, Widget child) {
    final statusBar = _systemUi.statusBar ?? widget.statusBar;
    final navBar = _systemUi.systemNavigationBar ?? widget.systemNavigationBar;
    final baseMode = _systemUi.screenMode ?? widget.screenMode;
    final screenMode = baseMode != null || statusBar != null || navBar != null
        ? resolveEffectiveOmniScreenMode(
            baseMode ?? OmniScreenMode.edgeToEdge,
            statusBar: statusBar,
            systemNavigationBar: navBar,
          )
        : null;
    final runtimeOrientation =
        _systemUi.orientations != null || _systemUi.orientation != null;
    final orientation = runtimeOrientation
        ? _systemUi.orientation
        : widget.orientation;
    final orientations = runtimeOrientation
        ? _systemUi.orientations
        : (widget.orientation != null ? null : widget.orientations);
    final hasThemeHost = _hasThemeHost;

    var current = child;
    if (hasThemeHost) {
      current = OmniResponsiveThemeHost(
        omniTheme: widget.omniTheme,
        themes: widget.themes,
        themeAnimation: widget.themeAnimation,
        appScreenMode: screenMode,
        appStatusBar: statusBar,
        appSystemNavigationBar: navBar,
        child: current,
      );
    }
    current = OmniSystemUi(
      screenMode: hasThemeHost ? null : screenMode,
      statusBar: hasThemeHost ? null : statusBar,
      systemNavigationBar: hasThemeHost ? null : navBar,
      brightness:
          !hasThemeHost &&
              (statusBar != null || navBar != null || screenMode != null)
          ? MediaQuery.platformBrightnessOf(context)
          : null,
      orientation: orientation,
      orientations: orientations,
      child: current,
    );
    final first = widget.omniTheme ?? widget.themes.firstOrNull;
    return OmniSystemUiScope(
      controller: _systemUi,
      effectiveScreenMode:
          screenMode ?? first?.screenMode ?? OmniScreenMode.edgeToEdge,
      effectiveOrientation: orientation,
      effectiveStatusBar:
          statusBar ??
          first?.statusBar ??
          const OmniStatusBarStyle.transparent(),
      effectiveSystemNavigationBar:
          navBar ??
          first?.systemNavigationBar ??
          const OmniSystemNavigationBarStyle.transparent(),
      child: current,
    );
  }

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

  Widget _appBuilder(BuildContext context, Widget? child) {
    var current = child ?? const SizedBox.shrink();
    if (!_hasThemeHost) current = _syncBarTheme(context, current);
    if (widget.appBuilder case final own?) current = own(context, current);
    final scales =
        (widget.responsive.enabled && widget.responsive.adaptTextScaling) ||
        widget.minTextScale != null ||
        widget.maxTextScale != null;
    if (scales) {
      current = OmniResponsiveTextScaleHost(
        config: widget.responsive,
        minTextScale: widget.minTextScale,
        maxTextScale: widget.maxTextScale,
        child: current,
      );
    }
    return current;
  }

  /// Without an [OmniTheme], AppBars would reset the system bar style the
  /// app asked for; give them the same overlay style.
  static Widget _syncBarTheme(BuildContext context, Widget child) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OmniSystemUiScope>();
    if (scope == null ||
        (scope.effectiveStatusBar == const OmniStatusBarStyle.transparent() &&
            scope.effectiveSystemNavigationBar ==
                const OmniSystemNavigationBarStyle.transparent() &&
            scope.effectiveScreenMode == OmniScreenMode.edgeToEdge)) {
      return child;
    }
    final theme = Theme.of(context);
    final overlay = composeOmniSystemUiOverlayStyle(
      brightness: theme.brightness,
      screenMode: scope.effectiveScreenMode,
      statusBar: scope.effectiveStatusBar,
      systemNavigationBar: scope.effectiveSystemNavigationBar,
      fallbackTopBackground:
          theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
      fallbackBottomBackground: theme.scaffoldBackgroundColor,
    );
    if (theme.appBarTheme.systemOverlayStyle == overlay) return child;
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(systemOverlayStyle: overlay),
      ),
      child: child,
    );
  }
}
