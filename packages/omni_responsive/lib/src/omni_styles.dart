import 'package:flutter/material.dart';

import 'omni_colors.dart';
import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';

/// পুরো অ্যাপের সব `TextField` / `TextFormField`-এর ডিফল্ট ইনপুট স্টাইল ধরন।
enum OmniInputVariant {
  /// হালকা রঙিন ব্যাকগ্রাউন্ড + চারপাশে সূক্ষ্ম বর্ডার (আধুনিক ডিফল্ট)।
  filled,

  /// স্বচ্ছ বা কার্ড-রঙিন ব্যাকগ্রাউন্ড + স্পষ্ট চারপাশের আউটলাইন বর্ডার।
  outlined,

  /// কেবল নিচে একটি পরিচ্ছন্ন লাইন বর্ডার (মিনিমাল ফর্মের জন্য)।
  underlined,
}

/// ডেভেলপারদের জন্য ১-লাইনের রেডিমেড UI ডিজাইন স্টাইল প্রিসেট (`OmniTheme(style: ...)`
/// অথবা সেটিংস থেকে `context.setThemeStyle(...)`)।
///
/// আলাদা আলাদা `borderRadius`, `inputVariant`, `cardBorderWidth`, `cardElevation`
/// মনে না রেখেও মাত্র ১টি প্রিসেটে পুরো অ্যাপের লুক বদলে দেওয়া যায়।
enum OmniThemeStyle {
  /// আধুনিক ফ্ল্যাট কার্ড (`1dp` বর্ডার), ব্যালেন্সড রেডিয়াস ও `.filled` ইনপুট (ডিফল্ট)।
  modern(
    label: 'Modern',
    inputVariant: OmniInputVariant.filled,
    borderWidth: 1.0,
    focusedBorderWidth: 1.8,
    cardBorderWidth: 1.0,
    cardElevation: 0.0,
  ),

  /// পরিষ্কার চারপাশের আউটলাইন কার্ড ও `.outlined` ইনপুট ফিল্ড (ফর্ম ও SaaS অ্যাপের আদর্শ)।
  outlined(
    label: 'Outlined',
    inputVariant: OmniInputVariant.outlined,
    borderWidth: 1.2,
    focusedBorderWidth: 2.0,
    cardBorderWidth: 1.2,
    cardElevation: 0.0,
  ),

  /// গোল `20dp` পিল কর্নার ও বর্ডার-মুক্ত সফট কনজিউমার অ্যাপ স্টাইল।
  soft(
    label: 'Soft',
    inputVariant: OmniInputVariant.filled,
    borderWidth: 1.0,
    focusedBorderWidth: 1.8,
    cardBorderWidth: 0.0,
    cardElevation: 0.0,
    borderRadius: 20.0,
  ),

  /// হালকা শ্যাডো (`2dp`) যুক্ত এলিভেটেড কার্ড ও `.filled` ইনপুট।
  elevated(
    label: 'Elevated',
    inputVariant: OmniInputVariant.filled,
    borderWidth: 1.0,
    focusedBorderWidth: 1.8,
    cardBorderWidth: 0.0,
    cardElevation: 2.0,
  ),

  /// শুধু নিচে লাইনওয়ালা মিনিমাল `.underlined` ইনপুট ও সূক্ষ্ম বর্ডার।
  minimal(
    label: 'Minimal',
    inputVariant: OmniInputVariant.underlined,
    borderWidth: 1.0,
    focusedBorderWidth: 1.8,
    cardBorderWidth: 0.8,
    cardElevation: 0.0,
  ),

  /// তীক্ষ্ণ `8dp` কর্নার ও `.outlined` ইনপুটসহ ড্যাশবোর্ড/অ্যাডমিন কম্প্যাক্ট স্টাইল।
  compact(
    label: 'Compact',
    inputVariant: OmniInputVariant.outlined,
    borderWidth: 1.0,
    focusedBorderWidth: 1.6,
    cardBorderWidth: 1.0,
    cardElevation: 0.0,
    borderRadius: 8.0,
  ),

  /// গোল `24dp` পিল-শেপ কর্নার ও `.filled` ইনপুটসহ ফ্রেন্ডলি কনজিউমার স্টাইল।
  pill(
    label: 'Pill',
    inputVariant: OmniInputVariant.filled,
    borderWidth: 0.8,
    focusedBorderWidth: 1.8,
    cardBorderWidth: 0.8,
    cardElevation: 0.0,
    borderRadius: 24.0,
  ),

  /// তীক্ষ্ণ `4dp` জিওমেট্রিক কর্নার ও `.outlined` ইনপুটসহ এডিটোরিয়াল/ডাটা স্টাইল।
  sharp(
    label: 'Sharp',
    inputVariant: OmniInputVariant.outlined,
    borderWidth: 1.2,
    focusedBorderWidth: 2.0,
    cardBorderWidth: 1.2,
    cardElevation: 0.0,
    borderRadius: 4.0,
  ),

  /// বর্ডারহীন `16dp` কার্ডে উঁচু `6.0dp` শ্যাডোসহ ফ্লোটিং এলিভেটেড স্টাইল।
  floating(
    label: 'Floating',
    inputVariant: OmniInputVariant.filled,
    borderWidth: 0.0,
    focusedBorderWidth: 1.6,
    cardBorderWidth: 0.0,
    cardElevation: 6.0,
    borderRadius: 16.0,
  ),

  /// মোটা `2.2dp` বর্ডার ও ৬dp কর্নারসহ আধুনিক নিও-ব্রুটালিস্ট/হাই-কনট্রাস্ট স্টাইল।
  brutal(
    label: 'Bold Edge',
    inputVariant: OmniInputVariant.outlined,
    borderWidth: 2.2,
    focusedBorderWidth: 3.0,
    cardBorderWidth: 2.2,
    cardElevation: 0.0,
    borderRadius: 6.0,
  ),

