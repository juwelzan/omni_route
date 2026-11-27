import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'field_patterns.dart';
import 'field_identity.dart';
import 'field_theme.dart';
import 'omni_validators.dart';
import 'field_core.dart';

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
    this.invalidGmailMessage =
        'Please enter a valid Gmail address (@gmail.com)',
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

class _OmniEmailFieldState extends State<OmniEmailField>
    with FieldRebuildFilter<OmniEmailField> {
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
    rebuildIfShownChanged(_ctrl.text);
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
    final config = ResolvedFieldConfig.of(
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

    final suffix = combineSuffixWidgets([
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

    return OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: widget.label,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.emailAddress,
      textInputAction: widget.textInputAction,
      inputFormatters: [FilteringTextInputFormatter.deny(fieldReSpace)],
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
