import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'omni_styles.dart';

/// প্রতিটি প্রি-ডিফাইনড ইনপুট ফিল্ডের নিজস্ব আইডেন্টিটি (`OmniFieldIdentity`)।
///
/// সব ফিল্ড একই [OmniFieldTheme] ও [OmniTheme] শেয়ার করলেও, প্রতিটি আইডেন্টিটি
/// নিজস্ব আইকন, কিবোর্ড, অটো-ফিল, ভ্যালিডেশন ও পার-আইডেন্টিটি স্টাইল বজায় রাখে।
enum OmniFieldIdentity {
  /// ইমেইল ও জিমেইল ভেরিফিকেশন ইনপুট।
  email,

  /// পাসওয়ার্ড (শো/হাইড, স্ট্রেংথ ও কনফার্ম) ইনপুট।
  password,

  /// পূর্ণ নাম / ফার্স্ট-লাস্ট নেম / ইউজারনেম ইনপুট।
  name,

  /// মোবাইল নাম্বার, কান্ট্রি কোড ও ভেরিফিকেশন ইনপুট।
  phone,

  /// পূর্ণসংখ্যা, দশমিক বা কারেন্সি নাম্বার ইনপুট।
  number,

  /// মাল্টি-বক্স OTP / পিন ভেরিফিকেশন ইনপুট।
  otp,

  /// ডিবাউন্সড সার্চ ও ফিল্টার ইনপুট।
  search,

  /// মাল্টিলাইন বায়ো, ঠিকানা বা নোটস ইনপুট।
  multiline,

  /// ওয়েবসাইট / URL লিংক ইনপুট।
  url,

  /// সাধারণ কাস্টম টেক্সট ইনপুট।
  text;

  /// এই আইডেন্টিটির ডিফল্ট লেবেল।
  String get defaultLabel => switch (this) {
    OmniFieldIdentity.email => 'Email',
    OmniFieldIdentity.password => 'Password',
    OmniFieldIdentity.name => 'Full Name',
    OmniFieldIdentity.phone => 'Phone Number',
    OmniFieldIdentity.number => 'Number',
    OmniFieldIdentity.otp => 'Verification Code',
    OmniFieldIdentity.search => 'Search',
    OmniFieldIdentity.multiline => 'Notes',
    OmniFieldIdentity.url => 'Website URL',
    OmniFieldIdentity.text => 'Text',
  };

  /// এই আইডেন্টিটির ডিফল্ট প্লেসহোল্ডার।
  String get defaultHint => switch (this) {
    OmniFieldIdentity.email => 'name@gmail.com',
    OmniFieldIdentity.password => 'Enter password',
    OmniFieldIdentity.name => 'Enter your name',
    OmniFieldIdentity.phone => '01712-345678',
    OmniFieldIdentity.number => '0',
    OmniFieldIdentity.otp => '••••••',
    OmniFieldIdentity.search => 'Search...',
    OmniFieldIdentity.multiline => 'Write here...',
    OmniFieldIdentity.url => 'https://example.com',
    OmniFieldIdentity.text => 'Enter text',
  };

  /// এই আইডেন্টিটির ডিফল্ট প্রিফিক্স আইকন।
  IconData get defaultIcon => switch (this) {
    OmniFieldIdentity.email => Icons.mail_outline_rounded,
    OmniFieldIdentity.password => Icons.lock_outline_rounded,
    OmniFieldIdentity.name => Icons.person_outline_rounded,
    OmniFieldIdentity.phone => Icons.phone_android_rounded,
    OmniFieldIdentity.number => Icons.numbers_rounded,
    OmniFieldIdentity.otp => Icons.verified_user_outlined,
    OmniFieldIdentity.search => Icons.search_rounded,
    OmniFieldIdentity.multiline => Icons.notes_rounded,
    OmniFieldIdentity.url => Icons.link_rounded,
    OmniFieldIdentity.text => Icons.text_fields_rounded,
  };
}

/// প্রি-ডিফাইনড ফিল্ডগুলোর লেবেল কীভাবে দেখানো হবে।
enum OmniFieldLabelMode {
  /// ফিল্ডের ভেতরে/বর্ডারে Material ফ্লোটিং লেবেল দেখায়।
  floating,

  /// ইনপুট বক্সের ওপরে আলাদা লেবেল টাইটেল দেখায়।
  above,

  /// কোনো লেবেল টেক্সট না দেখিয়ে শুধু হিন্ট ব্যবহার করে।
  none,
}

/// OTP ভেরিফিকেশন বক্সগুলোর ভিজ্যুয়াল ধরন।
enum OmniOtpBoxStyle {
  /// চারদিকে রাউন্ডেড বর্ডারযুক্ত বক্স।
  outlined,

  /// সফট ব্যাকগ্রাউন্ড ফিল্ড বক্স।
  filled,

  /// শুধু নিচে ড্যাশ/আন্ডারলাইন স্টাইল।
  underlined,
}

/// Pinput-স্টাইলে OTP ঘরের ভেতরের অক্ষর প্রবেশের অ্যানিমেশন ধরন।
enum OmniOtpAnimationType {
  /// স্কেল হয়ে সুন্দরভাবে ফুটে ওঠে (ডিফল্ট)।
  scale,

  /// মসৃণ আলফা ফেডে দেখা যায়।
  fade,

  /// নিচ থেকে ওপর দিকে স্লাইড হয়ে আসে।
  slide,

  /// হালকা রোটেট-স্কেল অ্যানিমেশনে আসে।
  rotation,

  /// অ্যানিমেশন ছাড়া তাৎক্ষণিক দেখায়।
  none,
}

/// `pinput` প্যাকেজের মতো প্রতিটি OTP / PIN ঘরের আলাদা ডিজাইন ও বর্ডার কনফিগারেশন।
///
/// [OmniOtpField]-এ `defaultPinTheme`, `focusedPinTheme`, `submittedPinTheme`,
/// `followingPinTheme`, `errorPinTheme`, `disabledPinTheme`-এ ব্যবহার করা যায়।
@immutable
class OmniPinTheme {
  /// প্রতিটি OTP ঘরের [width], [height], [decoration], [textStyle] নির্ধারণ করে।
  const OmniPinTheme({
    this.width,
    this.height,
    this.margin,
    this.padding,
    this.textStyle,
    this.decoration,
    this.constraints,
  });

  /// ঘরের প্রস্থ (অটো রেসপনসিভ ফিট হলে সর্বোচ্চ প্রস্থ হিসেবে ব্যবহৃত হয়)।
  final double? width;

  /// ঘরের উচ্চতা।
  final double? height;

  /// ঘরের বাইরের মার্জিন।
  final EdgeInsetsGeometry? margin;

  /// ঘরের ভেতরের প্যাডিং।
  final EdgeInsetsGeometry? padding;

  /// ঘরের ভেতরের অক্ষরের `TextStyle`।
  final TextStyle? textStyle;

  /// ঘরের ব্যাকগ্রাউন্ড, বর্ডার ও শ্যাডো ডেকোরেশন।
  final BoxDecoration? decoration;

  /// ঐচ্ছিক `BoxConstraints`।
  final BoxConstraints? constraints;

  /// নির্বাচিত প্রপার্টি বদলে নতুন [OmniPinTheme] কপি তৈরি করে।
  OmniPinTheme copyWith({
    double? width,
    double? height,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    TextStyle? textStyle,
    BoxDecoration? decoration,
    BoxConstraints? constraints,
  }) => OmniPinTheme(
    width: width ?? this.width,
    height: height ?? this.height,
    margin: margin ?? this.margin,
    padding: padding ?? this.padding,
    textStyle: textStyle ?? this.textStyle,
    decoration: decoration ?? this.decoration,
    constraints: constraints ?? this.constraints,
  );

  /// শুধু [BoxDecoration] প্রপার্টিগুলো সহজে বদলে নতুন [OmniPinTheme] তৈরি করে।
  OmniPinTheme copyDecorationWith({
    Color? color,
    DecorationImage? image,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BlendMode? backgroundBlendMode,
    BoxShape? shape,
  }) => copyWith(
    decoration: (decoration ?? const BoxDecoration()).copyWith(
      color: color,
      image: image,
      border: border,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      gradient: gradient,
      backgroundBlendMode: backgroundBlendMode,
      shape: shape,
    ),
  );

  /// শুধু বর্ডার বদলে নতুন [OmniPinTheme] তৈরি করে (`pinput.copyBorderWith` সমতুল্য)।
  OmniPinTheme copyBorderWith({required BoxBorder border}) =>
      copyDecorationWith(border: border);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniPinTheme &&
          width == other.width &&
          height == other.height &&
          margin == other.margin &&
          padding == other.padding &&
          textStyle == other.textStyle &&
          decoration == other.decoration &&
          constraints == other.constraints;

  @override
  int get hashCode => Object.hash(
    width,
    height,
    margin,
    padding,
    textStyle,
    decoration,
    constraints,
  );
}

/// যেকোনো একটি ফিল্ড বা নির্দিষ্ট [OmniFieldIdentity]-এর জন্য আলাদা ভিজ্যুয়াল
/// ওভাররাইড (`accentColor`, `fillColor`, `borderRadius`, `variant` ইত্যাদি)।
@immutable
class OmniFieldStyle {
  /// একটি ফিল্ড আইডেন্টিটির জন্য কাস্টম স্টাইল ওভাররাইড তৈরি করে।
  const OmniFieldStyle({
    this.variant,
    this.borderRadius,
    this.borderWidth,
    this.focusedBorderWidth,
    this.fillColor,
    this.darkFillColor,
    this.borderColor,
    this.darkBorderColor,
    this.focusedBorderColor,
    this.darkFocusedBorderColor,
    this.errorBorderColor,
    this.successBorderColor,
    this.accentColor,
    this.darkAccentColor,
    this.prefixIconColor,
    this.suffixIconColor,
    this.textStyle,
    this.labelStyle,
    this.hintStyle,
    this.contentPadding,
    this.isDense,
    this.showClearButton,
    this.prefixIcon,
    this.suffixIcon,
    this.showPrefixIcon,
    this.clearIcon,
  });

  /// এই ফিল্ডের নিজস্ব ইনপুট ধরন (`.filled`, `.outlined`, `.underlined`)।
  final OmniInputVariant? variant;

  /// এই ফিল্ডের কর্নার রেডিয়াস।
  final double? borderRadius;

  /// সাধারণ অবস্থায় বর্ডার পুরুত্ব।
  final double? borderWidth;

  /// ফোকাস অবস্থায় বর্ডার পুরুত্ব।
  final double? focusedBorderWidth;

  /// লাইট মোডে ব্যাকগ্রাউন্ড ফিল কালার।
  final Color? fillColor;

  /// ডার্ক মোডে ব্যাকগ্রাউন্ড ফিল কালার।
  final Color? darkFillColor;

  /// লাইট মোডে বর্ডার কালার।
  final Color? borderColor;

  /// ডার্ক মোডে বর্ডার কালার।
  final Color? darkBorderColor;

  /// লাইট মোডে ফোকাস বর্ডার কালার।
  final Color? focusedBorderColor;

  /// ডার্ক মোডে ফোকাস বর্ডার কালার।
  final Color? darkFocusedBorderColor;

  /// এরর অবস্থায় বর্ডার ও বার্তা কালার।
  final Color? errorBorderColor;

  /// ভ্যালিড/ভেরিফায়েড অবস্থায় বর্ডার ও ব্যাজ কালার।
  final Color? successBorderColor;

  /// লাইট মোডে ফিল্ডের নিজস্ব আইডেন্টিটি অ্যাকসেন্ট কালার।
  final Color? accentColor;

  /// ডার্ক মোডে ফিল্ডের নিজস্ব আইডেন্টিটি অ্যাকসেন্ট কালার।
  final Color? darkAccentColor;

  /// প্রিফিক্স আইকনের কালার।
  final Color? prefixIconColor;

  /// সাফিক্স আইকনের কালার।
  final Color? suffixIconColor;

  /// ইনপুট টেক্সটের কাস্টম স্টাইল।
  final TextStyle? textStyle;

  /// লেবেল টেক্সটের কাস্টম স্টাইল।
  final TextStyle? labelStyle;

  /// হিন্ট টেক্সটের কাস্টম স্টাইল।
  final TextStyle? hintStyle;

  /// ইনপুট বক্সের ভেতরের প্যাডিং।
  final EdgeInsetsGeometry? contentPadding;

  /// কম্প্যাক্ট উচ্চতা ব্যবহার করবে কি না।
  final bool? isDense;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool? showClearButton;

  /// এই আইডেন্টিটির জন্য কাস্টম প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// এই আইডেন্টিটির জন্য অতিরিক্ত কাস্টম সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// প্রিফিক্স আইকন দেখাবে কি না (`false` দিলে আইকন ছাড়াই ক্লিন ইনপুট)।
  final bool? showPrefixIcon;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

