import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';
import 'omni_status_bar.dart';
import 'omni_system_navigation_bar.dart';

/// সিস্টেম স্ট্যাটাস বার, বটম নেভিগেশন বার ও ফুলস্ক্রিন ডিসপ্লে নিয়ন্ত্রণের মোড।
///
/// Android ও iOS দুই প্ল্যাটফর্মেই অ্যাপের স্ক্রিন কীভাবে দেখাবে এবং নিচের
/// গেস্টচার/সোয়াইপ বারের কালো এরিয়া কীভাবে হ্যান্ডেল করবে তা ১ শব্দে নিয়ন্ত্রণ করে।
enum OmniScreenMode {
  /// আধুনিক এজ-টু-এজ মোড (ডিফল্ট): ওপর ও নিচের সিস্টেম বার সম্পূর্ণ স্বচ্ছ থাকে
  /// এবং গেস্টচার সোয়াইপ বারের পেছনে কোনো কালো এরিয়া থাকে না।
  edgeToEdge,

  /// ক্লাসিক নরমাল মোড: ওপর ও নিচের সিস্টেম বার দৃশ্যমান থাকে এবং নির্ধারিত
  /// [OmniStatusBarStyle] ও [OmniSystemNavigationBarStyle] রঙ ব্যবহার করে।
  normal,

  /// সম্পূর্ণ ফুলস্ক্রিন মোড (`immersiveSticky`): স্ট্যাটাস ও নেভিগেশন বার লুকানো থাকে।
  /// কিনারা থেকে সোয়াইপ করলে সাময়িক এসে কয়েক সেকেন্ড পর আবার লুকিয়ে যায়।
  fullscreen,

  /// লিন-ব্যাক ফুলস্ক্রিন মোড (`leanBack`): বারগুলো লুকানো থাকে, স্ক্রিনে ট্যাপ করলেই ফিরে আসে।
  fullscreenLean,

  /// কেবল ওপরের স্ট্যাটাস বার খোলা থাকে, নিচের সিস্টেম নেভিগেশন/গেস্টচার বার লুকানো থাকে।
  statusBarOnly,

  /// কেবল নিচের সিস্টেম নেভিগেশন বার খোলা থাকে, ওপরের স্ট্যাটাস বার লুকানো থাকে।
  navigationBarOnly;

  /// এই মোডের জন্য সংশ্লিষ্ট Flutter [SystemUiMode] রিটার্ন করে।
  SystemUiMode get systemUiMode => switch (this) {
    OmniScreenMode.edgeToEdge => SystemUiMode.edgeToEdge,
    OmniScreenMode.fullscreen => SystemUiMode.immersiveSticky,
    OmniScreenMode.fullscreenLean => SystemUiMode.leanBack,
    OmniScreenMode.normal ||
    OmniScreenMode.statusBarOnly ||
    OmniScreenMode.navigationBarOnly => SystemUiMode.manual,
  };

  /// `SystemUiMode.manual`-এ কোন কোন বার চালু থাকবে (`edgeToEdge`/`fullscreen`-এ `null`)।
  List<SystemUiOverlay>? get overlays => switch (this) {
    OmniScreenMode.normal => const [
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ],
    OmniScreenMode.statusBarOnly => const [SystemUiOverlay.top],
    OmniScreenMode.navigationBarOnly => const [SystemUiOverlay.bottom],
    OmniScreenMode.edgeToEdge ||
    OmniScreenMode.fullscreen ||
    OmniScreenMode.fullscreenLean => null,
  };

  /// বর্তমানে কোনো ফুলস্ক্রিন মোড (`fullscreen` বা `fullscreenLean`) চলছে কি না।
  bool get isFullscreen =>
      this == OmniScreenMode.fullscreen ||
      this == OmniScreenMode.fullscreenLean;

  /// এই মোডে সিস্টেম বার স্বচ্ছ এজ-টু-এজ থাকবে কি না।
  bool get isEdgeToEdge => this == OmniScreenMode.edgeToEdge || isFullscreen;
}

/// ডিভাইস ওরিয়েন্টেশন বা স্ক্রিন রোটেশনের রেডিমেড মোড (`OmniApp(orientation: ...)`
/// অথবা প্রতি পেজে `OmniPage(orientation: ...)` বা `context.setOrientation(...)`)।
enum OmniOrientation {
  /// সেন্সর অনুযায়ী ৪ দিকেই (খাঁড়া, উল্টো, বাম, ডান) স্বয়ংক্রিয় রোটেশন।
  auto,

  /// শুধু স্বাভাবিক খাঁড়া (`portraitUp`) মোডে লক করা — ফোন ঘুরালেও রোটেট হবে না।
  portrait,

