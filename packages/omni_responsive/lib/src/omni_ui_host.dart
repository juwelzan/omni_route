import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'omni_localization.dart';
import 'omni_preferences.dart';
import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';
import 'omni_status_bar.dart';
import 'omni_system_navigation_bar.dart';
import 'omni_system_ui.dart';
import 'omni_text_scale.dart';
import 'omni_theme.dart';
import 'omni_theme_transition.dart';

/// The one composition behind both `OmniApp` (omni_route) and
/// [OmniResponsiveApp]: responsive scope, localization, text size, themes
/// and system UI, in a fixed order with a fixed tree shape.
///
/// Also holds the first frame (at most [OmniPreferences.startupWait]) until
/// the saved theme, language and text size are read, so the app never
/// flashes the defaults. After [OmniPreferences.preload] nothing is held.
///
/// Apps don't use this directly; it is exported from `integration.dart` for
/// `omni_route`.
class OmniUiHost extends StatefulWidget {
  /// Hosts [child] (the app widget, e.g. `MaterialApp.router`).
  const OmniUiHost({
    super.key,
    required this.child,
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
    this.systemUiController,
  });

  /// The app widget.
  final Widget child;

  /// Breakpoints, tokens and tier text scaling.
  final OmniResponsiveConfig responsive;

  /// Lower clamp for the final text scale.
  final double? minTextScale;

  /// Upper clamp for the final text scale.
  final double? maxTextScale;

  /// Initial (or only) theme.
  final OmniTheme? omniTheme;

  /// Themes users can switch between.
  final List<OmniTheme> themes;

  /// Theme/mode change animation.
  final OmniThemeAnimation? themeAnimation;

  /// Languages and persistence.
  final OmniLocalization? localization;

  /// Optional isolated locale controller.
  final OmniLocaleController? localeController;

  /// Text size settings for the global [OmniTextScale].
  final OmniTextScaling textScaling;

  /// Optional isolated text size controller (then [textScaling] is unused).
  final OmniTextScaleController? textScaleController;

  /// App-wide status bar style.
  final OmniStatusBarStyle? statusBar;

  /// App-wide navigation bar style.
  final OmniSystemNavigationBarStyle? systemNavigationBar;

  /// Screen mode (edge-to-edge, immersive, …).
  final OmniScreenMode? screenMode;

  /// Locked orientation.
  final OmniOrientation? orientation;

  /// Allowed orientations (ignored when [orientation] is set).
  final List<DeviceOrientation>? orientations;

  /// Runtime system UI controller; one is created when omitted.
  final OmniSystemUiController? systemUiController;

  /// What `MaterialApp.builder` / `CupertinoApp.builder` should return:
  /// [child] with the per-language font and system bar style applied to the
  /// Material theme ([material] only), the app's own builders, and the
  /// composed text scale (OS × screen tier × user text size × language).
  ///
  /// The returned tree always has the same shape, so changing any of these
  /// at runtime never remounts the app.
  static Widget buildAppContent(
    BuildContext context,
    Widget? child, {
    required OmniResponsiveConfig responsive,
    double? minTextScale,
    double? maxTextScale,
    bool material = true,
    bool syncBarTheme = false,
    TransitionBuilder? appBuilder,
    TransitionBuilder? overlayBuilder,
  }) {
    Widget current = child ?? const SizedBox.shrink();
    if (material) {
      current = _OmniMaterialThemeAdjust(
        syncBars: syncBarTheme,
        child: current,
      );
    }
    if (appBuilder != null) current = appBuilder(context, current);
    if (overlayBuilder != null) current = overlayBuilder(context, current);
    return OmniResponsiveTextScaleHost(
      config: responsive,
      minTextScale: minTextScale,
      maxTextScale: maxTextScale,
      child: current,
    );
  }

  @override
  State<OmniUiHost> createState() => _OmniUiHostState();
}

class _OmniUiHostState extends State<OmniUiHost> {
  OmniSystemUiController? _ownedSystemUi;
  bool _holdingFirstFrame = false;
  Timer? _startupTimer;

  OmniSystemUiController get _systemUi =>
      widget.systemUiController ??
      (_ownedSystemUi ??= OmniSystemUiController());

  OmniTextScaleController get _textScale =>
      widget.textScaleController ?? OmniTextScale.controller;

