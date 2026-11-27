part of 'omni_bottom_sheet.dart';

class _SheetScrollController extends ScrollController {
  _SheetScrollController(this.sheet);

  final _OmniSheetViewState sheet;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SheetScrollPosition(
    sheet: sheet,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    debugLabel: debugLabel,
  );
}

class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition({
    required this.sheet,
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });

  final _OmniSheetViewState sheet;
  bool _driving = false;

  @override
  void applyUserOffset(double delta) {
    // A drag down that reaches the top mid-gesture: the list scrolls the
    // rest of the way to its top, the remainder moves the sheet.
    if (!_driving &&
        delta > 0 &&
        pixels > minScrollExtent &&
        pixels - delta < minScrollExtent &&
        sheet._config.enableDrag &&
        sheet._heights.isNotEmpty) {
      final toTop = pixels - minScrollExtent;
      super.applyUserOffset(toTop);
      _driving = true;
      sheet._dragStart();
      sheet._dragUpdate(delta - toTop);
      return;
    }
    if (sheet._takesScroll(delta, this)) {
      if (!_driving) {
        _driving = true;
        sheet._dragStart();
      }
      sheet._dragUpdate(delta);
      return;
    }
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (_driving) {
      _driving = false;
      final expanded =
          sheet._presence.value >= 1 && sheet._raw >= sheet._heights.last;
      if (expanded) {
        // The sheet is fully up: the content keeps its fling.
        sheet._dragEnd(0);
        super.goBallistic(velocity);
      } else {
        sheet._dragEnd(-velocity);
        super.goBallistic(0);
      }
      return;
    }
    super.goBallistic(velocity);
  }

  @override
  void dispose() {
    if (_driving) sheet._dragEnd(0);
    super.dispose();
  }
}