  /// স্বাভাবিক ও উল্টো উভয় খাঁড়া (`portraitUp` + `portraitDown`) মোড।
  portraitBoth,

  /// উভয় আড়াআড়ি (`landscapeLeft` + `landscapeRight`) মোড — ভিডিও ও গেমের জন্য আদর্শ।
  landscape,

  /// কেবল বাম-পাশের ল্যান্ডস্কেপ (`landscapeLeft`) মোডে লক করা।
  landscapeLeft,

  /// কেবল ডান-পাশের ল্যান্ডস্কেপ (`landscapeRight`) মোডে লক করা।
  landscapeRight,

  /// স্মার্ট অ্যাডাপ্টিভ মোড: ফোনে (`mobile`) খাঁড়া পোর্ট্রেট লক থাকে, আর
  /// ট্যাবলেট/ফোল্ডেবল/বড় স্ক্রিনে ৪ দিকেই অটো-রোটেট চালু হয়!
  portraitOnMobile,

  /// ডিভাইস ও OS-এর ডিফল্ট ম্যানিফেস্ট রোটেশন সেটিংস (`[]`) অনুসরণ করে।
  system;

  /// প্রদত্ত [device] টিয়ারের জন্য কার্যকর Flutter [DeviceOrientation] তালিকা দেয়।
  List<DeviceOrientation> resolveFor(OmniDeviceType device) => switch (this) {
    OmniOrientation.auto => const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    OmniOrientation.portrait => const [DeviceOrientation.portraitUp],
    OmniOrientation.portraitBoth => const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
    OmniOrientation.landscape => const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    OmniOrientation.landscapeLeft => const [DeviceOrientation.landscapeLeft],
    OmniOrientation.landscapeRight => const [DeviceOrientation.landscapeRight],
    OmniOrientation.portraitOnMobile =>
      device == OmniDeviceType.mobile
          ? const [DeviceOrientation.portraitUp]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
    OmniOrientation.system => const <DeviceOrientation>[],
  };
}

/// আলাদা [OmniStatusBarStyle] ও [OmniSystemNavigationBarStyle]-এর `visible`
/// ফ্ল্যাগ এবং [baseMode] মিলিয়ে কার্যকর [OmniScreenMode] নির্ণয় করে।
OmniScreenMode resolveEffectiveOmniScreenMode(
  OmniScreenMode baseMode, {
  OmniStatusBarStyle? statusBar,
  OmniSystemNavigationBarStyle? systemNavigationBar,
}) {
  if (baseMode.isFullscreen) return baseMode;
  final topVisible =
      (statusBar?.visible ?? true) &&
      baseMode != OmniScreenMode.navigationBarOnly;
  final bottomVisible =
      (systemNavigationBar?.visible ?? true) &&
      baseMode != OmniScreenMode.statusBarOnly;

  if (!topVisible && !bottomVisible) return OmniScreenMode.fullscreen;
  if (!topVisible && bottomVisible) return OmniScreenMode.navigationBarOnly;
  if (topVisible && !bottomVisible) return OmniScreenMode.statusBarOnly;
  return baseMode;
}

/// আলাদা [OmniStatusBarStyle] (ওপর) এবং [OmniSystemNavigationBarStyle] (নিচ)-কে
/// একত্র করে ফ্লাটারের [SystemUiOverlayStyle] তৈরি করে।
SystemUiOverlayStyle composeOmniSystemUiOverlayStyle({
  required Brightness brightness,
  required OmniScreenMode screenMode,
  OmniStatusBarStyle? statusBar,
  OmniSystemNavigationBarStyle? systemNavigationBar,
  Color? fallbackTopBackground,
  Color? fallbackBottomBackground,
}) {
  final edgeToEdge = screenMode.isEdgeToEdge;
  final top = (statusBar ?? const OmniStatusBarStyle.transparent())
      .toOverlayStyle(
        brightness: brightness,
        fallbackBackground: fallbackTopBackground,
        edgeToEdge: edgeToEdge,
      );
  final bottom =
      (systemNavigationBar ?? const OmniSystemNavigationBarStyle.transparent())
          .toOverlayStyle(
            brightness: brightness,
            fallbackBackground: fallbackBottomBackground,
            edgeToEdge: edgeToEdge,
          );
  return SystemUiOverlayStyle(
    statusBarColor: top.statusBarColor,
    statusBarIconBrightness: top.statusBarIconBrightness,
    statusBarBrightness: top.statusBarBrightness,
    systemStatusBarContrastEnforced: top.systemStatusBarContrastEnforced,
    systemNavigationBarColor: bottom.systemNavigationBarColor,
    systemNavigationBarDividerColor: bottom.systemNavigationBarDividerColor,
    systemNavigationBarIconBrightness: bottom.systemNavigationBarIconBrightness,
    systemNavigationBarContrastEnforced:
        bottom.systemNavigationBarContrastEnforced,
  );
}

