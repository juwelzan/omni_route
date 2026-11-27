import 'package:flutter/material.dart';

import 'field_patterns.dart';
import 'omni_phone_field.dart';

/// মোবাইল কান্ট্রি ডায়াল কোড মডেল ([OmniPhoneField])-এর জন্য।
@immutable
class OmniCountryDialCode {
  /// কান্ট্রি কোড, ডিজিট লিমিট ও অটো-ফরম্যাট মাস্কসহ [OmniCountryDialCode] তৈরি করে।
  const OmniCountryDialCode({
    required this.dialCode,
    required this.isoCode,
    required this.name,
    this.flag = '',
    this.minDigits = 7,
    this.maxDigits = 15,
    this.formatMask = '',
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

  /// `#` ভিত্তিক অটো-ফরম্যাট মাস্ক (যেমন `'#####-######'`, `'(###) ###-####'`)।
  final String formatMask;

  /// উদাহরণ প্লেসহোল্ডার।
  final String exampleHint;

  /// ইনপুটকৃত ডিজিট অনুযায়ী সর্বোচ্চ ডিজিট সীমা রিটার্ন করে।
  int effectiveMaxDigits(String rawDigits, {int? overrideMax}) {
    if (overrideMax != null) return overrideMax;
    if (dialCode == '+880') {
      return (rawDigits.isEmpty || rawDigits.startsWith('0')) ? 11 : 10;
    }
    return maxDigits;
  }

  /// কাঁচা ডিজিটগুলোকে [formatMask] অনুযায়ী সুন্দরভাবে ফরম্যাট ও ক্ল্যাম্প করে।
  String formatDigits(String rawInput, {int? overrideMax}) {
    final rawDigits = rawInput.replaceAll(fieldReNonDigit, '');
    if (rawDigits.isEmpty) return '';
    final maxLen = effectiveMaxDigits(rawDigits, overrideMax: overrideMax);
    final digits = rawDigits.length > maxLen
        ? rawDigits.substring(0, maxLen)
        : rawDigits;

    final activeMask = dialCode == '+880' && !digits.startsWith('0')
        ? '####-######'
        : formatMask;

    if (activeMask.isEmpty) return digits;

    final buf = StringBuffer();
    var dIdx = 0;
    for (
      var mIdx = 0;
      mIdx < activeMask.length && dIdx < digits.length;
      mIdx++
    ) {
      final ch = activeMask[mIdx];
      if (ch == '#') {
        buf.write(digits[dIdx]);
        dIdx++;
      } else {
        buf.write(ch);
      }
    }
    while (dIdx < digits.length) {
      buf.write(digits[dIdx]);
      dIdx++;
    }
    return buf.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniCountryDialCode &&
          dialCode == other.dialCode &&
          isoCode == other.isoCode;

  @override
  int get hashCode => Object.hash(dialCode, isoCode);
}
