import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'field_identity.dart';
import 'field_theme.dart';
import 'omni_validators.dart';
import 'field_core.dart';

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
    this.prefix,
    this.suffixIcon,
    this.suffixText,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton = false,
    this.clearIcon,
    this.decrementIcon = Icons.remove_rounded,
    this.incrementIcon = Icons.add_rounded,
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
    this.prefix,
    this.suffixIcon,
    this.suffixText,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton = false,
    this.clearIcon,
    this.decrementIcon = Icons.remove_rounded,
    this.incrementIcon = Icons.add_rounded,
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
    this.prefix,
    this.suffixIcon,
    this.suffixText,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton = false,
    this.clearIcon,
    this.decrementIcon = Icons.remove_rounded,
    this.incrementIcon = Icons.add_rounded,
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
    this.prefix,
    this.suffixIcon,
    this.suffixText,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton = false,
    this.clearIcon,
    this.decrementIcon = Icons.remove_rounded,
    this.incrementIcon = Icons.add_rounded,
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

  /// ইনপুটের ভেতরে প্রিফিক্স উইজেট।
  final Widget? prefix;

  /// সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// সাফিক্স টেক্সট (`'kg'`, `'%'` ইত্যাদি)।
  final String? suffixText;

  /// ইনপুটের ভেতরে সাফিক্স উইজেট।
  final Widget? suffix;

  /// প্রিফিক্স আইকন দেখাবে কি না (`false` দিলে আইকন ছাড়া)।
  final bool showPrefixIcon;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

  /// স্টেপার `-` বাটনের কাস্টম আইকন।
  final IconData decrementIcon;

  /// স্টেপার `+` বাটনের কাস্টম আইকন।
  final IconData incrementIcon;

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

class _OmniNumberFieldState extends State<OmniNumberField>
    with FieldRebuildFilter<OmniNumberField> {
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
    rebuildIfShownChanged(_ctrl.text);
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
    return widget.allowDecimal ? double.tryParse(clean) : int.tryParse(clean);
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

  RegExp? _numberRegex;
  (bool, bool, int)? _numberRegexKey;

  /// The input pattern, recompiled only when its options change.
  RegExp _numberPattern() {
    final key = (
      widget.allowNegative,
      widget.allowDecimal,
      math.max(0, widget.decimalRange),
    );
    final cached = _numberRegex;
    if (cached != null && key == _numberRegexKey) return cached;
    final negPrefix = key.$1 ? '-?' : '';
    _numberRegexKey = key;
    return _numberRegex = key.$2
        ? RegExp('^$negPrefix\\d*(?:\\.\\d{0,${key.$3}})?\$')
        : RegExp('^$negPrefix\\d*\$');
  }

  List<TextInputFormatter> _buildFormatters() {
    return [
      TextInputFormatter.withFunction((oldValue, newValue) {
        final t = newValue.text;
        if (t.isEmpty) return newValue;
        return _numberPattern().hasMatch(t) ? newValue : oldValue;
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
    final config = ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.number,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: widget.fieldStyle,
      showClearButtonOverride: widget.showClearButton,
      showPrefixIconOverride: widget.showPrefixIcon,
      clearIconOverride: widget.clearIcon,
      autovalidateModeOverride: widget.autovalidateMode,
    );

    final suffix = combineSuffixWidgets([
      if (config.showClearButton &&
          widget.enabled &&
          !widget.readOnly &&
          _ctrl.text.isNotEmpty)
        IconButton(
          tooltip: 'Clear number',
          icon: Icon(config.clearIcon, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            widget.onChanged?.call('');
            widget.onNumberChanged?.call(null);
          },
        ),
      if (widget.showStepper && widget.enabled && !widget.readOnly) ...[
        IconButton(
          tooltip: 'Decrease',
          visualDensity: VisualDensity.compact,
          icon: Icon(widget.decrementIcon, color: config.suffixIconColor),
          onPressed: () => _applyDelta(-widget.step),
        ),
        IconButton(
          tooltip: 'Increase',
          visualDensity: VisualDensity.compact,
          icon: Icon(widget.incrementIcon, color: config.accentColor),
          onPressed: () => _applyDelta(widget.step),
        ),
      ],
      config.resolveSuffixIcon(widget.suffixIcon),
    ]);

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixText: widget.prefixText,
      suffixText: widget.suffixText,
      prefixIcon: config.resolvePrefixIcon(
        widget.prefixIcon,
        OmniFieldIdentity.number.defaultIcon,
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