// ── Active System Chrome Stack Coordinator ──────────────────────────────────

final class _OmniChromeEntry {
  OmniScreenMode? screenMode;
  SystemUiOverlayStyle? overlayStyle;
  List<DeviceOrientation>? orientations;
  bool hasExplicitOrientations = false;
  bool active = true;
}

abstract final class _OmniChromeCoordinator {
  static final List<_OmniChromeEntry> _entries = [];
  static OmniScreenMode? _lastAppliedMode;
  static SystemUiOverlayStyle? _lastAppliedOverlayStyle;
  static List<DeviceOrientation>? _lastAppliedOrientations;
  static bool _everAppliedOrientation = false;

  static void attach(_OmniChromeEntry entry) {
    _entries.add(entry);
    sync();
  }

  static void detach(_OmniChromeEntry entry) {
    _entries.remove(entry);
    sync();
  }

  static void sync() {
    if (_entries.isEmpty) {
      if (_everAppliedOrientation) {
        SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
        _everAppliedOrientation = false;
      }
      _lastAppliedMode = null;
      _lastAppliedOverlayStyle = null;
      _lastAppliedOrientations = null;
      return;
    }

    OmniScreenMode? targetMode;
    SystemUiOverlayStyle? targetOverlay;
    List<DeviceOrientation>? targetOrientations;
    var hasOrientationTarget = false;

    for (var i = _entries.length - 1; i >= 0; i--) {
      final entry = _entries[i];
      if (!entry.active) continue;
      targetMode ??= entry.screenMode;
      targetOverlay ??= entry.overlayStyle;
      if (!hasOrientationTarget && entry.hasExplicitOrientations) {
        targetOrientations = entry.orientations;
        hasOrientationTarget = true;
      }
      if (targetMode != null && targetOverlay != null && hasOrientationTarget) {
        break;
      }
    }

    if (targetMode != null && targetMode != _lastAppliedMode) {
      _lastAppliedMode = targetMode;
      SystemChrome.setEnabledSystemUIMode(
        targetMode.systemUiMode,
        overlays: targetMode.overlays,
      );
    }

    if (targetOverlay != null && targetOverlay != _lastAppliedOverlayStyle) {
      _lastAppliedOverlayStyle = targetOverlay;
      SystemChrome.setSystemUIOverlayStyle(targetOverlay);
    }

    if (hasOrientationTarget && targetOrientations != null) {
      if (!_listEquals(_lastAppliedOrientations, targetOrientations)) {
        _lastAppliedOrientations = List<DeviceOrientation>.unmodifiable(
          targetOrientations,
        );
        _everAppliedOrientation = true;
        SystemChrome.setPreferredOrientations(targetOrientations);
      }
    } else if (_everAppliedOrientation && !hasOrientationTarget) {
      _lastAppliedOrientations = null;
      _everAppliedOrientation = false;
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    }
  }

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// রানটাইমে আলাদাভাবে স্ট্যাটাস বার ([OmniStatusBarStyle]), সিস্টেম নেভিগেশন বার
/// ([OmniSystemNavigationBarStyle]), ফুলস্ক্রিন ([OmniScreenMode]) ও রোটেশন
/// ([OmniOrientation]) নিয়ন্ত্রণের কন্ট্রোলার।
class OmniSystemUiController extends ChangeNotifier {
  OmniScreenMode? _screenMode;
  OmniStatusBarStyle? _statusBar;
  OmniSystemNavigationBarStyle? _systemNavigationBar;
  OmniOrientation? _orientation;
  List<DeviceOrientation>? _orientations;

  /// বর্তমান ওভাররাইড করা ডিসপ্লে মোড (`null` মানে অ্যাপ/থিম ডিফল্ট)।
  OmniScreenMode? get screenMode => _screenMode;

  /// বর্তমান ওভাররাইড করা [OmniStatusBarStyle] (`null` মানে থিম/অ্যাপ ডিফল্ট)।
  OmniStatusBarStyle? get statusBar => _statusBar;

  /// বর্তমান ওভাররাইড করা [OmniSystemNavigationBarStyle] (`null` মানে থিম/অ্যাপ ডিফল্ট)।
  OmniSystemNavigationBarStyle? get systemNavigationBar => _systemNavigationBar;

  /// বর্তমান ওভাররাইড করা রোটেশন মোড।
  OmniOrientation? get orientation => _orientation;

  /// বর্তমান কাস্টম ডিভাইস ওরিয়েন্টেশন লিস্ট।
  List<DeviceOrientation>? get orientations => _orientations;

