import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'omni_colors.dart';
import 'omni_fields.dart';
import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';
import 'omni_status_bar.dart';
import 'omni_styles.dart';
import 'omni_system_navigation_bar.dart';
import 'omni_system_ui.dart';
import 'omni_theme_transition.dart';

/// বর্তমান সক্রিয় থিম কনফিগার করার জন্য কাস্টম হুক (প্রতি ডিভাইস টিয়ারে একবার
/// চলে ও ফল মেমোইজড থাকে)।
typedef OmniThemeCustomizer = ThemeData Function(
  ThemeData base,
  OmniDeviceType device,
  OmniResponsiveTokens tokens,
);

/// বর্তমান সক্রিয় থিম আইডি, লাইট/ডার্ক/সিস্টেম মোড, থিম স্টাইল ও স্ক্রিন অ্যানিমেশনের স্ন্যাপশট।
@immutable
class OmniThemeSelection {
  /// [mode], [themeId], ঐচ্ছিক [style] ও [animationMode] নিয়ে স্ন্যাপশট তৈরি করে।
  const OmniThemeSelection({
    required this.mode,
    required this.themeId,
    this.style,
    this.animationMode,
  });

  /// বর্তমান `ThemeMode` (`light`, `dark`, বা `system`)।
  final ThemeMode mode;

  /// বর্তমান সক্রিয় `OmniTheme.id` (যেমন `'default'`, `'ocean'`, `'emerald'`)।
  final String themeId;

  /// রানটাইমে বদলানো ঐচ্ছিক [OmniThemeStyle] ওভাররাইড (`null` মানে থিমের নিজস্ব স্টাইল)।
  final OmniThemeStyle? style;

  /// রানটাইমে বদলানো ঐচ্ছিক [OmniThemeAnimationMode] (`null` মানে থিমের নিজস্ব অ্যানিমেশন)।
  final OmniThemeAnimationMode? animationMode;

  /// নির্বাচিত ক্ষেত্র পরিবর্তন করে নতুন কপি তৈরি করে।
  OmniThemeSelection copyWith({
    ThemeMode? mode,
    String? themeId,
    OmniThemeStyle? style,
    OmniThemeAnimationMode? animationMode,
    bool clearStyle = false,
    bool clearAnimationMode = false,
  }) => OmniThemeSelection(
    mode: mode ?? this.mode,
    themeId: themeId ?? this.themeId,
    style: clearStyle ? null : (style ?? this.style),
    animationMode:
        clearAnimationMode ? null : (animationMode ?? this.animationMode),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniThemeSelection &&
          mode == other.mode &&
          themeId == other.themeId &&
          style == other.style &&
          animationMode == other.animationMode;

  @override
  int get hashCode => Object.hash(mode, themeId, style, animationMode);
}

/// পুরো অ্যাপের সক্রিয় কালার প্যালেট (`themeId`), `ThemeMode` (`light`/`dark`/`system`),
/// [OmniThemeStyle] ও থিম অ্যানিমেশন ([OmniThemeAnimationMode]) নিয়ন্ত্রণের কন্ট্রোলার।
///
/// পরিবর্তন করলেই `shared_preferences`-এ অটো-সেভ হয় (যদি [persist] = `true`)
/// এবং স্ক্রিনের ওপর দিয়ে মসৃণ অ্যানিমেশনে রঙ ও মোড বদলে যায়।
class OmniThemeController extends ValueNotifier<OmniThemeSelection> {
  /// [initialMode], [initialThemeId], ঐচ্ছিক [initialStyle] ও [initialAnimationMode]
  /// নিয়ে থিম কন্ট্রোলার তৈরি করে।
  OmniThemeController({
    ThemeMode initialMode = ThemeMode.system,
    String initialThemeId = 'default',
    OmniThemeStyle? initialStyle,
    OmniThemeAnimationMode? initialAnimationMode,
    this.persist = true,
    this.storageKey = 'default',
  }) : _initialSelection = OmniThemeSelection(
         mode: initialMode,
         themeId: initialThemeId,
         style: initialStyle,
         animationMode: initialAnimationMode,
       ),
       super(
         OmniThemeSelection(
           mode: initialMode,
           themeId: initialThemeId,
           style: initialStyle,
           animationMode: initialAnimationMode,
         ),
       );

  final OmniThemeSelection _initialSelection;

  /// মোড, কালার প্যালেট, স্টাইল ও অ্যানিমেশন নির্বাচন `SharedPreferences`-এ সেভ থাকবে কি না।
  final bool persist;

  /// একাধিক অ্যাপ বা প্রোফাইলের সেভ ডেটা আলাদা রাখার কী।
  final String storageKey;

  bool _disposed = false;
  bool _hydrated = false;
  int _nonAnimatedVersion = 0;
  Offset? _pendingOrigin;

  /// অ্যানিমেশন ছাড়া অভ্যন্তরীণ আপডেট (যেমন স্টার্টআপ হাইড্রেশন) শনাক্তের কাউন্টার।
  int get nonAnimatedVersion => _nonAnimatedVersion;

  /// কোড থেকে দেওয়া অ্যানিমেশন উৎস পজিশন একবারের জন্য নিয়ে রিসেট করে।
  Offset? takePendingOrigin() {
    final o = _pendingOrigin;
    _pendingOrigin = null;
    return o;
  }

  /// সেভ করা লাইট/ডার্ক মোডের কী।
  String get prefKey => 'omni_route.theme.$storageKey.mode';

  /// সেভ করা অ্যাক্টিভ থিম আইডির কী।
  String get themeIdPrefKey => 'omni_route.theme.$storageKey.themeId';

  /// সেভ করা অ্যাক্টিভ থিম স্টাইলের কী।
  String get stylePrefKey => 'omni_route.theme.$storageKey.style';

  /// সেভ করা অ্যাক্টিভ থিম ট্রানজিশন অ্যানিমেশনের কী।
  String get animationModePrefKey => 'omni_route.theme.$storageKey.animationMode';

  /// বর্তমান `ThemeMode` (`light`, `dark`, বা `system`)।
  ThemeMode get mode => value.mode;

  /// বর্তমান সক্রিয় থিমের `id`।
  String get themeId => value.themeId;

  /// রানটাইমে নির্বাচিত [OmniThemeStyle] (অথবা `null`)।
  OmniThemeStyle? get style => value.style;

  /// রানটাইমে নির্বাচিত [OmniThemeAnimationMode] (অথবা `null`)।
  OmniThemeAnimationMode? get animationMode => value.animationMode;

  /// স্টার্টআপে প্রথম ফ্রেম ব্লক না করে `SharedPreferences` থেকে সেভ করা
  /// থিম, মোড, স্টাইল ও অ্যানিমেশন পছন্দ লোড করে (কোনো স্টার্টআপ ফ্ল্যাশ ছাড়াই)।
  Future<void> hydrate() async {
    if (!persist || _hydrated || _disposed) return;
    _hydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final rawMode = prefs.getString(prefKey);
      final restoredMode = switch (rawMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
      final restoredId = prefs.getString(themeIdPrefKey);
      final rawStyle = prefs.getString(stylePrefKey);
      OmniThemeStyle? restoredStyle;
      if (rawStyle != null) {
        for (final s in OmniThemeStyle.values) {
          if (s.name == rawStyle) {
            restoredStyle = s;
            break;
          }
        }
      }
      final rawAnim = prefs.getString(animationModePrefKey);
      OmniThemeAnimationMode? restoredAnim;
      if (rawAnim != null) {
        for (final m in OmniThemeAnimationMode.values) {
          if (m.name == rawAnim) {
            restoredAnim = m;
            break;
          }
        }
      }
      final next = OmniThemeSelection(
        mode: restoredMode ?? value.mode,
        themeId: (restoredId != null && restoredId.isNotEmpty)
            ? restoredId
            : value.themeId,
        style: restoredStyle ?? value.style,
        animationMode: restoredAnim ?? value.animationMode,
      );
      if (next != value) {
        _nonAnimatedVersion++;
        value = next;
      }
    } catch (_) {
      // হেডলেস টেস্টে SharedPreferences মক না থাকলে নিরাপদ ফলব্যাক।
    }
  }

  /// ১ ক্লিকে পুরো অ্যাপের কালার প্যালেট ([themeId]) অ্যানিমেশনসহ পরিবর্তন করে।
  void setTheme(String themeId, {Offset? origin, bool animate = true}) {
    if (_disposed) return;
    _pendingOrigin = origin;
    if (!animate) _nonAnimatedVersion++;
    if (value.themeId != themeId) {
      value = value.copyWith(themeId: themeId);
    }
    if (persist) {
      unawaited(_saveString(themeIdPrefKey, themeId));
    }
  }

  /// ১ ক্লিকে পুরো অ্যাপের ডিজাইন স্টাইল ([OmniThemeStyle]) অ্যানিমেশনসহ পরিবর্তন করে।
  void setStyle(OmniThemeStyle style, {Offset? origin, bool animate = true}) {
    if (_disposed) return;
    _pendingOrigin = origin;
    if (!animate) _nonAnimatedVersion++;
    if (value.style != style) {
      value = value.copyWith(style: style);
    }
    if (persist) {
      unawaited(_saveString(stylePrefKey, style.name));
    }
  }

  /// ডার্ক মোড ও কালার প্যালেট পরিবর্তনের অ্যানিমেশন মোড ([OmniThemeAnimationMode]) সেট করে।
  void setAnimationMode(OmniThemeAnimationMode mode) {
    if (_disposed) return;
    if (value.animationMode != mode) {
      _nonAnimatedVersion++;
      value = value.copyWith(animationMode: mode);
    }
    if (persist) {
      unawaited(_saveString(animationModePrefKey, mode.name));
    }
  }

  /// উপলব্ধ [themes] তালিকার পরবর্তী থিমে ১ ক্লিকে চলে যায়।
  void nextTheme(
    List<OmniTheme> themes, {
    Offset? origin,
    bool animate = true,
  }) {
    if (themes.length <= 1) return;
    final idx = themes.indexWhere((t) => t.id == value.themeId);
    final next = idx < 0 ? themes.first : themes[(idx + 1) % themes.length];
    setTheme(next.id, origin: origin, animate: animate);
  }

  /// লাইট, ডার্ক বা সিস্টেম মোড অ্যানিমেশনসহ সেট করে এবং লোকালি সেভ রাখে।
  void setMode(ThemeMode next, {Offset? origin, bool animate = true}) {
    if (_disposed) return;
    _pendingOrigin = origin;
    if (!animate) _nonAnimatedVersion++;
    if (value.mode != next) {
      value = value.copyWith(mode: next);
    }
    if (persist) {
      unawaited(_saveString(prefKey, next.name));
    }
  }

  /// লাইট মোড চালু করে।
  void useLight({Offset? origin, bool animate = true}) =>
      setMode(ThemeMode.light, origin: origin, animate: animate);

  /// ডার্ক মোড চালু করে।
  void useDark({Offset? origin, bool animate = true}) =>
      setMode(ThemeMode.dark, origin: origin, animate: animate);

  /// ডিভাইসের সিস্টেম মোড অনুসরণ করে।
  void useSystem({Offset? origin, bool animate = true}) =>
      setMode(ThemeMode.system, origin: origin, animate: animate);

  /// ১ ক্লিকে লাইট <-> ডার্ক মোড অ্যানিমেশনসহ পাল্টায় (সিস্টেম মোড থেকেও কাজ করে)।
  void toggle([
    Brightness? platformBrightness,
    Offset? origin,
    bool animate = true,
  ]) {
    final effBrightness = platformBrightness ??
        PlatformDispatcher.instance.platformBrightness;
    final currentlyDark = value.mode == ThemeMode.dark ||
        (value.mode == ThemeMode.system && effBrightness == Brightness.dark);
    setMode(
      currentlyDark ? ThemeMode.light : ThemeMode.dark,
      origin: origin,
      animate: animate,
    );
  }

  /// `system -> light -> dark -> system` চক্রাকারে ঘোরায়।
  void cycle({Offset? origin, bool animate = true}) => setMode(
    switch (value.mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    },
    origin: origin,
    animate: animate,
  );

  /// সেভ করা থিম, মোড, স্টাইল ও অ্যানিমেশন পছন্দ মুছে ডিফল্টে ফিরে আসে।
  Future<void> resetSavedMode({bool animate = false}) async {
    if (!_disposed && value != _initialSelection) {
      if (!animate) _nonAnimatedVersion++;
      value = _initialSelection;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefKey);
      await prefs.remove(themeIdPrefKey);
      await prefs.remove(stylePrefKey);
      await prefs.remove(animationModePrefKey);
    } catch (_) {
      // প্ল্যাটফর্ম স্টোরেজ না থাকলে নিরাপদ ইগনোর।
    }
  }

