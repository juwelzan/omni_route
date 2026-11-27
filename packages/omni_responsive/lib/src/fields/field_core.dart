// Internal building blocks shared by every predefined field: resolved theme
// values, the label/decoration shell and the rebuild filter. Not exported
// from the package, so its members are not public API and are documented
// only where the intent is not obvious.
// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../omni_localization.dart';
import '../omni_styles.dart';
import 'field_identity.dart';
import 'field_theme.dart';
import 'field_texts.dart';

@immutable
class ResolvedFieldConfig {
  const ResolvedFieldConfig({
    required this.ui,
    required this.fieldTheme,
    required this.variant,
    required this.labelMode,
    required this.labelSpacing,
    required this.borderRadius,
    required this.borderWidth,
    required this.focusedBorderWidth,
    required this.fillColor,
    required this.borderColor,
    required this.focusedBorderColor,
    required this.accentColor,
    required this.errorColor,
    required this.successColor,
    required this.labelStyle,
    required this.hintStyle,
    required this.textStyle,
    required this.prefixIconColor,
    required this.suffixIconColor,
    required this.contentPadding,
    required this.isDense,
    required this.showClearButton,
    required this.showValidationIcons,
    required this.autovalidateMode,
    required this.showPrefixIcon,
    required this.clearIcon,
    required this.localeState,
    this.stylePrefixIcon,
    this.styleSuffixIcon,
  });

  final OmniUiTheme ui;
  final OmniFieldTheme fieldTheme;
  final OmniInputVariant variant;
  final OmniFieldLabelMode labelMode;
  final double labelSpacing;
  final BorderRadius borderRadius;
  final double borderWidth;
  final double focusedBorderWidth;
  final Color fillColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color accentColor;
  final Color errorColor;
  final Color successColor;
  final TextStyle labelStyle;
  final TextStyle hintStyle;
  final TextStyle textStyle;
  final Color prefixIconColor;
  final Color suffixIconColor;
  final EdgeInsetsGeometry contentPadding;
  final bool isDense;
  final bool showClearButton;
  final bool showValidationIcons;
  final AutovalidateMode autovalidateMode;
  final bool showPrefixIcon;
  final IconData clearIcon;
  final OmniLocaleState localeState;
  final Widget? stylePrefixIcon;
  final Widget? styleSuffixIcon;

  /// প্রিফিক্স আইকন রিজলভ করে (`showPrefixIcon == false` হলে `null`)।
  Widget? resolvePrefixIcon(
    Widget? widgetIcon,
    IconData defaultIcon, {
    bool widgetShowPrefixIcon = true,
  }) {
    if (!widgetShowPrefixIcon || !showPrefixIcon) return null;
    return widgetIcon ?? stylePrefixIcon ?? Icon(defaultIcon);
  }

  /// কাস্টম সাফিক্স আইকন রিজলভ করে।
  Widget? resolveSuffixIcon(Widget? widgetSuffixIcon) =>
      widgetSuffixIcon ?? styleSuffixIcon;