  /// কোনো কার্ড বা ইনপুট বর্ডার/শ্যাডো ছাড়া টোনাল সারফেস-ভিত্তিক ক্লিন ফ্ল্যাট স্টাইল।
  flat(
    label: 'Flat',
    inputVariant: OmniInputVariant.filled,
    borderWidth: 0.0,
    focusedBorderWidth: 1.6,
    cardBorderWidth: 0.0,
    cardElevation: 0.0,
    borderRadius: 12.0,
  ),

  /// পাতলা `0.7dp` বর্ডার, `1.0dp` লিফট ও `18dp` কর্নারসহ হালকা এয়ারি স্টাইল।
  glassy(
    label: 'Airy',
    inputVariant: OmniInputVariant.outlined,
    borderWidth: 0.7,
    focusedBorderWidth: 1.5,
    cardBorderWidth: 0.7,
    cardElevation: 1.0,
    borderRadius: 18.0,
  );

  const OmniThemeStyle({
    required this.label,
    required this.inputVariant,
    required this.borderWidth,
    required this.focusedBorderWidth,
    required this.cardBorderWidth,
    required this.cardElevation,
    this.borderRadius,
  });

  /// UI পিকারে দেখানোর সহজ নাম।
  final String label;

  /// এই স্টাইলের ডিফল্ট ইনপুট ভ্যারিয়েন্ট।
  final OmniInputVariant inputVariant;

  /// সাধারণ অবস্থায় ইনপুট, চিপ ও আউটলাইন বর্ডারের পুরুত্ব।
  final double borderWidth;

  /// ফোকাস বা এরর অবস্থায় বর্ডারের পুরুত্ব।
  final double focusedBorderWidth;

  /// কার্ডের চারদিকের বর্ডারের পুরুত্ব।
  final double cardBorderWidth;

  /// কার্ডের শ্যাডো উচ্চতা।
  final double cardElevation;

  /// ঐচ্ছিক নির্দিষ্ট কর্নার রেডিয়াস (`null` হলে টিয়ার অনুযায়ী অটো)।
  final double? borderRadius;
}

/// প্রি-ক্যাশড, রেসপন্সিভ ও পিওর নামের টেক্সট স্টাইল সেট (`context.textStyles`)।
///
/// প্রতিবার স্ক্রিন বিল্ডে `TextStyle(...)` তৈরি করার বদলে একবারে টিয়ার অনুযায়ী
/// মেমোইজড স্টাইল দেয় — শূন্য মেমরি অ্যালোকেশন ও ডার্ক/লাইট অটো-সাপোর্টসহ।
@immutable
class OmniTextStyles extends ThemeExtension<OmniTextStyles> {
  /// সব টেক্সট রোল নিয়ে [OmniTextStyles] তৈরি করে।
  const OmniTextStyles({
    required this.display,
    required this.heading,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.bodyMuted,
    required this.label,
    required this.caption,
    required this.hint,
    required this.button,
    required this.link,
    required this.error,
    required this.warning,
    required this.success,
    required this.code,
  });

  /// বড় হিরো টাইটেল, ব্যালেন্স অঙ্ক বা স্প্ল্যাশ হেডলাইন স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** ড্যাশবোর্ডের বড় টাকা/সংখ্যা, অনবোর্ডিং প্রধান শিরোনাম।
  /// **কী কাজে লাগে:** তাৎক্ষণিকভাবে মূল সংখ্যা বা হেডলাইনে নজর টানতে।
  final TextStyle display;

  /// পেজ ও বড় সেকশনের মূল শিরোনাম স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** স্ক্রিন হেডার, ফর্ম শিরোনাম (`"লগইন করুন"`)।
  /// **কী কাজে লাগে:** স্ক্রিনের প্রধান সেকশনগুলোকে পরিষ্কারভাবে শুরু করতে।
  final TextStyle heading;

  /// কার্ড, ডায়ালগ ও অ্যাপবার টাইটেল স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** `AppBar.title`, `Card` হেডার ও পপআপ ডায়ালগ শিরোনাম।
  /// **কী কাজে লাগে:** মাঝারি গুরুত্বের টাইটেলগুলোকে সুন্দরভাবে সাজাতে।
  final TextStyle title;

  /// সাবটাইটেল ও লিস্ট আইটেমের প্রধান লেখার স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** `ListTile.title`, সেটিংস আইটেম ও সেকশন সাবহেডার।
  /// **কী কাজে লাগে:** সাধারণ বডি টেক্সটের চেয়ে একটু ভারী ও স্পষ্ট দেখাতে।
  final TextStyle subtitle;

  /// সাধারণ অনুচ্ছেদ, বিবরণ ও মূল প্যারাগ্রাফ পড়ার স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** আর্টিকেল, প্রোডাক্ট বিবরণ, কমেন্ট ও মেসেজ বডি।
  /// **কী কাজে লাগে:** সব ডিভাইসে আরামদায়ক ও সহজে পড়া যায় এমন টেক্সট দিতে।
  final TextStyle body;

  /// তুলনামূলক হালকা রঙের সহায়ক প্যারাগ্রাফ ও সাবটাইটেল স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** `ListTile.subtitle`, বিবরণ ও কার্ডের দ্বিতীয় লাইন।
  /// **কী কাজে লাগে:** মূল লেখাকে হাইলাইট রেখে সহায়ক তথ্য নরম রাখতে।
  final TextStyle bodyMuted;

  /// ইনপুট ফিল্ডের উপরের লেবেল ও ট্যাব/বাটন ক্যাটাগরি লেখার স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** `InputDecoration.labelStyle`, ফর্ম ফিল্ড হেডার, চিপ।
  /// **কী কাজে লাগে:** ফিল্ডের নামটি পরিষ্কার ও গোছানো দেখাতে।
  final TextStyle label;