  Future<void> _saveString(String key, String data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, data);
    } catch (_) {
      // হেডলেস টেস্টে নিরাপদ ইগনোর।
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// জিরো-বয়লারপ্লেট রেসপন্সিভ থিমিং, কালার প্যালেট, টেক্সট স্টাইল ও মাল্টি-থিম সিস্টেম।
///
/// ১ লাইনে পুরো অ্যাপে [OmniColors] (৫৩টি পিওর সেমান্টিক রঙ), [OmniTextStyles]
/// (`context.textStyles`), [OmniStyles] (`context.styles`), [OmniUiTheme] (`context.ui`)
/// এবং ডার্ক/লাইট/সিস্টেম মোড ও একাধিক কালার প্যালেটের মধ্যে ১-ক্লিক সুইচিং দেয়:
/// ```dart
/// OmniApp.material(
///   omniTheme: const OmniTheme(
///     seedColor: Colors.indigo,
///     style: OmniThemeStyle.outlined,
///   ),
///   themes: OmniTheme.presets, // ৮টি রেডি কালার প্যালেট বা নিজের কাস্টম লিস্ট!
///   routes: [...],
/// )
/// ```
@immutable
class OmniTheme {
  /// [seedColor], [light]/[dark] প্যালেট, ঐচ্ছিক [style] প্রিসেট ও সেমান্টিক কালার দিয়ে একটি থিম তৈরি করে।
  const OmniTheme({
    this.seedColor = const Color(0xFF2563EB),
    this.id = 'default',
    this.name = 'Default',
    this.previewColor,
    this.mode = ThemeMode.system,
    this.persistMode = true,
    this.storageKey = 'default',
    this.controller,
    this.darkSeedColor,
    this.secondaryColor,
    this.darkSecondaryColor,
    this.light,
    this.dark,
    this.style = OmniThemeStyle.modern,
    this.useMaterial3 = true,
    this.fontFamily,
    this.headingWeight = FontWeight.w700,
    this.borderRadius,
    this.inputVariant,
    this.borderWidth,
    this.focusedBorderWidth,
    this.cardBorderWidth,
    this.surfaceColor,
    this.darkSurfaceColor,
    this.secondaryBackgroundColor,
    this.darkSecondaryBackgroundColor,
    this.scaffoldBackgroundColor,
    this.darkScaffoldBackgroundColor,
    this.cardColor,
    this.darkCardColor,
    this.appBarColor,
    this.appBarTextColor,
    this.navBarColor,
    this.navSelectedColor,
    this.navUnselectedColor,
    this.buttonColor,
    this.buttonTextColor,
    this.secondaryButtonColor,
    this.secondaryButtonTextColor,
    this.dangerButtonColor,
    this.dangerButtonTextColor,
    this.linkColor,
    this.borderColor,
    this.focusedBorderColor,
    this.dividerColor,
    this.inputFillColor,
    this.textColor,
    this.secondaryTextColor,
    this.hintTextColor,
    this.iconColor,
    this.chipColor,
    this.chipTextColor,
    this.badgeColor,
    this.badgeTextColor,
    this.selectedItemColor,
    this.hoverColor,
    this.rippleColor,
    this.disabledColor,
    this.disabledTextColor,
    this.disabledBorderColor,
    this.switchActiveColor,
    this.switchInactiveColor,
    this.snackbarColor,
    this.snackbarTextColor,
    this.tooltipColor,
    this.tooltipTextColor,
    this.errorColor,
    this.warningColor,
    this.successColor,
    this.infoColor,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
    this.overlayColor,
    this.shadowColor,
    this.lightColors,
    this.darkColors,
    this.cardElevation,
    this.appBarCenterTitle,
    this.screenMode = OmniScreenMode.edgeToEdge,
    this.statusBar,
    this.systemNavigationBar,
    this.animation = const OmniThemeAnimation(),
    this.fieldTheme,
    this.customizer,
  });

  /// কম্প্যাক্ট `8dp` কর্নারওয়ালা প্রোডাক্টিভিটি প্রিসেট।
  const OmniTheme.compact({
    this.seedColor = const Color(0xFF2563EB),
    this.id = 'default',
    this.name = 'Compact',
    this.previewColor,
    this.mode = ThemeMode.system,
    this.persistMode = true,
    this.storageKey = 'default',
    this.controller,
    this.darkSeedColor,
    this.secondaryColor,
    this.darkSecondaryColor,
    this.light,
    this.dark,
    this.style = OmniThemeStyle.compact,
    this.useMaterial3 = true,
    this.fontFamily,
    this.headingWeight = FontWeight.w700,
    this.borderRadius = 8,
    this.inputVariant = OmniInputVariant.outlined,
    this.borderWidth = 1.0,
    this.focusedBorderWidth = 1.8,
    this.cardBorderWidth = 1.0,
    this.surfaceColor,
    this.darkSurfaceColor,
    this.secondaryBackgroundColor,
    this.darkSecondaryBackgroundColor,
    this.scaffoldBackgroundColor,
    this.darkScaffoldBackgroundColor,
    this.cardColor,
    this.darkCardColor,
    this.appBarColor,
    this.appBarTextColor,
    this.navBarColor,
    this.navSelectedColor,
    this.navUnselectedColor,
    this.buttonColor,
    this.buttonTextColor,
    this.secondaryButtonColor,
    this.secondaryButtonTextColor,
    this.dangerButtonColor,
    this.dangerButtonTextColor,
    this.linkColor,
    this.borderColor,
    this.focusedBorderColor,
    this.dividerColor,
    this.inputFillColor,
    this.textColor,
    this.secondaryTextColor,
    this.hintTextColor,
    this.iconColor,
    this.chipColor,
    this.chipTextColor,
    this.badgeColor,
    this.badgeTextColor,
    this.selectedItemColor,
    this.hoverColor,
    this.rippleColor,
    this.disabledColor,
    this.disabledTextColor,
    this.disabledBorderColor,
    this.switchActiveColor,
    this.switchInactiveColor,
    this.snackbarColor,
    this.snackbarTextColor,
    this.tooltipColor,
    this.tooltipTextColor,
    this.errorColor,
    this.warningColor,
    this.successColor,
    this.infoColor,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
    this.overlayColor,
    this.shadowColor,
    this.lightColors,
    this.darkColors,
    this.cardElevation = 0,
    this.appBarCenterTitle,
    this.screenMode = OmniScreenMode.edgeToEdge,
    this.statusBar,
    this.systemNavigationBar,
    this.animation = const OmniThemeAnimation(),
    this.fieldTheme,
    this.customizer,
  });

  /// রাউন্ডেড `20dp` কর্নারওয়ালা কনজিউমার অ্যাপ প্রিসেট।
  const OmniTheme.pill({
    this.seedColor = const Color(0xFF2563EB),
    this.id = 'default',
    this.name = 'Pill',
    this.previewColor,
    this.mode = ThemeMode.system,
    this.persistMode = true,
    this.storageKey = 'default',
    this.controller,
    this.darkSeedColor,
    this.secondaryColor,
    this.darkSecondaryColor,
    this.light,
    this.dark,
    this.style = OmniThemeStyle.soft,
    this.useMaterial3 = true,
    this.fontFamily,
    this.headingWeight = FontWeight.w700,
    this.borderRadius = 20,
    this.inputVariant = OmniInputVariant.filled,
    this.borderWidth = 1.0,
    this.focusedBorderWidth = 1.8,
    this.cardBorderWidth = 1.0,
    this.surfaceColor,
    this.darkSurfaceColor,
    this.secondaryBackgroundColor,
    this.darkSecondaryBackgroundColor,
    this.scaffoldBackgroundColor,
    this.darkScaffoldBackgroundColor,
    this.cardColor,
    this.darkCardColor,
    this.appBarColor,
    this.appBarTextColor,
    this.navBarColor,
    this.navSelectedColor,
    this.navUnselectedColor,
    this.buttonColor,
    this.buttonTextColor,
    this.secondaryButtonColor,
    this.secondaryButtonTextColor,
    this.dangerButtonColor,
    this.dangerButtonTextColor,
    this.linkColor,
    this.borderColor,
    this.focusedBorderColor,
    this.dividerColor,
    this.inputFillColor,
    this.textColor,
    this.secondaryTextColor,
    this.hintTextColor,
    this.iconColor,
    this.chipColor,
    this.chipTextColor,
    this.badgeColor,
    this.badgeTextColor,
    this.selectedItemColor,
    this.hoverColor,
    this.rippleColor,
    this.disabledColor,
    this.disabledTextColor,
    this.disabledBorderColor,
    this.switchActiveColor,
    this.switchInactiveColor,
    this.snackbarColor,
    this.snackbarTextColor,
    this.tooltipColor,
    this.tooltipTextColor,
    this.errorColor,
    this.warningColor,
    this.successColor,
    this.infoColor,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
    this.overlayColor,
    this.shadowColor,
    this.lightColors,
    this.darkColors,
    this.cardElevation = 0,
    this.appBarCenterTitle,
    this.screenMode = OmniScreenMode.edgeToEdge,
    this.statusBar,
    this.systemNavigationBar,
    this.animation = const OmniThemeAnimation(),
    this.fieldTheme,
    this.customizer,
  });

  /// এই থিমটিকে `OmniThemePicker`-এ চেনার জন্য ইউনিক আইডি (যেমন `'ocean'`)।
  final String id;

  /// থিম বাছাই করার UI-তে প্রদর্শিত নাম (যেমন `'Ocean'`)।
  final String name;

  /// পিকার বাটনে দেখানোর রঙ ডট (না দিলে [seedColor] ব্যবহার হয়)।
  final Color? previewColor;

  /// ব্র্যান্ডের প্রধান প্রাইমারি রঙ (যা থেকে পুরো প্যালেট তৈরি হয়)।
  final Color seedColor;

  /// প্রাথমিক লাইট/ডার্ক/সিস্টেম মোড।
  final ThemeMode mode;

  /// ইউজারের বাছাই করা থিম, মোড ও স্টাইল লোকাল স্টোরেজে অটো সেভ রাখবে কি না।
  final bool persistMode;

  /// সেভ ডেটা আলাদা রাখার কী।
  final String storageKey;

  /// ঐচ্ছিক বাহ্যিক [OmniThemeController]।
  final OmniThemeController? controller;

  /// ডার্ক মোডের প্রধান ব্র্যান্ড প্রাইমারি রঙ (`null` হলে `dark?.primaryColor ?? seedColor`)।
  final Color? darkSeedColor;

  /// সেকেন্ডারি অ্যাকসেন্ট কালার (`OmniColors.secondaryColor`)।
  final Color? secondaryColor;

  /// ডার্ক মোডের সেকেন্ডারি অ্যাকসেন্ট কালার (`null` হলে `dark?.secondaryColor ?? secondaryColor`)।
  final Color? darkSecondaryColor;

  /// লাইট মোডের জন্য সহজ কালার প্যালেট ওভাররাইড (৫৫টি কালারের মধ্যে শুধু প্রয়োজনীয়গুলো দিন)।
  final OmniColorPalette? light;

  /// ডার্ক মোডের জন্য সহজ কালার প্যালেট ওভাররাইড (৫৫টি কালারের মধ্যে শুধু প্রয়োজনীয়গুলো দিন)।
  final OmniColorPalette? dark;

  /// ১-লাইনের ডিজাইন স্টাইল প্রিসেট (`modern`, `outlined`, `soft`, `elevated`, `minimal`, `compact`)।
  final OmniThemeStyle style;

  /// Material 3 চালু রাখে (ডিফল্ট `true`)।
  final bool useMaterial3;

  /// পুরো অ্যাপের ডিফল্ট ফন্ট ফ্যামিলি।
  final String? fontFamily;

  /// ডিসপ্লে, হেডিং ও কার্ড টাইটেলের ডিফল্ট ফন্ট ওয়েট (ডিফল্ট `FontWeight.w700`)।
  final FontWeight headingWeight;

  /// সব বাটন, কার্ড ও ইনপুটের কর্নার রেডিয়াস (`null` হলে [style] বা টিয়ার অনুযায়ী অটো)।
  final double? borderRadius;

  /// সব `TextField` / `TextFormField`-এর গ্লোবাল স্টাইল ভ্যারিয়েন্ট (না দিলে [style] অনুযায়ী)।
  final OmniInputVariant? inputVariant;

  /// সাধারণ অবস্থায় ইনপুট ফিল্ড, চিপ ও আউটলাইন বাটনের বর্ডারের পুরুত্ব (না দিলে [style] অনুযায়ী)।
  final double? borderWidth;

  /// ইনপুট ফিল্ড ফোকাস বা এরর অবস্থায় বর্ডারের পুরুত্ব (না দিলে [style] অনুযায়ী)।
  final double? focusedBorderWidth;

  /// কার্ডের চারদিকের বর্ডারের পুরুত্ব (`0` দিলে বর্ডার ছাড়া কার্ড হয়; না দিলে [style] অনুযায়ী)।
  final double? cardBorderWidth;

  /// লাইট মোডে `Scaffold` / পেজের মূল ব্যাকগ্রাউন্ড কালার (`OmniColors.surfaceColor`)।
  final Color? surfaceColor;

  /// ডার্ক মোডে `Scaffold` / পেজের মূল ব্যাকগ্রাউন্ড কালার।
  final Color? darkSurfaceColor;

  /// লাইট মোডে সেকশন/কোড বক্স/অল্টারনেটিং রো-এর দ্বিতীয় ব্যাকগ্রাউন্ড কালার (`OmniColors.secondaryBackgroundColor`)।
  final Color? secondaryBackgroundColor;

  /// ডার্ক মোডে সেকশন/কোড বক্সের দ্বিতীয় ব্যাকগ্রাউন্ড কালার।
  final Color? darkSecondaryBackgroundColor;

  /// [surfaceColor]-এর পুরোনো বিকল্প নাম (Scaffold ব্যাকগ্রাউন্ড ওভাররাইড)।
  final Color? scaffoldBackgroundColor;

  /// [darkSurfaceColor]-এর পুরোনো বিকল্প নাম।
  final Color? darkScaffoldBackgroundColor;

  /// লাইট মোডে কার্ড, ডায়ালগ ও বক্সের কালার (`OmniColors.cardColor`)।
  final Color? cardColor;

  /// ডার্ক মোডে কার্ড, ডায়ালগ ও বক্সের কালার।
  final Color? darkCardColor;

  /// উপরের `AppBar`-এর ব্যাকগ্রাউন্ড কালার (`OmniColors.appBarColor`)।
  final Color? appBarColor;

  /// `AppBar`-এর টাইটেল ও আইকনের কালার (`OmniColors.appBarTextColor`)।
  final Color? appBarTextColor;

  /// নিচের নেভিগেশন বার ও সাইড রেলের ব্যাকগ্রাউন্ড কালার (`OmniColors.navBarColor`)।
  final Color? navBarColor;

  /// নেভিগেশন বারে সিলেক্ট করা ট্যাবের আইকন ও টেক্সট কালার (`OmniColors.navSelectedColor`)।
  final Color? navSelectedColor;

  /// নেভিগেশন বারে আন-সিলেক্টেড ট্যাবের আইকন ও টেক্সট কালার (`OmniColors.navUnselectedColor`)।
  final Color? navUnselectedColor;

  /// প্রাইমারি বাটনের ব্যাকগ্রাউন্ড কালার (`OmniColors.buttonColor`)।
  final Color? buttonColor;

  /// প্রাইমারি বাটনের ভেতরের টেক্সট কালার (`OmniColors.buttonTextColor`)।
  final Color? buttonTextColor;

  /// সেকেন্ডারি বাটনের ("Cancel", "Back", "Skip") ব্যাকগ্রাউন্ড কালার (`OmniColors.secondaryButtonColor`)।
  final Color? secondaryButtonColor;

  /// সেকেন্ডারি বাটনের ভেতরের টেক্সট ও আইকন কালার (`OmniColors.secondaryButtonTextColor`)।
  final Color? secondaryButtonTextColor;

  /// ডেঞ্জার/ডিলিট বাটনের ("Delete", "Remove", "Logout") ব্যাকগ্রাউন্ড কালার (`OmniColors.dangerButtonColor`)।
  final Color? dangerButtonColor;

  /// ডেঞ্জার/ডিলিট বাটনের ভেতরের টেক্সট ও আইকন কালার (`OmniColors.dangerButtonTextColor`)।
  final Color? dangerButtonTextColor;

  /// ক্লিকেবল টেক্সট লিংক ও টেক্সট বাটনের রঙ (`OmniColors.linkColor`)।
  final Color? linkColor;

  /// সাধারণ কার্ড/ইনপুটের বর্ডার কালার (`OmniColors.borderColor`)।
  final Color? borderColor;

  /// ইনপুট ফোকাস হলে বর্ডার কালার (`OmniColors.focusedBorderColor`)।
  final Color? focusedBorderColor;

  /// তালিকা ও সেকশনের মাঝখানের ডিভাইডার লাইনের কালার (`OmniColors.dividerColor`)।
  final Color? dividerColor;

  /// টেক্সট ফিল্ডের ভেতরের ব্যাকগ্রাউন্ড কালার (`OmniColors.inputFillColor`)।
  final Color? inputFillColor;

  /// মূল হেডিং ও বডি লেখার রঙ (`OmniColors.textColor`)।
  final Color? textColor;

  /// সাবটাইটেল ও তুলনামূলক হালকা লেখার রঙ (`OmniColors.secondaryTextColor`)।
  final Color? secondaryTextColor;

  /// টেক্সট ফিল্ডের প্লেসহোল্ডার/হিন্ট লেখার রঙ (`OmniColors.hintTextColor`)।
  final Color? hintTextColor;

  /// সাধারণ UI আইকনের ডিফল্ট রঙ (`OmniColors.iconColor`)।
  final Color? iconColor;

  /// ট্যাগ, ফিল্টার ও ক্যাটাগরি চিপের ব্যাকগ্রাউন্ড কালার (`OmniColors.chipColor`)।
  final Color? chipColor;

  /// ট্যাগ/চিপের ভেতরের টেক্সট কালার (`OmniColors.chipTextColor`)।
  final Color? chipTextColor;

  /// নোটিফিকেশন/কাউন্টার ব্যাজের ব্যাকগ্রাউন্ড কালার (`OmniColors.badgeColor`)।
  final Color? badgeColor;

  /// নোটিফিকেশন/কাউন্টার ব্যাজের ভেতরের টেক্সট কালার (`OmniColors.badgeTextColor`)।
  final Color? badgeTextColor;

  /// সিলেক্ট করা তালিকা আইটেম বা অ্যাক্টিভ রো-এর হালকা হাইলাইট রঙ (`OmniColors.selectedItemColor`)।
  final Color? selectedItemColor;

  /// ডেস্কটপ/ওয়েবে মাউস হোভার বা প্রেস হাইলাইট রঙ (`OmniColors.hoverColor`)।
  final Color? hoverColor;

  /// বাটন বা কার্ডে ট্যাপ করলে ছড়িয়ে পড়া রিপল/স্প্ল্যাশ কালার (`OmniColors.rippleColor`)।
  final Color? rippleColor;

  /// নিষ্ক্রিয় (disabled) বাটন/ইনপুটের ব্যাকগ্রাউন্ড কালার (`OmniColors.disabledColor`)।
  final Color? disabledColor;

  /// নিষ্ক্রিয় (disabled) বাটন/ইনপুটের টেক্সট কালার (`OmniColors.disabledTextColor`)।
  final Color? disabledTextColor;

  /// নিষ্ক্রিয় (disabled) ইনপুট বা আউটলাইন বাটনের বর্ডার কালার (`OmniColors.disabledBorderColor`)।
  final Color? disabledBorderColor;

  /// `Switch`, `Checkbox`, ও `Radio` চালু অবস্থার রঙ (`OmniColors.switchActiveColor`)।
  final Color? switchActiveColor;

  /// `Switch`, `Checkbox`, ও স্লাইডার বন্ধ অবস্থার রঙ (`OmniColors.switchInactiveColor`)।
  final Color? switchInactiveColor;

  /// `SnackBar` / টোস্টের ব্যাকগ্রাউন্ড কালার (`OmniColors.snackbarColor`)।
  final Color? snackbarColor;

  /// `SnackBar` / টোস্টের ভেতরের লেখার কালার (`OmniColors.snackbarTextColor`)।
  final Color? snackbarTextColor;

  /// `Tooltip` পপআপ বক্সের ব্যাকগ্রাউন্ড কালার (`OmniColors.tooltipColor`)।
  final Color? tooltipColor;

  /// `Tooltip` পপআপের ভেতরের লেখার কালার (`OmniColors.tooltipTextColor`)।
  final Color? tooltipTextColor;

  /// এরর ও ভুল ভ্যালিডেশনের লাল কালার (`OmniColors.errorColor`)।
  final Color? errorColor;

  /// সতর্কতা ও পেন্ডিং অবস্থার ওয়ার্নিং কালার (`OmniColors.warningColor`)।
  final Color? warningColor;

  /// সফল ও ভেরিফাইড অবস্থার সাকসেস কালার (`OmniColors.successColor`)।
  final Color? successColor;

  /// তথ্যমূলক ব্যানার ও টিপসের ইনফো কালার (`OmniColors.infoColor`)।
  final Color? infoColor;

  /// লোডিং শিমার/স্কেলেটন প্লেসহোল্ডারের বেস কালার (`OmniColors.shimmerBaseColor`)।
  final Color? shimmerBaseColor;

  /// লোডিং শিমার অ্যানিমেশনের উজ্জ্বল হাইলাইট কালার (`OmniColors.shimmerHighlightColor`)।
  final Color? shimmerHighlightColor;

  /// ডায়ালগ বা বটমশিটের পেছনের স্ক্রিন ঢেকে দেওয়ার ওভারলে কালার (`OmniColors.overlayColor`)।
  final Color? overlayColor;

  /// কার্ড ও ফ্লোটিং বাটনের ড্রপ শ্যাডো রঙ (`OmniColors.shadowColor`)।
  final Color? shadowColor;

  /// লাইট মোডের জন্য সম্পূর্ণ কাস্টম [OmniColors] প্যালেট (ঐচ্ছিক)।
  final OmniColors? lightColors;

  /// ডার্ক মোডের জন্য সম্পূর্ণ কাস্টম [OmniColors] প্যালেট (ঐচ্ছিক)।
  final OmniColors? darkColors;

  /// কার্ডের শ্যাডো উচ্চতা (না দিলে [style] অনুযায়ী অটো)।
  final double? cardElevation;

  /// সব `AppBar`-এ টাইটেল সেন্টারে রাখবে কি না।
  final bool? appBarCenterTitle;

  /// অ্যাপের সিস্টেম বার ও ফুলস্ক্রিন ডিসপ্লে মোড (ডিফল্ট [OmniScreenMode.edgeToEdge])।
  final OmniScreenMode screenMode;

  /// উপরের সিস্টেম স্ট্যাটাস বারের আলাদা স্টাইল ও রঙ ([OmniStatusBarStyle])।
  ///
  /// এখান থেকে সেট করলে অ্যাপের **প্রতিটি স্ক্রিনে** (অ্যাপবারসহ বা অ্যাপবার ছাড়া)
  /// আলাদা কোড ছাড়াই স্বয়ংক্রিয়ভাবে প্রযোজ্য হয়।
  final OmniStatusBarStyle? statusBar;

  /// নিচের সিস্টেম নেভিগেশন ও গেস্টচার সোয়াইপ বারের আলাদা স্টাইল ও রঙ
  /// ([OmniSystemNavigationBarStyle])।
  ///
  /// গেস্টচার সোয়াইপ পিল/ডটের নিচের কালো এরিয়া দূর করে অ্যাপের প্রতিটি স্ক্রিনে
  /// থিমের সাথে মসৃণভাবে মিশিয়ে দেয়।
  final OmniSystemNavigationBarStyle? systemNavigationBar;

  /// ডার্ক/লাইট মোড ও কালার প্যালেট বদলানোর সময় পুরো স্ক্রিনের ট্রানজিশন অ্যানিমেশন।
  final OmniThemeAnimation animation;

  /// সব প্রি-ডিফাইনড ইনপুট ফিল্ডের (`OmniEmailField`, `OmniPasswordField`, `OmniOtpField`
  /// ইত্যাদি) জন্য একটি শেয়ার্ড থিম (না দিলে [OmniTheme] ও `context.ui` থেকে অটো)।
  final OmniFieldTheme? fieldTheme;

  /// যেকোনো থিম উপাদান (`Switch`, `Chip`, `BottomSheet`) আরও কাস্টম করার হুক।
  final OmniThemeCustomizer? customizer;

  /// পিকারের জন্য রঙের স্যাম্পল রিটার্ন করে।
  Color get swatchColor =>
      previewColor ??
      light?.primaryColor ??
      lightColors?.primaryColor ??
      seedColor;

  /// প্রদত্ত [brightness] (লাইট বা ডার্ক) অনুযায়ী প্যালেট সওয়াচ ডটের রঙ রিটার্ন করে।
  Color swatchColorFor(Brightness brightness) {
    if (previewColor case final p?) return p;
    final isDark = brightness == Brightness.dark;
    return isDark
        ? (darkColors?.primaryColor ??
            dark?.primaryColor ??
            darkSeedColor ??
            light?.primaryColor ??
            seedColor)
        : (lightColors?.primaryColor ?? light?.primaryColor ?? seedColor);
  }

  /// [OmniTheme] ও ঐচ্ছিক রানটাইম [styleOverride] মিলিয়ে কার্যকর ইনপুট ভ্যারিয়েন্ট।
  OmniInputVariant effectiveInputVariant([OmniThemeStyle? styleOverride]) =>
      styleOverride?.inputVariant ?? inputVariant ?? style.inputVariant;

  /// কার্যকর বর্ডার পুরুত্ব।
  double effectiveBorderWidth([OmniThemeStyle? styleOverride]) =>
      styleOverride?.borderWidth ?? borderWidth ?? style.borderWidth;

  /// কার্যকর ফোকাস বর্ডার পুরুত্ব।
  double effectiveFocusedBorderWidth([OmniThemeStyle? styleOverride]) =>
      styleOverride?.focusedBorderWidth ??
      focusedBorderWidth ??
      style.focusedBorderWidth;

  /// কার্যকর কার্ড বর্ডার পুরুত্ব।
  double effectiveCardBorderWidth([OmniThemeStyle? styleOverride]) =>
      styleOverride?.cardBorderWidth ?? cardBorderWidth ?? style.cardBorderWidth;

  /// কার্যকর কার্ড এলিভেশন।
  double effectiveCardElevation([OmniThemeStyle? styleOverride]) =>
      styleOverride?.cardElevation ?? cardElevation ?? style.cardElevation;

  /// কার্যকর কর্নার রেডিয়াস (`null` হলে ডিভাইস টিয়ার অনুযায়ী অটো)।
  double? effectiveBorderRadius([OmniThemeStyle? styleOverride]) =>
      styleOverride != null
          ? (styleOverride.borderRadius ?? borderRadius)
          : (borderRadius ?? style.borderRadius);

  /// বর্তমান থিম ও [colors] অনুযায়ী ওপরের সিস্টেম স্ট্যাটাস বারের স্টাইল দেয়।
  OmniStatusBarStyle resolveStatusBar(OmniColors colors) {
    final explicit = statusBar;
    if (explicit != null) return explicit;
    return OmniStatusBarStyle(
      color: colors.statusBarColor,
      darkColor: colors.statusBarColor,
    );
  }

  /// বর্তমান থিম ও [colors] অনুযায়ী নিচের সিস্টেম নেভিগেশন/গেস্টচার বারের স্টাইল দেয়।
  OmniSystemNavigationBarStyle resolveSystemNavigationBar(OmniColors colors) {
    final explicit = systemNavigationBar;
    if (explicit != null) return explicit;
    return OmniSystemNavigationBarStyle(
      color: colors.systemNavigationBarColor,
      darkColor: colors.systemNavigationBarColor,
    );
  }

  // ── রেডিমেড মাল্টি-প্যালেট প্রিসেট (১-ক্লিকে পুরো অ্যাপের কালার প্যালেট বদলানোর জন্য) ──

  /// সমুদ্র নীল প্রিসেট প্যালেট (`id: 'ocean'`)।
  static const ocean = OmniTheme(
    id: 'ocean',
    name: 'Ocean',
    seedColor: Color(0xFF2563EB),
    secondaryColor: Color(0xFF0EA5E9),
    dark: OmniColorPalette(
      primaryColor: Color(0xFF3B82F6),
      secondaryColor: Color(0xFF38BDF8),
    ),
  );

  /// সবুজ প্রকৃতি প্রিসেট প্যালেট (`id: 'emerald'`)।
  static const emerald = OmniTheme(
    id: 'emerald',
    name: 'Emerald',
    seedColor: Color(0xFF059669),
    secondaryColor: Color(0xFF14B8A6),
    dark: OmniColorPalette(
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF2DD4BF),
    ),
  );

  /// রাজকীয় বেগুনি প্রিসেট প্যালেট (`id: 'violet'`)।
  static const violet = OmniTheme(
    id: 'violet',
    name: 'Violet',
    seedColor: Color(0xFF7C3AED),
    secondaryColor: Color(0xFFA855F7),
    dark: OmniColorPalette(
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFFC084FC),
    ),
  );

  /// সোনালি কমলা প্রিসেট প্যালেট (`id: 'sunset'`)।
  static const sunset = OmniTheme(
    id: 'sunset',
    name: 'Sunset',
    seedColor: Color(0xFFEA580C),
    secondaryColor: Color(0xFFF59E0B),
    dark: OmniColorPalette(
      primaryColor: Color(0xFFF97316),
      secondaryColor: Color(0xFFFBBF24),
    ),
  );

  /// গোলাপি বেরি প্রিসেট প্যালেট (`id: 'rose'`)।
  static const rose = OmniTheme(
    id: 'rose',
    name: 'Rose',
    seedColor: Color(0xFFE11D48),
    secondaryColor: Color(0xFFEC4899),
    dark: OmniColorPalette(
      primaryColor: Color(0xFFF43F5E),
      secondaryColor: Color(0xFFF472B6),
    ),
  );

  /// নীলচে-সবুজ টিল প্রিসেট প্যালেট (`id: 'teal'`)।
  static const teal = OmniTheme(
    id: 'teal',
    name: 'Teal',
    seedColor: Color(0xFF0D9488),
    secondaryColor: Color(0xFF06B6D4),
    dark: OmniColorPalette(
      primaryColor: Color(0xFF14B8A6),
      secondaryColor: Color(0xFF22D3EE),
    ),
  );

  /// উষ্ণ সোনালি অ্যাম্বার প্রিসেট প্যালেট (`id: 'amber'`)।
  static const amber = OmniTheme(
    id: 'amber',
    name: 'Amber',
    seedColor: Color(0xFFD97706),
    secondaryColor: Color(0xFFEA580C),
    dark: OmniColorPalette(
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFFB923C),
    ),
  );

  /// কর্পোরেট স্লেট-ইন্ডিগো প্রিসেট প্যালেট (`id: 'slate'`)।
  static const slate = OmniTheme(
    id: 'slate',
    name: 'Slate',
    seedColor: Color(0xFF475569),
    secondaryColor: Color(0xFF6366F1),
    dark: OmniColorPalette(
      primaryColor: Color(0xFF94A3B8),
      secondaryColor: Color(0xFF818CF8),
      buttonTextColor: Color(0xFF0F172A),
    ),
  );

  /// গভীর ইন্ডিগো-স্কাই প্রিসেট প্যালেট (`id: 'indigo'`)।
  static const indigo = OmniTheme(
    id: 'indigo',
    name: 'Indigo',
    seedColor: Color(0xFF4F46E5),
    secondaryColor: Color(0xFF0EA5E9),
    dark: OmniColorPalette(
      primaryColor: Color(0xFF818CF8),
      secondaryColor: Color(0xFF38BDF8),
      buttonTextColor: Color(0xFF0F172A),
    ),
  );

  /// গাঢ় ক্রিমসন-অরেঞ্জ প্রিসেট প্যালেট (`id: 'crimson'`)।
  static const crimson = OmniTheme(
    id: 'crimson',
    name: 'Crimson',
    seedColor: Color(0xFFDC2626),
    secondaryColor: Color(0xFFF97316),
    dark: OmniColorPalette(
      primaryColor: Color(0xFFF87171),
      secondaryColor: Color(0xFFFB923C),
      buttonTextColor: Color(0xFF18181B),
    ),
  );

  /// নিয়োন সাইবারপাঙ্ক ম্যাজেন্টা-সায়ান প্রিসেট প্যালেট (`id: 'cyberpunk'`)।
  static const cyberpunk = OmniTheme(
    id: 'cyberpunk',
    name: 'Neon Cyber',
    seedColor: Color(0xFFD946EF),
    secondaryColor: Color(0xFF06B6D4),
    dark: OmniColorPalette(
      primaryColor: Color(0xFFF472B6),
      secondaryColor: Color(0xFF22D3EE),
      surfaceColor: Color(0xFF090914),
      secondaryBackgroundColor: Color(0xFF121226),
      cardColor: Color(0xFF181832),
      buttonTextColor: Color(0xFF090914),
    ),
  );

  /// প্রাকৃতিক ফরেস্ট সবুজ প্রিসেট প্যালেট (`id: 'forest'`)।
  static const forest = OmniTheme(
    id: 'forest',
    name: 'Forest',
    seedColor: Color(0xFF15803D),
    secondaryColor: Color(0xFF65A30D),
    dark: OmniColorPalette(
      primaryColor: Color(0xFF4ADE80),
      secondaryColor: Color(0xFFA3E635),
      surfaceColor: Color(0xFF07130C),
      secondaryBackgroundColor: Color(0xFF0E2015),
      cardColor: Color(0xFF13291B),
      buttonTextColor: Color(0xFF052E16),
    ),
  );

  /// উষ্ণ এসপ্রেসো-কফি ওয়ার্ম প্যালেট (`id: 'coffee'`)।
  static const coffee = OmniTheme(
    id: 'coffee',
    name: 'Espresso',
    seedColor: Color(0xFF78350F),
    secondaryColor: Color(0xFFD97706),
    light: OmniColorPalette(
      surfaceColor: Color(0xFFFAF7F2),
      secondaryBackgroundColor: Color(0xFFF3ECE1),
    ),
    dark: OmniColorPalette(
      primaryColor: Color(0xFFFBBF24),
      secondaryColor: Color(0xFFF59E0B),
      surfaceColor: Color(0xFF140E0A),
      secondaryBackgroundColor: Color(0xFF1F1610),
      cardColor: Color(0xFF291D15),
      buttonTextColor: Color(0xFF1C1008),
    ),
  );

  /// নর্ডিক আইস-ব্লু মিনিমালিস্ট প্রিসেট প্যালেট (`id: 'nordic'`)।
  static const nordic = OmniTheme(
    id: 'nordic',
    name: 'Nordic Ice',
    seedColor: Color(0xFF0369A1),
    secondaryColor: Color(0xFF38BDF8),
    light: OmniColorPalette(
      surfaceColor: Color(0xFFF4F8FB),
      secondaryBackgroundColor: Color(0xFFE7EFF6),
    ),
    dark: OmniColorPalette(
      primaryColor: Color(0xFF7DD3FC),
      secondaryColor: Color(0xFF38BDF8),
      surfaceColor: Color(0xFF09121C),
      secondaryBackgroundColor: Color(0xFF0F1C2A),
      cardColor: Color(0xFF152536),
      buttonTextColor: Color(0xFF082F49),
    ),
  );

  /// রয়্যাল গোল্ড ও ডার্ক স্লেট প্রিসেট প্যালেট (`id: 'gold'`)।
  static const gold = OmniTheme(
    id: 'gold',
    name: 'Royal Gold',
    seedColor: Color(0xFFCA8A04),
    secondaryColor: Color(0xFF1E293B),
    dark: OmniColorPalette(
      primaryColor: Color(0xFFFACC15),
      secondaryColor: Color(0xFFCBD5E1),
      surfaceColor: Color(0xFF0E0D0A),
      secondaryBackgroundColor: Color(0xFF181611),
      cardColor: Color(0xFF211E17),
      buttonTextColor: Color(0xFF1C1917),
    ),
  );

  /// ক্লিন মনোক্রোম ও AMOLED ট্রু-ব্ল্যাক প্রিসেট প্যালেট (`id: 'monochrome'`)।
  static const monochrome = OmniTheme(
    id: 'monochrome',
    name: 'Monochrome',
    seedColor: Color(0xFF18181B),
    secondaryColor: Color(0xFF52525B),
    light: OmniColorPalette(
      primaryColor: Color(0xFF18181B),
      secondaryColor: Color(0xFF52525B),
      surfaceColor: Color(0xFFFAFAFA),
      secondaryBackgroundColor: Color(0xFFF4F4F5),
      cardColor: Color(0xFFFFFFFF),
      buttonColor: Color(0xFF18181B),
      buttonTextColor: Color(0xFFFFFFFF),
      secondaryButtonColor: Color(0xFFE4E4E7),
      secondaryButtonTextColor: Color(0xFF18181B),
    ),
    dark: OmniColorPalette(
      primaryColor: Color(0xFFF4F4F5),
      secondaryColor: Color(0xFFA1A1AA),
      surfaceColor: Color(0xFF000000),
      secondaryBackgroundColor: Color(0xFF09090B),
      cardColor: Color(0xFF18181B),
      appBarColor: Color(0xFF000000),
      navBarColor: Color(0xFF09090B),
      buttonColor: Color(0xFFFAFAFA),
      buttonTextColor: Color(0xFF09090B),
      secondaryButtonColor: Color(0xFF27272A),
      secondaryButtonTextColor: Color(0xFFFAFAFA),
    ),
  );

  /// ১৬টি রেডিমেড প্রোডাকশন কালার প্যালেটের বান্ডিল (`OmniApp.material(themes: OmniTheme.presets)`)।
  static const List<OmniTheme> presets = [
    ocean,
    emerald,
    violet,
    sunset,
    rose,
    teal,
    amber,
    slate,
    indigo,
    crimson,
    cyberpunk,
    forest,
    coffee,
    nordic,
    gold,
    monochrome,
  ];

  /// [id] দিয়ে রেডিমেড [presets] থেকে প্যালেট খুঁজে বের করে (না পেলে `null`)।
  static OmniTheme? findPreset(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// নির্দিষ্ট প্রোপার্টি বদলে নতুন [OmniTheme] কপি দেয়।
  OmniTheme copyWith({
    String? id,
    String? name,
    Color? previewColor,
    Color? seedColor,
    ThemeMode? mode,
    bool? persistMode,
    String? storageKey,
    OmniThemeController? controller,
    Color? darkSeedColor,
    Color? secondaryColor,
    Color? darkSecondaryColor,
    OmniColorPalette? light,
    OmniColorPalette? dark,
    OmniThemeStyle? style,
    bool? useMaterial3,
    String? fontFamily,
    FontWeight? headingWeight,
    double? borderRadius,
    OmniInputVariant? inputVariant,
    double? borderWidth,
    double? focusedBorderWidth,
    double? cardBorderWidth,
    Color? surfaceColor,
    Color? darkSurfaceColor,
    Color? secondaryBackgroundColor,
    Color? darkSecondaryBackgroundColor,
    Color? scaffoldBackgroundColor,
    Color? darkScaffoldBackgroundColor,
    Color? cardColor,
    Color? darkCardColor,
    Color? appBarColor,
    Color? appBarTextColor,
    Color? navBarColor,
    Color? navSelectedColor,
    Color? navUnselectedColor,
    Color? buttonColor,
    Color? buttonTextColor,
    Color? secondaryButtonColor,
    Color? secondaryButtonTextColor,
    Color? dangerButtonColor,
    Color? dangerButtonTextColor,
    Color? linkColor,
    Color? borderColor,
    Color? focusedBorderColor,
    Color? dividerColor,
    Color? inputFillColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? hintTextColor,
    Color? iconColor,
    Color? chipColor,
    Color? chipTextColor,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? selectedItemColor,
    Color? hoverColor,
    Color? rippleColor,
    Color? disabledColor,
    Color? disabledTextColor,
    Color? disabledBorderColor,
    Color? switchActiveColor,
    Color? switchInactiveColor,
    Color? snackbarColor,
    Color? snackbarTextColor,
    Color? tooltipColor,
    Color? tooltipTextColor,
    Color? errorColor,
    Color? warningColor,
    Color? successColor,
    Color? infoColor,
    Color? shimmerBaseColor,
    Color? shimmerHighlightColor,
    Color? overlayColor,
    Color? shadowColor,
    OmniColors? lightColors,
    OmniColors? darkColors,
    double? cardElevation,
    bool? appBarCenterTitle,
    OmniScreenMode? screenMode,
    OmniStatusBarStyle? statusBar,
    OmniSystemNavigationBarStyle? systemNavigationBar,
    OmniThemeAnimation? animation,
    OmniFieldTheme? fieldTheme,
    OmniThemeCustomizer? customizer,
  }) => OmniTheme(
    id: id ?? this.id,
    name: name ?? this.name,
    previewColor: previewColor ?? this.previewColor,
    seedColor: seedColor ?? this.seedColor,
    mode: mode ?? this.mode,
    persistMode: persistMode ?? this.persistMode,
    storageKey: storageKey ?? this.storageKey,
    controller: controller ?? this.controller,
    darkSeedColor: darkSeedColor ?? this.darkSeedColor,
    secondaryColor: secondaryColor ?? this.secondaryColor,
    darkSecondaryColor: darkSecondaryColor ?? this.darkSecondaryColor,
    light: light ?? this.light,
    dark: dark ?? this.dark,
    style: style ?? this.style,
    useMaterial3: useMaterial3 ?? this.useMaterial3,
    fontFamily: fontFamily ?? this.fontFamily,
    headingWeight: headingWeight ?? this.headingWeight,
    borderRadius: borderRadius ?? this.borderRadius,
    inputVariant: inputVariant ?? this.inputVariant,
    borderWidth: borderWidth ?? this.borderWidth,
    focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
    cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
    surfaceColor: surfaceColor ?? this.surfaceColor,
    darkSurfaceColor: darkSurfaceColor ?? this.darkSurfaceColor,
    secondaryBackgroundColor:
        secondaryBackgroundColor ?? this.secondaryBackgroundColor,
    darkSecondaryBackgroundColor:
        darkSecondaryBackgroundColor ?? this.darkSecondaryBackgroundColor,
    scaffoldBackgroundColor:
        scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
    darkScaffoldBackgroundColor:
        darkScaffoldBackgroundColor ?? this.darkScaffoldBackgroundColor,
    cardColor: cardColor ?? this.cardColor,
    darkCardColor: darkCardColor ?? this.darkCardColor,
    appBarColor: appBarColor ?? this.appBarColor,
    appBarTextColor: appBarTextColor ?? this.appBarTextColor,
    navBarColor: navBarColor ?? this.navBarColor,
    navSelectedColor: navSelectedColor ?? this.navSelectedColor,
    navUnselectedColor: navUnselectedColor ?? this.navUnselectedColor,
    buttonColor: buttonColor ?? this.buttonColor,
    buttonTextColor: buttonTextColor ?? this.buttonTextColor,
    secondaryButtonColor: secondaryButtonColor ?? this.secondaryButtonColor,
    secondaryButtonTextColor:
        secondaryButtonTextColor ?? this.secondaryButtonTextColor,
    dangerButtonColor: dangerButtonColor ?? this.dangerButtonColor,
    dangerButtonTextColor:
        dangerButtonTextColor ?? this.dangerButtonTextColor,
    linkColor: linkColor ?? this.linkColor,
    borderColor: borderColor ?? this.borderColor,
    focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
    dividerColor: dividerColor ?? this.dividerColor,
    inputFillColor: inputFillColor ?? this.inputFillColor,
    textColor: textColor ?? this.textColor,
    secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
    hintTextColor: hintTextColor ?? this.hintTextColor,
    iconColor: iconColor ?? this.iconColor,
    chipColor: chipColor ?? this.chipColor,
    chipTextColor: chipTextColor ?? this.chipTextColor,
    badgeColor: badgeColor ?? this.badgeColor,
    badgeTextColor: badgeTextColor ?? this.badgeTextColor,
    selectedItemColor: selectedItemColor ?? this.selectedItemColor,
    hoverColor: hoverColor ?? this.hoverColor,
    rippleColor: rippleColor ?? this.rippleColor,
    disabledColor: disabledColor ?? this.disabledColor,
    disabledTextColor: disabledTextColor ?? this.disabledTextColor,
    disabledBorderColor: disabledBorderColor ?? this.disabledBorderColor,
    switchActiveColor: switchActiveColor ?? this.switchActiveColor,
    switchInactiveColor: switchInactiveColor ?? this.switchInactiveColor,
    snackbarColor: snackbarColor ?? this.snackbarColor,
    snackbarTextColor: snackbarTextColor ?? this.snackbarTextColor,
    tooltipColor: tooltipColor ?? this.tooltipColor,
    tooltipTextColor: tooltipTextColor ?? this.tooltipTextColor,
    errorColor: errorColor ?? this.errorColor,
    warningColor: warningColor ?? this.warningColor,
    successColor: successColor ?? this.successColor,
    infoColor: infoColor ?? this.infoColor,
    shimmerBaseColor: shimmerBaseColor ?? this.shimmerBaseColor,
    shimmerHighlightColor:
        shimmerHighlightColor ?? this.shimmerHighlightColor,
    overlayColor: overlayColor ?? this.overlayColor,
    shadowColor: shadowColor ?? this.shadowColor,
    lightColors: lightColors ?? this.lightColors,
    darkColors: darkColors ?? this.darkColors,
    cardElevation: cardElevation ?? this.cardElevation,
    appBarCenterTitle: appBarCenterTitle ?? this.appBarCenterTitle,
    screenMode: screenMode ?? this.screenMode,
    statusBar: statusBar ?? this.statusBar,
    systemNavigationBar: systemNavigationBar ?? this.systemNavigationBar,
    animation: animation ?? this.animation,
    fieldTheme: fieldTheme ?? this.fieldTheme,
    customizer: customizer ?? this.customizer,
  );

  /// [brightness]-এর জন্য কার্যকর [OmniColors] তৈরি করে।
  OmniColors resolveColors(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final explicit = isDark ? darkColors : lightColors;
    if (explicit != null) return explicit;

    final p = isDark ? dark : light;
    return OmniColors.fromSeed(
      primaryColor: p?.primaryColor ??
          (isDark ? (darkSeedColor ?? seedColor) : seedColor),
      brightness: brightness,
      secondaryColor: p?.secondaryColor ??
          (isDark ? (darkSecondaryColor ?? secondaryColor) : secondaryColor),
      surfaceColor: p?.surfaceColor ??
          (isDark
              ? (darkSurfaceColor ?? darkScaffoldBackgroundColor)
              : (surfaceColor ?? scaffoldBackgroundColor)),
      secondaryBackgroundColor: p?.secondaryBackgroundColor ??
          (isDark ? darkSecondaryBackgroundColor : secondaryBackgroundColor),
      cardColor: p?.cardColor ?? (isDark ? darkCardColor : cardColor),
      appBarColor: p?.appBarColor ?? appBarColor,
      appBarTextColor: p?.appBarTextColor ?? appBarTextColor,
      navBarColor: p?.navBarColor ?? navBarColor,
      navSelectedColor: p?.navSelectedColor ?? navSelectedColor,
      navUnselectedColor: p?.navUnselectedColor ?? navUnselectedColor,
      buttonColor: p?.buttonColor ?? buttonColor,
      buttonTextColor: p?.buttonTextColor ?? buttonTextColor,
      secondaryButtonColor: p?.secondaryButtonColor ?? secondaryButtonColor,
      secondaryButtonTextColor:
          p?.secondaryButtonTextColor ?? secondaryButtonTextColor,
      dangerButtonColor: p?.dangerButtonColor ?? dangerButtonColor,
      dangerButtonTextColor: p?.dangerButtonTextColor ?? dangerButtonTextColor,
      linkColor: p?.linkColor ?? linkColor,
      inputFillColor: p?.inputFillColor ?? inputFillColor,
      borderColor: p?.borderColor ?? borderColor,
      focusedBorderColor: p?.focusedBorderColor ?? focusedBorderColor,
      dividerColor: p?.dividerColor ?? dividerColor,
      textColor: p?.textColor ?? textColor,
      secondaryTextColor: p?.secondaryTextColor ?? secondaryTextColor,
      hintTextColor: p?.hintTextColor ?? hintTextColor,
      iconColor: p?.iconColor ?? iconColor,
      chipColor: p?.chipColor ?? chipColor,
      chipTextColor: p?.chipTextColor ?? chipTextColor,
      badgeColor: p?.badgeColor ?? badgeColor,
      badgeTextColor: p?.badgeTextColor ?? badgeTextColor,
      selectedItemColor: p?.selectedItemColor ?? selectedItemColor,
      hoverColor: p?.hoverColor ?? hoverColor,
      rippleColor: p?.rippleColor ?? rippleColor,
      disabledColor: p?.disabledColor ?? disabledColor,
      disabledTextColor: p?.disabledTextColor ?? disabledTextColor,
      disabledBorderColor: p?.disabledBorderColor ?? disabledBorderColor,
      switchActiveColor: p?.switchActiveColor ?? switchActiveColor,
      switchInactiveColor: p?.switchInactiveColor ?? switchInactiveColor,
      snackbarColor: p?.snackbarColor ?? snackbarColor,
      snackbarTextColor: p?.snackbarTextColor ?? snackbarTextColor,
      tooltipColor: p?.tooltipColor ?? tooltipColor,
      tooltipTextColor: p?.tooltipTextColor ?? tooltipTextColor,
      errorColor: p?.errorColor ?? errorColor,
      errorBackgroundColor: p?.errorBackgroundColor,
      warningColor: p?.warningColor ?? warningColor,
      warningBackgroundColor: p?.warningBackgroundColor,
      successColor: p?.successColor ?? successColor,
      successBackgroundColor: p?.successBackgroundColor,
      infoColor: p?.infoColor ?? infoColor,
      infoBackgroundColor: p?.infoBackgroundColor,
      shimmerBaseColor: p?.shimmerBaseColor ?? shimmerBaseColor,
      shimmerHighlightColor:
          p?.shimmerHighlightColor ?? shimmerHighlightColor,
      overlayColor: p?.overlayColor ?? overlayColor,
      shadowColor: p?.shadowColor ?? shadowColor,
      statusBarColor: p?.statusBarColor ?? statusBar?.resolveColor(brightness),
      systemNavigationBarColor:
          p?.systemNavigationBarColor ??
          systemNavigationBar?.resolveColor(brightness),
    );
  }

  /// [device], [tokens], [brightness] এবং ঐচ্ছিক [styleOverride] অনুযায়ী সম্পূর্ণ
  /// Material [ThemeData] তৈরি করে (`Scaffold`, `Button`, `TextField`, `Card`, `Dialog`,
  /// `NavigationBar`, `Switch`, `Checkbox`, `Tooltip`, `SnackBar`, [OmniColors],
  /// [OmniTextStyles] এবং [OmniStyles]সহ)।
  ThemeData resolve({
    required OmniDeviceType device,
    required OmniResponsiveTokens tokens,
    required Brightness brightness,
    OmniThemeStyle? styleOverride,
    OmniScreenMode? screenModeOverride,
    OmniStatusBarStyle? statusBarOverride,
    OmniSystemNavigationBarStyle? systemNavigationBarOverride,
  }) {
    final colors = resolveColors(brightness);
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primaryColor,
      brightness: brightness,
      primary: colors.primaryColor,
      onPrimary: colors.buttonTextColor,
      secondary: colors.secondaryColor,
      error: colors.errorColor,
      surface: colors.cardColor,
      onSurface: colors.textColor,
      onSurfaceVariant: colors.secondaryTextColor,
      outline: colors.borderColor,
      outlineVariant: colors.dividerColor,
    );

    final isDesktop =
        device == OmniDeviceType.desktop ||
        device == OmniDeviceType.largeDesktop;

    final effRadius = effectiveBorderRadius(styleOverride);
    final effInputVariant = effectiveInputVariant(styleOverride);
    final effBorderWidth = effectiveBorderWidth(styleOverride);
    final effFocusedBorderWidth = effectiveFocusedBorderWidth(styleOverride);
    final effCardBorderWidth = effectiveCardBorderWidth(styleOverride);
    final effCardElevation = effectiveCardElevation(styleOverride);

    final cardRadius = effRadius != null
        ? BorderRadius.all(Radius.circular(effRadius))
        : tokens.cardBorderRadius;
    final buttonRadius = effRadius != null
        ? BorderRadius.all(Radius.circular(effRadius))
        : tokens.buttonBorderRadius;
    final dialogRadius = effRadius != null
        ? BorderRadius.all(Radius.circular(effRadius + 2))
        : tokens.dialogBorderRadius;

    final textStyles = OmniTextStyles.fromTheme(
      colors: colors,
      tokens: tokens,
      fontFamily: fontFamily,
      headingWeight: headingWeight,
    );
    final styles = OmniStyles.resolve(
      colors: colors,
      textStyles: textStyles,
      tokens: tokens,
      cardRadius: cardRadius,
      buttonRadius: buttonRadius,
      inputVariant: effInputVariant,
      borderWidth: effBorderWidth,
      focusedBorderWidth: effFocusedBorderWidth,
      cardBorderWidth: effCardBorderWidth,
    );
    final effStatusBar = statusBarOverride ?? resolveStatusBar(colors);
    final effNavBar =
        systemNavigationBarOverride ?? resolveSystemNavigationBar(colors);
    final effScreenMode = resolveEffectiveOmniScreenMode(
      screenModeOverride ?? screenMode,
      statusBar: effStatusBar,
      systemNavigationBar: effNavBar,
    );
    final appBarOverlayStyle = composeOmniSystemUiOverlayStyle(
      brightness: brightness,
      screenMode: effScreenMode,
      statusBar: effStatusBar,
      systemNavigationBar: effNavBar,
      fallbackTopBackground: colors.appBarColor,
      fallbackBottomBackground: colors.navBarColor,
    );

    final baseTheme = ThemeData(
      useMaterial3: useMaterial3,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: colors.surfaceColor,
      dividerColor: colors.dividerColor,
      hoverColor: colors.hoverColor,
      splashColor: colors.rippleColor,
      highlightColor: colors.hoverColor,
      disabledColor: colors.disabledColor,
      shadowColor: colors.shadowColor,
      iconTheme: IconThemeData(color: colors.iconColor),
      dividerTheme: DividerThemeData(color: colors.dividerColor, thickness: 1),
      visualDensity: isDesktop
          ? VisualDensity.compact
          : VisualDensity.standard,
      materialTapTargetSize: isDesktop
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.appBarColor,
        foregroundColor: colors.appBarTextColor,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: appBarOverlayStyle,
        elevation: 0,
        centerTitle: appBarCenterTitle,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: colors.selectedItemColor,
        selectedColor: colors.primaryColor,
        iconColor: colors.iconColor,
        textColor: colors.textColor,
      ),
      cardTheme: CardThemeData(
        color: colors.cardColor,
        shadowColor: colors.shadowColor,
        surfaceTintColor: Colors.transparent,
        elevation: effCardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: effCardBorderWidth > 0
              ? BorderSide(color: colors.borderColor, width: effCardBorderWidth)
              : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.cardColor,
        barrierColor: colors.overlayColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: dialogRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.cardColor,
        modalBackgroundColor: colors.cardColor,
        modalBarrierColor: colors.overlayColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: dialogRadius.topLeft),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.navBarColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.selectedItemColor,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.navSelectedColor
                : colors.navUnselectedColor,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textStyles.caption.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colors.navSelectedColor
                : colors.navUnselectedColor,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.navBarColor,
        indicatorColor: colors.selectedItemColor,
        selectedIconTheme: IconThemeData(color: colors.navSelectedColor),
        unselectedIconTheme: IconThemeData(color: colors.navUnselectedColor),
        selectedLabelTextStyle: textStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: colors.navSelectedColor,
        ),
        unselectedLabelTextStyle: textStyles.caption.copyWith(
          color: colors.navUnselectedColor,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.chipColor,
        selectedColor: colors.selectedItemColor,
        disabledColor: colors.disabledColor,
        labelStyle: textStyles.label.copyWith(color: colors.chipTextColor),
        secondaryLabelStyle: textStyles.label.copyWith(
          color: colors.primaryColor,
        ),
        side: effBorderWidth > 0
            ? BorderSide(color: colors.borderColor, width: effBorderWidth)
            : BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledTextColor
              : states.contains(WidgetState.selected)
                  ? colors.buttonTextColor
                  : colors.switchInactiveColor,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledColor
              : states.contains(WidgetState.selected)
                  ? colors.switchActiveColor
                  : colors.secondaryBackgroundColor,
        ),
        trackOutlineColor: WidgetStatePropertyAll(colors.borderColor),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledColor
              : states.contains(WidgetState.selected)
                  ? colors.switchActiveColor
                  : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(colors.buttonTextColor),
        side: BorderSide(
          color: colors.borderColor,
          width: effBorderWidth > 0 ? effBorderWidth : 1.5,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.disabledTextColor
              : states.contains(WidgetState.selected)
                  ? colors.switchActiveColor
                  : colors.switchInactiveColor,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.snackbarColor,
        contentTextStyle: textStyles.body.copyWith(
          color: colors.snackbarTextColor,
        ),
        actionTextColor:
            isDark ? colors.primaryColor : colors.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.tooltipColor,
          borderRadius: BorderRadius.all(
            Radius.circular(((effRadius ?? tokens.buttonRadius) / 2).clamp(4, 12)),
          ),
        ),
        textStyle: textStyles.caption.copyWith(color: colors.tooltipTextColor),
      ),
      inputDecorationTheme: styles.inputDecorationTheme,
      filledButtonTheme: FilledButtonThemeData(style: styles.primaryButton),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.buttonColor,
          foregroundColor: colors.buttonTextColor,
          disabledBackgroundColor: colors.disabledColor,
          disabledForegroundColor: colors.disabledTextColor,
          minimumSize: Size(0, tokens.minTapTarget),
          textStyle: textStyles.button,
          shape: RoundedRectangleBorder(borderRadius: buttonRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: styles.outlineButton),
      textButtonTheme: TextButtonThemeData(style: styles.linkButton),
      extensions: <ThemeExtension<dynamic>>[
        colors,
        textStyles,
        styles,
        ?fieldTheme,
      ],
    );

    final baseText = baseTheme.textTheme;
    final scaledText = baseText.copyWith(
      displayLarge: textStyles.display.copyWith(
        fontSize: tokens.displaySize + 8,
      ),
      displayMedium: textStyles.display,
      headlineMedium: textStyles.heading,
      titleLarge: textStyles.title.copyWith(fontSize: tokens.titleSize + 2),
      titleMedium: textStyles.title,
      titleSmall: textStyles.subtitle,
      bodyLarge: textStyles.body.copyWith(fontSize: tokens.bodySize + 1),
      bodyMedium: textStyles.body,
      bodySmall: textStyles.caption,
      labelLarge: textStyles.button,
      labelMedium: textStyles.label,
      labelSmall: textStyles.caption,
    );

    final themed = baseTheme.copyWith(textTheme: scaledText);
    return customizer != null ? customizer!(themed, device, tokens) : themed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniTheme &&
          id == other.id &&
          name == other.name &&
          previewColor == other.previewColor &&
          seedColor == other.seedColor &&
          mode == other.mode &&
          persistMode == other.persistMode &&
          storageKey == other.storageKey &&
          identical(controller, other.controller) &&
          darkSeedColor == other.darkSeedColor &&
          secondaryColor == other.secondaryColor &&
          darkSecondaryColor == other.darkSecondaryColor &&
          light == other.light &&
          dark == other.dark &&
          style == other.style &&
          useMaterial3 == other.useMaterial3 &&
          fontFamily == other.fontFamily &&
          headingWeight == other.headingWeight &&
          borderRadius == other.borderRadius &&
          inputVariant == other.inputVariant &&
          borderWidth == other.borderWidth &&
          focusedBorderWidth == other.focusedBorderWidth &&
          cardBorderWidth == other.cardBorderWidth &&
          surfaceColor == other.surfaceColor &&
          darkSurfaceColor == other.darkSurfaceColor &&
          secondaryBackgroundColor == other.secondaryBackgroundColor &&
          darkSecondaryBackgroundColor == other.darkSecondaryBackgroundColor &&
          scaffoldBackgroundColor == other.scaffoldBackgroundColor &&
          darkScaffoldBackgroundColor == other.darkScaffoldBackgroundColor &&
          cardColor == other.cardColor &&
          darkCardColor == other.darkCardColor &&
          appBarColor == other.appBarColor &&
          appBarTextColor == other.appBarTextColor &&
          navBarColor == other.navBarColor &&
          navSelectedColor == other.navSelectedColor &&
          navUnselectedColor == other.navUnselectedColor &&
          buttonColor == other.buttonColor &&
          buttonTextColor == other.buttonTextColor &&
          secondaryButtonColor == other.secondaryButtonColor &&
          secondaryButtonTextColor == other.secondaryButtonTextColor &&
          dangerButtonColor == other.dangerButtonColor &&
          dangerButtonTextColor == other.dangerButtonTextColor &&
          linkColor == other.linkColor &&
          borderColor == other.borderColor &&
          focusedBorderColor == other.focusedBorderColor &&
          dividerColor == other.dividerColor &&
          inputFillColor == other.inputFillColor &&
          textColor == other.textColor &&
          secondaryTextColor == other.secondaryTextColor &&
          hintTextColor == other.hintTextColor &&
          iconColor == other.iconColor &&
          chipColor == other.chipColor &&
          chipTextColor == other.chipTextColor &&
          badgeColor == other.badgeColor &&
          badgeTextColor == other.badgeTextColor &&
          selectedItemColor == other.selectedItemColor &&
          hoverColor == other.hoverColor &&
          rippleColor == other.rippleColor &&
          disabledColor == other.disabledColor &&
          disabledTextColor == other.disabledTextColor &&
          disabledBorderColor == other.disabledBorderColor &&
          switchActiveColor == other.switchActiveColor &&
          switchInactiveColor == other.switchInactiveColor &&
          snackbarColor == other.snackbarColor &&
          snackbarTextColor == other.snackbarTextColor &&
          tooltipColor == other.tooltipColor &&
          tooltipTextColor == other.tooltipTextColor &&
          errorColor == other.errorColor &&
          warningColor == other.warningColor &&
          successColor == other.successColor &&
          infoColor == other.infoColor &&
          shimmerBaseColor == other.shimmerBaseColor &&
          shimmerHighlightColor == other.shimmerHighlightColor &&
          overlayColor == other.overlayColor &&
          shadowColor == other.shadowColor &&
          lightColors == other.lightColors &&
          darkColors == other.darkColors &&
          cardElevation == other.cardElevation &&
          appBarCenterTitle == other.appBarCenterTitle &&
          screenMode == other.screenMode &&
          statusBar == other.statusBar &&
          systemNavigationBar == other.systemNavigationBar &&
          animation == other.animation &&
          fieldTheme == other.fieldTheme &&
          customizer == other.customizer;

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    previewColor,
    seedColor,
    mode,
    persistMode,
    storageKey,
    controller,
    darkSeedColor,
    secondaryColor,
    darkSecondaryColor,
    light,
    dark,
    style,
    useMaterial3,
    fontFamily,
    headingWeight,
    borderRadius,
    inputVariant,
    borderWidth,
    focusedBorderWidth,
    cardBorderWidth,
    surfaceColor,
    darkSurfaceColor,
    secondaryBackgroundColor,
    darkSecondaryBackgroundColor,
    scaffoldBackgroundColor,
    darkScaffoldBackgroundColor,
    cardColor,
    darkCardColor,
    appBarColor,
    appBarTextColor,
    navBarColor,
    navSelectedColor,
    navUnselectedColor,
    buttonColor,
    buttonTextColor,
    secondaryButtonColor,
    secondaryButtonTextColor,
    dangerButtonColor,
    dangerButtonTextColor,
    linkColor,
    borderColor,
    focusedBorderColor,
    dividerColor,
    inputFillColor,
    textColor,
    secondaryTextColor,
    hintTextColor,
    iconColor,
    chipColor,
    chipTextColor,
    badgeColor,
    badgeTextColor,
    selectedItemColor,
    hoverColor,
    rippleColor,
    disabledColor,
    disabledTextColor,
    disabledBorderColor,
    switchActiveColor,
    switchInactiveColor,
    snackbarColor,
    snackbarTextColor,
    tooltipColor,
    tooltipTextColor,
    errorColor,
    warningColor,
    successColor,
    infoColor,
    shimmerBaseColor,
    shimmerHighlightColor,
    overlayColor,
    shadowColor,
    lightColors,
    darkColors,
    cardElevation,
    appBarCenterTitle,
    screenMode,
    statusBar,
    systemNavigationBar,
    animation,
    fieldTheme,
    customizer,
  ]);
}