  factory ResolvedFieldConfig.of(
    BuildContext context, {
    required OmniFieldIdentity identity,
    OmniFieldTheme? fieldThemeOverride,
    OmniFieldStyle? fieldStyleOverride,
    bool? showClearButtonOverride,
    bool? showPrefixIconOverride,
    IconData? clearIconOverride,
    AutovalidateMode? autovalidateModeOverride,
  }) {
    final localeState = OmniL10nScope.watch(context);
    final ui = context.ui;
    final isDark = ui.isDark;
    final shared = fieldThemeOverride ?? OmniFieldTheme.of(context);
    final idStyle = shared.identityStyles[identity];
    final local = fieldStyleOverride;

    final themeInput = ui.styles.inputDecorationTheme;
    final defaultVariant = themeInput.filled
        ? OmniInputVariant.filled
        : (themeInput.enabledBorder is UnderlineInputBorder
              ? OmniInputVariant.underlined
              : OmniInputVariant.outlined);

    final variant =
        local?.variant ?? idStyle?.variant ?? shared.variant ?? defaultVariant;

    final rawRadius =
        local?.borderRadius ?? idStyle?.borderRadius ?? shared.borderRadius;
    final borderRadius = rawRadius != null
        ? BorderRadius.all(Radius.circular(rawRadius))
        : ui.styles.inputRadius;

    final themeEnabledWidth = themeInput.enabledBorder?.borderSide.width ?? 1.0;
    final themeFocusedWidth = themeInput.focusedBorder?.borderSide.width ?? 1.8;

    final borderWidth =
        local?.borderWidth ??
        idStyle?.borderWidth ??
        shared.borderWidth ??
        themeEnabledWidth;
    final focusedBorderWidth =
        local?.focusedBorderWidth ??
        idStyle?.focusedBorderWidth ??
        shared.focusedBorderWidth ??
        themeFocusedWidth;

    Color? pickMode(Color? lightC, Color? darkC) =>
        isDark ? (darkC ?? lightC) : lightC;

    final accentColor =
        pickMode(local?.accentColor, local?.darkAccentColor) ??
        pickMode(idStyle?.accentColor, idStyle?.darkAccentColor) ??
        ui.colors.primaryColor;

    final defaultFill = variant == OmniInputVariant.outlined
        ? ui.colors.cardColor
        : ui.colors.inputFillColor;
    final fillColor =
        pickMode(local?.fillColor, local?.darkFillColor) ??
        pickMode(idStyle?.fillColor, idStyle?.darkFillColor) ??
        pickMode(shared.fillColor, shared.darkFillColor) ??
        defaultFill;

    final borderColor =
        pickMode(local?.borderColor, local?.darkBorderColor) ??
        pickMode(idStyle?.borderColor, idStyle?.darkBorderColor) ??
        pickMode(shared.borderColor, shared.darkBorderColor) ??
        ui.colors.borderColor;

    final focusedBorderColor =
        pickMode(local?.focusedBorderColor, local?.darkFocusedBorderColor) ??
        pickMode(
          idStyle?.focusedBorderColor,
          idStyle?.darkFocusedBorderColor,
        ) ??
        pickMode(local?.accentColor, local?.darkAccentColor) ??
        pickMode(idStyle?.accentColor, idStyle?.darkAccentColor) ??
        pickMode(shared.focusedBorderColor, shared.darkFocusedBorderColor) ??
        ui.colors.focusedBorderColor;

    final errorColor =
        local?.errorBorderColor ??
        idStyle?.errorBorderColor ??
        shared.errorColor ??
        ui.colors.errorColor;

    final successColor =
        local?.successBorderColor ??
        idStyle?.successBorderColor ??
        shared.successColor ??
        ui.colors.successColor;

    final resolvedLabelColor =
        pickMode(shared.labelColor, shared.darkLabelColor) ??
        ui.text.label.color;
    final labelStyle =
        local?.labelStyle ??
        idStyle?.labelStyle ??
        ui.text.label.copyWith(color: resolvedLabelColor);

    final resolvedHintColor =
        pickMode(shared.hintColor, shared.darkHintColor) ?? ui.text.hint.color;
    final hintStyle =
        local?.hintStyle ??
        idStyle?.hintStyle ??
        ui.text.hint.copyWith(color: resolvedHintColor);

    final textStyle = local?.textStyle ?? idStyle?.textStyle ?? ui.text.body;

    final iconBaseColor =
        pickMode(shared.iconColor, shared.darkIconColor) ?? ui.colors.iconColor;

    final prefixIconColor =
        local?.prefixIconColor ??
        idStyle?.prefixIconColor ??
        pickMode(local?.accentColor, local?.darkAccentColor) ??
        pickMode(idStyle?.accentColor, idStyle?.darkAccentColor) ??
        iconBaseColor;

    final suffixIconColor =
        local?.suffixIconColor ?? idStyle?.suffixIconColor ?? iconBaseColor;

    final contentPadding =
        local?.contentPadding ??
        idStyle?.contentPadding ??
        shared.contentPadding ??
        (variant == OmniInputVariant.underlined
            ? const EdgeInsets.symmetric(horizontal: 2, vertical: 12)
            : ui.tokens.cardPadding);

    final isDense = local?.isDense ?? idStyle?.isDense ?? shared.isDense;
    final showClearButton =
        showClearButtonOverride ??
        local?.showClearButton ??
        idStyle?.showClearButton ??
        shared.showClearButton;
    final showPrefixIcon =
        showPrefixIconOverride ??
        local?.showPrefixIcon ??
        idStyle?.showPrefixIcon ??
        true;
    final clearIcon =
        clearIconOverride ??
        local?.clearIcon ??
        idStyle?.clearIcon ??
        Icons.close_rounded;

    return ResolvedFieldConfig(
      ui: ui,
      fieldTheme: shared,
      variant: variant,
      labelMode: shared.labelMode,
      labelSpacing: shared.labelSpacing,
      borderRadius: borderRadius,
      borderWidth: borderWidth,
      focusedBorderWidth: focusedBorderWidth,
      fillColor: fillColor,
      borderColor: borderColor,
      focusedBorderColor: focusedBorderColor,
      accentColor: accentColor,
      errorColor: errorColor,
      successColor: successColor,
      labelStyle: labelStyle,
      hintStyle: hintStyle,
      textStyle: textStyle,
      prefixIconColor: prefixIconColor,
      suffixIconColor: suffixIconColor,
      contentPadding: contentPadding,
      isDense: isDense,
      showClearButton: showClearButton,
      showValidationIcons: shared.showValidationIcons,
      autovalidateMode: autovalidateModeOverride ?? shared.autovalidateMode,
      showPrefixIcon: showPrefixIcon,
      clearIcon: clearIcon,
      localeState: localeState,
      stylePrefixIcon: local?.prefixIcon ?? idStyle?.prefixIcon,
      styleSuffixIcon: local?.suffixIcon ?? idStyle?.suffixIcon,
    );
  }