  /// ছোট ক্যাপশন, সময়, তারিখ ও মেটাডেটা লেখার স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** `"২ মিনিট আগে"`, ব্যাজ কাউন্টার ও ফুটার নোট।
  /// **কী কাজে লাগে:** অপ্রধান কিন্তু দরকারি ছোট তথ্য দেখাতে।
  final TextStyle caption;

  /// ইনপুটের প্লেসহোল্ডার ও হিন্ট লেখার স্টাইল (`colors.hintTextColor`)।
  ///
  /// **কোথায় ব্যবহার হয়:** `TextField` হিন্ট, সার্চ প্লেসহোল্ডার।
  /// **কী কাজে লাগে:** ইনপুট খালি থাকা অবস্থায় উদাহরণ লেখা দেখাতে।
  final TextStyle hint;

  /// বাটনের ভেতরের লেখার স্টাইল (সেমি-বোল্ড)।
  ///
  /// **কোথায় ব্যবহার হয়:** কাস্টম বাটন, CTA লেবেল ও ডায়ালগ অ্যাকশন।
  /// **কী কাজে লাগে:** বাটনের লেখা স্পষ্ট ও সুষম রাখতে।
  final TextStyle button;

  /// ক্লিকেবল লিংক লেখার স্টাইল (`colors.linkColor`)।
  ///
  /// **কোথায় ব্যবহার হয়:** `"পাসওয়ার্ড ভুলে গেছেন?"`, `"আরও দেখুন"`, URL টেক্সট।
  /// **কী কাজে লাগে:** লিংকটি যে ট্যাপযোগ্য তা চোখে বুঝিয়ে দিতে।
  final TextStyle link;

  /// ফর্ম ভুল ও এরর মেসেজ দেখানোর স্টাইল (`colors.errorColor`)।
  ///
  /// **কোথায় ব্যবহার হয়:** `TextField` ভ্যালিডেশন এরর ও অ্যালার্ট টেক্সট।
  /// **কী কাজে লাগে:** ভুল তথ্য দিলে ইউজারকে স্পষ্টভাবে সতর্ক করতে।
  final TextStyle error;

  /// সতর্কতামূলক নোটিশ লেখার স্টাইল (`colors.warningColor`)।
  ///
  /// **কোথায় ব্যবহার হয়:** পেন্ডিং ব্যানার ও লিমিট সতর্কতা লেখা।
  /// **কী কাজে লাগে:** সাবধানবাণী পরিষ্কারভাবে ফুটিয়ে তুলতে।
  final TextStyle warning;

  /// সফল বা ভেরিফাইড স্ট্যাটাস লেখার স্টাইল (`colors.successColor`)।
  ///
  /// **কোথায় ব্যবহার হয়:** `"Paid"`, `"Verified"`, ও অর্ডার সফল টেক্সট।
  /// **কী কাজে লাগে:** ইতিবাচক কনফার্মেশন স্পষ্ট করতে।
  final TextStyle success;

  /// অর্ডার আইডি, OTP কোড, প্রোমো কোড বা টেকনিক্যাল ডেটার মনোস্পেস স্টাইল।
  ///
  /// **কোথায় ব্যবহার হয়:** ইনভয়েস আইডি, ভেরিফিকেশন কোড, API/ডিবাগ টেক্সট।
  /// **কী কাজে লাগে:** প্রতিটি অক্ষর ও সংখ্যা সমান প্রস্থে পরিষ্কার দেখাতে।
  final TextStyle code;