  /// ডিসপ্লে/ফুলস্ক্রিন মোড পরিবর্তন করে (`null` করলে ডিফল্টে ফিরে আসে)।
  void setScreenMode(OmniScreenMode? mode) {
    if (_screenMode == mode) return;
    _screenMode = mode;
    notifyListeners();
  }

  /// ফুলস্ক্রিন চালু করে (`leanBack: true` দিলে ট্যাপে বার ফেরে)।
  void enterFullscreen({bool leanBack = false}) => setScreenMode(
    leanBack ? OmniScreenMode.fullscreenLean : OmniScreenMode.fullscreen,
  );

  /// ফুলস্ক্রিন বন্ধ করে এজ-টু-এজ মোডে ফিরে আসে।
  void exitFullscreen() => setScreenMode(OmniScreenMode.edgeToEdge);

  /// শুধু উপরের সিস্টেম স্ট্যাটাস বারের স্টাইল/রঙ পরিবর্তন করে (`null` করলে ডিফল্টে ফেরে)।
  void setStatusBar(OmniStatusBarStyle? style) {
    if (_statusBar == style) return;
    _statusBar = style;
    notifyListeners();
  }

  /// শুধু উপরের স্ট্যাটাস বার লুকায় (বটম নেভ বার আগের মতোই থাকে)।
  void hideStatusBar() => setStatusBar(
    (_statusBar ?? const OmniStatusBarStyle.transparent()).copyWith(
      visible: false,
    ),
  );

  /// উপরের স্ট্যাটাস বার পুনরায় দেখায়।
  void showStatusBar() => setStatusBar(
    (_statusBar ?? const OmniStatusBarStyle.transparent()).copyWith(
      visible: true,
    ),
  );

  /// শুধু নিচের সিস্টেম নেভিগেশন/গেস্টচার বারের স্টাইল/রঙ পরিবর্তন করে (`null` করলে ডিফল্টে ফেরে)।
  void setSystemNavigationBar(OmniSystemNavigationBarStyle? style) {
    if (_systemNavigationBar == style) return;
    _systemNavigationBar = style;
    notifyListeners();
  }

  /// শুধু নিচের সিস্টেম নেভ/গেস্টচার বার লুকায় (স্ট্যাটাস বার আগের মতোই থাকে)।
  void hideSystemNavigationBar() => setSystemNavigationBar(
    (_systemNavigationBar ?? const OmniSystemNavigationBarStyle.transparent())
        .copyWith(visible: false),
  );

  /// নিচের সিস্টেম নেভ/গেস্টচার বার পুনরায় দেখায়।
  void showSystemNavigationBar() => setSystemNavigationBar(
    (_systemNavigationBar ?? const OmniSystemNavigationBarStyle.transparent())
        .copyWith(visible: true),
  );

  /// প্রিসেট [OmniOrientation] সেট করে (যেমন `.portrait`, `.landscape`, `.auto`)।
  void setOrientation(OmniOrientation? orientation) {
    if (_orientation == orientation && _orientations == null) return;
    _orientation = orientation;
    _orientations = null;
    notifyListeners();
  }

  /// কাঁচা [DeviceOrientation] লিস্ট সেট করে।
  void setOrientations(List<DeviceOrientation>? orientations) {
    _orientations = orientations;
    _orientation = null;
    notifyListeners();
  }

  /// সব রানটাইম ওভাররাইড রিসেট করে অ্যাপ/থিমের মূল সেটিংসে ফেরে।
  void reset() {
    if (_screenMode == null &&
        _statusBar == null &&
        _systemNavigationBar == null &&
        _orientation == null &&
        _orientations == null) {
      return;
    }
    _screenMode = null;
    _statusBar = null;
    _systemNavigationBar = null;
    _orientation = null;
    _orientations = null;
    notifyListeners();
  }
}

/// অ্যাপ জুড়ে লাইভ [OmniSystemUiController] এবং বর্তমান কার্যকর মোড ও বার
/// কনফিগারেশন পৌঁছে দেয়।
class OmniSystemUiScope extends InheritedWidget {
  /// [OmniSystemUiScope] তৈরি করে।
  const OmniSystemUiScope({
    super.key,
    required this.controller,
    required this.effectiveScreenMode,
    this.effectiveOrientation,
    this.effectiveStatusBar = const OmniStatusBarStyle.transparent(),
    this.effectiveSystemNavigationBar =
        const OmniSystemNavigationBarStyle.transparent(),
    required super.child,
  });

  /// রানটাইম সিস্টেম UI ও রোটেশন কন্ট্রোলার।
  final OmniSystemUiController controller;

  /// বর্তমান কার্যকর [OmniScreenMode]।
  final OmniScreenMode effectiveScreenMode;