  InputBorder makeBorder(Color color, double width) {
    final side = width <= 0
        ? BorderSide.none
        : BorderSide(color: color, width: width);
    return switch (variant) {
      OmniInputVariant.underlined => UnderlineInputBorder(borderSide: side),
      OmniInputVariant.filled || OmniInputVariant.outlined =>
        OutlineInputBorder(borderRadius: borderRadius, borderSide: side),
    };
  }

  InputDecoration buildDecoration({
    String? label,
    String? hint,
    String? helperText,
    String? errorText,
    String? prefixText,
    String? suffixText,
    Widget? prefixIcon,
    Widget? prefix,
    Widget? suffixIcon,
    Widget? suffix,
    Widget? counter,
    bool enabled = true,
    InputDecoration? customDecoration,
    Color? activeBorderOverride,
  }) {
    final effectiveEnabledBorder = makeBorder(
      activeBorderOverride ?? borderColor,
      borderWidth,
    );
    final effectiveFocusedBorder = makeBorder(
      activeBorderOverride ?? focusedBorderColor,
      focusedBorderWidth,
    );

    final base = InputDecoration(
      labelText: (labelMode == OmniFieldLabelMode.floating && label != null)
          ? trField(label, localeState)
          : null,
      hintText: hint == null ? null : trField(hint, localeState),
      helperText: helperText == null ? null : trField(helperText, localeState),
      errorText: errorText == null ? null : trField(errorText, localeState),
      prefixText: prefixText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      prefix: prefix,
      suffixIcon: suffixIcon,
      suffix: suffix,
      counter: counter,
      enabled: enabled,
      isDense: isDense,
      filled: variant == OmniInputVariant.filled,
      fillColor: enabled ? fillColor : ui.colors.disabledColor,
      contentPadding: contentPadding,
      labelStyle: labelStyle,
      floatingLabelStyle: labelStyle.copyWith(color: focusedBorderColor),
      hintStyle: hintStyle,
      helperStyle: ui.text.caption,
      errorStyle: ui.text.error.copyWith(color: errorColor),
      prefixIconColor: prefixIconColor,
      suffixIconColor: suffixIconColor,
      border: effectiveEnabledBorder,
      enabledBorder: effectiveEnabledBorder,
      focusedBorder: effectiveFocusedBorder,
      errorBorder: makeBorder(errorColor, math.max(borderWidth, 1.0)),
      focusedErrorBorder: makeBorder(errorColor, focusedBorderWidth),
      disabledBorder: makeBorder(ui.colors.disabledBorderColor, borderWidth),
    );

    if (customDecoration == null) return base;

    return base.copyWith(
      labelText: customDecoration.labelText,
      label: customDecoration.label,
      hintText: customDecoration.hintText,
      helperText: customDecoration.helperText,
      errorText: customDecoration.errorText,
      prefixText: customDecoration.prefixText,
      suffixText: customDecoration.suffixText,
      prefixIcon: customDecoration.prefixIcon,
      prefix: customDecoration.prefix,
      suffixIcon: customDecoration.suffixIcon,
      suffix: customDecoration.suffix,
      counter: customDecoration.counter,
      counterText: customDecoration.counterText,
      fillColor: customDecoration.fillColor,
      filled: customDecoration.filled,
      contentPadding: customDecoration.contentPadding,
      border: customDecoration.border,
      enabledBorder: customDecoration.enabledBorder,
      focusedBorder: customDecoration.focusedBorder,
      errorBorder: customDecoration.errorBorder,
      focusedErrorBorder: customDecoration.focusedErrorBorder,
      disabledBorder: customDecoration.disabledBorder,
      isDense: customDecoration.isDense,
      constraints: customDecoration.constraints,
    );
  }
}