enum _OmniThemeAspect { mode, activeTheme, style, animation, themes, catalog }

/// অ্যাস্পেক্ট-স্প্লিট `InheritedModel` যা পুরো অ্যাপে [OmniThemeController],
/// সক্রিয় থিম তালিকা, স্টাইল, অ্যানিমেশন ও মেমোইজড `lightTheme`/`darkTheme` পৌঁছে দেয়।
class OmniThemeScope extends InheritedModel<Object> {
  /// [OmniThemeScope] তৈরি করে।
  const OmniThemeScope({
    super.key,
    required this.controller,
    required this.selection,
    required this.activeTheme,
    required this.activeStyle,
    this.activeAnimationMode = OmniThemeAnimationMode.circularReveal,
    required this.availableThemes,
    required this.lightTheme,
    required this.darkTheme,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.linear,
    required super.child,
  });

  /// থিম, মোড, স্টাইল ও অ্যানিমেশন পরিবর্তনকারী কন্ট্রোলার।
  final OmniThemeController controller;

  /// বর্তমান `ThemeMode`, `themeId`, `style` ও `animationMode`।
  final OmniThemeSelection selection;

  /// বর্তমান সক্রিয় [OmniTheme]।
  final OmniTheme activeTheme;

  /// বর্তমান কার্যকর [OmniThemeStyle]।
  final OmniThemeStyle activeStyle;

