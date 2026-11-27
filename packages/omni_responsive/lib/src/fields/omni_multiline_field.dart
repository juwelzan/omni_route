import 'package:flutter/material.dart';

import 'field_identity.dart';
import 'field_theme.dart';
import 'omni_text_field.dart';

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
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton,
    this.clearIcon,
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

  /// কাস্টম প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// ইনপুটের ভেতরে প্রিফিক্স উইজেট।
  final Widget? prefix;

  /// কাস্টম সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// ইনপুটের ভেতরে সাফিক্স উইজেট।
  final Widget? suffix;

  /// প্রিফিক্স আইকন দেখাবে কি না।
  final bool showPrefixIcon;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool? showClearButton;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

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
    prefixIcon: prefixIcon,
    prefix: prefix,
    suffixIcon: suffixIcon,
    suffix: suffix,
    showPrefixIcon: showPrefixIcon,
    showClearButton: showClearButton,
    clearIcon: clearIcon,
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
