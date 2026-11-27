part of 'omni_bottom_sheet.dart';

/// Controls the sheet a widget is in; get it with [OmniSheet.of].
abstract interface class OmniSheetController {
  /// Index of the detent the sheet rests on (or is moving to).
  ValueListenable<int> get detent;

  /// How many detents the sheet has.
  int get detentCount;

  /// The resolved style ([OmniSheetStyle.adaptive] is never returned).
  OmniSheetStyle get style;

  /// The controller that lets a scroll view inside drag the sheet. Scroll
  /// views pick it up on their own on iOS and Android
  /// (`PrimaryScrollController`); pass it explicitly on desktop.
  ScrollController get scrollController;

  /// Animates to the detent at [index].
  Future<void> snapTo(int index);

  /// Closes the sheet, completing `showOmniBottomSheet` with [result].
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