  /// অপর প্রপার্টিগুলো অপরিবর্তিত রেখে নতুন কপি তৈরি করে।
  OmniFieldStyle copyWith({
    OmniInputVariant? variant,
    double? borderRadius,
    double? borderWidth,
    double? focusedBorderWidth,
    Color? fillColor,
    Color? darkFillColor,
    Color? borderColor,
    Color? darkBorderColor,
    Color? focusedBorderColor,
    Color? darkFocusedBorderColor,
    Color? errorBorderColor,
    Color? successBorderColor,
    Color? accentColor,
    Color? darkAccentColor,
    Color? prefixIconColor,
    Color? suffixIconColor,
    TextStyle? textStyle,
    TextStyle? labelStyle,
    TextStyle? hintStyle,
    EdgeInsetsGeometry? contentPadding,
    bool? isDense,
    bool? showClearButton,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool? showPrefixIcon,
    IconData? clearIcon,
  }) => OmniFieldStyle(
    variant: variant ?? this.variant,
    borderRadius: borderRadius ?? this.borderRadius,
    borderWidth: borderWidth ?? this.borderWidth,
    focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
    fillColor: fillColor ?? this.fillColor,
    darkFillColor: darkFillColor ?? this.darkFillColor,
    borderColor: borderColor ?? this.borderColor,
    darkBorderColor: darkBorderColor ?? this.darkBorderColor,
    focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
    darkFocusedBorderColor:
        darkFocusedBorderColor ?? this.darkFocusedBorderColor,
    errorBorderColor: errorBorderColor ?? this.errorBorderColor,
    successBorderColor: successBorderColor ?? this.successBorderColor,
    accentColor: accentColor ?? this.accentColor,
    darkAccentColor: darkAccentColor ?? this.darkAccentColor,
    prefixIconColor: prefixIconColor ?? this.prefixIconColor,
    suffixIconColor: suffixIconColor ?? this.suffixIconColor,
    textStyle: textStyle ?? this.textStyle,
    labelStyle: labelStyle ?? this.labelStyle,
    hintStyle: hintStyle ?? this.hintStyle,
    contentPadding: contentPadding ?? this.contentPadding,
    isDense: isDense ?? this.isDense,
    showClearButton: showClearButton ?? this.showClearButton,
    prefixIcon: prefixIcon ?? this.prefixIcon,
    suffixIcon: suffixIcon ?? this.suffixIcon,
    showPrefixIcon: showPrefixIcon ?? this.showPrefixIcon,
    clearIcon: clearIcon ?? this.clearIcon,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniFieldStyle &&
          variant == other.variant &&
          borderRadius == other.borderRadius &&
          borderWidth == other.borderWidth &&
          focusedBorderWidth == other.focusedBorderWidth &&
          fillColor == other.fillColor &&
          darkFillColor == other.darkFillColor &&
          borderColor == other.borderColor &&
          darkBorderColor == other.darkBorderColor &&
          focusedBorderColor == other.focusedBorderColor &&
          darkFocusedBorderColor == other.darkFocusedBorderColor &&
          errorBorderColor == other.errorBorderColor &&
          successBorderColor == other.successBorderColor &&
          accentColor == other.accentColor &&
          darkAccentColor == other.darkAccentColor &&
          prefixIconColor == other.prefixIconColor &&
          suffixIconColor == other.suffixIconColor &&
          textStyle == other.textStyle &&
          labelStyle == other.labelStyle &&
          hintStyle == other.hintStyle &&
          contentPadding == other.contentPadding &&
          isDense == other.isDense &&
          showClearButton == other.showClearButton &&
          prefixIcon == other.prefixIcon &&
          suffixIcon == other.suffixIcon &&
          showPrefixIcon == other.showPrefixIcon &&
          clearIcon == other.clearIcon;

  @override
  int get hashCode => Object.hashAll([
    variant,
    borderRadius,
    borderWidth,
    focusedBorderWidth,
    fillColor,
    darkFillColor,
    borderColor,
    darkBorderColor,
    focusedBorderColor,
    darkFocusedBorderColor,
    errorBorderColor,
    successBorderColor,
    accentColor,
    darkAccentColor,
    prefixIconColor,
    suffixIconColor,
    textStyle,
    labelStyle,
    hintStyle,
    contentPadding,
    isDense,
    showClearButton,
    prefixIcon,
    suffixIcon,
    showPrefixIcon,
    clearIcon,
  ]);
}

/// পুরো অ্যাপ বা ফর্মের **একটি সমন্বিত থিম** যা `OmniEmailField`, `OmniPasswordField`,
/// `OmniNameField`, `OmniOtpField`, `OmniPhoneField`, `OmniNumberField`-সহ সব ফিল্ডে
/// স্বয়ংক্রিয়ভাবে প্রযোজ্য হয় — এবং [identityStyles] দিয়ে প্রতিটি ফিল্ডের আলাদা
/// আইডেন্টিটি ও অ্যাকসেন্ট রঙও ধরে রাখে।
@immutable
class OmniFieldTheme extends ThemeExtension<OmniFieldTheme> {
  /// সব প্রি-ডিফাইনড ফিল্ডের জন্য একটি শেয়ার্ড থিম তৈরি করে।
  const OmniFieldTheme({
    this.variant,
    this.labelMode = OmniFieldLabelMode.floating,
    this.labelSpacing = 6.0,
    this.borderRadius,
    this.borderWidth,
    this.focusedBorderWidth,
    this.fillColor,
    this.darkFillColor,
    this.borderColor,
    this.darkBorderColor,
    this.focusedBorderColor,
    this.darkFocusedBorderColor,
    this.errorColor,
    this.successColor,
    this.labelColor,
    this.darkLabelColor,
    this.hintColor,
    this.darkHintColor,
    this.iconColor,
    this.darkIconColor,
    this.contentPadding,
    this.isDense = false,
    this.showClearButton = false,
    this.showValidationIcons = true,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.otpBoxStyle = OmniOtpBoxStyle.outlined,
    this.otpBoxWidth = 46.0,
    this.otpBoxHeight = 54.0,
    this.otpBoxSpacing = 10.0,
    this.identityStyles = const <OmniFieldIdentity, OmniFieldStyle>{},
  });

  /// সব ফিল্ডের ডিফল্ট ভ্যারিয়েন্ট (`null` হলে `OmniThemeStyle` অনুযায়ী)।
  final OmniInputVariant? variant;

  /// সব ফিল্ডের লেবেল অবস্থান (`floating`, `above`, `none`)।
  final OmniFieldLabelMode labelMode;

  /// `labelMode == .above` হলে লেবেল ও ইনপুট বক্সের মাঝের ফাঁকা।
  final double labelSpacing;

  /// সব ফিল্ডের ডিফল্ট কর্নার রেডিয়াস।
  final double? borderRadius;

  /// সাধারণ অবস্থায় বর্ডার পুরুত্ব।
  final double? borderWidth;

  /// ফোকাস ও এরর অবস্থায় বর্ডার পুরুত্ব।
  final double? focusedBorderWidth;

  /// লাইট মোডে ইনপুট ব্যাকগ্রাউন্ড কালার।
  final Color? fillColor;

  /// ডার্ক মোডে ইনপুট ব্যাকগ্রাউন্ড কালার।
  final Color? darkFillColor;

  /// লাইট মোডে বর্ডার কালার।
  final Color? borderColor;

  /// ডার্ক মোডে বর্ডার কালার।
  final Color? darkBorderColor;

  /// লাইট মোডে ফোকাসড বর্ডার কালার।
  final Color? focusedBorderColor;

  /// ডার্ক মোডে ফোকাসড বর্ডার কালার।
  final Color? darkFocusedBorderColor;

  /// এরর ও ভ্যালিডেশন ব্যাজ কালার।
  final Color? errorColor;

  /// ভ্যালিড / ভেরিফায়েড অবস্থা কালার।
  final Color? successColor;

  /// লাইট মোডে লেবেল টেক্সট কালার।
  final Color? labelColor;

  /// ডার্ক মোডে লেবেল টেক্সট কালার।
  final Color? darkLabelColor;

  /// লাইট মোডে হিন্ট টেক্সট কালার।
  final Color? hintColor;

  /// ডার্ক মোডে হিন্ট টেক্সট কালার।
  final Color? darkHintColor;

  /// লাইট মোডে আইকন কালার।
  final Color? iconColor;

  /// ডার্ক মোডে আইকন কালার।
  final Color? darkIconColor;

  /// সব ফিল্ডের কমন `contentPadding`।
  final EdgeInsetsGeometry? contentPadding;

  /// কম্প্যাক্ট ইনপুট উচ্চতা ব্যবহার করবে কি না।
  final bool isDense;

  /// ক্লিয়ার বাটন ডিফল্ট চালু থাকবে কি না।
  final bool showClearButton;

  /// ভ্যালিড/ভেরিফায়েড ব্যাজ দেখাবে কি না।
  final bool showValidationIcons;

  /// সব ফিল্ডের ডিফল্ট `AutovalidateMode`।
  final AutovalidateMode autovalidateMode;

  /// `OmniOtpField`-এর ডিফল্ট বক্স স্টাইল।
  final OmniOtpBoxStyle otpBoxStyle;

  /// `OmniOtpField`-এর প্রতিটি বক্সের প্রস্থ।
  final double otpBoxWidth;

  /// `OmniOtpField`-এর প্রতিটি বক্সের উচ্চতা।
  final double otpBoxHeight;

  /// `OmniOtpField`-এর বক্সগুলোর মাঝের ফাঁকা।
  final double otpBoxSpacing;

  /// প্রতিটি ফিল্ড আইডেন্টিটির (`email`, `password`, `phone` ইত্যাদি) জন্য আলাদা স্টাইল।
  final Map<OmniFieldIdentity, OmniFieldStyle> identityStyles;

  /// বর্তমান [BuildContext] থেকে কার্যকর [OmniFieldTheme] খুঁজে দেয়।
  ///
  /// প্রায়োরিটি: `OmniFieldThemeScope` > `Theme.of(context).extension<OmniFieldTheme>()` > ডিফল্ট `OmniFieldTheme()`।
  static OmniFieldTheme of(BuildContext context) {
    final scoped = OmniFieldThemeScope.maybeOf(context);
    if (scoped != null) return scoped;
    return Theme.of(context).extension<OmniFieldTheme>() ??
        const OmniFieldTheme();
  }

  /// নির্বাচিত প্রপার্টি বদলে নতুন [OmniFieldTheme] তৈরি করে।
  @override
  OmniFieldTheme copyWith({
    OmniInputVariant? variant,
    OmniFieldLabelMode? labelMode,
    double? labelSpacing,
    double? borderRadius,
    double? borderWidth,
    double? focusedBorderWidth,
    Color? fillColor,
    Color? darkFillColor,
    Color? borderColor,
    Color? darkBorderColor,
    Color? focusedBorderColor,
    Color? darkFocusedBorderColor,
    Color? errorColor,
    Color? successColor,
    Color? labelColor,
    Color? darkLabelColor,
    Color? hintColor,
    Color? darkHintColor,
    Color? iconColor,
    Color? darkIconColor,
    EdgeInsetsGeometry? contentPadding,
    bool? isDense,
    bool? showClearButton,
    bool? showValidationIcons,
    AutovalidateMode? autovalidateMode,
    OmniOtpBoxStyle? otpBoxStyle,
    double? otpBoxWidth,
    double? otpBoxHeight,
    double? otpBoxSpacing,
    Map<OmniFieldIdentity, OmniFieldStyle>? identityStyles,
  }) => OmniFieldTheme(
    variant: variant ?? this.variant,
    labelMode: labelMode ?? this.labelMode,
    labelSpacing: labelSpacing ?? this.labelSpacing,
    borderRadius: borderRadius ?? this.borderRadius,
    borderWidth: borderWidth ?? this.borderWidth,
    focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
    fillColor: fillColor ?? this.fillColor,
    darkFillColor: darkFillColor ?? this.darkFillColor,
    borderColor: borderColor ?? this.borderColor,
    darkBorderColor: darkBorderColor ?? this.darkBorderColor,
    focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
    darkFocusedBorderColor:
        darkFocusedBorderColor ?? this.darkFocusedBorderColor,
    errorColor: errorColor ?? this.errorColor,
    successColor: successColor ?? this.successColor,
    labelColor: labelColor ?? this.labelColor,
    darkLabelColor: darkLabelColor ?? this.darkLabelColor,
    hintColor: hintColor ?? this.hintColor,
    darkHintColor: darkHintColor ?? this.darkHintColor,
    iconColor: iconColor ?? this.iconColor,
    darkIconColor: darkIconColor ?? this.darkIconColor,
    contentPadding: contentPadding ?? this.contentPadding,
    isDense: isDense ?? this.isDense,
    showClearButton: showClearButton ?? this.showClearButton,
    showValidationIcons: showValidationIcons ?? this.showValidationIcons,
    autovalidateMode: autovalidateMode ?? this.autovalidateMode,
    otpBoxStyle: otpBoxStyle ?? this.otpBoxStyle,
    otpBoxWidth: otpBoxWidth ?? this.otpBoxWidth,
    otpBoxHeight: otpBoxHeight ?? this.otpBoxHeight,
    otpBoxSpacing: otpBoxSpacing ?? this.otpBoxSpacing,
    identityStyles: identityStyles ?? this.identityStyles,
  );

