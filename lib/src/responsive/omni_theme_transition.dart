import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ডার্ক/লাইট মোড, কালার প্যালেট বা থিম স্টাইল বদলানোর সময় স্ক্রিনের ওপর দিয়ে
/// যে ধরনের ভিজ্যুয়াল অ্যানিমেশন চলবে তা নির্ধারণ করে।
enum OmniThemeAnimationMode {
  /// ট্যাপ করা বাটন বা স্ক্রিনের কেন্দ্র থেকে গোল রিপল/ওয়েভ বড় হয়ে পুরো স্ক্রিনজুড়ে
  /// নতুন থিম ও রঙ ছড়িয়ে পড়ে।
  circularReveal,

  /// পুরোনো স্ক্রিন গোল হয়ে ভেতরের দিকে সংকুচিত হতে থাকে এবং চারপাশ থেকে নতুন
  /// থিম বেরিয়ে আসে।
  circularShrink,

  /// বাম থেকে ডানে (RTL-এ ডান থেকে বামে) মসৃণ সুইপ ওয়েভে স্ক্রিনের রঙ বদলে যায়।
  horizontalWipe,

  /// ওপর থেকে নিচে পর্দা নামার মতো স্মুথ কার্টেইন সুইপে থিম ও কালার পরিবর্তন হয়।
  verticalWipe,

  /// ওপরের বাম কোণা থেকে নিচের ডান কোণায় ডায়াগোনাল সুইপে পুরো স্ক্রিন বদলায়।
  diagonalSweep,

  /// মাঝখান থেকে দুই দিকে পর্দা সরে গিয়ে সিনেমা-স্টাইলে নতুন থিম উন্মোচিত হয়।
  splitShutter,

  /// ট্যাপ পয়েন্ট বা কেন্দ্র থেকে ডায়মন্ড (রম্বস) আকারে ছড়িয়ে স্ক্রিনের থিম বদলায়।
  diamondReveal,

  /// পুরোনো ও নতুন পুরো স্ক্রিন মসৃণ আলফা ক্রসফেডে মিশে রূপান্তরিত হয়।
  crossfade,

  /// স্ক্রিন ওভারলে ছাড়াই অ্যাপের প্রতিটি রঙ, টেক্সট, কার্ড ও বাটন মসৃণভাবে
  /// কালার ইন্টারপোলেশনে (`Color.lerp`) রূপান্তরিত হয়।
  colorMorph,

  /// কোনো অ্যানিমেশন ছাড়াই তাৎক্ষণিক পরিবর্তন।
  none;

  /// UI ও পিকারে দেখানোর সংক্ষিপ্ত নাম।
  String get label => switch (this) {
    OmniThemeAnimationMode.circularReveal => 'Circular Reveal',
    OmniThemeAnimationMode.circularShrink => 'Circular Shrink',
    OmniThemeAnimationMode.horizontalWipe => 'Horizontal Wipe',
    OmniThemeAnimationMode.verticalWipe => 'Vertical Wipe',
    OmniThemeAnimationMode.diagonalSweep => 'Diagonal Sweep',
    OmniThemeAnimationMode.splitShutter => 'Split Shutter',
    OmniThemeAnimationMode.diamondReveal => 'Diamond Reveal',
    OmniThemeAnimationMode.crossfade => 'Crossfade',
    OmniThemeAnimationMode.colorMorph => 'Color Morph',
    OmniThemeAnimationMode.none => 'Instant',
  };

  /// এই অ্যানিমেশন কীভাবে কাজ করে তার সংক্ষিপ্ত বিবরণ।
  String get description => switch (this) {
    OmniThemeAnimationMode.circularReveal =>
      'ট্যাপ পয়েন্ট বা কেন্দ্র থেকে গোল ওয়েভ ছড়িয়ে থিম ও কালার বদলায়',
    OmniThemeAnimationMode.circularShrink =>
      'পুরোনো স্ক্রিন গোল হয়ে ভেতরে মিশে গিয়ে নতুন থিম বের হয়',
    OmniThemeAnimationMode.horizontalWipe =>
      'পাশাপাশি মসৃণ সুইপ ওয়েভে পুরো স্ক্রিনের রঙ পরিবর্তন হয়',
    OmniThemeAnimationMode.verticalWipe =>
      'ওপর থেকে নিচে মসৃণ পর্দার মতো রঙ পরিবর্তন হয়',
    OmniThemeAnimationMode.diagonalSweep =>
      'কোণাকুণি ডায়াগোনাল সুইপে পুরো স্ক্রিন বদলে যায়',
    OmniThemeAnimationMode.splitShutter =>
      'মাঝখান থেকে দুই পাশে শাটার সরে নতুন থিম ফুটে ওঠে',
    OmniThemeAnimationMode.diamondReveal =>
      'ডায়মন্ড আকারে কেন্দ্র বা ট্যাপ পয়েন্ট থেকে থিম ছড়িয়ে পড়ে',
    OmniThemeAnimationMode.crossfade =>
      'পুরোনো ও নতুন পুরো স্ক্রিন মসৃণ ক্রসফেডে মিশে যায়',
    OmniThemeAnimationMode.colorMorph =>
      'সব রঙ, কার্ড ও বাটন ধাপে ধাপে স্মুথ কালার মর্ফ হয়',
    OmniThemeAnimationMode.none => 'অ্যানিমেশন ছাড়া তাৎক্ষণিক থিম পরিবর্তন',
  };

