part of 'omni_bottom_sheet.dart';

/// Settings shared by the modal sheet ([OmniSheetRoute]) and the
/// in-page one ([OmniScalableSheet]).
@immutable
class _SheetConfig {
  const _SheetConfig({
    required this.builder,
    required this.header,
    required this.title,
    required this.trailing,
    required this.showCloseButton,
    required this.scrolling,
    required this.detents,
    required this.initialDetent,
    required this.isDismissible,
    required this.enableDrag,
    required this.showHandle,
    required this.backgroundColor,
    required this.handleColor,
    required this.cornerRadius,
    required this.margin,
    required this.maxWidth,
    required this.shadow,
    required this.useSafeArea,
    required this.semanticLabel,
  });

  final WidgetBuilder builder;
  final WidgetBuilder? header;
  final String? title;
  final WidgetBuilder? trailing;
  final bool? showCloseButton;
  final OmniSheetScrolling scrolling;
  final List<OmniSheetDetent> detents;
  final int initialDetent;
  final bool isDismissible;
  final bool enableDrag;
  final bool? showHandle;
  final Color? backgroundColor;
  final Color? handleColor;
  final double? cornerRadius;
  final EdgeInsets? margin;
  final double? maxWidth;
  final List<BoxShadow>? shadow;
  final bool useSafeArea;
  final String? semanticLabel;
}

/// What the sheet view needs from whoever shows it: a modal route or an
/// in-page [OmniScalableSheet].
abstract class _SheetHost {
  _SheetConfig get config;

  OmniSheetStyle get effectiveStyle;

  OmniSheetMotion get effectiveMotion;

  /// 0 = hidden below the edge, 1 = shown; dragging writes to it directly.
  AnimationController get presence;

  bool get reduceMotion;

  /// Modal sheets name and scope a route for screen readers.
  bool get isModal;

  /// Whether the host has started closing and should ignore new drag gestures.
  bool get isClosing => false;

  /// Springs [presence] back to 1 after a partial drag.
  void settlePresence(double velocity);

  /// Hides the sheet after a drag down at [velocity] (presence units/s).
  /// Completes with `false` when something (a `PopScope`) refused.
  Future<bool> dismiss(double velocity);

  /// Closes the sheet from code ([OmniSheetController.close]).
  void close(Object? result);

  /// The detent the sheet now rests on (or moves to), in caller order.
  void didChangeDetent(int index);

  /// The view registers itself so the host's controller can drive it.
  void attachView(_OmniSheetViewState? view);
}

/// Validates sheet configuration at runtime so invalid inputs fail early and
/// consistently in both debug and release builds.
void _validateSheetConfig({
  required List<OmniSheetDetent> detents,
  required int initialDetent,
  int? dimFromDetent,
  double? cornerRadius,
  double? maxWidth,
  OmniSheetMotion? motion,
}) {
  if (detents.isEmpty) {
    throw ArgumentError.value(
      detents,
      'detents',
      'A sheet needs at least one detent.',
    );
  }
  for (var i = 0; i < detents.length; i++) {
    detents[i]._validate(i);
  }
  if (detents.length > 1 && detents.any((d) => d._isContent)) {
    throw ArgumentError.value(
      detents,
      'detents',
      'OmniSheetDetent.content can only be used on its own.',
    );
  }
  RangeError.checkValidIndex(initialDetent, detents, 'initialDetent');
  if (dimFromDetent != null) {
    RangeError.checkValidIndex(dimFromDetent, detents, 'dimFromDetent');
  }
  if (cornerRadius != null && (!cornerRadius.isFinite || cornerRadius < 0)) {
    throw ArgumentError.value(
      cornerRadius,
      'cornerRadius',
      'Corner radius must be finite and >= 0.',
    );
  }
  if (maxWidth != null && (!maxWidth.isFinite || maxWidth <= 0)) {
    throw ArgumentError.value(
      maxWidth,
      'maxWidth',
      'Max width must be finite and > 0.',
    );
  }
  motion?._validate();
}

/// Springs [presence] to [target], or jumps there with reduced motion.
TickerFuture _springPresence(
  AnimationController presence,
  OmniSheetMotion motion,
  double target,
  double velocity, {
  required bool reduceMotion,
}) {
  if (reduceMotion) {
    return target >= presence.value
        ? presence.animateTo(
            target,
            duration: const Duration(milliseconds: 160),
          )
        : presence.animateBack(
            target,
            duration: const Duration(milliseconds: 160),
          );
  }
  final sim = _settlingSpring(
    motion.spring,
    presence.value,
    target,
    velocity,
    tolerance: const Tolerance(distance: 0.0008, velocity: 0.01),
  );
  return target >= presence.value
      ? presence.animateWith(sim)
      : presence.animateBackWith(sim);
}