  @override
  OmniFieldTheme lerp(covariant ThemeExtension<OmniFieldTheme>? other, double t) {
    if (other is! OmniFieldTheme) return this;
    return OmniFieldTheme(
      variant: t < 0.5 ? variant : other.variant,
      labelMode: t < 0.5 ? labelMode : other.labelMode,
      labelSpacing: labelSpacing + (other.labelSpacing - labelSpacing) * t,
      borderRadius: t < 0.5 ? borderRadius : other.borderRadius,
      borderWidth: t < 0.5 ? borderWidth : other.borderWidth,
      focusedBorderWidth:
          t < 0.5 ? focusedBorderWidth : other.focusedBorderWidth,
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      darkFillColor: Color.lerp(darkFillColor, other.darkFillColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      darkBorderColor: Color.lerp(darkBorderColor, other.darkBorderColor, t),
      focusedBorderColor:
          Color.lerp(focusedBorderColor, other.focusedBorderColor, t),
      darkFocusedBorderColor:
          Color.lerp(darkFocusedBorderColor, other.darkFocusedBorderColor, t),
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      successColor: Color.lerp(successColor, other.successColor, t),
      labelColor: Color.lerp(labelColor, other.labelColor, t),
      darkLabelColor: Color.lerp(darkLabelColor, other.darkLabelColor, t),
      hintColor: Color.lerp(hintColor, other.hintColor, t),
      darkHintColor: Color.lerp(darkHintColor, other.darkHintColor, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      darkIconColor: Color.lerp(darkIconColor, other.darkIconColor, t),
      contentPadding: EdgeInsetsGeometry.lerp(
        contentPadding,
        other.contentPadding,
        t,
      ),
      isDense: t < 0.5 ? isDense : other.isDense,
      showClearButton: t < 0.5 ? showClearButton : other.showClearButton,
      showValidationIcons:
          t < 0.5 ? showValidationIcons : other.showValidationIcons,
      autovalidateMode: t < 0.5 ? autovalidateMode : other.autovalidateMode,
      otpBoxStyle: t < 0.5 ? otpBoxStyle : other.otpBoxStyle,
      otpBoxWidth: otpBoxWidth + (other.otpBoxWidth - otpBoxWidth) * t,
      otpBoxHeight: otpBoxHeight + (other.otpBoxHeight - otpBoxHeight) * t,
      otpBoxSpacing: otpBoxSpacing + (other.otpBoxSpacing - otpBoxSpacing) * t,
      identityStyles: t < 0.5 ? identityStyles : other.identityStyles,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OmniFieldTheme) return false;
    if (variant != other.variant ||
        labelMode != other.labelMode ||
        labelSpacing != other.labelSpacing ||
        borderRadius != other.borderRadius ||
        borderWidth != other.borderWidth ||
        focusedBorderWidth != other.focusedBorderWidth ||
        fillColor != other.fillColor ||
        darkFillColor != other.darkFillColor ||
        borderColor != other.borderColor ||
        darkBorderColor != other.darkBorderColor ||
        focusedBorderColor != other.focusedBorderColor ||
        darkFocusedBorderColor != other.darkFocusedBorderColor ||
        errorColor != other.errorColor ||
        successColor != other.successColor ||
        labelColor != other.labelColor ||
        darkLabelColor != other.darkLabelColor ||
        hintColor != other.hintColor ||
        darkHintColor != other.darkHintColor ||
        iconColor != other.iconColor ||
        darkIconColor != other.darkIconColor ||
        contentPadding != other.contentPadding ||
        isDense != other.isDense ||
        showClearButton != other.showClearButton ||
        showValidationIcons != other.showValidationIcons ||
        autovalidateMode != other.autovalidateMode ||
        otpBoxStyle != other.otpBoxStyle ||
        otpBoxWidth != other.otpBoxWidth ||
        otpBoxHeight != other.otpBoxHeight ||
        otpBoxSpacing != other.otpBoxSpacing ||
        identityStyles.length != other.identityStyles.length) {
      return false;
    }
    for (final entry in identityStyles.entries) {
      if (other.identityStyles[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    variant,
    labelMode,
    labelSpacing,
    borderRadius,
    borderWidth,
    focusedBorderWidth,
    fillColor,
    darkFillColor,
    borderColor,
    darkBorderColor,
    focusedBorderColor,
    darkFocusedBorderColor,
    errorColor,
    successColor,
    labelColor,
    darkLabelColor,
    hintColor,
    darkHintColor,
    iconColor,
    darkIconColor,
    contentPadding,
    isDense,
    showClearButton,
    showValidationIcons,
    autovalidateMode,
    otpBoxStyle,
    otpBoxWidth,
    otpBoxHeight,
    otpBoxSpacing,
    Object.hashAllUnordered(
      identityStyles.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  ]);
}

/// নির্দিষ্ট ফর্ম বা স্ক্রিন সাব-ট্রি-তে সব প্রি-ডিফাইনড ফিল্ডের জন্য একটি
/// কমন [OmniFieldTheme] প্রয়োগ করার `InheritedWidget`।
class OmniFieldThemeScope extends InheritedWidget {
  /// [theme] সব চাইল্ড `Omni*Field` উইজেটে সরবরাহ করে।
  const OmniFieldThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  /// এই সাব-ট্রি-তে ব্যবহৃত শেয়ার্ড ফিল্ড থিম।
  final OmniFieldTheme theme;

  /// নিকটতম [OmniFieldThemeScope]-এর থিম রিটার্ন করে (না থাকলে `null`)।
  static OmniFieldTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniFieldThemeScope>()?.theme;

  @override
  bool updateShouldNotify(covariant OmniFieldThemeScope oldWidget) =>
      oldWidget.theme != theme;
}

/// প্রি-ডিফাইনড ফিল্ডগুলোর কমন স্ট্যান্ড-অ্যালোন ভ্যালিডেশন ও পার্সিং ইউটিলিটি।
abstract final class OmniValidators {
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static final RegExp _gmailDomainRegex = RegExp(
    r'@(gmail|googlemail)\.com$',
    caseSensitive: false,
  );

  static final RegExp _bdPhoneRegex = RegExp(r'^(?:\+?880|0)?(1[3-9]\d{8})$');
  static final RegExp _urlRegex = RegExp(
    r'^(https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/.*)?$',
    caseSensitive: false,
  );

  /// সাধারণ ইমেইল অথবা কেবল Gmail (`gmailOnly: true`) যাচাই করে।
  static String? email(
    String? value, {
    bool required = true,
    bool gmailOnly = false,
    List<String>? allowedDomains,
    String requiredMessage = 'Please enter an email address',
    String invalidEmailMessage = 'Please enter a valid email address',
    String invalidGmailMessage = 'Please enter a valid Gmail address (@gmail.com)',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? requiredMessage : null;
    if (!_emailRegex.hasMatch(trimmed)) return invalidEmailMessage;

    if (gmailOnly && !_gmailDomainRegex.hasMatch(trimmed)) {
      return invalidGmailMessage;
    }
    if (allowedDomains != null && allowedDomains.isNotEmpty) {
      final atIdx = trimmed.lastIndexOf('@');
      final domain = atIdx >= 0 ? trimmed.substring(atIdx + 1).toLowerCase() : '';
      final matched = allowedDomains.any(
        (d) => d.trim().toLowerCase().replaceFirst('@', '') == domain,
      );
      if (!matched) {
        return 'Allowed email domain: ${allowedDomains.join(', ')}';
      }
    }
    return null;
  }

  /// সাধারণ বা কেবল `@gmail.com` ঠিকানা যাচাইয়ের সংক্ষিপ্ত হেল্পার।
  static String? gmail(
    String? value, {
    bool required = true,
    String requiredMessage = 'Please enter your Gmail address',
    String invalidGmailMessage = 'Please enter a valid @gmail.com address',
  }) => email(
    value,
    required: required,
    gmailOnly: true,
    requiredMessage: requiredMessage,
    invalidEmailMessage: invalidGmailMessage,
    invalidGmailMessage: invalidGmailMessage,
  );

  /// পাসওয়ার্ডের দৈর্ঘ্য, ক্যারেক্টার নিয়ম ও স্ট্রেংথ যাচাই করে।
  static String? password(
    String? value, {
    bool required = true,
    int minLength = 6,
    bool requireUppercase = false,
    bool requireLowercase = false,
    bool requireDigit = false,
    bool requireSpecialChar = false,
    String requiredMessage = 'Please enter a password',
  }) {
    final raw = value ?? '';
    if (raw.isEmpty) return required ? requiredMessage : null;
    if (raw.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (requireUppercase && !RegExp(r'[A-Z]').hasMatch(raw)) {
      return 'Include at least 1 uppercase letter';
    }
    if (requireLowercase && !RegExp(r'[a-z]').hasMatch(raw)) {
      return 'Include at least 1 lowercase letter';
    }
    if (requireDigit && !RegExp(r'\d').hasMatch(raw)) {
      return 'Include at least 1 number';
    }
    if (requireSpecialChar && !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(raw)) {
      return 'Include at least 1 special character';
    }
    return null;
  }

  /// পাসওয়ার্ড স্ট্রেংথ (`0` দুর্বল থেকে `4` খুব শক্তিশালী) হিসাব করে।
  static int passwordStrengthScore(String password, {int minLength = 8}) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= minLength) score++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^a-zA-Z0-9\s]').hasMatch(password)) score++;
    return score.clamp(1, 4);
  }

  /// নাম বা ইউজারনেম যাচাই করে।
  static String? name(
    String? value, {
    bool required = true,
    int minLength = 2,
    int? maxLength,
    bool allowDigits = false,
    bool allowSpaces = true,
    String requiredMessage = 'Please enter a name',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? requiredMessage : null;
    if (!allowSpaces && trimmed.contains(' ')) {
      return 'Spaces are not allowed';
    }
    if (trimmed.length < minLength) {
      return 'Must be at least $minLength characters';
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return 'Must be at most $maxLength characters';
    }
    if (!allowDigits && RegExp(r'\d').hasMatch(trimmed)) {
      return 'Numbers are not allowed in name';
    }
    return null;
  }

  /// মোবাইল নাম্বার (বাংলাদেশ `+880` এবং আন্তর্জাতিক E.164 ফরম্যাটসহ) যাচাই করে।
  static String? phone(
    String? value, {
    String countryCode = '+880',
    bool required = true,
    bool validateBangladeshOperators = true,
    int? minDigits,
    int? maxDigits,
    String requiredMessage = 'Please enter a phone number',
    String invalidMessage = 'Please enter a valid mobile number',
  }) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return required ? requiredMessage : null;

    if (countryCode == '+880') {
      if (validateBangladeshOperators) {
        if (!_bdPhoneRegex.hasMatch(digits)) return invalidMessage;
      } else {
        final clean = digits.replaceFirst(RegExp(r'^\+?880'), '');
        final len = clean.startsWith('0') ? clean.length : clean.length + 1;
        if (len != 11) return invalidMessage;
      }
      return null;
    }

    final numericOnly = digits.replaceAll('+', '');
    final effMin = minDigits ?? 7;
    final effMax = maxDigits ?? 15;
    if (numericOnly.length < effMin || numericOnly.length > effMax) {
      return invalidMessage;
    }
    return null;
  }

  /// কান্ট্রি কোডসহ E.164 ফরম্যাট (`+8801712345678`) তৈরি করে।
  static String normalizePhone(String rawInput, {String countryCode = '+880'}) {
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (countryCode == '+880') {
      final m = _bdPhoneRegex.firstMatch(digits);
      if (m != null) return '+880${m.group(1)}';
      if (digits.startsWith('880')) return '+$digits';
      if (digits.startsWith('0')) return '+880${digits.substring(1)}';
      return '+880$digits';
    }
    return '$countryCode$digits';
  }

  /// ওটিপি কোডের দৈর্ঘ্য যাচাই করে।
  static String? otp(
    String? value, {
    int length = 6,
    bool digitsOnly = true,
    String? incompleteMessage,
  }) {
    final clean = (value ?? '').trim();
    if (clean.length < length) {
      return incompleteMessage ?? 'Enter the $length-digit verification code';
    }
    if (digitsOnly && !RegExp(r'^\d+$').hasMatch(clean)) {
      return 'Verification code must contain only digits';
    }
    return null;
  }

  /// সংখ্যা ও `min` / `max` সীমা যাচাই করে।
  static String? number(
    String? value, {
    bool required = true,
    bool allowDecimal = false,
    bool allowNegative = false,
    num? min,
    num? max,
    String requiredMessage = 'Please enter a number',
    String invalidMessage = 'Please enter a valid number',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? requiredMessage : null;
    final parsed = allowDecimal
        ? double.tryParse(trimmed)
        : int.tryParse(trimmed);
    if (parsed == null) return invalidMessage;
    if (!allowNegative && parsed < 0) return 'Negative values are not allowed';
    if (min != null && parsed < min) return 'Minimum value is $min';
    if (max != null && parsed > max) return 'Maximum value is $max';
    return null;
  }

  /// ওয়েবসাইট URL ফরম্যাট যাচাই করে।
  static String? url(
    String? value, {
    bool required = true,
    String requiredMessage = 'Please enter a URL',
    String invalidMessage = 'Please enter a valid URL (e.g. https://site.com)',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? requiredMessage : null;
    if (!_urlRegex.hasMatch(trimmed)) return invalidMessage;
    return null;
  }
}

/// মোবাইল কান্ট্রি ডায়াল কোড মডেল ([OmniPhoneField])-এর জন্য।
@immutable
class OmniCountryDialCode {
  /// কান্ট্রি কোড তৈরি করে।
  const OmniCountryDialCode({
    required this.dialCode,
    required this.isoCode,
    required this.name,
    this.flag = '',
    this.minDigits = 7,
    this.maxDigits = 15,
    this.exampleHint = '123456789',
  });

  /// ডায়াল কোড যেমন `'+880'`, `'+1'`।
  final String dialCode;

  /// দেশের সংক্ষিপ্ত ISO কোড যেমন `'BD'`, `'US'`।
  final String isoCode;

  /// দেশের পূর্ণ নাম।
  final String name;

  /// ঐচ্ছিক ইমোজি পতাকা।
  final String flag;

  /// ন্যূনতম লোকাল ডিজিট সংখ্যা।
  final int minDigits;

  /// সর্বোচ্চ লোকাল ডিজিট সংখ্যা।
  final int maxDigits;

  /// উদাহরণ প্লেসহোল্ডার।
  final String exampleHint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniCountryDialCode &&
          dialCode == other.dialCode &&
          isoCode == other.isoCode;

  @override
  int get hashCode => Object.hash(dialCode, isoCode);
}

@immutable
class _ResolvedFieldConfig {
  const _ResolvedFieldConfig({
    required this.ui,
    required this.fieldTheme,
    required this.variant,
    required this.labelMode,
    required this.labelSpacing,
    required this.borderRadius,
    required this.borderWidth,
    required this.focusedBorderWidth,
    required this.fillColor,
    required this.borderColor,
    required this.focusedBorderColor,
    required this.accentColor,
    required this.errorColor,
    required this.successColor,
    required this.labelStyle,
    required this.hintStyle,
    required this.textStyle,
    required this.prefixIconColor,
    required this.suffixIconColor,
    required this.contentPadding,
    required this.isDense,
    required this.showClearButton,
    required this.showValidationIcons,
    required this.autovalidateMode,
    required this.showPrefixIcon,
    required this.clearIcon,
    this.stylePrefixIcon,
    this.styleSuffixIcon,
  });

  final OmniUiTheme ui;
  final OmniFieldTheme fieldTheme;
  final OmniInputVariant variant;
  final OmniFieldLabelMode labelMode;
  final double labelSpacing;
  final BorderRadius borderRadius;
  final double borderWidth;
  final double focusedBorderWidth;
  final Color fillColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color accentColor;
  final Color errorColor;
  final Color successColor;
  final TextStyle labelStyle;
  final TextStyle hintStyle;
  final TextStyle textStyle;
  final Color prefixIconColor;
  final Color suffixIconColor;
  final EdgeInsetsGeometry contentPadding;
  final bool isDense;
  final bool showClearButton;
  final bool showValidationIcons;
  final AutovalidateMode autovalidateMode;
  final bool showPrefixIcon;
  final IconData clearIcon;
  final Widget? stylePrefixIcon;
  final Widget? styleSuffixIcon;

  /// প্রিফিক্স আইকন রিজলভ করে (`showPrefixIcon == false` হলে `null`)।
  Widget? resolvePrefixIcon(
    Widget? widgetIcon,
    IconData defaultIcon, {
    bool widgetShowPrefixIcon = true,
  }) {
    if (!widgetShowPrefixIcon || !showPrefixIcon) return null;
    return widgetIcon ?? stylePrefixIcon ?? Icon(defaultIcon);
  }

  /// কাস্টম সাফিক্স আইকন রিজলভ করে।
  Widget? resolveSuffixIcon(Widget? widgetSuffixIcon) =>
      widgetSuffixIcon ?? styleSuffixIcon;

  factory _ResolvedFieldConfig.of(
    BuildContext context, {
    required OmniFieldIdentity identity,
    OmniFieldTheme? fieldThemeOverride,
    OmniFieldStyle? fieldStyleOverride,
    bool? showClearButtonOverride,
    bool? showPrefixIconOverride,
    IconData? clearIconOverride,
    AutovalidateMode? autovalidateModeOverride,
  }) {
    final ui = context.ui;
    final isDark = ui.isDark;
    final shared = fieldThemeOverride ?? OmniFieldTheme.of(context);
    final idStyle = shared.identityStyles[identity];
    final local = fieldStyleOverride;

    final themeInput = ui.styles.inputDecorationTheme;
    final defaultVariant = themeInput.filled
        ? OmniInputVariant.filled
        : (themeInput.enabledBorder is UnderlineInputBorder
              ? OmniInputVariant.underlined
              : OmniInputVariant.outlined);

    final variant =
        local?.variant ?? idStyle?.variant ?? shared.variant ?? defaultVariant;

    final rawRadius = local?.borderRadius ?? idStyle?.borderRadius ?? shared.borderRadius;
    final borderRadius = rawRadius != null
        ? BorderRadius.all(Radius.circular(rawRadius))
        : ui.styles.inputRadius;

    final themeEnabledWidth = themeInput.enabledBorder?.borderSide.width ?? 1.0;
    final themeFocusedWidth = themeInput.focusedBorder?.borderSide.width ?? 1.8;

    final borderWidth =
        local?.borderWidth ??
        idStyle?.borderWidth ??
        shared.borderWidth ??
        themeEnabledWidth;
    final focusedBorderWidth =
        local?.focusedBorderWidth ??
        idStyle?.focusedBorderWidth ??
        shared.focusedBorderWidth ??
        themeFocusedWidth;

    Color? pickMode(Color? lightC, Color? darkC) =>
        isDark ? (darkC ?? lightC) : lightC;

    final accentColor =
        pickMode(local?.accentColor, local?.darkAccentColor) ??
        pickMode(idStyle?.accentColor, idStyle?.darkAccentColor) ??
        ui.colors.primaryColor;

    final defaultFill = variant == OmniInputVariant.outlined
        ? ui.colors.cardColor
        : ui.colors.inputFillColor;
    final fillColor =
        pickMode(local?.fillColor, local?.darkFillColor) ??
        pickMode(idStyle?.fillColor, idStyle?.darkFillColor) ??
        pickMode(shared.fillColor, shared.darkFillColor) ??
        defaultFill;

    final borderColor =
        pickMode(local?.borderColor, local?.darkBorderColor) ??
        pickMode(idStyle?.borderColor, idStyle?.darkBorderColor) ??
        pickMode(shared.borderColor, shared.darkBorderColor) ??
        ui.colors.borderColor;

    final focusedBorderColor =
        pickMode(local?.focusedBorderColor, local?.darkFocusedBorderColor) ??
        pickMode(idStyle?.focusedBorderColor, idStyle?.darkFocusedBorderColor) ??
        pickMode(local?.accentColor, local?.darkAccentColor) ??
        pickMode(idStyle?.accentColor, idStyle?.darkAccentColor) ??
        pickMode(shared.focusedBorderColor, shared.darkFocusedBorderColor) ??
        ui.colors.focusedBorderColor;

    final errorColor =
        local?.errorBorderColor ??
        idStyle?.errorBorderColor ??
        shared.errorColor ??
        ui.colors.errorColor;

    final successColor =
        local?.successBorderColor ??
        idStyle?.successBorderColor ??
        shared.successColor ??
        ui.colors.successColor;

    final resolvedLabelColor =
        pickMode(shared.labelColor, shared.darkLabelColor) ??
        ui.text.label.color;
    final labelStyle =
        local?.labelStyle ??
        idStyle?.labelStyle ??
        ui.text.label.copyWith(color: resolvedLabelColor);

    final resolvedHintColor =
        pickMode(shared.hintColor, shared.darkHintColor) ?? ui.text.hint.color;
    final hintStyle =
        local?.hintStyle ??
        idStyle?.hintStyle ??
        ui.text.hint.copyWith(color: resolvedHintColor);

    final textStyle =
        local?.textStyle ?? idStyle?.textStyle ?? ui.text.body;

    final iconBaseColor =
        pickMode(shared.iconColor, shared.darkIconColor) ?? ui.colors.iconColor;

    final prefixIconColor =
        local?.prefixIconColor ??
        idStyle?.prefixIconColor ??
        pickMode(local?.accentColor, local?.darkAccentColor) ??
        pickMode(idStyle?.accentColor, idStyle?.darkAccentColor) ??
        iconBaseColor;

    final suffixIconColor =
        local?.suffixIconColor ?? idStyle?.suffixIconColor ?? iconBaseColor;

    final contentPadding =
        local?.contentPadding ??
        idStyle?.contentPadding ??
        shared.contentPadding ??
        (variant == OmniInputVariant.underlined
            ? const EdgeInsets.symmetric(horizontal: 2, vertical: 12)
            : ui.tokens.cardPadding);

    final isDense = local?.isDense ?? idStyle?.isDense ?? shared.isDense;
    final showClearButton =
        showClearButtonOverride ??
        local?.showClearButton ??
        idStyle?.showClearButton ??
        shared.showClearButton;
    final showPrefixIcon =
        showPrefixIconOverride ??
        local?.showPrefixIcon ??
        idStyle?.showPrefixIcon ??
        true;
    final clearIcon =
        clearIconOverride ??
        local?.clearIcon ??
        idStyle?.clearIcon ??
        Icons.close_rounded;

    return _ResolvedFieldConfig(
      ui: ui,
      fieldTheme: shared,
      variant: variant,
      labelMode: shared.labelMode,
      labelSpacing: shared.labelSpacing,
      borderRadius: borderRadius,
      borderWidth: borderWidth,
      focusedBorderWidth: focusedBorderWidth,
      fillColor: fillColor,
      borderColor: borderColor,
      focusedBorderColor: focusedBorderColor,
      accentColor: accentColor,
      errorColor: errorColor,
      successColor: successColor,
      labelStyle: labelStyle,
      hintStyle: hintStyle,
      textStyle: textStyle,
      prefixIconColor: prefixIconColor,
      suffixIconColor: suffixIconColor,
      contentPadding: contentPadding,
      isDense: isDense,
      showClearButton: showClearButton,
      showValidationIcons: shared.showValidationIcons,
      autovalidateMode: autovalidateModeOverride ?? shared.autovalidateMode,
      showPrefixIcon: showPrefixIcon,
      clearIcon: clearIcon,
      stylePrefixIcon: local?.prefixIcon ?? idStyle?.prefixIcon,
      styleSuffixIcon: local?.suffixIcon ?? idStyle?.suffixIcon,
    );
  }

  InputBorder makeBorder(Color color, double width) {
    final side = width <= 0
        ? BorderSide.none
        : BorderSide(color: color, width: width);
    return switch (variant) {
      OmniInputVariant.underlined => UnderlineInputBorder(borderSide: side),
      OmniInputVariant.filled || OmniInputVariant.outlined =>
        OutlineInputBorder(borderRadius: borderRadius, borderSide: side),
    };
  }

  InputDecoration buildDecoration({
    String? label,
    String? hint,
    String? helperText,
    String? errorText,
    String? prefixText,
    String? suffixText,
    Widget? prefixIcon,
    Widget? prefix,
    Widget? suffixIcon,
    Widget? suffix,
    Widget? counter,
    bool enabled = true,
    InputDecoration? customDecoration,
    Color? activeBorderOverride,
  }) {
    final effectiveEnabledBorder = makeBorder(
      activeBorderOverride ?? borderColor,
      borderWidth,
    );
    final effectiveFocusedBorder = makeBorder(
      activeBorderOverride ?? focusedBorderColor,
      focusedBorderWidth,
    );

    final base = InputDecoration(
      labelText: labelMode == OmniFieldLabelMode.floating ? label : null,
      hintText: hint,
      helperText: helperText,
      errorText: errorText,
      prefixText: prefixText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      prefix: prefix,
      suffixIcon: suffixIcon,
      suffix: suffix,
      counter: counter,
      enabled: enabled,
      isDense: isDense,
      filled: variant == OmniInputVariant.filled,
      fillColor: enabled ? fillColor : ui.colors.disabledColor,
      contentPadding: contentPadding,
      labelStyle: labelStyle,
      floatingLabelStyle: labelStyle.copyWith(color: focusedBorderColor),
      hintStyle: hintStyle,
      helperStyle: ui.text.caption,
      errorStyle: ui.text.error.copyWith(color: errorColor),
      prefixIconColor: prefixIconColor,
      suffixIconColor: suffixIconColor,
      border: effectiveEnabledBorder,
      enabledBorder: effectiveEnabledBorder,
      focusedBorder: effectiveFocusedBorder,
      errorBorder: makeBorder(errorColor, math.max(borderWidth, 1.0)),
      focusedErrorBorder: makeBorder(errorColor, focusedBorderWidth),
      disabledBorder: makeBorder(ui.colors.disabledBorderColor, borderWidth),
    );

    if (customDecoration == null) return base;

    return base.copyWith(
      labelText: customDecoration.labelText,
      label: customDecoration.label,
      hintText: customDecoration.hintText,
      helperText: customDecoration.helperText,
      errorText: customDecoration.errorText,
      prefixText: customDecoration.prefixText,
      suffixText: customDecoration.suffixText,
      prefixIcon: customDecoration.prefixIcon,
      prefix: customDecoration.prefix,
      suffixIcon: customDecoration.suffixIcon,
      suffix: customDecoration.suffix,
      counter: customDecoration.counter,
      counterText: customDecoration.counterText,
      fillColor: customDecoration.fillColor,
      filled: customDecoration.filled,
      contentPadding: customDecoration.contentPadding,
      border: customDecoration.border,
      enabledBorder: customDecoration.enabledBorder,
      focusedBorder: customDecoration.focusedBorder,
      errorBorder: customDecoration.errorBorder,
      focusedErrorBorder: customDecoration.focusedErrorBorder,
      disabledBorder: customDecoration.disabledBorder,
      isDense: customDecoration.isDense,
      constraints: customDecoration.constraints,
    );
  }
}

/// কমন লেবেল (`above` / `floating` / `none`) ও `TextFormField` র‍্যাপার।
class _OmniFieldInputShell extends StatelessWidget {
  const _OmniFieldInputShell({
    required this.config,
    required this.controller,
    required this.decoration,
    this.label,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onEditingComplete,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofillHints,
    this.textAlign = TextAlign.start,
  });

  final _ResolvedFieldConfig config;
  final TextEditingController controller;
  final InputDecoration decoration;
  final String? label;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: config.textStyle,
      cursorColor: config.accentColor,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: config.autovalidateMode,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autofocus: autofocus,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? null : minLines,
      maxLength: maxLength,
      autofillHints: autofillHints,
      textAlign: textAlign,
    );

    if (config.labelMode == OmniFieldLabelMode.above &&
        label != null &&
        label!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label!, style: config.labelStyle),
          SizedBox(height: config.labelSpacing),
          field,
        ],
      );
    }
    return field;
  }
}

/// একাধিক সাফিক্স অ্যাকশন (যেমন valid badge + clear button + custom suffix) একসাথে সাজায়।
Widget? _combineSuffixWidgets(List<Widget?> items) {
  final active = items.whereType<Widget>().toList(growable: false);
  if (active.isEmpty) return null;
  if (active.length == 1) return active.first;
  return Row(mainAxisSize: MainAxisSize.min, children: active);
}

// =============================================================================
// 1. OmniTextField (Universal Base Predefined Field)
// =============================================================================

/// [OmniFieldTheme] ও [OmniTheme] দ্বারা থিমড ইউনিভার্সাল টেক্সট ফিল্ড উইজেট।
class OmniTextField extends StatefulWidget {
  /// সব কমন কাস্টমাইজেশনসহ [OmniTextField] তৈরি করে।
  const OmniTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.clearIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onEditingComplete,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showClearButton,
    this.autofillHints,
    this.textAlign = TextAlign.start,
    this.required = false,
    this.requiredMessage = 'This field is required',
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
    this.identity = OmniFieldIdentity.text,
  });