  bool get _hasThemeHost =>
      widget.omniTheme != null || widget.themes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _holdFirstFrameUntilSettingsLoad();
    _applyTextScaling();
  }

  /// Saved theme/language/text size must be in place for the first frame.
  void _holdFirstFrameUntilSettingsLoad() {
    if (OmniPreferences.cached != null) return;
    final binding = WidgetsBinding.instance;
    binding.deferFirstFrame();
    _holdingFirstFrame = true;
    _startupTimer = Timer(OmniPreferences.startupWait, _releaseFirstFrame);
    OmniPreferences.load().then(
      (_) => _releaseFirstFrame(),
      onError: (Object _) => _releaseFirstFrame(),
    );
  }

  void _releaseFirstFrame() {
    _startupTimer?.cancel();
    _startupTimer = null;
    if (!_holdingFirstFrame) return;
    _holdingFirstFrame = false;
    // Controllers restore on the same load; let their callbacks run first.
    scheduleMicrotask(WidgetsBinding.instance.allowFirstFrame);
  }

  void _applyTextScaling() {
    if (widget.textScaleController case final own?) {
      unawaited(own.hydrate());
    } else {
      OmniTextScale.attach(widget.textScaling);
    }
  }

  @override
  void didUpdateWidget(covariant OmniUiHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textScaleController != oldWidget.textScaleController ||
        widget.textScaling != oldWidget.textScaling) {
      _applyTextScaling();
    }
    if (widget.systemUiController != null && _ownedSystemUi != null) {
      _ownedSystemUi!.dispose();
      _ownedSystemUi = null;
    }
  }

  @override
  void dispose() {
    _releaseFirstFrame();
    _ownedSystemUi?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final systemUi = _systemUi;
    Widget child = ListenableBuilder(
      listenable: systemUi,
      child: widget.child,
      builder: (context, built) => _systemUiLayer(context, systemUi, built!),
    );
    child = OmniTextScaleScope(controller: _textScale, child: child);
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

  Widget _systemUiLayer(
    BuildContext context,
    OmniSystemUiController systemUi,
    Widget child,
  ) {
    final statusBar = systemUi.statusBar ?? widget.statusBar;
    final navBar = systemUi.systemNavigationBar ?? widget.systemNavigationBar;
    final baseMode = systemUi.screenMode ?? widget.screenMode;
    final screenMode = baseMode != null || statusBar != null || navBar != null
        ? resolveEffectiveOmniScreenMode(
            baseMode ?? OmniScreenMode.edgeToEdge,
            statusBar: statusBar,
            systemNavigationBar: navBar,
          )
        : null;
    final runtimeOrientation =
        systemUi.orientations != null || systemUi.orientation != null;
    final orientation = runtimeOrientation
        ? systemUi.orientation
        : widget.orientation;
    final orientations = runtimeOrientation
        ? systemUi.orientations
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
      controller: systemUi,
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
}

/// Applies the active language's font ([OmniLocalization.localeFonts]) and,
/// without an [OmniTheme], the app's system bar style to the Material theme
/// every screen reads. Always inserts a `Theme`, so the tree shape never
/// changes; derived themes are cached per source theme.
class _OmniMaterialThemeAdjust extends StatelessWidget {
  const _OmniMaterialThemeAdjust({required this.syncBars, required this.child});

  final bool syncBars;
  final Widget child;

  static final Expando<_AdjustedTheme> _cache = Expando('omniThemeAdjust');

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final l10n = OmniL10nScope.maybeOf(context);
    final language = l10n?.notifier?.value.language;
    final font = language == null ? null : l10n!.config.fontFor(language);
    final overlay = syncBars ? _overlayFor(context, base) : null;
    return Theme(data: _adjusted(base, font, overlay), child: child);
  }

  static SystemUiOverlayStyle? _overlayFor(
    BuildContext context,
    ThemeData theme,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OmniSystemUiScope>();
    if (scope == null ||
        (scope.effectiveStatusBar == const OmniStatusBarStyle.transparent() &&
            scope.effectiveSystemNavigationBar ==
                const OmniSystemNavigationBarStyle.transparent() &&
            scope.effectiveScreenMode == OmniScreenMode.edgeToEdge)) {
      return null;
    }
    return composeOmniSystemUiOverlayStyle(
      brightness: theme.brightness,
      screenMode: scope.effectiveScreenMode,
      statusBar: scope.effectiveStatusBar,
      systemNavigationBar: scope.effectiveSystemNavigationBar,
      fallbackTopBackground:
          theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
      fallbackBottomBackground: theme.scaffoldBackgroundColor,
    );
  }

  static ThemeData _adjusted(
    ThemeData base,
    String? font,
    SystemUiOverlayStyle? overlay,
  ) {
    final needsOverlay =
        overlay != null && base.appBarTheme.systemOverlayStyle != overlay;
    if (font == null && !needsOverlay) return base;
    final hit = _cache[base];
    if (hit != null && hit.font == font && hit.overlay == overlay) {
      return hit.theme;
    }
    var theme = base;
    if (font != null) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: font),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: font),
      );
    }
    if (needsOverlay) {
      theme = theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(systemOverlayStyle: overlay),
      );
    }
    _cache[base] = _AdjustedTheme(font, overlay, theme);
    return theme;
  }
}

class _AdjustedTheme {
  const _AdjustedTheme(this.font, this.overlay, this.theme);

  final String? font;
  final SystemUiOverlayStyle? overlay;
  final ThemeData theme;
}
