import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'field_identity.dart';
import 'field_theme.dart';
import 'field_texts.dart';
import 'field_core.dart';

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

class _OmniTextFieldState extends State<OmniTextField>
    with FieldRebuildFilter<OmniTextField> {
  @override
  Object? shownFrom(String text) => text.isNotEmpty;

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
      (oldWidget.controller ?? _ownedController)?.removeListener(
        _onTextChanged,
      );
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
    rebuildIfShownChanged(_ctrl.text);
  }

  @override
  void dispose() {
    (widget.controller ?? _ownedController)?.removeListener(_onTextChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ResolvedFieldConfig.of(
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

    final suffix = combineSuffixWidgets([
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

    return OmniFieldInputShell(
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
              ? (v) => (v ?? '').trim().isEmpty
                    ? trField(widget.requiredMessage, config.localeState)
                    : null
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