  /// বাহ্যিক [TextEditingController]।
  final TextEditingController? controller;

  /// `controller` না দিলে প্রাথমিক মান।
  final String? initialValue;

  /// ঐচ্ছিক [FocusNode]।
  final FocusNode? focusNode;

  /// ফিল্ড লেবেল।
  final String? label;

  /// ফিল্ড প্লেসহোল্ডার।
  final String? hint;

  /// নিচে দেখানো সহায়ক টেক্সট।
  final String? helperText;

  /// সরাসরি এরর টেক্সট ওভাররাইড।
  final String? errorText;

  /// কাস্টম প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// ইনপুটের ভেতরে প্রিফিক্স উইজেট।
  final Widget? prefix;

  /// কাস্টম সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// ইনপুটের ভেতরে সাফিক্স উইজেট।
  final Widget? suffix;

  /// প্রিফিক্স আইকন দেখাবে কি না (`false` দিলে আইকন ছাড়া)।
  final bool showPrefixIcon;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

  /// কিবোর্ড টাইপ।
  final TextInputType? keyboardType;

  /// কিবোর্ড অ্যাকশন বাটন।
  final TextInputAction? textInputAction;

  /// অটো-ক্যাপিটালাইজেশন ধরন।
  final TextCapitalization textCapitalization;

  /// ইনপুট ফরম্যাটার তালিকা।
  final List<TextInputFormatter>? inputFormatters;

  /// কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// অটো-ভ্যালিডেট মোড ওভাররাইড।
  final AutovalidateMode? autovalidateMode;

  /// মান পরিবর্তনের কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// ট্যাপ কলব্যাক।
  final VoidCallback? onTap;

  /// এডিটিং সমাপ্তি কলব্যাক।
  final VoidCallback? onEditingComplete;

  /// সক্রিয় আছে কি না।
  final bool enabled;

  /// রিড-অনলি মোড কি না।
  final bool readOnly;

  /// টেক্সট লুকিয়ে রাখবে কি না।
  final bool obscureText;

  /// শুরুতেই ফোকাস নেবে কি না।
  final bool autofocus;

  /// সর্বোচ্চ লাইন।
  final int? maxLines;

  /// সর্বনিম্ন লাইন।
  final int? minLines;

  /// সর্বোচ্চ ক্যারেক্টার।
  final int? maxLength;

  /// টেক্সট থাকলে ক্লিয়ার (`×`) বাটন দেখাবে কি না।
  final bool? showClearButton;

  /// অটো-ফিল হিন্টস।
  final Iterable<String>? autofillHints;

  /// টেক্সট অ্যালাইনমেন্ট।
  final TextAlign textAlign;

  /// খালি থাকলে ভ্যালিডেশন আটকাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// শুধু এই উইজেটের জন্য [OmniFieldTheme] ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// শুধু এই উইজেটের জন্য [OmniFieldStyle] ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// সম্পূর্ণ কাস্টম [InputDecoration] ওভাররাইড।
  final InputDecoration? decoration;

  /// ফিল্ডের আইডেন্টিটি (ডিফল্ট [OmniFieldIdentity.text])।
  final OmniFieldIdentity identity;

  @override
  State<OmniTextField> createState() => _OmniTextFieldState();
}

class _OmniTextFieldState extends State<OmniTextField> {
  TextEditingController? _ownedController;

  TextEditingController get _ctrl => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant OmniTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_onTextChanged);
      if (widget.controller == null) {
        _ownedController ??= TextEditingController(
          text: oldWidget.controller?.text ?? widget.initialValue ?? '',
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _ctrl.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    (widget.controller ?? _ownedController)?.removeListener(_onTextChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _ResolvedFieldConfig.of(
      context,
      identity: widget.identity,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: widget.fieldStyle,
      showClearButtonOverride: widget.showClearButton,
      showPrefixIconOverride: widget.showPrefixIcon,
      clearIconOverride: widget.clearIcon,
      autovalidateModeOverride: widget.autovalidateMode,
    );

    final effectiveClear =
        config.showClearButton &&
        widget.enabled &&
        !widget.readOnly &&
        _ctrl.text.isNotEmpty;

    final suffix = _combineSuffixWidgets([
      if (effectiveClear)
        IconButton(
          tooltip: 'Clear',
          icon: Icon(config.clearIcon, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            widget.onChanged?.call('');
          },
        ),
      config.resolveSuffixIcon(widget.suffixIcon),
    ]);

    final effectiveLabel = widget.label;
    final decoration = config.buildDecoration(
      label: effectiveLabel,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: config.resolvePrefixIcon(
        widget.prefixIcon,
        widget.identity.defaultIcon,
        widgetShowPrefixIcon: widget.showPrefixIcon,
      ),
      prefix: widget.prefix,
      suffixIcon: suffix,
      suffix: widget.suffix,
      enabled: widget.enabled,
      customDecoration: widget.decoration,
    );

    return _OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: effectiveLabel,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      validator:
          widget.validator ??
          (widget.required
              ? (v) =>
                  (v ?? '').trim().isEmpty ? widget.requiredMessage : null
              : null),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      onEditingComplete: widget.onEditingComplete,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      autofillHints: widget.autofillHints,
      textAlign: widget.textAlign,
    );
  }
}

// =============================================================================
// 2. OmniEmailField (Email & Gmail Verification Field)
// =============================================================================

/// বিল্ট-ইন **ইমেইল / Gmail ভ্যালিডেশন**, ভ্যালিড চেক ব্যাজ, `@gmail.com` কুইক-ফিল
/// ও ক্লিয়ার বাটনসহ প্রি-ডিফাইনড ইমেইল টেক্সট ফিল্ড (`OmniFieldIdentity.email`)।
class OmniEmailField extends StatefulWidget {
  /// সব কাস্টমাইজেশনসহ [OmniEmailField] তৈরি করে।
  const OmniEmailField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Email',
    this.hint = 'name@gmail.com',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.clearIcon,
    this.validBadgeIcon,
    this.gmailOnly = false,
    this.allowedDomains,
    this.required = true,
    this.requiredMessage = 'Please enter an email address',
    this.invalidEmailMessage = 'Please enter a valid email address',
    this.invalidGmailMessage = 'Please enter a valid Gmail address (@gmail.com)',
    this.showValidBadge = true,
    this.showClearButton = true,
    this.showGmailQuickFill,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// শুধুমাত্র `@gmail.com` / `@googlemail.com` গ্রহণ ও ভেরিফিকেশনের জন্য
  /// প্রি-কনফিগার্ড [OmniEmailField.gmail] কনস্ট্রাক্টর।
  const OmniEmailField.gmail({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Gmail',
    this.hint = 'username@gmail.com',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.clearIcon,
    this.validBadgeIcon,
    this.required = true,
    this.requiredMessage = 'Please enter your Gmail address',
    this.invalidEmailMessage = 'Please enter a valid @gmail.com address',
    this.invalidGmailMessage = 'Please enter a valid @gmail.com address',
    this.showValidBadge = true,
    this.showClearButton = true,
    this.showGmailQuickFill = true,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : gmailOnly = true,
       allowedDomains = null;

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// `controller` না দিলে প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// ফিল্ড লেবেল (ডিফল্ট `'Email'`, `.gmail`-এ `'Gmail'`)।
  final String? label;

  /// প্লেসহোল্ডার টেক্সট।
  final String? hint;

  /// হেল্পার টেক্সট।
  final String? helperText;

  /// ম্যানুয়াল এরর টেক্সট ওভাররাইড।
  final String? errorText;

  /// কাস্টম প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// ইনপুটের ভেতরে প্রিফিক্স উইজেট।
  final Widget? prefix;

  /// কাস্টম সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// ইনপুটের ভেতরে সাফিক্স উইজেট।
  final Widget? suffix;

  /// প্রিফিক্স আইকন দেখাবে কি না (`false` দিলে আইকন ছাড়া)।
  final bool showPrefixIcon;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

  /// ভ্যালিড ব্যাজের কাস্টম আইকন।
  final IconData? validBadgeIcon;

  /// `true` হলে শুধুমাত্র `@gmail.com` / `@googlemail.com` ঠিকানা গ্রহণ করে।
  final bool gmailOnly;

  /// অনুমোদিত ডোমেইন তালিকা (যেমন `['gmail.com', 'company.com']`)।
  final List<String>? allowedDomains;

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// ইমেইল ফরম্যাট ভুল হলে মেসেজ।
  final String invalidEmailMessage;

  /// Gmail ছাড়া অন্য ডোমেইন দিলে মেসেজ।
  final String invalidGmailMessage;

  /// ইমেইল ভ্যালিড হলে সবুজ চেক আইকন দেখাবে কি না।
  final bool showValidBadge;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// `@` লেখার আগে ১-ট্যাপ `@gmail.com` বাটন দেখাবে কি না।
  final bool? showGmailQuickFill;

  /// কিবোর্ড অ্যাকশন।
  final TextInputAction? textInputAction;

  /// অটো-ভ্যালিডেট মোড।
  final AutovalidateMode? autovalidateMode;

  /// সম্পূর্ণ কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// মান পরিবর্তনে কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// সক্রিয় অবস্থা।
  final bool enabled;

  /// রিড-অনলি মোড।
  final bool readOnly;

  /// অটো-ফোকাস।
  final bool autofocus;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  State<OmniEmailField> createState() => _OmniEmailFieldState();
}

class _OmniEmailFieldState extends State<OmniEmailField> {
  TextEditingController? _ownedController;

  TextEditingController get _ctrl => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
    _ctrl.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant OmniEmailField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_handleChange);
      if (widget.controller == null) {
        _ownedController ??= TextEditingController(
          text: oldWidget.controller?.text ?? widget.initialValue ?? '',
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _ctrl.addListener(_handleChange);
    }
  }

  void _handleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    (widget.controller ?? _ownedController)?.removeListener(_handleChange);
    _ownedController?.dispose();
    super.dispose();
  }