  /// বর্তমান সক্রিয় [OmniThemeAnimationMode]।
  final OmniThemeAnimationMode activeAnimationMode;

  /// অ্যাপে রেজিস্ট্রিকৃত সব [OmniTheme]।
  final List<OmniTheme> availableThemes;

  /// বর্তমান ডিভাইস টিয়ার, সক্রিয় প্যালেট ও স্টাইলের মেমোইজড লাইট থিম।
  final ThemeData lightTheme;

  /// বর্তমান ডিভাইস টিয়ার, সক্রিয় প্যালেট ও স্টাইলের মেমোইজড ডার্ক থিম।
  final ThemeData darkTheme;

  /// সক্রিয় `MaterialApp.themeAnimationDuration` (কালার মর্ফ ও স্ন্যাপশট রিজলভারের সাথে সিঙ্কড)।
  final Duration animationDuration;

  /// সক্রিয় `MaterialApp.themeAnimationCurve`।
  final Curve animationCurve;

  /// নন-লিসেনিং O(1) লুকআপ (`onPressed` ও কলব্যাকে নিরাপদ)।
  static OmniThemeController? maybeControllerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OmniThemeScope>()?.controller;

  /// নন-লিসেনিং কন্ট্রোলার রিটার্ন করে (না পেলে থ্রো করে)।
  static OmniThemeController controllerOf(BuildContext context) =>
      maybeControllerOf(context) ??
      (throw FlutterError(
        'OmniTheme controller requested without OmniApp.material(omniTheme: ... or themes: ...).',
      ));

