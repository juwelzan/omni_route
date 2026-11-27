import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'field_patterns.dart';
import 'field_identity.dart';
import 'field_theme.dart';
import 'omni_validators.dart';
import 'omni_text_field.dart';

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
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.required = true,
    this.requiredMessage = 'Please enter a URL',
    this.invalidUrlMessage = 'Please enter a valid URL (e.g. https://site.com)',
    this.showClearButton = true,
    this.clearIcon,
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

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// URL ভুল হলে মেসেজ।
  final String invalidUrlMessage;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

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
    prefixIcon: prefixIcon,
    prefix: prefix,
    suffixIcon: suffixIcon,
    suffix: suffix,
    showPrefixIcon: showPrefixIcon,
    keyboardType: TextInputType.url,
    textInputAction: TextInputAction.next,
    inputFormatters: [FilteringTextInputFormatter.deny(fieldReSpace)],
    showClearButton: showClearButton,
    clearIcon: clearIcon,
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
