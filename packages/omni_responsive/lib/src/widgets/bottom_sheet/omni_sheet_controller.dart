part of 'omni_bottom_sheet.dart';

/// Controls the sheet a widget is in; get it with [OmniSheet.of].
abstract interface class OmniSheetController {
  /// Index of the detent the sheet rests on (or is moving to), in the caller's
  /// `detents` order.
  ValueListenable<int> get detent;

  /// Whether the scroll view inside is scrolled away from its top — for a
  /// custom header that shows a separator or a shadow.
  ValueListenable<bool> get isScrolled;

  /// How many detents the sheet has.
  int get detentCount;

  /// The resolved style ([OmniSheetStyle.adaptive] is never returned).
  OmniSheetStyle get style;

  /// The controller that lets a scroll view inside drag the sheet. Scroll
  /// views pick it up on their own via `PrimaryScrollController`; pass it
  /// explicitly if another controller or nested scroll setup overrides it.
  ScrollController get scrollController;

  /// Animates to the detent at [index] (in the caller's `detents` order).
  Future<void> snapTo(int index);

  /// Closes the sheet programmatically, completing `showOmniBottomSheet` with
  /// [result] (bypasses `PopScope` guards; user-initiated dismissal via drag,
  /// barrier tap, close button, or Escape respects `PopScope`).
  void close([Object? result]);
}

/// Access to the sheet around a widget.
abstract final class OmniSheet {
  /// The sheet around [context]; throws outside one.
  static OmniSheetController of(BuildContext context) =>
      maybeOf(context) ??
      (throw FlutterError(
        'OmniSheet.of() called with a context that is not inside an Omni '
        'bottom sheet.',
      ));

  /// The sheet around [context], or `null`.
  static OmniSheetController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_OmniSheetScope>()?.controller;
}

class _OmniSheetScope extends InheritedWidget {
  const _OmniSheetScope({required this.controller, required super.child});

  final OmniSheetController controller;

  @override
  bool updateShouldNotify(_OmniSheetScope old) => false;
}
