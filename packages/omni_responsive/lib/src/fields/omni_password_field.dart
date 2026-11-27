import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'field_identity.dart';
import 'field_theme.dart';
import 'field_texts.dart';
import 'omni_validators.dart';
import 'field_core.dart';

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

class _OmniPasswordFieldState extends State<OmniPasswordField>
    with FieldRebuildFilter<OmniPasswordField> {
  @override
  Object? shownFrom(String text) =>
      (text, widget.matchController?.text ?? widget.matchValue);

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
    rebuildIfShownChanged(_ctrl.text);
  }

  void _onMatchChanged() {
    rebuildIfShownChanged(_ctrl.text);
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
        return widget.required ? trField(widget.requiredMessage) : null;
      }
      if (v != target) return trField(widget.mismatchMessage);
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
    final config = ResolvedFieldConfig.of(
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

    final suffix = combineSuffixWidgets([
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

    final input = OmniFieldInputShell(
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
                        color: filled
                            ? barColor
                            : config.ui.colors.dividerColor,
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
                trField(
                  widget.strengthLabels[(score - 1).clamp(
                    0,
                    widget.strengthLabels.length - 1,
                  )],
                  config.localeState,
                ),
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