  /// কেবল `ThemeMode` পরিবর্তন হলেই রি-বিল্ড সাবস্ক্রিপশন নেয়।
  static ThemeMode modeOf(BuildContext context) {
    final scope = InheritedModel.inheritFrom<OmniThemeScope>(
      context,
      aspect: _OmniThemeAspect.mode,
    );
    return scope?.selection.mode ?? ThemeMode.system;
  }

  /// কেবল সক্রিয় থিম (`id`/`OmniTheme`) বদলালেই রি-বিল্ড হয়।
  static OmniTheme? activeThemeOf(BuildContext context) =>
      InheritedModel.inheritFrom<OmniThemeScope>(
        context,
        aspect: _OmniThemeAspect.activeTheme,
      )?.activeTheme;

  /// কেবল সক্রিয় ডিজাইন স্টাইল ([OmniThemeStyle]) বদলালেই রি-বিল্ড হয়।
  static OmniThemeStyle activeStyleOf(BuildContext context) =>
      InheritedModel.inheritFrom<OmniThemeScope>(
        context,
        aspect: _OmniThemeAspect.style,
      )?.activeStyle ??
      OmniThemeStyle.modern;

  /// কেবল সক্রিয় স্ক্রিন অ্যানিমেশন ([OmniThemeAnimationMode]) বদলালেই রি-বিল্ড হয়।
  static OmniThemeAnimationMode activeAnimationModeOf(BuildContext context) =>
      InheritedModel.inheritFrom<OmniThemeScope>(
        context,
        aspect: _OmniThemeAspect.animation,
      )?.activeAnimationMode ??
      OmniThemeAnimationMode.circularReveal;

