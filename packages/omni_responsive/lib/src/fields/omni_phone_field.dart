import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../omni_localization.dart';
import 'field_patterns.dart';
import 'field_identity.dart';
import 'field_theme.dart';
import 'field_texts.dart';
import 'omni_validators.dart';
import 'country_dial_code.dart';
import 'field_core.dart';

/// কান্ট্রি ডায়াল কোড পিকার, বাংলাদেশ/আন্তর্জাতিক মোবাইল নাম্বার ভ্যালিডেশন ও
/// ইনলাইন **Verify / Verified** স্টেটসহ মোবাইল নাম্বার ফিল্ড (`OmniFieldIdentity.phone`)।
class OmniPhoneField extends StatefulWidget {
  /// সব কাস্টমাইজেশনসহ [OmniPhoneField] তৈরি করে।
  const OmniPhoneField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label = 'Mobile Number',
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.leadingIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.showCountryCodePrefix = true,
    this.countryDropdownIcon = Icons.arrow_drop_down_rounded,
    this.clearIcon,
    this.verifiedIcon = Icons.verified_rounded,
    this.countryCode = '+880',
    this.countryCodes,
    this.showCountryPicker = true,
    this.validateBangladeshOperators = true,
    this.autoFormat = true,
    this.enforceCountryLength = true,
    this.showLengthCounter = true,
    this.minDigits,
    this.maxDigits,
    this.required = true,
    this.requiredMessage = 'Please enter your mobile number',
    this.invalidPhoneMessage,
    this.isVerified = false,
    this.onVerifyPressed,
    this.verifyLabel = 'Verify',
    this.verifiedLabel = 'Verified',
    this.showClearButton = true,
    this.textInputAction = TextInputAction.next,
    this.autovalidateMode,
    this.validator,
    this.onChanged,
    this.onFullNumberChanged,
    this.onCountryChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    this.decoration,
  });

  /// জনপ্রিয় দেশগুলোর ডিফল্ট ডায়াল কোড, অটো-ফরম্যাট মাস্ক ও নির্দিষ্ট ডিজিট লিমিট তালিকা।
  static const List<OmniCountryDialCode> defaultCountryCodes = [
    OmniCountryDialCode(
      dialCode: '+880',
      isoCode: 'BD',
      name: 'Bangladesh',
      flag: '🇧🇩',
      minDigits: 10,
      maxDigits: 11,
      formatMask: '#####-######',
      exampleHint: '01712-345678',
    ),
    OmniCountryDialCode(
      dialCode: '+91',
      isoCode: 'IN',
      name: 'India',
      flag: '🇮🇳',
      minDigits: 10,
      maxDigits: 10,
      formatMask: '##### #####',
      exampleHint: '98765 43210',
    ),
    OmniCountryDialCode(
      dialCode: '+92',
      isoCode: 'PK',
      name: 'Pakistan',
      flag: '🇵🇰',
      minDigits: 10,
      maxDigits: 10,
      formatMask: '### #######',
      exampleHint: '300 1234567',
    ),
    OmniCountryDialCode(
      dialCode: '+1',
      isoCode: 'US',
      name: 'United States',
      flag: '🇺🇸',
      minDigits: 10,
      maxDigits: 10,
      formatMask: '(###) ###-####',
      exampleHint: '(202) 555-0147',
    ),
    OmniCountryDialCode(
      dialCode: '+44',
      isoCode: 'GB',
      name: 'United Kingdom',
      flag: '🇬🇧',
      minDigits: 10,
      maxDigits: 11,
      formatMask: '#### ######',
      exampleHint: '7700 900077',
    ),
    OmniCountryDialCode(
      dialCode: '+971',
      isoCode: 'AE',
      name: 'UAE',
      flag: '🇦🇪',
      minDigits: 9,
      maxDigits: 9,
      formatMask: '## ### ####',
      exampleHint: '50 123 4567',
    ),
    OmniCountryDialCode(
      dialCode: '+966',
      isoCode: 'SA',
      name: 'Saudi Arabia',
      flag: '🇸🇦',
      minDigits: 9,
      maxDigits: 9,
      formatMask: '## ### ####',
      exampleHint: '50 123 4567',
    ),
    OmniCountryDialCode(
      dialCode: '+60',
      isoCode: 'MY',
      name: 'Malaysia',
      flag: '🇲🇾',
      minDigits: 9,
      maxDigits: 10,
      formatMask: '##-### #####',
      exampleHint: '12-345 6789',
    ),
    OmniCountryDialCode(
      dialCode: '+65',
      isoCode: 'SG',
      name: 'Singapore',
      flag: '🇸🇬',
      minDigits: 8,
      maxDigits: 8,
      formatMask: '#### ####',
      exampleHint: '8123 4567',
    ),
    OmniCountryDialCode(
      dialCode: '+61',
      isoCode: 'AU',
      name: 'Australia',
      flag: '🇦🇺',
      minDigits: 9,
      maxDigits: 9,
      formatMask: '### ### ###',
      exampleHint: '412 345 678',
    ),
  ];

  /// বাহ্যিক কন্ট্রোলার।
  final TextEditingController? controller;

  /// প্রাথমিক মান।
  final String? initialValue;

  /// ফোকাস নোড।
  final FocusNode? focusNode;

  /// লেবেল।
  final String? label;

  /// হিন্ট (ডিফল্ট নির্বাচিত দেশের উদাহরণ)।
  final String? hint;

  /// হেল্পার টেক্সট।
  final String? helperText;

  /// এরর ওভাররাইড।
  final String? errorText;

  /// কাস্টম প্রিফিক্স আইকন (দিলে সম্পূর্ণ বাম দিকের ডায়াল কোড অংশ প্রতিস্থাপন করে)।
  final Widget? prefixIcon;

  /// ডায়াল কোড পিলের ভেতরে আইকন দেখাতে চাইলে দিন (যেমন `Icon(Icons.phone)`).
  final Widget? leadingIcon;

  /// ইনপুটের ভেতরে প্রিফিক্স উইজেট।
  final Widget? prefix;

  /// কাস্টম সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// ইনপুটের ভেতরে সাফিক্স উইজেট।
  final Widget? suffix;

  /// বাম দিকের প্রিফিক্স/ডায়াল কোড আইকন দেখাবে কি না।
  final bool showPrefixIcon;

  /// বাম দিকে কান্ট্রি ডায়াল কোড (`+880`) দেখাবে কি না।
  final bool showCountryCodePrefix;

  /// কান্ট্রি কোড ড্রপডাউনের আইকন।
  final IconData countryDropdownIcon;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

  /// ভেরিফায়েড ব্যাজের আইকন।
  final IconData verifiedIcon;

  /// ডিফল্ট কান্ট্রি ডায়াল কোড (`'+880'` ইত্যাদি)।
  final String countryCode;

  /// কাস্টম কান্ট্রি কোড তালিকা (না দিলে [defaultCountryCodes])।
  final List<OmniCountryDialCode>? countryCodes;

  /// ডায়াল কোড ট্যাপ করে পরিবর্তন করা যাবে কি না।
  final bool showCountryPicker;

  /// `+880` হলে বাংলাদেশি অপারেটর (`013`–`019`) যাচাই করবে কি না।
  final bool validateBangladeshOperators;

  /// নির্বাচিত দেশের ফরম্যাট মাস্ক (`01712-345678`, `(202) 555-0147` ইত্যাদি) স্বয়ংক্রিয়ভাবে প্রয়োগ করবে কি না।
  final bool autoFormat;

  /// দেশের সর্বোচ্চ ডিজিট সীমা কঠোরভাবে আটকে দেবে কি না (বেশি ডিজিট উঠবে না)।
  final bool enforceCountryLength;

  /// ডানদিকে ডিজিট সংখ্যা কাউন্টার (`11/11`) দেখাবে কি না।
  final bool showLengthCounter;

  /// আন্তর্জাতিক ন্যূনতম ডিজিট ওভাররাইড।
  final int? minDigits;

  /// আন্তর্জাতিক সর্বোচ্চ ডিজিট ওভাররাইড।
  final int? maxDigits;

  /// খালি রাখা যাবে কি না।
  final bool required;

  /// খালি থাকলে এরর মেসেজ।
  final String requiredMessage;

  /// নাম্বার ভুল হলে কাস্টম এরর মেসেজ (`null` হলে দেশ অনুযায়ী অটো মেসেজ)।
  final String? invalidPhoneMessage;

  /// নাম্বার ইতিমধ্যে ভেরিফাই হয়ে গেছে কি না।
  final bool isVerified;

  /// `Verify` বাটনে ট্যাপ কলব্যাক (দিলে ইনলাইন Verify বাটন দেখায়)।
  final VoidCallback? onVerifyPressed;

  /// Verify বাটনের টেক্সট।
  final String verifyLabel;

  /// Verified ব্যাজের টেক্সট।
  final String verifiedLabel;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// কিবোর্ড অ্যাকশন।
  final TextInputAction? textInputAction;

  /// অটো-ভ্যালিডেট মোড।
  final AutovalidateMode? autovalidateMode;

  /// কাস্টম ভ্যালিডেটর।
  final FormFieldValidator<String>? validator;

  /// লোকাল ইনপুট পরিবর্তনের কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// পূর্ণ E.164 নাম্বার (`+88017...`) কলব্যাক।
  final ValueChanged<String>? onFullNumberChanged;

  /// কান্ট্রি কোড পরিবর্তনে কলব্যাক।
  final ValueChanged<OmniCountryDialCode>? onCountryChanged;

  /// সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// সক্রিয় কি না।
  final bool enabled;

  /// রিড-অনলি মোড কি না।
  final bool readOnly;

  /// অটো-ফোকাস কি না।
  final bool autofocus;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  State<OmniPhoneField> createState() => _OmniPhoneFieldState();
}

