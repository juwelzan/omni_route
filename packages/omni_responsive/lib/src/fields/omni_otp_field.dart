import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../omni_localization.dart';
import 'field_patterns.dart';
import 'field_identity.dart';
import 'otp_styles.dart';
import 'field_theme.dart';
import 'field_texts.dart';
import 'omni_validators.dart';
import 'field_core.dart';

/// `pinput` প্যাকেজের আর্কিটেকচারে (সিঙ্গেল-ইনপুট + অ্যানিমেটেড আলাদা প্রতিটি
/// ঘরের পিন সেল) তৈরি রেসপনসিভ ওটিপি ভেরিফিকেশন উইজেট (`OmniFieldIdentity.otp`)।
///
/// ৩, ৪, ৫, ৬ বা যেকোনো `length` দিলে ঠিক ততটি ঘর একই লাইনে সুন্দরভাবে বসে;
/// `defaultPinTheme`, `focusedPinTheme`, `submittedPinTheme`, `followingPinTheme`,
/// `errorPinTheme`, `disabledPinTheme`, `separatorBuilder` ও `pinAnimationType`
/// দিয়ে পুরোপুরি কাস্টমাইজ করা যায়।
class OmniOtpField extends FormField<String> {
  /// [length] সংখ্যার OTP / PIN ভেরিফিকেশন ঘর তৈরি করে (`3`, `4`, `5`, `6`, `8` ইত্যাদি)।
  OmniOtpField({
    super.key,
    this.length = 6,
    this.controller,
    this.label = 'Verification Code',
    this.prefixIcon,
    this.showLabelIcon = true,
    this.helperText,
    this.warningText,
    this.errorText,
    this.status,
    this.digitsOnly = true,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.obscuringWidget,
    this.boxStyle,
    this.boxWidth,
    this.boxHeight,
    this.boxSpacing,
    this.textStyle,
    this.defaultPinTheme,
    this.focusedPinTheme,
    this.submittedPinTheme,
    this.followingPinTheme,
    this.warningPinTheme,
    this.errorPinTheme,
    this.disabledPinTheme,
    this.separatorBuilder,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.showCursor = true,
    this.cursor,
    this.pinAnimationType = OmniOtpAnimationType.scale,
    this.errorAnimation = OmniOtpErrorAnimation.shake,
    this.warningAnimation = OmniOtpWarningAnimation.pulse,
    this.verifiedAnimation = OmniOtpVerifiedAnimation.mergeCheck,
    this.errorTrigger = 0,
    this.warningTrigger = 0,
    this.warningIcon = Icons.warning_amber_rounded,
    this.errorIcon = Icons.error_outline_rounded,
    this.verifiedIcon = Icons.check_rounded,
    this.animationDuration = const Duration(milliseconds: 160),
    this.closeKeyboardWhenCompleted = true,
    this.onChanged,
    this.onCompleted,
    this.resendDuration,
    this.onResend,
    this.resendButtonLabel = 'Resend Code',
    this.isVerifying = false,
    this.isVerified = false,
    this.verifiedLabel = 'OTP Verified',
    super.enabled = true,
    this.autofocus = false,
    this.fieldTheme,
    this.fieldStyle,
    AutovalidateMode? autovalidateMode,
    FormFieldValidator<String>? validator,
  }) : assert(length >= 2 && length <= 12),
       super(
         initialValue: controller?.text ?? '',
         autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
         validator:
             validator ??
             (v) =>
                 OmniValidators.otp(v, length: length, digitsOnly: digitsOnly),
         builder: (state) {
           final widget = state.widget as OmniOtpField;
           return _OmniOtpBoxes(field: widget, formState: state);
         },
       );

  /// OTP ঘরের সংখ্যা (`3`, `4`, `5`, `6`, `8` ইত্যাদি — যে সংখ্যা দেবেন ঠিক ততটি ঘর নেবে)।
  final int length;

  /// বাহ্যিক [TextEditingController]।
  final TextEditingController? controller;

  /// ওপরের লেবেল।
  final String? label;

  /// লেবেলের পাশে কাস্টম আইকন (ডিফল্ট `OmniFieldIdentity.otp.defaultIcon`)।
  final Widget? prefixIcon;

  /// লেবেলের পাশে আইকন দেখাবে কি না।
  final bool showLabelIcon;

  /// নিচে সহায়ক টেক্সট।
  final String? helperText;

  /// ওয়ার্নিং মেসেজ (দিলে স্বয়ংক্রিয়ভাবে অ্যাম্বার ওয়ার্নিং ও অ্যানিমেশন দেখায়)।
  final String? warningText;

  /// সরাসরি এরর টেক্সট ওভাররাইড।
  final String? errorText;

  /// সরাসরি OTP স্টেট (`idle`, `verifying`, `warning`, `error`, `verified`)।
  final OmniOtpStatus? status;

  /// শুধুমাত্র সংখ্যা (`0-9`) নেবে কি না।
  final bool digitsOnly;

  /// পিন কোডের মতো লুকানো (`•`) দেখাবে কি না।
  final bool obscureText;

  /// [obscureText] চালু থাকলে যে ক্যারেক্টার দেখায়।
  final String obscuringCharacter;

  /// [obscureText] চালু থাকলে কাস্টম ডট/আইকন উইজেট।
  final Widget? obscuringWidget;

  /// বক্সের ভিজ্যুয়াল স্টাইল (`outlined`, `filled`, `underlined`)।
  final OmniOtpBoxStyle? boxStyle;

  /// প্রতিটি বক্সের সর্বোচ্চ/ডিফল্ট প্রস্থ।
  final double? boxWidth;

  /// প্রতিটি বক্সের উচ্চতা।
  final double? boxHeight;

  /// দুটি বক্সের মাঝের দূরত্ব।
  final double? boxSpacing;

  /// বক্সের ভেতরের সংখ্যা টেক্সট স্টাইল।
  final TextStyle? textStyle;

  /// পিনের ডিফল্ট ঘর স্টাইল (`pinput`-এর মতো)।
  final OmniPinTheme? defaultPinTheme;

  /// সক্রিয়/ফোকাসড ঘরের স্টাইল।
  final OmniPinTheme? focusedPinTheme;

  /// পূরণ হয়ে যাওয়া ঘরের স্টাইল।
  final OmniPinTheme? submittedPinTheme;

  /// এখনো পূরণ না হওয়া পরের ঘরের স্টাইল।
  final OmniPinTheme? followingPinTheme;

  /// ওয়ার্নিং অবস্থায় ঘরের স্টাইল।
  final OmniPinTheme? warningPinTheme;

  /// ভ্যালিডেশন এরর অবস্থায় ঘরের স্টাইল।
  final OmniPinTheme? errorPinTheme;

  /// নিষ্ক্রিয় অবস্থায় ঘরের স্টাইল।
  final OmniPinTheme? disabledPinTheme;

  /// দুটি ঘরের মাঝখানে কাস্টম সেপারেটর বিল্ডার (যেমন ৩ ঘর পর `-` দেখানো)।
  final IndexedWidgetBuilder? separatorBuilder;

  /// বক্সগুলোর অনুভূমিক অ্যালাইনমেন্ট।
  final MainAxisAlignment mainAxisAlignment;

  /// বক্সগুলোর উল্লম্ব অ্যালাইনমেন্ট।
  final CrossAxisAlignment crossAxisAlignment;

  /// সক্রিয় খালি ঘরে কার্সর বার দেখাবে কি না।
  final bool showCursor;

  /// কাস্টম কার্সর উইজেট।
  final Widget? cursor;