  /// বর্তমান কার্যকর [OmniOrientation] (যদি সেট করা থাকে)।
  final OmniOrientation? effectiveOrientation;

  /// বর্তমান কার্যকর [OmniStatusBarStyle] (উপরের স্ট্যাটাস বার)।
  final OmniStatusBarStyle effectiveStatusBar;

  /// বর্তমান কার্যকর [OmniSystemNavigationBarStyle] (নিচের নেভ/গেস্টচার বার)।
  final OmniSystemNavigationBarStyle effectiveSystemNavigationBar;

  /// নন-লিসেনিং কন্ট্রোলার লুকআপ (`null` হতে পারে)।
  static OmniSystemUiController? maybeControllerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OmniSystemUiScope>()?.controller;

  /// নন-লিসেনিং স্ট্যাটাস বার স্টাইল পড়ে।
  static OmniStatusBarStyle statusBarOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OmniSystemUiScope>()
          ?.effectiveStatusBar ??
      const OmniStatusBarStyle.transparent();

  /// নন-লিসেনিং সিস্টেম নেভিগেশন বার স্টাইল পড়ে।
  static OmniSystemNavigationBarStyle systemNavigationBarOf(
    BuildContext context,
  ) =>
      context
          .dependOnInheritedWidgetOfExactType<OmniSystemUiScope>()
          ?.effectiveSystemNavigationBar ??
      const OmniSystemNavigationBarStyle.transparent();

  /// বর্তমান কার্যকর [OmniScreenMode] পড়ে (পরিবর্তন হলে এই উইজেট রি-বিল্ড হয়)।
  static OmniScreenMode screenModeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OmniSystemUiScope>()
          ?.effectiveScreenMode ??
      OmniScreenMode.edgeToEdge;

  /// বর্তমান কার্যকর [OmniOrientation] পড়ে।
  static OmniOrientation? orientationOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OmniSystemUiScope>()
      ?.effectiveOrientation;

  @override
  bool updateShouldNotify(covariant OmniSystemUiScope oldWidget) =>
      !identical(controller, oldWidget.controller) ||
      effectiveScreenMode != oldWidget.effectiveScreenMode ||
      effectiveOrientation != oldWidget.effectiveOrientation ||
      effectiveStatusBar != oldWidget.effectiveStatusBar ||
      effectiveSystemNavigationBar != oldWidget.effectiveSystemNavigationBar;
}

/// প্রতিটি স্ক্রিন বা রাউটকে স্বয়ংক্রিয়ভাবে আলাদা [OmniStatusBarStyle] (ওপর),
/// আলাদা [OmniSystemNavigationBarStyle] (নিচ), ফুলস্ক্রিন মোড এবং ওরিয়েন্টেশন
/// দেওয়ার উইজেট।
///
/// কোনো স্ক্রিনের ভেতরে ম্যানুয়ালি `SystemChrome.setSystemUIOverlayStyle` বা
/// `AppBar(systemOverlayStyle: ...)` লেখার দরকার ছাড়াই প্রতিটি স্ক্রিনে (অ্যাপবারসহ
/// বা অ্যাপবার ছাড়া) রঙ, আইকন ব্রাইটনেস ও এজ-টু-এজ আচরণ নিশ্চিত করে।
class OmniSystemUi extends StatefulWidget {
  /// আলাদা [statusBar], [systemNavigationBar], [screenMode] এবং ওরিয়েন্টেশন দিয়ে র‍্যাপ করে।
  const OmniSystemUi({
    super.key,
    this.statusBar,
    this.systemNavigationBar,
    this.screenMode,
    this.orientation,
    this.orientations,
    this.applySystemChrome = true,
    this.brightness,
    this.fallbackTopColor,
    this.fallbackBottomColor,
    required this.child,
  });

  /// শুধু উপরের সিস্টেম স্ট্যাটাস বারের কনফিগারেশন।
  final OmniStatusBarStyle? statusBar;

  /// শুধু নিচের সিস্টেম নেভিগেশন / গেস্টচার সোয়াইপ বারের কনফিগারেশন।
  final OmniSystemNavigationBarStyle? systemNavigationBar;

  /// ডিসপ্লে/ফুলস্ক্রিন মোড ওভাররাইড (`fullscreen`, `edgeToEdge`, `normal` ইত্যাদি)।
  final OmniScreenMode? screenMode;

  /// প্রিসেট রোটেশন/ওরিয়েন্টেশন মোড ([OmniOrientation])।
  final OmniOrientation? orientation;

  /// কাস্টম [DeviceOrientation] তালিকা (সেট করলে [orientation]-এর চেয়ে অগ্রাধিকার পায়)।
  final List<DeviceOrientation>? orientations;

