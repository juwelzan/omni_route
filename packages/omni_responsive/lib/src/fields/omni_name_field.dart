import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'field_patterns.dart';
import 'field_identity.dart';
import 'field_theme.dart';
import 'omni_validators.dart';
import 'field_core.dart';

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

class _OmniNameFieldState extends State<OmniNameField>
    with FieldRebuildFilter<OmniNameField> {
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
    rebuildIfShownChanged(_ctrl.text);
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
    final config = ResolvedFieldConfig.of(
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

    final suffix = combineSuffixWidgets([
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
      if (!widget.allowSpaces) FilteringTextInputFormatter.deny(fieldReSpace),
      if (!widget.allowDigits) FilteringTextInputFormatter.deny(fieldReDigit),
      if (!widget.allowSpaces && widget.allowDigits)
        FilteringTextInputFormatter.allow(fieldReHandleChar),
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

    return OmniFieldInputShell(
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