  /// অ্যাপের সব উপলব্ধ থিম রিটার্ন করে।
  static List<OmniTheme> availableThemesOf(BuildContext context) =>
      InheritedModel.inheritFrom<OmniThemeScope>(
        context,
        aspect: _OmniThemeAspect.catalog,
      )?.availableThemes ??
      const [];

  /// মেমোইজড `(light, dark, mode)` পড়ে (কোনো থিম না থাকলে `null`)।
  static ({ThemeData light, ThemeData dark, ThemeMode mode})? maybeThemesOf(
    BuildContext context,
  ) {
    final scope = InheritedModel.inheritFrom<OmniThemeScope>(
      context,
      aspect: _OmniThemeAspect.themes,
    );
    if (scope == null) return null;
    InheritedModel.inheritFrom<OmniThemeScope>(
      context,
      aspect: _OmniThemeAspect.mode,
    );
    return (
      light: scope.lightTheme,
      dark: scope.darkTheme,
      mode: scope.selection.mode,
    );
  }

  /// সক্রিয় `MaterialApp.themeAnimationDuration` ও `themeAnimationCurve` পড়ে।
  static ({Duration duration, Curve curve})? animationSettingsOf(
    BuildContext context,
  ) {
    final scope = InheritedModel.inheritFrom<OmniThemeScope>(
      context,
      aspect: _OmniThemeAspect.themes,
    );
    if (scope == null) return null;
    return (
      duration: scope.animationDuration,
      curve: scope.animationCurve,
    );
  }

  @override
  bool updateShouldNotify(covariant OmniThemeScope oldWidget) =>
      !identical(oldWidget.controller, controller) ||
      oldWidget.selection != selection ||
      oldWidget.activeTheme != activeTheme ||
      oldWidget.activeStyle != activeStyle ||
      oldWidget.activeAnimationMode != activeAnimationMode ||
      !identical(oldWidget.availableThemes, availableThemes) ||
      !identical(oldWidget.lightTheme, lightTheme) ||
      !identical(oldWidget.darkTheme, darkTheme) ||
      oldWidget.animationDuration != animationDuration ||
      oldWidget.animationCurve != animationCurve;

  @override
  bool updateShouldNotifyDependent(
    covariant OmniThemeScope oldWidget,
    Set<Object> dependencies,
  ) {
    if (dependencies.contains(_OmniThemeAspect.mode) &&
        oldWidget.selection.mode != selection.mode) {
      return true;
    }
    if (dependencies.contains(_OmniThemeAspect.activeTheme) &&
        oldWidget.activeTheme != activeTheme) {
      return true;
    }
    if (dependencies.contains(_OmniThemeAspect.style) &&
        oldWidget.activeStyle != activeStyle) {
      return true;
    }
    if (dependencies.contains(_OmniThemeAspect.animation) &&
        oldWidget.activeAnimationMode != activeAnimationMode) {
      return true;
    }
    if (dependencies.contains(_OmniThemeAspect.catalog) &&
        !identical(oldWidget.availableThemes, availableThemes)) {
      return true;
    }
    if (dependencies.contains(_OmniThemeAspect.themes) &&
        (!identical(oldWidget.lightTheme, lightTheme) ||
            !identical(oldWidget.darkTheme, darkTheme) ||
            oldWidget.animationDuration != animationDuration ||
            oldWidget.animationCurve != animationCurve)) {
      return true;
    }
    return false;
  }
}

@immutable
class _OmniVisualThemeSnapshot {
  const _OmniVisualThemeSnapshot({
    required this.selection,
    required this.brightness,
    required this.theme,
    required this.style,
  });

  final OmniThemeSelection selection;
  final Brightness brightness;
  final OmniTheme theme;
  final OmniThemeStyle style;

  bool visuallyDiffersFrom(_OmniVisualThemeSnapshot other) =>
      brightness != other.brightness ||
      theme != other.theme ||
      style != other.style;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _OmniVisualThemeSnapshot &&
          selection == other.selection &&
          brightness == other.brightness &&
          theme == other.theme &&
          style == other.style;

  @override
  int get hashCode => Object.hash(selection, brightness, theme, style);
}

/// প্রতিটি `(themeId, style, device, tokens)` কম্বিনেশনের `ThemeData` ক্যাশ করে রাখে
/// এবং ডার্ক/লাইট মোড বা কালার প্যালেট বদলালে স্ক্রিনের ওপর দিয়ে মসৃণ
/// অ্যানিমেশন ([OmniThemeTransition]) চালায়।
class OmniResponsiveThemeHost extends StatefulWidget {
  /// [omniTheme] এবং/অথবা [themes] সহ থিম হোস্ট তৈরি করে।
  const OmniResponsiveThemeHost({
    super.key,
    this.omniTheme,
    this.themes = const [],
    this.themeAnimation,
    this.appScreenMode,
    this.appStatusBar,
    this.appSystemNavigationBar,
    required this.child,
  }) : assert(omniTheme != null || themes.length > 0);

  /// প্রাথমিক থিম।
  final OmniTheme? omniTheme;

  /// অ্যাপে সুইচ করার জন্য উপলব্ধ সব থিম।
  final List<OmniTheme> themes;

  /// `OmniApp(themeAnimation: ...)` থেকে পাওয়া গ্লোবাল স্ক্রিন ট্রানজিশন ওভাররাইড।
  final OmniThemeAnimation? themeAnimation;

  /// `OmniApp` বা রানটাইম কন্ট্রোলার থেকে পাওয়া ডিসপ্লে মোড ওভাররাইড।
  final OmniScreenMode? appScreenMode;

  /// `OmniApp` বা রানটাইম কন্ট্রোলার থেকে পাওয়া আলাদা স্ট্যাটাস বার স্টাইল।
  final OmniStatusBarStyle? appStatusBar;

  /// `OmniApp` বা রানটাইম কন্ট্রোলার থেকে পাওয়া আলাদা সিস্টেম নেভ/গেস্টচার বার স্টাইল।
  final OmniSystemNavigationBarStyle? appSystemNavigationBar;

  /// চাইল্ড অ্যাপ উইজেট।
  final Widget child;

  @override
  State<OmniResponsiveThemeHost> createState() =>
      _OmniResponsiveThemeHostState();
}

class _OmniResponsiveThemeHostState extends State<OmniResponsiveThemeHost> {
  OmniThemeController? _ownedController;
  late List<OmniTheme> _catalog;
  OmniDeviceType? _cacheDevice;
  OmniResponsiveTokens? _cacheTokens;
  final Map<
    String,
    ({
      OmniTheme source,
      OmniThemeStyle? styleOverride,
      OmniScreenMode? screenModeOverride,
      OmniStatusBarStyle? statusBarOverride,
      OmniSystemNavigationBarStyle? systemNavigationBarOverride,
      ThemeData light,
      ThemeData dark,
    })
  >
  _resolvedCache = {};

  OmniTheme get _primaryTheme => widget.omniTheme ?? widget.themes.first;

  List<OmniTheme> _buildCatalog() {
    final seen = <String>{};
    final out = <OmniTheme>[];
    void addIfNew(OmniTheme t) {
      if (seen.add(t.id)) out.add(t);
    }

    if (widget.omniTheme case final primary?) addIfNew(primary);
    for (final t in widget.themes) {
      addIfNew(t);
    }
    return List<OmniTheme>.unmodifiable(out);
  }

  OmniTheme _findTheme(String themeId) {
    for (final t in _catalog) {
      if (t.id == themeId) return t;
    }
    return _catalog.first;
  }

  OmniThemeController get _controller {
    final primary = _primaryTheme;
    return primary.controller ??
        (_ownedController ??= OmniThemeController(
          initialMode: primary.mode,
          initialThemeId: primary.id,
          persist: primary.persistMode,
          storageKey: primary.storageKey,
        ));
  }

  @override
  void initState() {
    super.initState();
    _catalog = _buildCatalog();
    unawaited(_controller.hydrate());
  }

  @override
  void didUpdateWidget(covariant OmniResponsiveThemeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.omniTheme != oldWidget.omniTheme ||
        widget.themes != oldWidget.themes) {
      _catalog = _buildCatalog();
      _resolvedCache.clear();
    }

    final oldPrimary = oldWidget.omniTheme ?? oldWidget.themes.firstOrNull;
    final nextPrimary = _primaryTheme;
    if (nextPrimary.controller != null && _ownedController != null) {
      _ownedController!.dispose();
      _ownedController = null;
    } else if (oldPrimary != null &&
        (oldPrimary.storageKey != nextPrimary.storageKey ||
            oldPrimary.persistMode != nextPrimary.persistMode)) {
      _ownedController?.dispose();
      _ownedController = null;
      unawaited(_controller.hydrate());
    } else if (oldPrimary != null &&
        nextPrimary.controller == null &&
        oldPrimary.mode != nextPrimary.mode) {
      _ownedController?.setMode(nextPrimary.mode);
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    _resolvedCache.clear();
    super.dispose();
  }

  ({ThemeData light, ThemeData dark}) _resolveFor(
    OmniTheme theme,
    OmniThemeStyle? styleOverride,
    OmniScreenMode? screenModeOverride,
    OmniStatusBarStyle? statusBarOverride,
    OmniSystemNavigationBarStyle? systemNavigationBarOverride,
    OmniDeviceType device,
    OmniResponsiveTokens tokens,
  ) {
    if (_cacheDevice != device || _cacheTokens != tokens) {
      _resolvedCache.clear();
      _cacheDevice = device;
      _cacheTokens = tokens;
    }
    final cacheKey = '${theme.id}|${styleOverride?.name ?? ''}';
    final existing = _resolvedCache[cacheKey];
    if (existing != null &&
        existing.source == theme &&
        existing.styleOverride == styleOverride &&
        existing.screenModeOverride == screenModeOverride &&
        existing.statusBarOverride == statusBarOverride &&
        existing.systemNavigationBarOverride == systemNavigationBarOverride) {
      return (light: existing.light, dark: existing.dark);
    }
    final built = (
      source: theme,
      styleOverride: styleOverride,
      screenModeOverride: screenModeOverride,
      statusBarOverride: statusBarOverride,
      systemNavigationBarOverride: systemNavigationBarOverride,
      light: theme.resolve(
        device: device,
        tokens: tokens,
        brightness: Brightness.light,
        styleOverride: styleOverride,
        screenModeOverride: screenModeOverride,
        statusBarOverride: statusBarOverride,
        systemNavigationBarOverride: systemNavigationBarOverride,
      ),
      dark: theme.resolve(
        device: device,
        tokens: tokens,
        brightness: Brightness.dark,
        styleOverride: styleOverride,
        screenModeOverride: screenModeOverride,
        statusBarOverride: statusBarOverride,
        systemNavigationBarOverride: systemNavigationBarOverride,
      ),
    );
    _resolvedCache[cacheKey] = built;
    return (light: built.light, dark: built.dark);
  }

