import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ডিভাইসের উপরের **সিস্টেম স্ট্যাটাস বার** (সময়, নেটওয়ার্ক, ব্যাটারি আইকন)-এর
/// জন্য সম্পূর্ণ আলাদা কনফিগারেশন ক্লাস।
///
/// লাইট মোডের রঙ (`color`) এবং ডার্ক মোডের রঙ (`darkColor`), আইকন ব্রাইটনেস,
/// দৃশ্যমানতা (`visible`) ও কনট্রাস্ট সবকিছু এক জায়গা থেকে অ্যাপের **প্রতিটি স্ক্রিনে**
/// স্বয়ংক্রিয়ভাবে প্রযোজ্য হয় — প্রতি স্ক্রিনের ভেতরে আলাদা কোড লেখার প্রয়োজন নেই।
@immutable
class OmniStatusBarStyle {
  /// উপরের সিস্টেম স্ট্যাটাস বারের কাস্টম স্টাইল তৈরি করে।
  const OmniStatusBarStyle({
    this.color = Colors.transparent,
    this.darkColor,
    this.iconBrightness,
    this.darkIconBrightness,
    this.contrastEnforced = false,
    this.visible = true,
  });

  /// সম্পূর্ণ স্বচ্ছ এজ-টু-এজ স্ট্যাটাস বার (ডিফল্ট)।
  const OmniStatusBarStyle.transparent({
    this.iconBrightness,
    this.darkIconBrightness,
    this.contrastEnforced = false,
  }) : color = Colors.transparent,
       darkColor = Colors.transparent,
       visible = true;

  /// নির্দিষ্ট রঙের (লাইট ও ঐচ্ছিক ডার্ক রঙসহ) সলিড বা টিন্টেড স্ট্যাটাস বার।
  const OmniStatusBarStyle.solid({
    this.color,
    this.darkColor,
    this.iconBrightness,
    this.darkIconBrightness,
    this.contrastEnforced = false,
  }) : visible = true;

  /// উপরের স্ট্যাটাস বার লুকিয়ে রাখে (`visible: false`)।
  const OmniStatusBarStyle.hidden()
    : color = Colors.transparent,
      darkColor = Colors.transparent,
      iconBrightness = null,
      darkIconBrightness = null,
      contrastEnforced = false,
      visible = false;

  /// লাইট মোডে (এবং [darkColor] না দিলে ডার্ক মোডেও) স্ট্যাটাস বারের ব্যাকগ্রাউন্ড রঙ।
  ///
  /// ডিফল্ট `Colors.transparent` যাতে অ্যাপের কন্টেন্ট/অ্যাপবার মসৃণভাবে ওপরে মিশে যায়।
  final Color? color;

  /// ডার্ক মোডে স্ট্যাটাস বারের আলাদা ব্যাকগ্রাউন্ড রঙ (`null` হলে [color] ব্যবহার হয়)।
  final Color? darkColor;

  /// লাইট মোডে স্ট্যাটাস বারের ঘড়ি ও ব্যাটারি আইকনের রঙ (`Brightness.dark` = কালো আইকন)।
  ///
  /// `null` হলে ব্যাকগ্রাউন্ড রঙের উজ্জ্বলতা বুঝে স্বয়ংক্রিয়ভাবে নির্ধারিত হয়।
  final Brightness? iconBrightness;

  /// ডার্ক মোডে স্ট্যাটাস বারের আইকন রঙ (`null` হলে অটো কনট্রাস্ট)।
  final Brightness? darkIconBrightness;

  /// Android 10+ স্বচ্ছ স্ট্যাটাস বারের পেছনে ডিফল্ট scrim ছায়া বসাবে কি না (ডিফল্ট `false`)।
  final bool contrastEnforced;

  /// স্ট্যাটাস বার দৃশ্যমান থাকবে (`true`) নাকি লুকানো থাকবে (`false`)।
  final bool visible;

  /// প্রদত্ত [brightness] (লাইট বা ডার্ক) অনুযায়ী স্ট্যাটাস বারের কার্যকর রঙ দেয়।
  Color? resolveColor(Brightness brightness) =>
      brightness == Brightness.dark ? (darkColor ?? color) : color;

  /// প্রদত্ত [brightness] ও [fallbackBackground] অনুযায়ী আইকনের উজ্জ্বলতা নির্ণয় করে।
  Brightness resolveIconBrightness(
    Brightness brightness, {
    Color? fallbackBackground,
  }) {
    final explicit = brightness == Brightness.dark
        ? (darkIconBrightness ?? iconBrightness)
        : iconBrightness;
    if (explicit != null) return explicit;

    final resolvedColor = resolveColor(brightness);
    final bg = (resolvedColor != null && resolvedColor.a >= 0.35)
        ? resolvedColor
        : (fallbackBackground != null && fallbackBackground.a >= 0.35)
        ? fallbackBackground
        : (brightness == Brightness.dark ? Colors.black : Colors.white);
    return ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
  }

  /// এই স্ট্যাটাস বারের প্রোপার্টি সহ কপি তৈরি করে।
  OmniStatusBarStyle copyWith({
    Color? color,
    Color? darkColor,
    Brightness? iconBrightness,
    Brightness? darkIconBrightness,
    bool? contrastEnforced,
    bool? visible,
  }) => OmniStatusBarStyle(
    color: color ?? this.color,
    darkColor: darkColor ?? this.darkColor,
    iconBrightness: iconBrightness ?? this.iconBrightness,
    darkIconBrightness: darkIconBrightness ?? this.darkIconBrightness,
    contrastEnforced: contrastEnforced ?? this.contrastEnforced,
    visible: visible ?? this.visible,
  );

  /// [brightness] অনুযায়ী ফ্লাটারের [SystemUiOverlayStyle]-এর কেবল উপরের স্ট্যাটাস বার অংশ তৈরি করে।
  SystemUiOverlayStyle toOverlayStyle({
    required Brightness brightness,
    Color? fallbackBackground,
    bool edgeToEdge = true,
  }) {
    final resolved =
        resolveColor(brightness) ??
        (edgeToEdge ? Colors.transparent : fallbackBackground);
    final icons = resolveIconBrightness(
      brightness,
      fallbackBackground: resolved ?? fallbackBackground,
    );
    return SystemUiOverlayStyle(
      statusBarColor: resolved ?? Colors.transparent,
      statusBarIconBrightness: icons,
      // iOS-এ statusBarBrightness ব্যাকগ্রাউন্ডের উজ্জ্বলতা বোঝায় (আইকনের বিপরীত)।
      statusBarBrightness:
          icons == Brightness.dark ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: contrastEnforced,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniStatusBarStyle &&
          color == other.color &&
          darkColor == other.darkColor &&
          iconBrightness == other.iconBrightness &&
          darkIconBrightness == other.darkIconBrightness &&
          contrastEnforced == other.contrastEnforced &&
          visible == other.visible;

  @override
  int get hashCode => Object.hash(
    color,
    darkColor,
    iconBrightness,
    darkIconBrightness,
    contrastEnforced,
    visible,
  );
}