  String? _defaultValidate(String? v) => OmniValidators.email(
    v,
    required: widget.required,
    gmailOnly: widget.gmailOnly,
    allowedDomains: widget.allowedDomains,
    requiredMessage: widget.requiredMessage,
    invalidEmailMessage: widget.invalidEmailMessage,
    invalidGmailMessage: widget.invalidGmailMessage,
  );

  @override
  Widget build(BuildContext context) {
    final config = _ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.email,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: widget.fieldStyle,
      showClearButtonOverride: widget.showClearButton,
      showPrefixIconOverride: widget.showPrefixIcon,
      clearIconOverride: widget.clearIcon,
      autovalidateModeOverride: widget.autovalidateMode,
    );

    final text = _ctrl.text.trim();
    final isValid = text.isNotEmpty && _defaultValidate(text) == null;
    final canQuickFillGmail =
        (widget.showGmailQuickFill ?? widget.gmailOnly) &&
        widget.enabled &&
        !widget.readOnly &&
        text.isNotEmpty &&
        !text.contains('@');

    final suffix = _combineSuffixWidgets([
      if (canQuickFillGmail)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ActionChip(
            label: Text(
              '@gmail.com',
              style: config.ui.text.caption.copyWith(
                color: config.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onPressed: () {
              final next = '$text@gmail.com';
              _ctrl.value = TextEditingValue(
                text: next,
                selection: TextSelection.collapsed(offset: next.length),
              );
              widget.onChanged?.call(next);
            },
          ),
        ),
      if (widget.showValidBadge && config.showValidationIcons && isValid)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            widget.validBadgeIcon ?? Icons.check_circle_rounded,
            size: 20,
            color: config.successColor,
          ),
        ),
      if (config.showClearButton &&
          widget.enabled &&
          !widget.readOnly &&
          _ctrl.text.isNotEmpty)
        IconButton(
          tooltip: 'Clear email',
          icon: Icon(config.clearIcon, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            widget.onChanged?.call('');
          },
        ),
      config.resolveSuffixIcon(widget.suffixIcon),
    ]);

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: config.resolvePrefixIcon(
        widget.prefixIcon,
        widget.gmailOnly
            ? Icons.alternate_email_rounded
            : OmniFieldIdentity.email.defaultIcon,
        widgetShowPrefixIcon: widget.showPrefixIcon,
      ),
      prefix: widget.prefix,
      suffixIcon: suffix,
      suffix: widget.suffix,
      enabled: widget.enabled,
      customDecoration: widget.decoration,
      activeBorderOverride: isValid ? config.successColor : null,
    );

    return _OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: widget.label,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.emailAddress,
      textInputAction: widget.textInputAction,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      validator: widget.validator ?? _defaultValidate,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      autofillHints: const [AutofillHints.email],
    );
  }
}

// =============================================================================
// 3. OmniPasswordField (Show/Hide, Strength Meter, Confirm Match)
// =============================================================================