class _OmniPhoneFieldState extends State<OmniPhoneField>
    with FieldRebuildFilter<OmniPhoneField> {
  TextEditingController? _ownedController;
  late OmniCountryDialCode _selectedCountry;
  bool _syncingFormat = false;

  TextEditingController get _ctrl => widget.controller ?? _ownedController!;

  List<OmniCountryDialCode> get _countries =>
      widget.countryCodes ?? OmniPhoneField.defaultCountryCodes;

  OmniCountryDialCode _resolveCountry(String dialCode) {
    for (final c in _countries) {
      if (c.dialCode == dialCode) return c;
    }
    return OmniCountryDialCode(dialCode: dialCode, isoCode: '', name: dialCode);
  }

  String _formatForCountry(String raw) {
    if (widget.autoFormat) {
      return _selectedCountry.formatDigits(
        raw,
        overrideMax: widget.enforceCountryLength ? widget.maxDigits : null,
      );
    }
    if (!widget.enforceCountryLength) return raw;
    final digitsOnly = raw.replaceAll(fieldReNonDigit, '');
    final maxAllowed = _selectedCountry.effectiveMaxDigits(
      digitsOnly,
      overrideMax: widget.maxDigits,
    );
    return digitsOnly.length > maxAllowed
        ? digitsOnly.substring(0, maxAllowed)
        : digitsOnly;
  }

  @override
  void initState() {
    super.initState();
    _selectedCountry = _resolveCountry(widget.countryCode);
    final initial = widget.initialValue ?? '';
    if (widget.controller == null) {
      _ownedController = TextEditingController(
        text: initial.isEmpty ? '' : _formatForCountry(initial),
      );
    } else if (widget.autoFormat && _ctrl.text.isNotEmpty) {
      final formatted = _formatForCountry(_ctrl.text);
      if (formatted != _ctrl.text) {
        _ctrl.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
    _ctrl.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant OmniPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryCode != widget.countryCode) {
      _selectedCountry = _resolveCountry(widget.countryCode);
      final reformatted = _formatForCountry(_ctrl.text);
      if (reformatted != _ctrl.text) {
        _syncingFormat = true;
        _ctrl.value = TextEditingValue(
          text: reformatted,
          selection: TextSelection.collapsed(offset: reformatted.length),
        );
        _syncingFormat = false;
      }
    }
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_handleChange);
      if (widget.controller == null) {
        _ownedController ??= TextEditingController(
          text: _formatForCountry(
            oldWidget.controller?.text ?? widget.initialValue ?? '',
          ),
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

  String? _defaultValidate(String? v) => OmniValidators.phone(
    v,
    countryCode: _selectedCountry.dialCode,
    countryName: _selectedCountry.name,
    required: widget.required,
    validateBangladeshOperators: widget.validateBangladeshOperators,
    minDigits: widget.minDigits ?? _selectedCountry.minDigits,
    maxDigits: widget.maxDigits ?? _selectedCountry.maxDigits,
    requiredMessage: widget.requiredMessage,
    invalidMessage: widget.invalidPhoneMessage,
  );

  void _notifyChanged(String val) {
    if (_syncingFormat) return;
    final formatted = (widget.autoFormat || widget.enforceCountryLength)
        ? _formatForCountry(val)
        : val;
    if (formatted != _ctrl.text) {
      _syncingFormat = true;
      _ctrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _syncingFormat = false;
    }
    widget.onChanged?.call(formatted);
    widget.onFullNumberChanged?.call(
      OmniValidators.normalizePhone(
        formatted,
        countryCode: _selectedCountry.dialCode,
      ),
    );
  }

  Future<void> _openCountryPicker() async {
    if (!widget.showCountryPicker || !widget.enabled || widget.readOnly) {
      return;
    }
    final picked = await showDialog<OmniCountryDialCode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(trField('Select Country Code')),
        children: [
          for (final c in _countries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Row(
                children: [
                  if (c.flag.isNotEmpty) ...[
                    Text(c.flag),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: Text('${c.name} (${c.isoCode})')),
                  Text(
                    c.dialCode,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCountry = picked);
      final reformatted = _formatForCountry(_ctrl.text);
      _syncingFormat = true;
      _ctrl.value = TextEditingValue(
        text: reformatted,
        selection: TextSelection.collapsed(offset: reformatted.length),
      );
      _syncingFormat = false;
      widget.onCountryChanged?.call(picked);
      _notifyChanged(reformatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.phone,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: widget.fieldStyle,
      showClearButtonOverride: widget.showClearButton,
      showPrefixIconOverride: widget.showPrefixIcon,
      clearIconOverride: widget.clearIcon,
      autovalidateModeOverride: widget.autovalidateMode,
    );

    final raw = _ctrl.text.trim();
    final digitsOnly = raw.replaceAll(fieldReNonDigit, '');
    final maxAllowed = _selectedCountry.effectiveMaxDigits(
      digitsOnly,
      overrideMax: widget.maxDigits,
    );
    final isValid = raw.isNotEmpty && _defaultValidate(raw) == null;

    final Widget? dialPrefix;
    if (!config.showPrefixIcon || !widget.showPrefixIcon) {
      dialPrefix = null;
    } else if (widget.prefixIcon != null) {
      dialPrefix = widget.prefixIcon;
    } else if (!widget.showCountryCodePrefix) {
      dialPrefix = config.resolvePrefixIcon(
        widget.leadingIcon,
        OmniFieldIdentity.phone.defaultIcon,
      );
    } else {
      dialPrefix = InkWell(
        borderRadius: config.borderRadius,
        onTap: widget.showCountryPicker ? _openCountryPicker : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leadingIcon != null) ...[
                widget.leadingIcon!,
                const SizedBox(width: 4),
              ],
              if (_selectedCountry.flag.isNotEmpty) ...[
                Text(_selectedCountry.flag),
                const SizedBox(width: 4),
              ],
              Text(
                _selectedCountry.dialCode,
                style: config.textStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.showCountryPicker)
                Icon(
                  widget.countryDropdownIcon,
                  size: 18,
                  color: config.prefixIconColor,
                ),
            ],
          ),
        ),
      );
    }

    final suffix = combineSuffixWidgets([
      if (widget.showLengthCounter && !widget.isVerified)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            config.localeState.useLocaleDigits
                ? OmniText.formatDigits(
                    '${digitsOnly.length}/$maxAllowed',
                    language: config.localeState.language,
                  )
                : '${digitsOnly.length}/$maxAllowed',
            style: config.ui.text.caption.copyWith(
              color: isValid
                  ? config.successColor
                  : config.ui.colors.secondaryTextColor,
              fontWeight: isValid ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      if (widget.isVerified)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Chip(
            visualDensity: VisualDensity.compact,
            backgroundColor: config.successColor.withValues(alpha: 0.14),
            side: BorderSide.none,
            avatar: Icon(
              widget.verifiedIcon,
              size: 16,
              color: config.successColor,
            ),
            label: Text(
              trField(widget.verifiedLabel, config.localeState),
              style: config.ui.text.caption.copyWith(
                color: config.successColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        )
      else if (widget.onVerifyPressed != null)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextButton(
            onPressed: widget.enabled && isValid
                ? widget.onVerifyPressed
                : null,
            child: Text(trField(widget.verifyLabel, config.localeState)),
          ),
        )
      else if (isValid && config.showValidationIcons)
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
          !widget.isVerified &&
          _ctrl.text.isNotEmpty)
        IconButton(
          tooltip: 'Clear phone',
          icon: Icon(config.clearIcon, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            _notifyChanged('');
          },
        ),
      config.resolveSuffixIcon(widget.suffixIcon),
    ]);

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint ?? _selectedCountry.exampleHint,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: dialPrefix,
      prefix: widget.prefix,
      suffixIcon: suffix,
      suffix: widget.suffix,
      enabled: widget.enabled,
      customDecoration: widget.decoration,
      activeBorderOverride: (widget.isVerified || isValid)
          ? config.successColor
          : null,
    );

    final formatters = <TextInputFormatter>[
      if (widget.autoFormat)
        _CountryPhoneMaskFormatter(
          country: _selectedCountry,
          maxDigitsOverride: widget.enforceCountryLength
              ? widget.maxDigits
              : null,
        )
      else ...[
        FilteringTextInputFormatter.digitsOnly,
        if (widget.enforceCountryLength)
          LengthLimitingTextInputFormatter(maxAllowed),
      ],
    ];

    return OmniFieldInputShell(
      config: config,
      controller: _ctrl,
      decoration: decoration,
      label: widget.label,
      focusNode: widget.focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      inputFormatters: formatters,
      validator: widget.validator ?? _defaultValidate,
      onChanged: _notifyChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      autofillHints: const [AutofillHints.telephoneNumber],
    );
  }
}

class _CountryPhoneMaskFormatter extends TextInputFormatter {
  const _CountryPhoneMaskFormatter({
    required this.country,
    this.maxDigitsOverride,
  });

  final OmniCountryDialCode country;
  final int? maxDigitsOverride;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newDigitsBeforeCursor = _countDigitsBefore(
      newValue.text,
      newValue.selection.end,
    );
    final formatted = country.formatDigits(
      newValue.text,
      overrideMax: maxDigitsOverride,
    );
    final cursorOffset = _offsetAfterDigits(formatted, newDigitsBeforeCursor);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  static int _countDigitsBefore(String text, int selectionEnd) {
    final limit = selectionEnd.clamp(0, text.length);
    var count = 0;
    for (var i = 0; i < limit; i++) {
      final cu = text.codeUnitAt(i);
      if (cu >= 48 && cu <= 57) count++;
    }
    return count;
  }

  static int _offsetAfterDigits(String formatted, int targetDigits) {
    if (targetDigits <= 0) {
      // Skip leading decorative separator like '(' if typing starts right inside mask:
      var firstDigitSlot = 0;
      while (firstDigitSlot < formatted.length) {
        final cu = formatted.codeUnitAt(firstDigitSlot);
        if (cu >= 48 && cu <= 57) break;
        firstDigitSlot++;
      }
      return firstDigitSlot;
    }
    var count = 0;
    for (var i = 0; i < formatted.length; i++) {
      final cu = formatted.codeUnitAt(i);
      if (cu >= 48 && cu <= 57) {
        count++;
        if (count == targetDigits) return i + 1;
      }
    }
    return formatted.length;
  }
}