/// কমন লেবেল (`above` / `floating` / `none`) ও `TextFormField` র‍্যাপার।
class OmniFieldInputShell extends StatelessWidget {
  const OmniFieldInputShell({
    super.key,
    required this.config,
    required this.controller,
    required this.decoration,
    this.label,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
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
    this.autofillHints,
    this.textAlign = TextAlign.start,
  });

  final ResolvedFieldConfig config;
  final TextEditingController controller;
  final InputDecoration decoration;
  final String? label;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: config.textStyle,
      cursorColor: config.accentColor,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: config.autovalidateMode,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autofocus: autofocus,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? null : minLines,
      maxLength: maxLength,
      autofillHints: autofillHints,
      textAlign: textAlign,
    );

    if (config.labelMode == OmniFieldLabelMode.above &&
        label != null &&
        label!.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trField(label!, config.localeState), style: config.labelStyle),
          SizedBox(height: config.labelSpacing),
          field,
        ],
      );
    }
    return field;
  }
}

/// একাধিক সাফিক্স অ্যাকশন (যেমন valid badge + clear button + custom suffix) একসাথে সাজায়।
Widget? combineSuffixWidgets(List<Widget?> items) {
  final active = items.whereType<Widget>().toList(growable: false);
  if (active.isEmpty) return null;
  if (active.length == 1) return active.first;
  return Row(mainAxisSize: MainAxisSize.min, children: active);
}

/// Rebuilds a field only when what its `build` shows from the controller
/// changes — not on every cursor move, selection or IME composing update.
mixin FieldRebuildFilter<T extends StatefulWidget> on State<T> {
  Object? _lastShown = const _Unset();

  /// The part of [text] that `build` depends on (default: the whole text).
  Object? shownFrom(String text) => text;

  /// Calls `setState` only when [shownFrom] differs from the last call.
  void rebuildIfShownChanged(String text) {
    final next = shownFrom(text);
    if (next == _lastShown) return;
    _lastShown = next;
    if (mounted) setState(() {});
  }
}

class _Unset {
  const _Unset();
}
