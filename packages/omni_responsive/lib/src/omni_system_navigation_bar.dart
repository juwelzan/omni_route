import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ডিভাইসের নিচের **সিস্টেম নেভিগেশন বার ও সোয়াইপ গেস্টচার বার**-এর জন্য
/// সম্পূর্ণ আলাদা কনফিগারেশন ক্লাস।
///
/// Android গেস্টচার নেভিগেশনের নিচে থাকা ছোট সোয়াইপ পিল/ডটের পেছনের কালো
/// এরিয়া (`contrastEnforced: false` + `Colors.transparent`) দূর করতে এবং লাইট
/// ও ডার্ক মোডে (`color` / `darkColor`) নিচের বারের রঙ অ্যাপের **প্রতিটি স্ক্রিনে**
/// গ্লোবালি সেট করতে ব্যবহৃত হয়।
@immutable
class OmniSystemNavigationBarStyle {
  /// নিচের সিস্টেম নেভিগেশন বা গেস্টচার বারের কাস্টম স্টাইল তৈরি করে।
  const OmniSystemNavigationBarStyle({
    this.color = Colors.transparent,
    this.darkColor,
    this.dividerColor = Colors.transparent,
    this.darkDividerColor,
    this.iconBrightness,
    this.darkIconBrightness,
    this.contrastEnforced = false,
    this.visible = true,
  });

  /// সম্পূর্ণ স্বচ্ছ এজ-টু-এজ গেস্টচার/নেভ বার — নিচে কোনো কালো বক্স বা ডট এরিয়া থাকে না (ডিফল্ট)।
  const OmniSystemNavigationBarStyle.transparent({
    this.iconBrightness,
    this.darkIconBrightness,
    this.dividerColor = Colors.transparent,
    this.darkDividerColor,
  }) : color = Colors.transparent,
       darkColor = Colors.transparent,
       contrastEnforced = false,
       visible = true;

  /// নির্দিষ্ট রঙের (লাইট ও ঐচ্ছিক ডার্ক রঙসহ) সলিড বা টিন্টেড সিস্টেম নেভিগেশন বার।
  const OmniSystemNavigationBarStyle.solid({
    this.color,
    this.darkColor,
    this.dividerColor = Colors.transparent,
    this.darkDividerColor,
    this.iconBrightness,
    this.darkIconBrightness,
    this.contrastEnforced = false,
  }) : visible = true;

  /// নিচের সিস্টেম নেভিগেশন ও গেস্টচার বার লুকিয়ে রাখে (`visible: false`)।
  const OmniSystemNavigationBarStyle.hidden()
    : color = Colors.transparent,
      darkColor = Colors.transparent,
      dividerColor = Colors.transparent,
      darkDividerColor = Colors.transparent,
      iconBrightness = null,
      darkIconBrightness = null,
      contrastEnforced = false,
      visible = false;

  /// লাইট মোডে (এবং [darkColor] না দিলে ডার্ক মোডেও) নিচের নেভিগেশন/গেস্টচার বারের রঙ।
  ///
  /// ডিফল্ট `Colors.transparent` যাতে গেস্টচার পিলের নিচে আলাদা কালো এরিয়া তৈরি না হয়।
  final Color? color;

  /// ডার্ক মোডে নিচের নেভিগেশন/গেস্টচার বারের আলাদা রঙ (`null` হলে [color] ব্যবহার হয়)।
  final Color? darkColor;

  /// লাইট মোডে নেভিগেশন বারের উপরের সরু ডিভাইডার লাইনের রঙ (Android P+)।
  final Color? dividerColor;

  /// ডার্ক মোডে নেভিগেশন বারের উপরের ডিভাইডার লাইনের রঙ (`null` হলে [dividerColor])।
  final Color? darkDividerColor;

  /// লাইট মোডে ব্যাক/হোম/রিসেন্ট আইকন বা গেস্টচার হ্যান্ডেলের রঙ (`null` = অটো কনট্রাস্ট)।
  final Brightness? iconBrightness;

  /// ডার্ক মোডে নেভ আইকন বা গেস্টচার হ্যান্ডেলের রঙ (`null` = অটো কনট্রাস্ট)।
  final Brightness? darkIconBrightness;

  /// Android 10+ ডিফল্ট কালো/সাদা scrim বক্স জোর করে দেখাবে কি না
  /// (ডিফল্ট `false` — যাতে গেস্টচার বারের পেছনে কালো এরিয়া না থাকে)।
  final bool contrastEnforced;

  /// নিচের নেভিগেশন/গেস্টচার বার দৃশ্যমান থাকবে (`true`) নাকি লুকানো থাকবে (`false`)।
  final bool visible;

  /// প্রদত্ত [brightness] অনুযায়ী নিচের বারের কার্যকর রঙ দেয়।
  Color? resolveColor(Brightness brightness) =>
      brightness == Brightness.dark ? (darkColor ?? color) : color;

  /// প্রদত্ত [brightness] অনুযায়ী উপরের ডিভাইডার লাইনের রঙ দেয়।
  Color? resolveDividerColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? (darkDividerColor ?? dividerColor)
      : dividerColor;

  /// প্রদত্ত [brightness] ও [fallbackBackground] অনুযায়ী আইকন ব্রাইটনেস নির্ণয় করে।
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

  /// নির্দিষ্ট প্রোপার্টি বদলে নতুন [OmniSystemNavigationBarStyle] কপি দেয়।
  OmniSystemNavigationBarStyle copyWith({
    Color? color,
    Color? darkColor,
    Color? dividerColor,
    Color? darkDividerColor,
    Brightness? iconBrightness,
    Brightness? darkIconBrightness,
    bool? contrastEnforced,
    bool? visible,
  }) => OmniSystemNavigationBarStyle(
    color: color ?? this.color,
    darkColor: darkColor ?? this.darkColor,
    dividerColor: dividerColor ?? this.dividerColor,
    darkDividerColor: darkDividerColor ?? this.darkDividerColor,
    iconBrightness: iconBrightness ?? this.iconBrightness,
    darkIconBrightness: darkIconBrightness ?? this.darkIconBrightness,
    contrastEnforced: contrastEnforced ?? this.contrastEnforced,
    visible: visible ?? this.visible,
  );

  /// [brightness] অনুযায়ী ফ্লাটারের [SystemUiOverlayStyle]-এর নিচের নেভিগেশন বার অংশ তৈরি করে।
  SystemUiOverlayStyle toOverlayStyle({
    required Brightness brightness,
    Color? fallbackBackground,
    bool edgeToEdge = true,
  }) {
    final resolved =
        resolveColor(brightness) ??
        (edgeToEdge ? Colors.transparent : fallbackBackground);
    final div = resolveDividerColor(brightness) ?? Colors.transparent;
    final icons = resolveIconBrightness(
      brightness,
      fallbackBackground: resolved ?? fallbackBackground,
    );
    return SystemUiOverlayStyle(
      systemNavigationBarColor: resolved ?? Colors.transparent,
      systemNavigationBarDividerColor: div,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarContrastEnforced: contrastEnforced,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniSystemNavigationBarStyle &&
          color == other.color &&
          darkColor == other.darkColor &&
          dividerColor == other.dividerColor &&
          darkDividerColor == other.darkDividerColor &&
          iconBrightness == other.iconBrightness &&
          darkIconBrightness == other.darkIconBrightness &&
          contrastEnforced == other.contrastEnforced &&
          visible == other.visible;

  @override
  int get hashCode => Object.hash(
    color,
    darkColor,
    dividerColor,
    darkDividerColor,
    iconBrightness,
    darkIconBrightness,
    contrastEnforced,
    visible,
  );
}