  /// ঘরের ভেতরে সংখ্যা আসার অ্যানিমেশন ধরন।
  final OmniOtpAnimationType pinAnimationType;

  /// এরর হলে ঝাঁকুনি/বাউন্স/পালস/ফ্ল্যাশ অ্যানিমেশন ধরন।
  final OmniOtpErrorAnimation errorAnimation;

  /// ওয়ার্নিং অবস্থায় পালস/ওয়াবল/বাউন্স/গ্লো অ্যানিমেশন ধরন।
  final OmniOtpWarningAnimation warningAnimation;

  /// ভেরিফাই সফল হলে সব ঘর একসাথে মিলিত হওয়া বা টিক-অ্যানিমেশনের ধরন।
  final OmniOtpVerifiedAnimation verifiedAnimation;

  /// বারবার একই এরর অবস্থায় নতুন করে অ্যানিমেশন চালাতে কাউন্টার বাড়ান।
  final int errorTrigger;

  /// বারবার একই ওয়ার্নিং অবস্থায় নতুন করে অ্যানিমেশন চালাতে কাউন্টার বাড়ান।
  final int warningTrigger;

  /// ওয়ার্নিং ব্যাজের আইকন।
  final IconData warningIcon;

  /// এরর ব্যাজের আইকন।
  final IconData errorIcon;

  /// ভেরিফাই সফল হলে মার্জড সার্কল/বক্সে দেখানো টিক আইকন।
  final IconData verifiedIcon;

  /// প্রতিটি ঘরের অ্যানিমেশন সময়কাল।
  final Duration animationDuration;

  /// সব ঘর পূরণ হওয়ামাত্র কিবোর্ড অটো বন্ধ করবে কি না।
  final bool closeKeyboardWhenCompleted;

  /// প্রতিটি ডিজিট পরিবর্তনে কলব্যাক।
  final ValueChanged<String>? onChanged;

  /// সব বক্স পূরণ হলেই স্বয়ংক্রিয়ভাবে কল হয়।
  final ValueChanged<String>? onCompleted;

  /// রিসেন্ড কাউন্টডাউন সময় (যেমন `Duration(seconds: 30)`)।
  final Duration? resendDuration;

  /// `Resend Code` বাটনে ট্যাপ কলব্যাক।
  final VoidCallback? onResend;

  /// রিসেন্ড বাটনের টেক্সট।
  final String resendButtonLabel;

  /// ভেরিফিকেশন লোডিং স্পিনার দেখানো হবে কি না।
  final bool isVerifying;

  /// OTP ভেরিফায়েড হয়ে গেছে কি না।
  final bool isVerified;

  /// ভেরিফায়েড ব্যাজ টেক্সট।
  final String verifiedLabel;

  /// শুরুতে অটো-ফোকাস নেবে কি না।
  final bool autofocus;

  /// শেয়ার্ড থিম ওভাররাইড।
  final OmniFieldTheme? fieldTheme;

  /// ফিল্ড স্টাইল ওভাররাইড।
  final OmniFieldStyle? fieldStyle;
}

class _OmniOtpBoxes extends StatefulWidget {
  const _OmniOtpBoxes({required this.field, required this.formState});

  final OmniOtpField field;
  final FormFieldState<String> formState;

  @override
  State<_OmniOtpBoxes> createState() => _OmniOtpBoxesState();
}

