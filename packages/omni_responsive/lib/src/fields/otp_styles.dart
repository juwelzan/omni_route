import 'package:flutter/material.dart';

import 'omni_otp_field.dart';

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

  /// রাবার-স্প্রিং ওভারশুটসহ প্রাণবন্ত পপ-ইন ও বক্স বাউন্স।
  spring,

  /// মসৃণ আলফা ফেডে দেখা যায়।
  fade,

  /// নিচ থেকে ওপর দিকে স্লাইড হয়ে আসে।
  slide,

  /// ওপর থেকে নিচে মসৃণ ড্রপ ও সেটল অ্যানিমেশন।
  drop,

  /// হালকা রোটেট-স্কেল অ্যানিমেশনে আসে।
  rotation,

  /// ৩ডি কার্ড ফ্লিপ হয়ে সংখ্যাটি প্রকাশ পায়।
  flip,

  /// মসৃণ জুম-ক্ল্যারিটি ফেড ইন।
  blur,

  /// অ্যানিমেশন ছাড়া তাৎক্ষণিক দেখায়।
  none,
}

/// OTP / পিন ভেরিফিকেশন ফিল্ডের বর্তমান অবস্থা।
enum OmniOtpStatus {
  /// সাধারণ ইনপুট নেওয়ার অবস্থা।
  idle,

  /// কোড যাচাই (API/লোকাল) চলছে।
  verifying,

  /// সতর্কবার্তা অবস্থা (যেমন সময় শেষ হচ্ছে বা সীমিত প্রচেষ্টা)।
  warning,

  /// ভুল কোড বা অসম্পূর্ণ ইনপুট এরর অবস্থা।
  error,

  /// সফলভাবে ভেরিফাই সম্পন্ন অবস্থা।
  verified,
}

/// OTP এরর অবস্থায় কী ধরনের অ্যানিমেশন চলবে।
enum OmniOtpErrorAnimation {
  /// ড্যাম্পড স্প্রিং ডানে-বামে ঝাঁকুনি (ডিফল্ট)।
  shake,

  /// প্রতিটি বক্স আলাদা ফেজে ঢেউ খেলানো ক্যাওটিক ঝাঁকি দেয়।
  staggerShake,

  /// বক্সগুলো হালকা কাত (Z-tilt) হয়ে ডানে-বামে সতর্ক করে।
  tiltShake,

  /// রাবার/জেলির মতো স্কোয়াশ অ্যান্ড স্ট্রেচ মোশন।
  jello,

  /// ওপর-নিচে লাফিয়ে সতর্ক করে।
  bounce,

  /// হালকা স্কেল থ্রব পালস।
  pulse,

  /// লাল রঙের ডাবল উজ্জ্বল গ্লো ফ্ল্যাশ।
  flash,

  /// কোনো এক্সট্রা মোশন ছাড়াই এরর বর্ডার।
  none,
}

/// OTP ওয়ার্নিং অবস্থায় কী ধরনের অ্যানিমেশন চলবে।
enum OmniOtpWarningAnimation {
  /// অ্যাম্বার রঙে মসৃণ শ্বাস-প্রশ্বাসের মতো পালস (ডিফল্ট)।
  pulse,

  /// ডাবল হৃৎস্পন্দনের (`lub-dub`) মতো সতর্কতা পালস।
  heartbeat,

  /// বাম থেকে ডানে প্রতিটি বক্স ঢেউয়ের মতো হালকা নেচে ওঠে।
  waveBounce,

  /// অ্যাম্বার আলোর ঝলক বাম থেকে ডানে বয়ে যায়।
  shimmer,

  /// বক্সগুলো হালকা কাত হয়ে সতর্ক দৃষ্টি আকর্ষণ করে।
  tilt,

  /// হালকা ডানে-বামে দুলুনি ওয়াবল।
  wobble,

  /// হালকা লাফ দিয়ে ওয়ার্নিং অ্যাটেনশন।
  bounce,

  /// অ্যাম্বার হ্যালো গ্লো অ্যানিমেশন।
  glow,

  /// অ্যানিমেশন ছাড়া শুধু ওয়ার্নিং বার্তা।
  none,
}

/// OTP ভেরিফাই সফল হলে বক্সগুলোর কী ধরনের অ্যানিমেশন হবে।
enum OmniOtpVerifiedAnimation {
  /// সবগুলো বক্স কোণ গোল করে একসঙ্গে মাঝখানে মিলিত হয়ে শকওয়েভ ও স্পার্কসহ গোল সবুজ টিক চিহ্নে রূপ নেয় (ডিফল্ট)।
  mergeCheck,

  /// সবগুলো বক্স একসাথে মাঝখানে মিশে স্পার্কলসহ সবুজ ক্যাপসুল পিল (`✓ Verified`) হয়।
  morphPill,

  /// বক্সগুলো তাসের ডেকের মতো একটার ওপর আরেকটা ভাঁজ হয়ে মাঝখানে সবুজ টিক ব্যাজে পরিণত হয়।
  stackMerge,

  /// বক্সগুলো বাম থেকে ডানে ঢেউয়ের মতো লাফিয়ে সবুজ টিক চিহ্নে রূপ নেয়।
  waveCheck,

  /// মাঝের বক্সগুলো থেকে দুই দিকে রিপল তরঙ্গের মতো সবুজ হয়ে টিক চিহ্ন ছড়িয়ে পড়ে।
  rippleCheck,

  /// প্রতিটি বক্স ঢেউয়ের মতো সবুজ হয়ে ভেতরে টিক চিহ্ন ফুটে ওঠে।
  expandCheck,

  /// প্রতিটি বক্স ৩ডি কার্ড ফ্লিপ করে সবুজ টিক চিহ্নে ঘুরে যায়।
  flipCheck,

  /// বক্সগুলো সবুজ হওয়ার পাশাপাশি ওপরে বর্ণিল কনফেটি পার্টিকেল ছড়িয়ে দেয়।
  confettiBurst,

  /// অক্ষর রেখে শুধু সবুজ বর্ডার ও ভেরিফাই ব্যাজ দেখায়।
  badgeOnly,
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
