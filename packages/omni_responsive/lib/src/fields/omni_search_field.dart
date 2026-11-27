import 'dart:async';

import 'package:flutter/material.dart';

import 'field_identity.dart';
import 'field_theme.dart';
import 'field_core.dart';

/// ডিবাউন্স সার্চ, ক্লিয়ার বাটন ও পিল-শেপ সাপোর্টসহ সার্চ ইনপুট (`OmniFieldIdentity.search`)।
class OmniSearchField extends StatefulWidget {
  /// সব কাস্টমাইজেশনসহ [OmniSearchField] তৈরি করে।
  const OmniSearchField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.hint = 'Search...',
    this.label,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.suffix,
    this.showPrefixIcon = true,
    this.showClearButton = true,
    this.clearIcon,
    this.filterIcon = Icons.tune_rounded,
    this.debounceDuration = const Duration(milliseconds: 280),
    this.onChanged,
    this.onSearchChanged,
    this.onSubmitted,
    this.onFilterPressed,
    this.pillShape = true,
    this.enabled = true,
    this.autofocus = false,
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

  /// হিন্ট টেক্সট।
  final String? hint;

  /// ঐচ্ছিক লেবেল।
  final String? label;

  /// কাস্টম সার্চ/প্রিফিক্স আইকন।
  final Widget? prefixIcon;

  /// ইনপুটের ভেতরে প্রিফিক্স উইজেট।
  final Widget? prefix;

  /// অতিরিক্ত কাস্টম সাফিক্স আইকন।
  final Widget? suffixIcon;

  /// ইনপুটের ভেতরে সাফিক্স উইজেট।
  final Widget? suffix;

  /// সার্চ প্রিফিক্স আইকন দেখাবে কি না।
  final bool showPrefixIcon;

  /// ক্লিয়ার বাটন দেখাবে কি না।
  final bool showClearButton;

  /// ক্লিয়ার বাটনের কাস্টম আইকন।
  final IconData? clearIcon;

  /// ফিল্টার বাটনের কাস্টম আইকন।
  final IconData filterIcon;

  /// `onSearchChanged` কল হওয়ার ডিবাউন্স সময়।
  final Duration debounceDuration;

  /// তাৎক্ষণিক পরিবর্তনের কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// ডিবাউন্সড সার্চ কলব্যাক।
  final ValueChanged<String>? onSearchChanged;

  /// কিবোর্ড সার্চ সাবমিট কলব্যাক।
  final ValueChanged<String>? onSubmitted;

  /// ফিল্টার আইকনে ট্যাপ করলে কল হয় (দিলে ফিল্টার বাটন দেখায়)।
  final VoidCallback? onFilterPressed;

  /// গোল পিল কর্নার ব্যবহার করবে কি না।
  final bool pillShape;

  /// সক্রিয় অবস্থা।
  final bool enabled;

  /// অটো-ফোকাস।
  final bool autofocus;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;

  /// ডেকোরেশন ওভাররাইড।
  final InputDecoration? decoration;

  @override
  State<OmniSearchField> createState() => _OmniSearchFieldState();
}

class _OmniSearchFieldState extends State<OmniSearchField>
    with FieldRebuildFilter<OmniSearchField> {
  @override
  Object? shownFrom(String text) => text.isNotEmpty;

  TextEditingController? _ownedController;
  Timer? _debounce;

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
  void didUpdateWidget(covariant OmniSearchField oldWidget) {
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

  void _scheduleSearch(String value) {
    widget.onChanged?.call(value);
    if (widget.onSearchChanged == null) return;
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () {
      if (mounted) widget.onSearchChanged?.call(value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    (widget.controller ?? _ownedController)?.removeListener(_handleChange);
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pillOverride = widget.pillShape
        ? (widget.fieldStyle ?? const OmniFieldStyle()).copyWith(
            borderRadius: widget.fieldStyle?.borderRadius ?? 999,
          )
        : widget.fieldStyle;

    final config = ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.search,
      fieldThemeOverride: widget.fieldTheme,
      fieldStyleOverride: pillOverride,
      showClearButtonOverride: widget.showClearButton,
      showPrefixIconOverride: widget.showPrefixIcon,
      clearIconOverride: widget.clearIcon,
    );

    final suffix = combineSuffixWidgets([
      if (config.showClearButton && widget.enabled && _ctrl.text.isNotEmpty)
        IconButton(
          tooltip: 'Clear search',
          icon: Icon(config.clearIcon, color: config.suffixIconColor),
          onPressed: () {
            _ctrl.clear();
            _debounce?.cancel();
            widget.onChanged?.call('');
            widget.onSearchChanged?.call('');
          },
        ),
      if (widget.onFilterPressed != null)
        IconButton(
          tooltip: 'Filter',
          icon: Icon(widget.filterIcon, color: config.suffixIconColor),
          onPressed: widget.enabled ? widget.onFilterPressed : null,
        ),
      config.resolveSuffixIcon(widget.suffixIcon),
    ]);

    final decoration = config.buildDecoration(
      label: widget.label,
      hint: widget.hint,
      prefixIcon: config.resolvePrefixIcon(
        widget.prefixIcon,
        OmniFieldIdentity.search.defaultIcon,
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
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      onChanged: _scheduleSearch,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
    );
  }
}
