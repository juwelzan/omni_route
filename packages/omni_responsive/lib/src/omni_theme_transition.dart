import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

  /// মাঝখান থেকে ওপর-নিচে অনুভূমিক শাটার খুলে গিয়ে নতুন থিম বেরিয়ে আসে।
  verticalSplitShutter,

  /// ভেনিশিয়ান ব্লাইন্ডের মতো স্তরে স্তরে স্লেট খুলে পুরো স্ক্রিনে নতুন থিম ফুটে ওঠে।
  blindsWipe,

  /// ঘড়ির কাঁটা বা রাডার সুইপের মতো ৩৬০° ঘুরে স্ক্রিনের রঙ ও থিম বদলে দেয়।
  clockSweep,

  /// ট্যাপ পয়েন্ট বা কেন্দ্র থেকে রাউন্ডেড কার্ড বড় হয়ে পুরো স্ক্রিনে ছড়িয়ে পড়ে।
  roundedBoxReveal,

  /// ট্যাপ পয়েন্ট বা কেন্দ্র থেকে ডায়মন্ড (রম্বস) আকারে ছড়িয়ে স্ক্রিনের থিম বদলায়।
  diamondReveal,

  /// পুরোনো ও নতুন পুরো স্ক্রিন মসৃণ আলফা ক্রসফেডে মিশে রূপান্তরিত হয়।
  crossfade,

  /// পুরোনো স্ক্রিন হালকা জুম-আউট হয়ে মসৃণ ফেডে নতুন থিমে মিশে যায়।
  zoomFade,

  /// পুরোনো স্ক্রিন একপাশে স্লাইড করে সরে গিয়ে নিচের লাইভ নতুন থিম উন্মোচিত করে।
  slideReveal,

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
    OmniThemeAnimationMode.verticalSplitShutter => 'Vertical Split',
    OmniThemeAnimationMode.blindsWipe => 'Blinds Reveal',
    OmniThemeAnimationMode.clockSweep => 'Radar Sweep',
    OmniThemeAnimationMode.roundedBoxReveal => 'Card Expand',
    OmniThemeAnimationMode.diamondReveal => 'Diamond Reveal',
    OmniThemeAnimationMode.crossfade => 'Crossfade',
    OmniThemeAnimationMode.zoomFade => 'Zoom Crossfade',
    OmniThemeAnimationMode.slideReveal => 'Slide Reveal',
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
    OmniThemeAnimationMode.verticalSplitShutter =>
      'মাঝখান থেকে ওপর-নিচে শাটার সরে গিয়ে নতুন থিম বের হয়',
    OmniThemeAnimationMode.blindsWipe =>
      'ভেনিশিয়ান ব্লাইন্ডের মতো স্তরে স্তরে স্লেট খুলে থিম বদলায়',
    OmniThemeAnimationMode.clockSweep =>
      'ঘড়ির কাঁটা বা রাডার সুইপের মতো ঘুরে পুরো স্ক্রিনের থিম বদলায়',
    OmniThemeAnimationMode.roundedBoxReveal =>
      'ট্যাপ পয়েন্ট বা কেন্দ্র থেকে রাউন্ডেড কার্ড বড় হয়ে পুরো স্ক্রিনে ছড়িয়ে পড়ে',
    OmniThemeAnimationMode.diamondReveal =>
      'ডায়মন্ড আকারে কেন্দ্র বা ট্যাপ পয়েন্ট থেকে থিম ছড়িয়ে পড়ে',
    OmniThemeAnimationMode.crossfade =>
      'পুরোনো ও নতুন পুরো স্ক্রিন মসৃণ ক্রসফেডে মিশে যায়',
    OmniThemeAnimationMode.zoomFade =>
      'পুরোনো স্ক্রিন হালকা জুম হয়ে মসৃণ ফেডে নতুন থিমে মিশে যায়',
    OmniThemeAnimationMode.slideReveal =>
      'পুরোনো স্ক্রিন একপাশে স্লাইড হয়ে সরে গিয়ে নিচের নতুন থিম দেখায়',
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
    OmniThemeAnimationMode.verticalSplitShutter => Icons.view_agenda_outlined,
    OmniThemeAnimationMode.blindsWipe => Icons.view_week_outlined,
    OmniThemeAnimationMode.clockSweep => Icons.timelapse_rounded,
    OmniThemeAnimationMode.roundedBoxReveal => Icons.crop_square_rounded,
    OmniThemeAnimationMode.diamondReveal => Icons.diamond_outlined,
    OmniThemeAnimationMode.crossfade => Icons.blur_on_rounded,
    OmniThemeAnimationMode.zoomFade => Icons.zoom_out_map_rounded,
    OmniThemeAnimationMode.slideReveal => Icons.swipe_left_rounded,
    OmniThemeAnimationMode.colorMorph => Icons.gradient_rounded,
    OmniThemeAnimationMode.none => Icons.flash_on_outlined,
  };

  /// এই মোডে স্ক্রিনের ওপর GPU স্ন্যাপশট ওভারলে অ্যানিমেশন চলে কি না।
  bool get usesScreenOverlay =>
      this != OmniThemeAnimationMode.colorMorph &&
      this != OmniThemeAnimationMode.none;
}