  /// `SystemChrome` প্লাটফর্ম চ্যানেল আপডেট করবে কি না।
  final bool applySystemChrome;

  /// থিম উজ্জ্বলতা (রুট `MaterialApp`-এর ওপরে ব্যবহারের জন্য ঐচ্ছিক ওভাররাইড)।
  final Brightness? brightness;

  /// স্বচ্ছ স্ট্যাটাস বার হলে আইকনের রঙ ঠিক করতে ব্যবহৃত ব্যাকগ্রাউন্ড রঙ।
  final Color? fallbackTopColor;

  /// স্বচ্ছ গেস্টচার/নেভ বার হলে আইকনের রঙ ঠিক করতে ব্যবহৃত ব্যাকগ্রাউন্ড রঙ।
  final Color? fallbackBottomColor;

  /// চাইল্ড উইজেট।
  final Widget child;

  @override
  State<OmniSystemUi> createState() => _OmniSystemUiState();
}

class _OmniSystemUiState extends State<OmniSystemUi> {
  final _OmniChromeEntry _entry = _OmniChromeEntry();
  bool _attached = false;

  bool get _hasBarOrModeOverride =>
      widget.statusBar != null ||
      widget.systemNavigationBar != null ||
      widget.screenMode != null;

  ({
    OmniScreenMode effectiveMode,
    OmniStatusBarStyle effectiveStatusBar,
    OmniSystemNavigationBarStyle effectiveNavBar,
    SystemUiOverlayStyle? overlayStyle,
    OmniSystemUiScope? parentScope,
  })
  _resolve(BuildContext context) {
    final parentScope = context
        .dependOnInheritedWidgetOfExactType<OmniSystemUiScope>();
    final effectiveStatusBar =
        widget.statusBar ??
        parentScope?.effectiveStatusBar ??
        const OmniStatusBarStyle.transparent();
    final effectiveNavBar =
        widget.systemNavigationBar ??
        parentScope?.effectiveSystemNavigationBar ??
        const OmniSystemNavigationBarStyle.transparent();
    final baseMode =
        widget.screenMode ??
        parentScope?.effectiveScreenMode ??
        OmniScreenMode.edgeToEdge;
    final effectiveMode = resolveEffectiveOmniScreenMode(
      baseMode,
      statusBar: widget.statusBar ?? parentScope?.effectiveStatusBar,
      systemNavigationBar:
          widget.systemNavigationBar ??
          parentScope?.effectiveSystemNavigationBar,
    );

    if (!_hasBarOrModeOverride) {
      return (
        effectiveMode: effectiveMode,
        effectiveStatusBar: effectiveStatusBar,
        effectiveNavBar: effectiveNavBar,
        overlayStyle: null,
        parentScope: parentScope,
      );
    }

    final theme = Theme.of(context);
    final brightness = widget.brightness ?? theme.brightness;
    final overlayStyle = composeOmniSystemUiOverlayStyle(
      brightness: brightness,
      screenMode: effectiveMode,
      statusBar: effectiveStatusBar,
      systemNavigationBar: effectiveNavBar,
      fallbackTopBackground:
          widget.fallbackTopColor ?? theme.scaffoldBackgroundColor,
      fallbackBottomBackground:
          widget.fallbackBottomColor ?? theme.scaffoldBackgroundColor,
    );
    return (
      effectiveMode: effectiveMode,
      effectiveStatusBar: effectiveStatusBar,
      effectiveNavBar: effectiveNavBar,
      overlayStyle: overlayStyle,
      parentScope: parentScope,
    );
  }

  void _syncEntry() {
    final tickerActive = TickerMode.valuesOf(context).enabled;
    final modalCurrent = ModalRoute.isCurrentOf(context);
    final isActive = tickerActive && (modalCurrent ?? true);
    final device = OmniResponsiveScope.deviceOf(context);
    final resolved = _resolve(context);

    final rawList = widget.orientations;
    final preset = widget.orientation;
    final hasExplicitOrientation = rawList != null || preset != null;

    _entry.active = isActive;
    _entry.screenMode = _hasBarOrModeOverride ? resolved.effectiveMode : null;
    _entry.overlayStyle = resolved.overlayStyle;
    _entry.hasExplicitOrientations = hasExplicitOrientation;
    _entry.orientations = rawList ?? preset?.resolveFor(device);

    if (widget.applySystemChrome) {
      if (!_attached) {
        _attached = true;
        _OmniChromeCoordinator.attach(_entry);
      } else {
        _OmniChromeCoordinator.sync();
      }
    } else if (_attached) {
      _attached = false;
      _OmniChromeCoordinator.detach(_entry);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncEntry();
  }

  @override
  void didUpdateWidget(covariant OmniSystemUi oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEntry();
  }

  @override
  void dispose() {
    if (_attached) {
      _attached = false;
      _OmniChromeCoordinator.detach(_entry);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolve(context);
    var child = widget.child;

    // রুট MaterialApp-এর ভেতরে পেজ-লেভেল বার ওভাররাইড থাকলে ঐ পেজের AppBar-ও যেন
    // আলাদা কোড ছাড়াই নতুন স্ট্যাটাস বার রঙ নেয় সেজন্য AppBarTheme আপডেট করি।
    final overlayStyle = resolved.overlayStyle;
    if (overlayStyle != null && widget.brightness == null) {
      final theme = Theme.of(context);
      if (theme.appBarTheme.systemOverlayStyle != overlayStyle) {
        child = Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              systemOverlayStyle: overlayStyle,
            ),
          ),
          child: child,
        );
      }
    }