  /// [colors] ও [tokens] থেকে পুরো টেক্সট স্টাইল সেট তৈরি করে।
  factory OmniTextStyles.fromTheme({
    required OmniColors colors,
    required OmniResponsiveTokens tokens,
    String? fontFamily,
    FontWeight headingWeight = FontWeight.w700,
  }) => OmniTextStyles(
    display: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.displaySize,
      fontWeight: headingWeight,
      color: colors.textColor,
      height: 1.15,
      letterSpacing: -0.4,
    ),
    heading: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.headlineSize,
      fontWeight: headingWeight,
      color: colors.textColor,
      height: 1.25,
      letterSpacing: -0.2,
    ),
    title: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.titleSize,
      fontWeight: FontWeight.w600,
      color: colors.textColor,
      height: 1.3,
    ),
    subtitle: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.bodySize + 1,
      fontWeight: FontWeight.w600,
      color: colors.textColor,
      height: 1.35,
    ),
    body: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.bodySize,
      fontWeight: FontWeight.w400,
      color: colors.textColor,
      height: 1.5,
    ),
    bodyMuted: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.bodySize,
      fontWeight: FontWeight.w400,
      color: colors.secondaryTextColor,
      height: 1.5,
    ),
    label: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.labelSize + 1,
      fontWeight: FontWeight.w500,
      color: colors.textColor,
      height: 1.3,
    ),
    caption: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.labelSize,
      fontWeight: FontWeight.w400,
      color: colors.secondaryTextColor,
      height: 1.35,
    ),
    hint: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.bodySize,
      fontWeight: FontWeight.w400,
      color: colors.hintTextColor,
      height: 1.4,
    ),
    button: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.bodySize + 0.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    link: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.bodySize,
      fontWeight: FontWeight.w500,
      color: colors.linkColor,
      height: 1.4,
    ),
    error: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.labelSize,
      fontWeight: FontWeight.w500,
      color: colors.errorColor,
      height: 1.35,
    ),
    warning: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.labelSize,
      fontWeight: FontWeight.w500,
      color: colors.warningColor,
      height: 1.35,
    ),
    success: TextStyle(
      fontFamily: fontFamily,
      fontSize: tokens.labelSize,
      fontWeight: FontWeight.w600,
      color: colors.successColor,
      height: 1.35,
    ),
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: tokens.bodySize - 0.5,
      fontWeight: FontWeight.w500,
      color: colors.textColor,
      height: 1.45,
    ),
  );

  /// ডিফল্ট লাইট [OmniTextStyles] ফলব্যাক।
  static final OmniTextStyles lightDefault = OmniTextStyles.fromTheme(
    colors: OmniColors.lightDefault,
    tokens: OmniResponsiveTokens.mobile,
  );

  /// ডিফল্ট ডার্ক [OmniTextStyles] ফলব্যাক।
  static final OmniTextStyles darkDefault = OmniTextStyles.fromTheme(
    colors: OmniColors.darkDefault,
    tokens: OmniResponsiveTokens.mobile,
  );

  /// নির্দিষ্ট স্টাইল বদলে নতুন কপি তৈরি করে।
  @override
  OmniTextStyles copyWith({
    TextStyle? display,
    TextStyle? heading,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? bodyMuted,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? hint,
    TextStyle? button,
    TextStyle? link,
    TextStyle? error,
    TextStyle? warning,
    TextStyle? success,
    TextStyle? code,
  }) => OmniTextStyles(
    display: display ?? this.display,
    heading: heading ?? this.heading,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    body: body ?? this.body,
    bodyMuted: bodyMuted ?? this.bodyMuted,
    label: label ?? this.label,
    caption: caption ?? this.caption,
    hint: hint ?? this.hint,
    button: button ?? this.button,
    link: link ?? this.link,
    error: error ?? this.error,
    warning: warning ?? this.warning,
    success: success ?? this.success,
    code: code ?? this.code,
  );

  @override
  OmniTextStyles lerp(
    covariant ThemeExtension<OmniTextStyles>? other,
    double t,
  ) {
    if (other is! OmniTextStyles) return this;
    return OmniTextStyles(
      display: TextStyle.lerp(display, other.display, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      subtitle: TextStyle.lerp(subtitle, other.subtitle, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyMuted: TextStyle.lerp(bodyMuted, other.bodyMuted, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      hint: TextStyle.lerp(hint, other.hint, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      link: TextStyle.lerp(link, other.link, t)!,
      error: TextStyle.lerp(error, other.error, t)!,
      warning: TextStyle.lerp(warning, other.warning, t)!,
      success: TextStyle.lerp(success, other.success, t)!,
      code: TextStyle.lerp(code, other.code, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniTextStyles &&
          display == other.display &&
          heading == other.heading &&
          title == other.title &&
          subtitle == other.subtitle &&
          body == other.body &&
          bodyMuted == other.bodyMuted &&
          label == other.label &&
          caption == other.caption &&
          hint == other.hint &&
          button == other.button &&
          link == other.link &&
          error == other.error &&
          warning == other.warning &&
          success == other.success &&
          code == other.code;

  @override
  int get hashCode => Object.hashAll([
    display,
    heading,
    title,
    subtitle,
    body,
    bodyMuted,
    label,
    caption,
    hint,
    button,
    link,
    error,
    warning,
    success,
    code,
  ]);
}

/// কার্ড, অ্যালার্ট বক্স, বাটন ও টেক্সট ফিল্ডের প্রি-অ্যালোকেটেড স্টাইল বান্ডিল
/// (`context.styles`)।
///
/// একবার `OmniTheme` তৈরি হওয়ার সময়ই সব `BoxDecoration` ও `ButtonStyle` ক্যাশ
/// হয়ে যায় — ফলে স্ক্রল বা রেন্ডারিংয়ে **০% বাড়তি মেমরি খরচ** হয়।
@immutable
class OmniStyles extends ThemeExtension<OmniStyles> {
  /// সব প্রি-অ্যালোকেটেড ডেকোরেশন ও বাটন স্টাইল নিয়ে [OmniStyles] তৈরি করে।
  const OmniStyles({
    required this.colors,
    required this.textStyles,
    required this.inputDecorationTheme,
    required this.inputRadius,
    required this.cardDecoration,
    required this.elevatedCardDecoration,
    required this.selectedCardDecoration,
    required this.subtleBoxDecoration,
    required this.disabledBoxDecoration,
    required this.errorBoxDecoration,
    required this.warningBoxDecoration,
    required this.successBoxDecoration,
    required this.infoBoxDecoration,
    required this.chipDecoration,
    required this.badgeDecoration,
    required this.primaryButton,
    required this.secondaryButton,
    required this.dangerButton,
    required this.outlineButton,
    required this.linkButton,
  });

  /// বর্তমান [OmniColors] রেফারেন্স।
  final OmniColors colors;

  /// বর্তমান [OmniTextStyles] রেফারেন্স।
  final OmniTextStyles textStyles;

  /// থিমে ব্যবহৃত সম্পূর্ণ [InputDecorationTheme]।
  final InputDecorationTheme inputDecorationTheme;

  /// টেক্সট ফিল্ড ও বাটনের বর্ডার রেডিয়াস।
  final BorderRadius inputRadius;

  /// সাধারণ কার্ড বা বক্সের জন্য রেডি `BoxDecoration` (বর্ডারসহ)।
  ///
  /// **কোথায় ব্যবহার হয়:** `Container(decoration: context.styles.cardDecoration)`।
  final BoxDecoration cardDecoration;

  /// হালকা ছায়া (`shadowColor`)-সহ এলিভেটেড কার্ডের `BoxDecoration`।
  ///
  /// **কোথায় ব্যবহার হয়:** ফ্লোটিং সামারি কার্ড ও পপআউট প্যানেল।
  final BoxDecoration elevatedCardDecoration;

  /// সিলেক্ট করা বা সক্রিয় কার্ডের হাইলাইট বর্ডারওয়ালা `BoxDecoration`।
  ///
  /// **কোথায় ব্যবহার হয়:** পেমেন্ট মেথড, প্ল্যান কার্ড বা সিলেক্টেড লিস্ট টাইল।
  final BoxDecoration selectedCardDecoration;

  /// সেকশন হেডার, কোড ব্লক বা হালকা আলাদা প্যানেলের `BoxDecoration`
  /// (`secondaryBackgroundColor` + `dividerColor`)।
  final BoxDecoration subtleBoxDecoration;

  /// নিষ্ক্রিয় (disabled) কার্ড বা রিড-অনলি ব্লকের `BoxDecoration`
  /// (`disabledColor` + `disabledBorderColor`)।
  final BoxDecoration disabledBoxDecoration;

  /// এরর অ্যালার্ট বক্সের রেডি `BoxDecoration` (`errorBackgroundColor` + `errorColor` বর্ডার)।
  final BoxDecoration errorBoxDecoration;

  /// ওয়ার্নিং বা সতর্কতা বক্সের রেডি `BoxDecoration` (`warningBackgroundColor` + `warningColor` বর্ডার)।
  final BoxDecoration warningBoxDecoration;

  /// সাকসেস বা কনফার্মেশন বক্সের রেডি `BoxDecoration` (`successBackgroundColor` + `successColor` বর্ডার)।
  final BoxDecoration successBoxDecoration;

  /// ইনফরমেশন বা টিপস বক্সের রেডি `BoxDecoration` (`infoBackgroundColor` + `infoColor` বর্ডার)।
  final BoxDecoration infoBoxDecoration;

  /// ট্যাগ বা ফিল্টার চিপের `BoxDecoration`।
  final BoxDecoration chipDecoration;

  /// কাউন্টার বা স্ট্যাটাস ব্যাজের পিল `BoxDecoration`।
  final BoxDecoration badgeDecoration;

  /// প্রাইমারি অ্যাকশন বাটন স্টাইল (`buttonColor` + `buttonTextColor`)।
  final ButtonStyle primaryButton;

  /// সেকেন্ডারি বা ক্যানসেল বাটন স্টাইল (`secondaryButtonColor` + `secondaryButtonTextColor`)।
  final ButtonStyle secondaryButton;

  /// ডিলিট, রিমুভ বা লগআউট বাটন স্টাইল (`dangerButtonColor` + `dangerButtonTextColor`)।
  ///
  /// উদাহরণ: `FilledButton(style: context.styles.dangerButton, onPressed: ..., child: const Text('মুছে ফেলুন'))`।
  final ButtonStyle dangerButton;

  /// আউটলাইন বর্ডারওয়ালা বাটন স্টাইল (`borderColor` + `disabledBorderColor` + `primaryColor`)।
  final ButtonStyle outlineButton;

  /// লিংক বা `TextButton`-এর স্টাইল (`linkColor`)।
  final ButtonStyle linkButton;

  /// [OmniColors], [OmniTextStyles], এবং [OmniResponsiveTokens] থেকে প্রি-ক্যাশড
  /// [OmniStyles] বান্ডিল তৈরি করে।
  factory OmniStyles.resolve({
    required OmniColors colors,
    required OmniTextStyles textStyles,
    required OmniResponsiveTokens tokens,
    required BorderRadius cardRadius,
    required BorderRadius buttonRadius,
    required OmniInputVariant inputVariant,
    required double borderWidth,
    required double focusedBorderWidth,
    required double cardBorderWidth,
  }) {
    BorderSide makeSide(Color color, double width) =>
        width <= 0 ? BorderSide.none : BorderSide(color: color, width: width);

    InputBorder makeInputBorder(Color color, double width) =>
        switch (inputVariant) {
          OmniInputVariant.underlined => UnderlineInputBorder(
            borderSide: makeSide(color, width),
          ),
          OmniInputVariant.filled ||
          OmniInputVariant.outlined => OutlineInputBorder(
            borderRadius: buttonRadius,
            borderSide: makeSide(color, width),
          ),
        };

    final inputTheme = InputDecorationTheme(
      filled: inputVariant == OmniInputVariant.filled,
      fillColor: inputVariant == OmniInputVariant.outlined
          ? colors.cardColor
          : colors.inputFillColor,
      labelStyle: textStyles.label,
      floatingLabelStyle: textStyles.label.copyWith(
        color: colors.focusedBorderColor,
      ),
      hintStyle: textStyles.hint,
      helperStyle: textStyles.caption,
      errorStyle: textStyles.error,
      prefixIconColor: colors.iconColor,
      suffixIconColor: colors.iconColor,
      contentPadding: tokens.cardPadding,
      border: makeInputBorder(colors.borderColor, borderWidth),
      enabledBorder: makeInputBorder(colors.borderColor, borderWidth),
      focusedBorder: makeInputBorder(
        colors.focusedBorderColor,
        focusedBorderWidth,
      ),
      errorBorder: makeInputBorder(colors.errorColor, borderWidth),
      focusedErrorBorder: makeInputBorder(
        colors.errorColor,
        focusedBorderWidth,
      ),
      disabledBorder: makeInputBorder(colors.disabledBorderColor, borderWidth),
    );

    final minSize = Size(0, tokens.minTapTarget);
    final buttonShape = RoundedRectangleBorder(borderRadius: buttonRadius);

    return OmniStyles(
      colors: colors,
      textStyles: textStyles,
      inputDecorationTheme: inputTheme,
      inputRadius: buttonRadius,
      cardDecoration: BoxDecoration(
        color: colors.cardColor,
        borderRadius: cardRadius,
        border: cardBorderWidth > 0
            ? Border.all(color: colors.borderColor, width: cardBorderWidth)
            : null,
      ),
      elevatedCardDecoration: BoxDecoration(
        color: colors.cardColor,
        borderRadius: cardRadius,
        border: Border.all(color: colors.dividerColor),
        boxShadow: [
          BoxShadow(
            color: colors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      selectedCardDecoration: BoxDecoration(
        color: colors.selectedItemColor,
        borderRadius: cardRadius,
        border: Border.all(
          color: colors.focusedBorderColor,
          width: focusedBorderWidth,
        ),
      ),
      subtleBoxDecoration: BoxDecoration(
        color: colors.secondaryBackgroundColor,
        borderRadius: cardRadius,
        border: Border.all(color: colors.dividerColor),
      ),
      disabledBoxDecoration: BoxDecoration(
        color: colors.disabledColor,
        borderRadius: cardRadius,
        border: borderWidth > 0
            ? Border.all(color: colors.disabledBorderColor, width: borderWidth)
            : null,
      ),
      errorBoxDecoration: BoxDecoration(
        color: colors.errorBackgroundColor,
        borderRadius: cardRadius,
        border: borderWidth > 0
            ? Border.all(color: colors.errorColor, width: borderWidth)
            : null,
      ),
      warningBoxDecoration: BoxDecoration(
        color: colors.warningBackgroundColor,
        borderRadius: cardRadius,
        border: borderWidth > 0
            ? Border.all(color: colors.warningColor, width: borderWidth)
            : null,
      ),
      successBoxDecoration: BoxDecoration(
        color: colors.successBackgroundColor,
        borderRadius: cardRadius,
        border: borderWidth > 0
            ? Border.all(color: colors.successColor, width: borderWidth)
            : null,
      ),
      infoBoxDecoration: BoxDecoration(
        color: colors.infoBackgroundColor,
        borderRadius: cardRadius,
        border: borderWidth > 0
            ? Border.all(color: colors.infoColor, width: borderWidth)
            : null,
      ),
      chipDecoration: BoxDecoration(
        color: colors.chipColor,
        borderRadius: buttonRadius,
      ),
      badgeDecoration: BoxDecoration(
        color: colors.badgeColor,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      primaryButton: FilledButton.styleFrom(
        backgroundColor: colors.buttonColor,
        foregroundColor: colors.buttonTextColor,
        disabledBackgroundColor: colors.disabledColor,
        disabledForegroundColor: colors.disabledTextColor,
        textStyle: textStyles.button,
        minimumSize: minSize,
        shape: buttonShape,
      ),
      secondaryButton: FilledButton.styleFrom(
        backgroundColor: colors.secondaryButtonColor,
        foregroundColor: colors.secondaryButtonTextColor,
        disabledBackgroundColor: colors.disabledColor,
        disabledForegroundColor: colors.disabledTextColor,
        textStyle: textStyles.button,
        minimumSize: minSize,
        shape: buttonShape,
      ),
      dangerButton: FilledButton.styleFrom(
        backgroundColor: colors.dangerButtonColor,
        foregroundColor: colors.dangerButtonTextColor,
        disabledBackgroundColor: colors.disabledColor,
        disabledForegroundColor: colors.disabledTextColor,
        textStyle: textStyles.button,
        minimumSize: minSize,
        shape: buttonShape,
      ),
      outlineButton:
          OutlinedButton.styleFrom(
            foregroundColor: colors.primaryColor,
            disabledForegroundColor: colors.disabledTextColor,
            textStyle: textStyles.button,
            minimumSize: minSize,
            shape: buttonShape,
          ).copyWith(
            side: WidgetStateProperty.resolveWith<BorderSide>(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? colors.disabledBorderColor
                    : states.contains(WidgetState.focused)
                    ? colors.focusedBorderColor
                    : colors.borderColor,
                width: borderWidth > 0 ? borderWidth : 1.0,
              ),
            ),
          ),
      linkButton: TextButton.styleFrom(
        foregroundColor: colors.linkColor,
        disabledForegroundColor: colors.disabledTextColor,
        textStyle: textStyles.link,
        minimumSize: minSize,
        shape: buttonShape,
      ),
    );
  }

  /// যেকোনো `TextField` / `TextFormField`-এ প্রি-কনফিগার্ড সুন্দর `InputDecoration`
  /// তৈরি করে।
  InputDecoration inputDecoration({
    String? label,
    String? hint,
    String? helper,
    String? error,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool enabled = true,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    errorText: error,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    enabled: enabled,
  );

  /// পিল-আকৃতির সার্চ বারের জন্য রেডি `InputDecoration`।
  InputDecoration searchDecoration({
    String hint = 'Search...',
    VoidCallback? onClear,
    Widget? prefixIcon,
  }) => InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon ?? const Icon(Icons.search),
    suffixIcon: onClear == null
        ? null
        : IconButton(icon: const Icon(Icons.close), onPressed: onClear),
    border: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      borderSide: BorderSide(color: colors.borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      borderSide: BorderSide(color: colors.borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      borderSide: BorderSide(color: colors.focusedBorderColor, width: 1.8),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      borderSide: BorderSide(color: colors.disabledBorderColor),
    ),
  );

  /// ডিফল্ট লাইট [OmniStyles] ফলব্যাক।
  static final OmniStyles lightDefault = OmniStyles.resolve(
    colors: OmniColors.lightDefault,
    textStyles: OmniTextStyles.lightDefault,
    tokens: OmniResponsiveTokens.mobile,
    cardRadius: OmniResponsiveTokens.mobile.cardBorderRadius,
    buttonRadius: OmniResponsiveTokens.mobile.buttonBorderRadius,
    inputVariant: OmniInputVariant.filled,
    borderWidth: 1,
    focusedBorderWidth: 1.8,
    cardBorderWidth: 1,
  );

  /// ডিফল্ট ডার্ক [OmniStyles] ফলব্যাক।
  static final OmniStyles darkDefault = OmniStyles.resolve(
    colors: OmniColors.darkDefault,
    textStyles: OmniTextStyles.darkDefault,
    tokens: OmniResponsiveTokens.mobile,
    cardRadius: OmniResponsiveTokens.mobile.cardBorderRadius,
    buttonRadius: OmniResponsiveTokens.mobile.buttonBorderRadius,
    inputVariant: OmniInputVariant.filled,
    borderWidth: 1,
    focusedBorderWidth: 1.8,
    cardBorderWidth: 1,
  );

  @override
  OmniStyles copyWith({
    OmniColors? colors,
    OmniTextStyles? textStyles,
    InputDecorationTheme? inputDecorationTheme,
    BorderRadius? inputRadius,
    BoxDecoration? cardDecoration,
    BoxDecoration? elevatedCardDecoration,
    BoxDecoration? selectedCardDecoration,
    BoxDecoration? subtleBoxDecoration,
    BoxDecoration? disabledBoxDecoration,
    BoxDecoration? errorBoxDecoration,
    BoxDecoration? warningBoxDecoration,
    BoxDecoration? successBoxDecoration,
    BoxDecoration? infoBoxDecoration,
    BoxDecoration? chipDecoration,
    BoxDecoration? badgeDecoration,
    ButtonStyle? primaryButton,
    ButtonStyle? secondaryButton,
    ButtonStyle? dangerButton,
    ButtonStyle? outlineButton,
    ButtonStyle? linkButton,
  }) => OmniStyles(
    colors: colors ?? this.colors,
    textStyles: textStyles ?? this.textStyles,
    inputDecorationTheme: inputDecorationTheme ?? this.inputDecorationTheme,
    inputRadius: inputRadius ?? this.inputRadius,
    cardDecoration: cardDecoration ?? this.cardDecoration,
    elevatedCardDecoration:
        elevatedCardDecoration ?? this.elevatedCardDecoration,
    selectedCardDecoration:
        selectedCardDecoration ?? this.selectedCardDecoration,
    subtleBoxDecoration: subtleBoxDecoration ?? this.subtleBoxDecoration,
    disabledBoxDecoration: disabledBoxDecoration ?? this.disabledBoxDecoration,
    errorBoxDecoration: errorBoxDecoration ?? this.errorBoxDecoration,
    warningBoxDecoration: warningBoxDecoration ?? this.warningBoxDecoration,
    successBoxDecoration: successBoxDecoration ?? this.successBoxDecoration,
    infoBoxDecoration: infoBoxDecoration ?? this.infoBoxDecoration,
    chipDecoration: chipDecoration ?? this.chipDecoration,
    badgeDecoration: badgeDecoration ?? this.badgeDecoration,
    primaryButton: primaryButton ?? this.primaryButton,
    secondaryButton: secondaryButton ?? this.secondaryButton,
    dangerButton: dangerButton ?? this.dangerButton,
    outlineButton: outlineButton ?? this.outlineButton,
    linkButton: linkButton ?? this.linkButton,
  );

  @override
  OmniStyles lerp(covariant ThemeExtension<OmniStyles>? other, double t) {
    if (other is! OmniStyles) return this;
    return OmniStyles(
      colors: colors.lerp(other.colors, t),
      textStyles: textStyles.lerp(other.textStyles, t),
      inputDecorationTheme: t < 0.5
          ? inputDecorationTheme
          : other.inputDecorationTheme,
      inputRadius: BorderRadius.lerp(inputRadius, other.inputRadius, t)!,
      cardDecoration: BoxDecoration.lerp(
        cardDecoration,
        other.cardDecoration,
        t,
      )!,
      elevatedCardDecoration: BoxDecoration.lerp(
        elevatedCardDecoration,
        other.elevatedCardDecoration,
        t,
      )!,
      selectedCardDecoration: BoxDecoration.lerp(
        selectedCardDecoration,
        other.selectedCardDecoration,
        t,
      )!,
      subtleBoxDecoration: BoxDecoration.lerp(
        subtleBoxDecoration,
        other.subtleBoxDecoration,
        t,
      )!,
      disabledBoxDecoration: BoxDecoration.lerp(
        disabledBoxDecoration,
        other.disabledBoxDecoration,
        t,
      )!,
      errorBoxDecoration: BoxDecoration.lerp(
        errorBoxDecoration,
        other.errorBoxDecoration,
        t,
      )!,
      warningBoxDecoration: BoxDecoration.lerp(
        warningBoxDecoration,
        other.warningBoxDecoration,
        t,
      )!,
      successBoxDecoration: BoxDecoration.lerp(
        successBoxDecoration,
        other.successBoxDecoration,
        t,
      )!,
      infoBoxDecoration: BoxDecoration.lerp(
        infoBoxDecoration,
        other.infoBoxDecoration,
        t,
      )!,
      chipDecoration: BoxDecoration.lerp(
        chipDecoration,
        other.chipDecoration,
        t,
      )!,
      badgeDecoration: BoxDecoration.lerp(
        badgeDecoration,
        other.badgeDecoration,
        t,
      )!,
      primaryButton: ButtonStyle.lerp(primaryButton, other.primaryButton, t)!,
      secondaryButton: ButtonStyle.lerp(
        secondaryButton,
        other.secondaryButton,
        t,
      )!,
      dangerButton: ButtonStyle.lerp(dangerButton, other.dangerButton, t)!,
      outlineButton: ButtonStyle.lerp(outlineButton, other.outlineButton, t)!,
      linkButton: ButtonStyle.lerp(linkButton, other.linkButton, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniStyles &&
          colors == other.colors &&
          textStyles == other.textStyles &&
          cardDecoration == other.cardDecoration &&
          elevatedCardDecoration == other.elevatedCardDecoration &&
          selectedCardDecoration == other.selectedCardDecoration &&
          subtleBoxDecoration == other.subtleBoxDecoration &&
          disabledBoxDecoration == other.disabledBoxDecoration &&
          errorBoxDecoration == other.errorBoxDecoration &&
          warningBoxDecoration == other.warningBoxDecoration &&
          successBoxDecoration == other.successBoxDecoration &&
          infoBoxDecoration == other.infoBoxDecoration;

  @override
  int get hashCode => Object.hash(
    colors,
    textStyles,
    cardDecoration,
    elevatedCardDecoration,
    selectedCardDecoration,
    subtleBoxDecoration,
    disabledBoxDecoration,
    errorBoxDecoration,
    warningBoxDecoration,
    successBoxDecoration,
    infoBoxDecoration,
  );
}

/// ডেভেলপারদের জন্য ১-লাইনের সমন্বিত থিম অ্যাক্সেস ফ্যাসাড (`final ui = context.ui`)।
///
/// আলাদা আলাদা `context.colors`, `context.textStyles`, `context.styles`,
/// `context.tokens` কল করার বদলে `ui.colors`, `ui.text`, `ui.styles`,
/// `ui.tokens`, `ui.isDark`, `ui.device` সব এক জায়গায় পান।
@immutable
class OmniUiTheme {
  /// [colors], [text], [styles], [tokens], [device], [brightness] দিয়ে [OmniUiTheme] তৈরি করে।
  const OmniUiTheme({
    required this.colors,
    required this.text,
    required this.styles,
    required this.tokens,
    required this.device,
    required this.brightness,
  });

  /// ৫৩টি পিওর সেমান্টিক কালার।
  final OmniColors colors;

  /// ১৫টি প্রি-ক্যাশড রেসপন্সিভ টেক্সট স্টাইল।
  final OmniTextStyles text;

  /// প্রি-ক্যাশড কার্ড, বক্স, বাটন ও ইনপুট স্টাইল।
  final OmniStyles styles;

  /// বর্তমান ডিভাইস টিয়ার অনুযায়ী স্পেসিং, রেডিয়াস ও ট্যাপ টার্গেট টোকেন।
  final OmniResponsiveTokens tokens;

  /// বর্তমান রেসপন্সিভ ডিভাইস টিয়ার।
  final OmniDeviceType device;

  /// বর্তমান ডার্ক/লাইট ব্রাইটনেস।
  final Brightness brightness;

  /// বর্তমানে ডার্ক মোড চলছে কি না।
  bool get isDark => brightness == Brightness.dark;

  /// সাধারণ মোবাইল স্ক্রিন কি না।
  bool get isMobile => device == OmniDeviceType.mobile;

  /// ট্যাবলেট স্ক্রিন কি না।
  bool get isTablet => device == OmniDeviceType.tablet;

  /// ডেস্কটপ বা বড় মনিটর স্ক্রিন কি না।
  bool get isDesktop =>
      device == OmniDeviceType.desktop || device == OmniDeviceType.largeDesktop;
}

/// যেকোনো `BuildContext` থেকে সহজে প্রি-ক্যাশড [OmniTextStyles], [OmniStyles]
/// ও [OmniUiTheme] পড়ার শর্টকাট (`context.textStyles`, `context.styles`, `context.ui`)।
extension OmniStylesContext on BuildContext {
  /// পিওর নামের রেসপন্সিভ টেক্সট স্টাইল (`display`, `heading`, `title`,
  /// `body`, `label`, `caption`, `link`, `error`, `warning`, `success`, `code`)।
  OmniTextStyles get textStyles {
    final theme = Theme.of(this);
    final ext = theme.extension<OmniTextStyles>();
    if (ext != null) return ext;
    return theme.brightness == Brightness.dark
        ? OmniTextStyles.darkDefault
        : OmniTextStyles.lightDefault;
  }

  /// প্রি-ক্যাশড বাটন, বক্স, কার্ড ও টেক্সট-ফিল্ড স্টাইল বান্ডিল (`dangerButton`,
  /// `secondaryButton`, `cardDecoration`, `warningBoxDecoration`, `searchDecoration`)।
  OmniStyles get styles {
    final theme = Theme.of(this);
    final ext = theme.extension<OmniStyles>();
    if (ext != null) return ext;
    return theme.brightness == Brightness.dark
        ? OmniStyles.darkDefault
        : OmniStyles.lightDefault;
  }

  /// ১ লাইনে কালার (`ui.colors`), টেক্সট (`ui.text`), স্টাইল (`ui.styles`),
  /// টোকেন (`ui.tokens`), ও `ui.isDark` পাওয়ার সহজ শর্টকাট।
  OmniUiTheme get ui {
    final theme = Theme.of(this);
    final isDark = theme.brightness == Brightness.dark;
    final c =
        theme.extension<OmniColors>() ??
        (isDark ? OmniColors.darkDefault : OmniColors.lightDefault);
    final ts =
        theme.extension<OmniTextStyles>() ??
        (isDark ? OmniTextStyles.darkDefault : OmniTextStyles.lightDefault);
    final s =
        theme.extension<OmniStyles>() ??
        (isDark ? OmniStyles.darkDefault : OmniStyles.lightDefault);
    final tokens = OmniResponsiveScope.tokensOf(this);
    final device = OmniResponsiveScope.deviceOf(this);
    return OmniUiTheme(
      colors: c,
      text: ts,
      styles: s,
      tokens: tokens,
      device: device,
      brightness: theme.brightness,
    );
  }
}