  OmniThemeAnimation _effectiveAnimationFor(OmniTheme targetTheme) {
    if (widget.themeAnimation case final appAnim?) return appAnim;
    if (targetTheme.animation != const OmniThemeAnimation()) {
      return targetTheme.animation;
    }
    return _primaryTheme.animation;
  }

  @override
  Widget build(BuildContext context) {
    final device = OmniResponsiveScope.deviceOf(context);
    final tokens = OmniResponsiveScope.tokensOf(context);
    final controller = _controller;

    return ValueListenableBuilder<OmniThemeSelection>(
      valueListenable: controller,
      child: widget.child,
      builder: (hostContext, selection, child) {
        final activeTheme = _findTheme(selection.themeId);
        final activeStyle = selection.style ?? activeTheme.style;
        final activeBrightness = switch (selection.mode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => MediaQuery.platformBrightnessOf(hostContext),
        };
        final targetState = _OmniVisualThemeSnapshot(
          selection: selection,
          brightness: activeBrightness,
          theme: activeTheme,
          style: activeStyle,
        );
        final animConfig = _effectiveAnimationFor(activeTheme);

        return OmniThemeTransition<_OmniVisualThemeSnapshot>(
          value: targetState,
          animation: animConfig,
          suppressAnimationToken: controller.nonAnimatedVersion,
          takeExplicitOrigin: controller.takePendingOrigin,
          shouldAnimate: (prev, next) => prev.visuallyDiffersFrom(next),
          resolveMode: (prev, next) => animConfig.effectiveModeFor(
            brightnessChanged: prev.brightness != next.brightness,
            paletteChanged: prev.theme != next.theme,
            styleChanged: prev.style != next.style,
            runtimeOverride: next.selection.animationMode,
          ),
          resolveDuration: (prev, next) => animConfig.effectiveDurationFor(
            brightnessChanged: prev.brightness != next.brightness,
            paletteChanged: prev.theme != next.theme,
          ),
          resolveGlowColor: (next) =>
              next.theme.swatchColorFor(next.brightness),
          builder: (_, displayed, materialDuration, materialCurve) {
            final dispTheme = displayed.theme;
            final dispSelection = displayed.selection;
            final dispColors = dispTheme.resolveColors(displayed.brightness);
            final effectiveStatusBar =
                widget.appStatusBar ?? dispTheme.resolveStatusBar(dispColors);
            final effectiveNavBar =
                widget.appSystemNavigationBar ??
                dispTheme.resolveSystemNavigationBar(dispColors);
            final effectiveScreenMode = resolveEffectiveOmniScreenMode(
              widget.appScreenMode ?? dispTheme.screenMode,
              statusBar: effectiveStatusBar,
              systemNavigationBar: effectiveNavBar,
            );
            final resolved = _resolveFor(
              dispTheme,
              dispSelection.style,
              widget.appScreenMode,
              widget.appStatusBar,
              widget.appSystemNavigationBar,
              device,
              tokens,
            );
            final activeAnimMode =
                dispSelection.animationMode ?? animConfig.mode;

            return OmniThemeScope(
              controller: controller,
              selection: dispSelection,
              activeTheme: dispTheme,
              activeStyle: displayed.style,
              activeAnimationMode: activeAnimMode,
              availableThemes: _catalog,
              lightTheme: resolved.light,
              darkTheme: resolved.dark,
              animationDuration: materialDuration,
              animationCurve: materialCurve,
              child: OmniSystemUi(
                statusBar: effectiveStatusBar,
                systemNavigationBar: effectiveNavBar,
                screenMode: effectiveScreenMode,
                brightness: displayed.brightness,
                fallbackTopColor: dispColors.surfaceColor,
                fallbackBottomColor: dispColors.navBarColor,
                child: child!,
              ),
            );
          },
        );
      },
    );
  }
}

/// যেকোনো `BuildContext` থেকে থিম, কালার প্যালেট, স্টাইল, মোড ও স্ক্রিন
/// অ্যানিমেশন নিয়ন্ত্রণের সহজ শর্টকাট।
extension OmniThemeContext on BuildContext {
  /// নন-লিসেনিং কন্ট্রোলার (`onPressed` ও কলব্যাকে নিরাপদ)।
  OmniThemeController get themeController => OmniThemeScope.controllerOf(this);

  /// বর্তমান `ThemeMode` (`system`, `light`, বা `dark`)।
  ThemeMode get themeMode => OmniThemeScope.modeOf(this);

  /// বর্তমান সক্রিয় [OmniTheme]।
  OmniTheme? get activeTheme => OmniThemeScope.activeThemeOf(this);

  /// বর্তমান সক্রিয় [OmniThemeStyle]।
  OmniThemeStyle get activeThemeStyle => OmniThemeScope.activeStyleOf(this);

  /// বর্তমান সক্রিয় স্ক্রিন অ্যানিমেশন মোড ([OmniThemeAnimationMode])।
  OmniThemeAnimationMode get activeThemeAnimationMode =>
      OmniThemeScope.activeAnimationModeOf(this);

  /// বর্তমান সক্রিয় থিমের `id`।
  String get activeThemeId => activeTheme?.id ?? 'default';

  /// অ্যাপে উপলব্ধ সব থিম ভ্যারিয়েন্ট।
  List<OmniTheme> get availableThemes =>
      OmniThemeScope.availableThemesOf(this);

  /// বর্তমানে ডার্ক মোড চলছে কি না।
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// ১ ক্লিকে নির্দিষ্ট `themeId` (যেমন `'emerald'`) অ্যানিমেশনসহ চালু করে।
  void setTheme(String themeId, {Offset? origin, bool animate = true}) =>
      themeController.setTheme(themeId, origin: origin, animate: animate);

  /// ১ ক্লিকে পুরো অ্যাপের [OmniThemeStyle] (`modern`, `outlined`, `soft`...) বদলায়।
  void setThemeStyle(
    OmniThemeStyle style, {
    Offset? origin,
    bool animate = true,
  }) => themeController.setStyle(style, origin: origin, animate: animate);

  /// ১ ক্লিকে থিম ও কালার প্যালেট বদলানোর স্ক্রিন অ্যানিমেশন ([OmniThemeAnimationMode]) বদলায়।
  void setThemeAnimationMode(OmniThemeAnimationMode mode) =>
      themeController.setAnimationMode(mode);

  /// ১ ক্লিকে পরবর্তী কালার প্যালেটে চলে যায়।
  void nextTheme({Offset? origin, bool animate = true}) {
    final list =
        getInheritedWidgetOfExactType<OmniThemeScope>()?.availableThemes ??
        const <OmniTheme>[];
    themeController.nextTheme(list, origin: origin, animate: animate);
  }

  /// `ThemeMode.light`, `.dark`, বা `.system` সেট করে ও অটো সেভ রাখে।
  void setThemeMode(ThemeMode mode, {Offset? origin, bool animate = true}) =>
      themeController.setMode(mode, origin: origin, animate: animate);

  /// ১ ক্লিকে লাইট ↔ ডার্ক মোড অ্যানিমেশনসহ টগল করে।
  void toggleTheme({Offset? origin, bool animate = true}) =>
      themeController.toggle(
        MediaQuery.maybePlatformBrightnessOf(this),
        origin,
        animate,
      );

  /// `system -> light -> dark -> system` অ্যানিমেশনসহ ঘোরায়।
  void cycleThemeMode({Offset? origin, bool animate = true}) =>
      themeController.cycle(origin: origin, animate: animate);

  /// Settings বা যেকোনো স্ক্রিন থেকে ১-ট্যাপে থিম ও কালার প্যালেট সেটিংস শিট খোলে।
  Future<void> openThemeSettings({
    String title = 'Theme & Appearance',
    String modeTitle = 'Appearance Mode',
    String themeTitle = 'Color Palette',
    String styleTitle = 'Theme Style',
    String animationTitle = 'Theme Animation',
    String systemLabel = 'System',
    String lightLabel = 'Light',
    String darkLabel = 'Dark',
    bool showStylePicker = true,
    bool showAnimationPicker = false,
  }) => showOmniThemeSheet(
    this,
    title: title,
    modeTitle: modeTitle,
    themeTitle: themeTitle,
    styleTitle: styleTitle,
    animationTitle: animationTitle,
    systemLabel: systemLabel,
    lightLabel: lightLabel,
    darkLabel: darkLabel,
    showStylePicker: showStylePicker,
    showAnimationPicker: showAnimationPicker,
  );
}

/// ১-ট্যাপে লাইট ↔ ডার্ক মোড বদলানোর আইকন বাটন (`AppBar.actions`-এর জন্য আদর্শ)।
class OmniThemeModeButton extends StatelessWidget {
  /// লাইট/ডার্ক (অথবা `allowSystemMode: true` দিলে ৩-স্টেট) টগল বাটন তৈরি করে।
  const OmniThemeModeButton({
    super.key,
    this.allowSystemMode = false,
    this.lightIcon = const Icon(Icons.light_mode_outlined),
    this.darkIcon = const Icon(Icons.dark_mode_outlined),
    this.systemIcon = const Icon(Icons.brightness_auto_outlined),
    this.tooltip,
  });

  /// `true` হলে `system -> light -> dark` ঘোরে; ডিফল্ট `false` সরাসরি `light <-> dark`।
  final bool allowSystemMode;

  /// লাইট মোডে ফিরতে দেখানো আইকন।
  final Widget lightIcon;

  /// ডার্ক মোডে যেতে দেখানো আইকন।
  final Widget darkIcon;

  /// অটো/সিস্টেম মোডে দেখানো আইকন।
  final Widget systemIcon;

  /// হোভার টুলটিপ।
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final mode = OmniThemeScope.modeOf(context);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final Widget icon;
    if (allowSystemMode && mode == ThemeMode.system) {
      icon = systemIcon;
    } else {
      icon = isDark ? lightIcon : darkIcon;
    }

    return IconButton(
      tooltip: tooltip ??
          (allowSystemMode
              ? 'Theme: ${mode.name}'
              : (isDark ? 'Light mode' : 'Dark mode')),
      icon: icon,
      onPressed: OmniThemeScope.maybeControllerOf(context) == null
          ? null
          : allowSystemMode
              ? () => context.cycleThemeMode()
              : () => context.toggleTheme(),
    );
  }
}

/// ১-ট্যাপে পরবর্তী কালার প্যালেটে (`ocean -> emerald -> violet ...`) যাওয়ার বাটন।
class OmniThemeButton extends StatelessWidget {
  /// `AppBar` বা টুলবারে ১-ক্লিক প্যালেট বদলানোর বাটন তৈরি করে।
  const OmniThemeButton({
    super.key,
    this.icon = const Icon(Icons.palette_outlined),
    this.tooltip,
  });

  /// বাটনে দেখানো আইকন (ডিফল্ট প্যালেট আইকন)।
  final Widget icon;

  /// কাস্টম হোভার টুলটিপ।
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final current = OmniThemeScope.activeThemeOf(context);
    return IconButton(
      tooltip:
          tooltip ?? (current != null ? 'Palette: ${current.name}' : 'Next palette'),
      icon: icon,
      onPressed: OmniThemeScope.maybeControllerOf(context) == null
          ? null
          : () => context.nextTheme(),
    );
  }
}

/// Settings পেজের জন্য `System / Light / Dark` সেগমেন্টেড সুইচ।
class OmniThemeModeSwitch extends StatelessWidget {
  /// ৩টি মোডের মধ্যে থেকে বেছে নেওয়ার সুইচ তৈরি করে।
  const OmniThemeModeSwitch({
    super.key,
    this.systemLabel = 'System',
    this.lightLabel = 'Light',
    this.darkLabel = 'Dark',
    this.showIcons = true,
  });

  /// `ThemeMode.system`-এর লেখা।
  final String systemLabel;

  /// `ThemeMode.light`-এর লেখা।
  final String lightLabel;

  /// `ThemeMode.dark`-এর লেখা।
  final String darkLabel;

  /// লেখার সাথে আইকন দেখাবে কি না।
  final bool showIcons;

  @override
  Widget build(BuildContext context) {
    final mode = OmniThemeScope.modeOf(context);
    final hasScope = OmniThemeScope.maybeControllerOf(context) != null;
    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          label: Text(systemLabel),
          icon: showIcons ? const Icon(Icons.brightness_auto_outlined) : null,
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          label: Text(lightLabel),
          icon: showIcons ? const Icon(Icons.light_mode_outlined) : null,
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          label: Text(darkLabel),
          icon: showIcons ? const Icon(Icons.dark_mode_outlined) : null,
        ),
      ],
      selected: {mode},
      onSelectionChanged: !hasScope
          ? null
          : (selection) {
              if (selection.isNotEmpty) {
                context.setThemeMode(selection.first);
              }
            },
    );
  }
}

/// [OmniThemePicker] দেখানোর ভিজ্যুয়াল ধরন।
enum OmniThemePickerLayout {
  /// ছোট পিল চিপ + সিঙ্গেল কালার ডট (কম্প্যাক্ট জায়গার জন্য)।
  chips,

  /// একাধিক সওয়াচ ডট (Primary + Secondary + Surface) ও নামসহ কালার প্যালেট কার্ড।
  paletteCards,
}

/// ১ ক্লিকে কালার প্যালেট পছন্দ করার সেটিংস-বান্ধব পিকার (`themes:` লিস্ট থেকে
/// স্বয়ংক্রিয়ভাবে প্যালেট রঙ ও নাম দেখায়)।
class OmniThemePicker extends StatelessWidget {
  /// সব উপলব্ধ কালার প্যালেট দেখিয়ে ১-ক্লিক পিকার তৈরি করে।
  const OmniThemePicker({
    super.key,
    this.themes,
    this.showNames = true,
    this.spacing = 10,
    this.layout = OmniThemePickerLayout.paletteCards,
  });

  /// ঐচ্ছিক থিম তালিকা (না দিলে `OmniApp` থেকে অটো পায়)।
  final List<OmniTheme>? themes;

  /// রঙ সওয়াচের পাশে প্যালেটের নাম দেখাবে কি না।
  final bool showNames;

  /// দুটি প্যালেটের মাঝখানের ফাঁকা জায়গা।
  final double spacing;

  /// প্রদর্শনের ধরন (`paletteCards` অথবা `chips`)।
  final OmniThemePickerLayout layout;

  @override
  Widget build(BuildContext context) {
    final scoped = OmniThemeScope.availableThemesOf(context);
    final items = themes ?? (scoped.isNotEmpty ? scoped : OmniTheme.presets);
    final activeId = OmniThemeScope.activeThemeOf(context)?.id ?? '';
    final hasController = OmniThemeScope.maybeControllerOf(context) != null;
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final t in items)
          _PaletteOptionItem(
            theme: t,
            selected: t.id == activeId,
            showName: showNames,
            layout: layout,
            isDark: isDark,
            colors: c,
            onTap: hasController ? () => context.setTheme(t.id) : null,
          ),
      ],
    );
  }
}