class _OmniOtpBoxesState extends State<_OmniOtpBoxes>
    with TickerProviderStateMixin {
  TextEditingController? _ownedController;
  final FocusNode _focusNode = FocusNode();
  bool _syncing = false;
  Timer? _resendTimer;
  final ValueNotifier<int> _remaining = ValueNotifier<int>(0);

  late final AnimationController _errorCtrl;
  late final AnimationController _warningCtrl;
  late final AnimationController _verifyCtrl;
  late final AnimationController _typingCtrl;

  OmniOtpStatus _lastStatus = OmniOtpStatus.idle;
  int _lastTypedLen = 0;
  int _popStartIndex = -1;
  int _popEndIndex = -1;

  TextEditingController get _ctrl =>
      widget.field.controller ?? _ownedController!;

  OmniOtpStatus _computeStatus({required bool formHasError}) {
    final explicit = widget.field.status;
    if (explicit != null) return explicit;
    if (widget.field.isVerified) return OmniOtpStatus.verified;
    if (formHasError ||
        (widget.field.errorText != null &&
            widget.field.errorText!.isNotEmpty)) {
      return OmniOtpStatus.error;
    }
    if (widget.field.warningText != null &&
        widget.field.warningText!.isNotEmpty) {
      return OmniOtpStatus.warning;
    }
    if (widget.field.isVerifying) return OmniOtpStatus.verifying;
    return OmniOtpStatus.idle;
  }

  @override
  void initState() {
    super.initState();
    _errorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _warningCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _verifyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 840),
    );
    _typingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
    if (widget.field.controller == null) {
      _ownedController = TextEditingController(
        text: widget.formState.value ?? '',
      );
    }
    _lastTypedLen = _sanitize(_ctrl.text).length;
    _ctrl.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
    _startResendCountdown();

    _lastStatus = _computeStatus(
      formHasError: widget.formState.errorText != null,
    );
    if (_lastStatus == OmniOtpStatus.verified) {
      _verifyCtrl.value = 1.0;
    } else if (_lastStatus == OmniOtpStatus.error &&
        widget.field.errorAnimation != OmniOtpErrorAnimation.none) {
      _errorCtrl.forward(from: 0.0);
    } else if (_lastStatus == OmniOtpStatus.warning &&
        widget.field.warningAnimation != OmniOtpWarningAnimation.none) {
      _warningCtrl.forward(from: 0.0);
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _triggerTypingPop(String clean) {
    final nextLen = clean.length;
    if (nextLen > _lastTypedLen &&
        widget.field.pinAnimationType != OmniOtpAnimationType.none) {
      _popStartIndex = _lastTypedLen;
      _popEndIndex = nextLen - 1;
      _typingCtrl.forward(from: 0.0);
    } else if (nextLen < _lastTypedLen) {
      _popStartIndex = -1;
      _popEndIndex = -1;
    }
    _lastTypedLen = nextLen;
  }

  void _onControllerChanged() {
    if (_syncing) return;
    final clean = _sanitize(_ctrl.text);
    if (clean != _ctrl.text) {
      _syncing = true;
      _ctrl.value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
      _syncing = false;
    }
    _triggerTypingPop(clean);
    if (widget.formState.value != clean) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.formState.didChange(clean);
      });
    }
    if (mounted) setState(() {});
  }

  String _sanitize(String raw) {
    final clean = widget.field.digitsOnly
        ? raw.replaceAll(fieldReNonDigit, '')
        : raw;
    return clean.length > widget.field.length
        ? clean.substring(0, widget.field.length)
        : clean;
  }

  void _handleInputChanged(String raw) {
    final clean = _sanitize(raw);
    if (_ctrl.text != clean) {
      _syncing = true;
      _ctrl.value = TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
      _syncing = false;
    }
    _triggerTypingPop(clean);
    widget.formState.didChange(clean);
    widget.field.onChanged?.call(clean);
    if (clean.length == widget.field.length) {
      if (widget.field.closeKeyboardWhenCompleted) {
        _focusNode.unfocus();
      }
      widget.field.onCompleted?.call(clean);
    }
    if (mounted) setState(() {});
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendTimer = null;
    final dur = widget.field.resendDuration;
    if (dur == null || dur.inSeconds <= 0) {
      _remaining.value = 0;
      return;
    }
    _remaining.value = dur.inSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remaining.value <= 1) t.cancel();
      _remaining.value = _remaining.value <= 1 ? 0 : _remaining.value - 1;
    });
  }

  /// `Resend code in mm:ss` in the current language.
  static String _resendCountdownText(int seconds, OmniLocaleState locale) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    final raw = trDynamic(
      en: 'Resend code in $m:$sec',
      bn: 'পুনরায় পাঠানো যাবে $m:$sec সেকেন্ডে',
      ar: 'إعادة الإرسال خلال $m:$sec',
      hi: '$m:$sec में कोड पुनः भेजें',
    );
    return locale.useLocaleDigits
        ? OmniText.formatDigits(raw, language: locale.language)
        : raw;
  }

  @override
  void didUpdateWidget(covariant _OmniOtpBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field.controller != widget.field.controller) {
      (oldWidget.field.controller ?? _ownedController)?.removeListener(
        _onControllerChanged,
      );
      if (widget.field.controller == null) {
        _ownedController ??= TextEditingController(
          text: _sanitize(oldWidget.field.controller?.text ?? ''),
        );
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _ctrl.addListener(_onControllerChanged);
    }
    if (oldWidget.field.length != widget.field.length) {
      _onControllerChanged();
    }
    if (oldWidget.field.resendDuration != widget.field.resendDuration) {
      _startResendCountdown();
    }

    final nextStatus = _computeStatus(
      formHasError: widget.formState.errorText != null,
    );
    if (nextStatus != _lastStatus) {
      if (nextStatus == OmniOtpStatus.verified) {
        _verifyCtrl.forward(from: 0.0);
      } else {
        if (_lastStatus == OmniOtpStatus.verified) {
          _verifyCtrl.reset();
        }
        if (nextStatus == OmniOtpStatus.error &&
            widget.field.errorAnimation != OmniOtpErrorAnimation.none) {
          _errorCtrl.forward(from: 0.0);
        } else if (nextStatus == OmniOtpStatus.warning &&
            widget.field.warningAnimation != OmniOtpWarningAnimation.none) {
          _warningCtrl.forward(from: 0.0);
        }
      }
      _lastStatus = nextStatus;
    } else {
      if (oldWidget.field.errorTrigger != widget.field.errorTrigger &&
          nextStatus == OmniOtpStatus.error &&
          widget.field.errorAnimation != OmniOtpErrorAnimation.none) {
        _errorCtrl.forward(from: 0.0);
      }
      if (oldWidget.field.warningTrigger != widget.field.warningTrigger &&
          nextStatus == OmniOtpStatus.warning &&
          widget.field.warningAnimation != OmniOtpWarningAnimation.none) {
        _warningCtrl.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _errorCtrl.dispose();
    _warningCtrl.dispose();
    _verifyCtrl.dispose();
    _typingCtrl.dispose();
    _resendTimer?.cancel();
    _remaining.dispose();
    (widget.field.controller ?? _ownedController)?.removeListener(
      _onControllerChanged,
    );
    _ownedController?.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Widget _buildAnimatedChar(String char, TextStyle textStyle) {
    final child = widget.field.obscureText
        ? (widget.field.obscuringWidget ??
              Text(widget.field.obscuringCharacter, style: textStyle))
        : Text(char, style: textStyle);

    if (widget.field.pinAnimationType == OmniOtpAnimationType.none) {
      return child;
    }

    final curve = switch (widget.field.pinAnimationType) {
      OmniOtpAnimationType.spring => Curves.elasticOut,
      OmniOtpAnimationType.drop ||
      OmniOtpAnimationType.flip => Curves.easeOutCubic,
      _ => Curves.easeOutBack,
    };

    return AnimatedSwitcher(
      duration: widget.field.animationDuration,
      switchInCurve: curve,
      transitionBuilder: (c, anim) => switch (widget.field.pinAnimationType) {
        OmniOtpAnimationType.scale => ScaleTransition(scale: anim, child: c),
        OmniOtpAnimationType.spring => ScaleTransition(
          scale: Tween<double>(begin: 0.45, end: 1.0).animate(anim),
          child: FadeTransition(opacity: anim, child: c),
        ),
        OmniOtpAnimationType.fade => FadeTransition(opacity: anim, child: c),
        OmniOtpAnimationType.slide => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.38),
            end: Offset.zero,
          ).animate(anim),
          child: FadeTransition(opacity: anim, child: c),
        ),
        OmniOtpAnimationType.drop => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.42),
            end: Offset.zero,
          ).animate(anim),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: c),
          ),
        ),
        OmniOtpAnimationType.rotation => RotationTransition(
          turns: Tween<double>(begin: 0.88, end: 1.0).animate(anim),
          child: ScaleTransition(scale: anim, child: c),
        ),
        OmniOtpAnimationType.flip => AnimatedBuilder(
          animation: anim,
          child: c,
          builder: (_, inner) {
            final v = anim.value.clamp(0.0, 1.0);
            final rotX = (1.0 - v) * (math.pi / 2.2);
            return Opacity(
              opacity: v,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.003)
                  ..rotateX(rotX),
                child: inner,
              ),
            );
          },
        ),
        OmniOtpAnimationType.blur => ScaleTransition(
          scale: Tween<double>(begin: 1.38, end: 1.0).animate(anim),
          child: FadeTransition(opacity: anim, child: c),
        ),
        OmniOtpAnimationType.none => c,
      },
      child: KeyedSubtree(key: ValueKey<String>(char), child: child),
    );
  }

  BoxDecoration _makeCellDecoration({
    required ResolvedFieldConfig config,
    required OmniOtpBoxStyle boxStyle,
    required BorderRadius borderRadius,
    required Color fillColor,
    required Color borderColor,
    required double borderWidth,
    BoxShadow? shadow,
  }) {
    if (boxStyle == OmniOtpBoxStyle.underlined) {
      return BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: borderColor,
            width: math.max(borderWidth, 1.5),
          ),
        ),
      );
    }
    return BoxDecoration(
      color: boxStyle == OmniOtpBoxStyle.filled
          ? fillColor
          : config.ui.colors.cardColor,
      borderRadius: borderRadius,
      border: borderWidth <= 0 && boxStyle == OmniOtpBoxStyle.filled
          ? null
          : Border.all(color: borderColor, width: math.max(borderWidth, 1.0)),
      boxShadow: shadow == null ? null : [shadow],
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ResolvedFieldConfig.of(
      context,
      identity: OmniFieldIdentity.otp,
      fieldThemeOverride: widget.field.fieldTheme,
      fieldStyleOverride: widget.field.fieldStyle,
    );
    final boxStyle = widget.field.boxStyle ?? config.fieldTheme.otpBoxStyle;
    final prefW =
        widget.field.defaultPinTheme?.width ??
        widget.field.boxWidth ??
        config.fieldTheme.otpBoxWidth;
    final boxH =
        widget.field.defaultPinTheme?.height ??
        widget.field.boxHeight ??
        config.fieldTheme.otpBoxHeight;
    final gap = widget.field.boxSpacing ?? config.fieldTheme.otpBoxSpacing;

    final effectiveError = widget.field.errorText ?? widget.formState.errorText;
    final activeStatus = _computeStatus(
      formHasError: effectiveError != null && effectiveError.isNotEmpty,
    );

    if (activeStatus != _lastStatus) {
      final triggered = activeStatus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (triggered == OmniOtpStatus.verified) {
          _verifyCtrl.forward(from: 0.0);
        } else {
          if (_lastStatus == OmniOtpStatus.verified) {
            _verifyCtrl.reset();
          }
          if (triggered == OmniOtpStatus.error &&
              widget.field.errorAnimation != OmniOtpErrorAnimation.none) {
            _errorCtrl.forward(from: 0.0);
          } else if (triggered == OmniOtpStatus.warning &&
              widget.field.warningAnimation != OmniOtpWarningAnimation.none) {
            _warningCtrl.forward(from: 0.0);
          }
        }
        _lastStatus = triggered;
      });
    }

    final hasError = activeStatus == OmniOtpStatus.error;
    final hasWarning = activeStatus == OmniOtpStatus.warning;
    final isVerifyingNow = activeStatus == OmniOtpStatus.verifying;
    final isVerifiedNow = activeStatus == OmniOtpStatus.verified;
    final isDisabled = !widget.field.enabled || isVerifyingNow || isVerifiedNow;

    final baseTextStyle =
        widget.field.textStyle ??
        widget.field.defaultPinTheme?.textStyle ??
        config.ui.text.heading.copyWith(color: config.ui.colors.textColor);

    final baseDefaultPin =
        widget.field.defaultPinTheme ??
        OmniPinTheme(
          width: prefW,
          height: boxH,
          textStyle: baseTextStyle,
          decoration: _makeCellDecoration(
            config: config,
            boxStyle: boxStyle,
            borderRadius: config.borderRadius,
            fillColor: config.fillColor,
            borderColor: config.borderColor,
            borderWidth: config.borderWidth,
          ),
        );

    final effectiveFocusedPin =
        widget.field.focusedPinTheme ??
        baseDefaultPin.copyWith(
          decoration: _makeCellDecoration(
            config: config,
            boxStyle: boxStyle,
            borderRadius: config.borderRadius,
            fillColor: config.fillColor,
            borderColor: config.focusedBorderColor,
            borderWidth: math.max(config.focusedBorderWidth, 1.8),
            shadow: boxStyle == OmniOtpBoxStyle.underlined
                ? null
                : BoxShadow(
                    color: config.focusedBorderColor.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
          ),
        );

    final effectiveSubmittedPin =
        widget.field.submittedPinTheme ??
        baseDefaultPin.copyWith(
          decoration: _makeCellDecoration(
            config: config,
            boxStyle: boxStyle,
            borderRadius: config.borderRadius,
            fillColor: isVerifiedNow
                ? config.successColor.withValues(alpha: 0.1)
                : config.accentColor.withValues(alpha: 0.08),
            borderColor: isVerifiedNow
                ? config.successColor
                : config.accentColor.withValues(alpha: 0.72),
            borderWidth: math.max(config.borderWidth, 1.2),
          ),
        );

    final warnColor = config.ui.colors.warningColor;
    final effectiveWarningPin =
        widget.field.warningPinTheme ??
        baseDefaultPin.copyWith(
          textStyle: baseTextStyle.copyWith(color: warnColor),
          decoration: _makeCellDecoration(
            config: config,
            boxStyle: boxStyle,
            borderRadius: config.borderRadius,
            fillColor: config.ui.colors.warningBackgroundColor,
            borderColor: warnColor,
            borderWidth: math.max(config.focusedBorderWidth, 1.6),
            shadow: boxStyle == OmniOtpBoxStyle.underlined
                ? null
                : BoxShadow(
                    color: warnColor.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
          ),
        );

    final effectiveErrorPin =
        widget.field.errorPinTheme ??
        baseDefaultPin.copyWith(
          textStyle: baseTextStyle.copyWith(color: config.errorColor),
          decoration: _makeCellDecoration(
            config: config,
            boxStyle: boxStyle,
            borderRadius: config.borderRadius,
            fillColor: config.errorColor.withValues(alpha: 0.06),
            borderColor: config.errorColor,
            borderWidth: math.max(config.focusedBorderWidth, 1.6),
          ),
        );

    final effectiveDisabledPin =
        widget.field.disabledPinTheme ??
        baseDefaultPin.copyWith(
          textStyle: baseTextStyle.copyWith(
            color: config.ui.colors.disabledTextColor,
          ),
          decoration: _makeCellDecoration(
            config: config,
            boxStyle: boxStyle,
            borderRadius: config.borderRadius,
            fillColor: config.ui.colors.disabledColor,
            borderColor: config.ui.colors.disabledBorderColor,
            borderWidth: config.borderWidth,
          ),
        );

    final effectiveFollowingPin =
        widget.field.followingPinTheme ?? baseDefaultPin;

    final code = _sanitize(_ctrl.text);
    final activeIndex = code.length >= widget.field.length
        ? widget.field.length - 1
        : code.length;

    final labelLeadingIcon = widget.field.showLabelIcon && config.showPrefixIcon
        ? config.resolvePrefixIcon(
            widget.field.prefixIcon,
            OmniFieldIdentity.otp.defaultIcon,
          )
        : null;

    final combinedAnim = Listenable.merge([
      _errorCtrl,
      _warningCtrl,
      _verifyCtrl,
      _typingCtrl,
    ]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._buildLabel(config, labelLeadingIcon),
        LayoutBuilder(
          builder: (context, constraints) {
            final n = widget.field.length;
            final maxW = constraints.maxWidth;
            final totalGap = gap * math.max(0, n - 1);
            final responsiveCellW =
                (maxW.isFinite && widget.field.separatorBuilder == null)
                ? math.min(prefW, math.max(24.0, (maxW - totalGap) / n))
                : prefW;
            final look = _OtpLook(
              config: config,
              boxStyle: boxStyle,
              baseTextStyle: baseTextStyle,
              effectiveFocusedPin: effectiveFocusedPin,
              effectiveSubmittedPin: effectiveSubmittedPin,
              effectiveWarningPin: effectiveWarningPin,
              effectiveErrorPin: effectiveErrorPin,
              effectiveDisabledPin: effectiveDisabledPin,
              effectiveFollowingPin: effectiveFollowingPin,
              warnColor: warnColor,
              code: code,
              activeIndex: activeIndex,
              n: n,
              gap: gap,
              boxH: boxH,
              responsiveCellW: responsiveCellW,
              hasError: hasError,
              hasWarning: hasWarning,
              isDisabled: isDisabled,
              isVerifiedNow: isVerifiedNow,
              verMode: widget.field.verifiedAnimation,
              centerIndex: (n - 1) / 2.0,
            );

            return AnimatedBuilder(
              animation: combinedAnim,
              builder: (_, _) {
                final errT = _errorCtrl.value;
                final warnT = _warningCtrl.value;
                final verT = _verifyCtrl.value;
                final typeT = _typingCtrl.value;

                // ১. সারি-ভিত্তিক এরর ও ওয়ার্নিং ট্রান্সফর্ম:
                Offset statusOffset = Offset.zero;
                double statusScale = 1.0;
                double errorGlow = 0.0;
                double warnGlow = 0.0;

                if (hasError && errT > 0 && errT < 1) {
                  switch (widget.field.errorAnimation) {
                    case OmniOtpErrorAnimation.shake:
                      statusOffset = Offset(
                        math.sin(errT * math.pi * 5.0) * (1.0 - errT) * 12.0,
                        0,
                      );
                      errorGlow = (1.0 - errT) * 0.55;
                    case OmniOtpErrorAnimation.bounce:
                      statusOffset = Offset(
                        0,
                        -math.sin(errT * math.pi * 3.0).abs() *
                            (1.0 - errT) *
                            10.0,
                      );
                    case OmniOtpErrorAnimation.pulse:
                      statusScale =
                          1.0 + math.sin(errT * math.pi * 2.0) * 0.055;
                      errorGlow = math.sin(errT * math.pi).clamp(0.0, 1.0);
                    case OmniOtpErrorAnimation.flash:
                      errorGlow = math.sin(errT * math.pi * 3.0).abs();
                    case OmniOtpErrorAnimation.staggerShake ||
                        OmniOtpErrorAnimation.tiltShake ||
                        OmniOtpErrorAnimation.jello ||
                        OmniOtpErrorAnimation.none:
                      break;
                  }
                } else if (hasWarning && warnT > 0 && warnT < 1) {
                  switch (widget.field.warningAnimation) {
                    case OmniOtpWarningAnimation.pulse:
                      statusScale =
                          1.0 + math.sin(warnT * math.pi * 2.0) * 0.045;
                      warnGlow = math.sin(warnT * math.pi).clamp(0.0, 1.0);
                    case OmniOtpWarningAnimation.heartbeat:
                      final b1 = math.sin(
                        (warnT / 0.36).clamp(0.0, 1.0) * math.pi,
                      );
                      final b2 = math.sin(
                        ((warnT - 0.34) / 0.42).clamp(0.0, 1.0) * math.pi,
                      );
                      final beat = math.max(b1 * 0.85, b2);
                      statusScale = 1.0 + beat * 0.07;
                      warnGlow = beat;
                    case OmniOtpWarningAnimation.wobble:
                      statusOffset = Offset(
                        math.sin(warnT * math.pi * 3.0) * (1.0 - warnT) * 7.5,
                        0,
                      );
                    case OmniOtpWarningAnimation.bounce:
                      statusOffset = Offset(
                        0,
                        -math.sin(warnT * math.pi * 2.0).abs() *
                            (1.0 - warnT) *
                            7.5,
                      );
                    case OmniOtpWarningAnimation.glow:
                      warnGlow = math.sin(warnT * math.pi * 2.0).abs();
                    case OmniOtpWarningAnimation.waveBounce ||
                        OmniOtpWarningAnimation.shimmer ||
                        OmniOtpWarningAnimation.tilt ||
                        OmniOtpWarningAnimation.none:
                      break;
                  }
                }

                final verMode = widget.field.verifiedAnimation;
                final isMergingMode =
                    isVerifiedNow &&
                    (verMode == OmniOtpVerifiedAnimation.mergeCheck ||
                        verMode == OmniOtpVerifiedAnimation.morphPill ||
                        verMode == OmniOtpVerifiedAnimation.stackMerge);

                // ২. মাল্টি-স্টেজ মার্জ কার্ভ (অ্যান্টিসিপেশন -> ম্যাগনেটিক কনভার্জের -> ব্যাজ পপ):
                final anticipateT = isMergingMode
                    ? math.sin((verT / 0.16).clamp(0.0, 1.0) * math.pi)
                    : 0.0;
                final mergePhase = isMergingMode
                    ? Curves.easeInOutCubic.transform(
                        ((verT - 0.10) / 0.44).clamp(0.0, 1.0),
                      )
                    : 0.0;
                final badgePhase = isMergingMode
                    ? Curves.easeOutBack.transform(
                        ((verT - 0.44) / 0.36).clamp(0.0, 1.0),
                      )
                    : 0.0;
                final checkReveal = isMergingMode
                    ? Curves.easeOutCubic.transform(
                        ((verT - 0.56) / 0.28).clamp(0.0, 1.0),
                      )
                    : 1.0;
                final boxFadeOpacity = isMergingMode
                    ? (1.0 - ((verT - 0.44) / 0.24).clamp(0.0, 1.0))
                    : 1.0;

                final frame = _OtpFrame(
                  errT: errT,
                  warnT: warnT,
                  verT: verT,
                  typeT: typeT,
                  errorGlow: errorGlow,
                  warnGlow: warnGlow,
                  anticipateT: anticipateT,
                  mergePhase: mergePhase,
                  boxFadeOpacity: boxFadeOpacity,
                  isMergingMode: isMergingMode,
                );

                final cellsRow = Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: widget.field.mainAxisAlignment,
                  crossAxisAlignment: widget.field.crossAxisAlignment,
                  children: [
                    for (var i = 0; i < n; i++) ...[
                      if (i > 0)
                        Opacity(
                          opacity: boxFadeOpacity,
                          child:
                              widget.field.separatorBuilder?.call(
                                context,
                                i - 1,
                              ) ??
                              SizedBox(width: gap),
                        ),
                      _buildCell(i, look, frame),
                    ],
                  ],
                );

                final fittedRow = widget.field.separatorBuilder != null
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: cellsRow,
                      )
                    : cellsRow;

                Widget buildAnimatedCheckGlyph(double size) {
                  final icon = Transform.rotate(
                    angle: (1.0 - checkReveal) * -0.22,
                    child: Icon(
                      widget.field.verifiedIcon,
                      color: Colors.white,
                      size: size,
                    ),
                  );
                  if (checkReveal >= 0.99) return icon;
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: checkReveal.clamp(0.05, 1.0),
                      child: icon,
                    ),
                  );
                }

                final Widget mergedOverlay;
                if (isVerifiedNow &&
                    (verMode == OmniOtpVerifiedAnimation.mergeCheck ||
                        verMode == OmniOtpVerifiedAnimation.stackMerge)) {
                  final isShield =
                      verMode == OmniOtpVerifiedAnimation.stackMerge;
                  mergedOverlay = Center(
                    child: Transform.scale(
                      scale: badgePhase.clamp(0.0, 1.16),
                      child: Container(
                        width: boxH,
                        height: boxH,
                        decoration: BoxDecoration(
                          shape: isShield
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          borderRadius: isShield
                              ? BorderRadius.circular(boxH * 0.28)
                              : null,
                          color: config.successColor,
                          boxShadow: [
                            BoxShadow(
                              color: config.successColor.withValues(
                                alpha: 0.38,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: buildAnimatedCheckGlyph(boxH * 0.54),
                      ),
                    ),
                  );
                } else if (isVerifiedNow &&
                    verMode == OmniOtpVerifiedAnimation.morphPill) {
                  mergedOverlay = Center(
                    child: Transform.scale(
                      scale: badgePhase.clamp(0.0, 1.10),
                      child: Container(
                        height: boxH * 0.86,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: config.successColor,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: config.successColor.withValues(
                                alpha: 0.34,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              buildAnimatedCheckGlyph(20),
                              const SizedBox(width: 8),
                              Text(
                                trField(
                                  widget.field.verifiedLabel,
                                  config.localeState,
                                ),
                                style: config.ui.text.button.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  mergedOverlay = const SizedBox.shrink();
                }

                final showSparkBurst =
                    isVerifiedNow &&
                    verT > 0.01 &&
                    verT < 0.995 &&
                    (isMergingMode ||
                        verMode == OmniOtpVerifiedAnimation.confettiBurst ||
                        verMode == OmniOtpVerifiedAnimation.rippleCheck);

                return Transform.translate(
                  offset: statusOffset,
                  child: Transform.scale(
                    scale: statusScale,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isDisabled
                          ? null
                          : () => _focusNode.requestFocus(),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          IgnorePointer(child: fittedRow),
                          if (showSparkBurst)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _OtpBurstPainter(
                                    progress: verT,
                                    mode: verMode,
                                    primaryColor: config.successColor,
                                    accentColor: config.accentColor,
                                  ),
                                ),
                              ),
                            ),
                          if (isMergingMode)
                            Positioned.fill(
                              child: IgnorePointer(child: mergedOverlay),
                            ),
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.001,
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focusNode,
                                enabled: !isDisabled,
                                autofocus: widget.field.autofocus,
                                showCursor: false,
                                enableInteractiveSelection: false,
                                cursorColor: Colors.transparent,
                                style: const TextStyle(
                                  color: Colors.transparent,
                                ),
                                keyboardType: widget.field.digitsOnly
                                    ? TextInputType.number
                                    : TextInputType.text,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                inputFormatters: [
                                  if (widget.field.digitsOnly)
                                    FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                    widget.field.length,
                                  ),
                                ],
                                onChanged: _handleInputChanged,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  counterText: '',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        ..._buildMessage(config, activeStatus, effectiveError, warnColor),
        ..._buildStatusRow(config, activeStatus),
      ],
    );
  }

  List<Widget> _buildLabel(
    ResolvedFieldConfig config,
    Widget? labelLeadingIcon,
  ) => [
    if (widget.field.label != null && widget.field.label!.isNotEmpty) ...[
      Row(
        children: [
          if (labelLeadingIcon != null) ...[
            IconTheme(
              data: IconThemeData(size: 16, color: config.accentColor),
              child: labelLeadingIcon,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            trField(widget.field.label!, config.localeState),
            style: config.labelStyle,
          ),
        ],
      ),
      SizedBox(height: config.labelSpacing + 2),
    ],
  ];

  List<Widget> _buildMessage(
    ResolvedFieldConfig config,
    OmniOtpStatus activeStatus,
    String? effectiveError,
    Color warnColor,
  ) {
    final hasError = activeStatus == OmniOtpStatus.error;
    final hasWarning = activeStatus == OmniOtpStatus.warning;
    return [
      if (hasError && (effectiveError?.isNotEmpty ?? false)) ...[
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.field.errorIcon, size: 15, color: config.errorColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                trField(effectiveError!, config.localeState),
                style: config.ui.text.error.copyWith(color: config.errorColor),
              ),
            ),
          ],
        ),
      ] else if (hasWarning &&
          (widget.field.warningText?.isNotEmpty ?? false)) ...[
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.field.warningIcon, size: 15, color: warnColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                trField(widget.field.warningText!, config.localeState),
                style: config.ui.text.warning.copyWith(color: warnColor),
              ),
            ),
          ],
        ),
      ] else if (widget.field.helperText != null) ...[
        const SizedBox(height: 6),
        Text(
          trField(widget.field.helperText!, config.localeState),
          style: config.ui.text.caption,
        ),
      ],
    ];
  }

  List<Widget> _buildStatusRow(
    ResolvedFieldConfig config,
    OmniOtpStatus activeStatus,
  ) {
    final isVerifyingNow = activeStatus == OmniOtpStatus.verifying;
    final isVerifiedNow = activeStatus == OmniOtpStatus.verified;
    return [
      if (isVerifyingNow ||
          (isVerifiedNow &&
              widget.field.verifiedAnimation !=
                  OmniOtpVerifiedAnimation.morphPill) ||
          (!isVerifiedNow && widget.field.onResend != null)) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            if (isVerifyingNow) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                trField('Verifying...', config.localeState),
                style: config.ui.text.caption,
              ),
            ] else if (isVerifiedNow) ...[
              Icon(
                Icons.verified_rounded,
                size: 16,
                color: config.successColor,
              ),
              const SizedBox(width: 6),
              Text(
                trField(widget.field.verifiedLabel, config.localeState),
                style: config.ui.text.caption.copyWith(
                  color: config.successColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (widget.field.onResend != null) ...[
              ValueListenableBuilder<int>(
                // Only this text ticks every second; the boxes don't rebuild.
                valueListenable: _remaining,
                builder: (context, remaining, _) {
                  if (remaining > 0) {
                    return Text(
                      _resendCountdownText(remaining, config.localeState),
                      style: config.ui.text.caption,
                    );
                  }
                  return TextButton.icon(
                    onPressed: widget.field.enabled
                        ? () {
                            _startResendCountdown();
                            widget.field.onResend?.call();
                          }
                        : null,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      trField(
                        widget.field.resendButtonLabel,
                        config.localeState,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ],
    ];
  }

  /// One animated OTP box (index [i]).
  Widget _buildCell(int i, _OtpLook look, _OtpFrame frame) {
    final _OtpLook(
      :config,
      :boxStyle,
      :baseTextStyle,
      :effectiveFocusedPin,
      :effectiveSubmittedPin,
      :effectiveWarningPin,
      :effectiveErrorPin,
      :effectiveDisabledPin,
      :effectiveFollowingPin,
      :warnColor,
      :code,
      :activeIndex,
      :n,
      :gap,
      :boxH,
      :responsiveCellW,
      :hasError,
      :hasWarning,
      :isDisabled,
      :isVerifiedNow,
      :verMode,
      :centerIndex,
    ) = look;
    final _OtpFrame(
      :errT,
      :warnT,
      :verT,
      :typeT,
      :errorGlow,
      :warnGlow,
      :anticipateT,
      :mergePhase,
      :boxFadeOpacity,
      :isMergingMode,
    ) = frame;
    final hasChar = i < code.length;
    final isFocusedCell =
        _focusNode.hasFocus && i == activeIndex && !isDisabled;

    final OmniPinTheme cellTheme;
    if (isVerifiedNow) {
      cellTheme = effectiveSubmittedPin;
    } else if (isDisabled) {
      cellTheme = effectiveDisabledPin;
    } else if (hasError) {
      cellTheme = effectiveErrorPin;
    } else if (hasWarning) {
      cellTheme = effectiveWarningPin;
    } else if (isFocusedCell) {
      cellTheme = effectiveFocusedPin;
    } else if (hasChar) {
      cellTheme = effectiveSubmittedPin;
    } else {
      cellTheme = effectiveFollowingPin;
    }

    final effectiveW = math.min(
      cellTheme.width ?? responsiveCellW,
      responsiveCellW,
    );
    final effectiveH = cellTheme.height ?? boxH;
    final style = cellTheme.textStyle ?? baseTextStyle;

    final linearPos = n <= 1 ? 0.5 : i / (n - 1);
    final distFromCenter = centerIndex <= 0
        ? 0.0
        : (i - centerIndex).abs() / centerIndex;

    // টাইপিং বা ভেরিফাই/ওয়ার্নিং/এরর অনুযায়ী প্রতি ঘরের সূক্ষ্ম গ্লো ও শেপ মর্ফ:
    var cellErrorGlow = errorGlow;
    var cellWarnGlow = warnGlow;
    var cellSuccessGlow = 0.0;
    var cellTypingGlow = 0.0;

    if (!hasError &&
        !hasWarning &&
        !isVerifiedNow &&
        typeT > 0 &&
        typeT < 1 &&
        i >= _popStartIndex &&
        i <= _popEndIndex) {
      cellTypingGlow = math.sin(typeT * math.pi) * 0.45;
    }
    if (hasWarning &&
        warnT > 0 &&
        warnT < 1 &&
        widget.field.warningAnimation == OmniOtpWarningAnimation.shimmer) {
      cellWarnGlow = math.sin(
        ((warnT * 1.65) - linearPos * 0.65).clamp(0.0, 1.0) * math.pi,
      );
    }
    if (hasError &&
        errT > 0 &&
        errT < 1 &&
        (widget.field.errorAnimation == OmniOtpErrorAnimation.staggerShake ||
            widget.field.errorAnimation == OmniOtpErrorAnimation.jello ||
            widget.field.errorAnimation == OmniOtpErrorAnimation.tiltShake)) {
      cellErrorGlow = (1.0 - errT) * 0.5;
    }

    final staggerT = isVerifiedNow
        ? (verMode == OmniOtpVerifiedAnimation.rippleCheck
              ? ((verT * 1.55) - distFromCenter * 0.55).clamp(0.0, 1.0)
              : ((verT * 1.55) - linearPos * 0.55).clamp(0.0, 1.0))
        : 0.0;

    if (isVerifiedNow &&
        !isMergingMode &&
        verMode != OmniOtpVerifiedAnimation.badgeOnly &&
        verT > 0 &&
        verT < 1) {
      cellSuccessGlow = math.sin(staggerT * math.pi) * 0.55;
    }

    BoxDecoration? resolvedDecoration = cellTheme.decoration;
    // mergeCheck-এ মিলিত হওয়ার সময় বর্গাকার কোণ গোল বৃত্তে মর্ফ হয়:
    if (isVerifiedNow &&
        verMode == OmniOtpVerifiedAnimation.mergeCheck &&
        resolvedDecoration != null &&
        boxStyle != OmniOtpBoxStyle.underlined &&
        mergePhase > 0.01) {
      resolvedDecoration = resolvedDecoration.copyWith(
        borderRadius: BorderRadius.lerp(
          resolvedDecoration.borderRadius as BorderRadius? ??
              config.borderRadius,
          BorderRadius.circular(effectiveH / 2),
          mergePhase,
        ),
      );
    }

    if (resolvedDecoration != null) {
      if (cellErrorGlow > 0.01) {
        resolvedDecoration = resolvedDecoration.copyWith(
          boxShadow: [
            BoxShadow(
              color: config.errorColor.withValues(alpha: 0.45 * cellErrorGlow),
              blurRadius: 12 * cellErrorGlow,
              spreadRadius: 1.5 * cellErrorGlow,
            ),
          ],
        );
      } else if (cellWarnGlow > 0.01) {
        resolvedDecoration = resolvedDecoration.copyWith(
          boxShadow: [
            BoxShadow(
              color: warnColor.withValues(alpha: 0.48 * cellWarnGlow),
              blurRadius: 13 * cellWarnGlow,
              spreadRadius: 1.8 * cellWarnGlow,
            ),
          ],
        );
      } else if (cellSuccessGlow > 0.01) {
        resolvedDecoration = resolvedDecoration.copyWith(
          boxShadow: [
            BoxShadow(
              color: config.successColor.withValues(
                alpha: 0.45 * cellSuccessGlow,
              ),
              blurRadius: 14 * cellSuccessGlow,
              spreadRadius: 1.5 * cellSuccessGlow,
            ),
          ],
        );
      } else if (cellTypingGlow > 0.01) {
        resolvedDecoration = resolvedDecoration.copyWith(
          boxShadow: [
            BoxShadow(
              color: config.accentColor.withValues(
                alpha: 0.38 * cellTypingGlow,
              ),
              blurRadius: 10 * cellTypingGlow,
              spreadRadius: 1.0 * cellTypingGlow,
            ),
          ],
        );
      }
    }

    final showsCellCheck =
        isVerifiedNow &&
        ((verMode == OmniOtpVerifiedAnimation.expandCheck && staggerT > 0.35) ||
            (verMode == OmniOtpVerifiedAnimation.waveCheck &&
                staggerT > 0.32) ||
            (verMode == OmniOtpVerifiedAnimation.rippleCheck &&
                staggerT > 0.30) ||
            (verMode == OmniOtpVerifiedAnimation.flipCheck && staggerT >= 0.5));

    Widget? cellContent;
    if (showsCellCheck) {
      final revealScale = verMode == OmniOtpVerifiedAnimation.flipCheck
          ? 1.0
          : Curves.easeOutBack.transform(
              ((staggerT - 0.30) / 0.70).clamp(0.0, 1.0),
            );
      cellContent = Transform.scale(
        scale: revealScale,
        child: Icon(
          widget.field.verifiedIcon,
          size: effectiveW * 0.52,
          color: config.successColor,
        ),
      );
    } else if (hasChar) {
      cellContent = Opacity(
        opacity: isMergingMode
            ? (1.0 - mergePhase * 1.45).clamp(0.0, 1.0)
            : 1.0,
        child: _buildAnimatedChar(code[i], style),
      );
    } else if (isFocusedCell && widget.field.showCursor) {
      cellContent =
          widget.field.cursor ??
          Container(
            width: 2,
            height: effectiveH * 0.42,
            decoration: BoxDecoration(
              color: config.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          );
    }

    final baseBox = AnimatedContainer(
      duration: widget.field.animationDuration,
      curve: Curves.easeOutCubic,
      width: effectiveW,
      height: effectiveH,
      margin: cellTheme.margin,
      padding: cellTheme.padding,
      constraints: cellTheme.constraints,
      decoration: resolvedDecoration,
      alignment: Alignment.center,
      child: cellContent,
    );

    Widget transformedBox = baseBox;
    if (isMergingMode) {
      final rel = i - centerIndex;
      final pushOut = rel * 4.5 * anticipateT;
      final dx =
          -rel * (effectiveW + gap) * mergePhase + pushOut * (1.0 - mergePhase);
      final dy = verMode == OmniOtpVerifiedAnimation.stackMerge
          ? -math.sin(mergePhase * math.pi) * rel.abs() * 5.5
          : 0.0;
      final angle = verMode == OmniOtpVerifiedAnimation.stackMerge
          ? rel * 0.06 * mergePhase
          : 0.0;
      final shrink = verMode == OmniOtpVerifiedAnimation.mergeCheck
          ? (1.0 - mergePhase * 0.16)
          : 1.0;
      transformedBox = Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: shrink + anticipateT * 0.05,
            child: Opacity(opacity: boxFadeOpacity, child: baseBox),
          ),
        ),
      );
    } else if (isVerifiedNow) {
      switch (verMode) {
        case OmniOtpVerifiedAnimation.waveCheck ||
            OmniOtpVerifiedAnimation.rippleCheck ||
            OmniOtpVerifiedAnimation.confettiBurst:
          final jump = math.sin(staggerT * math.pi);
          transformedBox = Transform.translate(
            offset: Offset(0, -jump * 9.5),
            child: Transform.scale(scale: 1.0 + jump * 0.10, child: baseBox),
          );
        case OmniOtpVerifiedAnimation.expandCheck:
          final bump = math.sin(staggerT * math.pi) * 0.14;
          transformedBox = Transform.scale(scale: 1.0 + bump, child: baseBox);
        case OmniOtpVerifiedAnimation.flipCheck:
          final angle = staggerT < 0.5
              ? staggerT * math.pi
              : (1.0 - staggerT) * math.pi;
          transformedBox = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: baseBox,
          );
        case OmniOtpVerifiedAnimation.mergeCheck ||
            OmniOtpVerifiedAnimation.morphPill ||
            OmniOtpVerifiedAnimation.stackMerge ||
            OmniOtpVerifiedAnimation.badgeOnly:
          break;
      }
    } else if (hasError && errT > 0 && errT < 1) {
      switch (widget.field.errorAnimation) {
        case OmniOtpErrorAnimation.staggerShake:
          final decay = 1.0 - errT;
          final dx = math.sin(errT * math.pi * 5.0 + i * 0.65) * decay * 7.5;
          final dy = math.cos(errT * math.pi * 4.0 + i * 0.85) * decay * 4.0;
          transformedBox = Transform.translate(
            offset: Offset(dx, dy),
            child: baseBox,
          );
        case OmniOtpErrorAnimation.tiltShake:
          final decay = 1.0 - errT;
          final rot =
              math.sin(errT * math.pi * 4.0 + (i.isEven ? 0.0 : 0.4)) *
              decay *
              0.14;
          final dx = math.sin(errT * math.pi * 4.0) * decay * 6.0;
          transformedBox = Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.rotate(angle: rot, child: baseBox),
          );
        case OmniOtpErrorAnimation.jello:
          final squash = math.sin(errT * math.pi * 4.0) * (1.0 - errT);
          transformedBox = Transform.scale(
            scaleX: 1.0 + squash * 0.16,
            scaleY: 1.0 - squash * 0.13,
            child: baseBox,
          );
        case OmniOtpErrorAnimation.shake ||
            OmniOtpErrorAnimation.bounce ||
            OmniOtpErrorAnimation.pulse ||
            OmniOtpErrorAnimation.flash ||
            OmniOtpErrorAnimation.none:
          break;
      }
    } else if (hasWarning && warnT > 0 && warnT < 1) {
      switch (widget.field.warningAnimation) {
        case OmniOtpWarningAnimation.waveBounce:
          final jump = math.sin(
            ((warnT * 1.6) - linearPos * 0.6).clamp(0.0, 1.0) * math.pi,
          );
          transformedBox = Transform.translate(
            offset: Offset(0, -jump * 8.0),
            child: Transform.scale(scale: 1.0 + jump * 0.06, child: baseBox),
          );
        case OmniOtpWarningAnimation.tilt:
          final rot =
              math.sin(warnT * math.pi * 2.5 + i * 0.3) * (1.0 - warnT) * 0.09;
          transformedBox = Transform.rotate(angle: rot, child: baseBox);
        case OmniOtpWarningAnimation.pulse ||
            OmniOtpWarningAnimation.heartbeat ||
            OmniOtpWarningAnimation.shimmer ||
            OmniOtpWarningAnimation.wobble ||
            OmniOtpWarningAnimation.bounce ||
            OmniOtpWarningAnimation.glow ||
            OmniOtpWarningAnimation.none:
          break;
      }
    } else if (cellTypingGlow > 0.01) {
      final popScale = 1.0 + math.sin(typeT * math.pi) * 0.085;
      transformedBox = Transform.scale(scale: popScale, child: baseBox);
    }
    return transformedBox;
  }
}