/// পাসওয়ার্ড **শো/হাইড টগল**, লাইভ **পাসওয়ার্ড স্ট্রেংথ মিটার**, ক্যারেক্টার নিয়ম
/// ও **কনফার্ম পাসওয়ার্ড ম্যাচিং** সুবিধাসহ প্রি-ডিফাইনড ফিল্ড (`OmniFieldIdentity.password`)।
class OmniPasswordField extends StatefulWidget {
  /// সব কাস্টমাইজেশনসহ [OmniPasswordField] তৈরি করে।
  const OmniPasswordField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Password',
    this.hint = 'Enter password',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton = false,
    this.clearIcon,
    this.initiallyObscured = true,
    this.showVisibilityToggle = true,
    this.showPasswordIcon = Icons.visibility_outlined,
    this.hidePasswordIcon = Icons.visibility_off_outlined,
    this.showStrengthIndicator = false,
    this.strengthLabels = const ['Weak', 'Fair', 'Good', 'Strong'],
    this.required = true,
    this.requiredMessage = 'Please enter a password',
    this.minLength = 6,
    this.requireUppercase = false,
    this.requireLowercase = false,
    this.requireDigit = false,
    this.requireSpecialChar = false,
    this.matchController,
    this.matchValue,
    this.mismatchMessage = 'Passwords do not match',
    this.textInputAction = TextInputAction.done,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.isNewPassword = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// সাইনআপ বা নতুন পাসওয়ার্ড সেট করার জন্য (স্ট্রেংথ মিটারসহ)।
  const OmniPasswordField.newPassword({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'New Password',
    this.hint = 'Create a strong password',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton = false,
    this.clearIcon,
    this.initiallyObscured = true,
    this.showVisibilityToggle = true,
    this.showPasswordIcon = Icons.visibility_outlined,
    this.hidePasswordIcon = Icons.visibility_off_outlined,
    this.showStrengthIndicator = true,
    this.strengthLabels = const ['Weak', 'Fair', 'Good', 'Strong'],
    this.required = true,
    this.requiredMessage = 'Please enter a password',
    this.minLength = 8,
    this.requireUppercase = true,
    this.requireLowercase = true,
    this.requireDigit = true,
    this.requireSpecialChar = false,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : matchController = null,
       matchValue = null,
       mismatchMessage = 'Passwords do not match',
       isNewPassword = true;

  /// পাসওয়ার্ড কনফার্ম ও লাইভ ম্যাচিং যাচাইয়ের কনস্ট্রাক্টর।
  const OmniPasswordField.confirm({
    super.key,
    required TextEditingController this.matchController,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Confirm Password',
    this.hint = 'Re-enter password',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton = false,
    this.clearIcon,
    this.initiallyObscured = true,
    this.showVisibilityToggle = true,
    this.showPasswordIcon = Icons.visibility_outlined,
    this.hidePasswordIcon = Icons.visibility_off_outlined,
    this.required = true,
    this.requiredMessage = 'Please confirm your password',
    this.mismatchMessage = 'Passwords do not match',
    this.textInputAction = TextInputAction.done,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : showStrengthIndicator = false,
       strengthLabels = const ['Weak', 'Fair', 'Good', 'Strong'],
       minLength = 1,
       requireUppercase = false,
       requireLowercase = false,
       requireDigit = false,
       requireSpecialChar = false,
       matchValue = null,
       isNewPassword = true;

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// ফিল্ড লেবেল।
  final String? label;

  /// প্লেসহোল্ডার।
  final String? hint;

  /// হেল্পার টেক্সট।
  final String? helperText;

  /// সরাসরি এরর টেক্সট।
  final String? errorText;

  /// কাস্টম প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// ইনপুটের ভেতরে প্রিফিক্স উইজেট।
  final Widget? prefix;

  /// অতিরিক্ত সাফিক্স উইজেট।
  final Widget? suffixIcon;

  /// ইনপুটের ভেতরে সাফিক্স উইজেট।
  final Widget? suffix;

  /// প্রিফিক্স আইকন দেখাবে কি না (`false` দিলে আইকন ছাড়া)।
  final bool showPrefixIcon;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

  /// শুরুতে পাসওয়ার্ড লুকানো থাকবে কি না।
  final bool initiallyObscured;

  /// শো/হাইড আই বাটন দেখাবে কি না।
  final bool showVisibilityToggle;

  /// পাসওয়ার্ড দেখানোর আইকন।
  final IconData showPasswordIcon;

  /// পাসওয়ার্ড লুকানোর আইকন।
  final IconData hidePasswordIcon;

  /// লাইভ ৪-ধাপের স্ট্রেংথ বার দেখাবে কি না।
  final bool showStrengthIndicator;

  /// স্ট্রেংথ ধাপের ৪টি নাম (`Weak`, `Fair`, `Good`, `Strong`)।
  final List<String> strengthLabels;

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// ন্যূনতম ক্যারেক্টার সংখ্যা।
  final int minLength;

  /// বড় হাতের অক্ষর (`A-Z`) বাধ্যতামূলক কি না।
  final bool requireUppercase;

  /// ছোট হাতের অক্ষর (`a-z`) বাধ্যতামূলক কি না।
  final bool requireLowercase;

  /// অন্তত ১টি সংখ্যা (`0-9`) বাধ্যতামূলক কি না।
  final bool requireDigit;

  /// অন্তত ১টি স্পেশাল ক্যারেক্টার বাধ্যতামূলক কি না।
  final bool requireSpecialChar;

  /// কনফার্ম ফিল্ডের জন্য মূল পাসওয়ার্ড কন্ট্রোলার।
  final TextEditingController? matchController;

  /// অথবা সরাসরি ম্যাচ করার স্ট্রিং মান।
  final String? matchValue;

  /// পাসওয়ার্ড না মিললে এরর মেসেজ।
  final String mismatchMessage;

  /// কিবোর্ড অ্যাকশন।
  final TextInputAction? textInputAction;

  /// অটো-ভ্যালিডেট মোড।
  final AutovalidateMode? autovalidateMode;

  /// সম্পূর্ণ কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// মান পরিবর্তনে কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// সক্রিয় কি না।
  final bool enabled;

  /// রিড-অনলি কি না।
  final bool readOnly;

  /// অটো-ফোকাস কি না।
  final bool autofocus;

  /// OS অটো-ফিল `newPassword` হিসেবে চিহ্নিত করবে কি না।
  final bool isNewPassword;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  State<OmniPasswordField> createState() => _OmniPasswordFieldState();
}

class _OmniPasswordFieldState extends State<OmniPasswordField> {
  TextEditingController? _ownedController;
  late bool _obscured;

  TextEditingController get _ctrl => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    _obscured = widget.initiallyObscured;
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
    _ctrl.addListener(_onChanged);
    widget.matchController?.addListener(_onMatchChanged);
  }

  @override
  void didUpdateWidget(covariant OmniPasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_onChanged);
      if (widget.controller == null) {
        _ownedController ??= TextEditingController(
          text: oldWidget.controller?.text ?? widget.initialValue ?? '',
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _ctrl.addListener(_onChanged);
    }
    if (oldWidget.matchController != widget.matchController) {
      oldWidget.matchController?.removeListener(_onMatchChanged);
      widget.matchController?.addListener(_onMatchChanged);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onMatchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    (widget.controller ?? _ownedController)?.removeListener(_onChanged);
    widget.matchController?.removeListener(_onMatchChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  String? _defaultValidate(String? v) {
    final target = widget.matchController?.text ?? widget.matchValue;
    if (target != null) {
      if ((v ?? '').isEmpty) {
        return widget.required ? widget.requiredMessage : null;
      }
      if (v != target) return widget.mismatchMessage;
      return null;
    }
    return OmniValidators.password(
      v,
      required: widget.required,
      minLength: widget.minLength,
      requireUppercase: widget.requireUppercase,
      requireLowercase: widget.requireLowercase,
      requireDigit: widget.requireDigit,
      requireSpecialChar: widget.requireSpecialChar,
      requiredMessage: widget.requiredMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.password,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: widget.fieldStyle,
      showClearButtonOverride: widget.showClearButton,
      showPrefixIconOverride: widget.showPrefixIcon,
      clearIconOverride: widget.clearIcon,
      autovalidateModeOverride: widget.autovalidateMode,
    );

    final raw = _ctrl.text;
    final targetMatch = widget.matchController?.text ?? widget.matchValue;
    final isMatched =
        targetMatch != null && raw.isNotEmpty && raw == targetMatch;

    final suffix = _combineSuffixWidgets([
      if (isMatched && config.showValidationIcons)
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: config.successColor,
          ),
        ),
      if (config.showClearButton &&
          widget.enabled &&
          !widget.readOnly &&
          raw.isNotEmpty)
        IconButton(
          tooltip: 'Clear password',
          icon: Icon(config.clearIcon, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            widget.onChanged?.call('');
          },
        ),
      if (widget.showVisibilityToggle)
        IconButton(
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscured ? widget.showPasswordIcon : widget.hidePasswordIcon,
            color: config.suffixIconColor,
          ),
          onPressed: widget.enabled
              ? () => setState(() => _obscured = !_obscured)
              : null,
        ),
      config.resolveSuffixIcon(widget.suffixIcon),
    ]);

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: config.resolvePrefixIcon(
        widget.prefixIcon,
        targetMatch != null
            ? Icons.verified_outlined
            : OmniFieldIdentity.password.defaultIcon,
        widgetShowPrefixIcon: widget.showPrefixIcon,
      ),
      prefix: widget.prefix,
      suffixIcon: suffix,
      suffix: widget.suffix,
      enabled: widget.enabled,
      customDecoration: widget.decoration,
      activeBorderOverride: isMatched ? config.successColor : null,
    );

    final input = _OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: widget.label,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      obscureText: _obscured,
      validator: widget.validator ?? _defaultValidate,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      autofillHints: [
        widget.isNewPassword
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
    );

    if (!widget.showStrengthIndicator || raw.isEmpty) {
      return input;
    }

    final score = OmniValidators.passwordStrengthScore(
      raw,
      minLength: math.max(widget.minLength, 8),
    );
    final barColor = switch (score) {
      1 => config.errorColor,
      2 => config.ui.colors.warningColor,
      3 => config.ui.colors.infoColor,
      _ => config.successColor,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        input,
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Row(
                children: List.generate(4, (i) {
                  final filled = i < score;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 4,
                      margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: filled ? barColor : config.ui.colors.dividerColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (widget.strengthLabels.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                widget.strengthLabels[(score - 1).clamp(
                  0,
                  widget.strengthLabels.length - 1,
                )],
                style: config.ui.text.caption.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// 4. OmniNameField (Full Name, First/Last Name, Username)
// =============================================================================

/// নাম ও ইউজারনেম ইনপুট ফিল্ড (`OmniFieldIdentity.name`) — ন্যূনতম দৈর্ঘ্য, সংখ্যা
/// নিয়ন্ত্রণ, অটো-ক্যাপিটালাইজেশন ও ক্লিয়ার বাটনসহ।
class OmniNameField extends StatefulWidget {
  /// পূর্ণ নামের [OmniNameField] তৈরি করে।
  const OmniNameField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Full Name',
    this.hint = 'Enter your full name',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefixText,
    this.prefix,
    this.suffixIcon,
    this.suffixText,
    this.suffix,
    this.showPrefixIcon = true,
    this.clearIcon,
    this.required = true,
    this.requiredMessage = 'Please enter your name',
    this.minLength = 2,
    this.maxLength = 60,
    this.allowDigits = false,
    this.allowSpaces = true,
    this.showClearButton = true,
    this.showValidBadge = false,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.autofillHints = const [AutofillHints.name],
    this.textCapitalization = TextCapitalization.words,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// ফার্স্ট নেমের প্রি-কনফিগার্ড কনস্ট্রাক্টর।
  const OmniNameField.firstName({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'First Name',
    this.hint = 'First name',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffixText,
    this.suffix,
    this.showPrefixIcon = true,
    this.clearIcon,
    this.required = true,
    this.requiredMessage = 'Please enter your first name',
    this.minLength = 2,
    this.maxLength = 30,
    this.showClearButton = true,
    this.showValidBadge = false,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : prefixText = null,
       allowDigits = false,
       allowSpaces = false,
       autofillHints = const [AutofillHints.givenName],
       textCapitalization = TextCapitalization.words;

  /// লাস্ট নেমের প্রি-কনফিগার্ড কনস্ট্রাক্টর।
  const OmniNameField.lastName({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Last Name',
    this.hint = 'Last name',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffixText,
    this.suffix,
    this.showPrefixIcon = true,
    this.clearIcon,
    this.required = true,
    this.requiredMessage = 'Please enter your last name',
    this.minLength = 2,
    this.maxLength = 30,
    this.showClearButton = true,
    this.showValidBadge = false,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : prefixText = null,
       allowDigits = false,
       allowSpaces = true,
       autofillHints = const [AutofillHints.familyName],
       textCapitalization = TextCapitalization.words;

  /// ইউজারনেম (`@handle`, স্পেস ছাড়া, অক্ষর ও সংখ্যা অনুমোদিত) কনস্ট্রাক্টর।
  const OmniNameField.username({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Username',
    this.hint = 'john_doe',
    this.helperText,
    this.errorText,
    this.prefixIcon = const Icon(Icons.alternate_email_rounded),
    this.prefixText,
    this.prefix,
    this.suffixIcon,
    this.suffixText,
    this.suffix,
    this.showPrefixIcon = true,
    this.clearIcon,
    this.required = true,
    this.requiredMessage = 'Please choose a username',
    this.minLength = 3,
    this.maxLength = 24,
    this.showClearButton = true,
    this.showValidBadge = true,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : allowDigits = true,
       allowSpaces = false,
       autofillHints = const [AutofillHints.username],
       textCapitalization = TextCapitalization.none;

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// লেবেল।
  final String? label;

  /// প্লেসহোল্ডার।
  final String? hint;

  /// হেল্পার টেক্সট।
  final String? helperText;

  /// ম্যানুয়াল এরর।
  final String? errorText;

  /// প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// প্রিফিক্স টেক্সট।
  final String? prefixText;

  /// ইনপুটের ভেতরে প্রিফিক্স উইজেট।
  final Widget? prefix;

  /// সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// সাফিক্স টেক্সট।
  final String? suffixText;

  /// ইনপুটের ভেতরে সাফিক্স উইজেট।
  final Widget? suffix;

  /// প্রিফিক্স আইকন দেখাবে কি না (`false` দিলে আইকন ছাড়া)।
  final bool showPrefixIcon;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// ন্যূনতম দৈর্ঘ্য।
  final int minLength;

  /// সর্বোচ্চ দৈর্ঘ্য।
  final int? maxLength;

  /// নামের ভেতর সংখ্যা অনুমোদিত কি না।
  final bool allowDigits;

  /// স্পেস অনুমোদিত কি না।
  final bool allowSpaces;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// ভ্যালিড হলে চেক ব্যাজ দেখাবে কি না।
  final bool showValidBadge;

  /// কিবোর্ড অ্যাকশন।
  final TextInputAction? textInputAction;

  /// অটো-ভ্যালিডেট মোড।
  final AutovalidateMode? autovalidateMode;

  /// কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// মান পরিবর্তনে কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// সক্রিয় অবস্থা।
  final bool enabled;

  /// রিড-অনলি মোড।
  final bool readOnly;

  /// অটো-ফোকাস।
  final bool autofocus;

  /// অটো-ফিল হিন্টস।
  final Iterable<String>? autofillHints;

  /// অটো-ক্যাপিটালাইজেশন ধরন।
  final TextCapitalization textCapitalization;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  State<OmniNameField> createState() => _OmniNameFieldState();
}

class _OmniNameFieldState extends State<OmniNameField> {
  TextEditingController? _ownedController;

  TextEditingController get _ctrl => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
    _ctrl.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant OmniNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_onChanged);
      if (widget.controller == null) {
        _ownedController ??= TextEditingController(
          text: oldWidget.controller?.text ?? widget.initialValue ?? '',
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _ctrl.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    (widget.controller ?? _ownedController)?.removeListener(_onChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  String? _defaultValidate(String? v) => OmniValidators.name(
    v,
    required: widget.required,
    minLength: widget.minLength,
    maxLength: widget.maxLength,
    allowDigits: widget.allowDigits,
    allowSpaces: widget.allowSpaces,
    requiredMessage: widget.requiredMessage,
  );

  @override
  Widget build(BuildContext context) {
    final config = _ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.name,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: widget.fieldStyle,
      showClearButtonOverride: widget.showClearButton,
      showPrefixIconOverride: widget.showPrefixIcon,
      clearIconOverride: widget.clearIcon,
      autovalidateModeOverride: widget.autovalidateMode,
    );

    final text = _ctrl.text.trim();
    final isValid = text.isNotEmpty && _defaultValidate(text) == null;

    final suffix = _combineSuffixWidgets([
      if (widget.showValidBadge && config.showValidationIcons && isValid)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: config.successColor,
          ),
        ),
      if (config.showClearButton &&
          widget.enabled &&
          !widget.readOnly &&
          _ctrl.text.isNotEmpty)
        IconButton(
          tooltip: 'Clear',
          icon: Icon(config.clearIcon, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            widget.onChanged?.call('');
          },
        ),
      config.resolveSuffixIcon(widget.suffixIcon),
    ]);

    final formatters = <TextInputFormatter>[
      if (!widget.allowSpaces) FilteringTextInputFormatter.deny(RegExp(r'\s')),
      if (!widget.allowDigits) FilteringTextInputFormatter.deny(RegExp(r'\d')),
      if (!widget.allowSpaces && widget.allowDigits)
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]')),
    ];

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixText: widget.prefixText,
      suffixText: widget.suffixText,
      prefixIcon: config.resolvePrefixIcon(
        widget.prefixIcon,
        OmniFieldIdentity.name.defaultIcon,
        widgetShowPrefixIcon: widget.showPrefixIcon,
      ),
      prefix: widget.prefix,
      suffixIcon: suffix,
      suffix: widget.suffix,
      enabled: widget.enabled,
      customDecoration: widget.decoration,
    );

    return _OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: widget.label,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.name,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: formatters.isEmpty ? null : formatters,
      validator: widget.validator ?? _defaultValidate,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      autofillHints: widget.autofillHints,
    );
  }
}

// =============================================================================
// 5. OmniPhoneField (Mobile Number + Dial Code Picker + Verification Action)
// =============================================================================

/// কান্ট্রি ডায়াল কোড পিকার, বাংলাদেশ/আন্তর্জাতিক মোবাইল নাম্বার ভ্যালিডেশন ও
/// ইনলাইন **Verify / Verified** স্টেটসহ মোবাইল নাম্বার ফিল্ড (`OmniFieldIdentity.phone`)।
class OmniPhoneField extends StatefulWidget {
  /// সব কাস্টমাইজেশনসহ [OmniPhoneField] তৈরি করে।
  const OmniPhoneField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Mobile Number',
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.leadingIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.showCountryCodePrefix = true,
    this.countryDropdownIcon = Icons.arrow_drop_down_rounded,
    this.clearIcon,
    this.verifiedIcon = Icons.verified_rounded,
    this.countryCode = '+880',
    this.countryCodes,
    this.showCountryPicker = true,
    this.validateBangladeshOperators = true,
    this.minDigits,
    this.maxDigits,
    this.required = true,
    this.requiredMessage = 'Please enter your mobile number',
    this.invalidPhoneMessage = 'Please enter a valid mobile number',
    this.isVerified = false,
    this.onVerifyPressed,
    this.verifyLabel = 'Verify',
    this.verifiedLabel = 'Verified',
    this.showClearButton = true,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onFullNumberChanged,
    this.onCountryChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// জনপ্রিয় দেশগুলোর ডিফল্ট ডায়াল কোড তালিকা।
  static const List<OmniCountryDialCode> defaultCountryCodes = [
    OmniCountryDialCode(
      dialCode: '+880',
      isoCode: 'BD',
      name: 'Bangladesh',
      flag: '🇧🇩',
      minDigits: 10,
      maxDigits: 11,
      exampleHint: '01712345678',
    ),
    OmniCountryDialCode(
      dialCode: '+91',
      isoCode: 'IN',
      name: 'India',
      flag: '🇮🇳',
      minDigits: 10,
      maxDigits: 10,
      exampleHint: '9876543210',
    ),
    OmniCountryDialCode(
      dialCode: '+1',
      isoCode: 'US',
      name: 'United States',
      flag: '🇺🇸',
      minDigits: 10,
      maxDigits: 10,
      exampleHint: '2025550147',
    ),
    OmniCountryDialCode(
      dialCode: '+44',
      isoCode: 'GB',
      name: 'United Kingdom',
      flag: '🇬🇧',
      minDigits: 10,
      maxDigits: 11,
      exampleHint: '7700900077',
    ),
    OmniCountryDialCode(
      dialCode: '+971',
      isoCode: 'AE',
      name: 'UAE',
      flag: '🇦🇪',
      minDigits: 9,
      maxDigits: 9,
      exampleHint: '501234567',
    ),
    OmniCountryDialCode(
      dialCode: '+966',
      isoCode: 'SA',
      name: 'Saudi Arabia',
      flag: '🇸🇦',
      minDigits: 9,
      maxDigits: 9,
      exampleHint: '501234567',
    ),
    OmniCountryDialCode(
      dialCode: '+60',
      isoCode: 'MY',
      name: 'Malaysia',
      flag: '🇲🇾',
      minDigits: 9,
      maxDigits: 10,
      exampleHint: '123456789',
    ),
    OmniCountryDialCode(
      dialCode: '+65',
      isoCode: 'SG',
      name: 'Singapore',
      flag: '🇸🇬',
      minDigits: 8,
      maxDigits: 8,
      exampleHint: '81234567',
    ),
  ];

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// লেবেল।
  final String? label;

  /// হিন্ট (ডিফল্ট নির্বাচিত দেশের উদাহরণ)।
  final String? hint;

  /// হেল্পার টেক্সট।
  final String? helperText;

  /// এরর ওভাররাইড।
  final String? errorText;

  /// কাস্টম প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// কাস্টম সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// ডিফল্ট কান্ট্রি ডায়াল কোড (`'+880'` ইত্যাদি)।
  final String countryCode;

  /// কাস্টম কান্ট্রি কোড তালিকা (না দিলে [defaultCountryCodes])।
  final List<OmniCountryDialCode>? countryCodes;

  /// ডায়াল কোড ট্যাপ করে পরিবর্তন করা যাবে কি না।
  final bool showCountryPicker;

  /// `+880` হলে বাংলাদেশি অপারেটর (`013`–`019`) যাচাই করবে কি না।
  final bool validateBangladeshOperators;

  /// আন্তর্জাতিক ন্যূনতম ডিজিট ওভাররাইড।
  final int? minDigits;

  /// আন্তর্জাতিক সর্বোচ্চ ডিজিট ওভাররাইড।
  final int? maxDigits;

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// নাম্বার ভুল হলে এরর মেসেজ।
  final String invalidPhoneMessage;

  /// নাম্বার ইতিমধ্যে ভেরিফাই হয়ে গেছে কি না।
  final bool isVerified;

  /// `Verify` বাটনে ট্যাপ কলব্যাক (দিলে ইনলাইন Verify বাটন দেখায়)।
  final VoidCallback? onVerifyPressed;

  /// Verify বাটনের টেক্সট।
  final String verifyLabel;

  /// Verified ব্যাজের টেক্সট।
  final String verifiedLabel;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// কিবোর্ড অ্যাকশন।
  final TextInputAction? textInputAction;

  /// অটো-ভ্যালিডেট মোড।
  final AutovalidateMode? autovalidateMode;

  /// কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// লোকাল ইনপুট পরিবর্তনের কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// পূর্ণ E.164 নাম্বার (`+88017...`) কলব্যাক।
  final ValueChanged<String>? onFullNumberChanged;

  /// কান্ট্রি কোড পরিবর্তনে কলব্যাক।
  final ValueChanged<OmniCountryDialCode>? onCountryChanged;

  /// সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// সক্রিয় কি না।
  final bool enabled;

  /// রিড-অনলি মোড কি না।
  final bool readOnly;

  /// অটো-ফোকাস কি না।
  final bool autofocus;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  State<OmniPhoneField> createState() => _OmniPhoneFieldState();
}

class _OmniPhoneFieldState extends State<OmniPhoneField> {
  TextEditingController? _ownedController;
  late OmniCountryDialCode _selectedCountry;

  TextEditingController get _ctrl => widget.controller ?? _ownedController!;

  List<OmniCountryDialCode> get _countries =>
      widget.countryCodes ?? OmniPhoneField.defaultCountryCodes;

  OmniCountryDialCode _resolveCountry(String dialCode) {
    for (final c in _countries) {
      if (c.dialCode == dialCode) return c;
    }
    return OmniCountryDialCode(dialCode: dialCode, isoCode: '', name: dialCode);
  }

  @override
  void initState() {
    super.initState();
    _selectedCountry = _resolveCountry(widget.countryCode);
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
    _ctrl.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant OmniPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryCode != widget.countryCode) {
      _selectedCountry = _resolveCountry(widget.countryCode);
    }
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_handleChange);
      if (widget.controller == null) {
        _ownedController ??= TextEditingController(
          text: oldWidget.controller?.text ?? widget.initialValue ?? '',
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _ctrl.addListener(_handleChange);
    }
  }

  void _handleChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    (widget.controller ?? _ownedController)?.removeListener(_handleChange);
    _ownedController?.dispose();
    super.dispose();
  }

  String? _defaultValidate(String? v) => OmniValidators.phone(
    v,
    countryCode: _selectedCountry.dialCode,
    required: widget.required,
    validateBangladeshOperators: widget.validateBangladeshOperators,
    minDigits: widget.minDigits ?? _selectedCountry.minDigits,
    maxDigits: widget.maxDigits ?? _selectedCountry.maxDigits,
    requiredMessage: widget.requiredMessage,
    invalidMessage: widget.invalidPhoneMessage,
  );

  void _notifyChanged(String val) {
    widget.onChanged?.call(val);
    widget.onFullNumberChanged?.call(
      OmniValidators.normalizePhone(val, countryCode: _selectedCountry.dialCode),
    );
  }

  Future<void> _openCountryPicker() async {
    if (!widget.showCountryPicker || !widget.enabled || widget.readOnly) {
      return;
    }
    final picked = await showDialog<OmniCountryDialCode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Country Code'),
        children: [
          for (final c in _countries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Row(
                children: [
                  if (c.flag.isNotEmpty) ...[
                    Text(c.flag),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: Text('${c.name} (${c.isoCode})')),
                  Text(
                    c.dialCode,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCountry = picked);
      widget.onCountryChanged?.call(picked);
      _notifyChanged(_ctrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.phone,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: widget.fieldStyle,
      showClearButtonOverride: widget.showClearButton,
      autovalidateModeOverride: widget.autovalidateMode,
    );

    final raw = _ctrl.text.trim();
    final isValid = raw.isNotEmpty && _defaultValidate(raw) == null;

    final dialPrefix =
        widget.prefixIcon ??
        InkWell(
          borderRadius: config.borderRadius,
          onTap: widget.showCountryPicker ? _openCountryPicker : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedCountry.flag.isNotEmpty) ...[
                  Text(_selectedCountry.flag),
                  const SizedBox(width: 4),
                ],
                Text(
                  _selectedCountry.dialCode,
                  style: config.textStyle.copyWith(fontWeight: FontWeight.w600),
                ),
                if (widget.showCountryPicker)
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: config.prefixIconColor,
                  ),
              ],
            ),
          ),
        );

    final suffix = _combineSuffixWidgets([
      if (widget.isVerified)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Chip(
            visualDensity: VisualDensity.compact,
            backgroundColor: config.successColor.withValues(alpha: 0.14),
            side: BorderSide.none,
            avatar: Icon(
              Icons.verified_rounded,
              size: 16,
              color: config.successColor,
            ),
            label: Text(
              widget.verifiedLabel,
              style: config.ui.text.caption.copyWith(
                color: config.successColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        )
      else if (widget.onVerifyPressed != null)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextButton(
            onPressed: widget.enabled && isValid ? widget.onVerifyPressed : null,
            child: Text(widget.verifyLabel),
          ),
        )
      else if (isValid && config.showValidationIcons)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: config.successColor,
          ),
        ),
      if (config.showClearButton &&
          widget.enabled &&
          !widget.readOnly &&
          !widget.isVerified &&
          _ctrl.text.isNotEmpty)
        IconButton(
          tooltip: 'Clear phone',
          icon: Icon(Icons.close_rounded, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            _notifyChanged('');
          },
        ),
      widget.suffixIcon,
    ]);

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint ?? _selectedCountry.exampleHint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: dialPrefix,
      suffixIcon: suffix,
      enabled: widget.enabled,
      customDecoration: widget.decoration,
      activeBorderOverride: (widget.isVerified || isValid)
          ? config.successColor
          : null,
    );

    return _OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: widget.label,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s-]'))],
      validator: widget.validator ?? _defaultValidate,
      onChanged: _notifyChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      autofillHints: const [AutofillHints.telephoneNumber],
    );
  }
}

// =============================================================================
// 6. OmniNumberField (Integer, Decimal, Currency, Steppers, Min/Max)
// =============================================================================

/// পূর্ণসংখ্যা, দশমিক বা কারেন্সি ইনপুট, `min`/`max` সীমা এবং `+`/`-` স্টেপার
/// বাটনসহ প্রি-ডিফাইনড নাম্বার ফিল্ড (`OmniFieldIdentity.number`)।
class OmniNumberField extends StatefulWidget {
  /// পূর্ণসংখ্যা বা সাধারণ নাম্বার ফিল্ড তৈরি করে।
  const OmniNumberField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Number',
    this.hint = '0',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.suffixText,
    this.allowDecimal = false,
    this.allowNegative = false,
    this.decimalRange = 2,
    this.min,
    this.max,
    this.step = 1,
    this.showStepper = false,
    this.required = true,
    this.requiredMessage = 'Please enter a number',
    this.invalidNumberMessage = 'Please enter a valid number',
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onNumberChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// শুধুমাত্র পূর্ণসংখ্যা ইনপুটের কনস্ট্রাক্টর।
  const OmniNumberField.integer({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Quantity',
    this.hint = '0',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.suffixText,
    this.allowNegative = false,
    this.min,
    this.max,
    this.step = 1,
    this.showStepper = true,
    this.required = true,
    this.requiredMessage = 'Please enter a quantity',
    this.invalidNumberMessage = 'Please enter a whole number',
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onNumberChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : allowDecimal = false,
       decimalRange = 0;

  /// দশমিক সংখ্যা ইনপুটের কনস্ট্রাক্টর।
  const OmniNumberField.decimal({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Amount',
    this.hint = '0.00',
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.suffixText,
    this.allowNegative = false,
    this.decimalRange = 2,
    this.min,
    this.max,
    this.step = 1,
    this.showStepper = false,
    this.required = true,
    this.requiredMessage = 'Please enter a number',
    this.invalidNumberMessage = 'Please enter a valid decimal number',
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onNumberChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : allowDecimal = true;

  /// টাকা/মূল্য ইনপুটের প্রি-কনফিগার্ড কনস্ট্রাক্টর।
  const OmniNumberField.currency({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Price / Amount',
    this.hint = '0.00',
    this.helperText,
    this.errorText,
    this.prefixIcon = const Icon(Icons.payments_outlined),
    this.prefixText = '৳ ',
    this.suffixIcon,
    this.suffixText,
    this.decimalRange = 2,
    this.min = 0,
    this.max,
    this.step = 10,
    this.showStepper = false,
    this.required = true,
    this.requiredMessage = 'Please enter an amount',
    this.invalidNumberMessage = 'Please enter a valid amount',
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onNumberChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  }) : allowDecimal = true,
       allowNegative = false;

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// লেবেল।
  final String? label;

  /// প্লেসহোল্ডার।
  final String? hint;

  /// হেল্পার টেক্সট।
  final String? helperText;

  /// ম্যানুয়াল এরর।
  final String? errorText;

  /// প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// প্রিফিক্স টেক্সট (`'৳ '`, `'\$ '` ইত্যাদি)।
  final String? prefixText;

  /// সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// সাফিক্স টেক্সট (`'kg'`, `'%'` ইত্যাদি)।
  final String? suffixText;

  /// দশমিক (`.`) অনুমোদিত কি না।
  final bool allowDecimal;

  /// নেগেটিভ (`-`) অনুমোদিত কি না।
  final bool allowNegative;

  /// দশমিকের পর সর্বোচ্চ কয় ঘর।
  final int decimalRange;

  /// সর্বনিম্ন মান।
  final num? min;

  /// সর্বোচ্চ মান।
  final num? max;

  /// স্টেপার `-` / `+` প্রতি ক্লিকে কত বাড়বে/কমবে।
  final num step;

  /// `-` / `+` স্টেপার বাটন দেখাবে কি না।
  final bool showStepper;

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// সংখ্যা ভুল হলে এরর মেসেজ।
  final String invalidNumberMessage;

  /// কিবোর্ড অ্যাকশন।
  final TextInputAction? textInputAction;

  /// অটো-ভ্যালিডেট মোড।
  final AutovalidateMode? autovalidateMode;

  /// কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// স্ট্রিং পরিবর্তনের কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// পার্সড সংখ্যার (`num?`) কলব্যাক।
  final ValueChanged<num?>? onNumberChanged;

  /// সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// সক্রিয় কি না।
  final bool enabled;

  /// রিড-অনলি কি না।
  final bool readOnly;

  /// অটো-ফোকাস কি না।
  final bool autofocus;

  /// টেক্সট অ্যালাইনমেন্ট।
  final TextAlign textAlign;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  State<OmniNumberField> createState() => _OmniNumberFieldState();
}

class _OmniNumberFieldState extends State<OmniNumberField> {
  TextEditingController? _ownedController;

  TextEditingController get _ctrl => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
    _ctrl.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant OmniNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_onChanged);
      if (widget.controller == null) {
        _ownedController ??= TextEditingController(
          text: oldWidget.controller?.text ?? widget.initialValue ?? '',
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _ctrl.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    (widget.controller ?? _ownedController)?.removeListener(_onChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  num? _parse(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    return widget.allowDecimal
        ? double.tryParse(clean)
        : int.tryParse(clean);
  }

  void _applyDelta(num delta) {
    final current = _parse(_ctrl.text) ?? (widget.min ?? 0);
    num next = current + delta;
    if (!widget.allowNegative && next < 0) next = 0;
    if (widget.min != null && next < widget.min!) next = widget.min!;
    if (widget.max != null && next > widget.max!) next = widget.max!;
    final formatted = widget.allowDecimal
        ? (next == next.roundToDouble()
              ? next.toInt().toString()
              : next.toStringAsFixed(math.min(widget.decimalRange, 4)))
        : next.round().toString();
    _ctrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onChanged?.call(formatted);
    widget.onNumberChanged?.call(_parse(formatted));
  }

  List<TextInputFormatter> _buildFormatters() {
    return [
      TextInputFormatter.withFunction((oldValue, newValue) {
        final t = newValue.text;
        if (t.isEmpty) return newValue;
        final negPrefix = widget.allowNegative ? '-?' : '';
        final pattern = widget.allowDecimal
            ? RegExp('^$negPrefix\\d*(?:\\.\\d{0,${math.max(0, widget.decimalRange)}})?\$')
            : RegExp('^$negPrefix\\d*\$');
        return pattern.hasMatch(t) ? newValue : oldValue;
      }),
    ];
  }

  String? _defaultValidate(String? v) => OmniValidators.number(
    v,
    required: widget.required,
    allowDecimal: widget.allowDecimal,
    allowNegative: widget.allowNegative,
    min: widget.min,
    max: widget.max,
    requiredMessage: widget.requiredMessage,
    invalidMessage: widget.invalidNumberMessage,
  );

  @override
  Widget build(BuildContext context) {
    final config = _ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.number,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: widget.fieldStyle,
      autovalidateModeOverride: widget.autovalidateMode,
    );

    final suffix = _combineSuffixWidgets([
      if (widget.showStepper && widget.enabled && !widget.readOnly) ...[
        IconButton(
          tooltip: 'Decrease',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.remove_rounded, color: config.suffixIconColor),
          onPressed: () => _applyDelta(-widget.step),
        ),
        IconButton(
          tooltip: 'Increase',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.add_rounded, color: config.accentColor),
          onPressed: () => _applyDelta(widget.step),
        ),
      ],
      widget.suffixIcon,
    ]);

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixText: widget.prefixText,
      suffixText: widget.suffixText,
      prefixIcon:
          widget.prefixIcon ?? Icon(OmniFieldIdentity.number.defaultIcon),
      suffixIcon: suffix,
      enabled: widget.enabled,
      customDecoration: widget.decoration,
    );

    return _OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: widget.label,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.allowDecimal,
        signed: widget.allowNegative,
      ),
      textInputAction: widget.textInputAction,
      inputFormatters: _buildFormatters(),
      validator: widget.validator ?? _defaultValidate,
      onChanged: (v) {
        widget.onChanged?.call(v);
        widget.onNumberChanged?.call(_parse(v));
      },
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
    );
  }
}

// =============================================================================
// 7. OmniOtpField (Multi-Box Verification Code / PIN Widget)
// =============================================================================

/// স্মার্ট পেস্ট, অটো-ফোকাস জাম্প, ব্যাকস্পেস নেভিগেশন, `FormField` ভ্যালিডেশন
/// এবং রিসেন্ড কাউন্টডাউন টাইমারসহ প্রি-ডিফাইনড OTP ভেরিফিকেশন উইজেট (`OmniFieldIdentity.otp`)।
class OmniOtpField extends FormField<String> {
  /// [length] সংখ্যার OTP ভেরিফিকেশন বক্স তৈরি করে (ডিফল্ট `6`)।
  OmniOtpField({
    super.key,
    this.length = 6,
    this.controller,
    this.label = 'Verification Code',
    this.helperText,
    this.errorText,
    this.digitsOnly = true,
    this.obscureText = false,
    this.boxStyle,
    this.boxWidth,
    this.boxHeight,
    this.boxSpacing,
    this.textStyle,
    this.onChanged,
    this.onCompleted,
    this.resendDuration,
    this.onResend,
    this.resendButtonLabel = 'Resend Code',
    this.isVerifying = false,
    this.isVerified = false,
    this.verifiedLabel = 'OTP Verified',
    super.enabled = true,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    AutovalidateMode? autovalidateMode,
    FormFieldValidator<String>? validator,
  }) : assert(length >= 2 && length <= 10),
       super(
         initialValue: controller?.text ?? '',
         autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
         validator:
             validator ??
             (v) => OmniValidators.otp(
               v,
               length: length,
               digitsOnly: digitsOnly,
             ),
         builder: (state) {
           final widget = state.widget as OmniOtpField;
           return _OmniOtpBoxes(
             field: widget,
             formState: state,
           );
         },
       );

  /// OTP ডিজিট সংখ্যা (`4`, `6`, `8` ইত্যাদি)।
  final int length;

  /// বাহ্যিক [TextEditingController]।
  final TextEditingController? controller;

  /// ওপরের লেবেল।
  final String? label;

  /// নিচে সহায়ক টেক্সট।
  final String? helperText;

  /// সরাসরি এরর টেক্সট ওভাররাইড।
  final String? errorText;

  /// শুধুমাত্র সংখ্যা (`0-9`) নেবে কি না।
  final bool digitsOnly;

  /// পিন কোডের মতো লুকানো (`•`) দেখাবে কি না।
  final bool obscureText;

  /// বক্সের ভিজ্যুয়াল স্টাইল (`outlined`, `filled`, `underlined`)।
  final OmniOtpBoxStyle? boxStyle;

  /// প্রতিটি বক্সের প্রস্থ।
  final double? boxWidth;

  /// প্রতিটি বক্সের উচ্চতা।
  final double? boxHeight;

  /// দুটি বক্সের মাঝের দূরত্ব।
  final double? boxSpacing;

  /// বক্সের ভেতরের সংখ্যা টেক্সট স্টাইল।
  final TextStyle? textStyle;

  /// প্রতিটি ডিজিট পরিবর্তনে কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// সব বক্স পূরণ হলেই স্বয়ংক্রিয়ভাবে কল হয়।
  final ValueChanged<String>? onCompleted;

  /// রিসেন্ড কাউন্টডাউন সময় (যেমন `Duration(seconds: 30)`)।
  final Duration? resendDuration;

  /// `Resend Code` বাটনে ট্যাপ কলব্যাক।
  final VoidCallback? onResend;

  /// রিসেন্ড বাটনের টেক্সট।
  final String resendButtonLabel;

  /// ভেরিফিকেশন লোডিং স্পিনার দেখানো হবে কি না।
  final bool isVerifying;

  /// OTP ভেরিফায়েড হয়ে গেছে কি না।
  final bool isVerified;

  /// ভেরিফায়েড ব্যাজ টেক্সট।
  final String verifiedLabel;

  /// প্রথম বক্সে অটো-ফোকাস নেবে কি না।
  final bool autofocus;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;
}

class _OmniOtpBoxes extends StatefulWidget {
  const _OmniOtpBoxes({
    required this.field,
    required this.formState,
  });

  final OmniOtpField field;
  final FormFieldState<String> formState;

  @override
  State<_OmniOtpBoxes> createState() => _OmniOtpBoxesState();
}

class _OmniOtpBoxesState extends State<_OmniOtpBoxes> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  bool _syncing = false;
  Timer? _resendTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initCells();
    _applyValue(widget.field.controller?.text ?? widget.formState.value ?? '');
    widget.field.controller?.addListener(_onExternalControllerChanged);
    _startResendCountdown();
  }

  void _initCells() {
    _controllers = List.generate(
      widget.field.length,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(widget.field.length, (index) {
      return FocusNode(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _controllers[index - 1].clear();
            _focusNodes[index - 1].requestFocus();
            _emitCombined(triggerCompleted: false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
      )..addListener(_onFocusChanged);
    });
  }

  void _disposeCells() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.removeListener(_onFocusChanged);
      f.dispose();
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendTimer = null;
    final dur = widget.field.resendDuration;
    if (dur == null || dur.inSeconds <= 0) {
      _remainingSeconds = 0;
      return;
    }
    _remainingSeconds = dur.inSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        t.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _OmniOtpBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field.length != widget.field.length) {
      _disposeCells();
      _initCells();
      _applyValue(widget.field.controller?.text ?? '');
    }
    if (oldWidget.field.controller != widget.field.controller) {
      oldWidget.field.controller?.removeListener(_onExternalControllerChanged);
      widget.field.controller?.addListener(_onExternalControllerChanged);
      _applyValue(widget.field.controller?.text ?? '');
    }
    if (oldWidget.field.resendDuration != widget.field.resendDuration) {
      _startResendCountdown();
    }
  }

  void _onExternalControllerChanged() {
    if (_syncing) return;
    _applyValue(widget.field.controller?.text ?? '');
  }

  void _applyValue(String raw) {
    _syncing = true;
    try {
      final clean = widget.field.digitsOnly
          ? raw.replaceAll(RegExp(r'\D'), '')
          : raw;
      for (var i = 0; i < _controllers.length; i++) {
        final ch = i < clean.length ? clean[i] : '';
        if (_controllers[i].text != ch) {
          _controllers[i].value = TextEditingValue(
            text: ch,
            selection: TextSelection.collapsed(offset: ch.length),
          );
        }
      }
      final truncated = clean.length > _controllers.length
          ? clean.substring(0, _controllers.length)
          : clean;
      if (widget.formState.value != truncated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.formState.didChange(truncated);
        });
      }
    } finally {
      _syncing = false;
    }
  }