  /// পিকার চিপে দেখানোর উপযুক্ত আইকন।
  IconData get icon => switch (this) {
    OmniThemeAnimationMode.circularReveal => Icons.radar_outlined,
    OmniThemeAnimationMode.circularShrink => Icons.radio_button_checked,
    OmniThemeAnimationMode.horizontalWipe => Icons.swap_horiz_rounded,
    OmniThemeAnimationMode.verticalWipe => Icons.vertical_align_bottom_rounded,
    OmniThemeAnimationMode.diagonalSweep => Icons.trending_up_rounded,
    OmniThemeAnimationMode.splitShutter => Icons.curtains_outlined,
    OmniThemeAnimationMode.diamondReveal => Icons.diamond_outlined,
    OmniThemeAnimationMode.crossfade => Icons.blur_on_rounded,
    OmniThemeAnimationMode.colorMorph => Icons.gradient_rounded,
    OmniThemeAnimationMode.none => Icons.flash_on_outlined,
  };

  /// এই মোডে স্ক্রিনের ওপর GPU স্ন্যাপশট ওভারলে অ্যানিমেশন চলে কি না।
  bool get usesScreenOverlay =>
      this != OmniThemeAnimationMode.colorMorph &&
      this != OmniThemeAnimationMode.none;
}

/// ডার্ক/লাইট মোড, কালার প্যালেট (`themeId`) ও থিম স্টাইল (`OmniThemeStyle`)
/// পরিবর্তনের সময় পুরো স্ক্রিনের অ্যানিমেশন কনফিগারেশন।
///
/// ডিফল্টভাবেই [OmniThemeAnimationMode.circularReveal] সক্রিয় থাকে — যেখানে
/// ইউজার যে বাটন বা প্যালেট কার্ডে ট্যাপ করবেন ঠিক সেখান থেকেই গোল রঙিন ওয়েভ
/// ছড়িয়ে পুরো স্ক্রিনের থিম ও কালার বদলে যাবে। চাইলে ডার্ক মোড ও কালার প্যালেটের
/// জন্য একই বা আলাদা (`paletteMode`) অ্যানিমেশন দিতে পারেন:
/// ```dart
/// OmniTheme(
///   seedColor: Colors.indigo,
///   animation: const OmniThemeAnimation(
///     mode: OmniThemeAnimationMode.circularReveal,
///     paletteMode: OmniThemeAnimationMode.diagonalSweep,
///   ),
/// )
/// ```
@immutable
class OmniThemeAnimation {
  /// ডার্ক মোড ও কালার প্যালেট পরিবর্তনের স্ক্রিন অ্যানিমেশন তৈরি করে।
  const OmniThemeAnimation({
    this.mode = OmniThemeAnimationMode.circularReveal,
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 480),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubicEmphasized,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 3.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : assert(edgeGlowWidth >= 0);

  /// ট্যাপ পজিশন বা কেন্দ্র থেকে গোল রিপল ছড়ানো অ্যানিমেশন।
  const OmniThemeAnimation.circularReveal({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 480),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubicEmphasized,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 3.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.circularReveal,
       assert(edgeGlowWidth >= 0);

  /// পুরোনো স্ক্রিন গোল হয়ে ভেতরের দিকে সংকুচিত হয়ে নতুন থিম বের হওয়া অ্যানিমেশন।
  const OmniThemeAnimation.circularShrink({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 460),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 3.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.circularShrink,
       assert(edgeGlowWidth >= 0);

  /// বাম থেকে ডানে অনুভূমিক সুইপ অ্যানিমেশন।
  const OmniThemeAnimation.horizontalWipe({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 420),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.centerLeft,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 3.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.horizontalWipe,
       assert(edgeGlowWidth >= 0);

  /// ওপর থেকে নিচে কার্টেইন/পর্দা নামার সুইপ অ্যানিমেশন।
  const OmniThemeAnimation.verticalWipe({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 420),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.topCenter,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 3.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.verticalWipe,
       assert(edgeGlowWidth >= 0);

  /// কোণাকুণি ডায়াগোনাল সুইপ অ্যানিমেশন।
  const OmniThemeAnimation.diagonalSweep({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 460),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.topLeft,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 3.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.diagonalSweep,
       assert(edgeGlowWidth >= 0);

  /// মাঝখান থেকে দুই দিকে পর্দা সরে থিম পরিবর্তনের শাটার অ্যানিমেশন।
  const OmniThemeAnimation.splitShutter({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 440),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 3.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.splitShutter,
       assert(edgeGlowWidth >= 0);

  /// ডায়মন্ড আকারে চারদিকে ছড়ানো থিম রিভিল অ্যানিমেশন।
  const OmniThemeAnimation.diamondReveal({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 480),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubicEmphasized,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 3.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.diamondReveal,
       assert(edgeGlowWidth >= 0);

  /// পুরো স্ক্রিন মসৃণ ক্রসফেড অ্যানিমেশন।
  const OmniThemeAnimation.crossfade({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 340),
    this.paletteDuration,
    this.curve = Curves.easeInOut,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = false,
    this.showEdgeGlow = false,
    this.edgeGlowColor,
    this.edgeGlowWidth = 0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.crossfade;

  /// ওভারলে ছাড়াই সব রঙ, কার্ড ও টেক্সট ধাপে ধাপে মসৃণ কালার মর্ফ অ্যানিমেশন।
  const OmniThemeAnimation.colorMorph({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 420),
    this.paletteDuration,
    this.curve = Curves.easeInOut,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = false,
    this.showEdgeGlow = false,
    this.edgeGlowColor,
    this.edgeGlowWidth = 0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.colorMorph;

  /// কোনো অ্যানিমেশন ছাড়াই তাৎক্ষণিক পরিবর্তন।
  const OmniThemeAnimation.none()
    : mode = OmniThemeAnimationMode.none,
      paletteMode = OmniThemeAnimationMode.none,
      styleMode = OmniThemeAnimationMode.none,
      duration = Duration.zero,
      paletteDuration = Duration.zero,
      curve = Curves.linear,
      origin = null,
      fallbackOrigin = Alignment.center,
      autoTapOrigin = false,
      showEdgeGlow = false,
      edgeGlowColor = null,
      edgeGlowWidth = 0,
      animateBrightness = false,
      animatePalette = false,
      animateStyle = false,
      respectReducedMotion = true;

  /// ডার্ক/লাইট মোড এবং ডিফল্ট থিম পরিবর্তনের অ্যানিমেশন ধরন।
  final OmniThemeAnimationMode mode;

  /// কালার প্যালেট বদলানোর জন্য ঐচ্ছিক আলাদা অ্যানিমেশন (`null` হলে [mode] ব্যবহার হয়)।
  final OmniThemeAnimationMode? paletteMode;

  /// [OmniThemeStyle] বদলানোর জন্য ঐচ্ছিক আলাদা অ্যানিমেশন (`null` হলে `paletteMode ?? mode`)।
  final OmniThemeAnimationMode? styleMode;

  /// অ্যানিমেশনের সময়কাল (ডিফল্ট `480ms`)।
  final Duration duration;

  /// কালার প্যালেট বদলানোর সময়কাল (`null` হলে [duration] ব্যবহার হয়)।
  final Duration? paletteDuration;

  /// অ্যানিমেশনের ইজিং কার্ভ।
  final Curve curve;

  /// `circularReveal` / `circularShrink` / `diamondReveal`-এর জন্য নির্দিষ্ট উৎস পজিশন।
  final Offset? origin;

  /// ট্যাপের উৎস না থাকলে কোন অ্যালাইনমেন্ট থেকে অ্যানিমেশন ছড়াবে।
  final AlignmentGeometry fallbackOrigin;

  /// বাটন বা প্যালেটে ট্যাপ করার পজিশন থেকে স্বয়ংক্রিয়ভাবে অ্যানিমেশন শুরু করবে কি না।
  final bool autoTapOrigin;

  /// সুইপ বা রিপল বর্ডারের গায়ে নতুন ব্র্যান্ড কালারের হালকা আলোকচ্ছটা দেখাবে কি না।
  final bool showEdgeGlow;

  /// বর্ডার গ্লো লাইনের কাস্টম রঙ (`null` হলে নতুন থিমের `primaryColor` নেয়)।
  final Color? edgeGlowColor;

  /// বর্ডার গ্লো লাইনের পুরুত্ব।
  final double edgeGlowWidth;

  /// ডার্ক ↔ লাইট বা সিস্টেম ব্রাইটনেস বদলালে অ্যানিমেট করবে কি না।
  final bool animateBrightness;

  /// কালার প্যালেট (`themeId` বা কালার) বদলালে অ্যানিমেট করবে কি না।
  final bool animatePalette;

  /// ডিজাইন স্টাইল (`OmniThemeStyle`) বদলালে অ্যানিমেট করবে কি না।
  final bool animateStyle;

  /// OS-এর "Reduce Motion / Disable Animations" চালু থাকলে অ্যানিমেশন বন্ধ রাখবে কি না।
  final bool respectReducedMotion;

  /// বর্তমান পরিবর্তনের ধরনের সাথে মিলিয়ে কার্যকর অ্যানিমেশন মোড বের করে।
  OmniThemeAnimationMode effectiveModeFor({
    required bool brightnessChanged,
    required bool paletteChanged,
    required bool styleChanged,
    OmniThemeAnimationMode? runtimeOverride,
  }) {
    final allowBrightness = brightnessChanged && animateBrightness;
    final allowPalette = paletteChanged && animatePalette;
    final allowStyle = styleChanged && animateStyle;
    if (!allowBrightness && !allowPalette && !allowStyle) {
      return OmniThemeAnimationMode.none;
    }
    if (runtimeOverride != null) return runtimeOverride;
    if (allowBrightness) return mode;
    if (allowPalette) return paletteMode ?? mode;
    return styleMode ?? paletteMode ?? mode;
  }

  /// পরিবর্তনের ধরনের সাথে মিলিয়ে অ্যানিমেশনের সময়কাল বের করে।
  Duration effectiveDurationFor({
    required bool brightnessChanged,
    required bool paletteChanged,
  }) {
    if (paletteChanged && !brightnessChanged) {
      return paletteDuration ?? duration;
    }
    return duration;
  }

  /// নির্বাচিত প্রোপার্টি বদলে নতুন [OmniThemeAnimation] কপি তৈরি করে।
  OmniThemeAnimation copyWith({
    OmniThemeAnimationMode? mode,
    OmniThemeAnimationMode? paletteMode,
    OmniThemeAnimationMode? styleMode,
    Duration? duration,
    Duration? paletteDuration,
    Curve? curve,
    Offset? origin,
    AlignmentGeometry? fallbackOrigin,
    bool? autoTapOrigin,
    bool? showEdgeGlow,
    Color? edgeGlowColor,
    double? edgeGlowWidth,
    bool? animateBrightness,
    bool? animatePalette,
    bool? animateStyle,
    bool? respectReducedMotion,
  }) => OmniThemeAnimation(
    mode: mode ?? this.mode,
    paletteMode: paletteMode ?? this.paletteMode,
    styleMode: styleMode ?? this.styleMode,
    duration: duration ?? this.duration,
    paletteDuration: paletteDuration ?? this.paletteDuration,
    curve: curve ?? this.curve,
    origin: origin ?? this.origin,
    fallbackOrigin: fallbackOrigin ?? this.fallbackOrigin,
    autoTapOrigin: autoTapOrigin ?? this.autoTapOrigin,
    showEdgeGlow: showEdgeGlow ?? this.showEdgeGlow,
    edgeGlowColor: edgeGlowColor ?? this.edgeGlowColor,
    edgeGlowWidth: edgeGlowWidth ?? this.edgeGlowWidth,
    animateBrightness: animateBrightness ?? this.animateBrightness,
    animatePalette: animatePalette ?? this.animatePalette,
    animateStyle: animateStyle ?? this.animateStyle,
    respectReducedMotion: respectReducedMotion ?? this.respectReducedMotion,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniThemeAnimation &&
          mode == other.mode &&
          paletteMode == other.paletteMode &&
          styleMode == other.styleMode &&
          duration == other.duration &&
          paletteDuration == other.paletteDuration &&
          curve == other.curve &&
          origin == other.origin &&
          fallbackOrigin == other.fallbackOrigin &&
          autoTapOrigin == other.autoTapOrigin &&
          showEdgeGlow == other.showEdgeGlow &&
          edgeGlowColor == other.edgeGlowColor &&
          edgeGlowWidth == other.edgeGlowWidth &&
          animateBrightness == other.animateBrightness &&
          animatePalette == other.animatePalette &&
          animateStyle == other.animateStyle &&
          respectReducedMotion == other.respectReducedMotion;

  @override
  int get hashCode => Object.hash(
    mode,
    paletteMode,
    styleMode,
    duration,
    paletteDuration,
    curve,
    origin,
    fallbackOrigin,
    autoTapOrigin,
    showEdgeGlow,
    edgeGlowColor,
    edgeGlowWidth,
    animateBrightness,
    animatePalette,
    animateStyle,
    respectReducedMotion,
  );
}

/// যেকোনো থিম বা কালার প্যালেট পরিবর্তনে পুরো স্ক্রিনের ওপর ভিজ্যুয়াল
/// অ্যানিমেশন (`circularReveal`, `horizontalWipe`, `diagonalSweep`, `colorMorph`
/// ইত্যাদি) চালানোর জিরো-ল্যাগ হোস্ট উইজেট।
///
/// `OmniApp.material(omniTheme: ...)` বা `OmniApp.material(themeAnimation: ...)`
/// দিলে এটি স্বয়ংক্রিয়ভাবে ইনস্টল হয়ে যায়। চাইলে আলাদা সাবট্রি র‍্যাপ করতেও
/// সরাসরি ব্যবহার করা যাবে।
class OmniThemeTransition<T> extends StatefulWidget {
  /// [value] বদলালেই [animation] অনুযায়ী মসৃণ স্ক্রিন/কালার ট্রানজিশন চালায়।
  const OmniThemeTransition({
    super.key,
    required this.value,
    this.animation = const OmniThemeAnimation(),
    required this.builder,
    this.shouldAnimate,
    this.resolveMode,
    this.resolveDuration,
    this.resolveGlowColor,
    this.suppressAnimationToken = 0,
    this.takeExplicitOrigin,
  });

  /// বর্তমান লক্ষ্য মান (যেমন থিম, কালার প্যালেট বা `ThemeMode` স্ন্যাপশট)।
  final T value;

  /// ট্রানজিশন অ্যানিমেশন কনফিগারেশন।
  final OmniThemeAnimation animation;

  /// প্রদর্শিত [displayedValue] ও `MaterialApp` থিম অ্যানিমেশন সেটিংস দিয়ে চাইল্ড তৈরি করে।
  final Widget Function(
    BuildContext context,
    T displayedValue,
    Duration materialAnimationDuration,
    Curve materialAnimationCurve,
  )
  builder;

  /// দুটি মান দৃশ্যত আলাদা হলে তবেই অ্যানিমেট করবে কি না।
  final bool Function(T previous, T next)? shouldAnimate;

  /// প্রতিটি পরিবর্তনের জন্য কোন [OmniThemeAnimationMode] চলবে তা ঠিক করে।
  final OmniThemeAnimationMode Function(T previous, T next)? resolveMode;

  /// প্রতিটি পরিবর্তনের সময়কাল বের করে।
  final Duration Function(T previous, T next)? resolveDuration;

  /// নতুন থিমের ওয়েভ বর্ডার গ্লো কালার বের করে।
  final Color? Function(T next)? resolveGlowColor;

  /// অ্যানিমেশন ছাড়াই সিঙ্ক করার টোকেন (যেমন স্টোরেজ হাইড্রেশনের সময় বাড়ানো হয়)।
  final int suppressAnimationToken;

  /// কোড থেকে explicitly পাস করা ট্যাপ/উৎস পজিশন একবারের জন্য পড়ে।
  final Offset? Function()? takeExplicitOrigin;

  @override
  State<OmniThemeTransition<T>> createState() => _OmniThemeTransitionState<T>();
}

class _OmniThemeTransitionState<T> extends State<OmniThemeTransition<T>>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'OmniThemeBoundary');
  late final AnimationController _animController;

  late T _displayedValue;
  T? _pendingValue;
  late int _seenSuppressToken;
  bool _captureScheduled = false;

  ui.Image? _snapshot;
  OmniThemeAnimationMode? _activeMode;
  Offset? _activeOrigin;
  Color _activeGlowColor = const Color(0xFF2563EB);
  double _activeGlowWidth = 3.0;
  bool _activeShowGlow = true;
  TextDirection _activeDirection = TextDirection.ltr;

  late Duration _materialAnimDuration;
  late Curve _materialAnimCurve;

  // কোনো জেসচার কনফ্লিক্ট ছাড়াই ট্যাপ পজিশন ধরে রাখার জন্য:
  Offset? _lastTapOrigin;
  bool _pointerDragged = false;
  int _activePointer = -1;

  @override
  void initState() {
    super.initState();
    _displayedValue = widget.value;
    _seenSuppressToken = widget.suppressAnimationToken;
    _animController = AnimationController(
      vsync: this,
      duration: widget.animation.duration > Duration.zero
          ? widget.animation.duration
          : const Duration(milliseconds: 1),
    )..addStatusListener(_onAnimStatus);
    if (widget.animation.mode == OmniThemeAnimationMode.colorMorph) {
      _materialAnimDuration = widget.animation.duration;
      _materialAnimCurve = widget.animation.curve;
    } else {
      _materialAnimDuration = Duration.zero;
      _materialAnimCurve = Curves.linear;
    }
  }

  bool _startingTransition = false;

  void _disposeSnapshot() {
    final old = _snapshot;
    _snapshot = null;
    old?.dispose();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _startingTransition) {
      return;
    }
    if (!mounted) {
      _disposeSnapshot();
      return;
    }
    setState(() {
      _disposeSnapshot();
      _activeMode = null;
      _activeOrigin = null;
    });
  }

  @override
  void didUpdateWidget(covariant OmniThemeTransition<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.suppressAnimationToken != _seenSuppressToken) {
      _seenSuppressToken = widget.suppressAnimationToken;
      _pendingValue = null;
      _captureScheduled = false;
      _lastTapOrigin = null;
      widget.takeExplicitOrigin?.call();
      _animController.stop();
      _disposeSnapshot();
      _activeMode = null;
      _displayedValue = widget.value;
      _materialAnimDuration = Duration.zero;
      _materialAnimCurve = Curves.linear;
      return;
    }

    if (widget.value != _displayedValue && widget.value != _pendingValue) {
      if (_pendingValue != null) {
        // ক্যাপচারের আগেই আরেকটি মান এসেছে; ফ্রেম শেষে বর্তমান স্থির স্ক্রিন
        // থেকেই সর্বশেষ লক্ষ্য মানে অ্যানিমেট করব।
        _pendingValue = widget.value;
      } else {
        _beginTransition(prev: _displayedValue, next: widget.value);
      }
    }
  }

  bool _isReducedMotionEnabled() {
    if (!widget.animation.respectReducedMotion) return false;
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  void _applyImmediate(
    T next, {
    required Duration duration,
    Curve curve = Curves.linear,
  }) {
    _animController.stop();
    _disposeSnapshot();
    _pendingValue = null;
    _activeMode = null;
    _displayedValue = next;
    _materialAnimDuration = duration;
    _materialAnimCurve = curve;
    _lastTapOrigin = null;
    widget.takeExplicitOrigin?.call();
  }

  void _beginTransition({required T prev, required T next}) {
    final allow = widget.shouldAnimate?.call(prev, next) ?? (prev != next);
    if (!allow) {
      _applyImmediate(next, duration: Duration.zero);
      return;
    }

    final mode = widget.resolveMode?.call(prev, next) ?? widget.animation.mode;
    final duration =
        widget.resolveDuration?.call(prev, next) ?? widget.animation.duration;
    if (_isReducedMotionEnabled() ||
        mode == OmniThemeAnimationMode.none ||
        duration <= Duration.zero) {
      _applyImmediate(next, duration: Duration.zero);
      return;
    }

    if (mode == OmniThemeAnimationMode.colorMorph) {
      _applyImmediate(next, duration: duration, curve: widget.animation.curve);
      return;
    }

    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null &&
        boundary.attached &&
        boundary.hasSize &&
        !boundary.size.isEmpty &&
        !boundary.debugNeedsPaint) {
      final snap = _tryCapture(boundary);
      if (snap != null) {
        _startOverlayTransitionLocked(
          next: next,
          snapshot: snap,
          mode: mode,
          duration: duration,
          boundary: boundary,
        );
        return;
      }
    }

    // ইনক রিপল বা প্যারেন্ট একই ফ্রেমে পেইন্ট সূচি করে রাখলে ফ্রেম-শেষ পর্যন্ত
    // পুরোনো থিম ধরে রেখে পেইন্ট হতেই ক্লিন স্ন্যাপশট নিয়ে অ্যানিমেশন শুরু করি।
    _pendingValue = next;
    if (!_captureScheduled) {
      _captureScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _completeCapture());
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void _completeCapture() {
    _captureScheduled = false;
    if (!mounted) {
      _pendingValue = null;
      return;
    }
    final next = _pendingValue;
    _pendingValue = null;
    if (next == null || next == _displayedValue) return;

    final prev = _displayedValue;
    final mode = widget.resolveMode?.call(prev, next) ?? widget.animation.mode;
    final duration =
        widget.resolveDuration?.call(prev, next) ?? widget.animation.duration;

    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    ui.Image? snap;
    if (boundary != null &&
        boundary.attached &&
        boundary.hasSize &&
        !boundary.size.isEmpty &&
        !boundary.debugNeedsPaint) {
      snap = _tryCapture(boundary);
    }

    setState(() {
      if (snap != null && boundary != null) {
        _startOverlayTransitionLocked(
          next: next,
          snapshot: snap,
          mode: mode,
          duration: duration,
          boundary: boundary,
        );
      } else {
        // স্ন্যাপশট নেওয়া সম্ভব না হলে নিরাপদ কালার মর্ফ ফলব্যাক।
        _disposeSnapshot();
        _activeMode = null;
        _displayedValue = next;
        _materialAnimDuration = duration;
        _materialAnimCurve = widget.animation.curve;
      }
    });
  }

  ui.Image? _tryCapture(RenderRepaintBoundary boundary) {
    final view = View.maybeOf(context);
    final rawDpr =
        view?.devicePixelRatio ?? MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final dpr = rawDpr.clamp(1.0, 3.0);
    try {
      return boundary.toImageSync(pixelRatio: dpr);
    } catch (_) {
      return null;
    }
  }

  void _startOverlayTransitionLocked({
    required T next,
    required ui.Image snapshot,
    required OmniThemeAnimationMode mode,
    required Duration duration,
    required RenderRepaintBoundary boundary,
  }) {
    _disposeSnapshot();
    _snapshot = snapshot;
    _displayedValue = next;
    _activeMode = mode;
    _materialAnimDuration = Duration.zero;
    _materialAnimCurve = Curves.linear;

    final dir = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _activeDirection = dir;

    final rect = Offset.zero & boundary.size;
    final explicit = widget.takeExplicitOrigin?.call() ?? widget.animation.origin;
    final autoTap =
        (widget.animation.autoTapOrigin && !_pointerDragged) ? _lastTapOrigin : null;
    _lastTapOrigin = null;

    final globalOrigin = explicit ?? autoTap;
    if (globalOrigin != null) {
      final local = boundary.globalToLocal(globalOrigin);
      _activeOrigin = Offset(
        local.dx.clamp(0.0, boundary.size.width),
        local.dy.clamp(0.0, boundary.size.height),
      );
    } else {
      _activeOrigin = widget.animation.fallbackOrigin.resolve(dir).withinRect(rect);
    }

    _activeGlowColor =
        widget.animation.edgeGlowColor ??
        widget.resolveGlowColor?.call(next) ??
        const Color(0xFF2563EB);
    _activeGlowWidth = widget.animation.edgeGlowWidth;
    _activeShowGlow = widget.animation.showEdgeGlow;

    _startingTransition = true;
    try {
      _animController.duration = duration;
      _animController.forward(from: 0.0);
    } finally {
      _startingTransition = false;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointer = event.pointer;
    _lastTapOrigin = event.position;
    _pointerDragged = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _pointerDragged) return;
    final down = _lastTapOrigin;
    if (down != null && (event.position - down).distance > kTouchSlop) {
      _pointerDragged = true;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointer) {
      _lastTapOrigin = null;
      _pointerDragged = false;
    }
  }

  @override
  void dispose() {
    _animController.removeStatusListener(_onAnimStatus);
    _animController.dispose();
    _pendingValue = null;
    _disposeSnapshot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = RepaintBoundary(
      key: _boundaryKey,
      child: widget.builder(
        context,
        _displayedValue,
        _materialAnimDuration,
        _materialAnimCurve,
      ),
    );

    final snap = _snapshot;
    final activeMode = _activeMode;
    final showOverlay =
        snap != null && activeMode != null && activeMode.usesScreenOverlay;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerCancel: _onPointerCancel,
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.passthrough,
        textDirection: TextDirection.ltr,
        children: [
          content,
          if (showOverlay)
            Positioned.fill(
              key: const ValueKey<String>('omni_theme_transition_overlay'),
              child: IgnorePointer(
                child: CustomPaint(
                  isComplex: true,
                  willChange: true,
                  painter: _OmniThemeTransitionPainter(
                    snapshot: snap,
                    mode: activeMode,
                    animation: _animController,
                    curve: widget.animation.curve,
                    origin: _activeOrigin ?? Offset.zero,
                    glowColor: _activeGlowColor,
                    showGlow: _activeShowGlow,
                    glowWidth: _activeGlowWidth,
                    textDirection: _activeDirection,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OmniThemeTransitionPainter extends CustomPainter {
  _OmniThemeTransitionPainter({
    required this.snapshot,
    required this.mode,
    required this.animation,
    required this.curve,
    required this.origin,
    required this.glowColor,
    required this.showGlow,
    required this.glowWidth,
    required this.textDirection,
  }) : super(repaint: animation);

  final ui.Image snapshot;
  final OmniThemeAnimationMode mode;
  final Animation<double> animation;
  final Curve curve;
  final Offset origin;
  final Color glowColor;
  final bool showGlow;
  final double glowWidth;
  final TextDirection textDirection;

  static double _maxCornerDistance(Offset p, Size s) {
    final dx = math.max(p.dx, s.width - p.dx);
    final dy = math.max(p.dy, s.height - p.dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _maxManhattanDistance(Offset p, Size s) {
    final dx = math.max(p.dx, s.width - p.dx);
    final dy = math.max(p.dy, s.height - p.dy);
    return dx + dy;
  }

  void _strokeGlowPath(Canvas canvas, Path path, double envelope) {
    if (!showGlow || glowWidth <= 0 || envelope <= 0.01) return;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth * 3.2
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.18 * envelope),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.55 * envelope),
    );
  }

  void _strokeGlowLine(Canvas canvas, Offset a, Offset b, double envelope) {
    if (!showGlow || glowWidth <= 0 || envelope <= 0.01) return;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = glowWidth * 3.2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.18 * envelope),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = glowWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.60 * envelope),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || snapshot.width <= 0 || snapshot.height <= 0) return;

    final rawT = animation.value.clamp(0.0, 1.0);
    final t = curve.transform(rawT).clamp(0.0, 1.0);
    final rect = Offset.zero & size;
    final src = Rect.fromLTWH(
      0,
      0,
      snapshot.width.toDouble(),
      snapshot.height.toDouble(),
    );
    final imagePaint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = true;

    final center = Offset(
      origin.dx.clamp(0.0, size.width),
      origin.dy.clamp(0.0, size.height),
    );
    final envelope = math.sin(rawT * math.pi).clamp(0.0, 1.0);

    switch (mode) {
      case OmniThemeAnimationMode.circularReveal:
        final r = _maxCornerDistance(center, size) * t;
        final revealCircle = Path()
          ..addOval(Rect.fromCircle(center: center, radius: r));
        final cutout = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect)
          ..addPath(revealCircle, Offset.zero);
        canvas.save();
        canvas.clipRect(rect);
        canvas.clipPath(cutout);
        canvas.drawImageRect(snapshot, src, rect, imagePaint);
        canvas.restore();
        if (r > 0.5) {
          canvas.save();
          canvas.clipRect(rect);
          _strokeGlowPath(canvas, revealCircle, envelope);
          canvas.restore();
        }

      case OmniThemeAnimationMode.circularShrink:
        final r = _maxCornerDistance(center, size) * (1.0 - t);
        if (r > 0.5) {
          final circle = Path()
            ..addOval(Rect.fromCircle(center: center, radius: r));
          canvas.save();
          canvas.clipRect(rect);
          canvas.clipPath(circle);
          canvas.drawImageRect(snapshot, src, rect, imagePaint);
          _strokeGlowPath(canvas, circle, envelope);
          canvas.restore();
        }

      case OmniThemeAnimationMode.horizontalWipe:
        final isLtr = textDirection == TextDirection.ltr;
        final x = isLtr ? size.width * t : size.width * (1.0 - t);
        final remain = isLtr
            ? Rect.fromLTRB(x, 0, size.width, size.height)
            : Rect.fromLTRB(0, 0, x, size.height);
        if (!remain.isEmpty) {
          canvas.save();
          canvas.clipRect(remain);
          canvas.drawImageRect(snapshot, src, rect, imagePaint);
          canvas.restore();
        }
        canvas.save();
        canvas.clipRect(rect);
        _strokeGlowLine(canvas, Offset(x, 0), Offset(x, size.height), envelope);
        canvas.restore();

      case OmniThemeAnimationMode.verticalWipe:
        final y = size.height * t;
        final remain = Rect.fromLTRB(0, y, size.width, size.height);
        if (!remain.isEmpty) {
          canvas.save();
          canvas.clipRect(remain);
          canvas.drawImageRect(snapshot, src, rect, imagePaint);
          canvas.restore();
        }
        canvas.save();
        canvas.clipRect(rect);
        _strokeGlowLine(canvas, Offset(0, y), Offset(size.width, y), envelope);
        canvas.restore();

      case OmniThemeAnimationMode.diagonalSweep:
        final w = size.width;
        final h = size.height;
        final d = (w + h) * t;
        final p1 = d <= w ? Offset(d, 0) : Offset(w, (d - w).clamp(0.0, h));
        final p2 = d <= h ? Offset(0, d) : Offset((d - h).clamp(0.0, w), h);
        final revealed = Path()..moveTo(0, 0);
        if (d <= w) {
          revealed.lineTo(d, 0);
        } else {
          revealed.lineTo(w, 0);
          revealed.lineTo(w, (d - w).clamp(0.0, h));
        }
        if (d <= h) {
          revealed.lineTo(0, d);
        } else {
          revealed.lineTo((d - h).clamp(0.0, w), h);
          revealed.lineTo(0, h);
        }
        revealed.close();

        final cutout = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect)
          ..addPath(revealed, Offset.zero);
        canvas.save();
        canvas.clipRect(rect);
        canvas.clipPath(cutout);
        canvas.drawImageRect(snapshot, src, rect, imagePaint);
        canvas.restore();
        if (d > 0.5 && d < w + h - 0.5) {
          canvas.save();
          canvas.clipRect(rect);
          _strokeGlowLine(canvas, p1, p2, envelope);
          canvas.restore();
        }

      case OmniThemeAnimationMode.splitShutter:
        final cx = size.width * 0.5;
        final halfOpen = cx * t;
        final leftX = (cx - halfOpen).clamp(0.0, cx);
        final rightX = (cx + halfOpen).clamp(cx, size.width);
        final leftRect = Rect.fromLTRB(0, 0, leftX, size.height);
        final rightRect = Rect.fromLTRB(rightX, 0, size.width, size.height);
        final shutters = Path()
          ..addRect(leftRect)
          ..addRect(rightRect);
        canvas.save();
        canvas.clipRect(rect);
        canvas.clipPath(shutters);
        canvas.drawImageRect(snapshot, src, rect, imagePaint);
        canvas.restore();
        canvas.save();
        canvas.clipRect(rect);
        _strokeGlowLine(
          canvas,
          Offset(leftX, 0),
          Offset(leftX, size.height),
          envelope,
        );
        _strokeGlowLine(
          canvas,
          Offset(rightX, 0),
          Offset(rightX, size.height),
          envelope,
        );
        canvas.restore();

      case OmniThemeAnimationMode.diamondReveal:
        final r = _maxManhattanDistance(center, size) * t;
        final diamond = Path()
          ..moveTo(center.dx, center.dy - r)
          ..lineTo(center.dx + r, center.dy)
          ..lineTo(center.dx, center.dy + r)
          ..lineTo(center.dx - r, center.dy)
          ..close();
        final cutout = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect)
          ..addPath(diamond, Offset.zero);
        canvas.save();
        canvas.clipRect(rect);
        canvas.clipPath(cutout);
        canvas.drawImageRect(snapshot, src, rect, imagePaint);
        canvas.restore();
        if (r > 0.5) {
          canvas.save();
          canvas.clipRect(rect);
          _strokeGlowPath(canvas, diamond, envelope);
          canvas.restore();
        }

      case OmniThemeAnimationMode.crossfade:
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        if (opacity > 0.004) {
          final fadePaint = Paint()
            ..filterQuality = FilterQuality.low
            ..isAntiAlias = true
            ..color = Color.fromRGBO(0, 0, 0, opacity);
          canvas.drawImageRect(snapshot, src, rect, fadePaint);
        }

      case OmniThemeAnimationMode.colorMorph:
      case OmniThemeAnimationMode.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _OmniThemeTransitionPainter oldDelegate) =>
      !identical(oldDelegate.snapshot, snapshot) ||
      oldDelegate.mode != mode ||
      oldDelegate.curve != curve ||
      oldDelegate.origin != origin ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.showGlow != showGlow ||
      oldDelegate.glowWidth != glowWidth ||
      oldDelegate.textDirection != textDirection;
}