    final parentScope = resolved.parentScope;
    if (parentScope != null &&
        (_hasBarOrModeOverride || widget.orientation != null)) {
      child = OmniSystemUiScope(
        controller: parentScope.controller,
        effectiveScreenMode: resolved.effectiveMode,
        effectiveOrientation:
            widget.orientation ?? parentScope.effectiveOrientation,
        effectiveStatusBar: resolved.effectiveStatusBar,
        effectiveSystemNavigationBar: resolved.effectiveNavBar,
        child: child,
      );
    }

    if (overlayStyle == null) {
      return child;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: child,
    );
  }
}

/// ১-ট্যাপে ফুলস্ক্রিন ↔ নরমাল (এজ-টু-এজ) মোড টগল করার আইকন বাটন।
class OmniFullscreenButton extends StatelessWidget {
  /// [AppBar] বা মিডিয়া কন্ট্রোল বারে ১-ক্লিক ফুলস্ক্রিন বাটন তৈরি করে।
  const OmniFullscreenButton({
    super.key,
    this.leanBack = false,
    this.enterIcon = const Icon(Icons.fullscreen_rounded),
    this.exitIcon = const Icon(Icons.fullscreen_exit_rounded),
    this.enterTooltip = 'Fullscreen',
    this.exitTooltip = 'Exit fullscreen',
  });

  /// `true` হলে ফুলস্ক্রিনে স্ক্রিন ট্যাপ করলেই সিস্টেম বার ফিরে আসে (`leanBack`)।
  final bool leanBack;

  /// ফুলস্ক্রিনে যাওয়ার আইকন।
  final Widget enterIcon;

  /// ফুলস্ক্রিন থেকে বের হওয়ার আইকন।
  final Widget exitIcon;

  /// প্রবেশের টুলটিপ।
  final String enterTooltip;

  /// বের হওয়ার টুলটিপ।
  final String exitTooltip;

  @override
  Widget build(BuildContext context) {
    final isFull = OmniSystemUiScope.screenModeOf(context).isFullscreen;
    final hasScope = OmniSystemUiScope.maybeControllerOf(context) != null;
    return IconButton(
      tooltip: isFull ? exitTooltip : enterTooltip,
      icon: isFull ? exitIcon : enterIcon,
      onPressed: !hasScope
          ? null
          : () => isFull
                ? context.exitFullscreen()
                : context.enterFullscreen(leanBack: leanBack),
    );
  }
}

/// যেকোনো `BuildContext` থেকে আলাদাভাবে স্ট্যাটাস বার, সিস্টেম নেভ বার,
/// ফুলস্ক্রিন মোড ও ওরিয়েন্টেশন নিয়ন্ত্রণের সহজ শর্টকাট।
extension OmniSystemUiContext on BuildContext {
  /// বর্তমান কার্যকর [OmniStatusBarStyle] (ওপরের স্ট্যাটাস বার)।
  OmniStatusBarStyle get statusBar => OmniSystemUiScope.statusBarOf(this);

  /// বর্তমান কার্যকর [OmniSystemNavigationBarStyle] (নিচের নেভ/গেস্টচার বার)।
  OmniSystemNavigationBarStyle get systemNavigationBar =>
      OmniSystemUiScope.systemNavigationBarOf(this);

  /// বর্তমান কার্যকর [OmniScreenMode] (`edgeToEdge`, `fullscreen` ইত্যাদি)।
  OmniScreenMode get screenMode => OmniSystemUiScope.screenModeOf(this);

  /// অ্যাপ বর্তমানে ফুলস্ক্রিন মোডে আছে কি না।
  bool get isFullscreen => screenMode.isFullscreen;

  /// বর্তমান [OmniOrientation] রোটেশন মোড (যদি সেট থাকে)।
  OmniOrientation? get orientationMode => OmniSystemUiScope.orientationOf(this);