  String get _combinedValue => _controllers.map((c) => c.text).join();

  void _emitCombined({required bool triggerCompleted}) {
    final code = _combinedValue;
    _syncing = true;
    try {
      final ext = widget.field.controller;
      if (ext != null && ext.text != code) {
        ext.value = TextEditingValue(
          text: code,
          selection: TextSelection.collapsed(offset: code.length),
        );
      }
      widget.formState.didChange(code);
    } finally {
      _syncing = false;
    }
    widget.field.onChanged?.call(code);
    if (triggerCompleted && code.length == widget.field.length) {
      widget.field.onCompleted?.call(code);
    }
    if (mounted) setState(() {});
  }

  void _handleCellChanged(int index, String value) {
    if (_syncing) return;
    final clean = widget.field.digitsOnly
        ? value.replaceAll(RegExp(r'\D'), '')
        : value;

    if (clean.length > 1) {
      // Multi-digit paste handling (e.g. "OTP: 482910"):
      _syncing = true;
      final startIndex = clean.length >= widget.field.length ? 0 : index;
      var cursor = startIndex;
      for (var k = 0; k < clean.length && cursor < widget.field.length; k++) {
        final ch = clean[k];
        _controllers[cursor].value = TextEditingValue(
          text: ch,
          selection: const TextSelection.collapsed(offset: 1),
        );
        cursor++;
      }
      _syncing = false;
      if (cursor < widget.field.length) {
        _focusNodes[cursor].requestFocus();
      } else {
        _focusNodes.last.unfocus();
      }
      _emitCombined(triggerCompleted: true);
      return;
    }

    if (clean.isEmpty) {
      if (_controllers[index].text.isNotEmpty) {
        _controllers[index].clear();
      }
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      _emitCombined(triggerCompleted: false);
      return;
    }

    if (_controllers[index].text != clean) {
      _syncing = true;
      _controllers[index].value = TextEditingValue(
        text: clean,
        selection: const TextSelection.collapsed(offset: 1),
      );
      _syncing = false;
    }
    if (index < widget.field.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
    _emitCombined(triggerCompleted: true);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    widget.field.controller?.removeListener(_onExternalControllerChanged);
    _disposeCells();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.otp,
      fieldThemeOverride: widget.field.fieldTheme,
      fieldStyleOverride: widget.field.fieldStyle,
    );
    final boxStyle = widget.field.boxStyle ?? config.fieldTheme.otpBoxStyle;
    final boxW = widget.field.boxWidth ?? config.fieldTheme.otpBoxWidth;
    final boxH = widget.field.boxHeight ?? config.fieldTheme.otpBoxHeight;
    final gap = widget.field.boxSpacing ?? config.fieldTheme.otpBoxSpacing;

    final effectiveError = widget.field.errorText ?? widget.formState.errorText;
    final hasError = effectiveError != null && effectiveError.isNotEmpty;
    final otpTextStyle =
        widget.field.textStyle ??
        config.ui.text.heading.copyWith(color: config.ui.colors.textColor);

    final effectiveBorderRadius = boxStyle == OmniOtpBoxStyle.underlined
        ? BorderRadius.zero
        : config.borderRadius;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.field.label != null && widget.field.label!.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                OmniFieldIdentity.otp.defaultIcon,
                size: 16,
                color: config.accentColor,
              ),
              const SizedBox(width: 6),
              Text(widget.field.label!, style: config.labelStyle),
            ],
          ),
          SizedBox(height: config.labelSpacing + 2),
        ],
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(widget.field.length, (i) {
            final isFocused = _focusNodes[i].hasFocus;
            final hasValue = _controllers[i].text.isNotEmpty;
            final strokeColor = hasError
                ? config.errorColor
                : widget.field.isVerified
                ? config.successColor
                : isFocused
                ? config.focusedBorderColor
                : hasValue
                ? config.accentColor.withValues(alpha: 0.7)
                : config.borderColor;
            final strokeWidth =
                (isFocused || hasError) ? config.focusedBorderWidth : config.borderWidth;

            InputBorder cellBorder(Color c, double w) {
              final side = w <= 0 && boxStyle == OmniOtpBoxStyle.filled
                  ? BorderSide.none
                  : BorderSide(color: c, width: math.max(w, 1.0));
              return boxStyle == OmniOtpBoxStyle.underlined
                  ? UnderlineInputBorder(borderSide: side)
                  : OutlineInputBorder(
                      borderRadius: effectiveBorderRadius,
                      borderSide: side,
                    );
            }

            final activeBorder = cellBorder(strokeColor, strokeWidth);
            return SizedBox(
              width: boxW,
              height: boxH,
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                enabled: widget.field.enabled && !widget.field.isVerifying,
                autofocus: widget.field.autofocus && i == 0,
                obscureText: widget.field.obscureText,
                textAlign: TextAlign.center,
                style: otpTextStyle,
                cursorColor: config.accentColor,
                keyboardType: widget.field.digitsOnly
                    ? TextInputType.number
                    : TextInputType.text,
                textInputAction: i == widget.field.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
                inputFormatters: widget.field.digitsOnly
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                onChanged: (v) => _handleCellChanged(i, v),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: boxStyle != OmniOtpBoxStyle.outlined,
                  fillColor: boxStyle == OmniOtpBoxStyle.filled
                      ? config.fillColor
                      : Colors.transparent,
                  border: activeBorder,
                  enabledBorder: activeBorder,
                  focusedBorder: cellBorder(
                    hasError ? config.errorColor : config.focusedBorderColor,
                    math.max(config.focusedBorderWidth, 1.8),
                  ),
                ),
              ),
            );
          }),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            effectiveError,
            style: config.ui.text.error.copyWith(color: config.errorColor),
          ),
        ] else if (widget.field.helperText != null) ...[
          const SizedBox(height: 6),
          Text(widget.field.helperText!, style: config.ui.text.caption),
        ],
        if (widget.field.isVerifying ||
            widget.field.isVerified ||
            widget.field.onResend != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.field.isVerifying) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('Verifying...', style: config.ui.text.caption),
              ] else if (widget.field.isVerified) ...[
                Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: config.successColor,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.field.verifiedLabel,
                  style: config.ui.text.caption.copyWith(
                    color: config.successColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (widget.field.onResend != null) ...[
                if (_remainingSeconds > 0)
                  Text(
                    'Resend code in 00:${_remainingSeconds.toString().padLeft(2, '0')}',
                    style: config.ui.text.caption,
                  )
                else
                  TextButton.icon(
                    onPressed: widget.field.enabled
                        ? () {
                            _startResendCountdown();
                            widget.field.onResend?.call();
                          }
                        : null,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(widget.field.resendButtonLabel),
                  ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// 8. OmniSearchField, OmniMultilineField & OmniUrlField
// =============================================================================

/// ডিবাউন্স সার্চ, ক্লিয়ার বাটন ও পিল-শেপ সাপোর্টসহ সার্চ ইনপুট (`OmniFieldIdentity.search`)।
class OmniSearchField extends StatefulWidget {
  /// সব কাস্টমাইজেশনসহ [OmniSearchField] তৈরি করে।
  const OmniSearchField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.hint = 'Search...',
    this.label,
    this.debounceDuration = const Duration(milliseconds: 280),
    this.onChanged,
    this.onSearchChanged,
    this.onSubmitted,
    this.onFilterPressed,
    this.pillShape = true,
    this.enabled = true,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// হিন্ট টেক্সট।
  final String? hint;

  /// ঐচ্ছিক লেবেল।
  final String? label;

  /// `onSearchChanged` কল হওয়ার ডিবাউন্স সময়।
  final Duration debounceDuration;

  /// তাৎক্ষণিক পরিবর্তনের কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// ডিবাউন্সড সার্চ কলব্যাক।
  final ValueChanged<String>? onSearchChanged;

  /// কিবোর্ড সার্চ সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// ফিল্টার আইকনে ট্যাপ করলে কল হয় (দিলে ফিল্টার বাটন দেখায়)।
  final VoidCallback? onFilterPressed;

  /// গোল পিল কর্নার ব্যবহার করবে কি না।
  final bool pillShape;

  /// সক্রিয় অবস্থা।
  final bool enabled;

  /// অটো-ফোকাস।
  final bool autofocus;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  State<OmniSearchField> createState() => _OmniSearchFieldState();
}

class _OmniSearchFieldState extends State<OmniSearchField> {
  TextEditingController? _ownedController;
  Timer? _debounce;

  TextEditingController get _ctrl => widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
    _ctrl.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant OmniSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_handleChange);
      if (widget.controller == null) {
        _ownedController ??= TextEditingController(
          text: oldWidget.controller?.text ?? widget.initialValue ?? '',
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _ctrl.addListener(_handleChange);
    }
  }

  void _handleChange() {
    if (mounted) setState(() {});
  }

  void _scheduleSearch(String value) {
    widget.onChanged?.call(value);
    if (widget.onSearchChanged == null) return;
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () {
      if (mounted) widget.onSearchChanged?.call(value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    (widget.controller ?? _ownedController)?.removeListener(_handleChange);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pillOverride = widget.pillShape
        ? (widget.fieldStyle ?? const OmniFieldStyle()).copyWith(
            borderRadius: widget.fieldStyle?.borderRadius ?? 999,
          )
        : widget.fieldStyle;

    final config = _ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.search,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: pillOverride,
    );

    final suffix = _combineSuffixWidgets([
      if (widget.enabled && _ctrl.text.isNotEmpty)
        IconButton(
          tooltip: 'Clear search',
          icon: Icon(Icons.close_rounded, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            _debounce?.cancel();
            widget.onChanged?.call('');
            widget.onSearchChanged?.call('');
          },
        ),
      if (widget.onFilterPressed != null)
        IconButton(
          tooltip: 'Filter',
          icon: Icon(Icons.tune_rounded, color: config.suffixIconColor),
          onPressed: widget.enabled ? widget.onFilterPressed : null,
        ),
    ]);

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint,
      prefixIcon: Icon(OmniFieldIdentity.search.defaultIcon),
      suffixIcon: suffix,
      enabled: widget.enabled,
      customDecoration: widget.decoration,
    );

    return _OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: widget.label,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      onChanged: _scheduleSearch,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
    );
  }
}

/// ঠিকানা, বায়ো, মন্তব্য বা বড় নোটসের জন্য প্রি-ডিফাইনড মাল্টি-লাইন ইনপুট (`OmniFieldIdentity.multiline`)।
class OmniMultilineField extends StatelessWidget {
  /// সব কাস্টমাইজেশনসহ [OmniMultilineField] তৈরি করে।
  const OmniMultilineField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Notes',
    this.hint = 'Write your message here...',
    this.helperText,
    this.errorText,
    this.minLines = 3,
    this.maxLines = 6,
    this.maxLength,
    this.required = false,
    this.requiredMessage = 'Please enter details',
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// লেবেল।
  final String? label;

  /// হিন্ট।
  final String? hint;

  /// হেল্পার টেক্সট।
  final String? helperText;

  /// এরর ওভাররাইড।
  final String? errorText;

  /// সর্বনিম্ন লাইন।
  final int minLines;

  /// সর্বোচ্চ লাইন।
  final int maxLines;

  /// সর্বোচ্চ ক্যারেক্টার সংখ্যা।
  final int? maxLength;

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// অটো-ভ্যালিডেট মোড।
  final AutovalidateMode? autovalidateMode;

  /// মান পরিবর্তনে কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// সক্রিয় অবস্থা।
  final bool enabled;

  /// রিড-অনলি মোড।
  final bool readOnly;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) => OmniTextField(
    controller: controller,
    initialValue: initialValue,
    focusNode: focusNode,
    label: label,
    hint: hint,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: Icon(OmniFieldIdentity.multiline.defaultIcon),
    keyboardType: TextInputType.multiline,
    textCapitalization: TextCapitalization.sentences,
    minLines: minLines,
    maxLines: maxLines,
    maxLength: maxLength,
    required: required,
    requiredMessage: requiredMessage,
    validator: validator,
    autovalidateMode: autovalidateMode,
    onChanged: onChanged,
    enabled: enabled,
    readOnly: readOnly,
    fieldTheme: fieldTheme,
    fieldStyle: fieldStyle,
    decoration: decoration,
    identity: OmniFieldIdentity.multiline,
  );
}

/// ওয়েবসাইট ও লিংক ভ্যালিডেশনসহ প্রি-ডিফাইনড URL ইনপুট (`OmniFieldIdentity.url`)।
class OmniUrlField extends StatelessWidget {
  /// সব কাস্টমাইজেশনসহ [OmniUrlField] তৈরি করে।
  const OmniUrlField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Website URL',
    this.hint = 'https://example.com',
    this.helperText,
    this.errorText,
    this.required = true,
    this.requiredMessage = 'Please enter a URL',
    this.invalidUrlMessage = 'Please enter a valid URL (e.g. https://site.com)',
    this.showClearButton = true,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// লেবেল।
  final String? label;

  /// হিন্ট।
  final String? hint;

  /// হেল্পার টেক্সট।
  final String? helperText;

  /// এরর ওভাররাইড।
  final String? errorText;

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// URL ভুল হলে মেসেজ।
  final String invalidUrlMessage;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// অটো-ভ্যালিডেট মোড।
  final AutovalidateMode? autovalidateMode;

  /// মান পরিবর্তনে কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// সক্রিয় অবস্থা।
  final bool enabled;

  /// রিড-অনলি মোড।
  final bool readOnly;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) => OmniTextField(
    controller: controller,
    initialValue: initialValue,
    focusNode: focusNode,
    label: label,
    hint: hint,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: Icon(OmniFieldIdentity.url.defaultIcon),
    keyboardType: TextInputType.url,
    textInputAction: TextInputAction.next,
    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
    showClearButton: showClearButton,
    validator:
        validator ??
        (v) => OmniValidators.url(
          v,
          required: required,
          requiredMessage: requiredMessage,
          invalidMessage: invalidUrlMessage,
        ),
    autovalidateMode: autovalidateMode,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    enabled: enabled,
    readOnly: readOnly,
    autofillHints: const [AutofillHints.url],
    fieldTheme: fieldTheme,
    fieldStyle: fieldStyle,
    decoration: decoration,
    identity: OmniFieldIdentity.url,
  );
}