/// What every OTP cell needs from one build/layout pass: resolved
/// theme and pin styles, the typed code, sizes and the current status.
@immutable
class _OtpLook {
  const _OtpLook({
    required this.config,
    required this.boxStyle,
    required this.baseTextStyle,
    required this.effectiveFocusedPin,
    required this.effectiveSubmittedPin,
    required this.effectiveWarningPin,
    required this.effectiveErrorPin,
    required this.effectiveDisabledPin,
    required this.effectiveFollowingPin,
    required this.warnColor,
    required this.code,
    required this.activeIndex,
    required this.n,
    required this.gap,
    required this.boxH,
    required this.responsiveCellW,
    required this.hasError,
    required this.hasWarning,
    required this.isDisabled,
    required this.isVerifiedNow,
    required this.verMode,
    required this.centerIndex,
  });

  final ResolvedFieldConfig config;
  final OmniOtpBoxStyle boxStyle;
  final TextStyle baseTextStyle;
  final OmniPinTheme effectiveFocusedPin;
  final OmniPinTheme effectiveSubmittedPin;
  final OmniPinTheme effectiveWarningPin;
  final OmniPinTheme effectiveErrorPin;
  final OmniPinTheme effectiveDisabledPin;
  final OmniPinTheme effectiveFollowingPin;
  final Color warnColor;
  final String code;
  final int activeIndex;
  final int n;
  final double gap;
  final double boxH;
  final double responsiveCellW;
  final bool hasError;
  final bool hasWarning;
  final bool isDisabled;
  final bool isVerifiedNow;
  final OmniOtpVerifiedAnimation verMode;
  final double centerIndex;
}