/// ডার্ক/লাইট মোড, কালার প্যালেট (`themeId`) ও থিম স্টাইল (`OmniThemeStyle`)
/// পরিবর্তনের সময় পুরো স্ক্রিনের জিরো-জ্যাঙ্ক অ্যানিমেশন কনফিগারেশন।
///
/// ডিফল্টভাবেই [OmniThemeAnimationMode.circularReveal] সক্রিয় থাকে — যেখানে
/// ১-ফ্রেম ওয়ার্মআপ ও লাইটওয়েট GPU শেডার ব্যবহার করে ঝাঁকি ছাড়াই মসৃণভাবে
/// পুরো স্ক্রিনের থিম ও কালার বদলে যায়।
@immutable
class OmniThemeAnimation {
  /// ডার্ক মোড ও কালার প্যালেট পরিবর্তনের স্ক্রিন অ্যানিমেশন তৈরি করে।
  const OmniThemeAnimation({
    this.mode = OmniThemeAnimationMode.circularReveal,
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 380),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// ট্যাপ পজিশন বা কেন্দ্র থেকে গোল রিপল ছড়ানো অ্যানিমেশন।
  const OmniThemeAnimation.circularReveal({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 380),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.circularReveal,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// পুরোনো স্ক্রিন গোল হয়ে ভেতরের দিকে সংকুচিত হয়ে নতুন থিম বের হওয়া অ্যানিমেশন।
  const OmniThemeAnimation.circularShrink({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 380),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.circularShrink,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// বাম থেকে ডানে অনুভূমিক সুইপ অ্যানিমেশন।
  const OmniThemeAnimation.horizontalWipe({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 360),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.centerLeft,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.horizontalWipe,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// ওপর থেকে নিচে কার্টেইন/পর্দা নামার সুইপ অ্যানিমেশন।
  const OmniThemeAnimation.verticalWipe({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 360),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.topCenter,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.verticalWipe,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// কোণাকুণি ডায়াগোনাল সুইপ অ্যানিমেশন।
  const OmniThemeAnimation.diagonalSweep({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 380),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.topLeft,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.diagonalSweep,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// মাঝখান থেকে দুই দিকে পর্দা সরে থিম পরিবর্তনের শাটার অ্যানিমেশন।
  const OmniThemeAnimation.splitShutter({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 380),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.splitShutter,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// ডায়মন্ড আকারে চারদিকে ছড়ানো থিম রিভিল অ্যানিমেশন।
  const OmniThemeAnimation.diamondReveal({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 380),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.diamondReveal,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// পুরো স্ক্রিন মসৃণ ক্রসফেড অ্যানিমেশন।
  const OmniThemeAnimation.crossfade({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 320),
    this.paletteDuration,
    this.curve = Curves.easeInOut,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = false,
    this.showEdgeGlow = false,
    this.edgeGlowColor,
    this.edgeGlowWidth = 0,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.crossfade,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// ওভারলে ছাড়াই সব রঙ, কার্ড ও টেক্সট ধাপে ধাপে মসৃণ কালার মর্ফ অ্যানিমেশন।
  const OmniThemeAnimation.colorMorph({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 360),
    this.paletteDuration,
    this.curve = Curves.easeInOut,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = false,
    this.showEdgeGlow = false,
    this.edgeGlowColor,
    this.edgeGlowWidth = 0,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.colorMorph,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// মাঝখান থেকে ওপর-নিচে শাটার খুলে থিম পরিবর্তনের অ্যানিমেশন।
  const OmniThemeAnimation.verticalSplitShutter({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 380),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.verticalSplitShutter,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// ভেনিশিয়ান ব্লাইন্ডের মতো স্তরে স্তরে স্লেট খুলে থিম পরিবর্তনের অ্যানিমেশন।
  const OmniThemeAnimation.blindsWipe({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 420),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.centerLeft,
    this.autoTapOrigin = false,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.0,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.blindsWipe,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// ঘড়ির কাঁটা বা রাডার সুইপের মতো ৩৬০° ঘুরে থিম পরিবর্তনের অ্যানিমেশন।
  const OmniThemeAnimation.clockSweep({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 420),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.clockSweep,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// ট্যাপ পয়েন্ট বা কেন্দ্র থেকে রাউন্ডেড কার্ড বড় হয়ে পুরো স্ক্রিনে ছড়ানো অ্যানিমেশন।
  const OmniThemeAnimation.roundedBoxReveal({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 380),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.roundedBoxReveal,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// পুরোনো স্ক্রিন হালকা জুম হয়ে মসৃণ ফেডে নতুন থিমে মিশে যাওয়ার অ্যানিমেশন।
  const OmniThemeAnimation.zoomFade({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 340),
    this.paletteDuration,
    this.curve = Curves.easeOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.center,
    this.autoTapOrigin = true,
    this.showEdgeGlow = false,
    this.edgeGlowColor,
    this.edgeGlowWidth = 0,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.zoomFade,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

  /// পুরোনো স্ক্রিন একপাশে স্লাইড করে সরে নিচের নতুন থিম বের হওয়ার অ্যানিমেশন।
  const OmniThemeAnimation.slideReveal({
    this.paletteMode,
    this.styleMode,
    this.duration = const Duration(milliseconds: 360),
    this.paletteDuration,
    this.curve = Curves.easeInOutCubic,
    this.origin,
    this.fallbackOrigin = Alignment.centerLeft,
    this.autoTapOrigin = false,
    this.showEdgeGlow = true,
    this.edgeGlowColor,
    this.edgeGlowWidth = 2.5,
    this.snapshotPixelRatio = 1.0,
    this.animateBrightness = true,
    this.animatePalette = true,
    this.animateStyle = true,
    this.respectReducedMotion = true,
  }) : mode = OmniThemeAnimationMode.slideReveal,
       assert(edgeGlowWidth >= 0),
       assert(snapshotPixelRatio > 0 && snapshotPixelRatio <= 3.0);

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
      snapshotPixelRatio = 1.0,
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

  /// অ্যানিমেশনের সময়কাল (ডিফল্ট `380ms`)।
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

  /// ওভারলে স্ন্যাপশটের পিক্সেল রেশিও (`1.0` ডিফল্ট — ৯ গুণ কম GPU মেমোরি ও শূন্য ঝাঁকি!)।
  final double snapshotPixelRatio;

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
    double? snapshotPixelRatio,
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
    snapshotPixelRatio: snapshotPixelRatio ?? this.snapshotPixelRatio,
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
          snapshotPixelRatio == other.snapshotPixelRatio &&
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
    snapshotPixelRatio,
    animateBrightness,
    animatePalette,
    animateStyle,
    respectReducedMotion,
  );
}

/// যেকোনো থিম বা কালার প্যালেট পরিবর্তনে পুরো স্ক্রিনের ওপর ভিজ্যুয়াল
/// অ্যানিমেশন (`circularReveal`, `horizontalWipe`, `diagonalSweep`, `colorMorph`
/// ইত্যাদি) চালানোর জিরো-জ্যাঙ্ক হোস্ট উইজেট।
class OmniThemeTransition<T> extends StatefulWidget {
  /// [value] বদলালেই [animation] অনুযায়ী ঝাঁকিহীন মসৃণ স্ক্রিন/কালার ট্রানজিশন চালায়।
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
  bool _startingTransition = false;
  bool _warmingSnapshot = false;
  bool _warmupScheduled = false;

  ui.Image? _snapshot;
  ui.ImageShader? _shader;
  Size? _shaderSize;
  OmniThemeAnimationMode? _activeMode;
  Offset? _activeOrigin;
  Color _activeGlowColor = const Color(0xFF2563EB);
  double _activeGlowWidth = 2.5;
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

  void _disposeSnapshot() {
    final oldShader = _shader;
    _shader = null;
    _shaderSize = null;
    oldShader?.dispose();

    final oldSnap = _snapshot;
    _snapshot = null;
    oldSnap?.dispose();
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
      _warmingSnapshot = false;
      _warmupScheduled = false;
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
    _warmingSnapshot = false;
    _warmupScheduled = false;
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
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary != null && _canCapture(boundary)) {
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
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    ui.Image? snap;
    if (boundary != null && _canCapture(boundary)) {
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
        _disposeSnapshot();
        _activeMode = null;
        _displayedValue = next;
        _materialAnimDuration = duration;
        _materialAnimCurve = widget.animation.curve;
      }
    });
  }

  /// Whether [boundary] can be snapshotted now.
  ///
  /// `debugNeedsPaint` only answers in debug builds (where `toImageSync`
  /// asserts on it) and is always `false` in profile/release. There, a
  /// boundary that was never painted has no layer: `toImageSync` throws,
  /// [_tryCapture] returns `null`, and the capture is retried after the next
  /// frame. A painted boundary keeps its last frame (the old theme), which is
  /// exactly what the overlay needs.
  static bool _canCapture(RenderRepaintBoundary boundary) =>
      boundary.attached &&
      boundary.hasSize &&
      !boundary.size.isEmpty &&
      !(kDebugMode && boundary.debugNeedsPaint);

  ui.Image? _tryCapture(RenderRepaintBoundary boundary) {
    final ratio = widget.animation.snapshotPixelRatio.clamp(0.5, 3.0);
    try {
      return boundary.toImageSync(pixelRatio: ratio);
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

    final size = boundary.size;
    if (!size.isEmpty && snapshot.width > 0 && snapshot.height > 0) {
      final sx = size.width / snapshot.width;
      final sy = size.height / snapshot.height;
      _shaderSize = size;
      _shader = ui.ImageShader(
        snapshot,
        TileMode.clamp,
        TileMode.clamp,
        Float64List.fromList(<double>[
          sx,
          0,
          0,
          0,
          0,
          sy,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ]),
        filterQuality: FilterQuality.low,
      );
    }

    _displayedValue = next;
    _activeMode = mode;
    _materialAnimDuration = Duration.zero;
    _materialAnimCurve = Curves.linear;

    final dir = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _activeDirection = dir;

    final rect = Offset.zero & size;
    final explicit =
        widget.takeExplicitOrigin?.call() ?? widget.animation.origin;
    final autoTap = (widget.animation.autoTapOrigin && !_pointerDragged)
        ? _lastTapOrigin
        : null;
    _lastTapOrigin = null;

    final globalOrigin = explicit ?? autoTap;
    if (globalOrigin != null) {
      final local = boundary.globalToLocal(globalOrigin);
      _activeOrigin = Offset(
        local.dx.clamp(0.0, size.width),
        local.dy.clamp(0.0, size.height),
      );
    } else {
      _activeOrigin = widget.animation.fallbackOrigin
          .resolve(dir)
          .withinRect(rect);
    }

    _activeGlowColor =
        widget.animation.edgeGlowColor ??
        widget.resolveGlowColor?.call(next) ??
        const Color(0xFF2563EB);
    _activeGlowWidth = widget.animation.edgeGlowWidth;
    _activeShowGlow = widget.animation.showEdgeGlow;

    // 1. প্রথমে _animController-কে t = 0.0 অবস্থায় রাখি যাতে ফ্রোজেন পুরোনো স্ক্রিনের
    //    নিচে MaterialApp সম্পূর্ণ নতুন থিমে রিবিল্ড ও রেন্ডার হয়ে GPU-তে রেডি হতে পারে।
    _startingTransition = true;
    try {
      _animController.stop();
      _animController.duration = duration;
      _animController.value = 0.0;
    } finally {
      _startingTransition = false;
    }

    _warmingSnapshot = true;
    if (!_warmupScheduled) {
      _warmupScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startTickerAfterWarmup(),
      );
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void _startTickerAfterWarmup() {
    _warmupScheduled = false;
    if (!mounted || !_warmingSnapshot || _snapshot == null) return;
    _warmingSnapshot = false;
    // নতুন থিম সম্পূর্ণ পেইন্ট হওয়ার পর ঠিক শূন্য সময় থেকে টিকার চালু করলে
    // কোনো ফ্রেম জাম্প বা আটকে যাওয়া ঝাঁকি থাকে না।
    setState(() {
      _startingTransition = true;
      try {
        _animController.forward(from: 0.0);
      } finally {
        _startingTransition = false;
      }
    });
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
    _warmingSnapshot = false;
    _warmupScheduled = false;
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
                    shader: _shader,
                    shaderSize: _shaderSize,
                    isWarming: _warmingSnapshot,
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
    required this.shader,
    required this.shaderSize,
    required this.isWarming,
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
  final ui.ImageShader? shader;
  final Size? shaderSize;
  final bool isWarming;
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

  void _drawShaderOrClippedPath({
    required Canvas canvas,
    required Size size,
    required Rect src,
    required Path path,
    required Paint imagePaint,
  }) {
    final activeShader = shader;
    if (activeShader != null && shaderSize == size) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = activeShader
          ..isAntiAlias = true,
      );
      return;
    }
    canvas.save();
    canvas.clipPath(path);
    canvas.drawImageRect(snapshot, src, Offset.zero & size, imagePaint);
    canvas.restore();
  }

  void _strokeGlowPath(Canvas canvas, Size size, Path path, double envelope) {
    if (!showGlow || glowWidth <= 0 || envelope <= 0.01) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth * 2.4
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.16 * envelope),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.48 * envelope),
    );
    canvas.restore();
  }

  void _strokeGlowLine(Canvas canvas, Offset a, Offset b, double envelope) {
    if (!showGlow || glowWidth <= 0 || envelope <= 0.01) return;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = glowWidth * 2.4
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.16 * envelope),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = glowWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = glowColor.withValues(alpha: 0.52 * envelope),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || snapshot.width <= 0 || snapshot.height <= 0) return;

    final rect = Offset.zero & size;
    final imgW = snapshot.width.toDouble();
    final imgH = snapshot.height.toDouble();
    final src = Rect.fromLTWH(0, 0, imgW, imgH);
    final imagePaint = Paint()..filterQuality = FilterQuality.low;

    final rawT = animation.value.clamp(0.0, 1.0);
    // প্রি-ওয়ার্ম ফ্রেম বা t == 0 অবস্থায় কোনো পাথ/ক্লিপ ছাড়াই একবারে ফুল ইমেজ দেখাই:
    if (isWarming || rawT <= 0.0001) {
      canvas.drawImageRect(snapshot, src, rect, imagePaint);
      return;
    }

    final t = curve.transform(rawT).clamp(0.0, 1.0);
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
        _drawShaderOrClippedPath(
          canvas: canvas,
          size: size,
          src: src,
          path: cutout,
          imagePaint: imagePaint,
        );
        if (r > 0.5) {
          _strokeGlowPath(canvas, size, revealCircle, envelope);
        }

      case OmniThemeAnimationMode.circularShrink:
        final r = _maxCornerDistance(center, size) * (1.0 - t);
        if (r > 0.5) {
          final circle = Path()
            ..addOval(Rect.fromCircle(center: center, radius: r));
          _drawShaderOrClippedPath(
            canvas: canvas,
            size: size,
            src: src,
            path: circle,
            imagePaint: imagePaint,
          );
          _strokeGlowPath(canvas, size, circle, envelope);
        }

      case OmniThemeAnimationMode.horizontalWipe:
        final isLtr = textDirection == TextDirection.ltr;
        final x = isLtr ? size.width * t : size.width * (1.0 - t);
        final frac = (x / size.width).clamp(0.0, 1.0);
        final srcX = imgW * frac;
        final dstRemain = isLtr
            ? Rect.fromLTRB(x, 0, size.width, size.height)
            : Rect.fromLTRB(0, 0, x, size.height);
        final srcRemain = isLtr
            ? Rect.fromLTRB(srcX, 0, imgW, imgH)
            : Rect.fromLTRB(0, 0, srcX, imgH);
        if (dstRemain.width > 0.5 && srcRemain.width > 0.5) {
          canvas.drawImageRect(snapshot, srcRemain, dstRemain, imagePaint);
        }
        _strokeGlowLine(canvas, Offset(x, 0), Offset(x, size.height), envelope);

      case OmniThemeAnimationMode.verticalWipe:
        final y = size.height * t;
        final frac = (y / size.height).clamp(0.0, 1.0);
        final srcY = imgH * frac;
        final dstRemain = Rect.fromLTRB(0, y, size.width, size.height);
        final srcRemain = Rect.fromLTRB(0, srcY, imgW, imgH);
        if (dstRemain.height > 0.5 && srcRemain.height > 0.5) {
          canvas.drawImageRect(snapshot, srcRemain, dstRemain, imagePaint);
        }
        _strokeGlowLine(canvas, Offset(0, y), Offset(size.width, y), envelope);

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
        _drawShaderOrClippedPath(
          canvas: canvas,
          size: size,
          src: src,
          path: cutout,
          imagePaint: imagePaint,
        );
        if (d > 0.5 && d < w + h - 0.5) {
          _strokeGlowLine(canvas, p1, p2, envelope);
        }

      case OmniThemeAnimationMode.splitShutter:
        final cx = size.width * 0.5;
        final halfOpen = cx * t;
        final leftX = (cx - halfOpen).clamp(0.0, cx);
        final rightX = (cx + halfOpen).clamp(cx, size.width);
        final leftSrcX = imgW * (leftX / size.width);
        final rightSrcX = imgW * (rightX / size.width);

        if (leftX > 0.5 && leftSrcX > 0.5) {
          canvas.drawImageRect(
            snapshot,
            Rect.fromLTRB(0, 0, leftSrcX, imgH),
            Rect.fromLTRB(0, 0, leftX, size.height),
            imagePaint,
          );
        }
        if (size.width - rightX > 0.5 && imgW - rightSrcX > 0.5) {
          canvas.drawImageRect(
            snapshot,
            Rect.fromLTRB(rightSrcX, 0, imgW, imgH),
            Rect.fromLTRB(rightX, 0, size.width, size.height),
            imagePaint,
          );
        }
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
        _drawShaderOrClippedPath(
          canvas: canvas,
          size: size,
          src: src,
          path: cutout,
          imagePaint: imagePaint,
        );
        if (r > 0.5) {
          _strokeGlowPath(canvas, size, diamond, envelope);
        }

      case OmniThemeAnimationMode.verticalSplitShutter:
        final cy = size.height * 0.5;
        final halfOpen = cy * t;
        final topY = (cy - halfOpen).clamp(0.0, cy);
        final bottomY = (cy + halfOpen).clamp(cy, size.height);
        final topSrcY = imgH * (topY / size.height);
        final bottomSrcY = imgH * (bottomY / size.height);

        if (topY > 0.5 && topSrcY > 0.5) {
          canvas.drawImageRect(
            snapshot,
            Rect.fromLTRB(0, 0, imgW, topSrcY),
            Rect.fromLTRB(0, 0, size.width, topY),
            imagePaint,
          );
        }
        if (size.height - bottomY > 0.5 && imgH - bottomSrcY > 0.5) {
          canvas.drawImageRect(
            snapshot,
            Rect.fromLTRB(0, bottomSrcY, imgW, imgH),
            Rect.fromLTRB(0, bottomY, size.width, size.height),
            imagePaint,
          );
        }
        _strokeGlowLine(
          canvas,
          Offset(0, topY),
          Offset(size.width, topY),
          envelope,
        );
        _strokeGlowLine(
          canvas,
          Offset(0, bottomY),
          Offset(size.width, bottomY),
          envelope,
        );

      case OmniThemeAnimationMode.blindsWipe:
        const slats = 6;
        const stagger = 0.35;
        final slatW = size.width / slats;
        final srcSlatW = imgW / slats;
        final isLtr = textDirection == TextDirection.ltr;

        for (var i = 0; i < slats; i++) {
          final order = isLtr ? i : (slats - 1 - i);
          final delay = (order / (slats - 1)) * stagger;
          final localT = ((t * (1.0 + stagger)) - delay).clamp(0.0, 1.0);
          final remainFrac = (1.0 - localT).clamp(0.0, 1.0);
          if (remainFrac <= 0.002) continue;

          final xStart = slatW * i;
          final xEnd = slatW * (i + 1);
          final srcStart = srcSlatW * i;
          final srcEnd = srcSlatW * (i + 1);

          final dstRemain = isLtr
              ? Rect.fromLTRB(xStart + slatW * localT, 0, xEnd, size.height)
              : Rect.fromLTRB(xStart, 0, xEnd - slatW * localT, size.height);
          final srcRemain = isLtr
              ? Rect.fromLTRB(srcStart + srcSlatW * localT, 0, srcEnd, imgH)
              : Rect.fromLTRB(srcStart, 0, srcEnd - srcSlatW * localT, imgH);

          if (dstRemain.width > 0.5 && srcRemain.width > 0.5) {
            canvas.drawImageRect(snapshot, srcRemain, dstRemain, imagePaint);
          }
          final edgeX = isLtr ? dstRemain.left : dstRemain.right;
          final slatEnv = math.sin(localT * math.pi).clamp(0.0, 1.0);
          if (slatEnv > 0.02) {
            _strokeGlowLine(
              canvas,
              Offset(edgeX, 0),
              Offset(edgeX, size.height),
              slatEnv,
            );
          }
        }

      case OmniThemeAnimationMode.clockSweep:
        final r = _maxCornerDistance(center, size);
        final angle = 2.0 * math.pi * t;
        const startAngle = -math.pi * 0.5;
        if (angle < 2.0 * math.pi - 0.001) {
          final sector = Path()
            ..moveTo(center.dx, center.dy)
            ..arcTo(
              Rect.fromCircle(center: center, radius: r),
              startAngle,
              angle,
              false,
            )
            ..close();
          final cutout = Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(rect)
            ..addPath(sector, Offset.zero);
          _drawShaderOrClippedPath(
            canvas: canvas,
            size: size,
            src: src,
            path: cutout,
            imagePaint: imagePaint,
          );
          final sweepEnd = startAngle + angle;
          canvas.save();
          canvas.clipRect(rect);
          _strokeGlowLine(
            canvas,
            center,
            Offset(
              center.dx + math.cos(sweepEnd) * r,
              center.dy + math.sin(sweepEnd) * r,
            ),
            envelope,
          );
          canvas.restore();
        }

      case OmniThemeAnimationMode.roundedBoxReveal:
        final maxHalfW = math.max(center.dx, size.width - center.dx);
        final maxHalfH = math.max(center.dy, size.height - center.dy);
        final halfW = maxHalfW * t;
        final halfH = maxHalfH * t;
        final corner = (32.0 * (1.0 - t)).clamp(0.0, 32.0);
        final revealBox = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: center,
                width: halfW * 2.0,
                height: halfH * 2.0,
              ),
              Radius.circular(corner),
            ),
          );
        final cutout = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect)
          ..addPath(revealBox, Offset.zero);
        _drawShaderOrClippedPath(
          canvas: canvas,
          size: size,
          src: src,
          path: cutout,
          imagePaint: imagePaint,
        );
        if (halfW > 1.0 && halfH > 1.0) {
          _strokeGlowPath(canvas, size, revealBox, envelope);
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

      case OmniThemeAnimationMode.zoomFade:
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        if (opacity > 0.004) {
          final scale = 1.0 + 0.07 * t;
          final fadePaint = Paint()
            ..filterQuality = FilterQuality.low
            ..isAntiAlias = true
            ..color = Color.fromRGBO(0, 0, 0, opacity);
          canvas.save();
          canvas.clipRect(rect);
          canvas.translate(center.dx, center.dy);
          canvas.scale(scale);
          canvas.translate(-center.dx, -center.dy);
          canvas.drawImageRect(snapshot, src, rect, fadePaint);
          canvas.restore();
        }

      case OmniThemeAnimationMode.slideReveal:
        final isLtr = textDirection == TextDirection.ltr;
        final dx = isLtr ? size.width * t : -size.width * t;
        final shifted = rect.shift(Offset(dx, 0));
        final edgeX = isLtr ? shifted.left : shifted.right;
        canvas.save();
        canvas.clipRect(rect);
        canvas.drawImageRect(snapshot, src, shifted, imagePaint);
        _strokeGlowLine(
          canvas,
          Offset(edgeX, 0),
          Offset(edgeX, size.height),
          envelope,
        );
        canvas.restore();

      case OmniThemeAnimationMode.colorMorph:
      case OmniThemeAnimationMode.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _OmniThemeTransitionPainter oldDelegate) =>
      !identical(oldDelegate.snapshot, snapshot) ||
      !identical(oldDelegate.shader, shader) ||
      oldDelegate.shaderSize != shaderSize ||
      oldDelegate.isWarming != isWarming ||
      oldDelegate.mode != mode ||
      oldDelegate.curve != curve ||
      oldDelegate.origin != origin ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.showGlow != showGlow ||
      oldDelegate.glowWidth != glowWidth ||
      oldDelegate.textDirection != textDirection;
}