class _PaletteOptionItem extends StatelessWidget {
  const _PaletteOptionItem({
    required this.theme,
    required this.selected,
    required this.showName,
    required this.layout,
    required this.isDark,
    required this.colors,
    required this.onTap,
  });

  final OmniTheme theme;
  final bool selected;
  final bool showName;
  final OmniThemePickerLayout layout;
  final bool isDark;
  final OmniColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final primary = theme.swatchColorFor(brightness);
    final secondary = isDark
        ? (theme.darkColors?.secondaryColor ??
            theme.dark?.secondaryColor ??
            theme.darkSecondaryColor ??
            theme.secondaryColor ??
            primary)
        : (theme.lightColors?.secondaryColor ??
            theme.light?.secondaryColor ??
            theme.secondaryColor ??
            primary);
    final surfaceSwatch = isDark
        ? (theme.darkColors?.cardColor ??
            theme.dark?.cardColor ??
            theme.darkCardColor ??
            theme.dark?.surfaceColor ??
            theme.darkSurfaceColor ??
            const Color(0xFF131C31))
        : (theme.lightColors?.cardColor ??
            theme.light?.cardColor ??
            theme.cardColor ??
            theme.light?.surfaceColor ??
            theme.surfaceColor ??
            Colors.white);

    if (layout == OmniThemePickerLayout.chips) {
      return InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: showName ? 12 : 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.14)
                : colors.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? primary : colors.borderColor,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                child: selected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (showName) ...[
                const SizedBox(width: 8),
                Text(
                  theme.name,
                  style: TextStyle(
                    color: colors.textColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showName ? 12 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: isDark ? 0.18 : 0.10)
              : colors.secondaryBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primary : colors.borderColor,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 38,
              height: 20,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    child: _SwatchDot(color: primary, border: colors.cardColor),
                  ),
                  Positioned(
                    left: 10,
                    child: _SwatchDot(color: secondary, border: colors.cardColor),
                  ),
                  Positioned(
                    left: 20,
                    child: _SwatchDot(
                      color: surfaceSwatch,
                      border: colors.borderColor,
                    ),
                  ),
                ],
              ),
            ),
            if (showName) ...[
              const SizedBox(width: 8),
              Text(
                theme.name,
                style: TextStyle(
                  color: colors.textColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 16, color: primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.color, required this.border});

  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
    );
  }
}

/// ১ ক্লিকে অ্যাপের ডিজাইন স্টাইল ([OmniThemeStyle]: `Modern`, `Outlined`,
/// `Soft`, `Elevated`, `Minimal`, `Compact`) বদলানোর সেটিংস পিকার।
class OmniThemeStylePicker extends StatelessWidget {
  /// [styles] অপশনগুলো সহ ১-ক্লিক থিম স্টাইল পিকার তৈরি করে।
  const OmniThemeStylePicker({
    super.key,
    this.styles = OmniThemeStyle.values,
    this.spacing = 8,
  });

  /// দেখানোর জন্য [OmniThemeStyle] তালিকা।
  final List<OmniThemeStyle> styles;

  /// চিপগুলোর মাঝখানের ফাঁকা জায়গা।
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final activeStyle = OmniThemeScope.activeStyleOf(context);
    final hasController = OmniThemeScope.maybeControllerOf(context) != null;
    final c = context.colors;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final style in styles)
          ChoiceChip(
            label: Text(style.label),
            selected: style == activeStyle,
            onSelected: !hasController
                ? null
                : (_) => context.setThemeStyle(style),
            backgroundColor: c.secondaryBackgroundColor,
            selectedColor: c.selectedItemColor,
            labelStyle: TextStyle(
              color: style == activeStyle ? c.primaryColor : c.textColor,
              fontWeight:
                  style == activeStyle ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: style == activeStyle ? c.primaryColor : c.borderColor,
            ),
          ),
      ],
    );
  }
}

/// ১ ক্লিকে ডার্ক মোড ও কালার প্যালেট বদলানোর স্ক্রিন অ্যানিমেশন
/// ([OmniThemeAnimationMode]) বাছাই করার পিকার।
class OmniThemeAnimationPicker extends StatelessWidget {
  /// [modes] অপশনগুলো সহ ১-ক্লিক থিম অ্যানিমেশন পিকার তৈরি করে।
  const OmniThemeAnimationPicker({
    super.key,
    this.modes = OmniThemeAnimationMode.values,
    this.spacing = 8,
    this.showIcons = true,
  });

  /// দেখানোর জন্য [OmniThemeAnimationMode] তালিকা।
  final List<OmniThemeAnimationMode> modes;

  /// চিপগুলোর মাঝখানের ফাঁকা জায়গা।
  final double spacing;

  /// লেখার সাথে আইকন দেখাবে কি না।
  final bool showIcons;

  @override
  Widget build(BuildContext context) {
    final activeMode = OmniThemeScope.activeAnimationModeOf(context);
    final hasController = OmniThemeScope.maybeControllerOf(context) != null;
    final c = context.colors;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final mode in modes)
          ChoiceChip(
            avatar: showIcons
                ? Icon(
                    mode.icon,
                    size: 16,
                    color: mode == activeMode
                        ? c.primaryColor
                        : c.secondaryTextColor,
                  )
                : null,
            label: Text(mode.label),
            tooltip: mode.description,
            selected: mode == activeMode,
            onSelected: !hasController
                ? null
                : (_) => context.setThemeAnimationMode(mode),
            backgroundColor: c.secondaryBackgroundColor,
            selectedColor: c.selectedItemColor,
            labelStyle: TextStyle(
              color: mode == activeMode ? c.primaryColor : c.textColor,
              fontWeight:
                  mode == activeMode ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: mode == activeMode ? c.primaryColor : c.borderColor,
            ),
          ),
      ],
    );
  }
}

/// Settings পেজের জন্য অল-ইন-ওয়ান থিম কার্ড (`System/Light/Dark` মোড,
/// ১-ক্লিক কালার প্যালেট পিকার, লাইভ প্রিভিউ স্ট্রিপ ও ঐচ্ছিক `OmniThemeStylePicker`
/// ও `OmniThemeAnimationPicker`)।
class OmniThemePanel extends StatelessWidget {
  /// সম্পূর্ণ থিম ও কালার প্যালেট সেটিংস প্যানেল তৈরি করে।
  const OmniThemePanel({
    super.key,
    this.modeTitle = 'Appearance Mode',
    this.themeTitle = 'Color Palette',
    this.styleTitle = 'Theme Style',
    this.animationTitle = 'Theme Animation',
    this.systemLabel = 'System',
    this.lightLabel = 'Light',
    this.darkLabel = 'Dark',
    this.themes,
    this.pickerLayout = OmniThemePickerLayout.paletteCards,
    this.showModeSwitch = true,
    this.showPalettePicker = true,
    this.showStylePicker = false,
    this.showAnimationPicker = false,
    this.showPalettePreview = true,
  });

  /// মোড সেকশনের শিরোনাম।
  final String modeTitle;

  /// কালার প্যালেট সেকশনের শিরোনাম।
  final String themeTitle;

  /// ডিজাইন স্টাইল সেকশনের শিরোনাম।
  final String styleTitle;

  /// অ্যানিমেশন সেকশনের শিরোনাম।
  final String animationTitle;

  /// সিস্টেম মোডের লেবেল।
  final String systemLabel;

  /// লাইট মোডের লেবেল।
  final String lightLabel;

  /// ডার্ক মোডের লেবেল।
  final String darkLabel;

  /// ঐচ্ছিক কাস্টম থিম তালিকা (না দিলে `OmniApp(themes: ...)` থেকে নেয়)।
  final List<OmniTheme>? themes;

  /// প্যালেট অপশন দেখানোর ধরন।
  final OmniThemePickerLayout pickerLayout;

  /// লাইট/ডার্ক/সিস্টেম মোড সুইচ দেখাবে কি না।
  final bool showModeSwitch;

  /// ১-ক্লিক কালার প্যালেট পিকার দেখাবে কি না।
  final bool showPalettePicker;

  /// ১-ক্লিক ডিজাইন স্টাইল পিকার দেখাবে কি না।
  final bool showStylePicker;

  /// ডার্ক মোড ও প্যালেট বদলানোর স্ক্রিন অ্যানিমেশন পিকার দেখাবে কি না।
  final bool showAnimationPicker;

  /// বর্তমান প্যালেটের প্রধান কালারগুলোর লাইভ ডট প্রিভিউ দেখাবে কি না।
  final bool showPalettePreview;

  @override
  Widget build(BuildContext context) {
    final t = OmniResponsiveScope.tokensOf(context);
    final c = context.colors;
    final available = themes ?? OmniThemeScope.availableThemesOf(context);
    final showPalettes = showPalettePicker && available.length > 1;

    return Card(
      child: Padding(
        padding: t.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showModeSwitch) ...[
              Text(modeTitle, style: context.textStyles.title),
              t.gapSm,
              OmniThemeModeSwitch(
                systemLabel: systemLabel,
                lightLabel: lightLabel,
                darkLabel: darkLabel,
              ),
            ],
            if (showPalettes) ...[
              if (showModeSwitch) t.gapMd,
              Row(
                children: [
                  Expanded(
                    child: Text(themeTitle, style: context.textStyles.title),
                  ),
                  if (showPalettePreview) _ActivePaletteStrip(colors: c),
                ],
              ),
              t.gapSm,
              OmniThemePicker(
                themes: themes,
                layout: pickerLayout,
              ),
            ],
            if (showStylePicker) ...[
              if (showModeSwitch || showPalettes) t.gapMd,
              Text(styleTitle, style: context.textStyles.title),
              t.gapSm,
              const OmniThemeStylePicker(),
            ],
            if (showAnimationPicker) ...[
              if (showModeSwitch || showPalettes || showStylePicker) t.gapMd,
              Text(animationTitle, style: context.textStyles.title),
              t.gapSm,
              const OmniThemeAnimationPicker(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivePaletteStrip extends StatelessWidget {
  const _ActivePaletteStrip({required this.colors});

  final OmniColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StripDot(colors.primaryColor),
          const SizedBox(width: 4),
          _StripDot(colors.secondaryButtonColor),
          const SizedBox(width: 4),
          _StripDot(colors.successColor),
          const SizedBox(width: 4),
          _StripDot(colors.warningColor),
          const SizedBox(width: 4),
          _StripDot(colors.errorColor),
        ],
      ),
    );
  }
}

class _StripDot extends StatelessWidget {
  const _StripDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Settings স্ক্রিনের `ListView`-তে ১ লাইনে বসানোর রেডি `ListTile`!
///
/// ট্যাপ করলেই রেসপন্সিভ বটমশিট বা ডায়ালগে [showOmniThemeSheet] খুলে দেয় —
/// সেখান থেকে ১ ক্লিকে পুরো অ্যাপের কালার প্যালেট, থিম মোড (`Dark/Light/System`)
/// ও ডিজাইন স্টাইল বদলানো যায়।
class OmniThemeSettingsTile extends StatelessWidget {
  /// সেটিংস মেনুর জন্য রেডি থিম ও কালার প্যালেট রো তৈরি করে।
  const OmniThemeSettingsTile({
    super.key,
    this.title = 'Theme & Color Palette',
    this.sheetTitle = 'Theme & Appearance',
    this.modeTitle = 'Appearance Mode',
    this.themeTitle = 'Color Palette',
    this.styleTitle = 'Theme Style',
    this.animationTitle = 'Theme Animation',
    this.systemLabel = 'System',
    this.lightLabel = 'Light',
    this.darkLabel = 'Dark',
    this.showStylePicker = true,
    this.showAnimationPicker = false,
  });

  /// সেটিংস রো-এর শিরোনাম।
  final String title;

  /// ওপেন হওয়া শিটের শিরোনাম।
  final String sheetTitle;

  /// মোড সেকশনের শিরোনাম।
  final String modeTitle;

  /// কালার প্যালেট সেকশনের শিরোনাম।
  final String themeTitle;

  /// স্টাইল সেকশনের শিরোনাম।
  final String styleTitle;

  /// অ্যানিমেশন সেকশনের শিরোনাম।
  final String animationTitle;

  /// সিস্টেম মোড লেবেল।
  final String systemLabel;

  /// লাইট মোড লেবেল।
  final String lightLabel;

  /// ডার্ক মোড লেবেল।
  final String darkLabel;

  /// শিটের ভেতর থিম স্টাইল পিকার দেখাবে কি না।
  final bool showStylePicker;

  /// শিটের ভেতর স্ক্রিন অ্যানিমেশন পিকার দেখাবে কি না।
  final bool showAnimationPicker;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeTheme = OmniThemeScope.activeThemeOf(context);
    final mode = OmniThemeScope.modeOf(context);
    final style = OmniThemeScope.activeStyleOf(context);
    final modeLabel = switch (mode) {
      ThemeMode.system => systemLabel,
      ThemeMode.light => lightLabel,
      ThemeMode.dark => darkLabel,
    };
    final paletteName = activeTheme?.name ?? 'Default';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: c.selectedItemColor,
        child: Icon(Icons.palette_outlined, color: c.primaryColor),
      ),
      title: Text(title, style: context.textStyles.subtitle),
      subtitle: Text(
        '$paletteName · $modeLabel · ${style.label}',
        style: context.textStyles.caption,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StripDot(c.primaryColor),
          const SizedBox(width: 4),
          _StripDot(c.secondaryColor),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: c.iconColor),
        ],
      ),
      onTap: () => showOmniThemeSheet(
        context,
        title: sheetTitle,
        modeTitle: modeTitle,
        themeTitle: themeTitle,
        styleTitle: styleTitle,
        animationTitle: animationTitle,
        systemLabel: systemLabel,
        lightLabel: lightLabel,
        darkLabel: darkLabel,
        showStylePicker: showStylePicker,
        showAnimationPicker: showAnimationPicker,
      ),
    );
  }
}

/// মোবাইলে `BottomSheet` এবং ট্যাবলেট/ডেস্কটপে `Dialog` হিসেবে ১-ক্লিক থিম,
/// কালার প্যালেট ও মোড কন্ট্রোল শিট খুলে দেয়।
Future<T?> showOmniThemeSheet<T>(
  BuildContext context, {
  String title = 'Theme & Appearance',
  String modeTitle = 'Appearance Mode',
  String themeTitle = 'Color Palette',
  String styleTitle = 'Theme Style',
  String animationTitle = 'Theme Animation',
  String systemLabel = 'System',
  String lightLabel = 'Light',
  String darkLabel = 'Dark',
  bool showStylePicker = true,
  bool showAnimationPicker = false,
}) {
  final device = OmniResponsiveScope.deviceOf(context);
  final isCompact = device == OmniDeviceType.mobile;

  Widget buildContent(BuildContext ctx) {
    final tk = OmniResponsiveScope.tokensOf(ctx);
    return Padding(
      padding: tk.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: ctx.textStyles.heading)),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(ctx).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          tk.gapSm,
          Flexible(
            child: SingleChildScrollView(
              child: OmniThemePanel(
                modeTitle: modeTitle,
                themeTitle: themeTitle,
                styleTitle: styleTitle,
                animationTitle: animationTitle,
                systemLabel: systemLabel,
                lightLabel: lightLabel,
                darkLabel: darkLabel,
                showStylePicker: showStylePicker,
                showAnimationPicker: showAnimationPicker,
              ),
            ),
          ),
        ],
      ),
    );
  }

  if (isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      builder: buildContent,
    );
  }

  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: buildContent(ctx),
      ),
    ),
  );
}
