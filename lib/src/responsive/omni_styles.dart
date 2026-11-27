import 'package:flutter/material.dart';

import 'omni_colors.dart';
import 'omni_responsive_config.dart';

/// পুরো অ্যাপের সব `TextField` / `TextFormField`-এর ডিফল্ট ইনপুট স্টাইল ধরন।
enum OmniInputVariant {
  /// হালকা রঙিন ব্যাকগ্রাউন্ড + চারপাশে সূক্ষ্ম বর্ডার (আধুনিক ডিফল্ট)।
  filled,

  /// স্বচ্ছ বা কার্ড-রঙিন ব্যাকগ্রাউন্ড + স্পষ্ট চারপাশের আউটলাইন বর্ডার।
  outlined,

  /// কেবল নিচে একটি পরিচ্ছন্ন লাইন বর্ডার (মিনিমাল ফর্মের জন্য)।
  underlined,
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

  /// আউটলাইন বর্ডারওয়ালা বাটন স্টাইল (`borderColor` + `primaryColor`)।
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
    InputBorder makeInputBorder(Color color, double width) =>
        switch (inputVariant) {
          OmniInputVariant.underlined => UnderlineInputBorder(
            borderSide: BorderSide(color: color, width: width),
          ),
          OmniInputVariant.filled || OmniInputVariant.outlined =>
            OutlineInputBorder(
              borderRadius: buttonRadius,
              borderSide: BorderSide(color: color, width: width),
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
      disabledBorder: makeInputBorder(colors.dividerColor, borderWidth),
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
      errorBoxDecoration: BoxDecoration(
        color: colors.errorBackgroundColor,
        borderRadius: cardRadius,
        border: Border.all(color: colors.errorColor, width: borderWidth),
      ),
      warningBoxDecoration: BoxDecoration(
        color: colors.warningBackgroundColor,
        borderRadius: cardRadius,
        border: Border.all(color: colors.warningColor, width: borderWidth),
      ),
      successBoxDecoration: BoxDecoration(
        color: colors.successBackgroundColor,
        borderRadius: cardRadius,
        border: Border.all(color: colors.successColor, width: borderWidth),
      ),
      infoBoxDecoration: BoxDecoration(
        color: colors.infoBackgroundColor,
        borderRadius: cardRadius,
        border: Border.all(color: colors.infoColor, width: borderWidth),
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
      outlineButton: OutlinedButton.styleFrom(
        foregroundColor: colors.primaryColor,
        disabledForegroundColor: colors.disabledTextColor,
        side: BorderSide(color: colors.borderColor, width: borderWidth),
        textStyle: textStyles.button,
        minimumSize: minSize,
        shape: buttonShape,
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
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    errorText: error,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
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
      inputDecorationTheme:
          t < 0.5 ? inputDecorationTheme : other.inputDecorationTheme,
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
    errorBoxDecoration,
    warningBoxDecoration,
    successBoxDecoration,
    infoBoxDecoration,
  );
}

/// যেকোনো `BuildContext` থেকে সহজে প্রি-ক্যাশড [OmniTextStyles] ও [OmniStyles]
/// পড়ার শর্টকাট (`context.textStyles`, `context.styles`)।
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
}