/// Per-animation-frame values (error/warning/verify/typing progress) the
/// cells read while the row animates.
@immutable
class _OtpFrame {
  const _OtpFrame({
    required this.errT,
    required this.warnT,
    required this.verT,
    required this.typeT,
    required this.errorGlow,
    required this.warnGlow,
    required this.anticipateT,
    required this.mergePhase,
    required this.boxFadeOpacity,
    required this.isMergingMode,
  });

  final double errT;
  final double warnT;
  final double verT;
  final double typeT;
  final double errorGlow;
  final double warnGlow;
  final double anticipateT;
  final double mergePhase;
  final double boxFadeOpacity;
  final bool isMergingMode;
}

class _OtpBurstPainter extends CustomPainter {
  const _OtpBurstPainter({
    required this.progress,
    required this.mode,
    required this.primaryColor,
    required this.accentColor,
  });

  final double progress;
  final OmniOtpVerifiedAnimation mode;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (mode == OmniOtpVerifiedAnimation.confettiBurst) {
      final t = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
      final fade = (1.0 - ((progress - 0.58) / 0.42).clamp(0.0, 1.0));
      if (fade <= 0.01) return;

      final palette = [
        primaryColor,
        accentColor,
        const Color(0xFFF59E0B),
        const Color(0xFFEC4899),
        const Color(0xFF3B82F6),
        const Color(0xFF8B5CF6),
      ];

      const count = 18;
      for (var i = 0; i < count; i++) {
        final angle = -math.pi + (i / (count - 1)) * math.pi;
        final spread = 42.0 + (i % 4) * 16.0;
        final startX = size.width * ((i + 0.5) / count).clamp(0.1, 0.9);
        final dx = math.cos(angle) * spread * t;
        final dy =
            math.sin(angle) * spread * t + 26.0 * t * t; // হালকা গ্র্যাভিটি
        final pos = Offset(startX + dx, center.dy + dy - 6.0);
        final paint = Paint()
          ..color = palette[i % palette.length].withValues(alpha: 0.9 * fade);
        if (i.isEven) {
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(angle + t * 2.4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -2, 8, 4),
              const Radius.circular(1.5),
            ),
            paint,
          );
          canvas.restore();
        } else {
          canvas.drawCircle(pos, 3.0 * (1.0 - t * 0.35), paint);
        }
      }
      return;
    }

    // mergeCheck / morphPill / stackMerge / rippleCheck-এর শকওয়েভ রিং ও স্পার্কল:
    final burstT = ((progress - 0.44) / 0.56).clamp(0.0, 1.0);
    if (burstT <= 0.01) return;

    final eased = Curves.easeOutCubic.transform(burstT);
    final fade = (1.0 - burstT).clamp(0.0, 1.0);

    final baseRadius = math.max(16.0, size.height * 0.44);
    final ringRadius = baseRadius + eased * (size.height * 0.65);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * fade
      ..color = primaryColor.withValues(alpha: 0.48 * fade);
    canvas.drawCircle(center, ringRadius, ringPaint);

    const sparkCount = 10;
    for (var i = 0; i < sparkCount; i++) {
      final a = (i * (2 * math.pi / sparkCount)) - math.pi / 2;
      final dist = baseRadius + eased * (size.height * 0.72);
      final pt = Offset(
        center.dx + math.cos(a) * dist,
        center.dy + math.sin(a) * dist,
      );
      final p = Paint()
        ..color = (i.isEven ? primaryColor : const Color(0xFFF59E0B))
            .withValues(alpha: 0.85 * fade);
      canvas.drawCircle(pt, (i.isEven ? 3.2 : 2.2) * (1.0 - eased * 0.3), p);
    }
  }

  @override
  bool shouldRepaint(covariant _OtpBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.mode != mode ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor;
}
