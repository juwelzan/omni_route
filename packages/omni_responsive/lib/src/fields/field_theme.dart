import 'package:flutter/material.dart';

import '../omni_styles.dart';
import 'field_identity.dart';
import 'otp_styles.dart';

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
  OmniFieldTheme lerp(
    covariant ThemeExtension<OmniFieldTheme>? other,
    double t,
  ) {
    if (other is! OmniFieldTheme) return this;
    return OmniFieldTheme(
      variant: t < 0.5 ? variant : other.variant,
      labelMode: t < 0.5 ? labelMode : other.labelMode,
      labelSpacing: labelSpacing + (other.labelSpacing - labelSpacing) * t,
      borderRadius: t < 0.5 ? borderRadius : other.borderRadius,
      borderWidth: t < 0.5 ? borderWidth : other.borderWidth,
      focusedBorderWidth: t < 0.5
          ? focusedBorderWidth
          : other.focusedBorderWidth,
      fillColor: Color.lerp(fillColor, other.fillColor, t),
      darkFillColor: Color.lerp(darkFillColor, other.darkFillColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      darkBorderColor: Color.lerp(darkBorderColor, other.darkBorderColor, t),
      focusedBorderColor: Color.lerp(
        focusedBorderColor,
        other.focusedBorderColor,
        t,
      ),
      darkFocusedBorderColor: Color.lerp(
        darkFocusedBorderColor,
        other.darkFocusedBorderColor,
        t,
      ),
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
      showValidationIcons: t < 0.5
          ? showValidationIcons
          : other.showValidationIcons,
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