  /// রানটাইমে ফুলস্ক্রিন, এজ-টু-এজ বা স্ট্যাটাস-বার-অনলি মোড সেট করে।
  void setScreenMode(OmniScreenMode mode) {
    final controller = OmniSystemUiScope.maybeControllerOf(this);
    if (controller != null) {
      controller.setScreenMode(mode);
      return;
    }
    SystemChrome.setEnabledSystemUIMode(
      mode.systemUiMode,
      overlays: mode.overlays,
    );
  }

  /// ১ লাইনে ফুলস্ক্রিন মোড চালু করে।
  void enterFullscreen({bool leanBack = false}) => setScreenMode(
    leanBack ? OmniScreenMode.fullscreenLean : OmniScreenMode.fullscreen,
  );

  /// ১ লাইনে ফুলস্ক্রিন থেকে এজ-টু-এজ মোডে ফিরে আসে।
  void exitFullscreen() => setScreenMode(OmniScreenMode.edgeToEdge);

  /// শুধু উপরের সিস্টেম স্ট্যাটাস বারের রঙ/স্টাইল পরিবর্তন করে (প্রতিটি স্ক্রিনে কার্যকর)।
  void setStatusBar(OmniStatusBarStyle style) {
    final controller = OmniSystemUiScope.maybeControllerOf(this);
    if (controller != null) {
      controller.setStatusBar(style);
      return;
    }
    final brightness = Theme.of(this).brightness;
    SystemChrome.setSystemUIOverlayStyle(
      composeOmniSystemUiOverlayStyle(
        brightness: brightness,
        screenMode: screenMode,
        statusBar: style,
        systemNavigationBar: systemNavigationBar,
      ),
    );
  }

  /// শুধু উপরের স্ট্যাটাস বার লুকায় (বটম বার আগের মতোই খোলা থাকে)।
  void hideStatusBar() =>
      OmniSystemUiScope.maybeControllerOf(this)?.hideStatusBar();

  /// উপরের স্ট্যাটাস বার পুনরায় দেখায়।
  void showStatusBar() =>
      OmniSystemUiScope.maybeControllerOf(this)?.showStatusBar();

  /// শুধু নিচের সিস্টেম নেভিগেশন বা গেস্টচার বারের রঙ/স্টাইল পরিবর্তন করে।
  void setSystemNavigationBar(OmniSystemNavigationBarStyle style) {
    final controller = OmniSystemUiScope.maybeControllerOf(this);
    if (controller != null) {
      controller.setSystemNavigationBar(style);
      return;
    }
    final brightness = Theme.of(this).brightness;
    SystemChrome.setSystemUIOverlayStyle(
      composeOmniSystemUiOverlayStyle(
        brightness: brightness,
        screenMode: screenMode,
        statusBar: statusBar,
        systemNavigationBar: style,
      ),
    );
  }

  /// শুধু নিচের সিস্টেম নেভিগেশন/গেস্টচার বার লুকায়।
  void hideSystemNavigationBar() =>
      OmniSystemUiScope.maybeControllerOf(this)?.hideSystemNavigationBar();

  /// নিচের সিস্টেম নেভিগেশন/গেস্টচার বার পুনরায় দেখায়।
  void showSystemNavigationBar() =>
      OmniSystemUiScope.maybeControllerOf(this)?.showSystemNavigationBar();

  /// ১ লাইনে ডিভাইস ওরিয়েন্টেশন/রোটেশন মোড সেট করে (`portrait`, `landscape`, `auto`, `portraitOnMobile`)।
  void setOrientation(OmniOrientation orientation) {
    final controller = OmniSystemUiScope.maybeControllerOf(this);
    if (controller != null) {
      controller.setOrientation(orientation);
      return;
    }
    final device = OmniResponsiveScope.deviceOf(this);
    SystemChrome.setPreferredOrientations(orientation.resolveFor(device));
  }

  /// শুধু পোর্ট্রেট (`portraitUp`) মোডে লক করে।
  void lockPortrait() => setOrientation(OmniOrientation.portrait);

  /// শুধু ল্যান্ডস্কেপ (`landscapeLeft` / `landscapeRight`) মোডে রাখে।
  void allowLandscape() => setOrientation(OmniOrientation.landscape);

  /// সেন্সর অনুযায়ী ৪ দিকেই অটো-রোটেশন চালু করে।
  void allowAutoRotate() => setOrientation(OmniOrientation.auto);

  /// সিস্টেম UI ও রোটেশন ওভাররাইড রিসেট করে অ্যাপ ডিফল্টে ফিরিয়ে আনে।
  void resetSystemUi() => OmniSystemUiScope.maybeControllerOf(this)?.reset();
}
